# 一致検証: paging-state-machine (001 回目)

**日付**: 2026-09-27
**判定**: VALID
**対象**: 作業ツリーの未コミットの変更すべて (`git diff HEAD` と未追跡ファイル。ios/ android/ samples/ 配下)
**デルタスペック**: `specs/collection-paging/spec.md` (ADDED 14 Requirement / 37 Scenario)、`specs/collection-core/spec.md` (MODIFIED 1 / ADDED 1 Requirement、10 Scenario)、`specs/samples/spec.md` (ADDED 5 Requirement / 13 Scenario)

## サマリー

- 全 21 Requirement・60 Scenario を 1 行ずつ、両プラットフォームの実装箇所と試験 (または証跡) に対応づけた
  - ❌ (未記録の欠落・乖離) は 0 件
  - 合意済みの差分が関わる行には ⚠️ を添えた。deviation.md の 5 件 (1・3・4・6・7 件目) と、brief.md の照合結果の 2 件 (4・5) が当たる
  - Scenario の判定そのものが ⚠️ なのは samples の「項目があるときの取り直しの失敗」の 1 件。残りの 59 件は ✅
  - deviation.md の 2 件目 (Sample の VM の書き方) は design の差で、Scenario には関わらない。5 件目は「変更なし」の記録
- tasks.md に虚偽のチェックはない
  - 7.2〜7.4 は未チェックで、オーナーの目視・体感ゲートの待ち (下の「オーナーゲート待ち」)
  - これらのゲートに直接結びつく Scenario は無い。関係する Scenario (端への挿入の MODIFIED、取り直しの先頭) は自動試験で確かめてある
- 逆流は無い。proposal / design / specs は HEAD (提案のコミット `58efa6c`) から変わっていない
  - tasks.md の差分はチェックの記入だけ
  - ui/brief.md の差分は末尾の「照合結果」の追記だけ
- 試験は 4 系統とも、このワーカーが絞り込みなしの全件で実行した (件数は「試験の実行」)

## 対応表

凡例: ✅ 一致 / ⚠️ deviation 記録済み / ❌ 欠落・乖離

パスの略記:

- iOS 本体のソース: `ios/Sources/KsCollectionView/`
- iOS 本体の試験: `ios/Tests/KsCollectionViewTests/`
- Android 本体のソース: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/`
- Android 本体の試験: `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/`
- iOS Sample: `samples/ios/KsCollectionViewSamples/`、UI 試験は `samples/ios/KsCollectionViewSamplesUITests/PagingDemoUITests.swift`
- Android Sample: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/`、試験は同じパッケージの `src/test/...`

試験名の後ろの数字は、その試験の関数が始まる行。

### collection-paging

| Requirement / Scenario | 実装 (iOS / Android) | 試験 (iOS / Android) | 状態 |
|---|---|---|---|
| **ページングの状態** (5 値・付属値なし・書き換えない) | `KsPagingState.swift:5` / `KsPagingState.kt:9` | `KsPublicAPITests.swift:303` / `KsCollectionViewPublicApiTest.kt:262` | ✅ |
| └ ライブラリは状態を書き換えない | 状態は設定から読むだけ (`KsCollectionViewController.swift:1622`) / `KsCollectionView.kt:369-390` | `KsPagingTriggerTests.swift:261` / `KsPagingTriggerTest.kt:240` | ✅ |
| **ページングの設定** (非同期関数・しきい値の既定 1) | `KsCollectionView+Paging.swift:55` / `KsPaging.kt:69`、`KsCollectionView.kt:159` | `KsPublicAPITests.swift:311,323,333,343` / `KsCollectionViewPublicApiTest.kt:277,293,312` | ✅ |
| └ ページングを付けない一覧 | `evaluatePaging` の guard (`KsCollectionViewController.swift:1623-1628`) / `pagingInput` が null (`KsCollectionView.kt:727`)、`hasFooterSlot` (`:176`) | `KsPagingTriggerTests.swift:243` / `KsPagingTriggerTest.kt:225` | ✅ |
| **追加読み込みの発火** | `KsPagingRequester.swift:31-41,64-92`、`visiblePagingItems` (`KsCollectionViewController.swift:1649`) / `KsPagingRequester.kt:58-83,129`、`pagingInput` (`KsCollectionView.kt:720`) | 単体: `KsPagingRequesterTests.swift:39-87` / `KsPagingRequesterTest.kt:33-95` | ✅ |
| └ 既定のしきい値で 1 画面分手前で頼む | 同上 | `KsPagingTriggerTests.swift:26` / `KsPagingTriggerTest.kt:66` | ✅ |
| └ しきい値 2 | 同上 | `KsPagingTriggerTests.swift:49` / `KsPagingTriggerTest.kt:81` | ✅ |
| └ しきい値 0 | 同上 | `KsPagingTriggerTests.swift:65` / `KsPagingTriggerTest.kt:93` | ✅ |
| └ グリッドは項目の数で数える | `sectionItemRanges` で配列上の位置に変換 / `itemIndexOfLazy` | `KsPagingTriggerTests.swift:83` / `KsPagingTriggerTest.kt:105` | ✅ |
| └ 画面に項目が出ていないとき | `KsPagingRequester.swift:79-87` / `KsPagingRequester.kt:72-78` | `KsPagingTriggerTests.swift:141` / `KsPagingTriggerTest.kt:155` (単体: `KsPagingRequesterTests.swift:87` / `KsPagingRequesterTest.kt:95`) | ✅ |
| └ 見出しとフッターは数えない | セルだけを数える (`KsCollectionViewController.swift:1649-1669`) / `itemIndexOfLazy < 0` を飛ばす (`KsCollectionView.kt:732-733`) | `KsPagingTriggerTests.swift:109` / `KsPagingTriggerTest.kt:119` | ✅ |
| **判定し直すきっかけ** | スクロール `scrollViewDidScroll` (`:330`)・レイアウトの確定 (`:337`)・差分の適用の完了 (`:945`)・設定の更新 (`:180`)・処理の終わり (`:1615`) / `snapshotFlow` で状態・配列・しきい値・表示範囲・実行中を観測 (`KsCollectionView.kt:369-390`) | 下の 3 行 | ✅ |
| └ 1 ページが画面に満たないとき | 同上 | `KsPagingTriggerTests.swift:170` / `KsPagingTriggerTest.kt:169` | ✅ |
| └ 失敗から待機に戻ったとき | 同上 | `KsPagingTriggerTests.swift:195` / `KsPagingTriggerTest.kt:186` | ✅ |
| └ 回転で画面に出る項目の数が変わったとき | 同上 (一覧の大きさの変化で判定) | `KsPagingTriggerTests.swift:221` / `KsPagingTriggerTest.kt:209` (どちらも一覧の大きさを変えて再現) | ✅ |
| **初回の読み込み** | `KsPagingRequester.swift:76-77` / `KsPagingRequester.kt:71` | 下の 1 行 | ✅ |
| └ 空で待機なら頼む | 同上 | `KsPagingTriggerTests.swift:272` / `KsPagingTriggerTest.kt:253` (単体: `KsPagingRequesterTests.swift:71` / `KsPagingRequesterTest.kt:75`) | ✅ |
| **待機のときだけ自動で頼む** | `KsPagingRequester.swift:74` / `KsPagingRequester.kt:69` | 単体: `KsPagingRequesterTests.swift:104` / `KsPagingRequesterTest.kt:115` | ✅ |
| └ 終端では頼まない | 同上 | `KsPagingTriggerTests.swift:210` / `KsPagingTriggerTest.kt:199` | ✅ |
| └ 失敗では自動で頼まない | 同上 | `KsPagingTriggerTests.swift:195` の前半 / `KsPagingTriggerTest.kt:186` の前半 (単体: 上と同じ) | ✅ |
| **頼んだ後の待ち方** | 控え (`latch`) と実行中の印 (`KsPagingRequester.swift:23,54-59,112-127`) / (`KsPagingRequester.kt:37-51,105`)。配列の版は iOS が中身の比較 (`KsCollectionViewController.swift:190-192`)、Android が `KsPagingItemsVersion` (`KsPagingRequester.kt:148`) | 下の 3 行と、判定を飛ばす間の往復 `KsPagingTriggerTests.swift:329` / `KsPagingTriggerTest.kt:266` | ✅ |
| └ VM が状態の書き換えを遅らせても二重に頼まない | 同上 | `KsPagingRequesterTests.swift:125` / `KsPagingRequesterTest.kt:131` | ✅ |
| └ 処理の中で待つ VM | 同上 | `KsPagingRequesterTests.swift:139` / `KsPagingRequesterTest.kt:146` | ✅ |
| └ 頼みが無視されたとき | 同上 | `KsPagingRequesterTests.swift:153` / `KsPagingRequesterTest.kt:171` (結合: `KsPagingTriggerTests.swift:261` / `KsPagingTriggerTest.kt:253`) | ✅ |
| **一覧が破棄されたときの取り消し** | `disconnect()` → `pagingRequester.cancel()` (`KsCollectionViewController.swift:364-370`) / `DisposableEffect` → `cancel()` (`KsCollectionView.kt:365-367`) | 取り消さない側: `KsPagingTriggerTests.swift:308` (iOS のみ。Android はナビゲーションの仕組みに任せる — spec の本文どおり) | ✅ |
| └ 読み込み中に画面を閉じる | 同上 | `KsPagingTriggerTests.swift:294` / `KsPagingTriggerTest.kt:289` | ✅ |
| **不正なしきい値** | `reportInvalidPagingThresholdIfNeeded` (`KsCollectionViewController.swift:1672`)、`effectiveThreshold` (`KsPagingRequester.swift:49`) / `invalidThresholdMessage` (`KsPaging.kt:95`、`KsCollectionView.kt:226`)、`effectiveThreshold` (`KsPagingRequester.kt:139`) | `KsPagingTriggerTests.swift:373`、`KsPagingRequesterTests.swift:252` / `KsPagingTriggerTest.kt:333` (debug の停止)、`KsPagingRequesterTest.kt:258` | ✅ |
| └ 負のしきい値 (release) | 同上 | `KsPagingTriggerTests.swift:354` / `KsPagingTriggerTest.kt:315` | ✅ |
| **ページングの表示** (6 つの表示・置き場・差し替え・既定) | 表: `KsPagingDisplay.swift:21-31` / `KsPagingDisplay.kt:49-55`。既定: `KsPagingDisplays.swift:18-32`、`KsPagingDefaultProgress.swift` / `KsPaging.kt:84`、`KsPagingDisplay.kt:69`。フッターの枠: `configurePagingFooter` (`KsCollectionViewController.swift:1510`)、`KsPagingFooterStack.swift` / `KsCollectionView.kt:644-661`、`KsPagingDisplay.kt:87`。0 件: `updatePagingPlaceholder` (`KsCollectionViewController.swift:1545`)、`KsPagingPlaceholderView.swift:10,45` / `KsCollectionView.kt:669-680` | 表の全組み合わせ: `KsPagingDisplayTests.swift:28` / `KsPagingDisplayTest.kt:52` | ✅ (置き場の幅は ⚠️ deviation.md 1 件目。下の注を参照) |
| └ 次のページの読み込み中 (既定) | 同上 | `KsPagingDisplayTests.swift:48` / `KsPagingDisplayTest.kt:72` | ✅ |
| └ 最初の読み込み中 (既定) | 同上 | `KsPagingDisplayTests.swift:83` / `KsPagingDisplayTest.kt:92,103` | ✅ |
| └ 失敗・終端・空は既定では出ない | 同上 | `KsPagingDisplayTests.swift:100` / `KsPagingDisplayTest.kt:111` | ✅ |
| └ 差し替えた表示が出る | 同上 | `KsPagingDisplayTests.swift:184` / `KsPagingDisplayTest.kt:135` | ✅ |
| └ VM が始めた取り直しの間は項目の上に何も出さない | 表の `(.refreshing, false)` / `Refreshing -> null` | `KsPagingDisplayTests.swift:210` / `KsPagingDisplayTest.kt:175` | ✅ |
| └ 状態だけが変わったとき | `invalidatePagingFooterIfNeeded` (`KsCollectionViewController.swift:1527`) / 状態を読んで再構成 | `KsPagingDisplayTests.swift:226` / `KsPagingDisplayTest.kt:187` | ✅ |
| └ 0 件の表示がヘッダーと重なっても押せる | 手前に重ね、外のタッチは通す (`KsPagingPlaceholderView.swift:10,45`) / `zIndex(1f)` (`KsCollectionView.kt:678`) | `KsPagingDisplayTests.swift:270` / `KsPagingDisplayTest.kt:208` (どちらも外のタッチが下へ通ることも確かめる) | ✅ |
| **再試行** | `retryPaging` (`KsCollectionViewController.swift:1608`)、`KsPagingRequester.swift:95` / `retryPaging` (`KsCollectionView.kt:350`)、`KsPagingRequester.kt:86` | 単体: `KsPagingRequesterTests.swift:174,187,194` / `KsPagingRequesterTest.kt:182,194,204` | ✅ |
| └ 項目があるときの再試行 | 同上 | `KsPagingDisplayTests.swift:362` / `KsPagingDisplayTest.kt:274` | ✅ |
| └ 0 件のときの再試行 | 同上 | `KsPagingDisplayTests.swift:385` / `KsPagingDisplayTest.kt:297` | ✅ |
| **Pull to Refresh の接続** | `@Environment(\.refresh)` (`KsCollectionView.swift:28,37-38`)、`syncPullRefreshControl` (`KsCollectionViewController.swift:1688`) / `onRefresh` 引数 (`KsCollectionView.kt:160`)、`Modifier.pullToRefresh` (`:413`) | `KsPullToRefreshTests.swift:31` (渡さない一覧は引っ張れない)、`:51` (`.refreshable` を受け取る) / `KsPullToRefreshTest.kt:81` | ✅ |
| └ 引っ張ると取り直しの処理が呼ばれる | 同上 | `KsPullToRefreshTests.swift:17` / `KsPullToRefreshTest.kt:57` (ページングの有無の両方) | ✅ |
| └ 0 件でも引っ張れる | 同上 | `KsPullToRefreshTests.swift:40` / `KsPullToRefreshTest.kt:94` | ✅ |
| **Pull to Refresh のインジケータ** | `handlePullRefresh`・`endPullRefreshIfFinished`・`finishPullRefresh` (`KsCollectionViewController.swift:1709,1728,1735`)、`KsRefreshControl.swift` / `KsPullRefresh.kt:43,63,67`、`PullToRefreshDefaults.Indicator` (`KsCollectionView.kt:690-696`) | 追加で `KsPullToRefreshTests.swift:161` / `KsPullToRefreshTest.kt:153,205` | ✅ |
| └ 処理の中で待つ取り直し | 同上 | `KsPullToRefreshTests.swift:69` / `KsPullToRefreshTest.kt:105` | ✅ |
| └ 処理がすぐ戻る取り直し | 同上 | `KsPullToRefreshTests.swift:88` / `KsPullToRefreshTest.kt:122` | ✅ |
| └ VM が始めた取り直しでは出さない | 同上 | `KsPullToRefreshTests.swift:110` / `KsPullToRefreshTest.kt:142` | ✅ |
| └ 全画面の一覧でも見える | `addRefreshExtraTopInset` (`KsCollectionViewController.swift:1776`)、`KsRefreshControl.swift:32,47` / `offset { topSafeArea.overlapPx() }` (`KsCollectionView.kt:696`) | `KsPullToRefreshTests.swift:184,268,303,317` / `KsPullToRefreshTest.kt:224`。証跡: `evidence/ios-pull-to-refresh-*.png`・`evidence/android-pull-to-refresh-*.png` (tasks 5.4) | ✅ (Android の Sample ではステータスバーの分を下げる処理が働かない点は ⚠️ brief の照合結果 4) |
| **追加読み込みの間は引っ張れない** | `syncPullRefreshControl` の `blocksPull` (`KsCollectionViewController.swift:1697-1702`) / `acceptsPull` → `enabled` (`KsCollectionView.kt:408,413-416`) | 下の 3 行 | ✅ |
| └ 追加読み込み中に引っ張る | 同上 | `KsPullToRefreshTests.swift:127` の前半 / `KsPullToRefreshTest.kt:169` の前半 | ✅ |
| └ 処理の実行中に引っ張る | 同上 | `KsPullToRefreshTests.swift:143` / `KsPullToRefreshTest.kt:187` | ✅ |
| └ 追加読み込みが終わった後 | 同上 | `KsPullToRefreshTests.swift:127` の後半 / `KsPullToRefreshTest.kt:169` の後半 | ✅ |

注 (ページングの表示の置き場): spec は置き場を「最後の項目の後ろ・ルートのフッターの前」とだけ定める。幅 (全幅か余白の内側か) は brief の見た目の範囲で、deviation.md の 1 件目に合意済み。置き場は `KsPagingDisplayTests.swift:119,163` で確かめている。

### collection-core

| Requirement / Scenario | 実装 (iOS / Android) | 試験 (iOS / Android) | 状態 |
|---|---|---|---|
| **端を表示中の端への挿入** (MODIFIED) | `edgeToKeep` (`KsCollectionViewController.swift:955-982`。直前が終端以外なら末尾を返さない `:976-978`) / `keepEdge` (`KsPositionKeeper.kt:100-136`。`:130`) | 下の 6 行 | ✅ |
| └ いちばん上での先頭への挿入 | 既存の規則のまま | `KsEdgeInsertionTests.swift:41` (list / グリッド、グループ・フッターの有無の組み合わせ) / `KsCollectionViewGroupingTest.kt:760,766,904` | ✅ |
| └ いちばん下での末尾への挿入 (ページングなし) | 既存の規則のまま (ページングなしは直前の状態が nil) | `KsEdgeInsertionTests.swift:69` / `KsCollectionViewGroupingTest.kt:772,778,927,933` | ✅ |
| └ ルートのフッターがあるときの末尾への挿入 (ページングなし) | 同上 | `KsEdgeInsertionTests.swift:69` のフッターありの組み合わせ (`:98-104`) / `KsCollectionViewGroupingTest.kt:829` | ✅ |
| └ 追加読み込みで届いたページは今の位置の下に現れる | 直前が追加読み込み中なら末尾に留めない | `KsPagingPositionTests.swift:20` (list / グリッド) / `KsPagingPositionTest.kt:44,50` | ✅ |
| └ 最後のページが届くのと同時に終端になる | 同上 | `KsPagingPositionTests.swift:55` / `KsPagingPositionTest.kt:56` | ✅ |
| └ 終端の後に末尾へ足した項目 | 直前が終端なら従来どおり末尾に留める | `KsPagingPositionTests.swift:73` / `KsPagingPositionTest.kt:63` | ✅ |
| **取り直しの結果は先頭から表示する** (ADDED) | `showsTopOnReplacement` (`KsCollectionViewController.swift:989`)、`showContentTopIfRefreshEnded` (`:997`)、`finishPullRefresh` (`:1735`) / `keepEdge` の先頭 (`KsPositionKeeper.kt:110-113`) | 下の 4 行。塊の件数が変わる差し替え: `KsPagingPositionTests.swift:219` | ✅ (Pull to Refresh の間の規則の追加は ⚠️ deviation.md 6 件目。取り直しの失敗時の iOS / Android の差は ⚠️ 7 件目) |
| └ 途中で取り直す | 同上 | `KsPagingPositionTests.swift:103,130` (list / グリッド) / `KsPagingPositionTest.kt:84` (list / グリッド) | ✅ |
| └ 大きな一覧を取り直す | 同上 | `KsPagingPositionTests.swift:198` / `KsPagingPositionTest.kt:93` | ✅ |
| └ Pull to Refresh の取り直し | 同上 | `KsPagingPositionTests.swift:244` / `KsPagingPositionTest.kt:99`。実際に引っ張る経路: `KsPullToRefreshTests.swift:373,418,441,467` / `KsPullToRefreshTest.kt:303,309,315` | ✅ |
| └ 状態を取り直し中にしない差し替え | 同上 (直前が取り直し中でなければ既定の保ち方) | `KsPagingPositionTests.swift:265` / `KsPagingPositionTest.kt:160`。出し終えた後の差し替え: `KsPullToRefreshTests.swift:493` / `KsPullToRefreshTest.kt:153` | ✅ |

レビュー 2 周目の後に足された iOS の試験 `KsPullToRefreshTests.swift:467` (`testSwiftUIのrefreshableで取得がすぐ終わる取り直しでも先頭が表示される`) は、次の経路を通る。

- `ObservableObject` の VM (`KsPagingRefreshModel`、同ファイル `:607`) と `.refreshable` を `UIHostingController` に載せる
- 500 件を途中までスクロールして引っ張る
- 最終位置がコンテンツの先頭で、先頭の項目が新しい配列の先頭であり、次ページ要求がすぐ呼ばれないことを確かめる

deviation.md 6 件目 (Pull to Refresh の間は直前の状態によらず先頭) と「Pull to Refresh の取り直し」の Scenario に対応する。今回の iOS 全件実行で成功した。

### samples

| Requirement / Scenario | 実装 (iOS / Android) | 試験・証跡 (iOS / Android) | 状態 |
|---|---|---|---|
| **デモ画面「ページング」** | `SampleScreen.swift:14`、`SampleDestinationView.swift:33`、`PagingDemoView.swift`、`PagingDemoSource.swift:11,14` / `SampleScreen.kt:23`、`SampleNavHost.kt:83`、`PagingDemoScreen.kt`、`PagingDemoSource.kt:35`。既定の遅延: `PagingDelay.swift:10` / `PagingDelay.kt:12` | `PagingDemoSourceTest.kt:18,24,36,47,70` | ✅ |
| └ 両プラットフォームで同じ構成 | 同上 | `PagingDemoUITests.swift:36` / `SampleScreenParityTest.kt:33,79,112` (iOS の文言・寸法の写しと突き合わせる) | ✅ |
| └ 開いたら最初のページを読み込む | 初回の読み込みはライブラリの初回の読み込み (0 件・待機) | `PagingDemoUITests.swift:74` / `PagingDemoScreenTest.kt:81`、`PagingDemoModelTest.kt:88`。証跡: `ui/verification/ios-01-initial-loading.png`・`android-01-initial-loading.png` | ✅ |
| └ スクロールで続きを読み込む | `loadNextPage` (`PagingDemoModel.swift:64` / `PagingDemoModel.kt:122`) | `PagingDemoUITests.swift:91` / `PagingDemoModelTest.kt:104` (画面の発火はライブラリの結合試験。tasks 6.4 の分担どおり)。証跡: `ui/verification/android-02-appending-list-folded.png` | ✅ |
| └ 最後まで読むと終端の表示が出る | 終端の表示の差し替え (`PagingDemoView.swift:92` / `PagingDemoScreen.kt:149`) | `PagingDemoUITests.swift:103` / `PagingDemoModelTest.kt:145`、`PagingDemoSourceTest.kt:36` | ✅ |
| **失敗と空の実演** | 2 つの切り替えと取得元 (`PagingDemoSource.swift` / `PagingDemoSource.kt`)、`setEmpty` (`PagingDemoModel.swift:118` / `PagingDemoModel.kt:186`)。差し替え (`PagingDemoView.swift:88-101` / `PagingDemoScreen.kt:142-156`)。文言 (`PagingDemoText.swift` / `PagingDemoText.kt`) | `PagingDemoModelTest.kt:116,181`、`PagingDemoSourceTest.kt:53,62`、`SampleScreenParityTest.kt:79` | ✅ |
| └ 次のページの失敗と再試行 | 同上 | `PagingDemoUITests.swift:122` / `PagingDemoModelTest.kt:158`。証跡: `ui/verification/ios-03-append-failed-grid.png`・`android-03-append-failed-grid.png` | ✅ |
| └ 最初の読み込みの失敗 | 同上 | `PagingDemoUITests.swift:145` / `PagingDemoScreenTest.kt:104`。証跡: `ui/verification/android-06-initial-failed.png` | ✅ |
| └ 0 件 | 同上 | `PagingDemoUITests.swift:162` / `PagingDemoScreenTest.kt:92`、`PagingDemoModelTest.kt:462`。証跡: `ui/verification/ios-05-empty.png`・`android-05-empty.png` | ✅ |
| **取り直しの実演** | `refresh` と世代 (`PagingDemoModel.swift:85-111` / `PagingDemoModel.kt:143-172`)、`reload` (`PagingDemoModel.swift:113` / `PagingDemoModel.kt:176`)、`.refreshable` / `onRefresh` (`PagingDemoView.swift:102` / `PagingDemoScreen.kt:158`) | `PagingDemoModelTest.kt:196,325,338,364` | ✅ (失敗時に戻す状態は ⚠️ deviation.md 3 件目。「更新できませんでした」の出し方は ⚠️ 4 件目・照合結果 5) |
| └ 途中から再読み込み | 同上 | `PagingDemoUITests.swift:176` / `PagingDemoScreenTest.kt:156` | ✅ |
| └ 追加読み込み中に再読み込み | 同上 | `PagingDemoUITests.swift:193` / `PagingDemoModelTest.kt:338,364,380` | ✅ |
| └ 項目があるときの取り直しの失敗 | 同上。帯: `PagingRefreshFailedBanner.swift` / `PagingRefreshFailedBanner.kt` | `PagingDemoUITests.swift:220` / `PagingDemoScreenTest.kt:123`、`PagingDemoModelTest.kt:213`。証跡: `ui/verification/ios-04-*.png`・`android-04-*.png` | ⚠️ (「更新できませんでした」を帯で出す。deviation.md 4 件目) |
| **操作を畳める** | `PagingControlPanel.swift`、`PagingPanelHandle.swift` / `PagingControlPanel.kt`、`PagingPanelHandle.kt`。下の余白: `PagingDemoView.swift:78` / `PagingDemoScreen.kt:74,138` | `SampleScreenParityTest.kt:112` (寸法) | ✅ |
| └ 畳んで広げる | 同上 | `PagingDemoUITests.swift:260` / `PagingDemoScreenTest.kt:170,188` | ✅ |
| └ 末尾の表示が操作に隠れない | 同上 | `PagingDemoUITests.swift:281` / 自動試験なし。証跡: `ui/verification/android-03-append-failed-grid.png` (パネルを広げたまま、次のページの失敗の「読み込めませんでした」と「再試行」がパネルの上に出ている) | ✅ (Android は証跡で確認。下の所見) |
| **起動引数** | `PagingDelay.swift:13` (`--paging-delay-ms`)、`SampleLaunchView.swift:36` (`--screen`) / `SampleRoutes.kt:48` (`ks_paging_delay_ms`)、`MainActivity.kt` (開始ルートと遅延) | `PagingDelayTest.kt:15,21,28,37` / `SampleScreenParityTest.kt:148` | ✅ |
| └ 遅延を縮めて開く | 同上 | `PagingDemoUITests.swift:62` / `PagingDelayTest.kt:21`、`SampleScreenParityTest.kt:148` | ✅ |

## 追加検査

- [x] **tasks.md**
  - 0.1〜7.1 の 30 件はチェック済みで、どれも対応表の実装・試験・証跡と対応している (虚偽なし)
  - 7.2〜7.4 は未チェック (オーナーゲート待ち)
- [x] **逆流検査**
  - `git diff HEAD -- proposal.md design.md specs/` は差分なし。提案のコミット `58efa6c` の後にコミットは無い
  - tasks.md の差分は `- [ ]` → `- [x]` だけで、本文の書き換えは無い
  - ui/brief.md の差分は末尾の「照合結果」の節の追記だけ
- [x] **未記録乖離**: 0 件。spec と違う箇所は、すべて deviation.md (7 件) か brief.md の照合結果 (5 件) に記録がある
- [x] **付随修正**: deviation.md に `[付随修正]` の行は無い。diff の中に、Scenario に対応しない実装上の変更が 3 つあるが、どれも付随修正には当たらない
  - Android の `KsTopSafeArea.kt` の下端の重なり: 0 件の表示を上下の安全領域を除いた真ん中に置くため。tasks 3.3、ページングの表示の Requirement の実装に含まれる
  - `KsCompositionalLayout.swift` の取り直し中の上端の余白: インジケータの位置のため。tasks 5.1
  - Android の `KsPositionKeeper` の「0 件から最初のページが届いたら先頭」: 先頭を表示中の先頭への挿入の規則の範囲
- [x] **UI 変更の記録**
  - brief.md に承認 mock の記録がある (案 C `mock/paging-variant-c-floating-panel.html`・`mock/approved.png`、2026-09-27 オーナー承認)
  - 照合結果と合意済み妥協 5 件がある
  - 視覚照合の画像は `ui/verification/` にある
- [x] **試験の全件成功**: 下の「試験の実行」

## オーナーゲート待ち (INVALID の理由にしない)

tasks 7.2〜7.4 は、オーナーとの目視・体感のゲートで、この後に行う。

| タスク | 関係する Scenario | この検証での扱い |
|---|---|---|
| 7.2 フッターの枠の高さが変わるときに表示範囲が跳ねない | spec に直接の Scenario は無い (brief と design の Risks)。関係するのは「状態だけが変わったとき」「追加読み込みで届いたページは今の位置の下に現れる」 | どちらも自動試験で一致を確かめた。跳ねの見え方はオーナーゲート待ち |
| 7.3 基準機の体感ゲート (遅延 200 ms・リスト) | Scenario 無し (design Decision 10) | オーナーゲート待ち |
| 7.4 iOS の塊の件数が変わる追加読み込みの見え方 | Scenario 無し (design の Risks)。取り直し側は `KsPagingPositionTests.swift:219` で確かめた | オーナーゲート待ち |

## 試験の実行

このワーカーが、新しく作った Simulator と Robolectric で絞り込みなしの全件を実行した。既存の Simulator・エミュレータ・実機には触れていない。

| 系統 | コマンド | 結果 |
|---|---|---|
| iOS ライブラリ (SwiftPM) | `ios/` で `xcodebuild test -scheme KsCollectionView -configuration Debug`。Simulator `ksn-paging-verify` (iPhone 17 Pro / iOS 26.5) | 430 件・失敗 0 (`** TEST SUCCEEDED **`)。ページングの試験は Display 15・Position 10・Requester 18・Trigger 19・PullToRefresh 21 (レビュー後に足された `:467` を含む)・PublicAPI 23・EdgeInsertion 3 |
| iOS Sample UI (通常スキーム) | `samples/ios/` で `xcodebuild test -scheme KsCollectionViewSamples`。Simulator `ksn-paging-verify-ui` (iPhone 17 Pro / iOS 26.5) | 34 件・失敗 0 (`** TEST SUCCEEDED **`)。PagingDemoUITests は 13 件。計測ドライバは通常スキームで除外される |
| Android ライブラリ | `android/` で `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks`。XML を集計 | 24 クラス・403 件・失敗 0・エラー 0・スキップ 0。ページングの 8 クラスは PublicApi 16・Trigger 17・Requester 17・Display 13・Position 11・PullToRefresh 15・FooterResize 3・EmbeddedSafeArea 2 |
| Android Sample | `samples/android/` で `./gradlew :app:testDebugUnitTest --rerun-tasks`。XML を集計 | 19 クラス・144 件・失敗 0・エラー 0・スキップ 0。ページングの試験は PagingDemoModel 23・PagingDemoScreen 7・PagingDemoSource 7・PagingDelay 4・SampleScreenParity 8 |

ホストが報告していた件数は、iOS ライブラリ 430・iOS Sample UI 34・Android ライブラリ 403・Android Sample 144 件。

試験の後、2 つの Simulator は停止した (削除はしていない)。

## 所見 (判定に影響しない)

- samples の「末尾の表示が操作に隠れない」は、Android に自動試験が無く、`ui/verification/android-03-append-failed-grid.png` の証跡だけで確かめている
  - tasks 6.4 は Android の Sample の試験を単体試験に分担しており (UI 試験は iOS の 6.5)、計画どおり
  - 両プラットフォームの下の余白は同じ寸法 (`SampleScreenParityTest.kt:112`) から組み立てている
- deviation.md の 6 件目・7 件目は、ADR-0021 の本文と負の帰結への反映を蒸留時に行う扱いになっている。蒸留で落とさないこと
- samples の「スクロールで続きを読み込む」と「最後まで読むと終端の表示が出る」は、Android では VM の単体試験と、ライブラリの発火・表示の結合試験を組み合わせて確かめている (画面の上の通しの試験は iOS の UI 試験だけ)。tasks 6.4 / 6.5 の分担どおり
