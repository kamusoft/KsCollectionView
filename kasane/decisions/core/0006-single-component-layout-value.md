---
id: 0006
title: レイアウト指定 — 単一コンポーネント + layout 値、向き別列数を一級サポート
status: accepted
date: 2026-09-01
---

## Context

リスト / 固定列グリッド / adaptive グリッド / 画面向きで列数が変わる可変グリッド (自社実績機能) の宣言方法が論点だった。内部対応物は、iOS は Compositional Layout が全形態を1機構で表現でき、Android は `LazyColumn` / `LazyVerticalGrid(GridCells.Fixed/Adaptive)` に分かれるがラッパー内部の分岐で吸収できる。

## Decision

リストとグリッドを**単一コンポーネント**とし、`layout` 値1つで宣言させる:

- `.list` / `KsLayout.List`
- `.grid(columns: .fixed(3))` / `KsLayout.Grid(KsColumns.Fixed(3))`
- `.grid(columns: .adaptive(minItemWidth: 120))` / `KsLayout.Grid(KsColumns.Adaptive(minItemWidth = 120.dp))`
- `.grid(columns: .fixed(portrait: 2, landscape: 4))` / `KsLayout.Grid(KsColumns.Fixed(portrait = 2, landscape = 4))`

向き別列数は値として一級サポートし、利用者に画面サイズ監視のボイラープレートを書かせない。

**向きの判定基準**: `portrait` / `landscape` は**コンポーネントのコンテナ (表示領域) の縦横比**で判定する — 高さ > 幅なら portrait、幅 ≥ 高さなら landscape。CSS の `orientation` メディア特性と同義であり、端末の物理向きではない (iPad Split View・画面分割では端末向きと一致しないことがある)。スマホ全画面では端末向きと常に一致する。

**スペーシングと余白**: 行間・列間は layout 値のパラメータで宣言する — `.list(rowSpacing:)` / `.grid(columns:, rowSpacing:, columnSpacing:)` (Kotlin は同名の named 引数)。旧 AiForms の「特定 GridType のみ有効」の制約は撤廃し、adaptive 含む全グリッドで有効。adaptive の列間は「指定値で固定、余りを均等配分」のみ (旧 `SpacingType` の Center 相当は提供しない)。画面端からの余白はコンポーネントレベルの `contentPadding` (4 辺) で宣言する。意味論は「コンポーネント本体とスクロールするコンテンツの間の内側余白」であり外側マージンではない — スクロールバーは padding に左右されず本体の端に留まる (iOS `contentInset` 系 / Compose `contentPadding` の標準挙動)。外側の余白は利用者が通常の padding 手段で付ける。既定値はいずれも 0。グループ単位の余白はセクション/グループ化機能の側で扱う。

**区切り線**: list レイアウト専用のオプションとして標準提供する (グリッドでは出さない)。**既定は表示**で、明示オプションで非表示にできる (SwiftUI `.listRowSeparator(.hidden)` と同じ opt-out 感覚)。描画は両プラットフォームともライブラリの自前描画 (iOS はシステム list を使わないため — ios/ADR-0003。Android は `LazyColumn` に標準機構がないため)。同じ宣言・同じ既定で対称にする。

## Alternatives Considered

- **リストとグリッドを別コンポーネントに分ける**: 却下。リスト⇔グリッドの表示切替でビューツリーが丸ごと入れ替わり状態 (スクロール位置等) が飛ぶ。セクション別レイアウト (phase-4) とも合成しにくい
- **クロージャで動的計算 (`(画面情報) -> レイアウト`)**: 却下。9割の利用者に過剰で、宣言から静的に読めない。必要になれば layout 値のエスケープハッチとして後付けできる
- **向きを端末の物理向きで判定する**: 却下。iPad Split View の細長い領域に landscape の多列数が適用される不自然さが出る。コンテナ縦横比なら表示幅に対して常に自然な列数になる
- **`narrow` / `wide` 等への改名 (コンテナ基準を名前で表す)**: 却下。単独では「何が narrow か」の主語が曖昧。portrait / landscape は縦長/横長の形を 1 語で的確に表し、CSS orientation の先例と旧 API (`PortraitColumns`) との連続性もある

## Consequences

- 正: データ・テンプレート・ページングの宣言を変えずにレイアウトだけ差し替えられる (表示切替 UI が書きやすい)
- 正: phase-4 で「セクションごとに layout 値を付与する」拡張が同じ語彙で乗る
- 負: Android ラッパーは layout 値によって内部 Composable (`LazyColumn` / `LazyVerticalGrid`) を切り替えるため、切替時の状態引き継ぎ (スクロール位置) を実装で担保する必要がある

出典: kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/history.md (2026-09-01: レイアウト指定の DSL) / kasane/roadmaps/v1-foundation/phases/phase-2-ios-engine-foundation/history.md (2026-09-01: レイアウト) / core/ADR-0001 / core/ADR-0002 / ios/ADR-0003
