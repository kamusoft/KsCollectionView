# セカンドオピニオン: drag-reorder (code-004)
**相方**: codex / **label**: so-code-drag-reorder / **日付**: 2026-09-30 / **対象**: 作業ツリーの未コミットの変更 (`git diff HEAD` と未追跡のファイル。ios/ android/ samples/)。second-opinion-code-003 / review-003 の指摘の修正の後
---
**判定: APPROVED — Minor 1 件。** 前回の Major は解消しています。`dropSessionDidExit` とドロップ終了時に指の位置を消し、再入後の位置更新でスクロールを再開する経路とテストを確認しました。

### 🟡 Minor: 上端の反応帯が UIKit と重なり得る

**該当箇所**: [ios/Sources/KsCollectionView/KsReorderTopAutoScroll.swift:45](ios/Sources/KsCollectionView/KsReorderTopAutoScroll.swift:45)

**問題点**: 上端の安全領域が UIKit の反応帯より短い配置では、UIKit の帯と自前の帯が画面上で重なります。たとえば安全領域が 24pt、帯が 60pt なら 24〜60pt が重複し、両方が送る可能性があります。現在のテストは安全領域が 0 または帯より長い場合を確認しています。これはコードと記録された帯幅からの推論で、同時送出は実機では未確認です。

**推奨修正**: 短い安全領域の配置でスクロールを観測し、重複する場合は UIKit が反応する部分で自前の送りを行わないようにしてください。

提示された全テスト成功・lint 違反 0 件を前提とした静的レビューです。合意済みの `deviation.md` は違反として扱っていません。

## 突き合わせ結果

ホスト側レビュー: review-004.md (APPROVED、Minor 2 / Suggestion 1。前回の指摘はすべて解消と判定)。

- **確定**: 前回 Major (一覧の外へ出ても上端の送りが続く) の解消 — ホスト側も iOS 26.5・18.6 で解消と判定
- **採用**: Minor「上端の反応帯が UIKit と重なり得る」(KsReorderTopAutoScroll.swift:45) — ホスト側は指摘なし。安全領域が UIKit の帯より短い配置 (バーの無い全画面など) で両方が送る経路の指摘で、根拠は推論だが箇所と構成が特定されており、観測で確かめて直す費用が小さい。ホスト側の Minor 2 件と同じ修正便に入れる
- **降格**: なし
- **未解決**: なし
