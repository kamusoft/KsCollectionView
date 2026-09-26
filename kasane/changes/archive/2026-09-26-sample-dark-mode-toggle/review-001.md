# レビュー結果: sample-dark-mode-toggle (001 回目)

**日付**: 2026-09-26
**判定**: APPROVED

## サマリー

外観の切り替え (見出し「外観」と 3 択・印・「選択中」の読み上げ・保存) と反映 (iOS は window の `overrideUserInterfaceStyle`、Android は `attachBaseContext` の Configuration 上書きと `recreate()`) は、デルタスペックの全 Requirement を満たしている。配色は両プラットフォームの `SamplePalette` に同じ名前・同じ並び・同じ RGBA の 2 組で置かれ、単体テストで突き合わされている。Critical / Major は無い。記録の粒度とコメントの参照先に Minor が 2 件、コメントの理由づけに Suggestion が 1 件ある。

## 照合した規約

- ソースコメント規約 (always)
- Sample のプラットフォーム間一致 (`samples/` を触るとき)
- テスト実行規約 (テストを実行するとき・結果を報告するとき)
- lessons/code-review.md の重点観点 L-001 (証跡の数値の再現)
- 関連の決定: cross/ADR-0004 (accepted)、cross/ADR-0007 (proposed。sample-parity の「dark mode 追随より一致を優先」の一文を改める決定で、改訂は蒸留時の予定。proposed のため判定の根拠にはしていない)

sample-parity は節ごとに照合した。「保証すること」(同じ文言・同じ構成・同じ RGBA・semantic color を使わない・メニューと画面タイトルの一致) は満たす。「dark mode 追随より一致を優先する」の一文は文面の上ではこの change と衝突するが、2 組の同値の配色と同じ切り替えで一致を保っており、趣旨は守られている (文面の改訂は cross/ADR-0007 の範囲)。「許容される差異」は、OS の部品 (ステータスバー・segmented・iOS のルートメニューの区切り線) を塗り替えない扱いとして brief.md に記録されている。

## 確認したこと

### ビルドとテスト (レビュー側で実行)

- Android Sample: `./gradlew :app:testDebugUnitTest --rerun-tasks` で **101 tests / 0 failures / 0 errors** (15 クラス。新規の `SampleAppearanceTest` 8・`SampleAppearanceReflectionTest` 5・`SamplePaletteParityTest` 5 を含み、期待するクラスがすべて現れた)。`:app:assembleDebug` / `assembleRelease` / `assembleBenchmark` 成功
- iOS Sample: 実装側とは別に作ったシミュレータ (iPhone 17 Pro / iOS 26.5) で `xcodebuild test -scheme KsCollectionViewSamples` を実行し **21 tests / 1 failure**。失敗は `LargeDataCountUITests.test件数に数値でない値を指定すると起動しない` の `Expected failure ... but none recorded` で、この change より前のコードでも揺れることが確認済みの既知の問題 (`changes/ios-launch-failure-uitests/exploration.md`)。新規の `AppearanceUITests` 3 件と、手の入った `GroupingDemoUITests` 6 件はすべて成功
- ライブラリ本体はこの diff で変わっていないため再実行していない (指揮側の把握: Android 321 件成功)
- 標準 lint (`comment-policy-lint.py` / `local-path-lint.py` / `identity-lint.py`): 検出 0 件

### 証跡の数値の再現 (L-001)

- ダークの組のコントラスト比 (15.52 / 13.30 / 6.56 / 5.62 / 5.82 / 4.99 / 5.82 / 1.34) を配色の値から独立に計算し、証跡の値と一致した
- iOS: 別のシミュレータで保存値と端末の表示モードを組み合わせて起動し、画素値を読んだ。端末ライト + 「ダーク」保存 → 下地 #0D1321・行 #182236、端末ダーク + 「ライト」保存 → #F2F2F7・#FFFFFF、端末ダーク / ライト + 「システム」 → それぞれダーク / ライトの組、「ダーク」保存 + `--screen リスト` で直接開いた画面もダーク。ナビゲーションバーの題名とステータスバーも外観に揃っていた (`evidence/review-001-ios-reproduction.png`: 左から 端末ライト + ダーク / 端末ダーク + ライト / 直接開いた「リスト」のダーク)
- Android の実行時の再現は行っていない (別のエミュレータを用意できなかった)。Activity の表示モードの上書きと配色の組の選択は、単体テスト `SampleAppearanceReflectionTest` (端末ライト + ダーク保存、端末ダーク + ライト保存、システム) で確かめた

### 観点

- 仕様充足: 全 Scenario に実装とテストまたは証跡がある (対応表は verify-001.md)。tasks.md のチェックは 5.4 (未実施として扱う) 以外すべて済みで、虚偽チェックは無い。proposal / specs / mock の更新時刻は実装ファイルより前で、足場の書き換えは無い
- 3.3 の外部 API: `UIView.overrideUserInterfaceStyle` (iOS 26.5 SDK の `UIView.h:701`、`API_AVAILABLE(ios(13.0))`)、`ContextThemeWrapper.applyOverrideConfiguration` と `Activity.recreate` (compileSdk の android-36 の `android.jar` で public) が公開宣言であることを確かめた
- 堅牢性: 未知の保存値は iOS (`@AppStorage` の RawRepresentable) / Android (`fromStorageValue`) とも「システム」に倒れる。同じ外観の選び直しでは Android は作り直さない。`Configuration()` の差分だけを上書きし、文字の大きさ等を残す (テストあり)
- 色の載せ替えの漏れ: ルートメニューから開ける画面で `SampleTheme` を経由しない色を検索した。残る `Color.white` / `Color.gray` は起動引数だけで開く検証画面 (proposal の Non-Goals) に限られる。Android の Material の既定の色は `toMaterialColorScheme()` で配色定義に写されている。「リスト」の `touchFeedback(color: SampleTheme.accent.opacity(0.15))` は `UIColor(Color)` を経るが、動的な色の不透明度の変換は動的なまま残ることを macOS の同等の API で確かめた
- 設計品質: iOS は 1 ファイル 1 型、状態は `@AppStorage` で App と ルートメニューが同じキーを共有。Android は `SampleTheme` を `CompositionLocal` 経由の `@Composable` getter にし、テストで直接描く画面はライトの組に倒れる。いずれも スコープに見合った大きさ
- 読み上げ: iOS は `accessibilityValue`、Android は `stateDescription` を選択中の行だけに付け、印は読み上げから外している。Android で `selectable` を使わない理由がコメントで説明されている

## 指摘事項

### 🟡 Minor iOS の配色定義のコメントが Android の別のファイルを指している

**該当箇所**: `samples/ios/KsCollectionViewSamples/SamplePalette.swift:3`
**問題点**: 「2 組の同じ名前の色は Android Sample の `SampleTheme.kt` と同じ RGBA にそろえる」とあるが、Android の 2 組の値は `SamplePalette.kt` に置かれ、`SampleTheme.kt` は組を選ぶ getter だけを持つ。値を揃えるときに開くべきファイルを取り違えさせる (Android 側の `SamplePalette.kt:6` は iOS の `SamplePalette.swift` を正しく指している)。
**推奨修正**: `SampleTheme.kt` を `SamplePalette.kt` に直す。

### 🟡 Minor ライトで変わった Android の Material の部品のうち、deviation.md に挙がっていないものがある

**該当箇所**: `deviation.md` の 2 行目 (Android の Material の部品の項)、`samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/SampleMenuPicker.kt:56`・`:63-64`
**問題点**: deviation.md は、ライトで変わる Android の部品をスライダーの残りの溝・スイッチのオフの溝と枠・メニューの面の 3 つに限って列挙している。一方 `evidence/android-appearance-verification.md` の「ライトは変わらない」の表では、「画像グリッド」のメニューの開閉の印 (▼) も最大 20/255 変わっている。▼は `LocalContentColor` を使うため、変更前は Scaffold の既定 (黒 #000000) で、今は配色定義の文字の色 (#111214) になる。同じ仕組みで、メニューを開いたときの選択肢の文字も Material の既定の onSurface (#1D1B20) から文字の色に変わるはずだが、証跡は面の色しか見比べていない。どちらも iOS の「色を指定していなかった文字」の項と同じ性質の差で、実害は無いが、列挙の外にあるため後から読むと未記録の差に見える。
**推奨修正**: deviation.md の Android の項に、▼とメニューの選択肢の文字 (Material の既定の文字色から配色定義の文字の色へ) を足す。または列挙を「Material の部品が既定で取る色 (面・溝・枠・つまみ・文字・印)」のように仕組みで書き直す。

### 🔵 Suggestion 保存に `commit()` を使う理由のコメントが実際の挙動と合わない

**該当箇所**: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/SampleAppearanceStore.kt:28`
**問題点**: 「保存の直後に Activity を作り直して読み戻すため、書き込みの完了を待つ commit を使う」とあるが、`apply()` でもメモリ上の値は呼んだ時点で更新され、同じプロセスの `getSharedPreferences` は同じ実体を返すため、作り直し後の読み戻しは `apply()` でも成り立つ。`commit()` を選ぶ実際の利点は、作り直しの前にディスクへの書き込みを終えてプロセスが止まっても値を失わない点にある。後で読む人が「apply では読み戻せない」と誤解する。
**推奨修正**: `commit()` のまま理由を「作り直しの前にディスクへの保存を終える (直後に落ちても選択を失わない)」に書き換える。

## アクションプラン

1. (Minor) `SamplePalette.swift:3` のコメントの参照先を `SamplePalette.kt` に直す
2. (Minor) deviation.md の Android の項に ▼ とメニューの選択肢の文字を足す (または仕組みで書き直す)
3. (Suggestion、任意) `SampleAppearanceStore.kt:28` のコメントの理由を直す

いずれも判定を左右しない。5.4 (オーナーの目視) の後の蒸留までに 1・2 を片付ければよい。
