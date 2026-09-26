# 一致検証: sample-dark-mode-toggle (001 回目)

**日付**: 2026-09-26
**判定**: VALID

デルタスペック `specs/samples/spec.md` (ADDED 3 Requirement / 11 Scenario) と実装の対応を突き合わせた。パスは次の略記を使う。

- iOS: `samples/ios/KsCollectionViewSamples/` → `ios/`、UI テスト `samples/ios/KsCollectionViewSamplesUITests/` → `ios-ui/`
- Android: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/` → `and/`、単体テスト `samples/android/app/src/test/kotlin/jp/kamusoft/kscollectionview/samples/android/` → `and-test/`

## 対応表

### Requirement: 外観の切り替え

| Scenario | 実装 | テスト / 証跡 | 状態 |
|---|---|---|---|
| 両プラットフォームで同じ構成 | `ios/RootMenuView.swift:13-18`・`ios/SampleAppearance.swift:18-46`・`ios/SampleAppearanceRow.swift:19-24` / `and/RootMenuScreen.kt:36-46`・`and/SampleAppearance.kt:14-47`・`and/SampleAppearanceRow.kt:53-62` | `and-test/SampleAppearanceTest.kt` (文言・保存値が iOS と一致、外観の項目群がデモ画面の項目より前) / `ios-ui/AppearanceUITests.swift` (`test外観の見出しと3項目がデモ画面の項目より上に並ぶ`) / `ui/verification/*-root-*.png` | ✅ 一致 |
| 初回起動は「システム」 | `ios/SampleAppearance.swift:43`・`ios/RootMenuView.swift:6` / `and/SampleAppearance.kt:44,50-51`・`and/SampleAppearanceStore.kt:21-24` | `ios-ui/AppearanceUITests.swift` (`test保存が無い状態で起動するとシステムが選択中`) / `and-test/SampleAppearanceTest.kt` (保存が無いとき・未知の保存値) | ✅ 一致 |
| 選んだ値が起動し直しても残る | `ios/KsCollectionViewSamplesApp.swift:7`・`ios/RootMenuView.swift:6` (`@AppStorage`) / `and/SampleAppearanceStore.kt:27-32`・`and/MainActivity.kt:25-28` | `ios-ui/AppearanceUITests.swift` (`testダークを選んで起動し直してもダークが選択中`) / `and-test/SampleAppearanceTest.kt` (保存した値が読み戻せる)・`and-test/SampleAppearanceReflectionTest.kt` (ダークを保存すると Activity がダーク) / 「アプリ全体がダーク」は `evidence/ios-list-dark-direct-launch.png`・`evidence/android-list-dark-direct-launch.png`・`evidence/review-001-ios-reproduction.png` | ✅ 一致 |
| 読み上げで選択中が分かる | `ios/SampleAppearanceRow.swift:23,30` / `and/SampleAppearanceRow.kt:38-40,60` | `ios-ui/AppearanceUITests.swift` (`assertSelected`: 選択中の項目だけが「選択中」) / `and-test/SampleAppearanceTest.kt` (`ルートメニューは選択中の項目だけを選択中と読む`) | ✅ 一致 |

### Requirement: 外観の反映

| Scenario | 実装 | テスト / 証跡 | 状態 |
|---|---|---|---|
| 「ダーク」を選ぶとアプリ全体がダークになる | `ios/KsCollectionViewSamplesApp.swift:26`・`ios/SampleWindowStyleApplyingView.swift:20-29`・`ios/SampleTheme.swift:36-41` / `and/MainActivity.kt:25-28,65-69`・`and/SampleAppTheme.kt:21-26`・`samples/android/app/src/main/res/values-night/themes.xml` | `and-test/SampleAppearanceReflectionTest.kt` (保存がダークなら端末ライトでも Activity がダーク、表示モードがダークなら配色と Material の配色がダークの組) / `evidence/ios-root-dark-after-select.png`・`evidence/ios-list-dark-pushed.png`・`evidence/android-root-dark-after-select.png`・`evidence/android-list-dark-pushed.png` (再起動なしの反映は実行時の証跡) | ✅ 一致 |
| 「ライト」を選ぶと端末がダークでもライトで描かれる | 同上 (`.light` / `UI_MODE_NIGHT_NO` の上書き) | `and-test/SampleAppearanceReflectionTest.kt` (ライトを保存すると端末ダークでも Activity がライト) / `evidence/ios-largedata-light-on-device-dark.png`・`evidence/android-largedata-light-on-device-dark.png` (インジケータが見える) / `evidence/review-001-ios-reproduction.png` (中央) | ✅ 一致 |
| 「システム」に戻すと端末の変化に追随する | `ios/SampleAppearance.swift:28-34` (`.unspecified`) / `and/SampleAppearance.kt:29-34`・`and/SampleAppearanceStore.kt:42-45` (上書きなし) | `and-test/SampleAppearanceReflectionTest.kt` (システムでは端末の表示モード)・`and-test/SampleAppearanceTest.kt` (システムは上書きしない) / `evidence/ios-root-system-follows-device.png`・`evidence/android-root-system-follows-device.png` (表示したままの切り替え) | ✅ 一致 |
| 直接開いた画面にも効く | `ios/KsCollectionViewSamplesApp.swift:24-26` (`SampleLaunchView` より上) / `and/MainActivity.kt:25-28` (Activity 単位の上書き) | `evidence/ios-dark-screens-1〜3.png`・`evidence/android-dark-screens-1〜3.png` (起動引数 / 開始ルートで直接開いたもの)・`evidence/review-001-ios-reproduction.png` (右: `--screen リスト`) | ✅ 一致 |

### Requirement: 両プラットフォーム同値の 2 組の配色

| Scenario | 実装 | テスト / 証跡 | 状態 |
|---|---|---|---|
| ダークで崩れない | `ios/SamplePalette.swift:39-47`・`ios/SampleTheme.swift:9-15` / `and/SamplePalette.kt:49-57`・`and/SampleTheme.kt:21-50`・`and/SampleAppTheme.kt:36-60`、載せ替え (`ios/ListDemoView.swift`・`FixedGridDemoView.swift`・`SpacingPaddingDemoView.swift`・`HeightChangeVerificationView.swift`、`and/SampleSegmentedControl.kt`・`DiffUpdateDemoScreen.kt`・`TemplateSwitchDemoScreen.kt`) | `and-test/SamplePaletteParityTest.kt` (文字の組 4.5 以上・区切り 1.3 以上。値はレビュー側でも再計算して一致) / `evidence/ios-appearance-verification.md`・`evidence/android-appearance-verification.md` の 5.3 の表 | ✅ 一致 (Android のスライダーの残りの溝の基準の読み方は deviation.md 3 行目で合意済み) |
| ライトの見た目は変わらない | ライトの組は変更前の値 (`ios/SamplePalette.swift:26-34` / `and/SamplePalette.kt:34-42`) | 両 evidence の「ライトは変わらない」の画素比較 | ⚠️ deviation 記録済み (iOS の色を指定していなかった文字 5 つ・Android の Material の部品。deviation.md 1〜2 行目。補足あり) |
| 両プラットフォームで同じ値 | `ios/SamplePalette.swift` / `and/SamplePalette.kt` (7 色 × 2 組、色見本 9 色) | `and-test/SamplePaletteParityTest.kt` (iOS の値を写した表とライト / ダーク / 色見本を突き合わせ) | ✅ 一致 |

補足 (「ライトの見た目は変わらない」): Android の「画像グリッド」のメニューの開閉の印 (▼) も、ライトで黒 #000000 から文字の色 #111214 に変わる (`evidence/android-appearance-verification.md` に記録あり)。deviation.md の Android の項の列挙には入っていないが、同じ Material の既定の色の載せ替えによる差で、deviation.md 1 行目で Scenario を「ライトの組の値が変わらない」と読むことが合意されているため、その読みの内側として ⚠️ に数えた。記録の追記を review-001.md の Minor として挙げた。

## 追加検査

- [x] tasks.md: 5.4 以外はすべてチェック済みで、対応表と食い違う虚偽チェックは無い。5.4 (ライブラリの既定の色のオーナー目視) は未実施で、対応する Scenario は無いため対応表の対象外
- [x] 逆流検査: proposal.md / specs/samples/spec.md / ui/mock の最終更新は実装ファイル (最初の `SamplePalette.swift` 等) より前。実装期間に更新されたのは tasks.md (チェック) と ui/brief.md (視覚照合の記録の追記) と deviation.md だけで、いずれも実装中に書く欄。足場は未追跡のため git 履歴ではなく更新時刻で確かめた
- [x] 未記録乖離: ❌ に当たるものは無い (上の補足を参照)
- [x] 付随修正: deviation.md に `[付随修正]` の行は無い。diff のうち Scenario に直接対応しない変更は `ios-ui/GroupingDemoUITests.swift` (メニューの先頭に項目が増えたための送り) だけで、外観の項目群の追加に伴う既存テストの追随
- [x] UI 変更: ui/brief.md に承認 mock (`mock/plan-b-navy.html` / `mock/approved.png`、2026-09-26 オーナー承認) と視覚照合の記録、合意済みの差 (見出しを行として置く・OS の部品を塗り替えない等) がある
- [x] テスト: Android Sample 101 tests / 0 failures (`--rerun-tasks`、15 クラスの内訳を確認)。iOS Sample UI テスト 21 tests / 1 failure — 失敗は `LargeDataCountUITests.test件数に数値でない値を指定すると起動しない` で、この change より前のコードでも揺れる既知の問題 (`changes/ios-launch-failure-uitests/exploration.md`)。この change の Scenario に対応するテスト (`AppearanceUITests` 3 件、Android の新規 3 クラス 18 件) はすべて成功

## 判定

全 11 Scenario が「✅ 一致」または「⚠️ deviation 記録済み」。虚偽チェック・逆流は無い。テストの失敗 1 件はこの change の前から揺れる既知の問題で、この change の範囲の検証には当たらないため VALID とした。
