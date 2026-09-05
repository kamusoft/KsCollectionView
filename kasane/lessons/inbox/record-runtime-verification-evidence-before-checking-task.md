---
scope: impl
kind: pain
severity: normal
count: 1
first-seen: 2026-09-05
last-seen: 2026-09-05
evidence:
  - template-parent-state-observation (tasks 3.2 の list / grid 実操作確認を実装ワーカーの目視報告だけで完了にし、相方レビュー second-opinion-code-001 Major 2 が「change 配下に証跡がない」と指摘。修正サイクルで evidence/height-change-tap-verification.md を追加した)
---

## ルール文
Simulator / 実機での操作確認を要件に持つタスクを完了 (`[x]`) にするときは、handbook の観測点表に対応する手順・観測結果・静止画の一覧を `evidence/` のファイルに書き、完了報告からそのファイルを参照できる状態にしてから完了にする。報告本文だけの目視報告 (「確認した」) で完了にしない。

## 経緯
- 2026-09-05 template-parent-state-observation: 実装ワーカーが Simulator で list / grid の 1 タップ目を確認して tasks 3.2 を完了にしたが、証跡は別目的の spike ログしか無く、handbook/cross/runtime-behavior-verification.md の「証跡を change 配下に残す」を満たしていなかった。ホストのレビューも見逃し、相方レビューが Major として指摘。1 サイクル分の追加作業になった。
