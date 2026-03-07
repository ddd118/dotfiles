# バリアント実装パターン

コンポーネントで `size` / `variant` などのバリエーションを持つ場合、以下の構造で実装する。

参考実装:

- [ModalBase.vue](vue/src/components/common/modal/ModalBase.vue)
- [FormFieldLayout.vue](vue/src/components/common/form/FormFieldLayout.vue)

## セクション構造

SCSS を以下の 4 セクションに分けて記述する:

```scss
// ----------------------------------------------------------------------------
// 1. 変数定義
// ----------------------------------------------------------------------------
$z-overlay: 2000;
$c-bg-panel: color("gray-98");

// ----------------------------------------------------------------------------
// 2. 共通CSS（Placeholder Selector）
// ----------------------------------------------------------------------------
%content-base {
  position: fixed;
  // ... 全バリアント共通の構造
}

%panel-structure {
  display: flex;
  flex-direction: column;
  // ... 共通のパネル構造
}

// ----------------------------------------------------------------------------
// 3. 静的コンポーネント（バリアント非依存）
// ----------------------------------------------------------------------------
.tdx-modal__overlay {
  position: fixed;
  inset: 0;
}

.tdx-modal__close {
  // ... 閉じるボタン等
}

// ----------------------------------------------------------------------------
// 4. バリアント定義
// ----------------------------------------------------------------------------
.tdx-modal__content--sm {
  @extend %content-base;
  width: 360px;

  .tdx-modal__panel {
    @extend %panel-structure;
  }
}

.tdx-modal__content--md {
  @extend %content-base;
  width: 480px;
  // ...
}
```

## Placeholder Selector の命名規則

| 接尾辞       | 用途                       | 例                                |
| ------------ | -------------------------- | --------------------------------- |
| `-base`      | 全バリアント共通の基礎構造 | `%content-base`, `%row-base`      |
| `-structure` | レイアウト構造（flex等）   | `%panel-structure`, `%field-base` |

## バリアントクラスの命名規則

```scss
// BEM + バリアント修飾子
.{block}--{variant}

// 例
.tdx-modal__content--sm
.tdx-modal__content--md
.tdx-form-row--tdx
.tdx-form-row--stacked
```

## template 側のクラスバインディング

```vue
<template>
  <!-- テンプレートリテラルでバリアントクラスを動的生成 -->
  <div :class="`tdx-form-row--${props.variant}`">...</div>
</template>

<script setup lang="ts">
const props = withDefaults(
  defineProps<{
    variant?: "tdx" | "utility" | "stacked" | "modal-md" | "modal-sm";
  }>(),
  {
    variant: "tdx",
  },
);
</script>
```

## ユーザーの意図

- バリアントを持つコンポーネントの SCSS 構造を統一し、可読性・保守性を向上させる
- Placeholder Selector で共通部分を DRY に保ち、バリアント固有のスタイルのみを各セクションで定義する
