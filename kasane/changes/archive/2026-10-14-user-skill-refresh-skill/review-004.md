# レビュー結果: user-skill-refresh-skill (004 回目)

**日付**: 2026-10-14
**判定**: APPROVED

## サマリー

`review-003.md` の Suggestion (「記録の更新が止まり、1 つ目の commit も無いときも、commit が 1 つもできない」) への対応として、オーナーの指示で足した 1 文を見た。Skill の本文 `SKILL.md:152` と草稿 `drafts/user-skill-refresh.md:116` の両方に同じ決まりが入り、Suggestion は解消した。spec の Requirement「承認の後の commit と記録の更新」と Scenario「源泉に commit していない変更があると、記録を更新しない」の THEN とは食い違わず、ほかの箇所との矛盾も無い。新しい指摘は無い。

## 照合した規約

- ソースコメント規約 (`kasane/handbook/cross/comment-policy.md`) — always。今回はコードの変更が無い。`scripts/comment-policy-lint.py` は違反なし (検査対象 501 ファイル)
- 利用者向け Skill の追従 (`kasane/handbook/cross/user-skill-refresh.md`) — 直しが Skill の本文と草稿に当たるため。今の文書と草稿の差は proposal の What Changes で蒸留時に反映と合意済みなので、照合の相手は草稿にした
- 検証 CI (`kasane/handbook/cross/verification-ci.md`)・テスト実行規約 (`kasane/handbook/cross/test-execution.md`) — 検査とテストを流して報告するため

ロードしたスキル: なし (パッケージの解決どおり。レビューで読む実装スキルは無い)

lessons: `kasane/lessons/code-review.md` の L-001・L-002 は、計測値も動きの過程も持たない文書だけの直しなので当たらない。

## 確認した観点

**対象の範囲**
- [x] `review-003.md` の後に変わったファイル — 更新の時刻で、`SKILL.md`・草稿・`deviation.md` の 3 枚だけと確かめた。ほかのひな形 3 枚・証跡・`tasks.md` は `review-003.md` より前のまま
- [x] 足場 — `proposal.md`・`specs/` は作業ツリーで未変更 (`git diff --quiet` が 0)

**Suggestion の解消**
- [x] `SKILL.md:152` — 括弧が「6 の 2 つ目の箇条と、1 の commit が無いまま 2 の `record` が止まったとき」に広がり、証跡を「6 でオーナーに見せた内容と、止まった理由として伝えた内容」とした。前回の推奨修正の経路 (7 の 2 で `record` が止まり、1 の commit も作らなかったとき) をそのまま覆う。この経路は試運転 3.5 (3) の形 (`evidence/refresh-skill-trial.md:76`。ワーカーが直さず、`record` が終了コード 1 で止まり、commit は 0 件) と一致する
- [x] 草稿 `drafts/user-skill-refresh.md:116` — 「源泉に commit していない変更が残っている」の行の末尾に、「1 の commit も無く、commit が 1 つもできないときは、6 でオーナーに見せた内容と、ここで伝えた内容をその回の追従の証跡とする」が足された

**Skill と草稿の揃い**
- [x] 条件 — Skill の「1 の commit が無いまま 2 の `record` が止まったとき」と、草稿の「(2 が止まる。) 1 の commit も無く、commit が 1 つもできないとき」は同じ経路を指す。「1 の commit が無い」の条件は、Skill `:144` の「利用者向け Skill の 1 枚にも、記録の `sources`・`apiExclusions` にも、追従による変更が無いときだけ、この commit を作らない」と、草稿 `:107`・`:115` の 1 の commit の決まりに対応する
- [x] 証跡の中身 — Skill の「止まった理由として伝えた内容」と草稿の「ここで伝えた内容」は、どちらも `:146` / 草稿 `:116` で伝える「commit していない源泉の一覧と、オーナーがそれを commit してから記録を更新する必要があること」を指す
- [x] 6 の経路の扱い — Skill `:138` (範囲の中の直しも無く commit が 1 つも無いとき、6 で見せた内容を証跡とし、commit を作らないことを伝える) と草稿 `:117` の行は今回変わっておらず、`:152` の括弧の 1 つ目の経路と引き続き対応する。`:152` の 1 文は 2 つの経路を並べて「6 でオーナーに見せた内容と、止まった理由として伝えた内容」とまとめており、6 の経路では「止まった理由」に当たるものは `:138` で伝える理由 (記録の commit の ID を更新しない理由) と読める。読み違えて手順が変わる箇所ではないので、指摘にはしない

**spec との食い違い**
- [x] Scenario「源泉に commit していない変更があると、記録を更新しない」の THEN (記録を更新しない・源泉の一覧と commit してから更新する必要を伝える・源泉の変更をメインが commit しない) — 足した文は、伝えた後の証跡の置き場だけを決め、commit を作る・記録を更新するふるまいを足していない。THEN の 3 つとも変わらない
- [x] Requirement「承認の後の commit と記録の更新」 — 本文は「追従の要約は、最初に作る commit のメッセージに書く」とし、commit が 1 つも無いときの置き場を決めていない。足した文はその空白を埋めるだけで、commit がある経路 (`:152` の 1 文目・2 文目) の決まりを変えない。「追従で変えていないファイルは commit しない」「push はしない」にも触れない
- [x] Requires (源泉のパスに commit していない変更が無いこと) — 満たさない経路での振る舞いの記述で、Requires の範囲の外の扱いとして前回までと同じ (`verify-004.md`)

**ほかの箇所との矛盾**
- [x] Skill の `:146` の「伝えて終える」と `:152` — `:152` は終え方を変えず、伝えた内容を証跡とみなすだけなので矛盾しない
- [x] 草稿「追従の証跡」の節 (`drafts/user-skill-refresh.md:121`〜`:131`) — 「承認の後に最初に作る commit のメッセージに要約して残す」とだけ書き、commit が無い経路は「commit と記録の更新の順」の表の 2 行 (`:116`・`:117`) に置く形で、前回 (6 の経路を足したとき) と同じ構造である。今回の 1 文もその構造に沿う
- [x] 試運転の証跡 — 3.5 (3) の回で、メインが伝えたことは足した文の「伝えた内容」と一致する。足した文は試運転のふるまいを変えない

**deviation.md**
- [x] 最後の行 — 蒸留送りの行 (`蒸留時に反映: handbook・cross/user-skill-refresh.md — …`) に、オーナーの指示で実装の中で草稿と Skill の本文の両方に足したこと、蒸留では草稿をそのまま置けばよいことを追記した。handbook (長命層) は書き換えておらず、草稿は変更のディレクトリの中の成果物で、Skill の本文は実装なので、`change-scope.md`「長命層の追随は蒸留に送る」に沿う。spec からの乖離を作る直しではないので、乖離の行が要らないことも合う

**検査とテスト**
- [x] `python3 scripts/ci/run-tests.py` — 523 件・失敗 0
- [x] `check-project-skills.py .` (違反なし・Skill 1 つ)・`check-skills.py .` (違反なし)・`local-path-lint.py`・`identity-lint.py`・`comment-policy-lint.py` — すべて終了コード 0・違反なし

## 指摘事項

なし

## アクションプラン

なし
