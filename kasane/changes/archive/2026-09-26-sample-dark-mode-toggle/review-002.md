# レビュー結果: sample-dark-mode-toggle (002 回目)

**日付**: 2026-09-26
**判定**: APPROVED

## サマリー

review-001 の Minor 2 件と Suggestion 1 件、相方の Minor 1 件 (降格) に対する修正サイクルの確認。iOS の配色定義のコメントの参照先、deviation.md の Android の Material の部品の列挙、`commit()` を使う理由のコメントは、いずれも指摘どおりに直っており、修正で新たな問題は出ていない。保存失敗の検知を降格した判断も妥当と評価する。

## 照合した規約

- ソースコメント規約 (always)
- Sample のプラットフォーム間一致 (`samples/` を触るとき。コメントの参照先の照合のみ)
- lessons/code-review.md の重点観点 L-001 (deviation.md に色の値が追記されたため、値の出どころを照合した)

## 確認したこと

範囲はコメントと記録の修正のみで実行時の挙動は変わらないため、依頼どおり静的確認とし、ビルド・テスト・シミュレータ / エミュレータは実行していない (前回の実行結果は review-001 を参照)。

- **`samples/ios/KsCollectionViewSamples/SamplePalette.swift:3`**: 参照先が `SamplePalette.kt` に直っている。Android の 2 組の値は実際に `samples/android/.../SamplePalette.kt` にあり、その 6 行目は iOS の `SamplePalette.swift` を指し返しているので、相互参照が対になった。`samples/` 配下に `SampleTheme.kt` を配色の置き場として指す記述は他に残っていない
- **`samples/android/.../SampleAppearanceStore.kt:28`**: 「作り直しより前にディスクへの書き込みを終える commit を使う」となり、前回問題にした「apply では読み戻せない」と読める理由づけは消えた。記述は事実に合う。前回の推奨にあった「(直後に落ちても選択を失わない)」の括弧書きは入っていないが、ディスクへの書き込みを終えることが目的だと読めるので、指摘には上げない
- **`deviation.md` の 2 項目 (Android の Material の部品)**: 「画像グリッド」のメニューの開閉の印 (▼) の #000000 → #111214 と、選択肢の文字の Material 既定 #1D1B20 → #111214 が追記され、review-001 の指摘で追記したことも記されている。値の出どころを照合した: 選択肢の文字は `SampleMenuPicker.kt:64` で色を指定しておらず `DropdownMenuItem` の既定 (colorScheme の onSurface) を取り、`SampleAppTheme.kt:47` で `onSurface = text` に写されている。#1D1B20 は Material 3 のライトの既定の onSurface の値に一致する。▼は `SampleMenuPicker.kt:56` の `TrailingIcon` が `LocalContentColor` を取るもので、前回の確認どおり。計測対象のコードはこのサイクルで変わっていないため、L-001 の再計測の条件には当たらない
- **標準 lint**: 修正の入った 3 ファイルに `comment-policy-lint.py` / `local-path-lint.py` / `identity-lint.py` を掛け、検出 0 件

### 降格した指摘 (保存失敗の検知) の評価

妥当。保存先はアプリ専用の SharedPreferences で、Sample で `commit()` が失敗する現実的な場面は乏しい。失敗しても起きるのは「今の画面には反映されるが次の起動で選択が戻る」だけで、データの損失や誤動作には至らない。失敗時の表示と作り直しの扱いを決めて足すのは、Sample の外観の切り替えというスコープに対して過剰である。

## 指摘事項

なし。

## アクションプラン

なし。tasks.md の 5.4 (オーナーによる既定色の目視確認) は review-001 の時点と同じく未完了で、コードレビューの承認とは別に必要。
