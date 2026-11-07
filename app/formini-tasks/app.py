"""Formini Tasks — API de gestion de tâches.

Application fil rouge de la formation DevOps Formini.
Volontairement simple : l'objet du cours est la chaîne d'outils autour.

Variables d'environnement :
  DATABASE_URL   chaîne SQLAlchemy (défaut : sqlite:///tasks.db)
  APP_VERSION    version affichée par /health (défaut : dev)
  PORT           port d'écoute en mode développement (défaut : 5000)
"""
import os
import time

from flask import Flask, Response, jsonify, request, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from prometheus_client import (CONTENT_TYPE_LATEST, Counter, Gauge, Histogram,
                               generate_latest)
from sqlalchemy import text

db = SQLAlchemy()

# ---------------------------------------------------------------- métriques
REQUESTS = Counter(
    "http_requests_total", "Nombre de requêtes HTTP",
    ["method", "endpoint", "status"],
)
LATENCY = Histogram(
    "http_request_duration_seconds", "Durée des requêtes HTTP",
    ["endpoint"],
)
TASKS_OPEN = Gauge("tasks_open", "Nombre de tâches non terminées")


class Task(db.Model):
    __tablename__ = "tasks"
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    done = db.Column(db.Boolean, nullable=False, default=False)
    created_at = db.Column(db.DateTime, server_default=db.func.now())

    def to_dict(self):
        return {
            "id": self.id,
            "title": self.title,
            "done": self.done,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


def create_app(config=None):
    app = Flask(__name__, static_folder="static", static_url_path="/static")
    app.config["SQLALCHEMY_DATABASE_URI"] = os.environ.get(
        "DATABASE_URL", "sqlite:///tasks.db")
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    app.config["APP_VERSION"] = os.environ.get("APP_VERSION", "dev")
    if config:
        app.config.update(config)

    db.init_app(app)
    with app.app_context():
        db.create_all()

    # ------------------------------------------------------------ middleware
    @app.before_request
    def _start_timer():
        request._t0 = time.perf_counter()

    @app.after_request
    def _observe(response):
        endpoint = request.endpoint or "unknown"
        if endpoint not in ("metrics", "static"):
            REQUESTS.labels(request.method, endpoint, response.status_code).inc()
            LATENCY.labels(endpoint).observe(time.perf_counter() - request._t0)
        return response

    # ------------------------------------------------------------ pages
    @app.get("/")
    def index():
        return send_from_directory(app.static_folder, "index.html")

    @app.get("/health")
    def health():
        try:
            db.session.execute(text("SELECT 1"))
            db_status = "ok"
        except Exception as exc:  # pragma: no cover
            db_status = f"error: {exc}"
        status = 200 if db_status == "ok" else 503
        return jsonify(status="ok" if status == 200 else "degraded",
                       database=db_status,
                       version=app.config["APP_VERSION"]), status

    @app.get("/metrics")
    def metrics():
        TASKS_OPEN.set(Task.query.filter_by(done=False).count())
        return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

    # ------------------------------------------------------------ API
    @app.get("/api/tasks")
    def list_tasks():
        tasks = Task.query.order_by(Task.id).all()
        return jsonify([t.to_dict() for t in tasks])

    @app.post("/api/tasks")
    def create_task():
        payload = request.get_json(silent=True) or {}
        title = (payload.get("title") or "").strip()
        if not title:
            return jsonify(error="Le champ 'title' est obligatoire"), 400
        task = Task(title=title)
        db.session.add(task)
        db.session.commit()
        return jsonify(task.to_dict()), 201

    @app.get("/api/tasks/<int:task_id>")
    def get_task(task_id):
        task = db.session.get(Task, task_id)
        if task is None:
            return jsonify(error="Tâche introuvable"), 404
        return jsonify(task.to_dict())

    @app.put("/api/tasks/<int:task_id>")
    def update_task(task_id):
        task = db.session.get(Task, task_id)
        if task is None:
            return jsonify(error="Tâche introuvable"), 404
        payload = request.get_json(silent=True) or {}
        if "title" in payload:
            title = (payload["title"] or "").strip()
            if not title:
                return jsonify(error="Le titre ne peut pas être vide"), 400
            task.title = title
        if "done" in payload:
            task.done = bool(payload["done"])
        db.session.commit()
        return jsonify(task.to_dict())

    @app.delete("/api/tasks/<int:task_id>")
    def delete_task(task_id):
        task = db.session.get(Task, task_id)
        if task is None:
            return jsonify(error="Tâche introuvable"), 404
        db.session.delete(task)
        db.session.commit()
        return "", 204

    return app


if __name__ == "__main__":  # pragma: no cover
    create_app().run(host="0.0.0.0", port=int(os.environ.get("PORT", 5000)))
