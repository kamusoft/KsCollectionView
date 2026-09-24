---
scope: spec-review
kind: pain
severity: normal
count: 2
first-seen: 2026-09-08
last-seen: 2026-09-24
evidence:
  - prefetch-display-size (提案の自己レビューと相方の spec レビュー 2 回を通った design に、既存経路との突き合わせ漏れが 2 件残り、実装レビューで見つかった。Android の表示の鍵から当てはめ方 (`ks#scale`) を外すと、範囲外で退けた先読みの項目がローダーのメモリで同じ鍵に当たり Scenario「大きすぎる/小さすぎる項目は使わない」が破れる (review-001)。design の索引の節が「消去以外では消さない」と「照会時に刈り込む」を両方書いていた (second-opinion-code-004)。どちらもオーナー決定で deviation に記録)
  - performance-criteria-review (提案のホスト側自己レビューが相方の spec レビューの指摘をほぼ拾えなかった。初版 (second-opinion-spec-001、2026-09-08) は自己レビュー 2 周で指摘 0 件、相方の 8 件はすべて採用。改訂 (second-opinion-spec-002、2026-09-16) は自己レビュー 2 周で相方の Major 5 件をすべて見逃した — 件数を変えた比較が同じ仕事量を比べていない、adaptive の塊の契約が spec / design / ADR で食い違い同値配列の早期 return を考慮していない、塊分割でメモリ往復ドライバの通過件数 (`indexPath.item`) が数えられなくなる、項目だけの挿入では位置が控えられない、handbook の「ドライバはメモリ往復だけ」が改訂 spec と矛盾する)
---

## ルール文
提案を作成・改訂したときの自己レビューでは、新設・変更した契約 (Requirement・Scenario・design の Decision) ごとに、同じ契約を書いている他の成果物 (design・ADR・handbook) と、その契約で前提が変わる既存コードの経路 (早期 return の条件・状態を控える契機・件数や順番の数え方) を開いて突き合わせ、突き合わせた箇所と結果を記録に書く。件数や条件を変えて比べる Scenario では、比べる 2 つの走行が同じ仕事量になる条件が書かれているかも確かめる。

## 経緯
- 2026-09-16 performance-criteria-review: 改訂の自己レビュー 2 周で、相方が見つけた成果物間の矛盾と既存経路への影響 (Major 5 件) をどれも検出できなかった。すべて採用され、spec・design・ADR・tasks を直してから実装に進んだ
- 2026-09-24 prefetch-display-size: 鍵の形を変える決定が、ローダーのメモリの引き当て (既存経路) に与える影響と、design の同じ節の中の 2 記述の食い違いを、提案段階で拾えなかった。実装レビューで見つかり、オーナー決定で直した
