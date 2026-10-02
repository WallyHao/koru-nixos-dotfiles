#!/usr/bin/env python3
"""Exercise real HTTP downloads, ranges and access boundaries on loopback."""
import http.client
import importlib.util
from pathlib import Path
import tempfile
import threading
import unittest
from urllib.parse import quote

SOURCE = Path(__file__).resolve().parents[2] / 'scripts/koru/file.py'
spec = importlib.util.spec_from_file_location('koru_file', SOURCE)
sharing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sharing)


class Downloads(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / '视频 " test.mp4'
        self.payload = bytes(range(256)) * 8193
        self.path.write_bytes(self.payload)
        self.url = '/random-token/' + quote(self.path.name, safe='')
        self.server = sharing.ThreadingHTTPServer(
            ('127.0.0.1', 0), sharing.handler_for(self.path, self.url),
        )
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop)

    def stop(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def request(self, method='GET', url=None, headers=None):
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_port)
        try:
            connection.request(method, url or self.url, headers=headers or {})
            response = connection.getresponse()
            return response.status, dict(response.getheaders()), response.read()
        finally:
            connection.close()

    def test_full_download_and_unicode_filename(self):
        status, headers, body = self.request()
        self.assertEqual(status, 200)
        self.assertEqual(body, self.payload)
        self.assertEqual(int(headers['Content-Length']), len(body))
        self.assertIn("filename*=UTF-8''" + quote(self.path.name, safe=''), headers['Content-Disposition'])

    def test_head(self):
        status, headers, body = self.request('HEAD')
        self.assertEqual(status, 200)
        self.assertEqual(int(headers['Content-Length']), len(self.payload))
        self.assertEqual(body, b'')

    def test_ranges(self):
        for value, expected in [('bytes=10-19', self.payload[10:20]),
                                ('bytes=-10', self.payload[-10:]),
                                ('bytes=2097390-', self.payload[2097390:])]:
            with self.subTest(value=value):
                status, headers, body = self.request(headers={'Range': value})
                self.assertEqual(status, 206)
                self.assertEqual(body, expected)
                self.assertIn('Content-Range', headers)
        status, _, body = self.request(headers={'Range': 'bytes=0-5', 'If-Range': 'old-etag'})
        self.assertEqual(status, 200)
        self.assertEqual(body, self.payload)

    def test_invalid_ranges(self):
        for value in ['bytes=99999999-', 'bytes=5-2', 'bytes=-0', 'bytes=0-1,3-4', 'garbage']:
            with self.subTest(value=value):
                status, headers, body = self.request(headers={'Range': value})
                self.assertEqual(status, 416)
                self.assertEqual(headers['Content-Range'], f'bytes */{len(self.payload)}')
                self.assertEqual(body, b'')

    def test_unshared_paths(self):
        for url in ['/', '/random-token/', '/wrong/' + quote(self.path.name), '/random-token/../secret', '/favicon.ico']:
            with self.subTest(url=url):
                self.assertEqual(self.request(url=url)[0], 404)

    def test_empty_and_removed_file(self):
        self.path.write_bytes(b'')
        self.assertEqual(self.request()[2], b'')
        self.assertEqual(self.request(headers={'Range': 'bytes=0-'})[0], 416)
        self.path.unlink()
        self.assertEqual(self.request()[0], 404)


if __name__ == '__main__':
    unittest.main()
