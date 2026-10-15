# レビュー結果: user-skill-refresh-skill (001 回目)

**日付**: 2026-10-14
**判定**: APPROVED

## サマリー

追従の Skill `docs-refresh` (本文とひな形 3 枚)・置き場の検査とそのテスト・AGENTS.md の案内・`skills-refresh.py` の冒頭の説明は、デルタスペックの 9 Requirement を満たしている。Skill が名前で指す handbook の節は、草稿 `drafts/user-skill-refresh.md` の節の名前とすべて一致した。スクリプトのテスト 523 件・置き場の検査・3 つの lint・Skill の整合の検査はすべて通り、試運転の証跡の数値 (テスト件数・`status` が「変わった源泉は無い」と出ること) も手元で再現した。指摘は、試運転で見えた本文の書き分けの不足 (Minor 1 件) と、草稿・本文の小さな改善 (Suggestion 3 件) だけである。

## 照合した規約

- ソースコメント規約 (`kasane/handbook/cross/comment-policy.md`) — always。`scripts/ci/check-project-skills.py`・テスト・`scripts/docs/skills-refresh.py` の冒頭の説明に適用
- 検証 CI (`kasane/handbook/cross/verification-ci.md`) — `scripts/ci/` を触るため。検査の足し方の表 (README・利用者向け Skill の検査の行) と、本変更の検査 (プロジェクト内の Skill の置き場) が当たらないことを確認
- 利用者向け Skill の追従 (`kasane/handbook/cross/user-skill-refresh.md`) — `scripts/docs/` を触り、追従の手順を扱うため。今の文書と草稿の差は proposal の What Changes で蒸留時に反映と合意済み
- 利用者向け Skill と README の書き方 (`kasane/handbook/cross/user-docs-writing.md`) — ひな形が名前で指す節 (「コード例を確かめる」「公開の宣言の名前」「構成」) の実在の確認
- テスト実行規約 (`kasane/handbook/cross/test-execution.md`) — テストを実行・報告するため (index の適用のきっかけで確認)

ロードしたスキル: なし (パッケージの解決どおり。config の `skills.code-review` は空、diff は cross ドメインのファイルだけ)

関連 ADR: cross/ADR-0005 (accepted。開発者向けの手順は handbook に置く)・cross/ADR-0017 (accepted。本変更が supersede する対象)・cross/ADR-0019 (accepted。利用者向け Skill の外への参照。プロジェクト内の Skill には当たらない)・cross/ADR-0020 (proposed。本変更の決定)

## 確認した観点

**仕様充足**
- [x] デルタスペックの Requirement / Scenario を満たしているか — 9 Requirement・35 Scenario を本文・ひな形・テスト・試運転の証跡と突き合わせた (対応表は `verify-001.md`)
- [x] tasks.md に虚偽チェックがないか — 16 件すべての成果物が実在する。tasks.md の差分はチェックボックスだけ
- [x] 足場の書き換えがないか — proposal.md・specs/・exploration.md は作業ツリーで未変更 (`git status` で確認)
- [x] deviation.md 以外の無断逸脱がないか — 無い。deviation.md は蒸留送り 3 行だけで、付随修正の行は無い
- [x] 付随修正の同梱条件 — 該当なし

**テスト**
- [x] 全テスト成功 — `python3 scripts/ci/run-tests.py` 523 件・失敗 0 (自分で流し直した)。`check-project-skills.py .`・local-path / identity / comment-policy の lint・`check-skills.py .` も違反なし
- [x] Scenario 対応のテスト — 置き場の Requirement の 3 Scenario はテスト (`scripts/ci/tests/test_check_project_skills.py`) で表現されている。Skill の挙動の Scenario は、tasks 3.1〜3.6 の合意どおり、試運転 (16 件) と本文の突き合わせ (14 件) で確かめてある
- [x] テストの手抜き — 無い。崩れた形 (リンク無し・ディレクトリ・別の場所・宙に浮いたリンク・絶対パス・名前違い・description 無し・frontmatter 無し・SKILL.md 無し・実体の無いリンク・置き場無し・空) を 1 件ずつ違反の文言まで確かめている
- [x] 証跡の数値の再現 (lessons L-001) — テスト件数 523 と、本リポジトリでの `skills-refresh.py status` の「変わった源泉は無い」「公開の宣言の増減は無い」を手元で再現した

**設計品質**
- [x] accepted ADR・handbook の規約 — cross/ADR-0017 (専用の Skill を作らない) と本実装は食い違うが、本変更はそれを supersede する cross/ADR-0020 の実装で、蒸留で ADR を切り替えると proposal で合意済み (指摘にしない)。cross/ADR-0005 の「手順は handbook」は、Skill が入口と指揮だけを持ち、手順の中身を草稿の節を名前で指して読ませる形で守られている
- [x] ADR に合わせるための過剰な複雑さ — 無い
- [x] オーバーエンジニアリング — 置き場の検査は 175 行で、spec の Scenario とテストの範囲に収まる
- [x] コメントの単独可読性 — `check-project-skills.py` の冒頭は、`(cross/ADR-0020)` の前に理由 (2 つの CLI が別の置き場を読むので実体を 1 つにする) を自分の言葉で書いている。ADR の ID だけに頼っていない。cross/ADR-0020 は現時点で proposed で、蒸留で accepted になる前提 (所見)
- [x] 入力検証・機密情報 — ルートが実在しないときは終了コード 2。ローカル絶対パス・識別子の混入なし (lint と grep で確認)
- [x] 汎用の品質 — 宙に浮いたリンク・絶対パスのリンク・`.agents/skills/` 直下のファイル (ディレクトリでないもの) の扱いを確認した。`.agents/` と `.claude/skills/` は `.gitignore` に当たらない (`git check-ignore` で確認)。`CLAUDE.md` は `AGENTS.md` へのリンクで、案内は両方から読める
- [x] Skill 本文とひな形の参照の整合 — 本文とひな形が「」で指す節 (ガイドの 20 の節・表の行、`user-docs-writing.md` の 3 節) は、草稿と handbook にすべて実在する
- [x] ワーカーの起動の書き方 — 起動・戻し・任せ直しのすべての箇所に、器の名前と両 CLI の指定の仕方が併記されている

## 指摘事項

### 🟡 Minor ワーカーが何も書き換えなかったときに、4 の検査を流すかが本文に書かれていない

**該当箇所**: `.agents/skills/docs-refresh/SKILL.md:102` (「4. 検査を流す」)・`kasane/changes/user-skill-refresh-skill/evidence/refresh-skill-trial.md:78`
**問題点**: 試運転 3.5 (2) では、ワーカーが何も書き換えなかったため、メインが名前の漏れだけを流し、ガイドの「4. 検査を流す」の 6 本を「前の結果から変わりようがない」として流さず、commit の証跡にも名前の漏れだけを書いた。本文の 4 は「ワーカーの書き直しが終わったら、メインが次を流す」としか書いておらず、書き換えが 0 件のときの扱いが読み手 (メインのモデル) の判断に任されている。spec の「検査とオーナーの承認」は書き直しの後に両方を流すとしており、証跡はこの差を記録しただけで、本文に反映するか・spec どおりに流させるかの判断が残っていない。実害は小さい (変わったファイルが無ければ違反は増えない) が、源泉の側の変更 (利用者役の画面など) で README の例の検査が落ちる場合は、ワーカーが何も書かなくても検査の結果が変わりうるため、流さない判断は常に安全とは言えない。
**推奨修正**: 「4. 検査を流す」に、ワーカーが何も書き換えなかったときも 1 と 2 を流す (README の例の検査は源泉の変更だけでも結果が変わるため) と 1 文足す。流さない形を採るなら、どの検査を省いてよいかを本文に書き、spec との差を deviation に記録する。

### 🔵 Suggestion 草稿のスクリプトのテストの件数が古い

**該当箇所**: `drafts/user-skill-refresh.md:215`
**問題点**: 「スクリプトのテストは、2026-10-10 時点で 504 件」とあるが、本変更で置き場の検査のテストが加わり、今は 523 件である。deviation.md の蒸留送りは「追従を通しで行ったことはまだ無い」の 1 文の書き直しだけを挙げており、件数の更新は拾われていない。
**推奨修正**: 草稿の件数を 523 件 (日付を合わせる) に直すか、deviation.md の蒸留送りの行に件数の更新を足す。

### 🔵 Suggestion 「Skill に掛からない」源泉が、掛かる源泉と一緒に変わったときの渡す先

**該当箇所**: `.agents/skills/docs-refresh/SKILL.md:89` (渡す先の表の 1 行目)・`.agents/skills/docs-refresh/SKILL.md:81`
**問題点**: 渡す先の表は「『見直す 1 枚』に `(ios の Skill だけ)` などが無ければ両方」としている。`status` は掛からない源泉の「見直す 1 枚」を `Skill に掛からない (理由: …)` と出す (`scripts/docs/skills_manifest.py:50`) ので、表をそのまま当てると、掛からない源泉も両方のワーカーに渡すことになる。掛からない源泉だけが変わった場合は 2 の 3 つ目の箇条が扱っているが、掛かる源泉と混ざった場合の扱いが本文に無い。
**推奨修正**: 表の 1 行目に、「Skill に掛からない」と出た源泉はワーカーに渡さず 6 で扱った源泉として見せる (または、利用者に関わる記述が増えていないかを見させるために両方に渡す) のどちらかを書き足す。

### 🔵 Suggestion codex からの追従の使い方 (ワーカーの起動) が試運転されていない

**該当箇所**: `.agents/skills/docs-refresh/SKILL.md:24`・`kasane/changes/user-skill-refresh-skill/evidence/refresh-skill-trial.md:35`
**問題点**: codex での試運転は、Skill の一覧と確かめるだけの使い方 (3.2) までで、器 `ksn-scribe` を指定した spawn は確かめていない。spec の「ワーカーの起動の書き方」は本文の書き方だけを求めているので spec の違反ではないが、cross/ADR-0020 の前提 (メインのセッションが器を指定してワーカーを呼べる実行環境であること) のうち、codex の側は未確認のまま残る。
**推奨修正**: 蒸留の handbook の草稿か deviation の蒸留送りに、codex から追従の使い方を通しで動かしたことはまだ無い、と 1 文残す (初めて codex で追従するときに確かめる、という扱いを明示する)。

## アクションプラン

1. (Minor) `SKILL.md` の「4. 検査を流す」に、ワーカーが何も書き換えなかったときの扱いを 1 文足す
2. (Suggestion) 草稿のテスト件数を直すか、蒸留送りに足す
3. (Suggestion) 渡す先の表に「Skill に掛からない」源泉の扱いを足す
4. (Suggestion) codex での追従の使い方が未試行であることを、草稿か蒸留送りに残す
