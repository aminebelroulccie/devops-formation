# Formini Tasks

Application fil rouge de la formation DevOps Formini : une petite API de gestion
de tâches en Python (Flask) avec sa base de données (SQLite en local, PostgreSQL
en conteneur et sur Kubernetes).

Ce dépôt est l'**état de départ** (jour 1). Chaque journée y ajoute une pièce :

| Jour | Ajout                                   | Dossier de solution                         |
|------|-----------------------------------------|---------------------------------------------|
| 2    | `Dockerfile`, `compose.yaml`            | `ateliers/jour2-docker/solution/`           |
| 3    | `.gitea/workflows/ci.yml`               | `ateliers/jour3-cicd/solution/`             |
| 4    | `k8s/`, `terraform/`, `ansible/`        | `ateliers/jour4-iac-kubernetes/solution/`   |
| 5    | `monitoring/`                           | `ateliers/jour5-supervision-projet/solution/` |

## Lancer en local

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
python app.py              # http://localhost:5000
pytest -q                  # tests
```

## Points d'entrée

| Méthode | Chemin             | Rôle                                   |
|---------|--------------------|----------------------------------------|
| GET     | `/`                | Interface web minimale                 |
| GET     | `/health`          | État de l'application et de la base    |
| GET     | `/metrics`         | Métriques Prometheus                   |
| GET     | `/api/tasks`       | Liste des tâches                       |
| POST    | `/api/tasks`       | Crée une tâche `{"title": "..."}`      |
| GET     | `/api/tasks/<id>`  | Détail d'une tâche                     |
| PUT     | `/api/tasks/<id>`  | Modifie `title` et/ou `done`           |
| DELETE  | `/api/tasks/<id>`  | Supprime une tâche                     |

## Configuration

| Variable       | Défaut               | Description                          |
|----------------|----------------------|--------------------------------------|
| `DATABASE_URL` | `sqlite:///tasks.db` | Chaîne de connexion SQLAlchemy       |
| `APP_VERSION`  | `dev`                | Version affichée par `/health`       |
| `PORT`         | `5000`               | Port en mode développement           |

Exemple PostgreSQL : `postgresql://formini:formini@db:5432/tasks`
