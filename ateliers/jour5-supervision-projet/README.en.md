# Day 5 — Monitoring and final project

_English version · la version française est dans [`README.md`](README.md)_

**Thursday 12 November 2026 · Formini DevOps training**

| Part | Slot          | Format                        | Sheet                                        |
|------|---------------|-------------------------------|----------------------------------------------|
| 1    | 10:45 – 12:00 | Guided lab                    | this document, Part 1                        |
| 2    | 13:15 – 15:00 | Final project, per team       | this document, Part 2 + `projet-final/`      |
| 3    | 15:00 – 15:45 | Presentations (10–15 min)     | `projet-final/en/PRESENTATION-TEMPLATE.md`   |

Conventions for the week:

- Gitea: `http://gitea.formini.local:3000`, organisation `equipe-a` (adapt to your team)
- Image: `gitea.formini.local:3000/equipe-a/formini-tasks:<tag>`
- VM: user `devops`, Ubuntu 24.04
- kind cluster `formini`, namespace `formini-tasks`, NodePort `8080`
- Application: port `5000`, routes `/health`, `/metrics`, `/api/tasks`

---

## Part 1 — Guided lab: monitoring Formini Tasks

### Goal

By the end of this part, you have:

- a Prometheus + Grafana + node_exporter + cAdvisor stack running on your VM;
- Prometheus collecting the metrics of Formini Tasks (the Day 2 version, running in Compose);
- a Grafana dashboard versioned in Git;
- one alert that fires when the application goes down, and another when the error rate exceeds 5%.

### 0. Prerequisite: the application is running

```bash
cd ~/formini-tasks
docker compose up -d
docker compose ps                       # web and db must be "running (healthy)"
curl -s localhost:5000/health           # {"status":"ok", ...}
curl -s localhost:5000/metrics | head   # Prometheus text format
docker network ls | grep formini        # formini-tasks_default must exist
```

If the network is not called `formini-tasks_default` (folder named differently),
write down its name: you will need to adapt it in `monitoring/compose.yaml`.

### 1. Start the monitoring stack

Take the `monitoring/` folder provided in the solution and put it **inside your
`formini-tasks` repository** (it will be versioned like everything else):

```bash
cd ~/formini-tasks
cp -r /path/to/formation-devops/ateliers/jour5-supervision-projet/solution/monitoring .
cd monitoring
docker compose up -d
docker compose ps
```

Four containers: `prometheus`, `grafana`, `node-exporter`, `cadvisor`.

Open Prometheus: `http://<VM-IP>:9090` → *Status → Targets*.
The targets `prometheus`, `formini-tasks`, `node`, `cadvisor` must be **UP**.

> **Target `formini-tasks` is DOWN?** Prometheus cannot find `web:5000`.
> Check the external network name in `compose.yaml` (`networks.app.name`)
> and that the application is actually running. Then run `docker compose up -d` again.

### 2. Generate traffic and query Prometheus

In a second terminal, leave the load generator running:

```bash
chmod +x monitoring/load.sh
./monitoring/load.sh http://localhost:5000 600
```

In Prometheus, *Graph* tab, run one after the other:

```promql
up
```
```promql
sum(rate(http_requests_total[2m]))
```
```promql
sum by (endpoint) (rate(http_requests_total[2m]))
```
```promql
100 * sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
```
```promql
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))
```
```promql
tasks_open
```

Questions to ask yourself:

- Why does `http_requests_total` on its own give a curve that only ever goes up?
- How many distinct series does `http_requests_total` have? (*Table* → count the rows)
- The 5xx error rate is 0: that is expected, `load.sh` triggers 404s and 400s, not 500s.
  Replace `5..` with `4..` and look again.

### 3. The Grafana dashboard

Open `http://<VM-IP>:3001` (admin / `formini`).
The **Formini Tasks — Golden signals** dashboard is in the *Formini* folder:
it was **provisioned** from `monitoring/grafana/dashboards/formini-tasks.json`.

> The panel titles of the provided dashboard and the alert texts are in French. English
> variants are in `solution/monitoring/en/` (see its `README.md` for the two `cp` commands to swap them in).

Find the four signals at the top: traffic, errors, p95 latency, open tasks.
Click a panel → *Edit*: the PromQL query is exactly the one you just typed.

### 4. Add a panel, then version it

1. *Add → Visualization*, query: `sum by (method) (rate(http_requests_total[2m]))`,
   title "Requests by method", unit `reqps`.
2. *Save dashboard*.
3. Export: *Share → Export → Save to file* (or *View JSON*), and replace
   `monitoring/grafana/dashboards/formini-tasks.json` with the exported file.
4. Check that Grafana does reload the file (30 s) and commit:

```bash
git switch -c feat/monitoring
git add monitoring
git commit -m "feat(monitoring): Prometheus/Grafana stack and golden signals dashboard"
git push -u origin feat/monitoring
```

Open the PR in Gitea and have it reviewed.

### 5. Trigger an alert

The rules are in `monitoring/prometheus/alerts.yml`. Check their syntax:

```bash
docker run --rm -v "$PWD/monitoring/prometheus:/cfg" --entrypoint promtool \
  prom/prometheus:v2.55.1 check rules /cfg/alerts.yml
```

In Prometheus, *Alerts* tab: `AppDown`, `HighErrorRate`, `HighLatencyP95`, `DiskAlmostFull`
are **inactive** (green).

Bring the application down:

```bash
cd ~/formini-tasks && docker compose stop web
```

Watch in *Alerts*: `AppDown` goes to **pending** (yellow), then **firing** (red) after 1 minute.
In Grafana, the "Traffic" panel collapses.

Restart it:

```bash
docker compose start web
```

The alert goes back to inactive. You have just been through the full detection → resolution cycle.

### 6. Bonus

- **Scrape the application on kind.** Uncomment the `formini-tasks-k8s` job in
  `prometheus.yml`, then reload: `curl -X POST localhost:9090/-/reload`.
  In Grafana, the *Application* variable at the top of the dashboard lets you switch
  between the two environments.
- **Cause a real 500 error.** Stop the database (`docker compose stop db`) and run
  `load.sh` again: `/health` answers 503 and `HighErrorRate` eventually fires.
- **Alert on 404s.** Add a `HighNotFoundRate` rule (> 20% of 404s over 5 min).

### Success criteria

- [ ] Four targets UP in Prometheus
- [ ] The five PromQL queries run and understood
- [ ] Dashboard visible in Grafana with one panel added, JSON committed
- [ ] `AppDown` seen firing, then resolved

---

## Part 2 — Final project

The full specification, the evaluation grid and the presentation template
are in the [`projet-final/`](projet-final/) folder (English versions in `projet-final/en/`).

### In one sentence

> A commit pushed to `main` must end up, **with no manual intervention**, in an application
> deployed on Kubernetes and visible in Grafana.

### What each team delivers (the `formini-tasks` repository of the team's organisation)

| #  | Deliverable                                                                                      | From day |
|----|--------------------------------------------------------------------------------------------------|----------|
| 1  | `main` protected; at least one PR reviewed, commented and merged today                          | D1       |
| 2  | Working `Dockerfile` and `compose.yaml` (application + PostgreSQL)                               | D2       |
| 3  | `.gitea/workflows/ci.yml`: test → build → scan → push of the image tagged with the SHA           | D3       |
| 4  | `k8s/`: 2-replica deployment on kind, probes, rolling update demonstrated                        | D4       |
| 5  | `monitoring/`: Prometheus scrapes the **deployed** application, provisioned dashboard, 1 alert   | D5       |
| 6  | One feature goes through the whole chain: a `priority` field on tasks                            | D1 → D5  |
| 7  | `README.md`: how to launch everything in fewer than 10 commands                                  |          |

### The "priority" feature

- `Task` gets an integer `priority` field (1 = high, 2 = normal, 3 = low), default 2.
- `POST /api/tasks` accepts `priority`; `GET /api/tasks` returns it; `GET /api/tasks?priority=1` filters.
- One test per behaviour in `tests/test_api.py`.
- The pipeline passes, the image is published, the deployment is updated, and `curl` on the NodePort
  returns tasks with `priority`.

> Why a feature? Because an empty chain proves nothing. We need to see a code change
> show up in production, with the pipeline checking it on the way.

### Afternoon schedule

| Time  | What                                                                                   |
|-------|----------------------------------------------------------------------------------------|
| 13:00 | Brief (slides), team draw confirmed, questions                                         |
| 13:15 | Start. **First fifteen minutes: written work-split plan**, who does what               |
| 14:00 | Trainer check-in, 3 min per team: where are you, what is blocking you?                 |
| 14:30 | Second check-in. From here on: **freeze, integrate, prepare the demo**                 |
| 14:50 | Demo rehearsal (the demo commit is ready, the pipeline has already run)                |
| 15:00 | Presentations, order drawn at random, visible stopwatch                                |

### Advice

- Split the work by stage of the chain, not by the person "who knows everything".
- Integrate early: a pipeline that passes at 13:45 beats a perfect pipeline at 14:55.
- The demo commit must be **tiny** (a text string, a default value).
- If a piece does not work, say so and show how far it does work. We assess the honesty
  of the diagnosis, not perfection.

### Quick troubleshooting

| Symptom                                               | Lead                                                                                     |
|-------------------------------------------------------|------------------------------------------------------------------------------------------|
| The runner does not pick up the job                   | `sudo systemctl status act_runner`, labels in `config.yaml`, matching `runs-on`          |
| `docker push` refused                                 | `REGISTRY_TOKEN` secret in Gitea, `docker login gitea.formini.local:3000`                |
| `ImagePullBackOff` on kind                            | Registry not declared insecure in the kind config, or tag does not exist; `kind load docker-image` as a fallback |
| Prometheus cannot see the kind application            | `host.docker.internal:8080` uncommented? NodePort exposed? `curl localhost:8080/metrics` |
| Grafana with no dashboard                             | `/var/lib/grafana/dashboards` path mounted? Valid JSON? `docker compose logs grafana`    |
| Alert still inactive                                  | `for:` not yet elapsed; check *Status → Rules* for a syntax error                        |
| The pipeline passes but nothing is deployed           | Expected: automatic deployment is a **bonus**. Show the `kubectl set image` command      |

---

## Before you leave

- [ ] `terraform destroy` on any AWS infrastructure still present (Day 4)
- [ ] The `formini-tasks` repository is up to date on Gitea, with the `README.md`
- [ ] You have cloned the `formation-devops` repository (slides, sheets, solutions)
- [ ] Feedback questionnaire handed to the trainer
