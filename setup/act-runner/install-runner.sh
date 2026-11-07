#!/usr/bin/env bash
# =============================================================================
# Installe et enregistre act_runner (Gitea Actions) en mode HOST sur une VM.
# Les jobs s'exécutent directement sur la VM : python3, docker, trivy, node
# sont disponibles (installés par install-vm.sh).
#
# Usage :
#   RUNNER_TOKEN=<jeton> sudo -E bash install-runner.sh
# Variables :
#   RUNNER_TOKEN   jeton d'enregistrement (bootstrap.sh ou Site Admin → Actions → Runners)
#   GITEA_URL      défaut http://gitea.formini.local:3000
#   RUNNER_NAME    défaut $(hostname)
#   RUNNER_LABELS  défaut ubuntu-latest:host,ubuntu-22.04:host
# =============================================================================
set -euo pipefail

VERSION="0.2.11"
GITEA_URL="${GITEA_URL:-http://gitea.formini.local:3000}"
RUNNER_TOKEN="${RUNNER_TOKEN:?Définissez RUNNER_TOKEN}"
RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
RUNNER_LABELS="${RUNNER_LABELS:-ubuntu-latest:host,ubuntu-22.04:host}"
RUNNER_USER="act_runner"
RUNNER_HOME="/var/lib/act_runner"

[[ $EUID -eq 0 ]] || { echo "Lancez ce script avec sudo." >&2; exit 1; }

echo "==> Binaire act_runner $VERSION"
curl -fsSLo /usr/local/bin/act_runner \
  "https://dl.gitea.com/act_runner/${VERSION}/act_runner-${VERSION}-linux-amd64"
chmod +x /usr/local/bin/act_runner

echo "==> Utilisateur système $RUNNER_USER"
id "$RUNNER_USER" &>/dev/null || useradd --system --create-home --home-dir "$RUNNER_HOME" --shell /bin/bash "$RUNNER_USER"
usermod -aG docker "$RUNNER_USER"
install -d -o "$RUNNER_USER" -g "$RUNNER_USER" "$RUNNER_HOME" /etc/act_runner

echo "==> Configuration /etc/act_runner/config.yaml"
install -m 644 "$(dirname "$0")/config.yaml" /etc/act_runner/config.yaml

echo "==> Enregistrement auprès de $GITEA_URL"
sudo -u "$RUNNER_USER" -H bash -c "cd $RUNNER_HOME && act_runner register --no-interactive \
  --config /etc/act_runner/config.yaml \
  --instance '$GITEA_URL' --token '$RUNNER_TOKEN' \
  --name '$RUNNER_NAME' --labels '$RUNNER_LABELS'"

echo "==> Service systemd"
cat > /etc/systemd/system/act_runner.service <<EOF
[Unit]
Description=Gitea Actions runner (act_runner)
After=network-online.target docker.service
Wants=network-online.target

[Service]
User=$RUNNER_USER
WorkingDirectory=$RUNNER_HOME
ExecStart=/usr/local/bin/act_runner daemon --config /etc/act_runner/config.yaml
Restart=always
RestartSec=5
Environment=HOME=$RUNNER_HOME

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now act_runner
sleep 2
systemctl --no-pager --lines=5 status act_runner
echo
echo "Vérifiez dans Gitea : Site Administration → Actions → Runners (état « Idle »)."
