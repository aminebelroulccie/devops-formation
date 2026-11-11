#!/usr/bin/env bash
# Génère un manifeste par étudiant à partir de template.yaml et students.txt.
# Usage : bash generate.sh            → generated/<login>.yaml + generated/all.yaml
#         bash generate.sh --apply    → idem, puis kubectl apply (contexte courant = admin du cluster)
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p generated
: > generated/all.yaml

count=0
while read -r student; do
  student="${student%%#*}"; student="$(echo "$student" | tr -d '[:space:]')"
  [ -z "$student" ] && continue
  if ! [[ "$student" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; then
    echo "login invalide : '$student' (minuscules, chiffres, tirets)" >&2; exit 1
  fi
  sed "s/__STUDENT__/$student/g" template.yaml > "generated/$student.yaml"
  { cat "generated/$student.yaml"; echo "---"; } >> generated/all.yaml
  count=$((count + 1))
done < students.txt

echo "$count espaces générés dans generated/ (un fichier par étudiant + all.yaml)"

if [ "${1:-}" = "--apply" ]; then
  kubectl apply -f generated/all.yaml
  echo
  kubectl get namespaces -l project=formation-devops
fi
