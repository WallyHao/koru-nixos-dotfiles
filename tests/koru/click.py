#!/usr/bin/env python3
"""Exercise the worker against a fake ydotoold; never click the real desktop."""
import importlib.util
import os
from pathlib import Path
import signal
import socket
import struct
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch, MagicMock

SOURCE = Path(__file__).resolve().parents[2] / 'scripts/koru/click.py'
spec = importlib.util.spec_from_file_location('click', SOURCE)
click = importlib.util.module_from_spec(spec)
spec.loader.exec_module(click)


class ClickTests(unittest.TestCase):
    def test_validation(self):
        for value in ('0', '-1', 'nan', 'inf', '1001', 'abc'):
            with self.assertRaises(click.argparse.ArgumentTypeError):
                click.frequency_value(value)
        self.assertEqual(click.frequency_value('100'), 100)
        self.assertEqual(click.frequency_value('2.5'), 2.5)

    def test_frequency_option_does_not_start_clicking(self):
        with tempfile.TemporaryDirectory(dir='/tmp') as directory:
            with patch.dict(os.environ, {'XDG_CONFIG_HOME': directory, 'XDG_RUNTIME_DIR': directory}):
                with patch.object(sys, 'argv', ['koru click', '--frequency', '250']):
                    with patch.object(click, 'is_active', return_value=False):
                        with patch.object(click.subprocess, 'run') as run:
                            with patch('builtins.print'):
                                click.main()
                            run.assert_not_called()
                self.assertEqual(click.read_frequency(), 250)

    def test_toggle_stops_and_starts(self):
        with tempfile.TemporaryDirectory(dir='/tmp') as directory:
            with patch.dict(os.environ, {'XDG_CONFIG_HOME': directory, 'XDG_RUNTIME_DIR': directory}):
                for active, expected in [(True, 'stop'), (False, 'start')]:
                    with patch.object(sys, 'argv', ['koru click', 'toggle']):
                        with patch.object(click, 'is_active', return_value=active):
                            with patch.object(click, 'check_backend', return_value=MagicMock()):
                                with patch.object(click.subprocess, 'run') as run:
                                    with patch('builtins.print'):
                                        click.main()
                                    run.assert_called_once_with(['systemctl', '--user', expected, click.UNIT], check=True)

    def test_settings_and_worker(self):
        with tempfile.TemporaryDirectory(prefix='click-', dir='/tmp') as directory:
            env = {**os.environ, 'XDG_CONFIG_HOME': directory, 'YDOTOOL_SOCKET': directory + '/socket'}
            with patch.dict(os.environ, env):
                self.assertEqual(click.read_frequency(), 100)
                click.save_frequency(100)
                with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as backend:
                    backend.bind(env['YDOTOOL_SOCKET'])
                    backend.settimeout(2)
                    process = subprocess.Popen([sys.executable, str(SOURCE), '--worker'], env=env)
                    try:
                        events = []
                        stamps = []
                        for _ in range(80):
                            event = struct.unpack('@llHHi', backend.recv(128))[2:]
                            events.append(event)
                            if event == (1, 272, 1):
                                stamps.append(time.monotonic())
                        self.assertEqual(events, [(1, 272, 1), (0, 0, 0), (1, 272, 0), (0, 0, 0)] * 20)
                        self.assertTrue(0.14 < stamps[-1] - stamps[0] < 0.30)
                        click.save_frequency(20)
                        stamps = []
                        while len(stamps) < 5:
                            if struct.unpack('@llHHi', backend.recv(128))[2:] == (1, 272, 1):
                                stamps.append(time.monotonic())
                        self.assertTrue(0.14 < stamps[-1] - stamps[0] < 0.30)
                        process.send_signal(signal.SIGTERM)
                        self.assertEqual(process.wait(timeout=2), 0)
                        remaining = []
                        backend.settimeout(0.1)
                        try:
                            while True:
                                remaining.append(struct.unpack('@llHHi', backend.recv(128))[2:])
                        except socket.timeout:
                            pass
                        self.assertEqual(remaining[-2:], [(1, 272, 0), (0, 0, 0)])
                    finally:
                        if process.poll() is None:
                            process.kill()
                            process.wait()


if __name__ == '__main__':
    unittest.main()
