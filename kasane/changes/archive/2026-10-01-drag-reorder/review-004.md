# レビュー結果: drag-reorder (004 回目)

**日付**: 2026-09-30
**判定**: APPROVED

## サマリー

前回 (review-003・相方の second-opinion-code-003) の Major「iOS の上端の自前の自動スクロールが、指が一覧の外 (バーの上) へ出ても・バーの上で離した後も止まらない」は直っている。Sample「並べ替え」で帯 → バーの上 → 帯 → バーの上で離す経路を iOS 26.5・18.6 の両方で動かし、バーの上では送らず、帯へ戻すと次のフレームで再開し、バーの上で離すとそれ以降は送らないことを、delegate の通知と contentOffset の毎フレームの記録で確かめた。証跡 `evidence/ios-r4-autoscroll-speed.log` の自前の送りの値 (深さ 24pt で 460 / 420pt/秒、バーの上で 0) もプローブで再現した ([L-001])。テストは 4 系統とも絞り込みなしで全件成功した。

残りは、送りの速さを UIKit 標準に合わせる較正の細部 (iOS 18 の送り始めの待ちと帯の深い側の速さ・描画が 30fps を下回ったときの頭打ち) で、どちらも基準機の目視 (tasks 6.3) の前に扱いを決めれば足りる Minor とした。

## 照合した規約

- ソースコメント規約 (always)。`scripts/comment-policy-lint.py --advisory` は禁止 0 件・要確認 10 件で review-003 と同じ。要確認のうちこの change の `KsReorderController.kt:614` は `internal class` の中の関数の doc コメントで、公開 doc コメントではない。前回の Minor (並べ替えのファイルの冒頭のコメント) の書き直しと、今回足された `KsReorderTopAutoScroll`・delegate のコメントを規約本文で照合し、作業文書への参照・履歴記述は無かった
- テスト実行規約 (テストの実行・結果の報告)。4 系統とも絞り込みなしで実行し件数をクラス別に確かめた。Android は `--rerun-tasks` を付け、XML の時刻が今回の実行であることを確かめた
- 実行時挙動の検証規約 (不具合修正の完了判定)。review-003 で再現した手順 (帯を通ってバーの上へ運ぶ) を今のビルドで同じ形で行い、解消を確かめた。観測点は先に書き出した (下の [L-002])
- Sample のプラットフォーム間一致・Sample の操作は本体の表示を変えない (`samples/**`): review-003 の後に Sample の差分は無い (更新時刻で確かめた)。review-001 の照合結果を引き継ぐ
- スクロール性能の体感ゲート / iOS・Android の性能検証の手順: tasks 6.2 が未実施 (未チェック) のため対象外

lessons/code-review.md の重点観点:

- [L-001] 直前のサイクルで直した上端の自前の送りについて、`evidence/ios-r4-autoscroll-speed.log` の「直した後の自前の送り」の値を自前のプローブで再現した。iOS 26.5: 帯に止めた 2 回目の区間で 460pt/秒 (証跡 460)、バーの上で 0、帯へ戻すと再開、バーの上で離した後は 0。iOS 18.6: 420pt/秒 (証跡 420)、同じ止まり方。証跡の UIKit 標準の値は、噛んだ回の 12pt (約 700)・25pt (約 400)・35pt (約 260) は合ったが、深さ 1・5pt (1090・920) は得られなかった (下の Suggestion)。UIKit 標準の値は今回直したコードの計測ではないため Major の対象にはしない
- [L-002] 先に書き出した期待値 (動きの品質の基準は、一覧を安全領域の内側に置いたときの UIKit 標準の上端と、同じ一覧の UIKit 標準の下端): 帯の中にある間だけ上へ送る / 一覧の外 (バーの上) へ出たら次のフレームで止まる / 帯へ戻したら次のフレームで再開する / 外で離したらその後は送らない (持ち上げた項目が元の位置へ戻る間も) / 深さに対する速さと送り始めの時機が UIKit 標準と同じ形。録画から 0.5 秒ごとにコマを抜き、アプリ側のプローブで contentOffset と delegate の通知を毎フレーム記録して見た

## 実行時の確認の記録

- テストの実行 (すべて絞り込みなし)
  - iOS ライブラリ: `xcodebuild test -scheme KsCollectionView` を `ksn-drag-reorder-review` (iPhone 17 / iOS 26.5) で実行。Executed 515 tests, 0 failures (`KsReorderEngineTests` 48・`KsReorderTopAutoScrollTests` 9・`KsReorderGapTrackerTests` 5・`KsReorderPlannerTests` 10・`KsPublicAPITests` 26。review-003 から 6 件増)
  - iOS Sample: `-scheme KsCollectionViewSamples` を同じシミュレータで実行。Executed 44 tests, 0 failures (`ReorderDemoUITests` 10 件を含む。計測ドライバは含まない)
  - Android ライブラリ: `:kscollectionview:testDebugUnitTest --rerun-tasks` で 474 件・失敗 0 (`KsReorderDragTest` 29・`KsReorderHoldTest` 15・`KsReorderPlannerTest` 10・`KsCollectionViewPublicApiTest` 20 を含む 28 クラス)
  - Android Sample: `:app:testDebugUnitTest --rerun-tasks` で 163 件・失敗 0 (`ReorderDemoModelTest` 10・`ReorderDemoScreenTest` 6・`SampleScreenParityTest` 10 を含む 21 クラス)
- iOS の動き: Sample の複製 (スクラッチに置き、本体は作業ツリーを参照) に、アプリ側のプローブ (タッチの始まりと終わり、contentOffset、公開の `hasActiveDrag` / `hasActiveDrop`、一覧の delegate の `dropSessionDidUpdate` / `dropSessionDidExit` / `dropSessionDidEnd` の呼び出しを記録) と、XCTest の合成タッチで 1 本の指を途中で止めながら動かす観測用の UI テストを置いた。リポジトリのファイルは変えていない。`ksn-drag-reorder-review` (iOS 26.5) と `ksn-drag-reorder-ios18` (iOS 18.6) だけを使い、終わった後に両方を止めた。確かめた過程は、帯 (深さ 24pt) に 1 秒 → バーの上 2.5 秒 → 帯に 1 秒 → バーの上で離す (両 OS)、帯の深さごとに 4 秒止める (自前と、一覧を安全領域の内側に置いた UIKit 標準)、下端 (UIKit 標準) に止める。記録の要約は `evidence/review-004-ios-top-autoscroll-probe.log`、iOS 26.5 の帯 → バー → 帯 → バーで離すまでのコマは `evidence/review-004-ios26-band-bar-band-release-on-bar.png`
- Android: review-003 の後に `android/`・`samples/android/` の差分が無い (更新時刻で確かめた) ため、エミュレータでの観察は行っていない。テストの再実行だけを行った
- evidence/ に置いた画像は静止画 1 枚で、写るのはシミュレータのステータスバー (時刻と通信の印) と Sample のデモデータだけであることを開いて確かめた。記録の要約はパス・端末の識別子を含まず、`scripts/identity-lint.py`・`scripts/local-path-lint.py` とも検出 0 件

## 前回の指摘の解消状況

| 出典 | 指摘 | 状況 | 確かめたこと |
|---|---|---|---|
| review-003 🟠 Major / second-opinion-code-003 🟠 Major (確定) | iOS: 上端の自前の送りが、指が一覧の外 (バーの上) へ出ても・バーの上で離した後も止まらない | **解消** | delegate が `dropSessionDidExit` / `dropSessionDidEnd` を受け (`ios/Sources/KsCollectionView/KsReorderDragDropDelegate.swift:63`〜`:72`)、どちらでも指の位置を捨てる (`ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:179`〜`:187`)。置いたときも入り口で捨てる (`:168`〜`:169`)。指が一覧へ戻れば `dropSessionDidUpdate` で控え直される (`:135`〜`:136`)。iOS 26.5 で、帯から出た通知 (ドラッグの始まりから 1.04 秒) の後は送らず (同じフレームの 1 回分を除く)、帯へ戻った最初の提案 (3.65 秒) の次のフレームから再開し、2 回目に出た後 (4.73 秒) とバーの上で離した後 (5.10 秒のドロップの終わり〜5.90 秒のドラッグの終わり) は 1pt も動かなかった。iOS 18.6 も同じ (出た 1.23 秒・4.93 秒、終わり 5.28 秒の後は 0)。録画でも、持ち上げた項目がバーの上にある間は一覧が止まり、離した後は一覧が動かずに項目だけが元の位置 (画面の外) へ戻った (`evidence/review-004-ios26-band-bar-band-release-on-bar.png` の 62.5〜64.5 秒と 66.5 秒以降)。結合テスト 3 件 (外へ出ると止まり戻ると再開する・外で離すとすぐ止まる・置いた後は終わりの前でも送らない。`ios/Tests/KsCollectionViewTests/KsReorderEngineTests.swift:266`・`:298`・`:322`) が成功 |
| review-003 🟡 Minor | iOS: 並べ替えのファイルの冒頭のコメントが「端での自動スクロールは UIKit に任せる」のまま | **解消** | `KsCollectionViewController+Reorder.swift:5`〜`:7` が「下端は UIKit に任せ、上端は一覧をバーの裏まで広げた置き方で指が一覧の中の帯にある間だけライブラリが足す (KsReorderTopAutoScroll)」と今の分担を書いている |
| review-003 🔵 Suggestion | 固定中の見出しの裏の行へ置く見え方と上端の送りの速さを 6.3 の観点として成果物に残す | **解消** | `owner-visual-checkpoints.md` の「途中で足した観点」に、固定中の見出しの裏の行へ置く動き (約 0.8 秒覆われる) と、上端の送りの速さ・加速が下端とそろって感じられるか・帯を通ってバーの上へ出たら止まるか、の行がある |
| second-opinion-code-003 (突き合わせ) | Android: 見えているのが持ち上げた項目だけのときの末尾への飛びの解消 | 解消のまま | review-003 の後に Android の差分は無く、回帰テスト `onlyLiftedItemVisibleKeepsPlacement` を含む `KsReorderHoldTest` 15 件が成功 |

## 指摘事項

### 🟡 Minor iOS 18 以前では、上端の自前の送りの「形」が UIKit 標準と違う (送り始めの待ちが無い・帯の深い側が遅い)

**該当箇所**: `ios/Sources/KsCollectionView/KsReorderTopAutoScroll.swift:28`〜`:35`・`:43`〜`:48`、`ios/Tests/KsCollectionViewTests/KsReorderTopAutoScrollTests.swift:52`〜`:58`

**問題点**:
- iOS 18.6 の UIKit 標準は、上端 (一覧を安全領域の内側に置いた場合) も下端も、指が帯に入ってから約 0.5 秒待って送り始める。プローブでは、指が帯に入るのはドラッグの始まりから約 0.3 秒で、UIKit 標準の上端 (深さ 25pt・45pt) と下端 (深さ 25pt) はどれも 0.75 秒の区間まで 0 で、1.0 秒の区間から一定の速さになった。自前の上端は帯に入った区間 (0.25 秒) からすぐ送る (`evidence/review-004-ios-top-autoscroll-probe.log` の iOS 18.6 の節)。実装者の証跡 `evidence/ios-r4-autoscroll-speed.log` でも、iOS 18.6 の UIKit 標準はどの深さでも 1.0 秒前後まで 0 で、自前の送りは 0.26 秒から進んでいる
- 帯の深い側の速さも違う。iOS 18.6 の深さ 45pt で UIKit 標準は約 130pt/秒、自前は約 80pt/秒 (式の値 82)。証跡の UIKit 標準も 121 で、単体テストの許容幅 (±60pt/秒) がこの差 (約 4 割) を通している
- iOS 26.5 では UIKit 標準も帯に入ってすぐ送り、深さ 25pt・約 60fps の区間では 1 フレームの送りが UIKit 標準・自前とも 6.7pt で一致した。違いは iOS 26 より前だけ
- deviation.md の最後の項目は「帯の幅と速さは、UIKit 標準の上端の実測に合わせた自前の値 (帯の中の指の深さで速さが決まり時間では加速しない形)」とし、送り始めの待ちには触れていない。基準機の iPhone 11 は iOS 18.7.8 (deviation.md の「確かめた範囲」の項目) で、6.3 の目視の「下端 (UIKit 標準) とそろって感じられるか」はまさにこの OS で見ることになる。上端はすぐ動き、下端は一拍置いてから動く違いが出る見込みが高い

**推奨修正**: どちらかを 6.3 の前に決める。
- (a) iOS 26 より前のプロファイルに、帯に入ってから送り始めるまでの待ち (約 0.5 秒。帯を出たら待ちを数え直す) を足し、深さに対する曲がり方を深い側の実測 (45pt で約 120〜130) に合わせる。単体テストの iOS 18 の許容幅を、深さ 45pt の差を通さない幅に絞る
- (b) 合わせない場合は、deviation.md の上端の項目に「iOS 26 より前では UIKit 標準にある送り始めの待ちを持たない」ことを書き、`owner-visual-checkpoints.md` の上端の行に「基準機 (iOS 18) で、上端はすぐ送り始め、下端は約 0.5 秒待ってから送る違いが気にならないか」を足して、オーナーの目視で決める

### 🟡 Minor (優先度低) 描画が 30fps を下回ると、上端の自前の送りだけが遅くなる

**該当箇所**: `ios/Sources/KsCollectionView/KsReorderTopAutoScroll.swift:25`〜`:26`・`:75`

**問題点**:
- 1 回に進める時間の上限 (`maximumStep` = 1/30 秒) により、フレームの間隔が 33ms を超えると送りの量が頭打ちになり、速さが落ちる。iOS 26.5 のシミュレータで帯の浅い側 (速い送り) に止めると、セルの生成で描画が約 22fps (フレームの間隔の中央値 44ms) に落ち、深さ 1pt で約 790〜860pt/秒 (式の値 約 1070)、12pt で約 590 (式の値 約 750) になった
- 同じ条件の UIKit 標準は、フレームの間隔が延びた分だけ 1 フレームの送りを伸ばして速さを保つ (深さ 12pt、間隔 47ms で 32.7pt、約 700pt/秒)。「速さは UIKit と同じ形」という作りの意図に対し、重い一覧ほど上端 (自前) だけが遅く感じられる
- 実機の Release ビルドで 60fps が保たれていれば頭打ちはほぼ起きないため、優先度は低い。ただし基準機の目視 (6.3) で「上端が下端より遅い」と感じられた場合に、原因がこの上限か速さの値かを切り分けにくい

**推奨修正**: 上限を「アプリが裏から戻った直後のような、明らかに飛んだフレーム」だけを切る値 (例: 0.1 秒) に広げ、単体テスト `testフレームが飛んでも1回に進む量には上限がある` をその値で書き直す。広げない場合は、6.3 の上端の行に「上端が遅く感じたら、そのときのフレームの間隔を記録する」と足しておく

### 🔵 Suggestion 速さの較正の証跡に、UIKit 標準を測ったときの指の運び方を残す

**該当箇所**: `evidence/ios-r4-autoscroll-speed.log` の「UIKit 標準」の節

**問題点**: 較正の元にした UIKit 標準の値のうち、iOS 26.5 の深さ 1pt (1090)・5pt (920) は、このレビューのプローブ (Sample「並べ替え」、XCTest の合成タッチで 0.4 秒で運んで止める) では得られなかった。UIKit 標準がそもそも送り始めない回があり (上端の深さ 1・3・5pt は 3 回とも 0、12pt は 3 回中 2 回 0、下端の深さ 25pt は 2 回とも 0)、送り始めるかどうかが指の運び方 (速さ・止めている間に移動の通知が来るか) に左右されるように見える。噛んだ回の値 (12pt 約 700・25pt 約 400・35pt 約 260) は証跡と合うので、較正の値そのものを疑う材料ではないが、証跡に測り方 (ハーネスの一覧の構成、指をどの速さで運びどう止めたか) が書かれていないため、後で測り直すときに同じ値へ届かない

**推奨修正**: 証跡の冒頭に、UIKit 標準を測った一覧 (実装者のハーネスか Sample か) と指の運び方 (運ぶ速さ・止めている間の扱い) を書き足す。蒸留で ios/ADR-0011 の「確かめた範囲」に速さの値を書くときも、同じ条件を添える

## 確認した観点 (問題なし)

- 足場: proposal / design / specs は変更されていない。tasks.md の差分はチェックの変更だけで、6.2〜6.4 は未チェックのまま。brief.md は照合結果の追記だけ
- deviation.md の乖離 6 件と付随修正 1 件は合意済みの差分として扱った。review-003 の後の変更は、上端の項目の速さの記述 (一定の 350pt/秒から、帯の中の深さで決まる UIKit の実測に合わせた値へ) と「指が一覧の外へ出たら止める」の追記で、コードの `KsReorderTopAutoScroll.profile` と一致する
- 指の位置の扱い: 一覧の外へ出た・ドロップのセッションが終わった・置いた、の 3 か所で捨て、ドラッグの終わり・一覧が画面から外れるとき (`stopReorderAutoScroll`) にも捨てる。取りやめたドラッグでは指の位置を控えても送らない (`KsCollectionViewController.swift:1689`〜`:1713` の `advanceReorderAutoScroll` の条件)。控え直しは自分の一覧のセッションの提案でだけ行う
- 深さに対する速さ: iOS 26 のプロファイル (帯 60pt・最大 1100pt/秒・指数 1.7) は、証跡の UIKit 標準の 6 点と 1 割以内で合い、プローブでも約 60fps の区間で UIKit 標準と 1 フレームの送りが一致した。時間で加速しない (同じ深さに止めている間は一定) ことも、両 OS のプローブで確かめた
- 公開 API・スイッチと長押し・配列の保留・ページングとスクロール命令・読み上げの操作・Android の実装は、review-003 の確認から変わっていない (review-003 の後の差分は iOS の上端の自動スクロールと、そのテスト・証跡・deviation の範囲だけ)

## アクションプラン

1. 🟡 iOS 18 以前の上端の送り始めの待ちと帯の深い側の速さを、合わせる (a) か、違いとして記録してオーナーの目視に回す (b) かを 6.3 の前に決める
2. 🟡 (優先度低) `maximumStep` を広げるか、6.3 の観点に「上端が遅く感じたらフレームの間隔を記録する」を足す
3. 🔵 `evidence/ios-r4-autoscroll-speed.log` に UIKit 標準の測り方を書き足す
4. 残っている tasks 6.2〜6.4 (体感ゲート・オーナーの目視・置いた直後の塊の件数の変化の見た目) へ進む
