# セカンドオピニオン: performance-criteria-review (code-002)
**相方**: codex / **label**: so-code-performance-criteria-review (turn 2) / **日付**: 2026-09-15 / **対象**: review-001 / second-opinion-code-001 の指摘修正後の作業ツリー (未コミット変更すべて)
---
# 再レビュー結果

**判定: CHANGES_REQUESTED**

前回 9 件は、8 件が解消、1 件が部分解消です。加えて Major を 1 件新規検出しました。提示されたテスト結果は受領済みとして扱い、ビルド・テストの再実行およびファイル書き込みは行っていません。

## 前回指摘 9 件の確認

1. **部分解消 — iOS の不一致カウンタが実際の再解決候補を過少計数する**

   **該当箇所**: `ios/Sources/KsCollectionView/KsHostingCell.swift:85`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:335`

   `preferredLayoutAttributesFitting` に渡された `original` と実測値を渡す修正、および現在の可変な推定値と比較しない回帰テストは確認できました。

   ただし `KsCollectionViewController.swift:339-341` では両方を量子化してから比較しています。生の高さが異なっていても同じピクセル格子へ丸められると「一致」と数えられるため、このカウンタはレイアウト再解決回数の「上界」になりません。詳細は後述の Major 指摘 1 です。

2. **解消 — Android の 3 試行が強制されない**

   **該当箇所**: `samples/android/benchmark/scripts/verify-fling-results.py:234`

   `frameCount.runs` がちょうど 3 件であることに加え、`repeatIterations` が存在する場合も 3 であることを検査しています。1・2・4 試行と繰り返し回数不一致のテストも `samples/android/benchmark/scripts/test_verify_fling_results.py:190` 以降に追加されています。

3. **解消 — 診断カウンタが通常の公開 API に追加されている**

   **該当箇所**: `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:1`、`ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:14`

   宣言全体が `#if DEBUG` に限定され、さらに `@_spi(KsMeasurement)` 経由でのみ参照可能になりました。Release 製品および通常の `import KsCollectionView` から見える利用者向け API には追加されません。

4. **解消 — iOS の破棄テストが 2,000 件を全件往復しない**

   **該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:1019`、`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:1037`、`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:1832`

   解放確認の前に `advanceRoundTrip` で末尾到達と先頭復帰の両方を確認し、走査不成立時には解放判定へ進まない構造になっています。

5. **解消 — iOS 基準機の代替に事前承認と非保証の記録が不要**

   **該当箇所**: `kasane/handbook/ios/performance-verification.md:32`

   代替前のオーナー承認と、代替機の性能にかかわらず「基準機の保証にならない」と証跡へ記載する規則が明記されています。

6. **解消 — 繰り返し前の平均値がピクセル格子へ再量子化されない**

   **該当箇所**: `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:60`、`ios/Tests/KsCollectionViewTests/KsEstimatedHeightTests.swift:84`

   平均を `sampledScale` で再量子化して返し、返却値が格子上にあることもテストされています。

7. **解消 — cross 規約の「数値の合格線なし」と Android 相対 10% 基準が矛盾する**

   **該当箇所**: `kasane/handbook/cross/scroll-performance-gate.md:19`

   絶対数値を置かない対象が「体感による滑らかさ」であり、Android の相対ゲートは目的・判定系統が異なることが明記されました。

8. **解消 — 検証スクリプトの使用例と実ファイル名が一致しない**

   **該当箇所**: `samples/android/benchmark/scripts/verify-fling-results.py:10`

   使用例が実ファイル名 `verify-fling-results.py` と一致しています。

9. **解消 — Android の過去証跡で OS 情報の欠落が無言になっている**

   **該当箇所**: `kasane/changes/performance-criteria-review/evidence/manual-imageGrid-android-2026-09-08.md:10`、`kasane/changes/performance-criteria-review/evidence/manual-largeData-android-2026-09-08.md:10`

   復元不能な値を推測せず「未記録」と明記し、比較不能条件および限界にも反映されています。

## 残存・新規指摘

### [🟠 Major] 量子化した高さの一致を「レイアウト再解決なし」とみなしている

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:339`

**問題点**: 実測高と original の生値が異なっていても、同じピクセル値へ量子化されれば一致として記録されます。量子化は推定値の標本を安定させる目的には適切ですが、UIKit に渡された attributes の差を消すものではありません。そのため、実際には再解決候補となるセルを一致として数え、不一致率 0.20 の受け入れ判定が偽陽性になる可能性があります。「再解決回数の上界」という `KsLayoutDiagnostics.swift:7` の説明とも一致しません。

**推奨修正**: カウンタでは少なくとも生の `size.height != original.height` を不一致として数え、量子化は `KsEstimatedHeight` の標本処理だけに限定してください。量子化後の一致を実際のレイアウト一致として扱うなら、セルから返す attributes 自体も同じ規則で量子化し、表示への影響をテストしてください。格子未満の差を使い、カウンタが過少計数しない回帰テストも必要です。

### [🟠 Major] iOS のメモリ計測ドライバが Debug 構成で実行される

**該当箇所**: `samples/ios/KsCollectionViewSamples.xcodeproj/xcshareddata/xcschemes/KsCollectionViewSamplesPerformance.xcscheme:26`

**問題点**: `TestAction` の `buildConfiguration` は `Debug` ですが、デルタスペックは計測スキームで Simulator に Release 構成を入れてメモリ自動往復を実行することを要求しています（`kasane/changes/performance-criteria-review/specs/samples/spec.md:45`）。`ProfileAction` や別途行った Release ビルドが成功していても、`PerformanceDriverUITests` が起動するアプリはこの TestAction の Debug 構成です。今後のメモリ証跡が要求された土俵と異なる構成で採取されます。

**推奨修正**: 性能スキームの `TestAction` を Release に変更するか、Release アプリを対象にドライバを実行する別スキーム／手順を明示的に用意してください。その構成で build-for-testing が成立することも確認してください。

## 件数

- Critical: 0
- Major: 2
- Minor: 0
- Suggestion: 0

したがって、現時点の判定は **CHANGES_REQUESTED** です。



## 突き合わせ結果 (review-002.md との照合、2026-09-15)

| # | 相方の指摘 | ホスト側 | 採否 | 重要度 |
|---|---|---|---|---|
| 1 | 量子化後の一致を再解決なしとみなし、カウンタが上界にならない | なし (前回 Major 1 は解消と判定) | **採用** (生値の不一致を数えれば上界の説明と整合し、コストも小さい) | Major |
| 2 | 計測スキームの TestAction が Debug で、spec「Release 構成を入れて」と不一致 | なし | **採用** (xcscheme 27 行目で確認。本 change 以前からの設定だが spec が Release を要求) | Major |

ホスト側のみ: Critical (2.4 のテストが Simulator 3/5 で決定的に失敗、不一致率 0.069 でも合計高さ基準が外れる)・Major (`MeasurementRoundTripCountingTest` の assert が順序を固定しない)・Minor (実物 JSON がフリング指標の容器を通っていない)・Suggestion。すべて採用。未解決 (矛盾) は無し。相方の前回 #1 を「部分解消」とした点はホストの「解消」と食い違うが、上表 #1 として採用するため実質一致。
