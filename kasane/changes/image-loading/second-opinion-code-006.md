# セカンドオピニオン: image-loading (code-006)
**相方**: codex / **label**: so-code-image-loading-006 / **日付**: 2026-09-08 / **対象**: 未コミットの作業ツリー差分 (レビュー 5 周目の指摘 7 件の修正 + 計測足場の全体: samples/ios・samples/android の計数機構と画面の印、ios/Tests の KsImageAccessibilityTests、benchmark の生存確認)
---
# レビュー結果: image-loading（006 回目）

**日付**: 2026-09-08  
**指摘件数**: Critical 0 / Major 1 / Minor 0 / Suggestion 0

## サマリー

前回の確定指摘 7 件と、降格後に同梱された source-set 整理は、いずれも個別には解消しています。アクセシビリティテストも提示された Simulator 2 版で成功しており、修正による製品コードの退行は見つかりませんでした。

ただし、計数機構がプロセス開始後の累計しか持たないため、tasks 7.4 の「戻ってきたとき」を初回表示から分離できません。このままでは再表示契約の合否を正しく判定できないため、差し戻します。

## 前回指摘の再確認

| 前回項目 | 結果 |
|---|---|
| iOS アクセシビリティ木の空振り | 解消。automation を明示的に有効化し、0 件を期待するテストにも実体化プローブを追加 |
| Android の計数が debug 常時有効 | 解消。Intent extra による実行時 opt-in となり、通常起動では本体既定表示を通る |
| ログ取りこぼしが偽の合格になる | 取りこぼし検出自体は解消。画面上の `lines` とログ件数・連番を突き合わせられる |
| benchmark 生存確認の計測影響 | 解消。未検証であることが `deviation.md` に明記された |
| source-set コメントの不足 | 解消 |
| iOS 計数分類のテスト不足 | 解消。実際の画像グリッドを使う UI テストが追加された |
| Compose テストの `Thread.sleep` | 解消。`waitUntil` と実測値付きタイムアウトへ変更された |
| debug 専用テストの配置 | 解消。`src/testDebug` へ移動された |

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`
- `kasane/handbook/cross/sample-parity.md`
- `kasane/handbook/cross/test-execution.md`
- `kasane/handbook/cross/runtime-behavior-verification.md`
- `kasane/handbook/ios/performance-verification.md`
- `kasane/handbook/android/performance-verification.md`
- `core/ADR-0002`、`core/ADR-0008`、`cross/ADR-0004`、`android/ADR-0001`
- SwiftUI / Kotlin / Jetpack Compose のレビュー観点

`deviation.md` 記録済みの差分は合意済みとして違反扱いしていません。依頼どおりビルド・テストは再実行せず、提示された実行結果を前提とした静的レビューです。

## 指摘事項

### [🟠 Major] 累計値では「初回表示」と「戻ってきたとき」を分離できない

**該当箇所**:

- `samples/ios/KsCollectionViewSamples/ImageLoadingSlotCounter.swift:18`
- `samples/android/app/src/counterEnabled/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotCounter.kt:30`
- `kasane/changes/image-loading/evidence/image-behavior-observation.md:111`
- `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/MainActivity.kt:24`

**問題点**:

両カウンタはプロセス開始後の `sized` / `unsized` の累計を保持し、「読み込み中を経由していない」の判定を `sized == 0` と定義しています。一方、tasks 7.4 の手順は、最初に画像を表示してから画面外へ送り、同じセルへ戻るものです。

cold・ディスク到達点の現在の土俵では、最初の表示時に非同期デコードを待つため対象セルの `sized` は通常 1 以上になります。その後、正しくメモリから即時再表示されて新しい読み込み中が一度も発生しなくても、累計値は 1 以上のままです。したがって現在の判定規則では、正常な再表示も不合格になります。

Android には `reset()` がありますが、テストからしか呼ばれておらず、初回表示完了後に計測ドライバが開始点を切る経路はありません。iOS には reset／baseline 自体がありません。ログと画面の `lines` を照合する修正はログ欠落を検出できますが、「どの局面で増えたか」は分離できません。

**推奨修正**:

- 初回表示完了後、画面外へ送る直前に観測セッションを開始できるよう、両プラットフォームへ同型の reset または baseline 機構を設ける。
- 判定を累計の `sized == 0` ではなく、対象セルごとの `戻った後 − 送り出す前 == 0` とする。
- 画面の印とログに session ID または baseline 後の差分を出し、以前の表示や以前の Activity の値が混ざらないようにする。
- `evidence/image-behavior-observation.md` の再計測手順には、対象 ID の前後値と `Δsized == 0` を残す。

## アクションプラン

1. 初回表示後に開始点を切れる reset／baseline を両プラットフォームへ追加する。
2. 画面上の印とログを同一セッションの差分として照合できるようにする。
3. tasks 7.4 を対象 ID の `Δsized == 0` で再計測する。
4. 修正後、今回と同じ静的再レビューを行う。

**判定: CHANGES_REQUESTED**



## 突き合わせ結果 (ホスト側 review-006.md との照合、2026-09-08)

| 相方の指摘 | ホスト側 | 採否 | 根拠 |
|---|---|---|---|
| Major: 計数が累計しか持たず、判定規則「対象要素の `sized == 0`」では初回表示で読み込み中を経由したセルが正しく即時再表示されても不合格になる (初回表示と戻りを分離できない) | 指摘なし (APPROVED) | **採用 (Major)** | 該当箇所特定済み。tasks 7.4 の土俵 (cold・ディスク到達点) では初回表示の `sized` が 1 以上になるのが通常で、記録された判定規則のままでは証跡の結論が正しく出ない。ログの時刻から差分を読むことは可能だが、画面の印 (累計) との突き合わせがこの局面で成立しない。ホスト側の見逃しとして扱う |

ホスト側のみの Suggestion 3 件 (テストの `waitForIdle()` と教訓の食い違い / SPI が Simulator 個体全体の設定を書き換える点の記録 / Android 計測画面の入れ子 1 段増の記録) は review-006.md のとおり。1 件目はコード側で解消、2・3 件目は deviation に記録する。

集計: 確定 0 / 採用 1 / 降格 0 / 未解決 0。
