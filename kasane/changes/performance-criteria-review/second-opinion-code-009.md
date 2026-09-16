# セカンドオピニオン: performance-criteria-review (code-009)
**相方**: codex / **label**: so-code9-performance-criteria-review / **日付**: 2026-09-16 / **対象**: 作業ツリーの未コミット差分 (tasks グループ 6〜8: ios/Sources/KsCollectionView、ios/Tests、samples/ios の Sample と UI テスト、handbook/ios/performance-verification.md)
---
# レビュー結果: performance-criteria-review

**判定: CHANGES_REQUESTED**

静的レビューのみ実施し、ファイルは変更していません。合意済みの `deviation.md` は違反として扱っていません。

## サマリー

内部セクション分割、境界表現、スクロール命令、adaptive 再分割、倍率変更時の標本破棄は概ね要求へ対応しています。

ただし、全件実行で既知のテスト失敗が残っているため承認できません。ほかに規約文書との不整合と、UI テストの非同期待機不足があります。

**件数:** Critical 0 / Major 1 / Minor 2 / Suggestion 0

## 照合した規約

- ソースコメント規約（always）
- Sample のプラットフォーム間一致
- テスト実行規約
- 実行時挙動の検証規約
- スクロール性能の体感ゲート
- iOS 性能検証の手順
- `swift-ui-impl-skill`
- ios/ADR-0003、ios/ADR-0006（accepted）
- ios/ADR-0009（proposed。判定根拠には不使用）

## 指摘事項

### [🟠 Major] 同時生存セルのテストが全件実行で不安定に失敗する

**該当箇所:** `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:1347`、`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:1354`、`kasane/changes/performance-criteria-review/tasks.md:48`

**問題点:** 全件実行で最大 167 件、上限 156 件となる失敗が実際に発生しています。再実行で成功しても、Kasane の判定基準およびテスト実行規約上、既知の不安定な failure を残した状態では完了にできません。

走査ヘルパは 8 段階ごとの固定 1ms 待機だけで解放機会を作っており、実行負荷によって弱参照セルの解放タイミングが変わります。そのため、実際の保持退行なのか、収束前を測るテスト設計の問題なのかも未確定です。

**推奨修正:** 全件実行条件で再現を集め、次を切り分けてください。

- セル／ホスティングが実際に保持され続けるなら実装を修正する。
- UIKit の解放待ち不足なら、実時間 deadline と観測条件を持つ収束待機へ変更してから最大値を測る。
- 閾値を単に引き上げず、テストが「走査中の瞬間最大」と「走査後に収束した保持数」のどちらを保証するのか明確にする。

修正後は、両 Simulator で絞り込みなしの全件実行を複数回通す必要があります。

### [🟡 Minor] 計測スキームの判定責務が handbook と食い違う

**該当箇所:** `samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift:3`、`samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift:137`、`kasane/handbook/cross/test-execution.md:53`

**問題点:** handbook とファイル冒頭は、計測ドライバを「アサーションを持たず、合否は Instruments 側で判定する」と定義しています。一方、今回のメモリドライバは全件通過、定常化、未判定をアサートし、明確に合否を持ちます。テスト件数の解釈や完了報告の規範が実装と一致していません。

**推奨修正:** handbook とファイルコメントを更新し、少なくとも次を区別してください。

- 画像読み込みの観測駆動は判定を持たない。
- メモリ往復ドライバは定常化を判定し、未判定を失敗にする。
- 計測スキームの成功件数には、判定を持つメモリテストが含まれる。

### [🟡 Minor] Debug 計数 UI テストが状態反映を待たずにラベルを読む

**該当箇所:** `samples/ios/KsCollectionViewSamplesUITests/LargeDataCountUITests.swift:53`、`samples/ios/KsCollectionViewSamplesUITests/LargeDataCountUITests.swift:57`、`samples/ios/KsCollectionViewSamplesUITests/LargeDataCountUITests.swift:67`

**問題点:** `read.tap()` / `reset.tap()` の直後に `tally.label` を同期的に読んでいます。SwiftUI の状態変更と accessibility tree の更新は非同期なので、実行負荷によって旧ラベルを読む可能性があります。これはテスト実行規約の「完了条件そのものを条件ベースで待つ」に反します。

**推奨修正:** 各操作後に実時間 deadline 付きでラベル更新を待ってください。例えば、reset 後は解析値が 0、read 後は解析値が 0 より大きいことを条件に待ち、期限超過時には最終ラベルを失敗メッセージへ含めます。

## アクションプラン

1. 同時生存セルの failure の原因を切り分け、全件実行を安定して成功させる。
2. 計測スキームの判定責務を handbook とコメントへ反映する。
3. Debug 計数 UI テストを条件ベース待機へ変更する。
4. 両 Simulator で 198 件の全件実行を複数回行い、失敗 0 を確認する。


## 突き合わせ結果 (2026-09-16)

ホスト側 `review-009.md` (CHANGES_REQUESTED: Major 2 / Minor 4 / Suggestion 3) との突き合わせ。

| 指摘 | ホスト | 相方 | 採否 |
|---|---|---|---|
| 同時生存セルのエンジンテストが全件実行で間欠失敗 (収束待ちの無い瞬間ピークの標本化) | Major | Major | **確定 (Major)**。見立ても一致 |
| Debug 計数の UI テストが tap 後に待たずに label を読む | Minor | Minor | **確定 (Minor)** |
| layout 値の変更で塊の件数が変わる経路にアニメーション抑止・遅延復元が掛からない | Major | 言及なし | ホスト側のみ。修正サイクルへ |
| 倍率テストが倍率の変化を通らず空振り | Minor | 言及なし | ホスト側のみ。修正サイクルへ |
| adaptive の組み直しが 1 実行機会遅れ、境界に不完全な行が 1 フレーム出る | Minor | 言及なし | ホスト側のみ。修正サイクルへ |
| 6.3 の証跡で体感と数値の食い違いに非接続の対照が無い | Minor | 言及なし | ホスト側のみ。9.1 (最終ビルド・同 fixture・同手順) で対照を兼ねる扱いにし、証跡の限界に明記 |
| 計測ドライバの判定責務が `cross/test-execution.md` とファイル冒頭の記述と食い違う | 言及なし | Minor | **採用** (該当箇所と実害が具体的。ホスト側の見逃し)。修正サイクルへ |

確定 2 / 採用 (相方のみ) 1 / 降格 0 / 未解決 0。
