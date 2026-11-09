"""Formini Hello — API minimale FastAPI.

Routes : GET /  → JSON de bienvenue, GET /health → {"status": "ok"}.
Lancement local : uvicorn app:app --reload --port 8000
"""
import socket

from fastapi import FastAPI

app = FastAPI(title="Formini Hello (Python)", version="0.1.0")


@app.get("/")
def index():
    return {
        "service": "formini-hello-python",
        "message": "Bonjour Formini",
        "hostname": socket.gethostname(),
    }


@app.get("/health")
def health():
    return {"status": "ok"}
