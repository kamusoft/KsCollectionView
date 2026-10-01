# レビュー結果: drag-reorder (002 回目)

**日付**: 2026-09-30
**判定**: NEEDS_DISCUSSION

## サマリー

前回 (review-001・相方の second-opinion-code-001) の指摘は、すべて解消または合意どおりに記録されていた。Android の「自動スクロール中に下端で離すと最後のグループの末尾へ飛ぶ」は、エミュレータで同じ操作を 8 回 (判定なし) と 4 回 (グループをまたがせない) 繰り返し、1 回も起きなかった。置く直前の判定・iOS の受け入れないときの戻り・UI テストの待ち方も直っている。テストは 4 系統とも絞り込みなしで全件成功した。

一方、前回見ていなかった iOS の動きの過程を見たところ、**全画面に広げた一覧 (Sample「並べ替え」) では、上端での自動スクロールが起きない**。指をナビゲーションバーの上に置くとドロップ先が一覧でなくなり、バーのすぐ下 (上端から 118・124・130pt) に 3 秒止めても一覧は動かなかった。Requirement「端での自動スクロール」(上端か下端の近くでその向きにスクロールを続ける SHALL) を上端で満たさない。直すには、design Decision 3 の「自動スクロールは UIKit 標準のまま」と、core/ADR-0017 の安全領域の使い方のどちらかに手を入れる必要がある。受け入れて記録する選択もあり、どれを採るかは設計の判断になるため NEEDS_DISCUSSION とする。

## 照合した規約

- ソースコメント規約 (always)。`scripts/comment-policy-lint.py --advisory` の結果は、禁止 0 件・要確認 10 件。要確認は review-001 と同じもので、この change で足した並べ替えの行には無い
- テスト実行規約 (テストの実行・結果の報告)。4 系統とも絞り込みなしで実行し、件数をクラス別に確かめた。Android は `--rerun-tasks` を付けた。iOS Sample の UI テストの待ち方は「収束を待つアサーション」の 3 条件で照合した
- 実行時挙動の検証規約 (不具合修正の完了判定)。review-001 の Critical を、同じ手順の繰り返しで解消を確かめた。観測点は先に書き出した (下の [L-002])
- Sample のプラットフォーム間一致・Sample の操作は本体の表示を変えない (`samples/**`)。review-001 の後に Sample で変わったのは iOS の UI テストだけ (`ReorderDemoUITests.swift`) で、画面・文言・パネルに差分は無い。review-001 の照合結果を引き継ぐ
- スクロール性能の体感ゲート / iOS・Android の性能検証の手順: tasks 6.2 が未実施 (未チェック) のため対象外

lessons/code-review.md の重点観点:

- [L-001] 実装者の証跡の数値 (`evidence/android-impl-drag-reorder.md`: 直した後は 8 回とも 100 件のまま、グループをまたがせないでも 4 回とも置かれる) を、自前の操作で再現した。同じ手順 (Item 2 を長押し → 下端の自動スクロールの範囲へ → 0.2〜0.9 秒止めて下端のまま離す) で、8 回とも「グループ 1」は 100 件のまま、Item 2 は離した位置の近くに置かれた。グループをまたがせないでも 4 回とも置かれた。数値は一致する
- [L-002] 先に書き出した期待値: 持ち上げた項目は指に付いたまま、隙間は持ち上げた項目の近くにある / 自動スクロールの間も見出しの件数は、置き場所がグループをまたぐまで変わらない / 置き場所が別のグループへ移るのは、指の下が次のグループに入ったとき 1 回だけ (行き来しない) / 下端のまま離すと指の近くに置かれる / 受け入れないとき・取りやめたときは、持ち上げた項目が元の位置へ動いて戻る (見え方は両プラットフォームで同じ) / 上端でも下端と同じように自動スクロールする。録画から 0.05〜0.5 秒間隔でコマを抜いて見た

## 実行時の確認の記録

- テストの実行 (すべて絞り込みなし)
  - iOS ライブラリ: `xcodebuild test -scheme KsCollectionView` を `ksn-drag-reorder-review` (iPhone 17 / iOS 26.5) で実行。Executed 496 tests, 0 failures (`KsReorderEngineTests` 38・`KsReorderGapTrackerTests` 5・`KsReorderPlannerTests` 10 を含む)。ログに出る UIKit の「Observation tracking feedback loop detected」は、ページング・グループの既存のテストクラスだけに出ていて、並べ替えのテストには出ていない
  - iOS Sample: `-scheme KsCollectionViewSamples` を同じシミュレータで実行。Executed 44 tests, 0 failures (`ReorderDemoUITests` 10 件を含む。計測ドライバは含まない)
  - Android ライブラリ: `:kscollectionview:testDebugUnitTest --rerun-tasks` で 473 件・失敗 0。XML をクラス別に集計し、`KsReorderDragTest` 29 (review-001 から 3 件増: 下端で離す 2 件・置く直前の判定 1 件)・`KsReorderHoldTest` 14・`KsReorderPlannerTest` 10・`KsCollectionViewPublicApiTest` 20 がそろっていることを確かめた
  - Android Sample: `:app:testDebugUnitTest --rerun-tasks` で 163 件・失敗 0 (`ReorderDemoModelTest` 10・`ReorderDemoScreenTest` 6・`SampleScreenParityTest` 10 を含む)
- Android の動き: レビュー用の AVD `ksn_drag_reorder_review_api36` (Pixel 7 / API 36) を port 5590 で起動した。操作の前ごとに `adb -s emulator-5590 emu avd name` で `ksn_drag_reorder_review_api36` と出ることを確かめた (手順のスクリプトの先頭で毎回照合)。今の作業ツリーから組んだ Sample の APK (Gradle の up-to-date で本体の最新の変更より新しいことを確かめた) を入れ、開始ルート `demo/Reorder` で開いた。`input motionevent` で長押しからのドラッグを送り、`screenrecord` で録画してコマを抜いた。確かめた過程は、下端で離す (判定なし 8 回・グループをまたがせない 4 回)、長く運んでグループ 1 からグループ 2 へまたぐ (判定なし・グループをまたがせない)、上端の自動スクロール。終わった後にエミュレータを止めた
- iOS の動き: シミュレータへ直接タッチを送る手段は使わず、Sample の複製 (スクラッチに置いた。本体は作業ツリーをそのまま参照) に観察用の UI テストと起動引数 (数秒後にスイッチを切る・layout を変える・受け入れない・グループをまたがせない) を足し、XCUITest で長押しからのドラッグを合成しながら `simctl io recordVideo` で録画してコマを抜いた。リポジトリのファイルは変えていない。確かめた過程は、下端の自動スクロールと下端で離す、上端の自動スクロール (指の位置を 4 通り)、受け入れないときの戻り (その場と、自動スクロールで元の位置が画面の外に出た後)、ドラッグ中にスイッチを切る・layout を変える (移動の途中と、持ち上げた直後)、長く運ぶ (7 秒)。終わった後にシミュレータを止めた
- 録画・複製はスクラッチに置いた。evidence/ には静止画 (コマを並べたもの) だけを置いた (`review-002-*.png` の 8 枚)。写るのはシミュレータ・エミュレータのステータスバー (時刻と通信の印) と Sample のデモデータで、個人を特定する要素が無いことを開いて確かめた

## 前回の指摘の解消状況

| 出典 | 指摘 | 状況 | 確かめたこと |
|---|---|---|---|
| review-001 🔴 Critical / 相方 Major 1 | Android: 自動スクロール中に下端で離すと最後のグループの末尾へ置かれる | **解消** | `KsReorderController.kt:731`〜`:744` で、表示範囲を走査し終えたときは一覧の末尾が見えているときだけ最後のグループの末尾、そうでなければ表示範囲のいちばん下の項目の後ろ (見出しならそのグループの先頭) にする。回帰テスト `releaseAtBottomEdgeDuringAutoScrollPlacesNearFinger`・`releaseAtBottomEdgeWithCanDropPlaces` が成功。エミュレータで 12 回とも起きず (`evidence/review-002-android-bottom-edge-release-8runs.png`・`-keep-groups.png`)。長く運んだときの見出しの件数は、置き場所がグループ 2 に入ったコマで 100 件 → 99 件に 1 回変わり、行き来しなかった (`evidence/review-002-android-autoscroll-cross-group.png`)。グリッドの `placementAt` の最後の `return` (`:669`) は、どの項目・見出しにも当たらない (ルートのフッター) ときだけ通り、表示範囲の外へ飛ぶ経路は無い |
| 相方 Major 2 | Android: 置くときに最新の `canDrop` で判定し直さない | **解消** | `KsReorderController.kt:201`〜`:206` で置く直前に判定し直し、偽なら元の位置へ戻す。`canDropRecheckedOnRelease` が成功。iOS も置くとき (`acceptDrop`) に判定し直しているので、両プラットフォームがそろった |
| review-001 🟡 Minor | iOS: 受け入れないときにプレビューが置いた場所で縮んで消える | **解消** | `KsCollectionViewController+Reorder.swift:204`〜`:223` で、元の位置の中心へ `UIDragPreviewTarget` で戻し、戻る間は元の位置のセルをレイアウトの属性で隠す。録画で、プレビューが約 0.3 秒で元の位置へ戻り、「Item 1」が同時に 2 つ見えるコマが無いことを確かめた (`evidence/review-002-ios-rejected-return.png`)。自動スクロールで元の位置が画面の外に出た後に受け入れなかった場合も、プレビューは上へ動いて見えなくなり、並びは変わらなかった。結合テスト 4 件 (`droppedTargetCenters` の確認) が成功 |
| review-001 🟡 Minor | iOS: 隙間の予測を iOS 16・17 で確かめていない | **記録で解消** | オーナー判断で確かめずに記録 (deviation.md の最後の項目)。蒸留時に ios/ADR-0011 の確かめた範囲へ書き残す、とある |
| review-001 🟡 Minor | iOS Sample の UI テストが固定の時間で待つ | **解消** | `ReorderDemoUITests.swift:308`〜`:325` の `waitUntilSettled` は、実時間の deadline・`Thread.sleep(0.1)` で譲る・超えたら最後の値を載せて失敗、の 3 条件を満たす。`assertOrder`・`assertGridOrder`・グループをまたぐ運び方がこれで待つ |
| review-001 🔵 Suggestion | UI テストの 2 件が長い | 見送り (合意どおり) | — |

## 指摘事項

### 🟠 Major iOS: 全画面に広げた一覧で、上端の自動スクロールが起きない (NEEDS_DISCUSSION)

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:124` (`reorderDropProposal`。自動スクロールは UIKit に任せている)、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:490` (`contentInsetAdjustmentBehavior = .never`)。design Decision 3「自動スクロールと持ち上げの見た目は UIKit 標準のまま」

**問題点**:
- Sample「並べ替え」(iPhone 17 / iOS 26.5。一覧はナビゲーションバーの裏まで広げ、バーの下端は上から 116pt) で、一覧を下へ送ってから下の方の項目を持ち上げ、指を上端へ運んで止めた。指の位置を 4 通りにした結果:
  - バーの上 (30pt・112pt): 一覧は動かない。離すとドロップ先が一覧でないため、持ち上げた項目は元の位置へ戻る
  - バーのすぐ下 (118pt・124pt・130pt。固定中の見出しの上): 3 秒 (130pt は 2.5 秒) 止めても一覧は 1pt も動かない (`evidence/review-002-ios-top-edge-no-autoscroll.png`: 34.5〜37.5 秒のコマで Item 47〜51 の位置が変わらない)。離すと、見えている範囲のいちばん上 (バーの裏にかかる行) に置かれる
- 下端は、ホームインジケータのあたり (下から 30pt) では自動スクロールした (`evidence/review-002-ios-bottom-autoscroll-release.png`) が、下から 90pt ではしなかった。UIKit の反応する範囲は一覧の外枠の端から狭い範囲に限られると見られる。上端ではその範囲がバーの裏に入り、指を置くとバーがドロップを受ける側になるため、上へ送る手段が無い
- 実装者の事前確認 (`evidence/ios-precheck-uikit-drag-and-drop.md` の #7) は「バーの上では上へスクロールしない」を記録しつつ、「#1 ではバーのすぐ下で上へスクロールした」としている。一時ハーネスのバーの高さでの観測で、Sample の構成では再現しなかった。deviation.md にも記録は無い
- Requirement「端での自動スクロール」は、上端か下端の近くでその向きにスクロールを続けることを SHALL で求める。Scenario は下端だけだが、Requirement の本文は上端を含む。長い一覧で項目を上へ運ぶには、ドラッグをいったん離すしかない。Android は、上端でも自動スクロールした (一覧の上端は不透明なバーの下にある)
- core/ADR-0017 (accepted) が全画面に広げた一覧を前提にしているので、Sample だけでなく、ライブラリの標準の置き方で同じことが起きる
- UIKit の自動スクロールの範囲は公開の契約に無い。UIKit のヘッダ (`UICollectionView.h`・`UIDropInteraction.h`・`UIDragInteraction.h`・`UIScrollView.h`) を確かめたが、記述は無かった。上の結論はシミュレータでの観測による。iOS 18.6 と実機では確かめていない

**選択肢** (どれにするかは設計の判断):
- A: 上端だけ、ライブラリが自動スクロールを足す。`dropSessionDidUpdate` で指が「上端の安全領域の境目 (固定中の見出しを止める位置と同じ) から一定の範囲」にある間、表示のリンクで上へ送る。下端は UIKit 標準のまま。design Decision 3 と ios/ADR-0011 (proposed) の「自動スクロールは標準で付く」を改め、安全領域を使う箇所を広げるので、core/ADR-0017 の適用範囲 (安全領域は固定の見出しと重ねる表示だけに使う) の追記が要る
- B: 両端とも自前で作る (Android と同じく一覧の外枠を基準にしつつ、上端は安全領域の境目から測る)。見え方が両プラットフォームでそろうが、UIKit 標準の速さ・加速の感じから外れる
- C: 直さずに、オーナー判断で deviation.md に記録し、利用者向けガイドに「バーの裏まで広げた一覧では上端で自動スクロールしない」と書く。Requirement の SHALL は上端で満たさないままになる

どれを採る場合も、6.3 のオーナーの目視 (端での自動スクロール) で見え方を確かめる。

### 🟡 Minor iOS: 持ち上げてから指を動かし始めるまでの間は「ドラッグ中」に数えず、その間の layout の変化で取りやめない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:90`〜`:111` (`reorderItemsForBeginning` では状態を持たず、`reorderDragSessionWillBegin` で `beginReorderDrag` する)、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:217` (`update` の保留は `isReorderDragging` のときだけ)

**問題点**:
- UIKit は `dragSessionWillBegin` を「持ち上げの動きが終わり、指を動かし始めたとき」に呼ぶ (`UICollectionView.h`: "Called after the lift animation has completed to signal the start of a drag session"、`UIDragInteraction.h`: "the user has started to drag the items away")。実装はここで初めて `reorderDrag` を持つので、持ち上げてから指を動かすまでの間は、届いた構成を控えず、スクロール命令も次ページの判定も止めない
- 録画で、持ち上げとほぼ同時 (0.1 秒以内) に layout を list から 2 列のグリッドへ変えたところ、持ち上げた Item 3 はそのまま運べ、グリッドの上で置いた位置で置いたときの処理が呼ばれて受け入れられた (Item 3 は Item 16 の後ろへ移った。`evidence/review-002-ios-layout-change-at-lift.png`)。Scenario「ドラッグ中に layout が変わる」(取りやめて元の位置に戻し、置いたときの処理を呼ばない) を、この間だけ満たさない。design Decision 5 も「ドラッグ中 (持ち上げてから…)」としている
- 持ち上げたまま指を止めている間 (4 秒) に layout を変えた場合と、スイッチを切った場合は、UIKit が持ち上げを取り消すか、置くときの判定で断られ、並びは変わらなかった。問題が出るのは持ち上げの動きの途中から動かし始めるまでの短い間で、知らせの行き先は見えている位置と一致するため、データが壊れることはない。Android は長押しが成立した時点 (`lift`) から控える
- 同じ間に届いた配列・スクロール命令は保留されず、すぐ当たる (持ち上げた項目の下で一覧が動きうる)

**推奨修正**: 持ち上げた時点 (`itemsForBeginning` で項目を返したとき) から控えを始め、持ち上げが取り消されたとき (セッションが始まらずに終わったとき) に控えを解く。UIKit に持ち上げの取り消しを受ける口が無く安全に組めない場合は、この間を「ドラッグ中」に含めないことを deviation.md に記録する (Decision 5・7 の範囲を「指を動かし始めてから」と読み替える)

### 🔵 Suggestion iOS: 固定中の見出しの裏に当たる行へ置くと、置いた直後の約 0.8 秒、見出しが置いた項目に隠れる

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:167`〜`:168` (`coordinator.drop(_:toItemAt:)`)

**問題点**: 上端の自動スクロールを試した操作で、指をバーのすぐ下 (固定中の見出しの上) で離すと、項目は見出しの裏にかかる行に置かれる。置く動きの間 (UIKit のプレビューはほかの表示より手前に描かれる)、「グループ 1」の見出しが置いた項目に覆われ、約 0.8 秒後に見出しが戻る (`evidence/review-002-ios-drop-preview-over-pinned-header.png` の 37.8〜38.6 秒)。UIKit 標準の置き方の見え方で、並びは正しい。上の Major の扱いによっては起きにくくなる

**推奨修正**: 6.3 のオーナーの目視の観点 (固定の見出しとの重なり) に「見出しの裏の行へ置いたときの置く動き」を加え、気になるなら、見出しの下端より上に置かれるときはプレビューの行き先を見出しの下へずらす (または置く前に一覧を送る) ことを検討する

## 確認した観点 (問題なし)

- 足場: proposal / design / specs は変更されていない。tasks.md の差分はチェックの変更だけで、6.2〜6.4 は未チェックのまま。brief.md は照合結果の追記だけ
- deviation.md の乖離 4 件と付随修正 1 件は合意済みの差分として扱った。review-001 の後に増えたのは iOS 16・17 の記録 (オーナー判断) と、取りやめたときの戻し方の変更 (review-001 の修正、オーナー承認) の追記
- Android の行き先の求め方: 走査し終えたときの行き先は、表示範囲のいちばん下の項目の後ろ・見出しならそのグループの先頭・ルートのヘッダーなら先頭で、一覧の末尾が見えているときだけ最後のグループの末尾。上へ運ぶ自動スクロールでは、表示範囲の上の項目の前が行き先になり、表示範囲の外へ飛ぶ経路は無い (エミュレータで上端の自動スクロールも確かめた)
- Android の端での自動スクロールの過程: 持ち上げた項目は指の下に描かれ続け、隙間は指の近くにある。グループ 1 から 2 へまたぐとき、見出しの件数は 100 → 99 と 101 に 1 回だけ変わった。グループをまたがせないときは、隙間はグループ 1 の末尾に留まり、グループ 2 の上で離すと元の位置へ戻って件数は変わらなかった
- iOS の端での自動スクロール (下端) と下端で離す: 自動スクロールの間、隙間は指の近くにあり、離すと指の下の位置 (同じグループの中) に置かれた。7 秒運んで Item 70 の後ろへ置く操作も同じ。見出しの件数は変わらない
- iOS の取りやめ: 移動の途中にスイッチを切る・layout を変えると、それ以後の隙間は動かず、離すと持ち上げた項目が元の位置へ戻り、並びは変わらず、layout を変えた場合は離した後に 2 列のグリッドで表示された (deviation.md の記録どおり)
- 並行・資源: 置いた後の戻る動きの完了で、隠したセルの控えを同じ位置のときだけ解く。戻る動きの間に構成を当てても、控えの位置が一致しなければ解かないので、別のセルを隠したまま残すことはない。自動スクロールの Job は置いたとき・取りやめたときに取り消す
- 公開 API・スイッチと長押し・配列の保留・ページングとスクロール命令・読み上げの操作は、review-001 の確認から変わっていない (差分は上の修正の範囲だけ)

## アクションプラン

1. 🟠 iOS の上端の自動スクロールの扱いを決める (選択肢 A / B / C)。A・B なら、design Decision 3 と ios/ADR-0011 の記述、core/ADR-0017 の適用範囲の扱いを決めてから実装し、Sample で指をバーのすぐ下に止めて上へ送れることを録画で確かめる。C なら deviation.md に記録し、ガイドへ送る
2. 🟡 iOS の持ち上げてから動かし始めるまでの間を「ドラッグ中」に含めるかを決め、含めるなら控えの開始を持ち上げの時点へ移し、含めないなら deviation.md に記録する
3. 🔵 6.3 の目視の観点に、固定中の見出しの裏の行へ置いたときの見え方を加える
4. 残っている tasks 6.2〜6.4 (体感ゲート・オーナーの目視・置いた直後の塊の件数の変化の見た目) は、1 の結論の後に行う
