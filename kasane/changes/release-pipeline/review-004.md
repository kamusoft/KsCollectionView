# レビュー結果: release-pipeline (004 回目)

**日付**: 2026-10-15
**判定**: APPROVED

## サマリー

tasks 9〜10.6 の後の未 commit の差分 (Skill と草稿への 1 文・README 2 枚からの 1 段落の削除・証跡 4 枚・tasks のチェック・deviation の付随修正の行) を見た。証跡の記述は、GitHub の上の実際の状態 (run の結論とジョブ・validate の出力・artifact・tag・Release・Pull Request の本文の編集の履歴・`main` の親) と読み直しで一致し、tasks のチェックに虚偽は無い。指摘は、足した 1 文が見出しの水準を書いていない Minor 1 件だけである。

## 照合した規約

- ソースコメント規約 (always)
- 利用者向け Skill と README の書き方 (ルートの `README.md` / `README_ja.md` を触るため。`kasane/handbook/cross/user-docs-writing.md:244` の「この 1 文は、初回のリリースのときに外す」と照合)
- ブランチの運用と GitHub の設定 (`main` 宛ての Pull Request の作成・マージの証跡を読むため)
- 検証 CI (CI script tests と lint の検査を手元で流すため)
- テスト実行規約 (テストを実行するとき)

ロードしたスキル: ksn-review (パッケージの指定どおり。レビューで読むスキルはなし)

## 確認した観点

**仕様充足**
- spec user-readme「インストール例」: README 2 枚のインストールの節は、`{version}` を置き換えること・置き換えないと失敗すること・最新の版の確かめ先から始まり、「まだ公開していない」に当たる文は README・`skills/`・`scripts/distribution/`・`.github/` のどこにも無い (grep で確認)。削除の位置は design の「初回のリリースまでは 1 文を残し、リリースの Pull Request で外す」(`design.md:255`) と合う (未 commit で、`develop` 経由のリリースの Pull Request で `main` に入る)
- spec release-notes「リリースの組み立て」の範囲: `main` 宛ての Pull Request は #1・#2・#3 の 3 本だけで、どれも `build-release-notes.py` の `parse_changes` で「利用者向けの変更なし・問題 0」と読めた (GitHub から本文を取り直して手元で読んだ)
- tasks.md のチェック (10.2〜10.6): すべて証跡と GitHub の実物で裏付けられ、虚偽のチェックは無い。10.7〜10.9 と 1.3 は未チェックのまま
- 足場 (proposal・design・specs) は HEAD から変わっていない

**証跡と GitHub の実物の照合 (読み取りだけ)**

| 証跡の記述 | 読み直した実物 | 結果 |
|---|---|---|
| #3 は `develop` → `main`、merge commit 36ca60b、`main^1` f2c1473・`main^2` d8ec4c1 (`evidence/github-prep-pr-001.md`) | `git ls-remote` と `git rev-parse origin/main^1 origin/main^2` で同じ値。題 `Add the release workflow`、マージ済み | 一致 |
| #3 の本文は `## Changes` / `- none` の後に `## Notes` と署名の行 | 本文の末尾が同じ形。`parse_changes` で `([], [])` | 一致 |
| workflow `Release` が既定のブランチで手動で起動できる (ID 385406920) | `gh workflow view` で同じ ID。run は試しと本番の 2 件だけ | 一致 |
| 試しの run 38721418708: `success`、7 ジョブ成功・公開以降の 5 ジョブ skipped、`validate` の出力 (`production=false`・`on-main=false`・`main-tag`/`spm-tag` は `absent`・`published=false`・`built=false`)、artifact 2 つ (380,729 / 579,663 バイト) (`evidence/github-develop-runs-001.md`) | `gh run view` のジョブと結論、ログの「出力:」の行、artifact の一覧がすべて同じ。起動した commit は d8ec4c1、ブランチ `develop` | 一致 |
| 本番の run 38722143173: `validate` の `Check inputs` で失敗、後ろのジョブはすべて skipped | 結論 `failure`、`validate` だけ failure、ほかは skipped。エラーの行の文面も証跡の引用と同じ | 一致 |
| 起動の後の外の状態は起動の前と同じ (tag 無し・配信用リポジトリは空・Release 無し・POM は 404) | 本リポジトリの tag 0、配信用リポジトリの `git ls-remote` は空で終了コード 0、Release は両リポジトリとも 0、repo1 の POM は 404 | 一致 |
| #1・#2 は、元の本文の末尾に空行と `## Changes` / `- none` を足しただけ (`evidence/github-pr-bodies-001.md`) | GraphQL の `userContentEdits` で編集の前後を取り、改行を揃えて比べると、新しい本文は前の本文で始まり、差は `\n## Changes\n\n- none\n` だけ | 一致 |
| README で外した段落は 38 行目 (`evidence/readme-before-release-001.md`) | diff の `@@ -35,8` から 38 行目に当たる | 一致 |

- 証跡の中の範囲の外への言及 (読み取りだけの token での Pull Request の一覧・Environment の branch policy が `develop` のジョブを止めること・発行物のバイトの一致) は、「確かめていないこと」として正しく未確認に置かれ、確かめた扱いにしていない
- 証跡に手元の絶対パス・個人のメールアドレスは無い (grep で確認)

**付随修正の同梱条件**
- `.agents/skills/release/SKILL.md:102`・`drafts/release-procedure.md:401` の 1 文: ① 本務で触るファイル (release-skill・リリースの手順の草稿) ② 公開 API・スキーマ・ADR に触れない ③ 2 ファイル・各 1 文 ④ 文面だけで、`check-project-skills.py` が通る ⑤ ユーザーの選択の分岐が無い — 同梱条件に収まる。spec release-notes の「節は次の `## ` の見出しの行の前まで」と、`parse_changes` の実装 (`scripts/release/build-release-notes.py:123-125`) とも方向は合う (下の Minor を除く)
- spec release-skill「変更の節の下書き」(`specs/release-skill/spec.md:107-109`) の範囲に収まり、新しい止まり方や確認の回数を足していない

**テスト・検査 (手元で流した)**
- `python3 scripts/ci/run-tests.py`: 実行 728 件 / 失敗 0 / スキップ 4 (Gradle の実物のテスト)
- `python3 scripts/ci/check-readme-examples.py .`: 違反なし (最小コード例 4 つ・依存の宣言の行 12 行)
- `python3 scripts/ci/check-project-skills.py .`: 違反なし (Skill 2 つ)
- `python3 scripts/ci/check-skills.py .`: 違反なし
- `scripts/local-path-lint.py`・`scripts/identity-lint.py`・`scripts/comment-policy-lint.py`・`scripts/ci/check-workflows.py`: 違反なし (終了コード 0)

**設計品質**
- accepted ADR・handbook の規約との衝突は無い。`user-docs-writing.md:244` の 1 文は、外した後の状態に合わせて蒸留で直す対象 (長命層の未反映は指摘しない)
- 機密情報: 証跡は secret の名前と更新の時刻だけで、値に触れていない (9.x の証跡は HEAD で既にレビュー済み)

## 指摘事項

### 🟡 Minor 足した 1 文が、変更の節を終える見出しの水準を書いていない

**該当箇所**: `.agents/skills/release/SKILL.md:102`、`kasane/changes/release-pipeline/drafts/release-procedure.md:401`
**問題点**: 両方の文の前半「変更の節は、次の見出しか本文の終わりまで続く」も同じく水準を書いていない。変更の節を終えるのは `## ` で始まる行だけである (spec release-notes の節の読み方、`scripts/release/build-release-notes.py:124`)。Skill の文は「見出しを置いてから書く」とだけ書き、水準を指定していない。草稿も「`## Notes` などの見出し」と例を挙げるだけである。`### Notes` や `# Notes` を置くと節は終わらず、その見出しの行と署名の行が節に入って `validate` で止まる (手元で `parse_changes('## Changes\n\n- none\n\n### Notes\n\nsig\n')` を流し、「`- none` とほかの行が混ざっている」で止まることを確かめた)。また、Pull Request のひな形の注釈は「節の中の見出しはリリースを止める」と書いているので、水準の無い「見出しを置く」はそれと読み合わせたときに紛らわしい。失敗は公開の前に止まる側に倒れるので害は小さいが、この 1 文が防ごうとしている止まり方そのものを、見出しの選び方次第で再び招く。
**推奨修正**: Skill と草稿の文を「`## ` で始まる見出し (`## Notes` など) を置いてから書く」のように水準を明示する。あわせて、草稿の本文の例 (`drafts/release-procedure.md:391-399` の Markdown) の末尾に `## Notes` を置いておく形にすれば、後から足す行が自然にその下に入る (任意)。

## アクションプラン

1. (Minor) Skill と草稿の 1 文に、見出しの水準 (`## `) を明示する
