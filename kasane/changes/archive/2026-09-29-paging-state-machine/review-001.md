# レビュー結果: paging-state-machine (001 回目)

**日付**: 2026-09-27
**判定**: NEEDS_DISCUSSION

## サマリー

両プラットフォームの公開 API・発火の式・待ち方・6 つの表示・表示範囲の置き方・Pull to Refresh は、デルタスペックの Requirement / Scenario にほぼ 1 対 1 で対応するテストが揃っていて、実装も読みやすく分かれています (判定は `KsPagingRequester`、表示の決め方は `KsPagingDisplay`、端の規則は既存の 1 か所に分岐を足す形)。再実行したテストはすべて成功しました (iOS 26.5 SwiftPM 422 件 / iOS 18.6 でページングの 4 クラス 59 件 / iOS Sample UI 34 件 / Android ライブラリ 396 件 / Android Sample 144 件)。

ただし「取り直しの結果は先頭から表示する」(collection-core の追加 Requirement) には問題があります。この規則は、取り直し中の状態が差し替えより前の描画の回で一覧に届くことに頼っています。取得がすぐ終わると両プラットフォームとも静かに効かなくなり、Sample は画面から VM への合図 (受け渡しの手順) を独自に組んで回避しています。これは実装だけでは直せない契約の問題なので、オーナーの判断を仰ぐ NEEDS_DISCUSSION にしました。ほかの指摘は Minor 2 件と Suggestion 1 件です。

## 照合した規約

- ソースコメント規約 (always) — 公開 doc コメントの内部用語、許容参照、禁止する記述類型を節ごとに照合しました。lint の advisory が出した 3 件 (`KsPagingDisplay.kt:47`・`KsPagingRequester.kt:135`・`KsTopSafeArea.kt:75`) は、どれも internal の型の中にあり公開 doc ではないため適合です
- Sample のプラットフォーム間一致 (`samples/**` を触る) — 画面の集合、文言の完全一致 (`SampleScreenParityTest` の文言・寸法の突き合わせ)、構成・パラメータ、`SampleTheme` の色、メニューと画面タイトルの一致を照合しました
- テスト実行規約 (テストの実行・報告) — 全件を実行し、件数まで確かめました。Android は `--rerun-tasks` 付きで回し、XML を集計しています
- iOS / Android 性能検証の手順・スクロール性能の体感ゲート (大量件数・スクロール経路に触れる) — tasks 7.2〜7.4 (体感ゲート・跳ねの目視・塊の境目の見え方) は未チェックのまま正直に残っています。これはオーナーの目視ゲートなので、このレビューでは合否を判断していません
- 実行時挙動の検証規約 — 該当なし (不具合修正ではない)

accepted な ADR: core/ADR-0005・0011・0017・0018、ios/ADR-0006・0008・0009・0010、android/ADR-0001・0003・0006 と照合しました。proposed の core/ADR-0019〜0025 は決定ではないため、CHANGES_REQUESTED の根拠にはしていません (下の論点は所見として出しています)。

## 指摘事項

### [NEEDS_DISCUSSION] 取り直しの結果を先頭から出す規則が、描画の回のまとまり方しだいで静かに効かなくなる

**該当箇所**:
- `ios/Sources/KsCollectionView/KsCollectionView+Paging.swift:35-37` (公開 doc)
- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsPaging.kt:38-40` (公開 KDoc)
- `samples/ios/KsCollectionViewSamples/PagingDemoModel.swift:14-22, 91, 125-147` と `samples/ios/KsCollectionViewSamples/PagingDemoView.swift:25-32`
- `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/PagingDemoModel.kt:39-43, 86-119, 150` と `.../PagingDemoScreen.kt:162-164`

**問題点**:
- 一覧は「差し替えの直前に一覧へ渡された状態」が取り直し中のときだけ先頭へ送ります。iOS の `showsTopOnReplacement` と Android の `KsPositionKeeper.keepEdge` の `precedingPagingState`、どちらも同じ判定です
- VM が「状態を取り直し中にする → 取得 → 配列を差し替えて待機にする」と正しい順で書いても、取得が次の描画より前に終わると事情が変わります (キャッシュ・ローカル DB・遅延 0 など)。2 つの書き換えは SwiftUI の更新 / Compose のフレームで 1 回にまとまり、一覧には取り直し中が一度も届きません。直前の状態は待機のままなので、先頭へ送られません
- 途中までスクロールした 500 件を 50 件に差し替えると、各プラットフォームの既定の位置の保ち方で末尾に着地します。するとすぐ次ページ要求が走ります。core/ADR-0021 (proposed) が防ごうとした状況そのもので、しかも取得の速さしだいで起きたり起きなかったりします
- 実装者もこれに気づいています。両プラットフォームの Sample の VM は、画面が「取り直し中を一覧に渡した」ことを知らせるまで取得を待つ手順を持っています。iOS は `onChange(of: model.state)` → `listDidReceiveRefreshing()` → continuation で、Android は `SideEffect { onDisplayed }` → `CompletableDeferred` → `withFrameNanos` です
- 一方で公開 doc は、無条件に「refreshing の間に配列を差し替えると、差し替えと同時にコンテンツの先頭を表示します」と約束しています。利用者はこの手順の必要を知る手がかりを持ちません
- core/ADR-0021 の負の帰結は「別の更新で書き換える順番」に左右されることしか書いていません。順番が正しくても回がまとまると効かない点は、どの成果物にも記録がありません。design Decision 9 は「Sample の VM は同じ回に書く」としか書いておらず、deviation.md にも記載がありません
- Sample は利用者向けの見本を兼ねるため、画面から VM への合図の手順が「こう書くもの」として写される恐れもあります

**選択肢** (契約・ADR の扱いなので、オーナーが選び、explore / propose 側で扱う):
1. **契約を明文化して受け入れる**: 公開 doc と phase-7 のガイドに「取り直し中が一覧に届いた後の描画の回で配列を差し替える必要がある」ことと書き方を足し、core/ADR-0021 の負の帰結に追記します。Sample の手順は見本として design / deviation に記録します。実装の変更は doc だけで済みますが、利用者の負担は残ります
2. **ライブラリで一部を吸収する**: 引っ張って始めた取り直し (ライブラリが処理を呼んだもの) の実行中とインジケータを出している間に届いた差し替えは、直前の状態によらず取り直しとして先頭を表示します。Pull to Refresh の経路は利用者の書き方によらず確実になります。VM が自分で始める「再読み込み」は 1 の明文化が必要なまま残ります
3. **先頭へ送る合図を明示的な口にする**: 例として、`KsScrollController` の先頭への命令 (core/ADR-0007 のデータ反映後に実行する順序保証を使う) を VM が差し替えと同時に出す規約にするか、差し替えに取り直しの結果だという印を添える口を足します。core/ADR-0021 の改訂 (「直前の状態で決める」の置き換え) が必要です
4. **今のまま受け入れる**: 公開 doc の約束を「状態が取り直し中であることが一覧に届いていれば」に弱めるだけにとどめます

**推奨**: 2 と 1 の組み合わせを勧めます。引っ張る経路はライブラリが確実にし、VM 起点の再読み込みは doc とガイドで条件を明示します。どれを選ぶ場合も、Sample の手順を design / deviation に記録するか、選んだ方式に合わせて簡素化してください。

### [🟡 Minor] 待ち方の控えを捨てる判定が、判定を飛ばす間は行われない

**該当箇所**:
- `ios/Sources/KsCollectionView/KsCollectionViewController.swift:1602-1610` (`evaluatePaging` の guard) と `ios/Sources/KsCollectionView/KsPagingRequester.swift:53-58, 72`
- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:370` と `:712` (`pagingInput` が null を返す条件)

**問題点**:
- `observe(state:itemsVersion:)` (頼んだ時点から状態か配列の版が変わったら控えを捨てる処理) は、`requestIfNeeded` の中からしか呼ばれていません
- iOS は差分の適用中 (`isApplyingSnapshot`) と、一覧が window に載っていない間 (NavigationStack で次の画面を積んだ間など) は `evaluatePaging` ごと飛ばします。Android は配置と構成の件数が食い違う間、判定の材料を null にして collect で捨てます
- その間に状態が「待機 → 追加読み込み中 → 待機」と往復し、配列は変わらなかったとします (続きがあるのに 0 件のページが返った VM など)。すると控えは頼んだ時点と同じ (待機, 同じ版) のまま残ります
- spec の「頼んだ後の待ち方」では状態が変わった時点で次を頼めるはずですが、この場合は配列が変わるまで二度と頼まれず、一覧が止まります。起きる条件は狭いものの、止まると利用者からは原因が見えません

**推奨修正**: 状態と配列の版を知らせる処理を、判定の guard から切り離して毎回の反映で呼んでください。iOS は `update(configuration:)` の中で `pagingRequester.observe(...)` を無条件に呼びます。Android は状態と版を `SideEffect` などで毎回 `observe` に渡します。あわせて、「往復が判定を飛ばす間に起きても次を頼める」ことを確かめる単体・結合テストを 1 件ずつ足してください。

### [🟡 Minor] Android の下端の重なりが、ウィンドウの座標とコンポジションの根の高さを混ぜて求めている

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsTopSafeArea.kt:78-81, 91`

**問題点**:
- `bottomOverlapPx()` は `bottomInWindow` (ウィンドウ上の位置) と `rootHeight - safeBottom` を比べていますが、`rootHeight` はコンポジションの根の高さで、ウィンドウの高さではありません
- `ComposeView` を画面の一部に埋めた構成 (根がウィンドウの下端に届かない) では、ナビゲーションバーに重なっていないのに重なりが出ます。その結果、0 件の表示の真ん中が上にずれます
- 上端 (`overlapPx`) はウィンドウ上の位置どうしで比べているため、上と下で基準がそろっていません

**推奨修正**: 下端もウィンドウの座標で比べてください。例えば `LocalView.current.rootView.height` か `LocalWindowInfo.current.containerSize.height` を基準にします。Robolectric で根がウィンドウより低い構成を 1 件試すと確かめられます。

### [🔵 Suggestion] Android の `KsPagingRequester.cancel()` が本番の経路から呼ばれていない

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsPagingRequester.kt:97-103`

**問題点**: 取り消しは `rememberCoroutineScope` がコンポジションを離れるときに行われ、`cancel()` を呼ぶのはテストだけです。ドキュメント上は「一覧が破棄されたときに呼ぶ」ように読めるため、iOS (`disconnect()` から呼ぶ) と作りが違って見えます。

**推奨修正**: どちらかにそろえてください。例えば `DisposableEffect` の onDispose から呼んで iOS と同じ入口にします。あるいは、スコープの取り消しが唯一の経路だとコメントに書き、`cancel()` は単体テスト用の入口だと明示します。

## 確認した観点 (問題なし)

- **仕様充足**
  - 5 状態の列挙、付属値なし、ライブラリが状態を書き換えないこと
  - 発火の式 (`ceil`、0 件で待機、画面に項目が無いときは頼まない)
  - 見出し・フッター・ページングの表示を数えないこと、グリッドを項目で数えること
  - 判定し直すきっかけ (スクロール・差し替え・状態・大きさ・処理の終わり)
  - 待機のときだけ頼むこと、待ち方、再試行 (待ち方の控えによらず、実行中なら何もしない)
  - 破棄時の取り消しと、画面を積んでも取り消さないこと
  - 不正なしきい値 (値が変わった回に報告して 0 として扱う)
  - 6 つの表示の表、既定の表示 (標準の読み込み中で文言なし)、状態だけの変化での測り直し
  - 0 件の表示の前面・タッチの透過・上下の安全領域の真ん中
  - 端への挿入の例外 (終端以外は末尾に留めない)、取り直しの先頭 (アニメーションを切る差し替え・同じ配列の場合を含む)
  - Pull to Refresh の接続・インジケータ・引っ張れない間・安全領域の下
  - Sample の構成・文言・起動引数・パネル
- **tasks.md**: 7.2〜7.4 以外はチェック済みで、対応する実装とテストがあり、虚偽のチェックはありません。足場 (proposal / design / specs) の書き換えもありません
- **deviation.md と brief の照合結果の合意済み妥協 5 件**: 実装はこれらのとおりで、違反としては扱っていません
- **堅牢性**
  - 取り消した処理が後から終わっても実行中の印を下ろさない (iOS は `Task.isCancelled`、Android は世代)
  - `[weak self]`、MainActor への閉じ込め
  - `CancellationException` の再送出 (Sample の VM)
- **設計品質**
  - 判定を UI から切り離した型に置いたこと、既存の添字の対応を壊さずにフッターの枠へ同居させたこと
  - Android の 0 件から最初のページが届いたときに先頭に留める手当て (フッターの枠を常に置く帰結への対処で、テストあり)
  - iOS の `UIRefreshControl` の描く位置を下げる実装と、取り直し中に足す余白の除き方
    - iOS 26.5 だけでなく、このレビューで iOS 18.6 でもページングの 4 クラス 59 件が通ることを確かめました (UIKit の版による差の懸念は、現時点では見当たりません)
- **Kotlin (kotlin-impl-skill)**
  - explicitApi 下の可視性、`KsPaging` を data class にしない判断 (`KsGroups` と同じ)
  - snapshotFlow の材料をまとめた data class による重複の抑止、`rememberUpdatedState` の使い方
  - structured concurrency (一覧のコンポジションのスコープ)、`!!` や `GlobalScope` を使っていないこと
- **ソースコメント**: 作業文書・通番・SHALL 等の混入はなく、公開 doc に ADR ID や内部用語はありません

## アクションプラン

1. **(オーナー判断)** 取り直しの先頭の規則について、上の選択肢 1〜4 から方針を決めてください。ADR-0021 の改訂または追記が要るなら explore / propose 側で扱います。決まった方針に合わせて、公開 doc (両プラットフォーム) と Sample の手順を直すか、design / deviation に記録します
2. **(実装)** Minor: 待ち方の控えを捨てる処理を、判定の guard から切り離してテストを足します (両プラットフォーム)
3. **(実装)** Minor: Android の下端の重なりをウィンドウの座標にそろえます
4. **(任意)** Suggestion: Android の取り消しの入口を iOS とそろえるか、役割を明記します
5. **(マージ前のゲート)** tasks 7.2〜7.4 (跳ねの目視・体感ゲート・塊の境目の見え方) をオーナーが行います

---

再実行の記録: iOS はこのレビュー用に作った Simulator `ksn-paging-review` (iOS 26.5) と `ksn-paging-review-18` (iOS 18.6) で実行し、終わった後に停止しました。Android は Robolectric (エミュレータなし) です。
