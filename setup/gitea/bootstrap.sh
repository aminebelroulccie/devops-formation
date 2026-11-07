#!/usr/bin/env bash
# =============================================================================
# Crée l'administrateur, les comptes participants, les organisations d'équipe
# et affiche un jeton d'enregistrement pour act_runner.
#
# Pré-requis : docker compose up -d (dans ce dossier), jq installé.
# Usage :
#   ADMIN_PASS='ChangezMoi!2026' bash bootstrap.sh participants.csv
#
# participants.csv : login,email,equipe   (une ligne par participant, voir exemple)
# =============================================================================
set -euo pipefail

GITEA_URL="${GITEA_URL:-http://localhost:3000}"
ADMIN_USER="${ADMIN_USER:-formateur}"
ADMIN_PASS="${ADMIN_PASS:?Définissez ADMIN_PASS}"
ADMIN_EMAIL="${ADMIN_EMAIL:-formateur@formini.tn}"
DEFAULT_PASS="${DEFAULT_PASS:-Formini2026!}"
CSV="${1:-participants.csv}"

api() { curl -fsS -u "$ADMIN_USER:$ADMIN_PASS" -H "Content-Type: application/json" "$@"; }

echo "==> Administrateur $ADMIN_USER"
docker exec -u git gitea gitea admin user create --admin \
  --username "$ADMIN_USER" --password "$ADMIN_PASS" --email "$ADMIN_EMAIL" --must-change-password=false \
  2>/dev/null || echo "    (existe déjà)"

echo "==> Participants et organisations"
tail -n +2 "$CSV" | while IFS=, read -r login email equipe; do
  [[ -z "$login" ]] && continue
  login="$(echo "$login" | tr -d '[:space:]')"; email="$(echo "$email" | tr -d '[:space:]')"; equipe="$(echo "$equipe" | tr -d '[:space:]')"

  # utilisateur
  if ! api "$GITEA_URL/api/v1/users/$login" >/dev/null 2>&1; then
    api -X POST "$GITEA_URL/api/v1/admin/users" -d "{
      \"username\": \"$login\", \"email\": \"$email\", \"password\": \"$DEFAULT_PASS\",
      \"must_change_password\": true, \"send_notify\": false }" >/dev/null
    echo "    + utilisateur $login"
  fi

  # organisation
  if ! api "$GITEA_URL/api/v1/orgs/$equipe" >/dev/null 2>&1; then
    api -X POST "$GITEA_URL/api/v1/orgs" -d "{
      \"username\": \"$equipe\", \"full_name\": \"Équipe ${equipe#equipe-}\",
      \"visibility\": \"public\", \"repo_admin_change_team_access\": true }" >/dev/null
    echo "    + organisation $equipe"
  fi

  # membre de l'équipe Owners de l'organisation
  team_id="$(api "$GITEA_URL/api/v1/orgs/$equipe/teams" | jq -r '.[] | select(.name=="Owners") | .id')"
  api -X PUT "$GITEA_URL/api/v1/teams/$team_id/members/$login" >/dev/null
  echo "    ~ $login -> $equipe (Owners)"
done

echo "==> Jeton d'enregistrement act_runner (valable pour toutes les VM) :"
docker exec -u git gitea gitea actions generate-runner-token

echo
echo "Terminé. Mot de passe initial des participants : $DEFAULT_PASS (changement forcé à la première connexion)."
