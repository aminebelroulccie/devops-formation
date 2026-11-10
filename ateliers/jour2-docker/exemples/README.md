# Jour 2 — Quatre Dockerfiles, quatre langages

_English version: [`README.en.md`](README.en.md)_

Le fil rouge Formini Tasks est en Python. Ces quatre exemples montrent que les **mêmes
principes** (ordre des couches, multi-stage, utilisateur non root, image de base minimale) se
déclinent différemment selon le langage. Chaque dossier contient une application « Formini
Hello » complète, son `Dockerfile` commenté, un `.dockerignore` et un README avec un exercice.

| Dossier | Stack | Pattern illustré | Image finale | Taille ≈ |
|---------|-------|------------------|--------------|----------|
| [`go/`](go/) | Go 1.23, bibliothèque standard | binaire statique → image **distroless** sans shell | `distroless/static` | 8 Mo |
| [`python/`](python/) | FastAPI + uvicorn | venv construit puis **copié** entre étapes, `HEALTHCHECK` | `python:3.12-slim` | 150 Mo |
| [`react/`](react/) | React 18 + Vite | build Node jeté, fichiers statiques servis par **nginx non privilégié** | `nginx-unprivileged:alpine` | 50 Mo |
| [`rust/`](rust/) | Rust 1.83 + tiny_http | **cache des dépendances compilées** (main.rs factice) | `debian:bookworm-slim` | 25 Mo |

Toutes les applications exposent `GET /` (JSON ou page) et `GET /health`, sur le port 8080
(8000 pour Python).

**Les piles Compose :** chaque langage a aussi son `compose.yaml` complet et autonome, avec un front
React servi par nginx, l'API dans ce langage, PostgreSQL (initialisé par `db/init.sql`) et Redis.
Même structure, même contrat d'API, seul le dossier `api/` change.

| Pile | API | Dossier |
|------|-----|---------|
| Go | Go 1.23, pgx, go-redis | [`stack-go/`](stack-go/README.md) |
| Python | FastAPI, psycopg 3, redis-py | [`stack-python/`](stack-python/README.md) |
| React + Node | Express, pg, ioredis | [`stack-react-node/`](stack-react-node/README.md) |
| Rust | tiny_http, postgres, redis | [`stack-rust/`](stack-rust/README.md) |

À montrer après le `compose.yaml` du fil rouge : `cp .env.example .env && docker compose up -d --build`,
puis <http://localhost:8080>.

## Utilisation en formation

- **Démonstration formateur (≈ 10 min)** : `bash build-all.sh` sur la VM pendant la pause
  (Rust est long la première fois), puis commenter le tableau des tailles. Message clé : la
  taille et la surface d'attaque dépendent de ce qu'on met dans l'image finale, pas du langage.
- **Bonus participants** : choisir l'exemple le plus proche de son contexte professionnel,
  le construire, le lancer, puis faire l'exercice du README.
- **Pour aller plus loin** : publier l'une des images dans le registre Gitea
  (`gitea.formini.local:3000/equipe-a/formini-hello-go:0.1.0`) avec la méthode de la partie 2.4.

## Ce qui est commun aux quatre

1. Les **dépendances avant le code** : `go.mod`, `requirements.txt`, `package-lock.json`,
   `Cargo.toml` sont copiés et installés dans une couche séparée, mise en cache.
2. **Multi-stage** : l'outillage de build reste dans la première étape ; l'image finale ne
   reçoit que le résultat (`COPY --from=build`).
3. **Utilisateur non root** : `nonroot` (distroless), `useradd … app`, utilisateur 101 (nginx).
4. **Forme exec** pour `CMD` / `ENTRYPOINT` : le processus est PID 1 et reçoit `SIGTERM`.
5. `.dockerignore` : `.git`, dossiers de build, documentation.

## Prérequis sur la VM

Docker uniquement. Aucun SDK (Go, Python, Node, Rust) n'est nécessaire sur la machine : tout
est installé dans l'étape de build. Première construction avec accès internet (téléchargement
des images de base et des dépendances) ; comptez ≈ 1 Go au total.
