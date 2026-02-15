# Settings

Linuxの初期セットアップ用プロジェクト

## init.sh の内容

TODO: まだ全部実装していない

1. 必要なソフトウェアのインストール
   1. TODO: 実装していません
   2. `apt`
      1. `autossh`
      2. `bat`
      3. `fzf`
      4. `git(ppa)`
      5. `inotify-tools`
      6. `jq`
      7. `language-pack-ja`
      8. `openssh-server`
      9. `peco`
      10. `poppler-utils`
      11. `python3`
      12. `python3-pip`
      13. `python3-venv`
      14. `ripgrep`
      15. `shellcheck`
      16. `shfmt`
      17. `unzip`
      18. `xclip`
      19. `zip`
      20. `zoxide`
      21. `zsh`
   3. `curl` によるインストール
      1. `claude`
      2. `oh-my-zsh`
      3. `uv`
         1. MEMO: `curl -LsSf https://astral.sh/uv/install.sh | sh`
      4. `vim-plug`
         1. URLメモ `curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim`
      5. `volta`
2. `dotfiles/` 以下のシンボリックリンク作成
   1. TODO: 実装してません
3. 以下の ディレクトリに入っているファイルのシンボリックリンクを作成
   1. TODO: 実装してません
   2. `.claude/`
   3. `.codex/`
   4. `.config/`
   5. `.cursor/`
   6. `.gemini/`
   7. `.githooks/`
   8. `.local/bin/`
   9. `.ssh/`
      1. 同時に空の `.ssh/conf.local` を生成する
4. `zsh` にシェルを変更
   1. TODO: 実装してません
   2. 以下の保管スクリプトを `.zsh/completions` に作る
      1. `git-gtr`
      2. `pnpm`
5. `volta` の必要パッケージをインストール
   1. TODO: 実装未確認
   2. 基本
      1. `node`
      2. `npm`
      3. `pnpm`
   3. ツール
      1. `@devcontainers/cli`
      2. `@google/gemini-cli`
      3. `@openai/codex`
      4. `@vscode/vsce`
6. `textlint` のセットアップ
   1. TODO: 実装未確認
   2. `.local/share` に `textlint-hub` を作成
   3. `npm init` して、以下のパッケージを `npm install`
      1. `textlint`
      2. `textlint-rule-preset-ja-spacing`
7. yazi の clone & `cargo build`
   1. TODO: 実装してません
   2. MEMO: `https://github.com/sxyazi/yazi.git`
   3. 更にプラグイン・テーマを `ya pkg` で導入
      1. `yazi-rs/plugins:full-border`
      2. `yazi-rs/flavors:catppuccin-macchiato`
      3. `yazi-rs/flavors:catppuccin-latte`
8. インターネットからのダウンロードが必要な `deb` パッケージのURLを画面に表示

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
