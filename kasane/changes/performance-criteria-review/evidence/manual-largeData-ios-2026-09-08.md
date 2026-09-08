# 大量件数 (iOS) の手動フリック計測 — 2026-09-08

探索中 (論点 6) に、cross/ADR-0006 (proposed) の手順を初めて適用した計測。目的は「自動駆動で出た 108〜136 ms/s が足場由来かエンジン由来か」の切り分け。

## 環境

| 項目 | 値 |
|---|---|
| 機種 / OS | iPhone 11 (基準機) / iOS 18.7.8 |
| 構成 | Release、削除してから入れ直し |
| fixture | Sample「大量件数」(10,000 件・2 列・固定高と 7 件ごとの長文の混在)。起動引数 `--screen 大量件数` で直接開く |
| 駆動 | オーナーの手動フリック (自動化なし)。記録 60 秒 |
| 記録 | Instruments Animation Hitches テンプレートをプロセス名指定で接続 (`xctrace record --template 'Animation Hitches' --attach <プロセス名>`)。pid 指定は「見つからない」で失敗し、名前指定なら接続できた |
| 熱状態 | 全区間 Nominal |

## オーナーの体感 (合否の主語)

- 初めて通る部分は少し重い。一度スクロール済みのところはスムーズ
- スクロールを連続すると重くなる。少し止めてからやるとスムーズに戻る
- 操作のたびにムラがある

## 数値 (証跡。合否ではない)

| 指標 | 値 |
|---|---|
| hitch 件数 (60 秒) | 554 (High 368 / Moderate 75 / Low 111) |
| hitch time ratio | 638 ms/s (60 秒窓)。参考: Apple の目安は 5 ms/s 以下 Good / 10 以上 Critical |
| hitch の長さ | 中央値 66.7 ms、p90 133.3 ms、最長 233.3 ms |
| hitch の種類 | Commit to Render latency 431、Expensive Commit(s) 101、Pre-Commit(s) latency 20 |
| 描画 (surface swaps / 秒) | 操作中の多くの秒で 7〜15 回。40〜57 回の秒もあり大きく揺れる |
| 主スレッド稼働 | 60 秒中 44.9 秒 (75%)。ほぼ P コア |

10 秒ごとの hitch 合計: 689 / 877 / 764 / 331 / 749 / 383 ms/s。単調に悪化はしておらず、操作の有無と対応する。

## 主スレッドの帰属 (time profile、inclusive、主スレッド標本比)

| 経路 | 比率 |
|---|---|
| `CA::Transaction::commit` → `UICollectionView layoutSubviews` → `_updateVisibleCellsNow:` | 80% |
| └ `UICollectionViewCompositionalLayout _preferredAttributesResolveWithInvalidatedPreferredAttributes:` → **`_UICollectionLayoutSectionEstimatedSolver _solveWithParameters:`** | **55%** |
| └ うち `_UICollectionLayoutAuxillaryOffsets` (offsets の再構築) | 16% |
| セルの生成 `_createPreparedCellForItemAtIndexPath:` | 16% |
| うち hosting の計測 `ViewRendererHost.sizeThatFits` (`KsHostingCell.preferredLayoutAttributesFitting`) | 7.5% |
| データソースのセル構成 (`configureDataSource` のクロージャ) | 5% |
| self 上位: `objc_msgSend` 12%、malloc/free 系 約 8% | — |

秒ごとの相関: 主スレッドが 90% 以上稼働している秒は solver が主スレッドの 55〜67% を占め、描画は 7〜15 回/秒。solver が 0% の秒 (入力なし・既に通った範囲を惰性で流れる区間) は主スレッド 32〜38%、描画 55〜57 回/秒で滑らか。

## 判定

- **自動駆動の足場は主因ではない。** 自動化なしでも hitch time ratio は 3 桁で、体感も不合格 (「少し重い」「連続で重くなる」「ムラがある」)。論点 6 の分岐は「体感 NG = エンジンの土台の問題」
- **主因は compositional layout の estimated 高さの solver。** 新しく可視になったセルが preferred size を返すたびに、1 セクション 10,000 件の solver が offsets を再構築する。既に解決済みの範囲では solver が走らないため「一度通ったところはスムーズ」、連続フリックで未解決のセルが供給され続けると solver が主スレッドを飽和させ、止めると溜まりが捌けて戻る
- hosting (SwiftUI) のセル計測は 7.5% で、`UIHostingConfiguration` 方式そのものは主因ではない
- 過去の自動駆動の値 (108〜136 ms/s) は、この手順の値 (638 ms/s、窓と操作が違う) と比較しない

## 限界

- 手動操作なので操作量は記録間で揃わない。数値は合否ではなく説明と傾向の材料 (cross/ADR-0006)
- 記録は 1 回。再現性は実装フェーズの計測で確認する
- 生の trace は退避先 (スクラッチ) にのみ置き、evidence/ には集計値だけを載せる
