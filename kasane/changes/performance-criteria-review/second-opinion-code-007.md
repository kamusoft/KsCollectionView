# セカンドオピニオン: performance-criteria-review (code-007)
**相方**: codex / **label**: so-code7-performance-criteria-review / **日付**: 2026-09-16 / **対象**: 作業ツリーの未コミット差分 (tasks 6.1・6.2 の試作: ios/Sources/KsCollectionView の KsSectionID / KsSectionChunking / KsCollectionViewController、ios/Tests のヘルパとテスト、samples/ios の PerformanceVerificationView)
---
# レビュー結果: performance-criteria-review（グループ 6.1・6.2）

**判定: APPROVED**

## サマリー

Critical / Major / Minor / Suggestion はすべて 0 件です。

指定範囲では、固定件数による snapshot 分割、内部セクション識別、既存操作経路の維持、Sample の全体順による通過件数記録が整合しています。過去に問題となった位置変更時の全件再構成も再導入されていません。

この承認は tasks 6.1・6.2 の試作コードに限ります。6.3 の基準実機計測やグループ 7 の本実装完了を意味しません。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` — always
- `kasane/handbook/cross/sample-parity.md` — Sample 変更
- `kasane/handbook/cross/test-execution.md` — 提示されたテスト結果
- `kasane/handbook/cross/scroll-performance-gate.md` — 大量件数・性能変更
- `kasane/handbook/ios/performance-verification.md` — snapshot／レイアウト経路
- `swift-ui-impl-skill` の性能・Swift 言語・コード衛生観点
- accepted: ios/ADR-0001、0003、0004、0006、0008
- proposed: ios/ADR-0009 は所見との整合確認に使用

## 指摘事項

なし。

確認した主な点:

- `KsSectionID` が塊の順番を安定した section identity として表現している。
- `KsSectionChunking` が固定列数・向き別列数・adaptive の列数候補から塊サイズを算出し、空配列でも section を一つ生成する。
- `KsCollectionViewController` が識別子の全体順を保ったまま snapshot を複数 section に分割している。
- tap、long press、scroll、prefetch は引き続き項目 ID から解決され、section-local な item 番号へ依存していない。
- テスト側の固定 `section: 0` 前提は全体順変換へ置換され、複数の塊をまたぐ逆写像と一意性が検証されている。
- `PerformanceVerificationView` は先行 section の件数を加算し、通過項目を全体順で記録している。
- 残っている境界の上線、余白、header/footer の重複、および adaptive の再構成・アンカー処理は、指定どおりグループ 7 の意図的な未実装として指摘対象外とした。
- 依頼に記載されたテスト 181 件・失敗 0、Sample build 成功、lint 違反 0を結果として採用し、ビルド・テストは再実行していない。
- `git diff --check HEAD` に差分エラーはなかった。

## アクションプラン

修正要求はありません。次のゲートは tasks 6.3 の基準実機による段階1計測です。


## 突き合わせ結果 (2026-09-16)

ホスト側 `review-007.md` (CHANGES_REQUESTED: Major 1 / Minor 3 / Suggestion 2) との突き合わせ。相方は APPROVED・指摘 0 件。

| 指摘 (ホスト側) | 相方 | 採否 |
|---|---|---|
| Major: 塊の件数が変わる更新で同値配列の可視セル再構成 (ios/ADR-0006) が落ちる | 言及なし | ホスト側のみ。修正サイクルへ (相方の見逃し) |
| Minor: 塊の構造を固定するテストが list 1 通り | 言及なし | ホスト側のみ。修正サイクルへ |
| Minor: Sample の通し番号変換がテスト非対象 | 言及なし | ホスト側のみ。修正サイクルへ |
| Minor: spec の Requirement に lcm の縮退規則が無い | 言及なし | 合意済みの差 (design Decision 10 / ios/ADR-0009) として deviation.md に記録 |
| Suggestion 2 件 | 言及なし | 裁量で処理 |

確定 0 / 採用 (相方のみ) 0 / 降格 0 / 未解決 0。矛盾なし。
