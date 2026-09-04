---
scope: code-review
kind: pain
severity: normal
count: 1
first-seen: 2026-09-02
last-seen: 2026-09-03
evidence:
  - ios-engine-foundation (オーナーの Simulator 確認で、区切り線切替・連続スライダー・layout 切替後スクロール・逆向き回転の不具合を発見)
---

## ルール文
コレクションの動的レイアウトや操作設定に触れたレビューでは、静止画と起動確認だけで完了せず、設定の ON/OFF、連続値のドラッグ、layout 切替後の上下スクロール、対応する全画面向きへの回転を Simulator で操作し、表示が各操作後も安定していることを確認する。

## 経緯
- 2026-09-03 ios-engine-foundation (同一 change、count 据え置き): ライブ調整でも、行の展開・折りたたみという操作後にだけ現れるはみ出しをオーナーの実操作が検出し、静止画と起動確認では捕まらなかった。
- 2026-09-02 ios-engine-foundation: 静止画の視覚照合と各画面の起動スモークは通過したが、操作後にだけ現れる4種類の不具合をオーナー確認まで検出できなかった。
