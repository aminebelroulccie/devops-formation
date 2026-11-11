#!/usr/bin/env bash
# Déploie la pile Go + React (namespace formini-go) sur le cluster kind courant et attend
# que tout soit prêt. Usage : bash apply.sh            (depuis exemples/go-react/)
set -euo pipefail
cd "$(dirname "$0")"
NS=formini-go

if [ ! -f k8s/secret.yaml ]; then
  echo "k8s/secret.yaml manquant : cp k8s/secret.example.yaml k8s/secret.yaml puis changez le mot de passe." >&2
  exit 1
fi

echo "==> Application des manifestes (kustomize)"
kubectl apply -k k8s/

echo "==> Attente des bases (StatefulSets) puis des applications (Deployments)"
kubectl -n "$NS" rollout status statefulset/postgres --timeout=180s
kubectl -n "$NS" rollout status statefulset/cache    --timeout=120s
kubectl -n "$NS" rollout status deployment/api       --timeout=180s
kubectl -n "$NS" rollout status deployment/frontend  --timeout=180s

echo
kubectl -n "$NS" get statefulset,deployment,service,pvc,pods
echo
echo "Front : http://localhost:8081   (NodePort 30081, voir k8s/kind-config.yaml)"
echo "Sinon : kubectl -n $NS port-forward svc/frontend 8081:80"
