# Trainer guide — Day 2: Containerisation with Docker

_English version · la version française est dans [`jour2.md`](../jour2.md)_

**Monday 9 November 2026 · 09:00 – 16:00**
Slides: `slides/en/day2-docker.html` (press `S` for presenter notes).
Participant lab sheet: `ateliers/jour2-docker/README.en.md`. Solution: `ateliers/jour2-docker/solution/`.

## Before 09:00 — checks (20 min, the evening before or early in the morning)

- [ ] Gitea answers on <http://gitea.formini.local:3000>; the `equipe-*` organisations
      exist and every participant is a member with write access.
- [ ] Package registry enabled in Gitea (`[packages] ENABLED = true`): test a
      `docker login` + `docker push` from your VM.
- [ ] On a randomly chosen participant VM: `docker version`, `docker compose version`,
      `cat /etc/docker/daemon.json` contains `insecure-registries`.
- [ ] Images pre-pulled on every VM to save bandwidth:
      `nginx:1.27-alpine`, `python:3.12-slim`, `postgres:16-alpine`
      (the `setup/install-vm.sh` script does this; otherwise loop `docker pull` over SSH).
- [ ] Your demo repository cloned and up to date: `~/formini-tasks`, with the solution
      ready in a separate folder (`~/demo-solution`) so as not to spoil it.
- [ ] Two terminals open on the projector, font enlarged; browser with Gitea.
- [ ] A stopwatch for the cache demo (slide 16).

## 09:00 – 09:10 — Welcome and recap of the previous day

Go back over the unclear points noted during the Day 1 wrap-up (5 min max). Announce the
concrete goal for the end of the day: *an image published in each team's Gitea registry*.
Say that tomorrow the pipeline will reproduce everything we do today, so we take notes of
the commands.

## 09:10 – 09:50 — Part 1: containers and VMs (slides 4 to 7)

**Slide 5, the problem.** Ask the room: "Who has already lost half a day getting a
colleague's project to run?" Let 2 or 3 anecdotes come out. Introduce the shipping
container metaphor (we will come back to it with the registry).

**Slide 6, VM or container.** Key point: *there is no kernel inside a container*. Give the
orders of magnitude (seconds versus minutes, MB versus GB). Add nuance: weaker isolation,
and a Linux container needs a Linux kernel.

**Slide 7, under the hood — demo 1 (5 min):**

```bash
docker run -d --name demo nginx:1.27-alpine
ps -ef | grep nginx            # visible from the host
docker exec demo ps -ef        # PID 1 inside the container
docker run --rm --memory 64m python:3.12-slim python -c "x = bytearray(200_000_000)"
# → killed by the cgroup (exit 137), a good illustration of limits
docker rm -f demo
```

Question: "Why does the process show up on both sides?" Expected answer: it is the same
process, isolated by namespaces.

## 09:50 – 10:30 — Part 2: images, containers, registries (slides 8 to 13)

**Slide 9, vocabulary.** Have them repeat: *you build an image, you run a container, you
push to a registry.* Show `docker images` and `docker ps -a` side by side.

**Slide 10, lifecycle — demo 2 (8 min):** run through the block on the slide exactly, open
`http://localhost:8080` in the VM's browser. Show `docker stop` then `docker ps -a`: "it
still exists". Then `docker rm`.

**Slide 11, persistence — demo 3 (6 min), the one that sticks:**

```bash
docker run -d --name db -e POSTGRES_PASSWORD=formini postgres:16-alpine
sleep 5; docker exec db psql -U postgres -c "create table t(x int); insert into t values (1);"
docker rm -f db
docker run -d --name db -e POSTGRES_PASSWORD=formini postgres:16-alpine
sleep 5; docker exec db psql -U postgres -c "select * from t;"   # → relation does not exist
docker rm -f db
# then the same thing with -v pgdata:/var/lib/postgresql/data: the table survives
```

**Slide 12, networking.** Announce the number one trap of the afternoon: `localhost` in
`DATABASE_URL` refers to the web container itself. The service name is the hostname.

**Slide 13, Dockerfile.** Read the six lines; clearly distinguish `RUN` (at build time)
from `CMD` (at run time). Do not talk about cache or users yet: that is for the afternoon.

**Buffer:** if you are ahead of schedule, show `docker inspect` on a container and comment
on three fields (IP, mounts, config). If running late, skip demo 1.

## 10:30 – 10:45 — Break

During the break: run `docker pull` for the three images on your VM if not done yet, and
check that a random participant has an up-to-date clone.

## 10:45 – 12:00 — Guided lab (slide 14)

Show slide 14, then Part 1 of the README lab sheet on the second screen if possible.
Suggested pace: 1.1 and 1.2 together until 11:10, then everyone moves at their own pace.

Walk around the room. Failures to expect, in order of frequency:

| Symptom                                  | Fix                                                         |
|------------------------------------------|-------------------------------------------------------------|
| `permission denied` on the Docker socket | `usermod -aG docker`, **new session** (not just `su`)       |
| `COPY failed` / `requirements.txt not found` | `docker build` run outside the repository root          |
| Port 5000 already in use                 | `python app.py &` from step 1.2 still alive: `kill %1`      |
| 700 MB image                             | `.venv` copied: say nothing, it is the hook for the afternoon |

Around 11:45, do a quick round: who has `/health` answering? Who saw `root` with
`whoami`? Who has `.venv` in `ls /app`? These three observations structure Part 3.

## 12:00 – 13:00 — Lunch

## 13:00 – 13:35 — Part 3: efficient Dockerfiles (slides 15 to 20)

**Slide 16, cache — timed demo 4 (5 min):** with the naive Dockerfile from the morning,
change a comment in `app.py`, `time docker build .` (pip runs, 30 s to 1 min). Reorder
(requirements first), rebuild: 2 s. Say: "that is the difference between a 5-minute
pipeline and a 30-second one tomorrow".

**Slide 17, .dockerignore.** Show the line `transferring context: 120MB` then
`transferring context: 12kB` after adding the file. Insist on `.env`: a secret in an
image is a public secret.

**Slide 18, size.** Table to read quickly. Multi-stage is a bonus for Python, essential for
Go/Java. Do not spend more than 3 minutes on it.

**Slide 19, the reference Dockerfile.** Read each line added compared with the morning:
`ENV`, `useradd`/`USER`, `HEALTHCHECK`, `CMD` in exec form. Question: "What happens with
`CMD gunicorn ...` without brackets?" Answer: a shell becomes PID 1, SIGTERM never reaches
gunicorn, `docker stop` waits 10 s then kills.

**Slide 20, tags.** Anecdote of the two servers on `latest` running two different versions.
The commit SHA as a tag prepares the Kubernetes rollback on Day 4.

## 13:35 – 14:00 — Part 4: Compose and registry (slides 21 to 25)

**Slide 22, Compose.** Show `docker compose up -d --build` on your solution, then
`docker compose ps` with both `healthy`. Then `down` (volume kept) and `down -v` (volume
destroyed): this is the "let me start from scratch" trap when you do not actually want to
lose the data.

**Slides 23 and 24, the file.** Read line by line. Point out the absence of `ports:` on
`db`. Show `docker compose config`: the variables are resolved, passwords included, so
never paste this output into a ticket.

**Slide 25, registry — demo 5 (6 min):** create a token in Gitea on the projector
(Settings → Applications → *package* scope read/write), `docker login`, `tag`, `push`, then
open the organisation's **Packages** tab. Insist on the anatomy of the full image name.

## 14:00 – 15:30 — Self-paced challenge (slide 26)

Show slide 26, then leave slide 27 (troubleshooting) on screen during the challenge.
Remind them of the split: Dockerfile / Compose / registry + PR.

Checkpoints:

- **14:30**: check each team's `DATABASE_URL` (the `localhost` trap) and the presence of
  `condition: service_healthy`. A team without the condition will see
  `connection refused`: let them search for 5 minutes before helping.
- **14:50**: `docker compose ps` must show two `healthy`. If `db` stays in `starting`,
  the `.env` password was changed after the volume was created: `down -v`.
- **15:05**: check the two tags in Packages. Common error: token without the package scope
  → `unauthorized`.
- **15:15**: one team shows its Packages tab and its `compose ps` on the projector. Ask:
  "How big is your image? Who is `whoami`?"

If a team finishes early: trivy bonus (number of critical CVEs, `slim` versus the full
image), then multi-stage and size comparison.

**Optional demo (10 min, if ahead of schedule):** `bash ateliers/jour2-docker/exemples/build-all.sh`,
started during the break (Rust compiles for 2 to 5 min the first time). Walk through the size
table: Go distroless ≈ 8 MB, Rust ≈ 25 MB, React/nginx ≈ 50 MB, Python ≈ 150 MB. Message: size
depends on what goes into the final image, not on the language. Point participants to
`exemples/README.en.md` for the "other languages" bonus.

**Second optional demo (after part 2.2, if ahead):** one of the `exemples/stack-*/` stacks (Go
builds fastest; Rust takes 5 to 10 min, prepare it before the session). `docker compose up -d --build`,
open http://localhost:8080, create a task, increment the counter. Show `depends_on … service_healthy`,
the `api` name in `frontend/nginx.conf`, then `docker compose stop cache` → `/api/info` reports a
Redis error while tasks still work. The four stacks are identical except for the `api/` folder:
participants pick the one for their language.

## 15:30 – 16:00 — Wrap-up (slides 28 and 29)

The three points on slide 28. Go around the table: one thing learned, one thing still
unclear (note it for tomorrow). **Explicitly check** that every team has an image in its
registry: tomorrow's pipeline rebuilds it, but the registry must be working. Remind them to
leave the VMs switched on.

## After the day

- Note the failures encountered and their frequency to adjust the troubleshooting slide.
- Check that `act_runner` is registered on the trainer VM for tomorrow
  (`setup/act-runner/`), and that a push to a test repository does trigger a job.
- If a team did not manage the push, do it with them at 16:00: Day 3 depends on it.

## Answers to frequently asked questions

- *"Is Docker secure?"* Less isolating than a VM; we compensate with a non-root user,
  minimal images, CVE scanning, and eventually hardened runtimes.
- *"Why not Podman?"* Largely compatible, daemonless, rootless by default; Docker remains
  the de facto standard in training and on runners.
- *"Can you put the database in a container in production?"* Yes, with a volume and
  backups, but a managed service is often preferred. We come back to this on Day 4 with
  Kubernetes.
- *"What about Windows or macOS?"* Docker Desktop runs a lightweight Linux VM; the
  commands are identical.
