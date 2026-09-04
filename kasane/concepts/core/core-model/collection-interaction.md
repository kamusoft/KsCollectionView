---
type: concept
title: コレクションの操作とスクロール制御
description: onItemTap / onItemLongTap / touchFeedback の発火規則と、KsScrollController によるスクロール命令の順序保証
tags: [core-model, interaction, scroll]
timestamp: 2026-09-03
---

# コレクションの操作とスクロール制御

この文書を読むと、項目のタップ・長押しがいつ発火していつ発火しないか、そしてスクロール命令がデータ更新とどう順序づけられるかが分かる。項目モデルは [collection-items](collection-items.md) を先に読むと分かりやすい。iOS 実装が先行しており (2026-09-03 時点)、Android は同じ契約に追随する。

## 目的

リスト・グリッドで定型的に必要になる「項目のタップ」「長押し」「特定の項目や端へのスクロール」を、テンプレートの中に手書きさせずに DSL の modifier として提供する (core/ADR-0007、core/ADR-0009)。

## 公開 API

```swift
KsCollectionView(items) { item in Row(item) }
    .onItemTap { item in select(item) }
    .onItemLongTap { item in showMenu(item) }
    .touchFeedback(color: .accentColor.opacity(0.2))
    .scrollController(controller)   // KsScrollController を View の外で保持する
```

`KsScrollController` はプレーンなオブジェクトで、`scrollTo(id:position:animated:)` (position は `.start` / `.center` / `.end`)、`scrollToStart(animated:)`、`scrollToEnd(animated:)` を持つ。View のライフサイクルに依存せず、ViewModel が所有してよい。

## 保証すること

- **タップされた要素が型付きで渡る**。コールバックの引数は配列の要素そのもの。
- **ハンドラを宣言した項目だけがフィードバックを出す**。`onItemTap` も `onItemLongTap` も無い項目は、タッチしてもハイライトしない。既定のフィードバックはプラットフォーム標準の塗り、`touchFeedback(color:)` で色を指定できる。
- **セル内の操作要素が優先される**。テンプレート内の `Button` や `Toggle` がタッチを処理したときは、項目のタップコールバックもフィードバックも発火しない。セル背景の余白をタップしたときだけ項目タップになる。
- **タップと長押しは排他**。長押しが成立したタッチでは `onItemTap` は発火しない。
- **スクロール命令はデータ反映後に実行される** (core/ADR-0007)。配列の末尾に要素を追加して同じ処理内で `scrollToEnd()` を呼ぶと、追加後の末尾まで到達する。命令は未完了の最後の差分反映が完了してから実行され、実行前に対象要素が削除されていれば no-op になる。
- **未接続・接続解除後のコントローラへの命令は no-op**。クラッシュも警告も出ない。存在しない ID への命令も no-op (debug では警告ログ)。
- 1 つのコントローラを複数の `KsCollectionView` に接続した場合は最後の接続だけが有効 (debug では警告ログ)。

## してはいけないこと

- スクロール命令を「反映前のデータで実行してほしい」と期待しない。命令は常に反映後に解決される。
- `KsScrollController` の API を MainActor 以外から呼ばない。公開 API は MainActor 上で提供される。

## 用語

- **項目タップ**: セル背景 (テンプレートが操作要素を置いていない領域) へのタップ。
- **フィードバック**: タッチ中にセル全面へ表示される塗り。

## 関連

- [collection-items](collection-items.md) — 差分反映の単位 (スクロール命令の順序保証はこれに乗る)
- [iOS コレクションエンジン](../../ios/architecture/collection-engine.md) — タップ判定の実現 (hitTest による操作要素判定) とコマンドキュー
- core/ADR-0007 (スクロール制御)、core/ADR-0009 (タップ・ハイライト)
