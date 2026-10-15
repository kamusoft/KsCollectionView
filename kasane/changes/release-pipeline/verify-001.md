# Verify: release-pipeline (001)

検証した日: 2026-10-15 / 対象: HEAD c764358 からの作業ツリーの未 commit の変更と未追跡のファイル / 時点: tasks 1.1・1.2・2〜8 が済み、1.3・9・10 が未着手

## 判定: VALID (GitHub の準備と初回のリリースの前の時点の判定)

- デルタスペック 7 枚・Requirement 26・Scenario 114 を、実装とテストに 1 行ずつ対応させた
- ❌ は 0 件。⚠️ (deviation 記録済み) は 1 件 (release-skill「事前の確認」)
- ⏳ (GitHub の準備と初回のリリースの後に確かめるもの) は Scenario 7 件 (release-workflow 1・repository-publication 5・user-readme 1。repository-publication の Requirement の行 2 つも ⏳)。どれも、定義・草稿の手順で備えができていることは確かめた。乖離には数えない
- ⏳ のほかに、テストと定義では一致しているが、実物の run でもう一度確かめる予定の Scenario がある (下の「実物でもう一度確かめる Scenario」)
- 足場 (proposal・design・specs) は HEAD から変わっていない。tasks.md の変更は、チェックを付けた差分だけである
- スクリプトのテストは、自分で流して 728 件・失敗 0・スキップ 4 だった
- 蒸留の前に、tasks 9・10 を終えてから、⏳ の 7 件と実物の確認の Scenario を確かめる検証 (verify-002) が要る

記号: ✅ 一致 / ⚠️ deviation 記録済み / ⏳ GitHub の準備と初回のリリースの後に確かめるもの (乖離ではない) / ❌ 欠落・乖離

テストの列のファイルは `scripts/ci/tests/` の下にある (`twf` = `test_workflow_files.py`、`tcp` = `test_central_portal.py`、`tcrs` = `test_check_release_state.py`、`tbrn` = `test_build_release_notes.py`、`tcaa` = `test_check_android_artifacts.py`、`tvci` = `test_verify_consumer_ios.py`、`tvca` = `test_verify_consumer_android.py`、`tcw` = `test_check_workflows.py`)。`release.yml` は `.github/workflows/release.yml`。

## 対応表

### release-workflow

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **リリースの起動** | `release.yml:26-37` (workflow_dispatch だけ・入力 2 つ)、`scripts/release/check-release-state.py:66-89`、`scripts/release/release_support.py:25` (版の形) | | ✅ |
| 正しい版で main から本番を起動する | 同上 (`production=true`) | `tcrs` InputsTest.test_accepts_production_from_main、`test_release_support.py` VersionTest | ✅ (実物: 10.9) |
| 版の形が違うと最初に止まる | 同上、validate の最初の step `Check inputs` (`release.yml:69-74`) | `tcrs` test_rejects_wrong_version_forms_first (`v0.1.0`・`0.1`・`0.1.0-pre.1`)、`twf:845` (validate の step の並び) | ✅ |
| main 以外から本番を起動すると止まる | `check-release-state.py:78-82` | `tcrs` test_rejects_production_from_other_branches | ✅ (実物: 10.4) |
| main 以外からの dry-run は受け付ける | 同上 | `tcrs` test_accepts_dry_run_from_other_branches | ✅ (実物: 10.3) |
| tag の push では起動しない | `release.yml:26-27` | `twf:746` test_tagのpushでの起動を足すと落ちる、`twf:743` | ✅ |
| リリースの起動 — Side Effects (なし) | validate は確かめと step の出力だけ。tag の確かめの写しは一時のディレクトリで、消える (`check-release-state.py:145`) | | ✅ |
| **1 本ずつ流れる** | `release.yml:45-47` (`group: release`・`cancel-in-progress: false`) | `twf:759`・`twf:764` | ✅ |
| 走っている間に起動したものは待つ | 同上 (待ちと打ち切りの動きは GitHub の決まり。evidence/research-github-actions.md) | `twf:759` | ✅ (実物での観察は予定に無い) |
| 待っているものがあるときに起動すると、待っていた方が取り消される | 同上 | `twf:764` (まとまりを 1 つに固定) | ✅ (同上) |
| 1 本ずつ流れる — Side Effects (なし) | 定義だけ | | ✅ |
| **公開の前の確認** | `release.yml:107-238` (verify-ios / verify-android / package-ios / package-android / consumer-ios / consumer-android)、`release.yml:250-251` (publish の needs と if) | `twf:810`・`twf:833`・`twf:865`・`twf:871` | ✅ |
| 検証が失敗すると公開に進まない | `release.yml:250` (publish は 5 つのジョブの成功を needs に持つ。`if:` は状態の関数を持たないので、成功が暗に掛かる) | `twf:810` test_ジョブの並びが決めたとおりである | ✅ |
| 利用者役は組み立てた配布物を使う | `release.yml:223-238`、`scripts/ci/verify-consumer-ios.py` (`--snapshot`)・`scripts/ci/verify-consumer-android.py` (artifact) | `twf:871`、`tvci:379`、`tvca:296` | ✅ |
| 組み立てた発行物に入力の版が入る | `release.yml:203-213` (`-Pversion` と `Check publication`)、`scripts/release/check-android-artifacts.py:73-99` | `twf:896`、`tcaa` test_snapshot_version_in_the_pom_stops / test_reference_alone_checks_coordinates_and_commit。期待値: 座標の版 `0.1.0-beta.1`、`-SNAPSHOT` なし | ✅ |
| dry-run は公開の直前で終わる | `release.yml:251` (`production == 'true'` のときだけ publish)。後のジョブは publish の needs に連なり、自分の条件を持たない | `twf:833` | ✅ (実物: 10.3・10.8) |
| 公開の前の確認 — Side Effects (artifact・ランナーの作業ディレクトリ) | artifact `spm-snapshot`・`android-maven` (`release.yml:135-140`・`215-220`)、`release-notes` は release-notes の Requirement で数える | `twf:871` | ✅ |
| **公開の順序** | `release.yml:248-562` | `twf:778`・`twf:1020`・`twf:1030` | ✅ |
| tag と Release は公開の後に作られる | step の並び: Push SPM snapshot (382) → Upload to Maven Central (432) → Wait for validation (471) → Publish deployment (480) / Wait for publication (491) → Tag SPM repository (509) → Tag main repository (526) → Create release (537) | `twf:743` (release_problems の PUBLISH_ORDER)、`twf:778` test_公開のstepの順を入れ替えると落ちる | ✅ (実物: 10.9 で終わった時刻を並べる) |
| 検証の決着が失敗なら取り下げる | `scripts/release/central-portal.py` command_settle (FAILED で取り下げて失敗)、`release.yml:556-562` | `tcp` SettleTest.test_failed_validation_drops_the_deployment_and_fails、`twf:1013` | ✅ |
| 公開の指示の前に止まったら何も公開されない | `release.yml:556-562` (`failure() && steps.publish.outcome == 'skipped'` のときだけ取り下げる)、`central-portal.py` command_drop | `twf:1013`、`tcp` DropTest (4 件) | ✅ |
| Release の作りを確かめる | `release.yml:537-552` (`--verify-tag --title "${KS_VERSION}" --notes-file … --latest`。`--draft`・`--prerelease` なし) | `twf:1030` test_Releaseの属性 | ✅ (実物: 10.9) |
| 発行物が元の commit を持つ | `android/kscollectionview/build.gradle.kts` (`ksCollectionViewSourceCommit` を POM の `scm` の `tag` に書く・形の検査・無ければ送信のタスクを止める)、`release.yml:416`・`447` | `test_android_publication.py` BuildDefinitionTest (流れる)・GradlePublicationTest (4 件。`KS_GRADLE_TESTS=1` のときだけ。今回はスキップ — evidence/local-tests-001.md で 706 件・失敗 0)、`tcaa` test_commit_mismatch_stops、evidence/publish-rehearsal-001.md | ✅ (実物: 10.9) |
| 署名が欠けていると送らない | `release.yml:420-424` → `check-android-artifacts.py:100-119` | `tcaa` test_missing_signature_stops / test_signature_of_another_form_stops、`twf:938` | ✅ |
| 中身が組み立ての段と違うと送らない | 同上 | `tcaa` test_different_content_stops / test_extra_or_missing_files_stop | ✅ |
| 版を上げる commit を作らない | 本リポジトリへの書き込みは `gh api … git/refs` の tag と Release だけ (`release.yml:531`・`551`)。git の commit と push は配信用リポジトリの作業コピーだけ (`-C "$spm_dir"`) | `twf:1045` test_本リポジトリにcommitを作らない | ✅ |
| 公開の順序 — Side Effects | 配信用リポジトリの commit と tag (`382-405`・`509-523`)、Maven Central の送信・公開の指示・取り下げ (`432-497`・`556-562`)、本リポジトリの tag (`526-531`)、Release (`537-552`)、控えの artifact (`462-468`、消さない)、ランナーの作業ディレクトリ。列挙の外の状態変更は無い (ssh-agent は step の終わりに消す) | `twf:906`・`twf:993` | ✅ |
| **同じ版での再実行** | `release.yml:340-373`・`382-405`・`502-552`、`check-release-state.py:117-188`、`central-portal.py` command_inspect (263-282) | | ✅ |
| 公開の後で失敗したら、再実行で残りを作る | `Check published deployment` が公開済みなら、送信・公開・待ちの step を飛ばし (`409`・`421`・`434`・`472`・`482`・`492` の条件)、`Check published commit` (359-363) を通って tag の step へ進む | `twf:961` test_送信の操作は状態に応じて飛ばす、`tcp` PublishedTest、`tcrs` test_version_published_from_the_same_commit_continues | ✅ |
| tag が別の commit を指していると止まる | `check-release-state.py:123-133` | `tcrs` test_stops_when_the_main_tag_points_at_another_commit | ✅ |
| 配信用リポジトリの tag だけが別の写しを指すと止まる | `check-release-state.py:135-158` (tree の照合) | `tcrs` test_stops_when_only_the_spm_tag_differs_while_the_main_tag_matches、TagsWithRealSnapshotTest | ✅ |
| 別の commit から公開済みの版では止まる | validate: `check-release-state.py:168-188`。publish: `release.yml:359-363` (取得先の POM の commit を、写しの push より前に照らす) | `tcrs` test_version_published_from_another_commit_stops、`test_wait_for_maven_central.py` test_commit_mismatch_fails、`twf:950` | ✅ |
| Release がすでにあれば作らない | `release.yml:543-546` (`gh release view` で在れば作らず、本文も書き換えない。見つからない以外の誤りでは止まる) | `twf:1030` (view が create より前) | ✅ |
| 写しに差分が無ければ commit を作らない | `release.yml:398-403`、`scripts/release/place-spm-snapshot.py:96-142` | `twf:1078`、`test_place_spm_snapshot.py` test_stages_nothing_when_the_snapshot_is_already_there | ✅ |
| 残った保留の送信を使う | `central-portal.py` inspect (VALIDATED → reuse)、`release.yml:472`・`482` | `tcp` test_actions_by_state、RerunScenarioTest (送り直さずに公開の指示が 1 回) | ✅ |
| 取り下げ済みの控えは使わない | inspect (見つからない → upload、ID を渡さない) | `tcp` test_dropped_deployment_is_not_reused | ✅ |
| 公開の処理中なら送り直さずに待つ | inspect (PUBLISHING → wait-published)、`release.yml:491-497` (Publish deployment は飛ばす) | `tcp` test_actions_by_state、PublishTest.test_does_not_instruct_again_once_publishing、`twf:961` | ✅ |
| 同じ版での再実行 — Side Effects (公開の順序のうち未了のもの) | 上の条件で、済んだ工程の step を飛ばす | `twf:961`・`twf:1020` | ✅ |
| **公開の後の確認** | `release.yml:565-628` | `twf:888`・`twf:1085`・`twf:982` | ✅ |
| 公開物を取得してビルドする | `release.yml:585-599` (mode: published)、`verify-consumer-ios.py` (版の完全一致)、`verification/android/settings.gradle.kts` (published は Maven Central だけ) | `twf:888`、`tvci:344`・`tvci:648`、`tvca:643` | ✅ (実物: 10.9) |
| 最新の Release が今回の版を指す | `release.yml:611-628` (API の latest と、`/releases/latest` の行き先の両方) | `twf:1085` | ✅ (実物: 10.9) |
| 待ちの上限に達すると失敗で終わる | `scripts/release/wait-for-maven-central.py:68-101` | `test_wait_for_maven_central.py` test_reaching_the_limit_fails / DeadlineWithFakeClockTest、`test_release_support.py` WaitUntilTest | ✅ |
| 公開の後の確認 — Side Effects (なし) | 待ちと check-release は読むだけ。smoke の利用者役が作る一時の出力は、consumer-verification の Requirement の Side Effects で数える (ランナーの上で消える) | | ✅ |
| **secret の渡し方** | `release.yml:253` (Environment は publish だけ)、secret は step の env にだけ (`353-354` ほか)、deploy key は ssh-agent に標準入力から (`394`・`520`) | `twf:906`・`twf:921`・`twf:769` | ✅ |
| main 以外から起動した run には secret が渡らない | publish 以外のジョブは secret を参照しない (定義)。main 以外の本番は validate で止まる。Environment の branch policy (`main` だけ) は tasks 9.3 で設定する | `twf:906`、`tcrs` test_rejects_production_from_other_branches | ⏳ (Environment の設定 9.3 と、10.3・10.4 の run で確かめる。草稿 drafts/release-procedure.md:139-164 にコマンドと読み直しがある) |
| dry-run は secret を使わない | `release.yml:251` (dry-run では publish が走らない) | `twf:833`・`twf:906` | ✅ (実物: 10.3・10.8) |
| secret の渡し方 — Side Effects (なし) | 定義だけ。鍵とパスフレーズをファイルに書かない (known_hosts は公開の値) | `twf:921` | ✅ |

### release-notes

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **Pull Request のひな形** | `.github/pull_request_template.md` (`## Changes` と、注釈の中の書き方) | `test_repository_files.py` PullRequestTemplateTest (3 件) | ✅ |
| 新しい Pull Request の本文に書き方がある | 同上 (ノートになる・行の形・4 つの種類・`- none`・英語と利用者の言葉・内部の作業を載せない・ほかの書き方で止まる) | PullRequestTemplateTest.test_書き方に行の形と種類と変更が無いときと言語の決まりがある | ✅ |
| Pull Request のひな形 — Side Effects (なし) | 静的なファイル | | ✅ |
| **リリースノートの組み立て** | `scripts/release/build-release-notes.py`、`release.yml:91-104` | `tbrn` (22 件) | ✅ |
| 前回の Release より後の Pull Request だけが入る | `build-release-notes.py:197-208`・`251-262` | `tbrn` RangeTest.test_only_pull_requests_after_the_previous_release_are_included | ✅ |
| 初回は main の最初からの Pull Request が入る | 同上 (起点が無ければ first-parent の全体) | `tbrn` test_first_release_includes_every_pull_request_from_the_start_of_main | ✅ |
| 変更の節が無いと止まる | `build-release-notes.py:117-118`・`164-176` (番号を添える) | `tbrn` test_missing_section、test_stops_with_the_pull_request_number_when_a_section_is_missing | ✅ |
| 読めない行があると止まる | `build-release-notes.py:138-142` | `tbrn` test_unknown_kind、test_headings_and_prose_in_the_section、test_reports_every_problem_with_the_pull_request_number | ✅ |
| 注釈は読まない | `build-release-notes.py:114` | `tbrn` test_reads_lines_and_ignores_comments_and_blank_lines、test_section_inside_a_comment_is_not_a_section | ✅ |
| 空の節は止まる | `build-release-notes.py:128-129` | `tbrn` test_empty_section | ✅ |
| 説明の無い行は止まる | `build-release-notes.py:143-146` | `tbrn` test_empty_description | ✅ |
| 変更の節が 2 つあると止まる | `build-release-notes.py:119-120` | `tbrn` test_two_sections | ✅ |
| 次の見出しから先は節に入らない | `build-release-notes.py:123-125` | `tbrn` test_section_ends_at_the_next_heading | ✅ |
| none とほかの行が混ざると止まる | `build-release-notes.py:131-134` | `tbrn` test_none_mixed_with_other_lines | ✅ |
| すべてが none なら変更が無いことを書く | `build-release-notes.py:153-155` | `tbrn` test_all_none_gives_one_line。期待値: `No user-facing changes in this release.` の 1 行 | ✅ |
| 種類ごとに分かれる | `build-release-notes.py:156-161` | `tbrn` test_groups_lines_by_kind | ✅ |
| main 以外からの dry-run では組み立てない | `build-release-notes.py:281-284` (`built=false`)、`release.yml:99` | `tbrn` test_dry_run_outside_main_does_not_build、`twf:845` | ✅ |
| リリースノートの組み立て — Side Effects (artifact の作成) | `release.yml:98-104` (`release-notes`)。step の概要への表示は数えない | `twf:845` | ✅ |
| **ノートは 1 回だけ組み立てる** | publish は artifact `release-notes` を取り込み (`release.yml:318-322`)、`build-release-notes.py` を呼ばない | `twf:1030` | ✅ |
| 組み立ての後に本文を書き換えても Release は変わらない | 同上 | `twf:1030` (publish に `build-release-notes.py` が無い・`--notes-file` で取り込んだファイルを使う) | ✅ |
| ノートは 1 回だけ組み立てる — Side Effects (なし) | | | ✅ |

### release-skill

Skill の Scenario は、エージェントの振る舞いの約束で、自動のテストの対象は置き場の形だけである。ほかは `.agents/skills/release/SKILL.md` の文面と Scenario を照らした (下の「所見」の 2)。

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **Skill の置き場と呼び名** | `.agents/skills/release/SKILL.md` (name: release)、`.claude/skills/release` → `../../.agents/skills/release`、`AGENTS.md` の「リリース」の節 | `scripts/ci/check-project-skills.py .` (違反なし・Skill 2 つ) | ✅ |
| 実体が 1 つで、リンクで指される | 同上 (`docs-refresh` と同じ形) | 同上 | ✅ |
| Skill の置き場と呼び名 — Side Effects (なし) | | | ✅ |
| **頼まれたときだけ動く** | `SKILL.md:47-52`・`119`、description の「自分から起動しない」、`AGENTS.md` | 文面の照合 | ✅ |
| 頼まれていなければ動かない | `SKILL.md:50` | 文面の照合 | ✅ |
| 頼まれたときだけ動く — Side Effects (なし) | | | ✅ |
| **手順の正を読む** | `SKILL.md:10-34` | 文面の照合 | ✅ |
| 手順の文書が無いと止まる | `SKILL.md:20-26` (何も実行しない旨の文面) | 文面の照合 | ✅ (handbook の文書は蒸留で置く。それまでは Skill は必ずここで止まる) |
| 手順に無い状況では止まる | `SKILL.md:28`・`111` | 文面の照合 | ✅ |
| 手順の正を読む — Side Effects (なし) | | | ✅ |
| **事前の確認** | `SKILL.md:54-63`、`scripts/release/check-ci-skipped-changes.py` (代える判定)、drafts/release-procedure.md:291-345 | `test_check_ci_skipped_changes.py` (11 件) | ⚠️ deviation 記録済み (検証 CI の記録が無いときに、直近の成功で代える。範囲は deviation.md の記録どおり) |
| 手元が先行していれば push して検証を待つ | `SKILL.md:58`・`60` (push の直後に run が現れるまで読み直す) | 文面の照合 | ✅ |
| 手元が分かれていると止まる | `SKILL.md:58` | 文面の照合 | ✅ |
| 検証 CI が失敗していると止まる | `SKILL.md:59` | 文面の照合 | ✅ |
| 追従は確かめるだけで行わない | `SKILL.md:61` (`docs-refresh` の `check`) | 文面の照合 | ✅ |
| 事前の確認 — Side Effects (develop の push) | `SKILL.md:58`。`docs-refresh` の `check` と `check-ci-skipped-changes.py` は読むだけ | `test_check_ci_skipped_changes.py` (何も書き換えない形) | ✅ |
| **確認は 1 回** | `SKILL.md:65-92` | 文面の照合 | ✅ |
| 確定の前には公開を伴う操作をしない | `SKILL.md:80`・`121` | 文面の照合 | ✅ |
| 確定の後は止まらずに進む | `SKILL.md:81`・`83-85` | 文面の照合 | ✅ |
| 確定の後に develop が進んだらマージしない | `SKILL.md:82` | 文面の照合 | ✅ |
| 確認は 1 回 — Side Effects (Pull Request の作成とマージ・workflow の起動) | `SKILL.md:81` | | ✅ |
| **変更の節の下書き** | `SKILL.md:94-102` | 文面の照合 | ✅ |
| すでに main にある変更は載せない | `SKILL.md:96` | 文面の照合 | ✅ |
| 内部の作業だけなら none になる | `SKILL.md:98`・`101` | 文面の照合 | ✅ |
| 変更の節の下書き — Side Effects (なし) | 下書きは確定まで本文に書かない (`SKILL.md:80`) | | ✅ |
| **止まる条件** | `SKILL.md:104-115` | 文面の照合 | ✅ |
| workflow が失敗したら止まって位置を示す | `SKILL.md:110`・`114` | 文面の照合 | ✅ |
| 止まる条件 — Side Effects (なし) | | | ✅ |

### consumer-verification

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **利用者役の参照の書き方** (MODIFIED) | `scripts/ci/verify-consumer-ios.py` (MODES に artifact・dependency_line)、`verification/android/settings.gradle.kts` (3 つの切り替え) | | ✅ |
| iOS の利用者役が package の名前で product を指す | 既存 (変更なし) | `tvci:703` | ✅ |
| iOS の local は写しのディレクトリをパスで参照する | 既存 | `tvci:636`・`tvci:709` | ✅ |
| iOS の artifact は渡された写しをパスで参照する | `verify-consumer-ios.py` snapshot_argument と dependency_line | `tvci:389`・`tvci:399`・`tvci:641`・`tvci:713` | ✅ |
| iOS の published は配信用リポジトリを版の完全一致で参照する | 既存 | `tvci:344`・`tvci:648` | ✅ |
| Android の利用者役の依存は座標の 1 行である | 既存 | `tvca:635` | ✅ |
| Android の local と artifact は作業用のリポジトリだけから取る | `settings.gradle.kts` (published 以外は渡されたディレクトリを exclusiveContent に) | `tvca:643`・`tvca:662`・`tvca:308`・`tvca:215` | ✅ |
| Android の published は Maven Central だけから取る | 既存 | `tvca:643` | ✅ |
| 本体のソースを参照しない | 既存 | `tvci:721`、`tvca:672` | ✅ |
| 利用者役の参照の書き方 — Side Effects (なし) | | | ✅ |
| **iOS の利用者の立場のビルドの確認** (MODIFIED) | `verify-consumer-ios.py` | | ✅ |
| 配布物が正しければ成功する | 既存 (変更 package-distribution で実物を流した: kasane/changes/archive/2026-10-09-package-distribution/evidence/consumer-ios.md) | `tvci:215` ほか | ✅ |
| 写しに本体のソースが欠けていると失敗する | 既存 (同上の証跡) | `tvci:518` (写しの作成の失敗でビルドの前に止まる)、`test_sync_spm_snapshot.py` test_元が欠けていると… | ✅ |
| 片方の行き先だけが失敗しても失敗する | 既存 | `tvci:569` | ✅ |
| artifact では渡された写しで同じビルドを行う | `verify-consumer-ios.py` (artifact は写しを作らない) | `tvci:379`・`tvci:407`・`tvci:418` | ✅ |
| artifact で写しが無いと始めない | snapshot_argument (渡していない・マニフェストが無い・名前が違う) | `tvci:486`・`tvci:493`・`tvci:502` | ✅ |
| published では写しを作らずに同じビルドを行う | 既存 | `tvci:335` | ✅ |
| 知らない切り替えでは始めない | MODES の検査 | `tvci:454` | ✅ |
| published で版が無いと始めない | 既存 | `tvci:464`・`tvci:467` | ✅ |
| 追跡しているファイルを変えない | 既存。artifact は渡された写しも変えない | `tvci:294`・`tvci:433` | ✅ |
| iOS — Side Effects (一時の作業用のディレクトリ) | 一時のディレクトリだけで、終わると消す | `tvci:301`・`tvci:307`・`tvci:433` | ✅ |
| **Android の利用者の立場のビルドの確認** (MODIFIED) | `verify-consumer-android.py` | | ✅ |
| 配布物が正しければ成功する | 既存 (kasane/changes/archive/2026-10-09-package-distribution/evidence/consumer-android.md) | `tvca:176` | ✅ |
| コード縮小が走っている | 既存 | `tvca:494`・`tvca:681` | ✅ |
| 作業用のリポジトリに発行物が無いと失敗する | 既存 | `tvca:462`・`tvca:519` | ✅ |
| 既定の手元の Maven リポジトリに書かない | 既存 | `tvca:226`・`tvca:668` | ✅ |
| artifact では発行せずに渡されたリポジトリで組み立てる | `verify-consumer-android.py` (artifact は発行しない) | `tvca:296`・`tvca:308`・`tvca:325`・`tvca:336` | ✅ |
| artifact でリポジトリか版が無いと始めない | 同上の引数の検査 | `tvca:399`・`tvca:406`・`tvca:415` | ✅ |
| published では発行せずに同じ組み立てを行う | 既存 | `tvca:257` | ✅ |
| 知らない切り替えでは始めない | MODES の検査 | `tvca:379` | ✅ |
| published で版が無いと始めない | 既存 | `tvca:389`・`tvca:392` | ✅ |
| 追跡しているファイルを変えない | 既存。artifact は渡されたリポジトリも変えない | `tvca:348` | ✅ |
| Android — Side Effects (作業用のリポジトリ・本体と利用者役のビルドの出力) | artifact では発行しないので、本体の出力も作業用のリポジトリも作らない | `tvca:296`・`tvca:348` | ✅ |
| **利用者役の再利用 workflow が成果物を受け取る** (ADDED) | `.github/workflows/verify-consumer-ios.yml:36-40`・`64-77`・`119-136`、`.github/workflows/verify-consumer-android.yml` (同じ形) | `twf:247`・`twf:294`・`twf:317`・`twf:335` | ✅ |
| artifact の名前を渡すと取り込んで確認する | 同上 (Download artifact → スクリプトへ取り込んだ場所を渡す) | `twf:294`・`twf:317` | ✅ (実物: 10.3) |
| artifact の名前が無いと始めない | `Check inputs` の step (最初の step、名前が空なら失敗) | `twf:335` | ✅ |
| 検証 CI の呼び方は変わらない | `.github/workflows/ci.yml` は変更なし | `twf:150` | ✅ |
| 再利用 workflow — Side Effects (ランナーの作業ディレクトリ) | `${{ runner.temp }}/consumer-artifact/…` | `twf:317` | ✅ |

### verification-ci

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **道具の固定と権限** (MODIFIED) | `scripts/ci/check-workflows.py` (CONTENTS_WRITE_JOB の例外)、`release.yml` (action を commit の ID で指定・`ubuntu-24.04`・全ジョブの時間の上限) | `tcw`、`twf:791` | ✅ |
| 決めた版の Xcode が無いと落ちる | 既存 (`verify-ios.yml`) | `twf:392`・`twf:493` | ✅ |
| チェックサムが合わないと落ちる | 既存 (`ci.yml` の lint) | `twf:189` | ✅ |
| commit の ID で指定していない action があると落ちる | 既存。release.yml にも掛かる | `tcw:143`・`twf:791` | ✅ |
| 最新を指す名前のランナーがあると落ちる | 既存 | `tcw:177` | ✅ |
| 読み取り以外の権限があると落ちる | `check-workflows.py` check_permissions (例外は release.yml の publish の `contents: write` だけ) | `tcw:224`・`tcw:259`・`tcw:263`・`tcw:272` | ✅ |
| 公開のジョブの書き込みの権限は通る | 同上 | `tcw:253`、`twf:799` | ✅ |
| 公開のジョブでも、書き込み以外の権限は落ちる | 同上 | `tcw:279`・`tcw:291` | ✅ |
| 時間の上限を超えると落ちる | 全ジョブの `timeout-minutes` (`release.yml:56`・`124`・`151`・`260`・`570`・`607`)。打ち切りは GitHub が行う | `tcw:308`、`twf:982` | ✅ |
| 道具の固定と権限 — Side Effects (なし) | 検査は読むだけ | | ✅ |
| **リリースの workflow の定義の検査** (ADDED) | `twf` の `release_problems` と ReleaseWorkflowTest (`twf:734` 以降)。`run-tests.py` が lint の中で流す | | ✅ |
| tag の push での起動を足すと落ちる | | `twf:746` | ✅ |
| 公開の step の順を入れ替えると落ちる | | `twf:778` (順の食い違いを示す) | ✅ |
| 公開以外のジョブに環境を指定すると落ちる | | `twf:769` | ✅ |
| リリースの workflow の定義の検査 — Side Effects (なし) | | | ✅ |

### repository-publication

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **配信用リポジトリ** | tasks 9.1・9.2 で作る。備え: drafts/release-procedure.md:95-137 (作成・`has_issues` などを false・`pull_request_creation_policy=collaborators_only`・読み直し・deploy key)、drafts/branch-and-github-settings.md:130-141 (設定の値)、README は `scripts/distribution/spm-readme.template.md` が写しに入る。Release を作らないこと: `release.yml:551` は `--repo "${GITHUB_REPOSITORY}"` (本リポジトリ) だけに作る | `test_sync_spm_snapshot.py` (README のひな形を写しに入れる。既存) | ⏳ |
| 配信用リポジトリから本リポジトリへ案内される | `spm-readme.template.md` (配信用の写しであること・使い方と不具合の報告先は本リポジトリ) | 既存 (写しの道具のテスト)。実物: 10.9 の最初の push で置かれる | ⏳ |
| Issue を作れない | drafts/release-procedure.md:95-120 | 実物: 9.1 の読み直しの証跡 | ⏳ |
| 共同作業者でない人は Pull Request を作れない | 同上 | 実物: 9.1 の読み直しの証跡 | ⏳ |
| 配信用リポジトリ — Side Effects (なし) | 状態の宣言。設定の変更は tasks 9 の外向きの操作 | | ✅ |
| **リリース用の環境** | tasks 9.3・9.4 で作る。備え: drafts/release-procedure.md:139-189 (Environment の作成・branch policy を `main` だけ・読み直し・`gh secret list --env release` で 6 つの名前)。workflow 側は `release.yml:253` と、secret の名前 6 つ (`twf:906` の SECRET_STEPS) | `twf:906` | ⏳ |
| main 以外の run は環境を使えない | 同上 | 実物: 9.3 の読み直しと 10.4 | ⏳ (release-workflow の同名の行と同じ確認) |
| 必要な secret がそろっている | 同上 | 実物: 9.4 | ⏳ |
| リリース用の環境 — Side Effects (なし) | 同上 | | ✅ |

### user-readme

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| **インストール例** (MODIFIED) | `README.md`・`README_ja.md` の「Installation」「インストール」 | `test_repository_files.py:202`、`test_check_readme_examples.py` | ✅ (下の 1 件を除く) |
| 例の値が利用者役と同じである | 既存 | `test_repository_files.py:202`、`test_check_readme_examples.py:377` | ✅ |
| 版が書かれていない | 既存 | `test_check_readme_examples.py:363` | ✅ |
| 最新の版の確かめ先が分かる | 既存 | `test_check_readme_examples.py:460` | ✅ |
| まだ公開していないとは書かれていない | 今は `README.md:38`・`README_ja.md:38` に 1 文がある (tasks 10.5 で外す。design の Migration Plan のとおり、初回のリリースまでは残す)。備え: drafts/release-procedure.md:229-241 | なし (所見の 3) | ⏳ |
| インストール例 — Side Effects (なし) | 文書 | | ✅ |

## 実物でもう一度確かめる Scenario

テストと定義で ✅ だが、tasks 10 の run と公開で、実物の挙動としても確かめる予定のもの。初回のリリースの後の検証で、証跡と照らす。

| Scenario | 確かめる tasks |
|---|---|
| release-workflow: 正しい版で main から本番を起動する・tag と Release は公開の後に作られる・Release の作りを確かめる・発行物が元の commit を持つ・公開物を取得してビルドする・最新の Release が今回の版を指す | 10.9 |
| release-workflow: main 以外から本番を起動すると止まる | 10.4 |
| release-workflow: main 以外からの dry-run は受け付ける・dry-run は公開の直前で終わる・dry-run は secret を使わない、consumer-verification: artifact の名前を渡すと取り込んで確認する | 10.3・10.8 |
| release-notes: リリースノートの組み立て (#1・#2・リリースの Pull Request の 3 本の範囲) | 10.8・10.9 |

## 追加検査

- [x] tasks.md: [x] の 1.1・1.2・2.1〜2.7・3.1〜3.4・4.1〜4.3・5.1・6.1・6.2・7.1・7.2・8.1・8.2 は、対応表の実装・テスト・草稿・証跡に実物がある。1.3・9・10 は未着手で、チェックも無い。ただし 3.4 は、change の中に証跡のファイルが無い (所見の 1)
- [x] 逆流検査: `git diff HEAD` で、proposal.md・design.md・specs/ に差分は無い。これらの最後の変更は提案の commit 50bfee2 である。tasks.md の差分はチェックの付け替えだけである
- [x] 未記録乖離: ❌ が無いので、無い。diff にあって Scenario に対応しないファイルは、`kasane/lessons/inbox/define-gate-when-ci-is-not-triggered.md` (教訓の捕捉。ハーネスの記録で、実装ではない) と、change の中の review・second-opinion・drafts・evidence だけである。`[付随修正]` の行は deviation.md に無く、要る差分も無い
- [x] Side Effects (逆向きの検査): 26 の Requirement すべてに行を置いた。列挙の外の状態変更は見つからなかった
- [x] UI 変更: この change に UI は無い (ui/ も無い)
- [x] テスト: `python3 scripts/ci/run-tests.py` を流した。実行 728 件 / 失敗 0 / スキップ 4 (Gradle を実際に流す 4 件。`KS_GRADLE_TESTS=1` のときだけ流れる。evidence/local-tests-001.md で流した記録がある)。あわせて `python3 scripts/ci/check-workflows.py` (6 本・違反なし)・`actionlint` (違反なし)・`python3 scripts/ci/check-project-skills.py .` (違反なし) を流した。xcodebuild と gradlew は、パッケージの指示で流していない (4 系統の結果は evidence/local-tests-001.md)

## 所見 (判定に影響しない)

1. **tasks 3.4 の証跡が change の中に無い**: 3.4 (手元で `local` と `artifact` の両方で iOS と Android の確認を流す) はチェック済みだが、evidence/ に該当する記録が無い。deviation.md の蒸留送りに「手元で `artifact` を流す手順と所要時間」とあり、流した報告はあったと読めるが、この検証では確かめられなかった。虚偽とは判定しない。見立て: 実装の報告にある結果 (コマンド・所要・結果) を evidence/ に 1 枚残す (実装を直す必要は無い)。リリースの run の consumer-ios / consumer-android (10.3) でも同じことを実物で確かめる
2. **release-skill の Scenario は文面の照合だけ**: 自動のテストは置き場の形だけで、振る舞いの Scenario は Skill の文面と照らした。Decision 12 により初回のリリースは草稿に従い Skill を使わないので、Skill の振る舞いを実物で確かめるのは 2 回目のリリースになる。また handbook の手順の文書 (`kasane/handbook/cross/release-procedure.md`) は蒸留で置くので、蒸留までは Skill は「手順の文書が無い」で必ず止まる (spec どおり)
3. **user-readme「まだ公開していないとは書かれていない」にテストの予定が無い**: design の Context のとおり、その 1 文を見ている検査は無く、tasks 10.5 は文面を外すだけである。10.5 の後の検証では文面の照合で確かめることになる。見立て: 必要なら、README の検査に「公開していない旨の文が無い」ことを足すかを 10.5 のときに決める (足さないなら、照合で確かめたことを証跡に書く)
4. **リリースノートの範囲から、今回の版と同じ名前の Release を外している**: `build-release-notes.py:253`。spec の「公開済みの Release の tag のうち最も近いもの」を字義どおりに読むと、Release を作った後の再実行で、その Release が起点になり範囲が空になる。実装は、これを避けるために同じ版の Release を起点にしない。再実行では Release がすでにあれば作らず本文も書き換えないので、観察できる結果 (Release の本文) は spec と変わらない。「前回の Release」(Scenario の言葉) の解釈の内として ✅ にした

## 次の検証 (verify-002) で確かめること

- ⏳ の 7 件: 9.1・9.3・9.4 の設定の読み直しの証跡、10.4 の起動の結果、10.5 の README、10.9 の最初の push で置かれた配信用 README
- 「実物でもう一度確かめる Scenario」の表の各行を、10.3・10.4・10.8・10.9 の証跡 (step の終わった時刻・tag・Release の属性・最新の Release・POM の commit) と照らす
- tasks 1.3・9・10 のチェックと証跡の対応
