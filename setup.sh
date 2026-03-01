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

is_wsl() {
  [[ -n "${WSL_DISTRO_NAME:-}" ]] && return 0
  [[ -r /proc/version ]] && grep -qi microsoft /proc/version
}

is_container() {
  [[ -f /.dockerenv || -f /run/.containerenv ]] && return 0
  [[ -n "${REMOTE_CONTAINERS:-}" || -n "${DEVCONTAINER:-}" || -n "${CODESPACES:-}" ]]
}

is_systemd_pid1() {
  [[ -r /proc/1/comm ]] && [[ "$(tr -d '\n' </proc/1/comm)" == "systemd" ]]
}

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

ensure_wsl_systemd_enabled() {
  # 個人用途では WSL の systemd 有効をデフォルトにしたい。
  # ただし Docker/Dev Container などコンテナでは設定しない。
  if ! is_wsl || is_container; then
    return 0
  fi

  if is_systemd_pid1; then
    return 0
  fi

  local wsl_conf="/etc/wsl.conf"

  echo "[INFO] WSL で systemd が無効です。/etc/wsl.conf に systemd=true を設定します..." >&2

  if [[ -f "${wsl_conf}" ]]; then
    if run_as_root grep -Eq '^[[:space:]]*systemd[[:space:]]*=[[:space:]]*true[[:space:]]*$' "${wsl_conf}"; then
      :
    elif run_as_root grep -Eq '^[[:space:]]*\[boot\][[:space:]]*$' "${wsl_conf}"; then
      run_as_root sed -i -E '/^[[:space:]]*\[boot\][[:space:]]*$/a systemd=true' "${wsl_conf}"
    else
      run_as_root sh -c "printf '\n[boot]\nsystemd=true\n' >> '${wsl_conf}'"
    fi
  else
    run_as_root sh -c "printf '[boot]\nsystemd=true\n' > '${wsl_conf}'"
  fi

  cat <<'MSG' >&2
[INFO] systemd 有効化設定を保存しました。
[INFO] Windows 側で `wsl --shutdown` を実行してから WSL を再起動し、`./setup.sh` を再実行してください。
MSG
  return 1
}

normalize_locale_for_ansible() {
  # ansible 起動時に "unsupported locale setting" が出る環境向けに、
  # 利用可能な UTF-8 ロケールへ安全に寄せる。
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

require_apt_get() {
  if ! has_cmd apt-get; then
    cat <<'MSG' >&2
[ERROR] apt-get が見つかりません。
この setup.sh は Debian/Ubuntu 系（WSL含む）専用です。
未対応環境では ansible-playbook を手動導入して実行してください。
MSG
    return 1
  fi
}

install_ansible_with_apt_if_needed() {
  if has_cmd ansible-playbook; then
    return 0
  fi

  echo "[INFO] ansible-playbook が見つかりません。apt で導入します..." >&2
  run_as_root apt-get update
  run_as_root apt-get install -y ansible || run_as_root apt-get install -y ansible-core
}

bootstrap_ansible_if_needed() {
  require_apt_get
  install_ansible_with_apt_if_needed

  if ! has_cmd ansible-playbook; then
    echo "[ERROR] apt 経由で ansible-playbook を導入できませんでした。" >&2
    return 1
  fi
}

bootstrap_ansible_if_needed

cd "$SCRIPT_DIR"
normalize_locale_for_ansible

if ! ensure_wsl_systemd_enabled; then
  exit 1
fi

ansible_args=()
if ! is_root && has_cmd sudo && ! sudo -n true >/dev/null 2>&1; then
  echo "[INFO] sudo パスワード入力が必要なため Ansible を -K 付きで実行します。" >&2
  ansible_args+=("-K")
fi

ansible-playbook "${ansible_args[@]}" ansible/site.yml "$@"
