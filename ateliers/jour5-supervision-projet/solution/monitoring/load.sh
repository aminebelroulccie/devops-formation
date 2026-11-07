#!/usr/bin/env bash
# Générateur de trafic pour Formini Tasks.
# Usage : ./load.sh [URL] [DURÉE_EN_SECONDES]
#   ./load.sh                      -> http://localhost:5000 pendant 300 s
#   ./load.sh http://localhost:8080 120
#
# Mélange volontaire : lectures, créations, mises à jour, suppressions,
# et quelques appels sur des identifiants inexistants (404) pour que le
# taux d'erreur ne soit pas nul. Ctrl+C pour arrêter.

URL="${1:-http://localhost:5000}"
DURATION="${2:-300}"
END=$(( $(date +%s) + DURATION ))
N=0

echo "Trafic vers $URL pendant ${DURATION}s (Ctrl+C pour arrêter)"
while [ "$(date +%s)" -lt "$END" ]; do
  N=$((N + 1))
  curl -s -o /dev/null "$URL/api/tasks"
  curl -s -o /dev/null "$URL/health"

  if (( N % 3 == 0 )); then
    ID=$(curl -s -X POST -H 'Content-Type: application/json' \
          -d "{\"title\":\"charge $N\"}" "$URL/api/tasks" | sed -E 's/.*"id": ?([0-9]+).*/\1/')
    if [[ "$ID" =~ ^[0-9]+$ ]]; then
      curl -s -o /dev/null -X PUT -H 'Content-Type: application/json' \
           -d '{"done": true}' "$URL/api/tasks/$ID"
      (( N % 6 == 0 )) && curl -s -o /dev/null -X DELETE "$URL/api/tasks/$ID"
    fi
  fi

  # une requête sur dix vise une tâche inexistante -> 404
  (( N % 10 == 0 )) && curl -s -o /dev/null "$URL/api/tasks/999999"
  # une requête sur vingt envoie un corps invalide -> 400
  (( N % 20 == 0 )) && curl -s -o /dev/null -X POST -H 'Content-Type: application/json' -d '{}' "$URL/api/tasks"

  (( N % 50 == 0 )) && echo "  $N itérations…"
  sleep 0.2
done
echo "Terminé : $N itérations."
