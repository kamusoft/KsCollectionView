# deploy key・Environment・secret (tasks 9.2・9.3・9.4)

日付: 2026-10-15 / 手順: drafts/release-procedure.md の「初回だけ行うこと」の 3〜5

## 9.2 書き込み用の deploy key (オーナーが実施)

オーナーが鍵の組を作り、公開鍵を配信用リポジトリに、秘密鍵を secret `SPM_DEPLOY_KEY` に登録した。エージェントは公開鍵の情報だけを読んだ。

```bash
gh api repos/kamusoft/KsCollectionView-SPM/keys --jq '[.[] | {title, read_only, created_at}]'
```

| 項目 | 期待する値 | 読み直した値 |
|---|---|---|
| 鍵の数 | 1 | 1 |
| 題 | `release workflow (kamusoft/KsCollectionView)` | 同じ |
| `read_only` | `false` (書き込みができる) | `false` |
| 登録の時刻 | — | 2026-10-15T10:16:33Z |

- 秘密鍵と公開鍵が組であることは、値を読まないので確かめていない。secret `SPM_DEPLOY_KEY` の更新の時刻 (10:18:14Z) は公開鍵の登録 (10:16:33Z) の後で、同じ時に作った組を登録し直したと見ている。組であることは、最初の本番の写しの push (または、その前の手順の確かめ) で分かる

## 9.3 Environment `release` (承認: オーナーがチャットで tasks 9.3 の実施を指示)

Environment `release` は、オーナーが 9.4 で secret を登録したときに、ブランチの決まりの無い状態 (どのブランチからも使える) で作られていた (2026-10-15 の読み直しで `deployment_branch_policy: null`)。手順のとおりに `main` だけにした。

```bash
gh api -X PUT repos/kamusoft/KsCollectionView/environments/release --input - <<'JSON'
{"deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true}}
JSON
gh api -X POST repos/kamusoft/KsCollectionView/environments/release/deployment-branch-policies \
  -f name=main -f type=branch
```

読み直した値 (20 秒待ってから):

```bash
gh api repos/kamusoft/KsCollectionView/environments/release \
  --jq '{name, deployment_branch_policy, protection_rules: [.protection_rules[].type]}'
gh api repos/kamusoft/KsCollectionView/environments/release/deployment-branch-policies \
  --jq '[.branch_policies[] | {name, type}]'
```

| 項目 | 期待する値 | 読み直した値 |
|---|---|---|
| `deployment_branch_policy` | `protected_branches: false`・`custom_branch_policies: true` | 同じ |
| `protection_rules` | `branch_policy` だけ | `["branch_policy"]` |
| ブランチの決まり | 1 件。`name: main`・`type: branch` | `[{"name":"main","type":"branch"}]` |
| リポジトリの Environment | `release` だけ | `["release"]` |

- spec repository-publication「main 以外の run は環境を使えない」の Scenario は、設定の値で確かめた。実際に `develop` から Environment を指定したジョブが止められることは、tasks 10.4 (`develop` から本番を試す。最初のジョブで止まる) では確かめられない (`validate` が先に止める) ので、確かめていない

## 9.4 secret (オーナーが登録)

名前の一覧だけを読んだ (値は読めないし、読まない)。

```bash
gh secret list --env release --repo kamusoft/KsCollectionView
gh secret list --repo kamusoft/KsCollectionView
```

| secret | Environment `release` | 更新の時刻 |
|---|---|---|
| `SIGNING_KEY` | ある | 2026-10-15T10:02:20Z |
| `SIGNING_KEY_ID` | ある | 2026-10-15T10:02:47Z |
| `SIGNING_PASSWORD` | ある | 2026-10-15T10:03:05Z |
| `MAVEN_CENTRAL_USERNAME` | ある | 2026-10-15T10:03:21Z |
| `MAVEN_CENTRAL_PASSWORD` | ある | 2026-10-15T10:03:35Z |
| `SPM_DEPLOY_KEY` | ある | 2026-10-15T10:18:14Z |

- リポジトリの secret (Environment の外): 0 件 (決まりどおり)
- 値の正しさ (鍵とパスフレーズの組・user token・名前空間 `jp.kamusoft` が検証済みであること) は、ここでは確かめていない。署名と認証は初回の本番の `publish` で分かる (送る前の署名で誤りが分かれば、外へは何も送らない)
