# Projet final — Grille d'évaluation

**Équipe : ______________________  Évaluateur : ______________________  Heure de passage : ______**

Total sur 100, bonus jusqu'à +10. Noter pendant la présentation, compléter en consultant le dépôt.

## 1. Git et revue de code — 15 points

| Critère                                                        | Points | Note |
|----------------------------------------------------------------|-------:|-----:|
| `main` protégée (pas de push direct, approbation requise)      | 4      |      |
| Au moins une PR fusionnée aujourd'hui avec commentaire de revue | 5      |      |
| Messages de commit conventionnels et historique lisible        | 3      |      |
| Pas de secret, de `.env` ni de binaire dans le dépôt           | 3      |      |

## 2. Conteneurisation — 15 points

| Critère                                                        | Points | Note |
|----------------------------------------------------------------|-------:|-----:|
| Image de base épinglée, dépendances avant le code (cache)      | 4      |      |
| Utilisateur non-root, `HEALTHCHECK`, `.dockerignore`           | 4      |      |
| `compose.yaml` : app + PostgreSQL, healthcheck, volume, env    | 5      |      |
| Taille d'image raisonnable (< 250 Mo) et expliquée             | 2      |      |

## 3. Pipeline CI/CD — 20 points

| Critère                                                        | Points | Note |
|----------------------------------------------------------------|-------:|-----:|
| Déclenché sur push et PR, visible dans l'onglet Actions        | 3      |      |
| Job de test (pytest, lint) qui bloque en cas d'échec           | 5      |      |
| Build et push de l'image taguée `sha-xxxxxxx` dans Gitea       | 6      |      |
| Scan de sécurité (Trivy) présent et lu                         | 3      |      |
| Secrets gérés par Gitea (pas dans le YAML)                     | 3      |      |

## 4. Déploiement Kubernetes — 20 points

| Critère                                                        | Points | Note |
|----------------------------------------------------------------|-------:|-----:|
| Manifests versionnés dans `k8s/`, namespace dédié              | 4      |      |
| Deployment 2 réplicas, probes readiness/liveness, resources    | 5      |      |
| PostgreSQL avec PVC, Secret pour les identifiants              | 3      |      |
| Rolling update démontré (`rollout status`), rollback connu     | 6      |      |
| Application accessible via NodePort, `/health` OK              | 2      |      |

## 5. Supervision — 15 points

| Critère                                                        | Points | Note |
|----------------------------------------------------------------|-------:|-----:|
| Prometheus scrape l'application **déployée** (cible UP)        | 4      |      |
| Tableau de bord provisionné depuis Git, golden signals         | 5      |      |
| Au moins une alerte, déclenchée et résolue pendant la prépa    | 4      |      |
| L'équipe sait lire le tableau de bord pendant la démo          | 2      |      |

## 6. Présentation — 15 points

| Critère                                                        | Points | Note |
|----------------------------------------------------------------|-------:|-----:|
| Timing respecté (10–15 min), rôles répartis                    | 3      |      |
| Démo live d'un commit qui traverse la chaîne                   | 6      |      |
| Clarté de l'architecture présentée                             | 2      |      |
| Honnêteté du bilan (ce qui marche, ce qui a résisté)           | 2      |      |
| Réponses aux questions                                         | 2      |      |

## Bonus — jusqu'à +10

| Critère                                                        | Points | Note |
|----------------------------------------------------------------|-------:|-----:|
| Fonctionnalité `priority` visible en production avec ses tests | +4     |      |
| Déploiement déclenché automatiquement par le pipeline          | +3     |      |
| Alertmanager avec notification, ou tag `v1.0.0` + changelog    | +3     |      |

## Total

| Section                        | / max | Note |
|--------------------------------|------:|-----:|
| 1. Git et revue                | 15    |      |
| 2. Conteneurisation            | 15    |      |
| 3. Pipeline CI/CD              | 20    |      |
| 4. Déploiement Kubernetes      | 20    |      |
| 5. Supervision                 | 15    |      |
| 6. Présentation                | 15    |      |
| Bonus                          | +10   |      |
| **Total**                      | 100   |      |

Commentaire pour l'équipe (deux forces, une piste d'amélioration) :

_______________________________________________________________________________

_______________________________________________________________________________

_______________________________________________________________________________
