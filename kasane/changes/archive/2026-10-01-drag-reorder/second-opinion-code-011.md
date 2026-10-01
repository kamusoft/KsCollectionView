# セカンドオピニオン: drag-reorder (code-011)
**相方**: codex / **label**: so-code-drag-reorder-rework / **日付**: 2026-10-01 / **対象**: review-009 / second-opinion-code-009 の指摘への対応と、置く絵の影の修正 (ios/Sources/KsCollectionView/KsCollectionViewController.swift・KsCollectionViewController+Reorder.swift・KsReorderDrag.swift・KsReorderDragDropDelegate.swift、ios/Tests/KsCollectionViewTests/KsReorderTestSupport.swift・KsReorderEngineTests.swift)
---
# レビュー結果: drag-reorder（review-009 対応）

**判定: APPROVED** — Critical 0件、Major 0件、Minor 1件、Suggestion 1件。

セッションの同一性、表示中の並びからの項目取得、隙間が動く前のドロップ経路とそのテストを静的に照合しました。影が約0.3秒で収まるという証跡の値は、静的レビューの指定に従い再計測していません。テストは提示された iOS ライブラリ各529件、UI テスト10件の成功結果を前提としています。

## 指摘事項

### 🟡 Minor: 古いセッションの終了通知が次のドラッグの指位置を消す

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:281`  
**問題点**: セッションの同一性を照合する前に `reorderFingerY` を `nil` にしています。前の `dropSessionDidEnd` が次のドラッグ中に届く順序では、並べ替えの復元は守られても、次のドラッグの上端自動スクロールが止まります。`fingerY == nil` は送りを止め、iOS 18 向けの待ち時間もリセットします。追加されたテストは、2回目を既にドロップした後に古い通知を渡すため、この状態を検出しません。  
**推奨修正**: 指位置を消す処理をセッション照合の後へ移し、2回目のドラッグ中に古い終了通知が届くテストを追加してください。

### 🔵 Suggestion: テストの説明コメントがまだ別のテストに付いている

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsReorderEngineTests.swift:704`  
**問題点**: 見出し上の隙間を説明する3行が、セッション同一性のテストの直前にあります。  
**推奨修正**: `test見出しの上では直前の隙間の位置で知らせる` の直前へ移してください。

**照合した規律**: `ksn-review` の仕様充足・テスト・状態管理の観点、`kasane/lessons/code-review.md`、ソースコメント規約。影の見た目と計測値はホストの証跡の範囲として扱いました。

## 突き合わせ結果

ホスト側レビュー: review-011.md (CHANGES_REQUESTED、Major 1 / Minor 1 / Suggestion 1)。

- **確定**: Suggestion「テストの説明コメントがまだ別のテストに付いている」(KsReorderEngineTests.swift:704) — ホスト側の Suggestion と同じ
- **採用**: Minor「古いセッションの終了通知が次のドラッグの指位置を消す」(KsCollectionViewController+Reorder.swift:281) — ホスト側は指摘なし。該当箇所と実害 (次のドラッグの上端の自動スクロールが止まる) が特定されている
- 相方は静的レビューで、ホスト側の Major (グループを下へまたいで置いたときの置く動きの見え方の崩れ。実行時の観測による) と Minor (証跡・deviation の影の消え方の書き方) には触れていない。観点の差として、ホスト側の指摘を採る
- **降格**: なし / **未解決**: なし
