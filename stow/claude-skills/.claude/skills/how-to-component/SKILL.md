---
name: how-to-make-component
description: '【次の条件に当てはまるとき必ず当skillを使用】Vue コンポーネント（.vue）を新規作成するとき。Props定義の基本パターン（const props, インラインtype）を提供。共通コンポーネント（web/src/components/common/）作成時はProps設計とバリアントSCSSのリファレンスも参照する。ラッパーコンポーネントには発火不要。'
---

# Vue コンポーネント作成ガイド

Vue コンポーネントを新規作成する際の基本ルール。

## 1. props は `const props = defineProps()` で定義する

props は必ず `const props` で受け取り、`props.xxx` でアクセスする。

```vue
<script setup lang="ts">
// ❌ Bad: 分割代入で props を直接展開
const { title, items } = defineProps<{
  title: string;
  items: Item[];
}>();

// ✅ Good: const props で定義し、props.xxx でアクセス
const props = defineProps<{
  title: string;
  items: Item[];
}>();

// 使用時
console.log(props.title);
props.items.forEach((item) => {
  // ...
});
</script>
```

**理由:**

- `props.` プレフィックスで「親から渡されたもの」だと一目でわかる
- ローカル変数と props の区別がつきやすい
- コードを読む際に「このデータはどこから来たのか？」が明確

## 2. 型は defineProps 内にインラインで書く

Props の型を外部の `type` や `interface` に切り出さない。`interface` を定義するのは、props をオブジェクトにまとめて渡す場合（→ `references/props-design.md`）のみ。

```vue
<script setup lang="ts">
// ❌ Bad: 1箇所でしか使わない型を外に切り出す
type Variant = 'tdx' | 'utility' | 'stacked' | 'modal-md' | 'modal-sm';

withDefaults(
  defineProps<{
    variant?: Variant;
  }>(),
  {
    variant: 'tdx',
  },
);

// ✅ Good: defineProps 内にインラインで書く
withDefaults(
  defineProps<{
    variant?: 'tdx' | 'utility' | 'stacked' | 'modal-md' | 'modal-sm';
  }>(),
  {
    variant: 'tdx',
  },
);
</script>
```

**理由:**

- `defineProps` を見るだけで props の全体像が把握できる
- 型定義を追いかけるジャンプが不要
- 外部 `interface` が必要なのは、props をオブジェクトにまとめて渡すときだけ（→ `references/props-design.md`）

---

## 共通コンポーネント（vue/src/components/common/）を作成する場合

上記の基本ルールに加え、以下のリファレンスも読むこと:

| リファレンス                  | 内容                                                     |
| ----------------------------- | -------------------------------------------------------- |
| `references/props-design.md`  | 関連する prop のオブジェクトまとめ、`T \| null` パターン |
| `references/variant-style.md` | size/variant 等のバリエーションを持つ SCSS 実装パターン  |
