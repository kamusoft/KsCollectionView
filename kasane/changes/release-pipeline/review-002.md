# レビュー結果: release-pipeline (002 回目)

**日付**: 2026-10-15
**判定**: APPROVED

## サマリー

前回 (review-001 と second-opinion-code-001 の突き合わせ結果) で確定した 5 件は、すべて解消している。送信の step は `-e` の下でもログを出して元の終了コードで終わり、そのことを Actions と同じシェルのオプションで流すテストで確かめている。iOS は、確かめた artifact の中身をそのまま置いて push し、置く前と置いた後の 2 回 tree を照らす。草稿の「Wait for validation (上限)」の行・tasks 1.1/1.2 のチェック・手元の署名の通しも直っている。オーナーの指示で足した「検証 CI の記録が無いときに直近の成功で代える」判定 (`check-ci-skipped-changes.py`) は、乖離の記録どおりで、止まる側に倒れる作りになっている。新しい指摘は、push の直後に run がまだ現れていないときの読み違いの Minor 1 件と、artifact が運ばないものについての Suggestion 1 件である。

## 照合した規約

- ソースコメント規約 (always)
- テスト実行規約 (テストを実行するとき・テストを追加するとき)
- 検証 CI (`.github/workflows/`・`scripts/ci/` を触るとき) — 「コマンドの出力を記録に残す」「workflow の定義の検査が読める書き方」「検査を足すときの注意」を、修正サイクルで変わった step (`Upload to Maven Central`・`Push SPM snapshot`) について照合
- 配布物の形と作り方 (写しの置き方を変えた `Push SPM snapshot` と `scripts/release/place-spm-snapshot.py` のため)
- ブランチの運用と GitHub の設定 (事前の確認で読む検証 CI の起動条件 (`ci.yml` の `paths-ignore`) のため)

ロードしたスキル: ksn-review、kotlin-impl-skill (android の code-review。`build.gradle.kts` は修正サイクルで変わっていないことを確かめ、前回の照合を引き継いだ)

## 確認した観点

**前回の指摘の解消**

| 前回の指摘 | 結果 | 根拠 |
|---|---|---|
| (相方・採用) 送信の step が `bash -e` で、Gradle の失敗時にログと終了コードに届かない | 解消 | `.github/workflows/release.yml:443-449` が `|| status=$?` で受ける。`scripts/ci/tests/test_workflow_files.py:1120-1176` が step の本文を取り出し、偽の Gradle (標準出力と標準エラーに書いて 3 で終わる) を置いて、`bash -e` と `bash --noprofile --norc -eo pipefail` の両方で流し、ログの表示・ログのファイル・終了コード 3 を確かめる。`shell:` が足されたらテストが落ちる |
| (ホスト) iOS が確かめた artifact でなく作り直した写しを push する | 解消 | `release.yml:331-336` で `spm-snapshot` を取り込み、`release.yml:382-405` が `scripts/release/place-spm-snapshot.py` で置く。スクリプトは (1) 確かめた写しと起動した commit から作った写しの tree の一致 (外れたら作業コピーに触れない)、(2) `.git` を残して消して写す、(3) `git add --all` 後の index の tree と確かめた写しの tree の一致、を git の設定を読まずに行う。workflow のテストは `sync-spm-snapshot.py` が publish に無いこと・clone → 置く → 差分の確かめの順を固定する。スクリプトのテスト 12 件 (余分なファイル・HEAD の不一致・`.git` を含む写し・別のリポジトリの作業コピー・index の不一致・本リポジトリから作った本物の写し) がある |
| (ホスト) 草稿の「Wait for validation (上限)」の行が後始末の取り下げと合わない | 解消 | `drafts/release-procedure.md:573` が、後始末が最大 10 分待って取り下げること・取り下げていれば新しく送る・残っていれば決着を待つ、を書く |
| (ホスト) tasks 1.1・1.2 が未チェック | 解消 | `tasks.md:7-8` |
| (ホスト・Suggestion) 署名した組み立て直しとバイトの一致を手元で通す | 解消 | `evidence/publish-rehearsal-001.md`。別々のパスの clone・使い捨てのパスフレーズつきの鍵で、5 ファイルのバイトの一致と `.asc` 5 つ、誤ったパスフレーズで送る前に止まること、同じ作業ツリーの再起動で AAR と署名が UP-TO-DATE であることを確かめ、鍵と clone を `trash` で消している。確かめていない残り (別のランナーどうしの一致・`publishToMavenCentral` の束の中身) は草稿の「確かめていないこと」(`drafts/release-procedure.md:652-654`) に移っている |

**仕様充足**
- 足場 (proposal・design・specs) は HEAD から変わっていない
- tasks.md の [x] はすべて実物がある。1.3・9・10 は未着手で正しい
- deviation.md の「乖離 (オーナーの指示)」(検証 CI の記録が無いときに直近の成功で代える) は、`.agents/skills/release/SKILL.md:58-63,73,77` と `drafts/release-procedure.md:311-344` と `scripts/release/check-ci-skipped-changes.py` に、記録どおりの範囲で入っている (起動しないパスは対象の commit の `ci.yml` から読む・`ci.yml` 自身の変更は起動する側に数える・名前の変更は両方の名前で数える・祖先でなければ止まる・読めない pattern は止まる)。間に失敗や打ち切りの run があっても、その変更は差に入るので止まる側に倒れることを確かめた
- 蒸留送りの追加 2 行 (修正サイクル 1) は合意済みとして扱った

**テスト**
- `python3 scripts/ci/run-tests.py`: 実行 728 件 / 失敗 0 / スキップ 4 (スキップは `KS_GRADLE_TESTS=1` のときだけ流れる Gradle の実物のテスト。xcodebuild・gradlew はパッケージの制約で流していない)
- `scripts/ci/check-workflows.py`・`actionlint`・`scripts/ci/check-project-skills.py .`・`scripts/comment-policy-lint.py`: 違反なし (`doc-structure-lint.py` の警告は既存の handbook の文書で、この差分ではない)
- `check-ci-skipped-changes.py` のテスト 11 件は、正常 (起動しないパスだけ・差が無い)・異常 (起動するパス・`ci.yml` の変更・祖先でない・知らない commit・`paths` で絞る形や読めない pattern)・`*` が `/` を越えないこと・対象の commit の `ci.yml` を読むこと・本リポジトリの `ci.yml` を読めること、を持つ。言い訳コメントでのスキップは無い

**設計品質**
- accepted ADR・handbook の規約との衝突は無い
- `place-spm-snapshot.py` は、比べ方を `check-release-state.py tags` と共有し (`release_support.tree_of_directory`)、作業コピーの確かめ方と消し方を写しの道具から読み込んでいて、同じ規則を 2 か所に書いていない。push した tree と、後の再実行の tag の照合で比べる tree が同じ作り方になる
- コメントは単独で読める。secret の渡し方は前回から変わっていない (`SPM_DEPLOY_KEY` は `Push SPM snapshot` と `Tag SPM repository` だけ)
- 現時点の写しの元 (`ios/Sources`・`ios/Tests`・`ios/Package.swift`) に、隠しファイル・実行の権限・シンボリックリンクは無いことを確かめた (指摘 2 の前提)

## 指摘事項

### 🟡 Minor push の直後に run がまだ現れていないと「run が無い」に入り、起動するパスの変更があるのに「代えられない」で止まる

**該当箇所**: `drafts/release-procedure.md:311-344` (run の状態の表の「run が無い」の行と、`check-ci-skipped-changes.py` の結果の表)、`.agents/skills/release/SKILL.md:58-60`
**問題点**: 事前の確認は、手元が先行していれば push し、その直後に `gh run list --commit <対象の commit>` で run を読む。GitHub が push を受けてから run を一覧に載せるまでには遅れがあり、その間に読むと run が無く、表の「run が無い」に入る。今回足した代える判定は、対象の commit に起動するパスの変更があれば終了コード 1 と「起動するパス」の一覧を返し、表に従って止まる。止まる側に倒れるので害は無いが、実際には検証 CI がこれから走るだけの、ふつうの (蒸留の commit でない) リリースで止まり、オーナーには「代えられない変更がある」と見える。spec の止まる条件 (失敗・待っても終わらない) に当たらない停止である。
**推奨修正**: 「`check-ci-skipped-changes.py` が終了コード 1 で、出力に「起動するパス」がある」の行のすることを、「起動するパスの変更があるので、対象の commit の run はこれから現れるはずである。数分の上限をつけて `gh run list --commit …` を読み直し、現れたら run の状態の表に戻る。上限まで現れなければ止まる」にする。または、push した直後は、run が現れるまで上限つきで読み直してから「run が無い」と判断する、と書く。どちらも Skill の側は変えずに、手順の文書 (草稿) だけで直せる。

### 🔵 Suggestion artifact が運ばないもの (隠しファイル・実行の権限) を、写しの食い違いの調べ方に書いておく

**該当箇所**: `drafts/release-procedure.md:567` (`Push SPM snapshot` の tree の食い違いの行)、`.github/workflows/release.yml:135-140`
**問題点**: `actions/upload-artifact` は、既定で隠しファイル (名前が `.` で始まるもの) を入れず、ファイルの権限を保たない。写しの元に、将来 `.swiftlint.yml` のような隠しファイルや実行の権限のついたファイルが `ios/Sources`・`ios/Tests` に入ると、`consumer-ios` は通るのに、`place-spm-snapshot.py` の (1) の照合が毎回外れ、本番がそこで止まる (止まる側に倒れるので公開の害は無い)。今は該当するファイルは無い。草稿の行は「止まって調べる」とだけ書き、原因の当たりが無い。
**推奨修正**: 草稿のその行に、「原因の候補: artifact は隠しファイルと実行の権限を運ばない。写しの元にそういうファイルが入っていないかを見る」の 1 文を足す。あるいは、写しの道具か `package-ios` で、写しに隠しファイルや実行の権限が無いことを先に確かめる (外れたら `package-ios` で止まり、原因がその場で分かる)。

## アクションプラン

1. (Minor) 草稿の事前の確認で、push の直後に run がまだ現れていないときの扱いを書く (起動するパスの変更があると出たら、run を上限つきで読み直す)
2. (Suggestion) 草稿の `Push SPM snapshot` の食い違いの行に、artifact が隠しファイルと実行の権限を運ばないことを原因の候補として足す
