# Settings

Linux の初期セットアップ用プロジェクト

## ツール構成

- **パッケージ管理**: Ansible（宣言的セットアップ）
- **dotfiles 管理**: GNU Stow（シンボリックリンク）
- **対象環境**: WSL2 (Ubuntu/Debian), Debian/Ubuntu 系 Linux, Devcontainer

## ディレクトリ構成

```text
stow/           ... Stow パッケージ群（dotfiles, claude, config 等）
ansible/        ... Ansible playbook・roles
scripts/        ... 再利用性のあるユーティリティスクリプト
```

## セットアップ

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
```

## 依存を追加したいとき（入り口）

用途ごとに追加場所が分かれています。

- **apt パッケージを追加したい**
  - `ansible/roles/packages/defaults/main.yml`
    - `apt_base_packages` / `apt_additional_packages`
    - Ubuntu のみ: `apt_ubuntu_only_packages`
    - コンテナでは除外: `apt_container_exclude_packages`
- **mise のランタイムを追加したい**
  - `stow/config/.config/mise/config.toml` の `[tools]`
  - ローカル Linux / WSL では `yazi` 本体もここで管理します
  - dotfiles 経由の Dev Container では `stow/config/.config/mise/config.devcontainer.toml` の内容で `~/.config/mise/config.toml` を差し替えます
  - 現在の Dev Container 用最小構成は `yazi` と `codex` です。`codex` は `github:openai/codex` で直接管理します
  - `claude` は公式推奨に合わせて native installer で導入するため、ここには追加しません
- **yazi の flavor を追加したい**
  - `ansible/roles/yazi/defaults/main.yml` の `yazi_flavors`
  - `ansible-playbook ansible/site.yml --tags yazi` は yazi 本体ではなく flavor の補助セットアップです
- **curl で入れるツールを追加したい**
  - `ansible/roles/curl_tools/tasks/main.yml`
  - 例: Claude Code, vim-plug
- **stow でリンクするパッケージを増やしたい**
  - `ansible/roles/stow/defaults/main.yml` で mode を選んで追加
    - ファイル単位: `stow_file_packages`
    - ディレクトリ単位: `stow_dir_packages`
    - ディレクトリ単位の貼り先: `stow_dir_bind_targets`
  - 既存ディレクトリ配下へ skills のようなサブディレクトリ単位で差し込む場合は、
    `dir_mode` で個別の `target_rel_path` を定義する

## メモ書き

### yazi のコンテナ向けビルドコマンド

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

### Dev Container dotfiles として使う

VS Code Dev Containers の dotfiles 機能は、dotfiles リポジトリを clone した後に
`install.sh` / `setup.sh` などの bootstrap script を実行できます。

dotfiles 経由の Dev Container では `mise` ロール自体は動作しますが、
`stow` 後に `~/.config/mise/config.toml` を最小構成へ差し替えます。
これにより `.zshrc` を増やさず、通常環境はフル構成のまま維持します。

このリポジトリはコンテナ側の bind mount との兼ね合いで、
dotfiles の clone 先を `~/dotfiles` に固定する前提です。
`dotfiles.targetPath` は必ず `~/dotfiles` を指定してください。

例: VS Code の User Settings (`settings.json`) に追加

- `dotfiles.repository` は git clone できる URL（HTTPS / SSH）を指定します（private リポジトリでも OK）。
- `dotfiles.targetPath` は必ず `~/dotfiles` を指定します。

```json
{
  "dotfiles.repository": "https://github.com/<your-user>/<your-dotfiles-repo>.git",
  "dotfiles.targetPath": "~/dotfiles",
  "dotfiles.installCommand": "install.sh"
}
```
