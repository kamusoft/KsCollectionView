# セカンドオピニオン: drag-reorder (code-002)
**相方**: codex / **label**: so-code-drag-reorder / **日付**: 2026-09-30 / **対象**: 作業ツリーの未コミットの変更 (`git diff HEAD` と未追跡のファイル。ios/ android/ samples/)。review-001 / second-opinion-code-001 の指摘の修正後
---
**判定: CHANGES_REQUESTED — Major 1 件。** 前回の 2 件のうち、`canDrop` の再評価は解消しました。list の末尾への飛びは通常の複数可視項目では解消しましたが、次の条件が残っています。

### 🟠 Major: 持ち上げた項目だけが見えると、一覧末尾へ飛ぶ

**該当箇所**: [android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsReorderController.kt:735](android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsReorderController.kt:735)

**問題点**: 画面を占める高さの行など、可視項目が持ち上げた項目だけの場合、その項目は走査から除かれ、`lastCounted` が `null` になります。一覧には後続項目があり、末尾を表示していなくても、736 行目が最後のグループの末尾を返します。前回指摘した遠い位置への飛びが、この構成で再発します。

**推奨修正**: `lastCounted == null` を一覧末尾の判定に使わず、後続項目が画面外にある場合は現在の置き先を維持するなど、可視範囲から根拠なく遠い行き先を作らないようにしてください。高い行が 1 件だけ見える長い list をテストに加えてください。

前回の **ドロップ直前の `canDrop` 再評価は解消**しています。追加の指摘はありません。提示された全テスト成功・lint 違反 0 件を前提とした静的レビューで、実行時の動きは判定していません。

## 突き合わせ結果

ホスト側レビュー: review-002.md (NEEDS_DISCUSSION、Major 1 / Minor 1 / Suggestion 1。前回の指摘はすべて解消と判定)。

- **採用**: Major「持ち上げた項目だけが見えると、一覧末尾へ飛ぶ」(KsReorderController.kt:735) — ホスト側は指摘なし (通常の複数の可視項目の構成で解消を確認)。該当箇所の特定と構成 (可視項目が持ち上げた項目だけ) があり、前回の修正で塞ぎきれなかった経路。ホスト側の見逃しとして扱う
- **確定**: 前回 Major 2 (置く直前の canDrop の再評価) の解消 — ホスト側も解消と判定
- **降格**: なし
- **未解決**: なし (ホスト側の NEEDS_DISCUSSION 1 件は相方の指摘に無く、別途オーナーに諮る)
