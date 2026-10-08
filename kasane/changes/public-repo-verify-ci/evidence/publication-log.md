# 公開の実施の記録 (public-repo-verify-ci)

tasks のグループ 7・8 の記録。GitHub への操作ごとに、承認・実行したコマンド・読み直しの結果を書く。アカウントの名前などの識別子は書かない。

## 7.1 非公開でリポジトリを作り、main だけを push (2026-10-08)

実行はオーナーが手元の端末で行った。指揮側は、実行の前後の状態を読んで確かめた。

| 順 | 実行した内容 | 結果 |
|---|---|---|
| 1 | `gh repo create kamusoft/KsCollectionView --private` | リポジトリができた。公開の範囲は private、中身は空 |
| 2 | remote `origin` の設定 | 作成のコマンドが HTTPS の形で足した。オーナーの希望で SSH の形 (GitHub の SSH の URL。ホストは `github.com`、パスは `kamusoft/KsCollectionView.git`) に変えた (`git remote set-url`) |
| 3 | `git push origin main` | `main` が新しいブランチとして作られた。push したのは `main` だけ |

読み直し:

| 確かめたこと | 読み方 | 結果 |
|---|---|---|
| GitHub の `main` の先端が手元と同じ | `git ls-remote origin` と `git rev-parse main` | どちらも `a76c38054a7c15b1b622953991ff4f1dc3c035d5`。一致 |
| GitHub にあるブランチ | `git ls-remote origin` | `main` だけ (`develop` は無い) |
| 公開の範囲と既定のブランチ | `gh repo view --json visibility,defaultBranchRef` | private、既定のブランチは `main` |
| 検証の実行 | `gh api repos/kamusoft/KsCollectionView/actions/runs` | 0 件 (`main` に workflow が無いため) |

Scenario「公開された履歴が手元と一致する」: 一致を確かめた。

## 7.2 オーナーの目視と、public への切り替え (2026-10-08)

- オーナーに GitHub の画面で中身を見るよう依頼し、見る観点 (ルートのファイルの並び・開発の記録・commit の一覧とメッセージ・過去の証跡) を示した。オーナーから「public にして」の指示を受けて、指揮側が切り替えた
- 実行した内容: `gh repo edit kamusoft/KsCollectionView --visibility public --accept-visibility-change-consequences` (終了コード 0)

読み直し:

| 確かめたこと | 読み方 | 結果 |
|---|---|---|
| 公開の範囲 | `gh repo view --json visibility,isPrivate` | public (`isPrivate` は false) |
| 既定のブランチ | 同上 | `main` |
| リポジトリが無効・アーカイブになっていない | `gh api repos/kamusoft/KsCollectionView` の `disabled`・`archived` | どちらも false |
| `main` の先端 | `git ls-remote origin` | `a76c380…` のまま |

切り替えの直後の 1 回だけ、SSH での読み取りが「リポジトリが無効になっている」という応答で失敗した。数秒後にやり直すと 3 回続けて成功し、API の `disabled` も false だった。切り替えの直後の一時的な応答と見ている (原因は確かめていない)。

Scenario「public にする前にオーナーが確かめる」: 目視の依頼の後に、オーナーの指示を受けて切り替えた。

## 7.3 機能の設定・Pull Request を作れる人・secret の検査 (2026-10-08)

入れる前にいまの値を読み、design の Decision 9 の表と違う 4 つだけを変えた。オーナーの承認 (「実行して」) を得て、指揮側が実行した。

| 順 | 実行した内容 | 結果 |
|---|---|---|
| 1 | `gh repo edit kamusoft/KsCollectionView --enable-projects=false` | 終了コード 0 |
| 2 | `gh api -X PATCH repos/kamusoft/KsCollectionView -f pull_request_creation_policy=collaborators_only` | 終了コード 0。応答の値は `collaborators_only` |
| 3 | `gh api -X PATCH repos/kamusoft/KsCollectionView --input -` に `{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}` を渡す | 終了コード 0。応答で 2 つとも `enabled` |

読み直し (`gh api repos/kamusoft/KsCollectionView`、ラベルは `…/labels`、依存の脆弱性の通知は `…/vulnerability-alerts`) と、Decision 9 の表との突き合わせ:

| 設定 | 決めた値 | 入れる前 | 読み直した値 | 一致 |
|---|---|---|---|---|
| 公開の範囲 | public | public | `visibility: public` | ○ |
| 既定のブランチ | `main` | `main` | `default_branch: main` | ○ |
| Issues | 有効 | 有効 | `has_issues: true` | ○ |
| Wiki | 無効 | 無効 | `has_wiki: false` | ○ |
| Discussions | 無効 | 無効 | `has_discussions: false` | ○ |
| Projects | 無効 | 有効 | `has_projects: false` | ○ |
| Pull Request を作れる人 | 共同作業者だけ | 誰でも (`all`) | `pull_request_creation_policy: collaborators_only` | ○ |
| secret の検査 | 有効 | 無効 | `secret_scanning: enabled` | ○ |
| push の保護 | 有効 | 無効 | `secret_scanning_push_protection: enabled` | ○ |
| 依存の脆弱性の通知 | 有効 | 有効 | 応答 204 (有効) | ○ |
| ラベル | `bug`・`enhancement`・`question` がある | ある | 9 つのラベルに 3 つとも含まれる | ○ |

分かったこと (提案の段階で未確認だった点):

- 新しいリポジトリには、ラベル `bug`・`enhancement`・`question` が最初からある (ほかに 6 つ)
- Wiki と Discussions は最初から無効、依存の脆弱性の通知は最初から有効だった (`gh repo create --private` で作って public に切り替えた場合)
- Pull Request を作れる人の設定は、リポジトリの読み直しで `pull_request_creation_policy` として返り、PATCH で入れられる

Scenario「設定が決めたとおりになっている」「設定が共同作業者だけになっている」: 読み直しで確かめた。

## 7.4 develop の push と、検証 CI の最初の実行 (2026-10-08)

オーナーの承認 (「実行して」) を得て、7.1〜7.3 の記録を commit (`e1c3d67`) し、`git push -u origin develop` で push した。push で検証 CI が起動した (実行の ID は 37766512044、対象は `e1c3d67`)。

### 1 回目の実行の結果: 失敗 (3 つのうち iOS だけが失敗)

| 検査 | 結果 | 所要 | 中身 |
|---|---|---|---|
| `lint` | 成功 | 8 秒 | 出どころの確認は push なので対象外と判定。gitleaks はチェックサムが `OK`、約 11.07 MB を走査して検出なし。スクリプトのテストは実行 133 件・失敗 0・スキップ 0。workflow の定義の検査は違反なし |
| `android / verify` | 成功 | 6 分 14 秒 | 本体は実行 512 件・スキップ 0・失敗 0・クラス 31 / 31。Sample は実行 163 件・スキップ 0・失敗 0・クラス 21 / 21 |
| `ios / verify` | 失敗 | 13 分 10 秒 | 本体は 567 件のうち 1 件が失敗 (所要 333 秒)。Sample はユニットの 37 件が全件成功 |

落ちたテスト: iOS 本体の `KsCollectionEngineTests` の「2000 件を全件走査しても同時生存セルを可視範囲と再利用プールに留める」。同時に生きているセルの実測の最大が 2000 件 (上限 168 件、可視 42 件) になり、このテスト 1 件に 150 秒かかった。手元 (同じ機種・OS・Xcode) では通っている。原因は調査中。

### ランナーで初めて分かったこと

| 提案・実装の段階で未確認だった点 | 結果 |
|---|---|
| ランナー `xcode-27` の上の Xcode の置き場 | 決めた版として選べた。workflow の探し方 (`Xcode_27.0*.app`) に当たって選ばれた名前は `Xcode_27.0.0.app` で、ビルドの記録に出る実体の場所は `Xcode_27.app` |
| iOS 27 の iPhone の Simulator | あった (iPhone 17・iOS 27.0 が選ばれた) |
| チームの指定なしでの Sample の Simulator 向けのビルド | ビルドできた |
| Sample の UI テストが走らないこと | 走ったのはユニットの 37 件だけ |
| `ubuntu-24.04` のランナーに、コンパイル対象の Android SDK があるか | あった (Platform 36)。取得の枝は通っていない (この枝は今も未確認) |
| lint が Linux で手元と同じ結果になるか | 同じ (違反なし。スクリプトのテストは修正後の 133 件が Linux で通った) |
| 検査の名前 | `lint`・`ios / verify`・`android / verify` で報告された |
| 本体のテストが落ちても Sample の検証が走ること | 本体の step が失敗した後に、Sample のビルドとユニットテスト・件数の確認が走り、ジョブは失敗で終わった |

### 2 回目の実行の結果: 成功 (iOS をビルドだけにした後)

オーナーの判断で、検証 CI の iOS を「テストを実行せず、ビルドできることだけを確かめる」形に変えた (`deviation.md` の 2026-10-08 の乖離)。オーナーの承認 (「実行して」) を得て commit (`985f910`) し、`git push origin develop` で push した。実行の ID は 37773352416。

| 検査 | 結果 | 所要 | 中身 |
|---|---|---|---|
| `lint` | 成功 | 8 秒 | gitleaks は検出なし。スクリプトのテストは実行 111 件・失敗 0・スキップ 0 (Linux)。workflow の定義の検査は違反なし |
| `ios / verify` | 成功 | 4 分 8 秒 | 本体と本体のテストのビルド 1 分 56 秒、Sample のアプリとテストのビルド 1 分 53 秒。どちらも `TEST BUILD SUCCEEDED`。テストは実行していない |
| `android / verify` | 成功 | 3 分 59 秒 | 本体は実行 512 件・スキップ 0・失敗 0・クラス 31 / 31。Sample は実行 163 件・スキップ 0・失敗 0・クラス 21 / 21 |

検査の名前と出した側 (`gh api repos/kamusoft/KsCollectionView/commits/985f910/check-runs`): `lint`・`ios / verify`・`android / verify` の 3 つで、どれも GitHub Actions (アプリの ID は 15368) が出している。

Scenario「develop への push で起動する」「検査が決めた名前で報告される」: 確かめた。Scenario「全件が通れば成功する」(Android): 確かめた。iOS は deviation のとおり、ビルドの成功を確かめた。

所要時間の記録 (tasks 8.3 の材料):

| ジョブ | 1 回目 (`e1c3d67`) | 2 回目 (`985f910`) |
|---|---|---|
| `lint` | 8 秒 | 8 秒 |
| `android / verify` | 6 分 14 秒 | 3 分 59 秒 |
| `ios / verify` | 13 分 10 秒 (テストを実行していた形) | 4 分 8 秒 (ビルドだけ) |

## 7.5 main と develop の保護 (2026-10-08)

入れる値を表にしてオーナーに示し (design の表に無い値を含む)、承認 (「実行して」) を得て、指揮側が実行した。

| 順 | 実行した内容 | 結果 |
|---|---|---|
| 1 | `gh api -X PUT repos/kamusoft/KsCollectionView/branches/main/protection --input -` に、下の表の値の JSON を渡す | 終了コード 0 |
| 2 | `gh api -X PUT repos/kamusoft/KsCollectionView/branches/develop/protection --input -` に、下の表の値の JSON を渡す | 終了コード 0 |

`main` の読み直し (`gh api repos/kamusoft/KsCollectionView/branches/main/protection`) と、design の Decision 9 の表との突き合わせ:

| 項目 | 決めた値 | 渡した値 | 読み直した値 | 一致 |
|---|---|---|---|---|
| Pull Request を必須にする | する | `required_pull_request_reviews` を置く | 置かれている | ○ |
| 承認の必須の数 | 0 | `required_approving_review_count: 0` | 0 | ○ |
| 必須の検査 | `lint`・`ios / verify`・`android / verify`。GitHub Actions が出したものに限る | 3 件、どれも `app_id: 15368` | 3 件、名前と `app_id` (15368) が同じ | ○ |
| 強制 push | 禁じる | `allow_force_pushes: false` | false | ○ |
| 削除 | 禁じる | `allow_deletions: false` | false | ○ |
| 管理者に強制する | しない | `enforce_admins: false` | false | ○ |
| `main` の最新を取り込んでいないとマージできない | (表に無い) | `strict: false` | false | — |
| 古い承認の取り消し・コードオーナーの承認 | (表に無い) | どちらも false | どちらも false | — |
| push できる人の限定 | (表に無い) | `restrictions: null` | 無い | — |

`develop` の読み直し (`gh api repos/kamusoft/KsCollectionView/branches/develop/protection`):

| 項目 | 決めた値 | 渡した値 | 読み直した値 | 一致 |
|---|---|---|---|---|
| 強制 push | 禁じる | `allow_force_pushes: false` | false | ○ |
| 削除 | 禁じる | `allow_deletions: false` | false | ○ |
| 必須の検査 | 持たない | `required_status_checks: null` | 無い | ○ |
| Pull Request の必須 | (直接の push を受ける) | `required_pull_request_reviews: null` | 無い | ○ |
| 管理者に強制する | しない | `enforce_admins: false` | false | ○ |

表に無い値は、兄弟ライブラリと同じにした。`strict` を false にしたのは、true にすると、`main` にしか無い merge commit を `develop` に取り込むまで次の Pull Request をマージできなくなるため (オーナーに示して承認を得た)。

Scenario「main の保護に必須の検査が入っている」「develop は強制 push と削除だけを禁じる」: 読み直しで確かめた。
