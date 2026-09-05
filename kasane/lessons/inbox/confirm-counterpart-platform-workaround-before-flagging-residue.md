---
scope: code-review
kind: pain
severity: normal
count: 1
first-seen: 2026-09-05
last-seen: 2026-09-05
evidence:
  - template-parent-state-observation (review-001 Suggestion 4 が Android 検証画面に残る「展開中: N 行」表示を iOS で撤去した回避策の残骸として指摘したが、Compose では依存を張る回避策ではなく単なる表示であり、オーナー判断で撤去しないと確定した)
---

## ルール文
一方のプラットフォームで撤去した回避策と同名・同形の要素が対向プラットフォームに残っていることを指摘する前に、その要素が対向側でも回避策として機能しているか (依存を張る目的があるか、単なる表示か) を対向側のフレームワークの仕組みで確認し、単なる表示なら指摘しない。指摘するときは「対向側でも回避策である根拠」を review ファイルに書く。

## 経緯
- 2026-09-05 template-parent-state-observation: iOS の「展開中: N 行」は body で state を読んで依存を張る回避策だったが、Android の同名表示は Compose が親の State を自動購読するため回避策ではなかった。指摘は Suggestion に留まりオーナー判断で見送りになったが、オーナーへ諮る往復が 1 回増えた。
