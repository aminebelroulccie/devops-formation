# Final project — Specification

_English version · la version française est dans [`CAHIER-DES-CHARGES.md`](../CAHIER-DES-CHARGES.md)_

**Formini DevOps training · Thursday 12 November 2026 · 13:15 – 15:00, presentations at 15:00**

## 1. Purpose

Each team (the ones formed on Day 1) assembles, on the **Formini Tasks** application,
a complete, working DevOps chain:

```
code  →  test  →  build  →  deployment  →  monitoring
```

The result is demonstrated live: a commit pushed to `main` triggers the pipeline,
produces an image, updates the Kubernetes deployment, and the change is visible
in the application and in Grafana.

## 2. Scope

### 2.1 Mandatory

| Stage            | Requirement                                                                                                       |
|------------------|-------------------------------------------------------------------------------------------------------------------|
| **Code**         | `formini-tasks` repository in the team's Gitea organisation. `main` protected (no direct push, 1 approval). At least one PR merged today, with at least one review comment. Conventional commit messages. |
| **Test**         | `pytest` run by the pipeline on every push and every PR. A failing test blocks the merge.                        |
| **Build**        | Clean `Dockerfile`: pinned base image, dependencies installed before the code (cache), non-root user, `HEALTHCHECK`. Image built by the pipeline, scanned (Trivy), published to the Gitea registry with the tags `sha-<first 7 characters>` and `latest`. |
| **Compose**      | `compose.yaml` that starts application + PostgreSQL locally with `docker compose up -d`.                         |
| **Deployment**   | Manifests in `k8s/`: Namespace, Secret, PostgreSQL (Deployment + Service + PVC), application (Deployment with 2 replicas, readiness/liveness probes, resources), NodePort Service 8080. Rolling update demonstrated (`kubectl rollout status`), rollback known (`kubectl rollout undo`). |
| **Monitoring**   | `monitoring/`: Prometheus scrapes the deployed application (NodePort or Compose), Grafana provisioned with a versioned dashboard (golden signals), at least one alert rule tested (triggered then resolved during preparation). |
| **Feature**      | The `priority` field (see §3) developed on a branch, reviewed, merged, tested, built, deployed and visible in production. |
| **README**       | How to launch everything from a blank VM, in fewer than 10 commands. Who did what.                               |

### 2.2 Bonus (up to +10 points)

- Deployment on kind **triggered by the pipeline** (`deploy` job with `kubectl set image`, kubeconfig stored as a secret).
- Alertmanager configured with a real notification (local mail, webhook, test Slack).
- Git tag `v1.0.0` and image tagged the same way, changelog generated from the commits.
- Terraform: the Day 4 EC2 instance provisioned and configured by Ansible to host the application in Compose, destroyed before 16:00.

### 2.3 Out of scope

User interface, authentication, HTTPS, PostgreSQL high availability. We assess the chain, not the product.

## 3. The "priority" feature

| Element          | Specification                                                                                   |
|------------------|-------------------------------------------------------------------------------------------------|
| Model            | `Task.priority`: integer, 1 = high, 2 = normal (default), 3 = low. Values outside 1–3 rejected (400). |
| `POST /api/tasks`| Accepts an optional `priority`.                                                                 |
| `PUT /api/tasks/<id>` | Accepts `priority`.                                                                        |
| `GET /api/tasks` | Returns `priority`; `?priority=1` filters.                                                      |
| `to_dict()`      | Includes `priority`.                                                                            |
| Tests            | Creation with a priority, default value, invalid value, filter.                                 |
| Metrics (bonus)  | `tasks_open` broken down by a `priority` label.                                                 |

Note: `db.create_all()` does not alter an existing table. On a PostgreSQL volume that already
exists, delete it (`docker compose down -v`) or add the column by hand. This is a real
production constraint: say how you handled it.

## 4. Deliverables

1. The Gitea repository `equipe-x/formini-tasks`, up to date at 15:00 (anything pushed later is not assessed).
2. The live demonstration (10–15 min, see `PRESENTATION-TEMPLATE.md`).
3. The `README.md` at the root of the repository.

## 5. Assessment

See `EVALUATION-GRID.md`. Total out of 100, bonus up to +10.

## 6. Constraints

- Everything runs on the Formini VMs. No public service (GitHub, pushing to Docker Hub) is used.
- Secrets (registry token, kubeconfig, PostgreSQL password) are **never** in Git.
- Any AWS resources are destroyed before 16:00.
- At 15:00, you present what exists. No extensions.

## 7. Check-ins with the trainer

- 14:00: work-split plan, pipeline status.
- 14:30: deployment and monitoring status, decision on what to freeze.
- 14:50: demo rehearsal. The demo commit is ready and **has not been pushed yet**.
