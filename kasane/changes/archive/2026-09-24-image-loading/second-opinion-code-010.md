# セカンドオピニオン: image-loading (code-010)
**相方**: codex / **label**: so-code-image-loading-010 / **日付**: 2026-09-08 / **対象**: 群 1 = レビュー 9 周目の指摘対応 (Android)、群 2 = iOS の計測用の変更 (ScrollWindowSignpost / --prefetch の初期選択反映 / PerformanceDriverUITests)、証跡 3 本
---
# レビュー結果: image-loading（10 回目）

**日付**: 2026-09-08  
**判定**: CHANGES_REQUESTED

## サマリー

群 1 は review-009 / second-opinion-code-009 の指摘を解消しています。`Assume` 化、環境限定 KDoc、表示時の再デコード検査、現行 A/B 証跡はいずれも整合しています。

群 2 は通常起動では不活性で、表示文言・初期選択・画面構成の sample-parity も維持されています。一方、Android の撤去前計測を現行結果として完了扱いしている点と、iOS 7.4 の収束待機がタイムアウトを失敗にしない点が完了判定を妨げます。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`（always）
- `kasane/handbook/cross/sample-parity.md`
- `kasane/handbook/cross/test-execution.md`
- `kasane/handbook/cross/runtime-behavior-verification.md`
- `kasane/handbook/ios/performance-verification.md`
- `kasane/handbook/android/performance-verification.md`
- `cross/ADR-0004`
- `core/ADR-0008`
- Kotlin / SwiftUI 実装・レビュー規律

テスト・ビルドは依頼記載のホスト結果を根拠とし、静的レビューでは再実行していません。

## 指摘事項

### [🟠 Major] `allowHardware(false)` 撤去前の Android 計測を現行結果として完了扱いしている

**該当箇所**: `kasane/changes/image-loading/evidence/image-grid-measurement-android.md:5`、`:186`、`:270` / `kasane/changes/image-loading/evidence/image-behavior-observation.md:137` / `kasane/changes/image-loading/tasks.md:54`、`:56`

**問題点**: Android 計測証跡は `allowHardware(false)` 適用中の値であり、本文自身も同指定を RSS 増加・性能超過の原因候補として扱っています。一方、現行実装では指定が撤去済みです。さらに `deviation.md:83`、`:91` とクラッシュ修正証跡 `image-grid-memory-prefetch-crash-fix-android.md:119-124` は、到達点 memory の 7.4 / 7.5 を撤去後に取り直す必要があると明記しています。

これは合意済み乖離そのものへの指摘ではなく、乖離で要求された再計測が未実施なのに tasks 7.4 / 7.5 と証跡先頭が完了を表している矛盾です。特に 7.4 の「送り先すら読み込み中を経由しない」という観測は、現行の実機経路と条件が変わっています。

**推奨修正**: Pixel 4a で撤去後の到達点 memory について 7.4 と 7.5 を再計測し、証跡を更新してください。それまでは該当タスクを未完了に戻し、既存値は「撤去前の履歴」と明示してください。

### [🟠 Major] iOS 7.4 の収束待機がタイムアウトしても証跡採取を続行する

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift:159`

**問題点**: `waitUntilMarkSettles` は実時間 deadline と待機対象への実行機会を持ちますが、60 秒以内に収束しなかった場合も黙って戻ります。直後の出力には「静止による成功」と「タイムアウト」の区別が残らないため、証跡の「初回表示の収束後」という前提を確認できません。

これは `test-execution.md` が禁止する「黙って戻る待機」に該当し、7.4 の基準点を未収束状態で切っても駆動が緑になり得ます。

**推奨修正**: タイムアウト時は最終 `mark.label` を含めてテストを失敗させ、後続の基準点・ドラッグを実行しないようにしてください。

### [🟡 Minor] 計測ドライバのコメントが作業文書とタスク通番に依存している

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift:106`、`:108`

**問題点**: コメント中の `tasks 7.4` と `evidence/image-behavior-observation.md` は、ソースコメント規約が禁止するローカルタスク通番・作業文書パスです。lint 0 件でも、規約本文の適用範囲は機械検査より広いため手動レビューでは違反になります。

**推奨修正**: 「戻ってきたセルの再表示を観測する駆動」のように、ファイル内だけで意味が閉じる現在形の説明へ置き換えてください。

### [🟡 Minor] iOS 証跡の「規約どおり」が記録済みの時間乖離と矛盾する

**該当箇所**: `kasane/changes/image-loading/evidence/image-grid-measurement-ios.md:5`、`:201`

**問題点**: 冒頭は「規約どおりの手順」としていますが、同文書と `deviation.md:85` はフリック区間が 3.0〜6.0 秒で、規約の固定 3 秒に厳密には従っていないと説明しています。乖離は合意済みで判定自体も変わりませんが、証跡内の表現は不整合です。

**推奨修正**: 「合意済み乖離を含む立て直し手順」などへ改め、厳密な規約準拠とは表現しないでください。

## 確認して問題がなかった観点

- 群 1 の review-009 指摘はすべて反映済み
- `ScrollWindowSignpost` は起動引数なしでは observer・signpost とも有効化されない
- `--prefetch` が無い通常起動では初期選択 `.disk` を維持
- 計数用の印も opt-in なしでは空で、通常画面の構成・文言に影響しない
- iOS の表示文言、選択肢、件数、列数は Android Sample と一致
- iOS hitch ratio の算術（1.47 / 5.53 / 5.78 ms/s）と「3 試行中 2 試行不合格」の判定は一致
- Android の掲載済み数値計算自体は整合しているが、現行実装の値ではない

指摘件数: Critical 0、Major 2、Minor 2、Suggestion 0。

**判定: CHANGES_REQUESTED**



## 突き合わせ結果 (ホスト側 review-010.md との照合、2026-09-08)

| 相方の指摘 | ホスト側 | 採否 |
|---|---|---|
| Major: `allowHardware(false)` 撤去前の Android 計測を現行結果として完了扱い | Major 1 (同内容) | **確定 (Major)**。撤去後の到達点 memory の再計測 (7.4 / 7.5) は起票済みの取り直し便で実施中 |
| Major: iOS 7.4 の収束待機 `waitUntilMarkSettles` がタイムアウトしても黙って戻る | 指摘なし | **採用 (Major)**。該当箇所特定済み、test-execution の「黙って戻る待機」禁止に該当。次の iOS 便で修正 |
| Minor: 駆動コメントの tasks 通番・証跡パス | Major 2 (同内容) | **確定** (重要度はホスト側の Major) |
| Minor: iOS 証跡の「規約どおり」が区間 3.0〜6.0 秒の乖離と矛盾 | 指摘なし | **採用 (Minor)**。証跡の表現修正 |

ホスト側のみ: Minor 3 件 (クラッシュ修正証跡の見出し / 窓が伸びる要因の切り分け / 7.1 証跡に「次に必要なこと」)、Suggestion 2 件 (`--prefetch` 解釈の重複 / 7.4 の行数の帰属)。集計: 確定 2 / 採用 2 / 降格 0 / 未解決 0。
