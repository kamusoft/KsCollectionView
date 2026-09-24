# セカンドオピニオン: image-loading (code-013)
**相方**: codex / **label**: so-code-image-loading-013 / **日付**: 2026-09-08 / **対象**: 12 周目の指摘への記述修正 (evidence/image-grid-measurement-ios.md、deviation.md)
---
# レビュー結果: image-loading（13回目）

**判定: CHANGES_REQUESTED**  
**指摘件数**: Critical 0 / Major 0 / Minor 1 / Suggestion 0  
レビュー結果ファイルは指定どおり作成していません。

## 指摘事項

### [🟡 Minor・優先度高] deviation の再解析項に共通要因を排除する断定が残っている

**該当箇所**: `deviation.md:99`

証跡側 `evidence/image-grid-measurement-ios.md:335-338` と `deviation.md:97` は、次のように適切に限定されています。

- 共通要因だけでは件数差を説明できない「可能性が高い」
- 自動化なしの対照がなく、共通要因の分離は未確認

しかし `deviation.md:99` は「**共通要因（自動化）だけでは 108〜136 ms/s を説明できない**」と断定した直後に「分離は未確認」としています。分離できていない以上、この因果排除は証跡より強く、両文書で結論が一致していません。

**推奨修正**: `deviation.md:99` も証跡と同じく、例えば「共通要因だけでは件数差を説明できない可能性が高いが、自動化なしの対照がないため分離は未確認」に狭めてください。

## 12周目指摘の解消状況

| 指摘 | 判定 |
|---|---|
| 相方 Minor: 共通要因の断定的な排除 | **一部未解消**。`deviation.md:97` と証跡は修正済みだが、`:99` に断定が残る |
| 相方 Minor: 試行2の「主因」断定 | **解消**。「主因は未特定」に修正済み |
| ホスト Minor: 試行2のサンプル内訳 | **解消**。一次 trace と一致する5件（区切り線2／画像1／SwiftUI 1／空1、駆動側0） |
| ホスト Suggestion: 対照b1の合計差 | **解消**。312.59〜329.21 ms の幅と結論不変を限界に記録 |
| ホスト Suggestion: 自動化の分類定義 | **解消**。`XCTAccessibilityFramework`／`XCTest` 系に限定し、`UIViewAccessibility` を除外 |

一次 trace の再確認では、試行2の commit は 16.98 ms、主スレッドサンプル5件で、修正後の内訳と一致しました。対象2文書への local-path／identity lint と `git diff --check` も成功しています。記述のみの限定レビューのためビルド・テストは再実行していません。



## 突き合わせ結果 (2026-09-08)

相方 Minor 1 件 (deviation の再解析の項に共通要因を排除する断定が残存) → **採用**、「可能性が高いが分離は未確認」に修正済み。12 周目の他の指摘は解消と判定。ホスト側 review-013.md は到着後に追記。集計: 採用 1 / 未解決 0。

追記 (ホスト側 review-013.md 到着後): ホスト側は APPROVED (Minor 低 1: 「自動化」の分類定義に `AXRuntime` / `AccessibilityViewGraph` が足りない / Suggestion 3: b1 の注記が指す列、deviation:99 の断定 (相方と同じ・修正済み)、commit 内のサンプルが 5 件のみという事実の明記)。いずれも文言の反映で対応し、再レビューは挟まない (レビュアーの判断どおり)。
