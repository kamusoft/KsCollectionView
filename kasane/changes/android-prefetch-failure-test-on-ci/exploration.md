# Exploration: android-prefetch-failure-test-on-ci

## 課題 / 動機

検証 CI の `android / verify` で、Android 本体のテスト `KsImageCacheContractTest > failedMemoryPrefetchLeavesInFlight` が、ランナーの上でだけ落ちる。2026-10-15 に `develop` へ 119662f (変更 `release-pipeline` の実装) を push したときの run (https://github.com/kamusoft/KsCollectionView/actions/runs/38711686655) で、試行 1 と、失敗したジョブだけを再実行した試行 2 の両方で、同じ行 (`android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsImageCacheContractTest.kt:823`) の `AssertionError` で落ちた。512 件中 1 件。

落ちた行は、未対応の形式の URL (`ks-unsupported://...`) の先読みを、メモリへの先読みとして要求した直後に、`assertEquals(1, KsImageMemoryIndex.shared.fetchesInFlightCount)` で「取得中が 1 件」を確かめる行である。テストの意図は、その後の `awaitCondition` で「失敗の時点で取得中から外れる」を確かめること。

分かっていること:

- 同じコードで、手元の `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` は 512 件・失敗 0 (2026-10-15。`kasane/changes/release-pipeline/evidence/local-tests-001.md`)
- 119662f が Android で変えたのは `android/kscollectionview/build.gradle.kts` の公開の設定 (POM の scm の tag と、Maven Central へ送るタスクを止める条件) だけで、テストの設定・依存は変えていない
- 前回の `develop` への push (8a0f7df、2026-10-09) の検証 CI では `android / verify` は成功していた。テストのファイルはその間に変わっていない (最後の変更は `prefetch-display-size` の実装)
- 経緯の記録: `kasane/changes/release-pipeline/evidence/ci-develop-001.md`

発見の文脈: 変更 `release-pipeline` の tasks 10.1 (実装を `develop` に入れ、検証 CI が緑になることを確かめる) で見つけた。本務とは別の能力 (画像の読み込み) なので、オーナーの判断 (2026-10-15) で別の change として起票した。`main` 宛ての Pull Request では `android / verify` が必須の検査なので、これが直るまで `release-pipeline` の tasks 10.2 以降 (準備の Pull Request・初回のリリース) に進めない。

## 検討した選択肢 (却下案と理由を含む)

(未探索)

## 決定事項

(未探索)

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

(なし)

## 未決の論点

**未探索 (簡易起票)** — 深掘りはこのメモを出発点に通常の探索で行う。現時点で見えている疑問:

- ランナーの上では、未対応の形式の失敗が要求の直後 (確かめる前) にもう返っていて、取得中が 0 件になっているのか。それとも前のテストの取得中が残っていて 2 件以上なのか (`AssertionError` の期待値と実際の値はログに出ていない)
- 9 日の成功から何が変わったのか (ランナーのイメージ・JDK・依存の解決の結果)。手元でランナーと同じ条件 (JDK の版・並列の度合い) に寄せると再現するか
- 直すのはテストの確かめ方か (要求の直後の 1 件を確かめない・失敗を遅らせる取得層に差し替える)、それとも製品の側の数え方か (失敗が同期的に返ると数えずに終わる経路があるか)

## UI 素材 (ui/references/ の一覧と注釈)

(なし)

## 変更級の推奨: S / M / L (理由)

暫定 S (テストの確かめ方だけの直しで済むなら S。製品の側の数え方に問題があれば見直す)
