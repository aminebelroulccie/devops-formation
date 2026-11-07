#!/bin/bash
# Exécuté une seule fois, au premier démarrage de l'instance (cloud-init).
# On reste minimal : la configuration réelle est le travail d'Ansible.
set -eux

hostnamectl set-hostname formini-web
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-apt
echo "user_data terminé : $(date -Is)" > /var/log/formini-user-data.log
