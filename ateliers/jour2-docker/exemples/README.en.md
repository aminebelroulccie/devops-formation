# Day 2 — Four Dockerfiles, four languages

_English version · la version française est dans [`README.md`](README.md)_

The Formini Tasks running example is in Python. These four examples show that the **same
principles** (layer order, multi-stage, non-root user, minimal base image) play out differently
depending on the language. Each folder holds a complete "Formini Hello" application, its
commented `Dockerfile`, a `.dockerignore` and a README with an exercise.

| Folder | Stack | Pattern illustrated | Final image | Size ≈ |
|--------|-------|---------------------|-------------|--------|
| [`go/`](go/) | Go 1.23, standard library | static binary → **distroless** image with no shell | `distroless/static` | 8 MB |
| [`python/`](python/) | FastAPI + uvicorn | venv built then **copied** between stages, `HEALTHCHECK` | `python:3.12-slim` | 150 MB |
| [`react/`](react/) | React 18 + Vite | Node build discarded, static files served by **unprivileged nginx** | `nginx-unprivileged:alpine` | 50 MB |
| [`rust/`](rust/) | Rust 1.83 + tiny_http | **caching compiled dependencies** (dummy main.rs) | `debian:bookworm-slim` | 25 MB |

Every application exposes `GET /` (JSON or a page) and `GET /health`, on port 8080
(8000 for Python).

**The Compose stacks:** each language also has its own complete, self-contained `compose.yaml`, with a
React front end served by nginx, the API in that language, PostgreSQL (initialised by `db/init.sql`)
and Redis. Same structure, same API contract, only the `api/` folder differs.

| Stack | API | Folder |
|-------|-----|--------|
| Go | Go 1.23, pgx, go-redis | [`stack-go/`](stack-go/README.en.md) |
| Python | FastAPI, psycopg 3, redis-py | [`stack-python/`](stack-python/README.en.md) |
| React + Node | Express, pg, ioredis | [`stack-react-node/`](stack-react-node/README.en.md) |
| Rust | tiny_http, postgres, redis | [`stack-rust/`](stack-rust/README.en.md) |

Show it after the running example's `compose.yaml`: `cp .env.example .env && docker compose up -d --build`,
then <http://localhost:8080>. The Gitea Actions pipelines for these four stacks are in Day 3:
[`ateliers/jour3-cicd/exemples/`](../../jour3-cicd/exemples/README.en.md).

## How to use them in the course

- **Trainer demo (≈ 10 min)**: run `bash build-all.sh` on the VM during the break (Rust is slow
  the first time), then walk through the size table. Key message: size and attack surface
  depend on what you put in the final image, not on the language.
- **Participant bonus**: pick the example closest to your own work context, build it, run it,
  then do the exercise in its README.
- **Going further**: publish one of the images to the Gitea registry
  (`gitea.formini.local:3000/equipe-a/formini-hello-go:0.1.0`) using the method from part 2.4.

## What the four have in common

1. **Dependencies before code**: `go.mod`, `requirements.txt`, `package-lock.json`,
   `Cargo.toml` are copied and installed in a separate, cached layer.
2. **Multi-stage**: build tooling stays in the first stage; the final image only receives the
   result (`COPY --from=build`).
3. **Non-root user**: `nonroot` (distroless), `useradd … app`, user 101 (nginx).
4. **Exec form** for `CMD` / `ENTRYPOINT`: the process is PID 1 and receives `SIGTERM`.
5. `.dockerignore`: `.git`, build folders, documentation.

## Requirements on the VM

Docker only. No SDK (Go, Python, Node, Rust) is needed on the machine: everything is installed in
the build stage. The first build needs internet access (base images and dependencies); expect
about 1 GB in total.
