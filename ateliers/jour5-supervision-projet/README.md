# Jour 5 — Supervision et projet final

**Jeudi 12 novembre 2026 · Formation DevOps Formini**

| Partie | Horaire        | Format                     | Fiche                                   |
|--------|----------------|----------------------------|-----------------------------------------|
| 1      | 10:45 – 12:00  | Atelier guidé              | ce document, partie 1                   |
| 2      | 13:15 – 15:00  | Projet final, par équipe   | ce document, partie 2 + `projet-final/` |
| 3      | 15:00 – 15:45  | Présentations (10–15 min)  | `projet-final/MODELE-PRESENTATION.md`   |

Conventions de la semaine :

- Gitea : `http://gitea.formini.local:3000`, organisation `equipe-a` (adaptez à votre équipe)
- Image : `gitea.formini.local:3000/equipe-a/formini-tasks:<tag>`
- VM : utilisateur `devops`, Ubuntu 24.04
- Cluster kind `formini`, namespace `formini-tasks`, NodePort `8080`
- Application : port `5000`, routes `/health`, `/metrics`, `/api/tasks`

---

## Partie 1 — Atelier guidé : superviser Formini Tasks

### Objectif

À la fin de cette partie, vous avez :

- une pile Prometheus + Grafana + node_exporter + cAdvisor qui tourne sur votre VM ;
- Prometheus qui collecte les métriques de Formini Tasks (celle du jour 2, en Compose) ;
- un tableau de bord Grafana versionné dans Git ;
- une alerte qui se déclenche quand l'application tombe, et une autre quand le taux d'erreur dépasse 5 %.

### 0. Prérequis : l'application tourne

```bash
cd ~/formini-tasks
docker compose up -d
docker compose ps                       # web et db doivent être "running (healthy)"
curl -s localhost:5000/health           # {"status":"ok", ...}
curl -s localhost:5000/metrics | head   # du texte Prometheus
docker network ls | grep formini        # formini-tasks_default doit exister
```

Si le réseau ne s'appelle pas `formini-tasks_default` (dossier nommé différemment),
notez son nom : il faudra l'adapter dans `monitoring/compose.yaml`.

### 1. Démarrer la pile de supervision

Récupérez le dossier `monitoring/` fourni dans la solution et placez-le **dans votre dépôt**
`formini-tasks` (il sera versionné comme le reste) :

```bash
cd ~/formini-tasks
cp -r /chemin/vers/formation-devops/ateliers/jour5-supervision-projet/solution/monitoring .
cd monitoring
docker compose up -d
docker compose ps
```

Quatre conteneurs : `prometheus`, `grafana`, `node-exporter`, `cadvisor`.

Ouvrez Prometheus : `http://<IP-VM>:9090` → *Status → Targets*.
Les cibles `prometheus`, `formini-tasks`, `node`, `cadvisor` doivent être **UP**.

> **Cible `formini-tasks` en DOWN ?** Prometheus ne trouve pas `web:5000`.
> Vérifiez le nom du réseau externe dans `compose.yaml` (`networks.app.name`)
> et que l'application tourne bien. Puis `docker compose up -d` à nouveau.

### 2. Générer du trafic et interroger Prometheus

Dans un deuxième terminal, laissez tourner le générateur :

```bash
chmod +x monitoring/load.sh
./monitoring/load.sh http://localhost:5000 600
```

Dans Prometheus, onglet *Graph*, exécutez successivement :

```promql
up
```
```promql
sum(rate(http_requests_total[2m]))
```
```promql
sum by (endpoint) (rate(http_requests_total[2m]))
```
```promql
100 * sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
```
```promql
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))
```
```promql
tasks_open
```

Questions à vous poser :

- Pourquoi `http_requests_total` seul donne une courbe qui ne fait que monter ?
- Combien de séries différentes a `http_requests_total` ? (*Table* → compter les lignes)
- Le taux d'erreur 5xx vaut 0 : normal, `load.sh` provoque des 404 et des 400, pas des 500.
  Remplacez `5..` par `4..` et regardez.

### 3. Le tableau de bord Grafana

Ouvrez `http://<IP-VM>:3001` (admin / `formini`).
Le tableau de bord **Formini Tasks — Golden signals** est dans le dossier *Formini* :
il a été **provisionné** depuis `monitoring/grafana/dashboards/formini-tasks.json`.

Repérez les quatre signaux en haut : trafic, erreurs, latence p95, tâches ouvertes.
Cliquez sur un panneau → *Edit* : la requête PromQL est exactement celle que vous venez de taper.

### 4. Ajouter un panneau, puis le versionner

1. *Add → Visualization*, requête : `sum by (method) (rate(http_requests_total[2m]))`,
   titre « Requêtes par méthode », unité `reqps`.
2. *Save dashboard*.
3. Exportez : *Share → Export → Save to file* (ou *View JSON*), et remplacez
   `monitoring/grafana/dashboards/formini-tasks.json` par le fichier exporté.
4. Vérifiez que Grafana recharge bien le fichier (30 s) et commitez :

```bash
git switch -c feat/monitoring
git add monitoring
git commit -m "feat(monitoring): pile Prometheus/Grafana et tableau de bord golden signals"
git push -u origin feat/monitoring
```

Ouvrez la PR sur Gitea, faites-la relire.

### 5. Déclencher une alerte

Les règles sont dans `monitoring/prometheus/alerts.yml`. Vérifiez leur syntaxe :

```bash
docker run --rm -v "$PWD/monitoring/prometheus:/cfg" --entrypoint promtool \
  prom/prometheus:v2.55.1 check rules /cfg/alerts.yml
```

Dans Prometheus, onglet *Alerts* : `AppDown`, `HighErrorRate`, `HighLatencyP95`, `DiskAlmostFull`
sont **inactive** (vert).

Faites tomber l'application :

```bash
cd ~/formini-tasks && docker compose stop web
```

Observez dans *Alerts* : `AppDown` passe en **pending** (jaune), puis **firing** (rouge) après 1 minute.
Dans Grafana, le panneau « Trafic » s'effondre.

Relancez :

```bash
docker compose start web
```

L'alerte repasse en inactive. Vous venez de vivre le cycle complet détection → résolution.

### 6. Bonus

- **Scraper l'application sur kind.** Décommentez le job `formini-tasks-k8s` dans
  `prometheus.yml`, puis rechargez : `curl -X POST localhost:9090/-/reload`.
  Dans Grafana, la variable *Application* en haut du tableau de bord permet de basculer
  entre les deux environnements.
- **Provoquer une vraie erreur 500.** Arrêtez la base (`docker compose stop db`) et relancez
  `load.sh` : `/health` répond 503 et `HighErrorRate` finit par sonner.
- **Alerte sur les 404.** Ajoutez une règle `HighNotFoundRate` (> 20 % de 404 sur 5 min).

### Critères de réussite

- [ ] Quatre cibles UP dans Prometheus
- [ ] Les cinq requêtes PromQL exécutées et comprises
- [ ] Tableau de bord visible dans Grafana avec un panneau ajouté, JSON commité
- [ ] `AppDown` observée en firing puis résolue

---

## Partie 2 — Projet final

Le cahier des charges complet, la grille d'évaluation et le modèle de présentation
sont dans le dossier [`projet-final/`](projet-final/).

### En une phrase

> Un commit poussé sur `main` doit finir, **sans intervention manuelle**, dans une application
> déployée sur Kubernetes et visible dans Grafana.

### Ce que chaque équipe livre (dépôt `formini-tasks` de l'organisation de l'équipe)

| #  | Livrable                                                                                     | Jour d'origine |
|----|----------------------------------------------------------------------------------------------|----------------|
| 1  | `main` protégée ; au moins une PR relue, commentée et fusionnée aujourd'hui                  | J1             |
| 2  | `Dockerfile` et `compose.yaml` fonctionnels (application + PostgreSQL)                        | J2             |
| 3  | `.gitea/workflows/ci.yml` : test → build → scan → push de l'image taguée par le SHA           | J3             |
| 4  | `k8s/` : déploiement en 2 réplicas sur kind, probes, rolling update démontré                  | J4             |
| 5  | `monitoring/` : Prometheus scrape l'application **déployée**, dashboard provisionné, 1 alerte | J5             |
| 6  | Une fonctionnalité traverse toute la chaîne : champ `priority` sur les tâches                 | J1 → J5        |
| 7  | `README.md` : comment lancer l'ensemble en moins de 10 commandes                              |                |

### La fonctionnalité « priority »

- `Task` reçoit un champ `priority` entier (1 = haute, 2 = normale, 3 = basse), défaut 2.
- `POST /api/tasks` accepte `priority` ; `GET /api/tasks` le renvoie ; `GET /api/tasks?priority=1` filtre.
- Un test par comportement dans `tests/test_api.py`.
- Le pipeline passe, l'image est publiée, le déploiement est mis à jour, et `curl` sur le NodePort
  renvoie des tâches avec `priority`.

> Pourquoi une fonctionnalité ? Parce qu'une chaîne vide ne prouve rien. On doit voir un
> changement de code apparaître en production, et le pipeline le vérifier au passage.

### Déroulé de l'après-midi

| Heure | Quoi                                                                              |
|-------|-----------------------------------------------------------------------------------|
| 13:00 | Brief (diapositives), tirage des équipes confirmé, questions                      |
| 13:15 | Démarrage. **Premier quart d'heure : plan de répartition écrit**, qui fait quoi   |
| 14:00 | Point formateur 3 min par équipe : où en êtes-vous, qu'est-ce qui bloque ?        |
| 14:30 | Deuxième point. À partir d'ici : **on fige, on intègre, on prépare la démo**      |
| 14:50 | Répétition de la démo (le commit de démo est prêt, le pipeline a déjà tourné)     |
| 15:00 | Présentations, ordre tiré au sort, chronomètre visible                            |

### Conseils

- Répartissez par étape de la chaîne, pas par personne « qui sait tout ».
- Intégrez tôt : un pipeline qui passe à 13:45 vaut mieux qu'un pipeline parfait à 14:55.
- Le commit de démonstration doit être **minuscule** (un texte, une valeur par défaut).
- Si un morceau ne marche pas, dites-le et montrez jusqu'où ça marche. On évalue l'honnêteté
  du diagnostic, pas la perfection.

### Dépannage express

| Symptôme                                              | Piste                                                                                   |
|-------------------------------------------------------|-----------------------------------------------------------------------------------------|
| Le runner ne prend pas le job                         | `sudo systemctl status act_runner`, labels dans `config.yaml`, `runs-on` correspondant  |
| `docker push` refusé                                  | Secret `REGISTRY_TOKEN` dans Gitea, `docker login gitea.formini.local:3000`             |
| `ImagePullBackOff` sur kind                           | Registre non déclaré insecure dans la config kind, ou tag inexistant ; `kind load docker-image` en secours |
| Prometheus ne voit pas l'application kind             | `host.docker.internal:8080` décommenté ? NodePort exposé ? `curl localhost:8080/metrics` |
| Grafana sans tableau de bord                          | Chemin `/var/lib/grafana/dashboards` monté ? JSON valide ? `docker compose logs grafana` |
| Alerte toujours inactive                              | `for:` pas encore écoulé ; vérifier *Status → Rules* pour une erreur de syntaxe         |
| Le pipeline passe mais rien n'est déployé             | Normal : le déploiement automatique est un **bonus**. Montrez la commande `kubectl set image` |

---

## Avant de partir

- [ ] `terraform destroy` sur toute infrastructure AWS encore présente (jour 4)
- [ ] Le dépôt `formini-tasks` est à jour sur Gitea, avec le `README.md`
- [ ] Vous avez cloné le dépôt `formation-devops` (diapositives, fiches, solutions)
- [ ] Questionnaire de retour rendu au formateur
