#!/usr/bin/env bash
# Fabrique un kubeconfig par étudiant : jeton de son ServiceAccount, serveur et CA du cluster
# courant, namespace par défaut = le sien. À lancer après generate.sh --apply.
# Usage : bash make-kubeconfigs.sh [URL de l'API vue par les étudiants]
#   ex.  bash make-kubeconfigs.sh https://203.0.113.10:6443   (Elastic IP de node1 sur AWS)
#        sans argument : l'URL du contexte courant (ok si les étudiants y ont accès).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p kubeconfigs

SERVER="${1:-$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}')}"
CA="$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"
if [ -z "$CA" ]; then
  # CA donnée par fichier et non en base64 : on la lit
  CAFILE="$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority}')"
  CA="$(base64 -w0 < "$CAFILE")"
fi
CLUSTER="$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')"

while read -r student; do
  student="${student%%#*}"; student="$(echo "$student" | tr -d '[:space:]')"
  [ -z "$student" ] && continue

  # le jeton est rempli par le contrôleur quelques secondes après la création du Secret
  for _ in $(seq 1 15); do
    TOKEN="$(kubectl -n "$student" get secret "$student-token" -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || true)"
    [ -n "$TOKEN" ] && break; sleep 2
  done
  [ -n "$TOKEN" ] || { echo "pas de jeton pour $student : generate.sh --apply a-t-il été lancé ?" >&2; exit 1; }

  cat > "kubeconfigs/$student.conf" <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: $CLUSTER
    cluster:
      server: $SERVER
      certificate-authority-data: $CA
users:
  - name: $student
    user:
      token: $TOKEN
contexts:
  - name: $student
    context:
      cluster: $CLUSTER
      user: $student
      namespace: $student
current-context: $student
EOF
  chmod 600 "kubeconfigs/$student.conf"
  echo "kubeconfigs/$student.conf  (namespace par défaut : $student)"
done < students.txt

echo
echo "Distribuer chaque fichier à son étudiant uniquement (c'est un secret), par exemple :"
echo "  scp kubeconfigs/formini-a1.conf devops@<VM de formini-a1>:~/.kube/config"
