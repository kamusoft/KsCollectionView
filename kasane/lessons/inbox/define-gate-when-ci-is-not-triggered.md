---
scope: spec-review
kind: pain
severity: normal
count: 1
first-seen: 2026-10-15
last-seen: 2026-10-15
evidence:
  - release-pipeline (spec release-skill「事前の確認」が「対象の commit の検証 CI が成功していること」を求めたが、検証 CI は `develop` への push で `kasane/**` などを起動の対象から外している。実装のワーカーが手順の草稿を書く段で、蒸留や証跡の記録の commit が先端に来ると記録が無く毎回止まることに気づき、オーナーが「直近の成功の commit からの変更が、起動しないパスだけなら、その成功で代える」と決めた)
---

## ルール文
提案で、ある commit について検証 CI (または任意の workflow) の成功を進む条件にする Requirement を書くときは、その workflow の起動条件 (`paths-ignore`・`paths`・ブランチ・イベント) を読み、条件の commit で workflow が起動しない場合の扱い (止まる / 直近の成功で代える条件 / 起動させる) を Requirement に書く。起動しない場合が無いと確かめたときは、その根拠を design に 1 行書く。

## 経緯
- 2026-10-15 release-pipeline: 提案と相方の提案レビューは、リリースの Skill の事前の確認に「対象の commit の検証 CI が成功」を置き、失敗・未完了で止まると書いた。検証 CI の入口 `ci.yml` は、`develop` への push で開発の記録・Issue のフォーム・貢献の案内だけの変更では起動しない (cross/ADR-0010 の流れで決めた形)。このプロジェクトでは蒸留と証跡の記録の commit がいつも `kasane/` だけを変えるので、蒸留の直後のリリースは毎回、記録が無いまま止まる形になっていた。実装の段 (手順の草稿を書くワーカー) で気づいて報告し、オーナーに諮って乖離として記録した。提案の段で起動条件を読んでいれば、Requirement に代える条件を書けていた。
