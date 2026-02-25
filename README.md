# Settings

Linux の初期セットアップ用プロジェクト

## ツール構成

- **パッケージ管理**: Ansible（宣言的セットアップ）
- **dotfiles 管理**: GNU Stow（シンボリックリンク）
- **対象環境**: WSL2 (Ubuntu/Debian), ネイティブ Linux, Devcontainer

## ディレクトリ構成

```
stow/           ... Stow パッケージ群（dotfiles, claude, config 等）
ansible/        ... Ansible playbook・roles
scripts/        ... 再利用性のあるユーティリティスクリプト
```

## セットアップ

### Stow による dotfiles 展開

```bash
stow -d stow -t ~ dotfiles claude codex config cursor firefox gemini githooks local-bin ssh
```

### フルセットアップ

```bash
# bootstrap（Ansible 未インストールなら自動インストール）
./setup.sh

# または直接実行
ansible-playbook ansible/site.yml

# タグで選択実行
ansible-playbook ansible/site.yml --tags "stow,shell"

# オプション変更
ansible-playbook ansible/site.yml -e "install_docker=false"
```

## 機能一覧と実装状況

### packages（パッケージインストール）

- [x] apt 基本パッケージ（zsh, fzf, zoxide, bat, xclip 等）
- [x] apt 追加パッケージ（autossh, jq, language-pack-ja, ripgrep, shellcheck, shfmt 等）
- [x] curl インストール（claude CLI, uv, vim-plug）

### shell（シェル設定）

- [x] oh-my-zsh + powerlevel10k + プラグイン
- [x] zsh をデフォルトシェルに変更
- [ ] pnpm 補完ファイル作成
- [x] git-gtr 補完ファイル

### stow（シンボリックリンク管理）

- [x] dotfiles のシンボリックリンク作成
- [x] .claude, .codex, .config 等のシンボリックリンク作成
- [x] .ssh/conf.local の空ファイル生成

### node（Node.js ツール）

- [x] volta + node + pnpm
- [x] グローバルツール（@devcontainers/cli, @google/gemini-cli, @openai/codex, @vscode/vsce）

### textlint

- [x] .local/share/textlint-hub セットアップ

### yazi

- [x] clone & cargo build
- [x] プラグイン・テーマ導入（full-border, catppuccin-macchiato, catppuccin-latte）

### その他

- [x] インターネットダウンロードが必要な .deb パッケージの URL 表示

## yazi のコンテナ向けビルドコマンド

```bash
docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  -v "/home/user/Downloads/yazi:/work" \
  -v "/home/user/Downloads/yazi-out:/out" \
  -w /work \
  rust:bookworm \
  bash -lc 'apt-get update &&
            apt-get install -y --no-install-recommends pkg-config libssl-dev ca-certificates &&
            cargo install --path . --locked --root /out'
```
