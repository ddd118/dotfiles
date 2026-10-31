# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 基本ルール

- **返答は日本語**で統一する。
- 不明点・前提不足がある場合は **早めに質問して確度を上げる**。質問は必ず **AskUserQuestion** を使い、回答しやすい選択肢（A/B、Yes/No）にする。
- スキル内に `**質問: ...**` + 番号付き選択肢の形式で質問が定義されている場合は、`header` / `question` / `options[{label, description}]` を持つ AskUserQuestion に変換して質問する（`multiSelect: false`）。

## このリポジトリについて

Linux（WSL2 / Debian・Ubuntu 系 / Dev Container）の初期セットアップ用 dotfiles リポジトリ。**Ansible**（宣言的セットアップ）が **GNU Stow**（symlink）で `stow/` 配下のパッケージを `$HOME` に展開する。アプリケーションコードやテストは無い。ビルド・lint・テストコマンドも無く、検証は playbook の実行（`--check` / `--tags`）で行う。

## コマンド

```bash
./setup.sh                                      # フルセットアップ（ansible 未導入なら apt で導入。sudo パスワードが要る場合は自動で -K を付与）
./setup.sh --tags stow                          # 特定ロールのみ（tags: packages stow fonts mise curl_tools shell yazi docker gui_apps systemd）
./setup.sh --check --diff                       # dry-run（引数はそのまま ansible-playbook に渡る）
./setup.sh -e install_docker=false              # オプショナルコンポーネントの上書き
./install.sh [--tags ...]                       # Dev Container dotfiles 用入口。SETTINGS_CONTAINER_CONTEXT=1 を付けて setup.sh に委譲
ansible-playbook ansible/site.yml --tags stow   # setup.sh を介さず直接実行する場合（setup.sh もリポジトリ直下からこの形で実行している）
```

- `setup.sh` は WSL で systemd が無効だと `/etc/wsl.conf` を書き換えて終了する。Windows 側で `wsl --shutdown` 後に再実行が必要。
- root 実行は拒否される（コンテナ内、または `-e allow_root=true` を除く）。
- textlint 用の依存（`package.json` / `pnpm-lock.yaml`）が root にあるが、リポジトリ自体のビルドには使わない。

## アーキテクチャ

### 全体の流れ

`setup.sh` → `ansible/site.yml`（localhost, connection: local）→ ロール群。ロールの順序は `packages → stow → fonts → mise → curl_tools → shell → yazi → docker → gui_apps → systemd`。`stow` が先に走るため、後続ロール（`shell` の zsh 設定、`mise` など）は展開済みの dotfiles を前提にできる。

- `ansible/group_vars/all.yml`: 環境の自動判定（`is_wsl`, `is_container`, `settings_container_context`）と、それに連動するオプショナルフラグ（`install_docker` / `install_gui_apps` / `install_fonts` は WSL・コンテナではデフォルト false、`install_mise` は true）。ロールの有効/無効はここのフラグと `when:` で決まる。
- `ansible/roles/<role>/defaults/main.yml`: 追加するパッケージやツール一覧（apt パッケージ、yazi flavor、curl インストール対象など）はここに宣言する。依存の追加先一覧は README.md の「依存を追加したいとき」を参照。

### stow ロール（2 モード）

`ansible/roles/stow/defaults/main.yml` で `stow/<package>/` を 2 種類のモードに振り分ける。**パッケージを増やすときはここへの登録が必要**（`stow_packages` は fallback 用で、実際に使われるのは `stow_file_packages` / `stow_dir_packages`）。

- **file モード**（`file_mode.yml`）: `stow --no-folding --restow`。ファイル単位の symlink。既存の通常ファイルや不一致 symlink は削除して置き換えるが、ディレクトリなど型が違う既存パスがあれば安全のため fail する。
- **dir モード**（`dir_mode.yml`）: ディレクトリ単位で symlink（`claude-commands`, `claude-skills`, `codex-rules`, `codex-skills`, `ssh-conf-d`）。`stow_dir_bind_targets` に `package` と `target_rel_path` を必ず定義する（未定義だと assert で失敗）。ターゲットが空ディレクトリなら削除して symlink 化し、**非空ディレクトリ・不一致 symlink・型不一致は fail**（手動整理が必要）。`~/.claude/skills` のような既存ディレクトリ配下へスキル単位で差し込むため、`claude-skills` は `.claude/skills/how-to-component` と `.claude/skills/plan` を個別に bind している。新しいスキルを足すときは `stow_dir_bind_targets` にもエントリを追加する。
- `config-systemd-user` は WSL 以外では file モード対象から除外される。
- symlink は相対パスで張られる（ホストとユーザー名が違う Dev Container でも動く）。Dev Container では clone 先が `~/dotfiles` に固定されている前提。

### Dev Container 用の差し替え

`SETTINGS_CONTAINER_CONTEXT=1`（`install.sh` 経由）のとき、stow 後に `~/.config/mise/config.toml` を `stow/config/.config/mise/config.devcontainer.toml`（最小構成）で上書きする。通常環境のフル構成は `config.toml`。`.zshrc` を分岐させずに環境差を吸収するための仕組み。

### stow/ パッケージの役割（`stow/<pkg>/` の中身は `$HOME` からの相対パス）

- `dotfiles`: `.zshrc` `.gitconfig` `.vimrc` `.p10k.zsh` など。`.gitconfig` は `core.hooksPath = ~/.githooks` を設定。
- `claude` / `claude-commands` / `claude-skills`: `~/.claude/` の CLAUDE.md・settings.json・statusline・commands・skills。
- `codex` / `codex-rules` / `codex-skills`: `~/.codex/` の AGENTS.md・config.toml・rules・skills。`codex-skills` は `claude-skills` の内容（`how-to-component`, `plan`）をミラーしつつ `commit` / `commit-and-push` も持つ（Claude 側は `claude-commands`）。**片方のスキルを変更したらもう片方も合わせる**。
- `cursor`, `gemini`: 各 AI ツールの AGENTS.md / GEMINI.md・MCP 設定。
- `config`: `~/.config/` 配下の mise（`config.toml`, `config.devcontainer.toml`, `tasks/textlint-init`）と yazi。`config-textlint` は textlint テンプレート、`config-jj` は jj（Jujutsu）の `~/.config/jj/config.toml`（user は書かず `.gitconfig` を流用する運用）。
- `githooks`: `post-commit` / `post-rewrite` が `~/.local/bin/export-archive` を呼ぶ（失敗してもコミットを壊さない設計、rebase 中はスキップして post-rewrite で 1 回だけ実行）。
- `local-bin`: `~/.local/bin` のユーティリティ（`export-archive` は `git archive` ＋ ignore 対象ファイルを zip 化して `.tmp/` に出力、flock で排他）。
- `ssh` / `ssh-conf-d`: `~/.ssh/config` と `conf.d/`（`conf.local` は Ansible が空ファイルを作る、リポジトリ管理外のローカル設定用）。
- `firefox`: policies.json。`config-systemd-user`: WSL 用 user service。

### ツール導入の使い分け

- apt: `ansible/roles/packages/defaults/main.yml`（コンテナではこのロール自体をスキップ）
- mise: `stow/config/.config/mise/config.toml` の `[tools]`（Dev Container 用は `config.devcontainer.toml` も別途編集）
- curl installer: `ansible/roles/curl_tools/tasks/main.yml`。**Claude Code と Codex は公式推奨の native/standalone installer で導入し、mise には入れない**。
- 詳細な手順は [README.md](README.md) を参照。

## 注意点

- Claude / Codex の設定を編集するときは、`$HOME` 側ではなくこのリポジトリの `stow/<pkg>/` 配下の実体を編集する（例: `stow/claude/.claude/settings.json`）。
- `.tmp/`（export-archive の出力）は gitignore 済み。
- `.vscode/cspell.json` はスペルチェックを `ignorePaths` 方式で運用している（対象外にしたいファイルはそこへ追加）。
