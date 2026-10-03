---
scope: process
kind: pain
severity: normal
count: 1
first-seen: 2026-10-03
last-seen: 2026-10-03
evidence:
  - android-build-jdk-range (オーナーの依頼でビルド定義の JDK の固定を外したが、accepted の android/ADR-0002 が同じ項目を決めていることを確かめずに実装し、探索メモに「ADR 候補なし」と書いた。独立レビューの 1 周目が食い違いを指摘し、オーナーに判断を仰ぎ直して一部改訂の ADR を起票した)
---

## ルール文
ビルド定義・版・依存の指定を変える依頼を受けたら、編集の前に、変える値や識別子 (例: `jvmToolchain`、版の番号) で `kasane/decisions/` を検索する。accepted の ADR が同じ項目を決めていたら、編集せずに、従う案と改訂案を並べてオーナーに諮る。

## 経緯
- 2026-10-03 android-build-jdk-range: 会話の途中の依頼にその場で応えたため、探索の「既存 ADR との関係」の確認を飛ばした。実装は変えずに済んだが、レビュー 1 周とオーナーへの確認 1 回が余分にかかった。
