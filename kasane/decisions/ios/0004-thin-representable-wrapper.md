---
id: 0004
title: SwiftUI ラッパーは Store 層を持たない薄い Coordinator 直結にする
status: accepted
date: 2026-09-01
---

## Context

SwiftUI DSL ラッパーの内部構成を決める必要があった。先行実装 KsSettingsViewSwiftUI は「宣言ツリー → 独自 diff 計算 (`DSLDiffCalculator`) → Store → VC が部分操作に変換」の多段構成だが、それが必要だったのはモデルが階層ツリー + 表示/非表示 projection を持つ特殊構造だったため。KsCollectionView の状態モデルは「プレーンな配列 + 安定 ID、差分計算はライブラリの責務」(core/ADR-0003)。

## Decision

`UIViewControllerRepresentable` → Coordinator (VC を保持) → 利用者の配列から snapshot を構築して apply する**薄い 2 層構成**とし、Store 層と独自 diff 計算は持たない。

- 挿入・削除・移動の差分計算は diffable data source に任せる (新配列から snapshot を作って渡すだけ)
- 内容変更の検知 (reconfigure 対象の選定) は旧新 projection の突き合わせ方式 (KsSettingsViewUI `FullSnapshotContentTargets` の翻案) を使う
- スクロール命令 (core/ADR-0007 の「データ反映後実行」) は Coordinator のコマンドキューに積み、`apply` の completion で flush する

## Alternatives Considered

- **KsSettingsViewSwiftUI の Store + 独自 diff 計算層まで踏襲する**: 却下。平坦な配列モデルには過剰で、システムが枯れた差分計算を提供しているのに自前 diff を保守することになる。update 毎のコストも snapshot 再構築 O(n) と同等で利点がない。将来のセクション対応も snapshot の section で自然に表現できる

## Consequences

- 正: 構造が 2 層で単純になり、差分計算の保守がゼロになる
- 正: スクロール命令の順序保証が apply completion と素直に接続する
- 負: 部分操作 (単一セル差し替え等) を狙い撃ちで最適化する経路がなく、常に snapshot 再構築を通る。性能問題が実測で出た場合に最適化層の後付けが必要になる

出典: kasane/roadmaps/v1-foundation/phases/phase-2-ios-engine-foundation/history.md (2026-09-01: SwiftUI DSL ラッパー) / core/ADR-0003 / core/ADR-0007 / ios/ADR-0001
