# セカンドオピニオン: drag-reorder (code-005)
**相方**: codex / **label**: so-code-drag-reorder / **日付**: 2026-09-30 / **対象**: review-004 の後の iOS の上端の自動スクロールの修正 (ios/Sources/KsCollectionView/KsReorderTopAutoScroll.swift・KsCollectionViewController.swift、ios/Tests/KsCollectionViewTests/KsReorderTopAutoScrollTests.swift・KsReorderEngineTests.swift)
---
**判定: APPROVED — Minor 1 件。** 前回の重複送出は解消しています。UIKit の反応帯では自前の送りを抑える条件と、境界のテストを確認しました。

### 🟡 Minor: iOS 18 以前で帯の境界を越えると再び 0.75 秒止まる

**該当箇所**: [ios/Sources/KsCollectionView/KsReorderTopAutoScroll.swift:84](ios/Sources/KsCollectionView/KsReorderTopAutoScroll.swift:84)

**問題点**: UIKit と自前の帯が重なる配置では、UIKit の帯にいる間、毎フレーム `dwell` が 0 に戻ります。iOS 18 以前で UIKit によるスクロールが始まった後、指を自前の帯だけが残る位置へ動かすと、そこで改めて 0.75 秒の待ちが入り、スクロールが途切れます。これはコード上の境界条件で、実機での見え方は未確認です。

**推奨修正**: 自前の帯に入っている時間は重複部分でも数え、重複部分での自前の送出だけを抑えてください。帯をまたぐ継続操作を iOS 18 の設定でテストしてください。

提示されたテスト成功・lint 違反 0 件を前提とする静的レビューです。

## 突き合わせ結果

ホスト側レビュー: review-005.md (APPROVED、Minor 1 / Suggestion 1。前回の指摘はすべて解消と判定)。

- **確定**: Minor「iOS 18 以前で帯の境界を越えると再び 0.75 秒止まる」(KsReorderTopAutoScroll.swift:84) — ホスト側の Minor (下向きにまたぐと UIKit の帯の中で待ちの時間を 0 に戻すため待ち直す、:83〜:90) と同じ箇所・同じ原因
- **確定**: 前回 Minor (UIKit の帯と重なる配置で両方が送る) の解消 — ホスト側も解消と判定
- **降格**: なし
- **未解決**: なし
