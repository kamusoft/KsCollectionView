# セカンドオピニオン: sections-grouping (code-003)
**相方**: codex / **label**: so-code-sections-grouping / **日付**: 2026-09-25 / **対象**: 883ee76 (HEAD) からの作業ツリーの未コミットの変更 (ios/ android/ samples/)、review-002 の修正後
---
# 再レビュー: sections-grouping

**判定: APPROVED**（Critical 0 / Major 0 / Minor 0 / Suggestion 0）

前回の 2 件は解消しています。

- **Android:** 構成が等しい場合も、見出しには`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:406`を渡しています。旧値と等しいが表示名の異なる値を使う回帰テストも追加されています。
- **iOS:** 取り出し方を切り替えた際は`ios/Sources/KsCollectionView/KsCollectionViewController.swift:205`、構成が同じ場合はその場で、変わる場合は snapshot 適用後に更新します。テストは切り替え以降の見出しの組み立てが新しい境界と一致することを確認しています。

修正に伴う新たな回帰や契約の不整合は、静的レビューでは見つかりませんでした。ビルド・テストは実行せず、ご提示の成功結果を前提としました。ファイルは変更していません。


## 突き合わせ結果

ホスト側: review-003.md (APPROVED、Minor 1 (低優先) / Suggestion 1)。前回の確定 Minor (iOS) と採用 Major (Android) は双方とも解消と判定。

| 指摘 | 相方 | ホスト | 採否 |
|---|---|---|---|
| iOS: グループの宣言 / 見出しの宣言を外すと、消えていく見出しの中身がフェードより先に消える (「差分更新」の「グループ」スイッチ) | — | Minor (低優先、spec の契約の外、プローブで確認) | **採用** — 5.7 の目視の画面で起きるため、特定済みの小さな修正として直す |
| iOS: 「項目の内容だけ変わっても見出しに新しい項目が渡る」回帰テストが無い (Android にはある) | — | Suggestion | **採用** — 両プラットフォームのテストを揃える |

未解決: なし
