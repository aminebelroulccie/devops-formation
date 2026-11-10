# Day 2 — Lab: Containerisation with Docker

_English version · la version française est dans [`README.md`](README.md)_

**Goal for the day:** run Formini Tasks and its PostgreSQL database in containers, then
publish the image to your team's Gitea container registry.

| Part | Slot          | Mode        | Expected outcome                                      |
|------|---------------|-------------|-------------------------------------------------------|
| 1    | 10:45 – 12:00 | Guided      | A `Dockerfile` that builds and starts the application |
| 2    | 14:00 – 15:30 | Self-paced  | `compose.yaml` with web + db, image published in Gitea |

## Prerequisites

- Your Ubuntu 24.04 VM reachable over SSH (Day 1 lab).
- Docker installed by `setup/install-vm.sh`. Check:

```bash
docker version          # Client and Server must both answer
docker compose version
id | grep docker        # your user is in the docker group
```

  If `docker` answers `permission denied`: `sudo usermod -aG docker $USER`, then open
  a **new** SSH session.
- Your clone of the team repository, up to date:

```bash
cd ~/formini-tasks && git switch main && git pull
```

- Gitea: <http://gitea.formini.local:3000>, organisation `equipe-a` (replace with your own).

---

## Part 1 — Guided lab: first container, first Dockerfile

### 1.1 First steps with a container

```bash
docker run -d --name web -p 8080:80 nginx:1.27-alpine
docker ps
```

Expected output: one line with `web`, status `Up`, ports `0.0.0.0:8080->80/tcp`.

```bash
curl -s localhost:8080 | head -5        # the nginx welcome page
docker logs web                          # the log lines from the curl request
docker exec -it web sh                   # a shell inside the container
  # inside the container:
  ps -ef                                 # nginx is PID 1
  cat /etc/nginx/conf.d/default.conf
  exit
docker stop web
docker ps -a                             # the container still exists, status Exited
docker rm web
docker ps -a                             # nothing left
```

Questions to ask yourself: what is the difference between `docker stop` and `docker rm`?
Why does `ps -ef` on the VM also show the nginx process?

### 1.2 Run the application without Docker (for comparison)

```bash
cd ~/formini-tasks
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
pytest -q                                # 7 tests pass
python app.py &                          # http://<vm-ip>:5000
curl -s localhost:5000/health
kill %1 ; deactivate
```

Everything you just did by hand (installing Python, the dependencies, starting the app)
is now going to be described in a file.

### 1.3 Write the Dockerfile

Create a branch and the `Dockerfile` at the root of the repository:

```bash
git switch -c feature/docker
```

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
EXPOSE 5000
CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:create_app()"]
```

> This Dockerfile is deliberately simple. You will improve it in Part 2.

### 1.4 Build and run

```bash
docker build -t formini-tasks:0.1 .
docker images formini-tasks
docker run -d --name tasks -p 5000:5000 formini-tasks:0.1
docker logs tasks                        # gunicorn: "Listening at: http://0.0.0.0:5000"
curl -s localhost:5000/health
```

Expected output:

```json
{"database":"ok","status":"ok","version":"dev"}
```

Open `http://<your-vm-ip>:5000` in the browser on the Formini workstation: add two tasks.

### 1.5 Inspect the image

```bash
docker history formini-tasks:0.1         # one line per instruction, with its size
docker exec tasks whoami                 # root (to be fixed this afternoon)
docker exec tasks ls -la /app            # .venv? .git? tasks.db?
docker image inspect formini-tasks:0.1 --format '{{.Size}}' | numfmt --to=iec
```

Write down: the image size, the user, and the files that have no business being in the
image.

### 1.6 Push the branch

```bash
git add Dockerfile
git commit -m "feat(docker): add a first Dockerfile"
git push -u origin feature/docker
```

Open a pull request in Gitea. **Do not merge it yet**: you are going to improve it.

### Part 1 bonus

- Start a second container from the same image on port 5001.
- Limit memory: `docker run --rm -p 5002:5000 --memory 128m formini-tasks:0.1`
  then `docker stats`.

---

## Part 2 — Challenge: the application and its database, published

Split the work across the team: one person on the Dockerfile, one on Compose, one on the
registry and the PR. Everything happens on the `feature/docker` branch.

### 2.1 Improve the Dockerfile

Evolve the Dockerfile so that it meets, in this order:

1. **Cache**: `COPY requirements.txt` and `pip install` **before** the `COPY` of the code.
2. **Clean context**: a `.dockerignore` that excludes `.git`, `.venv`, `__pycache__`,
   `*.db`, `.env`, `tests/`, `ateliers/`.
3. **Non-root user**: `useradd` + `USER app`.
4. **`HEALTHCHECK`** that calls `/health`.
5. **`ENV PYTHONUNBUFFERED=1`** for immediate log output.

Check:

```bash
docker build -t formini-tasks:0.2.0 .
docker image inspect formini-tasks:0.2.0 --format '{{.Size}}' | numfmt --to=iec   # < 200M
docker run --rm formini-tasks:0.2.0 whoami                                          # app
docker run --rm formini-tasks:0.2.0 ls -la /app                                     # no .venv or .git
```

Time it: change a comment in `app.py`, run `docker build` again. Only the layers after
`COPY app.py` should be rebuilt.

### 2.2 Write compose.yaml

Create `compose.yaml` with two services:

| Service | Image / build        | Mandatory points                                                           |
|---------|----------------------|----------------------------------------------------------------------------|
| `web`   | `build: .`           | port `8000:5000`, `DATABASE_URL` pointing to `db`, `depends_on` with `service_healthy` |
| `db`    | `postgres:16-alpine` | `POSTGRES_*` from `.env`, named volume `pgdata`, `healthcheck` with `pg_isready` |

Create `.env.example` (versioned) and `.env` (ignored by Git):

```bash
cp .env.example .env     # then change the password
```

```bash
docker compose up -d --build
docker compose ps        # both services must show (healthy)
docker compose logs web  # no connection errors
curl -s localhost:8000/health
```

Expected output: `"database":"ok"`.

### 2.3 Prove persistence

```bash
curl -s -X POST localhost:8000/api/tasks -H 'Content-Type: application/json' \
  -d '{"title":"Publish the image"}'
docker compose down
docker compose up -d
curl -s localhost:8000/api/tasks         # the task is still there
```

Then, to understand what happens: `docker compose down -v`, `up -d`, the list is empty.

### 2.4 Publish to the Gitea registry

1. In Gitea: avatar → **Settings** → **Applications** → *Generate Token*, name
   `docker`, **package** scope with read/write. Copy the token.
2. On the VM:

```bash
docker login gitea.formini.local:3000 -u <your-login>      # password = the token
SHA=$(git rev-parse --short HEAD)
docker tag formini-tasks:0.2.0 gitea.formini.local:3000/equipe-a/formini-tasks:0.2.0
docker tag formini-tasks:0.2.0 gitea.formini.local:3000/equipe-a/formini-tasks:$SHA
docker push gitea.formini.local:3000/equipe-a/formini-tasks:0.2.0
docker push gitea.formini.local:3000/equipe-a/formini-tasks:$SHA
```

   The script `solution/push-registry.sh` automates these lines.
3. Check in Gitea: organisation `equipe-a` → **Packages** tab → `formini-tasks`
   → two tags.

### 2.5 Merge and verify on a teammate's VM

```bash
git add Dockerfile .dockerignore compose.yaml .env.example
git commit -m "feat(docker): hardened image, web+db compose, registry publishing"
git push
```

A teammate reviews the PR, then merges it. **Another** team member, on their own VM,
runs the image from the registry without building it:

```bash
docker run -d -p 9000:5000 gitea.formini.local:3000/equipe-a/formini-tasks:0.2.0
curl -s localhost:9000/health
```

### Success criteria

- [ ] `docker compose ps`: `web` and `db` in `healthy` state.
- [ ] Image < 200 MB; `whoami` inside the container ≠ `root`.
- [ ] `.env` absent from Git, `.env.example` present.
- [ ] Image visible in Gitea → Packages with two tags (`0.2.0` and the SHA).
- [ ] PR `feature/docker` merged after review; branch deleted.

### Part 2 bonus

- **Multi-stage**: write a `Dockerfile.multistage` variant (see slide) and compare
  `docker images`.
- **Other languages**: four commented Dockerfiles (Go, Python/FastAPI, React, Rust) in
  [`exemples/`](exemples/README.en.md). Pick the one closest to your context, build it and do
  its exercise.
- **Full stacks**: one `compose.yaml` per language in `exemples/stack-*/` (React front end,
  Go, Python, Node or Rust API, PostgreSQL, Redis), for example
  [`exemples/stack-go/`](exemples/stack-go/README.en.md). Exercises: scaling the API, cache
  outage, publishing the images.
- **Vulnerability scanning**: `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.58.0 image formini-tasks:0.2.0`
  (or `docker scout quickview formini-tasks:0.2.0` if available). How many critical
  CVEs? How many with `python:3.12` instead of `-slim`?
- Add an `adminer` service (image `adminer:4`) on port 8081 to browse the database.

---

## Troubleshooting

| Message                                                   | Cause                                                | Fix                                                                 |
|-----------------------------------------------------------|------------------------------------------------------|---------------------------------------------------------------------|
| `permission denied while trying to connect to the Docker daemon` | user not in the `docker` group                 | `sudo usermod -aG docker $USER`, new session                        |
| `connection refused` / `could not connect to server` in the web logs | `localhost` in `DATABASE_URL`, or db not ready yet | host `db`, `depends_on: condition: service_healthy`          |
| `password authentication failed for user "formini"`       | `.env` changed after the volume was first created    | `docker compose down -v` then `up -d` (data is lost)                |
| `Bind for 0.0.0.0:8000 failed: port is already allocated` | another container is using the port                  | `docker ps`, `docker rm -f <name>` or change the host port          |
| `http: server gave HTTP response to HTTPS client`         | HTTP registry not declared                           | check that `/etc/docker/daemon.json` contains `insecure-registries`, `sudo systemctl restart docker` |
| `unauthorized: authentication required` on push           | no `docker login`, or token without the package scope | regenerate the token, `docker login` again                         |
| `denied: ... not allowed to push`                         | you are not a member of the organisation             | ask the trainer to add you to `equipe-a`                            |
| `unhealthy` state                                         | the healthcheck is failing                           | `docker inspect --format '{{json .State.Health}}' <container>`      |
| 900 MB image                                              | `.venv` / `.git` were copied                         | `.dockerignore`, then `docker history`                              |
| `COPY failed: file not found`                             | `docker build` run from the wrong directory          | go to the repository root; the trailing `.` is the build context    |

Reference solution: `ateliers/jour2-docker/solution/`.
