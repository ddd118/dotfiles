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

has_cmd() { command -v "$1" >/dev/null 2>&1; }

is_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]]; }

is_wsl() {
  uname -a 2>/dev/null | grep -qi microsoft && return 0
  [[ -r /proc/version ]] && grep -qi microsoft /proc/version
}

normalize_locale_for_ansible() {
  # ansible 起動時に "unsupported locale setting" が出る環境向けに、
  # 利用可能な UTF-8 ロケールへ安全に寄せる。
  #
  # setup.sh にも同等の処理があるが、将来 apt-get 以外（例: brew）に移行したときに
  # install.sh から直接 ansible-playbook を起動しても落ちないよう、ここにも置いておく。
  local current="${LC_ALL:-${LANG:-}}"
  local current_alt=""
  local available=""
  local fallback=""

  if has_cmd locale; then
    available="$(locale -a 2>/dev/null || true)"
  fi

  case "${available}" in
    *"ja_JP.utf8"*)
      fallback="ja_JP.UTF-8"
      ;;
    *"C.UTF-8"*)
      fallback="C.UTF-8"
      ;;
    *"C.utf8"*)
      fallback="C.utf8"
      ;;
    *)
      fallback="C"
      ;;
  esac

  if [[ -z "${current}" ]]; then
    export LANG="${fallback}"
    export LC_ALL="${fallback}"
    unset LANGUAGE || true
    return 0
  fi

  # 現在値が未生成ロケールなら fallback に置き換える
  if [[ "${current}" =~ ^(C|POSIX|C\.UTF-8|C\.utf8|ja_JP\.UTF-8|ja_JP\.utf8)$ ]]; then
    return 0
  fi

  current_alt="${current/UTF-8/utf8}"
  if [[ "${available}" != *"${current}"* && "${available}" != *"${current_alt}"* ]]; then
    echo "[WARN] 現在のロケール (${current}) は利用不可のため ${fallback} を使用します。" >&2
    export LANG="${fallback}"
    export LC_ALL="${fallback}"
    unset LANGUAGE || true
  fi
}

cd "${SCRIPT_DIR}"

# apt-get が使える環境（今のメイン運用）では setup.sh に委譲する。
# - WSL の systemd 有効化や sudo(-K) など、細かい処理を setup.sh 側に寄せるため。
#
# ただし将来的に apt-get 以外（例: Linuxbrew）へ移行した場合、
# setup.sh は apt-get 前提のためこの install.sh から ansible-playbook を直接実行できるようにする。

if has_cmd apt-get || is_wsl; then
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
fi

# ここから先は "apt-get が無い" を想定したフォールバック。
# - 個人用途で将来 brew ベースに寄せたくなったときのため

if ! has_cmd ansible-playbook; then
  if has_cmd brew; then
    echo "[INFO] ansible-playbook が見つかりません。brew で導入します..." >&2
    brew install ansible
  else
    echo "[ERROR] ansible-playbook が見つかりません。" >&2
    echo "        ansible を手動で導入してから再実行してください。" >&2
    exit 1
  fi
fi

normalize_locale_for_ansible

ansible_args=()
if ! is_root && has_cmd sudo && ! sudo -n true >/dev/null 2>&1; then
  echo "[INFO] sudo パスワード入力が必要なため Ansible を -K 付きで実行します。" >&2
  ansible_args+=("-K")
fi

exec ansible-playbook "${ansible_args[@]}" ansible/site.yml "$@"
