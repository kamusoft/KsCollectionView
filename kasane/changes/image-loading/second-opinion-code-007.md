# セカンドオピニオン: image-loading (code-007)
**相方**: codex / **label**: so-code-image-loading-007 / **日付**: 2026-09-08 / **対象**: 未コミットの作業ツリー差分 (レビュー 6 周目で採用した Major = 計数の基準点機構と判定規則 Δsized == 0、Suggestion の waitForIdle 対応、およびそれ以前の計測足場)
---
# レビュー結果: image-loading（007 回目）

**日付**: 2026-09-08  
**判定**: APPROVED  
**指摘件数**: Critical 0 / Major 0 / Minor 3 / Suggestion 0

## サマリー

前回採用した Major は解消しています。iOS・Android とも基準点と session を持ち、画面の印から区間を開始し、判定を累計値ではなく `Δsized == 0` で行える構造になっています。

前回の Suggestion 3 件も、`waitForIdle()` の追加と deviation への記録によって解消しています。新たな製品コード上の Critical / Major はありません。残るのはテストの検証不足、証跡の古い記述、コメント規約違反の Minor 3 件です。

提示済みのテスト・ビルド結果を前提とした静的レビューであり、再実行はしていません。`deviation.md` の記録済み差分は違反として扱っていません。

## 前回指摘の解消確認

| 前回指摘 | 判定 | 根拠 |
|---|---|---|
| Major: 初回表示と再表示を累計値から分離できない | **解消** | iOS は `baseline = tallies`、Android は現在値を baseline に保存して session を進める。印から開始でき、証跡手順も `Δsized == 0` に更新済み |
| Suggestion: Robolectric の待機に `waitForIdle()` がない | **解消** | `samples/android/app/src/testDebug/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotCounterTest.kt:203` の待機ループ内で `waitForIdle()` を実行し、実時間 deadline・実測値付き失敗も維持 |
| Suggestion: Simulator 全体の automation 設定を書き換える制約が未記録 | **解消** | `kasane/changes/image-loading/deviation.md:75` に並走禁止と異常終了時の残留リスクを記録 |
| Suggestion: Android 計測画面の `Column` 追加が未記録 | **解消** | `kasane/changes/image-loading/deviation.md:76` に土俵変更として記録 |

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`
- `kasane/handbook/cross/sample-parity.md`
- `kasane/handbook/cross/test-execution.md`
- `kasane/handbook/cross/runtime-behavior-verification.md`
- `kasane/handbook/cross/public-identifiers.md`
- `kasane/handbook/ios/performance-verification.md`
- `kasane/handbook/android/performance-verification.md`
- `kotlin-impl-skill`
- `core/ADR-0002`、`cross/ADR-0004`、`android/ADR-0001`

`core/ADR-0012` は proposed のため、判定根拠にはしていません。

## 指摘事項

### [🟡 Minor] iOS の session テストが baseline の更新を検証していない

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/ImageLoadingSlotUITests.swift:42`

**問題点**: テスト名とコメントは「基準点から差分が数え直される」ことを検証するとしていますが、実際の正規表現が確認するのは `session` が増えたことと `total` が非ゼロであることだけです。`beginSession()` から `baseline = tallies` を削除して `session += 1` だけにしても、このテストは成功します。今回の Major の核心である「初回表示分を差分から除外する」回帰を iOS 側では固定できていません。

**推奨修正**: 初回表示が収束した後に印を叩き、更新後の印が `session > 0` に加えて `sized=0 unsized=0 lines=0` を示すことを確認してください。必要なら counter の純粋ロジックを単体テスト可能な形へ分け、基準点前の累計が差分ゼロになることを直接固定してください。

### [🟡 Minor] 証跡に「計数手段がない」という解消済み記述が残っている

**該当箇所**: `kasane/changes/image-loading/evidence/image-behavior-observation.md:132`

**問題点**: 現在は両プラットフォームに計数スロットと基準点機構がありますが、この節では「いまの Sample に手立てが無い」「追加は行っていない」と記述されています。また、現在の手順では直接計数は手順 4 ですが、同節は「手順 3」と参照しています。未完了の tasks 7.4 を実施する人が、現在の足場の有無と正しい手順を誤認します。

**推奨修正**: この節を「当時不足していたもの（現在は解消済み）」と明示し、現行実装への参照と手順 4 への訂正を加えてください。

### [🟡 Minor] ソースコメントが lessons のローカル識別子を参照している

**該当箇所**: `samples/android/app/src/testDebug/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotCounterTest.kt:197`

**問題点**: `(lessons: wait-for-idle-in-robolectric-compose-tests)` は、`comment-policy.md` が許容する ADR ID・URL・恒常規格・コード識別子のいずれでもありません。作業文書に依存するローカル識別子であり、標準 lint の検出範囲外でも規約本文上は違反です。直前の文章だけで理由は自己完結しています。

**推奨修正**: parenthetical の lessons 参照だけを削除し、`waitForIdle()` が必要な理由の現在形の説明を残してください。

## アクションプラン

1. iOS UI テストで baseline 後の差分ゼロを実際に検証する。
2. 証跡の解消済み節と手順番号を更新する。
3. Kotlin テストコメントから lessons のローカル識別子を除く。

**最終判定: APPROVED**

Critical / Major はなく、現在の baseline/session 実装そのものは前回採用 Major を解消しています。上記 Minor は、tasks 7.4 の実測前に直すことを推奨します。


