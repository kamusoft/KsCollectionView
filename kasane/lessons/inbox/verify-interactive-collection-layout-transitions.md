---
scope: code-review
kind: pain
severity: normal
count: 2
first-seen: 2026-09-02
last-seen: 2026-09-26
evidence:
  - ios-engine-foundation (オーナーの Simulator 確認で、区切り線切替・連続スライダー・layout 切替後スクロール・逆向き回転の不具合を発見)
  - sections-grouping (iOS Sample「差分更新」で、グループなしで並びを崩してから「グループ」スイッチをオンにすると debug で停止する不具合を、review-001〜004 (ホスト・相方とも) は見逃し、verify-001 が Simulator で切り替えを操作して検出した)
---

## ルール文
コレクションの動的レイアウトや操作設定に触れたレビューでは、静止画と起動確認だけで完了せず、設定の ON/OFF、連続値のドラッグ、layout 切替後の上下スクロール、対応する全画面向きへの回転を Simulator で操作し、表示が各操作後も安定していることを確認する。

## 経緯
- 2026-09-03 ios-engine-foundation (同一 change、count 据え置き): ライブ調整でも、行の展開・折りたたみという操作後にだけ現れるはみ出しをオーナーの実操作が検出し、静止画と起動確認では捕まらなかった。
- 2026-09-02 ios-engine-foundation: 静止画の視覚照合と各画面の起動スモークは通過したが、操作後にだけ現れる4種類の不具合をオーナー確認まで検出できなかった。
- 2026-09-26 sections-grouping: 設定の ON/OFF (グループの有無の切り替え) を、操作の順序 (崩してから切り替え) まで含めて Simulator で操作したのは verify だけだった。
