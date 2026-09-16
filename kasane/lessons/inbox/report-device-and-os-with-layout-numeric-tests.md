---
scope: impl
kind: pain
severity: normal
count: 1
first-seen: 2026-09-15
last-seen: 2026-09-15
evidence:
  - performance-criteria-review (tasks 2.4 のエンジンテスト「行高が一様な配列で初回表示の合計高さの見積もりを損ねない」が、実装者の iPhone 17 Pro Max Simulator では 1.01% / 2 回で緑だったが、レビュアーが試した 5 つの Simulator のうち 3 つで決定的に失敗 (誤差 8.69〜9.98% / 変化 124〜188 回)。実装報告・deviation の数値に機種・OS が無く、1 環境でしか成立しない値だと 2 周目のレビューまで気付けなかった)
---

## ルール文
レイアウトの数値 (高さ・誤差 %・回数) に対するアサーションを持つテストを追加または変更したときは、実行に使った Simulator / 実機の機種と OS を実装報告と証跡 (deviation・evidence) の数値に必ず併記し、完了印を付ける前に画面サイズまたは scale の異なる 2 機種以上で通す。1 機種の緑を根拠に数値をチェックリストや deviation に書かない。

## 経緯
- 2026-09-15 performance-criteria-review: 推定高さの最頻値化で「合計高さの見積もり」を数値で再検証したが、機種依存の結果を 1 環境で採って完了印を付けた。ホストの独立レビューが別 Simulator で再現して Critical として差し戻し、修正サイクルが 1 周増えた。
