---
id: 0007
title: スクロール制御 — plain な KsScrollController を両プラットフォーム同名で提供、所有位置は自由
status: accepted
date: 2026-09-01
---

## Context

「新着メッセージで末尾へ」「タブ再タップで先頭へ」のような命令的スクロールは宣言的データフローの外にある。標準機構は SwiftUI が `ScrollViewReader` proxy、Compose が `LazyListState` だが、iOS エンジンは UICollectionView (core/ADR-0001) のため `ScrollViewReader` は効かない。また利用実績 (ColorAnalyzer の `ICameraController`) から、VM が抽象を直接操作する形への要望が確認された。

## Decision

- 命令ハンドル **`KsScrollController`** を両プラットフォーム**同名**で提供する。Compose 側も `state` とは呼ばない — `LazyListState` の `state` はリスト全体の状態窓口の名であり、スクロール命令専用の窓口に流用すると意味がずれる。命令的ハンドルの `Controller` 命名は Compose にも先例がある (`NavController`)
- 命令語彙は ID ベースで1対1: `scrollTo(id:position:animated:)` / `scrollToStart` / `scrollToEnd`。位置は安定 ID (core/ADR-0003) で指す。端への命令名は向き中立の旧実績語彙 (`ScrollToStart` / `ScrollToEnd`) を継承し、将来水平レイアウトを追加しても API が壊れない (core/ADR-0009)
- コントローラは **UI ライフサイクル非依存の plain オブジェクト** (Flutter の `ScrollController` と同型)。View が attach / detach し、所有位置は自由: View 所有 (`@State` / `rememberKsScrollController()`)・VM 所有 (直接命令)・イベント方式 (VM が発行し View が受けて呼ぶ) のいずれも成立する
- 契約: 未接続時の命令は no-op。命令は保留中のデータ反映 (差分適用) 後に実行し、順序保証はライブラリの責務とする — これにより「配列に追加 → 直後に末尾へ」が素朴に書ける
- ドキュメントの標準レシピは View 所有とし、VM 所有もサンプルに載せる

## Alternatives Considered

- **スクロール先を状態として渡す (`scrollTarget: ItemID?`)**: 却下。一度きりの命令を状態で表すと実行後のリセット契約 (誰がいつ nil に戻すか) が利用者に漏れる
- **提供しない (標準機構に丸投げ)**: 却下。iOS だけ命令手段がなくなり対称性が破綻する
- **Kotlin 側を Compose 慣習に寄せて `state` 引数にする**: 却下 (オーナー指摘)。スクロール専用窓口に `state` の名は意味が違いすぎ、慣習の適用として誤り

## Consequences

- 正: VM からの直接命令が配線なしで書け、`ICameraController` 型の MVVM 設計と同構造になる。テストは未接続 no-op / fake で回る
- 正: 命令ハンドル方式は Flutter が大規模に実証済み。VM 所有が Compose / SwiftUI ガイドの主流 (イベント方式) と異なる点も、禁止の実質理由 (UI ライフサイクル縛り・リーク) を plain 化で消している
- 負: VM 所有ではVM がライブラリ型に依存する。KMP 共有 VM からは利用者が interface + expect/actual を1枚挟んで絶縁する必要がある (両プラットフォーム同形なので変換は機械的)
- 負: 「データ反映後実行」の順序保証は phase-2 / phase-3 のエンジン実装に要件として乗る

出典: kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/history.md (2026-09-01: スクロール制御) / core/ADR-0001 / core/ADR-0002 / core/ADR-0003
