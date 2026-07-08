"""
KadianAI LABS — Python backend microservice.

An independent Flask service (no coupling to the Node frontend). It exposes a
small JSON API and its own health check, is versioned via APP_VERSION, and runs
under gunicorn in the container. Deployed as its own artifact/image.
"""
import os
import re
import socket

from flask import Flask, jsonify, request

app = Flask(__name__)

# APP_VERSION is injected at build time (Dockerfile ARG / Azure build number).
APP_VERSION = os.environ.get("APP_VERSION", "dev")

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


@app.get("/health")
def health():
    """Health check endpoint. Load balancers / deploy scripts ping this."""
    return jsonify(status="ok", service="backend", version=APP_VERSION)


@app.get("/api/status")
def status():
    """Basic service metadata."""
    return jsonify(
        service="kadianai-backend",
        version=APP_VERSION,
        hostname=socket.gethostname(),
    )


@app.post("/api/contact")
def contact():
    """
    Accept a contact/lead submission. Validates input and echoes a receipt.
    In a real system this would enqueue/store the message; kept side-effect-free
    here so it's safe to run anywhere.
    """
    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()
    email = (data.get("email") or "").strip()
    message = (data.get("message") or "").strip()

    errors = {}
    if not name:
        errors["name"] = "required"
    if not _EMAIL_RE.match(email):
        errors["email"] = "must be a valid email"
    if not message:
        errors["message"] = "required"

    if errors:
        return jsonify(ok=False, errors=errors), 400

    return jsonify(ok=True, received={"name": name, "email": email}), 201


if __name__ == "__main__":
    # 0.0.0.0 so it is reachable from outside the container.
    app.run(host="0.0.0.0", port=8000)
