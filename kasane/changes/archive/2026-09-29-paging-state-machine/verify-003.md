# 一致検証: paging-state-machine (003 回目)

**日付**: 2026-09-29
**判定**: VALID
**対象**: 作業ツリーの未コミットの変更すべて (`git diff HEAD` と未追跡ファイル。ios/ android/ samples/ 配下)
**デルタスペック**: `specs/collection-paging/spec.md` (ADDED 14 Requirement / 37 Scenario)、`specs/collection-core/spec.md` (MODIFIED 1 / ADDED 1 Requirement、10 Scenario)、`specs/samples/spec.md` (ADDED 5 Requirement / 13 Scenario)

## サマリー

- 全 21 Requirement・60 Scenario を 1 行ずつ、両プラットフォームの実装箇所と試験 (または証跡) に対応づけ直した
  - ❌ (未記録の欠落・乖離) は 0 件
  - Scenario の判定そのものが ⚠️ (deviation 記録済み) なのは 2 件。collection-paging の「次のページの読み込み中 (既定)」(置き場・出入り・下地。`deviation.md:10,11,16,17`、brief の照合結果 6)、samples の「項目があるときの取り直しの失敗」(帯。`deviation.md:6`、照合結果 5)。残りの 58 件は ✅
- verify-002 の後に入った変更 (既定の読み込み中の表示から下地を外した・差し替えた表示の範囲のタップを止めドラッグを一覧のスクロールにした・iOS の試験・公開 doc・体感ゲートの証跡・tasks 7.2〜7.4) は、spec と deviation の組み合わせに一致している (下の「前回からの変更の突き合わせ」)
- review-005 の 3 件は、Minor 1 と Suggestion が解消、Minor 2 は 3 点のうち 2 点が解消して 1 点 (試験のコメントに「ドラッグは合成しない」と書く) が残る。残りは試験の説明の書き方で、一致の判定には影響しない (下の「review-005 の指摘の解消の確認」)
- tasks.md の 33 件はすべてチェック済みで、虚偽はない。7.2〜7.4 のチェックは evidence/ の 2 つの証跡の判定 (どちらも合格) と食い違わない
- 逆流は無い。proposal / design / specs は HEAD (提案のコミット `58efa6c`) から変わっていない
  - tasks.md の差分は `- [ ]` → `- [x]` の 33 行だけ
  - ui/brief.md の差分は末尾の「照合結果」「照合結果 (2 回目)」の追記だけ (削除行 0)
- 試験は 4 系統とも、このワーカーが絞り込みなしの全件で実行し、すべて成功した (件数は「試験の実行」)

deviation.md の項目は番号を持たないため、この文書ではファイルの行番号 (`deviation.md:<行>`) で指す。verify-002 の後に `deviation.md:15` (公開 API の改名)・`:16` (0.2 秒のフェードでの出入り)・`:17` (既定の表示の下地を外す) が足されている。15 と 16 は verify-002 の所見 1・2 の記録にあたる。

## 前回からの変更の突き合わせ

verify-002 の後にファイルが書き換わったのは、iOS の `KsPagingIndicatorView.swift`・`KsPagingDefaultIndicator.swift`・`KsCollectionView+Paging.swift`・`KsCollectionViewController.swift`・`KsPagingIndicatorTests.swift` と、Android の `KsCollectionView.kt`・`KsScrollIndicator.kt`・`KsPaging.kt`・`KsPagingDisplay.kt`・`KsPagingAppendingIndicatorTest.kt`・`KsScrollIndicatorTest.kt` だけ (verify-002.md より新しい更新時刻のファイルを検索)。`samples/` は iOS / Android とも書き換わっていない。

| 変更 | spec の該当 | 合意の記録 | 実装 (iOS / Android) | 試験 (iOS / Android) | 結果 |
|---|---|---|---|---|---|
| 既定の次のページの読み込み中の表示から、円の下地と影を外す | collection-paging「ページングの表示」(差し替えていないときは標準の読み込み中の表示を出し、文言を持たない) | `deviation.md:17`、brief の照合結果 6 (ios-02・ios-02b・android-02・android-02b を撮り直して 2026-09-29 承認) | `KsPagingDefaultIndicator.swift:5-10` (`ProgressView` だけ) / `KsPagingAppendingIndicatorDefault` (`KsPagingDisplay.kt:81-86`、`CircularProgressIndicator` だけ) | `KsPagingIndicatorTests.swift:23` (表示の枠が標準の読み込み中の部品の大きさと同じ) / `KsPagingAppendingIndicatorTest.kt:70,76,84` (表示の高さが読み込み中の表示の直径 24dp)、`indicatorBounds` (`:382`) は読み込み中の semantics だけで位置を取る | ⚠️ 一致 (合意どおり。標準の読み込み中の表示・文言なしは spec のまま) |
| 差し替えた表示の範囲のタップを止め、範囲から始めた縦のドラッグは一覧のスクロールにする | spec は次のページの読み込み中の表示のタッチを定めない (外の操作を妨げない規則は 0 件の表示だけ) | 公開 doc (`KsCollectionView+Paging.swift:70-72` / `KsPaging.kt:59-61`) | iOS: 入れ物を一覧 (`UICollectionView`) の子に置き (`KsCollectionViewController.swift:1676-1690`)、差し替えたときだけ中身がタッチを受ける (`KsPagingIndicatorView.swift:45-49`、`isReplaced` `KsPagingDisplays.swift:36`)。一覧のパンがそのままタッチを受ける / Android: `ksBlockingTouches` (`KsCollectionView.kt:766-785`) が `scrollable` で `gridState` を動かし、`pointerInput` で下の項目へのタップを止める。インジケータへの知らせ (`overlayDragInteractions` `:340-341`) と端で伸びる効果 (`overscrollEffect` `:343,518`) は一覧と共有 | `KsPagingIndicatorTests.swift:135,160,196` / `KsPagingAppendingIndicatorTest.kt:142,155,182,202,208,242`、`KsScrollIndicatorTest.kt:121` | ✅ (両プラットフォームで同じ観察できる振る舞い。spec の Scenario の判定に影響しない) |
| iOS の公開 doc に「差し替えた表示の範囲から始めたドラッグでも一覧はスクロールする」を足す | 同上 | — | `KsCollectionView+Paging.swift:72` | — | ✅ (Android の `KsPaging.kt:60-61` と同じ内容) |
| 体感ゲートの証跡 2 つ (Android の新規・iOS の 2 回目の採用走行) と tasks 7.2〜7.4 のチェック | Scenario なし (design Decision 10・design の Risks) | — | — | `evidence/perf-android-paging.md`、`evidence/perf-ios-paging.md` | 下の「追加検査」の tasks と証跡の突き合わせ |

## review-005 の指摘の解消の確認

ksn-review の観点 (指摘の問題点と推奨修正を満たしたか、試験が修正の前なら失敗する形か、別の後戻りを入れていないか) で確かめた。

| 指摘 (review-005) | 状態 | 確かめたこと |
|---|---|---|
| 🟡 Minor 1: Android で差し替えた表示の範囲から始めたドラッグでは、スクロールインジケータが出ず、オーバースクロールも付かない | **解消** | 推奨修正 1 (付属物もそろえる) の形で直っている。下の 1 |
| 🟡 Minor 2: iOS の試験は構造を確かめるだけで、「ボタンあり」がボタンの経路を通らず、ジェスチャーの条件が逆向き | **ほぼ解消 (1 点が残る)** | 推奨修正の 3 点のうち、「ボタンあり」の経路とジェスチャーの向きは直っている。「ドラッグそのものは合成しない」と試験のコメントか名前に書く点は入っていない。下の 2 |
| 🔵 Suggestion: iOS の公開 doc に、ドラッグで一覧がスクロールすることが書かれていない | **解消** | `KsCollectionView+Paging.swift:72` に「差し替えた表示の範囲から始めたドラッグでも、一覧はスクロールします。」が入った。Android の `KsPaging.kt:60-61` (「表示の範囲から始めたドラッグは一覧のスクロールになります」) と同じ内容 |

### 1. Minor 1 (Android のインジケータとオーバースクロール)

- **スクロールインジケータ**
  - `KsCollectionView.kt:340` で知らせの経路 (`MutableInteractionSource`) を 1 つ作り、`ksBlockingTouches` の `scrollable` の `interactionSource` に渡している (`:777`)
  - `rememberKsScrollIndicatorVisibility` (`KsScrollIndicator.kt:79-90`) は、一覧自身のドラッグと、この経路のドラッグの論理和を「利用者のドラッグ」として見る。引数は既定値 `null` を持ち、渡さない呼び出しは従来と同じ (一覧の知らせを 2 回見るだけ)
  - 試験 `indicatorIsShownWhileDraggingFromSubstitutedAppendingIndicator` (`KsScrollIndicatorTest.kt:121`): 差し替えた表示 (120×30dp) の真ん中から指を置いたまま上へドラッグし、バーの濃さが 1 になることを確かめる。review-005 がスクラッチで測った修正前の値は 0.0 なので、修正を外せば失敗する形
- **オーバースクロール (端で伸びる効果)**
  - `KsCollectionView.kt:343` で `rememberOverscrollEffect()` を 1 つ作り、`LazyVerticalGrid(overscrollEffect = …)` (`:518`) と `ksBlockingTouches` の `scrollable(overscrollEffect = …)` (`:775`) の両方に渡している
  - `LazyVerticalGrid` の既定の引数も `rememberOverscrollEffect()` のため、差し替えていない一覧の効果は従来と同じ
  - 試験 `dragFromSubstitutedIndicatorUsesListOverscrollEffect` (`KsPagingAppendingIndicatorTest.kt:242`): `LocalOverscrollFactory` を記録する実体に差し替え、効果の実体が一覧で 1 つだけ作られること、差し替えた表示の範囲から始めたドラッグのスクロールがその実体を通ることを確かめる。修正前 (`scrollable` の短い形は `overscrollEffect = null`) なら、ドラッグはどの実体も通らず失敗する形
  - 伸びる見た目そのものは Robolectric では見ていない。同じ実体を通ることの確認で十分と判断した (描画は一覧の側に付く)
- **保たれていること**: タップを止めること (`:182`)、中のボタンが押せること (`:155`)、既定の表示が下へ通すこと (`:142`)、list / グリッドで中身が動くこと (`:202,208`) の試験は、今回の全件実行で通過した
- **doc**: `ksBlockingTouches` の doc (`KsCollectionView.kt:760-765`) は「向き・慣性・端で伸びる効果を一覧と同じにし、ドラッグの知らせをスクロールインジケータに届ける」に直り、実装と一致する。推奨修正 1 を採ったため、deviation.md への記録は要らない (差として受け入れたものではない)

### 2. Minor 2 (iOS の試験)

- **「ボタンあり」の経路 (直っている)**
  - 試験の 2 つの場合分けの中身から目印のビュー (`KsPagingProbeRepresentable`) を外した (`KsPagingIndicatorTests.swift:197-210`、コメント `:195`)
  - 当たったビューが差し替えた表示の中身 (SwiftUI のホスティング) かその子孫であること (`:233`)、目印のビューではないこと (`:234`) を確かめる。推奨修正の「当たったビューが `UIHostingContentView` (またはその中) になることを確かめる」のとおり
- **ジェスチャーの条件の向き (直っている)**
  - `panWaitsForFailure` (`:258-263`) は、「認識器がパンに失敗を待たせる」(`shouldBeRequiredToFail(by: pan)` と、その代理の `shouldBeRequiredToFailBy: pan`) か、「パンがその認識器の失敗を待つ」(`pan.shouldRequireFailure(of:)` と、パンの代理の `shouldRequireFailureOf: recognizer`) のどちらかで true になる。パンを待たせる向きに直っていて、review-005 が挙げた 2 つの条件をどちらも含む
  - 当たったビューから一覧までの祖先をたどり、有効な認識器ごとにこの条件を確かめる (`:241-252`)
- **試験が確かめる範囲の書き方 (残る)**
  - 推奨修正の 3 点目「試験のコメントか名前に、『ドラッグそのものは合成できないため、スクロールを妨げない構造を確かめる』と書く」は入っていない
  - コメント (`:192-195`) は確かめる仕組み (一覧の子に重ねてあるのでパンに届き、中身のタッチを取り消せる) を説明しているが、ドラッグを実際には行わないことは書かれていない。試験の名前 (`:196`「…縦のドラッグで一覧がスクロールできる」) は、実際に確かめている範囲 (構造) より広いまま
  - 見立て: 実装ではなく試験の説明の直し。コメントに 1 文 (例:「単体テストからはドラッグを合成できないため、スクロールを妨げない構造を確かめる」) を足せば閉じる。一致の判定には影響しない

## 対応表

凡例: ✅ 一致 / ⚠️ deviation 記録済み / ❌ 欠落・乖離

パスの略記:

- iOS 本体のソース: `ios/Sources/KsCollectionView/`
- iOS 本体の試験: `ios/Tests/KsCollectionViewTests/`
- Android 本体のソース: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/`
- Android 本体の試験: `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/`
- iOS Sample: `samples/ios/KsCollectionViewSamples/`、UI 試験は `samples/ios/KsCollectionViewSamplesUITests/PagingDemoUITests.swift`
- Android Sample: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/`、試験は同じパッケージの `src/test/...`

試験名の後ろの数字は、その試験の関数が始まる行 (iOS は `func test...` の行、Android は `fun` の行)。verify-002 の後に書き換わっていないファイルの行は verify-002 と同じ (今回、行を読み直して確かめた)。

### collection-paging

| Requirement / Scenario | 実装 (iOS / Android) | 試験 (iOS / Android) | 状態 |
|---|---|---|---|
| **ページングの状態** (5 値・付属値なし・書き換えない) | `KsPagingState.swift:5` / `KsPagingState.kt:9` | `KsPublicAPITests.swift:303` / `KsCollectionViewPublicApiTest.kt:262` | ✅ |
| └ ライブラリは状態を書き換えない | 状態は設定から読むだけ (`evaluatePaging`、`KsCollectionViewController.swift:1722`) / `KsCollectionView.kt:385-411` | `KsPagingTriggerTests.swift:261` / `KsPagingTriggerTest.kt:240` | ✅ |
| **ページングの設定** (非同期関数・しきい値の既定 1) | `KsCollectionView+Paging.swift:55` / `KsPaging.kt:74-78`、`KsCollectionView.kt:170-171` | `KsPublicAPITests.swift:311,323,333,343` / `KsCollectionViewPublicApiTest.kt:277,293,312` | ✅ |
| └ ページングを付けない一覧 | `evaluatePaging` の guard (`KsCollectionViewController.swift:1723-1730`) / `pagingInput` が null (`KsCollectionView.kt:804`)、`hasFooterSlot` (`:187`)、重ねる表示は `paging != null` のときだけ (`:710`) | `KsPagingTriggerTests.swift:243` / `KsPagingTriggerTest.kt:225` | ✅ |
| **追加読み込みの発火** | `KsPagingRequester.swift:31,64`、`visiblePagingItems` (`KsCollectionViewController.swift:1749`) / `KsPagingRequester.kt:58,129`、`pagingInput` (`KsCollectionView.kt:804`) | 単体: `KsPagingRequesterTests.swift:39-87` / `KsPagingRequesterTest.kt:33-95` | ✅ |
| └ 既定のしきい値で 1 画面分手前で頼む | 同上 | `KsPagingTriggerTests.swift:26` / `KsPagingTriggerTest.kt:66` | ✅ |
| └ しきい値 2 | 同上 | `KsPagingTriggerTests.swift:49` / `KsPagingTriggerTest.kt:81` | ✅ |
| └ しきい値 0 | 同上 | `KsPagingTriggerTests.swift:65` / `KsPagingTriggerTest.kt:93` | ✅ |
| └ グリッドは項目の数で数える | `sectionItemRanges` で配列上の位置に変換 (`KsCollectionViewController.swift:1752`) / `itemIndexOfLazy` | `KsPagingTriggerTests.swift:83` / `KsPagingTriggerTest.kt:105` | ✅ |
| └ 画面に項目が出ていないとき | `KsPagingRequester.swift:64-92` / `KsPagingRequester.kt:58-83` | `KsPagingTriggerTests.swift:141` / `KsPagingTriggerTest.kt:155` (単体: `KsPagingRequesterTests.swift:87` / `KsPagingRequesterTest.kt:95`) | ✅ |
| └ 見出しとフッターは数えない | セルだけを数える (`visiblePagingItems`)。下端に重ねた表示は一覧のサブビューでセルではない / lazy の項目だけを数え、重ねた表示は lazy の要素ではない | `KsPagingTriggerTests.swift:109` / `KsPagingTriggerTest.kt:119` | ✅ |
| **判定し直すきっかけ** | スクロール `scrollViewDidScroll` (`:345`)・レイアウトの確定 `viewDidLayoutSubviews` (`:352`)・差分の適用の完了・設定の更新・処理の終わり `pagingRequestDidFinish` (`:1715`) / `snapshotFlow` で状態・配列・しきい値・表示範囲・実行中を観測 (`KsCollectionView.kt:385-411`) | 下の 3 行 | ✅ |
| └ 1 ページが画面に満たないとき | 同上 | `KsPagingTriggerTests.swift:170` / `KsPagingTriggerTest.kt:169` | ✅ |
| └ 失敗から待機に戻ったとき | 同上 | `KsPagingTriggerTests.swift:195` / `KsPagingTriggerTest.kt:186` | ✅ |
| └ 回転で画面に出る項目の数が変わったとき | 同上 (一覧の大きさの変化で判定) | `KsPagingTriggerTests.swift:221` / `KsPagingTriggerTest.kt:209` (どちらも一覧の大きさを変えて再現) | ✅ |
| **初回の読み込み** | `KsPagingRequester.swift:64-92` (0 件で待機なら頼む) / `KsPagingRequester.kt:71` | 下の 1 行 | ✅ |
| └ 空で待機なら頼む | 同上 | `KsPagingTriggerTests.swift:272` / `KsPagingTriggerTest.kt:253` (単体: `KsPagingRequesterTests.swift:71` / `KsPagingRequesterTest.kt:75`) | ✅ |
| **待機のときだけ自動で頼む** | `KsPagingRequester.swift:64-92` / `KsPagingRequester.kt:69` | 単体: `KsPagingRequesterTests.swift:104` / `KsPagingRequesterTest.kt:115` | ✅ |
| └ 終端では頼まない | 同上 | `KsPagingTriggerTests.swift:210` / `KsPagingTriggerTest.kt:199` | ✅ |
| └ 失敗では自動で頼まない | 同上 | `KsPagingTriggerTests.swift:195` の前半 / `KsPagingTriggerTest.kt:186` の前半 (単体: 上と同じ) | ✅ |
| **頼んだ後の待ち方** | 控えと実行中の印 (`KsPagingRequester.swift:54,112`) / (`KsPagingRequester.kt:47,105`)。配列の版は iOS が中身の比較 (`KsCollectionViewController.swift:199-201`)、Android が `KsPagingItemsVersion` (`KsPagingRequester.kt:153`)。状態と版は毎回知らせる (`KsCollectionViewController.swift:205` / `KsCollectionView.kt:375-378`) | 下の 3 行と、判定を飛ばす間の往復 `KsPagingTriggerTests.swift:329` / `KsPagingTriggerTest.kt:266` | ✅ |
| └ VM が状態の書き換えを遅らせても二重に頼まない | 同上 | `KsPagingRequesterTests.swift:125` / `KsPagingRequesterTest.kt:131` | ✅ |
| └ 処理の中で待つ VM | 同上 | `KsPagingRequesterTests.swift:139` / `KsPagingRequesterTest.kt:146` | ✅ |
| └ 頼みが無視されたとき | 同上 | `KsPagingRequesterTests.swift:153` / `KsPagingRequesterTest.kt:171` | ✅ |
| **一覧が破棄されたときの取り消し** | `disconnect()` → `pagingRequester.cancel()` (`KsCollectionViewController.swift:380`) / `DisposableEffect` → `cancel()` (`KsCollectionView.kt:381-383`) | 取り消さない側: `KsPagingTriggerTests.swift:308` (iOS のみ。Android はナビゲーションの仕組みに任せる — spec の本文どおり) | ✅ |
| └ 読み込み中に画面を閉じる | 同上 | `KsPagingTriggerTests.swift:294` / `KsPagingTriggerTest.kt:289` | ✅ |
| **不正なしきい値** | `reportInvalidPagingThresholdIfNeeded` (`KsCollectionViewController.swift:1772`)、`effectiveThreshold` (`KsPagingRequester.swift:49`) / `invalidThresholdMessage` (`KsPaging.kt:100`、`KsCollectionView.kt:237`)、`effectiveThreshold` (`KsPagingRequester.kt:139`) | `KsPagingTriggerTests.swift:373`、`KsPagingRequesterTests.swift:252` / `KsPagingTriggerTest.kt:333` (debug の停止)、`KsPagingRequesterTest.kt:258` | ✅ |
| └ 負のしきい値 (release) | 同上 | `KsPagingTriggerTests.swift:354` / `KsPagingTriggerTest.kt:315` | ✅ |
| **ページングの表示** (6 つの表示・置き場・差し替え・既定) | 表: `resolve`・`placement` (`KsPagingDisplay.swift:33-50`) / `resolve` (`KsPagingDisplay.kt:50-57`)。既定: `KsPagingDisplays.swift:18-33`、`KsPagingDefaultIndicator.swift`、`KsPagingDefaultProgress.swift` / `KsPaging.kt:89-97`、`KsPagingDisplay.kt:64,81`。フッターの枠 (失敗・終端): `configurePagingFooter` (`KsCollectionViewController.swift:1526`)、`KsPagingFooterStack.swift` / `KsCollectionView.kt:661-682`。下端に重ねる (次のページの読み込み中): `updatePagingIndicator` (`KsCollectionViewController.swift:1631`) / `KsCollectionView.kt:707-736`。0 件: `updatePagingPlaceholder` (`KsCollectionViewController.swift:1572`)、`KsPagingPlaceholderView.swift:45` / `KsCollectionView.kt:687-703` | 表の全組み合わせ: `KsPagingDisplayTests.swift:28` / `KsPagingDisplayTest.kt:52` | ⚠️ (次のページの読み込み中の置き場・出入り・下地は `deviation.md:10,11,16,17`。失敗・終端の幅は `deviation.md:3`) |
| └ 次のページの読み込み中 (既定) | 同上 | `KsPagingDisplayTests.swift:48`、`KsPagingIndicatorTests.swift:23,62` / `KsPagingDisplayTest.kt:72`、`KsPagingAppendingIndicatorTest.kt:70,76,84,90` | ⚠️ (文言なしの標準の読み込み中が下地なしで出ることは一致。「最後の項目の後ろ」は、見えている範囲の下端に重ねる形に置き換え済み — `deviation.md:10,11,17`、照合結果 6) |
| └ 最初の読み込み中 (既定) | 同上 | `KsPagingDisplayTests.swift:71` / `KsPagingDisplayTest.kt:86,97` | ✅ |
| └ 失敗・終端・空は既定では出ない | 同上 | `KsPagingDisplayTests.swift:88` / `KsPagingDisplayTest.kt:105` | ✅ |
| └ 差し替えた表示が出る | 同上 | `KsPagingDisplayTests.swift:153` / `KsPagingDisplayTest.kt:129` (次のページの読み込み中の差し替えは `KsPagingIndicatorTests.swift:160` / `KsPagingAppendingIndicatorTest.kt:155`) | ✅ |
| └ VM が始めた取り直しの間は項目の上に何も出さない | 表の `(.refreshing, false)` / `Refreshing -> null`。重ねる表示も状態が追加読み込み中のときだけ (`KsCollectionView.kt:719`) | `KsPagingDisplayTests.swift:179` / `KsPagingDisplayTest.kt:169` | ✅ |
| └ 状態だけが変わったとき | `invalidatePagingFooterIfNeeded` (`KsCollectionViewController.swift:1543`)、`updatePagingIndicator` は毎回の `update` で呼ぶ / 状態を読んで再構成、`AnimatedVisibility` の `visible` (`KsCollectionView.kt:718-719`) | `KsPagingDisplayTests.swift:195`、`KsPagingIndicatorTests.swift:84` / `KsPagingDisplayTest.kt:181`、`KsPagingAppendingIndicatorTest.kt:107` | ✅ |
| └ 0 件の表示がヘッダーと重なっても押せる | 手前に重ね、外のタッチは通す (`KsPagingPlaceholderView.swift:45`) / `zIndex(1f)` (`KsCollectionView.kt:698`) | `KsPagingDisplayTests.swift:229` / `KsPagingDisplayTest.kt:202` (どちらも外のタッチが下へ通ることも確かめる) | ✅ |
| **再試行** | `retryPaging` (`KsCollectionViewController.swift:1708`)、`KsPagingRequester.swift:95` / `retryPaging` (`KsCollectionView.kt:366`)、`KsPagingRequester.kt:86` | 単体: `KsPagingRequesterTests.swift:174,187,194` / `KsPagingRequesterTest.kt:182,194,204` | ✅ |
| └ 項目があるときの再試行 | 同上 | `KsPagingDisplayTests.swift:321` / `KsPagingDisplayTest.kt:268` | ✅ |
| └ 0 件のときの再試行 | 同上 | `KsPagingDisplayTests.swift:344` / `KsPagingDisplayTest.kt:291` | ✅ |
| **Pull to Refresh の接続** | `@Environment(\.refresh)` (`KsCollectionView.swift:28,37-38`)、`syncPullRefreshControl` (`KsCollectionViewController.swift:1788`) / `onRefresh` 引数 (`KsCollectionView.kt:171`)、`Modifier.pullToRefresh` (`:429-440`) | `KsPullToRefreshTests.swift:31` (渡さない一覧は引っ張れない)、`:51` (`.refreshable` を受け取る) / `KsPullToRefreshTest.kt:81` | ✅ |
| └ 引っ張ると取り直しの処理が呼ばれる | 同上 | `KsPullToRefreshTests.swift:17` / `KsPullToRefreshTest.kt:57` (ページングの有無の両方) | ✅ |
| └ 0 件でも引っ張れる | 同上 | `KsPullToRefreshTests.swift:40` / `KsPullToRefreshTest.kt:94` | ✅ |
| **Pull to Refresh のインジケータ** | `handlePullRefresh`・`endPullRefreshIfFinished`・`finishPullRefresh` (`KsCollectionViewController.swift:1809,1828,1835`)、`KsRefreshControl.swift` / `KsPullRefresh.kt:43,63,67`、`PullToRefreshDefaults.Indicator` (`KsCollectionView.kt:742-749`) | 追加で `KsPullToRefreshTests.swift:161` / `KsPullToRefreshTest.kt:153,205` | ✅ |
| └ 処理の中で待つ取り直し | 同上 | `KsPullToRefreshTests.swift:69` / `KsPullToRefreshTest.kt:105` | ✅ |
| └ 処理がすぐ戻る取り直し | 同上 | `KsPullToRefreshTests.swift:88` / `KsPullToRefreshTest.kt:122` | ✅ |
| └ VM が始めた取り直しでは出さない | 同上 | `KsPullToRefreshTests.swift:110` / `KsPullToRefreshTest.kt:142` | ✅ |
| └ 全画面の一覧でも見える | `addRefreshExtraTopInset` (`KsCollectionViewController.swift:1876`)、`KsRefreshControl.swift:32,47`、`KsCompositionalLayout.swift` の `refreshExtraTopInset` / `offset { topSafeArea.overlapPx() }` (`KsCollectionView.kt:748`) | `KsPullToRefreshTests.swift:184,268,303,317` / `KsPullToRefreshTest.kt:224`。証跡: `evidence/ios-pull-to-refresh-*.png`・`evidence/android-pull-to-refresh-*.png` (tasks 5.4) | ✅ (Android の Sample ではステータスバーの分を下げる処理が働かない点は ⚠️ 照合結果 4) |
| **追加読み込みの間は引っ張れない** | `syncPullRefreshControl` の `blocksPull` (`KsCollectionViewController.swift:1797-1802`) / `acceptsPull` → `enabled` (`KsCollectionView.kt:424,432`) | 下の 3 行 | ✅ |
| └ 追加読み込み中に引っ張る | 同上 | `KsPullToRefreshTests.swift:127` の前半 / `KsPullToRefreshTest.kt:169` の前半 | ✅ |
| └ 処理の実行中に引っ張る | 同上 | `KsPullToRefreshTests.swift:143` / `KsPullToRefreshTest.kt:187` | ✅ |
| └ 追加読み込みが終わった後 | 同上 | `KsPullToRefreshTests.swift:127` の後半 / `KsPullToRefreshTest.kt:169` の後半 | ✅ |

注 (ページングの表示の「高々 1 つ」): 出す表示は状態と件数の表 (`resolve`) で 1 つに決まり、置き場の振り分け (`placement` / `isFooter`) も排他になっている。状態が追加読み込み中から失敗・終端に変わった直後、下端の表示が 0.2 秒のフェードで消える間だけフッターの枠の表示と重なって見える。これは `deviation.md:16` に記録され、tasks 7.2 の基準機の目視 (両プラットフォームとも問題なし) で確かめられた。

注 (次のページの読み込み中の差し替えた表示のタッチ): spec はこの表示のタッチを定めない。両プラットフォームとも「範囲のタップは止める・範囲から始めたドラッグは一覧のスクロール (インジケータと端の効果を含む)・範囲の外は下へ通す・既定の表示は全部下へ通す」にそろい、公開 doc に同じ内容が書かれている。spec の外の振る舞いのため対応表の判定には入れていない。

### collection-core

| Requirement / Scenario | 実装 (iOS / Android) | 試験 (iOS / Android) | 状態 |
|---|---|---|---|
| **端を表示中の端への挿入** (MODIFIED) | `edgeToKeep` (`KsCollectionViewController.swift:971-998`。直前が終端以外なら末尾を返さない `:992-994`)、差し替えの直前の状態の受け渡し (`:282`) / `keepEdge` (`KsPositionKeeper.kt:100-137`。`:130`) | 下の 6 行 | ✅ |
| └ いちばん上での先頭への挿入 | 既存の規則のまま | `KsEdgeInsertionTests.swift:41` (list / グリッド、グループ・フッターの有無の組み合わせ) / `KsCollectionViewGroupingTest.kt:760,766,904` | ✅ |
| └ いちばん下での末尾への挿入 (ページングなし) | 既存の規則のまま (ページングなしは直前の状態が nil / null) | `KsEdgeInsertionTests.swift:69` / `KsCollectionViewGroupingTest.kt:772,778,927,933` | ✅ |
| └ ルートのフッターがあるときの末尾への挿入 (ページングなし) | 同上 | `KsEdgeInsertionTests.swift:69` のフッターありの組み合わせ / `KsCollectionViewGroupingTest.kt:829` | ✅ |
| └ 追加読み込みで届いたページは今の位置の下に現れる | 直前が追加読み込み中なら末尾に留めない | `KsPagingPositionTests.swift:20` (list / グリッド) / `KsPagingPositionTest.kt:44,50` | ✅ (GIVEN の「次のページの読み込み中の表示が見えている」は下端に重ねる形で成り立つ。`deviation.md:10`) |
| └ 最後のページが届くのと同時に終端になる | 同上 | `KsPagingPositionTests.swift:56` / `KsPagingPositionTest.kt:56` | ✅ |
| └ 終端の後に末尾へ足した項目 | 直前が終端なら従来どおり末尾に留める | `KsPagingPositionTests.swift:74` / `KsPagingPositionTest.kt:63` | ✅ |
| **取り直しの結果は先頭から表示する** (ADDED) | `showsTopOnReplacement` (`KsCollectionViewController.swift:1005`)、`showContentTopIfRefreshEnded` (`:1013`)、`finishPullRefresh` (`:1835`)、`returnToContentTopAfterRefresh` (`:1850`) / `keepEdge` の先頭 (`KsPositionKeeper.kt:110-113`)、`isPullRefreshing` の受け渡し (`KsCollectionView.kt:422,477`) | 下の 4 行。塊の件数が変わる差し替え: `KsPagingPositionTests.swift:220`。同じ ID・同じ配列の取り直し: `KsPagingPositionTests.swift:131,168` | ✅ (Pull to Refresh の間の規則の追加は ⚠️ `deviation.md:8`。取り直しの失敗時の iOS / Android の差は ⚠️ `deviation.md:9`) |
| └ 途中で取り直す | 同上 | `KsPagingPositionTests.swift:104` (list / グリッド) / `KsPagingPositionTest.kt:84` (list / グリッド) | ✅ |
| └ 大きな一覧を取り直す | 同上 | `KsPagingPositionTests.swift:199` / `KsPagingPositionTest.kt:93` | ✅ |
| └ Pull to Refresh の取り直し | 同上 | `KsPagingPositionTests.swift:245` / `KsPagingPositionTest.kt:99`。実際に引っ張る経路: `KsPullToRefreshTests.swift:373,418,441,467` / `KsPullToRefreshTest.kt:303,309,315` | ✅ |
| └ 状態を取り直し中にしない差し替え | 同上 (直前が取り直し中でなく、引っ張って始めた取り直しの間でもなければ既定の保ち方) | `KsPagingPositionTests.swift:266` / `KsPagingPositionTest.kt:160`。出し終えた後の差し替え: `KsPullToRefreshTests.swift:493` / `KsPullToRefreshTest.kt:153` | ✅ |

### samples

`samples/` は verify-002 の後に書き換わっていないため、行は verify-002 と同じ。

| Requirement / Scenario | 実装 (iOS / Android) | 試験・証跡 (iOS / Android) | 状態 |
|---|---|---|---|
| **デモ画面「ページング」** | `SampleScreen.swift:14`、`SampleDestinationView.swift:33`、`PagingDemoView.swift`、`PagingDemoSource.swift:11,14` / `SampleScreen.kt:23`、`SampleNavHost.kt:83`、`PagingDemoScreen.kt`、`PagingDemoSource.kt:35,38`。既定の遅延: `PagingDelay.swift` / `PagingDelay.kt` | `PagingDemoSourceTest.kt:18,24,36,47,70` | ✅ |
| └ 両プラットフォームで同じ構成 | 同上。文言: `PagingDemoText.swift` / `PagingDemoText.kt` | `PagingDemoUITests.swift:36` / `SampleScreenParityTest.kt:41,87,122` (iOS の文言・寸法の写しと突き合わせる) | ✅ |
| └ 開いたら最初のページを読み込む | 初回の読み込みはライブラリの初回の読み込み (0 件・待機) | `PagingDemoUITests.swift:74` / `PagingDemoScreenTest.kt:92`、`PagingDemoModelTest.kt:88`。証跡: `ui/verification/ios-01-initial-loading.png`・`android-01-initial-loading.png` | ✅ |
| └ スクロールで続きを読み込む | `loadNextPage` (`PagingDemoModel.swift:64` / `PagingDemoModel.kt:122`) | `PagingDemoUITests.swift:91` / `PagingDemoModelTest.kt:104` (画面の発火はライブラリの結合試験。tasks 6.4 の分担どおり)。証跡: `ui/verification/ios-02-appending-list-folded.png`・`android-02-appending-list-folded.png` (下地を外した後に撮り直し) | ✅ |
| └ 最後まで読むと終端の表示が出る | 終端の表示の差し替え (`PagingDemoView.swift:91` / `PagingDemoScreen.kt:142`) | `PagingDemoUITests.swift:103` / `PagingDemoModelTest.kt:145`、`PagingDemoSourceTest.kt:36` | ✅ |
| **失敗と空の実演** | 2 つの切り替えと取得元 (`PagingDemoSource.swift:30` / `PagingDemoSource.kt:27`)、`setEmpty` (`PagingDemoModel.swift:118` / `PagingDemoModel.kt:186`)。差し替え (`PagingDemoView.swift:87-100` / `PagingDemoScreen.kt:135-149`)。文言 (`PagingDemoText.swift` / `PagingDemoText.kt`) | `PagingDemoModelTest.kt:116,181`、`PagingDemoSourceTest.kt:53,62`、`SampleScreenParityTest.kt:87` | ✅ |
| └ 次のページの失敗と再試行 | 同上 | `PagingDemoUITests.swift:122` / `PagingDemoModelTest.kt:158`。証跡: `ui/verification/ios-03-append-failed-grid.png`・`android-03-append-failed-grid.png` | ✅ |
| └ 最初の読み込みの失敗 | 同上 | `PagingDemoUITests.swift:145` / `PagingDemoScreenTest.kt:115`。証跡: `ui/verification/ios-06-initial-failed.png`・`android-06-initial-failed.png` | ✅ |
| └ 0 件 | 同上 | `PagingDemoUITests.swift:162` / `PagingDemoScreenTest.kt:103`、`PagingDemoModelTest.kt:462`。証跡: `ui/verification/ios-05-empty.png`・`android-05-empty.png` | ✅ |
| **取り直しの実演** | `refresh` と世代 (`PagingDemoModel.swift:85` / `PagingDemoModel.kt:143`)、`reload` (`PagingDemoModel.swift:113` / `PagingDemoModel.kt:176`)、`restoredState` (`PagingDemoModel.swift:168` / `PagingDemoModel.kt:210`)、`.refreshable` / `onRefresh` (`PagingDemoView.swift:101` / `PagingDemoScreen.kt:151`) | `PagingDemoModelTest.kt:196,325,338,364,380,399` | ✅ (失敗時に戻す状態は ⚠️ `deviation.md:5`。「更新できませんでした」の出し方は ⚠️ `deviation.md:6`・照合結果 5) |
| └ 途中から再読み込み | 同上 | `PagingDemoUITests.swift:176` / `PagingDemoScreenTest.kt:171` | ✅ |
| └ 追加読み込み中に再読み込み | 同上 | `PagingDemoUITests.swift:193` / `PagingDemoModelTest.kt:338,364,380` | ✅ |
| └ 項目があるときの取り直しの失敗 | 同上。帯: `PagingRefreshFailedBanner.swift` (`PagingDemoView.swift:33-39`) / `PagingRefreshFailedBanner.kt` (`PagingDemoScreen.kt:74-87`) | `PagingDemoUITests.swift:220` / `PagingDemoScreenTest.kt:138`、`PagingDemoModelTest.kt:213,256`。証跡: `ui/verification/ios-04-*.png`・`android-04-*.png` | ⚠️ (「更新できませんでした」をパネルではなく帯で出す。`deviation.md:6`) |
| **操作を畳める** | `PagingControlPanel.swift`、`PagingPanelHandle.swift`、`PagingDemoView.swift:55-68` / `PagingControlPanel.kt`、`PagingPanelHandle.kt`。パネルの置き方: `PagingDemoView.swift:41-43`、`PagingPanelMetrics.swift:15` / `PagingDemoScreen.kt:90-95`、`PagingPanelMetrics.kt:25` | `SampleScreenParityTest.kt:122,149` (寸法と上げる量) | ⚠️ (一覧の下の余白にパネルの分を入れず、パネルを上げて浮かせる。上げる量の差を含め `deviation.md:12,14`、照合結果 7) |
| └ 畳んで広げる | 同上 | `PagingDemoUITests.swift:260` / `PagingDemoScreenTest.kt:220,238` | ✅ |
| └ 末尾の表示が操作に隠れない | 同上 | `PagingDemoUITests.swift:282` (広げたまま・畳んだあとの両方で、失敗の文言と「再試行」がパネル / 丸いボタンより下にあり押せる) / `PagingDemoScreenTest.kt:192` (広げたまま、パネルより下にあり押せる) | ✅ |
| **起動引数** | `PagingDelay.swift:13` (`--paging-delay-ms`)、`SampleLaunchView.swift:36` (`--screen`) / `SampleRoutes.kt:48` (`ks_paging_delay_ms`)、`MainActivity.kt:51-61` (開始ルートと遅延) | `PagingDelayTest.kt:15,21,28,37` / `SampleScreenParityTest.kt:178` | ✅ |
| └ 遅延を縮めて開く | 同上 | `PagingDemoUITests.swift:62` / `PagingDelayTest.kt:21`、`SampleScreenParityTest.kt:178` | ✅ |

## 追加検査

- [x] **tasks.md**
  - 33 件すべてチェック済みで、どれも対応表の実装・試験・証跡と対応している (虚偽なし)
  - 3.1 / 3.2 (次のページの読み込み中をフッターの枠に置く)・6.3 (一覧の下の余白にパネルの分を入れる)・1.1 / 1.2 (旧名の `pagingAppendingFooter` / `appendingFooter`) の文面は、`deviation.md:10,12,15` で置き換えられた合意済みの差。タスクの目的は満たされており、虚偽のチェックとは扱わない
- [x] **tasks 7.2〜7.4 のチェックと evidence/ の判定の突き合わせ**

  | タスク | 証跡の判定 | 食い違い |
  |---|---|---|
  | 7.2 表示範囲が跳ねないことの目視 | iOS: 2 回目の採用走行で「下端の読み込み中の表示の出入りと項目の跳ね: オーナーの目視で問題なし」(`evidence/perf-ios-paging.md:91`)。Android: 同じく問題なし (`evidence/perf-android-paging.md:39`) | なし |
  | 7.3 基準機の体感ゲート (遅延 200 ms・リスト) | iOS: 2 回目の採用走行が **合格** (`evidence/perf-ios-paging.md:90`)。1 回目は「未判定」で、合否に使っていない (`:42`)。Android: **合格** (`evidence/perf-android-paging.md:38`)。どちらも構成・判定を残している | なし |
  | 7.4 iOS の塊の件数が変わる追加読み込み | iOS: 2 回目の採用走行で「オーナーの目視で問題なし」、500 件の境目を越えたうえでの回答 (`evidence/perf-ios-paging.md:92,101`) | なし |

  - iOS の 2 回目の記録は、既定の表示に下地が付いていたときの実装で採られ、その後に下地を外した。証跡は「飾りを外すだけでスクロールと追加読み込みの経路は変わらないため、取り直しは行わずこの記録で判定する」と理由と限界を書いている (`evidence/perf-ios-paging.md:94,100`)。オーナーの体感ゲートの判定として記録されたもので、Scenario を持たないため、この検証の判定には影響しない
  - Android の記録は下地を外した後の実装で採られている (`evidence/perf-android-paging.md:6`)。記録の後に、差し替えた表示からのドラッグの手当て (Minor 1 の修正) が `KsCollectionView.kt` に入った。差し替えていない一覧 (証跡の Sample) では、端の効果は `LazyVerticalGrid` の既定と同じ `rememberOverscrollEffect()`、インジケータは知らせの経路を 1 つ多く見るだけで、測った経路は実質変わらない (下の所見 2)
- [x] **逆流検査**
  - `git diff HEAD -- proposal.md design.md specs/` は差分なし。提案のコミット `58efa6c` の後にコミットは無い
  - tasks.md の差分は `- [ ]` → `- [x]` の 33 行だけで、本文の書き換えは無い (削除行 33・追加行 33 がすべてチェックの行)
  - ui/brief.md の差分は末尾の「照合結果」「照合結果 (2 回目)」の節の追記だけ (削除行 0)。照合結果 6 に、下地を外して撮り直した画像を 2026-09-29 に承認したことが書かれている
- [x] **未記録乖離**: 0 件。spec と違う箇所は、すべて deviation.md か brief.md の照合結果に記録がある。verify-002 の所見 1 (公開 API の改名) と所見 2 (フェード) は `deviation.md:15,16` に記録された
- [x] **付随修正**
  - `deviation.md:13` の `[付随修正]` (iOS のヘッダー / フッターの枠の測り直し) は対応表の対象外。試験は `KsContentPaddingChangeTests.swift` の 4 件で、今回の全件実行で通過した
  - Scenario に直接対応しない他の変更は、どれも本務の実装の一部で付随修正には当たらない (verify-002 の一覧のとおり。今回足された Android の `KsScrollIndicator.kt` の `extraDragInteractions` は、差し替えた表示からのドラッグを一覧のスクロールとして扱う手当ての一部)
- [x] **UI 変更の記録**
  - brief.md に承認 mock の記録がある (案 C `mock/paging-variant-c-floating-panel.html`・`mock/approved.png`、2026-09-27 オーナー承認)
  - 照合結果 (1 回目) の合意済み妥協 5 件と、照合結果 (2 回目) の 2 件がある。2 回目の 6 は下地を外した後の撮り直しを 2026-09-29 に承認
  - 撮り直した画像 (`ui/verification/ios-02-appending-list-folded.png`・`ios-02b-appending-list-panel.png`・`android-02-appending-list-folded.png`・`android-02b-appending-list-panel.png`) は 2026-09-29 の更新
- [x] **試験の全件成功**: 下の「試験の実行」

## 試験の実行

このワーカーが、新しく作った Simulator 2 台と Robolectric で絞り込みなしの全件を実行した。既存の Simulator・エミュレータ・実機には触れていない。ビルドの中間物はスクラッチの DerivedData に置いた。

| 系統 | コマンド | 結果 |
|---|---|---|
| iOS ライブラリ (SwiftPM) | `ios/` で `xcodebuild test -scheme KsCollectionView -configuration Debug`。Simulator `ksn-paging-verify3` (iPhone 17 Pro / iOS 26.5) | 440 件・失敗 0 (`Executed 440 tests, with 0 failures`、`** TEST SUCCEEDED **`。xcresult の集計も passed 440 / failed 0 / skipped 0)。ページングまわりの試験は Display 14・Indicator 7・Position 10・Requester 18・Trigger 19・PullToRefresh 21・ContentPaddingChange 4・PublicAPI 23・EdgeInsertion 3 |
| iOS Sample UI (通常スキーム) | `samples/ios/` で `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples`。Simulator `ksn-paging-verify3-ui` (iPhone 17 Pro / iOS 26.5) | 34 件・失敗 0 (`Executed 34 tests, with 0 failures`、`** TEST SUCCEEDED **`)。PagingDemoUITests は 13 件。計測ドライバは通常スキームで除外される (件数に含まれない) |
| Android ライブラリ | `android/` で `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks`。XML を集計 | 25 クラス・416 件・失敗 0・エラー 0・スキップ 0。ページングまわりは PublicApi 16・Trigger 17・Requester 17・Display 13・AppendingIndicator 12・Position 11・PullToRefresh 15・FooterResize 3・EmbeddedSafeArea 2・ScrollIndicator 20 |
| Android Sample | `samples/android/` で `./gradlew :app:testDebugUnitTest --rerun-tasks`。XML を集計 | 19 クラス・146 件・失敗 0・エラー 0・スキップ 0。ページングの試験は PagingDemoModel 23・PagingDemoScreen 8・PagingDemoSource 7・PagingDelay 4・SampleScreenParity 9 |

ホストが報告していた件数 (iOS ライブラリ 440・Android ライブラリ 416・Android Sample 146 件、iOS Sample UI は review-004 の 34 件) と一致する。verify-002 からの増分は、iOS ライブラリが +1 (`KsPagingIndicatorTests.swift:196`)、Android ライブラリが +4 (`KsPagingAppendingIndicatorTest.kt:202,208,242`、`KsScrollIndicatorTest.kt:121`)。

試験の後、2 つの Simulator は停止した (削除はしていない)。

## 所見 (判定に影響しない)

1. **review-005 Minor 2 の残り 1 点** (上の「review-005 の指摘の解消の確認」の 2): `KsPagingIndicatorTests.swift:192-196` のコメントか名前に、ドラッグを合成せずスクロールを妨げない構造を確かめる試験であることを書くと閉じる
2. **Android の体感ゲートの記録の後に入った変更**: `evidence/perf-android-paging.md` は Minor 1 の修正 (`KsCollectionView.kt:340-343,518`、`KsScrollIndicator.kt:86-90`) の前の実装で採られている。差し替えていない一覧では、端の効果は `LazyVerticalGrid` の既定の値と同じものを明示的に渡す形になっただけで、インジケータは同じ知らせを 2 回見る (差し替えていないときの経路には何も流れない) だけのため、測り直しは要らないと見る。証跡の「実装」の行に、この修正の前の記録であることを書き足すかは呼び出し元の判断
3. **deviation の蒸留への持ち越し**: `deviation.md:8,9,10,11,15,16,17` は ADR-0021 / ADR-0024 の本文・負の帰結、および公開 API の名前への反映を蒸留時に行う扱い。蒸留で落とさないこと
4. **差し替えた次のページの読み込み中の表示のタッチ**: spec の外の振る舞い (範囲のタップは止め、ドラッグは一覧のスクロール) が両プラットフォームでそろい、公開 doc にも同じ内容で書かれた。phase-7 のガイドで同じ言い方にそろえるとよい (verify-002 の所見 3 の続き)
