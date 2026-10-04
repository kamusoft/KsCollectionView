---
scope: spec-review
timestamp: 2026-10-04
---

# lessons: spec-review

- [L-001] 提案を作成・改訂したときの自己レビューでは、新設・変更した契約 (Requirement・Scenario・design の Decision) ごとに、同じ契約を書いている他の成果物 (design・ADR・handbook・承認 mock) と、その契約で前提が変わる既存コードの経路 (早期 return の条件・状態を控える契機・件数や順番の数え方) を開いて突き合わせ、突き合わせた箇所と結果を記録に書く。件数や条件を変えて比べる Scenario では、比べる 2 つの走行が同じ仕事量になる条件が書かれているかも確かめる。 (昇格: 2026-09-26、出典: prefetch-display-size / performance-criteria-review / sample-dark-mode-toggle。経緯: details/cross-check-changed-contracts-in-spec-self-review.md)
- [L-002] 提案・設計のレビューで、Requirement・Scenario・design の Decision が外部のライブラリや OS の部品の具体的な利用 (値を読む・引き継ぐ・差し替える、色や大きさを渡してその見え方を約束する) を前提にしているときは、次の 2 点を確かめ、確かめた場所と結果をレビュー結果に書く。(1) その API が採用版のソースまたは公式リファレンスで公開宣言されていること (宣言の位置を書く)。(2) 公式の文書に書かれていない挙動 (渡した値がどう描かれるか・どう配置されるか) を SHALL で約束する場合は、提案の段階の最小試作で、利用者と同じ操作で出した実物を確かめてあること (確かめた環境と値を書く)。確かめられない挙動は Requirement に SHALL で書かず、確かめる作業を実装の最初のタスクに置く。 (昇格: 2026-10-04、出典: image-loading / performance-criteria-review / paging-indicator-color。経緯: details/verify-external-api-visibility-before-writing-it-into-design.md)
