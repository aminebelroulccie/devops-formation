# Jour 3 — Gitea Actions pour les quatre piles (Go, Python, Node, Rust)

_English version: [`README.en.md`](README.en.md)_

Le fil rouge Formini Tasks a son pipeline en Python. Ces quatre dossiers fournissent les
**mêmes workflows Gitea Actions** pour les piles du jour 2
([`ateliers/jour2-docker/exemples/stack-*/`](../../jour2-docker/exemples/README.md)) : front
React + API dans le langage + PostgreSQL + Redis. Même structure de pipeline, seules les étapes
de lint et de tests de l'API changent.

| Dossier | Pile cible | Étapes propres à l'API |
|---------|------------|------------------------|
| [`go/`](go/.gitea/workflows/ci.yml) | `stack-go/` | `gofmt -l` (informatif), `go vet`, `go test`, dans le conteneur `golang:1.23-alpine` |
| [`python/`](python/.gitea/workflows/ci.yml) | `stack-python/` | venv, `flake8`, `pytest`, `pip-audit` (informatif), avec le python3 de la VM |
| [`react-node/`](react-node/.gitea/workflows/ci.yml) | `stack-react-node/` | `npm ci`, `node --check`, `npm test` (node:test), `npm audit` (informatif) |
| [`rust/`](rust/.gitea/workflows/ci.yml) | `stack-rust/` | `cargo fmt --check` (informatif), `cargo clippy`, `cargo test`, dans le conteneur `rust:1.83-slim` |

Chaque dossier est un **dépôt complet, prêt à pousser** : le code de la pile (identique à
`ateliers/jour2-docker/exemples/stack-*/`) plus les workflows.

```
go/                     (idem python/, react-node/, rust/)
├── .gitea/
│   ├── workflows/
│   │   ├── ci.yml          pull request et push sur main : api → frontend → integration → publish
│   │   └── release.yml     tag v* : tests, images étiquetées avec la version, scan, publication
│   └── compose.ci.yaml     surcharge : aucun port hôte publié pendant le test d'intégration
├── api/                    l'API dans le langage, avec ses tests unitaires
├── frontend/               le front React (Vite) servi par nginx
├── db/init.sql             schéma et données de démonstration PostgreSQL
├── compose.yaml, .env.example, .gitignore
└── README.md               la fiche de la pile (démarrage, contrat d'API, exercices)
```

## Le pipeline `ci.yml`

```
  pull request / push main
          │
     ┌────┴─────┐
     ▼          ▼
   api       frontend        lint + tests unitaires  |  npm ci + vite build
     └────┬─────┘
          ▼
     integration             docker compose up --build --wait, puis depuis le conteneur frontend :
          │                  /health, /api/info (postgres et redis "ok"), POST puis GET /api/tasks
          ▼
      publish                push sur main seulement : build des 2 images → trivy → registre Gitea
```

Le job `integration` est ce qui distingue ce pipeline de celui du fil rouge : la pile complète
démarre réellement sur le runner, et une tâche est créée puis relue à travers nginx. Le
`compose.ci.yaml` retire les `ports:` (mot-clé `!reset`) et `COMPOSE_PROJECT_NAME` est unique par
run : deux runs simultanés, ou deux runners sur la même VM, ne se disputent pas 8080.

## Mettre en place

1. **Créer le dépôt** dans l'organisation de l'équipe sur Gitea (par exemple `equipe-a/formini-go`),
   Actions activées (Paramètres → Unités du dépôt).
2. **Copier le dossier et l'initialiser** :
   ```bash
   cp -r ateliers/jour3-cicd/exemples/go ~/formini-go && cd ~/formini-go
   git init -b main && git add -A && git commit -m "feat: pile Go et pipeline CI"
   git remote add origin http://gitea.formini.local:3000/equipe-a/formini-go.git
   git push -u origin main
   ```
   Remplacez `go` par `python`, `react-node` ou `rust`, et `equipe-a` par votre organisation
   dans `env.IMAGE_API` / `env.IMAGE_FRONT` des deux workflows.
3. **Secrets** (Paramètres → Actions → Secrets) : `REGISTRY_USER` et `REGISTRY_TOKEN`, comme en
   partie 2.1 de l'atelier.
4. **Observer** l'onglet Actions : quatre jobs pour une PR, cinq pour un push sur `main`.
5. **Livrer** : `git tag -a v1.0.0 -m "Première version" && git push origin v1.0.0` → onglet
   Paquets : `formini-go-api:v1.0.0` et `formini-go-frontend:v1.0.0`.

## Durées indicatives (runner à 2 vCPU)

| Pile | 1er run | Runs suivants | Pourquoi |
|------|---------|---------------|----------|
| Go | 3 min | 1 min 30 | téléchargement des modules dans le volume `formini-go-mod` |
| Python | 2 min | 1 min 30 | pip ; le venv est recréé à chaque run (bonus : `actions/cache`) |
| Node | 2 min | 1 min 30 | `npm ci` pour l'API et le front |
| Rust | 10 à 15 min | 2 min | compilation des crates, puis cache dans `formini-cargo-registry` et `formini-rust-target` |

Préparez le premier run Rust **avant** la session, ou lancez-le pendant une pause.

## Ce qu'il faut retenir

- **Mode host, deux stratégies** : les outils présents sur la VM (python3, node, docker, trivy)
  sont appelés directement ; les autres (Go, Rust) tournent dans leur image officielle via
  `docker run`, avec des volumes nommés comme cache. Aucune installation supplémentaire.
- **Les vérifications de format sont informatives** (`gofmt -l`, `cargo fmt --check`) pour que le
  pipeline ne casse pas sur un espace. Les rendre bloquantes est l'exercice n° 1.
- **Les audits de dépendances sont informatifs** (`pip-audit`, `npm audit`) : une CVE publiée la
  veille ne doit pas bloquer la formation ; en production, on les rend bloquants avec une liste
  d'exceptions datées.
- **Scan et publication dans le même job**, comme pour le fil rouge : l'image construite n'existe
  que dans le démon Docker du runner qui l'a construite.

## Exercices

1. Rendez `gofmt` ou `cargo fmt --check` **bloquant**, poussez un fichier mal formaté dans une PR
   et observez le refus.
2. Ajoutez un step `actions/upload-artifact@v3` qui conserve `info.json` et les journaux de
   `docker compose logs` du job `integration`.
3. **Matrice** : testez l'API Node sur `node:20` et `node:22` via `docker run` (comme pour Go)
   avec `strategy.matrix`.
4. **Kubernetes** : la pile Go se déploie ensuite sur le cluster kind du jour 4 avec
   [`ateliers/jour4-iac-kubernetes/exemples/go-react/`](../../jour4-iac-kubernetes/exemples/go-react/README.md)
   (namespace, StatefulSets, Deployments, Services).
5. **Déploiement** : ajoutez un job `deploy` après `publish`, qui, sur `main`, exécute
   `docker compose pull && docker compose up -d` sur la VM à partir d'un `compose.prod.yaml`
   utilisant les images du registre (`image:` au lieu de `build:`).
