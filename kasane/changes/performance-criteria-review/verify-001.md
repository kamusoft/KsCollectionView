# 一致検証: performance-criteria-review (001 回目)

**日付**: 2026-09-15
**判定**: VALID (未記録の乖離・虚偽チェック・逆流・テスト失敗はいずれも無し)

## 前提と検証範囲

- 検証対象: 作業ツリーの未コミット変更すべて (`git status` / `git diff HEAD` と未追跡ファイル)。`kasane/lessons/` は対象外
- 突き合わせの正: `specs/{collection-core,collection-layout,samples}/spec.md`。`deviation.md` に記録済みの乖離は合意済み差分として扱い、**読み替え後の Scenario** を検証対象にした
- `tasks.md` グループ 4 (再計測と判定) と 5 (仕上げ) は未着手。基準実機でのオーナー操作を要する Scenario は「実装と足場は揃っており、実行はオーナーの計測待ち」として ⏳ で区別した (INVALID の根拠にしていない)。ただし**足場が揃っているかは検証した**
- 使用 Simulator: `iPad Air 11-inch (M3) / iOS 26.0.1` (ライブラリ)、`iPhone 17e / iOS 26.4.1` (Sample)。レビュー 6 周が使った機体 (iPhone 16e / 17 / 17 Pro / 17 Pro Max / Air / 17e 26.5 / iPad Pro 11-inch (M5) / iPad mini (A17 Pro)) とは重ならない
- 参照した lessons (inbox): `do-not-run-review-and-verify-on-same-simulator` (機体を分けた)、`check-tests-exercise-production-path-before-accepting-green` (契約の中核 Scenario はテストが本番経路を通っているかを確かめた。下の「本番経路の確認」節)

## 対応表

凡例: ✅ 一致 / ⚠️ deviation 記録済み / ⏳ 実装・足場は揃い、実行はオーナーの計測待ち (tasks 4.x) / ❌ 欠落・乖離

### collection-core (MODIFIED)

#### Requirement: 大量件数での仮想化・再利用 (iOS)

| 条項 / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 生成されるセルは可視範囲 + 再利用プール分に留まる (SHALL) | `ios/Sources/KsCollectionView/KsCollectionViewController.swift:56` (`liveCellCount` / `compactLiveCells`) | `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:758` | ✅ |
| 推定高さの実測は項目単位ではなく上限つきの固定長で保持する (SHALL) | `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:30`, `:95` (`sampleCapacity = 32`) | `ios/Tests/KsCollectionViewTests/KsEstimatedHeightTests.swift:135` (保持上限を超えた分は古い実測値から捨てる) | ✅ |
| 判定は合格 / 不合格 / 未判定の 3 状態。未判定のままで完了と報告しない (SHALL NOT) | `kasane/handbook/cross/scroll-performance-gate.md:38-44` | — (規約) | ✅ |
| 判定規則・操作列・証跡の形式は `handbook/cross/scroll-performance-gate.md`、計測器と手順は `handbook/ios/performance-verification.md` に従う (SHALL) | 参照先に実在 (操作列 `:25-36`、3 状態 `:38-44`、証跡 6 節と雛形 `:57-135` / iOS 手順 `handbook/ios/performance-verification.md:38-60`) | — (規約) | ✅ |
| Scenario: 可変行高混在 10,000 件の手動フリック | fixture = Sample「大量件数」既定 10,000 件 (`samples/ios/KsCollectionViewSamples/LargeDataCount.swift:10`、`DemoData.swift:25`)。手順 `handbook/ios/performance-verification.md:38` / 操作列 `scroll-performance-gate.md:25` / 証跡雛形 `:92` | — | ⏳ (tasks 4.1。足場は揃っている) |
| Scenario: 迷いは未判定になる | 再試行規則 (非接続の対照 1 回 → なお迷えば未判定) `scroll-performance-gate.md:40-44` | — | ⏳ (tasks 4.1。規則は実在) |
| Scenario: 往復後もメモリが定常化する | `samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:85` (上限 10 往復)、`:89` (許容 2%)、`:93` (`runUntilSteady`)、`:105` (通過件数の出力) | `samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift:139` (通過 10000 / 10000 を往復ごとに確認) | ⏳ (証跡の採取は tasks 4.6。駆動と自動判定は実装済み・テスト緑) |
| Scenario: 配列の置換で不要な保持が解放される | `KsCollectionViewController.swift:56`, `:273` | `KsCollectionEngineTests.swift:1018` (2,000 件往復 → 置換 → 同時生存 < 可視 × 4) | ✅ |
| Scenario: コレクションの破棄で全て解放される | 同上 (所有関係) | `KsCollectionEngineTests.swift:1058` (弱参照プローブが nil) | ✅ |

#### Requirement: 大量件数での仮想化・再利用 (Android)

| 条項 / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 絶対値の合格線は置かない (SHALL NOT) | `samples/android/benchmark/scripts/verify-fling-results.py:30-47` (定数は下限フレーム数と劣化率のみ)、`handbook/android/performance-verification.md:26` | `samples/android/benchmark/scripts/test_verify_fling_results.py` (26 件) | ✅ |
| 基準実機の代替はオーナー承認 + 証跡に明記 (SHALL) | `handbook/android/performance-verification.md:38` | — (規約) | ✅ |
| 判定規則は cross、計測手順は android の規約に従う (SHALL) | 参照先に実在 (`handbook/android/performance-verification.md:16`, `:40-55`, `:57-88`, `:90-105`) | — (規約) | ✅ |
| Scenario: 比較対象に対する薄さ | `samples/android/benchmark/.../LargeDataScrollBenchmark.kt:32-48` (ライブラリ側 2 本 / 比較対象側 2 本)、`:57` (3 秒フリック × 3 試行、warmup 1)、比較対象 `samples/android/app/src/measurement/.../MeasurementDestinations.kt:351`, `:377` (`animateContentSize` = 既定機能) | `test_verify_fling_results.py` (フレーム数下限 90 / 劣化 10% の判定) | ⏳ (実機実行は tasks 4.4。足場・判定器は揃っている) |
| Scenario: 可変行高混在 10,000 件の手動フリック (Android) | 手順 `handbook/android/performance-verification.md:40-55`、操作列 `scroll-performance-gate.md:25` | — | ⏳ (tasks 4.5) |
| Scenario: 往復後もメモリが定常化する (Android) | `samples/android/app/src/measurement/.../MemoryRoundTripScreen.kt:134`, `:316` (連続 2 往復 2% 以内)、通過件数の照合 | `samples/android/benchmark/.../LargeDataMemoryBenchmark.kt:36`, `:45` | ⏳ (実機実行は tasks 4.6) |
| Scenario: 配列の置換と画面離脱で保持が解放される (Android) | `MemoryRoundTripScreen.kt:171`, `:178`, `:186`, `:216-219`、`MeasurementLifetime.kt:17` (プロセスに属する計数)、`MeasurementResultScreen.kt:38-53` (進捗の印)、`SampleNavHost.kt:77` (離脱先を積み残さない) | `LargeDataMemoryBenchmark.kt:89`, `:105` (`assertReleased`: peak / replaced ≤ 可視 × 4、left == 0)。ホスト側は `samples/android/app/src/testDebug/.../MeasurementLifetimeTest.kt` (3 件) / `MeasurementRoundTripCountingTest.kt` (1 件) | ⏳ (実機実行は tasks 4.6。判定器と計数は実装済み・単体テスト緑) |

### collection-layout (ADDED)

#### Requirement: 推定高さと一致するセルの自己サイズ (iOS)

| 条項 / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 推定高さ = 直近一定件数の実測 (ピクセル格子に量子化) の最頻値 | `KsEstimatedHeight.swift:48-72` | `KsEstimatedHeightTests.swift:20`, `:29`, `:79` | ✅ |
| **返す値は量子化後ではなく格子に入った直近の実測値そのもの** | `KsEstimatedHeight.swift:57`, `:71` | `KsEstimatedHeightTests.swift:65` (43.99 を返す) | ⚠️ deviation 記録済み (design Decision 1 との差。理由 = 丸めの半画素差が解き直しを起こさないまま全行に積み上がる) |
| 同数のときは新しい値 / 繰り返しが無いうちは平均 / 未計測は既定値 (SHALL) | `KsEstimatedHeight.swift:49`, `:59-70` | `KsEstimatedHeightTests.swift:6`, `:39`, `:47`, `:56`, `:94` | ✅ |
| 幅が変わったら前の幅の実測を捨てる (SHALL) | `KsEstimatedHeight.swift:89-91` | `KsEstimatedHeightTests.swift:162`, `:172`, `:181`, `:189` | ✅ |
| 推定と同じ高さに測られたセルの自己サイズはレイアウトの再解決を起こさない (SHALL NOT) | 実測値をそのまま返す設計 (`KsEstimatedHeight.swift:71`) + `KsHostingCell.swift:89` | `ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:29`, `:60`, `:105` (完全一致・最下位桁差・許容内では `invalidateLayout` / 測り直しが増えず、半画素超では増える) | ✅ |
| Debug 構成で「自己サイズを返したセル数」「推定と不一致だった回数」を数えられる (SHALL) | `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:18-72`、`KsCollectionViewController.swift:335` | `KsEstimatedHeightTests.swift:106`、`KsCollectionEngineTests.swift:836` | ✅ |
| Scenario: 多数派のセルは再解決を起こさない | 上記一式 | `KsCollectionEngineTests.swift:799` (高さ 2 種 6:1 の 2,000 件を実スクロールし不一致率 ≤ 0.20) | ✅ |
| Scenario: 複数列で行内に高いセルが 1 つある | レイアウト既存挙動 | `KsCollectionEngineTests.swift:884` (2 列・片側だけ高い 200 件。行高が高い方に揃う) | ✅ |
| Scenario: 微小な測定差は同じ高さとして数える | `KsEstimatedHeight.swift:94`, `:108` | `KsEstimatedHeightTests.swift:65`, `:79`, `:89` | ✅ |
| Scenario: 件数に比例しない | 件数指定 `LargeDataCount.swift`、計数の帯 `samples/ios/KsCollectionViewSamples/LargeDataMeasurementBar.swift`、time profile の帰属手順 `handbook/ios/performance-verification.md:55`、区間での占有率算出 `:58` | — | ⏳ (tasks 4.1。2,000 / 10,000 の比較に必要な足場は揃っている) |
| Scenario: 合計高さの見積もりを損ねない | `KsEstimatedHeight.swift:48` | `KsCollectionEngineTests.swift:923` (一様配列 2,000 件。初回誤差 ≤ 5%、0.1% 超の contentSize 変化 ≤ 3 回) | ⚠️ deviation 記録済み (GIVEN を一様配列 1 列へ読み替え / 変化回数を「合計高さの 0.1% 超」に校正。いずれも読み替え後の THEN をテストが表現している) |

### samples

#### Requirement: 性能計測の自動実行 (MODIFIED)

| 条項 / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 計測モジュールを同じビルドルートに持つ / fixture は iOS と同じ / 比較対象に既定機能を付ける (SHALL) | `samples/android/benchmark/`、`MeasurementDestinations.kt:351`, `:377`、`handbook/android/performance-verification.md:34`, `:71` | — | ✅ |
| 事後検証: 最新 1 実行のみ・テスト名で対応付け・環境一致・フレーム数 90 未満は未判定・P90/P99 劣化 10% 以内 (SHALL) | `verify-fling-results.py:94`, `:129`, `:159`, `:255`, `:288-328` | `test_verify_fling_results.py` (26 件 0 failures) | ✅ |
| 不合格・未判定・入力不正はいずれも非 0 終了 (SHALL) | `verify-fling-results.py:49-54`, `:339-349`, `:362` | 同上 | ✅ |
| 絶対値の合格線は判定しない (SHALL NOT) | 定数は下限フレーム数と劣化率のみ (`:30-47`) | 同上 | ✅ |
| 件数を変えた比較のための試行は持たない (SHALL NOT) | `LargeDataMemoryBenchmark.kt` / `ImageGridBenchmark.kt` から 1,000 件の試行 4 本を削除 (`SmallItemCount` 消滅)。`LargeDataScrollBenchmark.kt` も 10,000 件のみ | — (削除の確認: `grep SmallItemCount` 0 件) | ✅ |
| Scenario: 計測の再実行 | `LargeDataScrollBenchmark.kt:57` (3 秒 × 3 試行)、`LargeDataMemoryBenchmark.kt:45` (全項目通過の往復) | — | ⏳ (実機実行は tasks 4.4 / 4.6) |
| Scenario: 事後検証 | `verify-fling-results.py:255`, `:288` (試行ごとのフレーム数・劣化率・判定を出力) | `test_verify_fling_results.py` (合格 / 10% 超過) | ✅ |
| Scenario: 描画が少ない試行は未判定 | `verify-fling-results.py:265-274`, `:342` | `test_verify_fling_results.py` (下限割れ → 未判定・非 0、劣化が上限内でも合格にならない) | ✅ |
| Scenario: 入力不正は判定しない | `verify-fling-results.py:105-126`, `:152`, `:294`, `:301` | `test_verify_fling_results.py` (片側のみ / 環境不一致 / 複数実行混在 / 欠損 metric / 破損 JSON / 重複 / 指定 2 つ) | ✅ |

#### Requirement: 計測専用の件数指定 (iOS) (ADDED)

| 条項 / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 起動引数で件数を指定できる / 指定が無ければ 10,000 (SHALL) | `LargeDataCount.swift:10`, `:13`, `:33`, `:54`、`DemoData.swift:25` | `samples/ios/KsCollectionViewSamplesUITests/LargeDataCountUITests.swift:9` | ✅ |
| 不正値 (0・負数・非数値・値の欠落・複数指定) は既定へ戻さず起動を失敗させる (SHALL) | `LargeDataCount.swift:36-46`, `:68`、`KsCollectionViewSamplesApp.swift:13` | `LargeDataCountUITests.swift:32`, `:37`, `:48` | ✅ |
| Scenario: 件数を指定して開く | `LargeDataDemoView.swift:8-11`、`LargeDataMeasurementBar.swift:20` (画面に件数を表示) | `LargeDataCountUITests.swift:9` (件数 2000 の表示 + 先頭項目の生成規則) | ✅ |
| Scenario: 不正な件数 | 同上 | `LargeDataCountUITests.swift:32`, `:37` | ✅ |

#### Requirement: iOS の計測ドライバの構成 (ADDED)

| 条項 / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 自動フリックによるスクロール性能の駆動は持たない (SHALL NOT) | 自動フリック 2 本と `ScrollWindowSignpost.swift` / `--signpost-scroll-window` を削除 (源泉に残骸なし)、計測スキームの除外を整合 (`KsCollectionViewSamplesPerformance.xcscheme`) | `PerformanceDriverUITests.swift` に自動フリックのテストが存在しないこと | ✅ |
| 「メモリの自動往復**だけ**を持つ (SHALL)」 | `PerformanceDriverUITests.swift:139` (メモリ往復) に加え `:19` (画像グリッドの観測駆動) が残る | — | ⚠️ deviation 記録済み (退役対象は自動フリック 2 本と signpost。観測駆動は image-loading の証跡取得用で残す。spec 文言は蒸留時に追随) |
| Scenario: メモリの自動往復 | `PerformanceVerificationView.swift:93`, `:105` (通過件数と `phys_footprint`、定常判定の記録) | `PerformanceDriverUITests.swift:139` | ✅ (駆動そのもの。証跡の採取は tasks 4.6) |

#### Requirement: 保持対象の解放の自動確認 (Android) (ADDED)

| 条項 / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 計測用の入口が置換 → 離脱の後に同時生存 (累計 − 破棄) を読める自動走査を持つ (SHALL) | `MemoryRoundTripScreen.kt:160-186`、`MeasurementDestinations.kt:176-186`, `:200` | `MeasurementRoundTripCountingTest.kt` (最初に見える分を数え落とさない) | ✅ |
| カウンタは画面ではなくプロセスに属し、離脱後の値は結果画面の進捗の印から読める (SHALL) | `MeasurementLifetime.kt:17`、`MeasurementResultScreen.kt:38-53` | `MeasurementLifetimeTest.kt` (3 件) | ✅ |
| Scenario: 置換と離脱の走査 | 同上 + `SampleNavHost.kt:77` (離脱先を積み残さない) | `LargeDataMemoryBenchmark.kt:105` (`assertReleased`) | ⏳ (実機実行は tasks 4.6。判定器は実装済み) |

### 規約 (Requirement 本文が「〜に従う (SHALL)」で参照する先) の実在確認

| 参照先 | 参照される内容 | 実在 |
|---|---|---|
| `kasane/handbook/cross/scroll-performance-gate.md` | 判定規則 (3 状態 / 再試行) `:38-44`、固定の操作列 `:25-36`、証跡の 6 節と雛形 `:57-135`、合図の手順 `:46-55`、参考スケールの扱い `:78-82`、画像の表示待ちは別観測点 `:84-86`、自動駆動の再訪条件 `:88-90`、ADR-0006 へのリンク `:13` (`kasane/decisions/cross/0006-perceived-smoothness-as-performance-gate.md` 実在) | ✅ |
| `kasane/handbook/ios/performance-verification.md` | fixture `:26-30`、基準機と 2 走行 `:32-36`、Instruments の接続手順 `:38-49`、取り出す数値 (solver の帰属・不一致率) `:51-60`、メモリの自動往復 `:62-73` | ✅ |
| `kasane/handbook/android/performance-verification.md` | fixture `:30-34`、基準機 `:36-38`、手動 gfxinfo / Perfetto 手順 `:40-55`、相対計測と比較対象の条件 `:57-73`、事後検証スクリプトの契約 `:75-88`、メモリと解放確認 `:90-105` | ✅ |
| 各 index | cross に新規行を追加、ios / android の題名から「合格基準」を外し cross へ誘導 | ✅ |

## 追加検査

### tasks.md の虚偽チェック

| グループ | 記載 | 対応表との整合 |
|---|---|---|
| 1 (規約と証跡の雛形) 1.1〜1.5 | すべて `[x]` | ✅ 一致。1.5 は証跡 4 本とも 6 節 (環境 / 操作条件 / 体感 / 数値 / 判定 / 限界) に揃い、Android 側は記録窓の実長 (約 66 秒) と熱状態の観測事実表現、指標名と取得源が入っている |
| 2 (iOS) 2.1〜2.7 | すべて `[x]` | ✅ 一致 |
| 3 (Android) 3.1〜3.6 | すべて `[x]` | ✅ 一致 |
| 4 (再計測と判定) 4.1〜4.6 | すべて `[ ]` | ✅ 一致 (未着手。証跡 `evidence/` に新手順での再計測分は無い) |
| 5 (仕上げ) 5.1〜5.2 | すべて `[ ]` | ✅ 一致 |

**未実装なのにチェック済みの項目は無い。**

### 逆流検査

`proposal.md` / `design.md` / `specs/**` は最後のコミット (`2339940` 提案化) 以降 **一度も変更されていない** (`git status` / `git log` とも変更なし)。実装期間中の足場の書き換えは無い。

### 付随修正の記録

`deviation.md` の `[付随修正]` 3 件 (`ImageGridBenchmark.kt` の KDoc、`handbook/android/performance-verification.md` のメモリ手順、`MeasurementLifetime` を `measurement` ソースセットに新設した理由) は、いずれも diff の該当箇所と一致する。diff にあって Scenario にも `[付随修正]` にも対応しない変更は見つからなかった。

### 未記録の乖離

**無し。** 対応表に ❌ は 1 件も無い。

### テスト実行 (自分で再実行)

| 対象 | コマンド / 機体 | 結果 |
|---|---|---|
| iOS ライブラリ | `xcodebuild test -scheme KsCollectionView` / iPad Air 11-inch (M3) · iOS 26.0.1 (倍率 2) | **Executed 172 tests, with 0 failures** (`** TEST SUCCEEDED **`) |
| iOS Sample (通常スキーム) | `xcodebuild test -scheme KsCollectionViewSamples` / iPhone 17e · iOS 26.4.1 | **Executed 8 tests, with 0 failures** (`** TEST SUCCEEDED **`)。内訳に `LargeDataCountUITests` 3 件 (件数指定で開く / 0 で起動しない / 非数値で起動しない) を含む |
| 事後検証スクリプト | `python3 -m unittest discover -s samples/android/benchmark/scripts` | **Ran 26 tests — OK** |
| Android Sample | `./gradlew :app:testDebugUnitTest --rerun-tasks` | **32 tests / 0 failures** (`MeasurementLifetimeTest` 3 / `MeasurementRoundTripCountingTest` 1 を含む) |
| Android ライブラリ | `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` | **130 tests / 0 failures** |

### 本番経路の確認 (lessons: テストが本番と同じ経路を通しているか)

契約の中核となる Scenario について、テストが簡略化した経路で緑になっていないかを確かめた。

- **不一致率 (Scenario: 多数派のセルは再解決を起こさない)**: `KsCollectionEngineTests.swift:799` は実 `KsCollectionViewController` を window に載せ、実スクロール (`advanceUntilVisible`) で新しいセルを可視化して数えている。計数は本番経路 `KsHostingCell.preferredLayoutAttributesFitting` → `KsCollectionViewController.recordMeasuredSize` に載っており、テスト専用の計数経路ではない。比較の相手を「そのセルに渡された高さ (original)」にしている点も `KsCollectionEngineTests.swift:836` が別途固定している
- **不一致率が上界として読めるか**: `KsSelfSizingInvalidationTests.swift:60` が「半画素未満では解き直しが起きず、半画素超では起きる」ことを `invalidateLayout` の回数と測り直し回数で対照込みに確認しており、許容幅 `1e-9` はその内側 (`:105`)。「一致と数えたのに実は解き直していた」抜けが塞がれている
- **合計高さ (Scenario: 合計高さの見積もりを損ねない)**: `:923` は実 contentSize を KVO で観測し、比較対象を「実測した行の高さ × 件数」の解析値に取っている (到達後の contentSize を基準にすると解き終えた範囲しか反映しない)。deviation に退行の対照 (推定を固定 44pt にすると誤差 21%) も採られており、基準が空振りしていない
- **Android の解放確認**: 同時生存カウンタを既存の `TemplateInvocationCounter` と共用せず `MeasurementLifetime` を新設した経緯 (benchmark ビルド種別では既存カウンタが空実装で assert が常に 0 を読む = 検査しない緑) が deviation に記録され、実装もそのとおり。`assertReleased` の上限は同じ走査の同時生存ではなく**別観測の可視件数**から独立に決めており、「走査中からすでに多すぎた」場合を素通りさせない
- **Android の置換待ち**: `awaitPreviousItemsReleased` は「数が動かなくなったこと」ではなく「置換前の識別子が 1 つも載っていないこと」を条件にし、上限超過時は黙って戻らず失敗の印を返す

## 未対応 (合意済み・INVALID の根拠ではない)

- **tasks 4.1〜4.6 (再計測と判定)**: 基準実機 (iPhone 11 / Pixel 4a) でのオーナー操作と実機実行が必要。足場 (Sample の起動引数 `--large-count`、計数の帯、Release の計測スキーム、事後検証スクリプト、Android の自動走査、規約の手順と証跡雛形) は揃っており、実行待ち
- **tasks 4.2 (Decision 3 の分岐)**: 4.1 の判定が不合格だった場合の内部セクション分割は未着手。4.1 未実施のため分岐に入っていない
- **tasks 5.1 (cross/ADR-0006 の見直し)** / **5.2 (lint 3 種と `log-sanitize.py`)**: 未着手
- **spec 文言の追随 2 件** (deviation 記録済み): 「iOS の計測ドライバはメモリの自動往復**だけ**」→ 画像グリッドの観測駆動を含む文言へ、および collection-layout の「量子化した値を推定にする」→ 「数えるときだけ量子化する」へ。いずれも蒸留 (ksn-distill) での spec 追随として記録済み

## 判定

**VALID。** デルタスペック 3 本の全 Requirement / Scenario について、実装とテストの対応が付いた。❌ (未記録の欠落・乖離) は 0 件、tasks.md の虚偽チェックは 0 件、足場の逆流は無し、自分で再実行したテストはすべて成功した。オーナーの実機計測を要する Scenario 6 件は「足場は揃い実行待ち」であり、仕様と実装の不一致ではない。
