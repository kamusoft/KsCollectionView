# 提案の段階の確認 (public-repo-verify-ci)

提案を書くときに確かめたことの記録。日付はすべて 2026-10-08。

## 外部の仕様を前提にした約束の裏取り

Requirement と Decision が、GitHub・Xcode・外部の道具の振る舞いを前提にしている箇所と、その前提を確かめた場所。

| 前提にした振る舞い | 使っている箇所 | 確かめた場所 | 結果 |
|---|---|---|---|
| Free プランでは、ブランチの保護は public のリポジトリでだけ使える | 公開の当日の順番 (design Decision 8) | GitHub の公式の文書 (プランの比較)。ksn-scout の調査 | 確認 |
| public のリポジトリでは、標準の GitHub ホストのランナーが無料 | design Decision 8 | https://docs.github.com/en/billing/concepts/product-billing/github-actions | 確認 |
| ランナー `xcode-27` は GitHub が提供する標準のラベルで、Xcode 27.0 と iOS 27.0 の Simulator を持つ | CI: 道具の固定と権限 / design Decision 5 | https://docs.github.com/en/actions/reference/runners/github-hosted-runners と、actions/runner-images の `xcode-27-arm64` の Readme。兄弟ライブラリの実行 (ラベル `xcode-27` で GitHub ホスト) | 確認。public preview |
| 変更したパスがすべて除外の指定に当たる push では、workflow が起動しない | CI: 検証 CI の起動条件 | GitHub Actions の公式の文書 (`paths-ignore`)。兄弟ライブラリの `../KsSettingsView/.github/workflows/ci.yml:16-27` と、その決定の現行照合 | 確認 |
| 同じ組の新しい実行が、走っている古い実行を打ち切る | CI: 検証 CI の起動条件 | GitHub Actions の公式の文書 (`concurrency` と `cancel-in-progress`)。兄弟ライブラリの `ci.yml:35-37` | 文書で確認。実地の確認は tasks 8.2 |
| 必須の検査を、出した側のアプリを指定して登録できる | 公開: ブランチの保護 | 兄弟ライブラリの手順 `../KsSettingsView/kasane/handbook/cross/release-procedure.md:35-85` | 確認 (兄弟ライブラリで設定済み) |
| Pull Request を作れる人を、共同作業者に限れる | 公開: Pull Request を作れる人の制限 | https://github.blog/changelog/2026-02-13-new-repository-settings-for-configuring-pull-request-access/ 。兄弟ライブラリの設定の読み出し (`collaborators_only`) | 確認 |
| secret の検査と push の保護を、Free プランの public のリポジトリで有効にできる | 公開: 公開リポジトリの機能の設定 | 兄弟ライブラリの公開の記録 `../KsSettingsView/kasane/roadmaps/archive/2026-09-11-package-distribution/phases/phase-2-public-readiness/artifacts/publish-procedure.md:38` | 確認 (兄弟ライブラリで有効) |
| Issue のフォームで、必須の項目と、空の Issue の禁止を指定できる | 公開: Issue のフォームの必須項目 | 兄弟ライブラリの実物 `../KsSettingsView/.github/ISSUE_TEMPLATE/` | 確認。実地の確認は tasks 7.7 |
| `xcodebuild` の `-only-testing` は、指定したものだけを実行し、ほかを除く | CI: iOS の検証「Sample の UI テストは走らない」 | 手元の Xcode 27.0 の `man xcodebuild` | 文書で確認。本リポジトリの Sample での実測は tasks 4.1 (実装の最初に行う) |
| gitleaks 8.30.1 の Linux 向けの配布物のチェックサム | CI: 道具の固定と権限 | 兄弟ライブラリの `ci.yml:95-96` (同じ版を使用中) | 確認 |
| gitleaks の公式の action は、Organization の下でライセンスの鍵が要る | design Decision 7 | 兄弟ライブラリの `../KsSettingsView/kasane/changes/archive/2026-08-31-add-verification-ci/deviation.md:11-13` | 確認 (兄弟ライブラリで発生) |
| 新しいリポジトリに、ラベル `bug`・`enhancement`・`question` が最初からある | design の「置くファイル」 | 兄弟ライブラリの公開の手順 (ラベルの存在を確かめる項目がある) | 未確認。tasks 7.3 で確かめる |
| Linux のランナー `ubuntu-24.04` に、コンパイル対象の Android SDK がある | CI: Android の検証 | — | 未確認。tasks 4.3 で備える |

未確認の 2 つは、Requirement に「必ずそうなる」とは書いていない。ラベルは「ある」ことを設定の読み直しで確かめる形にし、Android SDK は無い場合の手順を workflow に持たせる。

## 同じ契約を書いているほかの成果物との突き合わせ

| 契約 | 突き合わせた相手 | 結果 |
|---|---|---|
| CI が走らせる範囲 (本体は全件、Sample はビルドとユニットテスト、UI テストは走らせない) | cross/ADR-0013 の Decision | 一致 |
| 検証 CI が走る時点 (`develop` への push・`main` 宛ての Pull Request) | cross/ADR-0010 の Decision | 一致 |
| `main` には `develop` からの Pull Request だけが入る | cross/ADR-0010 の Decision | 一致させた。初稿は保護に Pull Request の必須を書いておらず、検査を通った commit を直接 push できる形だった。自己レビューで「Pull Request を必須にする (承認の数は 0)」を足した |
| 外部の Pull Request を受けず、Issue で受ける。フォームは実際に動かした証拠を必須にする | cross/ADR-0011 の Decision | 一致 (版・プラットフォーム・再現手順を必須にしている) |
| MIT License、名義は `kamusoft` | cross/ADR-0012 の Decision | 一致 |
| 履歴を書き換えずに公開し、公開前に画像の目視と gitleaks を行う | cross/ADR-0009 の Decision | 一致 |
| iOS 本体のテストの流し方と件数の読み方 | `kasane/handbook/cross/test-execution.md` の iOS の節 | 一致 (Simulator で `xcodebuild test`、件数は集計の行で読む) |
| Android のテストのタスクと件数の読み方 | 同 Android の節 | 一致 (デバッグのユニットテスト、件数は結果のファイルで読む)。CI は Sample のアプリの組み立てを足している |
| iOS Sample のスキームの使い分け (通常の検証と計測) | 同「Sample のテストと計測ドライバを分けて実行する」 | 一致 (通常の検証のスキームを使い、計測のスキームは使わない) |
| README はルートの 2 枚で、同じ構成 | cross/ADR-0005 の Decision | 一致 (準備中の案内も 2 枚で同じ構成)。貢献の案内は README ではないので 2 枚の制限の外 |
| ルートに共通のビルドのファイルを置かない | cross/ADR-0002 の Decision | 抵触なし (置くのは `LICENSE`・README・`.github/`・`scripts/ci/`) |
| テスト 4 系統の合計を 10 分以内に保つ | cross/ADR-0008 の Decision | 抵触なし。検査のスクリプトのテストは 4 系統に含めず、別に数える (design Decision 3) |

## 既存の仕組みへの影響

| 仕組み | 確かめたこと |
|---|---|
| push の前の検査 (`.githooks/pre-push`・Bash の hook) | 最初の push では、まだどの remote にも無い commit がすべて検査の対象になる。公開前の確認 (tasks 6.2) と同じ検査で、二重に掛かる |
| 解決した依存の版のファイル | `.gitignore` が除外していて追跡していない。CI は実行のたびに依存を解決する (design の Risks) |
| 識別子の検査の範囲 | `kasane`・`skills`・`samples`。`.github/` と `scripts/ci/` は範囲の外。secret は gitleaks が全体を見る |
| iOS Sample の署名の設定 | 開発チームの値は入っていない (署名の方式の指定だけ)。Simulator 向けのビルドに署名は要らない |
| 追跡中の設定のファイル | 端末ごとの設定・鍵・環境の値のファイルは追跡していない |

## merge commit だけが持つ内容の検査 (相方の指摘 1 を受けて実施)

フェーズの議論で行った履歴の検査 (`scripts/git-gate-lint.py --range` と gitleaks) は、どちらも merge commit を数えていなかった。標準の検査は commit の列挙で merge commit を除いており、gitleaks は 73 commit のうち 70 commit を走査していた。そこで、merge commit だけが持つ内容を別に確かめた。

| 確かめたこと | 結果 |
|---|---|
| merge commit の数 | 3 (全 73 commit) |
| どちらの親とも違う内容を持つファイル | 4 件 (`kasane/concepts/log.md` が 3 つの merge commit に 1 件ずつ、`ios/Sources/KsCollectionView/KsCollectionViewController.swift` が 1 件) |
| ローカル絶対パスの検査 (リポジトリの中の一時の場所に取り出して `--paths` で実行) | 違反なし |
| 個人を特定する値の検査 (`kasane/` の下に取り出して実行。対象は範囲に入る `kasane/` の 3 件) | 違反なし |
| 対照 (同じ場所に、わざと違反を置いたファイル) | 2 つの検査とも検出した |
| gitleaks (取り出した 4 件) | 検出なし |
| gitleaks (merge commit を含む全履歴。`--log-opts="--all -m"`) | 73 commit を走査して検出なし |

分かった注意点が 2 つある。ローカル絶対パスの検査は、リポジトリの外に取り出したファイルを受け付けない。個人を特定する値の検査は、場所で範囲を決めるので、範囲の外 (リポジトリのルートの直下の一時の場所) に置いた対照を検出しなかった。どちらも、取り出す場所を `kasane/` の下にすると解決する。公開前の確認の手順 (design の Decision 10) はこの形にしてある。取り出したファイルは検査の後に消した。
