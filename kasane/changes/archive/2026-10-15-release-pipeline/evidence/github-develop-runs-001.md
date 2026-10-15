# develop からの試しと本番 (tasks 10.3・10.4)

日付: 2026-10-15 / 承認: オーナーがチャットで、版 0.1.0-beta.1 で develop からの試しと本番の確認を指示 / 手順: drafts/release-procedure.md の「初回だけ行うこと」の 7 と「試し」 / 起動した commit: d8ec4c19fb25b513daf21c7552fd78423a264637 (`origin/develop` の先端)

## 起動の前の外の状態

| 確かめたこと | 読んだ値 |
|---|---|
| 本リポジトリの tag `0.1.0-beta.1` | 無い |
| 配信用リポジトリの tag `0.1.0-beta.1` | 無い |
| 配信用リポジトリの ref | 何も無い (空のリポジトリ) |
| 本リポジトリの Release `0.1.0-beta.1` | `release not found` (Release は 0 件) |
| Maven Central の POM (`repo1.maven.org/.../kscollectionview-0.1.0-beta.1.pom`) | 404 |

## 10.3 develop からの試し

```bash
gh workflow run release.yml --repo kamusoft/KsCollectionView --ref develop -f version=0.1.0-beta.1 -f dry-run=true
```

run: https://github.com/kamusoft/KsCollectionView/actions/runs/38721418708 (結論 `success`、10:36:07〜10:41:14Z、約 5 分)

| ジョブ | 結果 | 所要 |
|---|---|---|
| `validate` | success | 10 秒 |
| `verify-ios / verify` | success | 2 分 4 秒 |
| `verify-android / verify` | success | 4 分 55 秒 |
| `package-ios` | success | 8 秒 |
| `package-android` | success | 1 分 45 秒 |
| `consumer-ios / verify` | success | 2 分 17 秒 |
| `consumer-android / verify` | success | 2 分 53 秒 |
| `publish`・`wait-for-registries`・`smoke-ios`・`smoke-android`・`check-release` | skipped | — |

`validate` の出力 (ログの「出力:」の行):

| 出力 | 値 | 読み |
|---|---|---|
| `production` | `false` | 試し |
| `on-main` | `false` | develop からの起動 |
| `main-tag`・`spm-tag` | `absent`・`absent` | 両リポジトリに同じ名前の tag が無い |
| `published` | `false` | Maven Central に未公開 (repo1 の POM が 404) |
| `built` | `false` | `main` 以外なのでノートを組み立てない (`Upload release notes` は skipped) |

- artifact: `spm-snapshot` (380,729 バイト)・`android-maven` (579,663 バイト)。`release-notes` は無い (組み立てていない)
- 利用者役は、工程が作った artifact (`mode: artifact`) でビルドして通った
- 起動の後の外の状態: 起動の前と同じ (tag 無し・配信用リポジトリは空・Release 無し・POM は 404)。外へは何も送っていない

## 10.4 develop からの本番

```bash
gh workflow run release.yml --repo kamusoft/KsCollectionView --ref develop -f version=0.1.0-beta.1
```

run: https://github.com/kamusoft/KsCollectionView/actions/runs/38722143173 (結論 `failure`)

- `validate` の `Check inputs` で失敗した。ログ: `本番 (dry-run でない起動) は main からだけ受け付ける (起動した ref: refs/heads/develop)。 公開しない試しなら dry-run を true にして起動する`
- 後ろのジョブ (検証・組み立て・利用者役・`publish` 以降) は、どれも skipped (走っていない)。`publish` が走らないので、Environment `release` と secret には届いていない
- 起動の後の外の状態: 起動の前と同じ

## この確認で分かったこと・確かめていないこと

- 読み取りだけの権限の token で Pull Request の一覧を読めるか (リリースノートの組み立て): `main` 以外からの起動では読まないので、この確認では分からない。tasks 10.8 (`main` からの試し) で確かめる
- Environment の branch policy が `develop` からのジョブを止めること: `validate` が先に止めるので、この確認では分からない
- package-android と publish の発行物のバイトの一致・前の試行の artifact の読み込み: `publish` が走らないので、初回の本番で確かめる
