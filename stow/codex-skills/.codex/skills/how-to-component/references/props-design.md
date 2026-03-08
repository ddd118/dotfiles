# 共通コンポーネントの Props 設計ガイド

共通コンポーネント（`vue/src/components/common/` 配下）で再利用可能な Props を設計する際のパターン。

## 1. 関連する prop はオブジェクトにまとめる

関連性のある複数の prop は 1 つのオブジェクト型にまとめ、呼び出し側で意味のあるまとまりとして渡す。

```ts
// ❌ Bad: 関連する prop が散らばっている
interface Props {
  subButtonLabel: string;
  subButtonIcon: "clear" | "trash";
  primaryButtonLabel: string;
  primaryButtonIcon?: "plus" | "save";
  primaryButtonDisabled?: boolean;
}

// ✅ Good: 関連する prop をオブジェクトにまとめる
interface SubButton {
  label: string;
  icon: "clear" | "trash";
}

interface PrimaryButton {
  label: string;
  icon?: "plus" | "save";
  disabled?: boolean;
}

interface Props {
  subButton?: SubButton;
  primaryButton: PrimaryButton;
}
```

呼び出し側でも関連性が一目でわかる：

```vue
<MyFooter
  :sub-button="{ label: '選択をクリア', icon: 'clear' }"
  :primary-button="{ label: '追加', icon: 'plus', disabled: count === 0 }"
/>
```

## 2. フラグ prop の代わりに `T | null` を使う

「この機能を使うか否か」を boolean フラグで制御せず、機能の設定オブジェクト自体を `T | null` の必須 prop にする。

```ts
// ❌ Bad: フラグ + 別 prop の二重管理
interface Props {
  showSelection: boolean; // true のとき以下が有効
  selectedCount: number;
  itemName: string;
}

// ✅ Good: オブジェクト or null で表現
interface Selection {
  selectedCount: number;
  itemName: string;
}

interface Props {
  selection: Selection | null; // null = 表示しない
}
```

呼び出し側が「意図的に null を渡す」ことで、渡し忘れとの区別がつく：

```vue
<!-- 表示する -->
<MyFooter :selection="{ selectedCount: 3, itemName: '商品' }" />

<!-- 意図的に非表示 -->
<MyFooter :selection="null" />
```

`selection?: Selection`（省略可）にしてしまうと、渡し忘れなのか意図的な省略なのか区別できない。必須 + `null` にすることで呼び出し元に判断を強制できる。
