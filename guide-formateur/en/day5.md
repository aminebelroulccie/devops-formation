# Trainer guide — Day 5: Monitoring and final project

_English version · la version française est dans [`jour5.md`](../jour5.md)_

**Thursday 12 November 2026 · 09:00 – 16:00**
Slides: `slides/en/day5-monitoring-final-project.html` (press `S` for presenter notes, `?print-pdf` to export)
Participant lab sheet: `ateliers/jour5-supervision-projet/README.en.md`
Solution: `ateliers/jour5-supervision-projet/solution/monitoring/`
Project: `ateliers/jour5-supervision-projet/projet-final/` (English versions in `projet-final/en/`)

---

## The evening before (Wednesday evening, 20 minutes)

- [ ] **Images pre-pulled on the trainer VM and, if possible, on every participant VM** (otherwise the `compose up` at 10:45 saturates the connection):
  ```bash
  for i in prom/prometheus:v2.55.1 grafana/grafana:11.3.1 prom/node-exporter:v1.8.2 gcr.io/cadvisor/cadvisor:v0.49.1; do docker pull $i; done
  ```
  Tip: a script in `setup/` can loop over all the VMs via SSH.
- [ ] **Test the full stack** on the trainer VM: Day 2 Compose application running, then `monitoring/` started, four targets UP, dashboard visible in Grafana under the *Formini* folder, `AppDown` triggered with `docker compose stop web` and then resolved.
- [ ] **Check the dashboard JSON**: `python3 -m json.tool formini-tasks.json > /dev/null`, and `promtool check rules alerts.yml`.
- [ ] **Check that port 3001** is free (Gitea uses 3000). And 8081 for cAdvisor (8080 is the kind NodePort).
- [ ] **Trainer kind cluster** still up with the application deployed, for the bonus demo and the project demo.
- [ ] **Print**: specification (1 per team), evaluation grid (1 per team + 1 for you per team), feedback questionnaire (1 per participant).
- [ ] **Prepare the random draw** for the presentation order (folded papers, or `shuf`).
- [ ] **Stopwatch** that can be shown on the projector (a browser tab is enough).
- [ ] **AWS**: check in the console that no Day 4 instance is still running; note the remaining ones so they get destroyed at 09:05.

---

## 08:45 – 09:00 · Setup

Projector, cover slide, trainer VM open with three tabs: Prometheus (9090), Grafana (3001), Gitea. A terminal with `load.sh` ready but not started.

## 09:00 – 09:10 · Welcome (slides 1–3)

- Ask: "Who still has a kind cluster running? Who still has an AWS instance?" → have those who do run `terraform destroy` right away.
- Remind them that the Day 1 teams are the project teams. Announce bluntly: "At 15:00 sharp, we present, finished or not."
- Read the agenda. Point out that the morning theory is short: 1h20, then hands-on.

## 09:10 – 10:30 · Prometheus theory (slides 4–14)

**Slide 5 — Why monitor.** Question to the room: "How do you find out that a service is down, today?" Let "a user calls" come out. Link to the DORA MTTR (Day 1): detect before you repair.

**Slide 6 — Three pillars.** Car metaphor: dashboard / service logbook / dashcam. We do metrics today because they are what wakes someone up.

**Slide 7 — Golden signals.** Announce that the 11:00 dashboard follows exactly this structure. Formini Tasks already exposes latency, traffic and errors; saturation will come from the exporters.

**Slide 8 — SLI/SLO.** Do not dwell on it. Single message: we alert on a user symptom (errors, latency), not on a cause (CPU). CPU goes on the dashboard, not on the on-call phone.

**Slide 9 — Pull architecture.** Draw the arrows on the board in the direction Prometheus → targets. Why pull: a vanished target is visible (`up == 0`), no configuration on the application side, no queue.

**Slide 10 — Exposition format. DEMO 1 (5 min).**
```bash
cd ~/formini-tasks && docker compose up -d
curl -s localhost:5000/metrics | grep -v '^#' | head -20
```
Then open `app.py` in VS Code, show `Counter`, `Histogram`, `Gauge` and the `after_request`. Insist: "never a user identifier as a label" (cardinality).

**Slide 11 — Types.** Have them guess: "The number of open tasks, what is it?" (gauge). "The number of requests since startup?" (counter). "For a latency percentile?" (histogram, cumulative buckets, `le` label).

**Slide 12 — PromQL. DEMO 2 (10 min).** First start the traffic in a visible terminal:
```bash
./monitoring/load.sh http://localhost:5000 1200
```
In Prometheus, Graph tab, type in this order:
```promql
up
http_requests_total
sum(rate(http_requests_total[2m]))
sum by (endpoint) (rate(http_requests_total[2m]))
100 * sum(rate(http_requests_total{status=~"4.."}[5m])) / sum(rate(http_requests_total[5m]))
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))
```
Show the raw counter curve climbing endlessly, then `rate()`. Use `4..` rather than `5..` so that the rate is non-zero (load.sh produces 404s). Then:
```bash
docker compose stop web     # in ~/formini-tasks
```
Go back to `up`: the series drops to 0 in under 30 s. Restart with `docker compose start web`.

**Slide 13 — Exporters.** Open *Status → Targets*: four green rows. Type one node_exporter query and one cAdvisor query. Mention that there are exporters for PostgreSQL, Gitea, nginx.

**Slide 14 — Alerts.** Open *Alerts*. Explain inactive / pending / firing and the role of `for`. Say that Alertmanager is not deployed today (project bonus), but that Grafana can notify too.

## 10:30 – 10:45 · Break

During the break, check that the images are present on two or three participant VMs (`docker images | grep -E 'prometheus|grafana'`).

## 10:45 – 11:00 · Grafana theory (slides 15–18)

**Slide 16 — DEMO 3 (5 min).** Open Grafana, the *Formini Tasks — Golden signals* dashboard. Read the top row from the back of the room. Edit the "p95 latency" panel to show that it is the same query as earlier. Change the *Application* variable if the kind job is enabled.

**Slide 17 — Provisioning.** Show the `monitoring/grafana/` folder in VS Code. Parallel with Terraform and Kubernetes: the desired state lives in a file, in Git, reviewed in a PR.

**Slide 18 — Compose.** Do not read the YAML. Point out: volumes mounted from Git, external network `formini-tasks_default`, port 3001, `host.docker.internal` for the kind NodePort.

## 11:00 – 12:00 · Guided lab (slide 19)

Project slide 19 and let the participants work through Part 1 of the lab sheet. Walk around.

**Failures to expect and answers:**

| Failure                                                         | Answer                                                                                                |
|-----------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| `network formini-tasks_default declared as external, but could not be found` | The Day 2 application is not running, or the folder has a different name: `docker network ls`, adapt `networks.app.name`. |
| Target `formini-tasks` DOWN                                      | Same cause. Or the service is not called `web` in their compose file: adapt `targets`.                |
| cAdvisor restarts in a loop                                      | Missing volumes or `/dev/kmsg` absent: remove the `devices` line, restart.                           |
| Port 3001 already in use                                         | `ss -tlnp | grep 3001`, change the host-side port.                                                    |
| Dashboard missing in Grafana                                     | `docker compose logs grafana | grep -i dashboard`: invalid JSON after a clumsy export; `python3 -m json.tool`. |
| 5xx error rate at 0                                              | Expected. Explain 4xx vs 5xx, do the `stop db` bonus for real 503s.                                   |
| `AppDown` stays pending                                          | `for: 1m`: wait. Show *Status → Rules* to check that the rule is loaded.                              |

At 11:40, ask one team to show its alert in *firing* on the projector. At 11:55, remind them that the `feat/monitoring` PR must be open: it counts for the project.

## 12:00 – 13:00 · Lunch

Over lunch: check that your own project demo chain (commit → pipeline → kind → Grafana) works. You will need it if a team wants to see "what it looks like when it works".

## 13:00 – 13:15 · Final project brief (slides 20–24)

- Slide 21: the key sentence, "a commit on main ends up in monitored production without a single click". The `priority` field is the tracer.
- Slide 22: read the five deliverables, hand out the printed specification.
- Slide 23: the grid. Say it clearly: "We grade the chain, not the Python code. An honest chain that gets as far as the build earns points. A demo that 'was working a minute ago' does not."
- Slide 24: presentation format, check-ins at 14:00 and 14:30, rehearsal at 14:50.
- Ask each team to name a demo lead and a timekeeper before 13:20.

## 13:15 – 15:00 · Final project in teams

**Your role: unblock, do not do.** Three rounds:

**13:20 – 13:35, round 1: the plan.** Each team must have written down (board, file) who does what. If a team "starts with the feature", redirect them: first get the existing chain to pass end to end, then the feature.

**14:00, check-in 1 (3 min per team, timed).** Questions: is the pipeline green? Is the image in the registry? What is blocking? Give a lead, not a solution. Note the status on your sheet.

**14:30, check-in 2.** "What are you freezing now?" Push the teams to stop adding and to integrate. Those without a working deployment: tell them to show Compose + Compose monitoring, that is accepted.

**14:50.** Go round saying "demo rehearsal" to every team. Check that the demo commit exists and has not been pushed.

**If a team is hard stuck:**

| Blocker                                    | Quick unblock                                                                                 |
|--------------------------------------------|-----------------------------------------------------------------------------------------------|
| Dead runner                                | `sudo systemctl restart act_runner`, check the label in `runs-on`.                            |
| Registry push refused                      | Redo the Gitea token (`write:package` scope), `REGISTRY_TOKEN` secret, `docker login`.        |
| `ImagePullBackOff`                         | Quick fix: `kind load docker-image <image> --name formini`, move on.                          |
| Prometheus cannot see kind                 | Uncomment the `formini-tasks-k8s` job, `curl -X POST localhost:9090/-/reload`.                |
| `priority` migration on an existing PostgreSQL | `docker compose down -v` in Compose; on kind, `kubectl exec` + `ALTER TABLE tasks ADD COLUMN priority INTEGER DEFAULT 2`. Have them note it for the debrief. |
| Team in conflict                           | Physically separate the tasks: one on the pipeline, one on kind, one on monitoring, integration at 14:30. |

## 15:00 – 15:45 · Presentations

- Draw the order in front of everyone. Start the stopwatch for each team, visible.
- You hold the grid (`projet-final/en/EVALUATION-GRID.md`); fill in sections 1 to 5 during the demo, section 6 right after.
- With 4 teams: 11 min each, no more. Cut politely at 11 min, allow 1 question.
- Encourage questions from the other teams. If the room is flat: "one bonus point for the best question".
- Do not comment on grades in public. Give each team two strengths and one lead, out loud, in 30 seconds.
- If a demo breaks: allow 90 seconds of diagnosis out loud, then ask them to move on. Grade the diagnosis positively.

After the last team: collect or photograph the grids, hand them back to the teams at the end of the day with the comment.

## 15:45 – 16:00 · Closing (slides 25–29)

**Summary (slide 26), 4 minutes.** Redraw the Day 1 infinity loop on the board and tick each stage with the matching day. Outline:

> "On Monday we said DevOps was neither a tool nor a job title. And yet this week you learned eight tools. None for its own sake: Git for review, Docker for reproducibility, Gitea Actions to test on every commit, Terraform and Ansible for infrastructure you can review, Kubernetes to deploy without downtime, Prometheus and Grafana to see before the user does. Every tool serves a practice. Every practice serves a single idea: deliver more often, in smaller pieces, and sleep at night."

**What next (slide 27), 3 minutes.** Quick round of the table: "The practice you will put in place next month, in one word." Write it on the board. Saying the commitment out loud matters.

**Feedback (slide 28), 5 minutes.** Hand out the questionnaire below, allow 4 minutes of silence, collect. Then round of the table: one thing you will do differently on Monday.

**Slide 29.** Thank them. Remind them: clone `formation-devops`, `terraform destroy`, VMs left clean.

### Feedback questionnaire (to print, anonymous)

```
Formini DevOps training — 8 to 12 November 2026 — Your feedback (anonymous)

1. The overall pace was:   □ too fast   □ about right   □ too slow

2. For each day, from 1 (not very useful) to 5 (very useful):
   D1 DevOps/Linux/Git ___   D2 Docker ___   D3 CI/CD ___   D4 IaC/Kubernetes ___   D5 Monitoring/project ___

3. The share of hands-on work (labs, project) was:   □ not enough   □ about right   □ too much

4. A topic or tool that was missing: ____________________________________________

5. What you are going to put in place in your team: _______________________________

6. One piece of advice for the next session: ______________________________________

7. Would you recommend this training?   □ yes   □ yes with reservations   □ no
   Why: ____________________________________________________________________________
```

---

## After 16:00 · Trainer checks

- [ ] **AWS**: console → EC2, VPC, EKS in the training region: no resources left. Check *Billing → Budgets* the next day.
- [ ] The participant VMs can be left as they are or reset, following Formini's instructions.
- [ ] Save the filled-in grids and the questionnaires; enter the grades in a spreadsheet (team, sections 1–6, bonus, total).
- [ ] Note in this guide the failures encountered today and the actual duration of each sequence, for the next session.
- [ ] Send to the participants, within 48 h: link to the `formation-devops` repository, the commented grids, and the "going further" leads from slide 27.
