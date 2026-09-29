# 一致検証: paging-state-machine (002 回目)

**日付**: 2026-09-28
**判定**: VALID
**対象**: 作業ツリーの未コミットの変更すべて (`git diff HEAD` と未追跡ファイル。ios/ android/ samples/ 配下)
**デルタスペック**: `specs/collection-paging/spec.md` (ADDED 14 Requirement / 37 Scenario)、`specs/collection-core/spec.md` (MODIFIED 1 / ADDED 1 Requirement、10 Scenario)、`specs/samples/spec.md` (ADDED 5 Requirement / 13 Scenario)

## サマリー

- 全 21 Requirement・60 Scenario を 1 行ずつ、両プラットフォームの実装箇所と試験 (または証跡) に対応づけ直した
  - ❌ (未記録の欠落・乖離) は 0 件
  - 合意済みの差分が関わる行には ⚠️ を添えた。deviation.md の 14 項目のうち Scenario に関わるのは 1・3・4・6・7・8・9・10・11 行目の項目と、12・14 行目の項目。brief.md の照合結果の合意済み妥協 7 件のうち 4〜7 が当たる
  - Scenario の判定そのものが ⚠️ なのは 2 件。collection-paging の「次のページの読み込み中 (既定)」(置き場が deviation の 10 行目)、samples の「項目があるときの取り直しの失敗」(帯。deviation の 6 行目)。残りの 58 件は ✅
- verify-001 の後に入った変更 6 点が、spec と deviation の組み合わせに一致していることを確かめた (下の「前回からの変更の突き合わせ」)
- tasks.md に虚偽のチェックはない。7.2〜7.4 は未チェックで、オーナーの目視・体感ゲートの待ち
- 逆流は無い。proposal / design / specs は HEAD (提案のコミット `58efa6c`) から変わっていない
  - tasks.md の差分は `- [ ]` → `- [x]` の 30 行だけ
  - ui/brief.md の差分は末尾の「照合結果」「照合結果 (2 回目)」の追記だけ
- 試験は 4 系統とも、このワーカーが絞り込みなしの全件で実行し、すべて成功した (件数は「試験の実行」)

deviation.md の項目は番号を持たないため、この文書ではファイルの行番号 (`deviation.md:<行>`) で指す。

## 前回からの変更の突き合わせ

| 変更 | spec の該当 | 合意の記録 | 実装 (iOS / Android) | 試験 (iOS / Android) | 結果 |
|---|---|---|---|---|---|
| 次のページの読み込み中の表示を、見えている範囲の下端に止めて重ねる | collection-paging「ページングの表示」の置き場 (最後の項目の後ろ) | `deviation.md:10`、brief の照合結果 6 | `KsPagingDisplay.swift:52,64` (`.bottomOverlay`)、`updatePagingIndicator` (`KsCollectionViewController.swift:1631`)、`KsPagingIndicatorView.swift` / `KsCollectionView.kt:698-724`、`KsPagingDisplay.kt:55` と `isFooter` (`KsCollectionView.kt:655`) | `KsPagingIndicatorTests.swift:23,80`、`KsPagingDisplayTests.swift:48` / `KsPagingAppendingIndicatorTest.kt:59,65,96,110`、`KsPagingDisplayTest.kt:72` | ⚠️ 一致 (合意どおり。出る条件は表のまま `(.appending, false)` / `Appending` かつ項目あり) |
| 上の表示の縦の位置を「下端の安全領域 + 8」だけで決め、contentPadding を見ない | 同上 | `deviation.md:11` | `updatePagingIndicatorPosition` (`KsCollectionViewController.swift:1694`) / `KsCollectionView.kt:711-714` (`bottomOverlapPx()` + 8dp)、`KsTopSafeArea.kt` の `bottomOverlapPx` | `KsPagingIndicatorTests.swift:23,58` / `KsPagingAppendingIndicatorTest.kt:65,73,79` | ⚠️ 一致 |
| 公開 API の改名 (`pagingAppendingFooter` → `pagingAppendingIndicator`、`KsPaging.appendingFooter` → `appendingIndicator`) | spec は名前を定めない (「6 つの表示はそれぞれ利用者が差し替えられる」だけ) | 記録なし (下の所見 1) | `KsCollectionView+Paging.swift:74` / `KsPaging.kt:78` | `KsPublicAPITests.swift:343` / `KsCollectionViewPublicApiTest.kt:293` | ✅ (spec との一致に影響なし。ソース・試験に旧名の残りは無い) |
| [付随修正] iOS のルートのヘッダー / フッターの枠を、上下の余白の変化で測り直す | Requirement なし | `deviation.md:13` (`[付随修正]`) | `KsCollectionViewController.swift:285-288`、`rebuildVisibleRootSupplementaryViews` (`:1553`) | `KsContentPaddingChangeTests.swift:24,53,71,97` | 対応表の対象外 (記録済み) |
| 両 Sample のパネルの置き方 (一覧の下の余白にパネルの分を入れず、パネルを上げて浮かせる。iOS 100pt・Android 128dp) | samples「操作を畳める」 | `deviation.md:12,14`、brief の照合結果 7 | `PagingDemoView.swift:41-43,75-80`、`PagingPanelMetrics.swift:15` / `PagingDemoScreen.kt:62-69,90-95`、`PagingPanelMetrics.kt:25`、`SampleScaffold.kt` の `extendsBehindBottomBar` | `PagingDemoUITests.swift:282` / `PagingDemoScreenTest.kt:192`、`SampleScreenParityTest.kt:122,149` | ⚠️ 一致 |
| 差し替えた「次のページの読み込み中」のタッチ (押せる部品を持たなくてもその範囲のタッチを止め、外は下へ通す。既定の表示は止めない) | spec はこの表示のタッチを定めない (外の操作を妨げない規則は 0 件の表示だけ) | 公開 doc に記載 (`KsCollectionView+Paging.swift:67-72` / `KsPaging.kt:56-61`) | `KsPagingIndicatorView.swift:45-49`、`isReplaced` (`KsPagingDisplays.swift:36`) / `blocksIndicatorTouches` と `ksBlockingTouches` (`KsCollectionView.kt:705,717-721`) | `KsPagingIndicatorTests.swift:131,156` / `KsPagingAppendingIndicatorTest.kt:131,144,171` | ✅ (両プラットフォームで同じ振る舞いにそろった。review-003 の Suggestion 1 の解消) |
| Pull to Refresh で始めた取り直しの間の差し替えは、直前の状態によらず先頭を表示する | collection-core「取り直しの結果は先頭から表示する」 | `deviation.md:8,9` | `showsTopOnReplacement` (`KsCollectionViewController.swift:1005`)、`finishPullRefresh` (`:1835`) / `keepEdge` の先頭 (`KsPositionKeeper.kt:110-113`)、`isPullRefreshing` の受け渡し (`KsCollectionView.kt:411,465`) | `KsPullToRefreshTests.swift:373,418,441,467,493` / `KsPullToRefreshTest.kt:303,309,315,153` | ⚠️ 一致 |

## 対応表

凡例: ✅ 一致 / ⚠️ deviation 記録済み / ❌ 欠落・乖離

パスの略記:

- iOS 本体のソース: `ios/Sources/KsCollectionView/`
- iOS 本体の試験: `ios/Tests/KsCollectionViewTests/`
- Android 本体のソース: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/`
- Android 本体の試験: `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/`
- iOS Sample: `samples/ios/KsCollectionViewSamples/`、UI 試験は `samples/ios/KsCollectionViewSamplesUITests/PagingDemoUITests.swift`
- Android Sample: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/`、試験は同じパッケージの `src/test/...`

試験名の後ろの数字は、その試験の関数が始まる行 (iOS は `func test...` の行、Android は `fun` の行)。

### collection-paging

| Requirement / Scenario | 実装 (iOS / Android) | 試験 (iOS / Android) | 状態 |
|---|---|---|---|
| **ページングの状態** (5 値・付属値なし・書き換えない) | `KsPagingState.swift:5` / `KsPagingState.kt:9` | `KsPublicAPITests.swift:303` / `KsCollectionViewPublicApiTest.kt:262` | ✅ |
| └ ライブラリは状態を書き換えない | 状態は設定から読むだけ (`evaluatePaging`、`KsCollectionViewController.swift:1722`) / `KsCollectionView.kt:373-399` | `KsPagingTriggerTests.swift:261` / `KsPagingTriggerTest.kt:240` | ✅ |
| **ページングの設定** (非同期関数・しきい値の既定 1) | `KsCollectionView+Paging.swift:55` / `KsPaging.kt:74-77`、`KsCollectionView.kt:164-165` | `KsPublicAPITests.swift:311,323,333,343` / `KsCollectionViewPublicApiTest.kt:277,293,312` | ✅ |
| └ ページングを付けない一覧 | `evaluatePaging` の guard (`KsCollectionViewController.swift:1723-1730`) / `pagingInput` が null (`KsCollectionView.kt:785`)、`hasFooterSlot` (`:181`)、重ねる表示は `paging != null` のときだけ (`:698`) | `KsPagingTriggerTests.swift:243` / `KsPagingTriggerTest.kt:225` | ✅ |
| **追加読み込みの発火** | `KsPagingRequester.swift:31,64`、`visiblePagingItems` (`KsCollectionViewController.swift:1749`) / `KsPagingRequester.kt:58,129`、`pagingInput` (`KsCollectionView.kt:778`) | 単体: `KsPagingRequesterTests.swift:39-87` / `KsPagingRequesterTest.kt:33-95` | ✅ |
| └ 既定のしきい値で 1 画面分手前で頼む | 同上 | `KsPagingTriggerTests.swift:26` / `KsPagingTriggerTest.kt:66` | ✅ |
| └ しきい値 2 | 同上 | `KsPagingTriggerTests.swift:49` / `KsPagingTriggerTest.kt:81` | ✅ |
| └ しきい値 0 | 同上 | `KsPagingTriggerTests.swift:65` / `KsPagingTriggerTest.kt:93` | ✅ |
| └ グリッドは項目の数で数える | `sectionItemRanges` で配列上の位置に変換 (`KsCollectionViewController.swift:1752,1763`) / `itemIndexOfLazy` | `KsPagingTriggerTests.swift:83` / `KsPagingTriggerTest.kt:105` | ✅ |
| └ 画面に項目が出ていないとき | `KsPagingRequester.swift:64-92` / `KsPagingRequester.kt:58-83` | `KsPagingTriggerTests.swift:141` / `KsPagingTriggerTest.kt:155` (単体: `KsPagingRequesterTests.swift:87` / `KsPagingRequesterTest.kt:95`) | ✅ |
| └ 見出しとフッターは数えない | セルだけを数える (`visiblePagingItems`)。下端に重ねた表示は一覧のサブビューでセルではない / lazy の項目だけを数え、重ねた表示は lazy の要素ではない | `KsPagingTriggerTests.swift:109` / `KsPagingTriggerTest.kt:119` | ✅ |
| **判定し直すきっかけ** | スクロール `scrollViewDidScroll` (`:345`)・レイアウトの確定 `viewDidLayoutSubviews` (`:352`)・差分の適用の完了 (`:961`)・設定の更新 (`update` の末尾)・処理の終わり `pagingRequestDidFinish` (`:1715`) / `snapshotFlow` で状態・配列・しきい値・表示範囲・実行中を観測 (`KsCollectionView.kt:374-399`) | 下の 3 行 | ✅ |
| └ 1 ページが画面に満たないとき | 同上 | `KsPagingTriggerTests.swift:170` / `KsPagingTriggerTest.kt:169` | ✅ |
| └ 失敗から待機に戻ったとき | 同上 | `KsPagingTriggerTests.swift:195` / `KsPagingTriggerTest.kt:186` | ✅ |
| └ 回転で画面に出る項目の数が変わったとき | 同上 (一覧の大きさの変化で判定) | `KsPagingTriggerTests.swift:221` / `KsPagingTriggerTest.kt:209` (どちらも一覧の大きさを変えて再現) | ✅ |
| **初回の読み込み** | `KsPagingRequester.swift:64-92` (0 件で待機なら頼む) / `KsPagingRequester.kt:71` | 下の 1 行 | ✅ |
| └ 空で待機なら頼む | 同上 | `KsPagingTriggerTests.swift:272` / `KsPagingTriggerTest.kt:253` (単体: `KsPagingRequesterTests.swift:71` / `KsPagingRequesterTest.kt:75`) | ✅ |
| **待機のときだけ自動で頼む** | `KsPagingRequester.swift:64-92` / `KsPagingRequester.kt:69` | 単体: `KsPagingRequesterTests.swift:104` / `KsPagingRequesterTest.kt:115` | ✅ |
| └ 終端では頼まない | 同上 | `KsPagingTriggerTests.swift:210` / `KsPagingTriggerTest.kt:199` | ✅ |
| └ 失敗では自動で頼まない | 同上 | `KsPagingTriggerTests.swift:195` の前半 / `KsPagingTriggerTest.kt:186` の前半 (単体: 上と同じ) | ✅ |
| **頼んだ後の待ち方** | 控えと実行中の印 (`KsPagingRequester.swift:54,112`) / (`KsPagingRequester.kt:47,105`)。配列の版は iOS が中身の比較 (`KsCollectionViewController.swift:199-201`)、Android が `KsPagingItemsVersion` (`KsPagingRequester.kt:153`)。状態と版は毎回知らせる (`KsCollectionViewController.swift:205` / `KsCollectionView.kt:366`) | 下の 3 行と、判定を飛ばす間の往復 `KsPagingTriggerTests.swift:329` / `KsPagingTriggerTest.kt:266` | ✅ |
| └ VM が状態の書き換えを遅らせても二重に頼まない | 同上 | `KsPagingRequesterTests.swift:125` / `KsPagingRequesterTest.kt:131` | ✅ |
| └ 処理の中で待つ VM | 同上 | `KsPagingRequesterTests.swift:139` / `KsPagingRequesterTest.kt:146` | ✅ |
| └ 頼みが無視されたとき | 同上 | `KsPagingRequesterTests.swift:153` / `KsPagingRequesterTest.kt:171` | ✅ |
| **一覧が破棄されたときの取り消し** | `disconnect()` → `pagingRequester.cancel()` (`KsCollectionViewController.swift:380-390`) / `DisposableEffect` → `cancel()` (`KsCollectionView.kt:370-372`) | 取り消さない側: `KsPagingTriggerTests.swift:308` (iOS のみ。Android はナビゲーションの仕組みに任せる — spec の本文どおり) | ✅ |
| └ 読み込み中に画面を閉じる | 同上 | `KsPagingTriggerTests.swift:294` / `KsPagingTriggerTest.kt:289` | ✅ |
| **不正なしきい値** | `reportInvalidPagingThresholdIfNeeded` (`KsCollectionViewController.swift:1772`)、`effectiveThreshold` (`KsPagingRequester.swift:49`) / `invalidThresholdMessage` (`KsPaging.kt:100`、`KsCollectionView.kt:231`)、`effectiveThreshold` (`KsPagingRequester.kt:139`) | `KsPagingTriggerTests.swift:373`、`KsPagingRequesterTests.swift:252` / `KsPagingTriggerTest.kt:333` (debug の停止)、`KsPagingRequesterTest.kt:258` | ✅ |
| └ 負のしきい値 (release) | 同上 | `KsPagingTriggerTests.swift:354` / `KsPagingTriggerTest.kt:315` | ✅ |
| **ページングの表示** (6 つの表示・置き場・差し替え・既定) | 表: `KsPagingDisplay.swift:50-60` / `KsPagingDisplay.kt:54-59`。既定: `KsPagingDisplays.swift:18-33`、`KsPagingDefaultIndicator.swift`、`KsPagingDefaultProgress.swift` / `KsPaging.kt:89-97`、`KsPagingDisplay.kt:69,88`。フッターの枠 (失敗・終端): `configurePagingFooter` (`KsCollectionViewController.swift:1526`)、`KsPagingFooterStack.swift` / `KsCollectionView.kt:649-670`。下端に重ねる (次のページの読み込み中): `updatePagingIndicator` (`KsCollectionViewController.swift:1631`) / `KsCollectionView.kt:698-724`。0 件: `updatePagingPlaceholder` (`KsCollectionViewController.swift:1572`)、`KsPagingPlaceholderView.swift:45` / `KsCollectionView.kt:677-691` | 表の全組み合わせ: `KsPagingDisplayTests.swift:28` / `KsPagingDisplayTest.kt:52` | ⚠️ (次のページの読み込み中の置き場は `deviation.md:10,11`。失敗・終端の幅は `deviation.md:3`) |
| └ 次のページの読み込み中 (既定) | 同上 | `KsPagingDisplayTests.swift:48`、`KsPagingIndicatorTests.swift:23,58` / `KsPagingDisplayTest.kt:72`、`KsPagingAppendingIndicatorTest.kt:59,65,73,79` | ⚠️ (文言なしの標準の読み込み中が出ることは一致。「最後の項目の後ろ」は、見えている範囲の下端に重ねる形に置き換え済み — `deviation.md:10,11`、照合結果 6) |
| └ 最初の読み込み中 (既定) | 同上 | `KsPagingDisplayTests.swift:71` / `KsPagingDisplayTest.kt:86,97` | ✅ |
| └ 失敗・終端・空は既定では出ない | 同上 | `KsPagingDisplayTests.swift:88` / `KsPagingDisplayTest.kt:105` | ✅ |
| └ 差し替えた表示が出る | 同上 | `KsPagingDisplayTests.swift:153` / `KsPagingDisplayTest.kt:129` (次のページの読み込み中の差し替えは `KsPagingIndicatorTests.swift:156` / `KsPagingAppendingIndicatorTest.kt:144`) | ✅ |
| └ VM が始めた取り直しの間は項目の上に何も出さない | 表の `(.refreshing, false)` / `Refreshing -> null`。重ねる表示も状態が追加読み込み中のときだけ | `KsPagingDisplayTests.swift:179` / `KsPagingDisplayTest.kt:169` | ✅ |
| └ 状態だけが変わったとき | `invalidatePagingFooterIfNeeded` (`KsCollectionViewController.swift:1543`)、`updatePagingIndicator` は毎回の `update` で呼ぶ / 状態を読んで再構成、`AnimatedVisibility` の `visible` | `KsPagingDisplayTests.swift:195`、`KsPagingIndicatorTests.swift:80` / `KsPagingDisplayTest.kt:181`、`KsPagingAppendingIndicatorTest.kt:96` | ✅ |
| └ 0 件の表示がヘッダーと重なっても押せる | 手前に重ね、外のタッチは通す (`KsPagingPlaceholderView.swift:45`) / `zIndex(1f)` (`KsCollectionView.kt:686`) | `KsPagingDisplayTests.swift:229` / `KsPagingDisplayTest.kt:202` (どちらも外のタッチが下へ通ることも確かめる) | ✅ |
| **再試行** | `retryPaging` (`KsCollectionViewController.swift:1708`)、`KsPagingRequester.swift:95` / `retryPaging` (`KsCollectionView.kt:355`)、`KsPagingRequester.kt:86` | 単体: `KsPagingRequesterTests.swift:174,187,194` / `KsPagingRequesterTest.kt:182,194,204` | ✅ |
| └ 項目があるときの再試行 | 同上 | `KsPagingDisplayTests.swift:321` / `KsPagingDisplayTest.kt:268` | ✅ |
| └ 0 件のときの再試行 | 同上 | `KsPagingDisplayTests.swift:344` / `KsPagingDisplayTest.kt:291` | ✅ |
| **Pull to Refresh の接続** | `@Environment(\.refresh)` (`KsCollectionView.swift:28,37-38`)、`syncPullRefreshControl` (`KsCollectionViewController.swift:1788`) / `onRefresh` 引数 (`KsCollectionView.kt:165`)、`Modifier.pullToRefresh` (`:417-431`) | `KsPullToRefreshTests.swift:31` (渡さない一覧は引っ張れない)、`:51` (`.refreshable` を受け取る) / `KsPullToRefreshTest.kt:81` | ✅ |
| └ 引っ張ると取り直しの処理が呼ばれる | 同上 | `KsPullToRefreshTests.swift:17` / `KsPullToRefreshTest.kt:57` (ページングの有無の両方) | ✅ |
| └ 0 件でも引っ張れる | 同上 | `KsPullToRefreshTests.swift:40` / `KsPullToRefreshTest.kt:94` | ✅ |
| **Pull to Refresh のインジケータ** | `handlePullRefresh`・`endPullRefreshIfFinished`・`finishPullRefresh` (`KsCollectionViewController.swift:1809,1828,1835`)、`KsRefreshControl.swift` / `KsPullRefresh.kt:43,63,67`、`PullToRefreshDefaults.Indicator` (`KsCollectionView.kt:726-737`) | 追加で `KsPullToRefreshTests.swift:161` / `KsPullToRefreshTest.kt:153,205` | ✅ |
| └ 処理の中で待つ取り直し | 同上 | `KsPullToRefreshTests.swift:69` / `KsPullToRefreshTest.kt:105` | ✅ |
| └ 処理がすぐ戻る取り直し | 同上 | `KsPullToRefreshTests.swift:88` / `KsPullToRefreshTest.kt:122` | ✅ |
| └ VM が始めた取り直しでは出さない | 同上 | `KsPullToRefreshTests.swift:110` / `KsPullToRefreshTest.kt:142` | ✅ |
| └ 全画面の一覧でも見える | `addRefreshExtraTopInset` (`KsCollectionViewController.swift:1876`)、`KsRefreshControl.swift:32,47`、`KsCompositionalLayout.swift` の `refreshExtraTopInset` / `offset { topSafeArea.overlapPx() }` (`KsCollectionView.kt:736`) | `KsPullToRefreshTests.swift:184,268,303,317` / `KsPullToRefreshTest.kt:224`。証跡: `evidence/ios-pull-to-refresh-*.png`・`evidence/android-pull-to-refresh-*.png` (tasks 5.4) | ✅ (Android の Sample ではステータスバーの分を下げる処理が働かない点は ⚠️ 照合結果 4) |
| **追加読み込みの間は引っ張れない** | `syncPullRefreshControl` の `blocksPull` (`KsCollectionViewController.swift:1797-1802`) / `acceptsPull` → `enabled` (`KsCollectionView.kt:413,421`) | 下の 3 行 | ✅ |
| └ 追加読み込み中に引っ張る | 同上 | `KsPullToRefreshTests.swift:127` の前半 / `KsPullToRefreshTest.kt:169` の前半 | ✅ |
| └ 処理の実行中に引っ張る | 同上 | `KsPullToRefreshTests.swift:143` / `KsPullToRefreshTest.kt:187` | ✅ |
| └ 追加読み込みが終わった後 | 同上 | `KsPullToRefreshTests.swift:127` の後半 / `KsPullToRefreshTest.kt:169` の後半 | ✅ |

注 (ページングの表示の「高々 1 つ」): 出す表示は状態と件数の表 (`resolve`) で 1 つに決まり、置き場の振り分け (`placement` / `isFooter`) も排他になっている。状態が追加読み込み中から失敗・終端に変わった直後、下端の表示が短いフェードで消える間だけフッターの枠の表示と重なって見える (両プラットフォーム同じ)。遷移の見え方は spec の範囲外 (デルタスペックの UI lint) のため ❌ にはしていない。記録の扱いは下の所見 2。

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
| **取り直しの結果は先頭から表示する** (ADDED) | `showsTopOnReplacement` (`KsCollectionViewController.swift:1005`)、`showContentTopIfRefreshEnded` (`:1013`)、`finishPullRefresh` (`:1835`)、`returnToContentTopAfterRefresh` (`:1850`) / `keepEdge` の先頭 (`KsPositionKeeper.kt:110-113`) | 下の 4 行。塊の件数が変わる差し替え: `KsPagingPositionTests.swift:220`。同じ ID・同じ配列の取り直し: `KsPagingPositionTests.swift:131,168` | ✅ (Pull to Refresh の間の規則の追加は ⚠️ `deviation.md:8`。取り直しの失敗時の iOS / Android の差は ⚠️ `deviation.md:9`) |
| └ 途中で取り直す | 同上 | `KsPagingPositionTests.swift:104` (list / グリッド) / `KsPagingPositionTest.kt:84` (list / グリッド) | ✅ |
| └ 大きな一覧を取り直す | 同上 | `KsPagingPositionTests.swift:199` / `KsPagingPositionTest.kt:93` | ✅ |
| └ Pull to Refresh の取り直し | 同上 | `KsPagingPositionTests.swift:245` / `KsPagingPositionTest.kt:99`。実際に引っ張る経路: `KsPullToRefreshTests.swift:373,418,441,467` / `KsPullToRefreshTest.kt:303,309,315` | ✅ |
| └ 状態を取り直し中にしない差し替え | 同上 (直前が取り直し中でなく、引っ張って始めた取り直しの間でもなければ既定の保ち方) | `KsPagingPositionTests.swift:266` / `KsPagingPositionTest.kt:160`。出し終えた後の差し替え: `KsPullToRefreshTests.swift:493` / `KsPullToRefreshTest.kt:153` | ✅ |

### samples

| Requirement / Scenario | 実装 (iOS / Android) | 試験・証跡 (iOS / Android) | 状態 |
|---|---|---|---|
| **デモ画面「ページング」** | `SampleScreen.swift:14`、`SampleDestinationView.swift:33`、`PagingDemoView.swift`、`PagingDemoSource.swift:11,14` / `SampleScreen.kt:23`、`SampleNavHost.kt:83`、`PagingDemoScreen.kt`、`PagingDemoSource.kt:35,38`。既定の遅延: `PagingDelay.swift` / `PagingDelay.kt` | `PagingDemoSourceTest.kt:18,24,36,47,70` | ✅ |
| └ 両プラットフォームで同じ構成 | 同上。文言: `PagingDemoText.swift` / `PagingDemoText.kt` | `PagingDemoUITests.swift:36` / `SampleScreenParityTest.kt:41,87,122` (iOS の文言・寸法の写しと突き合わせる) | ✅ |
| └ 開いたら最初のページを読み込む | 初回の読み込みはライブラリの初回の読み込み (0 件・待機) | `PagingDemoUITests.swift:74` / `PagingDemoScreenTest.kt:92`、`PagingDemoModelTest.kt:88`。証跡: `ui/verification/ios-01-initial-loading.png`・`android-01-initial-loading.png` | ✅ |
| └ スクロールで続きを読み込む | `loadNextPage` (`PagingDemoModel.swift:64` / `PagingDemoModel.kt:122`) | `PagingDemoUITests.swift:91` / `PagingDemoModelTest.kt:104` (画面の発火はライブラリの結合試験。tasks 6.4 の分担どおり)。証跡: `ui/verification/ios-02-appending-list-folded.png`・`android-02-appending-list-folded.png` | ✅ |
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
  - 0.1〜7.1 の 30 件はチェック済みで、どれも対応表の実装・試験・証跡と対応している (虚偽なし)
  - 3.1 / 3.2 (次のページの読み込み中をフッターの枠に置く) と 6.3 (一覧の下の余白にパネルの分を入れる) の文面は、`deviation.md:10,12` で置き換えられた合意済みの差。タスクの目的 (ページングの表示を出す / パネルを置く) は満たされており、虚偽のチェックとは扱わない
  - 7.2〜7.4 は未チェック (オーナーゲート待ち)
- [x] **逆流検査**
  - `git diff HEAD -- proposal.md design.md specs/` は差分なし。提案のコミット `58efa6c` の後にコミットは無い
  - tasks.md の差分は `- [ ]` → `- [x]` の 30 行だけで、本文の書き換えは無い (差分の行を突き合わせて確認)
  - ui/brief.md の差分は末尾の「照合結果」「照合結果 (2 回目)」の節の追記だけ (削除行 0)
- [x] **未記録乖離**: 0 件。spec と違う箇所は、すべて deviation.md か brief.md の照合結果に記録がある
- [x] **付随修正**
  - `deviation.md:13` の `[付随修正]` (iOS のヘッダー / フッターの枠の測り直し) は対応表の対象外。実装は `KsCollectionViewController.swift:285-288`、試験は `KsContentPaddingChangeTests.swift` の 4 件で、今回の全件実行で通過した
  - Scenario に直接対応しない他の変更は、どれも本務の実装の一部で付随修正には当たらない
    - iOS `KsCompositionalLayout.swift` の `refreshExtraTopInset`: 取り直し中のインジケータの位置と見出しの固定 (tasks 5.1・5.3)
    - Android `KsTopSafeArea.kt` の `bottomOverlapPx`: 0 件の表示の真ん中 (tasks 3.3) と、下端に重ねる表示の位置 (`deviation.md:10,11`)
    - Android の `compose-animation` の依存 (`libs.versions.toml`・`build.gradle.kts`): 下端に重ねる表示の出入り (`AnimatedVisibility`)。BOM の管理下で版を持たない
    - Android `SampleScaffold.kt` の `extendsBehindBottomBar`: 「ページング」の一覧をナビゲーションバーの裏まで広げ、パネル越しに透かす (brief・`deviation.md:12`)
    - Android `KsPositionKeeper` の「0 件から最初のページが届いたら先頭」: 先頭を表示中の先頭への挿入の規則の範囲
- [x] **UI 変更の記録**
  - brief.md に承認 mock の記録がある (案 C `mock/paging-variant-c-floating-panel.html`・`mock/approved.png`、2026-09-27 オーナー承認)
  - 照合結果 (1 回目) の合意済み妥協 5 件と、照合結果 (2 回目、2026-09-28 最終承認) の 2 件がある
  - 2 回目の照合の画像 (ios-01〜07・ios-02b・ios-04b、android-01〜07・android-02b・android-04b) は `ui/verification/` にある
- [x] **試験の全件成功**: 下の「試験の実行」

## オーナーゲート待ち (INVALID の理由にしない)

| タスク | 関係する Scenario | この検証での扱い |
|---|---|---|
| 7.2 フッターの枠の高さが変わるときに表示範囲が跳ねない | spec に直接の Scenario は無い (brief と design の Risks)。関係するのは「状態だけが変わったとき」「追加読み込みで届いたページは今の位置の下に現れる」 | どちらも自動試験で一致を確かめた。追加読み込み中はフッターの枠の高さが変わらないことも試験がある (`KsPagingIndicatorTests.swift:80` / `KsPagingAppendingIndicatorTest.kt:110`)。跳ねの見え方はオーナーゲート待ち |
| 7.3 基準機の体感ゲート (遅延 200 ms・リスト) | Scenario 無し (design Decision 10) | オーナーゲート待ち。`evidence/perf-ios-paging.md` は変更前の実装での記録で「未判定」 |
| 7.4 iOS の塊の件数が変わる追加読み込みの見え方 | Scenario 無し (design の Risks)。取り直し側は `KsPagingPositionTests.swift:220` で確かめた | オーナーゲート待ち |

## 試験の実行

このワーカーが、新しく作った Simulator と Robolectric で絞り込みなしの全件を実行した。既存の Simulator・エミュレータ・実機には触れていない。ビルドの中間物はスクラッチの DerivedData に置いた。

| 系統 | コマンド | 結果 |
|---|---|---|
| iOS ライブラリ (SwiftPM) | `ios/` で `xcodebuild test -scheme KsCollectionView -configuration Debug`。Simulator `ksn-paging-verify2` (iPhone 17 Pro / iOS 26.5) | 439 件・失敗 0 (`** TEST SUCCEEDED **`)。ページングまわりの試験は Display 14・Indicator 6・Position 10・Requester 18・Trigger 19・PullToRefresh 21・ContentPaddingChange 4・PublicAPI 23・EdgeInsertion 3 |
| iOS Sample UI (通常スキーム) | `samples/ios/` で `xcodebuild test -scheme KsCollectionViewSamples`。Simulator `ksn-paging-verify2-ui` (iPhone 17 Pro / iOS 26.5) | 34 件・失敗 0 (`** TEST SUCCEEDED **`)。PagingDemoUITests は 13 件。計測ドライバは通常スキームで除外される |
| Android ライブラリ | `android/` で `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks`。XML を集計 | 25 クラス・412 件・失敗 0・エラー 0・スキップ 0。ページングの 9 クラスは PublicApi 16・Trigger 17・Requester 17・Display 13・AppendingIndicator 9・Position 11・PullToRefresh 15・FooterResize 3・EmbeddedSafeArea 2 |
| Android Sample | `samples/android/` で `./gradlew :app:testDebugUnitTest --rerun-tasks`。XML を集計 | 19 クラス・146 件・失敗 0・エラー 0・スキップ 0。ページングの試験は PagingDemoModel 23・PagingDemoScreen 8・PagingDemoSource 7・PagingDelay 4・SampleScreenParity 9 |

ホストが報告していた件数 (iOS ライブラリ 439・iOS Sample UI 34・Android ライブラリ 412・Android Sample 146 件) と一致する。Android ライブラリは review-003 の時点の 411 件から、差し替えた表示のタッチの試験 (`KsPagingAppendingIndicatorTest.kt:171`) の 1 件が増えている。

試験の後、2 つの Simulator は停止した (削除はしていない)。

## 所見 (判定に影響しない)

1. **公開 API の改名が deviation.md に無い**
   - design.md の Decision 1 の表 (`design.md:30`) と tasks 1.1 は旧名 (`.pagingAppendingFooter` / `KsPaging(appendingFooter = )`) のまま。実装は `pagingAppendingIndicator` / `appendingIndicator`
   - spec は名前を定めないため、対応表の ❌ ではない。一方で deviation.md は design との差 (`deviation.md:4` の VM の書き方) も記録しているため、同じ扱いにするなら 1 行足すのが揃う
   - 見立て: deviation として合意する側 (改名の理由は `deviation.md:10` の置き場の変更で「フッター」でなくなったこと)。蒸留で concepts / ADR-0024 に書くときは新しい名前を使う
2. **下端に重ねる表示の短いフェードが brief / deviation に書かれていない**
   - 両プラットフォームとも 0.2 秒のフェードで出入りする (`KsPagingIndicatorView.swift:12` / `KsCollectionView.kt:715-716,746` の `KsAppendingIndicatorFadeMillis`)。フェードの間は、失敗・終端に変わった直後のフッターの枠の表示と一瞬重なって見える
   - 遷移の見え方は spec の範囲外で、最終状態は「高々 1 つ」に一致するため ❌ にはしていない。review-003 は「照合結果 2 回目で承認」と扱っているが、brief の照合結果 (2 回目) の 6 に「フェード」の語は無い
   - 見立て: brief の照合結果 (2 回目) の 6 か deviation.md の 10 行目の項目に、フェードで出入りすることを 1 句足して合意を明文にする
3. **公開 doc の「差し替えた表示のタッチ」は両プラットフォームでそろった**
   - review-003 の Suggestion 1 (iOS だけ範囲のタッチを止める) は、Android を iOS にそろえる形で解消している (`KsCollectionView.kt:705,717-721`、KDoc `KsPaging.kt:56-61`、試験 `KsPagingAppendingIndicatorTest.kt:171`)
   - spec が定めない範囲の振る舞いのため、phase-7 のガイドで「差し替えた次のページの読み込み中の表示の範囲は下の項目へ通さない」と書いておくとよい
4. **deviation の蒸留への持ち越し**: `deviation.md:8,9,10,11` は ADR-0021 / ADR-0024 の本文と負の帰結への反映を蒸留時に行う扱い。蒸留で落とさないこと
5. **samples の「スクロールで続きを読み込む」「最後まで読むと終端の表示が出る」**: Android は VM の単体試験とライブラリの結合試験の組み合わせで確かめている (画面の上の通しの試験は iOS の UI 試験だけ)。tasks 6.4 / 6.5 の分担どおり。「末尾の表示が操作に隠れない」は、verify-001 の時点で証跡だけだった Android にも自動試験 (`PagingDemoScreenTest.kt:192`) が入った
