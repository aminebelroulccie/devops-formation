"""Tests unitaires sans base ni cache : routes qui n'y touchent pas."""
import os

# l'application lit DATABASE_URL à l'import ; aucune connexion n'est ouverte avant la 1re requête
os.environ.setdefault("DATABASE_URL", "postgresql://x:x@localhost:5432/x")

from fastapi.testclient import TestClient  # noqa: E402

from app import app  # noqa: E402

client = TestClient(app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.text == "ok"


def test_task_title_blank_is_rejected():
    r = client.post("/api/tasks", json={"title": "   "})
    assert r.status_code == 400


def test_task_title_empty_fails_validation():
    r = client.post("/api/tasks", json={"title": ""})
    assert r.status_code == 422
