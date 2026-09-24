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

## 検討した選択肢 (却下案と理由を含む)

## 決定事項

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

## 未決の論点

**未探索 (簡易起票)** — 深掘りはこのメモを出発点に通常の探索で行う。現時点で見えている疑問は次のとおり。

- `handbook/cross/sample-parity.md` との整合をどう取るか。規約は色をプラットフォーム固有の semantic color にせず、同じ RGBA の `SampleTheme` を両方から参照すること、ダークモード追随のようなプラットフォームらしさより一致を優先することを定めている。ダーク用の RGBA の組を `SampleTheme` に足す形なら両立するか。規約の改訂が要るか
- 切り替えの形: Sample 内の切り替え UI か、端末の設定に従うか、その両方か。`../KsSettingsView/` の Sample がどうしているかを確かめる
- iOS / Android の両 Sample に同時に入れる (片側先行にしない) か
- ダークモードでの見え方の確認は、ライブラリの既定の色 (区切り線 `listSeparatorColor` の既定・タッチ feedback・スクロールインジケータ) の検証装置にもなる。その確認をこの change の完了条件に含めるか

## UI 素材 (ui/references/ の一覧と注釈)

## 変更級の推奨

未判定 (暫定: M。両プラットフォームの Sample と sample-parity の規約に触れるため)
