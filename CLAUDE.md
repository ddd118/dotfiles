# ガイドライン

## 基本ルール

- **返答は日本語**で統一する。

## 不明点の扱い

- 不明点・前提不足がある場合は **早めに質問して確度を上げる**。
- 質問するときは、必ず **AskUserQuestion** を使い、回答しやすい選択肢（A/B、Yes/No）にする。

---

## スキル内の質問 → AskUserQuestion 変換

スキル内に以下のような形式で質問が定義されている場合：

```markdown
**質問: バックエンドの実装状態は？**

1. 未確定 - 仕様未確定。データは空で後から取得処理を実装
2. 仕様のみ - 仕様は決まっているが未実装。仕様書を提示してください
3. 実装済み - 既に API 実装済み。serena 等で検索して接続
```

これを以下の AskUserQuestion 形式に変換して質問する：

```
AskUserQuestion({
  questions: [
    {
      header: "BE状態",
      question: "バックエンドの実装状態は?",
      multiSelect: false,
      options: [
        { label: "未確定", description: "仕様未確定。データは空で後から取得処理を実装" },
        { label: "仕様のみ", description: "仕様は決まっているが未実装。仕様書を提示してください" },
        { label: "実装済み", description: "既にAPI実装済み。serena等で検索して接続" }
      ]
    }
  ]
})
```
