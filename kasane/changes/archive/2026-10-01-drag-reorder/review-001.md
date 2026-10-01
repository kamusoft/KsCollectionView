# レビュー結果: drag-reorder (001 回目)

**日付**: 2026-09-30
**判定**: CHANGES_REQUESTED

## サマリー

両プラットフォームの公開 API・行き先の求め方・配列の保留・ページングとスクロール命令の停止・取りやめ・読み上げの操作は、デルタスペックと design の Decision に沿って組まれている。Scenario に対応するテストも揃っていて、全件成功した (iOS ライブラリ 496 件・iOS Sample UI 44 件・Android ライブラリ 470 件・Android Sample 163 件)。ただし、Android でエミュレータを使って動きの過程を見たところ ([L-002])、端での自動スクロール中に下端で指を離すと、項目が指の下ではなく別のグループ (一覧の最後のグループの末尾) へ置かれる不具合を 8 回中 3 回再現した。置いたときの処理にこの誤った行き先が渡り、VM のデータが書き換わる。この不具合があるため CHANGES_REQUESTED とする。

## 照合した規約

- ソースコメント規約 (always)。`scripts/comment-policy-lint.py --advisory` を実行し、禁止 0 件。要確認 10 件はすべてこの change の外のファイル。新しい公開 doc コメント (Swift の `KsCollectionView+Reorder.swift`・`KsReorderMove.swift`・`KsReorderDestination.swift`・`KsReorderAccessibilityActions.swift`、Kotlin の `KsReorder.kt`・`KsReorderMove.kt`・`KsReorderDestination.kt`・`KsReorderAccessibilityActions.kt`) に内部用語・ADR ID は無い
- テスト実行規約 (テストの実行・結果の報告): 実行件数の確認、Android の `--rerun-tasks`、収束を待つアサーション
- 実行時挙動の検証規約 (実行時挙動の確認): 目視の観測点を先に書き出し、実環境で動きの過程を確かめた
- Sample のプラットフォーム間一致 (`samples/**`): メニューの位置、文言の完全一致 (`ReorderDemoText` を両方で突き合わせた)、構成とデモデータ
- Sample の操作は本体の表示を変えない (`samples/**`): パネル・帯と一覧の `contentPadding` の関係
- スクロール性能の体感ゲート / iOS・Android の性能検証の手順: tasks 6.2 が未実施 (未チェック) のため、照合の対象外

lessons/code-review.md の重点観点:
- [L-001] 実装者の証跡にある数値 (隙間の予測が実際の隙間と一致した回数) は、記録を再生する単体テスト `KsReorderGapTrackerTests` がこの回の実行で成功したことで、今のコードでも成り立つことを確かめた。Android の粗い刻みの A/B は `KsReorderDragTest.coarseMoveKeepsGapUnderLiftedItem` が成功した
- [L-002] 動きの過程を、録画から抜いたコマ (0.04〜0.25 秒間隔) で見た。先に書き出した期待値: 持ち上げた項目は指に付いて動き、ほかの項目の上に描かれる / 隙間はいつも持ち上げた項目の近くにある / 入れ替わりはアニメーションでつながる / 自動スクロールの間も置き場所は指の近くにあり、見出しの件数は動かしていない項目のグループで変わらない / 受け入れないときは、持ち上げた項目が元の位置へ動いて戻る (Android の実装と iOS の UIKit 標準の取り消しと同じ見え方) / グループをまたぐと見出しの件数がそれに合わせて変わる

## 実行時の確認の記録

- テストの実行 (すべて絞り込みなし)
  - iOS ライブラリ: `xcodebuild test -scheme KsCollectionView` を `ksn-drag-reorder-review` (iPhone 17 / iOS 26.5) で実行。Executed 496 tests, 0 failures (`KsReorderEngineTests` 38・`KsReorderPlannerTests` 10・`KsReorderGapTrackerTests` 5 を含む)
  - iOS Sample: `-scheme KsCollectionViewSamples` で実行。Executed 44 tests, 0 failures (`ReorderDemoUITests` 10 件を含む)
  - Android ライブラリ: `:kscollectionview:testDebugUnitTest --rerun-tasks` で 470 件、失敗 0。XML をクラス別に集計し、`KsReorderDragTest` 26・`KsReorderHoldTest` 14・`KsReorderPlannerTest` 10・`KsCollectionViewPublicApiTest` 20 がそろっていることを確かめた
  - Android Sample: `:app:testDebugUnitTest --rerun-tasks` で 163 件、失敗 0 (`ReorderDemoModelTest` 10・`ReorderDemoScreenTest` 6・`SampleScreenParityTest` 10 を含む)
- Android の動き: レビュー用の AVD `ksn_drag_reorder_review_api36` (Pixel 7 / API 36) を port 5570 で起動した。操作の前に `adb -s emulator-5570 emu avd name` で `ksn_drag_reorder_review_api36` と出ることを確かめた。Sample「並べ替え」(開始ルート `demo/Reorder`) を開き、`input motionevent` で長押しからのドラッグを送りながら `screenrecord` で録画し、コマを抜いて見た。確かめた過程は、持ち上げ・入れ替わり、受け入れないときの戻り、端での自動スクロール (長く運ぶ)、グループをまたぐ移動。終わった後にエミュレータを止めた
- iOS の動き: シミュレータに直接タッチを送る手段は、許可の応答が得られず使えなかった。代わりに Sample の UI テスト (`test項目を並べ替える`・`test受け入れないと元に戻る`・`testグリッドとグループなしでも並べ替えられる`) を `ksn-drag-reorder-review` で動かし、実際のドラッグを `simctl io recordVideo` で録画してコマを抜いた。確かめた過程は、持ち上げ・隙間・入れ替わり (list・2 列グリッド) と、受け入れないときの戻り。**iOS の端での自動スクロール・グループをまたぐ移動・取りやめの過程は、このレビューでは見ていない** (実装者の証跡 `evidence/ios-precheck-uikit-drag-and-drop.md` の静止画だけ)。終わった後にシミュレータを止めた
- 録画はスクラッチに置き、コマを抜いた後に削除した。evidence/ には静止画だけを置いた。Android の画像に写るのはエミュレータのステータスバー (時刻と通信の印) と Sample のデモデータで、個人を特定する要素が無いことを開いて確かめた

## 指摘事項

### 🔴 Critical Android: 自動スクロール中に下端で指を離すと、項目が一覧の最後のグループの末尾へ置かれる (置けるかの判定があると元の位置へ戻る)

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsReorderController.kt:722` (`listPlacementAt` の最後の `return`)。関連: `KsReorderController.kt:321` (`retarget`)、`KsReorderController.kt:186` (`drop`)

**問題点**:
- list の行き先を求める `listPlacementAt` は、表示中の項目を上から見ていき、持ち上げた項目の上端より下に中心がある最初の項目の前を行き先にする。そういう項目が見つからないときは `KsReorderPlacement(planner.groupCount - 1, End)`、つまり**配列全体の最後のグループの末尾**を返す。持ち上げた項目の置き場所 (`slotLazy`) は数えずに飛ばす。このため、自動スクロールで置き場所が表示範囲のいちばん下まで来ると、その下に数える項目が無くなってこの行を通る。10,000 件の Sample では、グループ 1 の項目がグループ 100 の末尾へ飛ぶ
- 動きの過程 (`evidence/review-001-android-autoscroll-header-count-flicker.png`): Item 2 をグループ 1 の中で下端まで運び、自動スクロールさせている間、固定中の「グループ 1」の見出しの件数が 100 件 → 99 件 → 100 件と揺れる。99 件のコマでは置き場所の隙間が消え、並びが一瞬ずれる。項目はグループ 1 の中にあるのに、行き先がほかのグループへ移ったり戻ったりしている
- 離した結果 (グループ 1 の Item 2 を下端まで運び、0.2〜0.9 秒おいて下端のまま離す操作を 8 回): **3 回で「グループ 1」が 99 件になり、項目は指の下に残らなかった** (`evidence/review-001-android-autoscroll-release-left-group.png`。左は正しく置けた回、右は抜けた回)。Sample の VM は知らせのとおりにグループの値を書き換えるので、利用者のデータとしては、項目が遠いグループの末尾へ移ったことになる。`drop()` は、指を離す直前の `moveTo` の中の `retarget` で求めた行き先をそのまま使う
- 「グループをまたがせない」(`canDrop`) をオンにすると、同じ行き先が判定で断られ、`isOverForbidden` が立ったまま離されることがある。このときは、グループ 1 の中の置ける位置の上で離したのに、項目が元の位置 (画面の外の Item 1 の次) へ戻り、置いたときの処理が呼ばれなかった (6 回中 1 回。`evidence/review-001-android-autoscroll-release-returned.png`: 左が離した直後、右が先頭へ戻して見た並び)
- Requirement「置いたときの知らせ」(置いた位置から行き先を求める) と「端での自動スクロール」(スクロールで見えた位置に置ける) に反する。ドラッグの途中に `canDrop` が、関係のない行き先 (最後のグループの末尾) で呼ばれる点も、判定の契約 (ドラッグ中の行き先の候補ごとに呼ぶ) からずれている
- 自動テスト `KsReorderDragTest.autoScrollCarriesItemBeyondScreen` は、運ぶ間は `canDrop = { false }` で置き場所を元の位置に留め、離すのも中ほどに戻してからなので、この経路 (置ける状態で下端にいる間の行き先、下端で離す) を通らない

**推奨修正**:
- 持ち上げた項目の上端より下に中心がある項目が表示範囲に無いときは、配列全体の末尾ではなく、**表示範囲のいちばん下の項目 (置き場所を除く) の後ろ**を行き先にする。つまり、その項目が属するグループの中での次の位置にする。見出し・ルートのフッターの扱いは今の規則に合わせる。上端の側 (上へ運ぶ自動スクロール) も、同じように表示範囲の外へ飛ぶ経路が無いかを確かめる。グリッドの `placementAt` の最後の `return` (`KsReorderController.kt:663`) も、ルートのフッター以外で通らないかを確かめる
- 回帰テストを足す: 置ける状態 (`canDrop` なし・グループあり) で先頭付近の項目を下端まで運び、自動スクロールさせたまま下端で離す。行き先が離した位置の近くの項目 (元と同じグループ) になり、ドラッグ中に `canDrop` が最後のグループの行き先で呼ばれないことを確かめる。`canDrop` ありの版も足す (下端で離しても元の位置に戻らず、置いたときの処理が呼ばれる)
- 直した後は、エミュレータで同じ操作 (下端で離す・見出しの件数の揺れ) を繰り返し、A/B で解消を確かめる (実行時挙動の検証規約)

### 🟡 Minor iOS: 受け入れないときに、持ち上げた項目が元の位置へ戻らず、置いた場所で縮んで消える

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:185` (`guard reorder.onMove(move) else { return }`)。元の位置に置いたときの `return` (同じ関数の前の guard) も同じ経路

**問題点**: `performDropWith` で置かずに返すと、UIKit は既定の置き方にする。持ち上げていたプレビューは置いた場所で縮みながら消え (`UIDropInteraction.h`: previewForDroppingItem が nil のときは「fade and shrink the drag item in place」)、一覧の中の項目は元の位置にすぐ現れる。録画のコマでも、離した次のコマで Item 1 が先頭に戻り、その間 Item 3 の行の上で縮むプレビューが約 0.4 秒残って、「Item 1」が 2 つ同時に見えた (`evidence/review-001-ios-rejected-drop-preview-shrinks-in-place.png`)。Android は、持ち上げた項目が元の位置へ動いて戻る。design Decision 3 と brief は「UIKit が元の位置へ戻す」「受け入れないときに元の位置へ戻る動き」を前提にしているが、実際の見え方はその前提と違う。core/ADR-0027 (proposed) の「すぐアニメーションで元の位置に戻し」とも合わない。ADR が proposed なので、判定の根拠にはせず所見として書く。受け入れないことはデモの操作の 1 つなので、6.3 の目視の前に見え方を決めておくのがよい

**推奨修正**: 受け入れなかったとき (と元の位置に置いたとき) は、`coordinator.drop(dragItem, to: UIDragPreviewTarget(container: collectionView, center: <元のセルの中心>))` か、元の位置の項目を指す `drop(_:toItemAt:)` でプレビューを元の位置へ動かす。UIKit の取り消しの見え方にそろえ、Android と並べてもそろうようにする。どちらにするかを決めきれない場合は、6.3 のオーナーの目視で今の見え方でよいかを判断してもらい、その結果を記録する

### 🟡 Minor iOS: 置けるかの判定に使う隙間の予測 (`KsReorderGapTracker`) が、観測から組んだ規則で、iOS 16・17 では確かめていない

**該当箇所**: `ios/Sources/KsCollectionView/KsReorderGapTracker.swift:5`〜`:29` (規則の説明)、`ios/Package.swift:8` (`.iOS(.v16)`)

**問題点**: UIKit がドラッグ中に隙間を次にどこへ動かすかは公開の契約に無い。このため、`canDrop` の判定は、iOS 18.6・26.5 のシミュレータで観測した規則による予測で行っている。証跡 (`evidence/ios-precheck-uikit-drag-and-drop.md` の「再確認」) にも、iOS 16・17 は未確認とある。予測が外れても、`performDrop` で判定し直すので置いたときの処理は誤った行き先では呼ばれない。一方で、Requirement「動かせるかと置けるかの判定」の「偽の行き先には項目が入らない」は、見えている隙間が置けない位置に一度空く形で破れうる (途中の版の 18.6 で実際に起きた、と証跡に記録がある)。配布先の下限 (iOS 16) の範囲に、確かめていない版が残っている

**推奨修正**: iOS 16 / 17 のランタイムで、記録の再生 (`KsReorderGapTrackerTests` と同じ操作の列) を 1 回ずつ確かめる。ランタイムを用意できない場合は、確かめていない範囲として deviation.md に記録し、蒸留時に ios/ADR-0011 の確かめた範囲へ書き残す。規則が外れたときの見え方 (置けない位置に一時的に隙間が空く) も併せて書く

### 🟡 Minor iOS Sample の UI テストが、ドラッグの後を固定の時間で待っている

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/ReorderDemoUITests.swift:300`

**問題点**: `drag(_:to:)` は、離した後に `Thread.sleep(forTimeInterval: 0.8)` で動きが収まるのを待ち、その直後の `assertOrder` が各要素の `frame` を 1 回だけ読んで並びを判定する。テスト実行規約の「収束を待つアサーション」(完了条件を deadline つきで観測する) に反する。実行機が混んでいるときだけ、戻る・置く動きの途中の位置を読んで落ちる形になる

**推奨修正**: 固定の待ちをやめ、`assertOrder` の中で「並びが期待どおりで、各要素の `frame` が 2 回続けて同じ」になるまでを実時間の deadline つきで待つ。deadline を越えたら、そのときの並びをメッセージに入れて失敗させる

### 🔵 Suggestion iOS Sample の UI テストのうち 2 件が、それぞれ約 170 秒かかる

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/ReorderDemoUITests.swift:350` (`bringItemOneAboveGroupTwo`)

**問題点**: `test別のグループへ動かす` (168 秒) と `testグループをまたがせない` (172 秒) は、Item 1 をグループ 2 の見出しの手前まで、短いドラッグを何十回も繰り返して運ぶ。この 2 件で Sample の通常スキームの実行時間の約 2 割を占める

**推奨修正**: グループの件数を小さくする起動引数 (実装者の一時ハーネスの `--gs 5` と同じ考え方) を Sample の UI テスト用に足し、数回のドラッグでグループの境目に届くようにする。画面の文言と構成は既定の起動で変えない。起動引数は、画面を直接開く `--screen` と同じ扱いにする

## 確認した観点 (問題なし)

- 足場: proposal / design / specs は変更されていない。tasks.md はチェックの変更だけで、6.2〜6.4 (体感ゲートとオーナーの目視) は未チェックのまま (正直な状態)。brief.md は照合結果の追記だけ
- deviation.md の 3 件の乖離 (iOS の境目の置き方、iOS の取りやめの形、iOS Sample の VM を `ObservableObject` にする) は、合意済みの差分として扱った。付随修正 1 件 (`SampleTheme.swift` の `adaptive` を nonisolated にする) は、1 ファイル・Sample の範囲・公開 API に触れないので同梱の条件に収まる。直した後に iOS Sample の UI テストが全件成功した
- 公開 API: design Decision 1 の形 (Swift の `.reorder(isEnabled:canMove:canDrop:accessibilityActions:onMove:)`、Kotlin の `KsReorder`・`reorder` 引数は `onRefresh` の後ろ・`KsReorderDestination.End` は data object・ほかは普通の class) のとおり。公開 API のテストが両プラットフォームにある
- スイッチと長押し: iOS は `syncReorderInteraction` で `dragInteractionEnabled` と長押しの認識器を切り替え、`handlesItemTouch` で強調を決める。Android は `itemLongTap` と `hasTapHandler` で決める。collection-interaction の MODIFIED の各 Scenario に対応するテストがある
- 配列の保留と受け入れ後の待ち: iOS の `update` の手前の `deferDuringReorderDrag`・`reorderAwaitedItems`、Android の `shown` の `awaiting`。同じ配列での描き直しで戻らないこと、違う配列が届いたら従うこと、受け入れなかったら戻した後に最新を当てること。いずれも両プラットフォームのテストで押さえてある
- ページングとスクロール命令: iOS は `evaluatePaging`・`flushPendingCommands`・`receive` の各 guard、Android は `pagingInput` の `isReorderHolding` と命令の消費側の `isHolding`。ドラッグの終わりに判定し直し、溜めた命令を実行する
- Android の持ち上げた項目の pin (`LocalPinnableContainer`) で、置き場所が表示範囲の外へ出ても指の下に描かれ続ける (録画でも確かめた)
- 動きの過程 (Android): 持ち上げ (影つき)、入れ替わりのアニメーション、受け入れないときの元の位置への戻り (約 0.3 秒)、グループをまたぐときの見出しの件数の追従 (99 件 / 101 件) は期待どおりだった。問題は上の Critical の 1 件だけ
- 動きの過程 (iOS): list と 2 列グリッドの持ち上げ・隙間・入れ替わりは UIKit 標準の見え方だった。問題は上の Minor (受け入れないときの戻り) の 1 件
- Sample の一致: メニューの位置 (「ページング」の次)、`ReorderDemoText` の文言 (両方で突き合わせて一致)、10,000 件・100 件ずつ・10 の倍数は動かせない、VM の並べ替えの規則 (グループなしのときは隣の項目のグループの値に合わせる)。パネルと帯は一覧の `contentPadding` を変えない (安全領域の分だけ)
- 並行・資源: iOS の delegate の受け手 (`KsReorderDragDropDelegate.owner`) は weak、別の一覧のセッションは `localContext` の同一性で断る。Android のドラッグは `awaitEachGesture` の `finally` で取りやめる。自動スクロールの Job は、置いたとき・取りやめたときに取り消す

## アクションプラン

1. 🔴 Android の `listPlacementAt` の行き先を直す。表示範囲の下に項目が無いときに、一覧の最後のグループの末尾へ飛ばさない。下端で離す操作の回帰テスト (判定の有無の 2 版) を足し、エミュレータで同じ操作を繰り返して A/B で解消を確かめる
2. 🟡 iOS の受け入れないとき (と元の位置に置いたとき) のプレビューを、元の位置へ動かして戻す。今の見え方を残す場合は、6.3 のオーナーの目視で判断してもらう
3. 🟡 iOS 16 / 17 での隙間の予測を確かめる。確かめられなければ、確かめていない範囲を記録する
4. 🟡 iOS Sample の UI テストの固定の待ちを、条件を観測する待ちに置き換える
5. 🔵 (任意) UI テストのグループの件数を小さくする起動引数で、長い 2 件の実行時間を縮める
6. 残っている tasks 6.2〜6.4 (両プラットフォームの体感ゲート、オーナーの目視、iOS の置いた直後から確定の配列へ移るときの見た目) は、1 の修正の後に行う。iOS の端での自動スクロール・グループをまたぐ移動・取りやめの過程は、このレビューでは見ていないので、6.3 の目視に含めて確かめる
