# Day 1 — Lab: Linux, SSH and Git as a team

_English version · la version française est dans [`README.md`](README.md)_

**Duration:** 10:45 – 12:00 (guided lab) then 14:00 – 15:30 (self-paced challenge)
**Machine:** your Formini VM (Ubuntu Server 24.04, initial user `ubuntu`) and your Formini workstation (VS Code + terminal).

## Objectives

By the end of this lab you will know how to:

- create a working user on a Linux server and give it the right permissions;
- connect to that server over SSH **with a key**, without a password, and harden the configuration;
- collaborate as a team of three on a Git repository hosted on Gitea: branches, pull requests, review, conflict resolution.

## Prerequisites

- The IP address of your VM (printed on your workstation sheet, e.g. `192.168.10.21`).
- The Gitea address: `http://gitea.formini.local:3000` (account created by the trainer, initial password on the workstation sheet).
- Your team of three and the name of its Gitea organisation (`equipe-a`, `equipe-b`, …).

---

## Part 1 — A Linux server reachable over SSH (guided lab)

### 1.1 First connection and getting your bearings

From the terminal on the Formini workstation:

```bash
ssh ubuntu@192.168.10.21        # password on the workstation sheet
```

Once connected:

```bash
hostnamectl                     # system name and version
whoami && id                    # who am I, in which groups
df -h /                         # disk space
free -h                         # memory
ss -tlnp                        # listening ports: 22 must appear
sudo tail -n 20 /var/log/auth.log   # your own login is logged
```

> Make it a habit: `systemctl status <service>`, `journalctl -u <service>`, `ss -tlnp`. These are the three diagnostic commands of the week.

### 1.2 Create the working user `devops`

```bash
sudo adduser devops                   # pick a simple password, it will be disabled for SSH
sudo usermod -aG sudo devops          # administration rights
sudo usermod -aG docker devops        # Docker (installed by the trainer) — needed from tomorrow
id devops                             # check: sudo and docker groups
```

Check that `devops` can use `sudo`:

```bash
sudo -iu devops
sudo -v && echo "sudo OK"
exit
```

### 1.3 Generate an SSH key on the workstation and install it on the VM

On the **Formini workstation** (new terminal window, not on the VM):

```bash
ssh-keygen -t ed25519 -C "firstname.lastname@formini"
# Enter for the default location, passphrase optional
ssh-copy-id devops@192.168.10.21      # type the devops password one last time
ssh devops@192.168.10.21              # must connect without a password
```

What `ssh-copy-id` did on the VM:

```bash
ls -la ~/.ssh                 # drwx------ (700) for .ssh
cat ~/.ssh/authorized_keys    # your public key, one line
```

If the permissions are different, fix them, otherwise SSH will refuse the key:

```bash
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
```

Make your life easier on the workstation, in `~/.ssh/config`:

```
Host vm
  HostName 192.168.10.21
  User devops
  IdentityFile ~/.ssh/id_ed25519
```

From now on `ssh vm` is enough. VS Code (*Remote - SSH* extension) reads this file too.

### 1.4 Harden the SSH server

> **Lab safety rule:** keep one `ssh vm` session open at all times during this step. Always test in a **second** window before closing the first one.

On the VM, create an override file (cleaner than editing `sshd_config`):

```bash
sudo tee /etc/ssh/sshd_config.d/50-formini.conf > /dev/null <<'EOF'
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
MaxAuthTries 3
X11Forwarding no
EOF
sudo sshd -t && echo "configuration valid"     # ALWAYS test before restarting
sudo systemctl restart ssh
```

Check from the workstation, in a new window:

```bash
ssh vm                                  # works (key)
ssh -o PubkeyAuthentication=no vm       # must be refused: "Permission denied (publickey)"
```

### 1.5 Grant access to a colleague

Exchange your **public** key (`cat ~/.ssh/id_ed25519.pub` on the workstation) with a member of your team, via the Gitea chat or a shared file. On your VM:

```bash
echo "ssh-ed25519 AAAA... colleague@formini" >> ~/.ssh/authorized_keys
```

Your colleague must be able to run `ssh devops@<your-ip>`. Do the same on their VM. Then **revoke** the access by deleting the line: that is the whole point of keys.

### Bonus (if you finished early)

- Install `fail2ban` (`sudo apt install -y fail2ban`) and look at `sudo fail2ban-client status sshd`.
- Change the listening port (`Port 2222` in the override file, `sshd -t`, restart, then `ssh -p 2222 vm`).
- Read the login attempts: `sudo grep "Failed\|Accepted" /var/log/auth.log`.

---

## Part 2 — Shared repository, branches and pull requests (self-paced challenge)

**In teams of three.** Quickly assign roles: person A (API), person B (tests), person C (documentation). Everyone works on their own VM (`ssh vm`); the repository lives on Gitea.

### 2.1 Set up your Git identity (everyone, on their own VM)

```bash
git config --global user.name  "Firstname Lastname"
git config --global user.email "firstname.lastname@formini.tn"
git config --global init.defaultBranch main
git config --global pull.rebase true
```

### 2.2 Initialise the repository (person A only)

1. On Gitea, in the team organisation, create the `formini-tasks` repository (**empty**, without a README).
2. Get the starter code provided by the trainer (folder `app/formini-tasks` of the `formation-devops` repository), then:

```bash
cd ~/formini-tasks
git init
git add .
git commit -m "chore: Formini Tasks starter code"
git remote add origin http://gitea.formini.local:3000/equipe-a/formini-tasks.git
git push -u origin main
```

3. On Gitea: *Settings → Branches → Add protection* on `main`: tick **Enable push protection**, **Require approvals = 1**, **Block merge on rejected reviews**.

Persons B and C clone:

```bash
git clone http://gitea.formini.local:3000/equipe-a/formini-tasks.git
cd formini-tasks
```

> To avoid retyping the password: `git config --global credential.helper store` (acceptable on a training VM, not in production).

### 2.3 One branch each

| Person | Branch                 | Work                                                                                      |
|--------|------------------------|-------------------------------------------------------------------------------------------|
| A      | `feature/stats`        | Add a `GET /api/stats` route that returns `{"total": n, "done": m}` in `app.py`.          |
| B      | `test/stats`           | Add a `test_stats` test to `tests/test_api.py` (it will fail until A has merged: that is expected, mention it in the PR). |
| C      | `docs/readme`          | Complete the README: a "Team" section with the three first names and a "Routes" section mentioning `/api/stats`. |

```bash
git switch -c feature/stats
# ... changes ...
git add -p                       # re-read each hunk before staging it
git commit -m "feat(api): add the /api/stats route"
git push -u origin feature/stats
```

Open the pull request on Gitea (the link is displayed after the `push`). Conventional title, description: *what*, *why*, *how to test*.

### 2.4 Cross review

A reviews B's PR, B reviews C's, C reviews A's. Each reviewer:

1. leaves **at least one comment on a line** (question or suggestion);
2. requests a change (*Request changes*);
3. the author pushes a fix commit to the same branch;
4. the reviewer approves (*Approve*), the author merges (*Create merge commit*) and **deletes the branch**.

Recommended merge order: A, then B (their test now passes), then C.

### 2.5 Cause and resolve a conflict

After C's merge, A and B both change **the same line** of the README (for example the title line), each on a new branch:

```bash
git switch main && git pull
git switch -c fix/titre-a            # B uses fix/titre-b
# change the first line of README.md
git commit -am "docs: clarify the title"
git push -u origin fix/titre-a
```

A merges their PR first. B must then bring their branch up to date:

```bash
git switch main && git pull
git switch fix/titre-b
git rebase main
# CONFLICT (content): Merge conflict in README.md
git status                           # conflicting file listed
# edit README.md: keep the right version, remove <<<<<<< ======= >>>>>>>
git add README.md
git rebase --continue
git push --force-with-lease          # the branch was rewritten: "safe" force
```

B's PR can now be merged. Merge it.

### 2.6 Deliver

On any member's VM:

```bash
git switch main && git pull
git log --oneline --graph --decorate | head -20
git branch -r                        # no more feature/… branches on origin
```

### Success criteria

- [ ] `main` is protected: a direct `git push origin main` is refused.
- [ ] Three PRs merged, each with at least one review comment and one approval.
- [ ] Commit messages follow the `type(scope): summary` convention.
- [ ] A conflict was resolved by rebase without losing content (both changes are visible or sensibly merged).
- [ ] `pytest -q` passes on `main` (B's test included).

### Bonus

- Create a tag: `git tag -a v0.1.0 -m "First version" && git push origin v0.1.0`.
- Add `CODEOWNERS` and a PR template (`.gitea/PULL_REQUEST_TEMPLATE.md`): see the `solution/` folder.
- Try `git log -p --follow README.md`, `git blame README.md`, `git reflog` (to recover a "lost" commit).

---

## Troubleshooting

| Symptom | Probable cause | Fix |
|---------|----------------|-----|
| `Permission denied (publickey)` although the key was copied | Wrong permissions on `~/.ssh` (700) or `authorized_keys` (600); wrong user | `chmod`, check with `ssh -v devops@ip` |
| `WARNING: UNPROTECTED PRIVATE KEY FILE!` | Private key readable by others on the workstation | `chmod 600 ~/.ssh/id_ed25519` |
| Locked out after changing SSH | Typo in the configuration | Formini console of the VM, `sudo sshd -t` shows the faulty line |
| `git push` refused: `protected branch` | You are pushing to `main` | Create a branch and open a PR |
| `git push` refused: `fetch first` | The remote has moved on | `git pull --rebase` then `push` |
| `fatal: refusing to merge unrelated histories` | Gitea repository created with a README | Recreate it empty, or `git pull origin main --allow-unrelated-histories` |
| Incomprehensible conflict | Too many changes at once | `git rebase --abort`, then start again with smaller commits |
