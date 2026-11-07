# Gitea — training server

_English version · la version française est dans [`README.md`](README.md)_

Gitea runs on the **trainer VM** and serves as the Git forge, the container registry (day 2) and the CI engine (day 3).

## Installation (D-1)

```bash
# on the trainer VM, Docker already installed (setup/install-vm.sh)
cd setup/gitea
docker compose up -d
docker compose logs -f gitea      # wait for "Listen: http://0.0.0.0:3000"
```

Open `http://<trainer-ip>:3000`: the installation is locked (`INSTALL_LOCK`), there is no setup wizard. Create the accounts with the script:

```bash
sudo apt install -y jq
ADMIN_PASS='ChangezMoi!2026' bash bootstrap.sh participants.csv
```

The script creates:

- the `formateur` administrator account;
- one account per line of `participants.csv` (initial password `Formini2026!`, change forced at first login);
- one organisation per team (`equipe-a`, `equipe-b`, …), each member in the *Owners* team;
- and prints an **act_runner registration token** to keep for `setup/act-runner/install-runner.sh`.

## Training repository

Push this whole folder to a `formation-devops` repository under the `formini` organisation (create it in the web UI): participants will find the lab sheets, the starting code and whichever solutions you choose to make visible.

```bash
cd "<this folder>"
git init && git add . && git commit -m "chore: training material"
git remote add origin http://gitea.formini.local:3000/formini/formation-devops.git
git push -u origin main
```

## Name resolution

The workstations and the VMs must resolve `gitea.formini.local` to the trainer VM's IP:

- VMs: done by `install-vm.sh` (`GITEA_IP=...`);
- Formini Windows workstations: `C:\Windows\System32\drivers\etc\hosts`, line `192.168.10.10 gitea.formini.local` (administrator rights required); failing that, use the IP everywhere.

## Container registry

Enabled by default (`packages`). It is served over HTTP: every Docker host must declare `gitea.formini.local:3000` in `insecure-registries` (done by `install-vm.sh`).

```bash
docker login gitea.formini.local:3000          # Gitea login + password or token
docker tag formini-tasks:dev gitea.formini.local:3000/equipe-a/formini-tasks:dev
docker push gitea.formini.local:3000/equipe-a/formini-tasks:dev
```

## Backup / reset

All data lives in `./data`. To start from scratch: `docker compose down && sudo rm -rf data && docker compose up -d`, then run `bootstrap.sh` again.
