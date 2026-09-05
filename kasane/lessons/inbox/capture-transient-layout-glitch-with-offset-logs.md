---
scope: impl
kind: pain
severity: normal
count: 2
first-seen: 2026-09-03
last-seen: 2026-09-05
evidence:
  - ios-engine-foundation (ライブ調整でワーカーが静止画観測から「はみ出し非発現」と報告したが、オーナーの実操作で発生。60fps のフレーム抽出でも 1 フレームに定着しなかった)
  - template-parent-state-observation (トランザクション引き渡しの spike を、中身の描画に届かないフレームログだけで「不成立」と断定。review-001 が「構成 C は未判定」と指摘し、オーナー目視で判定した)
---

## ルール文
見た目の一過性の現象 (はみ出し・飛び・ちらつき・中身のアニメーションの有無) を検証するときは、静止画やフレーム抽出、対象の描画に届かない計測 (例: content view の外から採る frame ログ) で「非発現」「不成立」と判定せず、対象を直接観測できる数値 (content の frame / offset を毎レイアウトパスで記録した回数など) の A/B かオーナー目視で判定する。計測が対象に届かなかった構成は「未判定」と書き、断定しない。静止画は遷移区間の補助記録に留める。

## 経緯
- 2026-09-05 template-parent-state-observation: `withTransaction` の引き渡し spike で、presentation layer の高さのログは行の高さ (UICollectionView の自己サイズ変更) しか捉えず、中身 (SwiftUI 側の描画) のアニメーションは射程外だったのに deviation が「不成立」と断定。review-001 Minor 3 の指摘で「A・B は効果なし確定、C は未判定」に直し、オーナー目視で C も効果なしと確定した。
- 2026-09-03 ios-engine-foundation: `UIHostingConfiguration` の中央配置はみ出し (content offsetY −48.7pt) は静止画に写らず、ワーカーの「非発現」報告をそのまま採用すると対策不要と誤判定していた。offsetY のログで 4 回 → 0 回の A/B が取れて初めて裏付けになった。
