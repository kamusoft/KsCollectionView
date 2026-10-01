# Verify 001: drag-reorder

- 検証日: 2026-09-30
- 対象: 作業ツリーの未コミットの変更 (`git diff HEAD` と未追跡のファイル。ios/・android/・samples/ 配下)
- デルタスペック: `specs/collection-reorder/spec.md` (ADDED 10 Requirement / 30 Scenario)、`specs/collection-interaction/spec.md` (MODIFIED 1 / 7)、`specs/samples/spec.md` (ADDED 2 / 9)。計 13 Requirement / 46 Scenario
- 合意済みの差分: `deviation.md` の乖離 6 行・付随修正 1 行、`ui/brief.md` の合意済み妥協 2 件

## 判定: VALID

全 46 Scenario が「✅ 一致」または「⚠️ deviation 記録済み」。未記録の欠落・乖離 (❌) は 0 件。虚偽のチェック・足場の逆流・テストの失敗は無い。

ただし tasks 6.2〜6.4 (基準機の体感ゲートとオーナーの目視) は未完了 (チェック無し)。依頼どおり「verify の後にオーナーと行う基準機の確認」として扱い、この判定には含めない。蒸留 (archive) の前に 6.2〜6.4 を終え、結果を evidence/ に残す必要がある (観点は `owner-visual-checkpoints.md`)。

## テストの実行

直近の全件の結果を材料として使った (依頼の記載): iOS ライブラリ 519 件・iOS Sample の UI テスト 44 件 (うち `ReorderDemoUITests` 10 件は最新の修正後にも成功)・Android ライブラリ 474 件・Android Sample 163 件がすべて成功、lint 違反 0 件。

加えて、最後に変更された iOS の上端の自動スクロールまわり (`ios/Sources/KsCollectionView/KsReorderTopAutoScroll.swift`・`KsCollectionViewController.swift`・`KsCollectionViewController+Reorder.swift`。いずれも 18:50〜18:54 更新) の現時点の実装で、並べ替えのテストだけを絞って流した。

- `xcodebuild test -scheme KsCollectionView` を `ksn-drag-reorder-impl` (iOS 26.5) で、`-only-testing` に `KsReorderEngineTests`・`KsReorderTopAutoScrollTests`・`KsReorderGapTrackerTests`・`KsReorderPlannerTests`・`KsPublicAPITests` を指定。Executed 102 tests, 0 failures (48・13・5・10・26 件)
- Android は直近の全件実行の後にライブラリ・Sample の変更が無い (本体の最終更新は `KsReorderController.kt` 12:49) ため再実行していない

並行して動いている review-005 (上端の自動スクロールの小さな修正の確認) は、この時点で `review-005.md` がまだ無い。Requirement「端での自動スクロール」は上の時点の実装で判定した。

## 対応表

略記: iOS のテストは `ios/Tests/KsCollectionViewTests/`、Android ライブラリのテストは `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/`、Android Sample のテストは `samples/android/app/src/test/kotlin/jp/kamusoft/kscollectionview/samples/android/` の下。実装の iOS は `ios/Sources/KsCollectionView/`、Android は `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/` の下。

### collection-reorder

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 並べ替えのスイッチ / 有効の間は長押しでドラッグが始まる | iOS `KsCollectionViewController.swift:1580` (syncReorderInteraction)・`KsCollectionViewController+Reorder.swift:92` (itemsForBeginning)。Android `KsReorderController.kt:133` (lift)・`KsReorderController.kt:793` (長押しの検出) | iOS `KsReorderEngineTests` testスイッチが有効なら長押しで持ち上がり無効なら持ち上がらない。Android `KsReorderDragTest` longPressStartsDragAndItemFollowsFinger | ✅ |
| 同 / 無効の間はドラッグが始まらない | 同上 (スイッチ無効・reorder 未設定で持ち上げない) | iOS 同上・test並べ替えを設定していない一覧は持ち上がらない。Android disabledSwitchDoesNotStartDrag (無効と未設定の 2 変種) | ✅ |
| 同 / ドラッグ中にスイッチが無効になる | iOS `KsCollectionViewController.swift:1633` (deferDuringReorderDrag)・`:1644` (cancelsReorderDrag)・`KsCollectionViewController+Reorder.swift:138` (取りやめ後は `.unspecified`)。Android `KsCollectionView.kt:282`・`KsReorderController.kt:229` (cancel) | iOS testドラッグ中にスイッチが無効になると取りやめて知らせない・test持ち上げた直後にスイッチが無効になると動かし始めた時点で取りやめる。Android disablingSwitchDuringDragCancels | ⚠️ iOS は deviation 記録済み (取りやめは指を離したときに元の位置へ戻す)。Android ✅ |
| 同 / ドラッグ中に layout が変わる | 同上 (layout 値・グループの宣言の比較) | iOS testドラッグ中にlayoutが変わると取りやめて終わった後に新しいlayoutで表示する・testドラッグ中にグループの宣言が変わると取りやめる・test持ち上げた直後にlayoutが変わると動かし始めた時点で取りやめる。Android changingLayoutDuringDragCancels・changingGroupsDuringDragCancels | ⚠️ iOS は同じ deviation 記録済み。Android ✅ |
| 同 / list とグリッドの両方で効く | 両プラットフォームとも layout に依らない同じ経路 | iOS testグリッドでも並べ替えられ置いたときに知らせる。Android gridReordersToo | ✅ |
| 置いたときの知らせ / 置いたときに 1 回だけ知らせる | iOS `KsCollectionViewController+Reorder.swift:191` (acceptDrop)・`:27` (reorderMove。配列の要素そのもの)・`KsReorderPlanner.swift:37`。Android `KsReorderController.kt:186` (drop)・`KsReorderPlanner.kt:51` | iOS test置いたときに1回だけ動かした項目と後ろの項目で知らせる (途中で知らせない・D の前・グループ nil)。Android dropNotifiesOnceWithDestination (要素の同一性まで確認)。行き先の計算は iOS `KsReorderPlannerTests` testCとDの間に置くとDの前になる / Android `KsReorderPlannerTest` placeBetweenCAndDIsBeforeD | ✅ |
| 同 / 最後に置いたら末尾 | 同上 | iOS test最後に置くと末尾で知らせる・`KsReorderPlannerTests` test最後に置くと末尾になる。Android dropAfterLastIsEnd・placeAfterLastIsEnd | ✅ |
| 同 / 元の位置に置いたら知らせない | iOS acceptDrop の `placement != originalPlacement`。Android `KsReorderController.kt:194` | iOS test元の位置に置くと知らせない。Android dropAtOriginalDoesNotNotify | ✅ |
| 並べ替えは一覧の中だけ / 別の一覧には置けない | iOS `KsCollectionViewController+Reorder.swift:84` (isOwnReorderSession)・`:123`・`KsReorderDragDropDelegate.swift:30` (アプリの外へ出さない)。Android `KsReorderController.kt:176` (一覧の外で離すと戻す) | iOS test別の一覧のセッションは受けずどちらの処理も呼ばれない・testドラッグの項目はアプリの外へ渡す中身を持たない。Android cannotDropIntoAnotherList | ✅ |
| 受け入れと元に戻す / 受け入れないと元に戻る | iOS `KsCollectionViewController+Reorder.swift:167`・`:222` (元の位置へ動かして戻す)。Android `KsReorderController.kt:207`・`:239` | iOS test受け入れないと置かずに元の並びのまま。Android rejectedMoveReturnsToOriginal | ✅ |
| 同 / 受け入れたら配列が届くまで置いた並びのまま | iOS `KsCollectionViewController.swift:1720` (applyAcceptedReorder)・`:233` (待つ)。Android `KsReorderController.kt:216` (awaiting)・`:105` (shown) | iOS test受け入れたら配列が届くまで置いた並びのままで同じ配列の描き直しでも戻らない。Android acceptedMoveKeepsDroppedOrderUntilArrayArrives | ✅ |
| 同 / 配列が変わらない描き直しでは戻らない | 同上 (同じ配列なら置いた並びのまま) | iOS 同上 (同じ配列の update・時間経過・VM の配列)。Android redrawWithSameArrayKeepsDroppedOrder | ✅ |
| 同 / 保存の失敗で元の並びに戻す | 同上 (違う配列が届いたら待つのをやめる) | iOS test保存に失敗して元の並びの配列が渡されると元の並びに戻る。Android saveFailureRestoresOriginalOrder | ✅ |
| グループをまたぐ移動 / 別のグループの途中へ置く | iOS `KsCollectionViewController+Reorder.swift:52` (reorderPlacement)・`KsGroupChunkTable.swift:109`。Android `KsReorderController.kt:618` (placementAt)・`KsGroupPlan.kt:217` | iOS test別のグループの途中へ置くとそのグループの値で知らせる。Android dropIntoMiddleOfOtherGroup。計算は両 Planner テストの「別のグループの途中へ置く」 | ✅ |
| 同 / 見出しの上と下 | 同上。iOS は UIKit の隙間 (`coordinator.destinationIndexPath`) から求める | iOS test見出しの上では直前の隙間の位置で知らせる。Android aboveAndBelowGroupHeader・aboveAndBelowHeader | ⚠️ iOS は deviation 記録済み (境目は UIKit 標準の隙間が直前の位置を保つ)。Android ✅ |
| 同 / 見出しの無いグループでも境目で分かれる | 同上 | iOS test見出しの無いグループでも隙間の位置のグループで知らせる。Android boundaryWithoutHeaders (ライブラリ・Planner) | ⚠️ iOS は同じ deviation 記録済み。Android ✅ |
| 同 / 最後の 1 件をドラッグしても見出しは残る | iOS はドラッグ中にセクションを変えない。Android `KsReorderController.kt:121` (`keepsEmptyGroups = true`) | iOS test最後の1件をドラッグしている間も見出しは残り受け入れると消える・testドラッグ中にもとのグループへ戻して置ける。Android lastItemDragKeepsHeaderAndCanReturn・emptyGroupKeptDuringDragAndRemovedOnAccept | ✅ |
| 同 / 受け入れると空のグループが消える | iOS `KsCollectionViewController.swift:1720` (movingItem で空のセクションを除く)。Android `KsReorderController.kt:218` (`keepsEmptyGroups = false`) | iOS 同上 (受け入れ後に X が消え、VM の配列の後も出ない)。Android acceptingRemovesEmptyGroup | ✅ |
| 動かせるかと置けるかの判定 / 動かせない項目 | iOS `KsCollectionViewController+Reorder.swift:101`。Android `KsReorderController.kt:146` | iOS test動かせない項目は持ち上がらない。Android immovableItemDoesNotLift | ✅ |
| 同 / グループをまたがせない | iOS `KsCollectionViewController+Reorder.swift:70`・`:156` (`.forbidden`)・`KsReorderGapTracker.swift`。Android `KsReorderController.kt:327` (retarget)・`:198` (置く直前に判定し直す) | iOS test置けない行き先では隙間を空けず離しても知らせない・test判定には知らせと同じ形の行き先が渡る・`KsReorderGapTrackerTests` 5 件。Android canDropBlocksOtherGroup・canDropRecheckedOnRelease・releaseAtBottomEdgeWithCanDropPlaces | ✅ (iOS の隙間の予測を iOS 16・17 で確かめていない点は deviation 記録済み) |
| 端での自動スクロール / 画面の外の位置へ運ぶ | 下端: iOS は UIKit 標準、Android `KsReorderController.kt:380`・`:413` (64dp・1200dp/秒)。上端: iOS `KsReorderTopAutoScroll.swift:75`・`KsCollectionViewController.swift:1698` | Android autoScrollCarriesItemBeyondScreen (送り続ける・指を戻すと止まる・先で置ける・持ち上げが切れない)・releaseAtBottomEdgeDuringAutoScrollPlacesNearFinger。iOS 上端は `KsReorderEngineTests` の上端 7 件と `KsReorderTopAutoScrollTests` 13 件。iOS 下端は UIKit 標準のため自動テストは無く、証跡 `evidence/ios-precheck-uikit-drag-and-drop.md` の #6 (下端で送り続け、戻すと止まり、置ける)・`evidence/review-002-ios-bottom-autoscroll-release.png` | ⚠️ iOS の上端は deviation 記録済み (バーの裏まで広げた一覧ではライブラリが上端を自前で送る)。iOS の下端・Android は ✅ |
| 読み上げの移動操作 / 操作で 1 つ後ろへ動かす | iOS `KsCollectionViewController+Reorder.swift:248`・`:307`・`KsHostingCell.swift` (reorderAccessibility)。Android `KsReorderController.kt:270`・`KsReorderAccessibility.kt:18` | iOS test操作で1つ後ろへ動かすと後ろの後ろの項目の前で知らせる・test操作で受け入れなければ動かさない。Android accessibilityMoveNext・accessibilityMoveRejected。計算は両 Planner テスト | ✅ |
| 同 / グループの境目を越える操作 | `KsReorderPlanner.swift:57`・`KsReorderPlanner.kt:68` | iOS testグループの先頭の前へ移動は前のグループの末尾で知らせる。Android accessibilityMoveAcrossGroups・accessibilityMovesAcrossGroupBoundary | ✅ |
| 同 / 操作を出さない場合 | iOS `KsCollectionViewController+Reorder.swift:278`。Android `KsCollectionView.kt:731` | iOS test操作はスイッチが無効の間と動かせない項目と端と置けない行き先には出ない・test文言を渡さなければ操作を出さない。Android accessibilityActionsAbsentWhenNotApplicable | ✅ |
| ドラッグ中に届いた配列 / 指を離すまで当たらない | iOS `KsCollectionViewController.swift:230`・`:1617` (endReorderDrag で当てる)。Android `KsReorderController.kt:105` (shown) | iOS testドラッグ中の配列は指を離すまで当たらない。Android arrayDuringDragIsNotAppliedUntilRelease | ✅ (iOS の保留は指を動かし始めた時点から。deviation 記録済み) |
| 同 / 受け入れたら控えた配列を捨てる | iOS acceptDrop の `latestItems`・applyAcceptedReorder。Android `KsReorderController.kt:216` | iOS test受け入れたら控えた配列を捨てて置いた並びのまま待つ。Android acceptingDiscardsHeldArray (30 フレーム戻らない) | ✅ |
| 同 / 受け入れなければ最新の配列へ戻る | iOS endReorderDrag。Android returnToOriginal の後に shown が届いた配列へ | iOS test受け入れなければ元の位置に戻してから最新の配列を当てる。Android rejectingAppliesLatestHeldArray | ✅ |
| 同 / ドラッグ中の項目が消えた配列を控えて受け入れない | 同上 | iOS testドラッグ中の項目が消えた配列を控えて受け入れなければ元に戻してから消える。Android rejectingWithHeldArrayWithoutDraggedItem | ✅ |
| ドラッグ中のページングとスクロール命令 / ドラッグ中は次のページを頼まない | iOS `KsCollectionViewController.swift:1988` (evaluatePaging)・`:1617`。Android `KsCollectionView.kt:966` (pagingInput) | iOS testドラッグ中は次のページを頼まず終わった後に判定し直す (末尾近くへはプログラムのスクロールで運ぶ)・testドラッグの後に控えた配列を当てるとき直前のページングの状態で末尾に留める。Android noLoadMoreDuringDrag (端での自動スクロールで運ぶ)・heldAppendAtEndKeepsEnd | ✅ |
| 同 / ドラッグ中のスクロール命令は後で実行する | iOS `KsCollectionViewController.swift:2261`・`receive` の `!isReorderDragging`。Android `KsCollectionView.kt:382` | iOS testドラッグ中のスクロール命令は配列を当てた後に実行する。Android scrollCommandDuringDragRunsAfterRelease | ✅ |

### collection-interaction (MODIFIED「アイテムタップ / ロングタップ」)

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| セル内ボタンとの競合 (既存) | 変更なし | iOS `KsCollectionEngineTests` testセル内の操作要素へのタッチではitemTapとfeedbackを発火しない。Android `KsCollectionViewInteractionTest` itemButtonConsumesTouchInsteadOfItemTap・itemButtonPressDoesNotStartItemFeedback | ✅ |
| タップで型付き要素が渡る (既存) | 変更なし | iOS test選択時に型付き項目を通知する。Android tapPassesTappedItemToCallback | ✅ |
| ロングタップ (既存。スイッチ無効を前提に追記) | iOS `KsCollectionViewController.swift:1585` (無効の間だけ認識器を有効)。Android `KsCollectionView.kt:430` | iOS test長押し成立後の別タッチによる通常タップを抑止しない。Android longTapPassesItemAndSuppressesTap。旧挙動 (並べ替えの有無に依らず長押しの知らせ) を前提にしたテストは残っていない | ✅ |
| 並べ替えが有効な間の長押し | 同上 (有効の間は長押しの知らせを外す) | iOS test並べ替えが有効な間は長押しの知らせを呼ばない (動かせない項目を含む・動かせる項目は持ち上がる)。Android longTapNotCalledWhileReorderEnabled | ✅ |
| 並べ替えが有効な間のタップ | iOS `KsCollectionViewController.swift:1589` (handlesItemTouch)。Android `KsCollectionView.kt:429` | iOS test並べ替えが有効な間もタップの知らせは呼ぶ。Android tapWorksWhileReorderEnabled | ✅ |
| 長押しの知らせだけを宣言した一覧のタップ | 同上 (有効の間は長押しの知らせをハンドラに数えない) | iOS test長押しの知らせだけを宣言した一覧は並べ替えが有効な間タップしても強調しない。Android longTapOnlyListHasNoTapFeedbackWhileReorderEnabled | ✅ |
| スイッチを無効に戻すと長押しが戻る | 同上 | iOS testスイッチを無効に戻すと長押しの知らせが戻る。Android disablingSwitchRestoresLongTap | ✅ |

### samples

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| デモ画面「並べ替え」 / 両プラットフォームで同じ構成 | `samples/ios/KsCollectionViewSamples/SampleScreen.swift:15`・`ReorderDemoView.swift`・`ReorderDemoModel.swift:49`。`samples/android/.../SampleScreen.kt:24`・`ReorderDemoScreen.kt:106`・`ReorderDemoModel.kt` | iOS `ReorderDemoUITests` testメニューでページングの次にある・test直接開くと初期の並びと切り替えが出る。Android `SampleScreenParityTest` デモ画面のタイトルと順序が iOS と一致する・並べ替えの文言が iOS と一致する、`ReorderDemoModelTest` 初期の配列は 10000 件を…、`ReorderDemoScreenTest` 開くとグループ 1 の見出しと… | ✅ |
| 同 / 項目を並べ替える | iOS `ReorderDemoModel.swift:54`・`:81`。Android `ReorderDemoModel.kt:76` | iOS test項目を並べ替える (実際のドラッグ)。Android `ReorderDemoModelTest` Item 1 を Item 3 と Item 4 の間に置くと 2 3 1 4 の順になる (VM。ドラッグ自体はライブラリの `KsReorderDragTest`) | ✅ |
| 同 / 別のグループへ動かす | 同上 (グループの値を行き先に書き換える) | iOS test別のグループへ動かす。Android 別のグループの途中へ置くとグループの値を書き換えてその位置に入れる・グループの末尾へ置くと…・グループがオフの間は行き先の隣の項目のグループの値に合わせる | ✅ |
| 同 / 動かせない項目 | iOS `ReorderDemoView.swift:80`。Android `ReorderDemoScreen.kt:121` (`canMove = isMovable`) | iOS test動かせない項目 (実際のドラッグ)。Android 初期の配列… (10 の倍数が動かせない・「(移動不可)」)。持ち上がらないことはライブラリの immovableItemDoesNotLift | ✅ |
| 並べ替えの実演の操作 / スイッチを切ると長押しの知らせになる | iOS `ReorderDemoView.swift:75`・`ReorderDemoModel.swift` didLongPress。Android `ReorderDemoScreen.kt:117` | iOS testスイッチを切ると長押しの知らせになる。Android `ReorderDemoScreenTest` 並べ替えのスイッチを切って長押しすると 長押し Item 5 の帯が出て 3 秒で消える・`ReorderDemoModelTest` 長押しで長押し Item N の帯を… | ✅ |
| 同 / スイッチがオンの間は長押しの知らせが出ない | 同上 | iOS testスイッチがオンの間は長押しの知らせが出ない (ドラッグで置けることまで確認)。Android 並べ替えのスイッチがオンの間は長押ししても帯が出ない | ✅ |
| 同 / 受け入れないと元に戻る | iOS `ReorderDemoModel.swift:55`。Android `ReorderDemoModel.kt:77` | iOS test受け入れないと元に戻る (帯の位置と 3 秒で消えることまで)。Android 置いても受け入れないがオンなら並べ替えず受け入れなかった帯を 3 秒出す (VM。戻る動きはライブラリの rejectedMoveReturnsToOriginal) | ✅ |
| 同 / グループをまたがせない | iOS `ReorderDemoModel.swift:64`。Android `ReorderDemoModel.kt:92` | iOS testグループをまたがせない。Android グループをまたがせないがオンの間は元のグループへだけ置ける (VM。戻る動きはライブラリの canDropBlocksOtherGroup) | ✅ |
| 同 / グリッドとグループなしでも並べ替えられる | iOS `ReorderDemoView.swift:96`。Android `ReorderDemoScreen.kt:111` | iOS testグリッドとグループなしでも並べ替えられる。Android グループをオフにすると見出しが消え グリッドに切り替えても項目が並ぶ・グループがオフの間は… (VM) | ✅ |

Requirement 本文のうち Scenario の無い条項も確かめた: 操作のパネルが一覧の配置の入力を変えないこと (iOS `ReorderDemoView.swift:62` の contentPadding は安全領域だけ、Android も同じ。承認 mock との照合 `ui/verification/`)、読み上げの文言「前へ移動」「後ろへ移動」を渡すこと (両 Sample の `.reorder` / `KsReorder` と `SampleScreenParityTest` 並べ替えの文言が iOS と一致する)、初期値 (並べ替え・グループがオン、ほか 2 つがオフ。両プラットフォームのテストあり)。

## 追加検査

- [x] **tasks.md**: 0.1〜6.1 はチェック済みで、対応表と突き合わせて虚偽は無い (0.1・0.2 は `evidence/ios-precheck-uikit-drag-and-drop.md`・`evidence/android-impl-drag-reorder.md`、1.3 は両公開 API テストに並べ替えの型と引数が追加済み、2.2・3.7・4.7・5.5・5.6 は上の表のテストが存在、6.1 は `ui/verification/` と `ui/brief.md` の照合結果)。6.2〜6.4 は未チェック (未完了) で、verify の後に行う基準機の確認として扱う
- [x] **逆流検査**: `git diff HEAD` で proposal.md・design.md・specs/ に変更なし (最後の変更は提案作成のコミット c457a69)。作業ツリーで変わった足場外の成果物は tasks.md (チェックの付与のみ) と ui/brief.md (「照合結果」節の追加のみ)
- [x] **未記録乖離**: 0 件。⚠️ はすべて deviation.md の行に対応する (境目の置き先・取りやめの戻し方・上端の自動スクロール・iOS の保留の開始時点・iOS 16/17 で未確認の隙間の予測)
- [x] **付随修正**: `samples/ios/KsCollectionViewSamples/SampleTheme.swift` の変更は `[付随修正]` として記録済み。ほかの diff (「ページング」のパネルの部品の共通化と改名・`PagingMessageMetrics` の切り出し・`GroupHeaderMetrics` のコメント・`KsCompositionalLayout.swift` の戻る間の隠しと隙間の通知・`KsGroupChunkTable.swift`・`KsHostingCell.swift`・`KsGroupPlan.kt`) はすべて tasks 3.x・4.x・5.1 の範囲。`kasane/lessons/inbox/` の 3 件はハーネスの教訓の捕捉で、実装の差分ではない
- [x] **UI**: `ui/brief.md` に承認モック (案 B、2026-09-29 承認) と照合結果 (2026-09-30 最終承認)・合意済み妥協 2 件が記録されている。ダーク表示は照合していないと明記
- [x] **テスト**: 直近の全件の成功を材料にし、最後に変わった iOS の並べ替えのテスト 102 件を現時点の実装で流して全件成功を確かめた

## 所見 (❌ ではないが、蒸留・6.3 に申し送る点)

1. iOS の下端の自動スクロール (Scenario「画面の外の位置へ運ぶ」) は UIKit 標準に任せた部分で、自動テストは無く証跡 (#6) で担保している。tasks 3.7 の対象にも含まれていない。6.3 の目視で上端 (自前) とそろって感じられるかと合わせて確かめる
2. Android Sample の「項目を並べ替える」「別のグループへ動かす」「受け入れないと元に戻る」「グループをまたがせない」「グリッドとグループなし」は、Sample の画面で実際にドラッグするテストではなく、VM のテストとライブラリのドラッグのテストの組で担保している (tasks 5.5 の範囲どおり)。画面での実際のドラッグは 6.3 の基準機の目視で見る
3. iOS の「ドラッグ中は次のページを頼まない」のテストは、末尾の近くへ運ぶのを端での自動スクロールではなくプログラムのスクロールで代えている (UIKit のドラッグ & ドロップは合成できないため)。Android は自動スクロールで運んでいる
4. review-005 (上端の自動スクロールの修正の確認) はこの検証の時点で未完了。その結果で `KsReorderTopAutoScroll.swift` 周辺が変わった場合、Requirement「端での自動スクロール」の iOS の行は変更後の実装で見直す必要がある (該当テスト `KsReorderTopAutoScrollTests`・`KsReorderEngineTests` の上端 7 件)
