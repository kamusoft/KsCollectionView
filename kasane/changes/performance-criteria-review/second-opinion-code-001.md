# セカンドオピニオン: performance-criteria-review (code-001)
**相方**: codex / **label**: so-code-performance-criteria-review / **日付**: 2026-09-15 / **対象**: 作業ツリーの未コミット変更すべて (tasks グループ 1〜3 の成果物。iOS ライブラリ・iOS Sample・Android Sample / benchmark・handbook 3 本・evidence 4 本)
---
# レビュー結果: performance-criteria-review

**日付**: 2026-09-15  
**判定**: **CHANGES_REQUESTED**  
**指摘件数**: Critical 0 / Major 5 / Minor 4 / Suggestion 0

## サマリー

体感ゲートへの整理や計測自動化の方向は仕様に沿っていますが、合否判定に使う iOS 診断値と Android 検証スクリプトに偽陽性の経路があります。また、非公開とされている診断機能が Debug 構成の公開 API になっています。

提示されたビルド・テスト結果は成功として扱い、指示どおり再実行していません。`deviation.md` の記録済み乖離および未着手のグループ 4・5は指摘対象から除外しました。ファイルへの書き込みも行っていません。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`（always）
- `kasane/handbook/cross/sample-parity.md`
- `kasane/handbook/cross/scroll-performance-gate.md`
- `kasane/handbook/ios/performance-verification.md`
- `kasane/handbook/android/performance-verification.md`
- 関連する accepted ADR（iOS エンジン、Android LazyVerticalGrid、既定高さアニメーション、Sample parity）
- `cross/ADR-0006` は proposed のため、拘束力のある根拠には使用していません

## 指摘事項

### [🟠 Major] 不一致率がセルに渡された実際の推定高さを比較していない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:350`  
**問題点**: `recordMeasuredSize` は、自己サイズの結果を「その時点の可変な `estimatedHeight.value`」と比較しています。しかしレイアウト再解決の有無を決める比較相手は、そのセルの `preferredLayoutAttributesFitting` に渡された original attributes の高さです。複数セルが同じ section estimate から測定されている間にも `estimatedHeight` は更新されるため、現在値と original estimate が一致する保証はありません。

これにより、グループ 4.1 の主要判定値である不一致率 0.20 以下を過少・過大に数える可能性があります。現在のテストも同じカウンタを正としているため、この誤差を検出できません。

**推奨修正**: `preferredLayoutAttributesFitting` から original height と preferred height の両方をコールバックし、その2値を量子化して比較してください。推定用標本への追加は比較後に行い、レイアウト生成後に推定モデルが更新されたケースの回帰テストを追加してください。

### [🟠 Major] 1試行だけの結果でも「3試行の集計値」として合格できる

**該当箇所**: `samples/android/benchmark/scripts/verify-fling-results.py:194`  
**問題点**: `frame_counts_of` は `runs` が非空であることしか確認せず、試行数が3件かを検証していません。したがって、フレーム数90以上の結果が1件だけでも、P90/P99が10%以内なら合格になります。「未判定が緑になる」経路を塞ぐという本変更の中心目的に反します。

テストデータが常に3件を生成するため、不足・過剰試行のケースも検出されません。

**推奨修正**: 相対判定・画像グリッドとも `runs.count == 3` を必須にしてください。JSON の `repeatIterations` も利用できる場合は3であることを照合し、1・2・4試行の単体テストを追加してください。不一致は入力不正または未判定として非0終了にします。

### [🟠 Major] Debug限定の診断型がライブラリの公開APIになっている

**該当箇所**: `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:16`  
**問題点**: `KsLayoutDiagnostics` と読み取り・リセット操作が `public` です。`#if DEBUG` は Release に載らないだけで、Debug ライブラリの利用者には公開 API として見えます。構成によって存在が変わる公開面でもあり、proposal の「公開 API には変更なし」と一致しません。`deviation.md` にも公開面の変更として記録されていません。

**推奨修正**: 計測専用 product、非公開のログ／通知経路、または明示的な SPI など、通常の利用者 API に見えない境界へ移してください。公開を意図するなら、API変更として明示的に判断を取り直し、構成差を含む契約・APIテストを用意してください。

### [🟠 Major] コレクション破棄テストが仕様の全件往復条件を満たしていない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:994`  
**問題点**: Scenario は「2,000件を全件往復したコレクション」を前提にしていますが、テストは初期表示後に1画面分だけオフセットして破棄しています。再利用プールや多数のホスティングを通過した状態を作っておらず、`tasks.md:17` が完了済みなのは実態と一致しません。

**推奨修正**: 置換テストと同じ `advanceUntilVisible` を使い、末尾まで進んで先頭へ戻ったことを確認してから強参照を破棄してください。走査成立に失敗した場合は破棄検証へ進まないようにします。

### [🟠 Major] iOSだけ基準機の無承認代替を許している

**該当箇所**: `kasane/handbook/ios/performance-verification.md:34`  
**問題点**: iOS 規約は基準機を接続できなければそのまま代替を許し、「代替機が高速な場合」だけ非保証の記載を求めています。Android 側はオーナー承認と、代替結果が基準機の保証にならない旨を常に要求しています。端末差は単純な速度差だけではないため、iOS 側の文面では未承認の別端末結果を完了判定へ使えます。

**推奨修正**: Android と同様に、代替前のオーナー承認を必須とし、端末の速い／遅いにかかわらず「基準機の保証にはならない」と証跡へ記載させてください。

### [🟡 Minor] 繰り返し前の平均値がピクセル格子に載らない

**該当箇所**: `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:56`  
**問題点**: 個々の標本は量子化されていますが、その平均はピクセル格子外になり得ます。例えば scale 2 で 44.0 と44.5の平均は44.25です。design の「推定値として返すのも量子化後の値」と一致しません。

**推奨修正**: 現在の scale を保持して平均結果も再量子化し、格子の異なる2値から格子外の平均になるケースをテストしてください。

### [🟡 Minor] 数値の合格線に関する cross と Android の規約が文面上矛盾する

**該当箇所**: `kasane/handbook/cross/scroll-performance-gate.md:20`  
**問題点**: cross 規約は無条件に「数値に合格線を置かない」としていますが、Android 規約は独立した相対ゲートとして10%の数値基準を置いています。設計上は「体感ゲートの絶対値」と「ラッパーの相対上乗せ」の別軸ですが、規範文だけではその境界が閉じていません。

**推奨修正**: 「体感による滑らかさの合否には絶対数値の合格線を置かない」と限定し、Android の相対的な薄さのゲートは別系統であることを明記してください。

### [🟡 Minor] スクリプトの使用例が存在しないファイル名になっている

**該当箇所**: `samples/android/benchmark/scripts/verify-fling-results.py:11`  
**問題点**: 使用例は `verify_fling_results.py` ですが、実ファイル名は `verify-fling-results.py` です。記載どおりのコマンドは失敗します。

**推奨修正**: 使用例を実ファイル名に合わせ、可能ならリポジトリルートから実行できる完全な相対パスにしてください。

### [🟡 Minor] Androidの既存証跡にOS情報がない

**該当箇所**: `kasane/changes/performance-criteria-review/evidence/manual-imageGrid-android-2026-09-08.md:9`、`kasane/changes/performance-criteria-review/evidence/manual-largeData-android-2026-09-08.md:9`  
**問題点**: 新しい証跡雛形は「機種・OS」を必須にしていますが、Android 2件は Pixel 4a だけで OS/API level がありません。`tasks.md:8` の「4本を雛形に揃える」は完全には満たされていません。

**推奨修正**: 元記録から確認できる OS/API level を追記してください。確認不能なら推測せず「未記録」と明記し、比較不能条件として扱ってください。

## アクションプラン

1. iOS の不一致計数を original/preferred attributes 比較へ直す。
2. Android 検証スクリプトで試行数3件を強制する。
3. `KsLayoutDiagnostics` を通常の公開 API から外す。
4. iOS の全件往復後破棄テストを実装する。
5. 基準機代替と数値ゲートの handbook 文面を整合させる。
6. Minor 3件と不足テストを修正後、提示済みと同範囲の静的レビューを再実施する。

基準機代替の境界だけは過去のプロジェクト記録も補助照合しましたが、指摘自体は現行の spec と iOS/Android handbook の不整合から独立に成立します。



## 突き合わせ結果 (review-001.md との照合、2026-09-15)

| # | 相方の指摘 | ホスト側 | 採否 | 重要度 |
|---|---|---|---|---|
| 1 | 不一致率が original attributes ではなく現在の推定値と比較 | なし | **採用** (機構の特定と偽陽性の実害シナリオあり) | Major |
| 2 | スクリプトが試行数 3 を検証しない | なし | **採用** (spec「3 試行の集計値」の担保が無い) | Major |
| 3 | Debug 限定の診断型が public | Suggestion (公開範囲の意図確認) | **確定** (高い方を採る) | Major |
| 4 | 破棄テストが全件往復を再現していない | Minor (同旨) | **確定** (高い方を採る) | Major |
| 5 | iOS 規約だけ基準機の無承認代替を許す | なし | **採用** (design Decision 6「判定規則は両プラットフォーム同一」に反し、完了判定の穴になる) | Major |
| 6 | 繰り返し前の平均が格子に載らない | なし | **採用** (design Decision 1 の明文に反する) | Minor |
| 7 | cross と Android の合格線の文面矛盾 | なし | **採用** | Minor |
| 8 | 使用例のファイル名が実在しない | なし | **採用** | Minor |
| 9 | Android 証跡に OS 情報が無い | なし | **採用** | Minor |

ホスト側のみの指摘 (Major 3: Debug 限定カウンタと Release 規約の不整合 / Android の reset 順序 / 保持上限テストの空テスト化、Minor: replaced ≤ peak・2 ファイル指定・実物 JSON 未通過、Suggestion 3) はそのまま採用。未解決 (矛盾) は無し。
