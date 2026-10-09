# Verify 002: package-distribution

実施日: 2026-10-09。対象: commit `6e420a7` (`develop` の先端。`main` には merge commit `f2c1473` で入っている) と、その後の作業ツリーの未 commit の変更 (`tasks.md` のグループ 9 のチェックと、証跡 `evidence/public-repository-checks.md`)。`drafts/` は、別の作業が記入している最中なので対象にしていない。

`verify-001.md` は、tasks のグループ 9 が未実施だった時点の検証である。この検証は、グループ 9 の実施の後の、全 Scenario の最終の判定である。

## 判定

**VALID**。

| 状態 | Scenario の数 |
|---|---:|
| ✅ 一致 | 59 |
| ⚠️ 合意済みの乖離 (deviation 記録済み) | 1 |
| ⏳ 未実施 | 0 |
| ❌ 乖離 | 0 |
| 合計 | 60 |

- 前回「未実施」だった 7 つの Scenario は、GitHub の今の状態を読み直して、7 つとも一致と判定した
- Side Effects の行 (Requirement 13 個) は、13 個とも一致
- 未記録の乖離・虚偽チェック・逆流・テストの失敗は無い
- 証跡 `evidence/public-repository-checks.md` の値と、この検証で読み直した値に、食い違いは無い

## 表記

パスは、次の頭を略して書く。

| 略 | 実際のパス |
|---|---|
| `W/` | `.github/workflows/` |
| `C/` | `scripts/ci/` |
| `T/` | `scripts/ci/tests/` |
| `D/` | `scripts/distribution/` |
| `V/` | `verification/` |
| `A/` | `android/` |
| `E/` | `evidence/` (この change の中) |

確認の出どころは、次の 4 つを書き分ける。

| 語 | 意味 |
|---|---|
| 読み直し | この検証で、GitHub の今の状態を読み取った結果 (下の「GitHub の読み直し」) |
| 今回の実測 | この検証で、手元で流した結果 (スクリプトのテストだけ) |
| 前回の実測 | `verify-001.md` が自分で流した結果。この検証では流し直していない |
| 証跡 | 実装の側と指揮側が残した記録を読んだもの |

## 前回の検証の後に変わった箇所

前回「一致」「合意済みの乖離」だった 53 の Scenario は、前回の後の差分を次のように確かめたうえで、前回の判定を引き継いだ。

| 確かめたこと | 結果 |
|---|---|
| commit `6e420a7` に入っているファイルのうち、`verify-001.md` の更新の時刻より後に書き換わったもの | `C/verify-consumer-android.py`・`tasks.md`・`drafts/` の 3 枚だけ。本体・Sample・利用者役・workflow・ほかのスクリプト・テストは、前回の検証の後に変わっていない |
| `C/verify-consumer-android.py` の変更 | `:69` のコメント 1 行 (「コード縮小を有効にしたリリースの組み立てで、ここに対応表ができる」)。前回の気付き (R8 が書くという説明が正確でない) を受けた直しで、行の数は変わらず、コードは変わっていない |
| `HEAD` に対する作業ツリーの差分 | `tasks.md` (グループ 9 の 5 行のチェック) と、未追跡の `E/public-repository-checks.md` だけ (この検証の時点) |
| スクリプトのテスト | 今回の実測: 実行 262 件 / 失敗 0 件 / スキップ 0 件 |

- コメントの直しは、commit `6e420a7` に入っている (作業ツリーの未 commit の変更ではない)。ランナーの上の 2 つの実行は、この直しを含む commit に対して走っている
- 対応表の `path:line` は前回のものを引き継いだ。変わった 1 行は行の数を変えないので、ずれは無い (`W/ci.yml:64`・`:71`、`T/test_workflow_files.py` のテストの位置、`C/verify-consumer-android.py:69`・`:70` は、この検証で読んで確かめた)

## 対応表: package-distribution

| Requirement / Scenario | 実装 | テスト・確認 | 状態 |
|---|---|---|---|
| iOS のマニフェストが要求するツールの版 / 宣言が確かめている版と一致する | `ios/Package.swift:1` | `T/test_sync_spm_snapshot.py:450` (今回の実測) | ✅ 一致 |
| 同 / 宣言を上げてもテストが通る | `ios/Package.swift:1` | 前回の実測: 本体 567・Sample 48、失敗 0、スキップ 0。証跡: `E/local-completion.md` 8.1 | ✅ 一致 |
| 同 — Side Effects (なし) | 宣言の 1 行だけ。状態を変える処理は無い | — | ✅ 一致 |
| SwiftPM の写しを作る / 空の行き先に 5 点が置かれる | `D/sync-spm-snapshot.py:277-286` | `T/test_sync_spm_snapshot.py:153`・`:467` (今回の実測) | ✅ 一致 |
| 同 / 無い行き先は作られる | `D/sync-spm-snapshot.py:247-248`・`:297` | `T/test_sync_spm_snapshot.py:161` (今回の実測) | ✅ 一致 |
| 同 / マニフェストが本体と同じ内容である | `D/sync-spm-snapshot.py:281` | `T/test_sync_spm_snapshot.py:167`・`:467` (今回の実測) | ✅ 一致 |
| 同 / 追跡していないファイルは写されない | `D/sync-spm-snapshot.py:109-117` | `T/test_sync_spm_snapshot.py:197`・`:484` (今回の実測) | ✅ 一致 |
| 同 / 本体から消えたファイルは残らない | `D/sync-spm-snapshot.py:256-269` | `T/test_sync_spm_snapshot.py:216` (今回の実測) | ✅ 一致 |
| 同 / 行き先の git の状態を進めない | `D/sync-spm-snapshot.py:263-264`。git は読み取りだけに呼ぶ (`:112`・`:180`・`:188`・`:211`) | `T/test_sync_spm_snapshot.py:227` (今回の実測) | ✅ 一致 |
| 同 / README がこのリポジトリへ案内する | `D/sync-spm-snapshot.py:283`、`D/spm-readme.template.md:9` | `T/test_sync_spm_snapshot.py:475` (今回の実測) | ✅ 一致 |
| 同 / 元が欠けていると何も消さない | `D/sync-spm-snapshot.py:120-146`・`:292` | `T/test_sync_spm_snapshot.py:269`・`:308` (今回の実測) | ✅ 一致 |
| 同 / このリポジトリの中を行き先にすると拒否する | `D/sync-spm-snapshot.py:242-243` | `T/test_sync_spm_snapshot.py:314`・`:328` (今回の実測) | ✅ 一致 |
| 同 / このリポジトリを含むディレクトリを行き先にすると拒否する | `D/sync-spm-snapshot.py:244-245` | `T/test_sync_spm_snapshot.py:333` (今回の実測) | ✅ 一致 |
| 同 / 中身があって配信用リポジトリの作業コピーでない行き先を拒否する | `D/sync-spm-snapshot.py:176-195` | `T/test_sync_spm_snapshot.py:346`・`:352`・`:367`・`:371` (今回の実測) | ✅ 一致 |
| 同 — Side Effects | 書くのは行き先だけ: 作成 (`:297`)・`.git` を除く中身の削除 (`:298`)・5 点の作成 (`:299`)。列挙に収まる | `T/test_sync_spm_snapshot.py:227`・`:258` (今回の実測) | ✅ 一致 |
| Android の発行物 / 鍵なしで手元に発行できる | `A/kscollectionview/build.gradle.kts:75-86`・`:132-136` | 前回の実測: 5 点、`.asc` は 0。証跡: `E/android-publishing.md` 3.4 | ✅ 一致 |
| 同 / 外から渡した版で発行される | `A/build.gradle.kts:12-16` | 前回の実測: `-Pversion=0.0.1-check` で `0.0.1-check/` の下に 5 点 | ✅ 一致 |
| 同 / POM が決めた項目を持つ | `A/kscollectionview/build.gradle.kts:95-125` | 前回の実測: 名前・説明・URL・MIT License・開発者・`scm` がある | ✅ 一致 |
| 同 / 依存の範囲が公開面と合う | `A/kscollectionview/build.gradle.kts:184-204` | 前回の実測: ui-graphics と ui-unit は POM に直接は無く、ui が届ける。annotation 1.9.1 は直接ある。証跡: `E/android-publishing.md` 3.3 | ⚠️ deviation 記録済み (`deviation.md:3`) |
| 同 / 鍵を渡すと署名が付く | `A/kscollectionview/build.gradle.kts:93` | 前回の実測: 使い捨ての鍵で 5 点それぞれに `.asc`。証跡: `E/android-publishing.md` 3.4 | ✅ 一致 |
| 同 — Side Effects | 発行先に渡したディレクトリと、`android/` の下のビルドの出力だけ。列挙に収まる | 前回の実測 (既定の手元の Maven リポジトリは前後で同じ) | ✅ 一致 |
| 開発中の版を Maven Central へ送らない / 開発中の版のままでは送れない | `A/kscollectionview/build.gradle.kts:156-178` | 前回の実測: 送る 3 つのタスクが終了コード 1、動いたタスク 0。証跡: `E/android-publishing.md` 3.2 | ✅ 一致 |
| 同 / 開発中の版でも手元には発行できる | 同上 (手元への発行のタスクは対象外) | 前回の実測: 版 `0.1.0-SNAPSHOT` で `publishToMavenLocal` が成功 | ✅ 一致 |
| 同 — Side Effects | Maven Central への送信は行っていない。列挙に収まる | 前回の実測。読み直し: リモートに tag は 0 個で、公開に関わる実行も無い | ✅ 一致 |

## 対応表: consumer-verification

| Requirement / Scenario | 実装 | テスト・確認 | 状態 |
|---|---|---|---|
| 利用者役の参照の書き方 / iOS の利用者役が package の名前で product を指す | `V/ios/Package.swift.template:33` | `T/test_verify_consumer_ios.py:578`・`:240` (今回の実測) | ✅ 一致 |
| 同 / iOS の local は写しのディレクトリをパスで参照する | `C/verify-consumer-ios.py:142`・`:238` | `T/test_verify_consumer_ios.py:226`・`:210`・`:584` (今回の実測) | ✅ 一致 |
| 同 / iOS の published は配信用リポジトリを版の完全一致で参照する | `C/verify-consumer-ios.py:140-141` | `T/test_verify_consumer_ios.py:334`・`:529`・`:588` (今回の実測) | ✅ 一致 |
| 同 / Android の利用者役の依存は座標の 1 行である | `V/android/app/build.gradle.kts:73` | `T/test_verify_consumer_android.py:511` (今回の実測) | ✅ 一致 |
| 同 / Android の local は作業用のリポジトリだけから取る | `V/android/settings.gradle.kts:57-69`、`C/verify-consumer-android.py:212-217` | `T/test_verify_consumer_android.py:206`・`:519`・`:540` (今回の実測)。前回の実測: 空のディレクトリを渡すと、探した場所はそのディレクトリだけ | ✅ 一致 |
| 同 / Android の published は Maven Central だけから取る | `V/android/settings.gradle.kts:57-69` | `T/test_verify_consumer_android.py:519`・`:248` (今回の実測)。証跡: `E/consumer-android.md` | ✅ 一致 |
| 同 / 本体のソースを参照しない | `V/ios/Package.swift.template:26-36`、`V/android/settings.gradle.kts:54-84` | `T/test_verify_consumer_ios.py:592`・`:624`、`T/test_verify_consumer_android.py:544` (今回の実測) | ✅ 一致 |
| 同 — Side Effects (なし) | 定義のファイルだけで、状態を変える処理は無い | — | ✅ 一致 |
| iOS の利用者の立場のビルドの確認 / 配布物が正しければ成功する | `C/verify-consumer-ios.py:231-243`・`:94-98` | 読み直し: ランナーの上の `consumer-ios / verify` が success (実行 37891421543)。前回の実測: `--mode local` が終了コード 0。証跡: `E/consumer-ios.md` 4.4 | ✅ 一致 |
| 同 / 写しに本体のソースが欠けていると失敗する | `C/verify-consumer-ios.py:221-228` | 前回の実測: 一時のツリーで本体のソースを 1 つ欠くと終了コード 1。証跡: `E/consumer-ios.md` 4.5 | ✅ 一致 |
| 同 / 片方の行き先だけが失敗しても失敗する | `C/verify-consumer-ios.py:241-242` | `T/test_verify_consumer_ios.py:457` (今回の実測) | ✅ 一致 |
| 同 / published では写しを作らずに同じビルドを行う | `C/verify-consumer-ios.py:237-242` | `T/test_verify_consumer_ios.py:325`・`:343`・`:354` (今回の実測) | ✅ 一致 |
| 同 / 知らない切り替えでは始めない | `C/verify-consumer-ios.py:127-128`・`:249-251` | `T/test_verify_consumer_ios.py:374`・`:379` (今回の実測) | ✅ 一致 |
| 同 / published で版が無いと始めない | `C/verify-consumer-ios.py:133-134` | `T/test_verify_consumer_ios.py:382`・`:385` (今回の実測) | ✅ 一致 |
| 同 / 追跡しているファイルを変えない | `C/verify-consumer-ios.py:234`・`:54` | `T/test_verify_consumer_ios.py:284`・`:246`・`:641` (今回の実測)。前回の実測: 実行の前後で `git status` と `git diff` が同じ | ✅ 一致 |
| 同 — Side Effects | 一時のディレクトリだけを作り、終わると消す (`T/test_verify_consumer_ios.py:291`・`:297`)。列挙に収まる | 前回の実測 | ✅ 一致 |
| Android の利用者の立場のビルドの確認 / 配布物が正しければ成功する | `C/verify-consumer-android.py:276-294` | 読み直し: ランナーの上の `consumer-android / verify` が success (実行 37891421543)。前回の実測: `--mode local` が終了コード 0。`T/test_verify_consumer_android.py:167`・`:183` (今回の実測) | ✅ 一致 |
| 同 / コード縮小が走っている | `V/android/app/build.gradle.kts:47-50`、`C/verify-consumer-android.py:220-236` | `T/test_verify_consumer_android.py:370`・`:377`・`:553` (今回の実測)。前回の実測: 対応表のファイルがある。証跡: `E/consumer-android.md` 5.2 | ✅ 一致 |
| 同 / 作業用のリポジトリに発行物が無いと失敗する | `V/android/settings.gradle.kts:57-69` | 前回の実測: 空のディレクトリを渡すと終了コード 1。`T/test_verify_consumer_android.py:352` (今回の実測) | ✅ 一致 |
| 同 / 既定の手元の Maven リポジトリに書かない | `C/verify-consumer-android.py:198`・`:287` | `T/test_verify_consumer_android.py:217` (今回の実測)。前回の実測: 既定の手元の Maven リポジトリの一覧が前後で同じ | ✅ 一致 |
| 同 / published では発行せずに同じ組み立てを行う | `C/verify-consumer-android.py:278-284` | `T/test_verify_consumer_android.py:248`・`:262`・`:275` (今回の実測) | ✅ 一致 |
| 同 / 知らない切り替えでは始めない | `C/verify-consumer-android.py:114-115` | `T/test_verify_consumer_android.py:292`・`:297` (今回の実測) | ✅ 一致 |
| 同 / published で版が無いと始めない | `C/verify-consumer-android.py:120-121` | `T/test_verify_consumer_android.py:300`・`:303` (今回の実測) | ✅ 一致 |
| 同 / 追跡しているファイルを変えない | `C/verify-consumer-android.py:52`・`:287` | 前回の実測: 実行の前後で `git status --porcelain -uall` と `git diff` が同じ。証跡: `E/consumer-android.md` 5.5 | ✅ 一致 |
| 同 — Side Effects | 一時の Maven リポジトリ (終わると消す)・`android/` の下のビルドの出力 (`local` だけ)・`verification/android/` の下のビルドの出力。列挙に収まる | 前回の実測。`T/test_verify_consumer_android.py:562` (今回の実測) | ✅ 一致 |
| 確認の失敗が記録に残る / 準備が失敗した理由が記録に出る | `C/verify-consumer-ios.py:162-170`・`:181-182`、`C/verify-consumer-android.py:151-159`・`:200-201` | `T/test_verify_consumer_ios.py:406`・`:500`、`T/test_verify_consumer_android.py:319`・`:427` (今回の実測) | ✅ 一致 |
| 同 / 準備が失敗したらビルドを始めない | `C/verify-consumer-ios.py:237-240`、`C/verify-consumer-android.py:290-292` | `T/test_verify_consumer_ios.py:406`・`:426`・`:433`・`:475`・`:485`、`T/test_verify_consumer_android.py:319`・`:338`・`:345` (今回の実測) | ✅ 一致 |
| 同 — Side Effects (なし) | 出力を流すだけ | — | ✅ 一致 |
| コード縮小を有効にした利用者役の起動の確認 / 起動して一覧が表示される | `V/android/app/` | 証跡: `E/consumer-android.md` 5.7、`E/consumer-android-list-minified.png`、`E/consumer-android-launch-logcat.txt` | ✅ 一致 |
| 同 — Side Effects | 作業専用の AVD は削除済み (前回の実測)。証跡の 3 枚が `evidence/` にある。列挙に収まる | 前回の実測 | ✅ 一致 |

## 対応表: verification-ci

| Requirement / Scenario | 実装 | テスト・確認 | 状態 |
|---|---|---|---|
| 検証 CI の起動条件 (MODIFIED) / develop への push で起動する | `W/ci.yml:26-33`・`:64`・`:71` | 読み直し: 実行 37890909399 (起動の種類 push、ブランチ `develop`、commit `6e420a7`) で、`lint`・`ios / verify`・`android / verify` が success、`consumer-ios`・`consumer-android` が skipped。全体は success。`T/test_workflow_files.py:87`・`:132` (今回の実測) | ✅ 一致 |
| 同 / 開発の記録だけの push では起動しない | `W/ci.yml:26-33` (本変更で変えていない) | `T/test_workflow_files.py:93` (今回の実測)。実地は前の変更で確認済み (`kasane/changes/archive/2026-10-08-public-repo-verify-ci/verify-002.md`) | ✅ 一致 |
| 同 / main 宛ての Pull Request では絞り込まない | `W/ci.yml` (Pull Request の起動にパスの絞り込みが無い。ジョブは 5 つ) | 読み直し: 実行 37891421543 (起動の種類 pull_request、commit `6e420a7`) で、5 つのジョブがすべて走って success。Pull Request 2 番は `kasane/` 配下を含む 111 ファイルの変更で、絞り込まれていない。`T/test_workflow_files.py:100`・`:115` (今回の実測) | ✅ 一致 |
| 同 / 起動の対象になる新しい push が古い実行を打ち切る | `W/ci.yml:42-44` (本変更で変えていない) | `T/test_workflow_files.py:104` (今回の実測)。実地は前の変更で確認済み (同上) | ✅ 一致 |
| 同 / 起動しない push は走っている実行に影響しない | `W/ci.yml:26-33`・`:42-44` (本変更で変えていない) | `T/test_workflow_files.py:93`・`:104` (今回の実測)。実地は前の変更で確認済み (同上) | ✅ 一致 |
| 同 — Side Effects | 起きたのは実行の作成だけ (push で 1 つ、Pull Request で 1 つ)。読み直し: 実行の一覧で、本変更の commit に対する実行はこの 2 つだけで、マージの後に作られた実行は無い。打ち切られた実行も無い。足した 2 つのジョブは書き込みの権限を持たない (`W/ci.yml:36-37`) | 読み直し。`T/test_workflow_files.py:264`・`:305` (今回の実測) | ✅ 一致 |
| 利用者の立場のビルドの確認の再利用 / 検査が決めた名前で報告される | `W/ci.yml:62-74`、`W/verify-consumer-ios.yml`・`W/verify-consumer-android.yml` のジョブの名前 `verify` | 読み直し: 実行 37891421543 のジョブの名前と、commit `6e420a7` の検査の一覧 (Pull Request の実行の分) が、`lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify` の 5 つ。既存の 3 つの名前は変わっていない。`T/test_workflow_files.py:147` (今回の実測) | ✅ 一致 |
| 同 / 別の workflow から切り替えを渡して呼べる | `W/verify-consumer-ios.yml:19-30`、`W/verify-consumer-android.yml:20-31` | `T/test_workflow_files.py:224`・`:231` (今回の実測) | ✅ 一致 |
| 同 / 入口は local で呼ぶ | `W/ci.yml:62-74` | `T/test_workflow_files.py:132`・`:141` (今回の実測) | ✅ 一致 |
| 同 — Side Effects (なし) | 定義だけ | — | ✅ 一致 |
| 利用者の立場のビルドの確認の道具と権限 / workflow の定義の検査が新しい workflow でも通る | `W/verify-consumer-ios.yml`、`W/verify-consumer-android.yml` | `T/test_workflow_files.py:264` (今回の実測)。読み直し: ランナーの上の `lint` が 2 つの実行とも success。前回の実測: `check-workflows.py` と `actionlint` が違反なし | ✅ 一致 |
| 同 / 決めた版の Xcode が無いと落ちる | `W/verify-consumer-ios.yml:58-69` | `T/test_workflow_files.py:326`・`:335`・`:338` (今回の実測)。前回の実測: step の本文を、無い版で流すと終了コード 1 | ✅ 一致 |
| 同 / 失敗を見逃す指定が無い | 同 2 本 | `T/test_workflow_files.py:259`・`:290` (今回の実測) | ✅ 一致 |
| 同 — Side Effects (なし) | 権限は内容の読み取りだけ (`W/verify-consumer-ios.yml:32-33`、`W/verify-consumer-android.yml:33-34`)。依存の取得のキャッシュは結果を変えないキャッシュで、数えない | `T/test_workflow_files.py:379` (今回の実測) | ✅ 一致 |

旧い挙動のテストは残っていない (前回の確認のとおり。テストのファイルは前回の後に変わっていない)。

時間の上限 (tasks 9.5) は、2 本とも 15 分のまま (`W/verify-consumer-ios.yml:47`、`W/verify-consumer-android.yml:43`)。Requirement が求めるのは「各ジョブは時間の上限を持つ」で、値は決めていない。証跡の判断 (変えない) と、今の定義は一致している。

## 対応表: repository-publication

| Requirement / Scenario | 実装 (GitHub の設定と操作) | テスト・確認 | 状態 |
|---|---|---|---|
| ブランチの保護 (MODIFIED) / 報告された名前を確かめてから足す | `main` の保護の必須の検査 | 読み直し: Pull Request 2 番の実行 37891421543 が `consumer-ios / verify`・`consumer-android / verify` を報告している (06:01:51 開始、06:05:07 までに 2 つとも success)。`main` の保護には、今その 2 つが入っている。順序: `verify-001.md` が読んだ時点 (commit の前) では必須の検査は 3 つだった。足した時刻そのものは GitHub から読み取れないので、「報告を読んだ後に足した」ことは証跡 (`E/public-repository-checks.md` 9.2 → 9.3) による | ✅ 一致 |
| 同 / main の保護に必須の検査が 5 つ入っている | `main` の保護 | 読み直し: 必須の検査は 5 件で、名前は `lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify`。5 件とも `app_id` が 15368 (GitHub Actions。commit の検査の一覧でも、検査を出したアプリは `github-actions` の 15368)。`strict` は false。Pull Request の必須の設定があり、承認の必要数は 0。強制 push と削除は禁止 (`allow_force_pushes`・`allow_deletions` が false)。`enforce_admins` は false | ✅ 一致 |
| 同 / develop の保護は変わらない | `develop` の保護 | 読み直し: 必須の検査の項目も Pull Request の必須の項目も無い。強制 push と削除は禁止。`enforce_admins` は false。`verify-001.md` が更新の前に読んだ値と同じ | ✅ 一致 |
| 同 / main には 5 つの検査を通った develop が入る | Pull Request 2 番 | 読み直し: Pull Request 2 番 (`develop` → `main`、同じリポジトリの中) は MERGED (06:10:44)。先端の commit `6e420a7` で 5 つの検査が success (最後の終了は 06:06:53 で、マージより前)。merge commit `f2c1473` の親は 2 つ (`479fcdc` と `6e420a7`)。`main` の先端は `f2c1473` で、その中身 (tree) は `develop` の先端 `6e420a7` と同じ | ✅ 一致 |
| 同 — Side Effects | 下の「Side Effects の逆向きの検査」 | 読み直し | ✅ 一致 |

### Side Effects の逆向きの検査 (ブランチの保護)

| 起きた状態の変更 | 列挙のどれに当たるか | 読み直した値 |
|---|---|---|
| `main` の保護の更新 | 「GitHub のブランチの保護の設定 (`main`): 更新 (必須の検査を 3 つから 5 つにする)」 | 必須の検査が 5 件。そのほかの値 (`strict` false・承認の数 0・`dismiss_stale_reviews`・`require_code_owner_reviews`・`require_last_push_approval` が false・`enforce_admins` false・強制 push と削除の禁止・`required_linear_history`・`required_signatures`・`required_conversation_resolution`・`lock_branch`・`block_creations`・`allow_fork_syncing` が false) は、証跡の「更新の前に読んだ値」と同じ。`verify-001.md` が更新の前に読んだ値 (承認の数 0・強制 push と削除は禁止・管理者には強制しない) とも合う |
| Pull Request 2 番の作成とマージ | 「GitHub 上の Pull Request (`develop` から `main`): 作成、マージ (`main` に merge commit が加わる)」 | 本変更で作られた Pull Request は 2 番の 1 件だけ (全体では 1 番と 2 番の 2 件で、1 番は前の変更のもの)。`main` に加わったのは merge commit `f2c1473` の 1 つ |
| 証跡の作成 | 「変更の証跡 (`evidence/`): 作成」 | `E/public-repository-checks.md` がある (実行したコマンドと、読み直しの結果) |

列挙に無い変更は見つからなかった。

- `develop` の保護は変わっていない。`develop` のブランチは残っていて、先端は `6e420a7` のまま
- リモートの参照は `main`・`develop` と、Pull Request の 2 つの参照だけ。tag は 0 個
- マージの後に作られた検証の実行は無い
- `develop` への push (tasks 9.1) は、Scenario の WHEN に当たる操作そのもので、検証の実行の作成は Requirement「検証 CI の起動条件」の Side Effects に数えた

## GitHub の読み直し

この検証で読んだもの (どれも読み取りだけ)。時刻は UTC。

| 読んだもの | 読み直した値 | 証跡の値との突き合わせ |
|---|---|---|
| `main` の保護 | 上の対応表のとおり | 一致 (9.3 の「更新の後に読み直した値」) |
| `develop` の保護 | 上の対応表のとおり | 一致 (9.3) |
| 実行 37890909399 | workflow `CI`、起動の種類 push、`develop`、commit `6e420a7`、全体 success。`lint` 05:55:40〜05:55:58、`ios / verify` 05:55:47〜05:58:23、`android / verify` 05:55:52〜06:00:42、`consumer-ios`・`consumer-android` は skipped | 一致 (9.1。結果・時刻とも) |
| 実行 37891421543 | workflow `CI`、起動の種類 pull_request、commit `6e420a7`、全体 success。`lint` 06:01:51〜06:02:08、`ios / verify` 06:01:59〜06:06:03、`android / verify` 06:01:51〜06:06:53、`consumer-ios / verify` 06:01:57〜06:03:55、`consumer-android / verify` 06:01:51〜06:05:07 | 一致 (9.2。結果・時刻とも) |
| Pull Request 2 番 | MERGED、06:10:44、`develop` → `main`、先端 `6e420a7`、merge commit `f2c1473`、`isCrossRepository` は false。検査の一覧には、Pull Request の実行の 5 つ (success) と、push の実行の 5 つ (success 3・skipped 2) が並ぶ | 一致 (9.2・9.4)。マージの前の `mergeable`・`mergeStateStatus` は、マージの後には読み直せない (証跡の値のまま) |
| merge commit `f2c1473` | 親は `479fcdc` と `6e420a7` | 一致 (9.4) |
| リモートの参照 (`git ls-remote origin`) | `main` は `f2c1473`、`develop` は `6e420a7` | 一致 (9.4) |
| 実行の一覧 (新しい順に 7 つ) | 本変更の commit に対する実行は上の 2 つだけ | 一致 (9.4「マージの後に、`main` への push で起動した実行は無い」) |

## 追加検査

| 検査 | 結果 |
|---|---|
| tasks.md | グループ 1〜9 はすべてチェック済み。グループ 9 の 5 件は、読み直した GitHub の状態 (9.1〜9.4) と、証跡と今の定義 (9.5) で裏付けられる。虚偽チェックは無い |
| 逆流 | `proposal.md`・`design.md`・`specs/` は、提案の commit `192a10b` から変わっていない (履歴はその 1 commit だけで、作業ツリーにも変更が無い) |
| 未記録の乖離 | 無い |
| deviation.md | 乖離 1 行 (依存の範囲)。前回の検証の後に変わっていない。`[付随修正]` の行は無い |
| Scenario に対応しない変更 | 前回の後は、`C/verify-consumer-android.py:69` のコメント 1 行だけ。挙動を変えないコメントの直しで、付随修正 (不具合・不整合の修正) には当たらない |
| UI 変更 | 該当しない (`ui/` は無い) |
| テスト | スクリプトのテストは今回の実測で 262 件・失敗 0。テスト 4 系統は、前回の実測 (iOS 本体 567・iOS Sample 48・Android 本体 512・Android Sample 163、すべて失敗 0) の後に、本体・Sample・利用者役のソースが変わっていないことを確かめたので、流し直していない。ランナーの上でも、`android / verify` (JVM のテスト) と `ios / verify` (ビルド) が同じ commit で success |

## この検証で流したもの

| 流したもの | 結果 |
|---|---|
| `python3 scripts/ci/run-tests.py` | 実行 262 件 / 失敗 0 件 / スキップ 0 件 |
| GitHub の読み取り (保護 2 つ・実行 2 つ・Pull Request・commit・検査の一覧・実行の一覧・ブランチ) | 上の「GitHub の読み直し」のとおり |
| `git ls-remote origin`・`git diff`・`git log` (読み取りだけ) | 上のとおり |

Simulator・エミュレータは使っていない。Gradle と Xcode のビルド、手元への発行は流していない。git の書き込みと GitHub への書き込みは行っていない。足したのはこのファイルだけである。

## 確かめていないこと・気付いたこと

- **必須の検査を足した時刻**。保護の設定を変えた時刻は、読み取りの API からは分からない。「報告された名前を読んだ後に足した」ことは、証跡の記録の順序 (9.2 → 9.3) と、前回の検証が読んだ時点で 3 つだったことによる
- **マージの直前の Pull Request の状態** (`mergeable`・`mergeStateStatus`)。マージの後には読み直せない。5 つの検査の終了がマージより前であることは、読み直した時刻で確かめた
- **必須の検査が実際にマージを止めること**。5 つとも成功した状態でマージしているので、失敗した検査がマージを止めるところは見ていない。Scenario が求めているのは、成功で終わったときにマージできることである
- **Pull Request の検査の一覧に、push の実行の `consumer-ios`・`consumer-android` (skipped) も並ぶ**。同じ commit に対する 2 つの実行の結果が並ぶためで、名前に ` / verify` が付かない別の検査である。必須の検査に登録されているのは ` / verify` が付く名前で、Scenario の THEN (Pull Request で起動した検証 CI が報告する名前) は、Pull Request の実行の 5 つで満たされている。証跡 9.2 も同じことを書いている
- **`published` での取得の成功**。配信用リポジトリも Maven Central の公開物もまだ無い (前回と同じ。Scenario の外)
- **コンテキストとの違い**。この検証の依頼では、コメント 1 行の直しと `verify-001.md` は未 commit とされていたが、実際にはどちらも commit `6e420a7` に入っている。判定には影響しない
