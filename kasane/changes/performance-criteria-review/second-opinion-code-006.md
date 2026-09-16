# セカンドオピニオン: performance-criteria-review (code-006)
**相方**: codex / **label**: so-code-performance-criteria-review (turn 6) / **日付**: 2026-09-15 / **対象**: review-005 / second-opinion-code-005 の指摘修正後の作業ツリー (未コミット変更すべて)
---
## 再レビュー結果

**判定: APPROVED**

### 前回 Minor

**解消 — 診断カウンタの機構説明**

該当箇所:

- `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:6`
- `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:41`

「高さが違うたびに解き直す」という誤った説明は、差がピクセル格子の丸め境界（半画素）を超えた場合に解き直す、という実測に即した説明へ修正されています。`1e-9 pt` がその境界より十分小さいため、不一致数を解き直し回数の上界として扱えるという関係も明確です。

### ホスト側指摘の確認

以下はいずれも解消しています。

- `ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:60`  
  対照値を `displayScale` から導出し、倍率2・3の双方で半画素未満／超過を検証しています。
- `ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:225`  
  実測した倍率から1画素の大きさを返す `baseline()` が追加されています。
- `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:854`  
  現在の推定値と実測値が一致する環境にも依存しない検証へ修正されています。
- `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:10`  
  `shouldInvalidateLayout` の戻り値に機構を帰属させず、preferred と original の比較、および戻り値との非連動を正しく説明しています。
- `kasane/changes/performance-criteria-review/deviation.md:16`  
  積み上がりは60行で `6.0 pt`、倍率2・3双方の実測値と10,000件への外挿が整合しています。

### 新規指摘

ありません。

Critical 0件、Major 0件、Minor 0件、Suggestion 0件です。提示された3機種での172件成功およびlint 0件を証跡として扱い、こちらではビルド・テストを再実行していません。



## 突き合わせ結果 (review-006.md との照合、2026-09-15)

相方 APPROVED (指摘なし)、ホスト APPROVED (Minor 1: deviation.md 21 行目の倍率 2 の記述に機種・OS が無い → 直接追記して解消。Suggestion 2 は再掲で見送り)。未解決なし。レビューサイクル終了 (6 周。上限 3 周をオーナー承認で延長、5 周目以降は lessons/inbox の `stop-asking-per-cycle-when-fix-is-specified` に従い伺わず進行)。
