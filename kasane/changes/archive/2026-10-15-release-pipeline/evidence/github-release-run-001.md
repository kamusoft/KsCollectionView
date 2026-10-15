# 初回の本番 (tasks 10.9) — 試行 1

日付: 2026-10-15 / 承認: オーナーがチャットで、main から版 0.1.0-beta.1 の本番の起動を指示 / 起動した commit: df659f24e39f3129816bd9d9673b1bfb364d4da5 (`origin/main` の先端。起動の直前に確かめた)

```bash
gh workflow run release.yml --repo kamusoft/KsCollectionView --ref main -f version=0.1.0-beta.1
```

run: https://github.com/kamusoft/KsCollectionView/actions/runs/38726124250 (結論 `failure`、11:16:13〜11:23:21Z)

## ジョブ

| ジョブ | 結果 | 所要 |
|---|---|---|
| `validate` | success | 9 秒 |
| `verify-ios / verify` | success | 1 分 59 秒 |
| `verify-android / verify` | success | 5 分 5 秒 |
| `package-ios` | success | 7 秒 |
| `package-android` | success | 1 分 36 秒 |
| `consumer-ios / verify` | success | 1 分 30 秒 |
| `consumer-android / verify` | success | 2 分 20 秒 |
| `publish` | failure (`Build signed publication`) | 1 分 46 秒 |
| `wait-for-registries`・`smoke-ios`・`smoke-android`・`check-release` | skipped | — |

## publish の step

| step | 結果 |
|---|---|
| Download release notes / reference publication / SPM snapshot / deployment receipts | success |
| Check published deployment (Publisher API の `published`) | success (未公開。Central Portal の認証が通った) |
| Check published commit | skipped (未公開のため) |
| Inspect previous deployment | success (控え無し → 新しく送る) |
| Push SPM snapshot | success |
| **Build signed publication** | **failure** |
| Check signed publication 以降 (Upload to Maven Central・Wait for validation・Publish deployment・Wait for publication・tag・Release) | skipped |
| Drop pending deployment | skipped (送信の step が走っていないので、取り下げる送信が無い) |

失敗の理由 (Gradle の出力):

```
Execution failed for task ':kscollectionview:signMavenPublication' (registered in build file 'kscollectionview/build.gradle.kts').
> Error while evaluating property 'signatory.keyId' of task ':kscollectionview:signMavenPublication'.
   > Could not read PGP secret key
```

- 署名のタスクが、`SIGNING_KEY` から渡した秘密鍵を読み込めなかった。手元の通し (evidence/publish-rehearsal-001.md) でのパスフレーズの誤り (`PGPException`) とは別の形で、鍵の中身を読む段で止まっている
- 鍵とパスフレーズの値は読んでいない (secret は Environment の中だけにある)

## 外の状態 (試行 1 の後)

| 確かめたこと | 読んだ値 |
|---|---|
| 配信用リポジトリの `main` | 667175c1f33e5111c37be48ed22d70983227aeef (`KsCollectionView 0.1.0-beta.1 (df659f24e39f3129816bd9d9673b1bfb364d4da5)`)。既定のブランチは `main` |
| 配信用リポジトリの tag | 無い |
| 本リポジトリの tag `0.1.0-beta.1` | 無い |
| Release `0.1.0-beta.1` | 無い |
| Maven Central の POM | 404。送信の step が走っていないので、Central Portal に送信は無い |

## この試行で実物で確かめられたこと

- 公開のジョブは Environment `release` の secret を受け取った (`main` からの起動)
- Central Portal の認証の情報で Publisher API を呼べた (`Check published deployment` が success)
- deploy key の公開鍵と秘密鍵が組で、書き込みができる。`ssh-add -` が標準入力から鍵を受けた (`Identity added: (stdin)`)
- 空の配信用リポジトリの clone (`You appear to have cloned an empty repository.` の警告) と、最初の push で既定のブランチが `main` になること
- 確かめた写しを置き、tree の照合 (c61b8ced1c84461a1eeeae060a38501e964ff3ad) を通って push できた

## やり直しの形 (手順の草稿のとおり)

`SIGNING_KEY` の原因を取り除いた後、この run の失敗したジョブを再実行する (`gh run rerun 38726124250 --repo kamusoft/KsCollectionView --failed`)。起動した commit df659f2 のまま `publish` からやり直し、写しの push は差分が無ければ commit を作らずに進む。

## 原因 (オーナーが確かめた)

`SIGNING_KEY` に、`gpg --armor --export` で書き出した公開鍵 (`BEGIN PGP PUBLIC KEY BLOCK`) が登録されていた。署名には秘密鍵 (`gpg --armor --export-secret-keys`) が要る。オーナーが秘密鍵で登録し直してから、この run の失敗したジョブを再実行する。手順の草稿に、秘密鍵を入れることと登録の前に 1 行目を確かめることを足した。

# 試行 2 (失敗したジョブの再実行) — 成功

日付: 2026-10-15 / 承認: オーナーがチャットで、`SIGNING_KEY` を秘密鍵 (1 行目が `BEGIN PGP PRIVATE KEY BLOCK`) で登録し直したことを伝え、失敗したジョブの再実行を指示 / `SIGNING_KEY` の更新の時刻: 2026-10-15T11:31:45Z

```bash
gh run rerun 38726124250 --repo kamusoft/KsCollectionView --failed
```

run: https://github.com/kamusoft/KsCollectionView/actions/runs/38726124250 (試行 2、結論 `success`)。起動した commit は試行 1 と同じ df659f24e39f3129816bd9d9673b1bfb364d4da5。試行 1 で成功したジョブ (validate・検証・組み立て・利用者役) は再実行されず、`publish` から後ろが走った。

## ジョブ (試行 2)

| ジョブ | 結果 | 時刻 (UTC) | 所要 |
|---|---|---|---|
| `publish` | success | 11:34:26〜11:43:32 | 9 分 6 秒 |
| `wait-for-registries` | success | 11:43:35〜11:43:41 | 6 秒 |
| `smoke-ios / verify` (公開物を取る iOS の利用者役) | success | 11:43:48〜11:45:14 | 1 分 26 秒 |
| `smoke-android / verify` (公開物を取る Android の利用者役) | success | 11:43:44〜11:45:48 | 2 分 4 秒 |
| `check-release` | success | 11:43:44〜11:43:49 | 5 秒 |

## publish の step の順 (試行 2)

| # | step | 結果 | 時刻 (UTC) | ログの要点 |
|---|---|---|---|---|
| 9 | Check published deployment | success | 11:34:33 | `published=false` |
| 10 | Check published commit | skipped | | 未公開のため |
| 11 | Inspect previous deployment | success | 11:34:34 | `action=upload` (前の試行の控えは無い。試行 1 は送信の前に止まった) |
| 12 | Push SPM snapshot | success | 11:34:34〜35 | 「写しに差分が無いので、commit を作らない」(試行 1 の push の 667175c のまま) |
| 13 | Build signed publication | success | 11:34:35〜11:36:11 | |
| 14 | Check signed publication | success | 11:36:11 | 組み立ての段 (package-android、別のランナー) と署名したほうが、どちらも 5 ファイルで一致 |
| 15 | Upload to Maven Central | success | 11:36:11〜20 | `Uploaded bundle to Central Portal as USER_MANAGED, deployment id: <送信の ID (run のログにある)>`・`Skipping deployment validation!` |
| 16 | Extract deployment id | success | 11:36:20 | 控え `deployment-2.json` |
| 17 | Upload deployment receipt | success | 11:36:20〜21 | |
| 18 | Wait for validation | success | 11:36:21〜51 | VALIDATING → VALIDATED (約 30 秒) |
| 19 | Publish deployment | success | 11:36:51〜52 | 公開を指示 → `PUBLISHING` |
| 20 | Wait for publication | success | 11:36:52〜11:43:25 | PUBLISHING → PUBLISHED (約 6 分 33 秒) |
| 21 | Check tags before tagging | success | 11:43:25〜26 | 両リポジトリとも tag `0.1.0-beta.1` は無い |
| 22 | Tag SPM repository | success | 11:43:26〜27 | |
| 23 | Tag main repository | success | 11:43:27〜28 | |
| 24 | Create release | success | 11:43:28〜30 | https://github.com/kamusoft/KsCollectionView/releases/tag/0.1.0-beta.1 |
| 25 | Drop pending deployment | skipped | | 失敗していない |

公開の step は、取り消せる順 (写しの push → 署名 → 保留の送信 → 決着の待ち → 公開 → 公開済みの待ち → 配信用リポジトリの tag → 本リポジトリの tag → Release) に走った。

## 公開の後に読んだ実物 (2026-10-15、run の完了の後)

| 確かめたこと | 期待する値 | 読んだ値 |
|---|---|---|
| 本リポジトリの tag `0.1.0-beta.1` | 起動した commit を指す | `df659f24e39f3129816bd9d9673b1bfb364d4da5` (軽量の tag、`object.type: commit`) |
| 配信用リポジトリの tag `0.1.0-beta.1` | その commit から作った写しの commit を指す | `667175c1f33e5111c37be48ed22d70983227aeef` (`KsCollectionView 0.1.0-beta.1 (df659f2…)`、`main` と同じ) |
| 配信用リポジトリの中身 | 写しの 5 点 | `LICENSE`・`Package.swift`・`README.md`・`Sources`・`Tests`。README は配信用のひな形 (distribution mirror と本リポジトリへの案内) |
| 配信用リポジトリの Release | 無い | 0 件 |
| Release `0.1.0-beta.1` | tag・題が版の文字列、本文はノート、draft でもプレリリースでもない | `tagName: 0.1.0-beta.1`・`name: 0.1.0-beta.1`・`isDraft: false`・`isPrerelease: false`・`publishedAt: 2026-10-15T11:43:29Z`。本文は `### Features` と確定した 1 行 (#4) |
| 最新の Release | 今回の版 | API `releases/latest` は `0.1.0-beta.1`。`https://github.com/kamusoft/KsCollectionView/releases/latest` は `/releases/tag/0.1.0-beta.1` へ転送 |
| Maven Central の取得先 (`repo1.maven.org/maven2/jp/kamusoft/kscollectionview/0.1.0-beta.1/`) | 発行物と署名がある | `.pom`・`.aar`・`.module`・`-sources.jar`・`-javadoc.jar`・`.aar.asc`・`.pom.asc` がどれも 200 |
| 公開済みの POM の `scm` の `tag` | 起動した commit | `df659f24e39f3129816bd9d9673b1bfb364d4da5` |
| `maven-metadata.xml` | 今回の版 | `latest`・`release`・`versions` とも `0.1.0-beta.1` |
| wait-for-registries のログ | | `版 0.1.0-beta.1 が Maven Central の取得先に現れ、POM の元になった commit は df659f2…` |
| check-release のログ | | `最新の Release は 0.1.0-beta.1 を指す` |

## この試行で実物で確かめられたこと (草稿の「確かめていないこと」から)

- 別のランナーで組み立てた発行物 (package-android) と、公開のジョブで署名して組み立て直した発行物が、ファイルの一覧とバイトで一致した
- 送る束は、確かめた署名つきの発行物と同じ作業ツリーで up-to-date のまま送られた (`30 actionable tasks: 4 executed, 26 up-to-date`)
- プラグインは保留で送ると決着を待たずに終わり (`Skipping deployment validation!`)、ログの 1 行から送信の ID が読めた
- 検証の決着は約 30 秒、公開の指示から PUBLISHED までは約 6 分 33 秒、取得先に版が現れるまでは PUBLISHED の後すぐ (wait-for-registries は 6 秒)。上限 (60 分・120 分・120 分) には遠い
- 失敗したジョブの再実行で、写しの push は差分が無ければ commit を作らずに進んだ
- tag を付けた写しを、SwiftPM が解決できた (smoke-ios)。公開物を Maven Central から取れた (smoke-android)
- プレリリースの印の無い Release が、最新として選ばれた

tasks 10.9 は完了。
