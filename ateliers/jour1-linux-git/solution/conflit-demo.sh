#!/usr/bin/env bash
# Crée un petit dépôt local avec un conflit prêt à résoudre (entraînement hors Gitea).
# Usage : bash conflit-demo.sh && cd /tmp/conflit-demo && git status
set -euo pipefail
D=/tmp/conflit-demo
rm -rf "$D" && mkdir -p "$D" && cd "$D"
git init -q -b main
git config user.name "Demo" && git config user.email "demo@formini"
printf 'def greet():\n    return "Bonjour"\n' > app.py
git add app.py && git commit -qm "feat: salutation initiale"

git switch -qc feature/greeting
printf 'def greet():\n    return "Salut l'"'"'équipe"\n' > app.py
git commit -qam "feat: salutation informelle"

git switch -q main
printf 'def greet():\n    return "Bonjour Formini"\n' > app.py
git commit -qam "feat: salutation Formini"

echo "---- Tentative de fusion : un conflit est attendu ----"
git merge feature/greeting || true
echo
echo "Résolvez app.py, puis : git add app.py && git commit"
echo "Pour tout annuler : git merge --abort"
