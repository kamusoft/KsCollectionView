# 一致検証: user-skill-refresh-skill (003 回目)

**日付**: 2026-10-14
**判定**: VALID

修正サイクル 2 回目の後の再検証。デルタスペック `specs/user-docs-refresh/spec.md` (ADDED 9 Requirement・35 Scenario) と、直した後の実装を突き合わせた。前回 (`verify-002.md`) の後に変わったのは `.agents/skills/docs-refresh/SKILL.md`・`references/prompt-rewrite.md`・草稿 `drafts/user-skill-refresh.md`・証跡 `evidence/refresh-skill-trial.md` で、ほかのファイル (`prompt-read-check.md`・`prompt-use-check.md`・`.claude/skills/docs-refresh`・`scripts/ci/check-project-skills.py`・`scripts/ci/tests/test_check_project_skills.py`・`AGENTS.md`・`scripts/docs/skills-refresh.py`・`tasks.md`・`deviation.md`) は前回の検証の後に変わっていない (更新の時刻で確認)。修正は行の中の書き足しで、`SKILL.md` の行番号は前回から移っていない。

照合の仕方は前回と同じ。Skill の挙動の Scenario は、tasks 3.1〜3.6 の合意に従い、「試運転の証跡」(`evidence/refresh-skill-trial.md`) か「本文照合」で照合した。試運転は修正の前の Skill で行ったものなので、修正が試運転の経路に当たる Scenario は、修正がその THEN を変えていないかを本文で確かめ、必要なものは使い捨ての clone で再現した。Skill が名前で指す handbook の節は、草稿を照合の相手にした (蒸留時に反映と合意済み。指す 13 の節はすべて草稿に実在する)。

## 対応表

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **追従の Skill の置き場** | `.agents/skills/docs-refresh/SKILL.md:1`・`.claude/skills/docs-refresh` (→ `../../.agents/skills/docs-refresh`)・`scripts/ci/check-project-skills.py:86` | `scripts/ci/tests/test_check_project_skills.py` | ✅ 一致 |
| Claude Code で名前で呼べる | 同上 | 試運転 3.1。frontmatter は修正で変わっていない | ✅ 一致 |
| codex で名前と説明が分かる | `SKILL.md:3` | 試運転 3.2。説明は修正で変わっていない | ✅ 一致 |
| 今のリポジトリの置き場の形がテストで確かめられる | `scripts/ci/check-project-skills.py:140` | `scripts/ci/tests/test_check_project_skills.py:35`・`:44`・`:51`・`:56`。`check-project-skills.py .` も違反なし (Skill 1 つ) | ✅ 一致 |
| リンクが実体を指していないと、置き場の検査が違反を出す | `scripts/ci/check-project-skills.py:123` (`check_links`)・`:86` | `scripts/ci/tests/test_check_project_skills.py:86`・`:91`・`:97`・`:105`・`:111`・`:145` | ✅ 一致 |
| 名前がディレクトリと違うと、置き場の検査が違反を出す | `scripts/ci/check-project-skills.py:86` (`check_entity`) | `scripts/ci/tests/test_check_project_skills.py:117` (期待値: 名前とディレクトリの名前の食い違いの違反) | ✅ 一致 |
| 追従の Skill の置き場 — Side Effects | 「なし」。検査は読むだけ。テストは一時のディレクトリだけに書く | — | ✅ 一致 |
| **ワーカーの起動の書き方** | `SKILL.md:15`・`:24`・`:62`・`:87`・`:103`・`:107`・`:121`・`:128`・`:137`、`references/prompt-rewrite.md:3`、`references/prompt-read-check.md:3`・`:43`、`references/prompt-use-check.md:3`・`:48` | 本文照合 | ✅ 一致 |
| どちらの CLI で読んでも、器の起動の仕方が分かる | 上の各箇所に器の名前 `ksn-scribe`・Claude Code (Agent ツールの `subagent_type`)・codex (エージェントの名前で spawn) が併記されている。今回の修正 (`:54`・`:93`・`:138`・`:144`・`:147`・`:152`、`prompt-rewrite.md:27`) は欄名と git のコマンドの書き足しで、ワーカーの起動の箇所を増やしていない | 本文照合 | ✅ 一致 |
| ワーカーの起動の書き方 — Side Effects | 「なし」 | — | ✅ 一致 |
| **確かめるだけの使い方** | `SKILL.md:38`〜`:56` | 試運転 3.1・3.2・3.3・3.5 (1) | ✅ 一致 |
| 変わっていなければ、追従は要らないと報告する | `SKILL.md:56` | 試運転 3.1・3.2。本リポジトリで `skills-refresh.py status` を流し、終了コード 0 で「変わった源泉は無い」「公開の宣言の増減は無い」と出ることを確かめた | ✅ 一致 |
| 変わった源泉があれば、源泉と見直す 1 枚を報告する | `SKILL.md:54` | 試運転 3.3。修正で `:54` に足されたのは、無くなった源泉は「掛かっていた 1 枚」で並べる、という欄名の揃えで、変わった源泉 (ページングの概念の文書) の報告は変わらない | ✅ 一致 |
| 本体のソースを変えた commit があれば、一覧と、人が差分を見る必要を報告する | `SKILL.md:44`〜`:48`・`:55` | 試運転 3.3 | ✅ 一致 |
| 道具が失敗すると、理由を報告し、要らないとは言わない | `SKILL.md:43` | 試運転 3.5 (1) | ✅ 一致 |
| 何も変えない | `SKILL.md:40` | 試運転 3.1・3.2・3.3 | ✅ 一致 |
| (Requires) 道具が成功で終わること — 範囲の外 | `SKILL.md:43` | 試運転 3.5 (1) | ✅ 一致 |
| 確かめるだけの使い方 — Side Effects | 「なし」。流すのは `status` (`--diff` なし) と `git log` だけ | 試運転 3.1 | ✅ 一致 |
| **書き直しの任せ方** | `SKILL.md:58`〜`:103`、`references/prompt-rewrite.md` | 試運転 3.4・3.5 (2) (3)、本文照合 | ✅ 一致 |
| 両プラットフォームに掛かる源泉が変わると、Skill ごとにワーカーへ任せる | `SKILL.md:87`・`:91`〜`:96`・`:99` | 試運転 3.4 の回 1 | ✅ 一致 |
| 片方のプラットフォームにだけ掛かる源泉なら、その Skill だけを任せる | `SKILL.md:93` (無くなった源泉は「掛かっていた 1 枚」で判定) | 試運転 3.5 (2)・(3)。表の文面が道具の出力 (`scripts/docs/skills-refresh.py:331`・`:345`・`:351`、`scripts/docs/skills_manifest.py:53`〜`:54` の `(ios の Skill だけ)` の形) と一致することを本文照合した (期待値: iOS だけに掛かっていた源泉が消えたら iOS のワーカーだけ) | ✅ 一致 |
| 本体のソースを変えた commit があると、その差分を見させる | `SKILL.md:96`、`references/prompt-rewrite.md:39`〜`:45` | 本文照合 (Android の複数行の宣言)・試運転 3.4 の回 1 (iOS の側) | ✅ 一致 |
| コード例を変えたワーカーは、コンパイルの結果を報告する | `SKILL.md:102`、`references/prompt-rewrite.md:70`・`:78` | 本文照合 | ✅ 一致 |
| ワーカーが決められなかった箇所は、オーナーに諮ってから任せ直す | `SKILL.md:23`・`:100`、`references/prompt-rewrite.md:47`・`:81` | 本文照合 | ✅ 一致 |
| 変わった源泉が無ければ、ワーカーを起動せずに終わる | `SKILL.md:80` | 試運転 3.1。今回の修正はこの経路に当たらない | ✅ 一致 |
| 器を起動できないと、何も書かずに止まる | `SKILL.md:60`〜`:73` | 本文照合 | ✅ 一致 |
| 道具が失敗すると、何も書かずに止まる | `SKILL.md:79` | 本文照合 | ✅ 一致 |
| (Requires) 器を起動できること・道具が成功で終わること — 範囲の外 | `SKILL.md:64`・`:79` | 上の 2 Scenario | ✅ 一致 |
| 書き直しの任せ方 — Side Effects | 列挙: 見直す 1 枚 (英日) の更新・`skills/.manifest.json` の `sources`・`apiExclusions` の更新。今回の修正は渡す先の判定の欄名だけで、ワーカーが書くファイル (`prompt-rewrite.md:55`〜`:63`) は変わっていない | 試運転 3.4、本文照合 | ✅ 一致 |
| **検査とオーナーの承認** | `SKILL.md:105`〜`:115`・`:131`〜`:138` | 試運転 3.4、本文照合 | ✅ 一致 |
| 名前の漏れを確かめられないと、漏れが無いとは扱わない | `SKILL.md:111` | 本文照合 | ✅ 一致 |
| 検査が落ちると、ワーカーに戻す | `SKILL.md:113`・`:115` | 本文照合 | ✅ 一致 |
| 2 回戻しても残る違反は、オーナーに諮る | `SKILL.md:114` | 本文照合 | ✅ 一致 |
| 違反が無くなると、決めたものを見せて止まる | `SKILL.md:115`・`:133`〜`:135` | 試運転 3.4 の回 1 | ✅ 一致 |
| 承認されないと、直してから見せ直す | `SKILL.md:137` | 試運転 3.4 の回 2 | ✅ 一致 |
| 検査とオーナーの承認 — Side Effects | 列挙: 見直す 1 枚 (英日) の更新・`apiExclusions` の更新。どちらもワーカーへの戻し (`SKILL.md:110`・`:113`・`:137`) で起きる。`:138` に足された文は「commit を作らないことを伝える」で、状態変更を足さない | 試運転 3.4 の回 2 | ✅ 一致 |
| **配った先を再現した確認の判断** | `SKILL.md:117`〜`:129`、`references/prompt-read-check.md`、`references/prompt-use-check.md` | 試運転 3.4、本文照合 | ✅ 一致 |
| 文の直しだけなら、確認を行わない | `SKILL.md:119` | 試運転 3.4 | ✅ 一致 |
| コードブロックを書き直したら、その 1 枚の確認を行う | `SKILL.md:119`〜`:128`、草稿 `drafts/user-skill-refresh.md:281` (表の 2 行目) | 本文照合 (期待値: 読ませる確認 = iOS の Skill を英日 1 回ずつ、使わせる確認 = 課題 2 (`layout.md`) を iOS で 1 回、指摘を書き直しのワーカーへ) | ✅ 一致 |
| 配った先を再現した確認の判断 — Side Effects | 列挙: 見直す 1 枚 (英日) の更新 (指摘を書き直しのワーカーに戻すとき)。確認のワーカーの書き込みは置き場の中だけで、置き場と写しは確認の後に消す (`SKILL.md:129`) | 本文照合 | ✅ 一致 |
| **追従の範囲** | `SKILL.md:26`・`:101`・`:113`・`:115`・`:133`・`:138`、`references/prompt-rewrite.md:60`〜`:63`・`:82`〜`:83` | 本文照合 | ✅ 一致 |
| README の検査の違反は、ワーカーに戻さずにオーナーに伝える | `SKILL.md:113`・`:115`・`:133`、`references/prompt-rewrite.md:61` | 本文照合 | ✅ 一致 |
| 1 枚の追加が要ると報告されたら、構成の見直しとしてオーナーに伝える | `SKILL.md:101`・`:133`、`references/prompt-rewrite.md:63`・`:83` | 本文照合 | ✅ 一致 |
| 範囲の外が残ったまま承認されると、記録の commit の ID を更新しない | `SKILL.md:138` | 本文照合。修正で、範囲の中の直しも無く commit が 1 つもできないときの扱い (6 で見せた内容を証跡にし、commit を作らないことを伝える) が足された。THEN (範囲の中の直しを commit し、記録の commit の ID を更新せず、理由を伝える) は変わらない | ✅ 一致 |
| (Requires) 直しが既存の 1 枚と記録に収まること — 範囲の外 | 上の 2 Scenario | 本文照合 | ✅ 一致 |
| 追従の範囲 — Side Effects | 「なし」(範囲の中の commit は次の Requirement で数える) | — | ✅ 一致 |
| **承認の後の commit と記録の更新** | `SKILL.md:140`〜`:168` | 試運転 3.4・3.5、clone での再現 | ✅ 一致 |
| 承認の後、2 つの commit ができ、追従は要らない状態になる | `SKILL.md:144`〜`:148` | 試運転 3.4 の回 3。修正で commit の手順が `git add` → `git commit --only -- <パス…>` になった。clone で同じ手順を流し、1 つ目の commit が名指しした 2 枚だけ、2 つ目の commit が `skills/.manifest.json` だけを持つことを確かめた | ✅ 一致 |
| 直す 1 枚が無かったときは、記録の commit だけを作る | `SKILL.md:144`・`:152` | 試運転 3.5 (2)。記録だけの commit は `git commit --only -- skills/.manifest.json` で、clone の再現で記録のファイルだけが入ることを確かめた | ✅ 一致 |
| 源泉に commit していない変更があると、記録を更新しない | `SKILL.md:146` | 試運転 3.5 (3) | ✅ 一致 |
| 追従で変えていないファイルは commit しない | `SKILL.md:144` (パスを名指しして `git add` し、`git commit --only -- <パス…>`)・`:147` | 試運転 3.4 (stage していない Sample の変更)。clone で、別の作業の変更を 1 つ stage し、1 つを stage せずに残したうえで 2 つの commit を作り、どちらの変更もどちらの commit にも入らず、stage された変更は stage されたまま残ることを確かめた (期待値: 2 つの commit の変更のファイルは名指しのパスだけ、`git status --porcelain` は commit の前の別の作業の 2 行のまま) | ✅ 一致 |
| push しない | `SKILL.md:27`・`:150` | 試運転 (`git push` の呼び出し 0) | ✅ 一致 |
| (Requires) 源泉のパスに commit していない変更が無いこと — 範囲の外 | `SKILL.md:146` | 試運転 3.5 (3) | ✅ 一致 |
| 承認の後の commit と記録の更新 — Side Effects | 列挙: git の履歴の commit 2 種・記録の `syncedCommit` の更新。`--only` は commit に入るパスを狭めるだけで、状態変更を足さない (index の別の作業の stage は、clone の再現で前と同じに残った)。push しない | 試運転 3.4、clone での再現、本文照合 | ✅ 一致 |
| **追従の入口の案内** | `AGENTS.md:15`〜`:18` | 本文照合 | ✅ 一致 |
| AGENTS.md から追従の入口が分かる | `AGENTS.md:17`・`:18` | 本文照合 | ✅ 一致 |
| 追従の入口の案内 — Side Effects | 「なし」 | — | ✅ 一致 |

## 追加検査

- [x] tasks.md: 16 件すべて `[x]`。差分はチェックボックスだけで、前回の検証から変わっていない。各タスクの成果物は実在する
- [x] 逆流検査: `proposal.md`・`specs/`・`exploration.md` は、提案の commit (`ba2e36b`) の後に変更が無い (`git status` で未変更)
- [x] 未記録乖離: ❌ は無い。deviation.md は前回から変わらず蒸留送り 3 行だけで、今回の修正は spec からの乖離を作っていない
- [x] Side Effects: 全 9 Requirement に契約の欄があり、今回の修正 (欄名の揃え・`--only` による commit の対象の限定・commit が 1 つもできないときの証跡の扱い) を含め、状態変更が列挙に収まることを各 `— Side Effects` の行で確かめた
- [x] 付随修正: `[付随修正]` の行は無い。diff の中で Scenario に対応しない変更は、前回と同じく `scripts/docs/skills-refresh.py` の冒頭の説明だけ (proposal の What Changes・tasks 2.3)
- [x] UI 変更: 該当なし
- [x] テスト: `python3 scripts/ci/run-tests.py` 523 件・失敗 0 を自分で流した。`check-project-skills.py .`・`check-skills.py .`・ローカルパス・識別・コメントの 3 つの lint も違反なし
- [x] 修正が拠る git のふるまい: 本リポジトリの使い捨ての clone (scratchpad の下。remote を外し、`.githooks/pre-commit` を clone の `.git/hooks/` に写して有効にした) で、`SKILL.md:144`・`:147` の手順を流した。名指ししたパスだけが commit に入り、前から stage されていた別の作業の変更と、stage していない変更は残った。pre-commit hook の検査も名指ししたパスの内容だけに掛かった。clone は確かめた後に `trash` で消し、本リポジトリの作業ツリーと HEAD は変わっていない

## 判定

VALID。全 35 Scenario と 9 Requirement の Side Effects の行が「✅ 一致」で、虚偽チェック・逆流・テスト失敗は無い。今回の修正は、試運転で確かめた Scenario の THEN を変えていない。

補足 (判定に影響しない): `SKILL.md:152` の証跡の置き場の文は、`record` が止まって commit が 1 つもできない経路 (試運転 3.5 (3) の形) を名指ししていない。Scenario「源泉に commit していない変更があると、記録を更新しない」の THEN には掛からない。`review-003.md` の Suggestion に挙げた。
