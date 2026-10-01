# レビュー結果: drag-reorder (003 回目)

**日付**: 2026-09-30
**判定**: CHANGES_REQUESTED

## サマリー

前回 (review-002・相方の second-opinion-code-002) の指摘は、すべて直っているか、合意どおり deviation.md に記録されていた。iOS の上端の自動スクロールは、バーのすぐ下の帯に指を止めれば先頭まで運べ、帯の中で離したとき (受け入れる・受け入れない)・スイッチが切れたときに止まる。持ち上げた直後の layout の変化での取りやめも、Android の「見えているのが持ち上げた項目だけ」の修正も、動かして確かめた (Android は修正を外した A/B で症状の再現と解消の両方を見た)。テストは 4 系統とも、絞り込みなしで全件成功した。

一方、新しく足した iOS の上端の自動スクロールは、**指が帯を通って一覧の外 (ナビゲーションバーの上) へ出ても止まらない**。指をバーの上に置いている間、一覧は上へ送られ続け、さらにバーの上で離した後も、持ち上げた項目が戻る動きが終わるまで送られ続ける (iOS 26.5・18.6 の両方で再現)。帯は「指がその中にある間だけ」送る設計 (deviation.md の最後の項目、`KsReorderTopAutoScroll` のコメント) で、UIKit 標準の自動スクロール (一覧を安全領域の内側に置いた場合) は同じ操作で止まる。帯はバーのすぐ下にあり、指がバーへ行き過ぎるのはよくある操作のため Major とする。直し方は小さい (下の推奨修正)。

## 照合した規約

- ソースコメント規約 (always)。`scripts/comment-policy-lint.py --advisory` の結果は禁止 0 件・要確認 10 件で、review-002 と同じ (この change で足した並べ替えの行には無い)。規約本文で照合し、並べ替えのファイルの冒頭のコメントが今の作りと食い違うことを 1 件見つけた (下の Minor)
- テスト実行規約 (テストの実行・結果の報告)。4 系統とも絞り込みなしで実行し、件数をクラス別に確かめた。Android は `--rerun-tasks` を付け、XML の時刻が今回の実行であることも確かめた
- 実行時挙動の検証規約 (不具合修正の完了判定)。相方の Major (Android) を、修正を外したビルドと今のビルドの同じ手順の A/B で確かめた。観測点は先に書き出した (下の [L-002])
- Sample のプラットフォーム間一致・Sample の操作は本体の表示を変えない (`samples/**`): review-002 の後に Sample の差分は無い (mtime で確かめた)。review-001 の照合結果を引き継ぐ
- スクロール性能の体感ゲート / iOS・Android の性能検証の手順: tasks 6.2 が未実施 (未チェック) のため対象外

lessons/code-review.md の重点観点:

- [L-001] 証跡の数値のうち、直前のサイクルで直したコードに関わるものを自前のプローブで再現した。`evidence/ios-precheck-uikit-drag-and-drop.md` の (d)・r3 (約 350pt/秒で上へ進み先頭で止まる、置いた位置は隙間の位置) は、帯に止めた場合で再現した (iOS 26.5: 2139 → 0 まで進んで止まり、先頭に置かれた。シミュレータの実測の速さは 285〜300pt/秒で、フレームの抜けの分だけ遅い)。r3-3 (「バーの上は帯の外なので進まない」) は、**指を帯を通してバーへ運んだ場合には再現しなかった** (下の Major)
- [L-002] 先に書き出した期待値 (動きの品質の基準は、一覧を安全領域の内側に置いたときの UIKit 標準の上端の自動スクロール): 帯の中にある間だけ上へ送る / 帯を出たら (下へ戻す・一覧の外へ出す) すぐ止まる / 置いた・取りやめた・受け入れないときにその場で止まる / 先頭で行き過ぎずに止まる / 安全領域の上が 0 の一覧では自前の送りは無く UIKit 標準が動く / 持ち上げ直後の layout の変化では並びが変わらない。録画から 0.5〜1 秒間隔でコマを抜き、アプリ側のプローブで contentOffset を毎フレーム記録して見た

## 実行時の確認の記録

- テストの実行 (すべて絞り込みなし)
  - iOS ライブラリ: `xcodebuild test -scheme KsCollectionView` を `ksn-drag-reorder-review` (iPhone 17 / iOS 26.5) で実行。Executed 509 tests, 0 failures (`KsReorderEngineTests` 45・`KsReorderGapTrackerTests` 5・`KsReorderPlannerTests` 10・`KsReorderTopAutoScrollTests` 6 を含む。review-002 から 13 件増)
  - iOS Sample: `-scheme KsCollectionViewSamples` を同じシミュレータで実行。Executed 44 tests, 0 failures (`ReorderDemoUITests` 10 件を含む。計測ドライバは含まない)
  - Android ライブラリ: `:kscollectionview:testDebugUnitTest --rerun-tasks` で 474 件・失敗 0。クラス別に `KsReorderDragTest` 29・`KsReorderHoldTest` 15 (review-002 から 1 件増: `onlyLiftedItemVisibleKeepsPlacement`)・`KsReorderPlannerTest` 10・`KsCollectionViewPublicApiTest` 20
  - Android Sample: `:app:testDebugUnitTest --rerun-tasks` で 163 件・失敗 0 (`ReorderDemoModelTest` 10・`ReorderDemoScreenTest` 6・`SampleScreenParityTest` 10 を含む)
- iOS の動き: シミュレータへ直接タッチを送る手段は使わず、Sample の複製 (スクラッチに置き、本体は作業ツリーを参照) に、観測用の UI テスト (XCUITest で長押しからのドラッグを合成) と、アプリ側のプローブ (`UIApplication.sendEvent` でタッチの始まりと終わり、表示のリンクで contentOffset と公開の `hasActiveDrag` / `hasActiveDrop` を毎フレーム記録) と、起動引数 (一覧を安全領域の内側に置く・長押しから指定の秒数で layout を変える / スイッチを切る) を足した。`simctl io recordVideo` で録画し、AVFoundation でコマを抜いた。リポジトリのファイルは変えていない。`ksn-drag-reorder-review` (iOS 26.5) と `ksn-drag-reorder-ios18` (iOS 18.6) を使い、終わった後に両方を止めた。確かめた過程は、帯に止めて離す (受け入れる・受け入れない)、帯に止めて先頭まで運ぶ、帯を通ってバーの上へ運んで止める (遅く・速く)、帯に止めている間にスイッチが切れる、持ち上げたまま止めている間 / 動かし始めた時点に layout が変わる、一覧を安全領域の内側に置いた場合の上端とバーの上、下端 (UIKit 標準) の速さ。記録の要約は `evidence/review-003-ios-top-autoscroll-probe.log`
- Android の動き: レビュー用の AVD `ksn_drag_reorder_review_api36` (Pixel 7 / API 36) を port 5590 で起動した。adb の操作はすべて、送る前に `adb -s emulator-5590 emu avd name` で `ksn_drag_reorder_review_api36` と出ることを確かめる手順のスクリプトを通した。Sample の複製 (本体も複製) で「Item 3」だけを 1600dp の高さにし、本体の修正を外したビルドと今のビルドの 2 つの APK を作って同じ手順で比べた。終わった後にエミュレータを止めた
- evidence/ には静止画 (コマを並べたもの) 5 枚とプローブの記録の要約 1 つを置いた (`review-003-*`)。写るのはシミュレータ・エミュレータのステータスバー (時刻と通信の印) と Sample のデモデータで、個人を特定する要素が無いことを開いて確かめた

## 前回の指摘の解消状況

| 出典 | 指摘 | 状況 | 確かめたこと |
|---|---|---|---|
| review-002 🟠 Major | iOS: 全画面に広げた一覧で、上端の自動スクロールが起きない | **解消** (選択肢 A 相当。deviation.md の最後の項目にオーナー判断として記録) | `KsReorderTopAutoScroll` と `KsCollectionViewController.swift:1663`〜`:1706` で、ドラッグのセッションの間だけ表示のリンクを回し、安全領域の上の境目から下の帯 (26 以降 60pt・それより前 50pt) に指がある間 350pt/秒で上へ送り、先頭で止める。iOS 26.5 でバーのすぐ下 (境目から 30pt) に止めると 2139 → 0 まで進んで止まり、離すと先頭に置かれた (`evidence/review-003-ios26-top-band-to-first.png`)。帯の中で離したとき (受け入れる・受け入れない)・スイッチが切れたとき (iOS 26.5 で切れた 0.02 秒後) に止まる。一覧を安全領域の内側に置くと自前の送りは無く、UIKit 標準の上端の自動スクロールが動く (26.5 で約 510pt/秒、18.6 で約 446pt/秒)。ただし一覧の外へ出た場合に止まらない (下の Major) |
| review-002 🟡 Minor | iOS: 持ち上げてから指を動かし始めるまでの間は「ドラッグ中」に数えず、その間の layout の変化で取りやめない | **解消** (取りやめは直し、配列の保留などを動かし始めてからにすることは deviation.md に記録) | `reorderItemsForBeginning` で持ち上げた時点の構成を控え、`beginReorderDrag` で今の構成と比べて違えば取りやめる (`KsCollectionViewController.swift:1594`〜`:1604`)。iOS 26.5 で、持ち上げて止めている間 (長押しから 0.76 秒) と、動かし始めた時点 (1.1 秒) に layout を 2 列のグリッドへ変えると、どちらも Item 3 は元の位置のまま (グリッドの 2 行目の左) で並びは変わらなかった。結合テスト 3 件 (持ち上げ直後の layout の変化・スイッチの無効化・変化が無ければ取りやめない) が成功 |
| review-002 🔵 Suggestion | iOS: 固定中の見出しの裏に当たる行へ置くと、置いた直後に見出しが隠れる | 6.3 の目視へ回す (パッケージの記載) | tasks.md 6.3・ui/brief.md・deviation.md のどこにも観点としての記載は無い (下の Suggestion) |
| 相方 Major (second-opinion-code-002) | Android: 見えているのが持ち上げた項目だけのとき、一覧の末尾へ飛ぶ | **解消** | `KsReorderController.kt:731`〜`:737` で、一覧の末尾が表示されているときだけ最後のグループの末尾にし、数える項目が無ければ今の行き先を保つ。エミュレータで、見えているのが 1600dp の「Item 3」と固定中の見出しだけの状態から持ち上げて 60px 動かして離すと、修正を外したビルドでは「グループ 1」が 99 件になり Item 3 がグループ 100 の末尾へ移り、今のビルドでは 100 件のまま元の位置に残った。今のビルドで同じ行を下端へ運んで自動スクロールさせて離すと、Item 8 の後ろ (指の近く) に置かれた (`evidence/review-003-android-only-lifted-visible-ab.png`)。回帰テスト `onlyLiftedItemVisibleKeepsPlacement` が成功 |

## 指摘事項

### 🟠 Major iOS: 上端の自前の自動スクロールが、指が一覧の外 (バーの上) へ出ても、バーの上で離した後も止まらない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:134` (指の位置は `dropSessionDidUpdate` のときだけ控える)、`ios/Sources/KsCollectionView/KsReorderDragDropDelegate.swift:43`〜`:61` (`dropSessionDidExit` / `dropSessionDidEnd` を受けていない)、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:1614`〜`:1615`・`:1673`〜`:1678` (送りを止めて指の位置を捨てるのは `dragSessionDidEnd` だけ)

**問題点**:
- 指の位置 (`reorderFingerY`) は、一覧が受ける `dropSessionDidUpdate` のときだけ更新される。指が一覧の外へ出ると UIKit は一覧へ `dropSessionDidUpdate` を呼ばなくなる (代わりに `dropSessionDidExit` を呼ぶ。UICollectionView.h: "Called when the drop session is no longer being tracked inside the collection view's coordinate space.")。このため、帯の中で最後に控えた位置が残り、表示のリンクは上へ送り続ける
- iOS 26.5 (Sample「並べ替え」): Item 145 を持ち上げ、指を帯を通してバーの上 (バーの下端から 25pt 上) へ運んで 3 秒止めた。指がバーの上にある間、一覧は 6159 → 5101 まで送られ続け (約 3 秒)、Item 145 はバーの上に浮いたまま、その下で Item 138 から Item 114 まで流れた (`evidence/review-003-ios26-finger-on-bar-keeps-scrolling.png` の 36.0〜38.5 秒)。iOS 18.6 でも同じで、遅く運んだ場合 (120pt/秒) も速く運んだ場合 (800pt/秒) も、指がバーの上にある約 3〜3.8 秒の間、送られ続けた (`evidence/review-003-ios18-finger-on-bar-keeps-scrolling.png`)
- バーの上で離した後も止まらない。離すとドロップのセッションは終わる (`hasActiveDrop` が偽になる) が、持ち上げた項目が戻る動きの間はドラッグのセッションが続き (UIDragInteraction.h: 終わりの通知は "all related animations are completed" の後)、送りを止める `dragSessionDidEnd` まで 0.77〜0.78 秒、さらに 270pt 前後送られた (26.5・18.6 とも。`evidence/review-003-ios-top-autoscroll-probe.log` の test03・test11)。戻る先は一覧の内容の座標の元の位置なので、戻る動きの間にも一覧が動く
- 比較の基準: 一覧を安全領域の内側に置いた同じ操作 (UIKit 標準の上端の自動スクロール) では、一覧の上端を通る間だけ約 0.4〜0.5 秒送り、指がバーの上に止まっている間は動かない (iOS 26.5・18.6 とも。`evidence/review-003-ios18-inset-list-uikit-stops-on-bar.png`)
- deviation.md の最後の項目と `KsReorderTopAutoScroll` のコメントは「指がその (帯の) 中にある間は」送るとしている。帯はバーのすぐ下の 50〜60pt で、上へ運ぶときに指がバーへ行き過ぎるのはよくある操作。行き過ぎると一覧が先頭まで勝手に送られ、そこで離すと置かれずに元の位置へ戻る (元の位置はもう画面の外)
- 実装者の事前確認 (`evidence/ios-precheck-uikit-drag-and-drop.md` の r3-3「バーの上は帯の外なので進まない」) は、帯で止まらずに直接バーの上へ運んだ場合の観測と見られ、帯を通ってからバーへ出る経路は確かめていない。結合テスト (`KsReorderEngineTests` の上端の自動スクロールの 4 件) も、指が一覧の外へ出る場合と、置いた後・ドラッグの終わりの前の間を扱っていない

**推奨修正**:
- delegate で `collectionView(_:dropSessionDidExit:)` と `collectionView(_:dropSessionDidEnd:)` を受け、指の位置 (`reorderFingerY`) を捨てる (送りを止める)。指が一覧へ戻れば `dropSessionDidUpdate` で控え直されるので、送りは再開する
- 置いたとき (`reorderPerformDrop` の入り口) にも指の位置を捨て、戻る動き・置く動きの間に送らないようにする
- 結合テストに「帯に指を置いてから一覧の外へ出たことを知らせると、次のフレームで送らない」「帯の中で置いた後、ドラッグの終わりの前のフレームで送らない」を足す。直した後は、Sample で帯を通ってバーの上に止める操作を録画 (またはプローブ) で確かめる

### 🟡 Minor iOS: 並べ替えのファイルの冒頭のコメントが「端での自動スクロールは UIKit に任せる」のまま

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:5`〜`:6`

**問題点**: 上端は、一覧をバーの裏まで広げた置き方ではライブラリが自前で送る (`KsReorderTopAutoScroll`、`startReorderAutoScroll`)。冒頭のコメントはこのファイルを読む人に「自動スクロールは UIKit だけ」と伝え、今の作りと食い違う (ソースコメント規約: そのファイルだけを読んでいる人にとって意味が通ること)

**推奨修正**: 「下端の自動スクロールは UIKit に任せ、上端は一覧をバーの裏まで広げた置き方でだけ自前で足す (`KsReorderTopAutoScroll`)」のように、今の分担を書く

### 🔵 Suggestion review-002 の Suggestion (固定中の見出しの裏の行へ置く) を 6.3 の観点として成果物に残す

**該当箇所**: `tasks.md` 6.3

**問題点**: パッケージには「6.3 の目視の項目に回した」とあるが、tasks.md 6.3・ui/brief.md・deviation.md のいずれにも観点としての記載が無い。今回の上端の自動スクロールで先頭まで運ぶと、持ち上げた項目が固定中の見出しの上に重なって進み、先頭で離すと見出しの裏に当たる行へ置かれるため、この見え方に当たる機会は前より増えた (`evidence/review-003-ios26-top-band-to-first.png` の 24.0〜33.0 秒)。あわせて、上端の自前の速さ (実測 285〜300pt/秒) と、UIKit 標準の上端 (一覧を安全領域の内側に置いた場合、約 446〜510pt/秒)・下端 (約 380pt/秒) の差も、6.3 の「下端とそろって感じられるか」の材料になる

**推奨修正**: 6.3 のオーナーの目視の観点の控え (tasks.md の追記はオーケストレーターの判断。足場を書き換えない形なら、6.3 を行うときの観測点の一覧) に「固定中の見出しの裏の行へ置いたときの置く動き」と「上端の自前の送りの速さ (上の実測値)」を加える

## 確認した観点 (問題なし)

- 足場: proposal / design / specs は変更されていない。tasks.md の差分はチェックの変更だけで、6.2〜6.4 は未チェックのまま。brief.md は照合結果の追記だけ
- deviation.md の乖離 6 件と付随修正 1 件は合意済みの差分として扱った。review-002 の後に増えたのは、上端の自動スクロールを自前で足すこと (review-002 の Major、オーナー判断) と、持ち上げ直後の構成の変化を指を動かし始めた時点で比べて取りやめること (review-002 の Minor、オーナー判断) の 2 件
- 上端の自前の送り (帯の中): 帯の外 (帯の下の端より下) では送らない、安全領域の上が 0 の一覧では送らない、先頭で行き過ぎない、フレームが飛んでも 1 回に進む量に上限がある、を単体テスト 6 件で確かめており、実行でも先頭 (contentOffset 0) で止まって行き過ぎと空白は無かった。送りの間、置く先の隙間は指の下へ追従し、先頭で離すと見えていた隙間 (グループ 1 の先頭) に置かれた
- 取りやめたドラッグでは送らない: iOS 26.5 で帯に止めている間にスイッチを切ると、0.02 秒後に送りが止まった
- 表示のリンクの後始末: 受け手を弱く持つ入れ物 (`KsDisplayLinkTarget`) を通し、ドラッグの終わりと一覧が画面から外れるとき (`disconnect`) に止める。一覧を持ち続ける参照の循環は無い
- Android の行き先の求め方の修正は、数える項目が無いときに今の行き先を保つだけで、表示範囲に項目が入れば通常の経路に戻る (エミュレータで下端へ運んだとき、指の近くの Item 8 の後ろに置かれた)
- 公開 API・スイッチと長押し・配列の保留・ページングとスクロール命令・読み上げの操作は、review-002 の確認から変わっていない (review-002 の後の差分は、上の 3 つの修正と、そのテスト・証跡の範囲だけ)

## アクションプラン

1. 🟠 iOS の上端の自前の送りを、指が一覧の外へ出たとき (`dropSessionDidExit`)・ドロップのセッションが終わったとき・置いたときに止める。結合テストを 2 件足し、Sample で帯を通ってバーの上に止める操作を録画 (またはプローブ) で確かめる
2. 🟡 `KsCollectionViewController+Reorder.swift` の冒頭のコメントを、上端と下端の今の分担に合わせて書き直す
3. 🔵 6.3 の観測点に、固定中の見出しの裏の行へ置いたときの見え方と、上端の自前の送りの速さを加える
4. 残っている tasks 6.2〜6.4 (体感ゲート・オーナーの目視・置いた直後の塊の件数の変化の見た目) は、1 を直した後に行う
