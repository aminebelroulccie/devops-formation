#!/usr/bin/env bash
# Formation DevOps Formini — Jour 4
# Nettoyage complet. AWS d'abord (facturé), kind ensuite (gratuit, optionnel).
#
#   ./destroy.sh            # AWS seulement
#   ./destroy.sh --kind     # AWS + cluster kind
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "==> Terraform destroy (AWS)"
if [ -f "$HERE/terraform/terraform.tfstate" ]; then
  (cd "$HERE/terraform" && terraform destroy -auto-approve)
else
  echo "    aucun terraform.tfstate : rien à détruire ici (vérifiez quand même la console EC2)"
fi

if command -v aws >/dev/null 2>&1; then
  echo "==> Vérification : instances encore présentes avec le tag Project=formation-devops"
  aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=formation-devops" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Owner`]|[0].Value]' \
    --output table || true
fi

if [ "${1:-}" = "--kind" ]; then
  echo "==> Suppression du cluster kind 'formini'"
  kind delete cluster --name formini || true
fi

echo "Terminé. Checklist : console EC2 vide, VPC formini-* absent, key pair formini-* absente."
