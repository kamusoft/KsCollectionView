---
type: concept
title: コレクションの操作とスクロール制御
description: onItemTap / onItemLongTap / touchFeedback の発火規則と、KsScrollController によるスクロール命令の順序保証と位置指定の意味 (iOS / Android 共通)
tags: [core-model, interaction, scroll]
timestamp: 2026-09-05
---

# コレクションの操作とスクロール制御

この文書を読むと、項目のタップ・長押しがいつ発火していつ発火しないか、そしてスクロール命令がデータ更新とどう順序づけられ、指定した位置にどう着地するかが分かる。項目モデルは [collection-items](collection-items.md) を先に読むと分かりやすい。契約は両プラットフォーム共通。

## 目的

リスト・グリッドで定型的に必要になる「項目のタップ」「長押し」「特定の項目や端へのスクロール」を、テンプレートの中に手書きさせずに DSL の語彙として提供する (core/ADR-0007、core/ADR-0009)。

## 公開 API

```swift
KsCollectionView(items) { item in Row(item) }
    .onItemTap { item in select(item) }
    .onItemLongTap { item in showMenu(item) }
    .touchFeedback(color: .accentColor.opacity(0.2))
    .scrollController(controller)   // KsScrollController を View の外で保持する
```

```kotlin
val controller = rememberKsScrollController()   // Composable が持つ場合。ViewModel が持つなら KsScrollController() を直接生成する
KsCollectionView(
    items = items, key = { it.id },
    onItemTap = { item -> select(item) },
    onItemLongTap = { item -> showMenu(item) },
    touchFeedbackColor = MaterialTheme.colorScheme.primary,
    scrollController = controller,
) { template { item -> Row(item) } }
```

`KsScrollController` はどちらのプラットフォームでもプレーンなオブジェクト (`KsScrollController()` で生成できる) で、View のライフサイクルに依存せず ViewModel が所有してよい。

| 命令 | Swift | Kotlin |
|---|---|---|
| ID の項目へ | `scrollTo(id:position:animated:)` | `scrollTo(id, position, animated)` |
| 先頭 / 末尾へ | `scrollToStart(animated:)` / `scrollToEnd(animated:)` | `scrollToStart(animated)` / `scrollToEnd(animated)` |
| 位置 | `KsScrollPosition.start` / `.center` / `.end` | `KsScrollPosition.Start` / `Center` / `End` |

## 保証すること

### タップと長押し

- **タップされた要素が型付きで渡る**。コールバックの引数は配列の要素そのもの。
- **ハンドラを宣言した項目だけがフィードバックを出す**。`onItemTap` も `onItemLongTap` も無い項目は、タッチしてもハイライトしない。既定のフィードバックはプラットフォーム標準の塗り (iOS はハイライト、Android は material3 の ripple — android/ADR-0003)。
- **セル内の操作要素が優先される**。テンプレート内の `Button` / `Toggle` がタッチを処理したときは、項目のタップコールバックもフィードバックも発火しない。セル背景の余白をタップしたときだけ項目タップになる。
- **タップと長押しは排他**。長押しが成立したタッチでは `onItemTap` は発火しない。

### スクロール命令

- **命令はデータ反映後に実行される** (core/ADR-0007)。配列の末尾に要素を追加して同じ処理内で `scrollToEnd()` を呼ぶと、追加後の末尾まで到達する。実行前に対象要素が削除されていれば no-op。
- **命令は呼んだ順に取り出され、取りこぼされない**。次の命令の実行開始時に先行するアニメーションは中断されるため、最終位置は最後の命令のものになる。
- **アニメーションは一方向で着地する**。`Center` / `End` 指定でも、対象を行き過ぎてから戻る動きにならない (Sample「スクロール制御」で実機確認。観測点は [実行時挙動の検証規約](../../../handbook/cross/runtime-behavior-verification.md))。
- **位置の基準は `contentPadding` ([collection-layout](../styling/collection-layout.md)) の内側の表示範囲**。到達できない位置はスクロール可能範囲で clamp される。先頭・末尾付近の項目はスクロール端で止まり、表示範囲より高い項目は先頭合わせになる。
- **未接続・接続解除後・存在しない ID への命令は no-op**。クラッシュも例外も出ない。対象の削除と命令が競合して正当に起きうるため不正入力とは扱わず、debug でも assertion ではなく警告ログに留める。1 つのコントローラを複数の `KsCollectionView` に接続した場合は最後の接続だけが有効 (debug では警告ログ)。

## してはいけないこと

- スクロール命令を「反映前のデータで実行してほしい」と期待しない。命令は常に反映後に解決される。
- `KsScrollController` の API をメインスレッド以外から呼ばない (iOS は MainActor、Android はメインスレッドで debug assertion)。
- `touchFeedbackColor` に同じ生値を渡せば両プラットフォームで同じ見え方になると期待しない (下記の既知の非対称)。

## 既知の非対称: `touchFeedbackColor` の意味論

iOS は渡された色をそのままセル全面の塗りにする。Android は material3 の `ripple` が渡された色に自前で不透明度を掛けるため、iOS で使う半透明の色をそのまま渡すと見えなくなる。Sample「リスト」は描画結果を揃えるために別の生値を渡している (iOS は accent の 15%、Android は accent そのまま)。統一の方向は未決で、後続の変更で扱う (出典: kasane/changes/archive/2026-09-05-android-wrapper-foundation/deviation.md 4 件目)。

## 用語

- **項目タップ**: セル背景 (テンプレートが操作要素を置いていない領域) へのタップ。
- **フィードバック**: タッチ中にセル全面へ表示される塗り。
- **位置 (position)**: 対象項目を表示範囲のどこに置くか。`start` = 先頭揃え、`center` = 中央、`end` = 末尾揃え。

## 関連

- [collection-items](collection-items.md) — 差分反映の単位 (スクロール命令の順序保証はこれに乗る)
- [collection-layout](../styling/collection-layout.md) — `contentPadding` (位置指定の基準になる表示範囲)
- [iOS コレクションエンジン](../../ios/architecture/collection-engine.md) — hitTest による操作要素判定と、apply completion で flush するコマンドキュー
- [Android Compose ラッパー](../../android/architecture/compose-wrapper.md) — `combinedClickable` + ripple と、コンポジション後に最新配列で解決するコマンドキュー
- core/ADR-0007 (スクロール制御)、core/ADR-0009 (タップ・ハイライト)、android/ADR-0003 (material3 依存と ripple)
