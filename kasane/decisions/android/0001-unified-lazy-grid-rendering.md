---
id: 0001
title: Android の描画は LazyVerticalGrid に統一し、list は 1 列グリッドとして扱う
status: proposed
date: 2026-09-04
---

## Context

Android の描画エンジンは Compose Lazy 系の薄いラッパーである (core/ADR-0001)。公開 DSL は単一コンポーネント + layout 値 (list / grid) で宣言する (core/ADR-0006) ため、変換層は layout 値を見て Lazy DSL へ落とす必要がある。Compose には list 向けの `LazyColumn` と grid 向けの `LazyVerticalGrid` があり、それぞれ `LazyListState` / `LazyGridState` という別のスクロール状態を持つ。両者に共通の親は `ScrollableState` だけで、index 指定のスクロールを共通経路で呼ぶ公式手段はない。

core/ADR-0006 は「layout 切替で内部 Composable が入れ替わるとスクロール位置が失われる」を負の帰結として抱えていた。一方 iOS は全レイアウトを自前の compositional セクションで統一し、リストを 1 列グリッドとして扱う (ios/ADR-0003)。

Compose Foundation の現状 (2026-09 時点、公式リファレンスで確認): `LazyGridScope.stickyHeader` は 1.8.0 で stable、`LazyGridItemScope.animateItem` は 1.7.0 で list と同形、`LazyLayoutCacheWindow` は list / grid 双方で使える。

## Decision

変換先を **`LazyVerticalGrid` に統一**し、layout 値が list のときは `GridCells.Fixed(1)` の 1 列グリッドとして描く。`LazyColumn` は使わない。

- スクロール状態は `LazyGridState` の 1 種だけをライブラリが所有し、`KsScrollController` (core/ADR-0007) の attach 先もこれ 1 経路にする
- list ⇔ grid の切替は同じ Composable・同じ state のまま `columns` だけを変えるため、スクロール位置が保たれる
- 1 列グリッドの性能が `LazyColumn` と同等であることは Sample「大量件数」画面の実測で確認する

## Alternatives Considered

- **list は `LazyColumn`、grid は `LazyVerticalGrid` に分岐する**: 却下。切替時に Composable が入れ替わるため、両方の state を保持して位置を写す補正が要る。`KsScrollController` の接続も 2 種の state を自前の抽象で包む必要がある (公式の共通型がない)。標準の組み合わせそのものである利点はあるが、統一で失うものが v1 の範囲にない

統一で失うもの: `LazyItemScope` の `fillParentMax*` 修飾子 (grid の item scope にない) と `rememberSnapFlingBehavior(lazyListState)` の簡易オーバーロード。前者は利用者のテンプレートが生の item scope を触らない本ライブラリの DSL では露出せず、後者は吸着スクロール自体が v1 の対象外 (core/ADR-0009)。

## Consequences

- 正: iOS (ios/ADR-0003) と内部構造が同型になり、両プラットフォームの挙動差の説明が減る
- 正: core/ADR-0006 の負の帰結 (切替時のスクロール位置喪失) が Android 側で消える
- 正: スクロール制御・sticky ヘッダー (grid の `stickyHeader`) ・キャッシュ窓の接続が 1 経路で済む
- 負: 1 列グリッドが `LazyColumn` と同等の性能かは実測に依存する。乖離があれば本決定を見直す
- 負: `LazyColumn` 固有の補助 API (`fillParentMax*`、snap fling の簡易ヘルパー) を将来 DSL に載せたくなった場合、grid 向けに自前で用意する必要がある
- 負: Compose Foundation 1.8.0 以上が前提になる (grid の `stickyHeader`)

出典: kasane/roadmaps/v1-foundation/phases/phase-3-android-wrapper-foundation/history.md (2026-09-04: ラッパー構成) / core/ADR-0006 / ios/ADR-0003
