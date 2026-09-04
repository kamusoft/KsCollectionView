---
id: 0007
title: セル content は行の上端に固定・水平は中央に置き、content へ行の高さを提案しない
status: proposed
date: 2026-09-03
---

## Context

`UIHostingConfiguration` を `contentConfiguration` に差すセルホスティング (ios/ADR-0001 の流用骨格) には、翻案元 KsSettingsViewUI が実測で見つけた罠がある。ホスト View は行の高さを提案して content を測り、返った高さが行より大きいとその高さで組み直して行の中央に置く。行の高さが content の変化に 1 レイアウトパス遅れる間、content が上下へ均等にはみ出し、「本文が上から降りてくる」動きになる。

iOS エンジン基盤の実装では当初この対策を「翻案元の補正は固定行高契約のためのもので不要」と判断して落としたが、行の高さが変わる検証画面をオーナーが操作すると発現した (content offsetY −48.7pt)。対策には SwiftUI の `Layout` で content の配置を決める必要があり、その配置規則は利用者テンプレートの見え方を決める契約になる。

## Decision

セル content を `KsRowContentPlacement` (SwiftUI `Layout`) で包み、次の配置規則とする。

- 縦: 提案された行の高さをそのまま自分の高さとして返し、content は自然高のまま**上端に固定**する。行の高さが content に追いつくまでの間も上方向へはみ出さない
- 横: content の自然幅が提案幅より小さいときは余白を等分して**中央**に置く。幅いっぱいに広がる content は先頭から敷く (素の `UIHostingConfiguration` と同じ見え方)
- content へ行の高さを**提案しない** (自己サイズが自己参照になるため)。翻案元が持つ実効行高 (固定行高契約) の概念は持ち込まない

## Alternatives Considered

- **対策を入れない (素の `UIHostingConfiguration` の中央配置のまま)**: 却下。行の高さが動くテンプレートで上方向のはみ出しが発現する (実測 4 回 → 対策後 0 回)。
- **翻案元 `CustomCellRowPlacement` をそのまま移植 (実効行高を基準に定常高を計算)**: 却下。本ライブラリは固定行高の契約を持たず、実効行高が無いと定常高の計算は content の自然高に縮退する。核心 (上端固定) だけを移植した。
- **横も先頭固定にする (初版の実装)**: 却下。幅を明示しない短いテンプレートの見え方が素の hosting (中央) から変わる。縦のはみ出し対策に横の変更を混ぜない。

## Consequences

- 正: content の高さが実行中に変わっても、本文が行の上から降りてくる動きが出ない (Sample の高さ変化検証画面で目視確認、offsetY の A/B で −48.7pt → 0)。
- 正: 幅を明示しないテンプレートの見え方は従来どおり (素の hosting とスクリーンショットが画素一致)。
- 負: content へ行の高さを提案しないため、grid で背の低いセルは行高いっぱいに広がらず自然高のまま上端に置かれる。`.frame(maxHeight: .infinity)` や `Spacer()` で行全体に背景を敷く書き方は効かない。行全体を塗りたい利用者は content 側で高さを揃える必要がある。
- 負: Android (Compose Lazy 系) にはこの罠が無く、grid の行内でのセルの伸び方がプラットフォーム間で異なりうる。対称性の確認は Android 実装時の論点になる。

出典: kasane/changes/archive/2026-09-04-ios-engine-foundation/deviation.md (tasks 3.2 の自己サイズ補正、2026-09-03) / kasane/changes/archive/2026-09-04-ios-engine-foundation/summary.md (最終状態 1・採用値と根拠) / kasane/changes/archive/2026-09-04-ios-engine-foundation/evidence/height-change-after-ab-measurement.md / kasane/changes/archive/2026-09-04-ios-engine-foundation/evidence/row-placement-horizontal-measurement.md / ios/ADR-0001
