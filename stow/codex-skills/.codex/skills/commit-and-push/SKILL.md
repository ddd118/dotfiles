---
allowed-tools: Bash(git checkout --branch:*), Bash(git add:*), Bash(git status:*), Bash(git push:*), Bash(git push --force-with-lease:*), Bash(git commit:*), Bash(git diff:*), Bash(git rev-parse:*), Bash(git log:*), Bash(jj root:*), Bash(jj st:*), Bash(jj diff:*), Bash(jj log:*), Bash(jj commit:*), Bash(jj bookmark set:*), Bash(jj git push:*)
description: Commit, push, and open a PR
---

# コミット&プッシュ

## 目的（速度重視）

ワーキングツリーの変更を「処理や画面ごと等の小粒度」に自動分割してステージ・日本語でコミットし、
現在の作業ブランチの origin に push する。余計な処理は行わない。エラー発生時は即時に調査報告する。

## 実行方針

- 粒度は小さめ：1 コミットの対象は「同一画面/機能/ディレクトリ」かつ 3〜7 ファイル or ~500 変更行を目安。
- 対象外（無視）：node_modules, dist/.output/.next/.nuxt, bin/, obj/, .DS_Store など生成物や明らかなビルド成果物。
- インタラクティブ操作（add -p 等）は原則使わず、非対話で最短完了。必要なら 1 回だけ試行（詳細は下記）。
- 変更が無い場合は即座に完了報告。

## 受け取る引数（任意, $ARGUMENTS）

--preview : 実行計画とコミットメッセージ案のみ表示（実行しない）
--no-push : コミットまでで停止（push しない）
--max-files=N : 1 コミット最大ファイル数（既定: 7）
--max-lines=N : 1 コミット最大変更行数の目安（既定: 500）
--type=t : 全コミットの type を固定（feat|fix|refactor|chore|docs|perf|test|ci）
--scope=s : 全コミットの scope を固定（例: ui、api、orders 等）

## jj リポジトリの場合

最初に `jj root` を実行し、成功した場合（`.jj/` がある場合）は下記「手順」の git コマンドを次に読み替える。失敗したら git のまま進める。

- 手順 1（作業ブランチ）：BRANCH = `jj log -r 'heads(::@ & bookmarks())' --no-graph -T 'local_bookmarks.map(|b| b.name()).join(" ")'`。空の場合は bookmark 名を勝手に作らず、ユーザーに報告して停止する。複数ある場合は先頭を使う
- 手順 2（変更の取得）：`jj st` と `jj diff --stat`（新規ファイルは自動で追跡されるため `??` は無い）
- 手順 4（ステージ・コミット）：`git add` は不要。`jj commit -m "<header>\n\n<body>" -- <files...>` で対象ファイルだけをコミットする（残りは新しい作業コピーに残る。`-m` は 1 つの文字列で渡す）
- 手順 5（残差）：パス指定なしの `jj commit -m "chore(misc): ..."` でまとめる
- 手順 6（push）：`jj commit` は bookmark を進めないため、先に `jj bookmark set BRANCH -r @-` で最新コミットへ移動し、`jj git push --bookmark BRANCH` で push する（未追跡の bookmark は自動で追跡される）。push 拒否時は自動で強制せず、エラーを報告する
- インタラクティブな `jj split` / `jj commit -i` は使わない
- jj は git hook（`post-commit` 等）を実行しない。hook に依存する処理は走らない点に注意する

## 手順

1. 作業ブランチの特定：
   - BRANCH = `git rev-parse --abbrev-ref HEAD`
   - 追跡ブランチの有無を確認（無い場合は後続で `git push -u origin BRANCH`）

2. 変更の取得：
   - `git status --porcelain=v1` と `git diff --numstat` を取得
   - 無視対象パスを除外
   - 変更種別（M/A/D/R/??）と拡張子で分類し、トップレベル〜第 2 階層ディレクトリ（例: `app/vue/src/pages/Orders`）を「機能スコープ」とみなす

3. コミットの分割（小粒度化ルール）：
   - グループを「同一機能スコープ」単位に作成
   - グループが大きい場合は、拡張子（.vue/.ts/.cs など）でさらに分割
   - それでも大きい場合は `--max-files` / `--max-lines` を上限に分割（超過分は次コミットへ）
   - ドキュメントのみ変更 → type=docs、ロックファイルのみ → chore を優先
   - `--type` / `--scope` 指定があればそれを使用、無ければヒューリスティクスで決定
     - .vue/.ts 前端中心 → scope=ui（例）
     - .cs/.sln/.csproj 中心 → scope=api or backend（例）
     - tests/ 配下 → type=test
     - 単純リネーム/整形のみ → type=chore or refactor

4. 実行（プレビュー時はここで出力のみ）：
   - 各コミットごとに対象ファイルを `git add -- <files...>` でステージ
   - コミットメッセージ（日本語, 例：`fix(ui): 注文一覧のページネーション不具合を修正`）
     - 1 行目（ヘッダ）: `<type>(<scope>): <要約1文>`
     - 本文（箇条書き）: 変更点の要約、影響範囲、関連画面や API、注意点
     - 例:
       - `- /app/vue/src/pages/Orders を中心に3ファイル修正`
       - `- 正常系のページング・並び替えを統一`
       - `- 既存E2Eは影響なし`
   - `git commit -m "<header>" -m "<body>"`

5. 残差があれば最後に「雑多な微修正」として `chore(misc):` で 1 コミットに集約（サイズは小さく保つ）

6. push：
   - 追跡ブランチが無い → `git push -u origin BRANCH`
   - 既に追跡あり → `git push`
   - push 拒否（非 fast-forward）の場合：
     - `git push --force-with-lease --force-if-includes` で再試行（確認不要）
   - push 出力に MR/PR 作成用 URL が含まれる場合は、そのリンクをユーザーに表示する

## エラー時の調査・出力

- 1 行要約：最後に実行したコマンド／作業ディレクトリ／対象コミットの概略（ファイル数・スコープ）
- ログ抜粋：エラー出力の末尾 ~50 行
- 原因候補 Top3（例）：
  - pre-commit hook 失敗 / LFS 必須ファイル (>100MB) / 改行コード or フォーマッタ差異
  - 権限不足 / 上流の保護ブランチ設定
- 最短対処案（1 つだけ提示。自動操作はここでは行わない）：
  - 例）LFS 対応が必要な場合は `git lfs track` と再コミットを提案

## 追加ノート

- 変更ゼロなら「変更なし」と即時報告して終了
- バイナリ/大型差分が混在する場合は別コミットに分離（type=chore, scope=assets 等）
- 既存のコミット規約（Conventional Commits 等）がある場合はそれを優先する
