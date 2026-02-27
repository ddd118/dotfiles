#!/usr/bin/env bash

# エラーハンドリング: Gitリポジトリ内でない場合は終了
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  echo "Error: Not inside a git repository."
  exit 1
fi

# 現在のディレクトリ（メインリポジトリと仮定）の絶対パスを取得
MAIN_REPO_PATH=$(git rev-parse --show-toplevel)
echo "Main Repo: $MAIN_REPO_PATH"

# 親ディレクトリにあるサブディレクトリを探索
# maxdepth 2: 親ディレクトリ直下のフォルダのみを見る（深く探索しすぎない）
find "$MAIN_REPO_PATH/.." -maxdepth 2 -name ".git" -type f | while read -r gitfile; do
    # .gitファイルの親ディレクトリ（ワークツリーのルート）を取得
    WORKTREE_PATH=$(dirname "$(realpath "$gitfile")")

    # 自分自身（メインリポジトリ内の .git ではなく、ワークツリーの .git ファイルのみ対象）
    # ※ 通常メインリポジトリの .git はディレクトリだが、submoduleなどの場合も考慮してパス比較
    if [ "$WORKTREE_PATH" != "$MAIN_REPO_PATH" ]; then
        echo "------------------------------------------------"
        echo "Found worktree candidate: $WORKTREE_PATH"
        
        # 修復実行
        # メインリポジトリから「このパスにあるワークツリーを直せ」と命令する
        git worktree repair "$WORKTREE_PATH"
    fi
done

echo "------------------------------------------------"
echo "All repairs attempted."
