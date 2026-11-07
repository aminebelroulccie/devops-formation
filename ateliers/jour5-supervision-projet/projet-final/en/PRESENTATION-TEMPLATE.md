# Presentation template — Final project

_English version · la version française est dans [`MODELE-PRESENTATION.md`](../MODELE-PRESENTATION.md)_

**Duration: 10 to 15 minutes, questions included. Visible stopwatch. Order drawn at random at 15:00.**

No slides needed: the projector shows your terminal, Gitea and Grafana.
Prepare three browser tabs (Gitea Actions, the application, Grafana) and a terminal
with `kubectl` already pointed at the right namespace.

## 0. Before your turn (to do at 14:50)

- [ ] The demo commit is prepared on a branch, **not pushed**: a visible, risk-free change
      (README text, title in `static/index.html`, value of `APP_VERSION`).
- [ ] The pipeline has already run successfully once within the last hour.
- [ ] `kubectl get pods -n formini-tasks`: everything is Running.
- [ ] `load.sh` is running in the background against the deployed application so that Grafana moves.
- [ ] One team member is the "demo lead", another the "timekeeper".

## 1. The team — 1 minute

Who did what. One sentence per person. No "we did everything together".

## 2. The architecture — 2 minutes

On the whiteboard or on a simple diagram:

```
workstation → Gitea (PR, main) → act_runner (test, build, scan) → Gitea registry
                                                                  ↓
                            Grafana ← Prometheus ← kind (2 pods, NodePort 8080)
```

Say where things run (which VM, which port) and what triggers what.

## 3. The demonstration — 6 minutes

Suggested flow, talking during the waiting times:

1. **Before**: show the application on the NodePort and its version in `/health`.
2. **The commit**: push the branch, open the PR, a teammate approves, merge.
3. **The pipeline**: Actions tab, follow the jobs. While it runs, explain each stage
   and show `ci.yml`. Show the Trivy report from the last run.
4. **The image**: Gitea Packages tab, the `sha-…` tag has just appeared.
5. **The deployment**: `kubectl set image …` (or the deploy job), then
   `kubectl rollout status deployment/tasks -n formini-tasks`.
   Show `kubectl get pods -w`: the old pods stop after the new ones are ready.
6. **After**: `/health` returns the new version. The `priority` feature is visible
   in `curl …/api/tasks`.
7. **Monitoring**: Grafana, the generator's traffic, the p95, the error rate. Show the alert
   rule and say how you tested it.

If something breaks: breathe, open the logs (`kubectl logs`, Actions), diagnose
out loud. That is graded positively.

## 4. The debrief — 2 minutes

- What put up the most resistance, and how you solved it.
- What you would do differently with one more day.
- What you will take back to your own team on Monday.

## 5. Questions — 3 minutes

The other teams and the trainer ask questions. Likely questions:

- What happens if a test fails? Show it if you have time.
- How do you roll back after a bad deployment?
- Where is the PostgreSQL password stored? The registry token?
- Why `rate()` rather than the raw counter value?
- What would it take to move from kind to EKS?
