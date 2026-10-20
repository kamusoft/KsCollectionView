# Verify: release-pipeline (002)

検証した日: 2026-10-15 / 対象: `main` の df659f2 (#4 の merge commit。tree は `develop` の 769bb85 と同じ) と、作業ツリーの未 commit の記録 (tasks.md・deviation.md・drafts/release-procedure.md・evidence/ の 4 枚) / 時点: tasks 1〜10 がすべて完了 (初回のリリース 0.1.0-beta.1 の後)

## 判定: VALID

- デルタスペック 7 枚・Requirement 26・Scenario 112 を、実装・テスト・実物の証跡に 1 行ずつ対応させた (verify-001 の冒頭の「Scenario 114」は数え違いで、verify-001 の対応表の Scenario の行も 112 である)
- ❌ は 0 件。⚠️ (deviation 記録済み) は 1 件 (release-skill「事前の確認」。verify-001 と同じ)
- verify-001 の ⏳ (GitHub の準備と初回のリリースの後に確かめるもの) 7 件は、すべて解消した。うち 4 件は実物で ✅、3 件は設定の値までで ✅ にし、実物の操作では確かめていない (下の「実物で確かめられなかったもの」で分けて数える)
- verify-001 の「実物でもう一度確かめる Scenario」は、表のすべての行を実物の run と公開物で確かめ、食い違いは無かった
- 証跡の値は、GitHub (`gh api`・`gh run view`・`git ls-remote`) と Maven Central (`repo1.maven.org`) を読み取りだけで読み直し、どれも証跡と一致した
- 足場 (proposal・design・specs) は提案の commit 50bfee2 から変わっていない
- スクリプトのテストは、自分で流して 728 件・失敗 0・スキップ 4。4 系統 (iOS・Android の本体と Sample) は、df659f2 と同じ tree の 769bb85 の CI (#4 の必須の検査) で成功している

記号: ✅ 一致 (実物 = 実物の run・公開物でも確かめた / テスト = テストと定義で確かめ、実物の run ではその経路が起きていない) / ✅ (設定) = 設定の値で確かめ、実物の操作では確かめていない / ⚠️ deviation 記録済み / ❌ 欠落・乖離

実装とテストの列は verify-001 の対応表と同じ (実装のうち verify-001 の後に変わったのは `.agents/skills/release/SKILL.md` の 1 行と README 2 枚だけで、`.github/workflows/release.yml`・`scripts/`・テストは 119662f から変わっていない。行番号もそのまま使える)。下の表では、実装・テストは要点だけを書き、実物の証跡の列を足した。略号は verify-001 と同じ (`twf` = `scripts/ci/tests/test_workflow_files.py` ほか)。run の番号は次のとおり。

| 略号 | run | 何の run か | 結論 |
|---|---|---|---|
| R1 | [38721418708](https://github.com/kamusoft/KsCollectionView/actions/runs/38721418708) | `develop` (d8ec4c1) からの dry-run (tasks 10.3) | success |
| R2 | [38722143173](https://github.com/kamusoft/KsCollectionView/actions/runs/38722143173) | `develop` (d8ec4c1) からの本番 (tasks 10.4) | failure (validate) |
| R3 | [38724949662](https://github.com/kamusoft/KsCollectionView/actions/runs/38724949662) | `main` (df659f2) からの dry-run (tasks 10.8) | success |
| R4 | [38726124250](https://github.com/kamusoft/KsCollectionView/actions/runs/38726124250) | `main` (df659f2) からの本番 (tasks 10.9)。試行 1 は署名で失敗、試行 2 (失敗したジョブの再実行) で成功 | success (試行 2) |

## 対応表

### release-workflow

| Requirement / Scenario | 実装 / テスト | 実物の証跡 | 状態 |
|---|---|---|---|
| **リリースの起動** | `release.yml:26-37`、`scripts/release/check-release-state.py:66-89` | R1〜R4 (どれも `workflow_dispatch`) | ✅ 実物 |
| 正しい版で main から本番を起動する | `tcrs` test_accepts_production_from_main | R4 の validate の出力 `production=true`・`on-main=true`、後のジョブへ進んだ (evidence/github-release-run-001.md) | ✅ 実物 |
| 版の形が違うと最初に止まる | `tcrs` test_rejects_wrong_version_forms_first、`twf:845` | 実物では起こしていない (予定に無い) | ✅ テスト |
| main 以外から本番を起動すると止まる | `check-release-state.py:78-82`、`tcrs` test_rejects_production_from_other_branches | R2: validate の `Check inputs` が「本番 (dry-run でない起動) は main からだけ受け付ける (起動した ref: refs/heads/develop)」で失敗し、後のジョブはすべて skipped。起動の前後で外の状態は同じ (evidence/github-develop-runs-001.md。ログを読み直して一致) | ✅ 実物 |
| main 以外からの dry-run は受け付ける | `tcrs` test_accepts_dry_run_from_other_branches | R1: validate が success で、検証・組み立て・利用者役へ進んだ | ✅ 実物 |
| tag の push では起動しない | `release.yml:26-27`、`twf:746` | 参考: tag `0.1.0-beta.1` の作成 (11:43:27Z) の後、release.yml の run は R1〜R4 の 4 本 (すべて `workflow_dispatch`) のまま。ただし workflow の token で作った tag は元々 workflow を起動しないので、判定の根拠は定義とテスト | ✅ テスト |
| リリースの起動 — Side Effects (なし) | validate は確かめと step の出力だけ | R1・R2 の前後で、両リポジトリの tag・配信用リポジトリ・Release・Maven Central の POM が変わっていない | ✅ 実物 |
| **1 本ずつ流れる** | `release.yml:45-47`、`twf:759`・`twf:764` | R1〜R4 は時間が重なっていない | ✅ テスト |
| 走っている間に起動したものは待つ | 同上 (待ちの動きは GitHub の決まり) | 実物では起こしていない (予定に無い) | ✅ テスト |
| 待っているものがあるときに起動すると、待っていた方が取り消される | 同上 | 同上 | ✅ テスト |
| 1 本ずつ流れる — Side Effects (なし) | 定義だけ | | ✅ |
| **公開の前の確認** | `release.yml:107-238`・`250-251` | R1・R3・R4 で、検証・組み立て・利用者役の 6 ジョブがすべて success | ✅ 実物 |
| 検証が失敗すると公開に進まない | `twf:810` | release.yml の run で検証が失敗したことは無い | ✅ テスト |
| 利用者役は組み立てた配布物を使う | `release.yml:223-238`、`twf:871`・`tvci:379`・`tvca:296` | R3 のログ: consumer-ios に `mode: artifact`・`artifact: spm-snapshot` が渡り、success。R1 も同じ (evidence/github-develop-runs-001.md) | ✅ 実物 |
| 組み立てた発行物に入力の版が入る | `check-android-artifacts.py:73-99`、`twf:896`。期待値: `0.1.0-beta.1`、`-SNAPSHOT` なし | R4 の `Check signed publication`: 「Android の発行物 jp.kamusoft:kscollectionview:0.1.0-beta.1 を確かめた」。公開済みの POM の `<version>` は `0.1.0-beta.1` | ✅ 実物 |
| dry-run は公開の直前で終わる | `release.yml:251`、`twf:833` | R1・R3: `publish` 以降の 5 ジョブが skipped。起動の前後で外の状態は同じ (tag 無し・配信用リポジトリは空・Release 0 件・POM は 404) | ✅ 実物 |
| 公開の前の確認 — Side Effects (artifact・ランナーの作業ディレクトリ) | `release.yml:135-140`・`215-220` | R1・R3・R4 の artifact は `spm-snapshot`・`android-maven` (と release-notes の Requirement で数える `release-notes`) | ✅ 実物 |
| **公開の順序** | `release.yml:248-562`、`twf:778`・`twf:1020`・`twf:1030` | R4 の試行 2 の publish の step (下の行) | ✅ 実物 |
| tag と Release は公開の後に作られる | `twf:743`・`twf:778` | R4 の終わった時刻: 写しの push (試行 1。試行 2 は 11:34:35Z に差分なしで終了) → 保留の送信 11:36:20Z → 決着の待ち 11:36:51Z (VALIDATED) → 公開の指示 11:36:52Z → 公開済みの待ち 11:43:25Z (PUBLISHED) → 配信用リポジトリの tag 11:43:27Z → 本リポジトリの tag 11:43:28Z → Release 11:43:30Z。`gh api .../attempts/2/jobs` で読み直して証跡と一致 | ✅ 実物 |
| 検証の決着が失敗なら取り下げる | `central-portal.py` command_settle、`tcp` SettleTest、`twf:1013` | 実物の決着は VALIDATED で、この経路は起きていない | ✅ テスト |
| 公開の指示の前に止まったら何も公開されない | `release.yml:556-562`、`tcp` DropTest、`twf:1013` | GIVEN (保留で送った後に失敗) は起きていない。近い形として R4 の試行 1 が送信の前 (`Build signed publication`) で失敗し、Central Portal への送信は無く、`Drop pending deployment` は条件どおり skipped、tag・Release は作られず、POM は 404 のままだった | ✅ テスト |
| Release の作りを確かめる | `release.yml:537-552`、`twf:1030` | `gh release view` で読み直し: `tagName`・`name` とも `0.1.0-beta.1`、`isDraft: false`・`isPrerelease: false`、本文は `### Features` と #4 の 1 行 (R3・R4 の validate が組み立てたノートと同じ内容)。API の `releases/latest` も `0.1.0-beta.1` | ✅ 実物 |
| 発行物が元の commit を持つ | `android/kscollectionview/build.gradle.kts`、`test_android_publication.py`、`tcaa` test_commit_mismatch_stops | 公開済みの POM (`repo1.maven.org/.../kscollectionview-0.1.0-beta.1.pom`) の `<scm><tag>` は `df659f24e39f3129816bd9d9673b1bfb364d4da5` (起動した commit)。wait-for-registries のログも同じ commit | ✅ 実物 |
| 署名が欠けていると送らない | `check-android-artifacts.py:100-119`、`tcaa` test_missing_signature_stops ほか | 実物は署名がそろった形だけ (取得先に `.aar`・`.pom`・`.module`・`-sources.jar`・`-javadoc.jar` と、それぞれの `.asc` がどれも 200) | ✅ テスト |
| 中身が組み立ての段と違うと送らない | 同上、`tcaa` test_different_content_stops ほか | 実物は一致した形だけ (「組み立ての段 5 ファイル・署名したほう 5 ファイル」で一致。package-android と publish は別のランナー) | ✅ テスト |
| 版を上げる commit を作らない | `twf:1045` | `git ls-remote`: 本リポジトリの `refs/heads/main` は起動した commit df659f2 のままで、増えたのは `refs/tags/0.1.0-beta.1` だけ | ✅ 実物 |
| 公開の順序 — Side Effects | 配信用リポジトリの commit と tag・Maven Central の送信と公開の指示・本リポジトリの tag・Release・控えの artifact・ランナーの作業ディレクトリ | 実物で起きた状態変更: 配信用リポジトリの写しの commit 667175c (1 つだけ) と tag・Central Portal への送信 1 件と公開の指示・本リポジトリの tag・Release・artifact `central-portal-receipt-2`。列挙の外の変更は見つからなかった (GitHub が Environment の使用で自動で作る deployment の記録は、所見の 1) | ✅ 実物 |
| **同じ版での再実行** | `release.yml:340-373`・`382-405`・`502-552`、`check-release-state.py:117-188`、`central-portal.py` command_inspect | R4 の試行 2 は「失敗したジョブの再実行」の実物 | ✅ 実物 (一部の経路) |
| 公開の後で失敗したら、再実行で残りを作る | `twf:961`、`tcp` PublishedTest、`tcrs` test_version_published_from_the_same_commit_continues | 実物の失敗は公開の前 (署名) で、この経路は起きていない | ✅ テスト |
| tag が別の commit を指していると止まる | `tcrs` test_stops_when_the_main_tag_points_at_another_commit | 起きていない | ✅ テスト |
| 配信用リポジトリの tag だけが別の写しを指すと止まる | `tcrs` test_stops_when_only_the_spm_tag_differs_while_the_main_tag_matches | 起きていない | ✅ テスト |
| 別の commit から公開済みの版では止まる | `tcrs` test_version_published_from_another_commit_stops、`twf:950` | 起きていない | ✅ テスト |
| Release がすでにあれば作らない | `release.yml:543-546`、`twf:1030` | 起きていない (Release は 1 件) | ✅ テスト |
| 写しに差分が無ければ commit を作らない | `release.yml:398-403`、`place-spm-snapshot.py`、`twf:1078` | R4 の試行 2 の `Push SPM snapshot`: 「写しに差分が無いので、commit を作らない」。配信用リポジトリの commit は 667175c の 1 つだけ (`gh api .../commits` で 1 件) | ✅ 実物 |
| 残った保留の送信を使う | `tcp` test_actions_by_state、RerunScenarioTest | 起きていない (試行 1 は送信の前に止まり、試行 2 の `Inspect previous deployment` は控え無しで `action=upload`) | ✅ テスト |
| 取り下げ済みの控えは使わない | `tcp` test_dropped_deployment_is_not_reused | 起きていない | ✅ テスト |
| 公開の処理中なら送り直さずに待つ | `tcp` PublishTest、`twf:961` | 起きていない | ✅ テスト |
| 同じ版での再実行 — Side Effects (公開の順序のうち未了のもの) | 済んだ工程の step を飛ばす | R4 の試行 2 は、試行 1 で済んだ写しの push で新しい commit を作らず、未了の工程だけを行った | ✅ 実物 |
| **公開の後の確認** | `release.yml:565-628` | R4 の wait-for-registries・smoke-ios・smoke-android・check-release がすべて success | ✅ 実物 |
| 公開物を取得してビルドする | `release.yml:585-599`、`twf:888`・`tvci:344`・`tvca:643` | R4 のログ: smoke-ios に `mode: published`・`version: 0.1.0-beta.1`、smoke-android も同じで、どちらも success (配信用リポジトリの tag 667175c と Maven Central の公開物から取った) | ✅ 実物 |
| 最新の Release が今回の版を指す | `release.yml:611-628`、`twf:1085` | R4 の check-release のログ: 「最新の Release は 0.1.0-beta.1 を指す」。読み直し: `https://github.com/kamusoft/KsCollectionView/releases/latest` は `/releases/tag/0.1.0-beta.1` へ 302 で転送 | ✅ 実物 |
| 待ちの上限に達すると失敗で終わる | `wait-for-maven-central.py:68-101`、`test_wait_for_maven_central.py` | 実物は 6 秒で現れ、上限 (120 分) には遠い | ✅ テスト |
| 公開の後の確認 — Side Effects (なし) | 待ちと check-release は読むだけ | R4 の後の外の状態に、公開の順序で数えたもの以外の変化は無い | ✅ 実物 |
| **secret の渡し方** | `release.yml:253`、step の env だけ、`twf:906`・`twf:921`・`twf:769` | 下の 2 行 | ✅ 実物 |
| main 以外から起動した run には secret が渡らない | publish 以外のジョブは secret を参照しない、`tcrs` test_rejects_production_from_other_branches | R1・R2 とも `publish` は skipped。Environment `release` の deployment の記録は 2 件だけで、どちらも `ref=main`・df659f2 (R4 の試行 1・2)。`develop` の run で Environment に届いたジョブは無い | ✅ 実物 (verify-001 の ⏳ を解消) |
| dry-run は secret を使わない | `release.yml:251`、`twf:833`・`twf:906` | R3 (11:06〜11:12Z) は `publish` が skipped で、その時間帯に deployment の記録は無い (最初の記録は R4 の試行 1 の 11:21:31Z) | ✅ 実物 |
| secret の渡し方 — Side Effects (なし) | 定義だけ。鍵とパスフレーズをファイルに書かない | | ✅ |

### release-notes

| Requirement / Scenario | 実装 / テスト | 実物の証跡 | 状態 |
|---|---|---|---|
| **Pull Request のひな形** | `.github/pull_request_template.md`、`test_repository_files.py` PullRequestTemplateTest | (静的なファイル。変更なし) | ✅ |
| 新しい Pull Request の本文に書き方がある | PullRequestTemplateTest | | ✅ テスト |
| Pull Request のひな形 — Side Effects (なし) | | | ✅ |
| **リリースノートの組み立て** | `scripts/release/build-release-notes.py`、`release.yml:91-104`、`tbrn` | R3・R4 の validate | ✅ 実物 |
| 前回の Release より後の Pull Request だけが入る | `tbrn` RangeTest | 初回なので、この経路は起きていない | ✅ テスト |
| 初回は main の最初からの Pull Request が入る | `tbrn` test_first_release_includes_every_pull_request_from_the_start_of_main | R3・R4 のログ: 「範囲の起点: main の最初 / Pull Request: #1, #2, #3, #4」。権限 `contents: read` の token で範囲の本文を読めた | ✅ 実物 |
| 変更の節が無いと止まる | `tbrn` test_missing_section ほか | 起きていない (#1・#2 は tasks 10.6 で節を足した。evidence/github-pr-bodies-001.md) | ✅ テスト |
| 読めない行があると止まる | `tbrn` test_unknown_kind ほか | 起きていない (本文の末尾の署名の行は `## Notes` の下にある。#4 の本文を読み直して確かめた) | ✅ テスト |
| 注釈は読まない | `tbrn` | | ✅ テスト |
| 空の節は止まる | `tbrn` test_empty_section | | ✅ テスト |
| 説明の無い行は止まる | `tbrn` test_empty_description | | ✅ テスト |
| 変更の節が 2 つあると止まる | `tbrn` test_two_sections | | ✅ テスト |
| 次の見出しから先は節に入らない | `tbrn` test_section_ends_at_the_next_heading | #4 の本文: `## Changes` の 1 行の後の `## Notes` (署名の行) はノートに入っていない | ✅ 実物 |
| none とほかの行が混ざると止まる | `tbrn` test_none_mixed_with_other_lines | 起きていない | ✅ テスト |
| すべてが none なら変更が無いことを書く | `tbrn` test_all_none_gives_one_line | 起きていない (#4 に feature がある) | ✅ テスト |
| 種類ごとに分かれる | `tbrn` test_groups_lines_by_kind | Release の本文: `### Features` の下に #4 の 1 行。`- none` の #1〜#3 は載らない | ✅ 実物 |
| main 以外からの dry-run では組み立てない | `build-release-notes.py:281-284`、`tbrn` test_dry_run_outside_main_does_not_build | R1: `built=false`、`Upload release notes` は skipped、artifact `release-notes` は無い | ✅ 実物 |
| リリースノートの組み立て — Side Effects (artifact の作成) | `release.yml:98-104` | R3・R4 の artifact `release-notes` | ✅ 実物 |
| **ノートは 1 回だけ組み立てる** | publish は artifact `release-notes` を取り込む、`twf:1030` | R4 の publish の `Download release notes` が success。publish に組み立ての step は無い | ✅ 実物 |
| 組み立ての後に本文を書き換えても Release は変わらない | `twf:1030` | 実物で本文を書き換えてはいない | ✅ テスト |
| ノートは 1 回だけ組み立てる — Side Effects (なし) | | | ✅ |

### release-skill

初回のリリースは、Decision 12 のとおり草稿 (drafts/release-procedure.md) に従い、Skill を使っていない。Skill の Scenario は、verify-001 と同じく文面の照合で確かめた。verify-001 の後の Skill の変更は、付随修正の 1 文 (`.agents/skills/release/SKILL.md:102`。deviation.md に記録済み) だけで、どの Scenario の文面も変えていない。handbook の手順の文書 (`kasane/handbook/cross/release-procedure.md`) はまだ無いので、蒸留までは Skill は「手順の文書が無い」で止まる (spec どおり)。

| Requirement / Scenario | 実装 / テスト | 実物の証跡 | 状態 |
|---|---|---|---|
| **Skill の置き場と呼び名** | `.agents/skills/release/SKILL.md`、`.claude/skills/release` → `../../.agents/skills/release`、`AGENTS.md` | `check-project-skills.py .`: 違反なし (Skill 2 つ) | ✅ |
| 実体が 1 つで、リンクで指される | 同上 | 同上 | ✅ |
| Skill の置き場と呼び名 — Side Effects (なし) | | | ✅ |
| **頼まれたときだけ動く** | `SKILL.md:47-52` ほか | 文面の照合 | ✅ |
| 頼まれていなければ動かない | `SKILL.md:50` | 文面の照合 | ✅ |
| 頼まれたときだけ動く — Side Effects (なし) | | | ✅ |
| **手順の正を読む** | `SKILL.md:10-34` | 文面の照合 | ✅ |
| 手順の文書が無いと止まる | `SKILL.md:20-26` | 文面の照合。今は文書が無いので必ずここで止まる | ✅ |
| 手順に無い状況では止まる | `SKILL.md:28` ほか | 文面の照合 | ✅ |
| 手順の正を読む — Side Effects (なし) | | | ✅ |
| **事前の確認** | `SKILL.md:54-63`、`scripts/release/check-ci-skipped-changes.py`、`test_check_ci_skipped_changes.py` | 文面の照合 | ⚠️ deviation 記録済み (検証 CI の記録が無いときに、直近の成功で代える) |
| 手元が先行していれば push して検証を待つ | `SKILL.md:58`・`60` | 文面の照合 | ✅ |
| 手元が分かれていると止まる | `SKILL.md:58` | 文面の照合 | ✅ |
| 検証 CI が失敗していると止まる | `SKILL.md:59` | 文面の照合 | ✅ |
| 追従は確かめるだけで行わない | `SKILL.md:61` | 文面の照合 | ✅ |
| 事前の確認 — Side Effects (develop の push) | `SKILL.md:58` | | ✅ |
| **確認は 1 回** | `SKILL.md:65-92` | 文面の照合 | ✅ |
| 確定の前には公開を伴う操作をしない | `SKILL.md:80` ほか | 文面の照合 | ✅ |
| 確定の後は止まらずに進む | `SKILL.md:81`・`83-85` | 文面の照合 | ✅ |
| 確定の後に develop が進んだらマージしない | `SKILL.md:82` | 文面の照合 | ✅ |
| 確認は 1 回 — Side Effects (Pull Request の作成とマージ・workflow の起動) | `SKILL.md:81` | | ✅ |
| **変更の節の下書き** | `SKILL.md:94-103` | 文面の照合 | ✅ |
| すでに main にある変更は載せない | `SKILL.md:96` | 文面の照合 | ✅ |
| 内部の作業だけなら none になる | `SKILL.md:98`・`101` | 文面の照合 | ✅ |
| 変更の節の下書き — Side Effects (なし) | | | ✅ |
| **止まる条件** | `SKILL.md:105-116` | 文面の照合 | ✅ |
| workflow が失敗したら止まって位置を示す | `SKILL.md:111`・`115` | 文面の照合 | ✅ |
| 止まる条件 — Side Effects (なし) | | | ✅ |

### consumer-verification

| Requirement / Scenario | 実装 / テスト | 実物の証跡 | 状態 |
|---|---|---|---|
| **利用者役の参照の書き方** (MODIFIED) | `scripts/ci/verify-consumer-ios.py`、`verification/android/settings.gradle.kts` | R1・R3・R4 の consumer / smoke | ✅ 実物 |
| iOS の利用者役が package の名前で product を指す | `tvci:703` | | ✅ テスト |
| iOS の local は写しのディレクトリをパスで参照する | `tvci:636`・`tvci:709` | #3・#4 の必須の検査 `consumer-ios / verify` (local) が pass | ✅ 実物 |
| iOS の artifact は渡された写しをパスで参照する | `tvci:389` ほか | R1・R3・R4 の consumer-ios (`mode: artifact`) が success | ✅ 実物 |
| iOS の published は配信用リポジトリを版の完全一致で参照する | `tvci:344`・`tvci:648` | R4 の smoke-ios (`mode: published`・`version: 0.1.0-beta.1`) が success | ✅ 実物 |
| Android の利用者役の依存は座標の 1 行である | `tvca:635` | | ✅ テスト |
| Android の local と artifact は作業用のリポジトリだけから取る | `tvca:643` ほか | R1・R3・R4 の consumer-android (artifact) と、#3・#4 の `consumer-android / verify` (local) が success | ✅ 実物 |
| Android の published は Maven Central だけから取る | `tvca:643` | R4 の smoke-android (`mode: published`) が success。ログ: 実行時の依存に座標が指定の版で現れる | ✅ 実物 |
| 本体のソースを参照しない | `tvci:721`、`tvca:672` | | ✅ テスト |
| 利用者役の参照の書き方 — Side Effects (なし) | | | ✅ |
| **iOS の利用者の立場のビルドの確認** (MODIFIED) | `verify-consumer-ios.py` | | ✅ |
| 配布物が正しければ成功する | `tvci:215` ほか | R1・R3・R4 の consumer-ios・smoke-ios が success | ✅ 実物 |
| 写しに本体のソースが欠けていると失敗する | `tvci:518`、`test_sync_spm_snapshot.py` | | ✅ テスト |
| 片方の行き先だけが失敗しても失敗する | `tvci:569` | | ✅ テスト |
| artifact では渡された写しで同じビルドを行う | `tvci:379`・`tvci:407`・`tvci:418` | R1・R3・R4 の consumer-ios。手元: evidence/consumer-artifact-local-001.md | ✅ 実物 |
| artifact で写しが無いと始めない | `tvci:486`・`tvci:493`・`tvci:502` | | ✅ テスト |
| published では写しを作らずに同じビルドを行う | `tvci:335` | R4 の smoke-ios | ✅ 実物 |
| 知らない切り替えでは始めない | `tvci:454` | | ✅ テスト |
| published で版が無いと始めない | `tvci:464`・`tvci:467` | | ✅ テスト |
| 追跡しているファイルを変えない | `tvci:294`・`tvci:433` | | ✅ テスト |
| iOS — Side Effects (一時の作業用のディレクトリ) | `tvci:301`・`tvci:307`・`tvci:433` | | ✅ |
| **Android の利用者の立場のビルドの確認** (MODIFIED) | `verify-consumer-android.py` | | ✅ |
| 配布物が正しければ成功する | `tvca:176` | R1・R3・R4 の consumer-android・smoke-android が success | ✅ 実物 |
| コード縮小が走っている | `tvca:494`・`tvca:681` | | ✅ テスト |
| 作業用のリポジトリに発行物が無いと失敗する | `tvca:462`・`tvca:519` | | ✅ テスト |
| 既定の手元の Maven リポジトリに書かない | `tvca:226`・`tvca:668` | 手元: evidence/consumer-artifact-local-001.md | ✅ テスト |
| artifact では発行せずに渡されたリポジトリで組み立てる | `tvca:296` ほか | R1・R3・R4 の consumer-android | ✅ 実物 |
| artifact でリポジトリか版が無いと始めない | `tvca:399`・`tvca:406`・`tvca:415` | | ✅ テスト |
| published では発行せずに同じ組み立てを行う | `tvca:257` | R4 の smoke-android | ✅ 実物 |
| 知らない切り替えでは始めない | `tvca:379` | | ✅ テスト |
| published で版が無いと始めない | `tvca:389`・`tvca:392` | | ✅ テスト |
| 追跡しているファイルを変えない | `tvca:348` | | ✅ テスト |
| Android — Side Effects (作業用のリポジトリ・本体と利用者役のビルドの出力) | `tvca:296`・`tvca:348` | | ✅ |
| **利用者役の再利用 workflow が成果物を受け取る** (ADDED) | `.github/workflows/verify-consumer-ios.yml`・`verify-consumer-android.yml`、`twf:247` ほか | R1・R3・R4 | ✅ 実物 |
| artifact の名前を渡すと取り込んで確認する | `twf:294`・`twf:317` | R3 のログ: consumer-ios に `artifact: spm-snapshot` が渡り、`actions/download-artifact` で取り込んで success | ✅ 実物 |
| artifact の名前が無いと始めない | `twf:335` | 起きていない | ✅ テスト |
| 検証 CI の呼び方は変わらない | `twf:150` | #3・#4 の必須の検査 `consumer-ios / verify`・`consumer-android / verify` が従来の名前と呼び方で pass (evidence/github-prep-pr-001.md・github-release-pr-001.md) | ✅ 実物 |
| 再利用 workflow — Side Effects (ランナーの作業ディレクトリ) | `twf:317` | | ✅ |

### verification-ci

| Requirement / Scenario | 実装 / テスト | 実物の証跡 | 状態 |
|---|---|---|---|
| **道具の固定と権限** (MODIFIED) | `scripts/ci/check-workflows.py`、`tcw`、`twf:791` | 自分で流した `check-workflows.py`: 6 本・違反なし。#4 の必須の検査 `lint` が pass | ✅ |
| 決めた版の Xcode が無いと落ちる | `twf:392`・`twf:493` | | ✅ テスト |
| チェックサムが合わないと落ちる | `twf:189` | | ✅ テスト |
| commit の ID で指定していない action があると落ちる | `tcw:143`・`twf:791` | | ✅ テスト |
| 最新を指す名前のランナーがあると落ちる | `tcw:177` | | ✅ テスト |
| 読み取り以外の権限があると落ちる | `tcw:224` ほか | | ✅ テスト |
| 公開のジョブの書き込みの権限は通る | `tcw:253`、`twf:799` | R4 の publish が `contents: write` で tag と Release を作れた | ✅ 実物 |
| 公開のジョブでも、書き込み以外の権限は落ちる | `tcw:279`・`tcw:291` | | ✅ テスト |
| 時間の上限を超えると落ちる | `tcw:308`、`twf:982` | | ✅ テスト |
| 道具の固定と権限 — Side Effects (なし) | | | ✅ |
| **リリースの workflow の定義の検査** (ADDED) | `twf` の `release_problems` と ReleaseWorkflowTest | 自分で流した run-tests.py に含まれ、通る | ✅ |
| tag の push での起動を足すと落ちる | `twf:746` | | ✅ テスト |
| 公開の step の順を入れ替えると落ちる | `twf:778` | | ✅ テスト |
| 公開以外のジョブに環境を指定すると落ちる | `twf:769` | | ✅ テスト |
| リリースの workflow の定義の検査 — Side Effects (なし) | | | ✅ |

### repository-publication

verify-001 で ⏳ にした Requirement の行 2 つと Scenario 5 件。今回、GitHub の設定を読み直した値は次のとおり (どれも証跡と一致)。

| 読み直したもの | 値 |
|---|---|
| `repos/kamusoft/KsCollectionView-SPM` | `visibility: public`・`has_issues: false`・`has_wiki: false`・`has_projects: false`・`has_discussions: false`・`pull_request_creation_policy: collaborators_only`・`default_branch: main`・`archived: false` |
| 配信用リポジトリの共同作業者 | 1 つ (`admin`) |
| 配信用リポジトリの deploy key | 1 つ (`release workflow (kamusoft/KsCollectionView)`、`read_only: false`) |
| 配信用リポジトリの Release | 0 件 |
| 配信用リポジトリの ref (`git ls-remote`) | `HEAD`・`refs/heads/main`・`refs/tags/0.1.0-beta.1` がどれも 667175c (commit は 1 つ、tree は c61b8ced。メッセージは `KsCollectionView 0.1.0-beta.1 (df659f2…)`) |
| 配信用リポジトリの中身 | `LICENSE`・`Package.swift`・`README.md`・`Sources`・`Tests` |
| Environment `release` | `deployment_branch_policy: {protected_branches: false, custom_branch_policies: true}`・`protection_rules: ["branch_policy"]`・ブランチの決まりは `main` (`type: branch`) の 1 件。リポジトリの Environment は `release` だけ |
| Environment `release` の secret の名前 | `MAVEN_CENTRAL_PASSWORD`・`MAVEN_CENTRAL_USERNAME`・`SIGNING_KEY` (更新 11:31:45Z。試行 1 の後の登録し直し)・`SIGNING_KEY_ID`・`SIGNING_PASSWORD`・`SPM_DEPLOY_KEY` の 6 つ。リポジトリの secret は 0 件 |

| Requirement / Scenario | 実装 / テスト | 実物の証跡 | 状態 |
|---|---|---|---|
| **配信用リポジトリ** | 設定 (tasks 9.1・9.2)、`scripts/distribution/spm-readme.template.md`、Release は本リポジトリにだけ作る (`release.yml:551`) | 上の表: public・Issue 無効・Pull Request は共同作業者だけ・書き込みは deploy key (書き込み可) と管理者 1 つだけ・Release 0 件 | ✅ 実物 (verify-001 の ⏳ を解消) |
| 配信用リポジトリから本リポジトリへ案内される | `spm-readme.template.md`、`test_sync_spm_snapshot.py` | 配信用リポジトリのルートの README を API で読み、ひな形とバイトで同じであることを確かめた。「distribution mirror」であること・ソースと文書と Issue は本リポジトリにあること・使い方は本リポジトリの README・問題と提案は本リポジトリの Issues へ、が書かれている (本リポジトリは `has_issues: true`) | ✅ 実物 (⏳ を解消) |
| Issue を作れない | 設定 `has_issues: false` | 設定の値で確かめた。補助: サインインしていない状態で `.../KsCollectionView-SPM/issues/new` は 404。共同作業者でないアカウントで作成を試してはいない | ✅ (設定) (⏳ を解消。実物の操作は未確認) |
| 共同作業者でない人は Pull Request を作れない | 設定 `pull_request_creation_policy: collaborators_only` | 設定の値で確かめた。共同作業者でないアカウントの fork から作成を試してはいない | ✅ (設定) (⏳ を解消。実物の操作は未確認) |
| 配信用リポジトリ — Side Effects (なし) | 状態の宣言 | | ✅ |
| **リリース用の環境** | 設定 (tasks 9.3・9.4)、`release.yml:253`、`twf:906` | 上の表。R4 で、`main` からの publish が secret を受け取り、署名 (秘密鍵とパスフレーズ)・Central Portal の認証・deploy key の書き込みがどれも通った | ✅ 実物 (⏳ を解消) |
| main 以外の run は環境を使えない | 設定 (ブランチの決まりは `main` だけ) | 設定の値で確かめた。`develop` の run (R1・R2) は Environment を指定するジョブまで進まず (dry-run と validate で止まる)、Environment の保護が実際にジョブを止める場面は起きていない。deployment の記録が `ref=main` の 2 件だけであることは確かめた | ✅ (設定) (⏳ を解消。実物の操作は未確認) |
| 必要な secret がそろっている | 名前の一覧 | 名前の一覧で 6 つ (上の表)。R4 の試行 2 で 6 つとも使われて通った | ✅ 実物 (⏳ を解消) |
| リリース用の環境 — Side Effects (なし) | 状態の宣言 | | ✅ |

### user-readme

| Requirement / Scenario | 実装 / テスト | 実物の証跡 | 状態 |
|---|---|---|---|
| **インストール例** (MODIFIED) | `README.md`・`README_ja.md` のインストールの節 (df659f2 と作業ツリーで同じ)、`test_repository_files.py:202`、`test_check_readme_examples.py` | `check-readme-examples.py .`: 違反なし (最小コード例 4 つ・依存の宣言の行 12 行) | ✅ |
| 例の値が利用者役と同じである | `test_repository_files.py:202`、`test_check_readme_examples.py:377` | README の Package URL (`https://github.com/kamusoft/KsCollectionView-SPM`・`exact:`) と座標 (`jp.kamusoft:kscollectionview`) で、R4 の smoke の利用者役が公開物を取れた | ✅ 実物 |
| 版が書かれていない | `test_check_readme_examples.py:363` | | ✅ テスト |
| 最新の版の確かめ先が分かる | `test_check_readme_examples.py:460` | 節の先頭の Releases へのリンクの先に、Release `0.1.0-beta.1` (最新) がある | ✅ 実物 |
| まだ公開していないとは書かれていない | tasks 10.5 で段落を外した (769bb85。README 2 枚の 38 行目) | 文面の照合: インストールの節は `{version}` の置き換えの説明から始まる。`grep -n -i "not yet\|not been published\|まだ公開\|公開していない\|unreleased" README.md README_ja.md` は 0 件 (自分で流した)。自動の検査は足していない (evidence/readme-before-release-001.md。verify-001 の所見の 3 のとおり、照合で確かめたことを証跡に書く形) | ✅ (⏳ を解消) |
| インストール例 — Side Effects (なし) | 文書 | | ✅ |

## 実物で確かめられなかったもの (✅ (設定) の 3 件)

設定の値では spec どおりで、乖離ではない。実物の操作で確かめるには、次の理由で、この検証の範囲を超える。

| Scenario | 設定の値で確かめたこと | 実物で確かめなかった理由 |
|---|---|---|
| repository-publication: Issue を作れない | `has_issues: false` (Issue の機能が無いこと自体が THEN)。補助としてサインインしていない状態の `issues/new` が 404 | 共同作業者でないアカウントでサインインして作成を試す必要がある。手元に該当するアカウントが無く、作成の試みは GitHub への書き込みで、パッケージの制約で禁止 |
| repository-publication: 共同作業者でない人は Pull Request を作れない | `pull_request_creation_policy: collaborators_only`、共同作業者は管理者 1 つだけ | 共同作業者でないアカウントで fork を作り、Pull Request の作成を試す必要がある。上と同じ理由 |
| repository-publication: main 以外の run は環境を使えない | Environment `release` のブランチの決まりは `main` の 1 件だけ・保護の規則は `branch_policy`。`develop` の run から Environment に届いた記録 (deployment) は無い | release.yml は `develop` からの run を Environment を指定するジョブの手前で止める (validate と dry-run) ので、正規の起動では保護が働く場面が来ない。確かめるには、`develop` から Environment を指定するジョブを走らせる一時の workflow が要り、workflow の書き換えと起動はパッケージの制約で禁止 |

あわせて、実物の run で起きなかった経路 (失敗・再実行の分岐と、同時の起動) は、テストと定義で ✅ にした (上の表の「✅ テスト」)。これらは verify-001 でも実物で確かめる予定に入れておらず、今回の未確認には数えない。

## verify-001 の「実物でもう一度確かめる Scenario」との照合

| verify-001 の行 | 確かめた run・公開物 | 結果 |
|---|---|---|
| release-workflow: 正しい版で main から本番を起動する・tag と Release は公開の後に作られる・Release の作りを確かめる・発行物が元の commit を持つ・公開物を取得してビルドする・最新の Release が今回の版を指す | R4 (試行 2)、`gh release view`、`git ls-remote`、公開済みの POM | すべて一致 |
| release-workflow: main 以外から本番を起動すると止まる | R2 | 一致 |
| release-workflow: main 以外からの dry-run は受け付ける・dry-run は公開の直前で終わる・dry-run は secret を使わない、consumer-verification: artifact の名前を渡すと取り込んで確認する | R1・R3、deployment の記録 | 一致 |
| release-notes: リリースノートの組み立て (#1・#2・リリースの Pull Request の範囲) | R3・R4 の validate (#1〜#4)、Release の本文 | 一致 (範囲は準備の Pull Request #3 を含む 4 本。#1〜#3 は `- none`) |

## 追加検査

- [x] tasks.md: 1.1〜10.9 がすべて [x]。今回の作業ツリーの差分は 1.3・10.7・10.8・10.9 のチェックだけ。各タスクに証跡がある: 1.3 → evidence/owner-decisions-1-3.md (名前空間 `jp.kamusoft` は検証済み。実際に `jp.kamusoft:kscollectionview:0.1.0-beta.1` が公開された)、9.1 → github-spm-repository-001.md、9.2〜9.4 → github-release-environment-001.md、10.1 → ci-develop-001.md (run 38718155347 が success)、10.2 → github-prep-pr-001.md、10.3・10.4 → github-develop-runs-001.md、10.5 → readme-before-release-001.md、10.6 → github-pr-bodies-001.md、10.7 → github-release-pr-001.md、10.8 → github-main-dry-run-001.md、10.9 → github-release-run-001.md。証跡の値 (merge commit・run の結論・tag・Release・POM) は読み直して一致した。verify-001 の所見の 1 (3.4 の証跡が無い) は evidence/consumer-artifact-local-001.md で解消している。虚偽のチェックは無い
- [x] 逆流検査: `git log` で proposal.md・design.md・specs/ の最後の変更は提案の commit 50bfee2。`git diff 50bfee2` (作業ツリーまで) で差分は無い
- [x] 未記録乖離: ❌ が無いので無い。verify-001 の後に入った実装側の差分 (`git diff 119662f df659f2`、kasane/ を除く) は、`.agents/skills/release/SKILL.md` の 1 文 (deviation.md の `[付随修正]` に記録済み)・README 2 枚の段落の削除 (tasks 10.5、spec user-readme の実装)・`android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsImageCacheContractTest.kt` (別の change `android-prefetch-failure-test-on-ci` の 105ec13 で、この change の差分ではない) だけ。作業ツリーの未 commit の差分のうち drafts/release-procedure.md の secret の登録の段は `[付随修正]` に記録済み、`kasane/lessons/inbox/guide-secret-registration-with-one-command.md` は教訓の捕捉 (ハーネスの記録で、実装ではない)
- [x] Side Effects (逆向きの検査): 26 の Requirement すべてに行を置いた。今回は実物で起きた状態変更も照らし、列挙の外のものは見つからなかった (所見の 1 の deployment の記録は数えないものとして扱った)
- [x] 付随修正: deviation.md の `[付随修正]` 2 行 (Skill と草稿の見出しの 1 文・草稿の secret の登録の段) は対応表の対象外。diff の該当箇所と一致する
- [x] UI 変更: この change に UI は無い
- [x] テスト: `python3 scripts/ci/run-tests.py` を流した。実行 728 件 / 失敗 0 / スキップ 4 (`KS_GRADLE_TESTS=1` のときだけ流れる Gradle の実物の 4 件。R4 で、同じ設定の実物の署名と公開が通った)。あわせて `check-workflows.py` (6 本・違反なし)・`check-project-skills.py .` (違反なし)・`check-readme-examples.py .` (違反なし)・`actionlint` (違反なし) を流した。4 系統 (iOS・Android の本体と Sample) は手元では流していない。df659f2 と同じ tree の 769bb85 の CI (push の run 38724029546・#4 の run 38724047156) で `ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify` が success であることを読み直した

## 所見 (判定に影響しない)

1. **Environment の deployment の記録**: publish のジョブが Environment `release` を指定すると、GitHub が本リポジトリに deployment の記録を自動で作る (今は R4 の試行 1・2 の 2 件)。spec の「公開の順序」の Side Effects には無い。run の履歴やログと同じく GitHub の操作の履歴で、この change のどの能力も仕様として読まない (この検証で secret の渡し方を確かめる補助に使っただけ) ので、Side Effects に数えないものとして ✅ にした。見立て: 数えるべきと判断するなら、蒸留で concepts に書くときに、Environment を使うと deployment の記録が残ることを添える (実装を直す必要は無い)
2. **試行 1 で、tag の無い写しが配信用リポジトリに先に置かれた**: R4 の試行 1 は写しの push の後、署名で止まった。spec の公開の順序 (写しの push が 1 番目、tag は 5 番目) どおりで、tag が無い間は利用者の解決 (版の完全一致) に現れない。試行 2 はこの写しを差分なしとして使い、新しい commit を作らなかった。原因 (`SIGNING_KEY` に公開鍵を登録していた) は手順の草稿の付随修正と教訓の inbox に記録済み
3. **verify-001 の Scenario の数**: verify-001 の冒頭の「Scenario 114」は数え違いで、spec の `#### Scenario:` は 112、verify-001 の対応表の Scenario の行も 112 である。判定には影響しない
4. **release-skill は実物で使っていない**: 初回は Decision 12 のとおり草稿で進めたので、Skill の振る舞いの Scenario を実物で確かめるのは、蒸留で `kasane/handbook/cross/release-procedure.md` を置いた後の 2 回目のリリースになる (verify-001 の所見の 2 と同じ)
5. **送信の ID**: R4 の publish のログに Central Portal の送信の ID が出ている。secret ではないが、証跡 (github-release-run-001.md) は ID を書かずに「run のログにある」としており、この検証も書いていない

## 蒸留に向けて

- この change は、spec と実装・実物の一致の点では、アーカイブしてよい状態である
- deviation.md の蒸留送り (handbook の手順・設定の文書・verification-ci・consumer-build-check・user-docs-writing の直し) と、教訓の inbox 2 件 (`define-gate-when-ci-is-not-triggered.md`・`guide-secret-registration-with-one-command.md`) は、ksn-distill の入力になる
- 作業ツリーの未 commit の記録 (tasks.md・deviation.md・drafts/release-procedure.md・evidence/ の 4 枚・lessons の 1 枚・この verify-002.md) は、まだ commit されていない
