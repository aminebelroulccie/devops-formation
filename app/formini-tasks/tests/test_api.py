import pytest

from app import create_app, db


@pytest.fixture()
def client():
    app = create_app({"SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:",
                      "TESTING": True})
    with app.app_context():
        db.drop_all()
        db.create_all()
        yield app.test_client()


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.get_json()["status"] == "ok"


def test_liste_vide(client):
    r = client.get("/api/tasks")
    assert r.status_code == 200
    assert r.get_json() == []


def test_creer_une_tache(client):
    r = client.post("/api/tasks", json={"title": "Écrire le Dockerfile"})
    assert r.status_code == 201
    body = r.get_json()
    assert body["title"] == "Écrire le Dockerfile"
    assert body["done"] is False


def test_titre_obligatoire(client):
    r = client.post("/api/tasks", json={"title": "   "})
    assert r.status_code == 400


def test_terminer_une_tache(client):
    task_id = client.post("/api/tasks", json={"title": "Déployer"}).get_json()["id"]
    r = client.put(f"/api/tasks/{task_id}", json={"done": True})
    assert r.status_code == 200
    assert r.get_json()["done"] is True


def test_supprimer_une_tache(client):
    task_id = client.post("/api/tasks", json={"title": "Superviser"}).get_json()["id"]
    assert client.delete(f"/api/tasks/{task_id}").status_code == 204
    assert client.get(f"/api/tasks/{task_id}").status_code == 404


def test_metrics_exposees(client):
    client.get("/api/tasks")
    r = client.get("/metrics")
    assert r.status_code == 200
    assert b"http_requests_total" in r.data
    assert b"tasks_open" in r.data
