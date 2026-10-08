# Verify 001: public-repo-verify-ci (公開の前の段階)

- 日付: 2026-10-08
- 対象: tasks.md のグループ 2〜5 の成果物 (ブランチ `develop` の作業ツリーの未コミットの変更と未追跡ファイル)
- 範囲: この change は 2 段階で進む。今回は公開の前の段階で、GitHub 上のリポジトリ・設定・実行が無いと確かめられない Scenario は「公開の段階で確認 (未実施)」として列挙し、判定に数えない
- 前回の検証: なし (初回)

## 判定

**VALID (公開の前の段階の範囲)**

| 区分 | 件数 |
|---|---:|
| デルタスペックの Scenario の総数 | 55 (verification-ci 39 / repository-publication 16) |
| 今の段階で判定した Scenario | 37 (✅ 37 / ⚠️ 0 / ❌ 0。verification-ci 32 / repository-publication 5) |
| 公開の段階に持ち越した Scenario | 18 (verification-ci 7 / repository-publication 11) |
| Side Effects の行 | 16 (今の段階で判定 11: ✅ 11 / 持ち越し 5) |

- 対応の取れなかった Scenario: なし
- 虚偽のチェック: なし / 逆流: なし / 未記録の乖離: なし / テスト: 123 件成功

この VALID は、change 全体の VALID ではない。持ち越した 18 件と Side Effects の 5 行は、tasks のグループ 6〜8 の後に、あらためて検証が要る。

## 対応表の読み方

- パスの省略: `T/` は `scripts/ci/tests/`、`W/` は `.github/workflows/`、`S/` は `scripts/ci/`
- 証跡: `evidence/ci-local-verification.md` (以下「証跡」。節の番号は tasks の番号)
- 状態の「持ち越し」は「公開の段階で確認 (未実施)」。その Scenario を支える定義が今の成果物にあるかは「実装」の列に書いた

## 対応表: verification-ci

### Requirement: 検証 CI の起動条件

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| develop への push で起動する | 定義あり: `W/ci.yml:20-22` (起動)、`W/ci.yml:44-53` (3 つのジョブ) | `T/test_workflow_files.py:74`・`:96` (定義の形)。実地は tasks 7.4 | 持ち越し |
| 開発の記録だけの push では起動しない | 定義あり: `W/ci.yml:23-27` | `T/test_workflow_files.py:80` (定義の形)。実地は tasks 8.1 | 持ち越し |
| main 宛ての Pull Request では絞り込まない | 定義あり: `W/ci.yml:17-19` (絞り込みのキーなし) | `T/test_workflow_files.py:87` (定義の形)。実地は tasks 7.6 | 持ち越し |
| 起動の対象になる新しい push が古い実行を打ち切る | 定義あり: `W/ci.yml:36-38` | `T/test_workflow_files.py:91` (定義の形)。実地は tasks 8.2 | 持ち越し |
| 起動しない push は走っている実行に影響しない | 定義あり: `W/ci.yml:23-27` (起動しないので、同時実行のまとまりに入らない) | 定義の形は上の 2 行と同じ。実地は tasks 8.1 | 持ち越し |
| 検証 CI の起動条件 — Side Effects | 定義が起こすのは、実行の作成と、同じまとまりの古い実行の打ち切り (`W/ci.yml:16-38`) だけ。列挙に収まる | — | ✅ 一致 |

### Requirement: main 宛ての Pull Request の出どころの制限

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| develop からの Pull Request は通る | `S/check-pr-head.py:71`、`W/ci.yml:74-77` | `T/test_check_pr_head.py:25` | ✅ 一致 (実地の記録の確認は tasks 7.6) |
| develop 以外のブランチからの Pull Request は落ちる | `S/check-pr-head.py:66-70` | `T/test_check_pr_head.py:31`、証跡 5.2 | ✅ 一致 |
| 別のリポジトリの同じ名前のブランチからの Pull Request は落ちる | `S/check-pr-head.py:61-65` | `T/test_check_pr_head.py:38`、証跡 5.2 | ✅ 一致 |
| (本文) push で起動したときは確認を行わない | `S/check-pr-head.py:51-52` | `T/test_check_pr_head.py:44`、証跡 5.3 | ✅ 一致 |
| main 宛ての Pull Request の出どころの制限 — Side Effects | 標準出力への表示だけ (`S/check-pr-head.py:87-91`)。「なし」のとおり | — | ✅ 一致 |

### Requirement: lint の検証

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 違反が無ければ通る | `W/ci.yml:52-132` | 証跡 5.3 (macOS と Linux のコンテナで、全 step が終了コード 0)、`T/test_workflow_files.py:110` (検査の step の並び) | ✅ 一致 |
| secret を含む内容で落ちる | `W/ci.yml:92-113` | 証跡 5.2 (`leaks found: 2`)。自動のテストは無い | ✅ 一致 |
| ローカル絶対パスを含む内容で落ちる | `W/ci.yml:115-116` (既存の `scripts/local-path-lint.py` を呼ぶ) | 証跡 5.2。自動のテストは無い | ✅ 一致 |
| 個人を特定する値を含む内容で落ちる | `W/ci.yml:118-119` (既存の `scripts/identity-lint.py` を呼ぶ) | 証跡 5.2。自動のテストは無い | ✅ 一致 |
| コメントの規約に反するソースで落ちる | `W/ci.yml:121-122` (既存の `scripts/comment-policy-lint.py` を呼ぶ) | 証跡 5.2。自動のテストは無い | ✅ 一致 |
| 走査の対象を取り出せないと落ちる | `W/ci.yml:96` (pipefail)・`:102-112` | `T/test_workflow_files.py:141` (数の確認が走査より前)、証跡 5.2 (数が少ない場合と、取り出しが失敗する場合の 2 行) | ✅ 一致 |
| 検査のスクリプトのテストが落ちると lint も落ちる | `S/run-tests.py:36-43`、`W/ci.yml:126-127` | `T/test_run_tests.py:60`、証跡 5.2 | ✅ 一致 |
| lint の検証 — Side Effects | 検査の結果 (`lint`) の作成だけ。ランナーの一時の置き場への書き込み (`W/ci.yml:82-90`・`:100-102`) は、ジョブとともに消えるので数えない | — | ✅ 一致 |

### Requirement: iOS の検証

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 全件が通れば成功する | `W/verify-ios.yml:77-114`、`S/check-ios-test-count.py:125-136`・`:160` | `T/test_check_ios_test_count.py:67`、証跡 5.1 (本体 567 / Sample 37) | ✅ 一致 |
| 本体のテストが落ちても Sample の検証は走る | `W/verify-ios.yml:100` (条件)、`S/run-logged.py:84` (終了コードをそのまま返す) | `T/test_workflow_files.py:207`、`T/test_run_logged.py:46` | ✅ 一致 |
| Sample がビルドできないと落ちる | `W/verify-ios.yml:98-110`、`S/run-logged.py:84` | `T/test_run_logged.py:46` | ✅ 一致 |
| Sample のユニットテストが落ちると落ちる | 同上 | `T/test_run_logged.py:46` | ✅ 一致 |
| Sample の UI テストは走らない | `W/verify-ios.yml:109` | `T/test_workflow_files.py:199`、証跡 4.1 (始まった 37 件のうち UI テストは 0 件) | ✅ 一致 |
| 実行が 0 件なら落ちる | `S/check-ios-test-count.py:115-116` | `T/test_check_ios_test_count.py:88` | ✅ 一致 |
| 全件がスキップされていると落ちる | `S/check-ios-test-count.py:117-121` | `T/test_check_ios_test_count.py:94` | ✅ 一致 |
| 件数を読み取れないと落ちる | `S/check-ios-test-count.py:108-114` | `T/test_check_ios_test_count.py:100` (集計の行が無い)・`:105` (記録が無い) | ✅ 一致 |
| (本文) その実行で作られた記録から読む | `S/run-logged.py:38` (始める前に記録を空にする) | `T/test_run_logged.py:52` | ✅ 一致 |
| iOS の検証 — Side Effects | 検査の結果 (`ios / verify`) の作成だけ。実行の結果の概要への追記 (`S/ci_report.py:18-21`) は表示で、数えない | — | ✅ 一致 |

### Requirement: Android の検証

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 全件が通れば成功する | `W/verify-android.yml:99-119`、`S/check-android-test-count.py:274-301` | `T/test_check_android_test_count.py:62`、証跡 5.1 (本体 512 / Sample 163) | ✅ 一致 |
| 本体のテストが落ちても Sample の検証は走る | `W/verify-android.yml:107` (条件) | `T/test_workflow_files.py:256` | ✅ 一致 |
| Sample が組み立てられないと落ちる | `W/verify-android.yml:106-109` (`:app:assembleDebug` を step で直に流す) | `T/test_workflow_files.py:244` (流すコマンドの形) | ✅ 一致 |
| 結果のファイルが無いと落ちる | `S/check-android-test-count.py:248-250` | `T/test_check_android_test_count.py:75`、証跡 5.1 | ✅ 一致 |
| 実行が 0 件なら落ちる | `S/check-android-test-count.py:252-253` | `T/test_check_android_test_count.py:92` | ✅ 一致 |
| 全件がスキップされていると落ちる | `S/check-android-test-count.py:254-258` | `T/test_check_android_test_count.py:99` | ✅ 一致 |
| 一部のクラスの結果しか無いと落ちる | `S/check-android-test-count.py:263-270` | `T/test_check_android_test_count.py:106` | ✅ 一致 |
| 前の実行の結果は数えない | `W/verify-android.yml:93-97` (テストの前に置き場を空にする)・`:44-46` (ビルドの出力をキャッシュしない) | `T/test_workflow_files.py:237`・`:234`、証跡 5.1 (偽の 1000 件を置いて確かめた) | ✅ 一致 |
| (本文) Sample の計測用のモジュールは対象にしない | `W/verify-android.yml:109` (`:app` だけ) | `T/test_workflow_files.py:244` | ✅ 一致 |
| Android の検証 — Side Effects | 検査の結果 (`android / verify`) の作成だけ。依存のキャッシュ (`W/verify-android.yml:38-49`) は、観察できる結果を変えないキャッシュなので数えない | — | ✅ 一致 |

### Requirement: プラットフォームの検証の再利用

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 検査が決めた名前で報告される | 定義あり: `W/ci.yml:44-53` (`ios`・`android`・`lint`)、`W/verify-ios.yml:23-24`・`W/verify-android.yml:18-19` (`verify`) | `T/test_workflow_files.py:96`・`:158` (定義の形)。実地は tasks 7.4 | 持ち越し |
| 別の workflow から呼べる | `W/verify-ios.yml:11-12`、`W/verify-android.yml:11-12` (入力を取らない `workflow_call`) | `T/test_workflow_files.py:151`・`:103` | ✅ 一致 |
| プラットフォームの検証の再利用 — Side Effects | 定義だけで、状態を変えない。「なし」のとおり | — | ✅ 一致 |

### Requirement: 道具の固定と権限

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 決めた版の Xcode が無いと落ちる | `W/verify-ios.yml:37-48` | `T/test_workflow_files.py:181`、証跡 5.1 | ✅ 一致 |
| チェックサムが合わないと落ちる | `W/ci.yml:79-90` | `T/test_workflow_files.py:133` (照合が展開より前)、証跡 5.2 (Linux のコンテナ) | ✅ 一致 |
| commit の ID で指定していない action があると落ちる | `S/check-workflows.py:212-224` | `T/test_check_workflows.py:113` (場所の `ファイル:行` まで照合) | ✅ 一致 |
| 最新を指す名前のランナーがあると落ちる | `S/check-workflows.py:236-239` | `T/test_check_workflows.py:147` (ジョブの名前まで照合) | ✅ 一致 |
| 読み取り以外の権限があると落ちる | `S/check-workflows.py:269-285` | `T/test_check_workflows.py:194` | ✅ 一致 |
| 時間の上限を超えると落ちる | 定義あり: `W/ci.yml:57`・`W/verify-ios.yml:29`・`W/verify-android.yml:23` (値は暫定) | `T/test_workflow_files.py:166` (定義の形)。実測と値の決め直しは tasks 8.3 | 持ち越し |
| (本文) 決めた版の JDK を使う | `W/verify-android.yml:32-36` | `T/test_workflow_files.py:231` | ✅ 一致 |
| 道具の固定と権限 — Side Effects | 検査は読むだけ。「なし」のとおり | — | ✅ 一致 |

## 対応表: repository-publication

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 公開前の確認 / すべて通れば公開に進める | 今の成果物に要る定義は無い (手順は tasks 6) | tasks 6.1〜6.5 | 持ち越し |
| 公開前の確認 / 通らない確認があれば公開しない | 同上 | tasks 6.6 | 持ち越し |
| 公開前の確認 — Side Effects | 証跡は未作成 | tasks 6 | 持ち越し |
| 履歴をそのまま公開する / 公開された履歴が手元と一致する | 今の成果物に要る定義は無い | tasks 7.1 | 持ち越し |
| 履歴をそのまま公開する / public にする前にオーナーが確かめる | 同上 | tasks 7.2 | 持ち越し |
| 履歴をそのまま公開する — Side Effects | 手元のブランチ `develop` は作成済み。remote と GitHub 上のものは未作成 | tasks 1.1・7.1・7.2・7.4 | 持ち越し |
| ライセンスの表明 / ルートにライセンスがある | `LICENSE:1`・`:3` | `T/test_repository_files.py:59` | ✅ 一致 |
| ライセンスの表明 — Side Effects | 「なし」のとおり | — | ✅ 一致 |
| 準備中の案内 / 2 枚が同じ構成である | `README.md`・`README_ja.md` (見出し 4 つ) | `T/test_repository_files.py:70`。期待値: 見出しの深さの並びが 2 枚とも 1・2・2・2 | ✅ 一致 |
| 準備中の案内 / 準備中であることが分かる | `README.md:9`・`:13`・`:17`、`README_ja.md:9`・`:13`・`:17` | `T/test_repository_files.py:76` (ライセンスと貢献の案内への導線)。準備中の文面は自動のテストが無く、2 枚を読んで確かめた | ✅ 一致 |
| 準備中の案内 — Side Effects | 「なし」のとおり | — | ✅ 一致 |
| 貢献方針の表明 / 方針が両方の言語で読める | `.github/CONTRIBUTING.md:7`・`:13`、`.github/CONTRIBUTING_ja.md:7`・`:13` | `T/test_repository_files.py:94` | ✅ 一致 |
| 貢献方針の表明 / 2 枚が同じ構成である | 同上 (見出し 3 つ) | `T/test_repository_files.py:88`。期待値: 見出しの深さの並びが 2 枚とも 1・2・2 | ✅ 一致 |
| 貢献方針の表明 — Side Effects | 「なし」のとおり | — | ✅ 一致 |
| Issue のフォームの必須項目 / 3 本のフォームだけが選べる | 定義あり: `.github/ISSUE_TEMPLATE/` の 3 本と `config.yml:1` | `T/test_repository_files.py:121`・`:149` (定義の形)。実地は tasks 7.7 | 持ち越し |
| Issue のフォームの必須項目 / 必須の項目が空だと送れない | 定義あり: `.github/ISSUE_TEMPLATE/bug_report.yml:42-43` ほか。必須の項目は spec の表と 3 本とも一致 | `T/test_repository_files.py:125` (定義の形)。実地は tasks 7.7 | 持ち越し |
| Issue のフォームの必須項目 — Side Effects | ファイルは状態を変えない。「なし」のとおり | — | ✅ 一致 |
| Pull Request を作れる人の制限 / 設定が共同作業者だけになっている | 今の成果物に要る定義は無い (GitHub の設定) | tasks 7.3 | 持ち越し |
| Pull Request を作れる人の制限 — Side Effects | 未実施 | tasks 7.3 | 持ち越し |
| ブランチの保護 / main の保護に必須の検査が入っている | 必須の検査の名前の元になる定義あり: `W/ci.yml:44-53` | tasks 7.5 | 持ち越し |
| ブランチの保護 / develop は強制 push と削除だけを禁じる | 今の成果物に要る定義は無い | tasks 7.5 | 持ち越し |
| ブランチの保護 / main には検査を通った develop が入る | 定義あり: `W/ci.yml:17-19` (起動)、`W/ci.yml:74-77` (出どころの確認) | tasks 7.6 | 持ち越し |
| ブランチの保護 — Side Effects | 未実施 | tasks 7.5・7.6 | 持ち越し |
| 公開リポジトリの機能の設定 / 設定が決めたとおりになっている | ラベルを使う側の定義あり: フォーム 3 本の `labels` (`bug`・`enhancement`・`question`) | `T/test_repository_files.py:131` (定義の形)。実地は tasks 7.3 | 持ち越し |
| 公開リポジトリの機能の設定 — Side Effects | 未実施 | tasks 7.3 | 持ち越し |

## 公開の段階で確認 (未実施) の一覧

今回の判定に数えていない 18 件。

| # | 能力 | Requirement / Scenario | 確かめる tasks | 今ある定義 |
|---:|---|---|---|---|
| 1 | verification-ci | 起動条件 / develop への push で起動する | 7.4 | あり |
| 2 | verification-ci | 起動条件 / 開発の記録だけの push では起動しない | 8.1 | あり |
| 3 | verification-ci | 起動条件 / main 宛ての Pull Request では絞り込まない | 7.6 | あり |
| 4 | verification-ci | 起動条件 / 起動の対象になる新しい push が古い実行を打ち切る | 8.2 | あり |
| 5 | verification-ci | 起動条件 / 起動しない push は走っている実行に影響しない | 8.1 | あり |
| 6 | verification-ci | 再利用 / 検査が決めた名前で報告される | 7.4 | あり |
| 7 | verification-ci | 道具の固定と権限 / 時間の上限を超えると落ちる | 8.3 | あり (値は暫定) |
| 8 | repository-publication | 公開前の確認 / すべて通れば公開に進める | 6.1〜6.5 | 要らない |
| 9 | repository-publication | 公開前の確認 / 通らない確認があれば公開しない | 6.6 | 要らない |
| 10 | repository-publication | 履歴をそのまま公開する / 公開された履歴が手元と一致する | 7.1 | 要らない |
| 11 | repository-publication | 履歴をそのまま公開する / public にする前にオーナーが確かめる | 7.2 | 要らない |
| 12 | repository-publication | Issue のフォームの必須項目 / 3 本のフォームだけが選べる | 7.7 | あり |
| 13 | repository-publication | Issue のフォームの必須項目 / 必須の項目が空だと送れない | 7.7 | あり |
| 14 | repository-publication | Pull Request を作れる人の制限 / 設定が共同作業者だけになっている | 7.3 | 要らない |
| 15 | repository-publication | ブランチの保護 / main の保護に必須の検査が入っている | 7.5 | あり (検査の名前) |
| 16 | repository-publication | ブランチの保護 / develop は強制 push と削除だけを禁じる | 7.5 | 要らない |
| 17 | repository-publication | ブランチの保護 / main には検査を通った develop が入る | 7.6 | あり |
| 18 | repository-publication | 公開リポジトリの機能の設定 / 設定が決めたとおりになっている | 7.3 | あり (ラベルを使う側) |

持ち越した Scenario を支える定義で、今の成果物に欠けているものは無い。

今の段階で ✅ とした Scenario のうち、GitHub のランナーの上での実行をまだ見ていないもの (「違反が無ければ通る」、iOS と Android の「全件が通れば成功する」、「develop からの Pull Request は通る」) は、tasks 7.4・7.6 の実行で実地の裏付けが加わる。今回の ✅ は、手元と Linux のコンテナでの実測とスクリプトのテストに基づく。

## 追加検査

| 検査 | 結果 |
|---|---|
| tasks.md の虚偽のチェック | なし。チェック済みの 20 件 (2.1〜2.4、3.1〜3.7、4.1〜4.5、5.1〜5.4) は、どれも成果物・テスト・証跡と対応する。tasks.md の差分はチェックの印 20 箇所だけで、文面は変わっていない |
| 逆流 | なし。`proposal.md`・`design.md`・`specs/` は、提案の commit (a76c380) から作業ツリーまで差分が無い |
| 未記録の乖離 | なし |
| 付随修正 | `deviation.md` の 1 件 (Android の件数の検査で、テストのソースを走査する順を名前順にした) は `S/check-android-test-count.py:188-189` に当たる。記録済みで、乖離としない |
| Scenario に対応しない差分 | `S/select-simulator.py` と `T/test_select_simulator.py` (tasks 3.3)、`.github/actionlint.yaml` (tasks 4.5 で actionlint を通すための登録) は、tasks が求める成果物で、iOS の検証と道具の固定を支える。記録の無い付随修正には当たらない |
| Side Effects (逆向き) | 今の段階で判定した 11 行はすべて列挙に収まる。数えなかったもの: ランナーの一時の置き場への書き込み、実行の結果の概要への追記、依存のキャッシュ。`evidence/ci-local-verification.md` は開発の記録で、能力の実行が起こす状態の変更ではない |
| UI | 対象外 (UI の変更ではない) |
| テストの実行 | `python3 scripts/ci/run-tests.py` を今回流して、実行 123 件 / 失敗 0 件 / スキップ 0 件 (macOS)。テスト 4 系統 (iOS 本体 567・iOS Sample 48・Android 本体 512・Android Sample 163) は今回流しておらず、証跡 5.4 の記録を読んだだけである |

## 判定に数えない所見

一致の判定は変えないが、指揮側が知っておくとよい点。

1. **自動のテストを持たず、証跡だけで裏付けた Scenario が 4 件ある。** lint の「secret を含む内容で落ちる」「ローカル絶対パスを含む内容で落ちる」「個人を特定する値を含む内容で落ちる」「コメントの規約に反するソースで落ちる」。呼ぶ先は gitleaks と既存の 3 本の lint で、裏付けは証跡 5.2 の一時のツリーでの実測だけである。この確かめ方は tasks 5.2 と備考が定めたものなので ✅ とした。厳しく読むなら、テストの欠落として扱う余地がある。
2. **README の「準備中で公開物がまだ無い」の文面は、テストが表明していない。** テストが見るのは見出しの並びと導線だけである。文面は 2 枚を読んで確かめた (`README.md:9`・`README_ja.md:9`)。本文の「インストールの手順と使い方の説明は含めない」も同じで、読んで確かめた (どちらの README にも該当する節は無い)。
3. **iOS と Android の「落ちると落ちる」は、失敗する実行を実際には見ていない。** step の失敗がジョブの失敗になるという GitHub の挙動と、定義の形に依る。tasks の備考により、公開リポジトリでも失敗する実行は作らない方針なので、公開の段階でも実地の裏付けは加わらない。プラットフォームの 2 本の workflow に失敗の見逃しの指定 (`continue-on-error`) が無いことは、今回の検索で 0 件と確かめたが、テストがこれを守っているのは lint の step だけである (`T/test_workflow_files.py:127`)。
4. **レビュー後の修正の後、Linux のコンテナでの再実行はされていない。** 証跡 5.3 の 115 件は修正の前の数で、今の 123 件は macOS でだけ流されている (証跡の追記のとおり)。Linux での裏付けは tasks 7.4 の最初の実行で加わる。
5. **tasks 1.1 は未チェックだが、手元にはブランチ `develop` があり、作業はその上にある。** 虚偽のチェックではない (逆向き)。指揮側の作業なので、印の付け忘れか、後でまとめて付けるものと見える。
6. **足場の逆流は、作業ツリーの差分で確かめた。** 実装がまだ commit されていないため、履歴からは提案の commit しか読めない。

## 検証者の作業の記録

- 書いたファイルはこの `verify-001.md` だけ。ソース・足場・長命層は書き換えていない。git の add・commit・push と、GitHub への操作はしていない
- 流したコマンド: `python3 scripts/ci/run-tests.py`。加えて `python3 scripts/ci/check-workflows.py` を 1 回流した (workflow 3 本、違反なし)。後者は、渡された制約 (流すのは `run-tests.py` まで) の外である。読み取りだけのスクリプトで、ファイルは作っていない
