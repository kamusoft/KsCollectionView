# develop への取り込みと検証 CI (tasks 10.1) — 1 回目

日付: 2026-10-15 / commit: 119662f (実装の commit。手元の develop にあった未 push の 9 つの commit と一緒に push した。`8a0f7df..119662f`) / run: https://github.com/kamusoft/KsCollectionView/actions/runs/38711686655

| ジョブ | 試行 1 | 試行 2 (失敗したジョブだけ再実行) |
|---|---|---|
| lint | 成功 (30 秒。スクリプトのテスト 728 件・失敗 0・スキップ 4) | (再実行の対象外) |
| ios / verify | 成功 (2 分 8 秒) | (再実行の対象外) |
| android / verify | 失敗 (本体 512 件中 1 件。Sample は BUILD SUCCESSFUL) | 失敗 (同じテストの同じ行) |
| consumer-ios / consumer-android | 飛ばした (main 宛ての Pull Request のときだけ走る) | 同じ |

落ちたテスト: `KsImageCacheContractTest > failedMemoryPrefetchLeavesInFlight` の `KsImageCacheContractTest.kt:823` (`assertEquals(1, KsImageMemoryIndex.shared.fetchesInFlightCount)`。未対応の形式の URL の先読みを要求した直後に、取得中が 1 件であることを確かめる行)。

- この commit が Android で変えたのは `android/kscollectionview/build.gradle.kts` の公開の設定 (POM の scm の tag と、Maven Central へ送るタスクを止める条件) だけで、テストの設定・依存は変えていない
- 同じコードで、手元の `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` は 512 件・失敗 0 (evidence/local-tests-001.md)
- 前回の develop への push (8a0f7df、2026-10-09) の検証 CI では、android / verify は成功していた
- テストのファイルは、その間に変わっていない
- 原因は調べていない (ランナーの上でだけ、要求の直後に失敗がもう返っている見込みだが、確かめていない)

## 2 回目 (別の change で Android のテストを直した後)

日付: 2026-10-15 / commit: 105ec13 (変更 `android-prefetch-failure-test-on-ci` のテストの直し。製品のコードは変えていない。`develop` に早送りで取り込み、`119662f..105ec13` を push) / run: https://github.com/kamusoft/KsCollectionView/actions/runs/38718155347

| ジョブ | 結果 |
|---|---|
| lint | 成功 (31 秒。スクリプトのテスト 728 件・失敗 0・スキップ 4) |
| ios / verify | 成功 (2 分 29 秒) |
| android / verify | 成功 (5 分 2 秒。本体と Sample とも BUILD SUCCESSFUL) |
| consumer-ios / consumer-android | 飛ばした (main 宛ての Pull Request のときだけ走る) |

tasks 10.1 は、この run の成功で満たした。
