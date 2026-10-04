# セカンドオピニオン: paging-indicator-color (spec-001)
**相方**: codex / **label**: so-spec-paging-indicator-color-001 / **日付**: 2026-10-04 / **対象**: 提案一式 (proposal.md / specs/collection-paging/spec.md / specs/samples/spec.md / tasks.md / ui/brief.md / ui/mock/indicator-color-a-secondary-text.html / exploration.md)
---
CHANGES_REQUESTED — 3 件（Major 2、Minor 1）

1. **Major — `kasane/changes/paging-indicator-color/tasks.md:20`**
   
   **問題点:** `loadingIndicatorColor` を `onRefresh` の直後に追加すると、既存の位置引数による呼び出しが壊れます。現在、その位置には `reorder` があるため、渡していた `KsReorder` が `Color?` に対応してコンパイルできなくなります（`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:184`）。`proposal.md:38` の「破壊的変更なし」と矛盾します。
   
   **推奨修正:** 既存の呼び出しを維持する互換オーバーロードなどを設計し、位置引数の互換性確認をタスクに追加してください。破壊を許容する場合は、Impact を修正してください。

2. **Major — `kasane/changes/paging-indicator-color/specs/collection-paging/spec.md:6`**
   
   **問題点:** 「表示中に色を変えると追随する」という契約に対し、iOS のドラッグ中更新の扱いが未定義です。既存の `update(configuration:)` はドラッグ中に早期 return し、並べ替え設定以外を保留します（`ios/Sources/KsCollectionView/KsCollectionViewController.swift:235`、`:1705`）。追加読み込み中でも並べ替えは有効にできるため、tasks 1.2・1.3 の通常更新経路だけでは、表示中の色変更がドラッグ終了まで反映されません。
   
   **推奨修正:** ドラッグ中も色だけ即時反映するのか、終了まで保留する例外を設けるのかを明記し、実装タスクと Scenario を追加してください。即時反映する場合は、配列の保留を維持したまま色だけ更新することを検証してください。

3. **Minor — `kasane/changes/paging-indicator-color/specs/collection-paging/spec.md:35`、`:55`**
   
   **問題点:** `proposal.md:15` は3種類すべての表示中変更・解除を約束していますが、変更 Scenario は追加読み込み中だけ、解除 Scenario は解除後に再表示する確認です。tasks 1.5・2.5 も同じ範囲なので、最初の読み込み中や実行中の Pull to Refresh が古い色のままでも、記載された検証を通過できます。
   
   **推奨修正:** 3種類それぞれについて、表示を継続したまま「色A→色B」「指定色→未指定」を確認する Scenario とテストを追加してください。Pull to Refresh は取り直し処理を待機させ、同じ一覧で色変更・解除が反映されることを判定してください。

## 突き合わせ結果

突き合わせの相手はホスト側の自己レビュー (proposal.md「自己レビューの記録」、2 周で新たな問題なし)。相方の 3 件はどれもホスト側が拾えていなかった。

| # | 指摘 | 採否 | 根拠と反映 |
|---|---|---|---|
| 1 | Kotlin の引数を `onRefresh` の次に足すと、位置で渡している既存の呼び出しが壊れる | 採用 | 該当の位置に `reorder` があることをコードで確認した。引数を足す位置を `reorder` の次 (末尾の `content` の前) に変え、既存の引数の順番を変えない形にした (tasks 2.1、proposal の Impact)。互換の別の入口 (オーバーロード) は作らない — 末尾に足せば位置で渡す呼び出しは壊れないため |
| 2 | iOS は並べ替えのドラッグ中に届いた構成を控えるため、「表示中に色を変えると追随する」がドラッグ中は成り立たない | 採用 | `update(configuration:)` がドラッグ中は並べ替えの設定以外を控えることをコードで確認した。色だけを先に当てる経路は足さず、ドラッグ中に届くほかの設定と同じくドラッグが終わってから反映する例外をスペックに書き、Scenario「並べ替えのドラッグ中に色を変える (iOS)」とテストを足した (spec の Requirement「読み込み中の表示の色」、tasks 1.3・1.5、proposal の What Changes) |
| 3 | 表示中の変更と指定を外す確認が、3 つの表示のうち次のページの読み込み中にしか無い | 採用 | 最初の読み込み中や実行中の Pull to Refresh が古い色のまま残る実装でも通ってしまう。Scenario「表示中に色を変える」を 3 つの表示それぞれに広げ、「指定を外すと標準の色に戻る」を表示を出したまま確かめる「表示中に指定を外す」に置き換えた (spec、tasks 1.5・2.5) |

確定 0 件 / 採用 3 件 / 降格 0 件 / 未解決 0 件。
