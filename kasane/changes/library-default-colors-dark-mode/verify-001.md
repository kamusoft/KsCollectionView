# 一致検証: library-default-colors-dark-mode (001 回目)

**日付**: 2026-10-06
**判定**: VALID

❌ は 0 件。全 Requirement / Scenario が「✅ 一致」で、虚偽チェック・逆流・テスト失敗は無い。

パスの略記 (この文書の中だけ):

- iOS 本体 = `ios/Sources/KsCollectionView/`、iOS テスト = `ios/Tests/KsCollectionViewTests/`
- Android 本体 = `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/`、Android テスト = `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/`

## 対応表

### collection-layout — MODIFIED「区切り線の色 (両プラットフォーム)」

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 色の指定 | iOS 本体 `KsCollectionViewController.swift:752` / Android 本体 `KsCollectionView.kt:442` | iOS テスト `KsCollectionEngineTests.swift:222` / Android テスト `KsCollectionViewLayoutTest.kt:412` (既存) | ✅ 一致 |
| 非表示との組み合わせ | 同上 (表示の有無は変更なし) | iOS テスト `KsCollectionEngineTests.swift:265` / Android テスト `KsCollectionViewLayoutTest.kt:424` (既存) | ✅ 一致 |
| ライトの既定の色 | iOS 本体 `KsDefaultColors.swift:13,30`・`KsHostingCell.swift:7` / Android 本体 `KsListSeparator.kt:18,28` | iOS テスト `KsDefaultSeparatorColorTests.swift`「区切り線のライト用の既定の色は赤217緑217青222…」「…ライトではライト用ダークではダーク用…」 / Android テスト `KsDefaultSeparatorColorTest.kt` `lightModeDrawsTheLightDefaultColor`・`defaultColorsMatchTheSharedValues`。期待値: #D9D9DE (変更前と同じ) | ✅ 一致 |
| ダークの既定の色 | iOS 本体 `KsDefaultColors.swift:14,30` / Android 本体 `KsListSeparator.kt:21,28`・`KsCollectionView.kt:440-442` | iOS テスト 同「…ライトではライト用ダークではダーク用の値で描かれ位置と本数は同じ」 / Android テスト `darkModeDrawsTheDarkDefaultColorAtTheSamePositions`。期待値: #38383A | ✅ 一致 |
| 表示中に表示モードが切り替わる | iOS: 外観で解決される色 1 つ (`KsDefaultColors.swift:38-45`) / Android: `KsCollectionView.kt:440-442` (構成の変化で組み立て直し) | iOS テスト「色を指定しない一覧を出したまま外観を切り替えると…」 / Android テスト `defaultColorFollowsTheDisplayModeWhileShown` (ライト → ダーク → ライト。位置・本数も確認) | ✅ 一致 |
| 固定の色を指定すると表示モードで変わらない | iOS 本体 `KsCollectionViewController.swift:752` / Android 本体 `KsCollectionView.kt:442` | iOS テスト「固定の色を指定した一覧はライトでもダークでも指定した色のままで…」 / Android テスト `specifiedColorIsKeptInBothDisplayModes` | ✅ 一致 |
| 指定を外すと表示モードの側の既定の色になる | 同上 | iOS テスト 同上 (後半) / Android テスト `removingTheSpecifiedColorFallsBackToTheDefaultOfTheCurrentMode` | ✅ 一致 |
| アプリが外観を上書きした場所に置く (iOS) | iOS 本体 `KsDefaultColors.swift:38-45` | iOS テスト「一覧を置いたwindowの外観だけを上書きすると…」(端末の表示モードの反対へ上書きする。実行した端末はライトで、ダークへの上書きになった) | ✅ 一致 |
| 画面の構成の夜間モードで決まる (Android) | Android 本体 `KsCollectionView.kt:440` | Android テスト `darkModeDrawsTheDarkDefaultColorAtTheSamePositions` (テーマなし)・`deviceNightModeIsUsedUnderALightMaterialColorScheme` (ライトの配色のテーマ) | ✅ 一致 |
| アプリが画面の構成を上書きした場合 (Android) | 同上 | Android テスト `overriddenConfigurationNightModeIsUsed` | ✅ 一致 |
| Material の配色だけをダークにした場合 (Android) | 同上 (Material の配色を読まない) | Android テスト `darkMaterialColorSchemeAloneDoesNotSwitchTheDefaultColor` | ✅ 一致 |
| 両プラットフォームで同じ値 | iOS 本体 `KsDefaultColors.swift:13-14` / Android 本体 `KsListSeparator.kt:18,21` | iOS テスト「既定の色4つのライトとダークの値が色の表の値と一致する」 / Android テスト `defaultColorsMatchTheSharedValues`。期待値: #D9D9DE / #38383A (承認 mock の色の表と一致) | ✅ 一致 |
| 区切り線の色 — Side Effects (なし) | 永続化・他の能力が読む状態・外への送信は無い (色の選択と描画だけ) | — | ✅ 一致 |

### image-loading — ADDED「KsImage の既定の表示の色」

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| ライトの読み込み中 | iOS 本体 `KsImage.swift:336`・`KsDefaultColors.swift:17,31` / Android 本体 `KsImage.kt:533,573` | iOS テスト `KsImageDefaultColorTests.swift`「一覧の外に置いたKsImageの既定の読み込み中は…」 / Android テスト `KsImageDefaultColorTest.kt` `lightModeDrawsTheLightDefaultLoading`。期待値: #E5E5EA | ✅ 一致 |
| ダークの読み込み中 | 同上 (`KsDefaultColors.swift:18` / `KsImage.kt:576`) | iOS テスト 同上 / Android テスト `darkModeDrawsTheDarkDefaultLoading`・`imageInsideACollectionDrawsTheDarkDefaultLoading`。期待値: #2C2C2E | ✅ 一致 |
| ライトとダークの失敗 | iOS 本体 `KsImage.swift:351,355` / Android 本体 `KsImage.kt:539-541` | iOS テスト「…既定の失敗は下地と印がライトとダークそれぞれの色で描かれる」 / Android テスト `lightModeDrawsTheLightDefaultFailure`・`darkModeDrawsTheDarkDefaultFailure`・`unreadableResourceDrawsTheDarkDefaultFailure`。期待値: 下地 #D1D1D6 / #3A3A3C、印 #8E8E93 / #8E8E93 | ✅ 一致 |
| 表示中に表示モードが切り替わる | iOS: 外観で解決される色 / Android 本体 `KsImage.kt:320,533,539` | iOS テスト「既定の読み込み中を出したまま…」「既定の失敗を出したまま…」 / Android テスト `defaultLoadingFollowsTheDisplayModeWhileShown`・`defaultFailureFollowsTheDisplayModeWhileShown` (どちらも往復し、状態が変わらないことを要求の数で確認) | ✅ 一致 |
| 取得の途中で表示モードが切り替わる | iOS: 表示の型は色だけが変わる / Android 本体 `KsImage.kt:323-333,360-363` (宣言を渡し直すだけで部品を作り直さない) | iOS テスト「読み込みを始めてから出た読み込み中の間に…」「先読みの完了を待つ間に出た読み込み中の間に…」 / Android テスト `switchingTheDisplayModeKeepsTheFetchStartedOnComposition`・`switchingTheDisplayModeKeepsTheFetchStartedWhenShown` (2 つの経路とも、要求の数・取り消しの数・結果の画像を確認) | ✅ 一致 |
| 先読みの完了を待つ間の読み込み中 | iOS 本体 `KsImage.swift:336` / Android 本体 `KsImage.kt:320,427` | iOS テスト「先読みの完了を待つ間に出る読み込み中の表示もダークの外観でダーク用の色になる」 / Android テスト `KsImageShownFrameTest.kt` `defaultLoadingIsDrawnInTheDarkColorInTheFirstFrameInNightMode` (最初の描画の画素) | ✅ 一致 |
| 上書きした表示モードで決まる | 同上 | iOS テスト「KsImageを置いたwindowの外観だけを上書きすると…」 / Android テスト `overriddenConfigurationNightModeIsUsed` | ✅ 一致 |
| 差し替えた表示は変わらない | iOS: 差し替えた表示は既定の表示の型を通らない / Android 本体 `KsImage.kt:320` (利用者の表示のときは色を未指定にする) | iOS テスト「読み込み中と失敗を差し替えたKsImageはライトでもダークでも利用者の表示のまま出る」 / Android テスト `substitutedLoadingIsDrawnAsIsInBothDisplayModes`・`substitutedFailureIsDrawnAsIsInBothDisplayModes` | ✅ 一致 |
| 一覧の外に置いた KsImage | 同上 (一覧に依存しない) | iOS テスト「一覧の外に置いたKsImageの…」2 本 / Android テスト `darkModeDrawsTheDarkDefaultLoading`・`darkModeDrawsTheDarkDefaultFailure` (どちらも一覧の外) | ✅ 一致 |
| 両プラットフォームで同じ値 | iOS 本体 `KsDefaultColors.swift:17-26` / Android 本体 `KsImage.kt:573-588` | iOS テスト「既定の色4つのライトとダークの値が色の表の値と一致する」 / Android テスト `KsImageDefaultColorTest.kt` `defaultColorsMatchTheSharedValues`。期待値は上の 3 行のとおりで、承認 mock の色の表と一致 | ✅ 一致 |
| KsImage の既定の表示の色 — Side Effects (なし) | 永続化・他の能力が読む状態・外への送信は無い。表示モードの切り替えで取得の要求も増えない (上のテストで確認) | — | ✅ 一致 |

### collection-interaction — ADDED「タップしたときの色の濃さの決まり方」

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 半透明の色を指定する (iOS) | iOS 本体 `KsCollectionView.swift:276-281` (加工せずに持つ)・`KsHostingCell.swift:153,188` (前面に置いてそのまま塗る。変更なし) | iOS テスト `KsPublicAPITests.swift:61` (不透明度ごと設定に入る)・`KsCollectionEngineTests.swift:364` (指定した色がフィードバックに入り前面に出る。既存) | ✅ 一致 |
| 不透明度が違う同じ色みを指定する (Android) | Android 本体 `KsCollectionView.kt:452-454` (加工せずに標準の波紋へ渡す。変更なし) | 自動テストなし (波紋が描かれないため、スペックと tasks 4.2 が証跡での確認と定めている)。`evidence/android-touch-feedback-opacity.md`: 不透明な色と 10% の色で、押している行の全画素が一致 (ライト・ダーク) | ✅ 一致 |
| タップしたときの色の濃さの決まり方 — Side Effects (なし) | 状態変更なし (ライブラリの動きは変えていない) | — | ✅ 一致 |

### samples — ADDED「デモ画面「リスト」のタップしたときの色」

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 両プラットフォームで同じ値 | `samples/ios/KsCollectionViewSamples/ListDemoView.swift:39` (`SampleTheme.accent.opacity(0.1)`) / `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/ListDemoScreen.kt:60` (`SampleTheme.accent.copy(alpha = 0.1f)`) | 自動テストなし (提案が「新しいテストは足さない」と定めている)。ソースの突き合わせで確認。期待値: アクセントの 10% (`ui/brief.md` の承認の記録) | ✅ 一致 |
| 押している間の見え方 | 同上 | `ui/verification/` の `ios-list-pressed-light.png`・`ios-list-pressed-dark.png`・`android-list-pressed-light.png`・`android-list-pressed-dark.png` と `ui/brief.md` の照合記録 ④ | ✅ 一致 |
| デモ画面「リスト」のタップしたときの色 — Side Effects (なし) | 状態変更なし | — | ✅ 一致 |

## 追加検査

- **tasks.md**: 全 15 項目がチェック済みで、どれも対応する実装・テスト・証跡がある (虚偽チェックなし)。4.1 → `ui/verification/` の 16 枚と `ui/brief.md` の照合記録、4.2 → `evidence/android-touch-feedback-opacity.md`、4.3 → `evidence/` の並べ替えの持ち上げの画像 4 枚 (説明の文書が無い点は `review-001.md` の Minor)、4.4 → 下の実行結果
- **逆流検査**: proposal.md・specs/ の 4 ファイル・ui/mock/ に HEAD との差分は無い。tasks.md はチェックの付け替えだけ、ui/brief.md は「照合記録」の節の追加だけ。kasane/decisions・handbook・concepts にも差分は無い
- **未記録乖離**: 無し (❌ が無い)
- **Side Effects (逆向きの検査)**: 4 つの Requirement はどれも「なし」。実装が起こす状態変更に、永続化・他の能力が読む状態・外への送信に当たるものは無い (色の定数の追加、描画時の色の選択、doc コメント、Sample に渡す値の変更だけ)
- **付随修正**: Scenario に対応しない差分は `KsCollectionView.kt:746` の `?.` の除去 1 件で、deviation.md に `[付随修正]` として記録済み。ほかに Scenario に対応しない実装の差分は無い
- **UI 変更**: `ui/brief.md` に承認モックの記録 (案 A、2026-10-06 オーナー承認) と照合記録 (合意済み妥協 0 件) がある。照合記録には「オーナーの最終承認はまだ受けていない」とあり、最終承認は呼び出し元の段取りに残っている。照合記録の色の一致は、16 枚の画素を数え直して再現した
- **テスト (自分で実行。2026-10-06、絞り込みなし)**: iOS 本体 567 tests / 0 failures、iOS Sample 48 tests / 0 failures (ユニット 37 + UI 11) — どちらも iPhone 17・iOS 27.0。Android 本体 512 tests / 0 failures (31 クラス)、Android Sample 163 tests / 0 failures (21 クラス)
  - 参考: iOS 本体を iOS 17.5 で流すと 567 tests のうち既存の 1 件 (`KsLoadingIndicatorColorTests` の Pull to Refresh の色の追随) が失敗する。変更前のソースでも同じ 1 件が失敗することを確かめた。この change のスペックの対象外 (利用者が指定した外観で値の変わる色の扱い。proposal の Non-Goals) で、判定には含めていない
  - シミュレータは作業専用に 2 つ作り、どちらも終了後に削除した

## 判定の根拠

全 Requirement / Scenario (Side Effects の行を含む) が ✅ で、虚偽チェック・逆流・未記録乖離・テスト失敗が無いため VALID とする。

確かめていない条件 (スペックの Scenario の外): iOS 16、Android 10・11 の波紋の濃さ。
