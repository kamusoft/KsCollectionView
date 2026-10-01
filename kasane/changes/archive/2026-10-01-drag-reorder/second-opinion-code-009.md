# セカンドオピニオン: drag-reorder (code-009)
**相方**: codex / **label**: so-code-drag-reorder-rework / **日付**: 2026-10-01 / **対象**: iOS の並べ替えの reorder-capable な形への組み替え (ios/Sources/KsCollectionView/KsCollectionViewController.swift・KsCollectionViewController+Reorder.swift・KsReorderDrag.swift・KsReorderGapTracker.swift・KsReorderSnapshotTiming.swift、ios/Tests/KsCollectionViewTests/KsReorderTestSupport.swift・KsReorderEngineTests.swift、samples/ios/KsCollectionViewSamplesUITests/ReorderDemoUITests.swift)
---
# レビュー結果: drag-reorder

**判定: APPROVED**（Critical 0件、Major 0件、Minor 1件）

指定された iOS の組み替え、関連 spec、合意済みの deviation、テストを静的に照合しました。受け入れ判定、グループ間移動、取りやめ、保留と復元の経路に、修正を要する動作上の問題は確認できませんでした。提示されたテスト結果を前提とし、このレビューでは実行や映像による再計測はしていません。

## 指摘事項

### 🟡 Minor: 冒頭コメントが復元の時機と一致しない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:8`  
**問題点**: 受け入れない場合に「次の周回で」戻すとありますが、実装は `dropSessionDidEnd` を待ってから戻します。待機中の動作を読み違える原因になります。  
**推奨修正**: 「ドロップのセッションが終わってから元の並びへ戻す」に直してください。

**確認した観点**: spec と合意済み乖離への適合、1回だけの通知、置けるかの判定、グループ間の行き先、受け入れと復元、ドラッグ中の保留、読み上げ操作、長押し、関連テストの範囲。

## 突き合わせ結果

ホスト側レビュー: review-009.md (CHANGES_REQUESTED、Major 1 / Minor 3 / Suggestion 2)。

- **確定**: 相方の Minor「冒頭コメントが復元の時機と一致しない」(KsCollectionViewController+Reorder.swift:8) — ホスト側は指摘なしだが、箇所と食い違いが特定されており修正の費用が小さい。ホスト側の指摘と同じ修正便に入れる
- 相方は静的レビューで、ホスト側の Major (受け入れた後の収まりが証跡の値で再現しない。実行時の計測による) には触れていない。矛盾ではなく観点の差として、ホスト側の Major を採る
- **降格**: なし / **未解決**: なし
