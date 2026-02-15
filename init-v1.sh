#!/usr/bin/env bash
set -Eeuo pipefail

# ------------------------------------------------------------
# WSL 用: .zshrc から読み取れる依存 + 追加要望を導入するセットアップ
#
# 目的:
# - zsh / oh-my-zsh / powerlevel10k / autosuggestions / syntax-highlighting
# - fzf / zoxide / bat / xclip / git / git-gtr / volta(+node/pnpm)
# - dotnet / docker (※WSLではDocker Desktop連携を前提にCLIのみがデフォルト)
# - (任意) VS Code / Cursor / Google Antigravity
#
# 方針:
# - できるだけ apt + 公式リポジトリ方式（keyring + deb822 .sources）を優先
# - WSL では GUI エディタは「既定では入れない」（Windows 側利用が一般的なため）
#   必要な場合は INSTALL_GUI_APPS=1 で実行
# ------------------------------------------------------------

if [[ "$(id -u)" == 0 ]]; then
    echo "ERROR: root では実行しないでください（通常ユーザーで実行してください）" >&2
    exit 1
fi

# WSL 判定（WSL_DISTRO_NAME or /proc/version）
IS_WSL=0
if [[ -n "${WSL_DISTRO_NAME-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=1
fi

# ---- tunables (環境変数で上書き可) ------------------------------------------
DOTNET_SDK_VERSION="${DOTNET_SDK_VERSION:-8.0}" # 例: 10.0 / 9.0 / 8.0
if [[ -z "${INSTALL_GUI_APPS-}" ]]; then
    if [[ "$IS_WSL" == 1 ]]; then
        INSTALL_GUI_APPS="0"
    else
        INSTALL_GUI_APPS="1"
    fi
fi
INSTALL_VSCODE="${INSTALL_VSCODE:-$INSTALL_GUI_APPS}"
INSTALL_CURSOR="${INSTALL_CURSOR:-$INSTALL_GUI_APPS}"
INSTALL_ANTIGRAVITY="${INSTALL_ANTIGRAVITY:-$INSTALL_GUI_APPS}"

# ARCH を定義（Antigravity用）
ARCH="$(dpkg --print-architecture)"

# ---- OS info ----------------------------------------------------------------
# shellcheck disable=SC1091
. /etc/os-release
OS_ID="${ID:-unknown}"
OS_VERSION_ID="${VERSION_ID:-unknown}"
OS_CODENAME="${VERSION_CODENAME:-}"
OS_UBUNTU_CODENAME="${UBUNTU_CODENAME:-}"

sudo -v

if [[ "$IS_WSL" == 1 ]]; then
    echo "[INFO] 環境: WSL"
else
    echo "[INFO] 環境: ホスト Linux"
fi
echo "[INFO] OS: id=${OS_ID} version=${OS_VERSION_ID} codename=${OS_CODENAME} ubuntu_codename=${OS_UBUNTU_CODENAME}"

# ---- base packages (zshrc 依存) ---------------------------------------------
sudo apt-get update -y
sudo apt-get install -y \
    ca-certificates curl wget gnupg lsb-release software-properties-common \
    git zsh unzip less \
    fzf zoxide bat xclip \
    python3 python3-pip

# ---- wslview (wslu) ----------------------------------------------------------
# .zshrc で BROWSER=wslview を使っているので wslview を用意する（WSL時のみ）
# Ubuntu 22.04+ on WSL は wslu 同梱が無くなったため、PPA 方式が案内されている
if [[ "$IS_WSL" == 1 ]] && ! command -v wslview >/dev/null 2>&1; then
    if [[ "$OS_ID" == "ubuntu" ]]; then
        sudo add-apt-repository -y ppa:wslutilities/wslu
        sudo apt-get update -y
        sudo apt-get install -y wslu
    elif [[ "$OS_ID" == "debian" ]]; then
        # https://wslu.wedotstud.io/wslu/install.html の Debian 手順
        sudo apt-get install -y apt-transport-https
        sudo install -d -m 0755 /usr/share/keyrings
        wget -qO- https://pkg.wslutiliti.es/public.key | sudo gpg --dearmor -o /usr/share/keyrings/wslu-archive-keyring.pgp
        echo "deb [signed-by=/usr/share/keyrings/wslu-archive-keyring.pgp] https://pkg.wslutiliti.es/debian $(. /etc/os-release && echo \""$VERSION_CODENAME"\") main" |
            sudo tee /etc/apt/sources.list.d/wslu.list >/dev/null
        sudo apt-get update -y
        sudo apt-get install -y wslu
    else
        echo "[WARN] wslview(wslu) は OS_ID=${OS_ID} では自動設定をスキップしました。" >&2
    fi
fi

# ---- oh-my-zsh -------------------------------------------------------------
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ---- oh-my-zsh Themes ------------------------------------------------------
if [[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
fi

# ---- oh-my-zsh Plugins -----------------------------------------------------
if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

if [[ ! -d "$ZSH_CUSTOM/plugins/zsh-bat" ]]; then
    git clone --depth=1 https://github.com/fdellwing/zsh-bat.git "$ZSH_CUSTOM/plugins/zsh-bat"
fi

# ---- git-gtr (git worktree runner) -----------------------------------------
if ! command -v git-gtr >/dev/null 2>&1; then
    TMPDIR="$(mktemp -d)"
    git clone --depth=1 https://github.com/coderabbitai/git-worktree-runner.git "$TMPDIR/git-worktree-runner"
    (cd "$TMPDIR/git-worktree-runner" && ./install.sh)
    rm -rf "$TMPDIR"
fi

mkdir -p "$HOME/.zsh/completions"
if command -v git-gtr >/dev/null 2>&1 && [[ ! -f "$HOME/.zsh/completions/_git-gtr" ]]; then
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
    volta install node@lts
    volta install npm@latest
    volta install pnpm@latest
fi

# ---- .NET SDK ----------------------------------------------------------------
if ! command -v dotnet >/dev/null 2>&1; then
    if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "linuxmint" ]]; then
        # Ubuntu/Mint は dotnet/backports PPA を使う（MS Learn の案内に合わせる）
        sudo add-apt-repository -y ppa:dotnet/backports
        sudo apt-get update -y
        sudo apt-get install -y "dotnet-sdk-${DOTNET_SDK_VERSION}"
    elif [[ "$OS_ID" == "debian" ]]; then
        # Debian は Microsoft feed を設定してからインストール（MS Learn の prod.list 方式）
        sudo apt-get install -y gpg wget
        TMPDIR="$(mktemp -d)"
        cd "$TMPDIR"
        wget -q https://packages.microsoft.com/keys/microsoft.asc
        gpg --dearmor <microsoft.asc >microsoft.asc.gpg
        wget -q "https://packages.microsoft.com/config/${OS_ID}/${OS_VERSION_ID}/prod.list" -O prod.list
        sudo mv prod.list /etc/apt/sources.list.d/microsoft-prod.list

        KEYRING_PATH="$(grep -oP '(?<=signed-by=)[^]]+' /etc/apt/sources.list.d/microsoft-prod.list | head -n 1 || true)"
        if [[ -z "$KEYRING_PATH" ]]; then
            KEYRING_PATH="/etc/apt/keyrings/microsoft-prod.gpg"
        fi
        sudo install -d -m 0755 "$(dirname "$KEYRING_PATH")"
        sudo mv microsoft.asc.gpg "$KEYRING_PATH"
        sudo chmod a+r "$KEYRING_PATH"
        cd /
        rm -rf "$TMPDIR"

        sudo apt-get update -y
        sudo apt-get install -y "dotnet-sdk-${DOTNET_SDK_VERSION}"
    else
        echo "[WARN] dotnet は OS_ID=${OS_ID} では自動設定をスキップしました。" >&2
    fi
fi

# ---- Docker ------------------------------------------------------------------
if [[ "$IS_WSL" == 1 ]]; then
    # WSL: Docker Desktop の WSL Integration 前提
    if [[ -S /var/run/docker.sock ]]; then
        echo "[INFO] Docker Desktop WSL Integration を検出しました。"
    else
        echo "[WARN] Docker Desktop WSL Integration が無効、または Docker Desktop が起動していません。" >&2
        echo "       Windows側の Docker Desktop で WSL Integration を有効化してください。" >&2
    fi

    if ! command -v docker >/dev/null 2>&1; then
        echo "[WARN] docker コマンドが見つかりません。Docker Desktop の統合で提供されない場合は" >&2
        echo "       例: sudo apt install -y docker-ce-cli" >&2
    fi
else
    # Host Linux: Docker Engine をインストール
    if ! command -v docker >/dev/null 2>&1; then
        DOCKER_REPO_OS=""
        DOCKER_SUITE=""

        if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "linuxmint" ]]; then
            DOCKER_REPO_OS="ubuntu"
            DOCKER_SUITE="${OS_UBUNTU_CODENAME:-$OS_CODENAME}"
        elif [[ "$OS_ID" == "debian" ]]; then
            DOCKER_REPO_OS="debian"
            DOCKER_SUITE="$OS_CODENAME"
        fi

        if [[ -n "$DOCKER_REPO_OS" && -n "$DOCKER_SUITE" ]]; then
            sudo apt-get remove -y docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc || true

            sudo apt-get install -y ca-certificates curl
            sudo install -m 0755 -d /etc/apt/keyrings
            sudo curl -fsSL "https://download.docker.com/linux/${DOCKER_REPO_OS}/gpg" -o /etc/apt/keyrings/docker.asc
            sudo chmod a+r /etc/apt/keyrings/docker.asc

            sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/${DOCKER_REPO_OS}
Suites: ${DOCKER_SUITE}
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

            sudo apt-get update -y
            sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

            if command -v systemctl >/dev/null 2>&1; then
                sudo systemctl enable --now docker || true
            else
                echo "[WARN] systemctl が無いので docker service は自動起動できません。" >&2
            fi

            sudo groupadd docker >/dev/null 2>&1 || true
            sudo usermod -aG docker "$USER" || true
        else
            echo "[WARN] Docker repo 設定をスキップしました（OS_ID=${OS_ID}）" >&2
        fi
    else
        echo "[INFO] Docker は既にインストール済みです。"
    fi
fi

# ---- GUI apps (optional) -----------------------------------------------------
if [[ "$INSTALL_GUI_APPS" == "1" ]]; then
    if [[ "$IS_WSL" == 1 ]]; then
        echo "[INFO] GUI アプリをインストールします（WSLg 等で Linux GUI を動かす前提）"
    else
        echo "[INFO] GUI アプリをインストールします（ホスト Linux）"
    fi

    # VS Code (APT repo)
    if [[ "$INSTALL_VSCODE" == "1" ]] && ! command -v code >/dev/null 2>&1; then
        sudo apt-get install -y wget gpg apt-transport-https
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >/tmp/microsoft.gpg
        apt-get update
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

    # Cursor (.deb)
    if [[ "$INSTALL_CURSOR" == "1" ]] && ! command -v cursor >/dev/null 2>&1; then
        echo "[INFO] Cursor は公式の署名付きAPTがないため自動インストールを行いません。"
        echo "       公式サイトから手動で .deb をダウンロードしてください:"
        echo "       https://cursor.com/ja/download"
        echo "       ダウンロード後: sudo apt install ./cursor*.deb"
    fi

    # Google Antigravity
    if [[ "$INSTALL_ANTIGRAVITY" == "1" ]] && ! command -v antigravity >/dev/null 2>&1; then
        sudo apt-get install -y curl gpg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg |
            sudo gpg --dearmor -o /etc/apt/keyrings/antigravity-repo-key.gpg

        echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" |
            sudo tee /etc/apt/sources.list.d/antigravity.list >/dev/null

        sudo apt-get install -y antigravity
    fi
else
    if [[ "$IS_WSL" == 1 ]]; then
        echo "[INFO] WSL では GUI エディタは既定でインストールしません。必要なら INSTALL_GUI_APPS=1 で再実行してください。"
        echo "       例: INSTALL_GUI_APPS=1 ./install-deps.sh"
    else
        echo "[INFO] ホスト Linux では GUI アプリのインストールが既定ですが、無効化しています。"
        echo "       例: INSTALL_GUI_APPS=0 ./install-deps.sh"
    fi
fi

echo ""
echo "✅ 完了"
echo "   - zshrc 反映: 新しいシェルを開く / 'exec zsh'"
echo "   - docker グループ反映: いったんログアウト/再ログイン（または WSL 再起動）"
