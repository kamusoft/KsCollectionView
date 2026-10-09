# Verify 001: package-distribution

実施日: 2026-10-09。対象: commit `192a10b` に対する作業ツリーの未 commit の変更 (未追跡のファイルを含む)。

## 判定

**VALID** (手元で確かめられる範囲)。

| 状態 | Scenario の数 |
|---|---:|
| ✅ 一致 | 52 |
| ⚠️ 合意済みの乖離 (deviation 記録済み) | 1 |
| ⏳ 未実施 (グループ 9 の後に確かめる) | 7 |
| ❌ 乖離 | 0 |
| 合計 | 60 |

- 未記録の乖離・虚偽チェック・逆流・テストの失敗は無い
- 未実施の 7 つは、ランナーの上での実行と GitHub の設定の読み直しでしか確かめられない Scenario である (tasks のグループ 9。オーナーの承認を待っていて未着手)。手元で確かめられる部分 (workflow の定義の形) は一致している。この 7 つは、グループ 9 の後にもう 1 度検証する
- Side Effects の行 (Requirement 13 個) は、手元で確かめられる 12 個が一致、1 個 (ブランチの保護) が未実施

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

「実測」は、この検証で自分で流した結果である (下の「この検証で流したもの」)。「証跡」は、実装の側が残した記録を読んだものである。

## 対応表: package-distribution

| Requirement / Scenario | 実装 | テスト・確認 | 状態 |
|---|---|---|---|
| iOS のマニフェストが要求するツールの版 / 宣言が確かめている版と一致する | `ios/Package.swift:1` | `T/test_sync_spm_snapshot.py:450` | ✅ 一致 |
| 同 / 宣言を上げてもテストが通る | `ios/Package.swift:1` | 実測: 本体 567・Sample 48 (37 + 11)、失敗 0、スキップ 0。証跡: `E/local-completion.md` 8.1 | ✅ 一致 |
| 同 — Side Effects (なし) | 宣言の 1 行だけ。状態を変える処理は無い | — | ✅ 一致 |
| SwiftPM の写しを作る / 空の行き先に 5 点が置かれる | `D/sync-spm-snapshot.py:277-286` | `T/test_sync_spm_snapshot.py:153`・`:467` (実物の元) | ✅ 一致 |
| 同 / 無い行き先は作られる | `D/sync-spm-snapshot.py:247-248`・`:297` | `T/test_sync_spm_snapshot.py:161` | ✅ 一致 |
| 同 / マニフェストが本体と同じ内容である | `D/sync-spm-snapshot.py:281` | `T/test_sync_spm_snapshot.py:167`・`:467` | ✅ 一致 |
| 同 / 追跡していないファイルは写されない | `D/sync-spm-snapshot.py:109-117` | `T/test_sync_spm_snapshot.py:197`・`:484` | ✅ 一致 |
| 同 / 本体から消えたファイルは残らない | `D/sync-spm-snapshot.py:256-269` | `T/test_sync_spm_snapshot.py:216` | ✅ 一致 |
| 同 / 行き先の git の状態を進めない | `D/sync-spm-snapshot.py:263-264` (`.git` を残す)。git は読み取りだけに呼ぶ (`:112`・`:180`・`:188`・`:211`) | `T/test_sync_spm_snapshot.py:227` (HEAD・commit の数・tag・ブランチ・origin が同じ) | ✅ 一致 |
| 同 / README がこのリポジトリへ案内する | `D/sync-spm-snapshot.py:283`、`D/spm-readme.template.md:9` | `T/test_sync_spm_snapshot.py:475` | ✅ 一致 |
| 同 / 元が欠けていると何も消さない | `D/sync-spm-snapshot.py:120-146` (消す前に確かめる。`:292`) | `T/test_sync_spm_snapshot.py:269` (元の 5 点と、追跡に関わる 2 つの場合)・`:308` | ✅ 一致 |
| 同 / このリポジトリの中を行き先にすると拒否する | `D/sync-spm-snapshot.py:242-243` | `T/test_sync_spm_snapshot.py:314`・`:328` | ✅ 一致 |
| 同 / このリポジトリを含むディレクトリを行き先にすると拒否する | `D/sync-spm-snapshot.py:244-245` | `T/test_sync_spm_snapshot.py:333` | ✅ 一致 |
| 同 / 中身があって配信用リポジトリの作業コピーでない行き先を拒否する | `D/sync-spm-snapshot.py:176-195` | `T/test_sync_spm_snapshot.py:346`・`:352`・`:367`・`:371` | ✅ 一致 |
| 同 — Side Effects | 書くのは行き先だけ: 作成 (`:297`)・`.git` を除く中身の削除 (`:298`)・5 点の作成 (`:299`)。ほかの場所への書き込み・git の書き込み・通信は無い。列挙に収まる | `T/test_sync_spm_snapshot.py:227`・`:258` | ✅ 一致 |
| Android の発行物 / 鍵なしで手元に発行できる | `A/kscollectionview/build.gradle.kts:75-86`・`:132-136` | 実測: AAR・sources jar・javadoc jar・POM・`.module` の 5 点、`.asc` は 0。`signMavenPublication SKIPPED`。証跡: `E/android-publishing.md` 3.4 | ✅ 一致 |
| 同 / 外から渡した版で発行される | `A/build.gradle.kts:12-16` | 実測: `-Pversion=0.0.1-check` で `0.0.1-check/` の下に 5 点 | ✅ 一致 |
| 同 / POM が決めた項目を持つ | `A/kscollectionview/build.gradle.kts:95-125` | 実測: POM に名前・説明・URL・MIT License・開発者・`scm` がある | ✅ 一致 |
| 同 / 依存の範囲が公開面と合う | `A/kscollectionview/build.gradle.kts:184-204` | 実測: compile は runtime・ui・foundation-layout・coil-compose・annotation 1.9.1・kotlin-stdlib、BOM は依存の管理。`Color` を持つ ui-graphics と `Dp` を持つ ui-unit は POM に直接は無い (ui が届ける)。証跡: `E/android-publishing.md` 3.3 | ⚠️ deviation 記録済み (`deviation.md:3`) |
| 同 / 鍵を渡すと署名が付く | `A/kscollectionview/build.gradle.kts:93` | 実測: 使い捨ての鍵で 5 点それぞれに `.asc` (計 10)。`signMavenPublication` が実行された。証跡: `E/android-publishing.md` 3.4 | ✅ 一致 |
| 同 — Side Effects | 発行先に渡したディレクトリと、`android/` の下のビルドの出力だけ。既定の手元の Maven リポジトリは前後で同じ (実測)。列挙に収まる | 実測 | ✅ 一致 |
| 開発中の版を Maven Central へ送らない / 開発中の版のままでは送れない | `A/kscollectionview/build.gradle.kts:156-178` | 実測: `publishToMavenCentral`・`publishAndReleaseToMavenCentral`・`publish` が終了コード 1、動いたタスク 0、理由の文が出力にある。証跡: `E/android-publishing.md` 3.2 | ✅ 一致 |
| 同 / 開発中の版でも手元には発行できる | 同上 (手元への発行のタスクは対象外) | 実測: 版 `0.1.0-SNAPSHOT` で `publishToMavenLocal` が成功 | ✅ 一致 |
| 同 — Side Effects | Maven Central への送信は行っていない (実測でも、送るタスクは 1 つも動いていない)。列挙に収まる | 実測 | ✅ 一致 |

## 対応表: consumer-verification

| Requirement / Scenario | 実装 | テスト・確認 | 状態 |
|---|---|---|---|
| 利用者役の参照の書き方 / iOS の利用者役が package の名前で product を指す | `V/ios/Package.swift.template:33` | `T/test_verify_consumer_ios.py:578` (実物・2 つの切り替え)・`:240` | ✅ 一致 |
| 同 / iOS の local は写しのディレクトリをパスで参照する | `C/verify-consumer-ios.py:142`・`:238` | `T/test_verify_consumer_ios.py:226`・`:210`・`:584` | ✅ 一致 |
| 同 / iOS の published は配信用リポジトリを版の完全一致で参照する | `C/verify-consumer-ios.py:140-141` | `T/test_verify_consumer_ios.py:334`・`:529`・`:588` | ✅ 一致 |
| 同 / Android の利用者役の依存は座標の 1 行である | `V/android/app/build.gradle.kts:73` | `T/test_verify_consumer_android.py:511` | ✅ 一致 |
| 同 / Android の local は作業用のリポジトリだけから取る | `V/android/settings.gradle.kts:57-69`、`C/verify-consumer-android.py:212-217` | `T/test_verify_consumer_android.py:206`・`:519`・`:540`。実測: 空のディレクトリを渡すと、探した場所はそのディレクトリだけ | ✅ 一致 |
| 同 / Android の published は Maven Central だけから取る | `V/android/settings.gradle.kts:57-69` | `T/test_verify_consumer_android.py:519`・`:248`。証跡: `E/consumer-android.md` (無い版で、探した場所は Maven Central だけ) | ✅ 一致 |
| 同 / 本体のソースを参照しない | `V/ios/Package.swift.template:26-36`、`V/android/settings.gradle.kts:54-84` | `T/test_verify_consumer_ios.py:592`・`:624`、`T/test_verify_consumer_android.py:544` | ✅ 一致 |
| 同 — Side Effects (なし) | 定義のファイルだけで、状態を変える処理は無い | — | ✅ 一致 |
| iOS の利用者の立場のビルドの確認 / 配布物が正しければ成功する | `C/verify-consumer-ios.py:231-243`・`:94-98` | 実測: `--mode local` が終了コード 0。2 つの行き先とも `BUILD SUCCEEDED`。本体は写しから解決された。証跡: `E/consumer-ios.md` 4.4 | ✅ 一致 |
| 同 / 写しに本体のソースが欠けていると失敗する | `C/verify-consumer-ios.py:221-228` | 実測: リポジトリの外の一時のツリーで本体のソースを 1 つ欠くと、終了コード 1 (写しは Sources 92、Simulator 向けのビルドが失敗)。証跡: `E/consumer-ios.md` 4.5 | ✅ 一致 |
| 同 / 片方の行き先だけが失敗しても失敗する | `C/verify-consumer-ios.py:241-242` | `T/test_verify_consumer_ios.py:457` | ✅ 一致 |
| 同 / published では写しを作らずに同じビルドを行う | `C/verify-consumer-ios.py:237-242` | `T/test_verify_consumer_ios.py:325`・`:343`・`:354` | ✅ 一致 |
| 同 / 知らない切り替えでは始めない | `C/verify-consumer-ios.py:127-128`・`:249-251` | `T/test_verify_consumer_ios.py:374`・`:379` | ✅ 一致 |
| 同 / published で版が無いと始めない | `C/verify-consumer-ios.py:133-134` | `T/test_verify_consumer_ios.py:382`・`:385` | ✅ 一致 |
| 同 / 追跡しているファイルを変えない | `C/verify-consumer-ios.py:234` (書くのは一時のディレクトリだけ)・`:54` | `T/test_verify_consumer_ios.py:284`・`:246`・`:641`。実測: 実行の前後で `git status` と `git diff` が同じ | ✅ 一致 |
| 同 — Side Effects | 一時のディレクトリ (写し・利用者役の写し・ビルドの出力) だけを作り、終わると消す (`T/test_verify_consumer_ios.py:291`・`:297`)。列挙に収まる。概要の追記 (`C/ci_report.py:18-21`) は実行の結果の表示で、数えない | 実測 | ✅ 一致 |
| Android の利用者の立場のビルドの確認 / 配布物が正しければ成功する | `C/verify-consumer-android.py:276-294` | 実測: `--mode local` が終了コード 0。依存の一覧に `jp.kamusoft:kscollectionview:0.1.0-SNAPSHOT`。`T/test_verify_consumer_android.py:167`・`:183`。証跡: `E/consumer-android.md` 5.5 | ✅ 一致 |
| 同 / コード縮小が走っている | `V/android/app/build.gradle.kts:47-50`、`C/verify-consumer-android.py:220-236` | 実測: `app/build/outputs/mapping/release/mapping.txt` がある (151,683 行)。`T/test_verify_consumer_android.py:370`・`:377`・`:553`。証跡: `E/consumer-android.md` 5.2 (コード縮小を切ると対応表ができない) | ✅ 一致 |
| 同 / 作業用のリポジトリに発行物が無いと失敗する | `V/android/settings.gradle.kts:57-69` | 実測: 空のディレクトリを渡して組み立てると終了コード 1、`Could not find jp.kamusoft:kscollectionview:0.1.0-SNAPSHOT`。スクリプトを通した失敗の伝わり方は `T/test_verify_consumer_android.py:352` | ✅ 一致 |
| 同 / 既定の手元の Maven リポジトリに書かない | `C/verify-consumer-android.py:198`・`:287` | `T/test_verify_consumer_android.py:217`。実測: `~/.m2/repository/jp/kamusoft/` の下の一覧が前後で同じ (`kscollectionview` は無い) | ✅ 一致 |
| 同 / published では発行せずに同じ組み立てを行う | `C/verify-consumer-android.py:278-284` | `T/test_verify_consumer_android.py:248`・`:262`・`:275` | ✅ 一致 |
| 同 / 知らない切り替えでは始めない | `C/verify-consumer-android.py:114-115` | `T/test_verify_consumer_android.py:292`・`:297` | ✅ 一致 |
| 同 / published で版が無いと始めない | `C/verify-consumer-android.py:120-121` | `T/test_verify_consumer_android.py:300`・`:303` | ✅ 一致 |
| 同 / 追跡しているファイルを変えない | `C/verify-consumer-android.py:52`・`:287` | 実測: 実行の前後で `git status --porcelain -uall` と `git diff` が同じ。証跡: `E/consumer-android.md` 5.5 | ✅ 一致 |
| 同 — Side Effects | 一時の Maven リポジトリ (終わると消す)・`android/` の下のビルドの出力 (`local` だけ)・`verification/android/` の下のビルドの出力 (追跡の対象外。前の回の対応表の削除を含む)。列挙に収まる。規則のファイルは無い (`T/test_verify_consumer_android.py:562`) | 実測 | ✅ 一致 |
| 確認の失敗が記録に残る / 準備が失敗した理由が記録に出る | `C/verify-consumer-ios.py:162-170`・`:181-182`、`C/verify-consumer-android.py:151-159`・`:200-201` | `T/test_verify_consumer_ios.py:406`・`:500`、`T/test_verify_consumer_android.py:319`・`:427` | ✅ 一致 |
| 同 / 準備が失敗したらビルドを始めない | `C/verify-consumer-ios.py:237-240`、`C/verify-consumer-android.py:290-292` | `T/test_verify_consumer_ios.py:406`・`:426`・`:433`・`:475`・`:485`、`T/test_verify_consumer_android.py:319`・`:338`・`:345` | ✅ 一致 |
| 同 — Side Effects (なし) | 出力を流すだけ | — | ✅ 一致 |
| コード縮小を有効にした利用者役の起動の確認 / 起動して一覧が表示される | `V/android/app/` | 証跡: `E/consumer-android.md` 5.7、`E/consumer-android-list-minified.png` (`Item 0`〜`Item 20` の行が写っている)、`E/consumer-android-launch-logcat.txt` (`Displayed … +538ms`。致命的な例外の行は無い) | ✅ 一致 |
| 同 — Side Effects | 作業専用の AVD は削除済み (実測: AVD の一覧に残っていない)。証跡の 3 枚が `evidence/` にある。列挙に収まる | 実測 | ✅ 一致 |

## 対応表: verification-ci

| Requirement / Scenario | 実装 | テスト・確認 | 状態 |
|---|---|---|---|
| 検証 CI の起動条件 (MODIFIED) / 開発の記録だけの push では起動しない | `W/ci.yml:26-33` (本変更で変えていない) | `T/test_workflow_files.py:93`。実地は前の変更で確認済み (`kasane/changes/archive/2026-10-08-public-repo-verify-ci/verify-002.md`) | ✅ 一致 |
| 同 / 起動の対象になる新しい push が古い実行を打ち切る | `W/ci.yml:42-44` (本変更で変えていない) | `T/test_workflow_files.py:104`。実地は同上 | ✅ 一致 |
| 同 / 起動しない push は走っている実行に影響しない | `W/ci.yml:26-33`・`:42-44` (本変更で変えていない) | `T/test_workflow_files.py:93`・`:104`。実地は同上 | ✅ 一致 |
| 同 — Side Effects | 定義が起こすのは、実行の作成と、同じまとまりの古い実行の打ち切りだけ。足した 2 つのジョブは書き込みの権限を持たない (`W/ci.yml:36-37`) | `T/test_workflow_files.py:264`・`:305` | ✅ 一致 |
| 利用者の立場のビルドの確認の再利用 / 別の workflow から切り替えを渡して呼べる | `W/verify-consumer-ios.yml:19-30`、`W/verify-consumer-android.yml:20-31` | `T/test_workflow_files.py:224`・`:231` | ✅ 一致 |
| 同 / 入口は local で呼ぶ | `W/ci.yml:62-74` | `T/test_workflow_files.py:132`・`:141` | ✅ 一致 |
| 同 — Side Effects (なし) | 定義だけ | — | ✅ 一致 |
| 利用者の立場のビルドの確認の道具と権限 / workflow の定義の検査が新しい workflow でも通る | `W/verify-consumer-ios.yml`、`W/verify-consumer-android.yml` | 実測: `check-workflows.py` が 5 本で違反なし、`actionlint` が終了コード 0。`T/test_workflow_files.py:264` | ✅ 一致 |
| 同 / 決めた版の Xcode が無いと落ちる | `W/verify-consumer-ios.yml:58-69` | `T/test_workflow_files.py:326`・`:335`・`:338`。実測: step の本文を、無い版 (99.9) で流すと終了コード 1、`GITHUB_ENV` は 0 行 | ✅ 一致 |
| 同 / 失敗を見逃す指定が無い | 同 2 本 | `T/test_workflow_files.py:259`・`:290` | ✅ 一致 |
| 同 — Side Effects (なし) | 権限は内容の読み取りだけ (`W/verify-consumer-ios.yml:32-33`、`W/verify-consumer-android.yml:33-34`)。依存の取得のキャッシュ (`W/verify-consumer-android.yml:59-71`) は結果を変えないキャッシュで、数えない | `T/test_workflow_files.py:379` | ✅ 一致 |

旧い挙動のテストは残っていない。入口のジョブの集合を 3 つと決めていたテストは、5 つを期待する形に直されている (`T/test_workflow_files.py:115`)。既存の 3 つのジョブの名前と呼び方の検査 (`:122`・`:129`) は残っている。

## 未実施 (グループ 9 の後に確かめる)

| Requirement / Scenario | 手元で確かめた部分 | 残り (tasks) |
|---|---|---|
| 検証 CI の起動条件 / develop への push で起動する | 起動の定義と、利用者の立場のビルドの確認が Pull Request のときだけ走る条件 (`W/ci.yml:64`・`:71`、`T/test_workflow_files.py:87`・`:132`) | ランナーの上で 3 つだけが走ること (9.1) |
| 同 / main 宛ての Pull Request では絞り込まない | 絞り込みが無いことと、ジョブが 5 つであること (`T/test_workflow_files.py:100`・`:115`) | ランナーの上で 5 つが走ること (9.2) |
| 利用者の立場のビルドの確認の再利用 / 検査が決めた名前で報告される | 呼ぶ側と呼ばれる側のジョブの名前から組み立てた名前 (`T/test_workflow_files.py:147`) | 報告された名前の読み取り (9.2) |
| ブランチの保護 (MODIFIED) / 報告された名前を確かめてから足す | — | 9.2・9.3 |
| 同 / main の保護に必須の検査が 5 つ入っている | 今の値の読み取り: 必須の検査は 3 つ (`lint`・`ios / verify`・`android / verify`)、承認の数 0、強制 push と削除は禁止、管理者には強制しない | 9.3 |
| 同 / develop の保護は変わらない | 今の値の読み取り: 必須の検査なし、強制 push と削除は禁止、管理者には強制しない | 9.3 |
| 同 / main には 5 つの検査を通った develop が入る | — | 9.4 |
| ブランチの保護 — Side Effects | — (GitHub への操作は、まだ 1 つも行われていない) | 9.2〜9.4 |

## 追加検査

| 検査 | 結果 |
|---|---|
| tasks.md | グループ 1〜8 はすべてチェック済みで、対応表と食い違うものは無い (虚偽チェックなし)。グループ 9 の 5 件は未チェックで、実際にも未着手である (GitHub の Pull Request は前の変更の 1 件だけ、`main` の保護は 3 つのまま) |
| 逆流 | `proposal.md`・`design.md`・`specs/` は、`192a10b` から変わっていない (`git status` に現れない) |
| 未記録の乖離 | 無い |
| deviation.md | 乖離 1 行 (依存の範囲)。実装 (`A/kscollectionview/build.gradle.kts:193`・`:204`、`A/gradle/libs.versions.toml` の `androidx-annotation = "1.9.1"`) と一致する。`[付随修正]` の行は無い |
| Scenario に対応しない変更 | `T/support.py` の引数の追加 (道具のテストが使う)、`drafts/` の 4 枚 (tasks 7)、`kasane/lessons/inbox/` の 1 枚 (教訓の捕捉) だけで、挙動を変える付随修正は無い |
| UI 変更 | 該当しない (`ui/` は無い) |
| テスト | 下の「この検証で流したもの」のとおり、5 系統とも失敗 0 |

## この検証で流したもの

環境: macOS 27.0、Xcode 27.0、JDK 21.0.12、Gradle 9.7.0 (wrapper)。Android SDK の場所は環境変数 `ANDROID_HOME` で渡した (`android/local.properties` は読まず変えていない)。認証の情報と本物の署名の鍵は渡していない (環境変数と利用者の Gradle の設定に、その名前を持つ行が無いことを、行の数で確かめた)。

| 流したもの | 結果 |
|---|---|
| `python3 scripts/ci/run-tests.py` | 実行 262 件 / 失敗 0 件 / スキップ 0 件 |
| `check-workflows.py`・`actionlint`・`local-path-lint.py`・`identity-lint.py`・`comment-policy-lint.py` | どれも終了コード 0 (workflow 5 本で違反なし、コメントの規約は禁止 0 件) |
| iOS 本体のテスト (絞り込みなし) | 567 件、失敗 0、スキップ 0 |
| iOS Sample のテスト (絞り込みなし) | 48 件 (ユニットテスト 37 + UI テスト 11)、失敗 0、スキップ 0 |
| Android 本体のテスト (`--rerun-tasks`) | 512 件 (31 クラス)、失敗 0、エラー 0、スキップ 0 |
| Android Sample のテスト (`--rerun-tasks`) | 163 件 (21 クラス)、失敗 0、エラー 0、スキップ 0 |
| 手元への発行 (鍵なし・版を外から渡す・使い捨ての鍵) | 対応表のとおり。発行先はリポジトリの外の作業用のディレクトリ |
| 送信に至る 3 つのタスク (版は既定) | どれも終了コード 1、動いたタスク 0。開発中でない版の空実行 (`-m -Pversion=9.9.9`) は成功 |
| `verify-consumer-android.py --mode local` | 終了コード 0 |
| `verify-consumer-ios.py --mode local` | 終了コード 0 |
| 一時のツリーで本体のソースを欠いた iOS の確認 | 終了コード 1 |
| 空のディレクトリを取得元にした利用者役の組み立て | 終了コード 1 |

- iOS のテストは、この検証のために新しく作った Simulator 1 台 (iPhone 17・iOS 27.0) で流し、流し終えた後に削除した (一覧に残っていないことを確かめた)。既存の Simulator・エミュレータ・つながっている実機には触っていない
- 使い捨ての署名の鍵は、リポジトリの外の一時の鍵束に作り、確認の後に鍵束ごと `trash` で消した。鍵の中身は記録していない
- 作業用のディレクトリ (発行先・一時のツリー) は、確認の後に消した
- すべてを流し終えた後の `git status --porcelain -uall` と `git diff` は、流す前と同じだった (足したのはこのファイルだけ)
- 既定の手元の Maven リポジトリ (`~/.m2/repository/jp/kamusoft/`) の下の一覧は、流す前と同じだった

## 確かめていないこと・気付いたこと

- **未実施の 7 つ** (上の表)。ランナーの上では、利用者の立場のビルドの確認の 2 本はまだ 1 度も走っていない
- **`published` での取得の成功**。配信用リポジトリも Maven Central の公開物もまだ無い。Scenario が求めているのは定義の形と、コマンドを差し替えた形での動きまでで、そこは一致している
- **署名の検証**。この検証では、署名のファイルが 5 点に付くことまでを見た。署名が公開鍵で検証できることは、こちらの確認のコマンドの出力の読み取りに失敗して確かめられていない (証跡 `E/android-publishing.md` 3.4 は、5 つとも検証できたと記録している)。Scenario の THEN (署名のファイルが付いている) の外である
- **起動の確認は、この検証ではやり直していない**。Requirement が求めるのは実装の中での 1 回で、証跡の 3 枚を読んで判定した。証跡は `androidx.annotation` の宣言を足す前のもので、足す前と後で AAR の SHA-256 が同じであることは `E/android-publishing.md` の修正サイクル 1 が記録している
- **対応表を書くタスク**。この検証の `--mode local` の実行では、`:app:minifyReleaseWithR8` は `UP-TO-DATE` で、`outputs/mapping/release/mapping.txt` を書き直したのは `:app:mergeReleaseComposeMapping` だった。`C/verify-consumer-android.py:69` のコメント (R8 がここに対応表を書く) は、この点で正確でない。対応表があることがコード縮小の印になること自体は、証跡 5.2 (コード縮小を切ると `outputs/mapping/` ができない) のとおりで、判定には影響しない
- **手元の `develop` は、リモートより 1 commit 進んでいる** (提案の commit `192a10b` が未 push)。グループ 9.1 の push には、この commit も含まれる
