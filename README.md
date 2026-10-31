# Settings

Linux の初期セットアップ用 dotfiles リポジトリ。`./setup.sh` を 1 回実行すると、パッケージ導入・dotfiles 展開・シェル設定までを冪等に行います。

- **パッケージ管理**: Ansible（宣言的セットアップ）
- **dotfiles 管理**: GNU Stow（シンボリックリンク）
- **対象環境**: WSL2 (Ubuntu/Debian), Debian/Ubuntu 系 Linux, Devcontainer（`apt-get` が使える環境のみ）

## クイックスタート

```bash
git clone <このリポジトリの URL> ~/dotfiles
cd ~/dotfiles
./setup.sh        # Ansible 未導入なら apt で自動インストール
exec zsh          # zshrc を反映
```

- 通常ユーザーで実行してください（root は拒否されます。コンテナ内、または `-e allow_root=true` を除く）。
- sudo にパスワードが必要な場合は、自動で `-K`（パスワード入力）が付きます。
- WSL で systemd が無効な場合、`setup.sh` は `/etc/wsl.conf` に `[boot] systemd=true` を設定して一度終了します。Windows 側で `wsl --shutdown` してから再実行してください。
- `docker` ロールを実行した場合、docker グループの反映にはログアウト/再ログインが必要です。
- Cursor は自動導入されないため、<https://cursor.com/ja/download> から手動で入れてください。

## よく使うコマンド

`setup.sh` の引数はそのまま `ansible-playbook` に渡ります。

```bash
./setup.sh --check --diff            # dry-run（変更内容の確認）
./setup.sh --tags stow               # 特定のロールだけ実行
./setup.sh --tags stow,shell         # 複数ロールを指定
./setup.sh -e install_docker=false   # オプショナルコンポーネントの上書き
./install.sh [--tags ...]            # Dev Container dotfiles 用の入口（setup.sh に委譲）
```

### ロールとタグ

ロールは次の順に実行されます。`stow` が先に走るため、後続ロールは展開済みの dotfiles を前提にできます。

| タグ         | 内容                                                             | 実行条件           |
| ------------ | ---------------------------------------------------------------- | ------------------ |
| `packages`   | apt パッケージの導入                                             | コンテナ以外       |
| `stow`       | `stow/` 配下を `$HOME` へ symlink 展開                           | 常時               |
| `fonts`      | フォント導入                                                     | `install_fonts`    |
| `mise`       | mise と各ランタイム/ツールの導入                                 | `install_mise`     |
| `curl_tools` | curl installer 系ツール（Claude Code, Codex CLI, vim-plug など） | 常時               |
| `shell`      | zsh 設定、completion 生成                                        | 常時               |
| `yazi`       | yazi の flavor セットアップ                                      | 常時               |
| `docker`     | Docker 導入                                                      | `install_docker`   |
| `gui_apps`   | GUI アプリ（VS Code など）                                       | `install_gui_apps` |
| `systemd`    | systemd user service                                             | コンテナ以外       |

### 環境ごとのデフォルト

環境は自動判定されます（[ansible/group_vars/all.yml](ansible/group_vars/all.yml)）。

| 変数                                          | ネイティブ Linux | WSL   | コンテナ |
| --------------------------------------------- | ---------------- | ----- | -------- |
| `install_docker`                              | true             | false | false    |
| `install_gui_apps` / `install_fonts`          | true             | false | false    |
| `install_mise`                                | true             | true  | true     |
| `set_zsh_default`（zsh をデフォルトシェルに） | false            | false | false    |

いずれも `-e` で上書きできます。例: `./setup.sh -e set_zsh_default=true`

## ディレクトリ構成

```text
setup.sh        ... 入口。Ansible の bootstrap と playbook 実行
install.sh      ... Dev Container / Codespaces dotfiles 用の入口（setup.sh に委譲）
ansible/        ... Ansible playbook・roles・group_vars
stow/           ... Stow パッケージ群（中身は $HOME からの相対パス）
scripts/        ... 再利用性のあるユーティリティスクリプト（stow 対象外）
```

### stow/ パッケージ

| パッケージ                                   | 展開先・内容                                               |
| -------------------------------------------- | ---------------------------------------------------------- |
| `dotfiles`                                   | `.zshrc`, `.gitconfig` など                                |
| `claude`, `claude-commands`, `claude-skills` | `~/.claude/`（CLAUDE.md, settings.json, commands, skills） |
| `codex`, `codex-rules`, `codex-skills`       | `~/.codex/`（AGENTS.md, config.toml, rules, skills）       |
| `cursor`, `gemini`                           | 各 AI ツールの設定・MCP 設定                               |
| `config`, `config-textlint`                  | `~/.config/`（mise, yazi, textlint テンプレート）          |
| `config-systemd-user`                        | WSL 用 systemd user service（WSL のみ）                    |
| `githooks`                                   | `post-commit` / `post-rewrite`（`export-archive` を呼ぶ）  |
| `local-bin`                                  | `~/.local/bin` のユーティリティ                            |
| `ssh`, `ssh-conf-d`                          | `~/.ssh/config` と `conf.d/`                               |
| `firefox`                                    | policies.json                                              |

stow ロールには 2 つのモードがあります。

- **file モード**: ファイル単位の symlink（`stow --no-folding --restow`）。既存の通常ファイルや不一致 symlink は置き換えます。
- **dir モード**: ディレクトリ単位の symlink。`stow_dir_bind_targets` で貼り先を指定します。ターゲットが非空ディレクトリだと失敗するので、その場合は手動で整理してください。

symlink は相対パスで張られるため、ホストとユーザー名が違っても動作します。

### scripts/

| スクリプト                                        | 用途                                     |
| ------------------------------------------------- | ---------------------------------------- |
| `create_gitlab_runner.sh`                         | GitLab Runner の登録                     |
| `gitlab-container-registry-remover.sh`            | GitLab Container Registry のイメージ削除 |
| `repair-worktree.sh`                              | git worktree の参照修復                  |
| `volta_reset.sh`                                  | Volta のリセット                         |
| `move-downloads-to-wsl.ps1`, `wsl-ssh-tunnel.ps1` | Windows 側（PowerShell）用               |

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
  - `mise` の zsh completion は `usage` CLI が必要なので、completion を使う前提なら `[tools]` に `usage` を含めてください
  - shell セットアップでは `mise completion zsh` / `pnpm completion zsh` から `~/.zsh/completions/` を自動生成します
  - 現在の Dev Container 用構成は `yazi`, `uv`, `python`, `usage`, `hadolint` です
  - `claude` と `codex` は公式推奨に合わせて native / standalone installer で導入するため、ここには追加しません
- **yazi の flavor を追加したい**
  - `ansible/roles/yazi/defaults/main.yml` の `yazi_flavors`
  - `ansible-playbook ansible/site.yml --tags yazi` は yazi 本体ではなく flavor の補助セットアップです
- **curl で入れるツールを追加したい**
  - `ansible/roles/curl_tools/tasks/main.yml`
  - 例: Claude Code, Codex CLI, vim-plug
  - 既存の mise-managed Codex が残っている場合は、一度だけ `mise uninstall npm:@openai/codex` などで掃除してください。Ansible では自動削除しません
- **stow でリンクするパッケージを増やしたい**
  - `ansible/roles/stow/defaults/main.yml` で mode を選んで追加
    - ファイル単位: `stow_file_packages`
    - ディレクトリ単位: `stow_dir_packages`
    - ディレクトリ単位の貼り先: `stow_dir_bind_targets`
  - 既存ディレクトリ配下へ skills のようなサブディレクトリ単位で差し込む場合は、
    `dir_mode` で個別の `target_rel_path` を定義する

## 設定を編集するとき

Claude / Codex などの設定は `$HOME` 側ではなく、このリポジトリの `stow/<pkg>/` 配下の実体を編集してください（例: `stow/claude/.claude/settings.json`）。`$HOME` 側は実体へのシンボリックリンクです。

変更後は `./setup.sh --tags stow` で再展開できます。

## Dev Container dotfiles として使う

VS Code Dev Containers の dotfiles 機能は、dotfiles リポジトリを clone した後に `install.sh` / `setup.sh` などの bootstrap script を実行できます。

dotfiles 経由の Dev Container では `mise` ロール自体は動作しますが、 `stow` 後に `~/.config/mise/config.toml` を最小構成へ差し替えます。

これにより `.zshrc` を増やさず、通常環境はフル構成のまま維持します。

このリポジトリはコンテナ側の bind mount との兼ね合いで、 dotfiles の clone 先を `~/dotfiles` に固定する前提です。

`dotfiles.targetPath` は必ず `~/dotfiles` を指定してください。 stow による symlink は相対パスになるようにしているのでユーザー名がホストと異なるのは問題ないです。

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

特定ロールだけ実行したい場合は `"dotfiles.installCommand": "install.sh --tags stow,shell"` のように引数を付けられます。

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
