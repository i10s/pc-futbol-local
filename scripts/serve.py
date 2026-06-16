#!/usr/bin/env python3
"""
Tiny static file server with HTTP Range support.

v86 streams the multi-hundred-MB disk images using HTTP Range requests, so a
plain `python -m http.server` is not enough on older Python versions. This
server implements 206 Partial Content responses and is threaded so the browser
can pull several byte-ranges at once.

Usage:
    python3 serve.py --root /path/to/docroot --port 8782
"""
import argparse
import os
import posixpath
import re
import socket
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import unquote, urlparse

CONTENT_TYPES = {
    ".html": "text/html; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".mjs": "text/javascript; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".wasm": "application/wasm",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".svg": "image/svg+xml",
    ".ico": "image/x-icon",
    ".woff": "font/woff",
    ".woff2": "font/woff2",
    ".ttf": "font/ttf",
    ".bin": "application/octet-stream",
    ".map": "application/json; charset=utf-8",
}

RANGE_RE = re.compile(r"bytes=(\d*)-(\d*)")


class Handler(BaseHTTPRequestHandler):
    root = os.getcwd()
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):  # keep the console quiet
        pass

    def _resolve(self):
        # Strip the query string (?v=2 cache busters) before resolving the path.
        path = urlparse(self.path).path
        path = unquote(path)
        if path.endswith("/"):
            path += "index.html"
        # Normalise and prevent path traversal outside of the docroot.
        path = posixpath.normpath(path).lstrip("/")
        full = os.path.normpath(os.path.join(self.root, path))
        if not full.startswith(os.path.normpath(self.root)):
            return None
        return full

    def _ctype(self, full):
        return CONTENT_TYPES.get(os.path.splitext(full)[1].lower(),
                                 "application/octet-stream")

    def do_GET(self):
        self._serve(write_body=True)

    def do_HEAD(self):
        self._serve(write_body=False)

    def _serve(self, write_body):
        full = self._resolve()
        if not full or not os.path.isfile(full):
            self.send_error(404, "Not Found")
            return

        size = os.path.getsize(full)
        ctype = self._ctype(full)
        rng = self.headers.get("Range")

        start, end = 0, size - 1
        partial = False
        if rng:
            m = RANGE_RE.match(rng.strip())
            if m:
                g1, g2 = m.group(1), m.group(2)
                if g1 == "" and g2 != "":           # bytes=-N  (suffix)
                    length = min(int(g2), size)
                    start, end = size - length, size - 1
                else:
                    start = int(g1)
                    end = int(g2) if g2 != "" else size - 1
                if start > end or start >= size:
                    self.send_response(416)
                    self.send_header("Content-Range", f"bytes */{size}")
                    self.end_headers()
                    return
                end = min(end, size - 1)
                partial = True

        length = end - start + 1
        self.send_response(206 if partial else 200)
        self.send_header("Content-Type", ctype)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(length))
        if partial:
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()

        if not write_body:
            return

        try:
            with open(full, "rb") as f:
                f.seek(start)
                remaining = length
                chunk = 1024 * 256
                while remaining > 0:
                    data = f.read(min(chunk, remaining))
                    if not data:
                        break
                    self.wfile.write(data)
                    remaining -= len(data)
        except (BrokenPipeError, ConnectionResetError):
            pass


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=os.getcwd())
    ap.add_argument("--port", type=int, default=8782)
    ap.add_argument("--host", default="127.0.0.1")
    args = ap.parse_args()

    Handler.root = os.path.abspath(args.root)
    try:
        httpd = ThreadingHTTPServer((args.host, args.port), Handler)
    except OSError as exc:
        print(f"[serve] cannot bind {args.host}:{args.port} -> {exc}",
              file=sys.stderr)
        sys.exit(2)
    httpd.daemon_threads = True
    print(f"[serve] http://{args.host}:{args.port}  root={Handler.root}")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()


if __name__ == "__main__":
    main()
