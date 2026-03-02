#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# install.sh
#
# VS Code Dev Containers / Codespaces の dotfiles 機能から呼ばれる想定の入口。
#
# dotfiles.installCommand は、クローン後のワークツリー内で実行されます。
# このスクリプトは setup.sh に委譲し、追加の引数があればそのまま渡します。
#
# 例:
#   "dotfiles.installCommand": "install.sh"
#   "dotfiles.installCommand": "install.sh --tags stow,shell"
# ------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

cd "${SCRIPT_DIR}"

# setup.sh が存在しない/実行できない場合は、分かりやすく失敗させる
if [[ ! -f "./setup.sh" ]]; then
  echo "[ERROR] setup.sh が見つかりません: ${SCRIPT_DIR}/setup.sh" >&2
  exit 1
fi
if [[ ! -x "./setup.sh" ]]; then
  echo "[INFO] setup.sh に実行権限が無いので付与します" >&2
  chmod +x ./setup.sh
fi

exec ./setup.sh "$@"
