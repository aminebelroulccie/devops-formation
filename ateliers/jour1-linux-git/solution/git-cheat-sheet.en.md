# Git — Formini cheat sheet

_English version · la version française est dans [`git-aide-memoire.md`](git-aide-memoire.md)_

## Configuration

```bash
git config --global user.name  "Firstname Lastname"
git config --global user.email "firstname.lastname@formini.tn"
git config --global init.defaultBranch main
git config --global pull.rebase true
git config --global alias.lg "log --oneline --graph --decorate --all"
```

## Basic cycle

| Command | Effect |
|---------|--------|
| `git status` | State of the three areas |
| `git add <file>` / `git add -p` | Stage (hunk by hunk with `-p`) |
| `git commit -m "type(scope): summary"` | Record |
| `git diff` / `git diff --staged` | Unstaged / staged changes |
| `git log --oneline --graph` | History |
| `git restore <file>` | Undo an unstaged change |
| `git restore --staged <file>` | Unstage |

## Branches

| Command | Effect |
|---------|--------|
| `git switch -c feature/x` | Create and switch |
| `git switch main` | Switch |
| `git branch -d feature/x` | Delete (merged) |
| `git merge feature/x` | Merge into the current branch |
| `git rebase main` | Replay my commits on top of main |
| `git merge --abort` / `git rebase --abort` | Cancel everything |

## Remote

| Command | Effect |
|---------|--------|
| `git clone <url>` | Copy a repository |
| `git remote -v` | List remotes |
| `git push -u origin feature/x` | Push and track |
| `git fetch` | Fetch without merging |
| `git pull --rebase` | Fetch and rebase |
| `git push --force-with-lease` | Push a rewritten branch (never on main) |

## Conflict

1. `git status` → conflicting files.
2. Edit, remove `<<<<<<<`, `=======`, `>>>>>>>`.
3. `git add <file>`.
4. `git commit` (merge) or `git rebase --continue`.

## Message convention

`feat` · `fix` · `docs` · `test` · `chore` · `refactor` · `ci` — summary in the imperative, 50 characters, the body explains the *why*.
