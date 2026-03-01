# Settings

Linux の初期セットアップ用プロジェクト

## ツール構成

- **パッケージ管理**: Ansible（宣言的セットアップ）
- **dotfiles 管理**: GNU Stow（シンボリックリンク）
- **対象環境**: WSL2 (Ubuntu/Debian), Debian/Ubuntu 系 Linux, Devcontainer

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
# ※ setup.sh の自動導入は apt-get が使える Debian/Ubuntu 系のみ対応
# ※ WSL で systemd が無効な場合、setup.sh は /etc/wsl.conf に
#    [boot] systemd=true を設定して一度終了します。
#    その後 Windows 側で `wsl --shutdown` してから再実行してください。
./setup.sh

# Dev Container / Codespaces 用（install.sh は setup.sh に委譲）
./install.sh

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
- [x] apt 追加パッケージ（autossh, jq, ripgrep, shellcheck, shfmt 等）
- [x] locale 設定（ja_JP.UTF-8 を生成 / デフォルト LANG を設定）
- [x] Ubuntu のみ: language-pack-ja をインストール
- [x] curl でのツール導入（vim-plug）

### shell（シェル設定）

- [x] oh-my-zsh + powerlevel10k + プラグイン
- [x] zsh をデフォルトシェルに変更
- [x] pnpm 補完ファイル作成
- [x] git-gtr 補完ファイル

### stow（シンボリックリンク管理）

- [x] dotfiles のシンボリックリンク作成
- [x] .claude, .codex, .config 等のシンボリックリンク作成
- [x] .ssh/conf.local の空ファイル生成

### mise（言語ランタイム）

- [x] mise 本体の導入
- [x] グローバルランタイム（python, go, ruby, node, pnpm, uv, claude, codex, devcontainer-cli, gemini, npm:@vscode/vsce, dotnet, rust, yazi）
- [x] 個人用セットアップ前提で `latest` を利用（再現性は各プロジェクトの Dockerfile / lockfile 側で担保）

### fonts（フォント）

- [x] PlemolJP を Linux 側フォントとして導入
- [x] WSL では Windows 側アプリ用フォント導入の注意メッセージを表示

### textlint

- [x] .local/share/textlint-hub セットアップ

### yazi

- [x] mise で yazi を導入
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

## 依存を追加したいとき（入り口）

用途ごとに追加場所が分かれています。

- **apt パッケージを追加したい**
  - `ansible/roles/packages/defaults/main.yml`
    - `apt_base_packages` / `apt_additional_packages`
    - Ubuntu のみ: `apt_ubuntu_only_packages`
    - コンテナでは除外: `apt_container_exclude_packages`
- **mise のランタイムを追加したい**
  - `ansible/group_vars/all.yml` の `mise_runtime_versions`
- **curl で入れるツールを追加したい**
  - `ansible/roles/curl_tools/tasks/main.yml`
- **stow でリンクするパッケージを増やしたい**
  - `ansible/roles/stow/defaults/main.yml` の `stow_packages`

## Dev Container dotfiles として使う

VS Code Dev Containers の dotfiles 機能は、dotfiles リポジトリを clone した後に
`install.sh` / `setup.sh` などの bootstrap script を実行できます。

例: VS Code の User Settings (`settings.json`) に追加

```json
{
  "dotfiles.repository": "your-github-id/your-dotfiles-repo",
  "dotfiles.targetPath": "~/dotfiles",
  "dotfiles.installCommand": "install.sh"
}
```
