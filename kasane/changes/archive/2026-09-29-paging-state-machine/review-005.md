# レビュー結果: paging-state-machine (005 回目)

**日付**: 2026-09-29
**判定**: APPROVED

## サマリー

review-004 の後に入った変更だけを見ました。対象は次の 3 つです。

- Android: 差し替えた「次のページの読み込み中」の表示の範囲から始めた縦のドラッグを、一覧のスクロールに渡す修正 (`ksBlockingTouches` に `scrollable` を足した部分、公開 KDoc、試験 2 件)
- iOS: 同じ場面で一覧がスクロールできることを確かめる試験 1 件 (実装は変えていない)
- 体感ゲートの 2 つの証跡への追記

review-004 の Minor 1 と Minor 2 は、どちらも解消しています。

- Minor 1: 表示の範囲から始めたドラッグで、一覧の中身が同じ量だけ動くようになりました。タップを止めること・中のボタンが押せること・既定の表示が全部下へ通すことも保たれています
- Minor 2: 抜けていた項目 (Android の OS の版、文字サイズ、到達範囲、熱状態) が、事実か「記録していない」として書かれ、限界にも並んでいます

新しい指摘は Minor 2 件と Suggestion 1 件です。どれもマージを止めるものではありません。

- Minor 1: Android で、表示の範囲から始めたドラッグでは、一覧の縦のスクロールインジケータが出ません。端での伸びる効果 (オーバースクロール) も出ない見込みです。スクラッチの写しで確かめました
- Minor 2: iOS の試験は、スクロールを妨げない構造になっていることを確かめているだけで、実際にドラッグしてはいません。そのうち 2 か所は、確かめているつもりのことを確かめていません
- Suggestion: iOS の公開 doc に、ドラッグで一覧がスクロールすることが書かれていません

再実行したテスト (すべて絞り込みなしの全件):

- iOS ライブラリ (SwiftPM、新しく作った Simulator `ksn-paging-review5`、iPhone 17 / iOS 26.5): **440 件成功 / 失敗 0**
  - 新しい試験「差し替えた表示の範囲から始めた縦のドラッグで一覧がスクロールできる」も通過
- Android ライブラリ (`--rerun-tasks`、Robolectric): **414 件成功 / 失敗 0** (XML を集計)
  - `dragFromSubstitutedIndicatorScrollsListInList` / `...InGrid` を含む
- Android Sample (`--rerun-tasks`): **146 件成功 / 失敗 0** (19 クラス。XML を集計)

ホストが報告した件数と一致しています。iOS の Sample の UI テストは実行していません。review-004 の後に Sample と iOS の実装は変わっておらず、Sample は表示を差し替えていないためです。終わった後、Simulator は停止しました。

## 照合した規約

- **ソースコメント規約** (always)
  - `comment-policy-lint.py --advisory` の結果、禁止は 0 件でした (検査対象 407 ファイル)
  - 要確認の 8 件は、どれも今回の差分の外にあります
  - 書き換えた公開 KDoc (`KsPaging.kt:56-61`) と internal の doc (`KsCollectionView.kt:751-755`) は、ADR ID や外部文書に頼らずに読めます
- **スクロール性能の体感ゲート** (性能の証跡を書くとき)
  - 「証跡に残す項目」の表の 6 節の項目を、節ごとに照合しました。下の「前回までの指摘の再確認」に書いたとおり、抜けはありません
  - lessons/code-review.md [L-001] (計測の対象のコードが直前に直されていたら、測り直して値が再現するかを確かめる) も確かめました。今回の修正は、表示を差し替えた一覧にだけ効きます (`KsCollectionView.kt:708,722`)。証跡の Sample は表示を差し替えていないので、測った経路は変わっていません。測り直しは要りません
- **実行時挙動の検証規約** (実行時挙動の不具合の修正の完了を判定するとき)
  - review-004 の Minor 1 の症状 (範囲の中から swipe しても一覧が動かない) は、Robolectric の試験で再現できる種類の不具合です。そのため、規約の「対象外 (ユニットテストで症状を再現できるもの)」に当たります
  - 新しい 2 件の試験は、修正の前なら失敗する形になっています (範囲の中から 300dp 上へ swipe し、先頭の項目が 100dp より大きく上がったことを確かめる)。それが通過したことを、解消の確認として受け入れました
- **テスト実行規約**
  - 3 系統とも全件を実行し、件数を確かめました
  - Android は `--rerun-tasks` を付けて XML を集計しました
- **Sample のプラットフォーム間一致**: 今回は `samples/` を触っていないので、当てはまりません

accepted な ADR (core/ADR-0005・0011・0017・0018、android/ADR-0001・0003・0006、ios/ADR-0006・0008・0009・0010) と照合し、反する点はありませんでした。proposed の core/ADR-0019〜0025 は決定ではないため、判定の根拠にはしていません。

## 前回までの指摘の再確認

| 指摘 (出典) | 状態 | 確かめたこと |
|---|---|---|
| 差し替えた表示の範囲から始めたドラッグで、Android だけ一覧がスクロールしない (review-004 Minor 1) | 解消 (中身が動くことについて) | 詳しくは下の「Android の `scrollable` の付け方の突き合わせ」。範囲の中から始めたドラッグで、一覧の中身は範囲の外から始めたときと同じ量 (150dp のドラッグで 134dp) だけ動きます。付随する見た目 (スクロールインジケータ・オーバースクロール) には差が残ります (下の Minor 1) |
| 体感ゲートの証跡で、「環境」「操作条件」の項目の一部が抜けている (review-004 Minor 2) | 解消 | Android: 環境に「Android 13 / API 33」があり、熱状態は「記録していない (gfxinfo には無い)」とあります。操作条件に「文字サイズ: 端末の文字の倍率 1.0 (`settings get system font_scale`、記録の後に確認)」と「到達範囲: 記録していない」があります。限界にも、熱状態と到達範囲の未記録が並んでいます (`evidence/perf-android-paging.md:4,10,15-16,46-47`)。iOS: 採用した 2 回目の限界に、文字サイズと到達範囲を記録していないことと、7.4 の目視では 500 件の境目を越えたことが書かれています (`evidence/perf-ios-paging.md:101`)。どちらも事実と未記録を分けて書いていて、正直です |
| iOS の 2 つの既定の読み込み中の表示が同じ中身になった (review-004 Suggestion) | 持ち越し (急がない) | 今回の範囲の外です。`paging-indicator-color` で決める扱いのままです |

## Android の `scrollable` の付け方の突き合わせ

一覧は `LazyVerticalGrid` を既定の値で使っています (`KsCollectionView.kt:507-517`。`reverseLayout`・`flingBehavior`・`userScrollEnabled`・`overscrollEffect` は渡していない)。止める側の Box は `Modifier.scrollable(state = gridState, orientation = Vertical, reverseDirection = ScrollableDefaults.reverseDirection(layoutDirection, Vertical, false))` を付けています (`KsCollectionView.kt:756-767`)。

| 観点 | 一覧自身 | 表示の範囲 (差し替え) | 結果 |
|---|---|---|---|
| 向き | 縦 | 縦 | 一致 |
| 反転 | `reverseDirection(dir, Vertical, reverseLayout = false)` | 同じ式に `false` を渡す | 一致。縦のときは書字の向き (RTL) で変わらないため、`layoutDirection` を渡すのは害はないが要らない。試験は、指の向きに中身が動くことを確かめている (`KsPagingAppendingIndicatorTest.kt:219-227`。逆だと先頭で止まって失敗する) |
| 慣性 | `ScrollableDefaults.flingBehavior()` | `flingBehavior = null` で、`scrollable` の中で同じ既定になる | 一致 |
| 入れ子のスクロール | 祖先へ流す | 同じ `BoxWithConstraints` の子なので、同じ祖先へ流す | 一致。スクラッチの写しで、外側に置いた `nestedScroll` の受け手が、範囲の中から始めたドラッグでも外から始めたときと同じ量 (−134dp) を受け取ることを確かめた |
| Pull to Refresh | 土台の `pullToRefresh` は `BoxWithConstraints` に付いていて、入れ子のスクロールで引っ張りを受ける | 同じ土台に届く | 食い違いなし。追加読み込み中は `enabled = acceptsPull` で引っ張れず (`KsCollectionView.kt:415,424`)、表示は追加読み込み中とその後のフェードの間 (200ms) だけ出る。フェードの間に範囲から引っ張ると、外から引っ張ったときと同じに扱われる |
| スクロールインジケータ | ドラッグで出る (`gridState.interactionSource` のドラッグを見る) | **出ない** | 差あり → Minor 1 |
| オーバースクロール (端で伸びる効果) | `LazyVerticalGrid` の既定の `rememberOverscrollEffect()` | `scrollable` の短い形は `overscrollEffect = null` を渡す (foundation 1.11.4 の逆アセンブルで確認) | 差あり (見込み) → Minor 1 |

### 保たれていること

| 観点 | 確かめたこと | 結果 |
|---|---|---|
| 範囲のタップが下の項目に届かない | `substitutedIndicatorWithoutButtonBlocksTouchesInsideItsBounds` (`KsPagingAppendingIndicatorTest.kt:174-191`) が通過。`scrollable` のポインタ入力のノードに加えて `pointerInput` が残っているため、当たり判定は変わらない | 保たれている |
| 中のボタンが押せる | `substitutedIndicatorUsesSamePlacementAndOnlyItsOwnTouches` (`:147-171`) の `clickable` が 1 回受ける。`scrollable` はタッチの許容量 (touch slop) を越えるまで消費しないため、動かさないタップは中の部品に届く。ボタンの上から始めたドラッグは、許容量を越えたところで `scrollable` が消費し、ボタンのクリックは取り消される。一覧の項目の上から始めたドラッグと同じ扱い | 保たれている |
| 既定の表示が全部下へ通す | `blocksIndicatorTouches` が false のときは修飾を付けずに描く (`KsCollectionView.kt:708,722-726`)。`tapOnDefaultIndicatorReachesItemBelow` (`:134-144`) が通過 | 保たれている |
| 範囲の外は下へ通る | 上の 2 件の試験の「表示の外のタッチは下の項目へ通る」が通過 | 保たれている |

### 両プラットフォームで観察できる振る舞い

| 振る舞い (差し替えた表示の範囲) | iOS | Android | 結果 |
|---|---|---|---|
| タップ | 範囲の中身だけがタッチを受け、下の項目の選択は起きない (`KsPagingIndicatorView.swift:45-49`) | `ksBlockingTouches` で止める | 一致 |
| ドラッグで中身が動く | 入れ物は `UICollectionView` の子なので、一覧のパンがタッチを受ける | `scrollable` で `gridState` を動かす | 一致 |
| 慣性・向き | 一覧自身のパン | 上の表のとおり同じ既定 | 一致 |
| スクロールインジケータ | 一覧自身のパンなので出る | 出ない | 差あり (Minor 1) |
| 端の効果 | 一覧自身のバウンス | 伸びる効果が付かない見込み | 差あり (Minor 1) |

## 指摘事項

### [🟡 Minor] Android で、差し替えた表示の範囲から始めたドラッグでは、スクロールインジケータが出ず、オーバースクロールも付かない

**該当箇所**:
- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:751-767` (`ksBlockingTouches`)
- 関係する箇所: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsScrollIndicator.kt:80-84` (`gridState.interactionSource.collectIsDraggedAsState()`)

**問題点**:
- スクロールインジケータは、`gridState.interactionSource` のドラッグを見て「利用者のスクロール」と判定し、表示します
  - `ksBlockingTouches` の `scrollable` は `interactionSource` を渡していないので、このドラッグは一覧の interactionSource に出ません
  - そのため、範囲の中から始めたドラッグと、その後の慣性の間、インジケータは出ません
- スクラッチの写しに一時的な試験を足し、Robolectric (画素で読む。`KsScrollIndicatorTest` と同じ方法) で確かめました (リポジトリには置いていません)
  - 差し替えた表示 (120×30dp の `Text`) の中から 150dp 上へ、指を置いたままドラッグしました。中身は 134dp 動きましたが、バーの濃さは **0.0** でした
  - 範囲の外 (左端) から同じ操作をすると、中身は 134dp 動き、バーの濃さは **1.0** でした
- `scrollable` の短い形は `overscrollEffect = null` を渡します (foundation 1.11.4 の `ScrollableKt` の逆アセンブルで確かめた)
  - そのため、範囲の中から始めたドラッグで一覧の端を越えても、Android 12 以降の伸びる効果は付かない見込みです (これはコードからの推論で、試験では確かめていません)
  - 追加読み込み中は末尾の近くにいることが多いので、この場面は起きやすい方です
- iOS は一覧自身のパンが受けるため、どちらも出ます。「一覧自身のスクロールと同じ」という `ksBlockingTouches` の doc (「一覧自身のスクロールと同じ向きと慣性にする」) は向きと慣性については正しいものの、見た目の付属物はそろっていません
- 起きるのは、利用者が表示を差し替えた一覧で、画面の下端の中央の小さな範囲から指を置いたときだけです。中身が動かなかった review-004 の問題と比べると、ずっと小さい差です

**推奨修正** (どちらか):
1. 付属物もそろえる
   - `MutableInteractionSource` を 1 つ作って `ksBlockingTouches` の `scrollable` に渡し、`rememberKsScrollIndicatorVisibility` がそのドラッグも「利用者のドラッグ」として見るようにする (2 つの `collectIsDraggedAsState` の論理和など)
   - オーバースクロールは、`rememberOverscrollEffect()` を 1 つ作って `LazyVerticalGrid(overscrollEffect = …)` と `scrollable(overscrollEffect = …)` の両方に渡す。描画は一覧の側に付くため、両方の入力で同じ効果が伸びる
   - 試験は、既存の `assertDragFromSubstitutedIndicatorScrolls` に、ドラッグの間にバーが出ること (`KsScrollIndicatorTest` の画素の読み方) を足す
2. 差として受け入れる。`ksBlockingTouches` の doc を「向きと慣性は一覧と同じ。スクロールインジケータと端の効果は付かない」に直し、deviation.md に記録する

### [🟡 Minor] iOS の試験は構造を確かめているだけで、そのうち 2 か所は確かめているつもりのことを確かめていない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsPagingIndicatorTests.swift:195-251`

**問題点**:
- この試験は実際にはドラッグしません。確かめているのは、スクロールを妨げない構造かどうかです
  - タッチを受けるビューが一覧の子孫であること
  - パンが有効であること
  - `touchesShouldCancel(in:)` が true であること
  - XCTest の単体テストからタッチを合成できないことを考えると、この方法自体は妥当です
  - 入れ物を一覧の外 (兄弟のビュー) に移すような後戻りは、実際に捕まえられます
- ただし、次の 2 か所は意図どおりに働いていません。スクラッチの写しで、当たったビューとジェスチャーの一覧を出力して確かめました
  1. **「ボタンあり」の場合分けが、ボタンを通っていない** (`:204-209`)
     - どちらの場合分けも、当たったビューは `.background(KsPagingProbeRepresentable…)` の `KsPagingProbeView` でした
     - 当たったビューから上へたどると、`KsPagingProbeView` → `UIKitPlatformViewHost` → `UIHostingContentView` → `KsPagingIndicatorView` → `UICollectionView` です
     - UIKit の当たり判定は、下地に敷いた UIView を返します。そのため、「ボタンあり」も「押せる部品なし」と同じ経路を確かめていて、SwiftUI のボタンがタッチを受ける場合を確かめていません
  2. **ジェスチャーの確かめ (`:239-249`) の条件が逆向きで、失敗しようがない**
     - `recognizer.delegate?.gestureRecognizer?(recognizer, shouldRequireFailureOf: pan)` が true になるのは、「その認識器がパンの失敗を待つ」ときです。つまりパンが先に進める側で、パンを止める条件ではありません
     - パンを待たせるのは、次のどちらかです
       - `gestureRecognizer(recognizer, shouldBeRequiredToFailBy: pan)` が true (パンがその認識器の失敗を待つ)
       - パンの側の `shouldRequireFailureOf: recognizer` が true
     - 実際に見つかった認識器は、`UIHostingContentView` の `UIKitHoverGestureRecognizer` 1 つだけでした (`canPrevent(pan) = false`、delegate は nil)
     - 条件が正しい向きでも、今の構成では何も捕まえません。ただ、将来、中身にパンを待たせる認識器が入ったときにも捕まえられない書き方になっています
- 振る舞いの結論 (iOS では範囲の中から始めたドラッグで一覧がスクロールする) は、UIKit の仕組みから見て正しいと考えます。試験の名前とコメント (「ボタンを持つ表示」「パンより先にタッチを取るジェスチャーが無い」) が、実際に確かめている範囲より広いことが問題です

**推奨修正**:
- 「ボタンあり」は、下地の探り針を外すか、表示の範囲の外に置きます。そのうえで、当たったビューが `UIHostingContentView` (またはその中) になることを確かめます。どうしてもボタンの経路を通せないなら、場合分けを削って 1 つにします
- ジェスチャーの条件は、パンを待たせる向き (`shouldBeRequiredToFailBy: pan`、または `pan.delegate` の `shouldRequireFailureOf: recognizer`) に直します。直すのが難しければ、ループを削ってコメントを実態に合わせます
- 試験のコメントか名前に、「ドラッグそのものは合成できないため、スクロールを妨げない構造を確かめる」と書きます

### [🔵 Suggestion] iOS の公開 doc に、ドラッグで一覧がスクロールすることが書かれていない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionView+Paging.swift:70-72`

**問題点**:
- Android の公開 KDoc には「表示の範囲から始めたドラッグは一覧のスクロールになります」が足されました (`KsPaging.kt:60-61`)
- iOS は「その表示の範囲だけタッチを受けます」のままです。振る舞いは両プラットフォームで一致したのに、iOS の doc だけを読むと、スクロールも止まるように読めます

**推奨修正**: iOS にも「表示の範囲から始めたドラッグは一覧のスクロールになります」を 1 文足してください。phase-7 のガイドでも同じ言い方にそろえると、読み手が迷いません。

## 所見 (指摘ではない)

- **`ksBlockingTouches` の `pointerInput`**
  - `scrollable` もポインタ入力のノードを持つため、当たり判定を作るだけなら `pointerInput` は要らなくなっています
  - それでも、`scrollable` の設定を後で変えても止める働きが残るように、別に持っておく意味はあります。害はありません
- **Android の文字サイズの記録**: 「記録の後に確認」と書かれています。記録中に設定を変えていないという前提の上の値です。次回の比較には十分ですが、次回は記録の前に確かめると確実です
- **足場**
  - proposal / design / specs は HEAD から書き換えられていません
  - tasks.md と deviation.md は、review-004 の後に変わっていません (ファイルの更新時刻で確認)。今回の修正は差として受け入れたものではなく、そろえる修正なので、deviation.md に書き足すものはありません
- **Minor 2 (review-004) の iOS 1 回目の記録**: 1 回目の限界には、文字サイズと到達範囲の未記録が書き足されていません。1 回目は「未判定」で合否に使っていないので、指摘にはしません

## 確認した観点 (問題なし)

- **仕様充足**
  - collection-paging の「次のページの読み込み中」の Scenario の置き場・出る条件・既定のタッチの扱いは、今回の差分で変わっていません
  - verify-002 の ⚠️ (deviation 記録済み) のままです
- **堅牢性**
  - `scrollable` は `gridState` を直接動かすため、中身が収まっていて動かない一覧では何もしません
  - 表示が消えるフェードの間も、止めるかどうかは差し替えの有無だけで決まり、途中で振る舞いが変わりません
- **Kotlin (kotlin-impl-skill)**
  - `!!`・`GlobalScope`・`runBlocking` は使っていません
  - `pointerInput` のコルーチンは取り消しに任せていて、`CancellationException` を握りつぶしていません
  - `scrollable` の引数は名前付きで、意図が読めます
- **テスト (Android)**
  - list とグリッドの 2 件で、範囲の中から始めた swipe で先頭の項目が 100dp より大きく上がることを確かめています。修正を外すと 0dp のままになり失敗する形です (review-004 のスクラッチでの確かめと同じ条件)
  - 押せる部品を持たない表示で確かめているので、中の部品が消費してスクロールしたように見える取り違えはありません
  - 項目が見えなくなった場合 (`after == null`) もスクロールしたと扱っていて、偽の失敗になりません
- **ソースコメント**: 新しいコメントと KDoc は単独で読めます

## アクションプラン

1. **(Minor)** Android で、範囲の中から始めたドラッグでもスクロールインジケータとオーバースクロールが一覧と同じに出るようにする (推奨修正 1)。または、差として doc と deviation.md に書く (推奨修正 2)
2. **(Minor)** iOS の試験の「ボタンあり」の場合分けとジェスチャーの条件を直し、試験が確かめる範囲をコメントに書く
3. **(任意)** iOS の公開 doc に、ドラッグで一覧がスクロールすることを 1 文足す

---

再実行の記録:

- iOS は、このレビュー用に作った Simulator `ksn-paging-review5` (iPhone 17 / iOS 26.5) で実行し、終わった後に停止しました。既存の Simulator・エミュレータ・実機には触れていません
- Minor 1 と Minor 2 の確かめは、`android/` と `ios/` をスクラッチに写した中にだけ一時的な試験と出力を足して行い、リポジトリの作業ツリーは変えていません。写しは確かめた後に trash で片付けました
- Android は Robolectric (エミュレータなし) です
