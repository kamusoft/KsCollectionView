# レビュー結果: sample-comment-policy-cleanup (001 回目)

**日付**: 2026-10-03
**判定**: APPROVED

## サマリー

diff は iOS のコメント 3 行の言い換えだけで、exploration.md の決定事項が挙げた 3 か所と 1 対 1 に対応する。コード行の変更は無く、3 件とも条件・理由の意味を保ったまま「だった」を使わない現在形になっている。完了の目安 (検査の報告が履歴記述 0 件・公開 doc コメント内の ADR 参照 7 件) も実測で満たしており、指摘事項は無い。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` (always — ソースのコメントを書き換えた)
- `kasane/handbook/cross/test-execution.md` (テストを実行し、結果を報告する)

ロードしたスキル: ksn-review, swift-ui-impl-skill

`kasane/lessons/code-review.md` の重点観点 [L-001] (証跡の計測値の再現)・[L-002] (動きの過程の観察) は、計測値の証跡も動きの変わる変更も無いため該当しない。

## 確認した観点

**ビルドとテスト**

- `ios/` で `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -configuration Debug` を絞り込みなしで実行: 530 tests / 0 failures (TEST SUCCEEDED)。変更前の件数 (530 件) と同じ
- 確認した OS は iOS 27.0 の 1 つだけ (iOS 18.6・26.5 では実行していない)。コメントだけの変更のため、OS による差は生じない

**仕様充足 (合意スコープ)**

- 決定事項の 3 か所だけが変わっている。`git diff -- ios` は 3 ファイル・各 1 行で、コード行・識別子・テスト名の変更は無い
  - `ios/Sources/KsCollectionView/KsCollectionView+Paging.swift:39`: 「同値のままだった場合は」→「同値のままの場合は」
  - `ios/Sources/KsCollectionView/KsCollectionViewController.swift:2273`: 「同値だった等」→「同値の場合等」
  - `ios/Tests/KsCollectionViewTests/KsImageCacheContractTests.swift:915`: 「取得中だったため」→「取得中のため」
- 3 件とも意味が変わっていない。1 件目・2 件目は「取り直しの結果が同値」という条件、3 件目は「組み立ての時点で先読みが取得中」という理由を、前後の文とつながる形でそのまま表している
- Android の 7 件はコードが変わっておらず、誤検知の印 (`comment-policy:allow`) も付いていない (`git status` で `android/` 配下の変更なし)
- 完了の目安: `python3 scripts/comment-policy-lint.py --advisory` の報告は「7 ファイル / 禁止 0 件 / 要確認 7 件 (検査対象 473 ファイル)」で、7 件はすべて公開 doc コメント内の ADR 参照 (exploration.md の表の Android の 7 件と同じ場所)。履歴記述は 0 件
- `ios/Sources`・`ios/Tests` に「だった」は残っていない
- 無断の仕様逸脱・付随修正は無い (deviation.md は無く、diff に範囲外の変更も無い)
- 足場アーティファクト: `exploration.md` は作業ツリーで未コミットの変更になっている。内容は探索時 (2026-10-03) の状況と決定事項の書き直しで、実装の都合に合わせた書き換えを示すものは diff からは読み取れない。探索の成果物として扱った

**テスト**

- コメントだけの変更で、対応するテストの追加は要らない。3 件目はテスト関数の doc コメントで、テスト名・本体は変わっていない

**設計品質**

- ソースコメント規約との照合 (節ごと)
  - 許容する外部参照 / 禁止する参照: 2 件目の行コメントに続く `core/ADR-0021` は許容される ADR ID の形で、今回の変更では触れていない。作業文書のパス・通番・仮称の混入は無い
  - 禁止する記述類型: 3 件とも現在形で、履歴記述・過去仕様の説明・デルタスペックの構文キーワードは無い
  - 公開メンバーの doc コメント: 1 件目は公開 doc コメントで、内部用語 (ADR ID・change 等) を含まず、機能と契約だけを書いている
- コメントが単独で理解できる (外部文書の ID に頼った説明になっていない)
- 既存の文体との一貫性: 1 件目は前後の「です・ます」の箇条、2 件目・3 件目は「だ・である」の文体にそろっている
- オーバーエンジニアリング・入力検証・性能・リソースの観点は、コード行の変更が無いため該当しない
- swift-ui-impl-skill の観点 (モダン API・データフロー・Concurrency 等) も同じ理由で該当しない

## 指摘事項

なし。

## アクションプラン

なし (このまま次の工程へ進めてよい)。exploration.md の未決の論点 (配布元への検査の直しの依頼) は、この change の実装の範囲外でオーナーの指示待ち。
