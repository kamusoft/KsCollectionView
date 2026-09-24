# セカンドオピニオン: prefetch-display-size (code-006)
**相方**: codex / **label**: so-code-prefetch-display-size-006 / **日付**: 2026-09-23 / **対象**: 3e4a918 (HEAD) に対する作業ツリーの未コミット差分 (修正サイクル 5 = 画面に出る時点の再照会の後。samples/android/app/src/measurement/ は対象外)
---
# 独立コードレビュー結果

**Major 2 件。判定: CHANGES_REQUESTED。** 今回の修正には、Android の初回描画で空白になり得る経路と、iOS の読み込み中表示の計測に誤計上が生じる経路があります。ファイルの変更とビルド・テストの実行はしていません。提示されたテスト結果を前提にした静的レビューです。

照合した規約は、ksn-review、`lessons/code-review.md`、cross のコメント・Sample 一致・テスト実行・実行時挙動・スクロール性能規約、および iOS・Android の性能検証規約です。`deviation.md` の合意済み差分と、指定された未実施タスクは指摘に含めていません。

## 指摘事項

### 🟠 Major — Android でカスタム読み込み表示の前に空白を描く

**該当箇所:** `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImage.kt:226`、同 `:311`

**問題点:** 初回の配置時に再照会が外れ、利用者が `loading` を指定していると、`painter == null` かつ `drawsDefaultLoading == false` です。この状態の `draw()` は何も描きません。`shown.value` の変更を受けて読み込みスロットが組み立てられるまで、配置済みのセルに空白の描画が入り得ます。現行テストは最終的にスロットが構成されることを確認していますが、最初の描画は確認していません。

**推奨修正:** 再照会が外れた最初の描画から指定された読み込み表示を出せるようにし、先行合成後のキャッシュ不一致を実描画で確認してください。先読み項目に当たった場合は、引き続き読み込み表示を経由しないことも確認が必要です。

### 🟠 Major — iOS の計測が画面外で組み立てた表示を「読み込み中」に数える

**該当箇所:** `ios/Sources/KsCollectionView/KsImageDeferredLoad.swift:36`、`samples/ios/KsCollectionViewSamples/ImageLoadingSlotCounter.swift:146`、`samples/ios/KsCollectionViewSamples/ImagePrefetchMatchProbe.swift:175`

**問題点:** `.waiting` は画面に出る前にも `placeholder()` を組み立てます。計測用スロットはその組み立て時点で `sized` を加算するため、表示時の再照会で画像に当たり、画面上では読み込み中を経由しなかったセルにも `matchedSized > 0` が付き得ます。テストも、表示前に読み込みスロットが組み立てられることを明示的に確認しています。これでは今回の修正後に採る「読み込み中を経由したか」の数値を判定に使えません。

**推奨修正:** 待機中の組み立てと、画面に出て実際に読み込み中を表示した事象を分けて記録してください。先行組み立て後に先読み項目へ当たるケースで、表示要求 0・表示された読み込み中 0 を計測足場でも確認してください。

**判定: CHANGES_REQUESTED**



## 突き合わせ結果

ホスト側: review-006.md (CHANGES_REQUESTED。Major 1 = iOS で画面に出る時点で引き当てた表示が枠・表示倍率・当てはめ方の変化で選び直さない (プローブで再現)、Minor 3 = Android の空白フレーム / Android の要求開始の一律遅延 / iOS 計測の足場の誤計上、Suggestion 1 = オーナー決定 A の deviation 追記)。

| 指摘 | 出典 | 採否 | 根拠 |
|---|---|---|---|
| Android でカスタム読み込み表示の前に空白を描く | 双方 (相方 Major / ホスト Minor) | **確定** (重要度は相方の Major) | 利用者が指定した読み込み中スロットが最初の 1 フレーム描かれない実害が双方で特定 |
| iOS の計測が画面外で組み立てた表示を読み込み中に数える | 双方 (相方 Major / ホスト Minor) | **確定** (重要度は相方の Major) | tasks 8.2 の実機再計測の判定材料が使えない |
| iOS で画面に出る時点で引き当てた表示が枠の変化で選び直さない | ホストのみ | ホスト指摘として確定 (Major) | |
| Android の要求開始の一律遅延 | ホストのみ | ホスト指摘として確定 (Minor)。対処: 遅らせるのはその識別子の先読みが未完了のときだけ | |

件数: 確定 2 / 採用 0 / 降格 0 / 未解決 0
