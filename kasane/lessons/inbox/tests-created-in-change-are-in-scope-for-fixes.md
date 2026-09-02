---
scope: process
kind: pain
severity: normal
count: 1
first-seen: 2026-09-02
last-seen: 2026-09-02
evidence:
  - ios-engine-foundation (本 change の修正サイクルで追加したテスト 2 件の環境依存失敗を「スコープ外 → 簡易起票」と提示し、オーナーが「この change で作ったテストならここで直す」と差し戻した)
---

## ルール文
ワーカーが「スコープ外の発見」として報告した不具合を起票へ振り分ける前に、該当ファイルがこの change (修正サイクルを含む) で追加・変更されたものかを `git status` / 前回レビューの追跡表で確認し、この change 由来なら同梱修正として扱う。

## 経緯
- 2026-09-02 ios-engine-foundation: accessibility 設定に依存して失敗するテスト 2 件は review-002 / 003 の修正サイクルで本 change が追加したものだったが、ワーカー報告の「本 change の変更とは無関係」をそのまま受けて起票を提案した。
