# セカンドオピニオン: performance-criteria-review (code-004)
**相方**: codex / **label**: so-code-performance-criteria-review (turn 4) / **日付**: 2026-09-15 / **対象**: review-003 / second-opinion-code-003 の指摘修正後の作業ツリー (未コミット変更すべて)
---
## 再レビュー結果

**判定: CHANGES_REQUESTED**

### 前回 Minor

**解消 — 診断カウンタの「上界」の説明**

該当箇所:

- `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:6`
- `ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:20`
- `kasane/changes/performance-criteria-review/deviation.md:16`

1画素未満を一律に一致扱いしていた以前の説明は修正され、`nextUp` では再測定が増えず、`+0.2 pt` では増えるという正負の対照も追加されています。前回指摘した文言と実装の直接的な矛盾は解消しています。

### 新規指摘

#### [Major] `1e-9 pt` の許容範囲全体が UIKit テストで裏付けられていない

該当箇所:

- `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:41`
- `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:56`
- `ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:20`
- `ios/Tests/KsCollectionViewTests/KsEstimatedHeightTests.swift:106`
- `kasane/changes/performance-criteria-review/deviation.md:18`

問題点:

エンジンテストが「解き直しなし」と確認しているのは `rowHeight.nextUp`、すなわち約 `7.1e-15 pt` の差だけです。一方、実装は差が `1e-9 pt` 未満ならすべて一致とします。これはテストした差の約14万倍であり、例えば `5e-10 pt` の差を UIKit が無視することは確認されていません。

`+0.2 pt` の正対照は計測経路が機能することを示しますが、`nextUp` と `1e-9` の間の境界は確定できません。この範囲で再解決が起きる場合、診断値は再解決回数を過少計上するため、「上界」という保証が再び成立しません。

推奨修正:

- `matchTolerance / 2` など `1e-9` 直下の差についてエンジンテストを追加し、再解決が起きないことを直接確認する。または、
- 許容判定を、現在確認できている完全一致および隣接表現値（`nextUp` / `nextDown`）までに限定する。

後者の場合、固定値ではなく ULP に基づく比較にすると、値の大きさが変わっても「最下位桁」という説明と一致します。

Critical 0件、Major 1件、Minor 0件、Suggestion 0件です。提示されたテスト結果は確認済み証跡として扱い、こちらではビルド・テストを再実行していません。



## 突き合わせ結果 (review-004.md との照合、2026-09-15)

| # | 相方の指摘 | ホスト側 | 採否 | 重要度 |
|---|---|---|---|---|
| 1 | 許容幅 1e-9 のうちテストで裏付けたのは nextUp だけで、境界が確定していない | Minor (新テストが `matchTolerance` を固定しておらず 0.1 pt に緩めても緑)。ホストのプローブで境界は半画素 (+0.1 pt は解き直しなし、+0.2 pt であり) と確定し、1e-9 は十分内側 | **確定** (両者とも「テストが許容幅を固定する」修正を求める。挙動と定数は変更不要) | Major |

ホスト側のみ: Major (deviation.md とテスト doc の「shouldInvalidateLayout は呼ばれない」「境界は最下位桁」が再現せず、`KsEstimatedHeight.swift` の説明と矛盾 — 記録とコメントの書き直しのみ)、Minor (混在 fixture の参考値がテストコメント側で条件なし)、Suggestion 3。すべて採用。未解決 (矛盾) なし。
