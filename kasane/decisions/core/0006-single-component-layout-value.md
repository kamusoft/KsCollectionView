---
id: 0006
title: レイアウト指定 — 単一コンポーネント + layout 値、向き別列数を一級サポート
status: proposed
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

## Alternatives Considered

- **リストとグリッドを別コンポーネントに分ける**: 却下。リスト⇔グリッドの表示切替でビューツリーが丸ごと入れ替わり状態 (スクロール位置等) が飛ぶ。セクション別レイアウト (phase-4) とも合成しにくい
- **クロージャで動的計算 (`(画面情報) -> レイアウト`)**: 却下。9割の利用者に過剰で、宣言から静的に読めない。必要になれば layout 値のエスケープハッチとして後付けできる

## Consequences

- 正: データ・テンプレート・ページングの宣言を変えずにレイアウトだけ差し替えられる (表示切替 UI が書きやすい)
- 正: phase-4 で「セクションごとに layout 値を付与する」拡張が同じ語彙で乗る
- 負: Android ラッパーは layout 値によって内部 Composable (`LazyColumn` / `LazyVerticalGrid`) を切り替えるため、切替時の状態引き継ぎ (スクロール位置) を実装で担保する必要がある

出典: kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/history.md (2026-09-01: レイアウト指定の DSL) / core/ADR-0001 / core/ADR-0002
