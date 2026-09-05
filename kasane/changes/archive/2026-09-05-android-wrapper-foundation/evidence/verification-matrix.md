# Requirement と検証層の対応 (Android)

各欄には実在するテスト名と、そのテストが観測している内容だけを書く。自動検証が無い欄は
「自動検証なし」と明示し、どの層でも押さえられていない条件は最後の「未検証の一覧」に集める。

列の意味:

| 列 | 置くもの |
|---|---|
| unit | Composable を立てずに関数・値型を直接呼ぶ検証 (`resolveItems` / `KsScrollController` 単体) |
| Compose UI テスト | Robolectric 上で `createComposeRule` に実描画させ、semantics・実座標・画素で観測する検証 |
| Macrobenchmark | 実機で `samples/android/benchmark` が人手を挟まず走らせる計測 |
| 実機手動 | 実機・エミュレータでしか成立しない観測 (目視・静止画) |

Compose UI テストの実体は `android/kscollectionview/src/test/kotlin/` の 3 クラス (54 件) と
`samples/android/app/src/test/kotlin/` の 2 クラス (12 件)。区切り線・タップ・content 配置など実描画を
見るクラスは `@GraphicsMode(GraphicsMode.Mode.NATIVE)` を付けている (既定の legacy graphics では
描画が実行されず画素比較が空振りするため)。

iOS 追随の 3 Requirement (推論形 / 区切り線の色の iOS 側 / iOS Sample の追随) は iOS の
Simulator 実行テストが担う。表では unit 欄にそのテスト名を置き、Android 側の対応と区別する。

## collection-core

| Requirement / Scenario | unit | Compose UI テスト | Macrobenchmark | 実機手動 |
|---|---|---|---|---|
| プレーンな配列と安定 ID / key ラムダで配列を表示する | 自動検証なし | `KsCollectionViewCoreTest.displaysEveryItemAndKeepsComposedItemsBounded` が 100 件の先頭表示・index 99 へのスクロール到達・同時コンポジション数が件数未満であることを検証 | 不要 | 自動検証なし (Sample「リスト」で目視。`sample-parity-comparison.md` #1) |
| プレーンな配列と安定 ID / release ビルドでの重複 ID | `KsCollectionViewCoreTest.duplicateIdStopsInDebug` が `resolveItems` の debug 停止を検証。`.unsavableKeyStopsInDebug` が Bundle 保存不可の key の debug 停止を検証 | `KsCollectionViewCoreTest.duplicateIdKeepsLaterItemWhenNotDebug` が後勝ちの表示・先の要素が消えること・項目数 2・警告ログの出力を検証 | 不要 | 不要 |
| 差分更新 / 内容変更の反映 | 自動検証なし | `KsCollectionViewCoreTest.contentUpdateKeepsRememberedStateOfItem` が新内容の描画と `remember` した値の維持を検証 | 不要 | 不要 |
| 差分更新 / テンプレートキー変更での再描画 | 自動検証なし | `KsCollectionViewCoreTest.templateKeyChangeRedrawsWithNewTemplate` が同一 ID でのテンプレート差し替えを検証 | 不要 | 不要 |
| 差分更新 / 親の状態をテンプレートで読む | 自動検証なし | `KsCollectionViewCoreTest.parentStateReadInsideTemplateIsReflected` が新旧の選択項目の描画更新を検証 | 不要 | 不要 |
| 値キーによるテンプレート切り替え / キー値ごとのテンプレート適用 | 自動検証なし | `KsCollectionViewCoreTest.templatePerKeyValueIsApplied` が 2 種のキーそれぞれの描画を検証 | 不要 | 自動検証なし (Sample「テンプレート切り替え」で目視。`templates-android.png`) |
| 値キーによるテンプレート切り替え / 単一テンプレートの軽量形 | 自動検証なし | `KsCollectionViewCoreTest.singleTemplateFormDrawsEveryItem` がキー登録なしの全件描画を検証 | 不要 | 不要 |
| 値キーによるテンプレート切り替え / release ビルドでの二重登録 | 自動検証なし | `KsCollectionViewCoreTest.duplicateTemplateRegistrationKeepsLastWhenNotDebug` が後勝ちの描画を、`.duplicateTemplateRegistrationStopsInDebug` が debug 停止を検証 | 不要 | 不要 |
| 未登録キーの挙動 / release ビルドでの未登録キー | 自動検証なし | `KsCollectionViewCoreTest.unregisteredKeyShowsEmptyItemWhenNotDebug` が該当要素の位置が空項目として保たれること (後続要素が下がる) と警告ログを、`.unregisteredKeyStopsInDebug` が debug 停止を、`.sameWarningIsReportedOnlyOnce` が再コンポーズでの警告の重複抑止を検証 | 不要 | 不要 |
| 大量件数での仮想化・再利用 / 可変行高混在 10,000 件のスクロール | 自動検証なし | `KsCollectionViewCoreTest.displaysEveryItemAndKeepsComposedItemsBounded` が 100 件で同時コンポジション数の上限を検証。**自動テストの射程は 100 件であり、10,000 件は Macrobenchmark が担う** | `LargeDataScrollBenchmark` が 10,000 件・2 列・可変行高混在の fixture でフリック 3 秒 × 3 試行を素の `LazyVerticalGrid` / `LazyColumn` と突き合わせ (`performance-measurement.md`)。テンプレート呼び出しの累計が通過項目数とほぼ同数に留まること、および同時生存数が可視範囲 + 先読み分に留まることは `template-reuse-measurement.md` | Pixel 4a / Pixel 6a での実行そのもの (実機必須。エミュレータでは計測しない) |
| 大量件数での仮想化・再利用 / メモリが件数に比例しない | 自動検証なし | 自動検証なし | `LargeDataMemoryBenchmark` が 1,000 件 / 10,000 件の自動往復で PSS 合計の定常化 (連続 2 往復の増分 2% 以内) と件数比に比例しないことを検証 (`performance-measurement.md`) | 同上 |
| 値キーテンプレートの推論形 (iOS 追随) / 推論形の宣言がコンパイルできる | iOS: `KsSwiftUIIntegrationTests.test型注釈なしの推論形で宣言したテンプレートがキーごとに描画される` が型注釈なしの宣言のコンパイルとキー別描画を検証。組み立ては `KsPublicAPITests` / `KsTemplateRegistryTests` の `KsTemplate(.message)` 形 | 該当なし (iOS の Requirement) | 不要 | 自動検証なし (iOS Sample「テンプレート切り替え」で目視。review-001) |

## collection-layout

| Requirement / Scenario | unit | Compose UI テスト | Macrobenchmark | 実機手動 |
|---|---|---|---|---|
| layout 値による表示形態 / 固定列グリッド | 自動検証なし | `KsCollectionViewLayoutTest.fixedColumnsPlacesItemsInDeclaredColumnCount` が宣言した列数での配置を検証。不正値は `.invalidLayoutValuesAreDetected` / `.invalidLayoutValueStopsInDebug` | 不要 | 不要 |
| layout 値による表示形態 / adaptive グリッド | 自動検証なし | `KsCollectionViewLayoutTest.adaptiveColumnsKeepsColumnSpacingAndDistributesRemainder` が列数の自動決定・列間の固定・余剰幅の項目幅への配分を実座標で検証 | 不要 | 自動検証なし (Sample「グリッド (adaptive)」で目視。`adaptive-grid-android.png`) |
| layout 値による表示形態 / 向き別列数 (コンテナ縦横比基準) | 自動検証なし | `KsCollectionViewLayoutTest.orientationColumnsUsesPortraitCountWhenContainerIsTall` / `.orientationColumnsUsesLandscapeCountWhenContainerIsWide` がコンテナの縦横比だけで列数が切り替わることを検証 | 不要 | 自動検証なし (実機の回転で目視。`orientation-grid-android.png`。分割画面でのリサイズは未実施) |
| レイアウトの動的切り替え / list とグリッドの切り替え | 自動検証なし | `KsCollectionViewLayoutTest.switchingLayoutKeepsDataAndAnchorItemVisible` が、先頭でない位置 (index 20) をアンカーにして切り替え後もアンカーが表示範囲にあること・2 列として並ぶこと・先頭へ戻らないことを検証 | 不要 | 自動検証なし (Sample「グリッド (固定列)」の list⇄grid で目視) |
| スペーシング / グリッドの行間・列間 | 自動検証なし | `KsCollectionViewLayoutTest.rowAndColumnSpacingAreApplied` が指定した行間・列間を、`.spacingDefaultsToZero` が既定 0 を、`.listRowSpacingIsAppliedWhenSpecified` / `.listWithoutParenthesesBehavesAsDefaultList` が list 側の指定と括弧なし形を検証 | 不要 | 自動検証なし (Sample「スペーシングと余白」の滑り操作で目視) |
| contentPadding / 内側余白 | 自動検証なし | `KsCollectionViewLayoutTest.contentPaddingInsetsContent` が 4 辺個別の内側余白と幅の縮みを実座標で検証。`KsCollectionViewInteractionTest.scrollPositionsUseViewportInsideContentPadding` が余白の内側を表示範囲の基準にすることを検証 | 不要 | 自動検証なし (先頭・末尾までスクロールしたときの余白と、インジケータが余白の影響を受けないことは目視) |
| list の区切り線 / 既定表示と opt-out | 自動検証なし | `KsCollectionViewLayoutTest.listSeparatorsAreDrawnByDefault` が先頭上端・行間・最終行下端の 3 本を画素で、`.listSeparatorsAreDrawnOverOpaqueItemBackground` が不透明背景でも隠れないことを、`.listSeparatorsCanBeTurnedOff` が opt-out を検証 | 不要 | 不要 |
| list の区切り線 / グリッドでは出ない | 自動検証なし | `KsCollectionViewLayoutTest.gridDrawsNoSeparators` が画素で不在を検証 | 不要 | 不要 |
| 区切り線の色 / 色の指定 | iOS: `KsPublicAPITests.test区切り線の色を指定しなければ既定の色になる`。iOS 側の描画は `KsCollectionEngineTests.test区切り線の色を指定すると位置と本数を変えずにその色で描く` | `KsCollectionViewLayoutTest.listSeparatorColorChangesOnlyTheColor` が 3 本とも指定色になり位置・本数が変わらないことを画素で検証 | 不要 | 自動検証なし (Sample「リスト」の 3 択で両プラットフォームを目視。review-001 / `sample-parity-comparison.md` #1) |
| 区切り線の色 / 非表示との組み合わせ | iOS: `KsCollectionEngineTests.test区切り線が非表示なら色を指定しても描かない` | `KsCollectionViewLayoutTest.listSeparatorColorDrawsNothingWhenSeparatorsAreHidden` が画素で不在を検証 | 不要 | 不要 |
| ルートヘッダー / フッター / ヘッダーのスクロール追従 | 自動検証なし | `KsCollectionViewLayoutTest.headerScrollsAwayWithContent` がスクロール後にヘッダーが表示範囲から外れることを検証 | 不要 | 不要 |
| ルートヘッダー / フッター / 空配列でのヘッダー / フッター | 自動検証なし | `KsCollectionViewLayoutTest.headerAndFooterAreShownForEmptyItems` が項目 0 件でも両方が出ることを検証 | 不要 | 不要 |
| ルートヘッダー / フッター / グリッドでの全幅ヘッダー | 自動検証なし | `KsCollectionViewLayoutTest.headerSpansAllColumnsInGrid` がヘッダー幅と、その下に列が並ぶことを検証 | 不要 | 不要 |
| セル自己サイズと content の配置 / 可変行高 | 自動検証なし | `KsCollectionViewLayoutTest.rowHeightFollowsContent` が折り返す行だけが高くなること・行間に余分な空白が生じないことを検証 | 不要 | 自動検証なし (Sample「大量件数」で切れ・余白を目視) |
| セル自己サイズと content の配置 / 行の高さ変化のアニメーション | 自動検証なし | `KsCollectionViewLayoutTest.rowHeightChangeFromParentStateAnimates` / `.rowHeightChangeFromTemplateStateAnimates` / `.rowHeightChangeAnimatesInGrid` が、クロックを 1 フレームずつ進めて下の行の上端を記録し、中間の位置を複数フレーム通ることを検証。`.headerHeightChangeAnimates` がヘッダーの高さ変化について同じ判定を行う。`.rowHeightCollapseKeepsContentBottomAtRowBottom` が折りたたみの全フレームで中身の下端と行の下端が一致すること (中身と枠の間に帯ができないこと) を検証 | 大量件数のフリックへの上乗せを計測 (`performance-measurement.md` の追補) | 実機 (Pixel 4a) で親 state / テンプレート内 state × list / grid の 5 通りを毎フレームの行高で A/B 判定済み。折りたたみ中の帯の有無は、アニメーションを 10 倍に引き伸ばして撮った連続静止画の画素で A/B 判定済み (`row-height-animation.md`)。利用契約として、補間中はテンプレートの根に行の高さが制約として渡る — 根が制約を使わない透明な箱だと折りたたみの途中でページ背景が見えるため、根で背景を塗るか `propagateMinConstraints = true` で内側へ高さを渡す (Sample の「テンプレート内 state」経路は後者を採用済み。この契約は `KsCollectionView` の doc コメントにも書いてある)。制約に従わない content が行の外へ描かれないことは `.rowHeightAnimationClipsContentIgnoringHeightConstraint` が画素で検証 |
| セル自己サイズと content の配置 / 狭い content の水平配置 | 自動検証なし | `KsCollectionViewLayoutTest.narrowContentIsCenteredAndWideContentFillsFromStart` が狭い content の水平中央と `fillMaxWidth` の先頭敷きを実座標で検証 | 不要 | 不要 |

## collection-interaction

| Requirement / Scenario | unit | Compose UI テスト | Macrobenchmark | 実機手動 |
|---|---|---|---|---|
| アイテムタップ / 項目内ボタンとの競合 | 自動検証なし | `KsCollectionViewInteractionTest.itemButtonConsumesTouchInsteadOfItemTap` がボタンの実座標タップでボタンだけが反応することを、`.itemButtonPressDoesNotStartItemFeedback` が記録用 `Indication` で子押下中・離した後とも親へ `PressInteraction` が流れないこと (項目背景では流れることの正の対照付き) を検証 | 不要 | 不要 |
| アイテムタップ / タップで型付き要素が渡る | 自動検証なし | `KsCollectionViewInteractionTest.tapPassesTappedItemToCallback` が要素そのものの受け渡しを、`.tapHandlerAttachesTapAndFeedbackTarget` がタップ・長押しの受け口が項目に付くことを検証 | 不要 | **フィードバックの塗り (ripple) が実際に描かれること、`touchFeedbackColor` の色が ripple に届くことは未検証** (Robolectric では押下状態は成立するが塗りが描かれない) |
| アイテムタップ / ロングタップ | 自動検証なし | `KsCollectionViewInteractionTest.longTapPassesItemAndSuppressesTap` が長押し時に通常タップが発火しないことを検証 | 不要 | 不要 |
| アイテムタップ / ハンドラ未宣言ではフィードバックなし | 自動検証なし | `KsCollectionViewInteractionTest.noHandlerMeansNoTapTargetAndNoFeedback` がタップ・長押しの受け口が付かないことを検証 (受け口が無いことがフィードバックを出さないことと同義) | 不要 | 不要 |
| アイテムタップ (Requirement 本文) / スクロール開始によるタップのキャンセル | 自動検証なし | 自動検証なし (`combinedClickable` の既定挙動に委ねている) | 不要 | **未検証** (Sample のリストで押下したまま指を滑らせる操作が要る) |
| スクロール制御 / 存在しない ID への命令 | 自動検証なし | `KsCollectionViewInteractionTest.scrollToMissingIdDoesNothing` が位置の不変と警告ログを検証 | 不要 | 不要 |
| スクロール制御 / ID 指定スクロール | 自動検証なし | `KsCollectionViewInteractionTest.scrollToCenterPlacesItemAtViewportCenter` が中央配置を、`.scrollToItemAccountsForHeaderIndex` がヘッダーを index に数えないことを検証。動きの過程は `.animatedCenterScrollNeverReversesDirection` / `.animatedEndScrollNeverReversesDirection` / `.animatedCenterScrollNeverReversesWithMixedItemHeights` が毎フレームのスクロール量を採り、進行方向と逆向きの移動が無いことを検証 | 不要 | Sample「スクロール制御」の 3 ボタンで目視。「Item 50」の動きは毎フレームのスクロール量の A/B で判定済み (`scroll-center-motion.md`) |
| スクロール制御 / データ反映後のスクロール実行 | 自動検証なし | `KsCollectionViewInteractionTest.scrollToEndReachesItemAddedInTheSameFrame` が同一処理内で追加した要素まで到達することを検証 | 不要 | 不要 |
| スクロール制御 / 連続する命令 | `KsScrollController.processedCommandCount` を用いた待機 (`awaitCommands`) が命令の消化を観測 | `KsCollectionViewInteractionTest.laterCommandWinsOverEarlierOne` が最終位置が最後の命令で決まることを検証 | 不要 | **先行アニメーションが「中断される」こと自体は未検証** (最終位置しか見ていない) |
| スクロール制御 / 待機中に対象が削除された命令 | 自動検証なし | `KsCollectionViewInteractionTest.commandForRemovedItemIsSkippedAndLaterCommandRuns` が削除済み対象の no-op と後続命令の実行を検証 | 不要 | 不要 |
| スクロール制御 / 到達できない位置の要求 | 自動検証なし | `KsCollectionViewInteractionTest.unreachableCenterClampsToScrollableEnd` が末尾での停止と対象の可視を検証 | 不要 | 不要 |
| スクロール制御 / 複数接続は最後勝ち | 自動検証なし | `KsCollectionViewInteractionTest.lastAttachedCollectionWins` が後に接続した側だけが動くことを検証 | 不要 | 不要 |
| スクロール制御 / 未接続 no-op | `KsCollectionViewInteractionTest.unattachedControllerIsNoOp` が `processedCommandCount == 0` を検証 | 同テストが表示位置の不変も検証 | 不要 | 不要 |
| スクロール制御 / 接続解除後の no-op | 自動検証なし | `KsCollectionViewInteractionTest.detachedControllerIsNoOp` が解除後の命令で位置が変わらず例外にもならないことを検証 | 不要 | 不要 |

## samples

| Requirement / Scenario | unit | Compose UI テスト | Macrobenchmark | 実機手動 |
|---|---|---|---|---|
| Android Sample の器 / 本体の修正が Sample に映る | 自動検証なし | 自動検証なし | 不要 | Sample のビルドで本体のタスク (`:android:kscollectionview:*`) が走ることを確認。置換が外れた場合は明示 `dependencySubstitution` によりビルドエラーになる (公開版へ落ちない) |
| デモ画面の集合と文言の一致 / ルートメニューの一致 | `SampleScreenParityTest.デモ画面のタイトルと順序が iOS と一致する` / `.デモ画面は 9 つある` / `.メニューの文言と画面タイトルは同じ宣言元から引く` が宣言元 (`SampleScreen`) の文言・順序・単一宣言を検証 | 自動検証なし | 不要 | ルートメニューの並びを目視 (`sample-parity-comparison.md` / `root-menu-ios.png`) |
| デモ画面の集合と文言の一致 / デモ画面の構成一致 | 自動検証なし | `SampleDemoScreenTest.グリッド固定列画面は grid で始まり list へ切り替えられる` が初期値と操作を検証 | 不要 | iOS と並べた目視 (`sample-parity-comparison.md` #2、`fixed-grid-ios.png`) |
| デモ画面の集合と文言の一致 / 全画面の対応表による照合 | 自動検証なし | 自動検証なし | 不要 | 9 画面 + 固有検証画面の対応表と静止画 (`sample-parity-comparison.md`。不一致 1 件 = タップのフィードバック色。deviation.md に本体側の統一課題として追跡あり) |
| デモ画面の集合と文言の一致 / 「リスト」画面の区切り線 3 択 | 自動検証なし | `SampleDemoScreenTest.リスト画面の区切り線の初期選択は既定である` / `.リスト画面の区切り線は 3 択を選び直せる` が初期選択と 3 択の選び直しを検証 | 不要 | 色の実表示は目視 (Android: `../ui/verification/list-default.png` / `list-accent.png`、iOS: review-001 の Simulator 確認) |
| Android 固有の検証画面 / 親の状態による展開 | 自動検証なし | `SampleDemoScreenTest.検証画面は親の状態の経路で展開と折りたたみができる` が展開・折りたたみと展開中の行数を検証。`.検証画面は list と grid を切り替えられる` がレイアウト切替を検証 | 不要 | 展開時に本文が上端よりはみ出さないことは目視 (`height-change-android.png` / `height-change-expanded-android.png`) |
| Android 固有の検証画面 / テンプレート内の状態による展開 | 自動検証なし | `SampleDemoScreenTest.検証画面はテンプレート内の状態の経路で展開できる` が親の計数を動かさずに本文が現れること (展開まで) を、`.検証画面のテンプレート内の状態は画面外への往復で初期値へ戻る` が 60 行のうち対象行を最終行まで送って戻したときに本文が消えていること (Scenario の THEN) を検証 | 不要 | 実機 (Pixel 4a) で展開 → 画面外 → 復帰の 3 時点を静止画で記録 (`height-change-template-state-expanded.png` / `-offscreen.png` / `-restored.png`) |
| 性能計測の自動実行 / 計測の再実行 | 自動検証なし | 自動検証なし | `LargeDataScrollBenchmark` / `LargeDataMemoryBenchmark` を実機に対して繰り返し実行し、同じ手順が再現されることを確認済み (スクロールは 4 実行、メモリは暖機と本計測を独立に記録。`performance-measurement.md`) | 実機の接続そのもの |
| iOS Sample と dsl-samples の追随 / iOS Sample の追随 | iOS: `KsSwiftUIIntegrationTests.test型注釈なしの推論形で宣言したテンプレートがキーごとに描画される` (推論形の成立) | 該当なし (iOS の Requirement) | 不要 | iOS Simulator でルートメニュー → 「リスト」の 3 択と「テンプレート切り替え」を目視 (review-001) |

## 未検証の一覧

自動・手動のどの層でも押さえられていない条件。いずれも実装の欠落ではなく、検証手段の側の限界による。

| 条件 | 出典 | 押さえられない理由 | 押さえるとしたら |
|---|---|---|---|
| `touchFeedbackColor` に渡した色が実際の ripple の塗りに現れる | collection-interaction「アイテムタップ」Requirement 本文 | Robolectric では押下状態は成立するが ripple の塗りが描かれない。受け口 (`OnClick` semantics) と押下の伝播までが自動検証の限界 | 実機で押下中の画面を撮って色を見る。押下中の静止画を得る操作手順が要る |
| 後の命令が先行するスクロールアニメーションを中断する | collection-interaction「スクロール制御」Requirement 本文 (Scenario「連続する命令」の THEN 後半) | 現テストは最終位置だけを見ており、途中で止まったか最後まで走ってから上書きされたかを区別できない | アニメーション中の位置を時系列で採る計測、または実機での目視 |
| 押下追跡中にスクロールが始まるとタップがキャンセルされる | collection-interaction「アイテムタップ」Requirement 本文 | `combinedClickable` の既定挙動に委ねており、Scenario も無い | 実機で押下したまま指を滑らせ、コールバックが出ないことを見る |
| スクロールインジケータの位置が `contentPadding` の影響を受けない | collection-layout「contentPadding」Requirement 本文 | Robolectric の描画にインジケータが現れない | 実機で左右余白を変えながらインジケータの位置を目視 |
| 分割画面でのリサイズによる向き別列数の切り替え | collection-layout「layout 値による表示形態」Scenario「向き別列数」の WHEN | コンテナ縦横比の変化としては自動検証済みだが、分割画面の操作自体は実機でしか作れない | 実機の分割画面で Sample「向きで列数変更」を開いて目視 |
| フッターの高さ変化のアニメーション | collection-layout「セル自己サイズと content の配置」Scenario「行の高さ変化のアニメーション」(ヘッダー / フッターへの既定適用) | ヘッダーは `headerHeightChangeAnimates` で押さえたが、フッターは押し出される対象が無く、同じ形の観測点を作れない。Sample「ルートヘッダー/フッター」画面もフッターの高さが変わらない | 高さの変わるフッターを持つ画面を足し、フッター自身の上端を毎フレーム採る |
