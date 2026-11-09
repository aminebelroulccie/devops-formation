# Formini Hello (Python / FastAPI) — multi-stage avec un environnement virtuel.
# L'étape de build installe les dépendances (compilateurs, caches pip inclus) ;
# l'image finale ne récupère que le dossier /venv. Taille attendue : ~ 150 Mo.

# ---- étape 1 : build -------------------------------------------------------
FROM python:3.12-slim AS build
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
WORKDIR /src

# 1. dépendances dans un venv isolé (couche en cache tant que requirements.txt ne change pas)
RUN python -m venv /venv
COPY requirements.txt .
RUN /venv/bin/pip install -r requirements.txt

# ---- étape 2 : image finale -------------------------------------------------
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PATH="/venv/bin:$PATH"
WORKDIR /app

# le venv complet, et rien d'autre, vient de l'étape de build
COPY --from=build /venv /venv
COPY app.py .

# utilisateur non privilégié
RUN useradd --create-home --uid 1000 --shell /usr/sbin/nologin app \
 && chown -R app:app /app
USER app

EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).status == 200 else 1)"

# forme exec : uvicorn est PID 1 et reçoit SIGTERM
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
