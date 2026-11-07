# Formini Tasks — image de production
# Ordre des couches : du plus stable (base, dépendances) au plus volatil (code).
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# 1. dépendances : cette couche n'est reconstruite que si requirements.txt change
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 2. code applicatif (voir .dockerignore pour ce qui est exclu)
COPY app.py .
COPY static/ static/

# 3. utilisateur non privilégié
RUN useradd --create-home --uid 1000 --shell /usr/sbin/nologin app \
 && chown -R app:app /app
USER app

EXPOSE 5000

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:5000/health', timeout=2).status == 200 else 1)"

# forme exec : gunicorn est PID 1 et reçoit SIGTERM directement
CMD ["gunicorn", "-b", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "app:create_app()"]
