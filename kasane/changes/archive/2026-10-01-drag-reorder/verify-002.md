# Verify 002: drag-reorder

- 検証日: 2026-10-01
- 対象: 作業ツリーの未コミットの変更 (`git diff HEAD` と未追跡のファイル。ios/・android/・samples/ 配下)。verify-001 (VALID) の後の変更 — iOS の並べ替えの reorder-capable な形への組み替え (`reorderingHandlers`・`reorderingCadence = .slow`・ドロップのセッションの終わりを待つ戻し)、置く絵の見た目 (`dropPreviewParametersForItemAt`)、読み上げの部品の付け方、review-009 の指摘への対応、Android の持ち上げの影の層の付け直し (`ksReorderLiftShadow`) — を含む
- デルタスペック: `specs/collection-reorder/spec.md` (ADDED 10 Requirement / 30 Scenario)、`specs/collection-interaction/spec.md` (MODIFIED 1 / 7)、`specs/samples/spec.md` (ADDED 2 / 9)。計 13 Requirement / 46 Scenario
- 合意済みの差分: `deviation.md` の乖離 9 行 (うち verify-001 の後に足された 3 行: iOS の reorder-capable な形への組み替え (置く絵の見た目の追記を含む)・バーの上でのプレビューの縮み・組み替えで分かったこと (1)〜(5))・付随修正 1 行、`ui/brief.md` の合意済み妥協 2 件
- 並行する review-011 (iOS の直近の修正の確認) は、この検証の時点で `review-011.md` が無い。対応表はこの時点の実装で判定した

## 判定: VALID

全 46 Scenario が「✅ 一致」または「⚠️ deviation 記録済み」。未記録の欠落・乖離 (❌) は 0 件。虚偽のチェック・足場の逆流は無い。テストは、iOS Sample の UI テスト 1 件が Simulator の通知のバナーの割り込みで 1 回失敗したが、同じ 1 件を 3 回流し直して 3 回とも成功し、実装の失敗は無いと判断した (下の「テストの実行」)。

ただし tasks 6.3・6.4 (基準機でのオーナーの目視) は未完了 (チェック無し)。6.3 は 1 回目 (2026-09-30) の指摘 4 件を受けて iOS を組み替え、Android の影を直した後の「見直し」が残っている。依頼どおり「verify の後に行う基準機の確認」として扱い、この判定には含めない。蒸留 (archive) の前に 6.3・6.4 を終え、結果を evidence/ に残す必要がある (観点は `owner-visual-checkpoints.md` の「6.3 の見直しで見る観点」)。

## テストの実行

直近の全件の結果を材料として使った (依頼の記載): iOS ライブラリ 529 件が iOS 18.6・26.5 で成功、iOS Sample の `ReorderDemoUITests` 10 件成功 (ほかの UI テスト 34 件は組み替えの前の 44 件の実行で成功)、Android ライブラリ 474 件成功、Android Sample 163 件成功 (影の修正の前の実行)、lint 違反 0 件。

加えて、対応表を作るうえで最後に変わった部分を、この検証専用のシミュレータで絞って流した。

- iOS ライブラリ: `xcodebuild test -scheme KsCollectionView` を `ksn-drag-reorder-verify2-26` (iPhone 17 / iOS 26.5) と `ksn-drag-reorder-verify2-18` (iPhone 16 / iOS 18.6) の 2 台に同時に、`-only-testing` に `KsReorderEngineTests` (57)・`KsReorderPlannerTests` (10)・`KsReorderGapTrackerTests` (5)・`KsReorderTopAutoScrollTests` (14)・`KsPublicAPITests` (26) を指定。両 OS とも 112 件すべて成功 (計 224 件、失敗 0)。対象は iOS の本体と試験の最終更新 (`KsCollectionViewController+Reorder.swift`・`KsReorderAccessibilityModel.swift` 02:40、`KsReorderEngineTests.swift` 02:40) より後の作業ツリー
- iOS Sample: `ReorderDemoUITests` 10 件を `ksn-drag-reorder-verify2-26` (作りたての Simulator) で、現時点のライブラリから組んで実行。9 件成功・1 件失敗。失敗した `testグリッドとグループなしでも並べ替えられる` は、長押しからのドラッグを合成する直前に SpringBoard の通知のバナー (`NotificationShortLookView`) が割り込み、XCTest の既定の割り込み処理がバナーの消えるのを待ってから合成した回で、並びは 1 2 3 4 のまま動かなかった (ログの「Found 1 interrupting element」)。同じビルドのまま `test-without-building` でこの 1 件を 3 回 (`-test-iterations 3`) 流し、3 回とも成功した。Simulator の作りたての通知による環境の割り込みと判断し、実装の不具合とは扱わない (依頼の材料の直近の実行でも 10 件成功)
- Android Sample: 影の修正 (`KsReorderLift.kt`・`KsCollectionView.kt` 01:09) の後のライブラリで、`:app:testDebugUnitTest --tests '*ReorderDemo*' --tests '*SampleScreenParityTest*'` を実行。`ReorderDemoModelTest` 10・`ReorderDemoScreenTest` 6・`SampleScreenParityTest` 10 の 26 件すべて成功
- Android ライブラリの並べ替えのテスト (`KsReorderDragTest`・`KsReorderHoldTest`・`KsReorderPlannerTest`) と `KsReorderController.kt` は verify-001 の後に変わっていない (最終更新 2026-09-30 12:49)。影の修正の後の全件 474 件の成功を材料にし、再実行していない

## 対応表

略記: iOS の実装は `ios/Sources/KsCollectionView/`、iOS のテストは `ios/Tests/KsCollectionViewTests/`、Android の実装は `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/`、Android ライブラリのテストは `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/`、Android Sample のテストは `samples/android/app/src/test/kotlin/jp/kamusoft/kscollectionview/samples/android/` の下。`Ctl` は `KsCollectionViewController.swift`、`Ctl+R` は `KsCollectionViewController+Reorder.swift`、`Ctrl.kt` は `KsReorderController.kt`。

iOS の試験の組み立て: UIKit のドラッグ & ドロップは合成できないため、`KsReorderTestSupport.swift` の `KsReorderDriver` が一覧の受ける呼び出しを偽物のセッションで渡す。組み替えの後は、置いたときを UIKit と同じ 2 つの経路に分けている — 隙間を空ける提案で別の位置に置いたときは差分データソースの並びを動かしてから確定を知らせ (`reorderDidReorder`、`drop()`)、元の位置・取りやめ・隙間を空けない提案・隙間が動く前の離し方では置く処理を呼ぶ (`reorderPerformDrop`、`drop()` / `dropBeforeGapMoves`)。ドロップのセッションの終わり (`endDropSession` / `end()`) も別に渡す。

### collection-reorder

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 並べ替えのスイッチ / 有効の間は長押しでドラッグが始まる | iOS `Ctl:1645` (syncReorderInteraction で `dragInteractionEnabled`)・`Ctl+R:97` (itemsForBeginning)・`Ctl:600` (`reorderingHandlers.canReorderItem` はスイッチだけを見る)。Android `Ctrl.kt:133` (lift) | iOS `KsReorderEngineTests` testスイッチが有効なら長押しで持ち上がり無効なら持ち上がらない。Android `KsReorderDragTest` longPressStartsDragAndItemFollowsFinger | ✅ |
| 同 / 無効の間はドラッグが始まらない | 同上 (スイッチ無効・reorder 未設定で持ち上げない) | iOS 同上・test並べ替えを設定していない一覧は持ち上がらない。Android disabledSwitchDoesNotStartDrag | ✅ |
| 同 / ドラッグ中にスイッチが無効になる | iOS `Ctl:1705` (deferDuringReorderDrag)・`Ctl:1721` (cancelsReorderDrag)・`Ctl+R:145` (取りやめ後は `.unspecified`)・`Ctl+R:175` → `:325` (置く処理で元の位置へ動かして戻す)・`Ctl+R:216` (UIKit が並べ替えた後に取りやめていれば元の並びへ戻す)。Android `KsCollectionView.kt:282`・`Ctrl.kt:229` (cancel) | iOS testドラッグ中にスイッチが無効になると取りやめて知らせない (知らせ 0 件・元の位置の中心へ戻す・並び A B C)・test持ち上げた直後にスイッチが無効になると動かし始めた時点で取りやめる。Android disablingSwitchDuringDragCancels | ⚠️ iOS は deviation 記録済み (取りやめは指を離したときに元の位置へ戻す)。Android ✅ |
| 同 / ドラッグ中に layout が変わる | 同上 (layout 値・グループの宣言の比較) | iOS testドラッグ中にlayoutが変わると取りやめて終わった後に新しいlayoutで表示する・testドラッグ中にグループの宣言が変わると取りやめる・test持ち上げた直後にlayoutが変わると動かし始めた時点で取りやめる・test持ち上げた後に構成が変わらなければ取りやめない。Android changingLayoutDuringDragCancels・changingGroupsDuringDragCancels | ⚠️ iOS は同じ deviation 記録済み。Android ✅ |
| 同 / list とグリッドの両方で効く | 両プラットフォームとも layout に依らない同じ経路 | iOS testグリッドでも並べ替えられ置いたときに知らせる (末尾・B C D A)。Android gridReordersToo | ✅ |
| 置いたときの知らせ / 置いたときに 1 回だけ知らせる | iOS `Ctl:603` (didReorder) → `Ctl+R:201` (reorderDidReorder。見せていた隙間から行き先を求め `onMove` を 1 回)・`Ctl+R:294` (acceptDrop。隙間が動く前に離したとき)・`Ctl+R:32` (配列の要素そのもの)・`KsReorderPlanner.swift:37`。Android `Ctrl.kt:186` (drop)・`KsReorderPlanner.kt:51` | iOS test置いたときに1回だけ動かした項目と後ろの項目で知らせる (途中で知らせない・D の前・グループ nil・B C A D)・test隙間が動く前に離すと置く処理で知らせて受け入れたら置く・test確定した位置が見せていた隙間とずれても見せていた位置で知らせて揃える。Android dropNotifiesOnceWithDestination。計算は iOS `KsReorderPlannerTests` testCとDの間に置くとDの前になる / Android `KsReorderPlannerTest` placeBetweenCAndDIsBeforeD | ⚠️ iOS は置いた位置への移動を UIKit が確定する形 (deviation 記録済み: 組み替え、組み替えで分かったこと (4) の確定位置のずれを見せていた隙間に揃える)。知らせの回数・中身は spec どおり。Android ✅ |
| 同 / 最後に置いたら末尾 | 同上 | iOS test最後に置くと末尾で知らせる・`KsReorderPlannerTests` test最後に置くと末尾になる。Android dropAfterLastIsEnd・placeAfterLastIsEnd | ✅ |
| 同 / 元の位置に置いたら知らせない | iOS `Ctl+R:228`・`:307` (`placement != originalPlacement`)。元の位置では UIKit が置く処理を呼び `Ctl+R:325` で元の位置へ戻す。Android `Ctrl.kt:194` | iOS test元の位置に置くと知らせない (知らせ 0 件・元の位置の中心へ戻す)・testドラッグ中にもとのグループへ戻して置ける。Android dropAtOriginalDoesNotNotify | ✅ |
| 並べ替えは一覧の中だけ / 別の一覧には置けない | iOS `Ctl+R:89` (isOwnReorderSession)・`:129` (canHandle)・`:138` (他のセッションへは `.cancel`)・`KsReorderDragDropDelegate.swift:28` (アプリの外へ出さない)。Android `Ctrl.kt:176` | iOS test別の一覧のセッションは受けずどちらの処理も呼ばれない・testドラッグの項目はアプリの外へ渡す中身を持たない。Android cannotDropIntoAnotherList | ✅ |
| 受け入れと元に戻す / 受け入れないと元に戻る | iOS `Ctl+R:237` (受け入れなければ) → `Ctl:1844` (revertReorderedSnapshot。ドロップのセッションが終わってから元の並びへ動かして戻す)・`Ctl+R:280` (dropSessionDidEnd)。隙間が動く前に離したときは `Ctl+R:179` → `:325`。Android `Ctrl.kt:207`・`:239` | iOS test受け入れないと置いた位置から元の並びへ戻る (知らせ 1 回・セッションの終わりまでは B C A、終わった後に A B C)・test隙間が動く前に離して受け入れないと元の位置へ戻す・test前のドロップのセッションの終わりは次のドラッグに入らない。Android rejectedMoveReturnsToOriginal | ⚠️ iOS は deviation 記録済み (いったん置いた位置に収まってから元の位置へ戻る。組み替えで分かったこと (1) の約 1.3 秒の見え方)。結果 (元の並び・配列は変わらない) は spec どおり。Android ✅ |
| 同 / 受け入れたら配列が届くまで置いた並びのまま | iOS `Ctl:1803` (applyAcceptedReorder)・`Ctl:243` (受け入れた時点と同じ配列なら待つ)。Android `Ctrl.kt:216` (awaiting)・`:105` (shown) | iOS test受け入れたら配列が届くまで置いた並びのままで同じ配列の描き直しでも戻らない (置く処理は呼ばれず UIKit の並べ替えで確定・B A C のまま)。Android acceptedMoveKeepsDroppedOrderUntilArrayArrives | ✅ |
| 同 / 配列が変わらない描き直しでは戻らない | 同上 | iOS 同上 (同じ配列の update・時間経過・VM の配列)。Android redrawWithSameArrayKeepsDroppedOrder | ✅ |
| 同 / 保存の失敗で元の並びに戻す | 同上 (違う配列が届いたら待つのをやめる) | iOS test保存に失敗して元の並びの配列が渡されると元の並びに戻る。Android saveFailureRestoresOriginalOrder | ✅ |
| グループをまたぐ移動 / 別のグループの途中へ置く | iOS `Ctl+R:57` (reorderPlacement)・`KsGroupChunkTable.swift`・`Ctl:1909` (確定位置を見せていた隙間へ揃える)。Android `Ctrl.kt:618` (placementAt)・`KsGroupPlan.kt` | iOS test別のグループの途中へ置くとそのグループの値で知らせる (D の前・Y)・test確定した位置が見せていた隙間とずれても見せていた位置で知らせて揃える (D の前・Y、セクション [B] [C A D E])。Android dropIntoMiddleOfOtherGroup。計算は両 Planner テストの「別のグループの途中へ置く」 | ✅ (iOS の確定位置のずれへの対処は deviation 記録済み: 組み替えで分かったこと (4)) |
| 同 / 見出しの上と下 | 同上。iOS は UIKit の隙間 (`shownGap`・`coordinator.destinationIndexPath`) から求める | iOS test見出しの上では直前の隙間の位置で知らせる (C の前・Y / 末尾・X)。Android aboveAndBelowGroupHeader・aboveAndBelowHeader | ⚠️ iOS は deviation 記録済み (境目は UIKit 標準の隙間が直前の位置を保つ。slow では指を止めた位置で決まる — 組み替えで分かったこと (3))。Android ✅ |
| 同 / 見出しの無いグループでも境目で分かれる | 同上 | iOS test見出しの無いグループでも隙間の位置のグループで知らせる (末尾・X)。Android boundaryWithoutHeaders (ライブラリ・Planner) | ⚠️ iOS は同じ deviation 記録済み。Android ✅ |
| 同 / 最後の 1 件をドラッグしても見出しは残る | iOS はドラッグの間セクションを変えない。Android `Ctrl.kt:121` (`keepsEmptyGroups = true`) | iOS test最後の1件をドラッグしている間も見出しは残り受け入れると消える (ドラッグ中はセクション [A] [B C])・testドラッグ中にもとのグループへ戻して置ける。Android lastItemDragKeepsHeaderAndCanReturn・emptyGroupKeptDuringDragAndRemovedOnAccept | ✅ |
| 同 / 受け入れると空のグループが消える | iOS `Ctl:1803` (movingItem で空のセクションを除いた snapshot を当てる)。Android `Ctrl.kt:218` (`keepsEmptyGroups = false`) | iOS 同上 (受け入れ後に X が消え、見出し 1 つ、VM の配列の後も Y だけ)。Android acceptingRemovesEmptyGroup | ✅ |
| 動かせるかと置けるかの判定 / 動かせない項目 | iOS `Ctl+R:106`。Android `Ctrl.kt:146` | iOS test動かせない項目は持ち上がらない (ほかの項目は持ち上がる)。Android immovableItemDoesNotLift | ✅ |
| 同 / グループをまたがせない | iOS `Ctl+R:153`〜`:167` (見える隙間の位置で判定し `.forbidden`)・`Ctl+R:229` (UIKit が並べ替えた後も判定し直し、置けなければ元の並びへ戻す)・`Ctl+R:308` (置く処理の経路でも判定し直す)・`KsReorderGapTracker.swift`。Android `Ctrl.kt:327` (retarget)・`:198` (置く直前に判定し直す) | iOS test置けない行き先では隙間を空けず離しても知らせない (UIKit が置けない位置へ並べ替えた場合も知らせず A B C D へ戻す)・test隙間が動く前に置けない位置で離すと知らせない・test判定には知らせと同じ形の行き先が渡る・`KsReorderGapTrackerTests` 5 件。Android canDropBlocksOtherGroup・canDropRecheckedOnRelease・releaseAtBottomEdgeWithCanDropPlaces | ✅ (iOS の隙間の予測を iOS 16・17 で確かめていない点は deviation 記録済み) |
| 端での自動スクロール / 画面の外の位置へ運ぶ | 下端: iOS は UIKit 標準 (`Ctl:518` の `reorderingCadence = .slow` で送りの間は隙間が動かない)、Android `Ctrl.kt:380`・`:413`。上端: iOS `KsReorderTopAutoScroll.swift`・`Ctl:1743` (startReorderAutoScroll) | Android autoScrollCarriesItemBeyondScreen (送り続ける・指を戻すと止まる・先で置ける・持ち上げが切れない)・releaseAtBottomEdgeDuringAutoScrollPlacesNearFinger。iOS 上端は `KsReorderEngineTests` の上端 7 件と `KsReorderTopAutoScrollTests` 14 件。iOS 下端は UIKit 標準のため自動テストは無く、証跡 `evidence/ios-precheck-uikit-drag-and-drop.md` の #6・`evidence/review-002-ios-bottom-autoscroll-release.png`・組み替えの後の `evidence/review-009-autoscroll-release-18.png` | ⚠️ iOS の上端は deviation 記録済み (バーの裏まで広げた一覧ではライブラリが上端を自前で送る)。iOS の隙間が指を止めるまで動かない点も deviation 記録済み (組み替え)。Android ✅ |
| 読み上げの移動操作 / 操作で 1 つ後ろへ動かす | iOS `Ctl+R:351` (updateReorderAccessibility)・`:381` (reorderAccessibilityPlacement)・`:410` (performReorderAccessibilityMove)・`KsReorderAccessibilityModel.swift`・`KsReorderAccessibilityModifier.swift`・`KsHostingCell.swift`。Android `Ctrl.kt:270`・`KsReorderAccessibility.kt:18`・`KsCollectionView.kt:735`・`:780` | iOS test操作で1つ後ろへ動かすと後ろの後ろの項目の前で知らせる (C の前・B A C)・test操作で受け入れなければ動かさない。部品の付け方は test並べ替えを付けていない一覧と文言を渡さない一覧の中身には読み上げの部品を付けない・test文言を後から渡すと表示中の項目に部品を付けて操作を出す・testスクロールで表示に入る項目は中身を作った後に操作を入れ替えない。Android accessibilityMoveNext・accessibilityMoveRejected。計算は両 Planner テスト | ✅ |
| 同 / グループの境目を越える操作 | `KsReorderPlanner.swift:57`・`KsReorderPlanner.kt:68` | iOS testグループの先頭の前へ移動は前のグループの末尾で知らせる (末尾・X)。Android accessibilityMoveAcrossGroups・accessibilityMovesAcrossGroupBoundary | ✅ |
| 同 / 操作を出さない場合 | iOS `Ctl+R:351`〜`:360`・`:381`〜`:404`。Android `KsCollectionView.kt:735` | iOS test操作はスイッチが無効の間と動かせない項目と端と置けない行き先には出ない・test文言を渡さなければ操作を出さない。Android accessibilityActionsAbsentWhenNotApplicable | ✅ |
| ドラッグ中に届いた配列 / 指を離すまで当たらない | iOS `Ctl:237` (ドラッグ中は控える)・`Ctl:1685` (endReorderDrag で当てる)。Android `Ctrl.kt:105` (shown) | iOS testドラッグ中の配列は指を離すまで当たらない。Android arrayDuringDragIsNotAppliedUntilRelease | ✅ (iOS の保留は指を動かし始めた時点から、受け入れないときは戻し終えるまで続く。deviation 記録済み: Decision 5 の行・組み替えで分かったこと (2)) |
| 同 / 受け入れたら控えた配列を捨てる | iOS `Ctl+R:236` (latestItems)・`Ctl:1803` | iOS test受け入れたら控えた配列を捨てて置いた並びのまま待つ。Android acceptingDiscardsHeldArray | ✅ |
| 同 / 受け入れなければ最新の配列へ戻る | iOS `Ctl:1844` (ドロップのセッションの終わりに元の並びへ) → `Ctl+R:263` (finishReorderResolution) → `Ctl:1685` (控えた配列を当てる) | iOS test受け入れなければ元の位置に戻してから最新の配列を当てる (セッションの終わりまで B A C、終わった後に A B C D)。Android rejectingAppliesLatestHeldArray | ✅ |
| 同 / ドラッグ中の項目が消えた配列を控えて受け入れない | 同上 | iOS testドラッグ中の項目が消えた配列を控えて受け入れなければ元に戻してから消える (A C B → A C)。Android rejectingWithHeldArrayWithoutDraggedItem | ✅ |
| ドラッグ中のページングとスクロール命令 / ドラッグ中は次のページを頼まない | iOS `Ctl:2155` (evaluatePaging の `!isReorderDragging`)・`Ctl:1685`。Android `KsCollectionView.kt:968` (pagingInput) | iOS testドラッグ中は次のページを頼まず終わった後に判定し直す・testドラッグの後に控えた配列を当てるとき直前のページングの状態で末尾に留める。Android noLoadMoreDuringDrag・heldAppendAtEndKeepsEnd | ✅ |
| 同 / ドラッグ中のスクロール命令は後で実行する | iOS `Ctl:2514` (receive の `!isReorderDragging`)・`Ctl:2429` (flushPendingCommands)。Android `KsCollectionView.kt:382` | iOS testドラッグ中のスクロール命令は配列を当てた後に実行する。Android scrollCommandDuringDragRunsAfterRelease | ✅ |

### collection-interaction (MODIFIED「アイテムタップ / ロングタップ」)

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| セル内ボタンとの競合 (既存) | 変更なし | iOS `KsCollectionEngineTests` testセル内の操作要素へのタッチではitemTapとfeedbackを発火しない。Android `KsCollectionViewInteractionTest` itemButtonConsumesTouchInsteadOfItemTap・itemButtonPressDoesNotStartItemFeedback | ✅ |
| タップで型付き要素が渡る (既存) | 変更なし | iOS test選択時に型付き項目を通知する。Android tapPassesTappedItemToCallback | ✅ |
| ロングタップ (既存。スイッチ無効を前提に追記) | iOS `Ctl:1650` (無効の間だけ認識器を有効)・`Ctl:522` (`installsStandardGestureForInteractiveMovement = false` で標準の対話的な移動の長押しを付けない)。Android `KsCollectionView.kt:430` | iOS test長押し成立後の別タッチによる通常タップを抑止しない。Android longTapPassesItemAndSuppressesTap。旧挙動 (並べ替えの有無に依らず長押しの知らせ) を前提にしたテストは残っていない | ✅ |
| 並べ替えが有効な間の長押し | 同上 | iOS test並べ替えが有効な間は長押しの知らせを呼ばない (動かせない項目を含む・動かせる項目は持ち上がる)。Android longTapNotCalledWhileReorderEnabled | ✅ |
| 並べ替えが有効な間のタップ | iOS `Ctl:1654` (handlesItemTouch)。Android `KsCollectionView.kt:429` | iOS test並べ替えが有効な間もタップの知らせは呼ぶ。Android tapWorksWhileReorderEnabled | ✅ |
| 長押しの知らせだけを宣言した一覧のタップ | 同上 | iOS test長押しの知らせだけを宣言した一覧は並べ替えが有効な間タップしても強調しない。Android longTapOnlyListHasNoTapFeedbackWhileReorderEnabled | ✅ |
| スイッチを無効に戻すと長押しが戻る | 同上 | iOS testスイッチを無効に戻すと長押しの知らせが戻る。Android disablingSwitchRestoresLongTap | ✅ |

### samples

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| デモ画面「並べ替え」 / 両プラットフォームで同じ構成 | `samples/ios/KsCollectionViewSamples/SampleScreen.swift`・`ReorderDemoView.swift`・`ReorderDemoModel.swift`。`samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/SampleScreen.kt`・`ReorderDemoScreen.kt`・`ReorderDemoModel.kt` (いずれも verify-001 の後に変更なし) | iOS `ReorderDemoUITests` testメニューでページングの次にある・test直接開くと初期の並びと切り替えが出る。Android `SampleScreenParityTest`・`ReorderDemoModelTest`・`ReorderDemoScreenTest` | ✅ |
| 同 / 項目を並べ替える | iOS `ReorderDemoModel.swift`。Android `ReorderDemoModel.kt` | iOS test項目を並べ替える (実際のドラッグ。2 3 1 4)。Android `ReorderDemoModelTest` Item 1 を Item 3 と Item 4 の間に置くと 2 3 1 4 の順になる (VM。ドラッグ自体はライブラリの `KsReorderDragTest`) | ✅ |
| 同 / 別のグループへ動かす | 同上 (グループの値を行き先に書き換える) | iOS test別のグループへ動かす (101 1 102、Item 1 がグループ 2 の見出しより下。slow の隙間に合わせて Item 102 の上で指を止める)。Android 別のグループの途中へ置くとグループの値を書き換えてその位置に入れる ほか | ✅ |
| 同 / 動かせない項目 | iOS `ReorderDemoView.swift` (`canMove`)。Android `ReorderDemoScreen.kt` (`canMove = isMovable`) | iOS test動かせない項目 (実際のドラッグ)。Android 初期の配列 (10 の倍数が動かせない・「(移動不可)」)。持ち上がらないことはライブラリの immovableItemDoesNotLift | ✅ |
| 並べ替えの実演の操作 / スイッチを切ると長押しの知らせになる | iOS `ReorderDemoView.swift`・`ReorderDemoModel.swift`。Android `ReorderDemoScreen.kt` | iOS testスイッチを切ると長押しの知らせになる。Android `ReorderDemoScreenTest` 並べ替えのスイッチを切って長押しすると 長押し Item 5 の帯が出て 3 秒で消える | ✅ |
| 同 / スイッチがオンの間は長押しの知らせが出ない | 同上 | iOS testスイッチがオンの間は長押しの知らせが出ない (ドラッグで置けることまで確認)。Android 並べ替えのスイッチがオンの間は長押ししても帯が出ない | ✅ |
| 同 / 受け入れないと元に戻る | iOS `ReorderDemoModel.swift`。Android `ReorderDemoModel.kt` | iOS test受け入れないと元に戻る (帯・1 2 3 4・3 秒で消える)。Android 置いても受け入れないがオンなら並べ替えず受け入れなかった帯を 3 秒出す (VM。戻る動きはライブラリの rejectedMoveReturnsToOriginal) | ✅ (iOS の戻り方はライブラリの行の deviation に従う) |
| 同 / グループをまたがせない | iOS `ReorderDemoModel.swift`。Android `ReorderDemoModel.kt` | iOS testグループをまたがせない (101 102 のまま、Item 1 がグループ 2 の見出しより上で運ぶ前の隣のまま)。Android グループをまたがせないがオンの間は元のグループへだけ置ける (VM。戻る動きはライブラリの canDropBlocksOtherGroup) | ✅ |
| 同 / グリッドとグループなしでも並べ替えられる | iOS `ReorderDemoView.swift`。Android `ReorderDemoScreen.kt` | iOS testグリッドとグループなしでも並べ替えられる (2 3 1 4、Item 1 と Item 4 が同じ行)。Android グループをオフにすると見出しが消え グリッドに切り替えても項目が並ぶ ほか (VM) | ✅ |

Requirement 本文のうち Scenario の無い条項 (操作のパネルが一覧の配置の入力を変えないこと・読み上げの文言「前へ移動」「後ろへ移動」を渡すこと・初期値) は、verify-001 で確かめた後に Sample の実装が変わっていない (両プラットフォームの `Reorder*` の最終更新は 2026-09-30 02:10 以前) ことを確かめ、同じ判定とした。

Side Effects の行: specs/ のどこにも契約の欄 (Requires / Side Effects) が無い旧形式の change のため、逆向きの検査は対象外。

## 追加検査

- [x] **tasks.md**: 31 タスクのうち 29 がチェック済み (`git diff HEAD` はチェックの付与 29 件だけ)。対応表と突き合わせて虚偽は無い。6.2 は `evidence/perf-ios-reorder.md`・`evidence/perf-android-reorder.md` (両方とも合格)。**6.3・6.4 は未チェック (未完了)**。6.3 は 1 回目の目視 (2026-09-30) で指摘 4 件が出て、iOS の組み替え・Android の影の修正を行った後の見直しが残っている。この verify の後に行う基準機の確認として扱う
- [x] **逆流検査**: `git diff HEAD` で proposal.md・design.md・specs/ に変更なし (最後の変更は提案作成のコミット c457a69)。作業ツリーで変わった足場外の成果物は tasks.md (チェックの付与のみ) と ui/brief.md (「照合結果」節の追加のみ)
- [x] **未記録乖離**: 0 件。⚠️ はすべて deviation.md の行に対応する (境目の置き先・取りやめの戻し方・Sample の VM の持ち方・iOS 16/17 で未確認の隙間の予測・iOS の保留の開始時点・上端の自動スクロール・reorder-capable な形への組み替え (受け入れないときの戻り方・隙間の速さ・置く絵の見た目)・バーの上でのプレビューの縮み・組み替えで分かったこと (1)〜(5))
- [x] **付随修正**: `samples/ios/KsCollectionViewSamples/SampleTheme.swift` は `[付随修正]` として記録済み。verify-001 の後の diff は、iOS の組み替え (`Ctl`・`Ctl+R`・`KsReorderDrag.swift`・`KsReorderSnapshotTiming.swift`・`KsReorderGapTracker.swift`・`KsReorderDragDropDelegate.swift`)、読み上げの部品 (`KsReorderAccessibilityModel.swift`・`KsReorderAccessibilityModifier.swift`・`KsHostingCell.swift`)、Android の影の層 (`KsReorderLift.kt`・`KsCollectionView.kt`) で、いずれも tasks 3.x・4.3 の範囲 (組み替えは deviation に記録済み、Android の影は 6.3 の指摘を 4.3 の持ち上げの描き方の中で直したもので spec の挙動は変えない)。`ios/Sources/KsCollectionView/KsDisplayLinkTarget.swift` は上端の自動スクロール (deviation 記録済み) の CADisplayLink の受け手。`evidence/header-glitch-*` の調査は別の change (`kasane/changes/sample-group-header-spacing-color/`・`kasane/changes/ios-hosting-content-reuse/` の簡易起票) に切り出されていて、この change の実装の差分は無い。`kasane/lessons/inbox/` の追加はハーネスの教訓の捕捉で、実装の差分ではない
- [x] **UI**: `ui/brief.md` に承認モック (案 B、2026-09-29 承認) と照合結果 (2026-09-30 最終承認)・合意済み妥協 2 件が記録されている。ダーク表示は照合していないと明記。② ドラッグ中の動きは 6.3 で確かめる扱い
- [x] **テスト**: 直近の全件の成功を材料にし、最後に変わった iOS の並べ替えのテスト 112 件を 2 つの OS (計 224 件)、iOS Sample の `ReorderDemoUITests` 10 件 (1 件は通知のバナーの割り込みで失敗し、同じ 1 件を 3 回流し直して 3 回とも成功)、影の修正の後の Android Sample の並べ替えのテスト 26 件を現時点の実装で流して成功を確かめた

## 所見 (❌ ではないが、6.3 の見直し・蒸留に申し送る点)

1. **iOS の受け入れないときの見え方**: spec の結果 (元の並び・配列は変わらない) は満たすが、「置いた位置に収まる → 約 0.7 秒止まる → 元の位置へ戻る」(合計約 1.3 秒) の形は deviation で「基準機の目視で確かめる」とされている。6.3 の見直しで判定する (`owner-visual-checkpoints.md` の該当行)
2. **iOS の自動スクロール中に指を止めずに離す**: `reorderingCadence = .slow` のため、送りの間に指を止めずに離すと送り始めの前の隙間 (画面の外) に置かれる (review-009 Suggestion 1)。Scenario「画面の外の位置へ運ぶ」は指を止めれば先で置けるので満たすが、UIKit 標準と同じ見え方でよいかは 6.3 の見直しの観点に入っている
3. **iOS の下端の自動スクロールの自動テストが無い** (verify-001 の所見 1 のまま): UIKit 標準に任せた部分で、証跡で担保している
4. **iOS の新しい経路の試験は合成による**: UIKit のドラッグ & ドロップはテストから合成できず、組み替えの後の「UIKit が並べ替えとして並びを動かしてから確定を知らせる」「ドロップのセッションの終わり」も偽物の呼び出し順で再現している。実機の呼び出し順と合っていることは review-009 の Simulator の観測 (`evidence/review-009-probe.log`) と iOS Sample の UI テスト (実際のドラッグ) が裏付けている
5. **6.2 の体感ゲートは組み替えの前の計測**: `evidence/perf-ios-reorder.md` (2026-09-30 21:23) は iOS の組み替え・読み上げの部品の付け方の最後の変更 (2026-10-01) より前。計測はドラッグをしないスクロールで、組み替えの変更の多くはドラッグの経路だが、読み上げの部品はセルの表示の経路に入る。測り直すかは呼び出し元の判断とする (spec の Scenario ではないため判定には含めない)
6. **review-011 の結果**: 並行する review-011 (置く絵の見た目・review-009 の指摘への対応の確認) で iOS の実装が変わった場合、「受け入れと元に戻す」「置いたときの知らせ」「グループをまたぐ移動」の iOS の行は変更後の実装で見直す必要がある (該当テスト: `KsReorderEngineTests` の置く・戻す・揃える・セッションの終わりの各件)
