# セカンドオピニオン: image-loading (code-008)
**相方**: codex / **label**: so-code-image-loading-008 / **日付**: 2026-09-08 / **対象**: レビュー 7 周目の Minor (iOS UI テストの基準点後 sized=0 検査) と Suggestion (印の内訳の並び) への対応 4 ファイル
---

**日付**: 2026-09-08  
**指摘件数**: Critical 0 / Major 0 / Minor 0 / Suggestion 0

## サマリー

指定された狭い差分を静的レビューした。前回の Minor 3件と並び替えの Suggestion はすべて解消しており、両プラットフォームの規則も一致している。新たな問題は確認できなかった。

## 前回指摘の解消確認

| 対応項目 | 判定 | 根拠 |
|---|---|---|
| iOS が基準点後の差分ゼロを検査していない | 解消 | `samples/ios/KsCollectionViewSamplesUITests/ImageLoadingSlotUITests.swift:33-49` で、初回の非ゼロを確認後に印を叩き、`session > 0`、`sized=0`、`unsized=0`、`lines=0`、累計非ゼロを検査している。`baseline` 更新が欠落すれば失敗する |
| 証跡に解消済みの不足が現状として残っている | 解消 | `kasane/changes/image-loading/evidence/image-behavior-observation.md:138-149` で「現在は解消済み」と現行機構を明示し、古い記述を「当時」の記録として分離している。参照先も現行の手順4へ訂正済み |
| テストコメントが lessons のローカル識別子を参照している | 解消 | `samples/android/app/src/testDebug/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotCounterTest.kt:198-204` は待機理由を自己完結して説明しており、lessons 参照は残っていない |
| 内訳を差分の大きい順へ変更 | 解消 | iOS は `samples/ios/KsCollectionViewSamples/ImageLoadingSlotMark.swift:104-125`、Android は `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotMark.kt:118-136` で同一規則を実装している |

並び順は双方とも、次の完全に同じ優先順位である。

1. `Δsized` 降順
2. `Δunsized` 降順
3. 識別子の文字列表現による昇順

実際の Sample 識別子も双方とも `Int` なので、文字列比較の結果も一致する。Android テストは `samples/android/app/src/testDebug/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotCounterTest.kt:163-195` で、`sized` 優先、`unsized` 優先、文字列順をそれぞれ固定している。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`
- `kasane/handbook/cross/sample-parity.md`
- `kasane/handbook/cross/test-execution.md`
- `kasane/handbook/cross/runtime-behavior-verification.md`
- `cross/ADR-0004`
- `swift-ui-impl-skill`
- `kotlin-impl-skill`
- `jetpack-compose-impl-skill`

提示された iOS Sample UI 5件／0失敗、Android Sample unit 28件／0失敗、Android本体 unit 129件／0失敗、`:app:assembleRelease` 成功、標準lint禁止0件を前提とした静的レビューであり、こちらでは再実行していない。指定どおりレビュー結果ファイルへの書き込みも行っていない。

**判定: APPROVED**



## 突き合わせ結果 (ホスト側 review-008.md との照合、2026-09-08)

双方 APPROVED。相方の指摘は 0 件。ホスト側のみの Suggestion 1 件 (並び替えの帰結として判定対象が内訳の最後尾に回り必ず溢れるのに、`deltaSnapshot()` の doc コメントと deviation の「溢れうる」が追随していない) は、コメントと deviation の記述修正で対応した。集計: 確定 0 / 採用 0 / 降格 0 / 未解決 0。
