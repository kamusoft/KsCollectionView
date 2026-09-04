---
scope: impl
kind: pain
severity: normal
count: 1
first-seen: 2026-09-03
last-seen: 2026-09-03
evidence:
  - ios-engine-foundation (ライブ調整でワーカーが静止画観測から「はみ出し非発現」と報告したが、オーナーの実操作で発生。60fps のフレーム抽出でも 1 フレームに定着しなかった)
---

## ルール文
行高・サイズが 1 レイアウトパス遅れて追いつく種類の見た目の不具合 (はみ出し・飛び・ちらつき) を検証するときは、静止画やフレーム抽出で「非発現」と判定せず、content の frame / offset を毎レイアウトパスでログに出し「負の offset が出た回数」のような数値の A/B で判定する。静止画は遷移区間の補助記録に留める。

## 経緯
- 2026-09-03 ios-engine-foundation: `UIHostingConfiguration` の中央配置はみ出し (content offsetY −48.7pt) は静止画に写らず、ワーカーの「非発現」報告をそのまま採用すると対策不要と誤判定していた。offsetY のログで 4 回 → 0 回の A/B が取れて初めて裏付けになった。
