#!/usr/bin/env bash
# Formation DevOps Formini — Jour 4, partie 2
# Crée le cluster kind "formini", autorise le registre Gitea (HTTP) et déploie
# Formini Tasks. Idempotent : relançable sans risque.
#
#   ./deploy.sh                       # image par défaut (v1.0.0)
#   IMAGE_TAG=v1.1.0 ./deploy.sh      # autre tag
#   GITEA_IP=192.168.10.10 ./deploy.sh  # si gitea.formini.local n'est pas résolu
set -euo pipefail

CLUSTER="${CLUSTER:-formini}"
NS="formini-tasks"
REGISTRY="${REGISTRY:-gitea.formini.local:3000}"
IMAGE="${IMAGE:-$REGISTRY/equipe-a/formini-tasks}"
IMAGE_TAG="${IMAGE_TAG:-v1.0.0}"
HERE="$(cd "$(dirname "$0")" && pwd)"
K8S="$HERE/k8s"

# ----- 1. cluster -----------------------------------------------------------
if ! kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "==> Création du cluster kind '$CLUSTER'"
  kind create cluster --name "$CLUSTER" --config "$K8S/kind-config.yaml"
else
  echo "==> Cluster '$CLUSTER' déjà présent"
fi
kubectl config use-context "kind-$CLUSTER" >/dev/null

# ----- 2. registre Gitea en HTTP sur chaque nœud ---------------------------
GITEA_HOST="${REGISTRY%%:*}"
GITEA_IP="${GITEA_IP:-$(getent hosts "$GITEA_HOST" | awk '{print $1}' | head -1 || true)}"
echo "==> Autorisation du registre $REGISTRY (IP : ${GITEA_IP:-inconnue}) sur les nœuds"
for node in $(kind get nodes --name "$CLUSTER"); do
  docker exec "$node" mkdir -p "/etc/containerd/certs.d/$REGISTRY"
  docker exec -i "$node" sh -c "cat > /etc/containerd/certs.d/$REGISTRY/hosts.toml" <<EOF
server = "http://$REGISTRY"

[host."http://$REGISTRY"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
EOF
  if [ -n "$GITEA_IP" ] && ! docker exec "$node" grep -q "$GITEA_HOST" /etc/hosts; then
    docker exec "$node" sh -c "echo '$GITEA_IP $GITEA_HOST' >> /etc/hosts"
  fi
done

# ----- 3. secret ------------------------------------------------------------
if [ ! -f "$K8S/secret.yaml" ]; then
  echo "==> Génération de k8s/secret.yaml (non commité)"
  PWD_GEN="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20)"
  sed "s/change-moi/$PWD_GEN/" "$K8S/secret.example.yaml" > "$K8S/secret.yaml"
fi

# ----- 4. déploiement -------------------------------------------------------
echo "==> Déploiement dans le namespace $NS avec l'image $IMAGE:$IMAGE_TAG"
kubectl apply -f "$K8S/namespace.yaml"
kubectl apply -f "$K8S/secret.yaml"
kubectl apply -f "$K8S/postgres.yaml"
kubectl apply -f "$K8S/app.yaml"
kubectl apply -f "$K8S/service.yaml"
kubectl -n "$NS" set image deploy/tasks "tasks=$IMAGE:$IMAGE_TAG" >/dev/null
kubectl -n "$NS" annotate deploy/tasks "kubernetes.io/change-cause=$IMAGE_TAG" --overwrite >/dev/null

echo "==> Attente de PostgreSQL puis de l'application"
kubectl -n "$NS" rollout status deploy/postgres --timeout=180s
kubectl -n "$NS" rollout status deploy/tasks --timeout=180s

echo
kubectl -n "$NS" get pods -o wide
echo
echo "Formini Tasks : http://localhost:8080   (health : curl -s localhost:8080/health)"
