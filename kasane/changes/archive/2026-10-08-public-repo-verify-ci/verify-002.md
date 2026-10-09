# Verify 002: public-repo-verify-ci (change 全体の最終の検証)

- 日付: 2026-10-08
- 対象: change 全体。デルタスペックの 55 Scenario と Side Effects の 16 行を、今の実装 (`develop` の先端 `abf4ade`)・テスト・証跡・GitHub の今の状態と突き合わせた
- 前回の検証: `verify-001.md` (公開の前の段階。37 件を判定し、18 件を持ち越した)
- 対象にしていないもの: `drafts/` (別のワーカーが書き換えている最中のため。tasks 9.1〜9.3 は、置き場があることだけを見て、中身は読んでいない)

## 判定

**INVALID** (❌ 1 件。記録の無い乖離)

| 区分 | 件数 |
|---|---:|
| Scenario の総数 | 55 (verification-ci 39 / repository-publication 16) |
| ✅ 一致 | 48 (verification-ci 33 / repository-publication 15) |
| ⚠️ deviation により変更 | 6 (すべて verification-ci の「iOS の検証」) |
| ❌ 欠落・乖離 | 1 (repository-publication「Issue のフォームの必須項目 / 3 本のフォームだけが選べる」) |
| Side Effects の行 | 16 (✅ 16) |

- 虚偽のチェック: なし / 逆流: なし / テスト: 111 件成功 (今回流した)
- ❌ の中身: 管理する側の画面には空の Issue の行が出ることを、証跡 (`evidence/publication-log.md:213`・`:216`) が自分で「Scenario の文面と違う」と書いている。`deviation.md` にこの行が無い。実装 (`blank_issues_enabled: false`) は design のとおりで、GitHub の仕様なので実装では直せない。見立ては「deviation として合意」(下の「❌ の見立て」)
- ❌ はこの 1 件だけで、ほかに実装を直す必要のある点は見つかっていない

### 数え方

- 「⚠️ deviation により変更」は、`deviation.md:5`・`:6` の乖離で文面どおりには成り立たなくなった Scenario。合意済みの差分なので違反に数えない。deviation の記述と今の実装が合っているかを見た
- 証跡が「確かめていない」「オーナーの報告による」と書いている点は、定義とテストが Scenario と合っていて、反する観察が無いものを ✅ に数え、「裏付けが弱い Scenario」の一覧に挙げた。反する観察が記録にあるもの (上の 1 件) だけを ❌ にした
- GitHub の状態は、今回、読み取りだけのコマンドで読み直した (下の「GitHub の今の状態の読み直し」)。「実地」の列に「読み直し」と書いたものは、証跡の値が今も合っていることを自分で確かめたもの。「記録」と書いたものは、後から読めないので証跡の記述に依っている

## 対応表の読み方

- パスの省略: `T/` は `scripts/ci/tests/`、`W/` は `.github/workflows/`、`S/` は `scripts/ci/`
- 証跡: 「手元」は `evidence/ci-local-verification.md`、「公開前」は `evidence/pre-publication-checks.md`、「公開」は `evidence/publication-log.md`
- 実行の呼び名: 実行 1 (`e1c3d67`、push、失敗)・実行 2 (`985f910`、push、成功)・実行 PR (`7c6fd10`、Pull Request、成功)・実行 A (`f374fad`、push、打ち切り)・実行 B (`abf4ade`、push、成功)

## 対応表: verification-ci

### Requirement: 検証 CI の起動条件

| Scenario | 実装 | テスト | 実地 | 状態 |
|---|---|---|---|---|
| develop への push で起動する | `W/ci.yml:21-23`・`:45-54` | `T/test_workflow_files.py:75`・`:97` | 読み直し: 実行 1・2・A・B はどれも push で起動し、ジョブは `lint`・`ios / verify`・`android / verify` の 3 つ | ✅ 一致 |
| 開発の記録だけの push では起動しない | `W/ci.yml:24-28` | `T/test_workflow_files.py:81` | 読み直し: `kasane/` の下だけを変えた `7c6fd10` と `42b37e1` に、push で起動した実行が無い (実行の一覧は 5 件だけ。`42b37e1` の検査の報告は 0 件) | ✅ 一致 |
| main 宛ての Pull Request では絞り込まない | `W/ci.yml:18-20` (絞り込みのキーなし) | `T/test_workflow_files.py:88` | 読み直し: 実行 PR の対象 `7c6fd10` は `kasane/` の下だけの変更だが、3 つのジョブが走って成功した。見たのは「作られる」ときだけで、「更新される」ときは見ていない | ✅ 一致 |
| 起動の対象になる新しい push が古い実行を打ち切る | `W/ci.yml:37-39` | `T/test_workflow_files.py:92` | 読み直し: 実行 A は `cancelled` (12:29:04 に終了)、実行 B は 12:28:13 に作られて成功。A の `lint` は成功、残り 2 つは打ち切り | ✅ 一致 |
| 起動しない push は走っている実行に影響しない | `W/ci.yml:24-28` (起動しないので、同時実行のまとまりに入らない) | 定義の形は上の 2 行と同じ | 読み直し: `42b37e1` の実行は作られていない。実行 A が止まった時刻は実行 B が作られた後。記録: 「25 秒後も実行 A は走っていた」(公開 8.1・8.2) は後から読めない | ✅ 一致 |
| 検証 CI の起動条件 — Side Effects | 実行の作成と、同じまとまりの古い実行の打ち切りだけ。列挙に収まる | — | 実行の一覧は 5 件で、どれも列挙の範囲 | ✅ 一致 |

### Requirement: main 宛ての Pull Request の出どころの制限

| Scenario | 実装 | テスト | 実地 | 状態 |
|---|---|---|---|---|
| develop からの Pull Request は通る | `S/check-pr-head.py:71`、`W/ci.yml:75-78` | `T/test_check_pr_head.py:25` | 読み直し: 実行 PR の lint の記録に「出どころは kamusoft/KsCollectionView の develop」 | ✅ 一致 |
| develop 以外のブランチからの Pull Request は落ちる | `S/check-pr-head.py:66-70` | `T/test_check_pr_head.py:31`、手元 5.2 | 実地は無い (tasks の備考で、確かめるための Pull Request は作らない) | ✅ 一致 |
| 別のリポジトリの同じ名前のブランチからの Pull Request は落ちる | `S/check-pr-head.py:61-65` | `T/test_check_pr_head.py:38`、手元 5.2 | 同上 | ✅ 一致 |
| (本文) push で起動したときは確認を行わない | `S/check-pr-head.py:51-52` | `T/test_check_pr_head.py:44` | 読み直し: 実行 1 の lint の記録に「Pull Request での起動ではないため、出どころは確かめない」 | ✅ 一致 |
| main 宛ての Pull Request の出どころの制限 — Side Effects | 標準出力への表示だけ。「なし」のとおり | — | — | ✅ 一致 |

### Requirement: lint の検証

| Scenario | 実装 | テスト | 実地 | 状態 |
|---|---|---|---|---|
| 違反が無ければ通る | `W/ci.yml:53-133` | `T/test_workflow_files.py:111` | 読み直し: 5 つの実行すべてで `lint` が成功。実行 PR の記録に、走査の対象 1187 / 追跡中 1187・検出なし・テスト 111 件・定義の違反なし | ✅ 一致 |
| secret を含む内容で落ちる | `W/ci.yml:93-114` | 手元 5.2 (`leaks found: 2`)。自動のテストは無い | 実地は無い | ✅ 一致 |
| ローカル絶対パスを含む内容で落ちる | `W/ci.yml:116-117` | 手元 5.2。自動のテストは無い | 同上 | ✅ 一致 |
| 個人を特定する値を含む内容で落ちる | `W/ci.yml:119-120` | 手元 5.2。自動のテストは無い | 同上 | ✅ 一致 |
| コメントの規約に反するソースで落ちる | `W/ci.yml:122-123` | 手元 5.2。自動のテストは無い | 同上 | ✅ 一致 |
| 走査の対象を取り出せないと落ちる | `W/ci.yml:97`・`:103-113` | `T/test_workflow_files.py:142`、手元 5.2 (2 つの場合) | 同上 | ✅ 一致 |
| 検査のスクリプトのテストが落ちると lint も落ちる | `S/run-tests.py:36-43`、`W/ci.yml:127-128` | `T/test_run_tests.py:60`、手元 5.2 | 同上 | ✅ 一致 |
| lint の検証 — Side Effects | 検査の結果 (`lint`) の作成だけ。ランナーの一時の置き場への書き込みは数えない | — | 読み直し: 検査の報告は `lint` の名前で出ている | ✅ 一致 |

### Requirement: iOS の検証 (deviation で形が変わった)

`deviation.md:5` により、検証 CI では Simulator を使うテストを走らせず、本体と本体のテスト・Sample のアプリと Sample のテストがビルドできることだけを確かめる。`deviation.md:6` により、Simulator を選ぶスクリプト・iOS の実行件数を確かめるスクリプト・出力を記録に残すスクリプトと、そのテスト 25 件を取り除いた。

| Scenario | 実装 (今の形) | テスト | 実地 | 状態 |
|---|---|---|---|---|
| 全件が通れば成功する | `W/verify-ios.yml:68-89` (2 つの `build-for-testing`)。実行の件数は概要に出ない | `T/test_workflow_files.py:203` (テストを実行しない)・`:220`・`:231` | 読み直し: 実行 2・PR・B で `ios / verify` が成功。実行 PR の記録に `TEST BUILD SUCCEEDED` が 2 回、テストの実行の行は無い | ⚠️ deviation により変更 |
| 本体のテストが落ちても Sample の検証は走る | `W/verify-ios.yml:82` (本体のビルドが落ちても Sample のビルドは走る) | `T/test_workflow_files.py:254` | 変える前の形では、実行 1 で確かめられている (本体のテストの step が失敗した後に Sample の step が走り、ジョブは失敗)。今の形での実地は無い | ⚠️ deviation により変更 |
| Sample がビルドできないと落ちる | `W/verify-ios.yml:81-89` | `T/test_workflow_files.py:259` (失敗を見逃す指定が無い) | 手元 (Sample の UI テストのコードを壊すと終了コード 65)。ランナーでの実地は無い | ✅ 一致 (文面は deviation の後もそのまま成り立つ) |
| Sample のユニットテストが落ちると落ちる | テストを実行しないので、検証 CI では見つからない。見つかるのは、テストのコードがビルドできない場合だけ | `T/test_workflow_files.py:203` | — | ⚠️ deviation により変更 |
| Sample の UI テストは走らない | テストを 1 件も実行しない (`W/verify-ios.yml:72`・`:85`)。UI テストのコードはビルドの対象に入る | `T/test_workflow_files.py:203`・`:231` | 読み直し: 実行 B の step は、ビルドの 2 つだけ | ✅ 一致 (実行されるテストが無いので、文面は成り立つ) |
| 実行が 0 件なら落ちる | 取り除いた (件数を確かめるスクリプトが無い) | 取り除いた | — | ⚠️ deviation により変更 |
| 全件がスキップされていると落ちる | 同上 | 同上 | — | ⚠️ deviation により変更 |
| 件数を読み取れないと落ちる | 同上 | 同上 | — | ⚠️ deviation により変更 |
| iOS の検証 — Side Effects | 検査の結果 (`ios / verify`) の作成だけ | — | 読み直し: 検査の報告は `ios / verify` の名前で出ている | ✅ 一致 |

deviation の記述と実装の突き合わせ:

| deviation の記述 | 今の実装 | 合っているか |
|---|---|---|
| Simulator を使うテストを走らせない | `xcodebuild` の呼び出しは `build-for-testing` の 2 つだけ (`T/test_workflow_files.py:203` が守る) | ○ |
| 本体と本体のテスト、Sample のアプリと Sample のテストがビルドできることだけを確かめる | `W/verify-ios.yml:68-75`・`:81-89` | ○ |
| Simulator を選ばない | 行き先は `generic/platform=iOS Simulator` (`T/test_workflow_files.py:210`) | ○ |
| スクリプト 3 本とテスト 25 件を取り除く | `S/` に 3 本とも無く、`kasane/` の外に名前の参照も残っていない。テストは 133 件から 111 件 (取り除き 30・足し 8。30 のうち 25 が 3 本のテスト、5 が workflow のテスト) | ○ |
| 検査の名前・ランナー・Xcode の版の固定・権限は変えない | `W/verify-ios.yml:15-16`・`:21`・`:25-27`・`:38-65` | ○ |

### Requirement: Android の検証

| Scenario | 実装 | テスト | 実地 | 状態 |
|---|---|---|---|---|
| 全件が通れば成功する | `W/verify-android.yml:100-120`、`S/check-android-test-count.py:296-313` | `T/test_check_android_test_count.py:62` | 読み直し: 実行 1・2・PR・B で成功。実行 PR の概要は、本体 512 件 (スキップ 0・クラス 31 / 31)、Sample 163 件 (スキップ 0・クラス 21 / 21) | ✅ 一致 |
| 本体のテストが落ちても Sample の検証は走る | `W/verify-android.yml:108` | `T/test_workflow_files.py:299` | 実地は無い | ✅ 一致 |
| Sample が組み立てられないと落ちる | `W/verify-android.yml:107-110` | `T/test_workflow_files.py:287` (流すコマンドの形) | 実地は無い | ✅ 一致 |
| 結果のファイルが無いと落ちる | `S/check-android-test-count.py:272` | `T/test_check_android_test_count.py:75`、手元 5.1 | — | ✅ 一致 |
| 実行が 0 件なら落ちる | `S/check-android-test-count.py:275` | `T/test_check_android_test_count.py:92` | — | ✅ 一致 |
| 全件がスキップされていると落ちる | `S/check-android-test-count.py:278-279` | `T/test_check_android_test_count.py:99` | — | ✅ 一致 |
| 一部のクラスの結果しか無いと落ちる | `S/check-android-test-count.py:288-291` | `T/test_check_android_test_count.py:106` | — | ✅ 一致 |
| 前の実行の結果は数えない | `W/verify-android.yml:94-98` (テストの前に置き場を空にする)・`:39-50` (ビルドの出力をキャッシュしない) | `T/test_workflow_files.py:280`・`:277`、`T/test_check_android_test_count.py:308`・`:320`、手元 5.1 | — | ✅ 一致 |
| (本文) Sample の計測用のモジュールは対象にしない | `W/verify-android.yml:110` (`:app` だけ) | `T/test_workflow_files.py:287` | — | ✅ 一致 |
| Android の検証 — Side Effects | 検査の結果 (`android / verify`) の作成だけ。依存のキャッシュは、観察できる結果を変えないキャッシュなので数えない | — | 読み直し: 検査の報告は `android / verify` の名前で出ている | ✅ 一致 |

### Requirement: プラットフォームの検証の再利用

| Scenario | 実装 | テスト | 実地 | 状態 |
|---|---|---|---|---|
| 検査が決めた名前で報告される | `W/ci.yml:45-54`、`W/verify-ios.yml:24-25`、`W/verify-android.yml:18-19` | `T/test_workflow_files.py:97`・`:159` | 読み直し: `abf4ade` と `7c6fd10` の検査の報告は `lint`・`ios / verify`・`android / verify` の 3 つで、出した側は GitHub Actions (アプリの ID は 15368) | ✅ 一致 |
| 別の workflow から呼べる | `W/verify-ios.yml:12-13`、`W/verify-android.yml:11-12` (入力を取らない `workflow_call`) | `T/test_workflow_files.py:152`・`:104` | 入口の workflow は入力なしで呼んでいる。入口のほかの workflow から呼んだ実績は無い | ✅ 一致 |
| プラットフォームの検証の再利用 — Side Effects | 定義だけで、状態を変えない。「なし」のとおり | — | — | ✅ 一致 |

### Requirement: 道具の固定と権限

| Scenario | 実装 | テスト | 実地 | 状態 |
|---|---|---|---|---|
| 決めた版の Xcode が無いと落ちる | `W/verify-ios.yml:38-49` | `T/test_workflow_files.py:189`、手元 5.1 | 読み直し: 成功した実行で `Select Xcode` と `Show toolchain` の step が成功。無い場合の実地は無い。deviation の後は「テストを始める前」が「ビルドを始める前」になるが、止まる step は同じ | ✅ 一致 |
| チェックサムが合わないと落ちる | `W/ci.yml:80-91` | `T/test_workflow_files.py:134`、手元 5.2 (Linux のコンテナ) | 読み直し: 実行 PR の記録に照合の `OK`。合わない場合の実地は無い | ✅ 一致 |
| commit の ID で指定していない action があると落ちる | `S/check-workflows.py:218` | `T/test_check_workflows.py:114` | — | ✅ 一致 |
| 最新を指す名前のランナーがあると落ちる | `S/check-workflows.py:233-242` | `T/test_check_workflows.py:148` | — | ✅ 一致 |
| 読み取り以外の権限があると落ちる | `S/check-workflows.py:275-281` | `T/test_check_workflows.py:195` | — | ✅ 一致 |
| 時間の上限を超えると落ちる | `W/ci.yml:58` (5 分)・`W/verify-ios.yml:30` (15 分)・`W/verify-android.yml:24` (15 分) | `S/check-workflows.py:294-301` と `T/test_check_workflows.py:236` (上限の無いジョブを違反にする。`deviation.md:4` の付随修正) | 上限を超えたジョブが打ち切られて失敗で終わるところは、誰も見ていない (公開 8.3 が自分でそう書いている)。GitHub の振る舞いに依る | ✅ 一致 (裏付けが弱い) |
| (本文) 決めた版の JDK を使う | `W/verify-android.yml:33-37` | `T/test_workflow_files.py:274` | — | ✅ 一致 |
| 道具の固定と権限 — Side Effects | 検査は読むだけ。「なし」のとおり | — | — | ✅ 一致 |

## 対応表: repository-publication

| Requirement / Scenario | 実装 | テスト・証跡 | 実地 | 状態 |
|---|---|---|---|---|
| 公開前の確認 / すべて通れば公開に進める | 手順 (tasks 6.1〜6.5) | 公開前 (5 つとも通過。75 commit・画像 104 件) | 読み直し: 今の `main` と `develop` から届く 83 commit で、noreply でないメールアドレスは 0 件、コミットメッセージのローカル絶対パスは 0 件、メールアドレスの形は共同作者の行のものだけ。5 つの確認の後に足された commit に、画像・動画・PDF は 0 件 | ✅ 一致 |
| 公開前の確認 / 通らない確認があれば公開しない | 手順 (tasks 6.6) | 公開前 (5 つとも通ったので、この枝は起きていない。ほかのアプリに関わるものが写る 5 件は、オーナーに示して判断を得ている) | 起きなかった条件なので、実地の裏付けは無い | ✅ 一致 (裏付けが弱い) |
| 公開前の確認 — Side Effects | `evidence/pre-publication-checks.md` の作成 | — | `evidence/` にあるのは文書 4 つだけで、画像は 0 件 | ✅ 一致 |
| 履歴をそのまま公開する / 公開された履歴が手元と一致する | 手順 (tasks 7.1) | 公開 7.1 (最初の push の後、両方とも `a76c380`) | 読み直し: GitHub の `main` は `479fcdc`、`develop` は `abf4ade` で、どちらも手元と同じ。`a76c380` は `main` の先端の 1 つ目の親 | ✅ 一致 |
| 履歴をそのまま公開する / public にする前にオーナーが確かめる | 手順 (tasks 7.2) | 公開 7.2 (目視の依頼の後に、オーナーの指示で切り替えた) | 記録。後から読めるのは、今 public であることだけ | ✅ 一致 (裏付けが弱い) |
| 履歴をそのまま公開する — Side Effects | リポジトリの作成と public への更新、ブランチ `main`・`develop` の作成、remote の作成、手元の `develop` の作成 | 公開 7.1・7.2・7.4 | 読み直し: リポジトリは public、ブランチは `main` と `develop` の 2 つ。列挙に収まる | ✅ 一致 |
| ライセンスの表明 / ルートにライセンスがある | `LICENSE:1`・`:3` | `T/test_repository_files.py:59` | 読み直し: GitHub が `main` のライセンスを MIT と判定している | ✅ 一致 |
| ライセンスの表明 — Side Effects | 「なし」のとおり | — | — | ✅ 一致 |
| 準備中の案内 / 2 枚が同じ構成である | `README.md`・`README_ja.md` | `T/test_repository_files.py:70`。期待値: 見出しの深さの並びが 2 枚とも 1・2・2・2 | — | ✅ 一致 |
| 準備中の案内 / 準備中であることが分かる | `README.md:9`・`:13`・`:17`、`README_ja.md:9`・`:13`・`:17` | `T/test_repository_files.py:76` (導線)。準備中の文面は読んで確かめた | 読み直し: `main` のルートに 2 枚ともある | ✅ 一致 |
| 準備中の案内 — Side Effects | 「なし」のとおり | — | — | ✅ 一致 |
| 貢献方針の表明 / 方針が両方の言語で読める | `.github/CONTRIBUTING.md:7`・`:13`、`.github/CONTRIBUTING_ja.md:7`・`:13` | `T/test_repository_files.py:94` | — | ✅ 一致 |
| 貢献方針の表明 / 2 枚が同じ構成である | 同上 (見出し 3 つ) | `T/test_repository_files.py:88`。期待値: 見出しの深さの並びが 2 枚とも 1・2・2 | — | ✅ 一致 |
| 貢献方針の表明 — Side Effects | 「なし」のとおり | — | — | ✅ 一致 |
| Issue のフォームの必須項目 / 3 本のフォームだけが選べる | `.github/ISSUE_TEMPLATE/` の 3 本と `config.yml:1` | `T/test_repository_files.py:121`・`:149` | 読み直し: `main` に 3 本と `config.yml` (`blank_issues_enabled: false`) がある。記録 (公開 7.7): 管理する側の画面には、3 本のほかに空の Issue の行が出る。管理する側でない人の画面は見ていない | ❌ 乖離 (記録なし) |
| Issue のフォームの必須項目 / 必須の項目が空だと送れない | `.github/ISSUE_TEMPLATE/bug_report.yml:43` ほか。必須の項目は spec の表と 3 本とも一致 | `T/test_repository_files.py:125` | 記録 (公開 7.7): オーナーの報告 (「問題なさそう」) による。指揮側は画面を見ていない。今回も画面は見ていない | ✅ 一致 (裏付けが弱い) |
| Issue のフォームの必須項目 — Side Effects | ファイルは状態を変えない。「なし」のとおり | — | 読み直し: Issue は 1 件も作られていない | ✅ 一致 |
| Pull Request を作れる人の制限 / 設定が共同作業者だけになっている | GitHub の設定 (tasks 7.3) | 公開 7.3 | 読み直し: `pull_request_creation_policy` は `collaborators_only` | ✅ 一致 |
| Pull Request を作れる人の制限 — Side Effects | 設定の更新と、証跡の作成 | 公開 7.3 | — | ✅ 一致 |
| ブランチの保護 / main の保護に必須の検査が入っている | GitHub の設定 (tasks 7.5) | 公開 7.5 | 読み直し: Pull Request が必須で承認の数は 0。必須の検査は `lint`・`ios / verify`・`android / verify` の 3 つで、どれもアプリの ID が 15368。強制 push と削除は禁止。管理者には強制しない | ✅ 一致 |
| ブランチの保護 / develop は強制 push と削除だけを禁じる | 同上 | 公開 7.5 | 読み直し: 強制 push と削除は禁止。必須の検査と Pull Request の必須は無い。管理者には強制しない | ✅ 一致 |
| ブランチの保護 / main には検査を通った develop が入る | `W/ci.yml:18-20`・`:75-78`、手順 (tasks 7.6) | 公開 7.6 | 読み直し: Pull Request 1 番は `develop` から `main` 宛てで、別のリポジトリからではなく、3 つの検査が成功し、`MERGED`。merge commit は `479fcdc` で、親は `a76c380` と `7c6fd10` の 2 つ。`main` のルートに `LICENSE`・README 2 枚・`.github` がある | ✅ 一致 |
| ブランチの保護 — Side Effects | 保護の作成、Pull Request の作成とマージ、証跡の作成 | 公開 7.5・7.6 | 読み直し: Pull Request は 1 番だけ。列挙に収まる | ✅ 一致 |
| 公開リポジトリの機能の設定 / 設定が決めたとおりになっている | GitHub の設定 (tasks 7.3)、フォーム 3 本の `labels` | 公開 7.3、`T/test_repository_files.py:131` | 読み直し: 既定のブランチは `main`。Issues は有効、Wiki・Discussions・Projects は無効。secret の検査と push の保護は有効。依存の脆弱性の通知は有効 (応答 204)。ラベル 9 つに `bug`・`enhancement`・`question` が含まれる | ✅ 一致 |
| 公開リポジトリの機能の設定 — Side Effects | 設定の更新と、証跡の作成 | 公開 7.3 | — | ✅ 一致 |

## ❌ の見立て

| # | Scenario | 乖離の中身 | 見立て |
|---:|---|---|---|
| 1 | Issue のフォームの必須項目 / 3 本のフォームだけが選べる (本文の「フォームを使わない空の Issue は作れてはならない」を含む) | spec は「空の Issue は選べない」。管理する側 (書き込める人) の画面には、空の Issue の行が印つきで出る。証跡がこれを「Scenario の文面と違う」と書いているが、`deviation.md` に行が無い。あわせて、この Requirement が本来向いている相手 (管理する側でない人) の画面は、誰も見ていない | **deviation として合意する**のがよい。設定は design のとおりに入っていて、管理する側に空の Issue の行が出るのは GitHub の仕様なので、実装では直せない。合意の内容は「管理する側を除いて、空の Issue は作れない」。管理する側でない人の画面を 1 度見て、3 本だけが並ぶことを確かめられると、裏付けもそろう (ログインしていない読み取りでは見られない画面なので、今回の検証では確かめられなかった) |

決めるのは指揮側とオーナーで、この検証では `deviation.md` に書き足していない。

## 裏付けが弱い Scenario

✅ または ⚠️ に数えたが、Scenario の THEN そのものを誰も見ていない、または後から読めないもの。

| # | Scenario | 何が弱いか | 判定に数えた根拠 |
|---:|---|---|---|
| 1 | 道具の固定と権限 / 時間の上限を超えると落ちる | 上限を超えたジョブが打ち切られて失敗で終わるところは見ていない | 3 つのジョブが上限を持つこと (定義) と、上限の無いジョブを違反にする検査とそのテスト |
| 2 | Issue のフォームの必須項目 / 必須の項目が空だと送れない | オーナーの報告だけで、指揮側も検証者も画面を見ていない | フォームの必須の指定が spec の表と一致することと、そのテスト |
| 3 | 公開前の確認 / 通らない確認があれば公開しない | 通らない確認が起きなかったので、止まるところは見ていない | 5 つの確認の記録と、判断の要る 5 件をオーナーに示した記録 |
| 4 | 履歴をそのまま公開する / public にする前にオーナーが確かめる | 目視と承認は記録だけで、後から読めない。非公開の間に push したのが `main` だけだったことも同じ | 公開 7.1・7.2 の記録 |
| 5 | 起動条件 / 起動しない push は走っている実行に影響しない | 「push の後も走り続けていた」は、25 秒後の 1 回の観察の記録 | 実行が作られていないことと、実行 A が止まったのが実行 B の作成の後であることは、今回読み直した |
| 6 | 起動条件 / main 宛ての Pull Request では絞り込まない | Pull Request が「更新される」ときは見ていない (作られたときだけ) | 定義に絞り込みが無いことと、そのテスト |
| 7 | lint の検証の異常系 4 件 (secret・ローカル絶対パス・個人を特定する値・コメントの規約) | 自動のテストが無く、裏付けは手元 5.2 の一時のツリーでの実測だけ | tasks 5.2 と備考が定めた確かめ方。lint の step の並びは `T/test_workflow_files.py:111` が守る |
| 8 | iOS・Android の「落ちると落ちる」(iOS の Sample がビルドできない / Android の本体のテストが落ちても Sample は走る / Android の Sample が組み立てられない) | ランナーの上で失敗する実行を見ていない。iOS は手元でテストのコードを壊した場合だけ (アプリのコードを壊す場合は流していない) | 定義の形と、失敗を見逃す指定が無いことのテスト。iOS の「本体が落ちても Sample は走る」は、変える前の形で実行 1 が実地の例になっている |
| 9 | 道具の固定と権限 / チェックサムが合わないと落ちる・決めた版の Xcode が無いと落ちる | 落ちる側は、手元と Linux のコンテナでだけ確かめている | 定義の形のテストと、手元 5.1・5.2 |
| 10 | 再利用 / 別の workflow から呼べる | 入口のほかの workflow から呼んだ実績は無い | 入力を取らない定義と、そのテスト |

## GitHub の今の状態の読み直し

読み取りだけのコマンド (`gh api` の GET・`gh repo view` 相当の読み取り・`gh run list`・`gh run view`・`gh pr view`・`git ls-remote`) で読んだ。書き込みはしていない。

| 確かめたこと | 証跡の値 | 今回読んだ値 | 一致 |
|---|---|---|---|
| 公開の範囲 | public | `visibility: public`、`private: false`、`archived`・`disabled` は false | ○ |
| 既定のブランチ | `main` | `main` | ○ |
| Issues / Wiki / Discussions / Projects | 有効 / 無効 / 無効 / 無効 | true / false / false / false | ○ |
| Pull Request を作れる人 | 共同作業者だけ | `collaborators_only` | ○ |
| secret の検査 / push の保護 | 有効 / 有効 | `enabled` / `enabled` | ○ |
| 依存の脆弱性の通知 | 有効 (応答 204) | 応答 204 | ○ |
| ラベル | 9 つに `bug`・`enhancement`・`question` を含む | 9 つ。3 つとも含む | ○ |
| `main` の保護 | Pull Request が必須・承認 0・必須の検査 3 つ (アプリの ID 15368)・強制 push と削除は禁止・管理者に強制しない・`strict` は false・push できる人の限定なし | すべて同じ | ○ |
| `develop` の保護 | 強制 push と削除は禁止・必須の検査なし・Pull Request の必須なし・管理者に強制しない | すべて同じ | ○ |
| Pull Request 1 番 | `MERGED`・merge commit `479fcdc`・別のリポジトリからではない | 同じ。3 つの検査は成功 | ○ |
| ブランチの先端 | `main` は `479fcdc` | `main` は `479fcdc`、`develop` は `abf4ade` (手元と同じ) | ○ |
| `main` の先端の親 | `a76c380` と `7c6fd10` | 同じ | ○ |
| 実行の一覧 | 実行 1 (失敗)・2 (成功)・PR (成功)・A (打ち切り)・B (成功) | 5 件で、対象・起動のきっかけ・結果が同じ。ほかの実行は無い (マージの後の `main` への push の実行も無い) | ○ |
| ジョブの所要時間 | lint 7〜10 秒 / iOS 2 分 16 秒〜4 分 8 秒 (ビルドだけ)・13 分 10 秒 (実行 1) / Android 3 分 50 秒〜6 分 14 秒 | ジョブの開始と終了の時刻から数えて、すべて同じ | ○ |
| 実行 1 の iOS の step | 本体のテストが失敗し、Sample の step は走った | `Test library` が失敗、その後の 3 つの step は成功 | ○ |

証跡の値と今の状態で、食い違うものは無かった。

## 追加検査

| 検査 | 結果 |
|---|---|
| tasks.md の虚偽のチェック | なし。41 件すべてにチェックがある。tasks.md の提案からの差分はチェックの印 41 箇所だけで、文面は変わっていない。3.1・3.3・3.6 の成果物 (スクリプト 3 本) は今は無いが、作った後に `deviation.md:6` で取り除いたもので、虚偽ではない。9.1〜9.3 は `drafts/` があることだけを見た (中身は対象にしていない) |
| 逆流 | なし。`proposal.md`・`design.md`・`specs/` に触れた commit は提案の commit (`a76c380`) だけで、作業ツリーにも差分は無い |
| 未記録の乖離 | 1 件 (上の ❌) |
| 付随修正 | `deviation.md:3` は `S/check-android-test-count.py:210-211` に、`deviation.md:4` は `S/check-workflows.py:294-314`・`T/test_check_workflows.py:236-266`・`W/ci.yml:130-131` に当たる。どちらも記録済みで、乖離としない |
| Scenario に対応しない差分 | 提案の commit からの `kasane/` の外の差分は 25 ファイル (すべて追加)。Scenario に直接は対応しない `.github/actionlint.yaml`・`S/ci_report.py`・`T/support.py` は、tasks 4.5 と 3 章の成果物を支えるもので、記録の無い付随修正には当たらない。`kasane/` の中で、この change のディレクトリの外に差分は無い |
| Side Effects (逆向き) | 16 行すべて列挙に収まる。数えなかったもの: ランナーの一時の置き場への書き込み、実行の結果の概要への追記、依存のキャッシュ、GitHub が Pull Request に付ける参照。手元の `main` の早送りと remote の URL の形の変更 (公開 8.4・7.1) は、tasks 8.4 と remote の作成の中の操作で、どの Requirement の実装でもないため、逆向きの検査の対象にしていない |
| UI | 対象外 (UI の変更ではない) |
| テストの実行 | 今回流した: `python3 scripts/ci/run-tests.py` は実行 111 件 / 失敗 0 件 / スキップ 0 件。`python3 scripts/ci/check-workflows.py` は workflow 3 本で違反なし。lint 3 本 (ローカル絶対パス・個人を特定する値・コメントの規約) は終了コード 0。xcodebuild と Gradle は流していない。Android のテストの件数 (本体 512・Sample 163) は、実行 PR の記録から読んだ |

## 判定に数えない所見

1. **証跡の最後の追記と tasks のチェックが、まだ commit されていない。** `evidence/publication-log.md` (8.1〜8.4 の節) と `tasks.md` (8.1〜8.4 のチェック) は作業ツリーの変更のままである。検証は作業ツリーの内容で行った。
2. **`main` の workflow の時間の上限は、暫定の値のままである。** 上限を決め直した 2 つの commit (`f374fad`・`abf4ade`) は、Pull Request 1 番のマージの後に `develop` に入った。`main` と `develop` の `kasane/` の外の差は、workflow 3 本の上限の行だけである。tasks の順番 (7.6 の後に 8.3) のとおりで、乖離ではない。次の `main` 宛ての Pull Request で入る。
3. **公開前の 5 つの確認が見たのは、実装の commit (`c2697b3`) までの 75 commit である。** その後の 8 commit (うち 1 つは GitHub が作った merge commit) は、push の前の hook と検証 CI の lint に任されている。今回、今の 83 commit について、メールアドレス・コミットメッセージ・画像の追加の 3 点を読み直して、違反が無いことを確かめた。gitleaks での全履歴の走査は、今回は流していない (流してよいコマンドの外)。
4. **Android SDK の取得の枝 (`W/verify-android.yml:80-90`) は、どこでも通っていない。** ランナーに Platform 36 があるので、4 回の実行はすべて「ランナーにある」の枝を通った (実行 PR の記録で確かめた)。この枝に対応する Scenario は無く、tasks 4.3 の「備え」に当たる。判定には数えていない。
5. **gitleaks の全履歴の走査とチェックサムの突き合わせ、画像 104 件の目視は、証跡の記録を読んだだけである。** 取り出した画像は消されているので、後から見直せない。
6. **検証 CI の緑が保証する範囲が、提案のときから狭くなっている。** iOS のテストの実行は、手元の完了判定だけが担う。`deviation.md:7` の蒸留送りの行 (cross/ADR-0013 を直してから確定する) が、これを長命層に写す入口になっている。入口の workflow と iOS の workflow の冒頭のコメントは、すでに今の形を書いている。
7. **スクリプトのテストの件数は、Linux のランナーでも 111 件である。** 実行 PR の記録で確かめた。`verify-001.md` の所見 4 (修正の後の Linux での再実行が無い) は、これで解消している。

## 検証者の作業の記録

- 書いたファイルはこの `verify-002.md` だけ。ソース・足場・証跡・長命層は書き換えていない。git の add・commit・push はしていない
- GitHub への書き込み (設定の変更・Issue や Pull Request の作成とコメント・実行のやり直し・push) はしていない
- 流したコマンド: `python3 scripts/ci/run-tests.py`、`python3 scripts/ci/check-workflows.py`、lint 3 本、読み取りだけの `gh` と `git ls-remote`、読み取りだけの `git` (log・diff・show・rev-list)。実行の記録の読み取りでは、一時の場所に記録を 1 つ保存した (リポジトリの外)
