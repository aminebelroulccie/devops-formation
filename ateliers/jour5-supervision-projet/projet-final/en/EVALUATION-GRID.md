# Final project — Evaluation grid

_English version · la version française est dans [`GRILLE-EVALUATION.md`](../GRILLE-EVALUATION.md)_

**Team: ______________________  Assessor: ______________________  Presentation time: ______**

Total out of 100, bonus up to +10. Score during the presentation, complete by looking at the repository.

## 1. Git and code review — 15 points

| Criterion                                                      | Points | Score |
|----------------------------------------------------------------|-------:|------:|
| `main` protected (no direct push, approval required)           | 4      |       |
| At least one PR merged today with a review comment             | 5      |       |
| Conventional commit messages and readable history              | 3      |       |
| No secret, `.env` or binary in the repository                  | 3      |       |

## 2. Containerisation — 15 points

| Criterion                                                      | Points | Score |
|----------------------------------------------------------------|-------:|------:|
| Pinned base image, dependencies before the code (cache)        | 4      |       |
| Non-root user, `HEALTHCHECK`, `.dockerignore`                  | 4      |       |
| `compose.yaml`: app + PostgreSQL, healthcheck, volume, env     | 5      |       |
| Reasonable image size (< 250 MB) and explained                 | 2      |       |

## 3. CI/CD pipeline — 20 points

| Criterion                                                      | Points | Score |
|----------------------------------------------------------------|-------:|------:|
| Triggered on push and PR, visible in the Actions tab           | 3      |       |
| Test job (pytest, lint) that blocks on failure                 | 5      |       |
| Build and push of the image tagged `sha-xxxxxxx` to Gitea      | 6      |       |
| Security scan (Trivy) present and read                         | 3      |       |
| Secrets managed by Gitea (not in the YAML)                     | 3      |       |

## 4. Kubernetes deployment — 20 points

| Criterion                                                      | Points | Score |
|----------------------------------------------------------------|-------:|------:|
| Manifests versioned in `k8s/`, dedicated namespace             | 4      |       |
| Deployment with 2 replicas, readiness/liveness probes, resources | 5    |       |
| PostgreSQL with a PVC, Secret for the credentials              | 3      |       |
| Rolling update demonstrated (`rollout status`), rollback known | 6      |       |
| Application reachable via NodePort, `/health` OK               | 2      |       |

## 5. Monitoring — 15 points

| Criterion                                                      | Points | Score |
|----------------------------------------------------------------|-------:|------:|
| Prometheus scrapes the **deployed** application (target UP)    | 4      |       |
| Dashboard provisioned from Git, golden signals                 | 5      |       |
| At least one alert, triggered and resolved during preparation  | 4      |       |
| The team can read the dashboard during the demo                | 2      |       |

## 6. Presentation — 15 points

| Criterion                                                      | Points | Score |
|----------------------------------------------------------------|-------:|------:|
| Timing respected (10–15 min), roles shared out                 | 3      |       |
| Live demo of a commit going through the chain                  | 6      |       |
| Clarity of the architecture presented                          | 2      |       |
| Honesty of the debrief (what works, what put up a fight)       | 2      |       |
| Answers to questions                                           | 2      |       |

## Bonus — up to +10

| Criterion                                                      | Points | Score |
|----------------------------------------------------------------|-------:|------:|
| `priority` feature visible in production with its tests        | +4     |       |
| Deployment triggered automatically by the pipeline             | +3     |       |
| Alertmanager with notification, or `v1.0.0` tag + changelog    | +3     |       |

## Total

| Section                        | / max | Score |
|--------------------------------|------:|------:|
| 1. Git and review              | 15    |       |
| 2. Containerisation            | 15    |       |
| 3. CI/CD pipeline              | 20    |       |
| 4. Kubernetes deployment       | 20    |       |
| 5. Monitoring                  | 15    |       |
| 6. Presentation                | 15    |       |
| Bonus                          | +10   |       |
| **Total**                      | 100   |       |

Comment for the team (two strengths, one lead for improvement):

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________
