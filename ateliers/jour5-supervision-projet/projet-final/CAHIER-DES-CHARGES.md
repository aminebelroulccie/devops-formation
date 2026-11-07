# Projet final — Cahier des charges

**Formation DevOps Formini · Jeudi 12 novembre 2026 · 13:15 – 15:00, présentations à 15:00**

## 1. Objet

Chaque équipe (celles formées le jour 1) assemble, sur l'application **Formini Tasks**,
une chaîne DevOps complète et fonctionnelle :

```
code  →  test  →  build  →  déploiement  →  supervision
```

Le résultat est démontré en direct : un commit poussé sur `main` déclenche le pipeline,
produit une image, met à jour le déploiement Kubernetes, et le changement est visible
dans l'application et dans Grafana.

## 2. Périmètre

### 2.1 Obligatoire

| Étape            | Exigence                                                                                                          |
|------------------|-------------------------------------------------------------------------------------------------------------------|
| **Code**         | Dépôt `formini-tasks` dans l'organisation Gitea de l'équipe. `main` protégée (pas de push direct, 1 approbation). Au moins une PR fusionnée aujourd'hui, avec au moins un commentaire de revue. Messages de commit conventionnels. |
| **Test**         | `pytest` exécuté par le pipeline à chaque push et à chaque PR. Un test en échec bloque la fusion.                 |
| **Build**        | `Dockerfile` propre : image de base épinglée, dépendances installées avant le code (cache), utilisateur non-root, `HEALTHCHECK`. Image construite par le pipeline, scannée (Trivy), publiée dans le registre Gitea avec le tag `sha-<7 premiers caractères>` et `latest`. |
| **Compose**      | `compose.yaml` qui lance application + PostgreSQL en local avec `docker compose up -d`.                           |
| **Déploiement**  | Manifests dans `k8s/` : Namespace, Secret, PostgreSQL (Deployment + Service + PVC), application (Deployment 2 réplicas, probes readiness/liveness, resources), Service NodePort 8080. Mise à jour progressive démontrée (`kubectl rollout status`), retour arrière connu (`kubectl rollout undo`). |
| **Supervision**  | `monitoring/` : Prometheus scrape l'application déployée (NodePort ou Compose), Grafana provisionné avec un tableau de bord versionné (golden signals), au moins une règle d'alerte testée (déclenchée puis résolue pendant la préparation). |
| **Fonctionnalité** | Le champ `priority` (voir §3) développé sur une branche, relu, fusionné, testé, construit, déployé et visible en production. |
| **README**       | Comment lancer l'ensemble depuis une VM vierge, en moins de 10 commandes. Qui a fait quoi.                        |

### 2.2 Bonus (jusqu'à +10 points)

- Déploiement sur kind **déclenché par le pipeline** (job `deploy` avec `kubectl set image`, kubeconfig en secret).
- Alertmanager configuré avec une notification réelle (mail local, webhook, Slack de test).
- Tag Git `v1.0.0` et image taguée de même, changelog généré depuis les commits.
- Terraform : l'EC2 du jour 4 provisionnée et configurée par Ansible pour héberger l'application en Compose, détruite avant 16:00.

### 2.3 Hors périmètre

Interface utilisateur, authentification, HTTPS, haute disponibilité de PostgreSQL. On évalue la chaîne, pas le produit.

## 3. La fonctionnalité « priority »

| Élément          | Spécification                                                                                   |
|------------------|-------------------------------------------------------------------------------------------------|
| Modèle           | `Task.priority` : entier, 1 = haute, 2 = normale (défaut), 3 = basse. Valeurs hors 1–3 refusées (400). |
| `POST /api/tasks`| Accepte `priority` optionnel.                                                                   |
| `PUT /api/tasks/<id>` | Accepte `priority`.                                                                        |
| `GET /api/tasks` | Renvoie `priority` ; `?priority=1` filtre.                                                      |
| `to_dict()`      | Inclut `priority`.                                                                              |
| Tests            | Création avec priorité, valeur par défaut, valeur invalide, filtre.                             |
| Métriques (bonus)| `tasks_open` déclinée par label `priority`.                                                     |

Note : `db.create_all()` ne modifie pas une table existante. Sur un volume PostgreSQL déjà créé,
supprimez-le (`docker compose down -v`) ou ajoutez la colonne à la main. C'est une vraie
contrainte de production : dites comment vous l'avez gérée.

## 4. Livrables

1. Le dépôt Gitea `equipe-x/formini-tasks` à jour à 15:00 (ce qui est poussé après n'est pas évalué).
2. La démonstration en direct (10–15 min, voir `MODELE-PRESENTATION.md`).
3. Le `README.md` à la racine du dépôt.

## 5. Évaluation

Voir `GRILLE-EVALUATION.md`. Total sur 100, bonus jusqu'à +10.

## 6. Contraintes

- Tout tourne sur les VM Formini. Aucun service public (GitHub, Docker Hub en push) n'est utilisé.
- Les secrets (token de registre, kubeconfig, mot de passe PostgreSQL) ne sont **jamais** dans Git.
- Les ressources AWS éventuelles sont détruites avant 16:00.
- À 15:00, on présente ce qui existe. Pas de prolongation.

## 7. Points de contrôle avec le formateur

- 14:00 : plan de répartition, état du pipeline.
- 14:30 : état du déploiement et de la supervision, décision de ce que l'on fige.
- 14:50 : répétition de la démo. Le commit de démonstration est prêt et **n'a pas encore été poussé**.
