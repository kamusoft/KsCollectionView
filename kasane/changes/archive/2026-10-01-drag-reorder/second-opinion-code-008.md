# セカンドオピニオン: drag-reorder (code-008)
**相方**: codex / **label**: so-code-drag-reorder-a11y / **日付**: 2026-09-30 / **対象**: 読み上げの移動操作の部品の負荷の修正 (ios/Sources/KsCollectionView/KsCollectionViewController.swift・KsHostingCell.swift・KsReorderAccessibilityModel.swift、ios/Tests/KsCollectionViewTests/KsReorderEngineTests.swift)
---
# 独立コードレビュー: drag-reorder（指定範囲）

**判定: APPROVED**  
指摘: Critical 0 / Major 0 / Minor 0 / Suggestion 0

## 確認結果

`ios/Sources/KsCollectionView/KsCollectionViewController.swift:1670` の付与条件は、並べ替えを設定し、読み上げ文言を渡した一覧に限られています。スイッチの有効・無効では部品を付け替えず、無効時は操作を空にする経路です。文言の有無が変わる際は表示中のセルを再構成する経路も確認しました。

同ファイルの `:667` では、中身を設定する前に操作をモデルへ入れています。その後の `:718` の更新は、世代と項目が同じなら操作を書き換えません。セル再利用時には `ios/Sources/KsCollectionView/KsHostingCell.swift:175` でモデルを消去します。対象テストには付与条件、文言の追加・削除、スクロール時の設定後の操作変更を確認するケースがあります。

## 照合した規約・範囲

`ksn-review` の判定基準、`kasane/lessons/code-review.md`、読み上げの移動操作の Requirement、`deviation.md`、指定の性能証跡を照合しました。ロードしたスキルは `swift-ui-impl-skill` です。確認観点は仕様充足、セル再利用、状態更新順、テストの対応、描画負荷です。

**検証の限界:** 依頼どおり静的レビューとし、テストや性能プローブは再実行していません。523 件のライブラリテスト、10 件の Sample UI テスト、lint 0 件は提示されたホスト側の結果として扱いました。性能証跡の計測値も独立には再現していません。

## アクションプラン

修正要求はありません。

## 突き合わせ結果

ホスト側レビュー: review-008.md (APPROVED、Suggestion 2: ドラッグ中に文言を渡す・外す場合の結合テスト、並べ替えのオフ → オンで部品を付けたまま中身を作り直さないことを固定するテスト)。相方は指摘なしの APPROVED。

- **確定**: 修正は Requirement「読み上げの移動操作」を満たし、並べ替えを使わない一覧の振る舞いを変えていない (双方)
- **見送り**: ホスト側の Suggestion 2 件 (任意のテストの追加。ホスト側のプローブではどちらも正しく動くことを確認済み。回帰の歯止めとしての追加は見送る。2026-09-30)
- **降格**: なし / **未解決**: なし
