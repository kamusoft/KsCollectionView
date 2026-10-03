# Live Summary: sample-group-header-spacing-color

## 最終状態 (何がどうなったか)

Sample のグループの見出しの帯 (`GroupHeaderBand`) の背景が、画面の背景 (`SampleTheme.background`) から専用の色 (`SampleTheme.groupHeader`) に変わった。両プラットフォームで同じ値。グループの間隔 (16) には画面の背景が見えるままなので、帯と間隔が見分けられる。

変えていないもの: グループの間隔 (16)・見出しの帯の高さ (40)・グリッドの間隔 (1)・画面の背景と行の色・ライブラリ本体。

## 採用値と根拠 (却下試行の要点)

| 組 | `groupHeader` の値 |
|---|---|
| ライト | #E3E3EA (227, 227, 234) |
| ダーク | #223050 (34, 48, 80) |

- 最初に入れた値を、オーナーが専用の iOS シミュレータ (iPhone 11・iOS 27.0) と Android エミュレータ (Pixel 4a 相当・API 36) の実物で見て、そのまま確定した (2026-10-03)。却下した試行は無い
- ダークの帯は、補助の文字 (#8E9AB3) とのコントラスト比が約 4.6 で、テストの下限 4.5 に近い (実装ワーカーの手計算)
- ライトの帯の上の補助の文字 (#6E7076) のコントラスト比は 3.88 (変更前の画面の背景の上では 4.44)。ライトの組はテストの検査の対象外 (独立レビューの計算、`review-001.md`)

## 触ったファイル

- `samples/ios/KsCollectionViewSamples/SamplePalette.swift` — `groupHeader` の宣言と、ライト / ダークの値
- `samples/ios/KsCollectionViewSamples/SampleTheme.swift` — `groupHeader`
- `samples/ios/KsCollectionViewSamples/GroupHeaderBand.swift` — 背景の色と doc コメント
- `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/SamplePalette.kt` — `groupHeader` の宣言と、ライト / ダークの値、名前つきの一覧
- `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/SampleTheme.kt` — `groupHeader`
- `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/GroupHeaderBand.kt` — 背景の色と doc コメント
- `samples/android/app/src/test/kotlin/jp/kamusoft/kscollectionview/samples/android/SamplePaletteParityTest.kt` — iOS の値の表に `groupHeader` を追加、ダークの読みやすさの組に「文字 / 見出しの帯」「補助の文字 / 見出しの帯」を追加

確認した結果 (JDK 21。同じ作業ツリーにある別 change `android-build-jdk-range` のビルド定義の変更を含む状態で実行):

- iOS Sample のビルド: 成功
- Android Sample のユニットテスト: 163 件成功・失敗 0 (独立レビューでの実行。`SamplePaletteParityTest` は 5 件)
- iOS Sample の UI テスト: 全件は未実行。独立レビューが 44 件のうち 39 件まで回して 39 件成功した時点で、オーナーの指示で切り上げた (残りは `ReorderDemoUITests` の 5 件)。UI テストのソースに、見出しの帯の色や画素の色を見るテストは無い (`review-001.md`)

## 決定事項 / ADR 候補

- 見出しの帯を専用の色にする (探索での決定。`exploration.md` の決定事項)
- ADR 候補なし
