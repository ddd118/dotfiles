# ガイドライン

## バージョン管理（jj）

- 作業ディレクトリで `jj root` が成功する（`.jj/` がある）場合、コミット・push・ブランチ操作などの**書き込み系は git ではなく jj を使う**（`jj commit` / `jj bookmark set` / `jj git push` など）。
- `git log` / `git diff` / `git status` / `git show` などの**読み取り系は git のままで良い**（colocated なら正常に動く）。
- `.jj/` が無いリポジトリでは従来どおり git を使う。
- jj は git hook（`post-commit` 等）を実行しない点に注意する。
