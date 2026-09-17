# セカンドオピニオン: performance-criteria-review (code-003)
**相方**: codex / **label**: so-code-performance-criteria-review (turn 3) / **日付**: 2026-09-15 / **対象**: review-002 / second-opinion-code-002 の指摘修正後の作業ツリー (未コミット変更すべて)
---
# 再レビュー結果

**判定: APPROVED**

前回の Major 2 件はいずれも解消しています。修正による機能上の新規問題は確認できませんでしたが、診断値の意味を誤解させるコメント不整合を Minor 1 件検出しました。

提示されたテスト結果は受領済みとして扱い、ビルド・テストの再実行およびファイル書き込みは行っていません。

## 前回 Major の確認

1. **解消 — 量子化した高さの一致の扱い**

   **該当箇所**: `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:49`、`ios/Sources/KsCollectionView/KsEstimatedHeight.swift:46`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:335`

   不一致判定は量子化値同士の比較ではなく、実測値と original の差を直接比較する `matchesLayout` に変更されています。最頻値の分類にはピクセル格子を使用しつつ、推定値としては選択された格子内の直近の実測値を返すため、分類とレイアウトへ渡す値の責務も分離されています。

   1 ピクセル未満を一致とする扱いと推定値の返却方法は `kasane/changes/performance-criteria-review/deviation.md:16` の合意済み差分に一致しています。境界テストも `ios/Tests/KsCollectionViewTests/KsEstimatedHeightTests.swift:106` にあります。

2. **解消 — 計測スキームの TestAction 構成**

   **該当箇所**: `samples/ios/KsCollectionViewSamples.xcodeproj/xcshareddata/xcschemes/KsCollectionViewSamplesPerformance.xcscheme:26`

   `TestAction` は Release に変更されています。同じスキームの `LaunchAction` も `:52` で Release に揃っています。提示された Release の build-for-testing 成功およびメモリ自動往復 1 件成功とも整合します。

## 新規指摘

### [🟡 Minor] 診断カウンタが「再解決回数の上界」と説明されたままになっている

**該当箇所**: `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:6`、`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:795`

**問題点**: `matchesLayout` は合意済み deviation に従って 1 ピクセル未満の差を一致として扱います。一方、型コメントとテストコメントは、異なる高さをすべて数えてレイアウト再解決回数の「上界」を与えると説明しています。1 ピクセル未満の差による再解決候補を数えない以上、厳密な上界ではありません。`KsEstimatedHeight.swift:20` の「浮動小数として同一のときだけ」という説明とも食い違います。

**推奨修正**: コメントを「1 ピクセル以上の高さ差を数える診断用の近似指標」など、合意済みの判定規則に合わせてください。`recordSelfSizedCell` の引数説明 (`KsLayoutDiagnostics.swift:60`) も「同じ高さ」ではなく「1 ピクセル未満の差」に揃えると明確です。挙動や deviation の変更は不要です。

## 件数

- Critical: 0
- Major: 0
- Minor: 1
- Suggestion: 0

Critical / Major はなく、Minor は説明上の低優先度問題に限られるため、判定は **APPROVED** です。



## 突き合わせ結果 (review-003.md との照合、2026-09-15)

| # | 相方の指摘 | ホスト側 | 採否 | 重要度 |
|---|---|---|---|---|
| 1 | 診断カウンタの「上界」の説明が判定規則 (1 ピクセル未満は一致) と食い違う | Major (同じ論点。厳密比較では不一致率 0.100 → 0.825 で、上界の主張が実測と食い違う。UIKit が最下位桁の差を無視するかは未検証) | **確定** (高い方を採る) | Major |

相方は APPROVED、ホストは CHANGES_REQUESTED。相方 code-002 の Major 1 とホスト review-003 の Major が同じ論点で 2 周連続残存 → 収束シグナルにより NEEDS_DISCUSSION としてオーナーへ。ホスト側のみ: Minor 2 (画像グリッドの自動駆動が spec と食い違い deviation 未記録 / 混在 fixture の数値に機種・OS が無い)、Suggestion 2。
