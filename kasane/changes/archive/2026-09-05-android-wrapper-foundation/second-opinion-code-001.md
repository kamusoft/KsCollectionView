# セカンドオピニオン: android-wrapper-foundation (code-001)
**相方**: codex / **label**: so-code-android-wrapper-foundation-001 / **日付**: 2026-09-05 / **対象**: tasks.md グループ 1 (iOS 追随) の未コミット作業ツリー差分 (ios/Sources, ios/Tests, samples/ios, dsl-samples.md)
---
# レビュー結果: android-wrapper-foundation（グループ1）

**日付**: 2026-09-05  
**判定**: **CHANGES_REQUESTED**

## サマリー

実装コード自体は、`KsTemplate` の推論形、旧公開型の撤去、区切り線色の即時更新・非表示優先を正しく実現しています。一方、必須の性能検証と Sample の新規シナリオ検証がなく、完了済みにできない状態です。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`（always）
- `kasane/handbook/cross/sample-parity.md`（Sample 変更）
- `kasane/handbook/cross/test-execution.md`（テスト結果報告）
- `kasane/handbook/ios/performance-verification.md`（iOS 描画経路変更）
- core/ADR-0004、core/ADR-0010
- ios/ADR-0002、ios/ADR-0006
- deviation.md なし

## 指摘事項

### [🟠 Major] 描画経路を変更したのに必須の性能検証がない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:115`、`ios/Sources/KsCollectionView/KsHostingCell.swift:152`、`kasane/changes/android-wrapper-foundation/tasks.md:11`

**問題点**: 区切り線色の変更時に可視セルを走査し、各セルの描画設定を更新する経路が追加されています。これは `performance-verification.md` の「セルの描画・再利用経路に触れる変更」に該当しますが、提示された検証結果は SwiftPM/UI テストと lint のみです。固定 fixture による hitch time ratio とメモリ定常化の証跡がありません。

**推奨修正**: 規約の固定 fixture と手順でスクロール性能3試行およびメモリ定常化を確認し、環境・各測定値・判定を `kasane/changes/android-wrapper-foundation/evidence/` に記録してください。基準機を代替する場合は保証範囲も明記してください。

### [🟠 Major] 「区切り線3択」の Sample シナリオがテストされていない

**該当箇所**: `samples/ios/KsCollectionViewSamples/ListDemoView.swift:13`、`kasane/changes/android-wrapper-foundation/tasks.md:9`

**問題点**: 新しい Picker が「なし → 既定 → アクセント」を実際に切り替え、表示へ即時反映することを確認するテストまたは証跡がありません。報告された通常スキームの3 UIテストはセル内 Button と長押しの検証であり、この追加シナリオを通っていません。エンジン単体テストは低水準の色・表示制御を確認していますが、Sample の選択肢から modifier へ至る配線は未検証です。

**推奨修正**: Sample を起動して3選択肢を順に操作し、非表示・既定色・アクセント色への切り替えを観測する UI/統合テストを追加してください。視覚的な色確認が自動化困難なら、決定的なスクリーンショットまたはテスト用観測点による証跡を残してください。

### [🟡 Minor] 公開語彙一覧の ADR 出典が不足している

**該当箇所**: `kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md:403`

**問題点**: `listSeparatorColor` は core/ADR-0010 で導入された語彙ですが、公開語彙一覧では出典が `0006` のみになっています。API の由来を追うと、色指定の決定へ到達できません。

**推奨修正**: 当該行の出典を `0006, 0010` としてください。

## 良好だった点

- `buildExpression` と実際の描画を通す統合テストにより、型注釈なしの推論形を確認しています。
- `ios/Sources/` から旧 `Template` 型は撤去されています。
- 色変更、既定色への復帰、非表示優先が実装されています。
- Sample の3択の順序・文言とアクセント色の配線は仕様どおりです。
- 提示されたテスト件数は規約どおり明示されています。

## 件数

- Critical: 0
- Major: 2
- Minor: 1
- Suggestion: 0

**最終判定: CHANGES_REQUESTED**


---
## 突き合わせ結果 (ホスト側 review-001.md との照合、2026-09-05)

| 相方の指摘 | ホスト側 | 採否 | 根拠 |
|---|---|---|---|
| [Major] 描画経路を変更したのに性能検証がない | 指摘なし | **降格** (Suggestion 相当・対応不要) | 追加された経路は `separatorColor` が変わったときだけ可視セルを更新するもの (`KsCollectionViewController.swift` の差分)。スクロール・再利用経路に増えたのは `configureSeparators` の `UIColor` 比較 1 回のみで、`handbook/ios/performance-verification.md` の適用きっかけ (スクロール性能・メモリの検証、大量件数を扱う変更の完了判定) に該当しない。実害シナリオの提示もない |
| [Major] 「区切り線 3 択」の Sample シナリオがテストされていない | 指摘なし (Simulator で全状態遷移を目視確認、review-001.md) | **降格** (Minor 相当・修正サイクルは回さない) | samples 能力の Scenario の検証層は実機手動 (tasks.md 6.5 / 7.6 の対応表)。ホスト側レビューが「なし↔既定↔アクセント」の全遷移と色の実値を確認済み。対応表 (6.5) に「実機手動: review-001 で確認」として載せる |
| [Minor] 公開語彙一覧の `listSeparatorColor` の出典が `0006` のみ | Suggestion で同一指摘 | **確定** (Minor) | 双方一致。dsl-samples.md の該当行を `0006, 0010` に修正する |

ホスト側のみの指摘 (Minor 1: 区切り線の色のテストが下端の線を検証していない) はホスト側判定のまま修正対象とする。採用 0 / 確定 1 / 降格 2 / 未解決 0。
