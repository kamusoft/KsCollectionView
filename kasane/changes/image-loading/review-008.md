# レビュー結果: image-loading (008 回目)

**日付**: 2026-09-08
**判定**: APPROVED

## サマリー

前回 (ホスト側 review-007 / 相方 second-opinion-code-007) の共通 Minor「iOS の UI テストが基準点後の差分を検査していない」は解消している。`test印を叩くと観測区間が切り替わり差分が数え直される` は叩いた後に `sized=0 unsized=0 lines=0` を、かつ `total=` が非ゼロで残ることまで期待に含める形になり、`beginSession()` から基準点の記憶を落とす退行・累計を消す退行のどちらでも赤になる構造になった。相方の残り 2 件 (証跡の解消済み記述と手順番号 / テストコメントの lessons 参照) も対応済みで、後者は参照先が `KsImageTest` のコード識別子に置き換わっており `comment-policy` の許容範囲に収まっている。

印の内訳の並び替え (`Δsized` 降順 → `Δunsized` 降順 → 識別子の文字列順) は両プラットフォームで同一規則であり、Android は単体テスト 2 件が文字列一致で固定、iOS は本レビューの実機プローブで同じ並びが出ることを確認した。新たな Critical / Major / Minor は無い。指摘は Suggestion 1 件で、並び替えの副作用 (合格側の証跡が印から消える) と、それに追随していない doc コメント・deviation の記述に関するものである。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| `handbook/cross/comment-policy.md` | always (差分の 4 ファイルすべてがコメントを書き換えている) |
| `handbook/cross/test-execution.md` | テストの実行・結果の報告 (iOS UI テストの追加アサーションと本レビューの再実行) |
| `handbook/cross/sample-parity.md` | 差分が `samples/**` を触る (印の書式・並びの両プラットフォーム一致) |
| `handbook/cross/runtime-behavior-verification.md` | 差分が「検証: 画像の挙動」の再計測手順 (`evidence/image-behavior-observation.md`) の前提を変える |

参照した決定: `cross/ADR-0004` (Sample のプラットフォーム間一致)。`core/ADR-0012` は `proposed` のため判定の根拠にしていない。

参照した lessons (inbox): `do-not-run-review-and-verify-on-same-simulator` / `reviewer-reproduces-evidence-numbers-by-probe` / `check-sibling-contracts-when-fixing-a-review-finding` / `tests-created-in-change-are-in-scope-for-fixes` / `check-tests-exercise-production-path-before-accepting-green`。昇格済みの `lessons/code-review.md` は存在しない。

## 自分で再実行した結果

`do-not-run-review-and-verify-on-same-simulator` に従い、これまで使われた個体をすべて避け、テスト実行とプローブでも別個体を使った。実機は使っていない。

| 対象 | 手順 | 結果 |
|---|---|---|
| iOS Sample UI (iPhone 17 Pro / iOS 26.4) | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples` | **5 件 / 0 失敗**。内訳は `ImageLoadingSlotUITests` 2 件 (`test印を叩くと…` / `test数える起動では…`) + `InteractiveControlUITests` 3 件。計測ドライバは含まれない |
| Android Sample unit | `:app:testDebugUnitTest --rerun-tasks` | **28 件 / 0 失敗** (5 クラス。`ImageLoadingSlotCounterTest` 7 件・`SampleDemoScreenTest` 9 件・`ImageGridMeasurementFixtureTest` 5 件・`SampleScreenParityTest` 4 件・`ImageRequestKindTest` 3 件) |
| release ビルド | `:app:assembleRelease` | 成功 (印の並び替えが `counterDisabled` 側の `deltaSnapshot()` でも成立することの確認) |
| 標準 lint | `comment-policy-lint.py --advisory` / `local-path-lint.py` / `identity-lint.py` | 禁止 0 件・検出 0 件 (要確認 14 件はすべて既存ファイルで前回と同数。今回の差分 4 ファイルには 1 件も無い) |

本レビューの差分は `samples/**` と change 配下のみで、`ios/Sources` `android/kscollectionview` の本体には触れていない (前回から変わったファイルは 4 本 + `deviation.md` / `evidence/image-behavior-observation.md` / `ImageLoadingSlotCounter.swift`)。本体テスト (iOS 154 件 / Android 129 件) は 7 周目で通過済みの範囲であり、今回は再実行していない。

### 並び替えと基準点の独立再現 (プローブ)

`reviewer-reproduces-evidence-numbers-by-probe` に従い、書式を作る側 (`ImageLoadingSlotMark.summary`) が変わったので、iOS の印を実機経路で読み直した。実装・足場には触れていない。手順は上のテストとは別個体 (iPhone 17 Pro Max / iOS 26.1) に Sample を入れ、`simctl launch … --screen 画像グリッド --count-image-loading-slots` で起動し、印を叩き、2 画面送って戻した。

| 局面 | 印の実測 |
|---|---|
| 初回表示 | `slots session=0 items=15 sized=15 unsized=0 lines=15 total=15/0/15 1:1/0 10:1/0 11:1/0 12:1/0 13:1/0 14:1/0 15:1/0 2:1/0 3:1/0 … 9:1/0` |
| 印を叩いた直後 | `slots session=1 items=15 sized=0 unsized=0 lines=0 total=15/0/15 1:0/0 10:0/0 11:0/0 12:0/0 … 9:0/0` |
| 2 画面送って戻した後 | `slots session=1 items=57 sized=48 unsized=0 lines=48 total=63/0/63 31:2/0 32:2/0 33:2/0 13:1/0 14:1/0 … 29:1/0 more=37` |

読み取れたこと:

- **並び替えは仕様どおり動いている**。3 局面目で `Δsized=2` の 3 件が先頭に来て、その後ろに `Δsized=1` の 17 件が識別子の文字列順 (`13`〜`29`) で並ぶ。同値を文字列順で割る規則は Android の単体テスト (`印は総数と要素ごとの内訳を出す` の `1:1/1 10:1/0 2:1/0`) と同じ規則で、両プラットフォームの並びは一致している
- **基準点は実機で効いている**。叩いた直後に差分だけが 0 に戻り、累計 `total=15/0/15` は保たれる。iOS の UI テストが新たに見ている 3 つの数 (`sized=0 unsized=0 lines=0`) が、テストとは別の個体でも同じ挙動として観測できた
- **叩いた後にスクロールしなければ差分は 0 のまま**で、追加の読み込み中は起きなかった。UI テストの新しいアサーションが個体差で間欠的に落ちる形にはなっていない

## 前回指摘の解消判定

| # | 前回の指摘 | 判定 | 根拠 |
|---|---|---|---|
| 1 | 🟡 Minor (ホスト・相方の共通指摘) iOS の UI テストが基準点後の `sized=0` を見ていない | **解消** | `samples/ios/KsCollectionViewSamplesUITests/ImageLoadingSlotUITests.swift:44-49` の期待が `"slots session=[1-9][0-9]* items=[0-9]+ sized=0 unsized=0 lines=0 total=[1-9][0-9]*/.*"` になった。**赤になる構造**であることを 2 方向で確認した — (a) 同じテストが叩く前に `sized=[1-9][0-9]*` を待っており、叩いた後の `sized=0` はその状態からの遷移としてしか成立しないため、`beginSession()` が `baseline = tallies` を落として通し番号だけ進める実装では前段の値が残って時間切れになる。(b) 期待に `total=[1-9][0-9]*/` が含まれるため、逆に基準点で累計を消す実装 (差分は 0 になるが累計も 0 になる) でも落ちる。相方の推奨「baseline の更新を検証する」も同時に満たしている |
| 2 | 🔵 Suggestion (ホスト 2 件目 / 相方 2 件目) 証跡の手順番号のずれと「手立てが無い」の古い記述 | **解消** | `evidence/image-behavior-observation.md` の小節見出しが「測り直しに足りて**いなかった**もの (…**現在は解消済み**)」になり、冒頭に現行機構 (`ImageLoadingSlotCounter` / `ImageLoadingSlotMark` / 基準点機構) への参照が入り、本文の参照が「手順 4 (当時の手順 3)」に直った |
| 3 | 🔵 Suggestion (ホスト 5 件目) ログ側フォールバックの言い回しが `Δsized == 0` と一致しない / `log show` の取りこぼしが手順に無い | **解消** | `deviation.md` の残差の文が「対象 ID の行のうち `sized` が増えた行が無いこと。枠未確定 (`unsized`) だけの行は判定に含めない」になり、`evidence/image-behavior-observation.md` の突き合わせの注意に「`log show --info` は起動直後の行を落とすことがあるため、基準点より前の値は印の `total=` から取り、ログから数え直さない」が入った |
| 4 | 🔵 Suggestion (ホスト 3 件目) 印の内訳を差分の大きい順に | **解消 (残差あり)** | 両プラットフォームで `Δsized` 降順 → `Δunsized` 降順 → 識別子の文字列順に変わり、Android は `区間を切る前の値は差分に混ざらない` (`2:1/0 1:0/0`) と `印は総数と要素ごとの内訳を出す` (`1:1/1 10:1/0 2:1/0`) の 2 件が文字列一致で固定。iOS は上のプローブで確認。`deviation.md` に採用の記録あり。残差は下の Suggestion に記す |
| 5 | 🔵 Suggestion (ホスト 4 件目) deviation の「8dp」が実態と合わない | **解消** | 「印 (`bodySmall` 相当の複数行テキスト + 上下 4dp の余白) の分だけ**コレクションに残る高さが減る**。行数は数えた要素の件数に応じて伸びる」に書き換わった |
| 6 | 🟡 Minor (相方 3 件目) テストコメントが lessons のローカル識別子を参照 | **解消** | `samples/android/app/src/testDebug/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotCounterTest.kt:200-205` の parenthetical が「(この待機の形は本体の `KsImageTest` の同種ヘルパと同じ)」になった。`KsImageTest` はコード識別子なので `comment-policy` の許容参照であり、参照先の実体 (`android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsImageTest.kt:740-752` の `awaitCondition`) が実在し、deadline + `waitForIdle()` + `Thread.sleep(1)` の同じ形であることも確認した (存在しないものを指す参照ではない) |

## 指摘事項

### [🔵 Suggestion] 並び替えの副作用で、合格側の証跡が印から必ず消える — doc コメントと deviation がそれに追随していない

**該当箇所**: `samples/ios/KsCollectionViewSamples/ImageLoadingSlotCounter.swift:58-61`、`samples/android/app/src/counterEnabled/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotCounter.kt:109-114`、`deviation.md` (基準点機構の形の項の「残差」)

**問題点**: 並び替えは狙いどおり「差分が出ている要素」を内訳の先頭に集めるが、その裏返しとして**判定対象 (`Δsized == 0` であってほしい要素) は必ず内訳の最後尾へ回る**。上のプローブの 3 局面目がそのままの例で、戻ってきた item 1〜12 は 1 件も内訳に現れず (`more=37` に吸収)、印の内訳 20 件はすべて追い出された範囲で埋まった。並び替え前は文字列順だったため対象が数件は残っていたので、**印だけで合格を確かめられる場面は増えるどころか減っている** (不合格の在り処が読める場面が増えるのとの引き換え)。

判定そのものは壊れていない。`deviation.md` と `evidence/image-behavior-observation.md` の両方に「溢れた対象 ID はログ側で `sized` が増えた行が無いことを見る」があり、判定はログ側で成立する。問題なのは記述の側で:

- 両プラットフォームの `deltaSnapshot()` の doc コメントが「基準点より前から数えられている要素も差分 0 として残す (印に `id:0/0` として現れることが、その要素で読み込み中が起きていないことの積極的な証跡になる)」と書いているが、この「印に現れる」は要素数が 20 件を超える計測 (= tasks 7.4 で実際に行う計測) では成立しない。差分 0 の要素は必ず切られる側に回る
- `deviation.md` の残差が「送り戻し後 (要素数 40〜70) は対象 ID が内訳から**溢れうる**」のままである。並び替え後は「溢れうる」ではなく「対象 ID は差分が出ている要素が 20 件以上あれば必ず溢れる」であり、7.4 を実施する人が印だけで済ませられると読める余地が残る

**推奨修正**: doc コメントの parenthetical を実態に合わせる (「差分 0 として残すので、要素数が内訳の上限に収まる場面では `id:0/0` が積極的な証跡になる。上限を超える計測ではログ側で見る」等)。あわせて `deviation.md` の残差を「並び替えにより、対象 ID (差分 0) は内訳の最後尾に回るため、差分が出ている要素が上限を超える計測では必ず溢れる。判定はログ側で行う」に更新する。

印だけで合格側も読めるようにしたいなら、内訳とは別に「差分 0 の要素数」を 1 語 (`zeros=<件数>` 等) 併記する手もあるが、書式は両プラットフォーム一致が要るうえ突き合わせ規則にも影響するので、必須の修正としては挙げない。

## 確認して問題が無かった観点

- **`beginSession()` の形が保たれていること**: `samples/ios/KsCollectionViewSamples/ImageLoadingSlotCounter.swift:80-83` は `baseline = tallies` + `session += 1` のままで、累計を消していない。Android (`counterEnabled`) も `baseline.clear()` + `putAll(tallies)` + `sessionNumber += 1` のままで、`reset()` だけが累計を消す。今回の差分で基準点機構の意味は変わっていない
- **並び替え規則の両プラットフォーム一致** (`cross/ADR-0004`): iOS は `sized` 降順 → `unsized` 降順 → `"\(key)"` の昇順、Android は `compareByDescending { sized }.thenByDescending { unsized }.thenBy { key.toString() }`。どちらも識別子を**文字列として**比べており、`10` が `2` より前に来る点まで同じ。iOS の識別子が `Int` であることに引きずられて数値順にしていない (プローブの 1・10〜15・2〜9 の並びで実測確認)。印の書式 (`slots session= items= sized= unsized= lines= total=<s>/<u>/<sum>` + `<id>:<s>/<u>` + `more=`)、上限 20 件、`more=` の出し方も一致している
- **並び替えが総数・突き合わせ規則を壊していないこと**: `items` は `delta.count` / `delta.size`、`more=` は `entries.count - detailLimit` で、どちらも並びに依存しない。ログとの突き合わせに使う `lines` も差分の総和のままで、内訳を切っても失われる数は無い (プローブでも `items=57` / `lines=48` / `more=37` = 57 − 20 が整合)
- **iOS の並び替えが決定的であること**: `sorted(by:)` は安定ソートではないが、比較子が (sized, unsized, 識別子文字列) の全順序で、識別子は辞書の鍵として一意なので同順位が生じない。同じ計数からは常に同じ文字列になる
- **`counterDisabled` (配布構成) との整合**: 並び替えは `imageLoadingSlotSummary` (main ソースセット) 側にあり、`deltaSnapshot()` が空の `Map` を返す配布構成でも成立する。`:app:assembleRelease` の成功で確認した。印は `isEnabled` が false なら 1 要素も出さないため、配布構成の見た目は不変
- **UI テストが本番経路を通っていること** (`check-tests-exercise-production-path-before-accepting-green`): `launchCountingImageGrid()` はデモ画面そのものを起動引数付きで開いており、計測専用の別画面を作っていない。読んでいる印も `accessibilityIdentifier("imageLoadingSlot.tally")` が付いた本番の `ImageLoadingSlotMark`
- **UI テストの待機の形** (`handbook/cross/test-execution.md`「収束を待つアサーション」): `assertLabelMatches` は `XCTWaiter` + `XCTNSPredicateExpectation` の条件ベース待機で、上限 30 秒の実時間 deadline を持ち、失敗時は `mark.label` の実測値をメッセージに載せる。固定時間の待機を挟んで「静止した」ことにしていない
- **Android テストの追加分**: 並び替えを固定する 2 件の期待文字列 (`2:1/0 1:0/0` と `1:1/1 10:1/0 2:1/0`) は、私が規則から手計算した並びと一致する。`区間を切る前の値は差分に混ざらない` のコメント「切る前だけ数えた要素 1 は差分が出た要素 2 より後に来る」も、テストが実際に見ている内容と合っている
- **コメント規約** (`handbook/cross/comment-policy.md`): 今回の 4 ファイルに作業文書のパス・change 識別子・レビュー通番・lessons のローカル識別子は無い。UI テストの「(Android の `ImageLoadingSlotCounterTest` に対応)」と Kotlin テストの「本体の `KsImageTest` の同種ヘルパと同じ」はいずれもコード識別子への参照で許容範囲。標準 lint も禁止 0 件で、要確認 14 件は今回の差分の外
- **足場凍結**: `specs/` `proposal.md` `design.md` `tasks.md` に変更は無い (`git status` で未変更)。tasks.md の未完了 (7.1 / 7.4 / 7.5) は実機計測が残る項目であり、虚偽のチェックは無い
- **既定の実行への非波及**: iOS の印は `ImageLoadingSlotCounter.isEnabled` が false なら `body` が何も返さない。Android も同じ早期 return。並び替えは印の中だけの話で、`ImageGridCell` / `ImageGridDemoView` / `ImageGridDemoScreen` には今回の差分が無い。承認済みのデモ画面の見た目は数えない実行で不変

## アクションプラン

APPROVED を妨げるものは無い。着手するなら 1 点だけ。

1. **Suggestion**: 両プラットフォームの `deltaSnapshot()` の doc コメントと `deviation.md` の残差を、並び替え後の実態 (差分 0 の要素は内訳の最後尾に回り、上限を超える計測では必ず溢れる。判定はログ側) に合わせる。tasks 7.4 を実施する前が望ましい
