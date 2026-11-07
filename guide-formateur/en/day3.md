# Trainer guide — Day 3: CI/CD Pipelines with Gitea Actions

_English version · la version française est dans [`jour3.md`](../jour3.md)_

**Tuesday 10 November 2026 · 09:00 – 16:00 · Formini DevOps Training**

Slides: `slides/en/day3-cicd-gitea-actions.html` (31 slides, presenter notes
with the **S** key). Participant lab sheet: `ateliers/jour3-cicd/README.en.md`.
Solutions: `ateliers/jour3-cicd/solution/`.

Goal of the day: by 16:00, each team has a repository where every push to
`main` lints, tests, builds, scans and publishes the image to the Gitea registry, and
whose `main` branch refuses any merge without a green pipeline.

---

## The day before, or before 08:30

Check everything **on the trainer VM and on a participant VM**.

| Check | Command / location | Expected |
|-------|--------------------|----------|
| Gitea answers | `curl -s http://gitea.formini.local:3000/api/healthz` | `"status":"pass"` |
| Actions enabled at instance level | Site administration → Configuration → *Actions enabled* | `true` |
| Runners online | Site administration → **Actions** → **Runners** | one runner per participant VM, green dot, `ubuntu-latest` label |
| Runner service | `sudo systemctl status act_runner` on a participant VM | *active (running)* |
| Node.js (host mode, required by `actions/checkout`) | `node --version` | `v20.x` |
| trivy and its database | `trivy image --download-db-only` | downloads without error |
| Insecure registry | `docker info \| grep -A1 Insecure` | `gitea.formini.local:3000` |
| Registry login | `echo <token> \| docker login gitea.formini.local:3000 -u formateur --password-stdin` | *Login Succeeded* |
| Demo repository | `formateur/formini-tasks` on Gitea, with the Day 2 `Dockerfile` and a pipeline that is **already green** | to show at 09:40 |
| "Broken" repository | a `demo/test-casse` branch with a wrong test, PR open, red run | to show at 10:10 |

Have to hand: the trainer account's `ci-registry` token, a terminal open on the
trainer VM, the Actions tab of the demo repository.

If a participant runner is offline in the morning: `sudo systemctl restart act_runner`
then `journalctl -u act_runner -n 30`. If the registration is lost, run
`setup/act-runner/install-runner.sh` again with a new registration token
(Site administration → Actions → Runners → *Create registration token*).

---

## 09:00 – 09:15 · Opening (slides 1 to 3)

- Welcome, quick round: "Who has their Docker image from yesterday? Who pushed it to the
  registry by hand?" The raised hands are the transition: *today is the last time you
  push it by hand.*
- Slide 2: the week. Today's pipeline produces the image that Kubernetes will
  pull tomorrow. Each day builds on the previous one.
- Slide 3: agenda. Announce the rule of the day: **a simple, green pipeline
  before an ambitious one**.

## 09:15 – 09:45 · Part 1: continuous integration and continuous delivery (slides 4 to 9)

**Points to get across**

- Slide 5: integration hell. Tell the story of a six-week release. Ask
  "who has already had a build that only one person knew how to run?". There is always someone.
- Slide 6: CI / continuous delivery / continuous deployment. Key question to
  tell the two CDs apart: *who presses the button?* Announce: CI this morning, delivery this
  afternoon, deployment tomorrow.
- Slide 7: ten minutes and small batches. Link back to the DORA metrics from Day 1.
  Write on the board and leave it there all day: **red on main = top priority**.
- Slide 8: the six stages. Insist on the order, from the cheapest to the most expensive.
  Publication on `main` only.
- Slide 9: questions, not tools. Get the room to say which tool would answer each
  question in *their* language (Java, PHP, Node…).

**Question to ask**: "Between a commit and the certainty that it breaks nothing, how much
time goes by in your organisation today?" Note the answers, come back to them at the
wrap-up.

## 09:45 – 10:30 · Part 2: Gitea Actions (slides 10 to 16)

**Demo 1 (09:50, slide 11) — reading a workflow.** Open the demo repository's
`.gitea/workflows/ci.yml` in VS Code. Read it top to bottom with
the four questions: when, what, where, how. Do not explain the keywords one
by one: slide 12 is a reference, we will come back to it during the lab.

**Demo 2 (10:00, slides 13 and 15) — the runner.** On the trainer VM:

```bash
sudo systemctl status act_runner
sudo cat /etc/act_runner/config.yaml | grep -A3 labels
journalctl -u act_runner -f
```

Then in Gitea: Site administration → Actions → Runners. Show the green dot, the
labels, the last-contact date. Make the connection: *the runner polls Gitea,
not the other way round*. Stop the runner (`sudo systemctl stop act_runner`), push an
empty commit to the demo repository:

```bash
git commit --allow-empty -m "ci: trigger a run" && git push
```

Show the job **waiting**. Start the runner again, the job starts. This is failure
number one of the day: show it before it happens.

**Demo 3 (10:15, slide 16) — reading a red run.** Open the `demo/test-casse` PR.
Red cross in the PR → Actions tab → `test` job → "Tests" step expanded →
**last line** of the log. Replay the step's command on the VM:

```bash
.venv/bin/pytest -q
```

Same error, same line. Message: every step is a command you can
type yourself.

**Slide 14 (labels)**: explain in two minutes why we are in host mode
(fast, transparent) and why production prefers docker mode (isolation).

## 10:30 – 10:45 · Break

During the break: check in Site administration → Runners that all the participant
runners are still green.

## 10:45 – 12:00 · Guided lab: a first pipeline (slide 17)

Participant sheet, **part 1**. Stay on slide 17.

**Suggested schedule**

| Time | Step | What the trainer does |
|------|------|-----------------------|
| 10:45 | 1.1 – 1.2 enable Actions, check the runner | Do the manipulation once on the projector, then let them do it. Go and see those who cannot see the Actions tab. |
| 10:55 | 1.3 write `ci.yml` | Project the file. Warn about indentation. Walk around. |
| 11:10 | 1.4 push, PR, watch | First green run expected around 11:15. Ask everyone for their run time. |
| 11:25 | 1.5 break a test | The most useful moment: everyone must **read** their red run. Ask three people: "which line?" |
| 11:45 | merge, run on `main`, artifact bonus | The fast ones do the bonus. |
| 11:55 | summary | Count the green pipelines by a show of hands. |

**Expected failures and answers**

- *No run appears* → Actions not enabled on the repository, or badly indented YAML.
  `python3 -c "import yaml; yaml.safe_load(open('.gitea/workflows/ci.yml'))"`.
- *Job waiting* → runner offline, or `runs-on` that does not match
  the label. Show where to compare.
- *`node: not found` in `actions/checkout`* → Node missing on the VM; run the
  runner install script again.
- *flake8 red on a line that is too long* → this is intended, the linter is doing its
  job. Fix it or adjust `.flake8`.
- *`pip install` very slow* → first run, no cache; mention the afternoon's
  cache bonus.

## 12:00 – 13:00 · Lunch break

Restart any runners that went down. Prepare the demo token for the secrets.

## 13:00 – 13:35 · Part 3: secrets and security (slides 18 to 23)

**Slide 19 — never in the code.** Tell the story of the committed AWS keys and the
next day's bill. Insist: a committed secret gets **revoked**, it does not get hidden.

**Demo 4 (13:10, slide 20) — secrets in Gitea.**

1. Avatar → Settings → Applications → `ci-registry` token, *package:
   Read and Write* permission. Show that the token is only displayed once.
2. Repository → Settings → Actions → Secrets → `REGISTRY_USER`, `REGISTRY_TOKEN`.
3. Temporarily add to the demo workflow a step
   `run: echo "${{ secrets.REGISTRY_TOKEN }}"`, push, open the log: `***`.
4. **Delete that step** in front of the room, explaining why: you do not leave
   an echo of a secret lying around, even masked (an `echo` through `base64` would reveal it).

**Demo 5 (13:20, slides 21-22) — trivy on yesterday's image.**

```bash
trivy image gitea.formini.local:3000/formateur/formini-tasks:latest
trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 gitea.formini.local:3000/formateur/formini-tasks:latest
echo $?
```

Explain `--ignore-unfixed`: without it, the pipeline would be permanently red because of
base-OS vulnerabilities that have no fix. The usual remedy for a critical
vulnerability: `docker build --pull` on an up-to-date base image.

**Demo 6 (13:30, slide 23) — protecting `main`.** Repository → Settings → Branches →
`main` rule: push disabled, required status `CI / test*`, one approval. Open
the `demo/test-casse` PR: Merge button greyed out, *required status check missing*. Message:
*nobody bypasses the tests, not even the admin*. Give the exact name of the
context: `CI / test (pull_request)`, hence the pattern `CI / test*`.

## 13:35 – 14:00 · Part 4: delivery strategies (slides 24 to 28)

- Slide 25: three tags, three uses. The `latest` trap: two machines,
  two images, nobody knows. Tomorrow Kubernetes will always deploy a
  precise tag.
- Slide 26: `release.yml` on tag. Show a tag live on the demo repository:

```bash
git tag -a v1.0.0 -m "First version" && git push origin v1.0.0
```

  While the run is going, move on to slide 27.
- Slide 27: build once, deploy everywhere. What changes between
  environments is the configuration, never the image. Go back to yesterday's Compose
  (`DATABASE_URL`).
- Slide 28: good practices. Go back to the demo repository: the `v1.0.0` image is in
  Packages. Ask: "which of these practices is most lacking in your projects?"

Announce the challenge: aim first for a `build` that works, then the protection, then the
tag. The bonuses afterwards.

## 14:00 – 15:30 · Self-paced challenge (slide 29)

Participant sheet, **part 2**. Same teams as yesterday.

| Time | Expected milestone | Where to step in |
|------|--------------------|------------------|
| 14:00 – 14:15 | 2.1 token and secrets created, manual `docker login` successful | Tokens without *package write*; `REGISTRY_USER` = login, not e-mail; organisation members without write access to packages. |
| 14:15 – 14:45 | 2.2 `build` job green, `:<sha>` and `:latest` image in Packages | `http: server gave HTTP response` → registry not declared in `daemon.json`. `permission denied` on the Docker socket → `docker` group. trivy red → `--pull` or a more recent base image. |
| 14:45 – 15:00 | 2.3 `main` protected, broken PR not mergeable | Status pattern: `CI / test*`. Test with a non-admin account if possible. |
| 15:00 – 15:15 | 2.4 `v1.0.0` tag, `docker pull …:v1.0.0` from another VM | Tag pushed but no run → `on.push.tags` missing, or non-annotated tag pushed before the workflow. |
| 15:15 – 15:30 | Demonstration | One team shows on the projector: push → run → Packages → pull from another VM. |

**Question to ask teams that finish early**: "Why are the scan and the publication
steps of the same job rather than separate jobs?" The answer (runners
on different VMs, different Docker daemons) is in the sheet; check
that they have understood it, then send them off to the cache or pip-audit bonus.

**Buffer**: if the teams are running late at 15:00, drop 2.4 (the tag) and
do it as a demo at the wrap-up. Branch protection matters more than the tag.

## 15:30 – 16:00 · Wrap-up (slides 30 and 31)

- Slide 30: three things to remember. Pick up the answers noted at 09:30 ("how much
  time between a commit and the certainty"): now, it is the duration of the run.
- Go around the table: one thing learned, one thing still unclear. Note the unclear points
  to come back to them tomorrow morning.
- Logistics reminders:
  - **Do not switch off the VMs**: runners and registry are used tomorrow.
  - Each team must have at least one `v1.0.0` image in Packages: it is the one
    Kubernetes will deploy tomorrow.
- Announce tomorrow: Terraform and Ansible in the morning, Kubernetes in the afternoon.
  Prerequisite for tomorrow morning: the training's AWS credentials will be handed out at
  09:00.

---

## Known pitfalls (summary)

| Pitfall | Signal | Countermeasure |
|---------|--------|----------------|
| Runner offline | job "waiting" forever | `systemctl restart act_runner`; check in Site administration → Runners |
| Label that does not match | same | `runs-on: ubuntu-latest` and label `ubuntu-latest:host` |
| Badly scoped token | `unauthorized` on `docker login` | *package: Read and Write* permission |
| HTTP registry not declared | `http: server gave HTTP response to HTTPS client` | `insecure-registries` in `/etc/docker/daemon.json` + docker restart |
| Separate jobs in host mode | `image not found` at scan or push | a single job for build + scan + push |
| Wrong status pattern | merge possible despite a red test | `CI / test*` |
| Node missing | `node: not found` in checkout | Node.js 20 on the VM |
| YAML with tabs | no run appears | two spaces; validate with `yaml.safe_load` |

## Fallback timing

If the morning overruns: cut slide 9 (questions per stage) and slide 14
(host / docker modes) down to one sentence each. If the afternoon overruns: the
`v1.0.0` tag becomes a trainer demo at the wrap-up. Never sacrifice 1.5 (breaking a test)
or 2.3 (branch protection): those are the two moments when people understand what
a pipeline is for.
