# Verify 003: ios-engine-foundation

判定: **VALID**

- 対象: `specs/collection-core/spec.md` / `specs/collection-layout/spec.md` / `specs/collection-interaction/spec.md` (15 Requirement / 24 Scenario)
- 実装: `ios/Sources/KsCollectionView/`、テスト: `ios/Tests/KsCollectionViewTests/`、Sample と UI テスト: `samples/ios/`
- ❌ (未記録の欠落・乖離 / テスト失敗) **0 件**。⚠️ (deviation 記録済み) 7 件
- `verify-002.md` の ❌ 2 件 (S6.1 メモリ往復 / S14.3 Sample UI テスト) は**いずれも解消**を確認した

行番号は修正サイクル 10 後の現在のファイルに合わせて取り直している (verify-002 の行番号とはずれる)。

---

## テスト実行結果 (検証者が実行)

Simulator: iPhone 17 Pro / iOS 26.5

| 実行 | コマンド (実行ディレクトリ) | 結果 |
|---|---|---|
| ライブラリ Debug | `xcodebuild test -scheme KsCollectionView -configuration Debug` (`ios/`) | **60 tests / 0 failures** — TEST SUCCEEDED |
| ライブラリ Release | 同上 `-configuration Release ENABLE_TESTABILITY=YES` (`ios/`) | **61 tests / 0 failures** — TEST SUCCEEDED |
| Sample UI テスト (1 回目) | `xcodebuild test -scheme KsCollectionViewSamples` (`samples/ios/`) | **3 tests / 0 failures** — TEST SUCCEEDED |
| Sample UI テスト (2 回目) | 同上 | **3 tests / 0 failures** — TEST SUCCEEDED |
| Sample UI テスト (3 回目) | 同上 | **3 tests / 0 failures** — TEST SUCCEEDED |
| Sample UI テスト (4 回目) | 同上 | **3 tests / 0 failures** — TEST SUCCEEDED |
| Sample UI テスト (5 回目) | 同上 | **3 tests / 0 failures** — TEST SUCCEEDED |

Debug 60 件 / Release 61 件の差は構成別テストの内訳と一致する: 共通 59 件 + Debug 限定 1 件 (`KsCollectionEngineTests.test2000件を全件走査しても同時生存セルを可視範囲と再利用プールに留める`、`#if DEBUG`) + Release 限定 2 件 (`KsCollectionEngineTests.testReleaseでは重複IDを後勝ちで解決して表示を継続する` / `KsTemplateRegistryTests.testReleaseでは未登録キーを空セルへ解決する`、`#if !DEBUG`)。Release 実行では後者 2 件が実際に走ったことをログで確認した。

計測スキーム `KsCollectionViewSamplesPerformance` は指示どおり未実行。両スキームの `SkippedTests` は相互排他になっている — 通常スキームは `PerformanceDriverUITests` を、計測スキームは `InteractiveControlUITests` を除外する (`.xcscheme` で確認)。

**計測環境についての注記**: Sample UI テストの最初の試行は、同一 Simulator 上で別プロセスの `xcodebuild test` が同じ Sample スキームを並走しており、両者が同じアプリを起動し合って互いを崩していた。そのため一度中断し、並走が終わってから上記 5 回を逐次実行し直している。上記 5 回はいずれも `Restarting after unexpected exit, crash, or test timeout` が 0 件で、3 件すべてが報告されている。

---

## verify-002 の ❌ 2 件の追跡

### ❌ 1 (S6.1 のメモリ往復) → **解消 (⚠️ deviation 記録済み)**

**(a) 走査が全項目を通過するようになった。**
`samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:61` の `traversalStepRatio = 0.5` により、送り幅は可視範囲の高さの半分になった (`:127` で `bounds.height * ratio`)。verify-002 が指摘した 200 件固定刻みは無くなっている。統合テスト `KsCollectionEngineTests.swift:655` の `step: bounds.height / 2` と同じ条件である。

通過の実証も画面自身が持つ: `:172-176` が各段階の可視セルの項目番号を集合へ記録し、`:35` が「通過: N / 10000」を表示、`:85` が `KS_PERF_VISITED_ITEMS` として出力する。`evidence/performance-early-measurement.md` は独立 2 実行とも通過 10,000 / 10,000 件を記録している。経路の担保として Sample UI テスト `PerformanceDriverUITests.test大量件数を全件通過で2往復してメモリを表示する` (`samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift:57`) が `通過: 10000 / 10000` を検証する (計測スキームでのみ実行)。

**(b) 判定方法は spec と異なるが deviation に記録された。**
spec の THEN は「1 往復後を基準にさらに 1 往復してもメモリが増え続けない」。実装・証跡の判定は「連続する 2 往復の増分がいずれも 1 往復後の値の 2% 以内になったら定常 (上限 10 往復)」で、`PerformanceVerificationView.swift:74` (`steadyStateTolerance = 0.02`) / `:70` (`maximumRoundTrips = 10`) / `:233-239` (`hasSteadied`) がその実装。この差は `deviation.md` の 2026-09-03 の記録「性能検証のメモリ判定」で合意済みとして扱われている。許容差と上限を計測前に決めた旨は `evidence/performance-early-measurement.md` の手順・結果の双方に明記されている。

証跡の数値は実装のアルゴリズムと整合する — 実行 1 は 5 往復目で (+0.32% / +0.00%)、実行 2 は 4 往復目で (+0.16% / +0.10%) 初めて「直近 2 増分がいずれも 1 往復後の値の 2% 以内」を満たし、そこで打ち切られている。3 往復目までは条件を満たさない (実行 1 の 3 往復目 +4.39%、実行 2 の 2 往復目 +4.69%)。記録された打ち切り往復数はこの判定と一致する。

verify-002 で「単調増加で横ばいに達していない」とした点も解消しており、両実行が開始値の違い (567.2 MB / 581.8 MB) にかかわらず 610.68 MB / 610.67 MB でほぼ同じ天井に収束している。

### ❌ 2 (Sample UI テストの通し失敗) → **解消**

`samples/ios/KsCollectionViewSamplesUITests/InteractiveControlUITests.swift:64-81` の `launchVerification` が、起動のたびに `app.terminate()` してから `launch()` し、目的の検証画面の root 要素が現れなければ最大 2 回まで起動し直す形になった。通常スキームを逐次 5 回実行して全回 TEST SUCCEEDED (各回 3 件すべて報告、`Restarting after unexpected exit, crash, or test timeout` 0 件) を確認した。

---

## 対応表: collection-core

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **R1 プレーンな配列と安定 ID による表示** | `ios/Sources/KsCollectionView/KsCollectionView.swift:12` (Identifiable) / `:29` (`id:` キーパス)、`KsSnapshotPlanner.swift:11-14` (重複 ID assertion)、`KsCollectionViewController.swift:24` (`AnyHashable` 識別子 + 単一 section)、`KsSectionID.swift:3` | — | ⚠️ deviation 記録済み (重複 ID の release 挙動は後勝ち + 警告ログ。`KsSnapshotPlanner.swift:39-51` / `KsCollectionViewController.swift:362-372`) |
| S1.1 Identifiable 準拠の配列を表示する | `KsCollectionView.swift:12`、`KsCollectionViewController.swift:155` (cellProvider) | `KsSnapshotPlannerTests.testIdentifiable相当の100件を全てsnapshotへ含める` (計画 100 件)、`KsCollectionEngineTests.test100件をdataSourceへ反映する` (`numberOfItems` 100 件)。仮想化 (可視範囲 + 再利用分に留まる) は `KsCollectionEngineTests.test2000件を全件走査しても同時生存セルを可視範囲と再利用プールに留める` (半画面刻みの全件往復で同時生存セル < 可視数 × 4、`cellProviderCallCount > 2000`) | ✅ |
| S1.2 非準拠型を `id:` キーパスで表示する | `KsCollectionView.swift:29` / `:38` (`$0[keyPath: id]`) | `KsPublicAPITests.test非Identifiable型をidキーパスで組み立てられる`、`KsCollectionScenarioTests.test非Identifiable型のidキーパスで描画し差分更新のidentityにする`、`KsSnapshotPlannerTests.test非準拠型のキーパス相当IDで順序を構築する` | ✅ |
| **R2 差分更新** | `KsSnapshotPlanner.swift:22-30` (reconfigure / reload の振り分け)、`KsCollectionViewController.swift:333-423` (snapshot 構築と適用) | — | ⚠️ deviation 記録済み (同値配列でも可視セルを再構成 / 同値配列では `id:`・`template:`・登録集合の差し替えを反映しない) |
| S2.1 挿入・削除・移動のアニメーション適用 | `KsCollectionViewController.swift:412` (`animatingDifferences: true`)、`:118` | `KsSnapshotPlannerTests.test挿入削除移動後の順序を新配列に合わせる`、`KsCollectionEngineTests.test挿入削除並べ替え後に区切り線の位置を再構成する` (snapshot 順と位置依存表示)、`.test挿入時に内容不変の要素のセルプロバイダを再実行しない` (無関係要素の非再描画) | ✅ |
| S2.2 内容変更の再構成 | `KsSnapshotPlanner.swift:25-26` (同一キーは reconfigure)、`KsCollectionViewController.swift:406` | `KsSnapshotPlannerTests.test同一IDかつ同一キーの内容変更は再構成する`、`KsCollectionScenarioTests.test同一IDかつ同一キーの内容変更でセルインスタンスを維持して再描画する` (`cellForItem` の同一性と新内容の再描画) | ✅ |
| S2.3 テンプレートキー変更でのセル置換 | `KsSnapshotPlanner.swift:27-28` (キー変更は reload)、`KsCollectionViewController.swift:222-241` (キー別 `CellRegistration`)、`:407` | `KsSnapshotPlannerTests.test同一IDでキー変更時はセルを置換する`、`KsCollectionScenarioTests.test同一IDでテンプレートキーが変わるとセルを別テンプレートへ置き換える` (セルインスタンスの入れ替わり・再利用識別子の相違)、`.testレイアウト切替と同時にテンプレートキーが変わってもセルを置き換える` | ✅ |
| **R3 値キーによるテンプレート切り替え** | `KsCollectionView.swift:47` / `:65` (`template:` セレクタ)、`Template.swift:4`、`KsTemplateBuilder.swift:3`、`KsTemplateRegistry.swift:9-19`、`KsCollectionViewController.swift:222-241` (キー → 再利用種別) | — | ⚠️ deviation 記録済み (宣言形が `Template(TemplateDemoKind.message) { (item: TemplateDemoItem) in … }` の明示形。オーナー本意は推論形で phase-3 前に再訪) |
| S3.1 キー値ごとのテンプレート適用 | `KsCollectionView.swift:47`、`KsCollectionViewController.swift:165-171` | `KsTemplateRegistryTests.test値キーごとのテンプレートを登録する`、`KsPublicAPITests.test値キーの複数テンプレートを組み立てられる`、`KsCollectionScenarioTests.test同一IDでテンプレートキーが変わると…` (2 種テンプレートの実描画) | ✅ |
| S3.2 単一テンプレートの軽量形 | `KsCollectionView.swift:12` / `:23`、`KsTemplateRegistry.swift:21-24`、`KsSingleTemplateKey.swift:1` | `KsTemplateRegistryTests.test単一テンプレートは専用キーで解決できる`、`KsPublicAPITests.test単一テンプレートと利用者向けmodifierを組み立てられる` | ✅ |
| **R4 未登録キーの挙動** | `KsCollectionViewController.swift:245-256` (snapshot 準備時に検知 + debug assertion)、`KsTemplateRegistry.swift:26-36` (release は空セル + `logger.warning`)、`:15` / `:23` (最小高 1pt の fallback) | — | ✅ |
| S4.1 release ビルドでの未登録キー | `KsTemplateRegistry.swift:31` (警告ログ) / `:33` (空セル) | `KsTemplateRegistryTests.testReleaseでは未登録キーを空セルへ解決する` (Release 実行で通過を確認)。件数一致は `KsCollectionEngineTests.test未登録テンプレートキーをsnapshot準備時に検知する` が、未登録キーの要素を snapshot に載せたまま検知することで担保 | ✅ |
| **R5 セル再利用時の状態非保持** | `KsHostingCell.swift:101-109` (`prepareForReuse` で `contentConfiguration = nil`)。ドキュメント: `kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md` の「iOS セル再利用の注意」 | — | ✅ |
| S5.1 スクロール往復での状態初期化 | `KsHostingCell.swift:103` | `KsCollectionScenarioTests.testセルの再利用が起きる距離を往復するとテンプレートのstateは初期値へ戻る` (300 件中 250 番目まで往復し `@State` が初期値へ) | ✅ |
| **R6 大量件数での仮想化・再利用** | `KsCollectionViewController.swift:24` / `:155` (diffable + 再利用)、`:205-220` (同時生存セルの計数、debug 限定)、`samples/ios/KsCollectionViewSamples/DemoData.swift:23-31` (10,000 件・7 件ごと長文の決定的生成)、`samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift` | Requirement 本文の「可視範囲 + 再利用プール分に留まる」「件数に比例して増加しない」は `KsCollectionEngineTests.test2000件を全件走査しても同時生存セルを可視範囲と再利用プールに留める` が担保 | ⚠️ deviation 記録済み (基準機 iPhone 11 → iPhone 15 で代替計測) |
| S6.1 可変行高混在 10,000 件のスクロール | 同上。走査の刻みは `PerformanceVerificationView.swift:61` / `:127`、通過の記録は `:172-176` / `:35` / `:85`、定常判定は `:70` / `:74` / `:233-239` | hitch は `evidence/performance-early-measurement.md` (iPhone 15、3 試行すべて 0.0 ms/s)。メモリは同ファイル (iPhone 17 Pro Simulator / iOS 26.5、Release 構成、独立 2 実行とも通過 10,000 / 10,000 件、5 往復 / 4 往復で定常化)。計測経路は Sample UI テスト `PerformanceDriverUITests.test大量件数を全件通過で2往復してメモリを表示する` | ⚠️ deviation 記録済み (計測機の代替 / Simulator でのメモリ計測 / 定常化の判定方法。上記「❌ 1 の追跡」参照) |

## 対応表: collection-layout

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **R7 layout 値による表示形態** | `KsCollectionLayout.swift:17` / `:20` / `:25`、`KsGridColumns.swift:12` / `:17` / `:22`、`KsLayoutMetrics.swift:4-20`、`KsCollectionViewController.swift:425-479`。不正入力の assertion は `KsCollectionLayout.swift:38-52`、利用可能幅は `KsLayoutMetrics.swift:16-17` + `KsCollectionViewController.swift:428-429` / `:434-440` | — | ✅ |
| S7.1 固定列グリッド | `KsLayoutMetrics.swift:11-12`、`KsCollectionViewController.swift:443-457` | `KsLayoutMetricsTests.test固定3列を返す`、`KsCollectionEngineTests.testグリッドからリストへ切替後にスクロールしても全セルが一列になる` (`.fixed(3)` からの切替)。3 列表示は `ui/verification/fixed-grid-normal.png` | ✅ |
| S7.2 adaptive グリッド | `KsLayoutMetrics.swift:15-18`、`KsCollectionViewController.swift:458` (列間固定) | `KsLayoutMetricsTests.testAdaptiveは最小幅を下回らない最大列数を返す`、`KsCollectionEngineTests.testadaptiveの余白列間と項目幅を実レイアウト属性へ反映する` (左右余白 15 / 列間 8 / 幅 ≥ 120 / 右端 375 を実レイアウト属性で検証) | ✅ |
| S7.3 向き別列数 (コンテナ縦横比基準) | `KsLayoutMetrics.swift:13-14` (`height > width` で判定)、`KsCollectionViewController.swift:434-439` (`environment.container.effectiveContentSize`)、`:127-131` (寸法変化で `invalidateLayout`) | `KsLayoutMetricsTests.test向き別列数はコンテナ縦横比で切り替える`、`KsCollectionEngineTests.testコンテナ縦横比の変更で縦2列と横4列を再計算する` (window リサイズで再計算)。実機向きは `evidence/orientation-portrait.png` / `evidence/orientation-landscape-left.png` / `evidence/orientation-landscape-right.png` | ⚠️ deviation 記録済み (iPhone Sample の対応向きは portrait / landscape 左右の 3 方向。`samples/ios/KsCollectionViewSamples.xcodeproj/project.pbxproj:241` で宣言) |
| **R8 レイアウトの動的切り替え** | `KsCollectionViewController.swift:86-121` (`update`)、`:97` (`captureAnchor`)、`:109` (`invalidateLayout`)、`:503-517` (アンカーの控え)、`:525-552` (復元)、`:578-590` (アンカー消失時の近傍解決) | — | ✅ |
| S8.1 list とグリッドの切り替え | `KsCollectionViewController.swift:95-98` / `:107-110` / `:420` | `KsCollectionEngineTests.testリストからグリッドへの切替後も先頭可視要素を表示範囲に残す`、`.testレイアウト切替と同時の先頭側への大量挿入でもアンカーを保つ`、`.testレイアウト切替と同時にアンカーが消えたら近傍要素を表示範囲に残す`、`.testアンカーの高さが大きく縮む切り替えでもアンカーを表示範囲に残す`、`.testグリッドからリストへ切替後にスクロールしても全セルが一列になる`、`.test深い位置で行間を大きく変えても先頭可視要素を表示範囲に残す` / `.test行間を連続して変えても先頭可視要素が変わらない` (`frame.minY - bounds.minY` の一致)、`.testデータ差し替えとレイアウト切り替えを同じControllerへ適用する` (データ状態の保持) | ✅ |
| **R9 スペーシング** | `KsCollectionLayout.swift:11` / `:14` / `:27-28` (既定 0)、`KsCollectionViewController.swift:458` (`interItemSpacing`) / `:461` (`interGroupSpacing`) | — | ✅ |
| S9.1 グリッドの行間・列間 | 同上 | 列間は `KsCollectionEngineTests.testadaptiveの余白列間と項目幅を実レイアウト属性へ反映する` (実属性で列間 8)、行間は `.test深い位置で行間を大きく変えても先頭可視要素を表示範囲に残す` (`leadingRowSpacing` が 40 になることを実レイアウトで確認) と `.test行間を連続して変えても先頭可視要素が変わらない`。既定 0 は `KsCollectionLayout.swift:27-28` と `KsPublicAPITests.test単一テンプレートと利用者向けmodifierを組み立てられる` (`layout.rowSpacing` の設定値) | ✅ |
| **R10 contentPadding** | `KsCollectionView.swift:15` / `:33` / `:51` / `:70` (4 辺個別の `EdgeInsets`、既定 `EdgeInsets()`)、`KsCollectionViewController.swift:462-467` (section の contentInsets)、`:142` (`contentInsetAdjustmentBehavior = .never`) | — | ✅ |
| S10.1 内側余白とスクロールインジケータ | 同上 | `KsCollectionEngineTests.test左右の内側余白を変えてもスクロールインジケータをコンポーネント端に保つ` (左右余白 40 → 120 のいずれでも `contentInset` / `adjustedContentInset` / `verticalScrollIndicatorInsets` が 0 のまま、コンテンツの `minX` は余白どおり) | ✅ |
| **R11 list の区切り線** | `KsCollectionView.swift:98` (既定 true) / `:149` (opt-out)、`KsCollectionViewController.swift:265-280` (`isList && showsSeparators`)、`:111-113` (種別・ON/OFF 変更時の可視セル更新)、`KsHostingCell.swift:54-64` (色) / `:72-91` (全幅 1pt の Top / Bottom) / `:135-143` | — | ⚠️ deviation 記録済み (左右全幅・先頭行の上端・最終行の下端まで描画 / 太さ 1pt / 色は固定 RGBA `#D9D9DE`) |
| S11.1 既定表示と opt-out | 同上 | `KsCollectionEngineTests.testリスト区切り線を全幅で先頭と行間に表示し即時に切り替える` (先頭 Top / 全行 Bottom の可視状態、`minX` 0・幅 = セル幅・高さ 1pt、色 `#D9D9DE`、重なり順、ON → OFF → ON の即時反映と描画差)、`.test挿入削除並べ替え後に区切り線の位置を再構成する` | ✅ |
| S11.2 グリッドでは出ない | `KsCollectionViewController.swift:266-273` (`.grid` では `isList = false`)、`:111-113` (種別変更時に可視セルを更新) | 自動検証なし (所見 1)。`ui/verification/fixed-grid-normal.png` で線が無いことを確認できる | ✅ (実装は構造的に成立。自動テストが無い点は所見 1) |
| **R12 ルートヘッダー / フッター** | `KsCollectionView.swift:110` / `:119`、`KsCollectionViewController.swift:179-201` (`SupplementaryRegistration` と provider)、`:470-476` (`boundarySupplementaryItems`、宣言時のみ追加)、`:282-296` / `:298-305`、`KsHostingSupplementaryView.swift:25-44` | — | ✅ |
| S12.1 ヘッダーのスクロール追従 | `KsCollectionViewController.swift:481-493` (`makeBoundaryItem`、pin しない) | `KsCollectionEngineTests.testheaderは下方向のスクロールでコンテンツと一緒に画面外へ出る` (スクロール後も header のコンテンツ座標の frame が不変で、表示範囲と交差しなくなる)、`.test表示中のheaderと動的件数footerを更新後に再構成する`、`.test内容不変のheader更新でホスティングビューを維持する` | ✅ |
| **R13 セル自己サイズ** | `KsCollectionViewController.swift:446` / `:451` (`.estimated(44)`)、`:258-263` (`UIHostingConfiguration` + `margins(.all, 0)`) | — | ⚠️ deviation 記録済み (tasks 3.2 の自己サイズ補正は不要と判断し実装しない) |
| S13.1 可変行高 | 同上 | `KsCollectionScenarioTests.test本文量の異なる行はそれぞれ必要な高さになる` (本文量に応じて高さが異なること、同じ本文量の行が同じ高さになること、各行の高さがホスト内容の fitting size と一致すること = 切れ・余分な空白が無いこと) | ✅ |

## 対応表: collection-interaction

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **R14 アイテムタップ / ロングタップ** | `KsCollectionView.swift:128` / `:135` / `:142`、`KsCollectionViewController.swift:693-699` (`shouldHighlight`: ハンドラ未宣言なら false)、`:701-708` (feedback の表示・消去)、`:710-724` (`didSelect`)、`:594-619` (長押し)、`:144-151` (`cancelsTouchesInView = true` / ハンドラ未宣言時は認識器無効)、`:101`、`:679-691` (子 control では認識器を通さない)、`KsHostingCell.swift:93-99` / `:120-133` (hitTest による操作要素判定)、`:111-118`、`KsCollectionViewController.swift:279` (既定 `.systemFill`) | — | ✅ (Requirement 本文の「タップ追跡中にスクロールが始まったらキャンセル」は Scenario 化されておらず、実装も `UICollectionView` 標準挙動に委ねている — 所見 3) |
| S14.1 セル内ボタンとの競合 | `KsHostingCell.swift:93-99` / `:120-133`、`KsCollectionViewController.swift:693-699` / `:710-716` | `KsCollectionEngineTests.testセル内の操作要素へのタッチではitemTapとfeedbackを発火しない` (セルの hitTest 経由で操作要素を判定させ、Button action 1 回 / item tap 0 回 / feedback 非表示)、Sample UI テスト `InteractiveControlUITests.testセル内Buttonの実座標タップを優先する` (実座標タップ、5 回とも成功)。`evidence/interactive-control-after-tap.png` | ✅ |
| S14.2 タップで型付き要素が渡る | `KsCollectionViewController.swift:701-708` (押下中の feedback)、`:710-724` (離した時点で型付き項目を通知) | `KsCollectionEngineTests.test選択時に型付き項目を通知する`、`.test不透明な内容の上へ指定色のtouchFeedbackを表示して消す` (描画差で表示・消失)、`.test既定のtouchFeedbackは半透明でセル内容を隠さない`、`.testtouchFeedback色の変更を可視セルへ反映する`、`.testロングタップ未宣言のときは長押し認識器を無効にする` | ✅ (押下中の feedback 描画の実機目視は未実施 — `evidence/verification-matrix.md` に明記) |
| S14.3 ロングタップ | `KsCollectionViewController.swift:594-609` (`.began` で成立)、`:611-619`、`:145` (`cancelsTouchesInView = true` により同一タッチの選択を発火させない)、`:101` / `:149` | `KsCollectionEngineTests.testロングタップ未宣言のときは長押し認識器を無効にする`、`.test長押し成立後の別タッチによる通常タップを抑止しない`。**排他そのもの (long tap 1 / tap 0) は Sample UI テスト** `InteractiveControlUITests.test長押し宣言時は同一タッチの通常タップを発火しない` / `.test長押し未宣言時は長押し相当の保持でも通常タップを発火する` が担保。通常スキームを 5 回逐次実行して全回成功 | ✅ |
| **R15 スクロール制御** | `KsScrollController.swift:5` (`@MainActor`) / `:13-19` / `:22-24` / `:27-29`、`KsScrollPosition.swift:1-6`、`KsCollectionViewController.swift:727-740` (コマンドキュー) / `:654-661` (flush) / `:412-422` (apply 完了後に flush)、`:31-38` (最後の接続だけ有効 + debug 警告)、`KsCollectionRepresentable.swift:17-22` (dismantle で disconnect) | — | ✅ |
| S15.1 存在しない ID への命令 | `KsCollectionViewController.swift:623-629` (`indexPath` 解決に失敗したら return、debug で警告ログ) | `KsCollectionScenarioTests.test接続済みでも存在しないIDへのスクロール命令では表示位置が変わらない` (表示位置の不変・`lastScrollTargetIdentifier` が nil・後続の有効な命令の到達) | ✅ |
| S15.2 ID 指定スクロール | `KsCollectionViewController.swift:630-635`、`KsScrollPosition.swift` + `KsCollectionViewController.swift:744-750` (`.center` → `centeredVertically`) | `KsCollectionScenarioTests.test表示範囲外の要素へのcenter指定スクロールでその要素が中央に来る` (対象要素の frame 中心が表示範囲の中心と一致) | ✅ |
| S15.3 データ反映後のスクロール実行 | `KsCollectionViewController.swift:727-740` (適用中は保留)、`:414-422` (重ねた snapshot がすべて反映されてから flush)、`:644-651` (`.end` は最新の `appliedIdentifiers.last`) | `KsCollectionEngineTests.testデータ追加と同一処理の末尾命令を最後のsnapshot後に実行する` (2 回連続の追加後、末尾 ID 31 へ到達)、`KsSwiftUIIntegrationTests.testState更新と同一Button処理の末尾命令が新snapshotへ到達する` (`UIHostingController` 上で新 snapshot の末尾へ到達)、`KsCollectionEngineTests.test同一配列の再適用でも保留中のスクロール命令を実行する`、`.test空の項目でも先頭へのスクロール命令でheaderの先頭へ戻す` | ✅ |
| S15.4 未接続 no-op | `KsScrollController.swift:7` (weak receiver、nil なら何もしない) / `:40-43` (detach)、`KsCollectionRepresentable.swift:17-22` | `KsScrollControllerTests.test未接続命令は何も起こさない`、`.test最後に接続したReceiverだけが命令を受け取る` | ✅ |

---

## 追加検査

| 項目 | 結果 |
|---|---|
| tasks.md 全タスク完了 | 全 35 タスクが `[x]`、未チェック 0。対応表と突き合わせ、**未実装なのにチェック済みの項目はなし**。5.3 の「3 形 → 2 形」と 3.2 の「補正不要」は deviation.md に記録済み |
| 逆流検査 (足場の書き換え) | `specs/` `proposal.md` `design.md` は提案コミット (`868d1f3`) 以降**未変更** (`git status` で差分なし)。`tasks.md` の差分 36 行はチェックボックスのみ — `[x]` を `[ ]` に正規化すると追加行と削除行が完全一致する (本文の追加・削除・書き換えなし)。`ui/brief.md` の差分 18 行は ksn-ui 規約どおりの「実装者による視覚照合」節とトークン候補の追記のみ |
| 未記録乖離 | **なし**。対応表に ❌ は無く、⚠️ 7 件はすべて `deviation.md` に対応する記録がある |
| 付随修正 | `deviation.md` の `[付随修正]` 2 件 (iOS 26 のセル登録準備 / 空配列での初回 snapshot) はいずれも `ios/Sources/KsCollectionView/KsCollectionViewController.swift:245-256` および `:378-383` に実装があり、`KsCollectionEngineTests.test未登録テンプレートキーをsnapshot準備時に検知する` / `.test空の項目でも先頭へのスクロール命令でheaderの先頭へ戻す` が担保している。Scenario にも `[付随修正]` にも対応しない変更は見つからなかった |
| UI 変更 | `ui/brief.md` に承認モック (`ui/mock/variant-a.html` / `ui/mock/approved.png`、2026-09-01 オーナー承認) と 2026-09-02 の最終承認、照合ラウンド 3 周、合意済み妥協 (見た目の妥協なし / 物理 drag のツール制約) が記録済み |
| テスト全件成功 | ライブラリ Debug 60 件 / Release 61 件、Sample UI テスト 3 件 × 5 回 — **すべて 0 failures** |
| 長命層の追随 (参考) | `kasane/handbook/cross/local-development-setup.md` / `test-execution.md` / `runtime-behavior-verification.md` と `kasane/roadmaps/v1-foundation/.../dsl-samples.md`・`phase-3-android-wrapper-foundation/agenda.md` に差分がある。いずれも足場ではなく、tasks 9.1 / 9.2 と deviation (明示形の phase-3 再訪) に対応する追随であり、逆流には当たらない |

---

## 所見 (VALID の判定を妨げないが記録しておく点)

1. **S11.2 (グリッドでは区切り線が出ない) に自動テストがない** — 実装上は `KsCollectionViewController.swift:266-273` の `isList && showsSeparators` と種別変更時の可視セル再構成 (`:111-113`) で構造的に成立し、`ui/verification/fixed-grid-normal.png` でも線が描かれていないことを確認できる。ただし挙動を固定する自動テストはない。verify-002 所見 1 から変化なし。
2. **不正入力の assertion に検証がない** — 0 以下の列数・`minItemWidth`、負のスペーシング (`KsCollectionLayout.swift:38-52`)、重複 ID (`KsSnapshotPlanner.swift:11-14`)、未登録キー (`KsCollectionViewController.swift:250-254`) の debug assertion は、assertion の性質上テストがない。release 側の縮退挙動は Release 実行のテストで担保されている。verify-002 所見 2 から変化なし。
3. **R14 の「タップ追跡中にスクロールが始まったらキャンセル」に対応する Scenario もテストもない** — Requirement 本文の SHALL だが Scenario 化されておらず、実装も `UICollectionView` の標準挙動に委ねている (専用コードなし)。verify-002 所見 3 から変化なし。
4. **性能計測の証跡が 1 本に統合されている** — tasks 8.1 (グループ 4 完了直後の早期計測) と 8.3 (Sample「大量件数」画面での最終計測) が `evidence/performance-early-measurement.md` 1 本に記録されている。記録内容は Sample 完成後の条件であり、8.1 を Sample 完成前に実施したことをアーティファクトから確認する手段はない。verify-002 所見 4 から変化なし。
5. **メモリの絶対値 (Simulator で約 610 MB) の内訳は未解明** — `evidence/performance-early-measurement.md` 自身が「内訳は Simulator の `phys_footprint` からは切り分けられず、実機での再確認は未実施」と記している。Simulator でのメモリ計測は deviation 記録済みで、判定は定常化に限られているため spec との一致は成立するが、実機での絶対値の確認は後続フェーズに残る。
6. **同時 Simulator 使用の脆さ** — 同じ Simulator と同じ Sample スキームで別の `xcodebuild test` が並走すると、XCUITest は互いのアプリ起動を崩して不安定になる。今回の 5 回は並走のない状態で実行している。CI で並列実行する場合は Simulator を分ける必要がある (今回の検証範囲外の運用上の注意)。

---

## 判定

**VALID**

- 15 Requirement / 24 Scenario のすべてが「✅ 一致」(17 件) または「⚠️ deviation 記録済み」(7 件)。❌ は 0 件
- `verify-002.md` の ❌ 2 件はいずれも解消 — S6.1 は走査が可視範囲の半分刻みで全 10,000 件を通過するようになり、判定方法の差は deviation に記録された。S14.3 / S14.1 を担保する Sample UI テストは通常スキームの逐次 5 回実行で全回成功した
- tasks.md の虚偽チェックなし、足場アーティファクト (`specs/` / `proposal.md` / `design.md`) への逆流なし、未記録の乖離なし
- テストは検証者が実行して確認した — ライブラリ Debug 60 件 / Release 61 件、Sample UI テスト 3 件 × 5 回、すべて 0 failures
