#!/usr/bin/env python3
"""Share a single file over HTTP with a terminal QR code."""

import argparse
import ipaddress
import json
import mimetypes
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import quote, urlsplit


def port_value(value):
    try:
        port = int(value)
        if 1 <= port <= 65535:
            return port
    except ValueError:
        pass
    raise argparse.ArgumentTypeError('Port must be between 1 and 65535.')


def host_value(value):
    try:
        address = ipaddress.IPv4Address(value)
        if not (address.is_unspecified or address.is_loopback or address.is_multicast):
            return str(address)
    except ValueError:
        pass
    raise argparse.ArgumentTypeError('Use a LAN IPv4 address, e.g. 192.168.1.10.')


def lan_addresses():
    result = subprocess.run(
        ['ip', '-j', '-4', 'addr', 'show', 'scope', 'global'],
        check=True, capture_output=True, text=True,
    )
    candidates = []
    for interface in json.loads(result.stdout):
        if 'UP' not in interface.get('flags', []) or 'POINTOPOINT' in interface.get('flags', []):
            continue
        name = interface['ifname']
        # Physical NICs first; bridges remain available for unusual network setups.
        physical = (Path('/sys/class/net') / name / 'device').exists()
        if name.startswith(('docker', 'veth', 'virbr', 'tun', 'tap', 'tailscale')):
            continue
        for info in interface.get('addr_info', []):
            if info.get('family') == 'inet':
                candidates.append((not physical, info['local']))
    return [address for _, address in sorted(candidates, key=lambda item: item[0])]


def byte_range(value, size):
    """Return inclusive bounds for a single HTTP byte range."""
    match = re.fullmatch(r'bytes=(\d*)-(\d*)', value)
    if not match or size == 0:
        raise ValueError('Invalid range')
    first, last = match.groups()
    if not first:
        length = int(last or '0')
        if length <= 0:
            raise ValueError('Invalid suffix')
        return max(0, size - length), size - 1
    start = int(first)
    end = min(int(last), size - 1) if last else size - 1
    if start >= size or start > end:
        raise ValueError('Unsatisfiable range')
    return start, end


def handler_for(path, download_path):
    class DownloadHandler(BaseHTTPRequestHandler):
        def log_message(self, format, *args):
            # Avoid printing request paths or untrusted request content.
            pass

        def do_HEAD(self):
            self.download(head=True)

        def do_GET(self):
            self.download(head=False)

        def download(self, head):
            if urlsplit(self.path).path != download_path:
                self.send_error(404, 'File not found')
                return
            try:
                stream = path.open('rb')
            except OSError:
                self.send_error(404, 'Shared file is no longer available')
                return
            with stream:
                size = os.fstat(stream.fileno()).st_size
                start, end = 0, size - 1
                partial = False
                if self.headers.get('Range') and not self.headers.get('If-Range'):
                    try:
                        start, end = byte_range(self.headers['Range'], size)
                        partial = True
                    except ValueError:
                        self.send_response(416)
                        self.send_header('Content-Range', f'bytes */{size}')
                        self.send_header('Content-Length', '0')
                        self.end_headers()
                        return
                self.send_response(206 if partial else 200)
                self.send_header('Content-Type', mimetypes.guess_type(path.name)[0] or 'application/octet-stream')
                self.send_header('Content-Disposition', f"attachment; filename=\"download\"; filename*=UTF-8''{quote(path.name, safe='')}")
                self.send_header('Content-Length', str(end - start + 1))
                self.send_header('Accept-Ranges', 'bytes')
                self.send_header('Cache-Control', 'no-store')
                self.send_header('X-Content-Type-Options', 'nosniff')
                if partial:
                    self.send_header('Content-Range', f'bytes {start}-{end}/{size}')
                self.end_headers()
                if head:
                    return
                try:
                    stream.seek(start)
                    remaining = end - start + 1
                    while remaining:
                        chunk = stream.read(min(1024 * 1024, remaining))
                        if not chunk:
                            break
                        self.wfile.write(chunk)
                        remaining -= len(chunk)
                    if not remaining:
                        print(f'Download sent to {self.client_address[0]} ({end - start + 1:,} bytes).', flush=True)
                except (BrokenPipeError, ConnectionResetError, TimeoutError):
                    pass

    return DownloadHandler


def main():
    parser = argparse.ArgumentParser(
        prog='koru file', description='Share one file with a phone on the same LAN. Ctrl+C stops sharing.',
    )
    parser.add_argument('path', type=Path, help='file to download')
    parser.add_argument('--host', type=host_value, help='LAN IPv4 address to put in the QR code (auto-detected)')
    parser.add_argument('--port', type=port_value, default=8080, help='HTTP port (default: 8080; other ports need firewall access)')
    args = parser.parse_args()
    try:
        path = args.path.expanduser().resolve(strict=True)
        if not path.is_file():
            parser.error('PATH must be a regular file.')
        with path.open('rb'):
            pass
        if not shutil.which('qrencode'):
            parser.error('qrencode is missing; rebuild the koru package.')
        addresses = lan_addresses() if args.host is None else [args.host]
        if not addresses:
            parser.error('No LAN IPv4 address found. Connect to Wi-Fi/Ethernet or use --host IP.')
        host = addresses[0]
        download_path = f'/{secrets.token_urlsafe(24)}/{quote(path.name, safe="")}'
        url = f'http://{host}:{args.port}{download_path}'
        # Do not silently reuse an occupied port: another app may own 8080.
        with ThreadingHTTPServer(('0.0.0.0', args.port), handler_for(path, download_path)) as server:
            server.daemon_threads = True
            server.timeout = 0.5
            print(f'File: {path.name}\nSize: {path.stat().st_size:,} bytes\nDownload: {url}', flush=True)
            if len(addresses) > 1:
                print(f'Other LAN addresses: {", ".join(addresses[1:])}. Use --host IP if needed.', flush=True)
            print('Connect your phone to the same LAN and scan the QR code.\nKeep this terminal open; Ctrl+C stops sharing.', flush=True)
            subprocess.run(['qrencode', '-t', 'UTF8', '-m', '2', url], check=True)
            server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        print('\nSharing stopped.', flush=True)
    except (OSError, subprocess.CalledProcessError, ValueError) as error:
        parser.exit(1, f'koru file: {error}\n')


if __name__ == '__main__':
    main()
