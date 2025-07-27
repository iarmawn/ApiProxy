# proxy.py

#!/usr/bin/env python3
import os
import sys
import time
import uuid
import logging
from flask import Flask, request, Response, jsonify
import requests
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# ─── Logging Filter ─────────────────────────────────────────────────────────────
class RequestIDFilter(logging.Filter):
    def filter(self, record):
        try:
            record.request_id = request.request_id
        except Exception:
            record.request_id = "-"
        return True

# ─── Basic Logging Setup ────────────────────────────────────────────────────────
logging.basicConfig(
    stream=sys.stdout,
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(request_id)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

# Attach filter to root, werkzeug, and our logger
root_logger = logging.getLogger()
root_logger.addFilter(RequestIDFilter())
logging.getLogger("werkzeug").addFilter(RequestIDFilter())
logging.getLogger("urllib3.connectionpool").setLevel(logging.WARNING)

logger = logging.getLogger("openai-proxy")
logger.addFilter(RequestIDFilter())

# ─── Configuration ──────────────────────────────────────────────────────────────
PORT            = int(os.getenv("PORT", 5050))
DEBUG           = os.getenv("DEBUG", "false").lower() in ("1", "true", "t")
API_BASE_URL    = os.getenv("API_BASE_URL", "https://api.openai.com/v1")
REQUEST_TIMEOUT = float(os.getenv("REQUEST_TIMEOUT", 18000))
MAX_CONTENT_LENGTH = int(os.getenv("MAX_CONTENT_LENGTH", 16 * 1024 * 1024))  # 16MB default
WORKERS         = int(os.getenv("WORKERS", 4))

# ─── Flask App ─────────────────────────────────────────────────────────────────
app = Flask(__name__)
app.config['MAX_CONTENT_LENGTH'] = MAX_CONTENT_LENGTH

# Security headers
@app.after_request
def add_security_headers(response):
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
    return response

@app.before_request
def start_request():
    request.request_id = uuid.uuid4().hex[:8]
    request.start_time = time.time()

@app.after_request
def log_request(response):
    latency_ms = (time.time() - request.start_time) * 1000
    logger.info(f"{request.method} {request.full_path} → {response.status_code} in {latency_ms:.1f}ms")
    return response

# ─── Error Handlers ────────────────────────────────────────────────────────────
@app.errorhandler(413)
def too_large(e):
    return jsonify(error="Request too large"), 413

@app.errorhandler(404)
def not_found(e):
    return jsonify(error="Not found"), 404

@app.errorhandler(500)
def internal_error(e):
    return jsonify(error="Internal server error"), 500

# ─── Health Check ──────────────────────────────────────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    return jsonify(status="ok", timestamp=time.time()), 200

# ─── Proxy Endpoint ─────────────────────────────────────────────────────────────
@app.route("/<path:path>", methods=[
    "GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD"
])
def proxy(path):
    url = f"{API_BASE_URL}/{path}"

    # Copy headers, drop Host and Accept-Encoding
    headers = {
        k: v
        for k, v in request.headers.items()
        if k.lower() not in ("host", "accept-encoding")
    }
    headers["Accept-Encoding"] = "identity"

    try:
        upstream = requests.request(
            method=request.method,
            url=url,
            params=request.args,
            headers=headers,
            data=request.get_data(),
            cookies=request.cookies,
            allow_redirects=False,
            stream=True,
            timeout=REQUEST_TIMEOUT
        )
    except requests.Timeout:
        logger.error("Upstream request timed out")
        return jsonify(error="Upstream timeout"), 502
    except requests.RequestException as e:
        logger.error(f"Upstream request failed: {e!r}")
        return jsonify(error="Bad gateway"), 502

    excluded = {
        "connection", "keep-alive", "proxy-authenticate",
        "proxy-authorization", "te", "trailers",
        "transfer-encoding", "upgrade", "content-encoding"
    }
    response_headers = [
        (name, value)
        for name, value in upstream.raw.headers.items()
        if name.lower() not in excluded
    ]

    return Response(
        upstream.raw,
        status=upstream.status_code,
        headers=response_headers
    )

# ─── Entrypoint ────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    logger.info(f"Starting proxy on 0.0.0.0:{PORT}")
    if DEBUG:
        app.run(host="0.0.0.0", port=PORT, debug=DEBUG)
    else:
        # Production mode - use gunicorn
        from gunicorn.app.base import BaseApplication
        
        class StandaloneApplication(BaseApplication):
            def __init__(self, app, options=None):
                self.options = options or {}
                self.application = app
                super().__init__()

            def load_config(self):
                for key, value in self.options.items():
                    self.cfg.set(key.lower(), value)

            def load(self):
                return self.application

        options = {
            'bind': f'0.0.0.0:{PORT}',
            'workers': WORKERS,
            'worker_class': 'sync',
            'timeout': 120,
            'keepalive': 2,
            'max_requests': 1000,
            'max_requests_jitter': 50,
        }
        
        StandaloneApplication(app, options).run()
