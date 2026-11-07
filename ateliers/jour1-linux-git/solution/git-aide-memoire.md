# Git — aide-mémoire Formini

## Configuration

```bash
git config --global user.name  "Prénom Nom"
git config --global user.email "prenom.nom@formini.tn"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global alias.lg "log --oneline --graph --decorate --all"
```

## Cycle de base

| Commande | Effet |
|----------|-------|
| `git status` | État des trois zones |
| `git add <fichier>` / `git add -p` | Indexer (par bloc avec `-p`) |
| `git commit -m "type(portée): résumé"` | Enregistrer |
| `git diff` / `git diff --staged` | Changements non indexés / indexés |
| `git log --oneline --graph` | Historique |
| `git restore <fichier>` | Annuler une modification non indexée |
| `git restore --staged <fichier>` | Désindexer |

## Branches

| Commande | Effet |
|----------|-------|
| `git switch -c feature/x` | Créer et basculer |
| `git switch main` | Basculer |
| `git branch -d feature/x` | Supprimer (fusionnée) |
| `git merge feature/x` | Fusionner dans la branche courante |
| `git rebase main` | Rejouer mes commits par-dessus main |
| `git merge --abort` / `git rebase --abort` | Tout annuler |

## Distant

| Commande | Effet |
|----------|-------|
| `git clone <url>` | Copier un dépôt |
| `git remote -v` | Lister les distants |
| `git push -u origin feature/x` | Pousser et suivre |
| `git fetch` | Récupérer sans fusionner |
| `git pull --rebase` | Récupérer et rebaser |
| `git push --force-with-lease` | Pousser une branche réécrite (jamais sur main) |

## Conflit

1. `git status` → fichiers en conflit.
2. Éditer, supprimer `<<<<<<<`, `=======`, `>>>>>>>`.
3. `git add <fichier>`.
4. `git commit` (merge) ou `git rebase --continue`.

## Convention de messages

`feat` · `fix` · `docs` · `test` · `chore` · `refactor` · `ci` — résumé à l'impératif, 50 caractères, le corps explique le *pourquoi*.
