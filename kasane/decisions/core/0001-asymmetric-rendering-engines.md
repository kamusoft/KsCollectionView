---
id: 0001
title: 描画エンジンの非対称構成 — iOS は UICollectionView ベース、Android は Compose Lazy 系ラッパー
status: accepted
date: 2026-08-31
---

## Context

並走調査で確認した両プラットフォームの仮想スクロール事情は非対称である:

- **SwiftUI**: `List` は iOS 16+ で UICollectionView 実装のため本物のセル再利用を持つが、グリッドには `List` 相当が存在しない。`LazyVGrid` は生成の遅延 (ビューポート近傍のみ生成) はあるが**再利用プールを持たず**、高速フリング時のフレーム落ち・白抜けが実測報告されている。ネイティブ開発の実務では、重量級グリッドは `UICollectionView` + `UIHostingConfiguration` (iOS 16+、セル中身だけ SwiftUI で書く公式 API) に組み替えるのが定着した解であり、その組み替え (diffable data source・cell registration・compositional layout) が定型ボイラープレートとして残っている
- **Compose**: `LazyColumn` / `LazyVerticalGrid` はともに本物の再利用を持ち (プール上限7 = RecyclerView の scrap 5 + cache 2 と同設計、`contentType` は view type と同概念)、Compose 1.9 の `LazyLayoutCacheWindow` 等で Google が「View と同等」性能を公式に主張する水準。一方 RecyclerView を含む View toolkit は 2026-05 に maintenance mode 宣言済み。RecyclerView 内での Compose ホスティングは KsSettingsView で compose-runtime 実装詳細への依存という保守コストが実証されている (`../KsSettingsView/kasane/decisions/android/0015-customcell-pool-aware-composition-disposal.md`)

グリッドの大量件数対応 (仮想化・再利用が効くこと) は本ライブラリの必須要件とする (ユーザー判断)。

## Decision

描画エンジンをプラットフォームごとに非対称に構成する:

- **iOS: UICollectionView ベースのエンジン**を持つ。セル中身は `UIHostingConfiguration` で SwiftUI として記述させ、利用者に見せる API は SwiftUI の宣言的 DSL とする。スクロール・仮想化・セル再利用は UIKit が担う
- **Android: 独自エンジンを持たず、Compose Lazy 系 (`LazyColumn` / `LazyVerticalGrid`) の薄いラッパー**とする。RecyclerView は採用しない

「同じ書き味」の対称性は公開 DSL の層で担保し、内部構造の非対称は利用者に露出させない。

## Alternatives Considered

- **両プラットフォームとも純宣言的 (標準 Lazy 部品の薄いラッパー)**: 却下。SwiftUI のグリッドに再利用プールがなく、大量件数グリッドで性能が成立しない。リストの逃げ道である `List` はグリッドに使えない。グリッド大量件数対応を守備範囲外と割り切る案も検討したが、仮想化が効かないグリッドは実用に耐えないと判断した
- **両プラットフォームともネイティブエンジン内蔵 (iOS: UICollectionView / Android: RecyclerView)**: 却下。RecyclerView は maintenance mode で新規資産の土台に不適 / Compose Lazy 系が性能同等でありエンジンを重ねる利得がない / RecyclerView 内 Compose ホスティングの保守コストが KsSettingsView で実証済み

## Consequences

- 正: iOS は本物のセル再利用と UIKit のスクロール性能を得る。`UIHostingConfiguration` は Apple 公式の合流点であり、実装詳細依存のリスクが Compose ホスティングより小さい
- 正: Android は標準部品の性能・将来の改善 (pausable composition 等) をそのまま享受し、凍結された土台を避けられる
- 負: プラットフォームで内部構造が根本的に異なるため、実装・テスト・性能検証の戦略が2系統に分岐する
- 負: iOS は UIKit interop (diffable data source・cell registration・compositional layout) の実装と保守を負う
- 負: 公開 DSL の対称性は自動では得られず、内部非対称が API に漏れないよう設計コストを払い続ける必要がある

出典: kasane/changes/revival-feasibility/exploration.md (調査結果: 各機能の実装コスト・検討した選択肢) / cross/ADR-0001
