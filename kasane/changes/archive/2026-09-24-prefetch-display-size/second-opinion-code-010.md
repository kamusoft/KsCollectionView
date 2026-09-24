# セカンドオピニオン: prefetch-display-size (code-010)
**相方**: codex / **label**: so-code-prefetch-display-size-010 / **日付**: 2026-09-24 / **対象**: review-009 の Major への修正 (ios/Sources/KsCollectionView/KsImage.swift・KsImageRetainedMatch.swift、ios/Tests/KsCollectionViewTests/KsImageCacheContractTests.swift)
---
## レビュー結果

**🟡 Minor — 条件を切り替えて戻すと、古い表示経路の記録が残ります。** `KsImageRetainedMatch.swift` では、別条件で画像が引き当たると `resolve` がその画像を返しますが、`deferredLoadCondition` は更新されません。条件 A で包みを選択 → 条件 B でメモリから引き当て → 先読みのない条件 A に戻ると、古い記録によって包みが再選択されます。条件が変わった時点で選択記録を破棄する修正を推奨します。現時点で確認できる影響は、不要な表示時の再照会です。

元の Major については、同じ条件での親の組み立て直しでも包みが維持されるため、修正されています。`clear(.all)` と対象ソースの `remove` は世代の変更、枠の変更は `condition` の変更によって再選択されることを静的に確認しました。テストは今回実行しておらず、276 件成功と修正前の回帰テスト失敗は依頼文に記載されたホスト側の結果です。

**判定: APPROVED**（Critical 0、Major 0、Minor 1）



## 突き合わせ結果

ホスト側: review-010.md (APPROVED、指摘 0。修正を外すと回帰テストとプローブ 4 本が失敗することを確認)。

| 指摘 | 出典 | 採否 | 根拠 |
|---|---|---|---|
| 条件を切り替えて戻すと古い表示経路の記録が残る (Minor) | 相方のみ | **降格** | 影響は画面に出る時点の再照会が 1 回余計に走ることだけで、spec の合否・表示結果は変わらない |

双方 APPROVED。件数: 確定 0 / 採用 0 / 降格 1 / 未解決 0。レビューはここで収束。
