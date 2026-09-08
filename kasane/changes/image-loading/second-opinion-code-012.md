# セカンドオピニオン: image-loading (code-012)
**相方**: codex / **label**: so-code-image-loading-012 / **日付**: 2026-09-08 / **対象**: 11 周目の残指摘への対応 (駆動の doc コメント・ImagePrefetchChoice の説明・deviation の注記と再解析結果・iOS 証跡の結論と対照節)
---
# レビュー結果: image-loading（12回目）

**指摘件数**: Critical 0 / Major 0 / Minor 2 / Suggestion 0  
**結果ファイル**: 書き込み不要の指定により未作成

## サマリー

11周目の指摘のうち、doc コメント、`ImagePrefetchChoice` の説明、古いプラットフォーム非対称の注記、対照の数値表、改善前・改善後 trace の分離は解消しています。

ただし、原因を特定していないという限界と両立しない因果断定が2箇所残っています。いずれも今回の重点である「測っていないことを測ったことにしない」に直接関わるため、優先度の高い Minor とします。

## 指摘事項

### [🟡 Minor・優先度高] 古い対照結論が、末尾の再解析結果と矛盾している

**該当箇所**:

- `kasane/changes/image-loading/deviation.md:97`
- `kasane/changes/image-loading/deviation.md:99`
- `kasane/changes/image-loading/evidence/image-grid-measurement-ios.md:252-257`
- `kasane/changes/image-loading/evidence/image-grid-measurement-ios.md:329-332`

**問題点**:

`deviation.md:97` は、画像グリッドの残り1件について「計測の足場に共通する原因ではなく」と共通要因を断定的に排除しています。

一方、末尾の再解析結果と証跡本文は、自動化なしの対照がなく「共通要因の分離は未確認」と正しく限定しています。大量件数の17〜19件を共通要因だけでは説明しにくいことと、画像グリッドの残り1件が共通要因ではないことは同義ではありません。

したがって、11周目の「異なる fixture の対照から共通要因を排除している」という指摘は、証跡側では解消していますが、`deviation.md:97` に残っています。

**推奨修正**:

`:97` の該当部分を、末尾と同じく「共通要因だけでは件数差を説明できない可能性が高いが、共通要因の分離は未確認」と限定するか、後段の再解析で訂正された旧見解である旨を注記してください。

### [🟡 Minor・優先度高] 試行2の「主因」は記録された数値から確定できない

**該当箇所**:

- `kasane/changes/image-loading/evidence/image-grid-measurement-ios.md:283-285`
- `kasane/changes/image-loading/evidence/image-grid-measurement-ios.md:316-321`
- `kasane/changes/image-loading/deviation.md:99`

**問題点**:

証跡は「この計測は原因を特定していない」としながら、改善後の試行2について「主因は自動化4サンプル＋区切り線更新・CA 2サンプル側」と断定しています。

記載値から確かめられるのは次までです。

- commit 全体: 17 ms
- `KsImageRequestFactory.makeContext`: 約1 ms
- 自動化: 4サンプル
- 区切り線更新・CA: 2サンプル

後二者を約6 msと読んでも17 msの過半には届かず、残りの帰属も示されていません。これは「`KsImageRequestFactory` より多く観測された」とは言えますが、「主因」とまでは測れていません。さらに、render 側へのテクスチャの影響を否定できないという限界も併記されています。

**推奨修正**:

「主因」を「観測サンプル数では `KsImageRequestFactory.makeContext` より自動化・区切り線更新・CA側が多かったが、主因は未特定」に狭めてください。主因を維持する場合は、17 msの相互排他的な帰属内訳かA/Bによる切り分けが必要です。

## 11周目指摘の解消判定

| 11周目の指摘 | 判定 |
|---|---|
| `waitUntilMarkSettles` の旧docコメント | **解消**。単一のdocブロックに統合され、タイムアウト時の失敗と後続中止を正しく説明 |
| `ImagePrefetchChoice` の指す先がなくなった説明 | **解消**。起動引数の解釈をこの型に一本化した現在形の説明になっている |
| 古いプラットフォーム非対称 | **解消**。`deviation.md:87` に当時の状態と解消済みの注記あり |
| 改善前traceの結論を改善後へ流用 | **解消**。改善前と改善後の試行2・3を分離し、試行2は「不在とは言えない」と記録 |
| 対照の数値不足 | **解消**。対照3試行の`KS71`、画面更新数、fps、無更新時間を追加 |
| 異なるfixtureからの共通要因排除 | **一部未解消**。証跡本文は限定されたが、`deviation.md:97` に旧断定が残存 |

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`
- `kasane/handbook/cross/sample-parity.md`
- `kasane/handbook/cross/test-execution.md`
- `kasane/handbook/cross/runtime-behavior-verification.md`
- `kasane/handbook/ios/performance-verification.md`
- SwiftUI／Swiftレビュー規律

テストは依頼どおり再実行していません。提示された iOS Sample UI 5/0、iOS本体154/0、Android本体130/0、Sample unit 28/0、Android実機4/0、lint 0件を前提にした静的レビューです。

**判定: CHANGES_REQUESTED**



## 突き合わせ結果 (ホスト側 review-012.md との照合、2026-09-08)

| 相方の指摘 | 採否 |
|---|---|
| Minor (優先度高): deviation の「スコープ外の発見」の項に「共通する原因ではなく」の旧断定が残存 | **採用**。「共通要因だけでは説明できない可能性が高いが、分離は未確認」に修正 |
| Minor (優先度高): 試行 2 の「主因は自動化 + 区切り線更新側」は記録値から確定できない | **採用**。証跡と deviation の両方を「観測サンプル数ではそちらが多いが主因は未特定」に修正 |

11 周目の指摘は上記 1 件の残存を除きすべて解消と判定された。ホスト側 review-012.md の結果は到着後に追記する。

追記 (ホスト側 review-012.md 到着後): ホスト側は Minor 1 (試行 2 の commit の内訳が一次データと合わない — サンプル 5 件、駆動側 0 件、「自動化 4」は UIKit のアクセシビリティ呼び出しの誤帰属で、識別できる最大の費用はライブラリの区切り線更新の経路) と Suggestion 2 (対照 b1 の合計の幅 / 「自動化」の分類定義)。いずれも証跡と deviation の記述修正で対応。相方の Minor 2 件と併せて集計: 確定 0 / 採用 3 / 降格 0 / 未解決 0 (Suggestion は記述に反映)。
