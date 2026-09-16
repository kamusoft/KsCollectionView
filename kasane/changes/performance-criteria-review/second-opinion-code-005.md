# セカンドオピニオン: performance-criteria-review (code-005)
**相方**: codex / **label**: so-code-performance-criteria-review (turn 5) / **日付**: 2026-09-15 / **対象**: review-004 / second-opinion-code-004 の指摘修正後の作業ツリー (未コミット変更すべて)
---
## 再レビュー結果

**判定: APPROVED**

### 前回 Major

**解消 — 許容幅 `1e-9` の裏付け**

該当箇所:

- `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:47`
- `ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:98`
- `kasane/changes/performance-criteria-review/deviation.md:17`

`matchTolerance × 0.9` を実際の推定高さとして UIKit 経路へ渡し、以下が直接確認されています。

- `matchesLayout` では一致
- 完全一致時より無効化・再測定が増えない
- `contentHeight` に観測可能な差が残らない
- `matchTolerance × 1.1` は不一致になる

さらに `+0.1 pt` と `+0.2 pt` の対照により、実際の再解決境界が半画素付近であり、`1e-9 pt` が十分内側にあることも固定されています。前回問題にした「実装の許容幅とエンジンテストの検証点が結び付いていない状態」は解消しています。

### 新規指摘

#### [Minor] 「高さが違うたびに解き直す」という説明が確定した挙動と矛盾する

**該当箇所**: `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:6`

**問題点**: コメントは「高さが違うたびにレイアウトの解き直しが起こる」と説明していますが、追加テストでは `+0.1 pt` の差があっても解き直しが起きないことを確定しています。上界としての計数ロジックには影響しませんが、同じコメント内の半画素境界の説明とも矛盾します。

**推奨修正**: 「高さの差がピクセル格子への丸め境界を超えると解き直しが起こる。この計数は、その境界より十分小さい許容幅を除いた差を数えるため上界になる」など、確定した挙動に合わせてください。

Critical 0件、Major 0件、Minor 1件、Suggestion 0件です。提示された iOS 172件成功および lint 0件を証跡として扱い、こちらではビルド・テストを再実行していません。



## 突き合わせ結果 (review-005.md との照合、2026-09-15)

| # | 相方の指摘 | ホスト側 | 採否 | 重要度 |
|---|---|---|---|---|
| 1 | `KsLayoutDiagnostics.swift:6` の「高さが違うたびに解き直す」が確定した挙動 (半画素境界) と矛盾 | Major 2 (`KsEstimatedHeight.swift:10-15` の機構説明が確定事実と逆) と同種の「コメントの機構説明」の指摘 | **採用** | Minor |

ホスト側のみ: Major 1 (今周に足したテストが 0.1 / 0.2 pt の固定値で、倍率 2 の機種では半画素 = 0.25 pt のため決定的に失敗)、Major 2、Minor 1 (deviation の積み上がりの実測値 5.3 pt → 4 機種で 6.0 pt)、Suggestion 2 (再掲)。すべて採用。未解決 (矛盾) なし。上限超過の延長はオーナー承認済みで、残指摘は修正箇所・内容とも特定済みのため、lessons/inbox の `stop-asking-per-cycle-when-fix-is-specified` に従い伺わずに次サイクルへ進む。
