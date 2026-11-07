# Formini Tasks

_English version · la version française est dans [`README.md`](README.md)_

Running-example application of the Formini DevOps training: a small task-management
API in Python (Flask) with its database (SQLite locally, PostgreSQL in a container
and on Kubernetes).

This repository is the **starting point** (day 1). Each day adds a piece to it:

| Day  | Addition                                | Solution folder                             |
|------|-----------------------------------------|---------------------------------------------|
| 2    | `Dockerfile`, `compose.yaml`            | `ateliers/jour2-docker/solution/`           |
| 3    | `.gitea/workflows/ci.yml`               | `ateliers/jour3-cicd/solution/`             |
| 4    | `k8s/`, `terraform/`, `ansible/`        | `ateliers/jour4-iac-kubernetes/solution/`   |
| 5    | `monitoring/`                           | `ateliers/jour5-supervision-projet/solution/` |

## Run locally

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
python app.py              # http://localhost:5000
pytest -q                  # tests
```

## Endpoints

| Method  | Path               | Purpose                                |
|---------|--------------------|----------------------------------------|
| GET     | `/`                | Minimal web interface                  |
| GET     | `/health`          | Application and database status        |
| GET     | `/metrics`         | Prometheus metrics                     |
| GET     | `/api/tasks`       | List tasks                             |
| POST    | `/api/tasks`       | Create a task `{"title": "..."}`       |
| GET     | `/api/tasks/<id>`  | Task details                           |
| PUT     | `/api/tasks/<id>`  | Update `title` and/or `done`           |
| DELETE  | `/api/tasks/<id>`  | Delete a task                          |

## Configuration

| Variable       | Default              | Description                          |
|----------------|----------------------|--------------------------------------|
| `DATABASE_URL` | `sqlite:///tasks.db` | SQLAlchemy connection string         |
| `APP_VERSION`  | `dev`                | Version reported by `/health`        |
| `PORT`         | `5000`               | Port in development mode             |

PostgreSQL example: `postgresql://formini:formini@db:5432/tasks`
