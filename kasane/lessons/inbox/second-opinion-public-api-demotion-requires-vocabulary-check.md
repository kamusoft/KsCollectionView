---
scope: process
kind: pain
severity: normal
count: 1
first-seen: 2026-09-02
last-seen: 2026-09-02
evidence:
  - ios-engine-foundation (second-opinion-code-001 #21 / code-005 Suggestion-3 の columnSpacing modifier 指摘を「初期化子で契約を満たす」と降格し、オーナーが降格判断を差し戻した)
---

## ルール文
セカンドオピニオンの突き合わせで公開 API の形 (語彙・引数・modifier) に関する指摘を降格する前に、該当 ADR と dsl-samples の語彙表・実装コードの公開宣言を並べて照合し、降格根拠を「どの文書のどの語彙と一致しているか」で second-opinion ファイルに書く。実装手段の言い換え (「初期化子で満たす」等) だけを根拠に降格しない。

## 経緯
- 2026-09-02 ios-engine-foundation: 相方が 2 回指摘した `columnSpacing` modifier の非対称を 2 回とも「対応不要」に降格したが、core/ADR-0006 の語彙 (`.list(rowSpacing:)`) と実装 (`.list` + `rowSpacing(_:)` modifier のみ) が既に食い違っており、公開 API の Major 相当だった。引き継ぎ後の再突き合わせで再昇格。
