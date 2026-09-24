# レビュー結果: image-loading (006 回目)

**日付**: 2026-09-08
**判定**: APPROVED

## サマリー

前回 (review-005) の 6 件 + 相方の Minor 1 件 (計 7 件) は、いずれも実装で解消していることを自分の手で確認した。特に Major だった iOS アクセシビリティテストの空振りは、**原因が Simulator 個体の設定であって OS 版でも製品の退行でもない**という deviation の診断を、レビュー側で独立に再現できた (前回「通った」個体は `AutomationEnabled` が 1、「落ちた」個体は 0 だった)。修正後は `AutomationEnabled` が 0 の個体 2 つ (iOS 26.0 / 26.1) でどちらも 154 件 / 0 失敗になり、実行後に個体の設定が元の値へ戻ることも確かめた。

Android の計数は実行時 opt-in に揃い、既定では両プラットフォームとも本体既定の読み込み中表示を通ることを、テストとコードの両方で確認した。計数の読み出しは画面の印との突き合わせ規則を伴う形になり、iOS 側にも本番セルを通る UI テストが 1 本入って両プラットフォームの担保が揃った。新たな Critical / Major は無く、残りは Suggestion 3 件 (いずれも今回の修正が生んだ小さな残差) である。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| `handbook/cross/comment-policy.md` | always |
| `handbook/cross/test-execution.md` | テストの実行・結果の報告 (本レビューの再実行) |
| `handbook/cross/sample-parity.md` | 差分が `samples/**` を触る |
| `handbook/cross/runtime-behavior-verification.md` | 前回 Minor が観測点表 (「検証: 画像の挙動」の読み込み中の既定表示) に関わる |
| `handbook/android/performance-verification.md` | 差分が Android の benchmark と計測画面に触れる |
| `handbook/ios/performance-verification.md` | 差分が iOS 計測の土俵となるセルに触れる |

参照した決定: `cross/ADR-0004` (Sample のプラットフォーム間一致)、`core/ADR-0002`、`android/ADR-0001`。`core/ADR-0012` は `proposed` のため判定の根拠にしていない。

参照した lessons (inbox): `do-not-run-review-and-verify-on-same-simulator` / `reviewer-reproduces-evidence-numbers-by-probe` / `check-tests-exercise-production-path-before-accepting-green` / `tests-created-in-change-are-in-scope-for-fixes` / `wait-for-idle-in-robolectric-compose-tests`。昇格済みの `lessons/code-review.md` は存在しない。

## 自分で再実行した結果 (プローブを含む)

| 対象 | コマンド / 手順 | 結果 |
|---|---|---|
| iOS 本体 (iOS 26.1 / iPhone 17。実行前 `AutomationEnabled` = 0) | `xcodebuild test -scheme KsCollectionView` | **154 件 / 0 失敗** (`KsImageAccessibilityTests` 6 件すべて成功) |
| iOS 本体 (iOS 26.0 / iPhone 16e。実行前は accessibility の設定ファイル自体が無い個体) | 同上 | **154 件 / 0 失敗** (同上) |
| iOS Sample UI (iOS 26.0 / iPhone 17 Pro Max) | `xcodebuild test -scheme KsCollectionViewSamples` | **4 件 / 0 失敗** (新設の `ImageLoadingSlotUITests` 1 件を含む) |
| Android 本体 unit | `:kscollectionview:testDebugUnitTest --rerun-tasks` | 129 件 / 0 失敗 (9 クラス) |
| Android Sample unit | `:app:testDebugUnitTest --rerun-tasks` | **26 件 / 0 失敗** (5 クラス。`ImageLoadingSlotCounterTest` 5 件が `src/testDebug` から実行されている) |
| release / benchmark ビルド | `:app:assembleRelease` `:app:assembleBenchmark` `:benchmark:assembleBenchmark` | 成功 |
| 計数の実体が配布構成に入らないこと | 3 構成の APK の dex 走査 | debug のみ `CountedLoadingSlot` (7) / `KsImageLoadingSlot` (1)。release / benchmark はどちらも 0 (印の識別子だけが main 由来で入るが、`isEnabled` が常に false のため何も描かない) |
| 標準 lint | `comment-policy-lint.py --advisory` / `local-path-lint.py` / `identity-lint.py` | 禁止 0 件・検出 0 件 (要確認 14 件はすべて既存ファイル。前回と同数) |

### 前回 Major の原因診断の独立再現

deviation は「原因は Simulator 個体の設定 (`AutomationEnabled`) であって OS 版ではない」と書いている。修正コードに触れずに、前回のレビューが使った個体の設定を読み出して照合した。

| 個体 | review-005 の結果 | `AutomationEnabled` |
|---|---|---|
| iOS 26.0 / iPhone 17 Pro | 154 / 0 (成功) | **1** |
| iOS 26.1 / iPhone 16e | 154 中 5 失敗 | **0** |

「OS 版で分かれた」ように見えた分布は、そのまま個体設定の分布と一致する。診断は正しい。さらに今回、`AutomationEnabled` = 0 の個体 2 つ (26.0 系と 26.1 系の片方ずつ) で 6 件とも成功したので、修正が個体差を吸収していることも確かめられた。実行後に両個体の `AutomationEnabled` が 0 に戻っていることも確認済みで、tearDown の復元は効いている。

## 前回指摘の解消判定

| # | 前回の指摘 | 判定 | 根拠 |
|---|---|---|---|
| 1 | 🟠 Major iOS 本体テストが Simulator の OS 版で 5 件失敗し、既定表示のアクセシビリティ契約が検証されない | **解消** | `AutomationEnabled` = 0 の個体 2 つで 154 / 0。空振りしても緑になっていた 2 件には `assertAccessibilityTreeIsMaterialized()` の事前条件が入り、木が空なら先に失敗する形になった (`ios/Tests/KsCollectionViewTests/KsImageAccessibilityTests.swift:116-138`)。原因診断も上表のとおり独立に再現。なお「検証した Simulator の OS 版を報告に残す」は今回の報告には入っているが `handbook/cross/test-execution.md` の手順には反映されていない — テストが個体設定に依らなくなったため必須ではないと判断し、指摘には数えない |
| 2 | 🟡 Minor Android の計数が debug 常時有効で、検証画面の観測点が本体既定を通らない | **解消** | 実行時 opt-in (`SampleRoutes.CountImageLoadingSlotsExtra`) に変わり、`ImageGridCell.kt:41` は指定が無ければ `loading = null` を渡す。検証画面 (`ImageBehaviorVerificationScreen.kt:99`) とデモ画面 (`ImageGridDemoScreen.kt:56`) は同じセルを共有するため、既定の実行では両方とも本体既定を通る。`ImageLoadingSlotCounterTest` の「数えない実行では読み込み中の表示を差し込まない」がこの分岐を固定している。iOS の起動引数と対称になった |
| 3 | 🟡 Minor 計数の読み出しがログ 1 本で、取りこぼしが合格側に倒れる | **解消** | 両プラットフォームに同一書式の画面の印を追加 (`slots items=N sized=S unsized=U lines=L …`)。突き合わせ規則 (行数と `lines` の一致・`sized=` の連番に飛びが無いこと) が `ImageLoadingSlotMark` の doc と deviation の両方に残った。書式は `ImageLoadingSlotCounterTest`「印は総数と要素ごとの内訳を出す」で固定され、iOS 側は UI テストが実機経路で印を読む |
| 4 | 🔵 Suggestion benchmark の生存確認の計測値への影響が未裏付け | **解消** | deviation に「未検証のまま」と明記し、tasks 7.5 の再計測で A/B を取る (取れなければ証跡に未検証と残す) 方針を記録。前回示した 2 案のうち後者を選んだ形 |
| 5 | 🔵 Suggestion `build.gradle.kts` のソースセット説明が実態と食い違う | **解消** | `samples/android/app/build.gradle.kts:70-79` が「テンプレート呼び出しと読み込み中スロットの計数の実体と空実装」に更新され、`src/testDebug` の役割説明も加わった |
| 6 | 🔵 Suggestion iOS の計数の分類にテストが無い | **解消** | `samples/ios/KsCollectionViewSamplesUITests/ImageLoadingSlotUITests.swift` を新設。デモ画面の本番セル (`ImageGridCell`) を通る経路で印に ` sized=[1-9]…` が現れることを見ており、通常スキームの 4 件目として 6.1 秒で成功する。`unsized=` に部分一致しないよう直前の空白込みで見分ける書き方も妥当 |
| 7 | 相方 🟡 Minor Compose テストの `Thread.sleep` ポーリング | **解消** | `composeTestRule.waitUntil` + `ComposeTimeoutException` 捕捉に置き換わり、時間切れ時はその時点の実測値を添えて失敗する (`ImageLoadingSlotCounterTest.kt:139-152`)。`handbook/cross/test-execution.md`「収束を待つアサーション」の 3 条件のうち、実時間 deadline と実測値付き失敗は満たす (残差は Suggestion 1 を参照) |
| (同梱) | 相方 Major の降格分: `ImageLoadingSlotCounterTest` を `src/testDebug` へ移す | **解消** | ファイルは `samples/android/app/src/testDebug/kotlin/.../ImageLoadingSlotCounterTest.kt` に移動済みで、`src/test` には残っていない。`build.gradle.kts:87-89` で source set を明示。`testDebugUnitTest` で 5 件とも実行されることを確認した |

## 指摘事項

### [🔵 Suggestion] Robolectric の待機に `waitForIdle()` が挟まっておらず、同じ change で記録した教訓と食い違う

**該当箇所**: `samples/android/app/src/testDebug/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotCounterTest.kt:141-143`

**問題点**: `awaitSizedTally` は `composeTestRule.waitUntil` の条件式だけで待っている。本 change が `kasane/lessons/inbox/wait-for-idle-in-robolectric-compose-tests.md` に記録した教訓は、まさにこの形 (条件式だけの `waitUntil`) で再コンポジションが進まず時間切れになった経験から「待機ループの各試行で `waitForIdle()` を呼ぶ」と定めている。今回は 5 件とも成功したので実害は観測できていないが、教訓を記録した本人の change の中で、その教訓に反する書き方が新しく入った状態になっている。

**推奨修正**: 教訓どおり `waitForIdle()` を挟む自前待機に寄せるか、`waitUntil` で足りることが分かったのであれば教訓側の射程 (`v2` の `createComposeRule` では不要、等) を lessons に追記して食い違いを解消する。

### [🔵 Suggestion] アクセシビリティの automation スイッチが Simulator 個体の全体設定であることが、どこにも残っていない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsImageAccessibilityTests.swift:211-239`、`deviation.md` (2026-09-08 の当該項)

**問題点**: `AccessibilityAutomation.setEnabled` が書き換えるのは**個体 (Simulator) 全体の設定**であって、テスト処理系の中に閉じた状態ではない。実際、実行前後で個体の `com.apple.Accessibility.plist` の値が変わることを確認した (実行後は元に戻る)。帰結が 2 つある。

- 同じ Simulator で本体テストと Sample の UI テストを並走させると、本体側の tearDown が `AutomationEnabled` を false へ戻した瞬間に、automation を必要とする UI テスト側が壊れうる。`kasane/lessons/inbox/do-not-run-review-and-verify-on-same-simulator.md` が既に「同一 Simulator で並走させない」を定めているので新しい制約ではないが、**この change が並走を壊す新しい理由を 1 つ増やした**ことは記録されていない
- 途中でテスト処理系が落ちると tearDown が走らず、個体に automation が入ったまま残る。次の実行はその状態で緑になるため、修正が効いているのか個体が汚れているのか見分けが付かなくなる (今回の Major の再来をレビュー側から見えなくする方向の残差)

**推奨修正**: deviation か `handbook/cross/test-execution.md` の iOS 手順に「このテストは個体の accessibility 設定を一時的に書き換えるため、実行中の Simulator を他の実行と共有しない」を 1 行残す。可能なら、`setUp` で読んだ値が「前回の異常終了で残った値」かを判別できるようにする (例: 入れる前の値を失敗メッセージに載せる) と、上の 2 つ目の残差も減る。

### [🔵 Suggestion] 計測画面の入れ子が 1 段増えたことが、benchmark の土俵の記述に含まれていない

**該当箇所**: `samples/android/app/src/measurement/kotlin/jp/kamusoft/kscollectionview/samples/android/MeasurementDestinations.kt:260-284`

**問題点**: `ImageGridMeasurementScreen` は `KsCollectionView` を直接置く形から `Column` + `Modifier.weight(1f)` へ変わった。印は数えない実行では何も描かないので**高さは変わらない**が、レイアウトの入れ子は 1 段増えている。deviation の benchmark の項は「アサーション追加のみだが計測値への影響は未検証」とだけ書いており、この構造変化には触れていない。tasks 7.2 の証跡はこの `Column` が無いコードで取った値なので、7.5 の再計測時に土俵の差として併記しておかないと、値が動いたときの切り分けが 1 つ増える。

**推奨修正**: deviation の当該項に「計測画面を `Column` で包んだ」ことを 1 行足す (影響の見立ては「印を出さない実行では高さ不変」で十分)。

## 確認して問題が無かった観点

- **アクセシビリティテストの事前条件が実際に効く形か**: `assertAccessibilityTreeIsMaterialized` は「名前を付けた表示が 1 件だけ拾えること」を等号で見ており、木が空なら `[]` との比較で必ず落ちる。`labels == []` を期待する 2 件の冒頭に置かれているため、前回指摘した「空振りしたまま緑」は構造的に起きなくなった。名前を期待する 4 件は元から空の木で落ちるので、事前条件が無くても空振りしない
- **SPI 引きの失敗が黙って素通りしないか**: `dlopen` / `dlsym` に失敗すると `Unavailable` を投げ、`setUp` が throw してテストが失敗する。「スイッチが引けないので木が空 → 0 件で緑」に倒れない書き方になっている
- **計数が本番経路を通っているか** (`check-tests-exercise-production-path-before-accepting-green`): Android のテストはデモ画面と同じ `ImageGridCell` を描いて `sized` を観測しており、計測専用の別物を作っていない。iOS の UI テストも起動引数付きでデモ画面そのものを開く。どちらも「道具の内部を突く」テストではない
- **opt-in が既定に戻ることの担保**: Android は `rememberLoadingSlot` が null を返す分岐をテストで固定。iOS は `ImageGridCell.image` の `else` 分岐が既存の `KsImage(url, contentMode:)` を呼ぶだけで、印 (`ImageLoadingSlotMark`) も `isEnabled` が false なら何も描かない。承認済みの見た目 (デモ画面) は数えない実行では一切変わらない
- **配布構成への非包含**: dex 走査で release / benchmark に `CountedLoadingSlot` / ログタグが無いことを確認。印の識別子文字列だけは main 由来で入るが、`counterDisabled` の `isEnabled` が常に false なので描画には到達しない
- **両プラットフォームの印の書式一致** (`cross/ADR-0004`): 総数の並び (`items` / `sized` / `unsized` / `lines`)、内訳の形 (`id:sized/unsized`)、上限 20 件と `more=`、識別子の文字列順ソートまで一致している。ログと突き合わせる規則も同一
- **benchmark の生存確認の置き場**: `assertMeasurementScreenAlive` は `LargeDataScrollBenchmark.kt:131-138` に 1 つ置かれ、2 本のベンチマークが同じヘルパを使う。見ているのが「画面の印の有無であって frameCount ではない」ことが doc に明記されており、判定の射程を過大に書いていない
- **計数の分類 (`sized` / `unsized`) の意味**: Android は `BoxWithConstraints` の制約、iOS は `GeometryReader` の実サイズで見分ける。枠未確定の分岐が `unsized` に落ちること (= 判定に使う `sized` を汚さないこと) は前回確認済みで、今回の変更でも壊れていない
- **足場凍結**: `specs/` `proposal.md` `design.md` `tasks.md` に変更は無い。tasks.md の未完了 (7.1 / 7.4 / 7.5) は実機計測が残っている項目であり、虚偽のチェックは無い
- **benchmark 側の extra キーの写し**: `MeasurementTarget` は対象アプリのキーを手で写して持つ構造だが、計数の extra はベンチマークから使わないため写していない。ベンチマークが計数を有効化しないことは意図どおり (計測の土俵を変えないため)

## SPI 利用についての所見 (deviation の「オーナー未確認」に対して)

判定には含めないが、求められているので所見を書く。**採用してよい**と考える。理由は 3 点。

1. **配布物に入らない**: `AccessibilityAutomation` はテストターゲット (`ios/Tests/`) の `private enum` であり、製品ターゲットからは到達しない。SwiftPM の利用者がライブラリを取り込んでもコンパイル対象にならないため、審査・配布上の risk は生じない
2. **壊れ方が安全側**: 将来 symbol が消えれば `setUp` が throw してテストが**失敗する**。「SPI が引けないので検査が空振りし、0 件期待の 2 件だけが緑になる」という前回の失敗形には戻らない
3. **代案の費用が実際に高い**: XCUITest へ移すと、既定の読み込み中・失敗表示の 2 種を Sample 側に露出させる必要がある (= 検証のために製品外の表面を増やす)。得られる担保は同じで、Sample の画面集合を触るため `sample-parity` の一致要求まで巻き込む

残る懸念は上の Suggestion 2 (個体全体の設定を触ること) だけで、これは記録と運用で塞げる範囲である。

## アクションプラン

いずれも APPROVED を妨げない。着手するなら次の順。

1. **Suggestion**: Robolectric の待機と lessons の食い違いを、コード側か教訓側のどちらかで解消する
2. **Suggestion**: automation スイッチが個体全体の設定であることを deviation か test-execution の手順に残す
3. **Suggestion**: 計測画面を `Column` で包んだことを deviation の benchmark の項に 1 行足す (7.5 の再計測前が望ましい)
