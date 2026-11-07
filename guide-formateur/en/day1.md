# Trainer guide — Day 1: DevOps fundamentals and Git

_English version · la version française est dans [`jour1.md`](../jour1.md)_

**Sunday 8 November 2026 · 09:00 – 16:00**
Slides: `slides/en/day1-devops-git.html` (press **S** for presenter notes, **F** for full screen, **Esc** for the overview).
Participant lab sheet: `ateliers/jour1-linux-git/README.en.md`.

## The day before (see also `setup/checklist-trainer.en.md`)

- [ ] Every participant VM answers over SSH with the `ubuntu` account (password on the workstation sheet).
- [ ] `setup/install-vm.sh` run on every VM (Docker, Git, Ansible, Terraform, kubectl, kind, Node, trivy).
- [ ] Gitea started on the trainer VM (`setup/gitea/`), reachable from the workstations: `http://gitea.formini.local:3000`. Participant accounts and `equipe-a…` organisations created (`setup/gitea/bootstrap.sh`).
- [ ] `formation-devops` repository pushed to Gitea with the contents of this folder (the starter code is in `app/formini-tasks`).
- [ ] Workstation sheets printed: VM IP, Gitea login, initial password, team name.
- [ ] Projector tested with the deck in full screen; font readable from the back of the room (browser zoom if needed).
- [ ] You have a clean "trainer" VM for the demos, plus a spare VM.

## Minute-by-minute schedule

### 09:00 – 09:15 · Welcome (slides 1–3)

- Introduce yourself in one minute. Go around the table: first name, job, one tool already used. Make a mental note of who knows Git: you will use them as relays within the teams.
- Slide 2: show the running example. Say it clearly: *"Everything you do today is used tomorrow. The repository you create this afternoon is the one we containerise on Monday."*
- Logistics: breaks, lunch, Formini machines only, no labs on personal laptops.

### 09:15 – 09:50 · DevOps (slides 4–10)

Points to get across, in order:

1. **The wall** (slide 5): tell the story of a failed deployment you lived through. Ask the room: *"Who has already heard 'it works on my machine'?"* Get reactions before explaining.
2. **Definition** (slide 6): insist on the order culture → practices → tools. *"You can buy Kubernetes and change nothing."*
3. **CALMS** (slide 7): link each letter to a day of the week.
4. **The loop** (slide 8): question to the room: *"Where you work, how long between a commit and production?"* Write the answers on the board, you will come back to them on Thursday.
5. **DORA** (slide 9): the counter-intuitive message, speed and stability go together.
6. **Running example** (slide 10): open Gitea on the projector, show the `formation-devops` repository and the `app/formini-tasks` folder. Start the application on your VM to show the interface:
   ```bash
   cd ~/formini-tasks && python3 -m venv .venv && . .venv/bin/activate
   pip install -r requirements-dev.txt && python app.py
   ```
   Open `http://<trainer-ip>:5000`, add a task, show `/health` and `/metrics`. *"Simple on purpose."*

### 09:50 – 10:30 · Essential Linux (slides 11–15)

Live demo on the trainer VM, projector on the terminal (font size 18 minimum).

- **Directory tree** (12): `ls /etc/ssh`, `tail -f /var/log/syslog` while you run `sudo systemctl restart ssh` in another window: the log moves, guaranteed effect.
- **Permissions** (13): have them work out 750 and 644 out loud. Demo of the `UNPROTECTED PRIVATE KEY FILE` error: `chmod 644 ~/.ssh/id_ed25519 && ssh vm`, then fix it. This is failure number one of the lab.
- **Processes and services** (14): `sudo systemctl stop docker`, `docker ps` fails, `systemctl status docker`, `journalctl -u docker -n 20`, `systemctl start docker`. Name the three-command reflex.
- **SSH** (15): draw workstation → server, private key / public key on the board. Do not do the lab for them: only show `ssh-keygen`.

If you are running late at 10:25, skip the processes demo (14): it is covered again in the lab sheet.

### 10:30 – 10:45 · Break

### 10:45 – 12:00 · Guided SSH lab (slide 16 + lab sheet Part 1)

- Show slide 16, then leave the lab sheet open on the projector (section 1.4: the override file).
- Pace: 1.1–1.2 in 20 min, 1.3 in 20 min, 1.4 in 20 min, 1.5 in 15 min.
- Walk around the room. Frequent failures:
  - `.ssh` / `authorized_keys` permissions → `chmod 700` / `600`;
  - `ssh-copy-id` run **on the VM** instead of the workstation;
  - `sshd -t` forgotten, service restarted with a typo → Formini console;
  - `ssh vm` asking for a password → wrong `User` in `~/.ssh/config`.
- At 11:45, check that everyone has at least finished 1.4: it is essential for Ansible on Wednesday. The bonuses keep the fast ones busy.

### 12:00 – 13:00 · Lunch

### 13:00 – 14:00 · Git and Gitea (slides 17–27)

Continuous demo on your VM, alongside the slides:

1. **Three areas** (18): `git init`, create a file, `git status` between each step. Show `git diff` then `git diff --staged`.
2. **Commands** (19): two commits, `git log --oneline --graph`. Add a `.gitignore` with `.env`: *"we will talk about this again on Tuesday with secrets"*.
3. **Branches** (20): the sticky-note metaphor. `git switch -c feature/x`, one commit, `git lg` (alias in the solution cheat sheet).
4. **Merges** (21): show a fast-forward, then create a commit on `main` and merge again: merge commit. Golden rule on the board: *"rebase your local branches, merge into main"*.
5. **Conflicts** (22): run `bash ateliers/jour1-linux-git/solution/conflit-demo.sh`, open the file in VS Code, resolve with the buttons, `git add`, `git commit`. Play it down: *"Git is asking you to arbitrate, that is all."*
6. **Remote** (23): create a repository on Gitea live, `git remote add`, `git push -u`. Show the *Clone* button.
7. **Workflow and protection** (25): Settings → Branches → protection of `main`. Show a refused `git push origin main`.
8. **PR and review** (25–26): ask for a volunteer: they push a branch, open a PR, you comment on a line, request a change, they fix it, you approve, they merge. Five minutes, very effective.
9. **Conventions** (27): show an unreadable `git log` versus a conventional one.

### 14:00 – 15:30 · Self-paced challenge (slide 28 + lab sheet Part 2)

- Form the teams of three **now** and announce that they stay the same until Thursday's final project. Mix the levels.
- Each team has a Gitea organisation ready (`equipe-a`, `equipe-b`…). Check that everyone is a member (bootstrap).
- Milestones to announce out loud: 14:20 repository pushed and `main` protected; 14:50 three PRs open; 15:10 all merged; 15:30 conflict resolved.
- Visit each team **at the time of the conflict** (2.5): that is when the questions come. Do not touch the keyboard, ask questions: *"What does git status say? Which version do you want to keep?"*
- At 15:20, ask one team to project its `git log --oneline --graph` and comment on it.
- Teams ahead of schedule: bonus (tag, CODEOWNERS, PR template).
- Team stuck on the HTTP push (password asked again): `git config --global credential.helper store`.

### 15:30 – 16:00 · Wrap-up (slides 29–30)

- Quick round of the table: *one thing learned, one thing still unclear*. Note the unclear points, you will open with them tomorrow morning.
- Announce tomorrow: Docker, we containerise `formini-tasks`. **Do not switch off the VMs**; Gitea must stay reachable.
- Reminder to the teams: the team's `formini-tasks` repository must be clean (main merged, tests green), tomorrow we start from there.

## If you have too much time

- Slide 14: `htop`, `ss -tlnp` with commentary.
- Git: `git stash`, `git cherry-pick`, `git bisect` as a quick demo.
- Discussion: *"What would stop your team from deploying every day?"*

## If you are short of time

- Skip the processes demo (14) and the conventions slide (27): the lab sheet covers them.
- The SSH lab bonus and the Git bonus are optional.
- The conflict (2.5) is the only part of the challenge that must not be skipped.
