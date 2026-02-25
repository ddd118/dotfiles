#!/usr/bin/env bash
set -euo pipefail

# Ansible がなければインストールして playbook を実行する
if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "[INFO] Ansible が見つかりません。インストールします..."
    sudo apt-get update -y
    sudo apt-get install -y python3 python3-pip python3-venv
    pip3 install --user ansible
    export PATH="$HOME/.local/bin:$PATH"
fi

cd "$(dirname "$0")"
ansible-playbook ansible/site.yml "$@"
