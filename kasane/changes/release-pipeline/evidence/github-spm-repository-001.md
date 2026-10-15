# 配信用リポジトリの作成 (tasks 9.1)

日付: 2026-10-15 / 承認: オーナーがチャットで tasks 9.1 の実施を指示 / 手順: drafts/release-procedure.md の「初回だけ行うこと」の 2

## 実行したコマンド

```bash
gh repo create kamusoft/KsCollectionView-SPM --public --disable-issues --disable-wiki \
  --description "Swift Package Manager distribution of KsCollectionView (source and issues: kamusoft/KsCollectionView)" \
  --homepage https://github.com/kamusoft/KsCollectionView
gh repo edit kamusoft/KsCollectionView-SPM --enable-projects=false --enable-discussions=false
gh api -X PATCH repos/kamusoft/KsCollectionView-SPM -f pull_request_creation_policy=collaborators_only
```

作成の時刻: 2026-10-15T09:35:13Z。README などのファイルは置いていない (最初の写しは本番の run が push する)。

## 読み直した設定

```bash
gh api repos/kamusoft/KsCollectionView-SPM \
  --jq '{visibility, has_issues, has_wiki, has_projects, has_discussions, pull_request_creation_policy, size}'
git ls-remote https://github.com/kamusoft/KsCollectionView-SPM.git
```

| 項目 | 期待する値 | 読み直した値 |
|---|---|---|
| `visibility` | `public` | `public` |
| `has_issues` | `false` | `false` |
| `has_wiki` | `false` | `false` |
| `has_projects` | `false` | `false` |
| `has_discussions` | `false` | `false` |
| `pull_request_creation_policy` | `collaborators_only` | `collaborators_only` |
| `size` | 0 (空) | 0 |
| `git ls-remote` | 何も出ずに終了コード 0 | 何も出ずに終了コード 0 |
| Release の数 (`repos/.../releases`) | 0 | 0 |
| 共同作業者 | 管理者だけ | オーナーのアカウント 1 つ (admin) |
| `default_branch` | (最初の本番の push で `main` に決まる) | API は `main` と返す (中身はまだ無い) |

- 変更の直後の読み直しでは、`has_projects` が `true`、`pull_request_creation_policy` が `all` と返った。20 秒待って読み直すと、上の表の値になった (反映の遅れ)。手順の文書の確かめ方には「変更の直後に食い違ったら、少し待って読み直す」を足すとよい
- spec repository-publication「配信用リポジトリ」の Scenario のうち、Issue を作れないこと・共同作業者でない人が Pull Request を作れないことは、設定の値で確かめた。共同作業者でないアカウントでの実地の確認はしていない。README の案内の Scenario は、最初の本番の push の後に確かめる
- 書き込み用の deploy key (tasks 9.2) はまだ無い
