# セカンドオピニオン: drag-reorder (code-003)
**相方**: codex / **label**: so-code-drag-reorder / **日付**: 2026-09-30 / **対象**: 作業ツリーの未コミットの変更 (`git diff HEAD` と未追跡のファイル。ios/ android/ samples/)。second-opinion-code-002 の指摘の修正と iOS の 2 件の変更の後
---
**判定: CHANGES_REQUESTED — Major 1 件。** 前回指摘した Android の末尾への飛びは解消しています。持ち上げた項目だけが見える場合に現在の置き先を保つ実装と、800dp の行で再現するテストを確認しました。

### 🟠 Major: ドラッグが一覧の上側へ出ても自動スクロールが続く

**該当箇所**: [ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:134](ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:134)、[ios/Sources/KsCollectionView/KsReorderDragDropDelegate.swift:47](ios/Sources/KsCollectionView/KsReorderDragDropDelegate.swift:47)

**問題点**: 自前のスクロールは最後に記録した `reorderFingerY` を毎フレーム使います。指が上端の反応帯から一覧の外へ出ても、その値はドラッグ終了まで消されません。[Apple の `dropSessionDidExit` の説明](https://developer.apple.com/documentation/uikit/uicollectionviewdropdelegate/collectionview%28_%3Adropsessiondidexit%3A%29)によれば、UIKit は一覧の境界を出た時点で別の通知を送りますが、現在の delegate は受け取っていません。コード上、その後も一覧が先頭へ向かってスクロールし続けます。

**推奨修正**: `dropSessionDidExit` で記録した指の位置を消し、再び一覧に入って位置が更新されたときだけスクロールを再開してください。上端の帯から一覧外へ出して保持するケースをテストしてください。

提示された全テスト成功・lint 違反 0 件を前提とする静的レビューです。合意済みの `deviation.md` は違反として指摘していません。

## 突き合わせ結果

ホスト側レビュー: review-003.md (CHANGES_REQUESTED、Major 1 / Minor 1 / Suggestion 1)。

- **確定**: Major「ドラッグが一覧の上側へ出ても自動スクロールが続く」(KsCollectionViewController+Reorder.swift:134、KsReorderDragDropDelegate.swift:47) — ホスト側の Major と同じ箇所・同じ原因 (dropSessionDidExit / End を受けず、帯の中で控えた指の位置が残る)。ホスト側が iOS 26.5・18.6 で再現
- **確定**: 前回 Major (Android、見えているのが持ち上げた項目だけのとき) の解消 — ホスト側もエミュレータの A/B で解消と判定
- **降格**: なし
- **未解決**: なし
