---
scope: process
kind: pain
severity: normal
count: 1
first-seen: 2026-09-03
last-seen: 2026-09-03
evidence:
  - ios-engine-foundation (review-010 と verify-003 を並列起動し、同じ Simulator で Sample の UI テストが並走して review-010 が誤って Major「UI テストが不安定」と判定した)
---

## ルール文
UI テストや Simulator 起動を伴うレビュー・verify のワーカーを同時に起動するときは、コンテキストパッケージで使用する Simulator (名前・OS) を分けて指定するか、直列に起動する。同一 Simulator で複数の `xcodebuild test` を並走させない。

## 経緯
- 2026-09-03 ios-engine-foundation: レビューと verify を並列にしたことで UI テストが互いの起動を崩し、1 サイクル分の誤判定 (Major 1 件) と再実行が発生した。
