#!/usr/bin/env bash

# Volta アンインストール
rm -rf ~/.volta

# Volta を Web 経由でインストール
curl https://get.volta.sh | bash -s -- --skip-setup

# Node を入れる
volta install node

# パッケージマネージャーを入れる
volta install npm
volta install yarn
volta install pnpm

# 利用頻度の高いツールはデフォルトで入れておく
volta install @openai/codex
volta install @vscode/vsce
volta install @devcontainers/cli
