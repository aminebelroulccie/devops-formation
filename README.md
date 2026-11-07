# Formation DevOps — Formini

Matériel complet de la formation pratique de 5 jours (08 – 12 novembre 2026, 30 heures) :
diapositives, scripts formateur, fiches d'atelier, code et scripts d'installation.

## Ouvrir les diapositives

Double-cliquez sur [`slides/index.html`](slides/index.html), puis choisissez la journée. Une version anglaise de chaque deck est dans [`slides/en/`](slides/en/index.html) (lien « English version » en haut de la page).
Les decks sont des pages HTML autonomes (reveal.js, polices et photos embarqués dans `assets/`) :
aucun logiciel à installer, ils fonctionnent entièrement hors ligne.

| Touche | Action |
|--------|--------|
| `→` `←` `Espace` | Navigation |
| `S` | Notes orateur (le script du formateur, diapo par diapo) |
| `F` / `Échap` | Plein écran / vue d'ensemble |
| `?print-pdf` dans l'URL | Export PDF via Imprimer → PDF |

## Arborescence

```
slides/                  les 5 decks + index.html (français) ; slides/en/ : les mêmes en anglais
assets/                  thème (theme.css), initialisation (deck.js), logo Formini, reveal.js,
                         polices (fonts/), photos libres de droits (img/ + CREDITS.md)
guide-formateur/         jour1.md … jour5.md : déroulé minute par minute, démos, pièges
ateliers/                fiches participants + dossiers solution/ par journée
  jour1-linux-git/
  jour2-docker/
  jour3-cicd/
  jour4-iac-kubernetes/
  jour5-supervision-projet/   (+ projet-final/ : cahier des charges, grille, modèle de soutenance)
app/formini-tasks/       application fil rouge (Flask + tests), état de départ du jour 1
setup/                   préparation des VM, Gitea, act_runner, AWS, liste de contrôle formateur
```

## Fil rouge

Une seule application, **Formini Tasks** (API de tâches en Python avec sa base), suit les
participants toute la semaine :

| Jour | Ce que l'on ajoute |
|------|--------------------|
| 1 | Dépôt Git sur Gitea, branches, pull requests, revue, serveur SSH durci |
| 2 | `Dockerfile`, `compose.yaml` (web + PostgreSQL), image publiée dans le registre Gitea |
| 3 | Pipeline Gitea Actions : lint, tests, build, scan trivy, publication |
| 4 | Infrastructure AWS avec Terraform, configuration Ansible, déploiement Kubernetes (kind), rolling update |
| 5 | Prometheus, Grafana, alertes, puis projet final présenté par équipe |

## Préparer la session

Suivez [`setup/checklist-formateur.md`](setup/checklist-formateur.md). En résumé :

1. `setup/install-vm.sh` sur chaque VM Ubuntu 24.04 (outils + registre non sécurisé) ;
2. `setup/gitea/` sur la VM formateur (Gitea, comptes, organisations, jeton runner) ;
3. `setup/act-runner/install-runner.sh` sur chaque VM (avant le jour 3) ;
4. `setup/aws/` : utilisateur IAM, politique, budget (avant le jour 4).

## Personnaliser

- **Logo** : remplacez `assets/formini-logo.svg` (fond clair) et `assets/formini-logo-light.svg` (fond sombre) par les fichiers officiels, mêmes noms. Le logo fourni est un placeholder dessiné pour la maquette.
- **Couleurs et polices** : variables en tête de `assets/theme.css` (Libre Baskerville, Source Sans 3, JetBrains Mono, embarquées dans `assets/fonts/`).
- **Photos** : `assets/img/`, issues de Wikimedia Commons sous licence libre, créditées dans `assets/img/CREDITS.md` et sur la dernière diapositive de chaque deck. Pour changer une photo, remplacez le fichier (même nom) ou modifiez l'attribut `data-photo` / `data-side-photo` de la diapositive.
- **Adresses** : Gitea est supposé joignable sur `http://gitea.formini.local:3000` ; recherchez-remplacez si vous utilisez une autre adresse.
