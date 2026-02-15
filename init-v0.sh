#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# Ubuntu / Linux Mint 用セットアップ（Desktop Linux 前提）
# - 環境セットアップに必要な開発ツール群を導入
#
# 目的:
# - zsh / oh-my-zsh / powerlevel10k
# - zsh-autosuggestions / zsh-syntax-highlighting / zsh-bat
# - fzf / zoxide / bat / xclip / git / git-gtr / volta(+node/pnpm)
# - dotnet / docker
# - vscode / cursor / Google Antigravity
#
# 使い方（例）
#   ./install-deps.sh
# ------------------------------------------------------------

if [[ "$(id -u)" -eq 0 ]]; then
    echo "ERROR: root では実行しないでください（通常ユーザーで実行してください）" >&2
    exit 1
fi

# WSL 判定
IS_WSL=$(! [[ -n "${WSL_DISTRO_NAME-}" ]] && ! grep -qi microsoft /proc/version 2>/dev/null)

# ---- tunables (環境変数で上書き可) ------------------------------------------
DOTNET_SDK_VERSION="${DOTNET_SDK_VERSION:-8.0}"     # 例: 10.0 / 9.0 / 8.0
INSTALL_DOCKER="${INSTALL_DOCKER:-1}"               # 0|1
INSTALL_VSCODE="${INSTALL_VSCODE:-1}"               # 0|1
INSTALL_CURSOR="${INSTALL_CURSOR:-1}"               # 0|1
INSTALL_ANTIGRAVITY="${INSTALL_ANTIGRAVITY:-1}"     # 0|1
INSTALL_PLEMOLJP_FONT="${INSTALL_PLEMOLJP_FONT:-0}" # 0|1 (PlemolJP Nerd Font を ~/.local/share/fonts に導入)
SET_ZSH_DEFAULT="${SET_ZSH_DEFAULT:-0}"             # 0|1 (デフォルトシェルを zsh にするなら 1)

ARCH="$(dpkg --print-architecture)"
CURSOR_PLATFORM=""
case "$ARCH" in
amd64) CURSOR_PLATFORM="linux-x64" ;;
arm64) CURSOR_PLATFORM="linux-arm64" ;;
esac

# ---- OS info ----------------------------------------------------------------
# shellcheck disable=SC1091
. /etc/os-release
OS_ID="${ID:-unknown}"
OS_VERSION_ID="${VERSION_ID:-unknown}"
OS_CODENAME="${VERSION_CODENAME:-}"
OS_UBUNTU_CODENAME="${UBUNTU_CODENAME:-}"

if [[ "$OS_ID" != "ubuntu" && "$OS_ID" != "linuxmint" ]]; then
    echo "ERROR: このスクリプトは Ubuntu / Linux Mint 向けです（OS_ID=${OS_ID}）" >&2
    exit 1
fi

# Mint は Ubuntu 派生なので、repo 設定では Ubuntu codename を使うことが多い
UBU_CODENAME="${OS_UBUNTU_CODENAME:-$OS_CODENAME}"

sudo -v

echo "[INFO] OS: id=${OS_ID} version=${OS_VERSION_ID} codename=${OS_CODENAME} ubuntu_codename=${UBU_CODENAME} arch=${ARCH}"

# ---- base packages -----------------------------------------------------------
sudo apt-get update -y
sudo apt-get install -y \
    ca-certificates curl wget gnupg lsb-release software-properties-common apt-transport-https \
    git zsh unzip less xdg-utils \
    fzf zoxide bat xclip \
    python3 python3-pip

# bat は Ubuntu/Debian だと batcat になることがあるので shim
if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    sudo install -d -m 0755 /usr/local/bin
    sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat
fi

# ---- oh-my-zsh + theme + plugins --------------------------------------------
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-bat" ]]; then
    git clone --depth=1 https://github.com/fdellwing/zsh-bat.git "$ZSH_CUSTOM/plugins/zsh-bat"
fi

# ---- git-gtr (git worktree runner) ------------------------------------------
if ! command -v git-gtr >/dev/null 2>&1; then
    TMPDIR="$(mktemp -d)"
    git clone --depth=1 https://github.com/coderabbitai/git-worktree-runner.git "$TMPDIR/git-worktree-runner"
    sudo install -m 0755 "$TMPDIR/git-worktree-runner/bin/git-gtr" /usr/local/bin/git-gtr
    rm -rf "$TMPDIR"
fi

mkdir -p "$HOME/.zsh/completions"
if [[ -f /usr/local/bin/git-gtr ]] && [[ ! -f "$HOME/.zsh/completions/_git-gtr" ]]; then
    curl -fsSL https://raw.githubusercontent.com/coderabbitai/git-worktree-runner/main/completions/_git-gtr \
        -o "$HOME/.zsh/completions/_git-gtr"
fi

# ---- Volta + Node + pnpm -----------------------------------------------------
if [[ ! -d "$HOME/.volta" ]]; then
    curl -fsSL https://get.volta.sh | bash -s -- --skip-setup
fi

export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"

if command -v volta >/dev/null 2>&1; then
    volta install node
    volta install npm@latest

    if command -v corepack >/dev/null 2>&1; then
        corepack enable
        corepack prepare pnpm@latest --activate
    fi
fi

# ---- .NET SDK ----------------------------------------------------------------
if ! command -v dotnet >/dev/null 2>&1; then
    # Ubuntu/Mint は dotnet/backports PPA
    sudo add-apt-repository -y ppa:dotnet/backports
    sudo apt-get update -y
    sudo apt-get install -y "dotnet-sdk-${DOTNET_SDK_VERSION}"
fi

# ---- Docker (Engine) ---------------------------------------------------------
if [[ "$INSTALL_DOCKER" == "1" ]]; then
    sudo apt-get remove -y docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc || true

    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBU_CODENAME}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo groupadd docker >/dev/null 2>&1 || true
    sudo usermod -aG docker "$USER" || true

    if command -v systemctl >/dev/null 2>&1; then
        sudo systemctl enable --now docker || true
    fi
fi

# ---- VS Code -----------------------------------------------------------------
if [[ "$INSTALL_VSCODE" == "1" ]] && ! command -v code >/dev/null 2>&1; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >/tmp/microsoft.gpg
    sudo install -D -o root -g root -m 644 /tmp/microsoft.gpg /usr/share/keyrings/microsoft.gpg
    rm -f /tmp/microsoft.gpg

    sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF

    sudo apt-get update -y
    sudo apt-get install -y code
fi

# ---- Cursor ------------------------------------------------------------------
if [[ "$INSTALL_CURSOR" == "1" ]] && [[ -n "$CURSOR_PLATFORM" ]] && ! command -v cursor >/dev/null 2>&1; then
    CURSOR_JSON="$(curl -fsSL "https://www.cursor.com/api/download?platform=${CURSOR_PLATFORM}&releaseTrack=stable")"
    CURSOR_DEB_URL="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("debUrl",""))' <<<"$CURSOR_JSON")"
    if [[ -n "$CURSOR_DEB_URL" ]]; then
        TMPDIR="$(mktemp -d)"
        curl -fL "$CURSOR_DEB_URL" -o "$TMPDIR/cursor.deb"
        sudo apt install -y "$TMPDIR/cursor.deb"
        rm -rf "$TMPDIR"
    else
        echo "[WARN] Cursor の debUrl が取れませんでした。スキップします。" >&2
    fi
fi

# ---- Google Antigravity ------------------------------------------------------
if [[ "$INSTALL_ANTIGRAVITY" == "1" ]] && ! command -v antigravity >/dev/null 2>&1; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg |
        sudo gpg --dearmor -o /etc/apt/keyrings/antigravity-repo-key.gpg

    echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" |
        sudo tee /etc/apt/sources.list.d/antigravity.list >/dev/null

    sudo apt-get update -y
    sudo apt-get install -y antigravity
fi

echo ""
echo "✅ 完了"
echo "   - zshrc 反映: 新しいシェルを開く / 'exec zsh'"
echo "   - docker グループ反映: いったんログアウト/再ログイン"
