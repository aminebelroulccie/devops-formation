# Guide formateur — Jour 1 : Fondamentaux DevOps et Git

**Dimanche 08 novembre 2026 · 09:00 – 16:00**
Support : `slides/jour1-devops-git.html` (touche **S** pour les notes orateur, **F** plein écran, **Échap** vue d'ensemble).
Fiche participants : `ateliers/jour1-linux-git/README.md`.

## La veille (voir aussi `setup/checklist-formateur.md`)

- [ ] Toutes les VM participants répondent en SSH avec le compte `ubuntu` (mot de passe sur fiche de poste).
- [ ] `setup/install-vm.sh` exécuté sur chaque VM (Docker, Git, Ansible, Terraform, kubectl, kind, Node, trivy).
- [ ] Gitea démarré sur la VM formateur (`setup/gitea/`), accessible depuis les postes : `http://gitea.formini.local:3000`. Comptes participants et organisations `equipe-a…` créés (`setup/gitea/bootstrap.sh`).
- [ ] Dépôt `formation-devops` poussé sur Gitea avec le contenu de ce dossier (le code de départ est dans `app/formini-tasks`).
- [ ] Fiches de poste imprimées : IP de la VM, identifiant Gitea, mot de passe initial, nom d'équipe.
- [ ] Projecteur testé avec le deck en plein écran ; police lisible du fond de la salle (zoom navigateur si besoin).
- [ ] Vous avez une VM « formateur » propre pour les démonstrations, plus une VM de secours.

## Déroulé minute par minute

### 09:00 – 09:15 · Accueil (diapos 1–3)

- Présentez-vous en une minute. Tour de table : prénom, poste, un outil déjà utilisé. Notez mentalement qui connaît Git : vous les utiliserez comme relais dans les équipes.
- Diapo 2 : montrez le fil rouge. Dites clairement : *« Tout ce que vous faites aujourd'hui sert demain. Le dépôt que vous créez cet après-midi est celui que l'on conteneurise lundi. »*
- Logistique : pauses, repas, machines Formini uniquement, pas d'atelier sur les portables.

### 09:15 – 09:50 · Le DevOps (diapos 4–10)

Points à faire passer, dans l'ordre :

1. **Le mur** (diapo 5) : racontez un déploiement raté vécu. Demandez à la salle : *« Qui a déjà entendu “ça marche sur ma machine” ? »* Faites réagir avant d'expliquer.
2. **Définition** (diapo 6) : insistez sur l'ordre culture → pratiques → outils. *« On peut acheter Kubernetes et ne rien changer. »*
3. **CALMS** (diapo 7) : reliez chaque lettre à un jour de la semaine.
4. **La boucle** (diapo 8) : question à la salle : *« Chez vous, combien de temps entre un commit et la production ? »* Notez les réponses au tableau, vous y reviendrez jeudi.
5. **DORA** (diapo 9) : le message contre-intuitif, vitesse et stabilité vont ensemble.
6. **Fil rouge** (diapo 10) : ouvrez Gitea au projecteur, montrez le dépôt `formation-devops`, le dossier `app/formini-tasks`. Lancez l'application sur votre VM pour montrer l'interface :
   ```bash
   cd ~/formini-tasks && python3 -m venv .venv && . .venv/bin/activate
   pip install -r requirements-dev.txt && python app.py
   ```
   Ouvrez `http://<ip-formateur>:5000`, ajoutez une tâche, montrez `/health` et `/metrics`. *« Simple exprès. »*

### 09:50 – 10:30 · Linux essentiel (diapos 11–15)

Démonstration en direct sur la VM formateur, projecteur sur le terminal (police 18 minimum).

- **Arborescence** (12) : `ls /etc/ssh`, `tail -f /var/log/syslog` pendant que vous lancez `sudo systemctl restart ssh` dans une autre fenêtre : le journal bouge, effet garanti.
- **Permissions** (13) : faites calculer 750 et 644 à voix haute. Démo de l'erreur `UNPROTECTED PRIVATE KEY FILE` : `chmod 644 ~/.ssh/id_ed25519 && ssh vm`, puis corrigez. C'est la panne n°1 de l'atelier.
- **Processus et services** (14) : `sudo systemctl stop docker`, `docker ps` échoue, `systemctl status docker`, `journalctl -u docker -n 20`, `systemctl start docker`. Nommez le réflexe en trois commandes.
- **SSH** (15) : dessinez au tableau poste → serveur, clé privée / publique. Ne faites pas l'atelier à leur place : montrez `ssh-keygen` seulement.

Si vous êtes en retard à 10:25, sautez la démo processus (14) : elle est reprise dans la fiche.

### 10:30 – 10:45 · Pause

### 10:45 – 12:00 · Atelier guidé SSH (diapo 16 + fiche partie 1)

- Affichez la diapo 16, puis laissez la fiche ouverte au projecteur (section 1.4 : le fichier de surcharge).
- Rythme : 1.1–1.2 en 20 min, 1.3 en 20 min, 1.4 en 20 min, 1.5 en 15 min.
- Passez dans la salle. Pannes fréquentes :
  - permissions `.ssh` / `authorized_keys` → `chmod 700` / `600` ;
  - `ssh-copy-id` lancé **sur la VM** au lieu du poste ;
  - `sshd -t` oublié, service redémarré avec une faute de frappe → console Formini ;
  - `ssh vm` qui demande un mot de passe → mauvais `User` dans `~/.ssh/config`.
- À 11:45, vérifiez que tout le monde a au moins 1.4 terminé : c'est indispensable pour Ansible mercredi. Les bonus occupent les rapides.

### 12:00 – 13:00 · Déjeuner

### 13:00 – 14:00 · Git et Gitea (diapos 17–27)

Démonstration continue sur votre VM, en parallèle des diapos :

1. **Trois zones** (18) : `git init`, créez un fichier, `git status` entre chaque étape. Montrez `git diff` puis `git diff --staged`.
2. **Commandes** (19) : deux commits, `git log --oneline --graph`. Ajoutez un `.gitignore` avec `.env` : *« on en reparle mardi avec les secrets »*.
3. **Branches** (20) : métaphore du post-it. `git switch -c feature/x`, un commit, `git lg` (alias dans la fiche solution).
4. **Fusions** (21) : montrez un fast-forward, puis créez un commit sur `main` et refaites un merge : commit de fusion. Règle d'or au tableau : *« on rebase ses branches locales, on merge dans main »*.
5. **Conflits** (22) : lancez `bash ateliers/jour1-linux-git/solution/conflit-demo.sh`, ouvrez le fichier dans VS Code, résolvez avec les boutons, `git add`, `git commit`. Dédramatisez : *« Git demande un arbitrage, c'est tout. »*
6. **Distant** (23) : créez un dépôt sur Gitea en direct, `git remote add`, `git push -u`. Montrez le bouton *Clone*.
7. **Flux et protection** (25) : Settings → Branches → protection de `main`. Montrez un `git push origin main` refusé.
8. **PR et revue** (25–26) : demandez un volontaire : il pousse une branche, ouvre une PR, vous commentez une ligne, demandez un changement, il corrige, vous approuvez, il fusionne. Cinq minutes, très efficace.
9. **Conventions** (27) : montrez un `git log` illisible vs conventionnel.

### 14:00 – 15:30 · Défi en autonomie (diapo 28 + fiche partie 2)

- Formez les équipes de trois **maintenant** et annoncez qu'elles restent les mêmes jusqu'au projet final de jeudi. Mélangez les niveaux.
- Chaque équipe a une organisation Gitea prête (`equipe-a`, `equipe-b`…). Vérifiez que chacun est membre (bootstrap).
- Jalons à annoncer à voix haute : 14:20 dépôt poussé et `main` protégée ; 14:50 trois PR ouvertes ; 15:10 toutes fusionnées ; 15:30 conflit résolu.
- Allez voir chaque équipe **au moment du conflit** (2.5) : c'est là que les questions arrivent. Ne touchez pas au clavier, posez des questions : *« Que dit git status ? Quelle version voulez-vous garder ? »*
- À 15:20, demandez à une équipe de projeter son `git log --oneline --graph` et de commenter.
- Équipes en avance : bonus (tag, CODEOWNERS, modèle de PR).
- Équipe bloquée sur le push HTTP (mot de passe redemandé) : `git config --global credential.helper store`.

### 15:30 – 16:00 · Bilan (diapos 29–30)

- Tour de table express : *une chose apprise, une chose encore floue*. Notez les points flous, vous ouvrirez demain matin avec.
- Annoncez demain : Docker, on conteneurise `formini-tasks`. **Ne pas éteindre les VM** ; Gitea doit rester accessible.
- Rappel aux équipes : le dépôt `formini-tasks` de l'équipe doit être propre (main fusionnée, tests verts), demain on part de là.

## Si vous avez trop de temps

- Diapo 14 : `htop`, `ss -tlnp` commentés.
- Git : `git stash`, `git cherry-pick`, `git bisect` en démonstration rapide.
- Discussion : *« Qu'est-ce qui empêcherait votre équipe de déployer tous les jours ? »*

## Si vous manquez de temps

- Sautez la démo processus (14) et la diapo conventions (27) : la fiche les couvre.
- Le bonus de l'atelier SSH et le bonus Git sont facultatifs.
- Le conflit (2.5) est la seule partie du défi qui ne doit pas être sautée.
