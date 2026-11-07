# Trainer checklist

_English version · la version française est dans [`checklist-formateur.md`](checklist-formateur.md)_

## D-7

- [ ] AWS account: IAM user, policy, budget, quotas (`setup/aws/README.md`, English version `setup/aws/README.en.md`).
- [ ] Request to Formini: 1 VM per participant + 2 trainer VMs (demo + spare), Ubuntu Server 24.04, 4 vCPU / 8 GB / 60 GB, fixed IPs, outbound Internet access, port 22 open from the workstations.
- [ ] Formini workstations: VS Code + *Remote - SSH* extension, OpenSSH client, rights to edit the `hosts` file (or use the IPs instead).
- [ ] Participant list → `setup/gitea/participants.csv`, teams of three.

## D-1

- [ ] On each VM: `GITEA_IP=<trainer-ip> sudo -E bash setup/install-vm.sh` (≈ 10 min per VM; run them in parallel with `tmux`).
- [ ] Trainer VM: Gitea started, `bootstrap.sh` run, runner token written down.
- [ ] On each VM: `RUNNER_TOKEN=<token> sudo -E bash setup/act-runner/install-runner.sh`; all runners show "Idle" in Gitea.
- [ ] `formini/formation-devops` repository pushed to Gitea (lab sheets, starting code, solutions if you publish them).
- [ ] End-to-end test on the trainer VM: clone `app/formini-tasks`, `pytest`, `docker build`, `docker push` to the registry, green pipeline, `kind create cluster`, `kubectl apply`, Prometheus sees the target.
- [ ] Workstation sheets printed (VM IP, Gitea login, initial password, team).
- [ ] Decks open in the room's browser, full screen tested, speaker notes (key S) on the trainer's screen.
- [ ] PDF version of the decks generated (`?print-pdf` then Print → PDF), just in case.

## Every morning

- [ ] Gitea responds, runners "Idle", every participant's VM reachable.
- [ ] Go back over the "unclear points" noted the day before (5 minutes).

## Every evening

- [ ] Days 4 and 5: `bash setup/aws/cleanup-check.sh`, no resources left behind.
- [ ] Note open questions and problems encountered to improve the lab sheet.
- [ ] Do not shut down Gitea or the VMs.

## Day 5

- [ ] Stopwatch for the presentations (10–15 min per team).
- [ ] Grading grid printed (`ateliers/jour5-supervision-projet/projet-final/en/EVALUATION-GRID.md`; French: `GRILLE-EVALUATION.md`).
- [ ] Satisfaction survey (in `guide-formateur/jour5.md`, English version `guide-formateur/en/day5.md`).
- [ ] After 16:00: AWS keys deactivated.
