# Verify 002: ios-engine-foundation

判定: **INVALID**

- 対象: `specs/collection-core/spec.md` / `specs/collection-layout/spec.md` / `specs/collection-interaction/spec.md` (15 Requirement / 24 Scenario)
- 実装: `ios/Sources/KsCollectionView/`、テスト: `ios/Tests/KsCollectionViewTests/`、Sample: `samples/ios/`
- ❌ (未記録の欠落・乖離 / テスト失敗) **2 件**。⚠️ (deviation 記録済み) 6 件
- 前回 `verify-001.md` (修正サイクル 8 時点、VALID) の所見 4 件のうち 2 件は解消、2 件は未解消。うち 1 件 (Sample UI テストの揺れ) は悪化して ❌ に上がった

行番号は修正サイクル 9 後の現在のファイルに合わせて取り直している (verify-001 の行番号とはずれる)。

---

## テスト実行結果 (検証者が実行)

Simulator: iPhone 17 Pro / iOS 26.5

| 実行 | コマンド (実行ディレクトリ) | 結果 |
|---|---|---|
| ライブラリ Debug | `xcodebuild test -scheme KsCollectionView -configuration Debug` (`ios/`) | **60 tests / 0 failures** — TEST SUCCEEDED |
| ライブラリ Release | 同上 `-configuration Release ENABLE_TESTABILITY=YES` (`ios/`) | **62 tests / 0 failures** — TEST SUCCEEDED (`#if !DEBUG` の 2 件 `KsCollectionEngineTests.testReleaseでは重複IDを後勝ちで解決して表示を継続する` / `KsTemplateRegistryTests.testReleaseでは未登録キーを空セルへ解決する` の実行を個別に確認) |
| Sample UI テスト (1 回目) | `xcodebuild test -scheme KsCollectionViewSamples` (`samples/ios/`) | **TEST FAILED** — `InteractiveControlUITests.test長押し未宣言時は長押し相当の保持でも通常タップを発火する` |
| Sample UI テスト (2 回目) | 同上 | **TEST FAILED** — `InteractiveControlUITests.test長押し宣言時は同一タッチの通常タップを発火しない` |
| Sample UI テスト (3 回目) | 同上 | **TEST FAILED** — `InteractiveControlUITests.test長押し未宣言時は長押し相当の保持でも通常タップを発火する` |
| Sample UI テスト (単体実行) | 同上 + `-only-testing:.../test長押し未宣言時は長押し相当の保持でも通常タップを発火する` | **1 test / 0 failures** — TEST SUCCEEDED |

計測スキーム `KsCollectionViewSamplesPerformance` は性能ドライバのため未実行 (コンテキストパッケージの指示どおり)。通常スキーム `KsCollectionViewSamples` が `PerformanceDriverUITests` を `SkippedTests` で除外していることは scheme ファイルで確認した。

Sample UI テストの失敗はアサーション失敗ではなく、いずれの回も 3 件のうち 1 件でアプリ起動後の要素探索から結果が返らないまま `Restarting after unexpected exit, crash, or test timeout` が起き、そのテストだけが未報告のまま TEST FAILED になる形。詳細は ❌ 2。

---

## 対応表: collection-core

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **R1 プレーンな配列と安定 ID による表示** | `ios/Sources/KsCollectionView/KsCollectionView.swift:12` (Identifiable) / `:29` (`id:` キーパス)、`KsSnapshotPlanner.swift:11` (重複 ID assertion)、`KsCollectionViewController.swift:22` (`AnyHashable` 識別子 + 単一 section) | — | ✅ |
| S1.1 Identifiable 準拠の配列を表示する | `KsCollectionView.swift:12`、`KsCollectionViewController.swift:150` | 件数は `KsSnapshotPlannerTests.testIdentifiable相当の100件を全てsnapshotへ含める` (計画 100 件) と `KsCollectionEngineTests.test100件をdataSourceへ反映する` (`numberOfItems` 100 件)。仮想化 (可視範囲 + 再利用分に留まる) は `KsCollectionEngineTests.test2000件を全件走査しても同時生存セルを可視範囲と再利用プールに留める` (半画面刻みで 2,000 件を往復し、`cellProviderCallCount > 2000` かつ同時生存セル < 400) | ✅ |
| S1.2 非準拠型を `id:` キーパスで表示する | `KsCollectionView.swift:29`、`:38` (`$0[keyPath: id]`) | `KsPublicAPITests.test非Identifiable型をidキーパスで組み立てられる`、`KsCollectionScenarioTests.test非Identifiable型のidキーパスで描画し差分更新のidentityにする`、`KsSnapshotPlannerTests.test非準拠型のキーパス相当IDで順序を構築する` | ✅ |
| **R2 差分更新** | `KsSnapshotPlanner.swift:22-30` (reconfigure / reload 振り分け)、`KsCollectionViewController.swift:324-414` (snapshot 構築と適用) | — | ⚠️ deviation 記録済み (同値配列でも可視セルを再構成 / 同値配列では `id:`・`template:`・登録集合の差し替えを反映しない) |
| S2.1 挿入・削除・移動のアニメーション適用 | `KsCollectionViewController.swift:403` (`animatingDifferences: true`) | `KsSnapshotPlannerTests.test挿入削除移動後の順序を新配列に合わせる`、`KsCollectionEngineTests.test挿入削除並べ替え後に区切り線の位置を再構成する`、`.test挿入時に内容不変の要素のセルプロバイダを再実行しない` (無関係要素の非再描画) | ✅ |
| S2.2 内容変更の再構成 | `KsSnapshotPlanner.swift:25-26` (同一キーは reconfigure)、`KsCollectionViewController.swift:397` | `KsSnapshotPlannerTests.test同一IDかつ同一キーの内容変更は再構成する`、`KsCollectionScenarioTests.test同一IDかつ同一キーの内容変更でセルインスタンスを維持して再描画する` (`cellForItem` 同一性) | ✅ |
| S2.3 テンプレートキー変更でのセル置換 | `KsSnapshotPlanner.swift:27-28` (キー変更は reload)、`KsCollectionViewController.swift:213-232` (キー別 `CellRegistration`)、`:398` | `KsSnapshotPlannerTests.test同一IDでキー変更時はセルを置換する`、`KsCollectionScenarioTests.test同一IDでテンプレートキーが変わるとセルを別テンプレートへ置き換える`、`.testレイアウト切替と同時にテンプレートキーが変わってもセルを置き換える` | ✅ |
| **R3 値キーによるテンプレート切り替え** | `KsCollectionView.swift:47` / `:65` (`template:` セレクタ)、`Template.swift:4`、`KsTemplateBuilder.swift:3`、`KsTemplateRegistry.swift:9`、`KsCollectionViewController.swift:213` (キー → 再利用種別) | — | ⚠️ deviation 記録済み (宣言形が `Template(TemplateDemoKind.message) { (item: TemplateDemoItem) in … }` の明示形。オーナー本意は推論形で phase-3 前に再訪) |
| S3.1 キー値ごとのテンプレート適用 | `KsCollectionView.swift:47`、`KsCollectionViewController.swift:249-254` | `KsTemplateRegistryTests.test値キーごとのテンプレートを登録する`、`KsPublicAPITests.test値キーの複数テンプレートを組み立てられる`、`KsCollectionScenarioTests.test同一IDでテンプレートキーが変わると…` (2 種テンプレートの実描画) | ✅ |
| S3.2 単一テンプレートの軽量形 | `KsCollectionView.swift:12`、`KsTemplateRegistry.swift:21`、`KsSingleTemplateKey.swift:1` | `KsTemplateRegistryTests.test単一テンプレートは専用キーで解決できる`、`KsPublicAPITests.test単一テンプレートと利用者向けmodifierを組み立てられる` | ✅ |
| **R4 未登録キーの挙動** | `KsCollectionViewController.swift:236-247` (snapshot 準備時に検知 + debug assertion)、`KsTemplateRegistry.swift:26-36` (release は空セル + `logger.warning`)、`:15` (最小高 1pt の fallback) | — | ✅ |
| S4.1 release ビルドでの未登録キー | `KsTemplateRegistry.swift:31` | `KsTemplateRegistryTests.testReleaseでは未登録キーを空セルへ解決する` (Release 実行で確認)。件数一致は `KsCollectionEngineTests.test未登録テンプレートキーをsnapshot準備時に検知する` が、未登録キーの要素を snapshot に載せたまま検知することで担保 | ✅ |
| **R5 セル再利用時の状態非保持** | `KsHostingCell.swift:101-109` (`prepareForReuse` で `contentConfiguration = nil`)。ドキュメント: `kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md` の「iOS セル再利用の注意」 | — | ✅ |
| S5.1 スクロール往復での状態初期化 | `KsHostingCell.swift:103` | `KsCollectionScenarioTests.testセルの再利用が起きる距離を往復するとテンプレートのstateは初期値へ戻る` (300 件中 250 番目まで往復し `@State` が初期値へ) | ✅ |
| **R6 大量件数での仮想化・再利用** | `KsCollectionViewController.swift:22` / `:150` (diffable + 再利用)、`:200-211` (同時生存セルの計数)、`samples/ios/KsCollectionViewSamples/DemoData.swift:23` (10,000 件・7 件ごと長文の固定生成)、`samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift` | Requirement 本文の「可視範囲 + 再利用プール分に留まる」「件数に比例して増加しない」は `KsCollectionEngineTests.test2000件を全件走査しても同時生存セルを可視範囲と再利用プールに留める` が担保 | ⚠️ deviation 記録済み (基準機 iPhone 11 → iPhone 15 で代替計測) |
| S6.1 可変行高混在 10,000 件のスクロール | 同上 | hitch は `evidence/performance-early-measurement.md` (iPhone 15、3 試行すべて 0.0 ms/s)。**メモリ側は下記 ❌ 1** | **❌** (hitch 側は ⚠️ deviation 記録済みで合格。メモリ側が未成立) |

## 対応表: collection-layout

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **R7 layout 値による表示形態** | `KsCollectionLayout.swift:17` / `:20` / `:25`、`KsGridColumns.swift:12` / `:17` / `:22`、`KsLayoutMetrics.swift:4`、`KsCollectionViewController.swift:416-469`。不正入力の assertion は `KsCollectionLayout.swift:38-52`、利用可能幅は `KsLayoutMetrics.swift:16-17` + `KsCollectionViewController.swift:420` / `:436` | — | ✅ |
| S7.1 固定列グリッド | `KsLayoutMetrics.swift:11-12`、`KsCollectionViewController.swift:435-448` | `KsLayoutMetricsTests.test固定3列を返す`、`KsCollectionEngineTests.testグリッドからリストへ切替後にスクロールしても全セルが一列になる` (`.fixed(3)` からの切替)。3 列表示は `ui/verification/fixed-grid-normal.png` | ✅ |
| S7.2 adaptive グリッド | `KsLayoutMetrics.swift:15-18`、`KsCollectionViewController.swift:449` (列間固定) | `KsLayoutMetricsTests.testAdaptiveは最小幅を下回らない最大列数を返す`、`KsCollectionEngineTests.testadaptiveの余白列間と項目幅を実レイアウト属性へ反映する` (左右余白 15 / 列間 8 / 幅 ≥120 / 右端 375 を実レイアウト属性で検証) | ✅ |
| S7.3 向き別列数 (コンテナ縦横比基準) | `KsLayoutMetrics.swift:13-14` (`height > width` で判定)、`KsCollectionViewController.swift:429` (`environment.container.effectiveContentSize`)、`:118-126` (寸法変化で `invalidateLayout`) | `KsLayoutMetricsTests.test向き別列数はコンテナ縦横比で切り替える`、`KsCollectionEngineTests.testコンテナ縦横比の変更で縦2列と横4列を再計算する` (window リサイズで再計算)。実機向きは `evidence/orientation-portrait.png` / `evidence/orientation-landscape-left.png` / `evidence/orientation-landscape-right.png` | ⚠️ deviation 記録済み (iPhone Sample の対応向きは portrait / landscape 左右の 3 方向。`portraitUpsideDown` は宣言しない) |
| **R8 レイアウトの動的切り替え** | `KsCollectionViewController.swift:80-116` (layout 差し替えとアンカー捕捉)、`:494` `captureAnchor`、`:516` `restorePendingAnchor`、`:545` `clampedAnchorOffsetFromTop`、`:569` `survivingAnchor` (近傍解決) | — | ✅ |
| S8.1 list とグリッドの切り替え | 同上 | `KsCollectionEngineTests.testリストからグリッドへの切替後も先頭可視要素を表示範囲に残す`、`.testレイアウト切替と同時の先頭側への大量挿入でもアンカーを保つ`、`.testレイアウト切替と同時にアンカーが消えたら近傍要素を表示範囲に残す`、`.testアンカーの高さが大きく縮む切り替えでもアンカーを表示範囲に残す`、`.test深い位置で行間を大きく変えても先頭可視要素を表示範囲に残す`、`.test行間を連続して変えても先頭可視要素が変わらない`、`.testグリッドからリストへ切替後にスクロールしても全セルが一列になる` (表示の乱れがないこと) | ✅ |
| **R9 スペーシング** | `KsCollectionLayout.swift:11-14` (既定 0)、`:20` (`list(rowSpacing:)`)、`:25` (`grid(…, rowSpacing:columnSpacing:)`)、`KsCollectionViewController.swift:449` (列間) / `:452` (行間) | — | ✅ |
| S9.1 グリッドの行間・列間 | 同上 | `KsCollectionEngineTests.testadaptiveの余白列間と項目幅を実レイアウト属性へ反映する` (列間 8 を実属性で検証)、`.test連続するスペーシングと余白変更でレイアウトを作り直さない`、`.test深い位置で行間を大きく変えても先頭可視要素を表示範囲に残す` (行間 40 の反映を実測)。既定 0 は `KsCollectionLayout.swift:37` + `KsPublicAPITests.test単一テンプレートと利用者向けmodifierを組み立てられる` | ✅ |
| **R10 contentPadding** | `KsCollectionView.swift:15` (`EdgeInsets` 4 辺、既定 `EdgeInsets()`)、`KsCollectionViewController.swift:453-458` (`section.contentInsets`)、`:137` (`contentInsetAdjustmentBehavior = .never` — scrollView 側 inset に触れないためインジケータは本体端) | — | ✅ |
| S10.1 内側余白とスクロールインジケータ | 同上 | 余白側は `KsCollectionEngineTests.testadaptiveの余白列間と項目幅を実レイアウト属性へ反映する` (左端 15 / 右端 375)。**インジケータ位置は `KsCollectionEngineTests.test左右の内側余白を変えてもスクロールインジケータをコンポーネント端に保つ` が担保** (余白 40pt / 120pt の 2 条件で項目 `minX` の追従を確認したうえで `contentInset` / `adjustedContentInset` / `verticalScrollIndicatorInsets` がいずれも 0 のまま) — verify-001 所見 1 は解消 | ✅ |
| **R11 list の区切り線** | `KsCollectionViewController.swift:256-271` (`isList && showsSeparators`)、`KsHostingCell.swift:54-64` / `:72-91` / `:135-143`、`KsCollectionView.swift:98` (既定 true) / `:149` (`listSeparators(_:)`) | — | ⚠️ deviation 記録済み 3 件 (左右全幅 + 先頭行 Top、最終行 Bottom、太さ 1pt、色は固定 RGBA `#D9D9DE`) |
| S11.1 既定表示と opt-out | 同上 | `KsCollectionEngineTests.testリスト区切り線を全幅で先頭と行間に表示し即時に切り替える` (表示・全幅・1pt・色・重なり順・ON→OFF→ON を描画差込みで検証)、`.test挿入削除並べ替え後に区切り線の位置を再構成する`、`KsPublicAPITests` (`listSeparators(false)`)。`ui/verification/list-normal.png` / `ui/verification/list-separators-off.png` | ⚠️ (描画範囲の deviation あり。既定表示と opt-out 自体は ✅) |
| S11.2 グリッドでは出ない | `KsCollectionViewController.swift:257-264` (grid では `isList = false`)、`:106-108` (種別変更時に可視セル再構成) | 自動テストなし。`ui/verification/fixed-grid-normal.png` に区切り線が描画されていないことを検証者が画像で確認 (所見 1) | ✅ |
| **R12 ルートヘッダー / フッター** | `KsCollectionView.swift:110` / `:119`、`KsCollectionViewController.swift:172-195` / `:460-467` / `:472-484` (`pinToVisibleBounds` 未設定 = コンテンツと一緒にスクロール)、`KsHostingSupplementaryView.swift` | — | ✅ |
| S12.1 ヘッダーのスクロール追従 | `KsCollectionViewController.swift:472-484` (boundary supplementary の既定非固定) | **`KsCollectionEngineTests.testheaderは下方向のスクロールでコンテンツと一緒に画面外へ出る` が担保** (スクロール後に可視 supplementary が 0 になり、header のコンテンツ座標での frame が変わらず表示範囲と交差しなくなる = pin されていない) — verify-001 所見 2 は解消。併せて `.test表示中のheaderと動的件数footerを更新後に再構成する`、`.test内容不変のheader更新でホスティングビューを維持する`、`.test空の項目でも先頭へのスクロール命令でheaderの先頭へ戻す` | ✅ |
| **R13 セル自己サイズ** | `KsCollectionViewController.swift:435-443` (`.estimated(44)`)、`KsHostingCell.swift` + `UIHostingConfiguration` (`:252`) | — | ⚠️ deviation 記録済み (翻案元の `KsCellViewSupport` / `CustomCellRowPlacement` 相当の補正は不要と判断し実装しない) |
| S13.1 可変行高 | 同上 | `KsCollectionScenarioTests.test本文量の異なる行はそれぞれ必要な高さになる` (本文量に応じた高さ差、同量行の一致、各行高さがホスト内容の fitting size と一致 = 切れ・余白なし) | ✅ |

## 対応表: collection-interaction

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **R14 アイテムタップ / ロングタップ** | `KsCollectionView.swift:128` / `:135` / `:142`、`KsCollectionViewController.swift:684` (`shouldHighlight`: ハンドラ未宣言なら false)、`:692` / `:697` (feedback)、`:701` (`didSelect`)、`:585` / `:602` (長押し)、`:139-146` (`cancelsTouchesInView` / ハンドラ未宣言時は認識器無効)、`:670` (子 control では認識器を通さない)、`KsHostingCell.swift:93` / `:120` (hitTest による操作要素判定)、`:270` (既定 `.systemFill`) | — | ✅ (Requirement 本文の「タップ追跡中にスクロールが始まったらキャンセル」は Scenario 化されておらず、実装も `UICollectionView` 標準挙動に委ねている — 所見 3) |
| S14.1 セル内ボタンとの競合 | `KsHostingCell.swift:93-99`、`KsCollectionViewController.swift:684` / `:701` | `KsCollectionEngineTests.testセル内の操作要素へのタッチではitemTapとfeedbackを発火しない` (セル hitTest 経由で Button action 1 / item tap 0 / feedback 非表示)、Sample UI テスト `InteractiveControlUITests.testセル内Buttonの実座標タップを優先する` (実座標タップ)。`evidence/interactive-control-after-tap.png` | ✅ (Sample UI テスト側の実行安定性は ❌ 2) |
| S14.2 タップで型付き要素が渡る | `KsCollectionViewController.swift:701-714`、`:692` | `KsCollectionEngineTests.test選択時に型付き項目を通知する`、`.test不透明な内容の上へ指定色のtouchFeedbackを表示して消す` (描画差で表示・消失)、`.test既定のtouchFeedbackは半透明でセル内容を隠さない`、`.testtouchFeedback色の変更を可視セルへ反映する` | ✅ |
| S14.3 ロングタップ | `KsCollectionViewController.swift:585-610`、`:96` / `:144` | `KsCollectionEngineTests.testロングタップ未宣言のときは長押し認識器を無効にする`、`.test長押し成立後の別タッチによる通常タップを抑止しない`。排他そのもの (long tap 1 / tap 0) は Sample UI テスト `InteractiveControlUITests.test長押し宣言時は同一タッチの通常タップを発火しない` / `.test長押し未宣言時は長押し相当の保持でも通常タップを発火する` だけが担保しており、**この 2 件が連続実行で緑にならない (❌ 2)** | **❌** (Scenario を担保するテストが安定して成功しない) |
| **R15 スクロール制御** | `KsScrollController.swift:5` (`@MainActor`)、`:13` / `:22` / `:27`、`:31-38` (最後の接続のみ有効 + debug 警告)、`:40` (detach)、`KsScrollPosition.swift`、`KsCollectionViewController.swift:612-643` (実行)、`:645` (flush)、`:718-729` (受信キュー)、`:403-413` (apply 完了後に flush) | — | ✅ |
| S15.1 存在しない ID への命令 | `KsCollectionViewController.swift:615-620` (no-op + debug 警告ログ) | `KsCollectionScenarioTests.test接続済みでも存在しないIDへのスクロール命令では表示位置が変わらない` (offset 不変 + 後続の有効命令が到達) | ✅ |
| S15.2 ID 指定スクロール | `KsCollectionViewController.swift:614-626`、`:732-739` (`.center` → `.centeredVertically`) | `KsCollectionScenarioTests.test表示範囲外の要素へのcenter指定スクロールでその要素が中央に来る` (frame 中心 ≈ 表示範囲中心、誤差 2) | ✅ |
| S15.3 データ反映後のスクロール実行 | `KsCollectionViewController.swift:720` (適用中はキュー)、`:409` (重ね掛け分がすべて反映されてから flush) | `KsCollectionEngineTests.testデータ追加と同一処理の末尾命令を最後のsnapshot後に実行する`、`.test同一配列の再適用でも保留中のスクロール命令を実行する`、`.test空の項目でも先頭へのスクロール命令でheaderの先頭へ戻す`、`KsSwiftUIIntegrationTests.testState更新と同一Button処理の末尾命令が新snapshotへ到達する` (`UIHostingController` 上) | ✅ |
| S15.4 未接続 no-op | `KsScrollController.swift:7` (weak receiver、nil なら何もしない)、`:40` (detach)、`KsCollectionRepresentable.swift:17-22` (dismantle 時に disconnect) | `KsScrollControllerTests.test未接続命令は何も起こさない`、`.test最後に接続したReceiverだけが命令を受け取る` | ✅ |

---

## ❌ 1: S6.1 のメモリ判定が成立していない (往復手順と測定値の両方)

Scenario の THEN: 「リスト全体の 1 往復スクロール後のメモリ使用量を基準に、さらに 1 往復してもメモリが増え続けない (再利用プール分で定常化する)」。

**(a) 往復手順が「全項目を通過する走査」になっていない。**

`samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:58` の `traversalStride = 200` は、`scrollTo(id:position:.start, animated: false)` で 200 件ごとのチェックポイントへ跳ぶ。この画面の可視範囲を検証者が実測したところ **1 画面あたり 22 件** (iPhone 17 Pro Simulator / iOS 26.5、2 列グリッド、Item 1〜22 が同時表示)。したがって 1 チェックポイントで実際にセルが作られるのは 200 件のうち 20〜30 件程度で、残り 85% 前後は一度もセル化されないまま次のチェックポイントへ跳ぶ。

これにより `evidence/performance-early-measurement.md` の次の記述が成り立たない:

- 「各段階でレイアウトを確定させ、通過した範囲のセルを実際に生成させる」— 通過した範囲のうち可視 1 画面分しか生成されない
- 「1 往復あたり 20,000 回の項目通過が起きるのに対し…」— 実際の項目通過 (セル生成) は 51 チェックポイント × 約 22 件 × 2 方向 ≒ 2,200 回程度で、比例増加を否定する根拠の分母が 1 桁近く過大

`deviation.md` の記録も「全項目を通過する走査での再計測は Simulator で行う」であり、**Simulator への環境変更は合意済みだが、走査が全項目を通過しないことは記録がない**。

なお、正しい刻みの条件は実装側の統合テストが自分で書いている: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:630` の `test2000件を全件走査しても同時生存セルを可視範囲と再利用プールに留める` は `step: bounds.height / 2` (半画面刻み) を使い、コメントに「前後の可視範囲が十分に重ならない刻みでは、UIKit は再利用ではなく作り直しになる」と明記している。Sample 側の 200 件刻みは可視範囲の約 9 倍で、この条件から外れている。

**(b) 記録された測定値が「定常化」を示していない。**

`evidence/performance-early-measurement.md` の 5 往復の記録は、実行 1 が 61,688,736 → 72,993,720 bytes (+18%)、実行 2 が 73,731,000 → 75,959,224 bytes (+3%) で、**両実行とも往復ごとに単調増加**しており横ばいに達していない。evidence 自身も「完全な横ばいにもならず、往復を重ねるとわずかに増える」「Simulator の計測では原因を切り分けられない」「基準機相当の実機での再確認は未実施」と書いている。

検証者による再現 (同じ `--verify-performance` 画面、**Debug 構成**のため絶対値は evidence の Release 値と比較できない、iPhone 17 Pro Simulator / iOS 26.5):

| 往復 | `phys_footprint` |
|---|---:|
| 1 往復後 | 58,280,264 bytes |
| 2 往復後 | 72,255,816 bytes (+24%) |

Scenario が求める「1 往復後を基準にさらに 1 往復しても増え続けない」に対し、2 往復目で +24% だった。

**見立て** (決定は呼び出し元とユーザー):

- 実装 (計測ハーネス) を直す案: `traversalStride` を可視範囲相当 (半画面刻み) に是正し、Release 構成で計り直す。統合テストと同じ刻みなら「全項目を通過する」記述と測定値の両方が spec の THEN と整合しうる
- deviation として合意する案: S6.1 のメモリ判定を「件数に比例した増加が起きないこと」に緩め、往復の刻み (200 件) と定常化に達しないことを deviation.md に明記する。この場合 evidence 側の「20,000 回の項目通過」「通過した範囲のセルを実際に生成させる」の記述も実態に合わせて訂正が要る

補足: R6 の Requirement 本文が定める「生成されるセルは可視範囲 + 再利用プール分に留まり、メモリ使用量が件数に比例して増加してはならない」自体は `KsCollectionEngineTests.test2000件を全件走査しても同時生存セルを可視範囲と再利用プールに留める` が半画面刻みの全件走査で担保している (同時生存セル < 400、`cellProviderCallCount > 2000`)。未成立なのは S6.1 のメモリ往復の THEN に限る。hitch time ratio の側は 3 試行すべて 0.0 ms/s で、基準機の代替は deviation 記録済み。

## ❌ 2: Sample UI テストが 3 回連続で TEST FAILED (S14.3 / S14.1 の担保が不安定)

`samples/ios/` の通常スキーム `KsCollectionViewSamples` を 3 回実行し、**3 回とも TEST FAILED**。毎回 `InteractiveControlUITests` の 3 件のうち 1 件が、アプリ起動直後の要素探索 (`longPress.declaresLongTap` の label 待ち) から戻らないまま `Restarting after unexpected exit, crash, or test timeout` に至り、そのテストだけ未報告で失敗扱いになる。失敗するテストは回ごとに入れ替わる (1・3 回目は `test長押し未宣言時は…`、2 回目は `test長押し宣言時は…`)。アサーション失敗の出力はない。

同じテストを `-only-testing` で単体実行すると成功する (8.262 秒)。つまり 1 テスト単位の挙動ではなく、同一スキーム内で `LongPressVerificationView` を使う検証画面をアプリ再起動しながら連続実行する経路が安定していない。

影響: S14.3 (ロングタップの排他) を担保するのはこの 2 件だけで、ライブラリ側の単体・統合テストには「長押しが成立したタッチでは `onItemTap` を発火しない」を実タッチで確かめるものがない (`KsCollectionEngineTests` にあるのは認識器の有効/無効と、長押し成立後の**別**タッチの扱い)。S14.1 も実座標タップの確認はこのスイートの 1 件が担っている。

verify-001 の所見 4 (3 回中 1 回失敗) と同じ現象で、修正サイクル 9 でも解消していない。今回は 3/3 で失敗しており、「たまに揺れる」ではなく「通しでは緑にならない」状態のため所見ではなく ❌ とした。

**見立て**: 仕様との乖離ではないため、実装 (UI テスト側) を直す案が妥当。検証画面ごとにアプリの終了完了を待ってから次を起動する、検証画面を 1 起動内で切り替えられるようにして再起動回数を減らす、などが候補。deviation として合意する場合は「Sample UI テストは単体実行でのみ緑」を明記することになるが、CI で回らない状態を許すことになる。

参考: 検証環境では別の Simulator (iPhone 17 Pro / iOS 26.0) も同時に起動状態だった。XCUITest の起動安定性に影響しうるが、切り分けは行っていない。

---

## 追加検査

| 項目 | 結果 |
|---|---|
| tasks.md 全タスク完了 | 全 30 タスクが `[x]`。対応表と突き合わせ、**未実装なのにチェック済みの項目はなし**。5.3 の「3 形 → 2 形」と 3.2 の「補正不要」は deviation.md に記録済み |
| 逆流検査 (足場の書き換え) | `specs/` `proposal.md` `design.md` は提案コミット 868d1f3 以降**未変更**。`tasks.md` の差分 (35 行) はチェックボックスのみで、`[x]` を `[ ]` に正規化すると追加行と削除行が完全一致する (本文の追加・削除・書き換えなし)。`ui/brief.md` の差分は ksn-ui 規約どおりの「実装者による視覚照合」節とトークン候補の追記のみ |
| 未記録乖離 | ❌ 1 の (a) が該当 — 「往復が全項目を通過しない」ことは deviation.md に記録がない (Simulator 計測への変更は記録済み)。❌ 2 は乖離ではなくテスト失敗 |
| 付随修正 | deviation.md の `[付随修正]` 2 件 (iOS 26 のセル登録準備 / 空配列での初回 snapshot) はいずれも `ios/Sources/KsCollectionView/KsCollectionViewController.swift:236-247` および `:369-374` に実装があり、`KsCollectionEngineTests.test未登録テンプレートキーをsnapshot準備時に検知する` / `.test空の項目でも先頭へのスクロール命令でheaderの先頭へ戻す` で担保されている。Scenario にも `[付随修正]` にも対応しない変更は見つからなかった |
| UI 変更 | `ui/brief.md` に承認モック (`ui/mock/variant-a.html` / `ui/mock/approved.png`、2026-09-01 オーナー承認) と 2026-09-02 の最終承認、照合ラウンド 3 周、合意済み妥協 (見た目の妥協なし / 物理 drag のツール制約) が記録済み |
| テスト全件成功 | ライブラリ Debug 60 件・Release 62 件はいずれも 0 failures。**Sample UI テストは 3 回中 3 回 TEST FAILED** (❌ 2) |

---

## 所見 (INVALID の理由ではないが記録しておく点)

1. **S11.2 (グリッドでは区切り線が出ない) に自動テストがない** — 実装上は `KsCollectionViewController.swift:264` の `isList && showsSeparators` と種別変更時の可視セル再構成 (`:106-108`) で構造的に成立し、`ui/verification/fixed-grid-normal.png` でも線が描かれていないことを確認できる。ただし挙動を固定する自動テストはない。
2. **不正入力の assertion に検証がない** — 0 以下の列数・`minItemWidth`、負のスペーシング (`KsCollectionLayout.swift:38-52`)、重複 ID (`KsSnapshotPlanner.swift:11`)、未登録キー (`KsCollectionViewController.swift:242`) の debug assertion は、assertion の性質上テストがない。release 側の縮退挙動は Release 実行のテストで担保されている。
3. **R14 の「タップ追跡中にスクロールが始まったらキャンセル」に対応する Scenario もテストもない** — Requirement 本文の SHALL だが Scenario 化されておらず、実装も `UICollectionView` の標準挙動に委ねている (専用コードなし)。verify-001 所見 6 から変化なし。
4. **性能計測の証跡が 1 本に統合されている** — tasks 8.1 (グループ 4 完了直後の早期計測) と 8.3 (Sample「大量件数」画面での最終計測) が `evidence/performance-early-measurement.md` 1 本に記録されている。記録内容は Sample 完成後の条件であり、8.1 を Sample 完成前に実施したことをアーティファクトから確認する手段はない。verify-001 所見 5 から変化なし。
5. **verify-001 の所見 1・2 は解消** — S10.1 のスクロールインジケータ位置と S12.1 のヘッダー追従に、それぞれ直接観測する統合テストが追加された (対応表参照)。

---

## 判定

**INVALID** — ❌ 2 件。

1. **S6.1 (collection-core / 大量件数での仮想化・再利用)**: メモリの往復計測が Scenario の「リスト全体の 1 往復」になっておらず (可視 22 件に対し 200 件刻み)、記録値も 5 往復すべて単調増加で「定常化」を示していない。走査が全項目を通過しないことは deviation.md に記録がない。
2. **S14.3 (collection-interaction / ロングタップ)**: Scenario を担保する Sample UI テストが 3 回連続で TEST FAILED (単体実行では成功)。S14.1 の実座標タップ検証も同じスイートに含まれる。

それ以外の 13 Requirement / 22 Scenario は「✅ 一致」または「⚠️ deviation 記録済み」。tasks.md の虚偽チェックなし、足場アーティファクトへの逆流なし、ライブラリのテスト (Debug 60 件 / Release 62 件) はいずれも成功を確認した。
