# Kubernetes — complete Go + React stack (namespace `formini-go`)

_English version · la version française est dans [`README.md`](README.md)_

The Day 2 stack ([`stack-go/`](../../../jour2-docker/exemples/stack-go/README.en.md)) and Day 3
repository ([`jour3-cicd/exemples/go/`](../../../jour3-cicd/exemples/go/README.en.md)), this time
on Kubernetes. Everything needed is in `k8s/`: the namespace, the Secret, both databases as
**StatefulSets**, the API and the front end as Deployments, the Services, and a ConfigMap for the
SQL schema.

```
  browser ──► Service frontend (NodePort 30081 → localhost:8081)
                     │
              Deployment frontend ×2  (nginx: /api/ → http://api:8080/)
                     │
              Service api (ClusterIP)
                     │
              Deployment api ×2  (Go)
                │            │
    Service postgres     Service cache        ← headless (clusterIP: None)
    (headless)           (headless)
       │                    │
  StatefulSet postgres   StatefulSet cache
  pod postgres-0         pod cache-0
  PVC data-postgres-0    PVC data-cache-0
```

| File | Objects | Why this kind |
|------|---------|---------------|
| `namespace.yaml` | Namespace `formini-go` | one isolated space per application: names, quotas, RBAC |
| `secret.example.yaml` | Secret `go-secret` | the PostgreSQL and Redis passwords, never in clear text in a manifest |
| `postgres.yaml` | headless Service + **StatefulSet** `postgres` | a database has state: stable name `postgres-0`, **its own** PVC `data-postgres-0` |
| `redis.yaml` | headless Service + **StatefulSet** `cache` | Redis persists here (`--save`) and requires a password (`--requirepass`): same rule as PostgreSQL |
| `api.yaml` | **Deployment** `api` ×2 + ClusterIP Service `api` | stateless: interchangeable replicas, rolling update; initContainers waiting for PostgreSQL and Redis |
| `frontend.yaml` | **Deployment** `frontend` ×2 + NodePort Service `frontend` | stateless; the only entry point from outside the cluster; initContainer waiting for the API |
| `configmap-api.yaml` | ConfigMap `api-config` | hosts, ports, names for the API: **all of its non-secret configuration** |
| `configmap-postgres.yaml` | ConfigMaps `postgres-config`, `postgres-init` | PostgreSQL variables and the `init.sql` schema |
| `configmap-redis.yaml` | ConfigMap `redis-config` | the `redis.conf` file mounted into the pod |
| `configmap-frontend.yaml` | ConfigMap `frontend-config` | `nginx.conf` and `proxy-params.conf`, mounted over the image's own |
| `kustomization.yaml` | the list of manifests | `kubectl apply -k k8s/` in one command |
| `kind-config.yaml` | kind cluster with ports 30080 and 30081 | useful if you recreate the cluster |

## The code

This folder is a complete repository, the same as [`jour3-cicd/exemples/go/`](../../../jour3-cicd/exemples/go/README.en.md)
plus `k8s/`:

```
api/            the Go API (pgx, go-redis) and its tests · distroless Dockerfile
frontend/       the React front end (Vite) served by nginx, proxy /api/ → api:8080 · tests: npm test
db/init.sql     PostgreSQL schema (same content as the postgres-init ConfigMap)
compose.yaml    the stack locally: cp .env.example .env && docker compose up -d --build → http://localhost:8080
.gitea/         Day 3 CI/CD pipeline (monorepo): lint, tests, integration, scan, publish, release
api/.gitea/, frontend/.gitea/   the same pipelines per component, if api/ and frontend/ are separate repositories
k8s/            the Kubernetes manifests described below
```

API contract: `GET /health`, `GET /api/info`, `GET`/`POST /api/tasks`, `GET /api/hits`.
Redis and PostgreSQL both require a password: locally via `.env`, on Kubernetes via the `go-secret` Secret.

## Prerequisites

- The images `formini-go-api:v1.0.0` and `formini-go-frontend:v1.0.0` published in your
  organisation's Gitea registry (Day 3 pipeline: `git tag v1.0.0`). Adjust `equipe-a` in
  `api.yaml` and `frontend.yaml`.
- A kind cluster `formini` whose nodes accept the Gitea registry over HTTP (done by
  `solution/deploy.sh` or `solution/deploy.sh --kind-only`). To reach the front end on
  `localhost:8081`, the cluster must have been created with this folder's `k8s/kind-config.yaml`
  (port 30081); otherwise use `kubectl port-forward` (below).

## Deploy

```bash
cd ateliers/jour4-iac-kubernetes/exemples/go-react
cp k8s/secret.example.yaml k8s/secret.yaml   # then change both passwords (PostgreSQL, Redis)
bash apply.sh                               # or: kubectl apply -k k8s/
kubectl -n formini-go get all,pvc
```

```
NAME                            READY   STATUS    RESTARTS   AGE
pod/api-7c9d4f8b6-abcde         1/1     Running   0          60s
pod/api-7c9d4f8b6-fghij         1/1     Running   0          60s
pod/cache-0                     1/1     Running   0          60s
pod/frontend-5f6c7d8e9-klmno    1/1     Running   0          60s
pod/frontend-5f6c7d8e9-pqrst    1/1     Running   0          60s
pod/postgres-0                  1/1     Running   0          60s
…
NAME                                     STATUS   VOLUME     CAPACITY   ACCESS MODES
persistentvolumeclaim/data-cache-0       Bound    pvc-…      256Mi      RWO
persistentvolumeclaim/data-postgres-0    Bound    pvc-…      1Gi        RWO
```

Open <http://localhost:8081> (or `kubectl -n formini-go port-forward svc/frontend 8081:80`,
then the same address). Create a task, increment the counter.

## What to observe

1. **Two families of objects.** `api` and `frontend` are Deployments: randomly named,
   replaceable pods. `postgres` and `cache` are StatefulSets: pods `postgres-0`, `cache-0`, each
   with its own PVC. `kubectl get pvc` shows the `data-<statefulset>-0` names.
2. **The DNS names are the Compose ones.** `postgres`, `cache`, `api`: the same `DATABASE_URL`,
   `REDIS_URL` and `proxy_pass` as on Day 2, without changing a line of code or nginx config.
3. **Configuration = ConfigMap, secret = Secret.** The workloads contain no configuration values:
   the API reads `api-config` (`envFrom` + `$(VAR)` to assemble `DATABASE_URL` and `REDIS_URL`),
   PostgreSQL reads `postgres-config`, Redis mounts `redis.conf` from `redis-config`, nginx mounts
   `nginx.conf` from `frontend-config` (which **overrides** the one baked into the image), and the
   `init.sql` schema is mounted in `/docker-entrypoint-initdb.d`. Only the passwords live in the
   `go-secret` Secret.
4. **The front end is the only entry point.** A single NodePort; the API, Redis and PostgreSQL
   are reachable inside the cluster only.
5. **Start-up order: the initContainers.** Kubernetes has no `depends_on`; we rebuild it with
   `initContainers` that loop until the awaited service answers: `api` waits for `pg_isready` on
   `postgres` and a `PONG` from `cache`, `frontend` waits for `/health` on `api`. Watch them:
   `kubectl -n formini-go get pods -w` shows `Init:0/2` then `Init:1/2` on the `api` pods, and
   `kubectl logs <pod> -c wait-for-postgres` shows their log. `postgres` and `cache` wait for
   nothing: they have no upstream dependency. Even without these initContainers the application
   would eventually converge thanks to the `readinessProbe`s, but with restarts and errors in the logs.

## Exercises

- **Stable identity.** `kubectl -n formini-go delete pod postgres-0`: the pod comes back with the
  same name, mounts `data-postgres-0` again, the tasks are still there. Compare with
  `kubectl -n formini-go delete pod -l app=api`: new names, no data lost either, but for a
  different reason. Which one?
- **Delete without losing.** `kubectl -n formini-go delete statefulset postgres`, then
  `kubectl -n formini-go get pvc`: the PVC is still there. Re-apply (`kubectl apply -k k8s/`):
  the data is back. Wipe it on purpose with `kubectl -n formini-go delete pvc data-postgres-0`.
- **Volatile Redis.** Turn `cache` into a Deployment with an `emptyDir` volume (drop `--save`).
  What happens to the counter after `kubectl delete pod -l app=cache`? When is that acceptable?
- **Change configuration without rebuilding.** In `k8s/configmap-frontend.yaml`, set
  `proxy_read_timeout` to `2s`; `kubectl apply -k k8s/` then
  `kubectl -n formini-go rollout restart deployment/frontend`. Same with `loglevel verbose` in
  `redis-config` then `rollout restart statefulset/cache`. Why is the `rollout restart` needed?
  (hint: a ConfigMap mounted with `subPath` or read through `envFrom` is not hot-reloaded).
- **Dependencies.** `kubectl -n formini-go scale statefulset/postgres --replicas=0`, then
  `kubectl -n formini-go rollout restart deployment/api`: the new `api` pods stay in `Init:0/2`
  while the old version keeps serving (rolling update + `maxUnavailable: 0`). Set `--replicas=1`
  again: the init containers finish and the rollout proceeds.
- **Rolling update.** `kubectl -n formini-go set image deployment/api api=…/formini-go-api:v1.1.0`
  with a `curl` loop on `localhost:8081/api/health`: zero errors. Then
  `kubectl -n formini-go rollout undo deployment/api`.
- **Scale.** `kubectl -n formini-go scale deployment/api --replicas=4`, refresh the page: the
  *Container* field changes. Try `scale statefulset/postgres --replicas=2`: why is that a bad idea
  as is? (hint: two independent PostgreSQL instances, not replication).

## Clean up

```bash
kubectl delete namespace formini-go     # removes everything, PVCs included
```
