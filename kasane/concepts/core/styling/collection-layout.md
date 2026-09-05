---
type: concept
title: コレクションのレイアウト語彙
description: layout 値 (list / grid・列数・向き別列数) とスペーシング・contentPadding・区切り線・ルートヘッダー/フッター・セルの高さの自動決定と content 配置・行の高さ変化の契約 (iOS / Android 共通)
tags: [styling, layout, grid]
timestamp: 2026-09-05
---

# コレクションのレイアウト語彙

この文書を読むと、リストとグリッドの表示形態を何で宣言し、切り替えたときに何が保たれ、行間・余白・区切り線・ヘッダー/フッターが既定でどう見え、セルの中身がどこに置かれるかが分かる。項目モデルは [collection-items](../core-model/collection-items.md) を参照。語彙は両プラットフォームで 1 対 1 に対応する (core/ADR-0006)。

## 目的

リストとグリッドを別コンポーネントにせず、単一の `KsCollectionView` に `layout` 値 1 つで表示形態を宣言させる (core/ADR-0006)。データを保ったまま実行中に切り替えられることが狙い。

## 公開 API

```swift
KsCollectionView(items, layout: .list(rowSpacing: 8)) { … }
KsCollectionView(items, layout: .grid(columns: .fixed(portrait: 2, landscape: 4), rowSpacing: 8, columnSpacing: 8),
                 contentPadding: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)) { … }
    .header { Text("見出し") }
    .footer { Text("末尾") }
    .listSeparators(false)
    .listSeparatorColor(.blue)
```

```kotlin
KsCollectionView(items = items, key = { it.id }, layout = KsLayout.List(rowSpacing = 8.dp)) { … }
KsCollectionView(
    items = items, key = { it.id },
    layout = KsLayout.Grid(KsColumns.Fixed(portrait = 2, landscape = 4), rowSpacing = 8.dp, columnSpacing = 8.dp),
    contentPadding = PaddingValues(horizontal = 16.dp),
    header = { Text("見出し") }, footer = { Text("末尾") },
    listSeparators = false, listSeparatorColor = Color.Blue,
) { … }
```

| 意味 | Swift | Kotlin |
|---|---|---|
| 1 列。行間は既定 0 | `.list` / `.list(rowSpacing:)` | `KsLayout.List` / `KsLayout.List(rowSpacing)` |
| 多列。行間・列間は既定 0 | `.grid(columns:rowSpacing:columnSpacing:)` | `KsLayout.Grid(columns, rowSpacing, columnSpacing)` |
| 固定列数 | `.fixed(n)` | `KsColumns.Fixed(n)` |
| コンテナの縦横比で列数を切り替える | `.fixed(portrait:landscape:)` | `KsColumns.Fixed(portrait, landscape)` |
| 最小アイテム幅を下回らない最大の列数 | `.adaptive(minItemWidth:)` | `KsColumns.Adaptive(minItemWidth)` |
| 本体とコンテンツの間の内側余白 (4 辺個別、既定 0) | `contentPadding:` | `contentPadding =` |
| 区切り線の表示 (既定 true) / 色 (既定は固定値) | `.listSeparators(_:)` / `.listSeparatorColor(_:)` | `listSeparators =` / `listSeparatorColor =` |

向き別列数は端末の物理向きではなく、コンポーネント自身の高さ > 幅なら portrait 側を使う (分割画面・タブレット・折りたたみで両プラットフォームの列数が揃う)。adaptive の余剰幅はアイテム幅へ均等配分し、列間は指定値のまま。列の利用可能幅は「コンポーネント幅 − contentPadding 左右 − columnSpacing × (列数 − 1)」。

## 保証すること

### 表示形態と切り替え

- **切り替えでデータと位置が保たれる**。表示中に `layout` を差し替えても画面全体の再構築や表示の乱れは起こさない。iOS は切り替え直前に表示範囲の先頭にあった要素をアンカーとして表示範囲内に残す (ios/ADR-0003)。Android は同じ Composable・同じスクロール状態のまま列数だけを変える (android/ADR-0001)。
- **ルートヘッダー/フッターはコンテンツと一緒にスクロールする**。宣言しなければ何も表示されない。配列が空でも表示される。グリッドでは全幅を占める。
- **スクロールインジケータの位置は `contentPadding` の影響を受けない**。常にコンポーネント本体の端に表示される。
- 0 以下の列数・0 以下の `minItemWidth`・負のスペーシングは不正入力。debug では assertion、release では表示を継続する (Android は警告ログを出し列数を 1 以上へ丸める。core/ADR-0011 の方針)。

### セルの高さと content の配置 (ios/ADR-0007、両プラットフォーム共通)

- **セルの高さはコンテンツから自動決定される**。利用者に高さの指定や事前計算を要求しない。
- **content は行の上端に固定され、水平は中央に置かれる**。自然幅が項目幅より小さい content は水平中央に置かれ、項目幅いっぱいに広がる content はそのまま項目幅を占める (規則は 1 つ)。
- **静定時は content へ行の高さを与えない** (SwiftUI では提案しない、Compose では制約として渡さない)。grid で背の低いセルは行高いっぱいに広がらず、余りは背景として見える。Android の高さ補間中だけが例外 (「してはいけないこと」)。両プラットフォームで見え方が一致することを Sample「大量件数」で確認済み。
- **行の高さが変わるときはアニメーションする**。展開する項目自身の高さ変化と、それに押される他の項目の移動が中間フレームを通る。iOS は UICollectionView の標準挙動、Android はライブラリ既定の高さ補間 (android/ADR-0004)。

### list の区切り線 (core/ADR-0010)

| 項目 | 契約 |
|---|---|
| 位置 | 先頭行の上端・各行の間・最終行の下端。リスト全体の上下境界を同じ線で示す |
| 幅と太さ | セルの左右いっぱい (インセットなし)、1pt / 1dp |
| 色 | 既定はライブラリ内部の固定値 `#D9D9DE`。`listSeparatorColor` で変更できる |
| 描画順 | content の前面。不透明な背景を持つテンプレートでも隠れない |
| 既定と opt-out | 既定で表示。`listSeparators(false)` で全て消す。グリッドには描かない |

## してはいけないこと

- grid のセルで `.frame(maxHeight: .infinity)` / `Spacer()` / `fillMaxHeight()` によって「行全体の高さに背景を敷く」ことを期待しない。行の高さはその行に並ぶセルのうち最も高いもので決まるが、各セルの content は自然高のまま上端に置かれる。行全体を塗りたい場合は content 側で高さを揃える。
- `rowSpacing > 0` の list で区切り線が行間の中央に出ることを期待しない。線はセルの底辺に描かれる。セクション対応 ([ロードマップ v1-foundation](../../../roadmaps/v1-foundation/roadmap.md) の後続フェーズ「セクション/グループ化」) で境界の規則を再設計する。
- テンプレートの中で `Divider` / `HorizontalDivider` を描いて区切り線の代用にしない。ライブラリの区切り線と二重になる。
- Android で、テンプレートの根を「制約を子へ渡さない透明な箱」にしない。行の高さ変化の補間中に限り根に行の高さが制約として渡るため、根で背景を塗るか `Box(propagateMinConstraints = true)` にしないと折りたたみの途中に隙間が見える (android/ADR-0004)。

## 用語

- **layout 値**: `KsCollectionLayout` (Swift) / `KsLayout` (Kotlin) の値。表示形態・列数・スペーシングをまとめて持つ。
- **アンカー要素**: レイアウト切り替え直前に表示範囲の先頭にあった要素。切り替え後の位置決めの基準 (iOS)。
- **ルートヘッダー/フッター**: コンテンツ全体の先頭・末尾に 1 つずつ置く View。セクション単位のヘッダーとは別物 (セクションは上記ロードマップの後続フェーズで導入予定)。
- **高さを与える / 提案する**: 親が子に高さを伝えて測らせること。SwiftUI では proposed size、Compose では constraints。本文書では両方を「与える」で表す。
- **Sample**: リポジトリ同梱 (`samples/`) の動作確認・パリティ検証用アプリ ([collection-items](../core-model/collection-items.md) の用語)。
- **content 配置**: セルの中身をセル領域のどこに置くかの規則 (上端固定・水平中央)。

## 関連

- [collection-items](../core-model/collection-items.md) — 差分更新とテンプレート
- [iOS コレクションエンジン](../../ios/architecture/collection-engine.md) — 自前 compositional レイアウト・区切り線サブビュー・自己サイズと推定高さ
- [Android Compose ラッパー](../../android/architecture/compose-wrapper.md) — `LazyVerticalGrid` 統一・`BoxWithConstraints` による向き判定・項目単位の区切り線描画・高さ補間
- core/ADR-0006 (layout 値の語彙)、core/ADR-0010 (区切り線の既定外観)、ios/ADR-0003 (自前レイアウトの統一)、ios/ADR-0007 (セル content の配置)、android/ADR-0001、android/ADR-0004
