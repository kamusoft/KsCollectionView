# Exploration: test-suite-speedup-and-pruning

## 課題 / 動機

テストの実行に時間がかかりすぎて、実用に耐えない (オーナーの指摘、2026-10-03)。テストの高速化と、無駄なテストの整理を行いたい。

`sample-group-header-spacing-color` (S 級、Sample の色 1 つの変更) の独立レビューで起きたこと:

- レビュアーが iOS Sample の UI テストを全件回し始め、28 分を超えても終わらなかった。44 件のうち 39 件まで進んだ時点で、オーナーの指示で切り上げた (残りは `ReorderDemoUITests` の 5 件)
- 変更に関係する UI テスト (見出しの帯の色や画素の色を見るテスト) は 1 件も無かった

過去にも同じ種類の痛みが記録されている:

- `drag-reorder` の 4 周目のレビューに約 2 時間 24 分かかった (`kasane/lessons/inbox/scope-test-reruns-per-review-cycle.md`)

この探索で分かっている規模 (2026-10-03 時点):

| 系統 | 件数 | 所要 |
|---|---|---|
| iOS 本体 (`ios/`) | 530 | 未計測 |
| iOS Sample の UI テスト (`samples/ios/KsCollectionViewSamplesUITests/`) | 44 | 39 件で 28 分超 |
| Android 本体 (`android/`) | 474 | 未計測 (ビルドとあわせて約 30 秒の実行例あり) |
| Android Sample (`samples/android/`) | 163 | 未計測 |

オーナーの依頼で簡易起票した。

## 検討した選択肢 (却下案と理由を含む)

## 決定事項

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

## 未決の論点

- 未探索 (簡易起票)
- どの系統・どのテストが時間を使っているか (系統ごと・テストごとの所要は未計測。iOS Sample の UI テストが最も重い見込みだが、裏付けは上の 1 例だけ)
- 「無駄なテスト」の基準 (重複して同じことを確かめているテスト・本番の経路を通らないテスト・UI テストでなくても確かめられるものなど、何を整理の対象にするか)
- 高速化の手段 (UI テストの起動や待ち時間の短縮・並列実行・ユニットテストへの置き換え・変更に応じて回す範囲を絞る仕組みなど)
- テスト実行規約 (`kasane/handbook/cross/test-execution.md`) の「全体を回す」完了判定との関係。回す範囲を絞るなら規約の改訂が要るか
- レビュー・検証のたびに全系統を流し直す運用の側の見直し (教訓 `scope-test-reruns-per-review-cycle`・`bound-test-scope-in-review-package-for-small-changes` との関係)

## UI 素材 (ui/references/ の一覧と注釈)

## 変更級の推奨: S / M / L (理由)

未判定 (計測して対象が決まってから判定する。テスト実行規約の改訂に及ぶなら M 以上の見込み)
