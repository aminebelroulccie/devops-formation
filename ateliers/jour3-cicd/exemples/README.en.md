# Day 3 — Gitea Actions for the four stacks (Go, Python, Node, Rust)

_English version · la version française est dans [`README.md`](README.md)_

The Formini Tasks running example has its pipeline in Python. These four folders provide the
**same Gitea Actions workflows** for the Day 2 stacks
([`ateliers/jour2-docker/exemples/stack-*/`](../../jour2-docker/exemples/README.en.md)): React
front end + API in the language + PostgreSQL + Redis. Same pipeline structure; only the API lint
and test steps differ.

| Folder | Target stack | API-specific steps |
|--------|--------------|--------------------|
| [`go/`](go/.gitea/workflows/ci.yml) | `stack-go/` | `gofmt -l` (informational), `go vet`, `go test`, inside the `golang:1.23-alpine` container |
| [`python/`](python/.gitea/workflows/ci.yml) | `stack-python/` | venv, `flake8`, `pytest`, `pip-audit` (informational), with the VM's python3 |
| [`react-node/`](react-node/.gitea/workflows/ci.yml) | `stack-react-node/` | `npm ci`, `node --check`, `npm test` (node:test), `npm audit` (informational) |
| [`rust/`](rust/.gitea/workflows/ci.yml) | `stack-rust/` | `cargo fmt --check` (informational), `cargo clippy`, `cargo test`, inside the `rust:1.83-slim` container |

Each folder is a **complete repository, ready to push**: the stack code (identical to
`ateliers/jour2-docker/exemples/stack-*/`) plus the workflows.

```
go/                     (same for python/, react-node/, rust/)
├── .gitea/
│   ├── workflows/
│   │   ├── ci.yml          pull request and push on main: api → frontend → integration → publish
│   │   └── release.yml     v* tag: tests, images tagged with the version, scan, publication
│   └── compose.ci.yaml     override: no host port published during the integration test
├── api/                    the API in the language, with its unit tests
│   └── .gitea/workflows/   ci.yml + release.yml for the API alone (if api/ is its own repository)
├── frontend/               the React front end (Vite) served by nginx
│   └── .gitea/workflows/   ci.yml + release.yml for the front end alone (if frontend/ is its own repository)
├── db/init.sql             PostgreSQL schema and demo data
├── compose.yaml, .env.example, .gitignore
└── README.md               the stack sheet (start-up, API contract, exercises)
```

## Two ways to split the repositories

| Split | Gitea repositories | Pipeline used | What it tests |
|-------|--------------------|---------------|---------------|
| **Monorepo** (default) | `equipe-a/formini-go` = the whole folder | `.gitea/` at the root | lint, tests, **full stack in Compose**, both images |
| **One repository per component** | `equipe-a/formini-go-api` = `api/` alone, `equipe-a/formini-go-frontend` = `frontend/` alone | `api/.gitea/` and `frontend/.gitea/` | each: lint, tests and build, **its** image only; the front end also checks that its image starts and answers on `/health` |

The three workflow sets publish the same images under the same names: the Day 4 Kubernetes
manifests work with either split. For the per-component split:

```bash
cp -r ateliers/jour3-cicd/exemples/go/api ~/formini-go-api && cd ~/formini-go-api
git init -b main && git add -A && git commit -m "feat: Go API and CI pipeline"
git remote add origin http://gitea.formini.local:3000/equipe-a/formini-go-api.git && git push -u origin main
# same with frontend/ → equipe-a/formini-go-frontend
```

## The `ci.yml` pipeline (monorepo)

```
  pull request / push main
          │
     ┌────┴─────┐
     ▼          ▼
   api       frontend        lint + unit tests  |  npm ci + vitest tests + vite build
     └────┬─────┘
          ▼
     integration             docker compose up --build --wait, then from the frontend container:
          │                  /health, /api/info (postgres and redis "ok"), POST then GET /api/tasks
          ▼
      publish                push on main only: build both images → trivy → Gitea registry
```

The `integration` job is what sets this pipeline apart from the running example's: the full
stack really starts on the runner, and a task is created then read back through nginx.
`compose.ci.yaml` removes the `ports:` (`!reset` keyword) and `COMPOSE_PROJECT_NAME` is unique
per run, so two simultaneous runs, or two runners on the same VM, never fight over port 8080.

## Set up

1. **Create the repository** in your team's Gitea organisation (for example `equipe-a/formini-go`),
   with Actions enabled (Settings → Repository units).
2. **Copy the folder and initialise it**:
   ```bash
   cp -r ateliers/jour3-cicd/exemples/go ~/formini-go && cd ~/formini-go
   git init -b main && git add -A && git commit -m "feat: Go stack and CI pipeline"
   git remote add origin http://gitea.formini.local:3000/equipe-a/formini-go.git
   git push -u origin main
   ```
   Replace `go` with `python`, `react-node` or `rust`, and `equipe-a` with your organisation in
   `env.IMAGE_API` / `env.IMAGE_FRONT` of both workflows.
3. **Secrets** (Settings → Actions → Secrets): `REGISTRY_USER` and `REGISTRY_TOKEN`, as in part
   2.1 of the lab.
4. **Watch** the Actions tab: four jobs for a PR, five for a push on `main`.
5. **Release**: `git tag -a v1.0.0 -m "First release" && git push origin v1.0.0` → Packages tab:
   `formini-go-api:v1.0.0` and `formini-go-frontend:v1.0.0`.

## Indicative durations (2 vCPU runner)

| Stack | First run | Later runs | Why |
|-------|-----------|------------|-----|
| Go | 3 min | 1 min 30 | module download into the `formini-go-mod` volume |
| Python | 2 min | 1 min 30 | pip; the venv is recreated on every run (bonus: `actions/cache`) |
| Node | 2 min | 1 min 30 | `npm ci` for the API and the front end; the front-end tests (Vitest, mocked API) take 5 s |
| Rust | 10 to 15 min | 2 min | crate compilation, then cached in `formini-cargo-registry` and `formini-rust-target` |

Run the first Rust pipeline **before** the session, or start it during a break.

## Key points

- **Host mode, two strategies**: tools present on the VM (python3, node, docker, trivy) are
  called directly; the others (Go, Rust) run in their official image via `docker run`, with
  named volumes as cache. Nothing extra to install.
- **Format checks are informational** (`gofmt -l`, `cargo fmt --check`) so the pipeline does not
  break over a space. Making them blocking is exercise 1.
- **Dependency audits are informational** (`pip-audit`, `npm audit`): a CVE published the day
  before must not block the course; in production they are made blocking with a dated list of
  exceptions.
- **Scan and publish in the same job**, as for the running example: the built image only exists
  in the Docker daemon of the runner that built it.

## Exercises

1. Make `gofmt` or `cargo fmt --check` **blocking**, push a badly formatted file in a PR and
   watch it get rejected.
2. Add an `actions/upload-artifact@v3` step that keeps `info.json` and the `docker compose logs`
   output of the `integration` job.
3. **Matrix**: test the Node API on `node:20` and `node:22` via `docker run` (as for Go) with
   `strategy.matrix`.
4. **Kubernetes**: the Go stack then deploys onto the Day 4 kind cluster with
   [`ateliers/jour4-iac-kubernetes/exemples/go-react/`](../../jour4-iac-kubernetes/exemples/go-react/README.en.md)
   (namespace, StatefulSets, Deployments, Services).
5. **Deployment**: add a `deploy` job after `publish` that, on `main`, runs
   `docker compose pull && docker compose up -d` on the VM from a `compose.prod.yaml` using the
   registry images (`image:` instead of `build:`).
