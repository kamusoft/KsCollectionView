# Exploration: sample-group-header-spacing-color

## 課題 / 動機

Sample のグループの見出しの帯の背景色と、画面の背景色が同じ色 (`SampleTheme.background`、ライトで 242,242,247) のため、グループとグループの間の間隔 (`GroupHeaderMetrics.groupSpacing` = 16) に透けて見える画面の背景が見出しの帯にくっついて見える。見出しそのものの高さ (40pt / 40dp) は固定中・押し出し中・固定なしのどれでも変わらないが、灰色の塊の長さが状態で変わって見える:

- 固定していない見出し: 間隔と合わせて 56pt に見える
- 固定中の見出し: 下を行が流れるので間隔が見えず 40pt に見える (オーナーの感じ方「固定中の見出しの高さが足りない」)
- 押し出しの途中: 押し出される見出し・間隔・次の見出しがひと続きの 96pt に見え、見出しが伸びたように見える

`drag-reorder` (L 級) の tasks 6.2 (基準機 iPhone 11 の体感ゲート、2026-09-30) でオーナーが「並べ替え」画面で気づいた。原因の調査は `kasane/changes/archive/2026-10-01-drag-reorder/evidence/header-glitch-investigation.md`。

- 該当箇所: iOS `samples/ios/KsCollectionViewSamples/GroupHeaderBand.swift:22` (帯の背景) と `samples/ios/KsCollectionViewSamples/SampleDestinationView.swift:41` (画面の背景) が同じ `SampleTheme.background`。Android も `GroupHeaderBand.kt` のコメント「背景は画面の背景と同じ色」のとおりで同じ見え方
- いつから: sections-grouping の Sample から。変更前のコードの「差分更新」画面でも同じ見え方。ライブラリ (固定の計算・安全領域の扱い) の不具合ではなく、drag-reorder の変更でもない
- 「並べ替え」画面は一覧をバーの裏まで広げていて、押し出される見出しがバーの裏で透けて見えるため目立ちやすい

オーナー判断で別 change として簡易起票した (Sample の見た目の決め事で、drag-reorder のスコープ外のため)。

## 検討した選択肢 (却下案と理由を含む)

調査時点の見当 (未検討):
- 間隔の色を見出しと区別する (帯の色を画面の背景から少しずらす、見出しの上端・下端に線を入れる)
- 間隔を行の色 (白) で埋める
- 仕様どおりとして変えない

## 決定事項

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

## 未決の論点

- 未探索 (簡易起票)
- どの見え方にするか (両プラットフォームでそろえる。ダークの組も含める — cross/ADR-0007)
- 「並べ替え」画面でバーが透けて見える理由 (未調査)

## UI 素材 (ui/references/ の一覧と注釈)

## 変更級の推奨: S / M / L (理由)

未判定 (Sample の見た目だけなら S の見込み。承認 mock の見え方に触れるため ui/ の要否は探索で決める)
