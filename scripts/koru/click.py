#!/usr/bin/env python3
"""Persistent click settings and a session-scoped ydotool worker."""
import argparse
import fcntl
import math
import os
from pathlib import Path
import signal
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time

UNIT = 'koru-click.service'
DEFAULT_FREQUENCY = 100.0
SOCKET = '/run/ydotoold/socket'


def settings_path():
    return Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'koru/click-frequency'


def frequency_value(value):
    try:
        number = float(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError('Frequency must be a number.') from error
    if not math.isfinite(number) or not 0.1 <= number <= 1000:
        raise argparse.ArgumentTypeError('Frequency must be between 0.1 and 1000 clicks per second.')
    return number


def read_frequency():
    try:
        return frequency_value(settings_path().read_text().strip())
    except FileNotFoundError:
        return DEFAULT_FREQUENCY


def save_frequency(number):
    path = settings_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, delete=False) as handle:
        temporary = Path(handle.name)
        handle.write(f'{number:g}\n')
    try:
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def check_backend():
    connection = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    try:
        connection.connect(os.environ.get('YDOTOOL_SOCKET', SOCKET))
    except OSError:
        connection.close()
        raise RuntimeError('Cannot access ydotoold. Apply the NixOS configuration and log out and back in.') from None
    return connection


def worker():
    stopped = threading.Event()
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: stopped.set())
    # ydotoold accepts native Linux input_event records, one per datagram.
    # BTN_LEFT down/up, each followed by SYN_REPORT, form one full click.
    def emit(connection, kind, code, value):
        connection.send(struct.pack('@llHHi', 0, 0, kind, code, value))

    with check_backend() as connection:
        deadline = time.monotonic() + 0.25  # Let the hotkey modifiers be released.
        try:
            while not stopped.wait(max(0, deadline - time.monotonic())):
                frequency = read_frequency()
                emit(connection, 1, 272, 1)
                emit(connection, 0, 0, 0)
                emit(connection, 1, 272, 0)
                emit(connection, 0, 0, 0)
                interval = 1 / frequency
                deadline += interval
                # Skip missed clicks instead of emitting bursts after a stall.
                if deadline < time.monotonic():
                    deadline = time.monotonic() + interval
        finally:
            emit(connection, 1, 272, 0)
            emit(connection, 0, 0, 0)


def is_active():
    return subprocess.run(['systemctl', '--user', 'is-active', '--quiet', UNIT], check=False).returncode == 0


def main():
    parser = argparse.ArgumentParser(prog='koru click', description='Toggle automatic left clicks at the cursor. Default: 100 clicks/s.')
    parser.add_argument('action', nargs='?', choices=['toggle', 'start', 'stop', 'status'])
    parser.add_argument('--frequency', type=frequency_value, help='save clicks per second (0.1–1000); applies while running')
    parser.add_argument('--worker', action='store_true', help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.worker:
        worker()
        return
    # Serialize rapid hotkey invocations so each press toggles exactly once.
    runtime = Path(os.environ.get('XDG_RUNTIME_DIR', '/tmp'))
    with (runtime / f'koru-click-{os.getuid()}.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if args.frequency is not None:
            save_frequency(args.frequency)
        action = args.action or ('status' if args.frequency is not None else 'toggle')
        if action == 'toggle':
            action = 'stop' if is_active() else 'start'
        if action == 'start':
            with check_backend():
                pass
        if action in ('start', 'stop'):
            subprocess.run(['systemctl', '--user', action, UNIT], check=True)
        print(f'Click: {"running" if is_active() else "stopped"}; frequency: {read_frequency():g} clicks/s')


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, argparse.ArgumentTypeError, subprocess.CalledProcessError) as error:
        print(f'koru click: {error}', file=sys.stderr)
        sys.exit(1)
