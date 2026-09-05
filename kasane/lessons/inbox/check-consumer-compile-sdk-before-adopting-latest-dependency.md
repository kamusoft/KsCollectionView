---
scope: code-review
kind: pain
severity: normal
count: 1
first-seen: 2026-09-05
last-seen: 2026-09-05
evidence:
  - android-wrapper-foundation (最新安定 Compose BOM 2026.08.00 を採用した結果、本体 AAR の minCompileSdk が 37 (直近リリースの Platform 37.2) になり利用者アプリに未普及の SDK Platform を強いていた。review-002 / 003 / 005 と相方 code-002 / 004 のいずれも指摘せず、オーナーが「利用者アプリに影響するならダメでは」と指摘して BOM を 1.11 系へ下げた)
---

## ルール文
配布されるライブラリのビルド定義 (依存の版・compileSdk) をレビューするときは、生成物 (AAR / パッケージ) のメタデータが利用者に要求する値 (`minCompileSdk`、推移依存が要求する SDK / ツールチェーン) を読み、その値が現時点で広く配布済みの SDK に収まっているかを判定に含める。「ADR が最新安定に追随と決めている」ことを、利用者側の要求値を確認しない根拠にしない。

## 経緯
- 2026-09-05 android-wrapper-foundation: android/ADR-0002 の「最新安定 BOM」に従って Compose 1.12.0 を選び、本体・Sample・計測がすべて通ってレビュー 5 回 (ホスト 3・相方 2) が APPROVED / 指摘なしで通過した後、オーナーの一言で利用者への compileSdk 37 の強制が判明。BOM の引き下げ・compileSdk 36 化・性能の再計測まで 1 サイクル分の手戻りになった。
