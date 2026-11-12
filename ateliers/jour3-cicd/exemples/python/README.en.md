# Python stack — React front end, Python API, PostgreSQL, Redis

_English version · la version française est dans [`README.md`](README.md)_

A complete, self-contained `compose.yaml`: a **React** front end served by nginx, a **Python API**
(FastAPI, psycopg 3, redis-py), a **PostgreSQL** database initialised by an SQL script and a **Redis** cache.
The three other stacks ([`go/`](../go/), [`python/`](../python/),
[`react-node/`](../react-node/), [`rust/`](../rust/)) share exactly the
same structure and API contract: only the `api/` folder differs.

```
  browser ──► frontend (nginx :8080) ──/api/──► api (Python :8080) ──┬──► db    (postgres 16)
                                                                     └──► cache (redis 7)
```

## Start

```bash
cd ateliers/jour3-cicd/exemples/python
cp .env.example .env            # change both passwords (PostgreSQL, Redis)
docker compose up -d --build    # first time: 1 to 2 min
docker compose ps               # 4 services; db and cache "healthy"
```

Open <http://localhost:8080>. The API is also exposed on 8081 for `curl`:

```bash
curl -s localhost:8081/api/info
curl -s localhost:8081/api/tasks
curl -s -X POST localhost:8081/api/tasks -H 'Content-Type: application/json' -d '{"title":"via curl"}'
curl -s localhost:8081/api/hits
```

## The API contract

| Method | Route | Response |
|--------|-------|----------|
| GET | `/health` | `ok` (text), used by the HEALTHCHECK |
| GET | `/api/info` | `{service, language, hostname, postgres, redis}` |
| GET | `/api/tasks` | last 50 tasks |
| POST | `/api/tasks` | `{"title": "…"}` → 201 and the created task |
| GET | `/api/hits` | increments the Redis key `hits:api-python` and returns `{service, hits}` |

## What to observe

1. **Service discovery**: the API reaches the database by its name `db` and the cache by `cache`
   (`DATABASE_URL`, `REDIS_URL` in `compose.yaml`; Redis requires a password, `--requirepass`); nginx reaches the API by its name `api`
   (`frontend/nginx.conf`). No hard-coded IPs.
2. **Start-up order**: `depends_on … condition: service_healthy`. The API only starts once
   `pg_isready` and `redis-cli ping` pass. Comment those lines out and restart to see the
   difference (then `restart: unless-stopped` recovers).
3. **Database initialisation**: `db/init.sql` mounted into `docker-entrypoint-initdb.d`, run only
   when the volume is created. `docker compose down -v` to replay it.
4. **API image**: `docker images formini-python-api` ≈ 170 MB. Compare with the other stacks.
5. **Persistent data**: `down` then `up`, tasks and counter are still there; `down -v` wipes them.
6. **Front-end tests without starting anything**: `cd frontend && npm ci && npm test`. Four Vitest +
   Testing Library tests (`src/App.test.jsx`) against a mocked API: rendering, task creation, counter,
   network error. The Day 3 pipeline runs them before building the image.

## Exercises

- **Scaling.** Remove the `ports` block from the `api` service, then
  `docker compose up -d --scale api=3`. Refresh the page: the *Container* field changes, nginx
  spreads requests across the three replicas.
- **Controlled failure.** `docker compose stop cache`. What do `/api/info` and `/api/tasks`
  return? Then `docker compose start cache`.
- **A single exposed port.** Remove the `ports` of `api`. Does everything still work? Why is
  that the production configuration?
- **Publish.** Push the two images to the Gitea registry
  (`gitea.formini.local:3000/equipe-a/formini-python-api:0.1.0`), then replace `build:` with
  `image:` in a `compose.prod.yaml`.


## Continuous integration

This folder is a complete repository, ready to push to Gitea: the workflows are in
`.gitea/workflows/` (`ci.yml`: lint, tests, stack integration test, scan, publish;
`release.yml`: release on a `v*` tag). Setup, durations and exercises: [`../README.en.md`](../README.en.md).
The code is identical to `ateliers/jour2-docker/exemples/stack-python/`.

## Stop

```bash
docker compose down        # keeps the data
docker compose down -v     # also removes the volumes
```
