# DevOps Training — Formini

_English version · la version française est dans [`README.md`](README.md)_

Complete material for the 5-day hands-on training course (8 – 12 November 2026, 09:00–16:00, 30 hours):
slides, trainer scripts, lab sheets, code and installation scripts. Everything exists in French and in English:
slides in `slides/en/`, lab sheets as `ateliers/jourN-…/README.en.md`, trainer guides in `guide-formateur/en/day1.md` … `day5.md`,
final-project documents in `ateliers/jour5-supervision-projet/projet-final/en/`, and setup notes as `*.en.md` next to the French files.

## Open the slides

Double-click [`slides/en/index.html`](slides/en/index.html), then pick the day. The French decks are in [`slides/index.html`](slides/index.html);
both index pages have a language switch button at the top ("English version" / « Version française »).
The decks are self-contained HTML pages (reveal.js, fonts and photos embedded in `assets/`):
nothing to install, they work entirely offline.

| Key | Action |
|-----|--------|
| `→` `←` `Space` | Navigation |
| `S` | Speaker notes (the trainer script, slide by slide) |
| `F` / `Esc` | Full screen / overview |
| `?print-pdf` in the URL | PDF export via Print → PDF |

## Layout

```
slides/                  the 5 decks + index.html (French); slides/en/: the same decks in English
assets/                  theme (theme.css), initialisation (deck.js), Formini logo, reveal.js,
                         fonts (fonts/), royalty-free photos (img/ + CREDITS.md)
guide-formateur/         jour1.md … jour5.md: minute-by-minute run sheet, demos, pitfalls (French);
                         en/day1.md … day5.md: the same trainer guides in English
ateliers/                participant lab sheets (README.md in French, README.en.md in English) + solution/ folders per day
  jour1-linux-git/
  jour2-docker/
  jour3-cicd/
  jour4-iac-kubernetes/
  jour5-supervision-projet/   (+ projet-final/: brief, grading grid, presentation template; English versions in projet-final/en/)
app/formini-tasks/       running-example application (Flask + tests), day 1 starting point
setup/                   VM, Gitea, act_runner and AWS preparation, trainer checklist (English notes as *.en.md next to each French file)
```

## Running example

A single application, **Formini Tasks** (a Python task API with its database), follows the
participants all week long:

| Day | What we add |
|-----|-------------|
| 1 | Git repository on Gitea, branches, pull requests, code review, hardened SSH server |
| 2 | `Dockerfile`, `compose.yaml` (web + PostgreSQL), image published to the Gitea registry |
| 3 | Gitea Actions pipeline: lint, tests, build, trivy scan, publication |
| 4 | AWS infrastructure with Terraform, Ansible configuration, Kubernetes deployment (kind), rolling update |
| 5 | Prometheus, Grafana, alerting, then the final project presented by each team |

## Preparing the session

Follow [`setup/checklist-trainer.en.md`](setup/checklist-trainer.en.md). In short:

1. `setup/install-vm.sh` on each Ubuntu 24.04 VM (tools + insecure registry);
2. `setup/gitea/` on the trainer VM (Gitea, accounts, organisations, runner token) — see [`setup/gitea/README.en.md`](setup/gitea/README.en.md);
3. `setup/act-runner/install-runner.sh` on each VM (before day 3);
4. `setup/aws/`: IAM user, policy, budget (before day 4) — see [`setup/aws/README.en.md`](setup/aws/README.en.md).

## Customising

- **Logo**: replace `assets/formini-logo.svg` (light background) and `assets/formini-logo-light.svg` (dark background) with the official files, keeping the same names. The logo supplied is a placeholder drawn for the mock-up.
- **Colours and fonts**: variables at the top of `assets/theme.css` (Libre Baskerville, Source Sans 3, JetBrains Mono, embedded in `assets/fonts/`).
- **Photos**: `assets/img/`, taken from Wikimedia Commons under a free licence, credited in `assets/img/CREDITS.md` and on the last slide of each deck. To change a photo, replace the file (same name) or edit the slide's `data-photo` / `data-side-photo` attribute.
- **Addresses**: Gitea is assumed to be reachable at `http://gitea.formini.local:3000`; search-and-replace if you use a different address.
