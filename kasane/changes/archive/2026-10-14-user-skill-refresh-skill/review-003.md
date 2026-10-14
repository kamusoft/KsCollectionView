# レビュー結果: user-skill-refresh-skill (003 回目)

**日付**: 2026-10-14
**判定**: APPROVED

## サマリー

前回に直すと決めた 4 件 (`second-opinion-code-002.md` の「突き合わせ結果」の採用 2・確定 2) は、`SKILL.md`・`references/prompt-rewrite.md`・草稿・証跡の直しで、すべて解消した。新しく入った `git commit --only -- <パス…>` のふるまい (前から stage されている別の作業の変更が入らない・pre-commit hook も名指ししたパスだけを見る) は、使い捨ての clone で再現して確かめた。修正は指摘の箇所に留まり、試運転で確かめた Scenario のふるまいを変えていない。新しい指摘は、証跡の置き場の 1 文が、同じ形の別の経路 (記録の更新が止まり、1 つ目の commit も無いとき) を覆っていないこと (Suggestion) だけである。

## 照合した規約

- ソースコメント規約 (`kasane/handbook/cross/comment-policy.md`) — always。今回のサイクルではコードの変更が無い。`scripts/comment-policy-lint.py` の違反なし (検査対象 501 ファイル) で、前回の照合から変わらないことを確かめた
- 利用者向け Skill の追従 (`kasane/handbook/cross/user-skill-refresh.md`) — 修正が Skill の本文・ひな形・草稿だけに当たるため。今の文書と草稿の差は、proposal の What Changes で蒸留時に反映と合意済み。草稿の節の名前と、Skill・ひな形が指す名前の一致を見た
- 検証 CI (`kasane/handbook/cross/verification-ci.md`) — `scripts/ci/` の検査が今回も通ることの確認
- テスト実行規約 (`kasane/handbook/cross/test-execution.md`) — テストを実行・報告するため

ロードしたスキル: なし (パッケージの解決どおり。config の `skills.code-review` は空、diff は cross ドメインのファイルだけ)

関連 ADR: cross/ADR-0005 (accepted)・cross/ADR-0017 (accepted。本変更が supersede する対象で、proposal で合意済み)・cross/ADR-0020 (proposed。本変更の決定。根拠にしていない)

lessons: `kasane/lessons/code-review.md` の L-001 (証跡の値を自前のプローブで再現する) の趣旨で、修正が拠る git のふるまいを clone で再現した。L-002 (動きの過程) は UI の変更が無いので当たらない。

## 確認した観点

**前回の指摘の解消** (正は `second-opinion-code-002.md` の「突き合わせ結果」)

| 前回の指摘 | 直した箇所 | 判定 |
|---|---|---|
| [Minor・相方] 無くなった源泉の渡す先が、道具の出力の欄名 (「掛かっていた 1 枚」) と合わない | `.agents/skills/docs-refresh/SKILL.md:93` (表)・`:54` (確かめるだけの報告)・`:81`・`:98`、`.agents/skills/docs-refresh/references/prompt-rewrite.md:27` | 解消。道具は無くなった源泉に `掛かっていた 1 枚:` を出し (`scripts/docs/skills-refresh.py:351`)、片方だけに掛かる源泉には `describe_pages` が `(ios の Skill だけ)` の形を添える (`scripts/docs/skills_manifest.py:53`〜`:54`)。表の文面はこの出力の形と一致し、iOS だけに掛かっていた源泉を消したときに iOS のワーカーだけへ渡る |
| [Suggestion・相方] 前から stage されている別の作業の変更を commit から外す | `SKILL.md:144`・`:147`、草稿 `drafts/user-skill-refresh.md:107`・`:109` | 解消。使い捨ての clone で、別の作業の変更を 1 つ stage し、もう 1 つを stage せずに残したうえで、`git add -- <Skill の 2 枚>` → `git commit --only -- <2 枚>` → 記録のファイルを書き換えて `git commit --only -- skills/.manifest.json` を流した。2 つの commit はそれぞれ名指ししたパスだけを持ち、別の作業の変更は stage されたまま・作業ツリーに残ったままだった。pre-commit hook (`.githooks/pre-commit` を clone の `.git/hooks/` に写して有効にした) は、どちらの commit でも名指ししたパスの内容だけを検査した。clone は確かめた後に `trash` で消した |
| [Suggestion・ホスト] 範囲の外が残ったまま承認され、範囲の中の直しも無いときに、証跡の置き場が無い | `SKILL.md:138`・`:152`、草稿 `:117` | 解消 (指摘した経路について)。6 でオーナーに見せた内容をその回の証跡とし、commit を作らないことを伝える、と書いた。同じ形の別の経路は下の Suggestion |
| [Suggestion・ホスト] 証跡が修正サイクルに追いついていない。改名した源泉は `record` の後に形を変えて出る | `evidence/refresh-skill-trial.md:139` (「レビューの後の直し」の節)、`SKILL.md:83`、草稿 `:164` | 解消。節の冒頭で、試運転と「Skill の直し」はこの節の直しの前の本文で動いたこと、追従を通しで流し直していないことを明記した。修正サイクル 1 回目の道具の確かめの手順と出力の要点 (`:163` 以降) が記録され、草稿 `:164` の「確かめた」の根拠が辿れるようになった。改名は「無くなった源泉」と「対応の決まっていない源泉」に形を変えて出る、と本文と草稿で書き分けた (前回の再現の結果と一致) |

**修正が新しい問題を持ち込んでいないか**
- [x] 本文の内部の整合 — `:54`・`:81`・`:93`・`:98` の「掛かっていた 1 枚」の扱いがそろっている。`:138` の新しい文と `:152` の「(6 の 2 つ目の箇条)」が対応している。`:144` と `:147` の `--only` が、草稿 `:107`・`:109` と同じ書き方である
- [x] ひな形 — `prompt-rewrite.md:27` の埋め方の説明が、`SKILL.md:93` の表と同じ欄名を使う。ほかの 2 枚のひな形 (`prompt-read-check.md`・`prompt-use-check.md`) は前回から変わっていない
- [x] ワーカーの起動の書き方 — 修正で足された文は git のコマンドと欄名だけで、ワーカーの起動の箇所は増えていない。片方の CLI の語だけの起動の箇所は無い
- [x] 草稿と Skill の節の名前 — Skill とひな形が「」で指すガイドの節 (13 種) と、`prompt-rewrite.md:12` の 5 節、「使わせる確認の進め方」の表の「作業用の写し」「ビルド」「ビルドが落ちたとき」は、草稿にすべて実在する。`prompt-rewrite.md:70` が指す `cross/user-docs-writing.md` の「コード例を確かめる」も、今の handbook に実在する
- [x] 試運転で確かめた Scenario のふるまいの変化 — 3.3 (変わった源泉と本体の commit) は無くなった源泉を含まず、`:54` の直しが当たらない。3.4 (両プラットフォームの 4 枚を直した回) は、`git add` の後に `--only` で名指ししたパスだけを commit するので、作業ツリーに残した Sample の変更が入らない結果は同じ (clone の再現で、stage していない変更が入らないことも確かめた)。3.5 (2) の記録だけの commit は `--only -- skills/.manifest.json` で同じ結果になる。3.5 (1)・(3) と 3.1・3.2 の経路には修正が当たらない
- [x] 凝りすぎ — 修正は 4 件の指摘の箇所に留まる。証跡に足した節は、直しの一覧と道具の確かめの記録だけで、新しい道具・検査・ひな形・試運転は足していない

**仕様充足・テスト・設計品質 (前回からの継続)**
- [x] デルタスペックの Requirement / Scenario — 9 Requirement・35 Scenario を、直した後の行で照合し直した (`verify-003.md`)
- [x] tasks.md — 16 件すべて `[x]`。差分はチェックボックスだけで、前回から変わっていない
- [x] 足場の書き換え — `proposal.md`・`specs/`・`exploration.md` は作業ツリーで未変更 (`git status`)
- [x] deviation.md — 前回から変わっていない (蒸留送り 3 行)。修正は spec からの乖離を作っていない
- [x] テスト — `python3 scripts/ci/run-tests.py` 523 件・失敗 0。`check-project-skills.py .` (違反なし・Skill 1 つ)・`check-skills.py .` (違反なし)・ローカルパス・識別・コメントの 3 つの lint も違反なし。`skills-refresh.py status` は終了コード 0 で「変わった源泉は無い」「公開の宣言の増減は無い」
- [x] 入力検証・機密情報 — 今回の修正は文書だけで、ローカル絶対パス・識別子の混入なし (lint)

## 指摘事項

### 🔵 Suggestion 記録の更新が止まり、1 つ目の commit も無いときも、commit が 1 つもできない

**該当箇所**: `.agents/skills/docs-refresh/SKILL.md:146`・`.agents/skills/docs-refresh/SKILL.md:152`、`drafts/user-skill-refresh.md:116`
**問題点**: `:152` の「commit が 1 つもできないとき (6 の 2 つ目の箇条) は、6 でオーナーに見せた内容が証跡になる」は、前回の指摘の経路 (範囲の外が残ったまま承認され、範囲の中の直しも無い) だけを括弧で名指ししている。同じく commit が 1 つもできない経路に、源泉に commit していない変更があって `record` が止まり (`:146`)、1 枚にも記録の対応表にも直しが無かった (`:144` で 1 つ目の commit を作らない) 場合がある。試運転 3.5 (3) はまさにこの経路だった (`evidence/refresh-skill-trial.md:76`。commit は 0 件)。このとき本文は「伝えて終える」だけで、証跡の扱いを書いていない。記録の commit の ID は更新されないので、次の追従で同じ源泉は再び出る (追従の漏れにはならない) が、その回の判断 (ワーカーが直さないとした理由など) の置き場が本文から読めない。前回の指摘の範囲を超える経路で、修正が持ち込んだ問題ではない (前回のレビューの見落とし)。Scenario「源泉に commit していない変更があると、記録を更新しない」の THEN には掛からない。
**推奨修正**: `:152` の括弧を「(6 の 2 つ目の箇条か、7 の 2 で `record` が止まり、1 の commit も作らなかったとき)」に広げる。草稿 `:116` の表の「源泉に commit していない変更が残っている」の行にも同じ 1 文を足す。草稿の側は蒸留時に直してもよく、これだけのために修正サイクルを回す必要は無い。

## アクションプラン

1. (Suggestion) `SKILL.md:152` の括弧と草稿 `:116` に、`record` が止まって commit が 1 つもできない経路を足す。蒸留時の手入れに回してもよい
