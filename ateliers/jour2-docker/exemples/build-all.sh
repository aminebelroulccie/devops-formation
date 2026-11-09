#!/usr/bin/env bash
# Construit les quatre exemples et affiche un tableau comparatif des tailles.
# Usage : bash build-all.sh            (depuis ateliers/jour2-docker/exemples/)
set -euo pipefail
cd "$(dirname "$0")"

for lang in go python react rust; do
  echo "=== $lang ==="
  start=$(date +%s)
  docker build -q -t "formini-hello-$lang" "$lang" >/dev/null
  echo "construit en $(( $(date +%s) - start )) s"
done

echo
printf '%-22s %-10s\n' IMAGE TAILLE
docker images --format '{{.Repository}}\t{{.Size}}' | grep '^formini-hello-' | sort \
  | awk -F'\t' '{ printf "%-22s %-10s\n", $1, $2 }'

echo
echo "Démarrer un exemple : docker run --rm -p 8080:8080 formini-hello-go   (python : -p 8000:8000)"
