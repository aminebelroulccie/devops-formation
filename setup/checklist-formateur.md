# Liste de contrôle formateur

## J-7

- [ ] Compte AWS : utilisateur IAM, politique, budget, quotas (`setup/aws/README.md`).
- [ ] Demande à Formini : 1 VM par participant + 2 VM formateur (démo + secours), Ubuntu Server 24.04, 4 vCPU / 8 GB / 60 GB, IP fixes, accès Internet sortant, port 22 ouvert depuis les postes.
- [ ] Postes Formini : VS Code + extension *Remote - SSH*, client OpenSSH, droits pour éditer le fichier `hosts` (ou utiliser les IP).
- [ ] Liste des participants → `setup/gitea/participants.csv`, équipes de trois.

## J-1

- [ ] Sur chaque VM : `GITEA_IP=<ip-formateur> sudo -E bash setup/install-vm.sh` (≈ 10 min par VM ; lancez-les en parallèle avec `tmux`).
- [ ] VM formateur : Gitea démarré, `bootstrap.sh` exécuté, jeton runner noté.
- [ ] Sur chaque VM : `RUNNER_TOKEN=<jeton> sudo -E bash setup/act-runner/install-runner.sh` ; tous les runners « Idle » dans Gitea.
- [ ] Dépôt `formini/formation-devops` poussé sur Gitea (fiches, code de départ, solutions si vous les publiez).
- [ ] Test de bout en bout sur la VM formateur : cloner `app/formini-tasks`, `pytest`, `docker build`, `docker push` vers le registre, pipeline vert, `kind create cluster`, `kubectl apply`, Prometheus voit la cible.
- [ ] Fiches de poste imprimées (IP VM, identifiant Gitea, mot de passe initial, équipe).
- [ ] Decks ouverts dans le navigateur de la salle, plein écran testé, notes orateur (touche S) sur l'écran formateur.
- [ ] Version PDF des decks générée (`?print-pdf` puis Imprimer → PDF) au cas où.

## Chaque matin

- [ ] Gitea répond, runners « Idle », VM de tous les participants joignables.
- [ ] Reprendre les « points flous » notés la veille (5 minutes).

## Chaque soir

- [ ] Jour 4 et 5 : `bash setup/aws/cleanup-check.sh`, aucune ressource restante.
- [ ] Noter les questions ouvertes et les problèmes rencontrés pour améliorer la fiche.
- [ ] Ne pas éteindre Gitea ni les VM.

## Jour 5

- [ ] Chronomètre pour les soutenances (10–15 min par équipe).
- [ ] Grille d'évaluation imprimée (`ateliers/jour5-supervision-projet/projet-final/GRILLE-EVALUATION.md`).
- [ ] Questionnaire de satisfaction (dans `guide-formateur/jour5.md`).
- [ ] Après 16:00 : clés AWS désactivées.
