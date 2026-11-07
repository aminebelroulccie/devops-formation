#!/usr/bin/env bash
# =============================================================================
# Formini · Formation DevOps — préparation d'une VM participant
# Ubuntu Server 24.04 LTS · 4 vCPU · 8 GB · 60 GB
#
# Installe : Git, Docker Engine + Compose, Ansible, Terraform, kubectl, kind,
#            Node.js 20 (pour act_runner en mode host), trivy, outils de base.
# Configure : /etc/hosts (gitea.formini.local), registre Docker non sécurisé.
#
# Usage (en root ou avec sudo) :
#   GITEA_IP=192.168.10.10 sudo -E bash install-vm.sh
# Options (variables d'environnement) :
#   GITEA_HOST   nom DNS de Gitea            (défaut : gitea.formini.local)
#   GITEA_IP     IP de la VM formateur       (obligatoire pour /etc/hosts)
#   TARGET_USER  utilisateur à mettre dans le groupe docker (défaut : devops,
#                ignoré s'il n'existe pas encore — créé par l'atelier du jour 1)
#   CREATE_USER  yes pour créer TARGET_USER maintenant (défaut : no)
# =============================================================================
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

GITEA_HOST="${GITEA_HOST:-gitea.formini.local}"
GITEA_IP="${GITEA_IP:-}"
TARGET_USER="${TARGET_USER:-devops}"
CREATE_USER="${CREATE_USER:-no}"

KIND_VERSION="v0.24.0"
KUBECTL_MINOR="v1.31"
NODE_MAJOR="20"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

[[ $EUID -eq 0 ]] || { echo "Lancez ce script avec sudo." >&2; exit 1; }
ARCH="$(dpkg --print-architecture)"   # amd64 attendu

# ----------------------------------------------------------------- base
log "Paquets de base"
apt-get update -q
apt-get install -y -q ca-certificates curl gnupg lsb-release apt-transport-https \
  git jq unzip tree htop vim nano python3 python3-venv python3-pip net-tools \
  software-properties-common

# ----------------------------------------------------------------- /etc/hosts
if [[ -n "$GITEA_IP" ]]; then
  log "/etc/hosts : $GITEA_HOST -> $GITEA_IP"
  sed -i "/[[:space:]]$GITEA_HOST\$/d" /etc/hosts
  echo "$GITEA_IP $GITEA_HOST" >> /etc/hosts
else
  echo "AVERTISSEMENT : GITEA_IP non défini, /etc/hosts non modifié." >&2
fi

# ----------------------------------------------------------------- docker
log "Docker Engine + Compose"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -q
apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

log "Registre non sécurisé (HTTP) : $GITEA_HOST:3000"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "insecure-registries": ["$GITEA_HOST:3000"],
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
systemctl enable --now docker
systemctl restart docker

# ----------------------------------------------------------------- hashicorp (terraform)
log "Terraform"
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg --yes
echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/hashicorp.list
apt-get update -q && apt-get install -y -q terraform

# ----------------------------------------------------------------- ansible
log "Ansible"
apt-get install -y -q ansible

# ----------------------------------------------------------------- kubectl
log "kubectl $KUBECTL_MINOR"
curl -fsSL "https://pkgs.k8s.io/core:/stable:/$KUBECTL_MINOR/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg --yes
echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/$KUBECTL_MINOR/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list
apt-get update -q && apt-get install -y -q kubectl

# ----------------------------------------------------------------- kind
log "kind $KIND_VERSION"
curl -fsSLo /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-linux-$ARCH"
chmod +x /usr/local/bin/kind

# ----------------------------------------------------------------- node (act_runner mode host)
log "Node.js $NODE_MAJOR"
curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
apt-get install -y -q nodejs

# ----------------------------------------------------------------- trivy
log "trivy"
curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /etc/apt/keyrings/trivy.gpg --yes
echo "deb [signed-by=/etc/apt/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  > /etc/apt/sources.list.d/trivy.list
apt-get update -q && apt-get install -y -q trivy

# ----------------------------------------------------------------- aws cli
log "AWS CLI v2"
if ! command -v aws >/dev/null; then
  tmp="$(mktemp -d)"
  curl -fsSLo "$tmp/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
  unzip -q "$tmp/awscliv2.zip" -d "$tmp" && "$tmp/aws/install" >/dev/null
  rm -rf "$tmp"
fi

# ----------------------------------------------------------------- utilisateur
if [[ "$CREATE_USER" == "yes" ]] && ! id "$TARGET_USER" &>/dev/null; then
  log "Création de l'utilisateur $TARGET_USER"
  adduser --disabled-password --gecos "Formini DevOps" "$TARGET_USER"
  usermod -aG sudo "$TARGET_USER"
fi
if id "$TARGET_USER" &>/dev/null; then
  usermod -aG docker "$TARGET_USER"
fi
# l'utilisateur qui a lancé sudo aussi (ubuntu)
if [[ -n "${SUDO_USER:-}" ]]; then usermod -aG docker "$SUDO_USER"; fi

# ----------------------------------------------------------------- images pré-chargées (gain de temps en salle)
log "Pré-chargement d'images Docker"
for img in python:3.12-slim postgres:16-alpine hello-world nginx:1.27-alpine \
           prom/prometheus:v2.55.1 grafana/grafana:11.3.1 prom/node-exporter:v1.8.2 \
           gcr.io/cadvisor/cadvisor:v0.49.1 kindest/node:v1.31.0; do
  docker pull -q "$img" || echo "  (échec pull $img, sera récupéré en salle)"
done

# ----------------------------------------------------------------- résumé
log "Versions installées"
git --version
docker --version && docker compose version
ansible --version | head -1
terraform version | head -1
kubectl version --client | head -1
kind version
node --version
trivy --version | head -1
aws --version
echo
echo "Terminé. Déconnectez/reconnectez l'utilisateur pour activer le groupe docker."
echo "Étape suivante (avant le jour 3) : setup/act-runner/install-runner.sh"
