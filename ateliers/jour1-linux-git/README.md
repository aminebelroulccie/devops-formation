# Jour 1 — Atelier : Linux, SSH et Git en équipe

**Durée :** 10:45 – 12:00 (atelier guidé) puis 14:00 – 15:30 (défi en autonomie)
**Machine :** votre VM Formini (Ubuntu Server 24.04, utilisateur initial `ubuntu`) et votre poste Formini (VS Code + terminal).

## Objectifs

À la fin de cet atelier vous saurez :

- créer un utilisateur de travail sur un serveur Linux et lui donner les bons droits ;
- vous connecter à ce serveur en SSH **par clé**, sans mot de passe, et durcir la configuration ;
- collaborer à trois sur un dépôt Git hébergé sur Gitea : branches, pull requests, revue, résolution de conflit.

## Prérequis

- L'adresse IP de votre VM (affichée sur la fiche de poste, ex. `192.168.10.21`).
- L'adresse de Gitea : `http://gitea.formini.local:3000` (compte créé par le formateur, mot de passe initial sur la fiche de poste).
- Votre équipe de trois et le nom de son organisation Gitea (`equipe-a`, `equipe-b`, …).

---

## Partie 1 — Un serveur Linux accessible en SSH (atelier guidé)

### 1.1 Première connexion et repérage

Depuis le terminal du poste Formini :

```bash
ssh ubuntu@192.168.10.21        # mot de passe sur la fiche de poste
```

Une fois connecté :

```bash
hostnamectl                     # nom et version du système
whoami && id                    # qui suis-je, dans quels groupes
df -h /                         # espace disque
free -h                         # mémoire
ss -tlnp                        # ports en écoute : 22 doit apparaître
sudo tail -n 20 /var/log/auth.log   # votre propre connexion est tracée
```

> Prenez l'habitude : `systemctl status <service>`, `journalctl -u <service>`, `ss -tlnp`. Ce sont les trois commandes de diagnostic de la semaine.

### 1.2 Créer l'utilisateur de travail `devops`

```bash
sudo adduser devops                   # choisissez un mot de passe simple, il sera désactivé en SSH
sudo usermod -aG sudo devops          # droits d'administration
sudo usermod -aG docker devops        # Docker (installé par le formateur) — utile dès demain
id devops                             # vérifier : groupes sudo et docker
```

Vérifiez que `devops` peut utiliser `sudo` :

```bash
sudo -iu devops
sudo -v && echo "sudo OK"
exit
```

### 1.3 Générer une clé SSH sur le poste et l'installer sur la VM

Sur le **poste Formini** (nouvelle fenêtre de terminal, pas sur la VM) :

```bash
ssh-keygen -t ed25519 -C "prenom.nom@formini"
# Entrée pour l'emplacement par défaut, passphrase facultative
ssh-copy-id devops@192.168.10.21      # saisir le mot de passe de devops une dernière fois
ssh devops@192.168.10.21              # doit se connecter sans mot de passe
```

Ce qu'a fait `ssh-copy-id` sur la VM :

```bash
ls -la ~/.ssh                 # drwx------ (700) pour .ssh
cat ~/.ssh/authorized_keys    # votre clé publique, une ligne
```

Si les permissions sont différentes, corrigez-les, sinon SSH refusera la clé :

```bash
chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
```

Simplifiez-vous la vie sur le poste, dans `~/.ssh/config` :

```
Host vm
  HostName 192.168.10.21
  User devops
  IdentityFile ~/.ssh/id_ed25519
```

Désormais `ssh vm` suffit. VS Code (extension *Remote - SSH*) lit aussi ce fichier.

### 1.4 Durcir le serveur SSH

> **Règle de sécurité de l'atelier :** gardez une session `ssh vm` ouverte en permanence pendant cette étape. Testez toujours dans une **deuxième** fenêtre avant de fermer la première.

Sur la VM, créez un fichier de surcharge (plus propre que d'éditer `sshd_config`) :

```bash
sudo tee /etc/ssh/sshd_config.d/50-formini.conf > /dev/null <<'EOF'
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
MaxAuthTries 3
X11Forwarding no
EOF
sudo sshd -t && echo "configuration valide"     # TOUJOURS tester avant de redémarrer
sudo systemctl restart ssh
```

Vérifiez depuis le poste, dans une nouvelle fenêtre :

```bash
ssh vm                                  # fonctionne (clé)
ssh -o PubkeyAuthentication=no vm       # doit être refusé : "Permission denied (publickey)"
```

### 1.5 Autoriser un collègue

Échangez votre clé **publique** (`cat ~/.ssh/id_ed25519.pub` sur le poste) avec un membre de votre équipe, par le chat Gitea ou un fichier partagé. Sur votre VM :

```bash
echo "ssh-ed25519 AAAA... collegue@formini" >> ~/.ssh/authorized_keys
```

Votre collègue doit pouvoir faire `ssh devops@<votre-ip>`. Faites de même chez lui. Puis **révoquez** l'accès en supprimant la ligne : c'est tout l'intérêt des clés.

### Bonus (si vous avez fini en avance)

- Installez `fail2ban` (`sudo apt install -y fail2ban`) et observez `sudo fail2ban-client status sshd`.
- Changez le port d'écoute (`Port 2222` dans le fichier de surcharge, `sshd -t`, restart, puis `ssh -p 2222 vm`).
- Lisez les tentatives de connexion : `sudo grep "Failed\|Accepted" /var/log/auth.log`.

---

## Partie 2 — Dépôt partagé, branches et pull requests (défi en autonomie)

**Par équipe de trois.** Désignez rapidement : la personne A (API), la personne B (tests), la personne C (documentation). Tout le monde travaille sur sa VM (`ssh vm`), le dépôt est sur Gitea.

### 2.1 Préparer l'identité Git (chacun, sur sa VM)

```bash
git config --global user.name  "Prénom Nom"
git config --global user.email "prenom.nom@formini.tn"
git config --global init.defaultBranch main
git config --global pull.rebase true
```

### 2.2 Initialiser le dépôt (personne A uniquement)

1. Sur Gitea, dans l'organisation de l'équipe, créez le dépôt `formini-tasks` (**vide**, sans README).
2. Récupérez le code de départ fourni par le formateur (dossier `app/formini-tasks` du dépôt `formation-devops`), puis :

```bash
cd ~/formini-tasks
git init
git add .
git commit -m "chore: code de départ Formini Tasks"
git remote add origin http://gitea.formini.local:3000/equipe-a/formini-tasks.git
git push -u origin main
```

3. Sur Gitea : *Settings → Branches → Add protection* sur `main` : cochez **Enable push protection**, **Require approvals = 1**, **Block merge on rejected reviews**.

Les personnes B et C clonent :

```bash
git clone http://gitea.formini.local:3000/equipe-a/formini-tasks.git
cd formini-tasks
```

> Pour ne pas retaper le mot de passe : `git config --global credential.helper store` (acceptable sur une VM de formation, pas en production).

### 2.3 Chacun sa branche

| Personne | Branche                | Travail                                                                                   |
|----------|------------------------|-------------------------------------------------------------------------------------------|
| A        | `feature/stats`        | Ajouter une route `GET /api/stats` qui renvoie `{"total": n, "done": m}` dans `app.py`.   |
| B        | `test/stats`           | Ajouter dans `tests/test_api.py` un test `test_stats` (il échouera tant que A n'a pas fusionné : c'est normal, notez-le dans la PR). |
| C        | `docs/readme`          | Compléter le README : section « Équipe » avec les trois prénoms et une section « Routes » mentionnant `/api/stats`. |

```bash
git switch -c feature/stats
# ... modifications ...
git add -p                       # relire chaque bloc avant de l'indexer
git commit -m "feat(api): ajoute la route /api/stats"
git push -u origin feature/stats
```

Ouvrez la pull request sur Gitea (le lien s'affiche après le `push`). Titre conventionnel, description : *quoi*, *pourquoi*, *comment tester*.

### 2.4 Revue croisée

A relit la PR de B, B relit celle de C, C relit celle de A. Chaque relecteur :

1. laisse **au moins un commentaire sur une ligne** (question ou suggestion) ;
2. demande une modification (*Request changes*) ;
3. l'auteur pousse un commit de correction sur la même branche ;
4. le relecteur approuve (*Approve*), l'auteur fusionne (*Create merge commit*) et **supprime la branche**.

Ordre de fusion conseillé : A, puis B (son test passe maintenant), puis C.

### 2.5 Provoquer et résoudre un conflit

Après la fusion de C, A et B modifient **la même ligne** du README (par exemple la ligne de titre), chacun sur une nouvelle branche :

```bash
git switch main && git pull
git switch -c fix/titre-a            # B fait fix/titre-b
# modifier la première ligne du README.md
git commit -am "docs: précise le titre"
git push -u origin fix/titre-a
```

A fusionne sa PR en premier. B doit alors mettre sa branche à jour :

```bash
git switch main && git pull
git switch fix/titre-b
git rebase main
# CONFLICT (content): Merge conflict in README.md
git status                           # fichier en conflit listé
# éditer README.md : garder la bonne version, supprimer <<<<<<< ======= >>>>>>>
git add README.md
git rebase --continue
git push --force-with-lease          # la branche a été réécrite : force « sécurisé »
```

La PR de B est maintenant fusionnable. Fusionnez-la.

### 2.6 Livrer

Sur la VM de n'importe quel membre :

```bash
git switch main && git pull
git log --oneline --graph --decorate | head -20
git branch -r                        # plus aucune branche feature/… côté origin
```

### Critères de réussite

- [ ] `main` est protégée : un `git push origin main` direct est refusé.
- [ ] Trois PR fusionnées, chacune avec au moins un commentaire de revue et une approbation.
- [ ] Les messages de commit suivent la convention `type(portée): résumé`.
- [ ] Un conflit a été résolu par rebase, sans perdre de contenu (les deux modifications sont visibles ou fusionnées intelligemment).
- [ ] `pytest -q` passe sur `main` (le test de B inclus).

### Bonus

- Posez un tag : `git tag -a v0.1.0 -m "Première version" && git push origin v0.1.0`.
- Ajoutez `CODEOWNERS` et un modèle de PR (`.gitea/PULL_REQUEST_TEMPLATE.md`) : voir le dossier `solution/`.
- Essayez `git log -p --follow README.md`, `git blame README.md`, `git reflog` (pour retrouver un commit « perdu »).

---

## Dépannage

| Symptôme | Cause probable | Remède |
|----------|----------------|--------|
| `Permission denied (publickey)` alors que la clé est copiée | Permissions de `~/.ssh` (700) ou `authorized_keys` (600) incorrectes ; mauvais utilisateur | `chmod`, vérifier `ssh -v devops@ip` |
| `WARNING: UNPROTECTED PRIVATE KEY FILE!` | Clé privée lisible par d'autres sur le poste | `chmod 600 ~/.ssh/id_ed25519` |
| Enfermé dehors après modification de SSH | Faute de frappe dans la configuration | Console Formini de la VM, `sudo sshd -t` montre la ligne fautive |
| `git push` refusé : `protected branch` | Vous poussez sur `main` | Créez une branche et ouvrez une PR |
| `git push` refusé : `fetch first` | Le distant a avancé | `git pull --rebase` puis `push` |
| `fatal: refusing to merge unrelated histories` | Dépôt Gitea créé avec un README | Recréez-le vide, ou `git pull origin main --allow-unrelated-histories` |
| Conflit incompréhensible | Trop de changements d'un coup | `git rebase --abort`, puis recommencer avec des commits plus petits |
