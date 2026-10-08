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
