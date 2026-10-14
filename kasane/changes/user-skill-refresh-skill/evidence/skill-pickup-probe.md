# 試作: 2 つの CLI が、実体 1 つとリンクで置いた Skill を拾うか

2026-10-14、提案の段階で確かめた (lessons/spec-review.md L-002: 外部の部品の挙動を前提にするときは、提案の段階の最小試作で実物を確かめる)。

## 置き方

リポジトリの外の作業用の置き場に、使い捨ての git のリポジトリを作り、次の形にした。

- 実体: `.agents/skills/probe-refresh/SKILL.md` (frontmatter に `name: probe-refresh` と `description`。本文は「呼ばれたら合言葉を答えるだけ」)
- `.claude/skills/probe-refresh` → `../../.agents/skills/probe-refresh` (相対のシンボリックリンク)

## 確かめたこと

| CLI (版) | 確かめ方 | 結果 |
|---|---|---|
| Claude Code (2.1.296) | 非対話の実行で、名前が `probe-` で始まる Skill を挙げさせた | `probe-refresh` が出た。description は出なかった。同じ形で `.claude/skills/` に直接置いた Skill も、description は出なかったので、リンクの置き方の差ではない |
| Claude Code (2.1.296) | 非対話の実行で `/probe-refresh` を呼んだ | 本文のとおり合言葉を答えた (リンクの先の本文が読まれた) |
| codex (codex-cli 0.162.0) | 非対話の実行 (読み取りだけの sandbox) で、ファイルを読まずに、名前が `probe-` で始まる Skill を挙げさせた | `probe-refresh` と、description の全文が出た (`.agents/skills/` から拾っている) |

## 分かったこと

- 実体を `.agents/skills/<名前>/` に置き、`.claude/skills/<名前>` をそこへのリンクにすると、Claude Code は名前で呼べ、codex は名前と説明を持つ
- Claude Code の非対話の実行では、プロジェクトの Skill の description が見えなかった。呼び出しには影響しない。対話の実行での見え方は確かめていない

確かめた後、作業用の置き場は消した。
