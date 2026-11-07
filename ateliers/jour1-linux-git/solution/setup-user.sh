#!/usr/bin/env bash
# Solution partie 1 : créer l'utilisateur devops, installer une clé publique, durcir SSH.
# Usage : sudo bash setup-user.sh "ssh-ed25519 AAAA... prenom@formini"
set -euo pipefail

PUBKEY="${1:-}"
USER_NAME="devops"

if [[ -z "$PUBKEY" ]]; then
  echo "Usage : sudo bash $0 \"<clé publique ssh>\"" >&2
  exit 1
fi

if ! id "$USER_NAME" &>/dev/null; then
  adduser --disabled-password --gecos "Formini DevOps" "$USER_NAME"
fi
usermod -aG sudo "$USER_NAME"
getent group docker >/dev/null && usermod -aG docker "$USER_NAME"

install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/.ssh"
touch "/home/$USER_NAME/.ssh/authorized_keys"
grep -qxF "$PUBKEY" "/home/$USER_NAME/.ssh/authorized_keys" || echo "$PUBKEY" >> "/home/$USER_NAME/.ssh/authorized_keys"
chmod 600 "/home/$USER_NAME/.ssh/authorized_keys"
chown "$USER_NAME:$USER_NAME" "/home/$USER_NAME/.ssh/authorized_keys"

install -m 644 "$(dirname "$0")/50-formini.conf" /etc/ssh/sshd_config.d/50-formini.conf
sshd -t
systemctl restart ssh
echo "OK : connectez-vous avec  ssh $USER_NAME@$(hostname -I | awk '{print $1}')"
