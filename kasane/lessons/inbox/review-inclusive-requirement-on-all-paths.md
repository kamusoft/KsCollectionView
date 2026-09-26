---
scope: code-review
kind: pain
severity: normal
count: 2
first-seen: 2026-09-05
last-seen: 2026-09-26
evidence:
  - template-parent-state-observation (Requirement「配列が同値であっても可視セルを再構成する」を同値配列経路にしか実装しておらず、配列変更と観測値変更が同時に届くと既存可視セルが古いまま残る欠陥を review-001 は見逃し、相方 second-opinion-code-001 Major 1 が検出した)
  - sections-grouping (Requirement「見出しの内容の更新」の「グループの値が変わらない場合も同じとする」に対し、Android はグループの構成が等しいと古い解決結果を使い回して、等しいが中身の違うグループの値を見出しへ渡していた。review-002 は見逃し、相方 second-opinion-code-002 が Major で検出した)
---

## ルール文
Requirement が「〜であっても」「〜でも」の包含条件で書かれているとき (例: 「配列が同値であっても再構成する」)、レビュアーは明示された経路 (同値配列) だけでなく包含の外側の経路 (配列が変わる更新) でも同じ THEN が成立するかを検査する。検査は最初の更新の直後の状態で行い、既存テストが 2 回目以降の更新後しか見ていなければ 1 回目直後を見るプローブを足す。

## 経緯
- 2026-09-05 template-parent-state-observation: 「配列の変化と観測する値の変化が同時に届く」Scenario の既存テストは、観測値を元に戻す 2 回目の更新後にだけ既存セルを確認していたため欠陥を素通りさせた。ホストのレビューは spec の Scenario 対応表を埋めて APPROVED 寄りに判定し、相方が実装の分岐 (早期 return 経路にしか観測値の変化が渡っていない) を読んで Major として検出。修正で配列変更経路にも引き渡し、回帰テスト 2 本を追加した。
- 2026-09-26 sections-grouping: 包含条件 (グループの値が変わらない場合も) の外側 — 等値だが別の中身の値 — をホスト側のレビューが検査せず、相方が検出した。
