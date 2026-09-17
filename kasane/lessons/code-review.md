---
scope: code-review
timestamp: 2026-09-17
---

# lessons: code-review

## 重点観点

- [L-001] レビュー対象の証跡・deviation に計測値 (contentSize・回数・比率など) が含まれ、その計測対象のコードが直前のサイクルで修正されているときは、証跡の手順を自前のプローブで再実行し、現行コードで同じ値が再現するかを判定に含める。再現しなければ Major として測り直しを求める。(昇格: 2026-09-17、出典: ios-engine-foundation / android-wrapper-foundation / template-parent-state-observation / image-loading / performance-criteria-review、経緯: [details/reviewer-reproduces-evidence-numbers-by-probe.md](details/reviewer-reproduces-evidence-numbers-by-probe.md))

## 指摘しないこと

(まだ無い)
