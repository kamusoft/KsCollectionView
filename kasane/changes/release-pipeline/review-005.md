# レビュー結果: release-pipeline (005 回目)

**日付**: 2026-10-15
**判定**: APPROVED

## サマリー

review-004.md の Minor 1 件 (変更の節を終える見出しの水準が書かれていない) の直しだけを見た。Skill と草稿の両方が、節を終えるのは `## ` で始まる見出しの行だけであること・後ろに書くときは `## ` で始まる見出しを置くこと・`###` などでは終わらないことを明示しており、指摘は解消している。spec release-notes の節の読み方と `parse_changes` の実際の読み方とも一致し、新しい食い違いは無い。deviation の付随修正の行が直しの後の形 (本文の例への `## Notes` の追加) を書いていない点を Suggestion として残す。

## 照合した規約

- ソースコメント規約 (always) のみ (直しは文面だけで、ほかの文書の適用のきっかけに当たらない)

ロードしたスキル: ksn-review (パッケージの指定どおり。レビューで読むスキルはなし)

## 確認した観点

**指摘の解消**
- `.agents/skills/release/SKILL.md:102`: 「次の `## ` で始まる見出しか、本文の終わりまで続く」「`## ` で始まる見出し (`## Notes` など) を置いてから書く」「`###` などほかの水準の見出しでは変更の節が終わらない」と水準を明示した。review-004 の推奨修正どおり
- `kasane/changes/release-pipeline/drafts/release-procedure.md:399-402`: リリースの Pull Request の本文の例の末尾に `## Notes` と、無ければ見出しごと置かない旨の置き場を足した (review-004 で任意とした推奨)。直後の段落 (`drafts/release-procedure.md:405`) は Skill と同じ内容で、止まる場所を `validate` と具体的に書いている

**新しい食い違いが無いこと**
- spec release-notes の節の読み方 (`specs/release-notes/spec.md:27`「次の `## ` の見出しの行の前 (無ければ本文の終わり) まで」) と、Skill・草稿の「次の `## ` で始まる見出しか、本文の終わりまで続く」は同じ範囲を言っている
- `scripts/release/build-release-notes.py:123-125` (`line.startswith("## ")` で節を終える) と照合した。行頭から `## ` で始まる行だけが節を終え、`###`・`#`・字下げした見出しは終えない。Skill・草稿の「`## ` で始まる」「ほかの水準では終わらない」と合う
- 手元で `parse_changes` を流して確かめた (読み取りだけ):

  | 本文の形 | 結果 |
  |---|---|
  | 草稿の例どおり (`## Changes` の 1 行の後に `## Notes` と署名の行) | 行 1 件・問題 0 |
  | 草稿の例から `## Notes` を見出しごと除いた形 | 行 1 件・問題 0 |
  | `- none` の後に `## Notes` と署名の行 | 空の並び・問題 0 |
  | `## Notes` だけで下に何も無い形 | 行 1 件・問題 0 |
  | `- none` の後に `### Notes` / `# Notes` と署名の行 | 止まる (`- none` とほかの行が混ざっている) |
  | 見出しを置かずに署名の行を足した形 | 止まる (読めない行) |

  Skill・草稿の書いたとおりの結果になる
- Pull Request のひな形 (`.github/pull_request_template.md`) の「節の中の見出しはリリースを止める」とは、「`## ` の見出しで節を出てから書く」という形で読み合わせても矛盾しない (`## ` の見出しは節の外になる)
- spec release-skill「変更の節の下書き」の範囲を超えて、新しい止まり方や確認の回数を足していない
- 足場 (proposal・design・specs) は変わっていない (`git diff` の対象に無い)

**検査**
- `python3 scripts/ci/check-project-skills.py .`: 違反なし (Skill 2 つ)
- `scripts/local-path-lint.py`・`scripts/comment-policy-lint.py`: 終了コード 0

## 指摘事項

### 🔵 Suggestion deviation の付随修正の行が直しの後の形を書いていない

**該当箇所**: `kasane/changes/release-pipeline/deviation.md:30`
**問題点**: 行は「見出しを置く、の 1 文を足した」のままで、直しで加わった水準 (`## `) の明示と、草稿の本文の例への `## Notes` の追加を書いていない。付随修正の同梱条件 (2 ファイル・文面だけ) には今も収まるので害は無いが、蒸留で handbook へ移すときに例の形の変更を見落とす余地がある。
**推奨修正**: 行を「`## ` で始まる見出しを置く旨の文を足し、草稿の本文の例の末尾に `## Notes` を置いた」のように直す。

## アクションプラン

1. (Suggestion) deviation の付随修正の行を、直しの後の形に合わせる
