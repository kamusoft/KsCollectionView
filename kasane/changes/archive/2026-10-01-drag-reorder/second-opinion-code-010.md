# セカンドオピニオン: drag-reorder (code-010)
**相方**: codex / **label**: so-code-drag-reorder-android-shadow / **日付**: 2026-10-01 / **対象**: Android の持ち上げた項目の影の修正 (android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsReorderLift.kt・KsCollectionView.kt)
---
# レビュー結果: drag-reorder（6.3 の影の修正）

**判定: APPROVED**  
指摘事項: Critical 0件、Major 0件、Minor 0件、Suggestion 0件。

影用の層は `ksItemSpacing` の内側に置かれ、透明な上下間隔を輪郭に含めない構成です（`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:765`、`:770`）。項目全体をずらして手前に描く処理は外側の層に残り、戻りの途中の影の濃さも既存の `liftAmount` に従います（`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsReorderLift.kt:69`、`:120`）。この修正範囲で、変更を求める問題は見つかりませんでした。

**照合した規約・観点:** `ksn-review`、`kotlin-impl-skill`、`kasane/lessons/code-review.md`、コメント規約、実行時挙動の検証規約、Android 性能検証の手順、関連 ADR とデルタスペック。影の範囲、描画順、戻りの動き、合意済みの `deviation.md` との整合を確認しました。テストは実行せず、Android ライブラリ474件成功・lint違反0件は提示されたホスト側結果として扱いました。

**残る確認:** 証跡にはエミュレータでの修正前後の比較があります。Pixel 4a 実機での最終的な見え方は、未完了の tasks 6.3 に沿ってオーナーが目視確認する段階です。

## 突き合わせ結果

ホスト側レビュー: review-010.md (APPROVED、Suggestion 2)。相方は指摘なしの APPROVED。

- **確定**: オーナーの指摘 (見出しをまたぐと動かしている項目の下に板が出る) の解消と、影の範囲・重なり順・ずらし方・グリッド・区切り線・高さの補間・持ち上げていないときの描画に新しい問題が無いこと (双方)
- **見送り**: ホスト側 Suggestion 1 (修飾の順を構造で押さえるテストの追加。任意)
- **蒸留送りの候補**: ホスト側 Suggestion 2 (影の輪郭は content の矩形なので、テンプレートの根が背景を塗らないと影が透けて見える。今回の修正で入ったものではない。KDoc か利用者向けガイドに一言)
- **降格**: なし / **未解決**: なし
