# Exploration: sample-comment-policy-cleanup

## 課題 / 動機

Android Sample のコードに、利用者から見える doc コメントの中へ決定記録 (ADR) の参照を書いている箇所が 8 件残っている。ソースコメント規約 (`kasane/handbook/cross/comment-policy.md`) は、設計根拠をこうした公開コメントではなく非公開の実装側コメントへ移すことを求めており、検査 (`scripts/comment-policy-lint.py --advisory`) は「要確認」として報告する (禁止ではないので commit / push は止まらない)。

`image-loading` の実装フェーズ (依存追加の便) で本務と無関係に発見した既存債務。同じ change に同梱するには箇所が広い (7 ファイル) ため、オーナー判断で別 change として積んだ (2026-09-07)。

**分布が偏っている点が本題の入口**: リポジトリ全体 152 ファイルの検査で、要確認 8 件は**すべて `samples/android/` に集中**している。iOS Sample もライブラリ本体も 0 件。

| ファイル | 件数 |
|---|---|
| `samples/android/app/src/main/kotlin/.../DemoData.kt` | 1 |
| `samples/android/app/src/main/kotlin/.../LargeDataDemoScreen.kt` | 1 |
| `samples/android/app/src/main/kotlin/.../SampleScreen.kt` | 1 |
| `samples/android/app/src/main/kotlin/.../SampleTheme.kt` | 1 |
| `samples/android/app/src/measurement/kotlin/.../MeasurementDestinations.kt` | 2 |
| `samples/android/app/src/test/kotlin/.../SampleScreenParityTest.kt` | 1 |
| `samples/android/benchmark/src/main/kotlin/.../LargeDataScrollBenchmark.kt` | 1 |

参照されている ADR は `cross/ADR-0004` (Sample のプラットフォーム間一致) と `android/ADR-0001` (ラッパーの薄さ) の 2 本。

## 検討した選択肢 (却下案と理由を含む)

(未探索)

## 決定事項

(未探索)

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

(なし)

## 未決の論点

**未探索 (簡易起票)** — 深掘りはこのメモを出発点に通常の探索で行う。現時点で見えている疑問:

- Sample は利用者に読ませる教材でもある。「なぜこの構成なのか」を doc コメントで示すことに学習上の価値があるとすれば、規約をそのまま当てて参照を消すのが正しいのか。参照先を ADR 番号ではない言葉 (「iOS Sample と同じ値を置く」等) に言い換えるだけで足りるのか
- iOS Sample が 0 件なのは規約に適合させた結果なのか、単に根拠を書く場所の習慣が違っただけなのか。後者なら、揃えるべき向きは Android → iOS とは限らない
- 規約側の見直し (Sample のような教材コードを要確認の対象から外す) も選択肢になりうる。その場合は `handbook/cross/comment-policy.md` の改訂が成果物になる

## UI 素材 (ui/references/ の一覧と注釈)

(なし)

## 変更級の推奨: 未判定

コメントの書き換えだけで収まるなら S 級。規約側の見直し (handbook の改訂) に及ぶなら M 級。どちらになるかは上の論点次第。
