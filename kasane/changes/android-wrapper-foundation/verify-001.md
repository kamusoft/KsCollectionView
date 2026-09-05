# 一致検証 001: android-wrapper-foundation

- 検証日: 2026-09-05
- 対象: デルタスペック 4 本 (collection-core / collection-layout / collection-interaction / samples) の全 Requirement / Scenario
- 判定: **VALID**

## 判定サマリ

| 区分 | 件数 |
|---|---:|
| Requirement | 21 |
| Scenario | 49 |
| ✅ 一致 | 45 |
| ⚠️ deviation 記録済み | 4 |
| ❌ 欠落・乖離 | 0 |

Scenario の THEN のうち、実装は存在するが自動検証の射程外にある条件が 4 件ある (下記「自動検証の
射程外」)。いずれも `evidence/verification-matrix.md` の「未検証の一覧」に検証手段の限界として
明記されており、実装の欠落・仕様との乖離ではないため ❌ とはしていない。

## 状態の記号

| 記号 | 意味 |
|---|---|
| ✅ | 実装とテストが存在し、Scenario の GIVEN / WHEN / THEN が観測されている |
| ⚠️ | deviation.md に合意済み差分として記録がある |
| 🔸 | THEN の一部が自動検証の射程外 (実装は存在。`evidence/verification-matrix.md` の未検証一覧に記録済み) |
| ❌ | 欠落・乖離 |

## テスト実行結果 (全件、`handbook/cross/test-execution.md` に従い再実行)

| 対象 | コマンド | 件数 | 失敗 |
|---|---|---:|---:|
| iOS 本体 | `ios/` の `xcodebuild test -scheme KsCollectionView` (iPhone 17 Pro / Debug) | 81 | 0 |
| iOS Sample | `samples/ios/` の `xcodebuild test -scheme KsCollectionViewSamples` | 3 | 0 |
| Android 本体 | `android/` の `:kscollectionview:testDebugUnitTest --rerun-tasks` | 54 | 0 |
| Android Sample | `samples/android/` の `:app:testDebugUnitTest --rerun-tasks` | 12 | 0 |

Android の件数は `build/test-results/testDebugUnitTest/TEST-*.xml` から集計 (本体: Core 14 / Layout 23 /
Interaction 17、Sample: SampleScreenParityTest 4 / SampleDemoScreenTest 8)。iOS は `xcodebuild` 出力の
`Executed N tests` から。直前の review-005 Minor 対応 (`samples/android` の `LargeDataDemoScreen.kt` /
`benchmark/AndroidManifest.xml` / `ui/brief.md`) による回帰は無い。

なお Android Sample のビルド実行ログに `:android:kscollectionview:compileDebugKotlin` 等の本体タスクが
現れており、composite build の依存置換が実際に効いていることを実測で確認した。

## 対応表

### collection-core

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| プレーンな配列と安定 ID / key ラムダで配列を表示する | `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:214-221` (`items(count, key, contentType)`) | `KsCollectionViewCoreTest.displaysEveryItemAndKeepsComposedItemsBounded` (100 件の先頭表示・index 99 への到達・同時コンポジション数 < 件数) | ✅ |
| プレーンな配列と安定 ID / release ビルドでの重複 ID | `KsItemsPlan.kt:51-72` (後勝ち畳み込み) / `:75-88` (`deduplicate`) / `KsDiagnostics.kt:43-46` | `.duplicateIdKeepsLaterItemWhenNotDebug` (後勝ち表示・件数 2・警告ログ) / `.duplicateIdStopsInDebug` | ✅ |
| プレーンな配列と安定 ID / (本文) key の Bundle 保存可能制約 | `KsItemsPlan.kt:90-96` (`isSavableKey`) / KDoc `KsCollectionView.kt:60-61` / `dsl-samples.md` の注記 | `.unsavableKeyStopsInDebug` | ✅ |
| 差分更新 / 内容変更の反映 | `KsCollectionView.kt:217` (安定 ID を key に渡す) | `.contentUpdateKeepsRememberedStateOfItem` (新内容の描画 + `remember` した値の維持) | ✅ |
| 差分更新 / テンプレートキー変更での再描画 | `KsCollectionView.kt:218-223` (`contentType` = キー値) | `.templateKeyChangeRedrawsWithNewTemplate` | ✅ |
| 差分更新 / 親の状態をテンプレートで読む | `KsCollectionView.kt:98` (宣言ブロックを毎コンポジション評価) | `.parentStateReadInsideTemplateIsReflected` | ✅ |
| 値キーによるテンプレート切り替え / キー値ごとのテンプレート適用 | `KsCollectionViewScope.kt:36-40` / `KsCollectionView.kt:250` | `.templatePerKeyValueIsApplied` | ✅ |
| 値キーによるテンプレート切り替え / 単一テンプレートの軽量形 | `KsCollectionViewScope.kt:49-51` / `:55` (`KsSingleTemplateKey`) | `.singleTemplateFormDrawsEveryItem` | ✅ |
| 値キーによるテンプレート切り替え / release ビルドでの二重登録 | `KsCollectionViewScope.kt:37-39` (後勝ち + 記録) / `KsCollectionView.kt:109-114` | `.duplicateTemplateRegistrationKeepsLastWhenNotDebug` / `.duplicateTemplateRegistrationStopsInDebug` | ✅ |
| 未登録キーの挙動 / release ビルドでの未登録キー | `KsCollectionView.kt:117-120` (検出) / `:253-256` (最小高の空項目) | `.unregisteredKeyShowsEmptyItemWhenNotDebug` (後続要素が下がる = 件数が保たれる + 警告) / `.unregisteredKeyStopsInDebug` / `.sameWarningIsReportedOnlyOnce` | ✅ |
| 大量件数での仮想化・再利用 / 可変行高混在 10,000 件のスクロール | `KsCollectionView.kt:197-204` (`LazyVerticalGrid` への流し込み) / `samples/android/benchmark/.../LargeDataScrollBenchmark.kt` | `LargeDataScrollBenchmark` (実機、3 秒フリック × 3 試行)。結果は `evidence/performance-measurement.md`: 2 列 P90 +1.1% / P99 -8.6%、1 列 P90 -3.1% / P99 -3.9%、`frameOverrunMs` P99 -5.52 ms (上限 0.0 ms 以内) | ⚠️ deviation 2 件目 (相対判定を `frameDurationCpuMs`、絶対を `frameOverrunMs` に分け、判定を 3 試行の集計に対して行う) |
| 大量件数での仮想化・再利用 / メモリが件数に比例しない | 同上 + `KsItemsPlan.kt:8-21` (件数に比例する付随データを作らない) | `LargeDataMemoryBenchmark`。`performance-measurement.md`: 4 実行すべて 3 往復で定常 (増分 2% 以内)、各往復で全項目通過、1,000⇄10,000 件の差は入力データ分で説明可能 (`memoryRssAnonLastKb` +11.8%)。再利用は `evidence/template-reuse-measurement.md` (同時生存 最大 32 / 400 項目通過) | ✅ |
| 値キーテンプレートの推論形 (iOS 追随) / 推論形の宣言がコンパイルできる | `ios/Sources/KsCollectionView/KsTemplateBuilder.swift:5-9` (`buildExpression`) / `ios/Sources/KsCollectionView/KsTemplate.swift` (旧 `Template.swift` は削除済み。旧名の残骸なし) | `KsSwiftUIIntegrationTests.test型注釈なしの推論形で宣言したテンプレートがキーごとに描画される` / `KsPublicAPITests` / `KsTemplateRegistryTests` | ✅ |

### collection-layout

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| layout 値による表示形態 / 固定列グリッド | `KsLayout.kt:57-64` / `KsCollectionView.kt:273-279` | `KsCollectionViewLayoutTest.fixedColumnsPlacesItemsInDeclaredColumnCount` / `.invalidLayoutValuesAreDetected` / `.invalidLayoutValueStopsInDebug` | ✅ |
| layout 値による表示形態 / adaptive グリッド | `KsLayout.kt:73` / `KsCollectionView.kt:277` (`GridCells.Adaptive`) | `.adaptiveColumnsKeepsColumnSpacingAndDistributesRemainder` (2 列決定・列間 20dp 固定・項目幅 140dp を実座標で検証) | ✅ |
| layout 値による表示形態 / 向き別列数 (コンテナ縦横比基準) | `KsCollectionView.kt:192-195` (`BoxWithConstraints` の `maxHeight > maxWidth`。端末の物理向きは参照しない) / `KsLayout.kt:101-102` | `.orientationColumnsUsesPortraitCountWhenContainerIsTall` / `.orientationColumnsUsesLandscapeCountWhenContainerIsWide`。実機回転の目視は `evidence/orientation-grid-android.png` | ✅ (WHEN の例示のうち「分割画面でのリサイズ」の実機操作は未実施。判定経路はコンテナ制約のみで同一) |
| レイアウトの動的切り替え / list とグリッドの切り替え | `KsCollectionView.kt:125` (`gridState` を layout 差し替えで作り直さない) | `.switchingLayoutKeepsDataAndAnchorItemVisible` (index 20 をアンカーに、切替後も可視・2 列で並ぶ・先頭へ戻らない) | ✅ |
| スペーシング / グリッドの行間・列間 | `KsLayout.kt:77-88` / `KsCollectionView.kt:202-203` | `.rowAndColumnSpacingAreApplied` / `.spacingDefaultsToZero` / `.listRowSpacingIsAppliedWhenSpecified` / `.listWithoutParenthesesBehavesAsDefaultList` | ✅ |
| contentPadding / 内側余白 | `KsCollectionView.kt:83` / `:201` | `.contentPaddingInsetsContent` (4 辺個別 + 幅の縮み) / `KsCollectionViewInteractionTest.scrollPositionsUseViewportInsideContentPadding` | ✅ (本文のインジケータ条項は 🔸 — 下記) |
| list の区切り線 / 既定表示と opt-out | `KsListSeparator.kt:31-49` (content 前面に `drawWithContent`) / `KsCollectionView.kt:183, 227-231` | `.listSeparatorsAreDrawnByDefault` (先頭上端・行間・最終行下端の 3 本を画素で) / `.listSeparatorsAreDrawnOverOpaqueItemBackground` / `.listSeparatorsCanBeTurnedOff` | ⚠️ deviation 1 件目 (design の `drawBehind` → 前面描画。spec の Requirement 本文は不変) |
| list の区切り線 / グリッドでは出ない | `KsCollectionView.kt:183` (`layout.isList` 条件) / `KsLayout.kt:91-92` | `.gridDrawsNoSeparators` (画素で不在) | ✅ |
| 区切り線の色 / 色の指定 | Android: `KsCollectionView.kt:90, 182` / `KsListSeparator.kt:11-17` (既定 `#D9D9DE`)。iOS: `KsCollectionView.swift:157` (`listSeparatorColor(_:)`) / `KsHostingCell.swift` (`defaultSeparatorColor`) | `.listSeparatorColorChangesOnlyTheColor` (3 本とも指定色・位置と本数は不変)。iOS `KsCollectionEngineTests.test区切り線の色を指定すると位置と本数を変えずにその色で描く` / `KsPublicAPITests.test区切り線の色を指定しなければ既定の色になる` | ✅ |
| 区切り線の色 / 非表示との組み合わせ | `KsCollectionView.kt:183` (色より表示可否が先) | `.listSeparatorColorDrawsNothingWhenSeparatorsAreHidden`。iOS `KsCollectionEngineTests.test区切り線が非表示なら色を指定しても描かない` | ✅ |
| ルートヘッダー / フッター / ヘッダーのスクロール追従 | `KsCollectionView.kt:205-212` (lazy の `item` として積む) | `.headerScrollsAwayWithContent` | ✅ |
| ルートヘッダー / フッター / 空配列でのヘッダー / フッター | 同上 (項目数と独立に積む) | `.headerAndFooterAreShownForEmptyItems` | ✅ |
| ルートヘッダー / フッター / グリッドでの全幅ヘッダー | `KsCollectionView.kt:207` / `:262` (`GridItemSpan(maxLineSpan)`) | `.headerSpansAllColumnsInGrid` | ✅ |
| セル自己サイズと content の配置 / 可変行高 | `KsCollectionView.kt:224-249` (高さを指定せず content の自然高に従う) | `.rowHeightFollowsContent` (折り返す行だけが高い・行間に余分な空白なし) | ✅ |
| セル自己サイズと content の配置 / 狭い content の水平配置 | `KsCollectionView.kt:248` (`Alignment.TopCenter`) | `.narrowContentIsCenteredAndWideContentFillsFromStart` (水平中央 75dp / `fillMaxWidth` は左端 150dp から幅 150dp) | ✅ |

### collection-interaction

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| アイテムタップ / 項目内ボタンとの競合 | `KsCollectionView.kt:234-245` (`combinedClickable` を項目に付け、子が先にタッチを消費する Compose の既定に委ねる) | `KsCollectionViewInteractionTest.itemButtonConsumesTouchInsteadOfItemTap` / `.itemButtonPressDoesNotStartItemFeedback` (記録用 `Indication` で子押下中・離した後とも親へ `PressInteraction` が流れないこと + 項目背景での正の対照) | ✅ |
| アイテムタップ / タップで型付き要素が渡る | `KsCollectionView.kt:239-240` (要素そのものを渡す) / `:186-190` (ripple) | `.tapPassesTappedItemToCallback` / `.tapHandlerAttachesTapAndFeedbackTarget` | 🔸 コールバックは ✅。フィードバックの塗り (ripple) が実際に描かれることは Robolectric の射程外 |
| アイテムタップ / ロングタップ | `KsCollectionView.kt:239` (`onLongClick`) | `.longTapPassesItemAndSuppressesTap` | ✅ |
| アイテムタップ / ハンドラ未宣言ではフィードバックなし | `KsCollectionView.kt:186, 234-244` (ハンドラが無ければ `combinedClickable` 自体を付けない) | `.noHandlerMeansNoTapTargetAndNoFeedback` | ✅ |
| スクロール制御 / 存在しない ID への命令 | `KsScrollCommandReceiver.kt:106-113` (null 返し + debug 警告) / `KsCollectionView.kt:161-165` | `.scrollToMissingIdDoesNothing` | ✅ |
| スクロール制御 / ID 指定スクロール | `KsScrollCommandReceiver.kt:132-166` (`performScroll` / `alignmentDelta`。基準は contentPadding の内側) / `KsCollectionView.kt:137` (ヘッダーを index に数えない) | `.scrollToCenterPlacesItemAtViewportCenter` / `.scrollToItemAccountsForHeaderIndex` / `.scrollPositionsUseViewportInsideContentPadding` | ✅ |
| スクロール制御 / データ反映後のスクロール実行 | `KsCollectionView.kt:142-156` (`withFrameNanos` を挟み、取り出し時点の最新配列で ID を解決) | `.scrollToEndReachesItemAddedInTheSameFrame` | ✅ |
| スクロール制御 / 連続する命令 | `KsCollectionView.kt:167` (`running?.cancel()` で先行アニメーションを中断) / `:170-177` | `.laterCommandWinsOverEarlierOne` (最終位置が最後の命令で決まる) | 🔸 最終位置は ✅。「先行アニメーションが中断される」こと自体は最終位置からは区別できない |
| スクロール制御 / 待機中に対象が削除された命令 | `KsCollectionView.kt:161-165` (no-op 後に後続へ進む) | `.commandForRemovedItemIsSkippedAndLaterCommandRuns` | ✅ |
| スクロール制御 / 到達できない位置の要求 | `KsScrollCommandReceiver.kt:128-146` (補正量がスクロール可能範囲で頭打ち) | `.unreachableCenterClampsToScrollableEnd` | ✅ |
| スクロール制御 / 複数接続は最後勝ち | `KsScrollController.kt:75-83` (後勝ち + debug 警告) | `.lastAttachedCollectionWins` | ✅ |
| スクロール制御 / 未接続 no-op | `KsScrollController.kt:70-73` (`receiver?.enqueue`) | `.unattachedControllerIsNoOp` (`processedCommandCount == 0` と表示位置の不変) | ✅ |
| スクロール制御 / 接続解除後の no-op | `KsScrollController.kt:85-88` / `KsCollectionView.kt:128-131` (`onDispose` で detach) | `.detachedControllerIsNoOp` | ✅ |
| スクロール制御 (本文) / メインスレッド契約・FIFO・配列更新でキューを失わない | `KsScrollCommandReceiver.kt:45-64` (`assertMainThread` / 単調増加の `enqueuedCount`) / `KsCollectionView.kt:135-142` (`rememberUpdatedState` で effect を作り直さない) | `.scrollToEndReachesItemAddedInTheSameFrame` / `.commandForRemovedItemIsSkippedAndLaterCommandRuns` が配列差し替えをまたぐキューの生存を観測 | ✅ |

### samples

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| Android Sample の器 / 本体の修正が Sample に映る | `samples/android/settings.gradle.kts` (composite `includeBuild` + 明示 `dependencySubstitution`。置換先を失えばビルドエラーで、公開版へ落ちない) / `samples/android/app/build.gradle.kts` (依存 1 行 `jp.kamusoft:kscollectionview`、版は本体カタログ、applicationId `jp.kamusoft.kscollectionview.samples.android`) | 自動テストなし。本検証でのビルド実行ログに `:android:kscollectionview:compileDebugKotlin` 等が現れることを実測 | ✅ |
| デモ画面の集合と文言の一致 / ルートメニューの一致 | `samples/android/app/src/main/kotlin/.../SampleScreen.kt` (9 件、`samples/ios/KsCollectionViewSamples/SampleScreen.swift` と文言・順序が一字一句一致することを実物照合) | `SampleScreenParityTest` 4 本 (タイトルと順序・9 件・単一宣言元・検証画面が別区分) | ✅ |
| デモ画面の集合と文言の一致 / デモ画面の構成一致 | 9 デモ画面 (`samples/android/app/src/main/kotlin/.../*DemoScreen.kt`) / `SampleTheme.kt` | `SampleDemoScreenTest.グリッド固定列画面は grid で始まり list へ切り替えられる`。目視は `evidence/sample-parity-comparison.md` #2 と `fixed-grid-ios.png` / `fixed-grid-list-android.png` | ✅ |
| デモ画面の集合と文言の一致 / 全画面の対応表による照合 | 同上 | `evidence/sample-parity-comparison.md` の対応表 (9 デモ + ルートメニュー + 固有検証)。不一致 1 件 = 「リスト」画面の `touchFeedbackColor` の生値 | ⚠️ deviation 4 件目 (本体の意味論の非対称。描画結果は揃え、統一は後続 change) |
| デモ画面の集合と文言の一致 / 「リスト」画面の区切り線 3 択 | `ListSeparatorChoice.kt` / `ListDemoScreen.kt`。iOS は `ListSeparatorChoice.swift` / `ListDemoView.swift` (文言「なし」「既定」「アクセント」が一致) | `SampleDemoScreenTest.リスト画面の区切り線の初期選択は既定である` / `.リスト画面の区切り線は 3 択を選び直せる`。色の実表示は `ui/verification/list-default.png` / `list-accent.png` | ✅ |
| Android 固有の検証画面 / 親の状態による展開 | `VerificationScreen.kt` (デモ画面と別区分) / `HeightChangeVerificationScreen.kt` | `SampleDemoScreenTest.検証画面は親の状態の経路で展開と折りたたみができる` / `.検証画面は list と grid を切り替えられる` | ✅ |
| Android 固有の検証画面 / テンプレート内の状態による展開 | 同上 (テンプレート内 `remember` の経路) | `SampleDemoScreenTest.検証画面はテンプレート内の状態の経路で展開できる` / `.検証画面のテンプレート内の状態は画面外への往復で初期値へ戻る` (60 行で最終行まで送って戻す)。実機 3 時点の静止画あり | ✅ |
| 性能計測の自動実行 / 計測の再実行 | `samples/android/benchmark/` (`LargeDataScrollBenchmark` = 3 秒フリック × 3 試行、`LargeDataMemoryBenchmark` = 全項目通過の往復)。fixture は iOS 規約と同じ (10,000 件・2 列・7 件ごとの長文による可変行高・決定的生成) | `evidence/performance-measurement.md` にスクロール 4 実行・メモリ暖機/本計測の独立記録。人手を挟まず再現される | ✅ |
| iOS Sample と dsl-samples の追随 / iOS Sample の追随 | `samples/ios/KsCollectionViewSamples/TemplateSwitchDemoView.swift:6-14` (`KsTemplate(.message)` / `KsTemplate(.notice)` の推論形) / `dsl-samples.md` (`KsTemplate` 改名・`listSeparatorColor` 両言語・公開語彙一覧の更新・`key` と `remember` の注記) | iOS Sample テスト 3 件 (ビルドと表示の成立) / `KsSwiftUIIntegrationTests` の推論形テスト | ✅ |

## 自動検証の射程外 (🔸) の内訳

いずれも実装は存在し、`evidence/verification-matrix.md` の「未検証の一覧」に検証手段の限界として
記録されている。deviation.md への記載は無いが、**仕様との差ではなく検証層の限界**であるため
未記録乖離としては扱わなかった。

| 条件 | 出典 | 実装の所在 | 押さえられない理由 |
|---|---|---|---|
| `touchFeedbackColor` の色が実際の ripple の塗りに現れる | collection-interaction「アイテムタップ」Scenario「タップで型付き要素が渡る」THEN 前半 / Requirement 本文 | `KsCollectionView.kt:187-190` | Robolectric では押下状態は成立するが ripple の塗りが描かれない |
| 後の命令が先行するスクロールアニメーションを中断する | collection-interaction「スクロール制御」Scenario「連続する命令」THEN 後半 | `KsCollectionView.kt:167` (`running?.cancel()`) | 現テストは最終位置しか見ず、途中で止まったか走り切って上書きされたかを区別できない |
| 押下追跡中にスクロールが始まるとタップがキャンセルされる | collection-interaction「アイテムタップ」Requirement 本文 (Scenario なし) | `combinedClickable` の既定挙動に委譲 (`KsCollectionView.kt:236`) | Scenario が無く、実機で押下したまま指を滑らせる操作が要る |
| スクロールインジケータの位置が `contentPadding` の影響を受けない | collection-layout「contentPadding」Requirement 本文 (Scenario なし) | `KsCollectionView.kt:201` (`contentPadding` を lazy へ渡すのみ) | Robolectric の描画にインジケータが現れない |

これに加え、collection-layout「向き別列数」Scenario の WHEN が例示する「分割画面でのリサイズ」は
実機操作としては未実施。ただし実装はコンテナ制約 (`BoxWithConstraints`) だけで列数を決めており、
回転と分割画面は同一の判定経路を通る。THEN 自体は 2 本のテストで両方向とも観測済み。

## 追加検査

### tasks.md の虚偽チェック

全 9 グループ・38 タスクがチェック済み。対応表と突き合わせ、**未実装のままチェックされたタスクは
無い**。抽出して確認した主なもの:

| タスク | 実物 |
|---|---|
| 1.1 / 1.2 `buildExpression` と `Template` → `KsTemplate` 改名 | `KsTemplateBuilder.swift:5-9` / `KsTemplate.swift` 新規・`Template.swift` 削除。旧名 `Template` の残骸は全 Swift ソースを走査して 0 件 |
| 1.3 `listSeparatorColor(_:)` | `KsCollectionView.swift:157` + iOS 3 テスト |
| 2.1 / 2.2 ビルド scaffold | `android/settings.gradle.kts` / `android/gradle/libs.versions.toml` / `android/kscollectionview/build.gradle.kts` |
| 3.3 / 3.4 前処理と debug assertion | `KsItemsPlan.kt` / `KsDiagnostics.kt` |
| 6.5 対応表 | `evidence/verification-matrix.md` |
| 7.5 テンプレート呼び出しカウンタ | `samples/android/app/src/counterEnabled` / `counterDisabled` の構成別実体 |
| 8.1 / 8.2 計測 | `samples/android/benchmark/` + `evidence/performance-measurement.md` (現行構成 Pixel 4a で測り直し済み) |
| 8.3 再利用の確認 | `evidence/template-reuse-measurement.md` (Layout Inspector は deviation 5 件目で代替) |
| 9.1 / 9.2 / 9.3 文書追随 | `handbook/cross/local-development-setup.md` の Android 節 / `dsl-samples.md` の注記 / `evidence/adr-alignment.md` |

### 逆流検査

`git log` では change ディレクトリに触れたコミットは提案作成の 1 本のみ。作業ツリーの差分は
`tasks.md` (チェックボックスのみ — 差分から `- [ ]` / `- [x]` 行を除くと残りゼロ) と `ui/brief.md`
(照合結果・プラットフォーム制約差分・トークン候補の追記のみ) の 2 ファイル。
**`proposal.md` / `design.md` / `specs/*/spec.md` はいずれも未変更** — 足場の逆流は無い。

### 未記録乖離

対応表に ❌ は無く、未記録の欠落・乖離は検出されなかった。

### 付随修正

deviation.md に `[付随修正]` 行は無い。作業ツリーの差分を走査した結果、Scenario に対応しない
変更は見当たらなかった。iOS 本体の 6 ファイルはすべてタスク 1.1〜1.3 (推論形 / 改名 /
`listSeparatorColor`) に、Sample 側 2 ファイルはタスク 1.4 に帰着する。`handbook/cross/` の 2 本と
`dsl-samples.md` はタスク 9.1 / 9.2 / 6.4 に対応する。

### deviation.md の 5 件と Requirement の対応

| # | 対象 | 対応表での扱い |
|---|---|---|
| 1 | 区切り線の描画順 (design の `drawBehind` → content 前面) | collection-layout「list の区切り線 / 既定表示と opt-out」に ⚠️。spec の Requirement 本文 (位置・本数・色・opt-out) は不変で、`.listSeparatorsAreDrawnOverOpaqueItemBackground` が新しい挙動を押さえている |
| 2 | 性能の判定指標 (`frameDurationCpuMs` で相対 / `frameOverrunMs` で絶対、3 試行の集計で判定) | collection-core「可変行高混在 10,000 件のスクロール」に ⚠️ |
| 3 | Compose BOM 1.11 系 / compileSdk 36 への引き下げ (android/ADR-0002 と tasks 2.1 に対する差) | Requirement 直結なし。`local-development-setup.md` の要件表と本体カタログが引き下げ後の値で整合 |
| 4 | Sample の `touchFeedbackColor` の生値の非対称 | samples「全画面の対応表による照合」に ⚠️ |
| 5 | Layout Inspector をカウンタで代替 (tasks 8.3) | collection-core「大量件数での仮想化・再利用」の証跡手段。`template-reuse-measurement.md` が代替結果を持つ |

いずれも合意済み差分として扱った。

### UI 変更の記録

`ui/brief.md` に承認モック (`ui/mock/approved.png`) の記録、視覚照合ループの収束 (2 周)、
プラットフォーム制約による差分 4 件、モックを採らなかった判断 (ルートメニューの検証区分の副文字色 —
iOS に合わせた) が記録されている。照合の静止画は `ui/verification/` の 4 枚。合意済み妥協のうち
DSL パラメータに及ぶ 1 件は deviation.md へ、残る 3 件は sample-parity の許容差異として brief に確定。

## 結論

**VALID**。デルタスペック 4 本の 21 Requirement / 49 Scenario すべてに実装が対応し、45 件は
テストまたは記録された実機計測で観測されている。残る 4 件は deviation.md に合意済み差分として
記録がある。❌ (未記録の欠落・乖離) は 0 件、tasks.md の虚偽チェックなし、足場の逆流なし、
テストは 4 スイート全件成功 (150 件 / 失敗 0)。

Scenario の THEN の一部が自動検証の射程外にある 4 件は、実装が存在し `verification-matrix.md` に
未検証として明示されているため INVALID の根拠とはしなかった。将来の押さえ方は同ファイルの
「押さえるとしたら」列に記録済み。
