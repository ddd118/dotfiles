#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# setup.sh
#
# - ローカル(WSL / Linux / Dev Container)に対して Ansible playbook を実行します
# - 依存(Ansible)が無い場合は bootstrap します
#
# NOTE:
#   - 目的は "一度実行すれば不足分だけを補う" ことなので、できるだけ冪等に作っています。
#   - 想定 OS は Debian/Ubuntu 系（apt-get が使える環境）です。
# ------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

has_cmd() { command -v "$1" >/dev/null 2>&1; }

is_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]]; }

run_as_root() {
  # root であればそのまま、そうでなければ sudo を使う
  if is_root; then
    "$@"
  else
    if ! has_cmd sudo; then
      echo "[ERROR] sudo が見つかりません。root で実行するか sudo を導入してください。" >&2
      return 1
    fi
    sudo "$@"
  fi
}

require_apt_get() {
  if ! has_cmd apt-get; then
    cat <<'MSG' >&2
[ERROR] apt-get が見つかりません。
この dotfiles は Debian/Ubuntu 系 (apt-get) を前提にしています。

対応案:
  - Ubuntu/Debian 系イメージ/ディストリビューションで実行する
  - もしくは Ansible を拡張して dnf/pacman/apk 等に対応する
MSG
    return 1
  fi
}

bootstrap_ansible_if_needed() {
  if has_cmd ansible-playbook; then
    return 0
  fi

  echo "[INFO] ansible-playbook が見つかりません。bootstrap します..." >&2

  require_apt_get

  # apt-get update は -y を付けられないため注意
  run_as_root apt-get update

  # Ansible の apt モジュールが python3-apt を要求することがあるため、
  # playbook 実行前に最低限の Python 系依存を揃える。
  run_as_root apt-get install -y \
    python3 \
    python3-apt \
    python3-pip \
    python3-venv

  # "pip3" 直呼びより python3 -m pip の方が環境差分に強い
  python3 -m pip install --user --upgrade pip >/dev/null
  python3 -m pip install --user ansible

  # ~/.local/bin を PATH に通す（このスクリプト内だけでOK）
  export PATH="$HOME/.local/bin:$PATH"

  if ! has_cmd ansible-playbook; then
    echo "[ERROR] Ansible のインストールに失敗しました。" >&2
    return 1
  fi
}

bootstrap_ansible_if_needed

ensure_python3_apt() {
  # Ansible の apt モジュールが python3-apt を要求することがある。
  # 既に Ansible が入っている環境でも python3-apt が無いと playbook が落ちるため、
  # playbook 実行前に確認して不足分だけ補う。
  if ! has_cmd apt-get; then
    return 0
  fi

  if dpkg -s python3-apt >/dev/null 2>&1; then
    return 0
  fi

  echo "[INFO] python3-apt が見つかりません。apt モジュール用にインストールします..." >&2
  run_as_root apt-get update
  run_as_root apt-get install -y python3-apt
}

ensure_python3_apt

cd "$SCRIPT_DIR"
ansible-playbook ansible/site.yml "$@"
