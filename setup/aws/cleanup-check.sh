#!/usr/bin/env bash
# Liste ce qui reste en vie dans la région de formation : à lancer chaque soir
# (jour 4 et jour 5) après les `terraform destroy` des participants.
# Usage : AWS_PROFILE=formation bash cleanup-check.sh
set -euo pipefail
REGION="${AWS_REGION:-eu-west-3}"
export AWS_DEFAULT_REGION="$REGION"

echo "== Compte : $(aws sts get-caller-identity --query Account --output text) · région $REGION"

echo; echo "== Instances EC2 (hors terminated)"
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].{Id:InstanceId,Type:InstanceType,State:State.Name,Owner:Tags[?Key==`Owner`]|[0].Value,Project:Tags[?Key==`Project`]|[0].Value}' \
  --output table

echo; echo "== VPC non par défaut"
aws ec2 describe-vpcs --filters "Name=is-default,Values=false" \
  --query 'Vpcs[].{Id:VpcId,Cidr:CidrBlock,Name:Tags[?Key==`Name`]|[0].Value}' --output table

echo; echo "== Adresses IP élastiques"
aws ec2 describe-addresses --query 'Addresses[].{Ip:PublicIp,Instance:InstanceId}' --output table

echo; echo "== Volumes EBS disponibles (non attachés)"
aws ec2 describe-volumes --filters "Name=status,Values=available" \
  --query 'Volumes[].{Id:VolumeId,Size:Size}' --output table

echo; echo "== Clusters EKS"
aws eks list-clusters --output table

echo; echo "== Paires de clés"
aws ec2 describe-key-pairs --query 'KeyPairs[].KeyName' --output table

echo; echo "Si une ressource subsiste : retrouvez son propriétaire (tag Owner) et faites-lui lancer 'terraform destroy'."
