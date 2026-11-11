# API Formini (Python / FastAPI) — multi-stage avec venv, utilisateur non root (~ 170 Mo).
FROM python:3.12-slim AS build
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_NO_CACHE_DIR=1
RUN python -m venv /venv
COPY requirements.txt .
RUN /venv/bin/pip install -r requirements.txt

FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PATH="/venv/bin:$PATH"
WORKDIR /app
COPY --from=build /venv /venv
COPY app.py .
RUN useradd --create-home --uid 1000 --shell /usr/sbin/nologin app && chown -R app:app /app
USER app
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=2).status == 200 else 1)"
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
