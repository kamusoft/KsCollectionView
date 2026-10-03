# Live Session: sample-group-header-spacing-color
対象: Sample のグループの見出しの帯 (`GroupHeaderBand`) に当てる専用の色 (ライト / ダークの 2 組、両プラットフォーム同値) の値
開始: 2026-10-03

確認の手段: この作業専用の iOS シミュレータ `ksn-header-color-ip11` (iPhone 11・iOS 27.0) と Android エミュレータ `ksn-header-color-px4a` (Pixel 4a 相当・API 36)。オーナーの指示で専用のものを用意し、作業の最後に削除する。

## 試行ログ (append-only)
- 専用の色 `groupHeader` を足して帯に当てる (最初の値) → 両プラットフォームの `SamplePalette` にライト #E3E3EA / ダーク #223050 を追加、`SampleTheme.groupHeader` を追加、`GroupHeaderBand` の背景を `SampleTheme.background` → `SampleTheme.groupHeader`、Android の `SamplePaletteParityTest` に追随 → 継続 (iOS は専用シミュレータで表示を確認。Android は未ビルド)

## 決定事項

## エスカレーション・スコープ外の発見
- Android のビルド・導入・テストが実行できない: この Mac に JDK 17 が無く (JDK 21 のみ)、`jvmToolchain(17)` が解決できない。JDK の導入とビルド定義の変更は調整対象の外のため、オーナーの判断待ち (2026-10-03)
- ダークの補助の文字 (#8E9AB3) と帯の最初の値 (#223050) のコントラスト比は約 4.6 で、テストの下限 4.5 に近い。ダークの帯をこれより明るくするとテストが落ちる見込み (ワーカーの手計算)
- JDK 17 が無い件は、オーナーの依頼で別 change `android-build-jdk-range` として扱い、JDK 21 でビルドできるようにした (2026-10-03)。Android も専用エミュレータ `emulator-5584` で表示を確認できる
- オーナーが両プラットフォームの実物を見て「これで OK」と確定 (2026-10-03)。最初の値のまま採用: ライト #E3E3EA / ダーク #223050
