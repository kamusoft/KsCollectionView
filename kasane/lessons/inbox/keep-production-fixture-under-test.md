---
scope: spec-review
kind: pain
severity: normal
count: 1
first-seen: 2026-09-16
last-seen: 2026-09-16
evidence:
  - performance-criteria-review (提案の改訂 (2026-09-16) で、本番 fixture の Sample「大量件数」= 混在 2 列の合計高さの見積もりを「単一の推定値では基準に届かない」としてテストの対象から外したまま、Open Questions に残して提案を締めようとし、オーナーが「テスト対象外で良いわけない」と却下した。design Decision 15 (行の高さによる見積もり) と Scenario「混在 2 列でも合計高さの見積もりを損ねない」を足した。独立レビューは review-003〜006 でこの状態を所見として再掲していた。verify-002 はこの教訓を inbox にある前提で引いていたが、実体は無かった)
---

## ルール文
提案・設計で、本番 fixture (Sample のデモ画面が使うデータの形) が Scenario の数値基準に届かないと分かったときは、その fixture をテストの対象から外したり Open Questions に残したりせず、届かせる仕組みの候補を design の Decision に立てて Scenario を置く。基準値は結果を見て動かさず、仕組みでも届かなければ NEEDS_DISCUSSION で止めてオーナーに諮る。

## 経緯
- 2026-09-16 performance-criteria-review: 混在 2 列の合計高さを、単一の推定値では当てられないことを理由にテスト対象外のまま提案を締めようとして却下された。足した仕組み (group に行の高さの平均を渡す) は A/B で前提が崩れて実装を止め、オーナー判断で Scenario を取り下げて、混在 2 列は基準機の体感と解き直しの占有率で判定した
