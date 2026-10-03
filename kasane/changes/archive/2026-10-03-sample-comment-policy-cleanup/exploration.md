# Exploration: sample-comment-policy-cleanup

## 課題 / 動機

起票時 (2026-09-07、`image-loading` の実装フェーズ) の課題は、Android Sample の doc コメントに決定記録 (ADR) の参照が 8 件残り、ソースコメント規約 (`kasane/handbook/cross/comment-policy.md`) の検査 (`scripts/comment-policy-lint.py --advisory`) が「要確認」として報告することだった。本務と無関係で箇所が広い (7 ファイル) ため、オーナー判断で別 change として積んだ。

探索時 (2026-10-03) に検査を回し直したところ、状況が変わっていた。

- **起票時の 8 件は残っていない**。`prefetch-display-size` の実装 (2026-09-24、コミット `3e3794c`) で、Android Sample の doc コメントから ADR の番号が外れ、「値は iOS Sample の同名定義とそろえる。」のように番号なしで理由が読める文に直っている。`samples/` 配下の要確認は 0 件
- **代わりに Sample の外に 10 件出る** (検査対象 473 ファイル、禁止 0 件)。1 件ずつ読んだ結果、どれも規約違反ではなく検査の誤検知と判断した

| 場所 | 件数 | 検査の報告 | 実際 |
|---|---|---|---|
| `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/` の `KsGroupPlan.kt:215` `KsPagingDisplay.kt:48` `KsPagingRequester.kt:135` `KsPrefetchDeclaration.kt:33` `KsReorderController.kt:614` `KsTopSafeArea.kt:86` | 6 | 公開 doc コメント内の ADR 参照 | どれも `internal` の型の中のメンバー。本体は `explicitApi()` で、明示の `public` が無い宣言は利用者から見えない。規約上は ADR の番号を書いてよい場所 |
| `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsImageTest.kt:536` | 1 | 同上 | テスト関数 |
| `ios/Sources/KsCollectionView/KsCollectionView+Paging.swift:39` `ios/Sources/KsCollectionView/KsCollectionViewController.swift:2273` `ios/Tests/KsCollectionViewTests/KsImageCacheContractTests.swift:915` | 3 | 履歴記述 (「だった」) | 「同値のままだった場合は」「取得中だったため」のような条件・理由の言い回しで、過去の仕様の説明ではない |

Android の 7 件は、検査が「doc コメントの直後の宣言行に非公開の修飾子が無ければ公開」と見るために出る (囲んでいる型の公開範囲は見ない)。起票時は 0 件で、機能追加のたびに増えてきた。検査スクリプトは Kasane の配布物で、このリポジトリでは編集しない (`kasane/handbook/cross/comment-policy.md` 冒頭)。

change-id は起票時のまま使う (archive 済みの `image-loading` のレビュー・検証がこの id を参照しているため)。扱う範囲は Sample ではなく本体のコメントに変わっている。

## 検討した選択肢 (却下案と理由を含む)

起票時の 3 つの疑問は、実物が答えを出している。

- Sample は教材でもあるので、参照を消すのが正しいか → 番号だけ外し、理由の文 (「iOS Sample とそろえる」) は残す形で直っている
- iOS Sample が 0 件なのは習慣の違いか → 現在は両プラットフォームとも、番号つきの根拠は行コメントにだけ置いている (`samples/ios/KsCollectionViewSamples/SamplePalette.swift:3`、`samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/SamplePalette.kt:6`)
- 規約の側を見直す (Sample を要確認の対象から外す) か → Sample の要確認が 0 件になったので不要

残る 10 件の扱いは 3 案を比べた。

| 判断軸 | 案 1: 3 件だけ直して閉じる (採用) | 案 2: 10 件ともコードで消す | 案 3: 何も変えずに閉じる |
|---|---|---|---|
| 要確認の件数 | 10 → 7 (検査が直れば 0) | すぐ 0 | 10 のまま |
| 本体に入れる手 | iOS のコメント 3 行 | コメント 10 か所 (Android は番号を行コメントへ移す) | なし |
| 再発 | 検査が直れば止まる | `internal` の型に番号つきの doc コメントを書くたびに出る | 増え続ける |
| ほかに要るもの | 配布元への直しの依頼 | なし | なし |

- 案 2 の却下理由: 規約違反ではないコメントを検査の判定に合わせて書き換えることになり、Android は機能追加のたびに再発する
- 案 3 の却下理由: レビューのたびに同じ 10 件を読み直すことになり、iOS の 3 件は意味を変えずに直せる

## 決定事項

オーナー判断 (2026-10-03) で案 1 を採用した。

- iOS の 3 件を、意味を変えずに現在形の言い回しへ書き換える (条件・理由を表す「だった」を使わない形にする)
  - `ios/Sources/KsCollectionView/KsCollectionView+Paging.swift:39` (公開 doc コメント)
  - `ios/Sources/KsCollectionView/KsCollectionViewController.swift:2273`
  - `ios/Tests/KsCollectionViewTests/KsImageCacheContractTests.swift:915`
- Android の 7 件はコードを変えない。誤検知の印 (`comment-policy:allow`) も付けない
- 完了の目安: `python3 scripts/comment-policy-lint.py --advisory` の報告が、履歴記述 0 件・公開 doc コメント内の ADR 参照 7 件 (上の表の Android の 7 件) になる。コメントだけの変更で、挙動とテストの結果は変わらない
- 検査の判定の直しは配布元 (Kasane) に依頼する。依頼する内容:
  - Kotlin で、`internal` の型の中のメンバーとテストのソースを公開とみなしている。`explicitApi()` のプロジェクトでは、明示の `public` がある宣言だけを公開とみなせばよい (C# / Java と同じ扱い)
  - Swift の既定の公開範囲は internal だが、検査は「既定が public」として扱っている (このリポジトリでは iOS が ADR の番号を `///` に書いていないため、まだ誤検知は出ていない)
  - 「だった」が、条件・理由の言い回しでも履歴記述として報告される

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

なし (可逆で局所的な判断のため起票しない)。

## 未決の論点

- 配布元 (Kasane) への依頼の出し方。このリポジトリの外への書き込みになるため、オーナーの指示を受けてから行う

## UI 素材 (ui/references/ の一覧と注釈)

なし。

## 変更級の推奨: S

コメント 3 行の言い換えだけ。触る能力は本体 (iOS) のコメントのみ、公開 API の変更なし、挙動の変更なし、可逆、UI なし。
