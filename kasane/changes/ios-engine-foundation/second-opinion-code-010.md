# セカンドオピニオン: ios-engine-foundation (code-010)
**相方**: codex / **label**: so-code-ios-engine-foundation-010 / **日付**: 2026-09-03 / **対象**: 修正サイクル 10 後の ios/・samples/ios/・change 成果物・関連 handbook / dsl-samples
---
# レビュー結果: ios-engine-foundation（最終）

**日付**: 2026-09-03  
**判定**: APPROVED  
**件数**: Critical 0 / Major 0 / Minor 2 / Suggestion 0

## サマリー

サイクル 10 の主要修正は成立しています。全 10,000 件を半画面刻みで通過する走査、定常化判定、Sample UI テストの安定化、生存セル計測の Release 除外に後退はありません。

メモリ計測は、許容差を事前定義したうえで独立 2 実行がほぼ同じ約 610.68 MB に収束しており、spec の「増え続けない」に対する判定として誠実です。絶対値の妥当性や内訳、実機との差を証明したものではない点も evidence 内で適切に限定されています。

ただし、計測失敗を成功経路から排除できない箇所と、仮想化テストの上限に関する証跡記述の不一致が残っています。いずれも今回の実測結果を覆すものではなく、APPROVED を妨げない Minor と判定します。

## 照合した規約

- ksn-review の汎用チェックリスト、重要度、判定基準
- ksn-core および handbook.md / delta-spec.md / paths.md / domain-axis.md / evidence.md / config.md / ui-artifacts.md
- swift-ui-impl-skill のモダン API、View 構造、状態管理、アクセシビリティ、性能、Concurrency、コード衛生
- ソースコメント規約（always）
- Sample のプラットフォーム間一致（samples/）
- テスト実行規約（テスト結果報告・条件ベース待機）
- 実行時挙動の検証規約（スクロール・セル再利用・レイアウト変更）
- 公開識別子と配布座標（Package.swift・Sample）
- ローカル開発環境と Sample の実行（guide）
- core/ADR-0003 / 0004 / 0006 / 0007 / 0009
- ios/ADR-0001〜0004
- deviation.md の全記録
- proposal.md / design.md / specs/*/spec.md の凍結状態
- 承認モック、最終 UI 照合画像、動作証跡画像

## 前回指摘の追跡

| 確定修正 | 状態 | 確認結果 |
|---|---|---|
| Major: メモリ計測の全項目走査と再計測 | **解消** | 半画面刻み、可視項目の記録、全 10,000 件通過、最大 10 往復、独立 2 実行を確認。両実行とも約 610.68 MB に収束 |
| Major: Sample UI テストの安定化 | **解消** | 起動前 terminate、対象画面の再確認、hittable 待機、結果 label の条件待機を確認。提示結果は通常スキーム 5 回連続成功 |
| Minor: 生存セル計測フックの Release 除外 | **解消** | 弱参照辞書、記録処理、関連テストが #if DEBUG 内に限定されている |
| Minor: 仮想化テストの件数と上限 | **部分解消** | 2,000 件という射程を明記し、固定 400 件から可視セル数基準の 4 倍へ改善。ただし証跡文書は「3 倍未満をテストで検証」と記載している |
| Minor: 計測画面コメント | **解消** | 「実機だけ」ではなく環境非依存のメモリ計測画面として説明されている |
| Minor: listSeparators のコメント | **解消** | 先頭上端・行間・最終行下端を含む現行契約へ追随している |

アンカー復元、スクロール命令、タップ／長押し、テンプレート再構成、レイアウト変更の既存経路にも、サイクル 10 修正による後退は確認しませんでした。

## 指摘事項

### [🟡 Minor] 計測走査の失敗を無視したまま定常化を報告できる

**該当箇所**:  
samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:100  
samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:144  
samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:168  
samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:232  
kasane/changes/ios-engine-foundation/evidence/performance-early-measurement.md:39

**問題点**: `settle` の戻り値を捨てており、タイムアウトしても走査とメモリ採取を継続します。片道の最大段数に達した場合も失敗として伝播しません。また、通過項目集合は往復間で累積されるため、最初の往復で全件に到達した後は、後続往復が不完全でも 10,000 件と表示されます。

今回の実測は全件通過と同一水準への収束が記録されているため無効とは判断しませんが、ハーネス単体では evidence の「各段階で到達を待つ」「1 往復ごとに全項目を通過」を fail-closed に保証できません。

**推奨修正**: 各往復で通過集合をリセットし、`traverse` から「端へ到達したか」「settle が全段階で成功したか」を返してください。失敗または通過件数不足の場合は footprint を定常化判定へ加えず、`KS_PERF_STEADY=no` または明示的な未判定として終了させてください。

### [🟡 Minor] 証跡がテストの上限を 3 倍と説明しているが、実際のアサーションは 4 倍である

**該当箇所**:  
ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:650  
kasane/changes/ios-engine-foundation/evidence/verification-matrix.md:18  
kasane/changes/ios-engine-foundation/evidence/performance-early-measurement.md:75

**問題点**: テストは `visibleCellCount * 4` を上限としていますが、2 つの evidence は「可視セル数の 3 倍未満に留まることを検証」と記載しています。実測最大 115 件／可視 39 件は実際には 3 倍未満ですが、回帰テストが将来もその境界を固定しているという説明にはなっていません。

**推奨修正**: 4 倍を安全余裕込みの契約とするなら evidence を「4 倍未満」に訂正し、実測値が約 2.95 倍だったことを別記してください。3 倍を回帰境界とするならアサーションも 3 倍へ揃えてください。

## アクションプラン

1. 計測走査を fail-closed にし、各往復単位で 10,000 件通過を確認する。
2. 仮想化テストの 3 倍／4 倍の記述を実装と統一する。
3. コードを変更した場合のみ、計測スキームと自動定常化経路を再確認する。

## 確認した観点

- 全 10,000 件走査の刻み、端点計算、条件待機、通過項目記録
- 2% 許容差の分母、直近 2 増分の計算、最大 10 往復
- 独立 2 実行の収束水準と evidence の限定表現
- Debug 専用生存セルフックと Release 経路
- Sample UI テストの起動分離・条件待機・5 回連続成功
- snapshot の挿入・削除・移動・reconfigure・reload
- 重複 ID、未登録テンプレート、Release 縮退
- list / fixed / adaptive / 向き別列数、spacing、padding
- アンカーの要素内オフセット、縮小時クランプ、削除時近傍復元
- セル再利用、SwiftUI state、自己サイズ、header / footer
- tap / long tap / 子コントロール競合 / feedback
- scroll controller の接続、no-op、center、データ反映後実行
- Sample 9 画面、公開識別子、最低対応版
- 承認モックと最終 UI 証跡
- tasks、verification matrix、deviation、handbook、dsl-samples
- コメント、ローカルパス、個体識別情報、秘密情報の扱い


## 突き合わせ結果 (2026-09-03)

ホスト側 `review-010.md` (CHANGES_REQUESTED: Major 2 / Minor 2 / Suggestion 3) および `verify-003.md` (VALID) と突き合わせた。サイクル 10 の確定リストは三者とも解消を確認、後退なし。

### ホストの Major 2 件の扱い

- Major-1 Sample UI テストが通しで失敗 (4 回中 3 回): **環境要因として却下**。verify-003 が同時刻に同じ Simulator で同じスキームの `xcodebuild test` を並走させていたことを特定し (オーケストレーターが review-010 と verify-003 を並列起動した結果)、並走終了後の 5 回連続実行は全回成功。実装者の 5 回連続成功とも一致する。教訓として lessons/inbox に記録
- Major-2 `ios/DerivedDataRelease/` が gitignore に載らず lint が赤: **採用・処理済み**。verify-003 が trash 済み。再発防止に `.gitignore` へ `DerivedData*/` を追加 (handbook の手順は `-derivedDataPath` を指定していないため handbook は変更なし)

### 確定 — 双方一致 (Minor)

- 証跡の「可視セル数の 3 倍未満」がテストの実アサーション (× 4) と不一致 (相方 Minor-2 / ホスト Minor-1): **Minor**。evidence 2 箇所を「4 倍未満 (実測は約 2.95 倍)」に訂正する
- 計測走査が往復単位で fail-closed になっていない (相方 Minor-1 / ホスト Minor-2): **Minor**。往復ごとに通過集合をリセットし、settle 失敗・通過件数不足の往復は定常化判定に加えず未判定として終了する。UI テストの検証も往復単位にする

### 据え置き

- ホスト Suggestion 3 件、verify-003 の据え置き所見 5 件 (S11.2 自動テスト不在 / assertion 未検証 / R14 の Scenario 化 / 8.1・8.3 証跡統合 / Simulator メモリ絶対値の内訳): 蒸留 (ksn-distill) へ送る

### 最終確認 (2026-09-03)

- サイクル 11 (Minor 2 件) の修正を `review-011.md` (APPROVED: Minor 1 / Suggestion 1) で独立確認。前サイクル Major の再燃なし。相方レビューは Minor のみの局所修正のため実施せず (`second-opinion.code-review` の趣旨は Major 級の見逃し防止)
- review-011 Minor (evidence の「1 往復あたり 10,000 件」が修正前ハーネスの累積出力に基づく) はオーケストレーターが evidence の文言を担保単位で書き分けて処理。Suggestion (自動実行の終了コード) は蒸留へ
