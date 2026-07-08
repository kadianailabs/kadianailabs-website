"""
Backend test suite. The BUILD pipeline runs these before producing an image,
so a broken service never gets shipped. This is the "CI" safety net.
"""
import os
import sys

# Make app.py importable when pytest runs from the repo root or src/Python.
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import app  # noqa: E402


def _client():
    return app.test_client()


def test_health():
    res = _client().get("/health")
    assert res.status_code == 200
    body = res.get_json()
    assert body["status"] == "ok"
    assert body["service"] == "backend"


def test_status():
    res = _client().get("/api/status")
    assert res.status_code == 200
    assert res.get_json()["service"] == "kadianai-backend"


def test_contact_valid():
    res = _client().post(
        "/api/contact",
        json={"name": "Ada", "email": "ada@example.com", "message": "hi"},
    )
    assert res.status_code == 201
    assert res.get_json()["ok"] is True


def test_contact_invalid_email():
    res = _client().post(
        "/api/contact",
        json={"name": "Ada", "email": "not-an-email", "message": "hi"},
    )
    assert res.status_code == 400
    assert "email" in res.get_json()["errors"]
