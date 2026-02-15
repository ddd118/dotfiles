#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

// Read JSON input from stdin
let inputData = "";

process.stdin.on("data", (chunk) => {
  inputData += chunk;
});

process.stdin.on("end", () => {
  let input;

  // --- 現在時刻 (HH:MM) ---
  const now = new Date();
  const hours = String(now.getHours()).padStart(2, "0");
  const minutes = String(now.getMinutes()).padStart(2, "0");
  const timeDisplay = `${hours}:${minutes}`;

  // JSON パースだけは全体を try/catch
  try {
    input = JSON.parse(inputData);
  } catch {
    console.log("[Claude]📁 workspace |🪙  0 |🗃️  0% | ⌚ ${timeDisplay}");
    return;
  }

  // --- モデル名 ---
  const modelName = input.model?.display_name || input.model?.id || "Unknown";

  // --- カレントディレクトリ ---
  const currentDir = input.workspace?.current_dir || process.cwd();
  const dirName = path.basename(currentDir);

  // --- Git ブランチ & 状態 ---
  let gitBranch = "";
  let gitColor = "\x1b[32m"; // デフォルト: 緑（クリーン）
  try {
    const branch = execSync("git --no-optional-locks branch --show-current", {
      cwd: currentDir,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();

    if (branch) {
      // 1. コンフリクトチェック（未マージファイルがあるか）
      let hasConflict = false;
      try {
        const unmerged = execSync("git --no-optional-locks ls-files -u", {
          cwd: currentDir,
          encoding: "utf8",
          stdio: ["ignore", "pipe", "ignore"],
        }).trim();
        hasConflict = unmerged.length > 0;
      } catch {
        hasConflict = false;
      }

      // 2. 変更チェック（ステージ済み + 未ステージ + 未追跡）
      let hasChanges = false;
      try {
        const status = execSync("git --no-optional-locks status --porcelain", {
          cwd: currentDir,
          encoding: "utf8",
          stdio: ["ignore", "pipe", "ignore"],
        }).trim();
        hasChanges = status.length > 0;
      } catch {
        hasChanges = false;
      }

      // 3. origin/develop が上流にあるかチェック
      let hasOriginDevelop = false;
      try {
        const upstream = execSync(
          "git --no-optional-locks rev-parse --abbrev-ref @{u}",
          {
            cwd: currentDir,
            encoding: "utf8",
            stdio: ["ignore", "pipe", "ignore"],
          }
        ).trim();
        hasOriginDevelop = upstream === "origin/develop";
      } catch {
        hasOriginDevelop = false;
      }

      // 色を決定（優先順位順）
      if (hasConflict) {
        gitColor = "\x1b[31m"; // 赤: コンフリクト
      } else if (hasChanges) {
        gitColor = "\x1b[33m"; // 黄: 変更あり
      } else if (!hasOriginDevelop) {
        gitColor = "\x1b[36m"; // シアン: origin/develop が上流にない
      } else {
        gitColor = "\x1b[32m"; // 緑: クリーン
      }

      gitBranch = ` (${gitColor}${branch}\x1b[39m)`;
    }
  } catch {
    // git リポジトリでない / git が無い場合は無視
    gitBranch = "";
  }

  // --- コンテキスト使用量 (context_window) ---
  const ctx = input.context_window || {};
  const contextWindowSize = ctx.context_window_size || 200000;
  const inputTokens =
    ctx.current_usage?.input_tokens || ctx.total_input_tokens || 0;
  const outputTokens =
    ctx.current_usage?.output_tokens || ctx.total_output_tokens || 0;
  const cacheCreationTokens =
    ctx.current_usage?.cache_creation_input_tokens || 0;
  const cacheReadTokens = ctx.current_usage?.cache_read_input_tokens || 0;

  // 「現在のコンテキストに載っているトークン量」
  const totalTokens =
    inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens;

  // --- トークン表示 (K / M 表記) ---
  let tokenDisplay;
  if (totalTokens >= 1_000_000) {
    tokenDisplay = (totalTokens / 1_000_000).toFixed(1) + "M";
  } else if (totalTokens >= 1_000) {
    tokenDisplay = (totalTokens / 1_000).toFixed(1) + "K";
  } else {
    tokenDisplay = totalTokens.toString();
  }

  // --- オートコンパクト閾値と割合 ---
  // 環境変数 > デフォルト(コンテキストの 80%)
  const envThreshold = Number.parseInt(
    process.env.CLAUDE_AUTO_COMPACT_THRESHOLD ?? "",
    10
  );
  const autoCompactThreshold =
    Number.isFinite(envThreshold) && envThreshold > 0
      ? envThreshold
      : Math.round(contextWindowSize * 0.8);

  let percentage =
    autoCompactThreshold > 0
      ? Math.round((totalTokens / autoCompactThreshold) * 100)
      : 0;

  if (percentage > 100) {
    percentage = 100;
  } else if (percentage < 0) {
    percentage = 0;
  }

  // 色付け
  let percentageColor;
  if (percentage >= 80) {
    percentageColor = "\x1b[31m" + percentage + "%\x1b[39m"; // Red
  } else if (percentage >= 50) {
    percentageColor = "\x1b[33m" + percentage + "%\x1b[39m"; // Yellow
  } else {
    percentageColor = "\x1b[32m" + percentage + "%\x1b[39m"; // Green
  }

  // --- 出力 ---
  const statusLine = `[${modelName}]📁 ${dirName}${gitBranch} |🪙  ${tokenDisplay} |🗃️  ${percentageColor} |⌚ ${timeDisplay}`;

  console.log(statusLine);
});

process.stdin.resume();
