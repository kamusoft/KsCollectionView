# 大量件数 (iOS) のメモリ自動往復 — 2026-09-15

tasks 4.6 (iOS 分)。計測スキーム (Release) のメモリ自動往復ドライバを Simulator で独立に 2 回実行した。

## 環境

| 項目 | 値 |
|---|---|
| 機体 | iPhone 17 Pro Max Simulator (Mac mini) |
| 構成 | Release (計測スキーム `KsCollectionViewSamplesPerformance` の TestAction) |
| fixture | Sample「大量件数」10,000 件、計測専用 launch 経路 (`--verify-performance`) |
| 駆動 | `PerformanceDriverUITests.test大量件数を全件通過で2往復してメモリを表示する` (人の操作なし) |

## 結果

| 実行 | 結果 | 所要 | 通過 |
|---|---|---|---|
| 1 回目 | passed | 80.1 秒 | 往復 1・2 とも 10,000 / 10,000 |
| 2 回目 | passed | 77.4 秒 | 往復 1・2 とも 10,000 / 10,000 |

## 限界 (未判定)

- ドライバは **2 往復固定**で、Scenario「往復後もメモリが定常化する」が求める「連続 2 往復の増分が 2% 以内になるまで重ねる (上限 10 往復)」の反復と定常判定を持たない (ios-engine-foundation 期の実装のまま。本 change は「維持」としたが、Scenario の MODIFIED に追随していない)
- 往復ごとの `phys_footprint` は画面のラベル (`performance.memory.first` / `second`) に出るが、テストは「bytes で終わる」ことしか検査せず値をログに残さない。そのため本証跡に数値が無い
- 上記 2 点により、Scenario の THEN「定常化に達し」は**未判定**。通過件数 (10,000 / 10,000) だけが確認できている
- 対処 (提案改訂に含める): ドライバを定常判定つきの反復に改め、往復ごとの footprint をテストログ (`KS` 接頭の print) に出す
