# レビュー結果: image-loading (007 回目)

**日付**: 2026-09-08
**判定**: APPROVED

## サマリー

前回採用した Major (計数が累計しか持たず、初回表示と戻りを分離できない) は解消している。両プラットフォームに同型の基準点機構 (`beginSession` / `session` / 差分スナップショット) が入り、判定規則が `Δsized == 0` に改まり、印とログが同じ `session=` で突き合わせられる形になった。**この解消は、レビュー側で実機経路を独立に再現して確かめた** — 初回表示で `sized=12` (累計) だった状態から印を叩いて `session=1 sized=0` に切り替わり、2 画面送って戻した後に戻った範囲 (item 1〜12) の `Δsized` が 0、追い出された範囲 (item 13〜48) が 1 以上、session=1 のログ行数 46 が印の `lines=46` と一致することを、証跡の値とは別の個体で自分で観測した。

review-006 の Suggestion 3 件も、1 件はコード側 (`waitForIdle()` を挟む自前待機)、2 件は deviation への記録として処置されている。新たな Critical / Major は無い。指摘は Minor 1 件 (iOS の UI テストが自分の名前どおりの検査をしていない) と Suggestion 4 件で、いずれも証跡の記述精度と計測の使い勝手に関する残差である。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| `handbook/cross/comment-policy.md` | always |
| `handbook/cross/test-execution.md` | テストの実行・結果の報告 (本レビューの再実行と、`awaitSizedTally` の待機の形) |
| `handbook/cross/sample-parity.md` | 差分が `samples/**` を触る |
| `handbook/cross/runtime-behavior-verification.md` | 差分が「検証: 画像の挙動」の再計測手順 (`evidence/image-behavior-observation.md`) を書き換える |
| `handbook/android/performance-verification.md` | 差分が Android の計測画面と benchmark に触れる |
| `handbook/ios/performance-verification.md` | 差分が iOS 計測の土俵となるセルに触れる |

参照した決定: `cross/ADR-0004` (Sample のプラットフォーム間一致)、`core/ADR-0002`、`android/ADR-0001`。`core/ADR-0012` は `proposed` のため判定の根拠にしていない。

参照した lessons (inbox): `wait-for-idle-in-robolectric-compose-tests` / `reviewer-reproduces-evidence-numbers-by-probe` / `do-not-run-review-and-verify-on-same-simulator` / `check-tests-exercise-production-path-before-accepting-green` / `tests-created-in-change-are-in-scope-for-fixes`。昇格済みの `lessons/code-review.md` は存在しない。

## 自分で再実行した結果

使用した個体は 6 周目までと重複しない (`do-not-run-review-and-verify-on-same-simulator` に従い、本体テスト・Sample UI テスト・実機プローブでそれぞれ別個体を使った)。

| 対象 | 手順 | 結果 |
|---|---|---|
| iOS 本体 (iPhone Air / iOS 26.1) | `xcodebuild test -scheme KsCollectionView -configuration Debug` | **154 件 / 0 失敗** (`KsImageAccessibilityTests` 6 件を含む) |
| iOS Sample UI (iPhone 17 / iOS 26.4.1) | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples` | **5 件 / 0 失敗** (`ImageLoadingSlotUITests` 2 件を含む。計測ドライバは含まれない) |
| Android 本体 unit | `:kscollectionview:testDebugUnitTest --rerun-tasks` | 129 件 / 0 失敗 |
| Android Sample unit | `:app:testDebugUnitTest --rerun-tasks` | **28 件 / 0 失敗** (5 クラス。`ImageLoadingSlotCounterTest` が 7 件) |
| release / benchmark ビルド | `:app:assembleRelease` `:app:assembleBenchmark` `:benchmark:assembleBenchmark` | 成功 |
| 計数の実体が配布構成に入らないこと | 3 構成の APK の dex 走査 | debug のみ `CountedLoadingSlot` (7) / `KsImageLoadingSlot` (1)。release / benchmark はどちらも 0。`beginSession` と印の識別子文字列は counterDisabled / main 由来で残るが、`isEnabled` が常に false のため描画に到達しない |
| 標準 lint | `comment-policy-lint.py --advisory` / `local-path-lint.py` / `identity-lint.py` | 禁止 0 件・検出 0 件 (要確認 14 件はすべて既存ファイル。前回と同数) |

### 基準点機構の独立再現 (プローブ)

`reviewer-reproduces-evidence-numbers-by-probe` に従い、修正された計数機構そのものを実機経路で動かして値を取り直した。実装・足場には一切触れていない。手順は Sample を iPhone 17e / iOS 26.5 (今回のテスト実行とは別個体) に入れ、`simctl launch ... --screen 画像グリッド --count-image-loading-slots` で起動し、印の文字列と `log show --predicate 'category == "image-loading-slot"' --info` を突き合わせた。

| 局面 | 画面の印 | 判定に効く点 |
|---|---|---|
| 初回表示の直後 | `slots session=0 items=12 sized=12 unsized=0 lines=12 total=12/0/12` (内訳は全要素 `1/0`) | **累計の `sized == 0` では判定できない**という相方の Major の前提が、実測で成立している (初回表示だけで 12) |
| 印を叩いた直後 | `slots session=1 items=12 sized=0 unsized=0 lines=0 total=12/0/12` (内訳は全要素 `0/0`) | 基準点が切れ、通し番号が 1 進み、累計は保たれたまま差分だけが 0 に戻る |
| 2 画面送って戻した後 | `slots session=1 items=48 sized=46 unsized=0 lines=46 total=58/0/58` (内訳に `1:0/0 2:0/0 10:0/0 11:0/0 12:0/0` … `more=28`) | 戻った範囲は差分 0、追い出された範囲は 1 以上 |
| ログ (session=1) | 46 行。`item=1`〜`12` の行は **0 行**、`item=13`〜`48` は各 1〜2 行 | 印の `lines=46` と一致。**内訳から溢れた item 3〜9 についても `Δsized == 0` がログ側で確認できる** |

結論: 「初回表示で読み込み中を経由したセルが、基準点後の戻りで `Δsized == 0` と判定できる」は成立している。観測が空振りしていないこと (追い出された範囲が 1 以上) も同時に取れている。

**副産物として 1 つ確認できたこと**: session=0 の 12 行は、`log show --info --debug --last 1h` でも 1 行も取れなかった (session=1 の 46 行はすべて取れた)。起動直後に出したログ行が保存側に残らないことが実際に起きるということであり、「ログだけに依存させない」という今回の設計判断が実測で正当化された形になる。判定する区間 (session=1) では行数が印と一致したため判定には影響しない。

## 前回指摘の解消判定

| # | 前回の指摘 | 判定 | 根拠 |
|---|---|---|---|
| 1 | 相方 🟠 Major 累計値では「初回表示」と「戻ってきたとき」を分離できない | **解消** | 両プラットフォームに `beginSession()` / `session` / `deltaSnapshot()` / `delta(_:)` が入り、印は差分を主・累計を `total=` に併記、ログは各行に `session=` と差分・累計を載せる (`samples/ios/KsCollectionViewSamples/ImageLoadingSlotCounter.swift:62-84`、`samples/android/app/src/counterEnabled/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotCounter.kt:115-146`)。判定規則の改定は `deviation.md` と `evidence/image-behavior-observation.md:109-128` に記録済み。Android は `ImageLoadingSlotCounterTest` の 3 件 (「区間を切ると差分は 0 から始まる」「区間を切る前の値は差分に混ざらない」「計数は 0 に戻せる」) が差分の意味と印の書式を文字列一致で固定している。iOS は UI テスト 1 本 + 上のプローブで確認した |
| 2 | 🔵 Suggestion Robolectric の待機に `waitForIdle()` が無く lessons と食い違う | **解消** | `awaitSizedTally` が実時間 deadline + 各試行の `composeTestRule.waitForIdle()` + `Thread.sleep(1)` + 実測値付き失敗メッセージの自前待機になった (`samples/android/app/src/testDebug/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotCounterTest.kt:201-213`)。`handbook/cross/test-execution.md`「収束を待つアサーション」の 3 条件をすべて満たし、`wait-for-idle-in-robolectric-compose-tests` とも一致する。5 周目に相方が指摘した `Thread.sleep` ポーリングとは別物 (固定時間の反復ではなく、規約が要求する「実行機会を譲る」1 ms) であり、後退ではない |
| 3 | 🔵 Suggestion automation スイッチが Simulator 個体全体の設定であることが記録されていない | **解消 (記録)** | `deviation.md` の 2026-09-08 の項に「個体全体の設定を書き換える / 異常終了時は残りうる / 同一個体で並走させない理由が増えた」が入った。推奨に添えた「前回の残り値を失敗メッセージに載せる」は未実施だが、これは元から任意扱い |
| 4 | 🔵 Suggestion 計測画面の入れ子が 1 段増えたことが記録されていない | **解消 (記録)** | `deviation.md` に「計測画面は `Column` + `weight(1f)` になり入れ子が 1 段増えた。7.5 はこの構造で取る値なので 7.2 の証跡とは比較しない」が入った |

## 指摘事項

### [🟡 Minor] iOS の UI テストが、名前に反して「差分が数え直される」ことを見ていない

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/ImageLoadingSlotUITests.swift:29-48`

**問題点**: `test印を叩くと観測区間が切り替わり差分が数え直される` が叩いた後に確かめているのは `slots session=[1-9][0-9]* .* total=[1-9][0-9]*/.*`、すなわち**通し番号が進んだことと累計が残っていること**だけである。「差分が数え直される」= `sized` が 0 に戻ることは 1 つも見ていない。

Android には同じ性質を文字列一致で固定する単体テストが 3 件あるが、iOS の差分計算は Swift の別実装 (`ImageLoadingSlotCounter.deltaSnapshot()` / `ImageLoadingSlotTally.subtracting(_:)`) であり、Sample に単体テストの置き場が無い以上、この UI テストが唯一の担保になる。今のアサーションでは、`beginSession()` が `baseline = tallies` を取り違えて差分が 0 に戻らなくなっても緑のままになる。

なお上のプローブでは、叩いた直後に `sized=0 unsized=0 lines=0` が安定して観測できている (画像は既に表示済みで、叩いた後にスクロールしなければ新しい読み込み中は起きない)。

**推奨修正**: 叩いた後の期待に `sized=0 unsized=0 lines=0` を含める (例: `"slots session=[1-9][0-9]* items=[0-9]+ sized=0 unsized=0 lines=0 total=[1-9][0-9]*/.*"`)。それが不安定なら、テスト名を実際に見ている内容 (通し番号が進み累計が残る) に合わせる。

### [🔵 Suggestion] 証跡の手順に 1 項挿入したことで、後段の参照番号が指す先がずれた

**該当箇所**: `kasane/changes/image-loading/evidence/image-behavior-observation.md:134`

**問題点**: 「やり直すときの手順」に基準点の項が挿入され 4 項 → 5 項になったが、後段の小節が「**手順 3 の**「読み込み中スロットの構成回数を直接数える」を実機で行う手立てが、いまの Sample に無い」と書いたままになっている。現在の手順 3 は「同じ表示サイズで戻す」であり、構成回数を数えるのは手順 4 である。

同じ小節はさらに「数を取るには…新たに置く必要がある」「この便では…追加は行っていない」と続く。過去の便の記録として読める文だが、本 change でその機構が入った現在、7.4 を実施する人が最初に読む文書としては誤解を招く。

**推奨修正**: 参照を手順 4 に直し、当該小節に「この不足は本 change の計数機構で解消済み」を 1 行添える (過去の記録として残す意図なら、その旨を明示する)。

### [🔵 Suggestion] 印の内訳の切り方 (識別子の文字列順で先頭 20 件) が、判定対象を実際に落とす

**該当箇所**: `samples/ios/KsCollectionViewSamples/ImageLoadingSlotMark.swift:104-108`、`samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotMark.kt:117-119`

**問題点**: 内訳は差分のある要素も無い要素も区別せず、識別子の**文字列順**で先頭 20 件を出す。実測 (上のプローブ) では戻り後に `items=48` となり、内訳は `1 10 11 12 13…19 2 20…27` の 20 件で `more=28`、**判定対象の item 3〜9 が内訳から消えた**。deviation はこの残差を記録し「判定はログ側で成立させる」としており、実際ログ側では成立した (対象 12 件すべて 0 行) ので判定は壊れていない。

ただし、差分が 0 でない要素を先に並べる (あるいは差分 0 の要素を後回しにする) だけで、20 件の枠が「読み込み中が起きた要素」に使われるようになり、印だけで不合格の在り処が読める場面が大きく増える。両プラットフォームで同じ並び替えにすれば書式の一致も保たれる。

**推奨修正**: 並びを「差分の大きい順 → 識別子順」に変える (両プラットフォーム同時)。変えない場合は、内訳から溢れた対象はログ側で見るという運用を `evidence/image-behavior-observation.md` の手順にも 1 行残す (現在は deviation にしかない)。

### [🔵 Suggestion] deviation の「印の分だけ計測画面の高さが 8dp 増える」が実態と合わない

**該当箇所**: `kasane/changes/image-loading/deviation.md` (2026-09-08 の最終項)、`samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotMark.kt:83-89`

**問題点**: 8dp は `padding(vertical = 4.dp)` の上下分だけで、印はそれとは別に `bodySmall` の `Text` 本体の高さを占める。さらに内訳は要素が増えるほど行が伸びる (iOS の実測で 2 行 → 3 行 → 4 行。Android も同じ `Text` の折り返しで伸びる)。また `Column` + `weight(1f)` の構造上、増えるのは「計測画面の高さ」ではなく**コレクションに残る高さが減る**側である。

数えない実行では印ごと出ないため 7.5 の土俵は不変であり、実害は無い。ただし数える実行の見え方を将来この記述から推測する人が出るため、記録としては直す価値がある。

**推奨修正**: 「数える実行では印 (`bodySmall` の複数行テキスト + 上下 4dp) の分だけコレクションの高さが減る。行数は数えた要素の件数に応じて伸びる」に書き換える。

### [🔵 Suggestion] ログ側フォールバックの言い回しが、判定規則 `Δsized == 0` と一致しない

**該当箇所**: `kasane/changes/image-loading/deviation.md` (基準点機構の形の項、「残差」の文)

**問題点**: 「判定はログ側 (`session=` で絞って対象 ID の行が無いこと) で成立させる」とあるが、ログ行は `sized` の記録でも `unsized` の記録でも 1 行出る。枠未確定の読み込み中だけが起きた要素は「行が有る」が `Δsized` は 0 であり、規則どおりなら合格になる。厳しい側にずれるので偽の合格にはならないが、書かれた手順どおりに読むと正常な実行を不合格にしうる。

あわせて、上のプローブで確認したとおり **`log show` は起動直後の行を落とすことがある**。判定する区間の行数が印の `lines` と一致することを先に確かめれば取りこぼしは検出できる (今回の実測ではその通りに一致した) が、この事実は証跡の手順のどこにも書かれていない。

**推奨修正**: フォールバックの文を「対象 ID の行のうち `sized` が増えた行が無いこと」に直す。あわせて `evidence/image-behavior-observation.md` の突き合わせ手順に「`log show --info` は起動直後の行を落とすことがあるため、基準点より前の値は印の `total=` から取る (ログから数え直さない)」を 1 行足す。

## 確認して問題が無かった観点

- **基準点機構の両プラットフォーム同型性** (`cross/ADR-0004`): 印の書式 (`slots session= items= sized= unsized= lines= total=<s>/<u>/<sum>` + `<id>:<s>/<u>` + `more=`)、ログの書式 (`loading session= item= size= sized= unsized= total=<s>/<u>`)、内訳の上限 20 件、識別子の文字列順ソート、叩いて区間を切る操作、いずれも一致している。差分を主・累計を併記という見せ方も同じ
- **累計を消していないこと**: 両プラットフォームとも `beginSession()` は baseline を取るだけで `tallies` を消さない。基準点の前後を突き合わせるための必要条件で、Android は単体テストで固定、iOS はプローブで `total=12/0/12` が保たれることを確認した
- **`session` の混入防止**: ログ行は記録時点の `session` を載せるため、区間をまたいだ行が混ざらない。Android は Activity より長生きする `object` を `MainActivity.onCreate` で `reset()` しており、再作成 (回転・プロセス復帰) が起きた場合は `session=0` に戻って画面上でそれと分かる。仮に測定中に起きても差分は不合格側 (`Δsized >= 1`) に倒れる
- **既定の実行への非波及**: iOS は `ImageGridCell.image` の `else` で従来どおり `KsImage(url, contentMode:)`、Android は `rememberLoadingSlot` が null を返す (単体テストで固定)。印は両プラットフォームとも `isEnabled` が false なら 1 要素も出さない。承認済みのデモ画面の見た目は数えない実行で不変
- **計数が本番経路を通っているか** (`check-tests-exercise-production-path-before-accepting-green`): Android のテストはデモ画面と同じ `ImageGridCell` を描いて観測。iOS の UI テストとプローブはデモ画面そのものを起動引数付きで開いている。どちらも計測専用の別物を作っていない
- **`sized` / `unsized` の分類が今回の変更で壊れていないか**: iOS は `KsImage` の「枠が決まるまで読み込みを始めない」分岐 (`ios/Sources/KsCollectionView/KsImage.swift:143-145`) が外側 `GeometryReader` の 0 サイズ frame の内側に来るため、`CountedImageLoadingPlaceholder` の `proxy.size` が 0 になり `unsized` に落ちる。Android は `BoxWithConstraints` の `hasBoundedWidth/Height` で見分ける。判定に使う `sized` を汚さない構造は保たれている
- **読み込み中の色の写しが本体と一致しているか**: `ios/Sources/KsCollectionView/KsImage.swift:243` の `Color(uiColor: .systemGray5)` と `android/kscollectionview/src/main/.../KsImage.kt:291` の `Color(0xFFE0E0E0)` に対し、Sample 側の複製も同じ値。数える実行でも土俵の見た目は変わらない
- **配布構成への非包含**: dex 走査で release / benchmark に `CountedLoadingSlot` / ログタグが無いことを再確認。`beginSession` と印の識別子文字列は `counterDisabled` / main 由来で残るが到達しない
- **デモ画面のレイアウトが壊れていないか**: `ImageGridDemoScreen` は元から `Column` + `weight(1f)` で、印を足しても `fillMaxSize` の子と競合しない。iOS の `ImageGridDemoView` は `VStack(spacing: 0)` なので、印が出ない実行では隙間も増えない
- **benchmark の生存確認**: `assertMeasurementScreenAlive` は `LargeDataScrollBenchmark.kt:131-138` に 1 つ置かれ 2 本が共有。見ているのが画面の印の有無であって frameCount ではないことが doc に明記されている。今回の差分では変わっていない
- **足場凍結**: `specs/` `proposal.md` `design.md` `tasks.md` に変更は無い (`git status` で未変更)。tasks.md の未完了 (7.1 / 7.4 / 7.5) は実機計測が残っている項目であり、虚偽のチェックは無い
- **`build.gradle.kts` の記述と実態**: `named("testDebug")` の source set 追加と、ソースセット説明のコメントが実態と一致している。`ImageLoadingSlotCounterTest` は `src/testDebug` にのみ存在し、`testDebugUnitTest` で 7 件とも実行された

## アクションプラン

いずれも APPROVED を妨げない。着手するなら次の順。

1. **Minor**: iOS の UI テストの期待に `sized=0 unsized=0 lines=0` を足す (Major 修正の iOS 側の唯一の担保なので、ここだけは早い方がよい)
2. **Suggestion**: `evidence/image-behavior-observation.md` の手順番号の参照ずれと、古い「手立てが無い」の記述を直す (7.4 を実施する前が望ましい)
3. **Suggestion**: ログ側フォールバックの言い回しを `Δsized` にそろえ、`log show` の取りこぼしについて 1 行足す (同上)
4. **Suggestion**: 印の内訳を差分の大きい順に並べ替える (両プラットフォーム同時)
5. **Suggestion**: deviation の「8dp」の記述を実態に合わせる
