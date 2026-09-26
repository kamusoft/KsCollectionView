# セカンドオピニオン: sections-grouping (code-002)
**相方**: codex / **label**: so-code-sections-grouping / **日付**: 2026-09-25 / **対象**: 883ee76 (HEAD) からの作業ツリーの未コミットの変更 (ios/ android/ samples/)、review-001 の修正後
---
# 再レビュー: sections-grouping

**判定: CHANGES_REQUESTED**（Major 1 件、Minor 1 件）

前回指摘した **iOS の定常表示での再グループ化漏れは解消**しています。キーパス変更時に同じ配列でもグループ構成を再計算し、境界と見出しを確認するテストが追加されました。

### 🟠 Major — Android の見出しに古いグループ値が渡る

**該当箇所:** `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:175`

**問題点:** 新旧のグループ値が `equals` で等しいと、`remember(resolvedGrouping.plan)` は古い `KsGroupResolution` を返します。グループ値を ID で比較し、表示名も持つ型で、ラムダを旧値から新値へ切り替えると、境界を維持する判断は正しい一方、`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:402`まで旧オブジェクトのままです。「新しいグループの値を見出しへ渡す」契約を満たしません。

**推奨修正:** 現在の `resolvedGrouping` を見出しに使い、行数など構造だけに依存する計算を構造的な等値比較で再利用してください。同じ ID・異なる表示名の値へラムダを切り替えるテストを追加してください。

### 🟡 Minor — iOS の切り替え中に旧境界へ新しい見出し内容を設定する

**該当箇所:** `ios/Sources/KsCollectionView/KsCollectionViewController.swift:202`

**問題点:** 通常の `observedValue` 未指定時は、キーパス切り替えの snapshot 適用前に、旧グループ境界の可視見出しを新しい見出しクロージャで更新します。カテゴリ別から別の境界へ切り替えると、差分アニメーション中の旧見出しに、新しい名前と旧件数の組み合わせが渡り得ます。追加テストは適用後の状態を確認しています。

**推奨修正:** グループ構成を切り替える更新では旧見出しの事前更新を避け、新しい構成に対応した見出しだけを更新してください。アニメーション途中の見出し内容も確認してください。

静的レビューのみです。ビルド・テストは実行せず、ご提示の成功結果を前提に判定しました。ファイルは変更していません。


## 突き合わせ結果

ホスト側: review-002.md (CHANGES_REQUESTED、Minor 1 (優先度高))。前回の確定 Major と採用 Suggestion は双方とも解消と判定。

| 指摘 | 相方 | ホスト | 採否 |
|---|---|---|---|
| iOS: 取り出し方の切り替えで、差分の適用前に古いグループの範囲の見出しを新しい取り出し方で組み立て直す (アニメーション中に古い見出しへ新しい名前が出る) | Minor | Minor (優先度高、プローブで組み立ての順を確認) | **確定 (Minor)** — 双方一致。修正する |
| Android: 構成が等しいと `remember(resolvedGrouping.plan)` が古い `KsGroupResolution` を返し、見出しへ古いグループの値 (等しいが別の中身) が渡る | Major | — (Android は構成と見出しを同じタイミングで読むので iOS の問題は起きない、とのみ言及) | **採用 (Major)** — 相方のみ + 根拠強。spec「見出しの内容の更新」(新しい配列でのグループの値とグループ内の項目が渡される / グループの値が変わらない場合も同じ) に反する。項目の内容だけの変更でも古い項目が渡らないかをあわせて確かめる |

未解決: なし
