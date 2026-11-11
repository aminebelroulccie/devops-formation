#!/usr/bin/env bash
# Vérifie l'isolation : chaque étudiant peut tout faire chez lui, rien chez les autres.
# Usage : bash verify.sh    (après make-kubeconfigs.sh)
set -uo pipefail
cd "$(dirname "$0")"

mapfile -t STUDENTS < <(grep -v '^\s*#' students.txt | tr -d '[:space:]' | grep -v '^$')
fail=0
check() { # check <kubeconfig> <attendu yes|no> <args kubectl auth can-i…>
  local cfg="$1" want="$2"; shift 2
  local got; got="$(kubectl --kubeconfig "$cfg" auth can-i "$@" 2>/dev/null || true)"
  if [ "$got" = "$want" ]; then printf '  ok   %-4s %s\n' "$want" "$*"
  else printf '  ECHEC attendu %s, obtenu %s : %s\n' "$want" "${got:-?}" "$*"; fail=1; fi
}

for s in "${STUDENTS[@]}"; do
  cfg="kubeconfigs/$s.conf"
  other="${STUDENTS[0]}"; [ "$other" = "$s" ] && other="${STUDENTS[1]}"
  echo "== $s"
  check "$cfg" yes create deployments -n "$s"
  check "$cfg" yes create secrets -n "$s"
  check "$cfg" yes create rolebindings -n "$s"
  check "$cfg" yes delete pods -n "$s"
  check "$cfg" no  get pods -n "$other"
  check "$cfg" no  create deployments -n "$other"
  check "$cfg" no  list namespaces
  check "$cfg" no  delete namespaces "$s"
  check "$cfg" yes get resourcequotas -n "$s"        # "admin" lit le quota…
  check "$cfg" no  delete resourcequotas -n "$s"     # …mais ne peut ni le modifier ni le supprimer
  check "$cfg" no  get nodes
done

echo
[ "$fail" = 0 ] && echo "Isolation vérifiée pour ${#STUDENTS[@]} étudiants." || { echo "Des vérifications ont échoué."; exit 1; }
