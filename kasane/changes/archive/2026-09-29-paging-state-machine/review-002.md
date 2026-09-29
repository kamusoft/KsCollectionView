# レビュー結果: paging-state-machine (002 回目)

**日付**: 2026-09-27
**判定**: APPROVED

## サマリー

前回の確定指摘 5 件 (NEEDS_DISCUSSION 1・Major 2・Minor 1・Suggestion 1) は、すべて解消していました。取り直しの先頭の規則は、オーナー判断 (deviation.md の最後の項目。選択肢 2 と 1 の組み合わせ) のとおりに両プラットフォームで実装されています。公開 doc にも、VM が自分で始める取り直しの条件と対処が書かれています。修正で新しく入った重大な問題はありません。

新しい指摘は Minor 1 件と Suggestion 1 件です。Minor は、項目があるときに取り直しが失敗した場合 (配列が変わらない場合) に iOS だけ先頭へ戻る、というプラットフォーム間の差です。どちらも優先度は低く、マージを止めるものではありません。

再実行したテスト:

- iOS ライブラリ: 全 429 件成功 (新しく作った Simulator `ksn-paging-review2`、iOS 26.5)
  - 1 回目は、この change が触れていない `KsImageCacheContractTests` の 1 件が収束待ちの期限切れで失敗しました
  - そのクラスだけの 3 回の反復 (117 件) と全件の再実行は、どちらも失敗 0 件でした (所見を参照)
- iOS Sample UI テスト (通常スキーム): 全 34 件成功 (PagingDemoUITests を含む。計測ドライバは含まない)
- Android ライブラリ: 全 403 件成功 (24 クラス)
- Android Sample: 全 144 件成功 (19 クラス)
- Android は、どちらも `--rerun-tasks` 付きで実行し、XML を集計しました

## 照合した規約

- ソースコメント規約 (always)
  - 変更した Swift / Kotlin 80 ファイルに `comment-policy-lint.py --advisory` をかけ、禁止は 0 件でした
  - 要確認は 5 件です。うち ADR 参照の 3 件 (`KsPagingDisplay.kt:47`・`KsPagingRequester.kt:135`・`KsTopSafeArea.kt:85`) は、internal の型の doc で、公開 doc ではありません
  - 「履歴記述」の 2 件 (`KsCollectionView+Paging.swift:39`・`KsCollectionViewController.swift:1739`) は、「同値のままだった場合」という条件の言い回しを拾った誤検出で、適合です
  - 公開 doc に ADR ID・内部用語・作業文書の参照は入っていません
- Sample のプラットフォーム間一致 (`samples/**` を触る)
  - 画面の集合・文言・構成を見ました。前回から Sample のソースは変わっていません
  - 「本体公開 API のプラットフォーム差で一致が不可能な箇所を黙認しない」の節を、下の Minor に適用しました
- テスト実行規約 (テストの実行・報告)
  - 全件を実行し、件数まで確かめました
  - 1 回目の iOS の失敗は、絞り込みの反復と全件の再実行の両方で扱いました
- 実行時挙動の検証規約: 該当なし (不具合修正ではありません)
- スクロール性能の体感ゲート・iOS / Android の性能検証 (大量件数・スクロール経路)
  - tasks 7.2〜7.4 は、未チェックのまま正直に残っています
  - オーナーの目視ゲートなので、このレビューでは合否を判断していません

accepted な ADR (core/ADR-0005・0011・0017・0018、ios/ADR-0006・0008・0009・0010、android/ADR-0001・0003・0006) と照合し、反する点はありませんでした。proposed の core/ADR-0019〜0025 は決定ではないため、判定の根拠にはしていません。ADR-0021 の本文と負の帰結への反映は、deviation.md のとおり蒸留時に行う扱いです。

## 前回の指摘の解消状況

| 前回の指摘 | 状態 | 確かめたこと |
|---|---|---|
| [NEEDS_DISCUSSION] 取り直しの結果を先頭から出す規則が、描画の回のまとまり方で効かなくなる | 解消 (オーナー判断どおり) | 下の「前回の指摘の確認の詳細」を参照 |
| [Major] iOS で有効な大きいしきい値のときに `Int` への変換で落ちる | 解消 | 下の「前回の指摘の確認の詳細」を参照 |
| [Major] Android の下端の重なりが、ウィンドウの座標と根の高さを混ぜている | 解消 | 下の「前回の指摘の確認の詳細」を参照 |
| [Minor] 待ち方の控えを捨てる判定が、判定を飛ばす間は行われない | 解消 | 下の「前回の指摘の確認の詳細」を参照 |
| [Suggestion] Android の `KsPagingRequester.cancel()` が本番の経路から呼ばれていない | 解消 | `KsCollectionView.kt` の `DisposableEffect(pagingRequester) { onDispose { pagingRequester.cancel() } }` で、iOS (`disconnect()`) と同じく「一覧が破棄されたとき」の入口になりました |

### 前回の指摘の確認の詳細

**取り直しの先頭 (NEEDS_DISCUSSION)**

- 実装
  - iOS の `showsTopOnReplacement` は `isPullRefreshing` の間を無条件に先頭にし、Android の `KsPositionKeeper.keepEdge` は `isPullRefreshing` の間の差し替えを `requestScrollToItem(0)` にします。どちらも、引っ張って始めた取り直しの間の差し替えを、直前の状態によらず先頭にしています
  - VM が自分で始める取り直しでは、先頭へ送られない条件と対処 (取り直し中が届いてから差し替える / `scrollToStart` を一緒に出す) を公開 doc に書いています (`KsCollectionView+Paging.swift:35-44`、`KsPaging.kt:38-48`)。`scrollToStart` は両プラットフォームに実在します
  - Sample の受け渡しの手順は、見本として残っています
- テスト
  - iOS は `KsPullToRefreshTests` の 4 件、Android は `KsPullToRefreshTest` の 3 件です
  - 対象は、状態が 1 回にまとまる list / グリッド・ページングなし・インジケータを出し終えた後は送らないことです
  - Android は、実際の Compose の状態で 3 つの書き換えを 1 回の描画にまとめて確かめています
- 追加の確認: iOS の単体テストは、取り直しの処理の中から `update(configuration:)` を直接呼んでいます。そのため、SwiftUI の `.refreshable` と `ObservableObject` を通る実際の経路も、作業ツリーの写しに一時的なテストを足して確かめました (リポジトリには置いていません)
  - 条件: 500 件を 6,000pt までスクロールして引っ張り、処理の中で `state = .refreshing; items = 50 件; state = .idle` を待たずに続けて書く
  - 結果: 最終位置はコンテンツの先頭 (y = 0 = -adjustedContentInset.top)、先頭の項目は新しい配列の先頭

**iOS の大きいしきい値 (Major)**

- `KsPagingRequester.isNearEnd` は、残りの数と許容量を `Double` のまま比べるようになりました (`KsPagingRequester.swift:37-40`)
- `1e19`・`Double(Int.max)`・`greatestFiniteMagnitude` のテストがあります。掛け算の結果が無限大になる場合も、`remaining <= inf` で「頼む」側に倒れます
- Android も `Float` の計算を `Double` で比べるだけで、`Int` への変換はありません

**Android の下端の重なり (Major)**

- 下端も、ウィンドウの座標どうしで比べるようになりました (`bottomInWindow` と `view.rootView.height - safeBottom`、`KsTopSafeArea.kt:90-94, 97-105`)
- `KsPagingEmbeddedSafeAreaTest` の 2 件で確かめています
  - 根の上に 100dp の View を置き、根がウィンドウの下端に届かないときは重ならない
  - 根が下端まで届くときは、重なった 48dp だけを除く

**待ち方の控え (Minor)**

- iOS は `update(configuration:)` の冒頭で毎回 `pagingRequester.observe(...)` を呼び、判定の guard と切り離しました
- Android は、コンポジションごとに `SideEffect` で `observe` を呼びます
- 単体テスト (iOS `test判定をしない間に知らせた状態の往復で控えを捨てる`、Android `observedRoundTripWithoutEvaluationReleasesLatch`) と結合テストがそろっています
  - iOS `test判定を飛ばす間に状態が往復しても画面に戻ったら次を頼む`: window から外した間の往復
  - Android `stateRoundTripWhileEvaluationIsSkippedAllowsNextRequest`: 表示範囲の高さ 0 の間の往復

## 指摘事項

### [🟡 Minor] 項目があるときの取り直しが失敗して配列が変わらないと、iOS だけ先頭へ戻る

**該当箇所**:
- `ios/Sources/KsCollectionView/KsCollectionViewController.swift:997-1006` (`showContentTopIfRefreshEnded`)
- `ios/Sources/KsCollectionView/KsCollectionViewController.swift:1735-1743` (`finishPullRefresh` の `showsContentTop: !pullRefreshShowedContentTop`)
- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsPositionKeeper.kt:83` (`previousItems !== items` のときだけ `keepEdge`)

**問題点**:
- iOS は配列を同値比較で扱うため、「同じ配列を返した取り直し」と「配列を差し替えなかった更新」を見分けられません (design の Context と表の「待ち方・再試行」の行に、iOS は同値比較・Android は参照の比較と書かれている差です)
- そのため iOS では、次の 2 つで表示範囲が先頭へ戻ります
  - 状態が取り直し中から抜けた更新で配列が同値のとき (VM が始めた取り直し)
  - 引っ張って始めた取り直しで差し替えが一度も届かなかったとき
- 取り直しが失敗して VM が配列を触らずに状態を戻した場合も、これに当たります
- Android は配列の参照が同じなら位置を触らないため、同じ失敗では元の位置に残ります
- Sample の「項目があるときの取り直しの失敗」で差が出ます。途中までスクロールして「再読み込み」を押す (または引っ張った後にスクロールする) と、iOS は「更新できませんでした」の帯と一緒に先頭へ戻り、Android は元の位置のまま帯が出ます
- 同値の配列で先頭を表示すること自体は iOS のテスト (`test前と同じ配列を返す取り直しでも取り直し中から抜ける回に先頭を表示する`・`test引っ張って始めた取り直しの結果が同じ配列でも先頭を表示する`) で意図されています。しかし、失敗のときの両プラットフォームの差は deviation.md にも spec にもありません
- sample-parity の「本体公開 API のプラットフォーム差で一致が不可能な箇所を黙認しない」に当たります
- なお、SwiftUI の実際の経路で結果を先頭から表示できているのは、この「差し替えが無ければ終わるときに先頭」の手当てによる可能性があります (上の追加の確認では最終位置しか見ていません)。単純に外すのは勧めません

**推奨修正**: どちらかにしてください。
1. iOS と Android の差として deviation.md に記録する (「取り直しが配列を変えずに終わったとき、iOS は先頭を表示し、Android は位置を保つ。iOS は同値の配列を差し替えと見分けられないため」)。phase-7 のガイドにも、失敗時に位置を保ちたい VM の書き方を載せる
2. そろえる。例えば Android でも、状態が取り直し中から抜けた回とインジケータを出し終えた回に、同じ配列でも先頭を表示する。iOS の失敗時の動きに合わせる形です

### [🔵 Suggestion] iOS の取り直しの先頭のテストが、SwiftUI の `.refreshable` を通る経路を含んでいない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsPullToRefreshTests.swift:373-416` (`test引っ張って始めた取り直しの間の差し替えは直前の状態によらず先頭を表示する` ほか)

**問題点**:
- この規則の対象は、利用者が `.refreshable` の中で `@Published` を書き換え、SwiftUI の更新で一覧へ届く経路です
- 今の iOS のテストは、処理の中から `controller.update(configuration:)` を同期で呼んでいます。そのため、SwiftUI が更新を後の回に回したときの順序 (処理の終わりと差し替えのどちらが先に一覧へ届くか) を確かめていません
- 上の追加の確認では最終位置が先頭になりましたが、回帰を防ぐテストがありません
- Android のテストは実際の Compose の状態で書いているため、この差はありません

**推奨修正**: `KsPagingRefreshableView` の形で、`ObservableObject` の VM (取り直しの処理の中で `state = .refreshing`・50 件への差し替え・`state = .idle` を待たずに続けて書く) を `UIHostingController` に載せます。途中までスクロールして引っ張り、最終位置が先頭であることを確かめるテストを 1 件足してください。

## 所見 (指摘ではない)

**iOS ライブラリの 1 回目の全件実行の失敗**

- 失敗したのは `KsImageCacheContractTests.test引き当てて表示中の画像はメモリのみ消去の後に別のソースの削除があっても置き換わらない` で、「削除した別のソースの取り直し が期限内に収束しませんでした。実測値: 1」でした
- このクラスはこの change の diff に含まれていません
- クラスだけの 3 回の反復 (117 件) と全件の再実行では失敗 0 件だったため、この change による失敗ではなく、混んだ実行機で出る間欠的な失敗と判断しました
- 同じ失敗が繰り返すなら、image-loading 側の別件として扱うのがよさそうです

**Observation のループの検出ログ**

- iOS の全件実行のログに、`Observation tracking feedback loop detected` (UICollectionView の `updateProperties`) が 83 回出ています
- ページングを触らない既存のテスト (`KsGroupingEngineTests` など) でも出ているため、この change で入ったものではありません

## 確認した観点 (問題なし)

- **仕様充足**
  - 前回確かめた Requirement / Scenario の対応に、修正で崩れたものはありません
  - 修正に関係する Scenario は次のとおりです
    - 途中で取り直す / 大きな一覧を取り直す / Pull to Refresh の取り直し / 状態を取り直し中にしない差し替え
    - 頼みが無視されたとき / 読み込み中に画面を閉じる
    - 0 件の表示の真ん中
  - deviation.md の最後の項目の範囲 (「インジケータを出し終えるまで」の間だけ、ページングの有無によらない) どおりに実装されています。出し終えた後の差し替えを送らないことは、両プラットフォームでテストされています
- **tasks.md**
  - 7.2〜7.4 以外はチェック済みで、虚偽のチェックはありません
  - 足場 (proposal / design / specs) は HEAD から書き換えられていません
  - brief.md の差分は「照合結果」の追記だけです
- **deviation.md と brief の照合結果の合意済み妥協 5 件**: 違反としては扱っていません
- **堅牢性**
  - iOS の取り直しの処理は `disconnect()` で取り消され、取り消した後の終わりでは印を下ろしません
  - Android の `KsPullRefresh` と `KsPagingRequester` は、世代で前の処理の終わりを捨てます
  - しきい値の非有限・巨大値で落ちません
  - `KsTopSafeArea` は配置の前 (`windowHeight == 0`) に重なり 0 を返します
- **Kotlin (kotlin-impl-skill)**
  - `DisposableEffect` と `rememberCoroutineScope` による取り消しの入口を一本化しています
  - `SideEffect` で observe し、コンポジションの途中で状態を書き換えていません
  - `!!`・`GlobalScope`・`runBlocking` は使っていません
  - explicitApi 下の可視性、KDoc の単独での読みやすさにも問題はありません
- **ソースコメント**: 修正で書き換えたコメントは、どれも外部文書の ID に頼らず単独で読めます

## アクションプラン

1. **(任意・低優先)** Minor: 取り直しが配列を変えずに終わったときの iOS と Android の差を、deviation.md に記録するか、そろえるかを決めてください (オーナー判断)
2. **(任意)** Suggestion: iOS に SwiftUI の `.refreshable` を通る取り直しの先頭のテストを 1 件足します
3. **(マージ前のゲート)** tasks 7.2〜7.4 (跳ねの目視・体感ゲート・塊の境目の見え方) をオーナーが行います

---

再実行の記録:

- iOS は、このレビュー用に作った Simulator `ksn-paging-review2` (ライブラリと追加の確認) と `ksn-paging-review2-ui` (Sample UI テスト) (どちらも iOS 26.5) で実行し、終わった後に停止しました
- 追加の確認の一時的なテストは、スクラッチの写しの中にだけ置きました
- Android は Robolectric (エミュレータなし) です
