# レビュー結果: release-pipeline (003 回目)

**日付**: 2026-10-15
**判定**: APPROVED

## サマリー

review-002 と second-opinion-code-002 の突き合わせで確定した 2 件 (push の直後に run がまだ現れないときの停止・artifact が運ばないものの手掛かり) は、どちらも草稿と Skill の文面で解消している。直しは草稿・Skill・spec release-skill・deviation の「乖離 (オーナーの指示)」・`check-ci-skipped-changes.py` の動き・`release.yml` のどれとも食い違っていない。新しい指摘は、読み直しの条件の書き方の揺れについての Suggestion 2 件だけである。

## 照合した規約

- ソースコメント規約 (always)
- テスト実行規約 (テストを実行するとき)
- 検証 CI (事前の確認が読む検証 CI の起動条件のため。直しは文書と Skill の文面だけで、workflow と `scripts/ci/` は変わっていない)

ロードしたスキル: ksn-review (パッケージの指定どおり。レビューで読むスキルはなし)

## 確認した観点

**前回の指摘の解消**

| 前回の指摘 | 結果 | 根拠 |
|---|---|---|
| (Minor) push の直後に run がまだ現れていないと「run が無い」に入り、起動するパスの変更があるのに「代えられない」で止まる | 解消 | `drafts/release-procedure.md:322` の「run が無い」の行が、同じコマンドで 1 分おきに最大 5 分読み直し、現れたら run の状態の表の上の行に従い、5 分経っても無いときだけ直近の成功で代える判定に進む、と書く。review-002 の推奨修正の 2 つ目の形 (run が現れるまで上限つきで読み直してから「run が無い」と判断する) に当たる。`.agents/skills/release/SKILL.md:60` も「push した直後なら手順の文書の上限まで読み直し、それでも無ければ…」になり、上限の値を Skill に写さず手順の文書を正にしている (Skill の役割の決め方どおり) |
| (Suggestion) artifact が運ばないもの (隠しファイル・実行の権限) を、写しの食い違いの調べ方に書いておく | 解消 | `drafts/release-procedure.md:568` の `Push SPM snapshot` (tree の食い違い) の行に、原因の候補の 1 文が足された。`release.yml:136-140` の `upload-artifact` (v7.0.2) は `include-hidden-files` を指定しておらず、既定で隠しファイルを入れないので、文面は実物の設定と合う |

**直しで新しい食い違いが入っていないか**
- spec release-skill (`specs/release-skill/spec.md:48-49`): 手元が先行していれば push して「その先端の検証 CI の完了を待つ」・「待っても終わらない」なら止まる、の範囲に収まる。読み直しは待ちの一部で、新しい止まり方を足していない (5 分経っても無いときは、従来どおり代える判定に進む)
- deviation の「乖離 (オーナーの指示)」: 代える判定の条件 (直近で成功した commit から対象の commit までの変更が起動しないパスだけ) は変わっていない。読み直しは代える判定の前に置かれただけで、代える範囲を広げも狭めもしない
- `scripts/release/check-ci-skipped-changes.py`: 変わっていない。草稿の結果の表 (`drafts/release-procedure.md:336-340`) も変わっておらず、読み直しの後に起動するパスの変更があると出たときは、これまでどおり止まる (上限を超えて run が現れない異常は止まる側に倒れる)
- `release.yml`: 変わっていない。`Push SPM snapshot` の食い違いの行は、`place-spm-snapshot.py` の 2 回の tree の照合 (起動した commit から作った写しとの照合・index との照合) の失敗の両方を指したままで、足した 1 文は前者の原因の候補として読める
- 足場 (proposal・design・specs) は HEAD から変わっていない

**テスト**
- `python3 scripts/ci/run-tests.py`: 実行 728 件 / 失敗 0 / スキップ 4 (スキップは `KS_GRADLE_TESTS=1` のときだけ流れる Gradle の実物のテスト)
- `python3 scripts/ci/check-project-skills.py .`: 違反なし (Skill 2 つ: docs-refresh・release)

## 指摘事項

### 🔵 Suggestion 「run が無い」の行の読み直しが、push しなかったときにも掛かるように読める

**該当箇所**: `drafts/release-procedure.md:322`、`.agents/skills/release/SKILL.md:60`
**問題点**: 草稿の行は「push した直後は、run が一覧に現れるまで少し遅れる。」と理由を述べた後、「同じコマンドで 1 分おきに最大 5 分読み直し」を条件なしの指示として書いている。Skill の側は「push した直後なら」と条件をつけている。出力が `0 0` (push していない) のときに草稿どおりに 5 分読み直しても害は無い (待つだけ) が、手順の正である草稿と Skill で、読み直す場面の範囲が揃っていない。
**推奨修正**: 草稿の行を「push した直後なら、…読み直す。push していなければ、またはそれでも無ければ、直近で成功した run で代えられるかを確かめる」のように条件を明示する。あるいは、どちらの場面でも読み直すことにして、Skill の「push した直後なら」を外す。蒸留で handbook に移すときに揃えれば足りる。

### 🔵 Suggestion artifact が実行の権限を保たないことの確かさの書き方が、2 か所で違う

**該当箇所**: `drafts/release-procedure.md:568`、`drafts/release-procedure.md:649`
**問題点**: 失敗したときの表は「artifact はどちらも保たない」と言い切り、「確かめていないこと」の表は「実行の権限を保たない見込み」と書く。どちらも原因の当たりとしては正しく働くが、同じ事実の確かさが文書の中で揃っていない。
**推奨修正**: 初回の本番で確かめるまでは、568 行も「保たない見込み」に揃える (または 649 行の確かめた結果が出たら、両方を確定の書き方にする)。

## アクションプラン

1. (Suggestion) 「run が無い」の読み直しの条件を、草稿と Skill で揃える (蒸留で handbook に移すときでよい)
2. (Suggestion) artifact が実行の権限を保たないことの確かさの書き方を、草稿の 2 か所で揃える
