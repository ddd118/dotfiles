# ガイドライン

- **返答は日本語**で統一する。

---

## バージョン管理（jj）

- 作業ディレクトリで `jj root` が成功する（`.jj/` がある）場合、コミット・push・ブランチ操作などの**書き込み系は git ではなく jj を使う**（`jj commit` / `jj bookmark set` / `jj git push` など）。
- `git log` / `git diff` / `git status` / `git show` などの**読み取り系は git のままで良い**（colocated なら正常に動く）。
- `.jj/` が無いリポジトリでは従来どおり git を使う。
- jj は git hook（`post-commit` 等）を実行しない点に注意する。

---

## Skills / Rules の編集提案

- リポジトリに `.claude/rules` または `skills` / `.agents/skills` が存在する場合のみ、関連する rules / skills の更新提案を行う。
- 該当ディレクトリが存在しない場合は、新規作成が明らかに有益な場合だけ提案する。
- 修正などによって skills、rules に書かれてたものと内容が食い違う、もしくは skills、rules に書かれてないものを新規実装したとき、**必ず `skills, rules` の編集を提案すること。**
- 実装方針・設計判断・コーディング規約・運用手順・ディレクトリ責務に影響する変更を行った場合のみ、rules / skills の更新提案を行う。
- typo、単純なバグ修正、既存ルールに沿った小変更では提案不要。

ここでいう rules / skills は以下を指す。

- rules: `.claude/rules/**/*.md`
- project skills: `.codex/skills/**/SKILL.md`
- user skills: `$HOME/.codex/skills/**/SKILL.md`
- プロジェクト固有の `.skills/` が存在する場合は、その配下も対象に含める。

### ユーザーの意図

- 修正や新規実装する時に skills、rules の修正をする手間の削減や skills、rules と実装が食い違うのを防ぐため。

### Rules の編集について

`.claude/rules` に追記した場合、以下のフォーマットに従って `## 対応表` に追記を行う。**対応表セクションが存在しない場合 `## 対応表` を作成する**

```md
| ルール適応対象パス       | 配置先             |
| ------------------------ | ------------------ |
| `{{ルール適応対象パス}}` | `{{フォルダパス}}` |
```

以下の [対応表セクション例](#対応表セクション例) も参照

#### 対応表セクション例

| ルール適応対象パス             | 配置先                                                |
| ------------------------------ | ----------------------------------------------------- |
| `**/*.md`                      | `.claude/rules/common/documents-general-rules.md`     |
| `**/docs/**/*.md`              | `.claude/rules/common/documents-project-rules.md`     |
| `**/*.cs`                      | `.claude/rules/common/csharp-style-rules.md`          |
| `**/*.go`                      | `.claude/rules/common/golang-style-rules.md`          |
| `**/*.ts`                      | `.claude/rules/common/react-style-rules.md`           |
| `**/*.tsx`                     | `.claude/rules/common/react-style-rules.md`           |
| `api/service/**/*.cs`          | `.claude/rules/backend/service-implement-rules.md`    |
| `api/tests/**/*.cs`            | `.claude/rules/backend/csharp-test-rules.md`          |
| `api/Persistence/**/*.cs`      | `.claude/rules/backend/queryservice-rules.md`         |
| `api/Domain/**/*.cs`           | `.claude/rules/backend/domain-rules.md`               |
| `api/Domain/Entities/*.cs`     | `.claude/rules/backend/ef-rules.md`                   |
| `api/Controller/**/*.cs`       | `.claude/rules/backend/controller-rules.md`           |
| `api/Hubs/**/*.cs`             | `.claude/rules/shared/signalR-server-rules.md`        |
| `api/GraphQL/**/*.cs`          | `.claude/rules/shared/graphql-server-rules.md`        |
| `web/app/**/*.tsx`             | `.claude/rules/frontend/base-implement-rules.md`      |
| `web/components/**/*.tsx`      | `.claude/rules/frontend/component-implement-rules.md` |
| `web/lib/**/*.ts`              | `.claude/rules/frontend/function-implement-rules.md`  |
| `web/types/**/*.ts`            | `.claude/rules/frontend/type-implement-rules.md`      |
| `web/lib/**/graphql-client.ts` | `.claude/rules/shared/graphql-client-rules.md`        |
| `web/hooks/**/*.ts`            | `.claude/rules/shared/signalR-client-rules.md`        |
| `ext-api/internal/**/*.go`     | `.claude/rules/external/external-api-rules.md`        |
| `ext-api/cmd/**/*.go`          | `.claude/rules/external/external-core-rules.md`       |

---

## 基本方針

- 作業開始時、カレントディレクトリに `AGENTS.local.md` が存在する場合は読む。
- `AGENTS.local.md` はローカル専用の補足指示として扱い、ユーザーの明示なしに編集・作成・コミットしない。
- `AGENTS.local.md` は `.gitignore` で git 管理から除外されるファイルである。

---

## コード検索の推奨

- ユーザーが `@path/to/file` でファイルパスを指定した場合は、まず read でそのファイルを読み込む。
- 指定パスが存在しない場合は、勝手に類似ファイルを編集せず、近い候補を検索してユーザーに確認する。
- 定義ジャンプや参照解決が必要なときは Serena MCP を優先して使用する。
- Serena MCP が利用できない、または十分な結果が得られない場合は、`rg`、`grep`、`find`、言語サーバー、通常の read を使って調査する。

---

## 作業前の確認

- 変更前に関連ファイルを読み、既存の設計・命名・責務分担を確認する。
- 推測だけで実装せず、既存コードのパターンに合わせる。
- 大きめの変更では、先に短い実装方針を提示してから作業する。

---

## 変更後の確認

- 変更後は可能な範囲で formatter / lint / test / typecheck を実行する。
- 実行できなかった場合は、その理由と代替確認内容を最終報告に書く。
- 最終報告には以下を含める。
  - 変更内容
  - 確認したこと
  - 実行したコマンド
  - 未確認事項
  - rules / skills 更新提案がある場合はその内容

---

## 安全性

- 破壊的操作、広範囲の削除、マイグレーション、依存関係追加、設定ファイルの大幅変更は、事前にユーザーへ確認する。
- `.env`、秘密鍵、認証情報、個人情報を表示・編集・コミットしない。
- ユーザーが明示していないファイルの大規模整形や無関係なリファクタリングは行わない。
