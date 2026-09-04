---
type: concept
title: コレクションのレイアウト語彙
description: layout 値 (list / grid・列数・向き別列数) とスペーシング・contentPadding・区切り線・ルートヘッダー/フッター・セル自己サイズの契約
tags: [styling, layout, grid]
timestamp: 2026-09-03
---

# コレクションのレイアウト語彙

この文書を読むと、リストとグリッドの表示形態を何で宣言し、切り替えたときに何が保たれ、行間・余白・区切り線・ヘッダー/フッターが既定でどう見えるかが分かる。項目モデルは [collection-items](../core-model/collection-items.md) を参照。iOS 実装が先行しており (2026-09-03 時点)、Android は同じ語彙に追随する (core/ADR-0006)。

## 目的

リストとグリッドを別コンポーネントにせず、単一の `KsCollectionView` に `layout` 値 1 つで表示形態を宣言させる (core/ADR-0006)。データを保ったまま実行中に切り替えられることが狙い。

## 公開 API

```swift
KsCollectionView(items, layout: .list) { … }
KsCollectionView(items, layout: .list(rowSpacing: 8)) { … }
KsCollectionView(items, layout: .grid(columns: .fixed(3), rowSpacing: 8, columnSpacing: 8)) { … }
KsCollectionView(items, layout: .grid(columns: .adaptive(minItemWidth: 120))) { … }
KsCollectionView(items, layout: .grid(columns: .fixed(portrait: 2, landscape: 4)),
                 contentPadding: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)) { … }
    .header { Text("見出し") }
    .footer { Text("末尾") }
    .listSeparators(false)
```

| 語彙 | 意味 |
|---|---|
| `KsCollectionLayout.list` / `.list(rowSpacing:)` | 1 列。行間は既定 0 |
| `.grid(columns:rowSpacing:columnSpacing:)` | 多列。行間・列間は既定 0 |
| `KsGridColumns.fixed(n)` | 固定列数 |
| `.fixed(portrait:landscape:)` | コンテナの縦横比で列数を切り替える。端末の物理向きではなく高さ > 幅なら portrait 側 |
| `.adaptive(minItemWidth:)` | 最小アイテム幅を下回らない最大の列数。余剰幅はアイテム幅へ均等配分し、列間は指定値のまま |
| `contentPadding` | コンポーネント本体とスクロールするコンテンツの間の内側余白 (4 辺個別)。既定 0 |

列の利用可能幅は「コンポーネント幅 − contentPadding 左右 − columnSpacing × (列数 − 1)」。

## 保証すること

- **切り替えでデータと位置が保たれる**。表示中に `layout` を差し替えると、切り替え直前に表示範囲の先頭にあった要素をアンカーとして表示範囲内に残す。画面全体の再構築や表示の乱れは起こさない (ios/ADR-0003: レイアウトオブジェクトを差し替えず、値の実行時参照 + invalidate で切り替える)。
- **セルの高さはコンテンツから自動決定される**。利用者に高さの指定や事前計算を要求しない。行ごとにテキスト量が違えば各行が必要な高さになる。
- **list の区切り線は既定で表示される**。先頭行の上端・行間・最終行の下端に、左右いっぱいの 1pt の線を描く。色はライブラリ内部の固定値 (`#D9D9DE` 相当)。`listSeparators(false)` で消せる。グリッドには描かない。
- **ルートヘッダー/フッターはコンテンツと一緒にスクロールする**。宣言しなければ何も表示されない。配列が空でも表示される。
- **スクロールインジケータは `contentPadding` に寄らない**。コンポーネント本体の端に表示される。
- 0 以下の列数・0 以下の `minItemWidth`・負のスペーシングは不正入力 (debug では assertion)。

## してはいけないこと

- grid のセルで `.frame(maxHeight: .infinity)` や `Spacer()` によって「行全体の高さに背景を敷く」ことを期待しない。行の高さは列内で最も高いセルで決まるが、各セルの content は自然高のまま行の上端に置かれる (iOS 実装の帰結。詳細は [iOS コレクションエンジン](../../ios/architecture/collection-engine.md))。行全体を塗りたい場合は content 側で高さを揃える。
- `rowSpacing > 0` の list で区切り線が行間の中央に出ることを期待しない。線はセルの底辺に描かれる。セクション対応 (ロードマップ v1-foundation の後続フェーズ「セクション/グループ化」) で再設計する。
- テンプレートの中で `Divider` を描いて区切り線の代用にしない。ライブラリの区切り線と二重になる。

## 用語

- **layout 値**: `KsCollectionLayout` の値。表示形態・列数・スペーシングをまとめて持つ。
- **アンカー要素**: レイアウト切り替え直前に表示範囲の先頭にあった要素。切り替え後の位置決めの基準。
- **ルートヘッダー/フッター**: コンテンツ全体の先頭・末尾に 1 つずつ置く View。セクション単位のヘッダーとは別物 (セクションはロードマップ v1-foundation の後続フェーズ「セクション/グループ化」で導入予定)。

## 関連

- [collection-items](../core-model/collection-items.md) — 差分更新とテンプレート
- [iOS コレクションエンジン](../../ios/architecture/collection-engine.md) — 自前 compositional レイアウト・区切り線サブビュー・自己サイズと推定高さ
- core/ADR-0006 (layout 値の語彙)、core/ADR-0010 (区切り線の既定外観)、ios/ADR-0003 (自前レイアウトの統一)、ios/ADR-0007 (セル content の配置)
