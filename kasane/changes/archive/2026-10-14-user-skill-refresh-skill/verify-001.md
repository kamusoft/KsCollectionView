# 一致検証: user-skill-refresh-skill (001 回目)

**日付**: 2026-10-14
**判定**: VALID

デルタスペック `specs/user-docs-refresh/spec.md` (ADDED 9 Requirement・35 Scenario) と、実装 (`.agents/skills/docs-refresh/`・`.claude/skills/docs-refresh`・`scripts/ci/check-project-skills.py`・`scripts/ci/tests/test_check_project_skills.py`・`AGENTS.md`・`scripts/docs/skills-refresh.py`) を突き合わせた。

この変更の実装の大半は、エージェントが読んで従う Skill の本文 (プロンプト) で、単体テストで表せない。tasks 3.1〜3.6 の合意に従い、Skill の挙動の Scenario は「試運転の証跡」(`evidence/refresh-skill-trial.md`) か「本文の突き合わせ」で照合した。テスト列の `試運転 3.x` は証跡の節、`本文照合` は本文とひな形の該当の箇所を、Scenario の GIVEN/WHEN/THEN と 1 つずつ読み合わせたことを表す。Skill が名前で指す handbook の節 (「追従の範囲」「追従の証跡」など) は今の handbook に無く、草稿 `drafts/user-skill-refresh.md` にある。handbook の改訂は proposal の What Changes で蒸留時に反映と合意済みなので、草稿を照合の相手にした (指す節の名前は草稿にすべて実在する)。

## 対応表

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **追従の Skill の置き場** | `.agents/skills/docs-refresh/SKILL.md:1`・`.claude/skills/docs-refresh` (→ `../../.agents/skills/docs-refresh`)・`scripts/ci/check-project-skills.py:86` | `scripts/ci/tests/test_check_project_skills.py` | ✅ 一致 |
| Claude Code で名前で呼べる | 同上 | 試運転 3.1 (`/docs-refresh check`・`refresh` で本文が読み込まれ、本文の進め方で動いた) | ✅ 一致 |
| codex で名前と説明が分かる | `.agents/skills/docs-refresh/SKILL.md:3` | 試運転 3.2 (説明の並べ替えの後に、名前と説明が出た) | ✅ 一致 |
| 今のリポジトリの置き場の形がテストで確かめられる | `scripts/ci/check-project-skills.py:140` | `scripts/ci/tests/test_check_project_skills.py:35`・`:44`・`:51`・`:56` (リンクであること・相対・実体を指す・リンク越しに SKILL.md が読める・name の一致) | ✅ 一致 |
| リンクが実体を指していないと、置き場の検査が違反を出す | `scripts/ci/check-project-skills.py:108` | `scripts/ci/tests/test_check_project_skills.py:86` (無い)・`:91` (リンクでない)・`:97` (別の場所)・`:105`・`:111`。違反の文言で、どの形が崩れているかを確かめている | ✅ 一致 |
| 名前がディレクトリと違うと、置き場の検査が違反を出す | `scripts/ci/check-project-skills.py:100` | `scripts/ci/tests/test_check_project_skills.py:117` (期待値: `name (skills-refresh) が、ディレクトリの名前 (docs-refresh) と違う`) | ✅ 一致 |
| 追従の Skill の置き場 — Side Effects | 「なし」。検査は読むだけで書き換えない (`scripts/ci/check-project-skills.py:9`)。テストは一時のディレクトリだけに書く | — | ✅ 一致 |
| **ワーカーの起動の書き方** | `.agents/skills/docs-refresh/SKILL.md:15`・`:24`・`:62`・`:85`・`:100`・`:104`・`:118`・`:125`・`:134`、`references/prompt-rewrite.md:3`、`references/prompt-read-check.md:3`・`:43`、`references/prompt-use-check.md:3`・`:48` | 本文照合 | ✅ 一致 |
| どちらの CLI で読んでも、器の起動の仕方が分かる | 上の各箇所に、器の名前 `ksn-scribe`・Claude Code (Agent ツールの `subagent_type`)・codex (エージェントの名前で spawn) が併記されている。片方の CLI の語だけの起動の箇所は無い | 本文照合 (起動・戻し・任せ直しの全箇所を grep で拾って確認) | ✅ 一致 |
| ワーカーの起動の書き方 — Side Effects | 「なし」。文面の要件で、状態変更を伴わない | — | ✅ 一致 |
| **確かめるだけの使い方** | `.agents/skills/docs-refresh/SKILL.md:38`〜`:56` | 試運転 3.1・3.2・3.3・3.5 (1) | ✅ 一致 |
| 変わっていなければ、追従は要らないと報告する | `SKILL.md:56` | 試運転 3.1・3.2 | ✅ 一致 |
| 変わった源泉があれば、源泉と見直す 1 枚を報告する | `SKILL.md:54` | 試運転 3.3 の 2 行目 (`collection-paging.md` と、両プラットフォームの `references/paging.md`) | ✅ 一致 |
| 本体のソースを変えた commit があれば、一覧と、人が差分を見る必要を報告する | `SKILL.md:44`〜`:48`・`:55` | 試運転 3.3 の 1 行目 (commit の一覧と、人が差分を見る必要。差分の本文は開いていない) | ✅ 一致 |
| 道具が失敗すると、理由を報告し、要らないとは言わない | `SKILL.md:43` | 試運転 3.5 (1) | ✅ 一致 |
| 何も変えない | `SKILL.md:40` | 試運転 3.1・3.2 (本リポジトリで `git status --porcelain`・HEAD・記録の sha1 が前後で同じ)・3.3 (変わった源泉がある写しで HEAD と作業ツリーが変わらない。ワーカー 0) | ✅ 一致 |
| (Requires) 道具が成功で終わること — 範囲の外 | `SKILL.md:43` (0 で終わらなければ理由を報告して終える) | 試運転 3.5 (1) | ✅ 一致 |
| 確かめるだけの使い方 — Side Effects | 「なし」。流すのは `status` (`--diff` なし) と `git log` だけ | 試運転 3.1 (道具の呼び出しが 2 つだけ) | ✅ 一致 |
| **書き直しの任せ方** | `SKILL.md:58`〜`:100`、`references/prompt-rewrite.md` | 試運転 3.4・3.5 (2) (3)、本文照合 | ✅ 一致 |
| 両プラットフォームに掛かる源泉が変わると、Skill ごとにワーカーへ任せる | `SKILL.md:85`・`:89`〜`:96` | 試運転 3.4 の回 1 (iOS 1・Android 1 を順に起動) | ✅ 一致 |
| 片方のプラットフォームにだけ掛かる源泉なら、その Skill だけを任せる | `SKILL.md:91` | 試運転 3.5 (2) (iOS だけ)・(3) (Android だけ) | ✅ 一致 |
| 本体のソースを変えた commit があると、その差分を見させる | `SKILL.md:94`、`references/prompt-rewrite.md:39`〜`:45` | 本文照合 (Android の複数行の宣言)。iOS の側は試運転 3.4 の回 1 で、`git diff <記録の commit> -- ios/Sources` を渡したことを確認 | ✅ 一致 |
| コード例を変えたワーカーは、コンパイルの結果を報告する | `SKILL.md:99`、`references/prompt-rewrite.md:70`・`:78` | 本文照合 | ✅ 一致 |
| ワーカーが決められなかった箇所は、オーナーに諮ってから任せ直す | `SKILL.md:23`・`:97`、`references/prompt-rewrite.md:47`・`:81` | 本文照合 | ✅ 一致 |
| 変わった源泉が無ければ、ワーカーを起動せずに終わる | `SKILL.md:80` | 試運転 3.1 (`refresh` でワーカー 0) | ✅ 一致 |
| 器を起動できないと、何も書かずに止まる | `SKILL.md:60`〜`:73` (止まる・代わりに書かない・器を指定しない起動をしない・`scripts/deploy.sh` の案内) | 本文照合 | ✅ 一致 |
| 道具が失敗すると、何も書かずに止まる | `SKILL.md:79` | 本文照合 (確かめるだけの使い方での失敗は試運転 3.5 (1)) | ✅ 一致 |
| (Requires) 器を起動できること・道具が成功で終わること — 範囲の外 | `SKILL.md:64`・`:79` | 上の 2 Scenario | ✅ 一致 |
| 書き直しの任せ方 — Side Effects | 列挙: 見直す 1 枚 (英日) の更新・`skills/.manifest.json` の `sources`・`apiExclusions` の更新。ひな形の「書いてよいファイル」(`references/prompt-rewrite.md:55`〜`:63`) がこの 2 つに限り、git の操作と `record` を禁じている (`:16`〜`:17`)。コード例のコンパイルの置き場はリポジトリの外で、使い終わったら消す (残らない) | 試運転 3.4 (書き換わったのは 4 枚の `references/paging.md` だけ) | ✅ 一致 |
| **検査とオーナーの承認** | `SKILL.md:102`〜`:112`・`:128`〜`:135` | 試運転 3.4、本文照合 | ✅ 一致 |
| 名前の漏れを確かめられないと、漏れが無いとは扱わない | `SKILL.md:108` (終了コード 3) | 本文照合 | ✅ 一致 |
| 検査が落ちると、ワーカーに戻す | `SKILL.md:110`・`:112` | 本文照合 | ✅ 一致 |
| 2 回戻しても残る違反は、オーナーに諮る | `SKILL.md:111` | 本文照合 | ✅ 一致 |
| 違反が無くなると、決めたものを見せて止まる | `SKILL.md:112`・`:130`〜`:132` | 試運転 3.4 の回 1 (見せて止まり、commit も記録の更新もしていない) | ✅ 一致 |
| 承認されないと、直してから見せ直す | `SKILL.md:134` | 試運転 3.4 の回 2 | ✅ 一致 |
| 検査とオーナーの承認 — Side Effects | 列挙: 見直す 1 枚 (英日) の更新・`apiExclusions` の更新。どちらもワーカーへの戻し・任せ直し (`SKILL.md:107`・`:110`・`:134`) で起き、範囲はひな形の「書いてよいファイル」に限られる。メインが流す検査はどれも書き換えない | 試運転 3.4 の回 2 | ✅ 一致 |
| **配った先を再現した確認の判断** | `SKILL.md:114`〜`:126`、`references/prompt-read-check.md`、`references/prompt-use-check.md` | 試運転 3.4、本文照合 | ✅ 一致 |
| 文の直しだけなら、確認を行わない | `SKILL.md:116` (回数 0 でも当てた行と理由を見せる) | 試運転 3.4 (「文の直し」の行で 0 回とし、見せた) | ✅ 一致 |
| コードブロックを書き直したら、その 1 枚の確認を行う | `SKILL.md:116`〜`:125`、草稿 `drafts/user-skill-refresh.md:276` (表の 2 行目) | 本文照合 (期待値: 読ませる確認 = iOS の Skill を英日 1 回ずつ、使わせる確認 = 並べ方の 1 枚に当たる課題 (「5 つの課題」の表) を iOS で 1 回、指摘を書き直しのワーカーへ) | ✅ 一致 |
| 配った先を再現した確認の判断 — Side Effects | 列挙: 見直す 1 枚 (英日) の更新 (指摘を書き直しのワーカーに戻すとき)。確認のワーカーはファイルを書かない (`prompt-read-check.md:19`)、または置き場の中に 1 つ書くだけ (`prompt-use-check.md:18`)。置き場と作業用の写しはリポジトリの外で、確認の後に消す (`SKILL.md:126`) | 本文照合 | ✅ 一致 |
| **追従の範囲** | `SKILL.md:26`・`:98`・`:110`・`:130`・`:135`、`references/prompt-rewrite.md:60`〜`:63`・`:82`〜`:83` | 本文照合 | ✅ 一致 |
| README の検査の違反は、ワーカーに戻さずにオーナーに伝える | `SKILL.md:110`・`:130`、`references/prompt-rewrite.md:61` | 本文照合 | ✅ 一致 |
| 1 枚の追加が要ると報告されたら、構成の見直しとしてオーナーに伝える | `SKILL.md:98`・`:130` (「変更の実装で行う必要」)、`references/prompt-rewrite.md:63`・`:83` | 本文照合 (試運転の中の Skill の直し 2 の後) | ✅ 一致 |
| 範囲の外が残ったまま承認されると、記録の commit の ID を更新しない | `SKILL.md:135` | 本文照合 | ✅ 一致 |
| (Requires) 直しが既存の 1 枚と記録に収まること — 範囲の外 | 上の 2 Scenario (範囲の外と構成の見直しは書かずにオーナーへ) | 本文照合 | ✅ 一致 |
| 追従の範囲 — Side Effects | 「なし」(範囲の中の commit は次の Requirement で数える)。この Requirement が起こす動きは、オーナーへの報告と、ワーカーに書かせないことだけ | — | ✅ 一致 |
| **承認の後の commit と記録の更新** | `SKILL.md:137`〜`:165` | 試運転 3.4・3.5 | ✅ 一致 |
| 承認の後、2 つの commit ができ、追従は要らない状態になる | `SKILL.md:141`〜`:145` | 試運転 3.4 の回 3 (`cc8f932`・`31390ab`、その後の `check` で変わった源泉なし) | ✅ 一致 |
| 直す 1 枚が無かったときは、記録の commit だけを作る | `SKILL.md:141`・`:149` | 試運転 3.5 (2) (`16ef6ee` のみ。メッセージに扱った源泉と直さなかった理由) | ✅ 一致 |
| 源泉に commit していない変更があると、記録を更新しない | `SKILL.md:143` | 試運転 3.5 (3) (`record` が終了コード 1、記録・HEAD 不変、源泉を commit しない) | ✅ 一致 |
| 追従で変えていないファイルは commit しない | `SKILL.md:141` (パスを名指しして `git add`) | 試運転 3.4 (Sample の変更が作業ツリーに残り、どちらの commit にも入らない) | ✅ 一致 |
| push しない | `SKILL.md:27`・`:147` | 試運転 (17 回の実行記録で `git push` の呼び出し 0) | ✅ 一致 |
| (Requires) 源泉のパスに commit していない変更が無いこと — 範囲の外 | `SKILL.md:143` | 試運転 3.5 (3) | ✅ 一致 |
| 承認の後の commit と記録の更新 — Side Effects | 列挙: git の履歴の commit 2 種・記録の `syncedCommit` の更新。実装が起こすのは、名指しの `git add` と commit (`SKILL.md:141`・`:144`) と `record` (`:142`) だけで、push しない。列挙の外の変更は無い | 試運転 3.4 | ✅ 一致 |
| **追従の入口の案内** | `AGENTS.md:15`〜`:18` (`CLAUDE.md` は `AGENTS.md` へのリンク) | 本文照合 | ✅ 一致 |
| AGENTS.md から追従の入口が分かる | `AGENTS.md:17` (名前 `docs-refresh`・オーナーが頼んだときにだけ)・`:18` (構成の見直しは変更の実装で) | 本文照合 | ✅ 一致 |
| 追従の入口の案内 — Side Effects | 「なし」 | — | ✅ 一致 |

## 追加検査

- [x] tasks.md: 16 件すべて `[x]`。各タスクの成果物 (Skill 本文・ひな形 3 枚・リンク・検査とテスト・AGENTS.md・冒頭の説明・試運転の証跡・草稿) が実在し、対応表と食い違うチェックは無い。tasks.md の作業ツリーの差分はチェックボックスの変更だけ
- [x] 逆流検査: `proposal.md`・`specs/`・`exploration.md` は、提案の commit (`ba2e36b`) の後に変更が無い (`git status` で未変更)。足場の書き換えは無い
- [x] 未記録乖離: ❌ は無い。deviation.md は蒸留送り 3 行だけで、乖離・付随修正の行は無い
- [x] Side Effects: ADDED の全 9 Requirement に契約の欄があり、上の表の各 `— Side Effects` の行で、実装の状態変更が列挙に収まることを確かめた
- [x] 付随修正: deviation.md に `[付随修正]` の行は無い。diff の中で Scenario に対応しない変更は `scripts/docs/skills-refresh.py` の冒頭の説明 (ADR の参照の付け替え) だけで、proposal の What Changes と tasks 2.3 に挙がっている
- [x] UI 変更: 該当なし
- [x] テスト: `python3 scripts/ci/run-tests.py` 523 件・失敗 0 を自分で流して確認した。`python3 scripts/ci/check-project-skills.py .` も違反なし (終了コード 0)

## 判定

VALID。全 35 Scenario と 9 Requirement の Side Effects の行が「✅ 一致」で、虚偽チェック・逆流・テスト失敗は無い。

補足 (判定に影響しない): 試運転 3.5 (2) で、ワーカーが何も書き換えなかった回に、メインがガイドの「4. 検査を流す」を流さなかったことが証跡に記録されている。照合した Scenario (直す 1 枚が無かったときは記録の commit だけを作る) の THEN には掛からないので ❌ にしていない。本文の書き分けの不足として `review-001.md` の Minor に挙げた。
