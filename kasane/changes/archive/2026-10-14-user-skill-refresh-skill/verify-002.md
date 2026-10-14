# 一致検証: user-skill-refresh-skill (002 回目)

**日付**: 2026-10-14
**判定**: VALID

修正サイクルの後の再検証。デルタスペック `specs/user-docs-refresh/spec.md` (ADDED 9 Requirement・35 Scenario) と、直した後の実装 (`.agents/skills/docs-refresh/SKILL.md`・`references/` のひな形 3 枚・`.claude/skills/docs-refresh`・`scripts/ci/check-project-skills.py`・`scripts/ci/tests/test_check_project_skills.py`・`AGENTS.md`・`scripts/docs/skills-refresh.py`) を突き合わせた。前回 (`verify-001.md`) から変わったのは `SKILL.md`・`references/prompt-rewrite.md`・草稿 `drafts/user-skill-refresh.md` で、ほかのファイルは前回の検証の後に変わっていない (更新の時刻で確認)。`SKILL.md` の行が移ったので、対応表は直した後の行で書き直した。

照合の仕方は前回と同じ。Skill の挙動の Scenario は、tasks 3.1〜3.6 の合意に従い、「試運転の証跡」(`evidence/refresh-skill-trial.md`) か「本文照合」で照合した。試運転は修正の前の Skill で行ったものなので、修正が試運転の経路に当たる Scenario は、修正がその THEN を変えていないかを本文で確かめ、状態の欄にそう書いた。Skill が名前で指す handbook の節は、草稿を照合の相手にした (蒸留時に反映と合意済み。指す 13 の節はすべて草稿に実在する)。

## 対応表

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **追従の Skill の置き場** | `.agents/skills/docs-refresh/SKILL.md:1`・`.claude/skills/docs-refresh` (→ `../../.agents/skills/docs-refresh`)・`scripts/ci/check-project-skills.py:86` | `scripts/ci/tests/test_check_project_skills.py` | ✅ 一致 |
| Claude Code で名前で呼べる | 同上 | 試運転 3.1。frontmatter は修正で変わっていない | ✅ 一致 |
| codex で名前と説明が分かる | `SKILL.md:3` | 試運転 3.2。説明は修正で変わっていない | ✅ 一致 |
| 今のリポジトリの置き場の形がテストで確かめられる | `scripts/ci/check-project-skills.py:140` | `scripts/ci/tests/test_check_project_skills.py:35`・`:44`・`:51`・`:56` | ✅ 一致 |
| リンクが実体を指していないと、置き場の検査が違反を出す | `scripts/ci/check-project-skills.py:123` (`check_links`)・`:86` | `scripts/ci/tests/test_check_project_skills.py:86`・`:91`・`:97`・`:105`・`:111`・`:145` | ✅ 一致 |
| 名前がディレクトリと違うと、置き場の検査が違反を出す | `scripts/ci/check-project-skills.py:86` (`check_entity`) | `scripts/ci/tests/test_check_project_skills.py:117` (期待値: 名前とディレクトリの名前の食い違いの違反) | ✅ 一致 |
| 追従の Skill の置き場 — Side Effects | 「なし」。検査は読むだけ。テストは一時のディレクトリだけに書く | — | ✅ 一致 |
| **ワーカーの起動の書き方** | `SKILL.md:15`・`:24`・`:62`・`:87`・`:103`・`:107`・`:121`・`:128`・`:137`、`references/prompt-rewrite.md:3`、`references/prompt-read-check.md:3`・`:43`、`references/prompt-use-check.md:3`・`:48` | 本文照合 | ✅ 一致 |
| どちらの CLI で読んでも、器の起動の仕方が分かる | 上の各箇所に器の名前 `ksn-scribe`・Claude Code (Agent ツールの `subagent_type`)・codex (エージェントの名前で spawn) が併記されている。修正で足された `:83`・`:98` は節 3 の冒頭 `:87` の起動の仕方を受けた書き方で、片方の CLI の語だけの起動の箇所は無い | 本文照合 (起動・任せ・渡す・戻すの全行を grep で拾い、器の名前の無い行が節 3 の起動の仕方を受けていることを確認) | ✅ 一致 |
| ワーカーの起動の書き方 — Side Effects | 「なし」 | — | ✅ 一致 |
| **確かめるだけの使い方** | `SKILL.md:38`〜`:56` | 試運転 3.1・3.2・3.3・3.5 (1) | ✅ 一致 |
| 変わっていなければ、追従は要らないと報告する | `SKILL.md:56` | 試運転 3.1・3.2 | ✅ 一致 |
| 変わった源泉があれば、源泉と見直す 1 枚を報告する | `SKILL.md:54` | 試運転 3.3。修正で `:54` に足されたのは、掛からない源泉だけが出たときの添え書きで、ページングの概念の文書 (掛かる源泉) の報告は変わらない | ✅ 一致 |
| 本体のソースを変えた commit があれば、一覧と、人が差分を見る必要を報告する | `SKILL.md:44`〜`:48`・`:55` | 試運転 3.3 | ✅ 一致 |
| 道具が失敗すると、理由を報告し、要らないとは言わない | `SKILL.md:43` | 試運転 3.5 (1) | ✅ 一致 |
| 何も変えない | `SKILL.md:40` | 試運転 3.1・3.2・3.3 | ✅ 一致 |
| (Requires) 道具が成功で終わること — 範囲の外 | `SKILL.md:43` | 試運転 3.5 (1) | ✅ 一致 |
| 確かめるだけの使い方 — Side Effects | 「なし」。流すのは `status` (`--diff` なし) と `git log` だけ | 試運転 3.1 | ✅ 一致 |
| **書き直しの任せ方** | `SKILL.md:58`〜`:103`、`references/prompt-rewrite.md` | 試運転 3.4・3.5 (2) (3)、本文照合 | ✅ 一致 |
| 両プラットフォームに掛かる源泉が変わると、Skill ごとにワーカーへ任せる | `SKILL.md:87`・`:91`〜`:96`・`:99` | 試運転 3.4 の回 1 | ✅ 一致 |
| 片方のプラットフォームにだけ掛かる源泉なら、その Skill だけを任せる | `SKILL.md:93` | 試運転 3.5 (2)・(3) | ✅ 一致 |
| 本体のソースを変えた commit があると、その差分を見させる | `SKILL.md:96`、`references/prompt-rewrite.md:39`〜`:45` | 本文照合 (Android の複数行の宣言)・試運転 3.4 の回 1 (iOS の側) | ✅ 一致 |
| コード例を変えたワーカーは、コンパイルの結果を報告する | `SKILL.md:102`、`references/prompt-rewrite.md:70`・`:78` | 本文照合 | ✅ 一致 |
| ワーカーが決められなかった箇所は、オーナーに諮ってから任せ直す | `SKILL.md:23`・`:100`、`references/prompt-rewrite.md:47`・`:81` | 本文照合 | ✅ 一致 |
| 変わった源泉が無ければ、ワーカーを起動せずに終わる | `SKILL.md:80` | 試運転 3.1。修正で足された `:81`〜`:83` の分岐は、出たものがある場合だけに当たり、この経路は変わらない | ✅ 一致 |
| 器を起動できないと、何も書かずに止まる | `SKILL.md:60`〜`:73` | 本文照合 | ✅ 一致 |
| 道具が失敗すると、何も書かずに止まる | `SKILL.md:79` | 本文照合 | ✅ 一致 |
| (Requires) 器を起動できること・道具が成功で終わること — 範囲の外 | `SKILL.md:64`・`:79` | 上の 2 Scenario | ✅ 一致 |
| 書き直しの任せ方 — Side Effects | 列挙: 見直す 1 枚 (英日) の更新・`skills/.manifest.json` の `sources`・`apiExclusions` の更新。修正で足された経路 (掛からない源泉の名前が変わった・無くなったときに、ワーカー 1 つが `sources` だけを直す。`SKILL.md:83`・`:98`、`prompt-rewrite.md:27`) は `sources` の更新で、列挙に収まる (spec の本文 `:91` の「名前の変わった源泉のパス、無くなった源泉の削除」に当たる)。ひな形の「書いてよいファイル」(`prompt-rewrite.md:55`〜`:63`) は変わっていない | 試運転 3.4、本文照合 | ✅ 一致 |
| **検査とオーナーの承認** | `SKILL.md:105`〜`:115`・`:131`〜`:138` | 試運転 3.4、本文照合 | ✅ 一致 |
| 名前の漏れを確かめられないと、漏れが無いとは扱わない | `SKILL.md:111` | 本文照合 | ✅ 一致 |
| 検査が落ちると、ワーカーに戻す | `SKILL.md:113`・`:115` | 本文照合 | ✅ 一致 |
| 2 回戻しても残る違反は、オーナーに諮る | `SKILL.md:114` | 本文照合 | ✅ 一致 |
| 違反が無くなると、決めたものを見せて止まる | `SKILL.md:115`・`:133`〜`:135` | 試運転 3.4 の回 1。修正で `:115` の見せる条件が「範囲の中の漏れと違反」に絞られたが、範囲の外の違反が無い試運転の経路では同じ | ✅ 一致 |
| 承認されないと、直してから見せ直す | `SKILL.md:137` | 試運転 3.4 の回 2 | ✅ 一致 |
| 検査とオーナーの承認 — Side Effects | 列挙: 見直す 1 枚 (英日) の更新・`apiExclusions` の更新。どちらもワーカーへの戻し (`SKILL.md:110`・`:113`・`:137`) で起き、メインが流す検査はどれも書き換えない。修正で足された「書き換えが無くても 1 と 2 を流す」(`:107`) は検査を流すだけで、状態変更を足さない | 試運転 3.4 の回 2 | ✅ 一致 |
| **配った先を再現した確認の判断** | `SKILL.md:117`〜`:129`、`references/prompt-read-check.md`、`references/prompt-use-check.md` | 試運転 3.4、本文照合 | ✅ 一致 |
| 文の直しだけなら、確認を行わない | `SKILL.md:119` | 試運転 3.4 | ✅ 一致 |
| コードブロックを書き直したら、その 1 枚の確認を行う | `SKILL.md:119`〜`:128`、草稿 `drafts/user-skill-refresh.md:281` (表の 2 行目) | 本文照合 (期待値: 読ませる確認 = iOS の Skill を英日 1 回ずつ、使わせる確認 = 課題 2 (`layout.md`) を iOS で 1 回、指摘を書き直しのワーカーへ) | ✅ 一致 |
| 配った先を再現した確認の判断 — Side Effects | 列挙: 見直す 1 枚 (英日) の更新 (指摘を書き直しのワーカーに戻すとき)。確認のワーカーの書き込みは置き場の中だけで、置き場と写しは確認の後に消す (`SKILL.md:129`) | 本文照合 | ✅ 一致 |
| **追従の範囲** | `SKILL.md:26`・`:101`・`:113`・`:115`・`:133`・`:138`、`references/prompt-rewrite.md:60`〜`:63`・`:82`〜`:83` | 本文照合 | ✅ 一致 |
| README の検査の違反は、ワーカーに戻さずにオーナーに伝える | `SKILL.md:113`・`:115`・`:133`、`references/prompt-rewrite.md:61` | 本文照合。修正で、範囲の外の違反が残ったまま 6 へ進む経路が `:115` に明記され、前回は読み手の判断に残っていた「違反が消えないと 6 へ進めない」矛盾が無くなった | ✅ 一致 |
| 1 枚の追加が要ると報告されたら、構成の見直しとしてオーナーに伝える | `SKILL.md:101`・`:133`、`references/prompt-rewrite.md:63`・`:83` | 本文照合 | ✅ 一致 |
| 範囲の外が残ったまま承認されると、記録の commit の ID を更新しない | `SKILL.md:138` | 本文照合 | ✅ 一致 |
| (Requires) 直しが既存の 1 枚と記録に収まること — 範囲の外 | 上の 2 Scenario | 本文照合 | ✅ 一致 |
| 追従の範囲 — Side Effects | 「なし」(範囲の中の commit は次の Requirement で数える) | — | ✅ 一致 |
| **承認の後の commit と記録の更新** | `SKILL.md:140`〜`:168` | 試運転 3.4・3.5 | ✅ 一致 |
| 承認の後、2 つの commit ができ、追従は要らない状態になる | `SKILL.md:144`〜`:148` | 試運転 3.4 の回 3。1 枚を直した回は、修正の後も `:144` の 1 つ目の commit を作る側に入る | ✅ 一致 |
| 直す 1 枚が無かったときは、記録の commit だけを作る | `SKILL.md:144`・`:152` | 試運転 3.5 (2)。修正で、1 つ目の commit を省く条件が「1 枚にも記録の `sources`・`apiExclusions` にも変更が無いとき」になった。spec の本文 (`spec.md:226`) は「追従で変えたファイル (利用者向け Skill の 1 枚と、記録の `sources`・`apiExclusions`) が無いとき」としており、修正の後の本文と一致する (修正の前は記録の対応表だけを直した場合を取りこぼしていた)。試運転 3.5 (2) は 1 枚も記録も直さなかった回なので、修正の後も記録の commit だけができる | ✅ 一致 |
| 源泉に commit していない変更があると、記録を更新しない | `SKILL.md:146` | 試運転 3.5 (3) | ✅ 一致 |
| 追従で変えていないファイルは commit しない | `SKILL.md:144` (パスを名指しして `git add`) | 試運転 3.4 | ✅ 一致 |
| push しない | `SKILL.md:27`・`:150` | 試運転 (`git push` の呼び出し 0) | ✅ 一致 |
| (Requires) 源泉のパスに commit していない変更が無いこと — 範囲の外 | `SKILL.md:146` | 試運転 3.5 (3) | ✅ 一致 |
| 承認の後の commit と記録の更新 — Side Effects | 列挙: git の履歴の commit 2 種・記録の `syncedCommit` の更新。修正で、記録の対応表だけを直したときも 1 つ目の commit を作るようになったが、これは列挙の「追従で変えたファイルの commit」に当たる。push しない | 試運転 3.4、本文照合 | ✅ 一致 |
| **追従の入口の案内** | `AGENTS.md:15`〜`:18` | 本文照合 | ✅ 一致 |
| AGENTS.md から追従の入口が分かる | `AGENTS.md:17`・`:18` | 本文照合 | ✅ 一致 |
| 追従の入口の案内 — Side Effects | 「なし」 | — | ✅ 一致 |

## 追加検査

- [x] tasks.md: 16 件すべて `[x]`。差分はチェックボックスだけで、前回の検証から変わっていない。各タスクの成果物は実在する
- [x] 逆流検査: `proposal.md`・`specs/`・`exploration.md` は、提案の commit (`ba2e36b`) の後に変更が無い (`git status` で未変更)
- [x] 未記録乖離: ❌ は無い。deviation.md は前回から変わらず蒸留送り 3 行だけで、修正は spec からの乖離を作っていない (修正の前の本文の取りこぼしを、spec の本文に合わせて直したもの)
- [x] Side Effects: 全 9 Requirement に契約の欄があり、修正で足された経路 (ワーカーによる `sources` だけの直し・記録の対応表だけの 1 つ目の commit・書き換えが無いときの検査) を含め、状態変更が列挙に収まることを各 `— Side Effects` の行で確かめた
- [x] 付随修正: `[付随修正]` の行は無い。diff の中で Scenario に対応しない変更は、前回と同じく `scripts/docs/skills-refresh.py` の冒頭の説明だけ (proposal の What Changes・tasks 2.3)
- [x] UI 変更: 該当なし
- [x] テスト: `python3 scripts/ci/run-tests.py` 523 件・失敗 0 を自分で流した。`check-project-skills.py .` (違反なし)・`check-skills.py .`・3 つの lint も通った
- [x] 修正が拠る道具のふるまい: 本リポジトリの使い捨ての clone で、(1) `excluded` の源泉を消して `record` だけを流すと次の `status` にも「無くなった源泉」が出ること、(2) `skills/.manifest.json` だけに commit していない変更があるとき `record` が止まらずに書き換えることを再現した。clone は確かめた後に `trash` で消し、本リポジトリの作業ツリーと HEAD は変わっていない

## 判定

VALID。全 35 Scenario と 9 Requirement の Side Effects の行が「✅ 一致」で、虚偽チェック・逆流・テスト失敗は無い。修正は、試運転で確かめた Scenario の THEN を変えていない。

補足 (判定に影響しない): 証跡 `evidence/refresh-skill-trial.md` は修正の前の状態のままで、レビューの後の直しが試運転の後に入ったことが読めない。`review-002.md` の Suggestion に挙げた。
