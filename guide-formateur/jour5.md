# Guide formateur — Jour 5 : Supervision et projet final

**Jeudi 12 novembre 2026 · 09:00 – 16:00**
Diapositives : `slides/jour5-supervision-projet.html` (touche `S` pour les notes, `?print-pdf` pour l'export)
Fiche participants : `ateliers/jour5-supervision-projet/README.md`
Solution : `ateliers/jour5-supervision-projet/solution/monitoring/`
Projet : `ateliers/jour5-supervision-projet/projet-final/`

---

## La veille (mercredi soir, 20 minutes)

- [ ] **Images pré-tirées sur la VM formateur et, si possible, sur chaque VM participant** (sinon le `compose up` de 10:45 sature la connexion) :
  ```bash
  for i in prom/prometheus:v2.55.1 grafana/grafana:11.3.1 prom/node-exporter:v1.8.2 gcr.io/cadvisor/cadvisor:v0.49.1; do docker pull $i; done
  ```
  Astuce : un script dans `setup/` peut le faire en boucle sur toutes les VM par SSH.
- [ ] **Tester la pile complète** sur la VM formateur : application Compose du jour 2 lancée, puis `monitoring/` lancé, quatre cibles UP, dashboard visible dans Grafana sous le dossier *Formini*, `AppDown` déclenchée avec `docker compose stop web` puis résolue.
- [ ] **Vérifier le JSON du dashboard** : `python3 -m json.tool formini-tasks.json > /dev/null`, et `promtool check rules alerts.yml`.
- [ ] **Vérifier le port 3001** libre (Gitea occupe 3000). Et 8081 pour cAdvisor (8080 est le NodePort kind).
- [ ] **Cluster kind formateur** encore debout avec l'application déployée, pour la démo bonus et la démo du projet.
- [ ] **Imprimer** : cahier des charges (1 par équipe), grille d'évaluation (1 par équipe + 1 pour vous par équipe), questionnaire de retour (1 par participant).
- [ ] **Préparer le tirage au sort** de l'ordre de passage (papiers pliés, ou `shuf`).
- [ ] **Chronomètre** affichable au projecteur (un onglet navigateur suffit).
- [ ] **AWS** : vérifier dans la console qu'aucune instance du jour 4 ne tourne encore ; noter celles qui restent pour les faire détruire à 09:05.

---

## 08:45 – 09:00 · Installation

Projecteur, diapositive de couverture, VM formateur ouverte avec trois onglets : Prometheus (9090), Grafana (3001), Gitea. Un terminal avec `load.sh` prêt mais non lancé.

## 09:00 – 09:10 · Accueil (diapos 1–3)

- Demander : « Qui a encore un cluster kind qui tourne ? Qui a encore une instance AWS ? » → faire lancer `terraform destroy` tout de suite à ceux qui en ont.
- Rappeler que les équipes du jour 1 sont celles du projet. Annoncer sans détour : « À 15:00 pile, on présente, fini ou pas. »
- Lire l'agenda. Préciser que la théorie du matin est courte : 1h20, puis pratique.

## 09:10 – 10:30 · Théorie Prometheus (diapos 4–14)

**Diapo 5 — Pourquoi superviser.** Question à la salle : « Comment apprenez-vous qu'un service est tombé, aujourd'hui ? » Laisser venir « un utilisateur appelle ». Relier au MTTR de DORA (jour 1) : détecter avant de réparer.

**Diapo 6 — Trois piliers.** Métaphore voiture : tableau de bord / carnet d'entretien / caméra embarquée. On fait les métriques aujourd'hui parce que ce sont elles qui réveillent quelqu'un.

**Diapo 7 — Golden signals.** Annoncer que le tableau de bord de 11h suit exactement cette structure. Formini Tasks expose déjà latence, trafic et erreurs ; la saturation viendra des exporters.

**Diapo 8 — SLI/SLO.** Ne pas s'étendre. Message unique : on alerte sur un symptôme utilisateur (erreurs, latence), pas sur une cause (CPU). Le CPU va sur le dashboard, pas dans le téléphone de l'astreinte.

**Diapo 9 — Architecture pull.** Dessiner les flèches au tableau dans le sens Prometheus → cibles. Pourquoi pull : la cible disparue se voit (`up == 0`), aucune config côté application, pas de file d'attente.

**Diapo 10 — Format d'exposition. DÉMO 1 (5 min).**
```bash
cd ~/formini-tasks && docker compose up -d
curl -s localhost:5000/metrics | grep -v '^#' | head -20
```
Puis ouvrir `app.py` dans VS Code, montrer `Counter`, `Histogram`, `Gauge` et le `after_request`. Insister : « jamais un identifiant utilisateur en label » (cardinalité).

**Diapo 11 — Types.** Faire deviner : « Le nombre de tâches ouvertes, c'est quoi ? » (gauge). « Le nombre de requêtes depuis le démarrage ? » (counter). « Pour un percentile de latence ? » (histogram, seaux cumulatifs, label `le`).

**Diapo 12 — PromQL. DÉMO 2 (10 min).** Lancer d'abord le trafic dans un terminal visible :
```bash
./monitoring/load.sh http://localhost:5000 1200
```
Dans Prometheus, onglet Graph, taper dans l'ordre :
```promql
up
http_requests_total
sum(rate(http_requests_total[2m]))
sum by (endpoint) (rate(http_requests_total[2m]))
100 * sum(rate(http_requests_total{status=~"4.."}[5m])) / sum(rate(http_requests_total[5m]))
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))
```
Montrer la courbe brute du compteur qui monte sans fin, puis `rate()`. Utiliser `4..` et non `5..` pour que le taux soit non nul (load.sh produit des 404). Puis :
```bash
docker compose stop web     # dans ~/formini-tasks
```
Revenir sur `up` : la série passe à 0 en moins de 30 s. Relancer `docker compose start web`.

**Diapo 13 — Exporters.** Ouvrir *Status → Targets* : quatre lignes vertes. Taper une requête node_exporter et une cAdvisor. Mentionner qu'il existe un exporter PostgreSQL, Gitea, nginx.

**Diapo 14 — Alertes.** Ouvrir *Alerts*. Expliquer inactive / pending / firing et le rôle de `for`. Dire qu'Alertmanager n'est pas déployé aujourd'hui (bonus du projet), mais que Grafana sait aussi notifier.

## 10:30 – 10:45 · Pause

Vérifier pendant la pause que les images sont bien présentes sur deux ou trois VM participants (`docker images | grep -E 'prometheus|grafana'`).

## 10:45 – 11:00 · Théorie Grafana (diapos 15–18)

**Diapo 16 — DÉMO 3 (5 min).** Ouvrir Grafana, le dashboard *Formini Tasks — Golden signals*. Lire la ligne du haut depuis le fond de la salle. Éditer le panneau « Latence p95 » pour montrer que c'est la même requête que tout à l'heure. Changer la variable *Application* si le job kind est activé.

**Diapo 17 — Provisioning.** Montrer le dossier `monitoring/grafana/` dans VS Code. Parallèle avec Terraform et Kubernetes : l'état désiré est dans un fichier, en Git, relu en PR.

**Diapo 18 — Compose.** Ne pas lire le YAML. Pointer : volumes montés depuis Git, réseau externe `formini-tasks_default`, port 3001, `host.docker.internal` pour le NodePort kind.

## 11:00 – 12:00 · Atelier guidé (diapo 19)

Projeter la diapo 19 et laisser les participants dérouler la partie 1 de la fiche. Circuler.

**Pannes attendues et réponses :**

| Panne                                                           | Réponse                                                                                               |
|-----------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| `network formini-tasks_default declared as external, but could not be found` | L'application du jour 2 n'est pas lancée, ou le dossier s'appelle autrement : `docker network ls`, adapter `networks.app.name`. |
| Cible `formini-tasks` DOWN                                       | Même cause. Ou le service ne s'appelle pas `web` dans leur compose : adapter `targets`.               |
| cAdvisor redémarre en boucle                                     | Volumes manquants ou `/dev/kmsg` absent : retirer la ligne `devices`, relancer.                       |
| Port 3001 déjà utilisé                                           | `ss -tlnp | grep 3001`, changer le port côté hôte.                                                    |
| Dashboard absent dans Grafana                                    | `docker compose logs grafana | grep -i dashboard` : JSON invalide après export maladroit ; `python3 -m json.tool`. |
| Taux d'erreur 5xx à 0                                            | Normal. Expliquer 4xx vs 5xx, faire le bonus `stop db` pour de vrais 503.                             |
| `AppDown` reste pending                                          | `for: 1m` : attendre. Montrer *Status → Rules* pour vérifier que la règle est chargée.                |

À 11:40, demander à une équipe de montrer son alerte en *firing* au projecteur. À 11:55, rappeler que la PR `feat/monitoring` doit être ouverte : elle compte pour le projet.

## 12:00 – 13:00 · Déjeuner

Pendant le déjeuner : vérifier que votre propre chaîne de démonstration du projet (commit → pipeline → kind → Grafana) fonctionne. Vous en aurez besoin si une équipe veut voir « à quoi ça ressemble quand ça marche ».

## 13:00 – 13:15 · Brief du projet final (diapos 20–24)

- Diapo 21 : la phrase clé, « un commit sur main finit en production supervisée sans clic ». Le champ `priority` est le traceur.
- Diapo 22 : lire les cinq livrables, distribuer le cahier des charges imprimé.
- Diapo 23 : la grille. Dire clairement : « On note la chaîne, pas le code Python. Une chaîne honnête jusqu'au build vaut des points. Une démo qui "marchait tout à l'heure" n'en vaut pas. »
- Diapo 24 : format de soutenance, points de contrôle à 14:00 et 14:30, répétition à 14:50.
- Demander à chaque équipe de nommer un chef de démo et un chef du temps avant 13:20.

## 13:15 – 15:00 · Projet final en équipe

**Votre rôle : débloquer, pas faire.** Trois tournées :

**13:20 – 13:35, tournée 1 : le plan.** Chaque équipe doit avoir écrit (tableau, fichier) qui fait quoi. Si une équipe « commence par la fonctionnalité », la recadrer : d'abord faire passer la chaîne existante de bout en bout, ensuite la fonctionnalité.

**14:00, point 1 (3 min par équipe, chronométré).** Questions : le pipeline est-il vert ? L'image est-elle dans le registre ? Qu'est-ce qui bloque ? Donner une piste, pas une solution. Noter l'état sur votre feuille.

**14:30, point 2.** « Qu'est-ce que vous figez maintenant ? » Pousser les équipes à arrêter d'ajouter et à intégrer. Celles qui n'ont pas de déploiement fonctionnel : leur dire de montrer Compose + supervision Compose, c'est accepté.

**14:50.** Passer dire « répétition de démo » à chaque équipe. Vérifier que le commit de démo existe et n'est pas poussé.

**Si une équipe est bloquée dur :**

| Blocage                                    | Déblocage rapide                                                                              |
|--------------------------------------------|-----------------------------------------------------------------------------------------------|
| Runner mort                                | `sudo systemctl restart act_runner`, vérifier le label dans `runs-on`.                        |
| Push registre refusé                       | Refaire le token Gitea (scope `write:package`), secret `REGISTRY_TOKEN`, `docker login`.       |
| `ImagePullBackOff`                         | Dépannage express : `kind load docker-image <image> --name formini`, continuer.               |
| Prometheus ne voit pas kind                | Décommenter le job `formini-tasks-k8s`, `curl -X POST localhost:9090/-/reload`.               |
| Migration `priority` sur PostgreSQL existant | `docker compose down -v` en Compose ; sur kind, `kubectl exec` + `ALTER TABLE tasks ADD COLUMN priority INTEGER DEFAULT 2`. Leur faire noter ça pour le bilan. |
| Équipe en conflit                          | Séparer physiquement les tâches : un sur le pipeline, un sur kind, un sur monitoring, intégration à 14:30. |

## 15:00 – 15:45 · Présentations

- Tirer l'ordre au sort devant tout le monde. Lancer le chronomètre à chaque passage, visible.
- Vous tenez la grille (`GRILLE-EVALUATION.md`) ; remplir les sections 1 à 5 pendant la démo, la 6 juste après.
- Avec 4 équipes : 11 min chacune, pas plus. Couper poliment à 11 min, laisser 1 question.
- Encourager les questions des autres équipes. Si la salle est molle : « un point bonus à la meilleure question ».
- Ne pas commenter les notes en public. Donner à chaque équipe deux forces et une piste, à l'oral, en 30 secondes.
- Si une démo casse : laisser 90 secondes de diagnostic à voix haute, puis demander de passer à la suite. Noter positivement le diagnostic.

Après la dernière équipe : ramasser ou prendre en photo les grilles, les remettre aux équipes en fin de journée avec le commentaire.

## 15:45 – 16:00 · Clôture (diapos 25–29)

**Synthèse (diapo 26), 4 minutes.** Reprendre le cycle infini du jour 1 au tableau et cocher chaque étape avec le jour correspondant. Trame :

> « Lundi, on a dit que le DevOps n'était ni un outil ni un poste. Cette semaine, vous avez pourtant appris huit outils. Aucun pour lui-même : Git pour la revue, Docker pour la reproductibilité, Gitea Actions pour tester à chaque commit, Terraform et Ansible pour une infrastructure que l'on relit, Kubernetes pour déployer sans interrompre, Prometheus et Grafana pour voir avant l'utilisateur. Chaque outil sert une pratique. Chaque pratique sert une seule idée : livrer plus souvent, plus petit, et dormir la nuit. »

**Et après (diapo 27), 3 minutes.** Tour de table express : « La pratique que vous mettez en place le mois prochain, en un mot. » Noter au tableau. L'engagement à voix haute compte.

**Retours (diapo 28), 5 minutes.** Distribuer le questionnaire ci-dessous, laisser 4 minutes de silence, ramasser. Puis tour de table : une chose que vous ferez différemment lundi.

**Diapo 29.** Remercier. Rappeler : cloner `formation-devops`, `terraform destroy`, VM laissées propres.

### Questionnaire de retour (à imprimer, anonyme)

```
Formation DevOps Formini — 8 au 12 novembre 2026 — Vos retours (anonyme)

1. Le rythme global était :   □ trop rapide   □ juste   □ trop lent

2. Pour chaque journée, de 1 (peu utile) à 5 (très utile) :
   J1 DevOps/Linux/Git ___   J2 Docker ___   J3 CI/CD ___   J4 IaC/Kubernetes ___   J5 Supervision/projet ___

3. La part de pratique (ateliers, projet) était :   □ insuffisante   □ juste   □ trop importante

4. Un sujet ou un outil qui manquait : ____________________________________________

5. Ce que vous allez mettre en place dans votre équipe : ___________________________

6. Un conseil pour la prochaine session : _________________________________________

7. Recommanderiez-vous cette formation ?   □ oui   □ oui avec réserves   □ non
   Pourquoi : _______________________________________________________________________
```

---

## Après 16:00 · Vérifications formateur

- [ ] **AWS** : console → EC2, VPC, EKS dans la région de formation : aucune ressource restante. Vérifier *Billing → Budgets* le lendemain.
- [ ] Les VM participants peuvent être laissées telles quelles ou réinitialisées selon la consigne Formini.
- [ ] Sauvegarder les grilles remplies et les questionnaires ; saisir les notes dans un tableau (équipe, sections 1–6, bonus, total).
- [ ] Noter dans ce guide les pannes rencontrées aujourd'hui et le temps réel de chaque séquence, pour la prochaine session.
- [ ] Envoyer aux participants, sous 48 h : lien vers le dépôt `formation-devops`, les grilles commentées, et les pistes « pour aller plus loin » de la diapo 27.
