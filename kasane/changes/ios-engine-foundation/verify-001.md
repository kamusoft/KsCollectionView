# Verify 001: ios-engine-foundation

判定: **VALID**

- 対象: `specs/collection-core/spec.md` / `specs/collection-layout/spec.md` / `specs/collection-interaction/spec.md` (15 Requirement / 24 Scenario)
- 実装: `ios/Sources/KsCollectionView/`、テスト: `ios/Tests/KsCollectionViewTests/`、Sample: `samples/ios/`
- ❌ (未記録の欠落・乖離) 0 件。⚠️ (deviation 記録済み) 6 件

---

## テスト実行結果 (検証者が実行)

Simulator: iPhone 17 Pro / iOS 26.5

| 実行 | コマンド | 結果 |
|---|---|---|
| ライブラリ Debug | `xcodebuild test -scheme KsCollectionView -configuration Debug` (`ios/`) | **56 tests / 0 failures** — TEST SUCCEEDED |
| ライブラリ Release | 同上 `-configuration Release ENABLE_TESTABILITY=YES` | **58 tests / 0 failures** — TEST SUCCEEDED (`#if !DEBUG` の 2 件 `testReleaseでは重複IDを後勝ちで解決して表示を継続する` / `testReleaseでは未登録キーを空セルへ解決する` を含む) |
| Sample UI テスト | `xcodebuild test -scheme KsCollectionViewSamples` (`samples/ios/`) | 3 回実行し **2 回は 3 tests / 0 failures**、1 回目のみ TEST FAILED (下記「所見 4」) |

計測スキーム `KsCollectionViewSamplesPerformance` は性能ドライバのため未実行 (コンテキストパッケージの指示どおり)。

---

## 対応表: collection-core

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **R1 プレーンな配列と安定 ID による表示** | `ios/Sources/KsCollectionView/KsCollectionView.swift:12` (Identifiable) / `:29` (`id:` キーパス)、`KsSnapshotPlanner.swift:11` (重複 ID assertion)、`KsCollectionViewController.swift:127` (`AnyHashable` 識別子 + 単一 section) | — | ✅ |
| S1.1 Identifiable 準拠の配列を表示する | `KsCollectionView.swift:12`、`KsCollectionViewController.swift:285` | `KsSnapshotPlannerTests.testIdentifiable相当の100件を全てsnapshotへ含める` (計画 100 件)、`KsCollectionEngineTests.test100件をdataSourceへ反映する` (data source 100 件)、仮想化は `KsCollectionScenarioTests.testセルの再利用が起きる距離を往復すると…` (300 件で再利用発生) と `evidence/performance-early-measurement.md` (10,000 件でメモリ定常化) | ✅ |
| S1.2 非準拠型を `id:` キーパスで表示する | `KsCollectionView.swift:29`、`:38` (`$0[keyPath: id]`) | `KsPublicAPITests.test非Identifiable型をidキーパスで組み立てられる`、`KsCollectionScenarioTests.test非Identifiable型のidキーパスで描画し差分更新のidentityにする`、`KsSnapshotPlannerTests.test非準拠型のキーパス相当IDで順序を構築する` | ✅ |
| **R2 差分更新** | `KsSnapshotPlanner.swift:4-37` (reconfigure / reload 振り分け)、`KsCollectionViewController.swift:344-374` (snapshot 構築と適用) | — | ⚠️ deviation 記録済み (同値配列でも可視セルを再構成 / 同値配列では `id:`・`template:`・登録集合の差し替えを反映しない) |
| S2.1 挿入・削除・移動のアニメーション適用 | `KsCollectionViewController.swift:364` (`animatingDifferences: true`) | `KsSnapshotPlannerTests.test挿入削除移動後の順序を新配列に合わせる`、`KsCollectionEngineTests.test挿入削除並べ替え後に区切り線の位置を再構成する`、`.test挿入時に内容不変の要素のセルプロバイダを再実行しない` (無関係要素の非再描画) | ✅ |
| S2.2 内容変更の再構成 | `KsSnapshotPlanner.swift:25` (同一キーは reconfigure) | `KsSnapshotPlannerTests.test同一IDかつ同一キーの内容変更は再構成する`、`KsCollectionScenarioTests.test同一IDかつ同一キーの内容変更でセルインスタンスを維持して再描画する` (`cellForItem` 同一性) | ✅ |
| S2.3 テンプレートキー変更でのセル置換 | `KsSnapshotPlanner.swift:27` (キー変更は reload)、`KsCollectionViewController.swift:174` (キー別 `CellRegistration`) | `KsSnapshotPlannerTests.test同一IDでキー変更時はセルを置換する`、`KsCollectionScenarioTests.test同一IDでテンプレートキーが変わるとセルを別テンプレートへ置き換える`、`.testレイアウト切替と同時にテンプレートキーが変わってもセルを置き換える` | ✅ |
| **R3 値キーによるテンプレート切り替え** | `KsCollectionView.swift:47` / `:65` (`template:` セレクタ)、`Template.swift:4`、`KsTemplateBuilder.swift:2`、`KsTemplateRegistry.swift:9`、`KsCollectionViewController.swift:174` (キー → 再利用種別) | — | ⚠️ deviation 記録済み (宣言形が `Template(TemplateDemoKind.message) { (item: TemplateDemoItem) in … }` の明示形。オーナー本意は推論形で phase-3 前に再訪) |
| S3.1 キー値ごとのテンプレート適用 | `KsCollectionView.swift:47`、`KsCollectionViewController.swift:210` | `KsTemplateRegistryTests.test値キーごとのテンプレートを登録する`、`KsPublicAPITests.test値キーの複数テンプレートを組み立てられる`、`KsCollectionScenarioTests.test同一IDでテンプレートキーが変わると…` (2 種テンプレートの実描画) | ✅ |
| S3.2 単一テンプレートの軽量形 | `KsCollectionView.swift:12`、`KsTemplateRegistry.swift:21`、`KsSingleTemplateKey.swift:1` | `KsTemplateRegistryTests.test単一テンプレートは専用キーで解決できる`、`KsPublicAPITests.test単一テンプレートと利用者向けmodifierを組み立てられる` | ✅ |
| **R4 未登録キーの挙動** | `KsCollectionViewController.swift:197` (snapshot 準備時に検知 + debug assertion)、`KsTemplateRegistry.swift:26-36` (release は空セル + `logger.warning`)、`:15` (最小高 1pt の fallback) | — | ✅ |
| S4.1 release ビルドでの未登録キー | `KsTemplateRegistry.swift:31` | `KsTemplateRegistryTests.testReleaseでは未登録キーを空セルへ解決する` (Release 実行で確認)。件数一致は `KsCollectionEngineTests.test未登録テンプレートキーをsnapshot準備時に検知する` が snapshot に載ったまま検知することで担保 | ✅ |
| **R5 セル再利用時の状態非保持** | `KsHostingCell.swift:101` (`prepareForReuse` で `contentConfiguration = nil`)。ドキュメント: `kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md:390`「iOS セル再利用の注意」 | — | ✅ |
| S5.1 スクロール往復での状態初期化 | `KsHostingCell.swift:101` | `KsCollectionScenarioTests.testセルの再利用が起きる距離を往復するとテンプレートのstateは初期値へ戻る` (300 件中 250 番目まで往復し `@State` が初期値へ) | ✅ |
| **R6 大量件数での仮想化・再利用** | `KsCollectionViewController.swift:127` (diffable + 再利用)、`samples/ios/KsCollectionViewSamples/DemoData.swift:23` (10,000 件・7 件ごと長文の固定生成)、`samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift` | — | ⚠️ deviation 記録済み (基準機 iPhone 11 → iPhone 15 で代替計測) |
| S6.1 可変行高混在 10,000 件のスクロール | 同上 | 自動テストなし。`evidence/performance-early-measurement.md`: hitch time ratio 3 試行すべて 0.0 ms/s (基準 5 ms/s 未満)、メモリ 1 往復 35,373,904 → 2 往復 27,640,656 bytes で増加なし | ⚠️ (計測機の deviation 記録済み。基準値そのものは合格) |

## 対応表: collection-layout

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **R7 layout 値による表示形態** | `KsCollectionLayout.swift:17/20/25`、`KsGridColumns.swift:12/17/22`、`KsLayoutMetrics.swift:4`、`KsCollectionViewController.swift:377-419`。不正入力の assertion は `KsCollectionLayout.swift:38-52`、利用可能幅は `KsLayoutMetrics.swift:16-17` + `KsCollectionViewController.swift:414` | — | ✅ |
| S7.1 固定列グリッド | `KsLayoutMetrics.swift:11-12`、`KsCollectionViewController.swift:396-409` | `KsLayoutMetricsTests.test固定3列を返す`、`KsCollectionEngineTests.testグリッドからリストへ切替後にスクロールしても全セルが一列になる` (`.fixed(3)` からの切替)。3 列表示は `ui/verification/fixed-grid-normal.png` | ✅ |
| S7.2 adaptive グリッド | `KsLayoutMetrics.swift:15-18`、`KsCollectionViewController.swift:410` (列間固定) | `KsLayoutMetricsTests.testAdaptiveは最小幅を下回らない最大列数を返す`、`KsCollectionEngineTests.testadaptiveの余白列間と項目幅を実レイアウト属性へ反映する` (左右余白 15 / 列間 8 / 幅 ≥120 / 右端 375 を実属性で検証) | ✅ |
| S7.3 向き別列数 (コンテナ縦横比基準) | `KsLayoutMetrics.swift:13-14` (`height > width` で判定)、`KsCollectionViewController.swift:390` (`environment.container.effectiveContentSize`)、`:95-103` (寸法変化で `invalidateLayout`) | `KsLayoutMetricsTests.test向き別列数はコンテナ縦横比で切り替える`、`KsCollectionEngineTests.testコンテナ縦横比の変更で縦2列と横4列を再計算する` (window リサイズで再計算)。実機向きは `evidence/orientation-portrait.png` / `orientation-landscape-left.png` / `orientation-landscape-right.png` | ⚠️ deviation 記録済み (iPhone Sample の対応向きは portrait / landscape 左右の 3 方向。`portraitUpsideDown` は宣言しない) |
| **R8 レイアウトの動的切り替え** | `KsCollectionViewController.swift:57-93` (layout 差し替えとアンカー捕捉)、`:455` `captureAnchor`、`:477` `restorePendingAnchor`、`:513` `survivingAnchor` (近傍解決) | — | ✅ |
| S8.1 list とグリッドの切り替え | 同上 | `KsCollectionEngineTests.testリストからグリッドへの切替後も先頭可視要素を表示範囲に残す`、`.testレイアウト切替と同時の先頭側への大量挿入でもアンカーを保つ`、`.testレイアウト切替と同時にアンカーが消えたら近傍要素を表示範囲に残す`、`.test深い位置で行間を大きく変えても…`、`.test行間を連続して変えても…`、`.testグリッドからリストへ切替後にスクロールしても全セルが一列になる` (表示の乱れがないこと) | ✅ |
| **R9 スペーシング** | `KsCollectionLayout.swift:11-14` (既定 0)、`:20` (`list(rowSpacing:)`)、`:25` (`grid(…, rowSpacing:columnSpacing:)`)、`KsCollectionViewController.swift:410` (列間) / `:413` (行間) | — | ✅ |
| S9.1 グリッドの行間・列間 | 同上 | `KsCollectionEngineTests.testadaptiveの余白列間と項目幅を実レイアウト属性へ反映する` (列間 8 を実属性で検証)、`.test連続するスペーシングと余白変更でレイアウトを作り直さない`、`.test深い位置で行間を大きく変えても先頭可視要素を表示範囲に残す` (行間 40 の反映を実測)。既定 0 は `KsCollectionLayout.swift:37` + `KsPublicAPITests.test単一テンプレートと利用者向けmodifierを組み立てられる` | ✅ |
| **R10 contentPadding** | `KsCollectionView.swift:15` (`EdgeInsets` 4 辺、既定 `EdgeInsets()`)、`KsCollectionViewController.swift:414-419` (`section.contentInsets`)、`:114` (`contentInsetAdjustmentBehavior = .never` — scrollView 側 inset に触れないためインジケータは本体端) | — | ✅ |
| S10.1 内側余白とスクロールインジケータ | 同上 | 余白側は `KsCollectionEngineTests.testadaptiveの余白列間と項目幅を実レイアウト属性へ反映する` (左端 15 / 右端 375)。インジケータ位置の観測は自動・手動とも記録なし (所見 1) | ✅ |
| **R11 list の区切り線** | `KsCollectionViewController.swift:217-232` (`isList && showsSeparators`)、`KsHostingCell.swift:54-64` / `:72-91` / `:135`、`KsCollectionView.swift:98` (既定 true) / `:149` (`listSeparators(_:)`) | — | ⚠️ deviation 記録済み 3 件 (左右全幅 + 先頭行 Top、最終行 Bottom、太さ 1pt、色は固定 RGBA `#D9D9DE`) |
| S11.1 既定表示と opt-out | 同上 | `KsCollectionEngineTests.testリスト区切り線を全幅で先頭と行間に表示し即時に切り替える` (表示・全幅・1pt・色・重なり順・ON→OFF→ON を描画差込みで検証)、`.test挿入削除並べ替え後に区切り線の位置を再構成する`、`KsPublicAPITests` (`listSeparators(false)`)。`ui/verification/list-normal.png` / `list-separators-off.png` | ⚠️ (描画範囲の deviation あり。既定表示と opt-out 自体は ✅) |
| S11.2 グリッドでは出ない | `KsCollectionViewController.swift:218-225` (grid では `isList = false`)、`:83` (種別変更時に可視セル再構成) | 自動テストなし。`ui/verification/fixed-grid-normal.png` で区切り線が描画されていないことを確認 (検証者が画像を確認) | ✅ |
| **R12 ルートヘッダー / フッター** | `KsCollectionView.swift:110` / `:119`、`KsCollectionViewController.swift:148-171` / `:421-428` / `:433-445` (`pinToVisibleBounds` 未設定 = コンテンツと一緒にスクロール)、`KsHostingSupplementaryView.swift` | — | ✅ |
| S12.1 ヘッダーのスクロール追従 | `KsCollectionViewController.swift:433` (boundary supplementary の既定非固定) | `KsCollectionEngineTests.test表示中のheaderと動的件数footerを更新後に再構成する`、`.test内容不変のheader更新でホスティングビューを維持する`、`.test空の項目でも先頭へのスクロール命令でheaderの先頭へ戻す` (header がスクロール領域内にあることを contentSize/offset で観測)。追従そのものの直接観測は記録なし (所見 2) | ✅ |
| **R13 セル自己サイズ** | `KsCollectionViewController.swift:396-404` (`.estimated(44)`)、`KsHostingCell.swift` + `UIHostingConfiguration` (`:213`) | — | ⚠️ deviation 記録済み (翻案元の `KsCellViewSupport` / `CustomCellRowPlacement` 相当の補正は不要と判断し実装しない) |
| S13.1 可変行高 | 同上 | `KsCollectionScenarioTests.test本文量の異なる行はそれぞれ必要な高さになる` (本文量に応じた高さ差、同量行の一致、各行高さがホスト内容の fitting size と一致 = 切れ・余白なし) | ✅ |

## 対応表: collection-interaction

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **R14 アイテムタップ / ロングタップ** | `KsCollectionView.swift:128` / `:135` / `:142`、`KsCollectionViewController.swift:625` (`shouldHighlight`: ハンドラ未宣言なら false)、`:633`/`:638` (feedback)、`:642` (`didSelect`)、`:528`/`:546` (長押し)、`:116-123` (`cancelsTouchesInView` / ハンドラ未宣言時は認識器無効)、`:611` (子 control では認識器を通さない)、`KsHostingCell.swift:93`/`:120` (hitTest による操作要素判定)、`:111` (既定 `.systemFill`) | — | ✅ |
| S14.1 セル内ボタンとの競合 | `KsHostingCell.swift:93`、`KsCollectionViewController.swift:625`/`:642` | `KsCollectionEngineTests.testセル内の操作要素へのタッチではitemTapとfeedbackを発火しない` (セル hitTest 経由で Button action 1 / item tap 0 / feedback 非表示)、Sample UI テスト `InteractiveControlUITests.testセル内Buttonの実座標タップを優先する` (実座標タップ)。`evidence/interactive-control-after-tap.png` | ✅ |
| S14.2 タップで型付き要素が渡る | `KsCollectionViewController.swift:642-655`、`:633` | `KsCollectionEngineTests.test選択時に型付き項目を通知する`、`.test不透明な内容の上へ指定色のtouchFeedbackを表示して消す` (描画差で表示・消失)、`.test既定のtouchFeedbackは半透明でセル内容を隠さない`、`.testtouchFeedback色の変更を可視セルへ反映する` | ✅ |
| S14.3 ロングタップ | `KsCollectionViewController.swift:528-554`、`:73`/`:121` | Sample UI テスト `InteractiveControlUITests.test長押し宣言時は同一タッチの通常タップを発火しない` (long tap 1 / tap 0)、`.test長押し未宣言時は長押し相当の保持でも通常タップを発火する`、`KsCollectionEngineTests.testロングタップ未宣言のときは長押し認識器を無効にする`、`.test長押し成立後の別タッチによる通常タップを抑止しない` | ✅ |
| **R15 スクロール制御** | `KsScrollController.swift:6` (`@MainActor`)、`:13`/`:22`/`:27`、`:31` (最後の接続のみ有効 + debug 警告)、`:40` (detach)、`KsScrollPosition.swift`、`KsCollectionViewController.swift:556-587` (実行)、`:589` (flush)、`:658-670` (受信キュー)、`:364-374` (apply 完了後に flush) | — | ✅ |
| S15.1 存在しない ID への命令 | `KsCollectionViewController.swift:559-563` (no-op + debug 警告ログ) | `KsCollectionScenarioTests.test接続済みでも存在しないIDへのスクロール命令では表示位置が変わらない` (offset 不変 + 後続の有効命令が到達) | ✅ |
| S15.2 ID 指定スクロール | `KsCollectionViewController.swift:558-570`、`:673-680` (`.center` → `.centeredVertically`) | `KsCollectionScenarioTests.test表示範囲外の要素へのcenter指定スクロールでその要素が中央に来る` (frame 中心 ≈ 表示範囲中心、誤差 2) | ✅ |
| S15.3 データ反映後のスクロール実行 | `KsCollectionViewController.swift:661` (適用中はキュー)、`:370` (重ね掛け分がすべて反映されてから flush) | `KsCollectionEngineTests.testデータ追加と同一処理の末尾命令を最後のsnapshot後に実行する`、`.test同一配列の再適用でも保留中のスクロール命令を実行する`、`.test空の項目でも先頭へのスクロール命令でheaderの先頭へ戻す`、`KsSwiftUIIntegrationTests.testState更新と同一Button処理の末尾命令が新snapshotへ到達する` (`UIHostingController` 上) | ✅ |
| S15.4 未接続 no-op | `KsScrollController.swift:7` (weak receiver、nil なら何もしない)、`:40` (detach)、`KsCollectionRepresentable.swift:17` (dismantle 時に disconnect) | `KsScrollControllerTests.test未接続命令は何も起こさない`、`.test最後に接続したReceiverだけが命令を受け取る` | ✅ |

---

## 追加検査

| 項目 | 結果 |
|---|---|
| tasks.md 全タスク完了 | 全 30 タスクが `[x]`。対応表と突き合わせ、**未実装なのにチェック済みの項目はなし**。5.3 の「3 形 → 2 形」と 3.2 の「補正不要」は deviation.md に記録済み |
| 逆流検査 (足場の書き換え) | `specs/` `proposal.md` `design.md` は提案コミット 868d1f3 以降**未変更** (作業ツリーに差分なし)。`tasks.md` の差分はチェックボックスのみ (本文の追加・削除・書き換えなし)。`ui/brief.md` の差分は ksn-ui 規約どおりの「実装者による視覚照合」記録 |
| 未記録乖離 | ❌ が 0 件のため該当なし |
| 付随修正 | deviation.md の `[付随修正]` 2 件 (iOS 26 のセル登録準備 / 空配列での初回 snapshot) はいずれも `KsCollectionViewController.swift:197` および `:330-335` に実装があり、`KsCollectionEngineTests.test未登録テンプレートキーをsnapshot準備時に検知する` / `.test空の項目でも先頭へのスクロール命令でheaderの先頭へ戻す` で担保されている。diff にあって Scenario にも `[付随修正]` にも対応しない変更は見つからなかった |
| UI 変更 | `ui/brief.md` に承認モック (`mock/variant-a.html` / `approved.png`、2026-09-01 オーナー承認) と 2026-09-02 の最終承認、照合ラウンド 3 周、合意済み妥協 (見た目の妥協なし / 物理 drag のツール制約) が記録済み |
| テスト全件成功 | ライブラリ Debug 56 件・Release 58 件はいずれも 0 failures。Sample UI テストは 3 回中 2 回が 0 failures、1 回は下記所見 4 |

---

## 所見 (INVALID ではないが記録しておく点)

1. **S10.1 のスクロールインジケータ位置に観測記録がない** — `contentPadding` は `section.contentInsets` にだけ適用され (`KsCollectionViewController.swift:414`)、`collectionView.contentInset` / `scrollIndicatorInsets` には触れず `contentInsetAdjustmentBehavior = .never` (`:114`) のため、構造上インジケータは本体端に出る。ただし自動テストも手動観測の記録もない。
2. **S12.1 のヘッダーのスクロール追従に直接の観測記録がない** — `NSCollectionLayoutBoundarySupplementaryItem` の `pinToVisibleBounds` を設定していない (既定 false) ため構造上コンテンツと一緒にスクロールする。既存テストは再構成とホスティング維持を見ており、追従そのものは見ていない。
3. **不正入力の assertion に検証がない** — 0 以下の列数・`minItemWidth`、負のスペーシング (`KsCollectionLayout.swift:38-52`)、重複 ID (`KsSnapshotPlanner.swift:11`)、未登録キー (`KsCollectionViewController.swift:203`) の debug assertion は、assertion の性質上テストがない。release 側の縮退挙動は Release 実行のテストで担保されている。
4. **Sample UI テストに再現性の揺れがある** — 1 回目の実行で `InteractiveControlUITests.test長押し宣言時は同一タッチの通常タップを発火しない` が結果を報告しないまま次のテストが開始し、全体が TEST FAILED になった (アサーション失敗の出力はなし。UI テストランナーの中断とみられる)。同じコマンドの 2 回目・3 回目は 3 件とも成功したため、仕様との乖離ではなく UI テストの不安定さと判断した。
5. **性能計測の証跡が 1 本に統合されている** — tasks 8.1 (グループ 4 完了直後の早期計測) と 8.3 (Sample「大量件数」画面での最終計測) が `evidence/performance-early-measurement.md` 1 本に記録されている。記録内容は Sample 完成後の条件 (「大量件数」画面 + 計測専用 launch 経路) であり、8.1 を Sample 完成前に実施したことをアーティファクトから確認する手段はない。合格判定そのものは記録された測定値で成立している。
6. **R14 の「タップ追跡中にスクロールが始まったらキャンセル」に対応する Scenario もテストもない** — Requirement 本文の SHALL だが Scenario 化されておらず、実装も `UICollectionView` の標準挙動に委ねている (専用コードなし)。

---

## 判定

**VALID** — 全 15 Requirement / 24 Scenario が「✅ 一致」または「⚠️ deviation 記録済み」。未記録の欠落・乖離なし、tasks.md の虚偽チェックなし、足場アーティファクトへの逆流なし、テストは実行して成功を確認した。
