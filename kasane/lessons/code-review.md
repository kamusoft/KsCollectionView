---
scope: code-review
timestamp: 2026-09-29
---

# lessons: code-review

## 重点観点

- [L-001] レビュー対象の証跡・deviation に計測値 (contentSize・回数・比率など) が含まれ、その計測対象のコードが直前のサイクルで修正されているときは、証跡の手順を自前のプローブで再実行し、現行コードで同じ値が再現するかを判定に含める。再現しなければ Major として測り直しを求める。(昇格: 2026-09-17、出典: ios-engine-foundation / android-wrapper-foundation / template-parent-state-observation / image-loading / performance-criteria-review、経緯: [details/reviewer-reproduces-evidence-numbers-by-probe.md](details/reviewer-reproduces-evidence-numbers-by-probe.md))
- [L-002] スクロール命令・行の高さの変化・layout の切り替え・一覧に重ねる表示のように「動きの過程」が利用者に見える機能をレビューするときは、最終位置や最終状態のアサートだけで済ませず、実機またはエミュレータで操作の過程を録画 (または 60fps のフレーム抽出) して、行き過ぎ・戻り・アニメーションの欠落・中身と一緒に流れる表示がないかを判定に含める。動きの品質の期待値 (対向プラットフォームや参照実装の既定挙動) を評価軸として先に書き出す。(昇格: 2026-09-29、出典: android-wrapper-foundation / sections-grouping / paging-state-machine、経緯: [details/observe-motion-not-only-end-state-for-scroll-and-resize.md](details/observe-motion-not-only-end-state-for-scroll-and-resize.md))

## 指摘しないこと

(まだ無い)
