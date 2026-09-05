# 一致検証 002: android-wrapper-foundation (verify-001 以降の差分検証)

- 検証日: 2026-09-05
- 対象: デルタスペック 4 本 (collection-core / collection-layout / collection-interaction / samples) の全 Requirement / Scenario。verify-001 (VALID) の対応表をベースに、**verify-001 以降に入った変更 (deviation 6・7 件目 + 補足・8 件目、本体テスト +12 件)** で対応が保たれているかを見る
- 判定: **VALID**

## 判定サマリ

| 区分 | verify-001 | verify-002 | 差 |
|---|---:|---:|---|
| Requirement | 21 | 21 | 変化なし (足場は凍結、逆流なし) |
| Scenario | 49 | 49 | 変化なし |
| ✅ 一致 | 45 | 43 | -2 (⚠️ へ移動) |
| ⚠️ deviation 記録済み | 4 | 6 | +2 (deviation 6 / 7 件目に対応する 2 行が新たに ⚠️ へ) |
| ❌ 欠落・乖離 | 0 | 0 | — |

⚠️ が 4 → 6 に増えたのは、verify-001 以降に**追加で合意された乖離** (deviation 6・7・8 件目) が
Requirement 3 本に掛かったためで、実装の欠落が増えたわけではない。うち 1 本 (ID 指定スクロール) は
verify-001 では ✅ だった行が deviation 8 件目の合意で ⚠️ に移り、同時に検証は 3 テスト分厚くなっている。

## 状態の記号 (verify-001 と同じ)

| 記号 | 意味 |
|---|---|
| ✅ | 実装とテストが存在し、Scenario の GIVEN / WHEN / THEN が観測されている |
| ⚠️ | deviation.md に合意済み差分として記録がある |
| 🔸 | THEN の一部が自動検証の射程外 (実装は存在。`evidence/verification-matrix.md` の未検証一覧に記録済み) |
| ❌ | 欠落・乖離 |

## テスト実行結果

`handbook/cross/test-execution.md` に従い、Android は 2 ビルドルートとも `--rerun-tasks` で全件を
回し直し、件数は `build/test-results/testDebugUnitTest/TEST-*.xml` の `tests` / `failures` 属性から
クラス単位で集計した。

| 対象 | コマンド | 件数 | 失敗 |
|---|---|---:|---:|
| Android 本体 | `android/` の `:kscollectionview:testDebugUnitTest --rerun-tasks` | **66** | 0 |
| Android Sample | `samples/android/` の `:app:testDebugUnitTest --rerun-tasks` | 12 | 0 |
| iOS 本体 | (verify-001 の値を引用。`ios/` は verify-001 以降 未変更) | 81 | 0 |
| iOS Sample | (同上) | 3 | 0 |

Android 本体のクラス別内訳と verify-001 からの差:

| クラス | verify-001 | verify-002 | 差 |
|---|---:|---:|---:|
| `KsCollectionViewCoreTest` | 14 | 14 | ±0 |
| `KsCollectionViewLayoutTest` | 23 | 30 | **+7** |
| `KsCollectionViewInteractionTest` | 17 | 22 | **+5** |
| 計 | 54 | 66 | +12 |

Sample は `SampleScreenParityTest` 4 / `SampleDemoScreenTest` 8 で verify-001 と同一。

iOS を再実行しなかった根拠: 変更日時での走査 (verify-001 出力時刻以降) で `ios/` 配下に更新された
ファイルは 0 件。更新されたのは `android/` 7 ファイル・`samples/android/` 3 ファイル・
`dsl-samples.md` の計 11 ファイルのみである。

## 新規 12 テストの内訳と Requirement への帰属

| テスト | 帰属する Requirement / 由来 |
|---|---|
| `KsCollectionViewLayoutTest.rowHeightChangeFromParentStateAnimates` | セル自己サイズと content の配置 (Android) / deviation 6 件目 |
| `.rowHeightChangeFromTemplateStateAnimates` | 同上 |
| `.rowHeightChangeAnimatesInGrid` | 同上 |
| `.headerHeightChangeAnimates` | ルートヘッダー / フッター (Android) + deviation 6 件目 (ヘッダーへの既定適用) |
| `.rowHeightCollapseKeepsContentBottomAtRowBottom` | セル自己サイズと content の配置 (Android) / deviation 6 件目 (帯が出ないこと) |
| `.rowHeightAnimationClipsContentIgnoringHeightConstraint` | 同上 (補間中のクリップ。review-007 の指摘で入った) |
| `.reusedItemDoesNotInheritPreviousRowHeight` | 大量件数での仮想化・再利用 (Android) + deviation 6 件目 (再利用時に補間を持ち越さない) |
| `KsCollectionViewInteractionTest.animatedCenterScrollNeverReversesDirection` | スクロール制御 (Android) / ID 指定スクロール / deviation 8 件目 |
| `.animatedEndScrollNeverReversesDirection` | 同上 |
| `.animatedCenterScrollNeverReversesWithMixedItemHeights` | 同上 (高さの推定が外れた場合) |
| `.forwardScrollIsJudgedByRequestedTopWithinSameItem` | 同上 (進行方向の判定。`isForwardScroll` の単体検証) |
| `.forwardScrollIsJudgedByIndexOrderForOtherItems` | 同上 |

12 件すべてが deviation 6 / 8 件目の合意内容に帰属し、Scenario を持たない新機能を勝手に足した
テストは無い。

---

## 対応表 (verify-001 からの差分を「差分」列に示す)

「差分」列が空欄の行は verify-001 から実装・テスト・状態のいずれも変わっていない。

### collection-core

| Requirement / Scenario | 実装 | テスト | 状態 | 差分 |
|---|---|---|---|---|
| プレーンな配列と安定 ID / key ラムダで配列を表示する | `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:241-250` | `KsCollectionViewCoreTest.displaysEveryItemAndKeepsComposedItemsBounded` | ✅ | 行番号のみ (241-250) |
| プレーンな配列と安定 ID / release ビルドでの重複 ID | `KsItemsPlan.kt:51-72` / `:75-88` / `KsDiagnostics.kt:43-46` | `.duplicateIdKeepsLaterItemWhenNotDebug` / `.duplicateIdStopsInDebug` | ✅ | |
| プレーンな配列と安定 ID / (本文) key の Bundle 保存可能制約 | `KsItemsPlan.kt:90-96` / KDoc `KsCollectionView.kt:66-67` / `dsl-samples.md` の注記 | `.unsavableKeyStopsInDebug` | ✅ | KDoc の行番号のみ |
| 差分更新 / 内容変更の反映 | `KsCollectionView.kt:244` (安定 ID を key に渡す) | `.contentUpdateKeepsRememberedStateOfItem` | ✅ | 行番号のみ |
| 差分更新 / テンプレートキー変更での再描画 | `KsCollectionView.kt:245-247` (`contentType` = キー値) | `.templateKeyChangeRedrawsWithNewTemplate` | ✅ | 行番号のみ |
| 差分更新 / 親の状態をテンプレートで読む | `KsCollectionView.kt:104-106` (宣言ブロックを毎コンポジション評価) | `.parentStateReadInsideTemplateIsReflected` | ✅ | 行番号のみ |
| 値キーによるテンプレート切り替え / キー値ごとのテンプレート適用 | `KsCollectionViewScope.kt:36-40` / `KsCollectionView.kt:245-247, 284` | `.templatePerKeyValueIsApplied` | ✅ | 行番号のみ |
| 値キーによるテンプレート切り替え / 単一テンプレートの軽量形 | `KsCollectionViewScope.kt:49-55` | `.singleTemplateFormDrawsEveryItem` | ✅ | |
| 値キーによるテンプレート切り替え / release ビルドでの二重登録 | `KsCollectionViewScope.kt:37-39` / `KsCollectionView.kt:115-120` | `.duplicateTemplateRegistrationKeepsLastWhenNotDebug` / `.duplicateTemplateRegistrationStopsInDebug` | ✅ | 行番号のみ |
| 未登録キーの挙動 / release ビルドでの未登録キー | `KsCollectionView.kt:123-126` (検出) / `:286-289` (最小高の空項目) | `.unregisteredKeyShowsEmptyItemWhenNotDebug` / `.unregisteredKeyStopsInDebug` / `.sameWarningIsReportedOnlyOnce` | ✅ | 行番号のみ |
| 大量件数での仮想化・再利用 / 可変行高混在 10,000 件のスクロール | `KsCollectionView.kt:216-224` (`LazyVerticalGrid` への流し込み) / `KsAnimatedHeight.kt:104-145` (補間中の切り取りは描画時に行い合成レイヤを作らない) / `samples/android/benchmark/` の `LargeDataScrollBenchmark` | `LargeDataScrollBenchmark` (実機 3 秒フリック × 3 試行、独立に 2 回実行)。正式結果は `evidence/performance-measurement.md`: 2 列 P90 **-9.1% / -4.2%**、P99 **-23.2% / -5.6%**、1 列 P90 -1.3% / -6.6%、P99 +2.5% / -10.1%。`frameOverrunMs` P99 はライブラリ側 2 列 -5.87 / -6.25 ms、1 列 -6.50 / -6.51 ms (上限 0.0 ms 以内) | ⚠️ deviation **2 + 7 件目 (+補足)** | **変更**: 比較対象に `animateContentSize` を付けた対等条件での再計測に差し替え。deviation 7 件目 (+補足) が新たに掛かる。verify-001 が引いていた値 (P90 +1.1% / P99 -8.6%) は同ファイルの「条件を揃える前の計測」節へ移動済み |
| 大量件数での仮想化・再利用 / メモリが件数に比例しない | 同上 + `KsItemsPlan.kt:8-21` | `LargeDataMemoryBenchmark`。4 実行すべて 3 往復で定常・全項目通過・`memoryRssAnonLastKb` +11.8%。再利用は `evidence/template-reuse-measurement.md` | ✅ | **補足**: 高さ変化の補間は項目ごとの保持構造を変えないためメモリは測り直していない旨が `performance-measurement.md` に明記。加えて `reusedItemDoesNotInheritPreviousRowHeight` が、再利用時に前の項目の高さ・進行中の補間を持ち越さないことを検証層で押さえた (`KsAnimatedHeight.kt:95-102, 200-206` の `onDetach` / `onReset`) |
| 値キーテンプレートの推論形 (iOS 追随) / 推論形の宣言がコンパイルできる | `ios/Sources/KsCollectionView/KsTemplateBuilder.swift:5-9` / `ios/Sources/KsCollectionView/KsTemplate.swift` | `KsSwiftUIIntegrationTests` / `KsPublicAPITests` / `KsTemplateRegistryTests` | ✅ | (iOS は verify-001 以降 未変更) |

### collection-layout

| Requirement / Scenario | 実装 | テスト | 状態 | 差分 |
|---|---|---|---|---|
| layout 値による表示形態 / 固定列グリッド | `KsLayout.kt:57-64` / `KsCollectionView.kt:311-317` | `.fixedColumnsPlacesItemsInDeclaredColumnCount` / `.invalidLayoutValuesAreDetected` / `.invalidLayoutValueStopsInDebug` | ✅ | 行番号のみ |
| layout 値による表示形態 / adaptive グリッド | `KsLayout.kt:73` / `KsCollectionView.kt:316` | `.adaptiveColumnsKeepsColumnSpacingAndDistributesRemainder` | ✅ | 行番号のみ |
| layout 値による表示形態 / 向き別列数 | `KsCollectionView.kt:211-213` (`BoxWithConstraints` の `maxHeight > maxWidth`) / `KsLayout.kt:101-102` | `.orientationColumnsUsesPortraitCountWhenContainerIsTall` / `.orientationColumnsUsesLandscapeCountWhenContainerIsWide` | ✅ (WHEN の「分割画面でのリサイズ」の実機操作は未実施。判定経路は同一) | 行番号のみ |
| レイアウトの動的切り替え / list とグリッドの切り替え | `KsCollectionView.kt:131` (`gridState` を layout 差し替えで作り直さない) | `.switchingLayoutKeepsDataAndAnchorItemVisible` | ✅ | 行番号のみ |
| スペーシング / グリッドの行間・列間 | `KsLayout.kt:77-88` / `KsCollectionView.kt:221-222` | `.rowAndColumnSpacingAreApplied` / `.spacingDefaultsToZero` / `.listRowSpacingIsAppliedWhenSpecified` / `.listWithoutParenthesesBehavesAsDefaultList` | ✅ | 行番号のみ |
| contentPadding / 内側余白 | `KsCollectionView.kt:89, 220` | `.contentPaddingInsetsContent` / `KsCollectionViewInteractionTest.scrollPositionsUseViewportInsideContentPadding` | ✅ (本文のインジケータ条項は 🔸) | 行番号のみ |
| list の区切り線 / 既定表示と opt-out | `KsListSeparator.kt:31-49` / `KsCollectionView.kt:202, 254-258` | `.listSeparatorsAreDrawnByDefault` / `.listSeparatorsAreDrawnOverOpaqueItemBackground` / `.listSeparatorsCanBeTurnedOff` | ⚠️ deviation 1 件目 | **補足**: `ksListSeparator` は `ksAnimatedHeight` より**外側**に置かれ、区切り線は補間中の行の高さに追従する (`KsCollectionView.kt:254-280`)。3 本の位置・本数・opt-out は不変で、テストも不変 |
| list の区切り線 / グリッドでは出ない | `KsCollectionView.kt:202` / `KsLayout.kt:91-92` | `.gridDrawsNoSeparators` | ✅ | 行番号のみ |
| 区切り線の色 / 色の指定 | Android `KsCollectionView.kt:96, 201` / `KsListSeparator.kt:11-17`。iOS `KsCollectionView.swift:157` / `KsHostingCell.swift` | `.listSeparatorColorChangesOnlyTheColor` / iOS 2 テスト | ✅ | 行番号のみ |
| 区切り線の色 / 非表示との組み合わせ | `KsCollectionView.kt:202` | `.listSeparatorColorDrawsNothingWhenSeparatorsAreHidden` / iOS 1 テスト | ✅ | 行番号のみ |
| ルートヘッダー / フッター / ヘッダーのスクロール追従 | `KsCollectionView.kt:226-238` (lazy の `item` として積む) | `.headerScrollsAwayWithContent` | ✅ | **変更**: ヘッダーの箱に `ksAnimatedHeight()` + `propagateMinConstraints = true` が付いた (deviation 6 件目の既定適用)。スクロール追従の挙動は不変で、`.headerHeightChangeAnimates` が高さ変化側を追加で押さえる |
| ルートヘッダー / フッター / 空配列でのヘッダー / フッター | 同上 + `:294-306` (フッター) | `.headerAndFooterAreShownForEmptyItems` | ✅ | **変更**: フッターの箱にも同じ 2 指定が付いた。表示条件は不変 |
| ルートヘッダー / フッター / グリッドでの全幅ヘッダー | `KsCollectionView.kt:227, 296` (`GridItemSpan(maxLineSpan)`) | `.headerSpansAllColumnsInGrid` | ✅ | 行番号のみ |
| セル自己サイズと content の配置 / 可変行高 | `KsCollectionView.kt:251-292` (高さを指定せず content の自然高に従う) / `KsAnimatedHeight.kt:61-206` (自然高が変わったときだけ、その値へ補間して追従。補間中は content も現在の高さで測り直し、描画を行の高さで切り取る) | `.rowHeightFollowsContent` (静定時の高さ) / `.rowHeightChangeFromParentStateAnimates` / `.rowHeightChangeFromTemplateStateAnimates` / `.rowHeightChangeAnimatesInGrid` / `.rowHeightCollapseKeepsContentBottomAtRowBottom` / `.rowHeightAnimationClipsContentIgnoringHeightConstraint`。実機は `evidence/row-height-animation.md` (中間フレーム 0 → 23 の A/B、帯の画素 0 px) | ⚠️ deviation **6 件目** | **変更 (✅ → ⚠️)**: 行の高さ変化をライブラリ既定でアニメーションさせる合意が新たに掛かった。Requirement 本文の「高さはコンテンツに応じて自動決定」「手動指定・事前計算を要求しない」は不変で、静定時の高さは `.rowHeightFollowsContent` が従来どおり押さえる |
| セル自己サイズと content の配置 / 狭い content の水平配置 | `KsCollectionView.kt:280` (`ksAnimatedHeight(horizontalAlignment = Alignment.CenterHorizontally)`) / `KsAnimatedHeight.kt:104-137` (content は `minWidth = 0` で測り、`y = 0` = 上端に置く) | `.narrowContentIsCenteredAndWideContentFillsFromStart` (水平中央 75dp / `fillMaxWidth` は左端 150dp から幅 150dp) | ✅ | **変更 (実装のみ)**: `Box(contentAlignment = TopCenter)` から `ksAnimatedHeight` の配置へ移った。上端配置 + 水平中央 + 全幅 content は先頭から、の 3 点は不変でテストも不変 (再実行で通過) |

### collection-interaction

| Requirement / Scenario | 実装 | テスト | 状態 | 差分 |
|---|---|---|---|---|
| アイテムタップ / 項目内ボタンとの競合 | `KsCollectionView.kt:259-272` (`combinedClickable`) | `.itemButtonConsumesTouchInsteadOfItemTap` / `.itemButtonPressDoesNotStartItemFeedback` | ✅ | 行番号のみ |
| アイテムタップ / タップで型付き要素が渡る | `KsCollectionView.kt:263-267` / `:205-209` (ripple) | `.tapPassesTappedItemToCallback` / `.tapHandlerAttachesTapAndFeedbackTarget` | 🔸 コールバックは ✅。ripple の塗りは Robolectric の射程外 | 行番号のみ |
| アイテムタップ / ロングタップ | `KsCollectionView.kt:265` | `.longTapPassesItemAndSuppressesTap` | ✅ | 行番号のみ |
| アイテムタップ / ハンドラ未宣言ではフィードバックなし | `KsCollectionView.kt:205, 259-270` | `.noHandlerMeansNoTapTargetAndNoFeedback` | ✅ | 行番号のみ |
| スクロール制御 / 存在しない ID への命令 | `KsScrollCommandReceiver.kt:118-125` (null 返し + debug 警告) / `KsCollectionView.kt:182-186` | `.scrollToMissingIdDoesNothing` | ✅ | 行番号のみ |
| スクロール制御 / ID 指定スクロール | `KsScrollCommandReceiver.kt:156-185` (`performScroll` — Center / End も 1 回の `animateScrollToItem(index, scrollOffset)` に集約) / `:187-205` (`initialScrollOffset` / `estimateItemHeight` = 可視なら実測 → 同 contentType の平均 → 可視全体の平均) / `:228-236` (`isForwardScroll`) / `:70` (`KsScrollAlignmentTolerance = 4.dp`) / `KsCollectionView.kt:159` (tolerance の px 換算) / `:145` (ヘッダーを index に数えない) | `.scrollToCenterPlacesItemAtViewportCenter` / `.scrollToItemAccountsForHeaderIndex` / `.scrollPositionsUseViewportInsideContentPadding` + 新規 `.animatedCenterScrollNeverReversesDirection` / `.animatedEndScrollNeverReversesDirection` / `.animatedCenterScrollNeverReversesWithMixedItemHeights` / `.forwardScrollIsJudgedByRequestedTopWithinSameItem` / `.forwardScrollIsJudgedByIndexOrderForOtherItems`。実機は `evidence/scroll-center-motion.md` (符号反転 15 → 0 フレーム、最大逆行 188 → 0 px、到達位置は A/B とも 8,667 px) | ⚠️ deviation **8 件目** | **変更 (✅ → ⚠️)**: 2 段階 (先頭合わせ → 補正) から 1 回命令へ。THEN「X が表示範囲の中央に来る」は `.scrollToCenterPlacesItemAtViewportCenter` が従来どおり押さえ、過程の往復が無いことを新規 3 テストが追加で押さえる |
| スクロール制御 / データ反映後のスクロール実行 | `KsCollectionView.kt:161-180` (`withFrameNanos` を挟み、取り出し時点の最新配列で ID を解決) | `.scrollToEndReachesItemAddedInTheSameFrame` | ✅ | 行番号のみ |
| スクロール制御 / 連続する命令 | `KsCollectionView.kt:187` (`running?.cancel()`) / `:190-197` | `.laterCommandWinsOverEarlierOne` | 🔸 最終位置は ✅。中断そのものは未検証 | 行番号のみ (verify-001 と同じ 🔸 のまま) |
| スクロール制御 / 待機中に対象が削除された命令 | `KsCollectionView.kt:182-186` | `.commandForRemovedItemIsSkippedAndLaterCommandRuns` | ✅ | 行番号のみ |
| スクロール制御 / 到達できない位置の要求 | `KsScrollCommandReceiver.kt:187-205` (対象が表示範囲より大きければオフセット 0 = 先頭合わせ) / `:240-253` (`alignmentDelta`) / `animateScrollToItem` 自体のスクロール可能範囲での頭打ち | `.unreachableCenterClampsToScrollableEnd` (末尾で止まる + 対象が可視) | ✅ | **変更 (実装のみ)**: 補正経路が 1 回命令 + 残差詰めに変わったが、deviation 8 件目が「clamp・contentPadding 内側基準・到達不能位置の扱いは不変」と明記し、テストも不変のまま通過 |
| スクロール制御 / 複数接続は最後勝ち | `KsScrollController.kt:75-83` | `.lastAttachedCollectionWins` | ✅ | |
| スクロール制御 / 未接続 no-op | `KsScrollController.kt:70-73` | `.unattachedControllerIsNoOp` | ✅ | |
| スクロール制御 / 接続解除後の no-op | `KsScrollController.kt:85-88` / `KsCollectionView.kt:134-137` | `.detachedControllerIsNoOp` | ✅ | 行番号のみ |
| スクロール制御 (本文) / メインスレッド契約・FIFO・配列更新でキューを失わない | `KsScrollCommandReceiver.kt:45-64` / `KsCollectionView.kt:141-148` (`rememberUpdatedState`) | `.scrollToEndReachesItemAddedInTheSameFrame` / `.commandForRemovedItemIsSkippedAndLaterCommandRuns` | ✅ | 行番号のみ |

### samples

| Requirement / Scenario | 実装 | テスト | 状態 | 差分 |
|---|---|---|---|---|
| Android Sample の器 / 本体の修正が Sample に映る | `samples/android/settings.gradle.kts` / `samples/android/app/build.gradle.kts` | 自動テストなし。本検証の Sample ビルド実行ログにも `:kscollectionview:*` タスクが現れ、composite build の置換が効いていることを再実測 | ✅ | |
| デモ画面の集合と文言の一致 / ルートメニューの一致 | `samples/android/app/src/main/kotlin/.../SampleScreen.kt` | `SampleScreenParityTest` 4 本 | ✅ | |
| デモ画面の集合と文言の一致 / デモ画面の構成一致 | 9 デモ画面 / `SampleTheme.kt` | `SampleDemoScreenTest.グリッド固定列画面は grid で始まり list へ切り替えられる` ほか。目視は `evidence/sample-parity-comparison.md` | ✅ | |
| デモ画面の集合と文言の一致 / 全画面の対応表による照合 | 同上 | `evidence/sample-parity-comparison.md` の対応表 | ⚠️ deviation 4 件目 | |
| デモ画面の集合と文言の一致 / 「リスト」画面の区切り線 3 択 | `ListSeparatorChoice.kt` / `ListDemoScreen.kt` / iOS 対応物 | `.リスト画面の区切り線の初期選択は既定である` / `.リスト画面の区切り線は 3 択を選び直せる` | ✅ | |
| Android 固有の検証画面 / 親の状態による展開 | `VerificationScreen.kt` / `HeightChangeVerificationScreen.kt` / `HeightChangeRowBody.kt` | `.検証画面は親の状態の経路で展開と折りたたみができる` / `.検証画面は list と grid を切り替えられる` | ✅ | **補足**: 行の本文が `HeightChangeRowBody.kt` に分離された (2 経路で同一の本文を使うため)。THEN「他の行の位置がそれに合わせて動く」は deviation 6 件目により段階を踏んで動くようになった (`row-height-animation.md`: 押し出される次の行の上端が同じ系列を辿る) |
| Android 固有の検証画面 / テンプレート内の状態による展開 | `HeightChangeVerificationScreen.kt:141-149` (`propagateMinConstraints = true`) | `.検証画面はテンプレート内の状態の経路で展開できる` / `.検証画面のテンプレート内の状態は画面外への往復で初期値へ戻る` | ✅ | **変更 (Sample のみ)**: テンプレートの根の透明な箱に `propagateMinConstraints = true` を恒久追加。deviation 6 件目で入った利用契約 (補間中はテンプレートの根に行の高さが制約として渡る) を Sample 自身が満たすための修正で、Scenario の GIVEN / WHEN / THEN (画面外への往復で初期値へ戻る) は不変・テストも不変 |
| 性能計測の自動実行 / 計測の再実行 | `samples/android/benchmark/` (`LargeDataScrollBenchmark` / `LargeDataMemoryBenchmark`) / `samples/android/app/src/measurement/kotlin/.../MeasurementDestinations.kt:186-215` (比較対象の項目にも `animateContentSize` を同じ位置に付ける) | `evidence/performance-measurement.md` (スクロールは対等条件で独立 2 回、メモリは 4 実行) | ⚠️ deviation **7 件目 (+補足)** | **変更 (✅ → ⚠️)**: 比較対象の条件が「素の Compose」から「ライブラリと同じ既定機能を持つ素の Compose」へ変わった。fixture (件数・列数・間隔・行の見た目・決定的生成) は不変で、Scenario の「同じ操作が再現され指標が得られる」も不変 |
| iOS Sample と dsl-samples の追随 / iOS Sample の追随 | `samples/ios/KsCollectionViewSamples/TemplateSwitchDemoView.swift:6-14` / `dsl-samples.md` | iOS Sample テスト 3 件 / `KsSwiftUIIntegrationTests` の推論形テスト | ✅ | **補足**: `dsl-samples.md` に「Android 行の高さ変化のアニメーション」節 (:441-443) が追加された。`KsTemplate` 改名・`listSeparatorColor`・公開語彙一覧という本 Scenario の対象部分は不変 |

---

## 自動検証の射程外 (🔸) の内訳

verify-001 の 4 件はいずれも変化なし (実装・理由とも同じ)。`evidence/verification-matrix.md` の
「未検証の一覧」にも 4 件とも残っている。**verify-001 以降に 2 件が同一覧へ追加された**:

| 条件 | 出典 | 状況 |
|---|---|---|
| 分割画面でのリサイズによる向き別列数の切り替え | collection-layout「向き別列数」Scenario の WHEN の例示 | verify-001 では本文の脚注として書いていたものが、今回「未検証の一覧」へ正式に載った。THEN 自体は 2 テストで観測済み。**扱いの変化なし** |
| フッターの高さ変化のアニメーション | deviation 6 件目 (ヘッダー / フッターへの既定適用)。**デルタスペックの Scenario ではない** | ヘッダー側は `.headerHeightChangeAnimates` で押さえたが、フッターは押し出される対象が無く同形の観測点を作れない。実装は同一の `ksAnimatedHeight` (`KsCollectionView.kt:299-302`)。合意した既定挙動の一部が未検証という状態であり、**Scenario の欠落ではない** |

## 追加検査

### tasks.md の虚偽チェック

全 9 グループ・38 タスクがチェック済みで、verify-001 以降に**チェック状態の変化なし** (作業ツリー
差分からチェックボックス行を除くと残りゼロ = 本文も未変更)。今回入った変更は既存タスクの
やり直し (4.5 / 5.3 / 6.2 / 6.3 / 7.4 / 8.1 / 8.2 / 9.2 に相当) に収まり、**未実装のままチェック
されたタスクは無い**。verify-001 以降に追加された実物を抽出して確認:

| タスク | verify-001 以降の実物 |
|---|---|
| 4.5 (項目 content のラップ) | `KsAnimatedHeight.kt` 新規 + `KsCollectionView.kt:280-282`。配置規則は不変 |
| 5.3 (Start / Center / End の補正と clamp) | `KsScrollCommandReceiver.kt:156-236` の 1 回命令化 |
| 6.2 / 6.3 (Scenario テスト) | Layout +7 / Interaction +5 の計 12 件 |
| 7.4 (検証画面) | `HeightChangeVerificationScreen.kt:141-149` + `HeightChangeRowBody.kt` |
| 8.1 / 8.2 (計測) | `MeasurementDestinations.kt:186-215` の対等化 + `performance-measurement.md` の正式結果差し替え |
| 9.2 (利用者向け注記) | `dsl-samples.md:441-443` + `KsCollectionView.kt:60-63` の KDoc |

### 逆流検査

`git log` で change ディレクトリに触れたコミットは提案作成の 1 本のみ (verify-001 と同じ)。
作業ツリーの追跡差分は `tasks.md` (チェックボックス行のみ — 差分から `- [ ]` / `- [x]` 行を
除くと残りゼロ) と `ui/brief.md` の 2 ファイルで、**`proposal.md` / `design.md` /
`specs/*/spec.md` はいずれも未変更**。`git diff --stat` でも specs / proposal / design に
差分行は現れない。足場の逆流は無い。

deviation 6・7・8 件目はいずれも **spec を書き換えずに deviation.md へ追記する**形を取っており、
凍結の規律に従っている。

### 未記録乖離

対応表に ❌ は無い。verify-001 以降に更新された 11 ファイルはすべて deviation 6・7・8 件目
(およびその 7 件目の補足) に帰着する。帰属を確認した内訳:

| ファイル | 帰属 |
|---|---|
| `KsAnimatedHeight.kt` (新規) / `KsCollectionView.kt` / `HeightChangeVerificationScreen.kt` / `HeightChangeRowBody.kt` / `dsl-samples.md` | deviation 6 件目 |
| `KsScrollCommandReceiver.kt` | deviation 8 件目 |
| `MeasurementDestinations.kt` | deviation 7 件目 |
| `android/gradle/libs.versions.toml` / `android/kscollectionview/build.gradle.kts` | deviation 6 件目に付随する依存追加 (`compose-animation-core` を `implementation` に 1 行。`Animatable` を使うため)。版の宣言元はカタログ 1 箇所のまま |
| `KsCollectionViewLayoutTest.kt` / `KsCollectionViewInteractionTest.kt` | 上記のテスト (新規 12 件、既存の書き換えなし) |

### 付随修正

deviation.md に `[付随修正]` 行は無い。verify-001 以降の変更を走査した結果、Scenario にも
deviation にも対応しない変更は見当たらなかった。`compose-animation-core` の依存追加は
deviation 6 件目の実装に不可欠な 1 行で、独立した修正ではない。

### deviation.md の 8 件と Requirement の対応

| # | 対象 | verify-002 での扱い | verify-001 からの差 |
|---|---|---|---|
| 1 | 区切り線の描画順 | collection-layout「list の区切り線 / 既定表示と opt-out」に ⚠️ | 変化なし (補間中の高さへの追従が加わったのみ) |
| 2 | 性能の判定指標 (相対 = `frameDurationCpuMs` / 絶対 = `frameOverrunMs`、3 試行の集計で判定) | collection-core「可変行高混在 10,000 件のスクロール」に ⚠️ | 判定方法は不変。正式結果の値が対等条件の再計測に差し替わった |
| 3 | Compose BOM 1.11 系 / compileSdk 36 | Requirement 直結なし | 変化なし (カタログの値も 2026.06.01 / 36 のまま) |
| 4 | Sample の `touchFeedbackColor` の生値の非対称 | samples「全画面の対応表による照合」に ⚠️ | 変化なし |
| 5 | Layout Inspector をカウンタで代替 | collection-core「大量件数での仮想化・再利用」の証跡手段 | 変化なし |
| **6** | 行の高さ変化をライブラリ既定でアニメーション | collection-layout「セル自己サイズと content の配置 / 可変行高」に ⚠️。ヘッダー / フッターと検証画面の行にも波及 (補足として記載) | **新規** |
| **7** (+補足) | 性能の比較対象にも同じ既定機能 (`animateContentSize`) を付けて対等比較。実装は揃えない | collection-core「可変行高混在 10,000 件のスクロール」と samples「計測の再実行」に ⚠️ | **新規** |
| **8** | Center / End を 1 回命令に集約 | collection-interaction「スクロール制御 / ID 指定スクロール」に ⚠️。「到達できない位置の要求」「連続する命令」「データ反映後のスクロール実行」は不変と明記され、テストも不変で通過 | **新規** |

いずれも合意済み差分として扱った。

### UI 変更の記録

`ui/brief.md` は verify-001 以降 未更新。今回の変更は承認済みモック (`ui/mock/approved.png`) が
対象とする 3 画面 (ルートメニュー / リスト / グリッド (固定列)) の**静止時の見た目を変えない**
(行の高さの補間は遷移中のみ、Sample の `propagateMinConstraints` は制約の伝播のみ、
`MeasurementDestinations.kt` は計測用構成でモックの対象外)。モック照合のやり直しを要する差は無い。

## 結論

**VALID**。デルタスペック 4 本の 21 Requirement / 49 Scenario すべてに実装が対応し、43 件は
テストまたは記録された実機計測で観測、6 件は deviation.md に合意済み差分として記録がある。
❌ (未記録の欠落・乖離) は 0 件、tasks.md の虚偽チェックなし、足場 (proposal / design / specs) の
逆流なし、テストは Android 2 スイート全件成功 (66 / 12、失敗 0)、iOS は未変更のため verify-001 の
値 (81 / 3、失敗 0) を引用。

verify-001 以降に入った 3 つの乖離 (deviation 6・7・8 件目) は、いずれも Requirement 本文を
書き換えずに挙動を足す / 判定条件を対等化する形で、既存 Scenario の THEN を壊していない。
該当 Scenario の元のテストはすべて不変のまま再実行で通過しており、新規 12 テストは追加された
挙動だけを押さえている。

## 呼び出し元への申し送り (判定には影響しない)

判定は VALID だが、蒸留 (ksn-distill) の入力として次の 2 点を記録しておく。いずれも
「実装と spec の不一致」ではなく、**合意の記述の粒度**の問題である。

1. **deviation 6 件目に「補間中は content も行の高さで測り直す」帰結が書かれていない。**
   Requirement「セル自己サイズと content の配置 (Android)」本文の「content は自然高のまま項目の
   上端に置かれ、行の高さに引き伸ばされない」は、補間している間だけは成立しない
   (`KsAnimatedHeight.kt:115-123` が `minHeight = maxHeight = currentHeight` で測り直す)。
   deviation 6 件目はこの Requirement を名指しでアニメーション化の対象としているため未記録乖離とは
   扱わなかったが、帰結を 1 文足しておくと蒸留時の ADR / concepts への写しが正確になる。
2. **deviation 6 件目が新しい利用契約を生んでいる。** 「テンプレートの根へ高さの制約を渡す
   (`propagateMinConstraints = true` か、根で背景を塗る)」は spec のどの Requirement にも無い
   利用者向けの契約で、現在は `KsCollectionView.kt:60-63` の KDoc・`dsl-samples.md:441-443`・
   `evidence/row-height-animation.md` の 3 か所にある。公開契約として concepts / handbook へ
   上げる候補。
