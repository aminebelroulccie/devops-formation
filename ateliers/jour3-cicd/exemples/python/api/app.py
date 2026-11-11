"""API Formini (Python / FastAPI) — même contrat que les API Go, Node et Rust.

  GET  /health      → "ok"
  GET  /api/info    → identité du service + état de PostgreSQL et Redis
  GET  /api/tasks   → liste des tâches (table partagée)
  POST /api/tasks   → {"title": "..."} crée une tâche
  GET  /api/hits    → incrémente et renvoie le compteur Redis de ce service
"""
import os
import platform
import socket

import psycopg
import redis
from fastapi import FastAPI, HTTPException
from fastapi.responses import PlainTextResponse
from psycopg.rows import dict_row
from pydantic import BaseModel, Field

SERVICE = "api-python"
DATABASE_URL = os.environ["DATABASE_URL"]
REDIS_URL = os.environ.get("REDIS_URL", "redis://cache:6379/0")

app = FastAPI(title="API Formini (Python)", version="0.1.0")
cache = redis.Redis.from_url(REDIS_URL, socket_connect_timeout=2, decode_responses=True)


def db():
    # une connexion par requête : simple et suffisant pour la démonstration
    return psycopg.connect(DATABASE_URL, row_factory=dict_row, connect_timeout=2)


class TaskIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)


@app.get("/health", response_class=PlainTextResponse)
def health():
    return "ok"


@app.get("/api/info")
def info():
    pg = rd = "ok"
    try:
        with db() as conn:
            conn.execute("SELECT 1")
    except Exception as exc:  # noqa: BLE001 — on veut afficher l'erreur, pas la cacher
        pg = f"erreur : {exc}"
    try:
        cache.ping()
    except Exception as exc:  # noqa: BLE001
        rd = f"erreur : {exc}"
    return {
        "service": SERVICE,
        "language": f"Python {platform.python_version()}",
        "hostname": socket.gethostname(),
        "postgres": pg,
        "redis": rd,
    }


@app.get("/api/tasks")
def list_tasks():
    with db() as conn:
        rows = conn.execute(
            "SELECT id, title, done, created_by, created_at FROM tasks ORDER BY id DESC LIMIT 50"
        ).fetchall()
    return rows


@app.post("/api/tasks", status_code=201)
def create_task(task: TaskIn):
    title = task.title.strip()
    if not title:
        raise HTTPException(status_code=400, detail="title requis")
    with db() as conn:
        row = conn.execute(
            "INSERT INTO tasks (title, created_by) VALUES (%s, %s) "
            "RETURNING id, title, done, created_by, created_at",
            (title, SERVICE),
        ).fetchone()
    return row


@app.get("/api/hits")
def hits():
    return {"service": SERVICE, "hits": cache.incr(f"hits:{SERVICE}")}
