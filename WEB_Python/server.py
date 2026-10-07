import json
import logging
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parent
API_URL = os.getenv("API_URL", "http://127.0.0.1:8000").rstrip("/")
LOG = logging.getLogger("web_python")


class WebHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def do_GET(self):
        if self._is_api_request():
            self._proxy()
        else:
            super().do_GET()

    def do_POST(self):
        self._proxy()

    def do_PUT(self):
        self._proxy()

    def do_DELETE(self):
        self._proxy()

    def _is_api_request(self):
        return self.path.startswith("/api/v1/") or self.path == "/health"

    def _proxy(self):
        if not self._is_api_request():
            self.send_error(404)
            return

        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length else None
        headers = {
            key: self.headers[key]
            for key in ("Accept", "Authorization", "Content-Type")
            if key in self.headers
        }
        request = Request(f"{API_URL}{self.path}", data=body, headers=headers, method=self.command)
        try:
            upstream = urlopen(request, timeout=15)
        except HTTPError as error:
            upstream = error
        except (URLError, TimeoutError) as error:
            LOG.error("API upstream request failed: %s", error)
            self._send_json_error(502, "API_UNAVAILABLE", "No se pudo conectar con la API de Python.")
            return

        with upstream:
            response_body = upstream.read()
            self.send_response(upstream.status)
            self.send_header("Content-Type", upstream.headers.get("Content-Type", "application/json"))
            self.send_header("Content-Length", str(len(response_body)))
            self.end_headers()
            self.wfile.write(response_body)

    def _send_json_error(self, status, code, message):
        body = json.dumps({"success": False, "error": {"code": code, "message": message}}).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    host = os.getenv("WEB_HOST", "127.0.0.1")
    port = int(os.getenv("WEB_PORT", "5501"))
    server = ThreadingHTTPServer((host, port), WebHandler)
    print(f"WEB_Python disponible en http://{host}:{port} (API: {API_URL})")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor web detenido.")
    finally:
        server.server_close()
