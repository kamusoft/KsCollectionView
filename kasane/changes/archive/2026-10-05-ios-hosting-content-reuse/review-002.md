# レビュー結果: ios-hosting-content-reuse (002 回目)

**日付**: 2026-10-05
**判定**: APPROVED

## サマリー

1 周目 (review-001.md) の Major 1 件・Minor 1 件・Suggestion 1 件は、どれも解消した。完了の判定で採らない項目と体感の合否はオーナー判断として deviation.md に記録され、state を変えたセルが別の項目へ再利用される経路を通す恒久のテストが足された。対応で入った新しい問題は見つからなかった。残るのは証跡の文言の食い違い 1 件 (Suggestion) だけである。

`ios/Sources/` は 1 周目から変わっていない (1 周目に取ったスクラッチの複製と全ファイル一致)。

## 1 周目の指摘の解消

| 1 周目の指摘 | 対応 | 判定 |
|---|---|---|
| Major: 完了の判定が済んでおらず、差が deviation.md に無い | `deviation.md` に 2 行が足された。基準機の走行は「並べ替え」の 1 組だけで完了にし、「大量件数」と不一致率は採らないこと、基準機の変更後は最終の形のソースからのビルドではないことが、理由つきのオーナー判断として記録された。体感の合否 (合格) も記録され、`evidence/perf-hosting-reuse-device.md` の「判定」にも書かれた | 解消。記録済みの差は合意済みの差分として扱う |
| Minor: state を変えたセルが別の項目へ再利用される経路の恒久のテストが無く、起きることが記録に無い | `ios/Tests/KsCollectionViewTests/KsHostingReuseTests.swift:161` に 1 件足された。`evidence/verify-hosting-reuse-stage2.md` の限界に、前の項目の state で `body` が 1 回評価される観測が足された | 解消 (下の「足されたテストの確認」) |
| Suggestion: 途中の形を前提にした記述が残っている | `evidence/perf-hosting-reuse-device.md` と `evidence/perf-hosting-reuse-stage1.md` の冒頭に断り書きが入り、`evidence/verify-hosting-reuse-ios17.md` の 2 か所は「この確認の時点の草稿」と分かる書き方になった。ADR のファイル名は `0012-reuse-hosting-on-ios-18-and-later.md` に変わり、`kasane/decisions/ios/index.md` のリンクも合っている。古い名前への参照は、review-001.md と deviation.md・証跡の経緯の記述を除いて残っていない | 解消 |

## 足されたテストの確認

- 経路: 先頭の項目の state を変え、可視範囲の半分ずつ送って、そのセルが別の項目を載せたことをセルの同一性で確かめてから、その項目の落ち着いた後の state と、`onAppear` が動いた時点の state が初期値であることを見る。1 周目に勧めた形と合う
- 待機: 実時間の期限・`Task.sleep` で譲る・期限切れは実測値つきで失敗、の 3 つを満たす (既存の `waitUntil` を使っている)。送る操作を待機の条件の中で行っているが、条件が満たされた時点で止まり、再利用が起きなければ期限で失敗する
- 一時的な評価の扱い: 前の state で 1 回評価されうることをコメントで断り、確かめる対象を表示に出た結果に限っている。1 周目のプローブの観測と合う

## 実行したテスト (観測)

変わった範囲に絞った (依頼どおり)。Simulator はこのレビュー専用のものを新しく作り、終了後に削除した (`ksn-review842019c-186`・`ksn-review842019c-175`、どちらも iPhone 11)。

| 対象 | 版 | 結果 |
|---|---|---|
| 作業ツリーの `KsHostingReuseTests` (絞り込み) | iOS 18.6 (使い回す側) | `Executed 6 tests, with 0 failures` |
| 作業ツリーの `KsHostingReuseTests` (絞り込み) | iOS 17.5 (作り直す側) | `Executed 6 tests, with 0 failures` |
| 対照: `prepareForReuse` の版の分岐を外したスクラッチの複製 | iOS 17.5 | 6 件中 2 件が失敗。足されたテストは「再利用された項目の state」が期限内に初期値にならず失敗し、入れ物の使い回しを版で見るテストも失敗した。ほかの 4 件は成功 |

- 対照の結果から、足されたテストは、OS が state を戻さないのに入れ物を使い回した場合を検出できる。証跡 (`evidence/verify-hosting-reuse-stage2.md` の「レビュー 1 周目の後に足したテスト」) の同じ確認を再現した
- 絞り込みなしの全件 (3 つの版で `Executed 536 tests, with 0 failures`) は証跡の記載で、この周では流し直していない。536 件は、1 周目に自分で流した 535 件に足された 1 件を加えた数と合う

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` (always)
- `kasane/handbook/cross/test-execution.md` (テストの追加と実行)
- `kasane/handbook/cross/scroll-performance-gate.md` (体感の合否の記載)

ロードしたスキル: ksn-review (ios ドメインに code-review 用のプロジェクト固有スキルは無い)

## 確認した観点

- 1 周目の指摘 3 件の解消 (上の表)
- 合意スコープとの一致: 完了の判定の差は deviation.md に記録済みになった。ほかに記録の無い差は無い
- 体感ゲートの規則: 合否はオーナーの判定として書かれ、判定の対象 (「並べ替え」の 1 走行ずつ、変更後は変種のビルド) も併記されている。未判定のままではない
- 足場の書き換え: exploration.md の決定事項に、対応による書き換えは無い
- ソース: 1 周目から変更なし
- 足されたテストの質 (上の節) と、既存の 5 件への影響 (記録の関数に引数が 1 つ増えただけで、6 件とも 2 つの版で成功)
- コメント: 足されたテストのコメントは単独で読める。`scripts/comment-policy-lint.py --advisory` で iOS のファイルに禁止 0 件・要確認 0 件
- ADR-0012 (proposed): ファイル名の変更だけで、本文は 1 周目と同じ。実装・証跡との食い違いは無い

## 指摘事項

### [🔵 Suggestion] 基準機の証跡の前置きが「合否は書かない」のまま

**該当箇所**: `evidence/perf-hosting-reuse-device.md:5`

**問題点**: 前置きに「合否はこの記録では書かない (判定はオーナー)」とあるが、同じファイルの「判定」には体感の合否 (合格) が書かれた。読む順によっては、合否が未記載と受け取られる。

**推奨修正**: 前置きのこの 1 文を、合否は「判定」の節にある、という書き方に直す。

## アクションプラン

1. (Suggestion、任意) `evidence/perf-hosting-reuse-device.md` の前置きの 1 文を「判定」の節と合わせる
