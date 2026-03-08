#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# install.sh
#
# VS Code Dev Containers / Codespaces の dotfiles 機能から呼ばれる想定の入口。
# 「コンテナ/remote dotfiles から入ってきた経路」を明示するための薄いラッパーで、
# 実際の bootstrap 本体は setup.sh に委譲する。
#
# dotfiles.installCommand は、クローン後のワークツリー内で実行されます。
# Debian/Ubuntu 系で apt-get が使える場合は setup.sh に委譲します。
# apt-get が無い環境はこのスクリプトの対象外です。
#
# 例:
#   "dotfiles.installCommand": "install.sh"
#   "dotfiles.installCommand": "install.sh --tags stow,shell"
# ------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

has_cmd() { command -v "$1" >/dev/null 2>&1; }

cd "${SCRIPT_DIR}"

# apt-get が使える Debian/Ubuntu 系では setup.sh に委譲する。
# setup.sh は apt-get 前提の bootstrap を持つため、現在のメイン入口はこちら。

if has_cmd apt-get; then
  # setup.sh が存在しない/実行できない場合は、分かりやすく失敗させる
  if [[ ! -f "./setup.sh" ]]; then
    echo "[ERROR] setup.sh が見つかりません: ${SCRIPT_DIR}/setup.sh" >&2
    exit 1
  fi
  if [[ ! -x "./setup.sh" ]]; then
    echo "[INFO] setup.sh に実行権限が無いので付与します" >&2
    chmod +x ./setup.sh
  fi

  exec env SETTINGS_CONTAINER_CONTEXT=1 ./setup.sh "$@"
fi

echo "[ERROR] apt-get が見つかりません。" >&2
echo "        install.sh は Debian/Ubuntu 系の dotfiles/bootstrap 用です。" >&2
echo "        対応が必要なら環境別に別スクリプトを用意してください。" >&2
exit 1
