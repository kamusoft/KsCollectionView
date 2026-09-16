---
scope: spec-review
kind: pain
severity: normal
count: 1
first-seen: 2026-09-15
last-seen: 2026-09-15
evidence:
  - performance-criteria-review (design Decision 2 の「合計高さ: 初回誤差 ±5% 以内 / contentSize 変化 3 回以下 (平均での実測は 0% / 1 回)」が、行高が一様な list の過去証跡 (`kasane/changes/archive/2026-09-04-ios-engine-foundation/evidence/estimated-height-ab-measurement.md`) の値を、固定高と可変行高が混在する fixture の Scenario「合計高さの見積もりを損ねない」の基準にそのまま置いた。同じ証跡は混在グリッドで平均が約 −12% と明記しており、実装フェーズの tasks 2.4 で最頻値 (34.5%) も平均 (12.0%) も基準を満たせず停止。ホストと相方の spec-review 8 件のどちらも由来の fixture を照合していなかった)
---

## ルール文
提案・設計のレビューで、Scenario の THEN に数値の受け入れ基準が置かれ、その根拠として過去の実測値が引かれているときは、**その実測値が採られた fixture (件数・行高の混在・列数) が Scenario の GIVEN と同じである**ことを証跡ファイルの該当行で確かめ、レビュー結果に「基準値の出典: <証跡パス:行> (fixture: <同じ / 異なる>)」を書く。fixture が異なるなら、その Scenario の基準値は「未校正」として提案側に差し戻す (実装後に合否線を動かす事態を避けるため)。

## 経緯
- 2026-09-15 performance-criteria-review: 「基準は実装前に固定し、結果を見て動かさない」(Decision 2) という趣旨自体は正しかったが、固定した値の出典 fixture が Scenario の fixture と違っていた。実装側で A/B (一様 fixture では最頻値が平均より厳密に良い、混在 fixture ではどちらも ±5% を満たさない) まで採って初めて判明し、tasks 2.4 が停止してオーナー判断に戻った。
