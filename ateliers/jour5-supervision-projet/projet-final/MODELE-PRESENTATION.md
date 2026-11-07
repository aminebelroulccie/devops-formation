# Modèle de présentation — Projet final

**Durée : 10 à 15 minutes, questions comprises. Chronomètre visible. Ordre tiré au sort à 15:00.**

Pas de diapositives nécessaires : le projecteur montre votre terminal, Gitea, et Grafana.
Préparez trois onglets de navigateur (Gitea Actions, l'application, Grafana) et un terminal
avec `kubectl` déjà pointé sur le bon namespace.

## 0. Avant de passer (à faire à 14:50)

- [ ] Le commit de démo est préparé sur une branche, **non poussé** : une modification visible
      et sans risque (texte du README, titre dans `static/index.html`, valeur de `APP_VERSION`).
- [ ] Le pipeline a déjà tourné une fois avec succès dans l'heure.
- [ ] `kubectl get pods -n formini-tasks` : tout est Running.
- [ ] `load.sh` tourne en arrière-plan sur l'application déployée pour que Grafana bouge.
- [ ] Un membre de l'équipe est « chef de démo », un autre « chef du temps ».

## 1. L'équipe — 1 minute

Qui a fait quoi. Une phrase par personne. Pas de « on a tout fait ensemble ».

## 2. L'architecture — 2 minutes

Au tableau blanc ou sur un schéma simple :

```
poste → Gitea (PR, main) → act_runner (test, build, scan) → registre Gitea
                                                            ↓
                      Grafana ← Prometheus ← kind (2 pods, NodePort 8080)
```

Dites où tournent les choses (quelle VM, quel port) et ce qui déclenche quoi.

## 3. La démonstration — 6 minutes

Déroulé conseillé, en parlant pendant les temps d'attente :

1. **Avant** : montrer l'application sur le NodePort et sa version dans `/health`.
2. **Le commit** : pousser la branche, ouvrir la PR, un collègue approuve, fusionner.
3. **Le pipeline** : onglet Actions, suivre les jobs. Pendant qu'il tourne, expliquer chaque étape
   et montrer le `ci.yml`. Montrer le rapport Trivy du dernier run.
4. **L'image** : onglet Packages de Gitea, le tag `sha-…` vient d'apparaître.
5. **Le déploiement** : `kubectl set image …` (ou le job deploy), puis
   `kubectl rollout status deployment/tasks -n formini-tasks`.
   Montrer `kubectl get pods -w` : les anciens pods s'arrêtent après que les nouveaux sont prêts.
6. **Après** : `/health` renvoie la nouvelle version. La fonctionnalité `priority` est visible
   dans `curl …/api/tasks`.
7. **La supervision** : Grafana, le trafic du générateur, le p95, le taux d'erreur. Montrer la règle
   d'alerte et dire comment vous l'avez testée.

Si quelque chose casse : respirez, ouvrez les logs (`kubectl logs`, Actions), diagnostiquez
à voix haute. C'est noté positivement.

## 4. Le bilan — 2 minutes

- Ce qui a résisté le plus, et comment vous l'avez résolu.
- Ce que vous feriez différemment avec une journée de plus.
- Ce que vous allez ramener dans votre équipe lundi.

## 5. Questions — 3 minutes

Les autres équipes et le formateur posent des questions. Questions probables :

- Que se passe-t-il si un test échoue ? Montrez-le si vous avez le temps.
- Comment revenir en arrière après un mauvais déploiement ?
- Où est stocké le mot de passe PostgreSQL ? Le token du registre ?
- Pourquoi `rate()` et pas la valeur brute du compteur ?
- Que faudrait-il pour passer de kind à EKS ?
