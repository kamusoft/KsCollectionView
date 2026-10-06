# Exploration: ios-adaptive-color-settings-before-ios-18

## 課題 / 動機

iOS で、ライトとダークで値が切り替わる色を、色を受け取る設定に渡すと、iOS 17.5 ではライトの値に固定される見込みである。`library-default-colors-dark-mode` の提案づくりで、相方の提案レビューの指摘 (利用者が指定した外観で値の変わる色の扱いが曖昧) を確かめるために実測して見つけた (2026-10-06、オーナー指示で起票)。

例: Sample の「リスト」は、区切り線「アクセント」で `.listSeparatorColor(SampleTheme.accent)` を渡す (`samples/ios/KsCollectionViewSamples/ListDemoView.swift:42`)。`SampleTheme.accent` はライトで `#2F6FED`、ダークで `#5B8DF6` に切り替わる色で、ダークでは線が `#5B8DF6` で出るのが期待である。

実測の結果 (`kasane/changes/library-default-colors-dark-mode/evidence/proposal-probes.md` の 4):

| iOS の版 | ダークの外観で解決した値 |
|---|---|
| iOS 18.6・26.0・27.0 | ダーク用の値 (期待どおり) |
| iOS 17.5 | ライト用の値のまま |

- 原因の見込み: ライブラリは受け取った SwiftUI の色を、内部で UIKit の色へ変換して持つ (`ios/Sources/KsCollectionView/KsCollectionView.swift:263`・`:277`・`:312` の `UIColor(color)`)。iOS 17.5 では、OS のこの変換が外観で値の変わる性質を落とし、ライトの値だけの色を返す。変換する時点の外観をダークにしておいても結果は同じだった。OS の色 (SwiftUI の標準の文字色) を変換しても同じだった
- 同じ変換を通る設定は 3 つ: 区切り線の色 (`.listSeparatorColor(_:)`)、タップしたときの色 (`.touchFeedback(color:)`)、読み込み中の表示の色 (`.loadingIndicatorColor(_:)`)
- 影響を受けないもの: 外観で値の変わらない色を渡す場合、色を指定しない場合 (ライブラリの既定の色は UIKit の色として持つ)、Android
- Sample は 3 つの設定とも外観で値の変わる色 (配色のアクセント・テキスト副) を渡している。iOS 17 以前のダークでは、ライトの配色の値で出ている可能性がある。Sample では同じ色みの明るさ違いなので目立たないが、利用者が「ライトは黒、ダークは白」のような色を渡すと、ダークで見えない色になる
- ライブラリの最低対応は iOS 16 (`ios/Package.swift`)

確かさの限界: 測ったのは、シミュレータの中で動かした単体の実行ファイルである (色を変換し、外観ごとに解決した値を出すだけ)。アプリの画面の中での見え方は確かめていない。iOS 16 はランタイムが無く測っていない。

## 検討した選択肢 (却下案と理由を含む)

## 決定事項

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

## 未決の論点

**未探索 (簡易起票)** — 深掘りはこのメモを出発点に通常の探索で行う。現時点で見えている疑問は次のとおり。

- 最初に確かめること: アプリの画面の中 (Sample の「リスト」をダークで開く) でも、iOS 17 のシミュレータでライトの値で出るか。iOS 16 でも同じか。3 つの設定のそれぞれで起きるか
- 直すなら、どこで直すか (受け取った SwiftUI の色を、変換せずに外観ごとに解決する形にする / UIKit の色を受け取る入口を足す / iOS 17 以前の制限として文書に書くだけにする)
- 既存のテストは、外観で値の変わる UIKit の色を内部の設定に直接入れて確かめており、公開の設定 (SwiftUI の色を受け取る入口) を通していない (`ios/Tests/KsCollectionViewTests/KsLoadingIndicatorColorTests.swift` の表示モードのテスト)。公開の入口を通すテストが要るか
- `library-default-colors-dark-mode` のデルタスペックは「指定した色にライブラリは手を加えない」とだけ約束し、外観で値の変わる色の追随は約束していない。この change でその約束を足すか

## UI 素材 (ui/references/ の一覧と注釈)

## 変更級の推奨

未判定
