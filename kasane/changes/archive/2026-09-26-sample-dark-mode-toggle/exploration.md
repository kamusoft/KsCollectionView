# Exploration: sample-dark-mode-toggle

## 課題 / 動機

iOS / Android の Sample は、端末をダークモードにすると表示が崩れる。Sample は固定の明るい色 (`SampleTheme`) で描かれてダークモードに追随しないのに、OS の部品は表示モードに従って明るい色になるため。オーナー判断で、Sample の中でライト / ダークを切り替えられるようにする。進め方は `../KsSettingsView/` の Sample を参考にする (オーナー指定)。

発見の文脈: `android-scrollbar-parity` の基準機確認 (2026-09-24)。Android の Pixel 4a で本体をダークにすると、Sample 上のスクロールインジケータが見えなくなった。iOS シミュレータ (iOS 26.5) でも同じ条件で確かめたところ、次が見えなくなっていた。

- 「大量件数」でスクロール中に出るインジケータ: ほぼ白 (249,249,251) で、背景の明るい灰色 (242,242,247) の上に描かれる
- ナビゲーションバーの題名とステータスバーの文字: 白くなり、明るい背景の上で読めない

ライブラリのインジケータは両プラットフォームとも表示モードに従う (iOS は trait、Android は `isSystemInDarkTheme()`) ため、ライブラリ側の食い違いではなく、Sample の配色がダークモードを持たないことが原因。

現状 (起票時点で確かめたこと):

- iOS Sample: `preferredColorScheme` / `overrideUserInterfaceStyle` / Info.plist の `UIUserInterfaceStyle` のいずれも指定していない
- Android Sample: テーマは `android:Theme.Material.Light.NoActionBar` (`samples/android/app/src/main/res/values/themes.xml`)。Compose 側は引数なしの `MaterialTheme { }` (`MainActivity.kt`)。配色は `SampleTheme` が正

### 探索で確かめたこと (2026-09-26)

- `../KsSettingsView/` の Sample (`../KsSettingsView/kasane/changes/archive/2026-09-05-add-sample-dark-mode-toggle/`)
  - ルートメニューの先頭に見出し「外観」のグループを置き、「システム / ライト / ダーク」の 3 行から選ぶ。初期値は「システム」、選んだ値は再起動後も保持 (iOS `@AppStorage` / Android SharedPreferences)
  - `SampleTheme` にライト / ダーク 2 組の RGBA を両プラットフォーム同値で持つ。ダークの配色はモックの暖色案を採用 (中立色の案はライブラリ既定色のダークと見分けにくいため却下)
  - iOS は window の `overrideUserInterfaceStyle` を `NavigationStack` の外側で書き換える。`preferredColorScheme` は、上書きを外したあとに端末の外観が変わるとナビゲーションバー・戻るボタン・ステータスバーだけ前の配色で残るため避けた
  - Android は `attachBaseContext` で `applyOverrideConfiguration(uiMode)` を掛け、選択が変わったら `recreate()`。AppCompat は使わない。`values-night/themes.xml` を持つ。この上書きはライブラリ側の `isSystemInDarkTheme()` にも効く
  - 実装中にライブラリ本体の既定色がライト固定だと分かり、本体は別 change で直した。handbook の「dark mode 追随よりパリティを優先」の一文は改めずに残っている
- このリポジトリの Sample
  - iOS: 前景色の無い `Text`・segmented の Picker・`LabeledContent` / `Slider`・ナビゲーションバーの題名が OS に従って崩れる。検証画面には OS の semantic color の直書きがある (`ImageLoadingSlotCounter.swift` の systemGray5 等)
  - Android: Activity テーマ (`Theme.Material.Light.NoActionBar`) も `MaterialTheme {}` もライト固定のため、崩れるのは `isSystemInDarkTheme()` を直接見るライブラリのスクロールインジケータが主と見られる (実機未確認)。`Color.White` の直書きが 3 箇所 (`TemplateSwitchDemoScreen.kt` / `DiffUpdateDemoScreen.kt` / `SampleSegmentedControl.kt`)
  - Sample から本体へ色を渡している箇所: 「一覧 (list)」の区切り線の色切り替え (`listSeparatorColor`) と `touchFeedback` / `touchFeedbackColor`
- ライブラリ本体の色
  - 固定: 区切り線の既定 `#D9D9DE` (core/ADR-0010 で semantic color を却下して固定)、Android の画像の読み込み中・失敗の色 (`KsImage.kt`)
  - 表示モードに追随: iOS のタッチの feedback (`.systemFill`)、iOS の画像の読み込み中の色 (systemGray5 / 4)、Android のスクロールインジケータ、Android の既定の ripple (MaterialTheme に従う)。iOS のスクロールインジケータは UIKit 既定 (追随すると推測、未確認)

## 検討した選択肢 (却下案と理由を含む)

- 切り替えの形
  - 採用: 「システム / ライト / ダーク」の 3 択、初期値「システム」、選んだ値は再起動後も保持 (KsSettingsView と同じ形)
  - 却下: 「ライト / ダーク」の 2 択で初期値ライト — 作る量は少ないが、端末の設定に従う状態 (実アプリと同じ経路) でライブラリの色を確かめられず、KsSettingsView とも揃わない
  - 対象外: Sample 内に切り替えを置かず端末の設定に従うだけ (オーナー判断で Sample 内の切り替えに決定済み)
- sample-parity の規約との両立
  - 採用: 規約の「dark mode 追随より一致を優先する」の一文を、2 組の同値 RGBA と同じ切り替えによるダーク対応を許す文面に改める (cross/ADR-0007)
  - 却下: 文面は変えず change の記録で趣旨に反しないと説明する (KsSettingsView の進め方) — 文面と実物が食い違ったまま残り、以後のレビュー・棚卸しで毎回規約違反として拾われる
- ライブラリの既定の色のダークでの確認
  - 採用: この change の完了条件に含める (既定の色に頼る画面を両プラットフォーム × ライト / ダークでオーナーが目視し、問題を記録する)
  - 却下: 含めず Sample 自体が崩れないことだけ確かめる — ライブラリ側のダークの問題が一覧にならず、気づいた都度の起票になる
- 見つかったライブラリの既定の色の問題を直す場所
  - 採用: 別の change に切り出す (KsSettingsView と同じ)。ダークでの確認の後、見つかった問題をまとめて簡易起票する
  - 却下: この change で直す — ライブラリの既定の色にダークの組を足す設計と core/ADR-0010 の改訂を伴い L 級になり、Sample の切り替えまで待たされる
  - 対象外: Sample から既定と違う区切り線の色を渡して見えなくする — sample-parity の「Sample 側で値を明示すると既定のデモという意図が壊れる」に反し、問題を隠す

## 決定事項

- 切り替えは Sample の中に置き、「システム / ライト / ダーク」の 3 択、初期値「システム」、選んだ値は再起動後も保持する。置き場所と見た目は提案の mock で決める
- iOS / Android の両 Sample に同じ change で入れる (sample-parity の「同一変更内で両プラットフォームを揃えるのが原則」による)
- `SampleTheme` にライト / ダーク 2 組の同値 RGBA を持ち、sample-parity の規約の一文を改める (cross/ADR-0007)。規約の文面の書き換えは蒸留 (ksn-distill) の書き込み経路で行う
- 完了条件に、ライブラリの既定の色に頼る画面 (一覧・画像グリッド・大量件数など) を両プラットフォーム × ライト / ダークでオーナーが目視し、見つかった問題を記録することを含める
- ライブラリの既定の色の修正はこの change に含めない。ダークでの確認の後に見つかった問題をまとめて簡易起票する。既知の候補は、区切り線の既定 `#D9D9DE` が固定でダークでも明るい線のまま残ること (core/ADR-0010 の一部改訂を伴う見込み) と、画像の読み込み中の色が iOS は OS の色でダークに追随し Android は固定のためダークでだけ両プラットフォームで食い違うこと
- ライブラリの修正が終わるまでは、ダークで既定の区切り線が明るく残ることを受け入れる
- 進行中のロードマップとは重ならない (v1-foundation の phase-7 はサンプルアプリを対象外と明記)

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

- 作成済み: cross/ADR-0007 (Sample のライト / ダーク対応は、両プラットフォーム同値の 2 組の配色と同じ切り替えで行い、パリティの範囲内とする) — proposed

## 未決の論点

- 論点5 (proposal で方針を決定: Android の作り直しは画面回転と同じ扱いで、計測用の初期化も回転時と同じく再実行される。iOS は起動の分岐より上で window の外観を上書きする): 表示モードの反映の仕組みと、Sample の起動経路の衝突。Android の `recreate()` は `MainActivity.onCreate` の計測用の初期化 (カウンタのリセット・キャッシュの消去・起動経路) と衝突しうる。iOS は RootMenu を通らずに開く起動経路 (`SampleLaunchView`) があるため、window の上書きはそれより上の階層に掛ける必要がある
- 提案の mock で決める: 切り替えの置き場所と見た目、ダークの配色 (KsSettingsView はダークの配色で暖色案を採用し、中立色の案をライブラリ既定色のダークと見分けにくいとして却下した)
- 提案で洗い出す: `SampleTheme` を経由しない色 (iOS の前景色の無い `Text`・segmented の Picker・検証画面の OS の色の直書き、Android の `Color.White` の直書き等) をダークの組に載せる範囲。計測用ビルドの固定色 (`BaselineScrollIndicator.kt` 等) と検証画面を対象に含めるか

## UI 素材 (ui/references/ の一覧と注釈)

## 変更級の推奨

M (2026-09-26 オーナー確定)。Sample だけの機能追加で公開 API に触れず可逆だが、両プラットフォームの Sample の配色を全画面にわたって 2 組に載せ替え、切り替え UI・選択の保持・表示モードの反映 (起動経路との衝突の設計を含む) を加え、規約の改訂 (cross/ADR-0007) を伴うため、S の「局所的」には収まらない。ライブラリの既定の色の修正を切り出したので L には当たらない。
