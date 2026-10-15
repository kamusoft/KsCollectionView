---
kind: guide
applies-when:
  always: false
  paths: [".agents/skills/release/**", ".github/workflows/release.yml", "scripts/release/**"]
  tasks: [リリースの実施, リリースの試し (dry-run), 失敗したリリースの再実行, 配信用リポジトリ・Environment・secret の設定, 残った保留の送信の取り下げ]
title: リリースの手順
description: リリースの workflow で iOS (配信用リポジトリ) と Android (Maven Central) に同じ版を公開する手順。初回だけ行う設定、毎回の手順 (事前の確認・変更の節・リリースの Pull Request・起動・見守り・公開の後の確認)、試し、失敗したときのやり直し、残った保留の送信の取り下げ
timestamp: 2026-10-15
---

<!--
草稿 (変更 release-pipeline の tasks 7.1)。蒸留で kasane/handbook/cross/release-procedure.md に置く。
リンクは、その置き場からの相対で書いてある (drafts/ の中からは辿れない)。
初回のリリース (tasks 9・10) は、この草稿の「初回だけ行うこと」に従って行う。蒸留の前に、初回で分かったことを書き足す。
-->

# リリースの手順

この文書は、版を入力してリリースの workflow (`.github/workflows/release.yml`) を起動し、iOS と Android の配布物を同じ版で公開して、tag と Release を作るまでの手順をまとめる。文中の「オーナー」は、リポジトリの持ち主である開発者を指す。コマンドの `<版>` は `0.1.0` や `0.1.0-beta.1` の形の値に、`<run の ID>`・`<番号>` はその都度の値に読み替える。

扱うリポジトリは 2 つある。本リポジトリ `kamusoft/KsCollectionView` と、SwiftPM の配信用リポジトリ `kamusoft/KsCollectionView-SPM` である ([cross/ADR-0015](../../decisions/cross/0015-swiftpm-via-distribution-repository.md))。版と tag の付け方は [cross/ADR-0021](../../decisions/cross/0021-single-version-and-plain-tag-across-repositories.md)、起動のしかたと公開の順序は [cross/ADR-0022](../../decisions/cross/0022-manual-release-dispatch-reversible-steps-first.md)、リリースノートの材料は [cross/ADR-0023](../../decisions/cross/0023-release-notes-from-main-pull-request-bodies.md)、Release の置き場所と印は [cross/ADR-0024](../../decisions/cross/0024-release-in-main-repository-marked-latest.md) にある。

## この文書の使い方

この文書がリリースの手順の正である。リリースの Skill `release` (`.agents/skills/release/`) は、起動のたびにこの文書を先頭から読み、書かれた順とコマンドのとおりに進める。Skill は段の順序もコマンドも持たないので、手順を変えるときはこの文書だけを直す。

| 場面 | 読む節 |
|---|---|
| 初めてリリースする (配信用リポジトリ・Environment・secret がまだ無い) | 「初回だけ行うこと」を上から順に。済んだ段は飛ばす |
| リリースする | 「リリースのたびに行うこと」の 1〜6 を順に |
| 試しをする (外へ何も送らずに、公開の前の確認までを通す) | 「試し」 |
| 実行が止まった・失敗した実行の続きをする | 「失敗したとき」 |
| 打ち切られた run などで、Central Portal に保留の送信が残った | 「残った保留の送信を取り下げる」 |
| secret が漏れた疑いがある | [ブランチの運用と GitHub の設定](branch-and-github-settings.md) の「secret を検出したとき」 |

判断はオーナーが行う: 出す版の番号・変更の節の文面・失敗したときに再実行するか・どの形で再実行するか・中止するか。オーナーへの確認は、版と変更の節の文面を 1 回のメッセージでまとめて行う。確定した後は、リリースの Pull Request の作成とマージ・起動・公開の後の確認まで、段ごとに確認せずに進める。止まるのは、失敗したときと、この文書に書かれていない状況に当たったときである。

GitHub と Maven Central への操作は外向きで、多くは取り消せない。確定の前に、公開を伴う操作 (リリースの Pull Request のマージ・本番の起動・tag の作成) をしない。secret の値は、オーナーが登録する。エージェントは値を扱わない。

## この文書の言葉

| 言葉 | 意味 |
|---|---|
| 本番 | 入力 `dry-run` を偽にした起動。`main` からだけ受け付け、公開まで進む |
| 試し | 入力 `dry-run` を真にした起動。どのブランチからでもよく、公開の前の確認で終わる。外へ何も送らず、secret を使わない |
| 対象の commit | 事前の確認を終えた時点の `origin/develop` の先端。リリースの Pull Request で `main` に入れ、公開する |
| 変更の節 | `main` 宛ての Pull Request の本文の `## Changes` の節。リリースノートの材料になる。書き方は `.github/pull_request_template.md` の注釈にある |
| リリースの Pull Request | 対象の commit を `develop` から `main` へ入れる Pull Request |
| 送信 | Maven Central (Central Portal) への発行物の送信 (deployment)。保留 (`USER_MANAGED`) で送り、公開を指示するまでは取り下げられる |
| 送信の控え | 送信の ID を書いたファイル。run の artifact `central-portal-receipt-<試行の番号>` に置き、同じ run の次の試行が読む |
| 試行 | 同じ run の実行の回。「失敗したジョブの再実行」をするたびに増える (`GITHUB_RUN_ATTEMPT`) |

## workflow の形

リリースの workflow は、手動の起動 (`workflow_dispatch`) でだけ走る。入力は `version` (必須) と `dry-run` (真偽。既定は偽) の 2 つである。同時に 1 本だけ流れ、走っている間に起動したものは待つ (走っているものは打ち切られない。待っているものがあるときにさらに起動すると、待っていた方が取り消される)。

| ジョブ | すること | 試しで走るか |
|---|---|---|
| `validate` | 版の形・起動したブランチ・両リポジトリの tag・Maven Central の公開済みの版を確かめ、`main` からの起動ならリリースノートを組み立てる | 走る |
| `verify-ios`・`verify-android` | 検証 CI と同じ検証 | 走る |
| `package-ios`・`package-android` | SwiftPM の写しと、入力の版の Android の発行物 (署名しない) を作って artifact に置く | 走る |
| `consumer-ios`・`consumer-android` | 組み立てた配布物そのものを、利用者役でビルドする | 走る |
| `publish` | 公開する。Environment `release` を指定し、secret を持つのはこのジョブだけ | 飛ばす |
| `wait-for-registries` | Maven Central の取得先に版が現れるまで待つ (上限 120 分) | 飛ばす |
| `smoke-ios`・`smoke-android`・`check-release` | 公開物を取得する利用者役と、最新の Release の確認 | 飛ばす |

`publish` の step は、取り消せる操作から順に並ぶ: 利用者役 (`consumer-ios`) で確かめた写しの push (`Push SPM snapshot`) → 署名して組み立て直す → 保留の送信 (`Upload to Maven Central`) → 検証の決着の待ち (`Wait for validation`、上限 60 分) → 公開の指示 (`Publish deployment`) → 公開済みの待ち (`Wait for publication`、上限 120 分) → 配信用リポジトリの tag → 本リポジトリの tag → Release。`Publish deployment` より後は取り消せない。

secret は 6 つで、Environment `release` にだけ置く。

| secret | 中身 | 使う step |
|---|---|---|
| `SIGNING_KEY` | 署名に使う GPG の秘密鍵 (ASCII armor の形で書き出したもの) | 署名して組み立て直す・保留の送信 |
| `SIGNING_KEY_ID` | その鍵の ID | 同上 |
| `SIGNING_PASSWORD` | その鍵のパスフレーズ | 同上 |
| `MAVEN_CENTRAL_USERNAME` | Central Portal の user token のユーザー名 | 保留の送信・Central Portal の API の呼び出し |
| `MAVEN_CENTRAL_PASSWORD` | Central Portal の user token のパスワード | 同上 |
| `SPM_DEPLOY_KEY` | 配信用リポジトリの書き込み用の deploy key の秘密鍵 | 写しの push・配信用リポジトリの tag |

## 初回だけ行うこと

初めてのリリースまでに、次の 1〜10 を順に行う。済んだ段は飛ばす。GitHub への操作は、1 つずつオーナーの承認を得てから行い、実行したコマンドと読み直した結果を証跡に残す。

2026-10-15 の時点で、この節の段はどれも実物で行っていない。初回で分かったことは、この節と「確かめていないこと」に書き足す。

### 1. 前もってオーナーが決めること

| 決めること | 内容 |
|---|---|
| 署名の鍵 | 兄弟ライブラリと共通の鍵を使うか、本ライブラリ用に作るか。公開鍵が鍵サーバーに上がっていること (Maven Central の検証が署名を照らすため) |
| Central Portal の user token | 兄弟ライブラリと共通にするか、本ライブラリ用に作るか |
| 名前空間 `jp.kamusoft` | Central Portal で検証済みであること (ドメイン `kamusoft.jp` の DNS の TXT レコードで検証する)。オーナーが Central Portal の画面で確かめる |

### 2. 配信用リポジトリを作る

配信用リポジトリを、空の public のリポジトリとして作る。README などのファイルは置かない (最初の写しは、本番の run が push する)。

```bash
gh repo create kamusoft/KsCollectionView-SPM --public --disable-issues --disable-wiki \
  --description "Swift Package Manager distribution of KsCollectionView (source and issues: kamusoft/KsCollectionView)" \
  --homepage https://github.com/kamusoft/KsCollectionView
gh repo edit kamusoft/KsCollectionView-SPM --enable-projects=false --enable-discussions=false
gh api -X PATCH repos/kamusoft/KsCollectionView-SPM -f pull_request_creation_policy=collaborators_only
```

確かめ方: 読み直して、次の表の値であることを確かめる。

```bash
gh api repos/kamusoft/KsCollectionView-SPM \
  --jq '{visibility, has_issues, has_wiki, has_projects, has_discussions, pull_request_creation_policy, size}'
git ls-remote https://github.com/kamusoft/KsCollectionView-SPM.git
```

| 項目 | 期待する値 |
|---|---|
| `visibility` | `public` |
| `has_issues`・`has_wiki`・`has_projects`・`has_discussions` | どれも `false` |
| `pull_request_creation_policy` | `collaborators_only` |
| `git ls-remote` | 何も出ずに、終了コード 0 で終わる (空のリポジトリ) |

配信用リポジトリには Release を作らない ([cross/ADR-0024](../../decisions/cross/0024-release-in-main-repository-marked-latest.md))。README は、写しに入る `scripts/distribution/spm-readme.template.md` が、最初の本番で置かれる。既定のブランチは、最初の本番の push (`main`) で決まる (「workflow の作りで知っておくこと」)。

リリースの workflow の `validate` は、配信用リポジトリの tag を読む (`git ls-remote`)。このリポジトリが無いと、試しも `validate` で失敗する。試し (7) より前に、この段を済ませる。

### 3. 書き込み用の deploy key を作る

オーナーが行う。鍵は、リポジトリの外の、作業用のディレクトリに作る。秘密鍵は、5 で secret に登録するまで、このディレクトリに置いておく。パスフレーズは付けない (workflow が標準入力から ssh-agent に載せるため)。

```bash
key_dir=$(mktemp -d)
ssh-keygen -t ed25519 -C "KsCollectionView release workflow" -N "" -f "$key_dir/spm-deploy-key"
gh repo deploy-key add "$key_dir/spm-deploy-key.pub" --repo kamusoft/KsCollectionView-SPM \
  --title "release workflow (kamusoft/KsCollectionView)" --allow-write
```

確かめ方: `gh repo deploy-key list --repo kamusoft/KsCollectionView-SPM` に、付けた題の鍵が書き込みの権限 (`read-write`) で 1 つだけあること。公開鍵の情報だけを読み、秘密鍵は読まない。

### 4. Environment `release` を作る

`main` から起動した run だけが使える Environment を作る。ブランチの決まりは「選んだブランチ」にして `main` だけを足す。`protected_branches` を真にする形は使わない (`develop` も保護されたブランチなので、`develop` から使えてしまう)。承認者 (required reviewers) は付けない (確定した後に止まらずに進む形にするため。起動そのものが手動の関門である)。

```bash
gh api -X PUT repos/kamusoft/KsCollectionView/environments/release --input - <<'JSON'
{"deployment_branch_policy": {"protected_branches": false, "custom_branch_policies": true}}
JSON
gh api -X POST repos/kamusoft/KsCollectionView/environments/release/deployment-branch-policies \
  -f name=main -f type=branch
```

確かめ方:

```bash
gh api repos/kamusoft/KsCollectionView/environments/release \
  --jq '{name, deployment_branch_policy, protection_rules: [.protection_rules[].type]}'
gh api repos/kamusoft/KsCollectionView/environments/release/deployment-branch-policies \
  --jq '[.branch_policies[] | {name, type}]'
```

| 項目 | 期待する値 |
|---|---|
| `deployment_branch_policy` | `protected_branches: false`・`custom_branch_policies: true` |
| `protection_rules` | `branch_policy` だけ (承認者・待ち時間の規則が無い) |
| ブランチの決まり | 1 件。`name: main`・`type: branch` |

### 5. secret を登録する

オーナーが行う。登録した値は、後から読み直せない (名前の一覧しか読めない)。値の形を確かめられるのは登録の前だけなので、次を守る。

- 何行もある値 (`SIGNING_KEY`・`SPM_DEPLOY_KEY`) は、ファイルか標準入力から流す。`gh secret set` の問いに貼り付けない (1 行の入力の問いに何行も貼ると、値が正しく入らず、残りの行がシェルに入るおそれがある。確かめてはいない)
- 1 行の値 (`SIGNING_KEY_ID`・`SIGNING_PASSWORD`・`MAVEN_CENTRAL_USERNAME`・`MAVEN_CENTRAL_PASSWORD`) は、問いに貼り付けてよい (画面に出ない)
- `--body` で値をコマンドに書かない (シェルの履歴に残る)
- `SIGNING_KEY` に入れるのは秘密鍵である。流すものそのものの 1 行目を見て、次の表で見分ける (1 行目は、表の文字列の前後に `-----` が付いた形。この文書では、secret の検査が鍵と見なさないよう、前後の `-----` を外して書く)。初回の本番の試行 1 (2026-10-15) は、公開鍵を登録していて、署名の段 (`Build signed publication`) が `Could not read PGP secret key` で止まった

| 書き出しのコマンド | 中身 | 1 行目 | `SIGNING_KEY` に |
|---|---|---|---|
| `gpg --armor --export-secret-keys <鍵の ID>` | 秘密鍵 | `BEGIN PGP PRIVATE KEY BLOCK` | 入れる |
| `gpg --armor --export <鍵の ID>` | 公開鍵 (鍵サーバーに上げる方) | `BEGIN PGP PUBLIC KEY BLOCK` | 入れない (登録をやめる) |

`SIGNING_KEY` は、一時のファイルに書き出し、そのファイルの 1 行目を確かめてから、同じファイルを流す。

```bash
key_file=$(mktemp)
gpg --armor --export-secret-keys <鍵の ID> > "$key_file"
head -1 "$key_file"   # BEGIN PGP PRIVATE KEY BLOCK を含むこと。PUBLIC なら登録しない
gh secret set SIGNING_KEY --env release --repo kamusoft/KsCollectionView < "$key_file"
trash "$key_file"
gh secret set SIGNING_KEY_ID --env release --repo kamusoft/KsCollectionView
gh secret set SIGNING_PASSWORD --env release --repo kamusoft/KsCollectionView
gh secret set MAVEN_CENTRAL_USERNAME --env release --repo kamusoft/KsCollectionView
gh secret set MAVEN_CENTRAL_PASSWORD --env release --repo kamusoft/KsCollectionView
gh secret set SPM_DEPLOY_KEY --env release --repo kamusoft/KsCollectionView < "$key_dir/spm-deploy-key"
trash "$key_dir"
```

鍵の控えのファイル (パスワード管理などから取り出したもの) から登録するときも、そのファイルの `head -1` を確かめてから `< <ファイル>` で流し、登録の後に `trash` で消す。

`SIGNING_KEY_ID` は、`gpg --list-secret-keys --keyid-format short` が示す 8 桁の 16 進の ID を入れる。パスフレーズつきの鍵を ASCII armor の形で、鍵の ID をこの形で渡す署名は、使い捨ての鍵で手元で通した (2026-10-15。`kasane/changes/archive/<archive の日付>-release-pipeline/evidence/publish-rehearsal-001.md`)。パスフレーズを誤ると、`Build signed publication` が署名のタスクで失敗する (送る前に止まる)。

確かめ方: 名前の一覧だけを読む (値は読めないし、読まない)。

```bash
gh secret list --env release --repo kamusoft/KsCollectionView
```

6 つの名前 (`SIGNING_KEY`・`SIGNING_KEY_ID`・`SIGNING_PASSWORD`・`MAVEN_CENTRAL_USERNAME`・`MAVEN_CENTRAL_PASSWORD`・`SPM_DEPLOY_KEY`) が、すべてあること。リポジトリの secret (Environment の外) には置かない。

### 6. workflow を既定のブランチに入れる

手動で起動する workflow は、既定のブランチ (`main`) にそのファイルがあるときだけ起動できる。リリースの workflow を `develop` に入れた後、準備の Pull Request で `main` に入れる。

1. リリースの workflow を含む commit を `develop` に push し、検証 CI が成功することを確かめる (「リリースのたびに行うこと」の 1 のコマンド)
2. 準備の Pull Request の本文を、リポジトリの外のファイルに書く。変更の節は `- none` の 1 行にする (利用者向けの変更が無い)
3. Pull Request を作り、5 つの必須の検査の成功を待ってマージする (「リリースのたびに行うこと」の 3 と同じコマンド。マージの前の、先端と対象の commit の照合も同じ)
4. 手動の起動ができるようになったことを確かめる: `gh workflow view release.yml --repo kamusoft/KsCollectionView` が workflow `Release` を示すこと

準備の Pull Request の本文の例:

```markdown
## Summary

Add the release workflow to the default branch so that it can be started manually.

## Changes

- none
```

### 7. develop から試しと本番を起動して確かめる

`develop` から試しを起動し、公開の前の確認まで通り、外へ何も送らないことを確かめる (「試し」の節のコマンドで `--ref develop`)。確かめること:

| 確かめること | 期待する結果 |
|---|---|
| ジョブの結果 | `validate`・`verify-*`・`package-*`・`consumer-*` が成功、`publish` 以降が飛ばされている (`skipped`) |
| リリースノート | `validate` の `Build release notes` が組み立てを飛ばしている (`main` 以外の起動) |
| 外へ送っていない | 「試し」の節の、送っていないことの確かめ方のとおり |

続けて、`develop` から本番を起動し、最初のジョブで止まることを確かめる。

```bash
gh workflow run release.yml --repo kamusoft/KsCollectionView --ref develop -f version=<版>
```

期待する結果: `validate` の `Check inputs` が、起動したブランチが `main` でないことを理由に失敗し、後ろのジョブはどれも走らない。`gh run view <run の ID> --repo kamusoft/KsCollectionView --log-failed` で理由の行を読む。

### 8. README の「まだ公開していない」の 1 文を外す

ルートの README 2 枚には、まだ公開していないので依存の宣言を解決できない、という 1 文がある (`README.md` と `README_ja.md` の「Installation」「インストール」の節の最初の段落)。リリースの Pull Request を出す前に、`develop` でこの 1 文 (段落ごと) を外す。リリースの workflow は README を書き換えない ([cross/ADR-0018](../../decisions/cross/0018-install-examples-without-concrete-version.md))。

あわせて、配信用リポジトリに置く README のひな形 (`scripts/distribution/spm-readme.template.md`) を、ルートの README と照らす。

| 照らすこと | 見るところ |
|---|---|
| 本リポジトリへの案内 | ひな形のリポジトリの URL・README へのリンク・Issue の URL が、本リポジトリ `kamusoft/KsCollectionView` を指す |
| 受け付けないもの | ひな形の「Issue と Pull Request をここに出さない」が、配信用リポジトリの設定 (2) と合う |
| ライセンス | ひな形の記述が、写しに入る `LICENSE` と、ルートの README のライセンスの記述と食い違わない |

確かめ方: `python3 scripts/ci/check-readme-examples.py .` と `python3 scripts/ci/run-tests.py` が通ること。commit して `develop` に push し、検証 CI が成功すること。

### 9. これまでの Pull Request に変更の節を足す

ひな形ができる前に `main` へ入った Pull Request (#1・#2) には、変更の節が無い。最初のリリースノートの範囲は `main` の最初からなので、このままでは `validate` が止まる。2 本の本文の末尾に、変更の節 (`- none`) を足す。どちらも、リポジトリの準備で、利用者向けの変更は無い。

```bash
work=$(mktemp -d)
for n in 1 2; do
  gh pr view "$n" --repo kamusoft/KsCollectionView --json body --jq .body > "$work/pr-$n.md"
  grep -n '^## Changes' "$work/pr-$n.md"   # 何も出ないこと (節がまだ無い)
  printf '\n## Changes\n\n- none\n' >> "$work/pr-$n.md"
  gh pr edit "$n" --repo kamusoft/KsCollectionView --body-file "$work/pr-$n.md"
done
trash "$work"
```

確かめ方: `gh pr view <番号> --repo kamusoft/KsCollectionView --json body --jq .body` の末尾が、`## Changes` と `- none` の 2 行 (間に空の行) であること。本文の、足した節より前は変わっていないこと。

手元で、`main` の今の先端までのノートを組み立てて、範囲の Pull Request に止まるものが無いかを確かめられる (GitHub の API を読むだけで、何も書き換えない。手元で通したことは、まだ無い)。

```bash
git fetch origin main --tags
python3 scripts/release/build-release-notes.py --version <版> --output "$(mktemp -d)/notes.md" \
  --commit "$(git rev-parse origin/main)" --ref refs/heads/main --repository kamusoft/KsCollectionView
```

### 10. 初回のリリース

「リリースのたびに行うこと」の 1〜3 を行う (事前の確認・変更の節・リリースの Pull Request)。初回の変更の節には、初めての公開であることを利用者の言葉で書く (文面はオーナーが決める。例: `- feature: First public release for iOS (Swift Package Manager) and Android (Maven Central).`)。

マージの後、本番を起動する前に、`main` から試しを 1 回流し、`validate` のリリースノートの組み立てまで通ることを確かめる (「試し」の節。`--ref main`)。組み立てたノートは、run の artifact `release-notes` で読める。

```bash
gh run download <run の ID> --repo kamusoft/KsCollectionView -n release-notes -D "$(mktemp -d)"
```

その後、オーナーの承認を得て、「リリースのたびに行うこと」の 4〜6 で版 `0.1.0-beta.1` を公開する。初回は、公開の後に次を証跡に残す (コマンドは 6 にある)。

- `publish` の step の順と、それぞれの終わった時刻
- 配信用リポジトリと本リポジトリの tag が指す commit
- Release の属性 (tag・題・draft か・プレリリースか・本文) と、最新の Release を指す URL の行き先
- Maven Central の公開と、公開済みの POM に書かれた元の commit
- 配信用リポジトリの既定のブランチが `main` であること
- 各ジョブの所要時間 (待ちの上限が妥当かを見直す材料)

## リリースのたびに行うこと

出す版が決まっていなくてもよい (2 の確認で決める)。次の 1〜6 を順に行う。各段の見出しの下に、その段を終えた状態 (到達状態) を書く。到達していないまま、次の段へ進まない。

### 1. 事前の確認

到達状態: 対象の commit が決まり、その検証 CI が成功していて (run が無いときは、直近の成功で代えられると確かめていて)、利用者向け Skill の追従が要るかが分かっている。

手元の `develop` と `origin/develop` の関係を読む。

```bash
git fetch origin
git rev-list --left-right --count origin/develop...develop
```

出力は「`origin/develop` にだけある commit の数」と「手元にだけある commit の数」の 2 つである。

| 出力 | すること |
|---|---|
| `0 0` | そのまま進む |
| `0 N` (手元が先行) | `git push origin develop` で push し、その先端の検証 CI の完了を待つ |
| `N 0` (手元が遅れている) | 止まる。手元に取り込むかはオーナーが決める |
| `N M` (分かれている) | push せずに止まる |

対象の commit は、この後の `origin/develop` の先端である (`git rev-parse origin/develop`)。その検証 CI の run を読む。

```bash
gh run list --repo kamusoft/KsCollectionView --workflow ci.yml --branch develop \
  --commit "$(git rev-parse origin/develop)" --json databaseId,status,conclusion,url
```

| run の状態 | すること |
|---|---|
| `conclusion` が `success` | 進む |
| 走っている | `gh run watch <run の ID> --repo kamusoft/KsCollectionView --exit-status --interval 60` で完了を待ち、読み直す |
| 失敗している | 止まる。`gh run view <run の ID> --repo kamusoft/KsCollectionView --json jobs --jq '.jobs[] \| [.name, .conclusion] \| @tsv'` で、失敗したジョブを示す |
| run が無い | push した直後は、run が一覧に現れるまで少し遅れる。同じコマンドで 1 分おきに最大 5 分読み直し、現れたら上の行に従う。5 分読み直しても無ければ、直近で成功した run で代えられるかを確かめる (下の段落) |

検証 CI は、`kasane/`・Issue のフォーム・貢献の案内だけを変えた push では起動しない ([検証 CI](verification-ci.md))。対象の commit がそういう push の先端だと、その commit の run は無い。このときは、直近で検証 CI が成功した commit から対象の commit までの変更が、検証 CI を起動しないパスだけなら、その成功で代えて進む。それ以外の変更があれば止まる。

直近で成功した run (`develop` への push で起動したもの) を読み、その commit から対象の commit までの変更を確かめる。

```bash
gh run list --repo kamusoft/KsCollectionView --workflow ci.yml --branch develop --event push --status success \
  --limit 1 --json databaseId,headSha,url
python3 scripts/release/check-ci-skipped-changes.py --base <その run の headSha> --target "$(git rev-parse origin/develop)"
```

`check-ci-skipped-changes.py` は、検証 CI を起動しないパスを、対象の commit の `.github/workflows/ci.yml` の push の `paths-ignore` から読む (値を手で写さない)。比べるのは 2 つの commit の中身の差で、名前の変更は元の名前の削除と新しい名前の追加として数える。`ci.yml` そのものの変更は、起動するパスの変更として数える。

| 結果 | すること |
|---|---|
| 終了コード 0 (`代えてよい`) | その run の成功で代えて進む。確認のメッセージに、代えた run と、出力の「起動しないパス」の一覧を添える |
| 終了コード 1 で、出力に「起動するパス」がある | 止まる。出力の「起動するパス」の一覧をオーナーに示す |
| 終了コード 1 で、「祖先でない」・「手元に無い」・「読めない」 | 止まる。出力のエラーの行をオーナーに示す (この文書に書いていない状況) |

代えて進むのは、起動しないパスのファイルが、iOS・Android のビルドとテストには入力されないからである。そのうち lint が読むもの (開発の記録など) は、リリースの Pull Request の必須の検査 (`lint`) で確かめられる。

利用者向け Skill の追従が要るかを、追従の Skill `docs-refresh` の確かめるだけの使い方 (引数 `check`) で調べる。追従そのものはしない。要ると出たら、確認のメッセージに添える (追従するかはオーナーが決め、追従した commit を入れてから、この段をやり直す)。

### 2. 変更の節の下書きと、オーナーの確認

到達状態: オーナーが、版と変更の節の文面を確定している。

下書きの材料は、リリースの Pull Request が `main` へ新しく持ち込む commit だけである。前回のリリースからのすべての変更ではない (すでに `main` に入った変更は、それを持ち込んだ Pull Request の変更の節が持っている)。

```bash
git fetch origin main develop
git log --no-merges --reverse origin/main..<対象の commit> --pretty=format:'%h %s%n%b%n--'
```

前回の版 (版の候補を決める材料):

```bash
gh release list --repo kamusoft/KsCollectionView --exclude-drafts --limit 1 --json tagName --jq '.[0].tagName'
```

下書きは、`.github/pull_request_template.md` の注釈の書き方に合わせる。

| 決まり | 内容 |
|---|---|
| 行の形 | `- <種類>: <説明>`。種類は `breaking`・`feature`・`fix`・`docs` の 4 つ |
| 変更が無いとき | `- none` の 1 行だけ |
| 言語と言葉 | 説明は英語で、利用者の言葉で書く。ハーネス・CI・テストの整備は載せない |
| 節の中に置けないもの | 見出し・地の文・別の書き方の行 (あると、`validate` が公開の前に止まる) |

手元だけで下書きからノートを組み立てる道具は無い。形は上の表で確かめる。

確認のメッセージは 1 回にまとめる (対象の commit・版 (または候補)・下書き・下書きから外した commit とその理由・事前の確認の結果 (直近の成功で代えたときは、代えた run と変わったパス)・追従が要るか)。確定するまで、下書きを Pull Request の本文に書かない。

版の形は `X.Y.Z` か `X.Y.Z-alpha.N`・`X.Y.Z-beta.N`・`X.Y.Z-rc.N` (N は 1 以上) に限る。`v` を付けない。

### 3. リリースの Pull Request

到達状態: リリースの Pull Request が merge commit でマージされ、`main` の先端の merge commit の 2 つ目の親が、対象の commit になっている。

開いている `develop` から `main` への Pull Request が無いことを確かめる。あれば止まる (この文書に書いていない状況)。

```bash
gh pr list --repo kamusoft/KsCollectionView --base main --head develop --state open --json number,url
```

本文を、リポジトリの外のファイルに書く。`## Summary` と、確定した変更の節を置く。

```markdown
## Summary

Release <版>.

## Changes

<確定した行>

## Notes

<本文の末尾に付ける署名の行など (無ければ、この見出しごと置かない)>
```

変更の節は、次の `## ` で始まる見出しか、本文の終わりまで続く。変更の節の後ろに何かを書くとき (Pull Request を作る道具が本文の末尾に足す署名の行など) は、`## ` で始まる見出し (`## Notes` など) を置いてから書く。`###` などほかの水準の見出しでは変更の節が終わらない。見出しを置かずに足すと、その行が変更の節の読めない行になり、リリースが `validate` で止まる (準備の Pull Request の本文を、リリースノートの組み立ての読み方で読んで確かめた。2026-10-15)。

Pull Request を作り、5 つの必須の検査 (`lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify`) を待つ。

```bash
gh pr create --repo kamusoft/KsCollectionView --base main --head develop --title "Release <版>" --body-file <本文のファイル>
gh pr checks <番号> --repo kamusoft/KsCollectionView --required --watch --interval 60
gh pr checks <番号> --repo kamusoft/KsCollectionView --required --json name,bucket
gh pr view <番号> --repo kamusoft/KsCollectionView --json headRefOid,mergeable,mergeStateStatus,isCrossRepository
```

| 読む項目 | 期待する値 |
|---|---|
| 必須の検査 | 5 つとも `bucket` が `pass` |
| `headRefOid` | 対象の commit。違えば、マージせずに止まる (確定の後に `develop` が進んだ) |
| `mergeable`・`mergeStateStatus` | `MERGEABLE`・`CLEAN` |
| `isCrossRepository` | `false` |

検査が 1 つも走らないときは、競合で起動していないことがある。`mergeable` を見る。外部の依存の取得などで検査が止まったときは、失敗したジョブを再実行して待つ。管理者も保護を迂回しない ([ブランチの運用と GitHub の設定](branch-and-github-settings.md))。

merge commit でマージする。`--match-head-commit` で、先端が対象の commit のときだけマージさせる。

```bash
gh pr merge <番号> --repo kamusoft/KsCollectionView --merge --match-head-commit <対象の commit>
git fetch origin
git rev-parse origin/main^2   # 対象の commit と同じであること
```

`main` を `develop` へ取り込み直さない。

### 4. 起動

到達状態: `main` の先端で本番の run が始まり、その run の ID と URL が分かっている。

`origin/main` の先端が、3 でマージした merge commit であることを確かめてから起動する。

```bash
gh workflow run release.yml --repo kamusoft/KsCollectionView --ref main -f version=<版>
gh run list --repo kamusoft/KsCollectionView --workflow release.yml --event workflow_dispatch --limit 1 \
  --json databaseId,headBranch,headSha,status,createdAt,url
```

一覧の先頭が、`headBranch` が `main`、`headSha` が `origin/main` の先端、`createdAt` が起動の後のものであること。別のリリースの run が走っていると、今回の run は待ちの状態 (`pending`) になる。

### 5. 見守り

到達状態: run のすべてのジョブが成功で終わっている。

```bash
gh run watch <run の ID> --repo kamusoft/KsCollectionView --exit-status --interval 60
gh run view <run の ID> --repo kamusoft/KsCollectionView --json jobs --jq '.jobs[] | [.name, .conclusion] | @tsv'
```

`gh run watch` の終了コードだけで判定せず、ジョブごとの結果を読み直す。止まったら「失敗したとき」へ。

所要時間は、まだ測っていない (初回で測る)。`publish` は、Maven Central の検証の決着と公開の待ちを含み、上限は 345 分である。

### 6. 公開の後の確認

到達状態: 2 つの公開物・Release・最新の Release を指す URL を、実物で確かめている。

`smoke-ios`・`smoke-android`・`check-release` の成功は、公開物を取得してビルドできたことと、最新の Release が今回の版であることを示す。加えて、次を読む。

```bash
# 本リポジトリの tag が、マージした merge commit を指すこと
git ls-remote --tags origin "refs/tags/<版>"
git rev-parse origin/main
# 配信用リポジトリの tag と、既定のブランチ
git ls-remote --tags https://github.com/kamusoft/KsCollectionView-SPM.git "refs/tags/<版>"
gh api repos/kamusoft/KsCollectionView-SPM --jq .default_branch
# Release の属性と、最新の Release
gh release view <版> --repo kamusoft/KsCollectionView --json tagName,name,isDraft,isPrerelease,body,url
gh api repos/kamusoft/KsCollectionView/releases/latest --jq .tag_name
curl -sI https://github.com/kamusoft/KsCollectionView/releases/latest | grep -i '^location:'
# Maven Central の公開済みの POM (scm の tag が、本リポジトリの tag の commit であること)
curl -s https://repo1.maven.org/maven2/jp/kamusoft/kscollectionview/<版>/kscollectionview-<版>.pom | grep -A4 '<scm>'
```

| 確かめること | 期待する結果 |
|---|---|
| 本リポジトリの tag | `origin/main` の先端 (起動した commit) を指す。`main` に、起動の前から増えた commit が無い |
| 配信用リポジトリ | tag がある。既定のブランチは `main` |
| Release | tag と題が `<版>`。`isDraft`・`isPrerelease` は `false`。本文は run のリリースノート |
| 最新の Release | API と URL の行き先 (`/releases/tag/<版>`) の両方が今回の版 |
| Maven Central | POM が取れ、`<scm>` の `<tag>` が起動した commit |

あわせて、オーナーが画面で次を見る: 配信用リポジトリのページ (README が本リポジトリへ案内していること)・Maven Central の `jp.kamusoft:kscollectionview` の今回の版・本リポジトリの Release のページ。

Release の本文は、変更の節から組み立てたものである。手で直さない。文面を直したいときは、次の版の変更の節の書き方を直す。

## 試し

試し (`dry-run` を真) は、`publish` 以降を飛ばし、外へ何も送らない。secret も使わない。起動するブランチは問わない。workflow を変えたときは、試しで `validate` から利用者役までを通しておく。

```bash
gh workflow run release.yml --repo kamusoft/KsCollectionView --ref <ブランチ> -f version=<版> -f dry-run=true
```

`<版>` には、実際に出す予定の値を入れる (`validate` が、その版の tag と公開済みの版を確かめる)。

| 起動したブランチ | リリースノート |
|---|---|
| `main` | 範囲の Pull Request を読んで検査し、組み立てて artifact `release-notes` に置く (Release は作らない)。リリースの Pull Request をマージした後に流すと、変更の節の誤りで本番の `validate` が止まる事態を前もって見つけられる |
| `main` 以外 | 読まず、組み立てない (`Build release notes` が `built=false` で終わる) |

外へ何も送っていないことの確かめ方:

```bash
git ls-remote --tags origin "refs/tags/<版>"                                      # 何も出ない
git ls-remote --tags https://github.com/kamusoft/KsCollectionView-SPM.git "refs/tags/<版>"  # 何も出ない
gh release view <版> --repo kamusoft/KsCollectionView                              # release not found
curl -s -o /dev/null -w '%{http_code}\n' \
  https://repo1.maven.org/maven2/jp/kamusoft/kscollectionview/<版>/kscollectionview-<版>.pom  # 404
```

配信用リポジトリの `main` も、試しの前と同じ commit であること (`git ls-remote https://github.com/kamusoft/KsCollectionView-SPM.git refs/heads/main`)。

## 失敗したとき

止まった位置 (ジョブと step) を読み、下の表の該当する行に従う。

```bash
gh run view <run の ID> --repo kamusoft/KsCollectionView --json jobs \
  --jq '.jobs[] | select(.conclusion == "failure") | {name, steps: [.steps[] | select(.conclusion == "failure") | .name]}'
gh run view <run の ID> --repo kamusoft/KsCollectionView --log-failed
```

再実行するか・どの形で再実行するか・中止するかは、オーナーが決める。リリースの Skill は、自分では再実行しない。

### 再実行の形

| 形 | コマンド | 使う場面 |
|---|---|---|
| 失敗したジョブの再実行 | `gh run rerun <run の ID> --repo kamusoft/KsCollectionView --failed` | 原因を取り除いた後。起動した commit のまま、失敗したジョブとその後ろのジョブだけが走る。送信の控えは試行をまたいで引き継がれる |
| 同じ版での新しい起動 | 「リリースのたびに行うこと」の 4 | `validate` で止まり、起動した commit から直す必要があるとき (新しい commit を `main` に入れた後) |

すべてのジョブの再実行 (`--failed` を付けない) は使わない。済んだ検証と組み立てをやり直すうえ、組み立て直した配布物と前の試行のものとの関係を確かめていない。

`workflow_dispatch` は commit を指して起動できない。公開の後で失敗した run を、`main` が進んだ後に続けるときは、新しく起動せずに、その run の失敗したジョブを再実行する。新しく起動すると、`validate` が、公開済みの POM の元の commit と起動した commit の食い違いで止まる。

### validate で止まったとき

外へは何も送っていない。

| 止まった step | 理由 | すること |
|---|---|---|
| `Check inputs` | 版の形が違う | 正しい版で新しく起動する |
| `Check inputs` | 本番を `main` 以外から起動した | `main` から起動する |
| `Check tags` | 同じ名前の tag が、別の commit (配信用リポジトリでは別の写し) を指す | その版は、この commit からは出せない。次の版で出す。tag が起動した commit を指すなら、止まらずに再実行として続く |
| `Check published version` | Maven Central に、別の commit から作った同じ版がある | その版は、この commit からは出せない。元の commit の run が残っていれば、その run の失敗したジョブを再実行する。無ければ次の版で出す |
| `Build release notes` | 範囲の Pull Request に、変更の節が無い・読めない行がある | ログが Pull Request の番号と行を示す。その本文を `gh pr edit` で直し、失敗したジョブを再実行する (`validate` が本文を読み直す) |
| `Check tags`・`Check published version`・`Build release notes` | GitHub や Maven Central に問い合わせられない | 時間をおいて、失敗したジョブを再実行する |

### 公開の前の確認で止まったとき

`verify-*`・`package-*`・`consumer-*` で止まったときも、外へは何も送っていない。

- 外部の依存の取得の失敗など、コードの誤りでないときは、失敗したジョブを再実行する
- コードや配布物の誤りのときは、`develop` で直し、リリースのたびに行うことの 1 からやり直す (新しいリリースの Pull Request と新しい起動)

### publish で止まったとき

`publish` の step は、同じ版でもう一度走らせても、済んだ工程を飛ばす。原因を取り除いてから、失敗したジョブを再実行する。

| 止まった step | 外の状態 | 再実行で起きること・すること |
|---|---|---|
| (ジョブが始まらない) Environment の保護 | 何も送っていない | `main` 以外から本番が来た。`validate` が止めるので通常は起きない。起きたら止まって調べる |
| `Check published deployment`・`Inspect previous deployment` | 何も送っていない | 認証の誤り (401・403) なら、オーナーが `MAVEN_CENTRAL_*` を確かめる |
| `Check published commit` | 公開済みの版が別の commit から作られている | その版はこの commit からは出せない。次の版で出す |
| `Push SPM snapshot` (確かめた写しが、起動した commit から作った写しと違う・作業コピーの index が確かめた写しと違う) | 何も push していない | 組み立ての段の写しと、公開のジョブで作り直した写しが食い違った。止まって調べる (ログに 2 つの tree の ID が出る)。原因の候補: 写しに、名前が `.` で始まるファイルか、実行の権限が要るファイルが入った (artifact はどちらも保たない) |
| `Push SPM snapshot` (それ以外) | 写しが配信用リポジトリの `main` に入ったかもしれない (tag は無い) | deploy key・ホスト鍵・空のリポジトリへの最初の push を調べる。再実行では、差分が無ければ commit を作らない |
| `Build signed publication`・`Check signed publication` | Maven Central へは送っていない | 署名の鍵の誤り (パスフレーズを誤ると、署名のタスク `signMavenPublication` が `PGPException` で失敗する) か、組み立ての段と中身が違う。中身の食い違いは、止まって調べる (手元の別々の clone では一致したが、別のランナーどうしでのバイトの一致は確かめていない) |
| `Upload to Maven Central`・`Extract deployment id` | 保留の送信があるかもしれない | ID が読めれば、後始末 (`Drop pending deployment`) が取り下げる。読めなければ「残った保留の送信を取り下げる」を行ってから再実行する |
| `Wait for validation` (検証の失敗) | 送信は取り下げ済み | ログの検証の誤りを直す。再実行は新しく送る |
| `Wait for validation` (上限) | 後始末の `Drop pending deployment` が、決着を最大 10 分待ってから取り下げる。その間に決着すれば取り下げ済み、決着しなければ送信が検証中のまま残る (`Drop pending deployment` も失敗する) | `Drop pending deployment` のログを読む。取り下げていれば、再実行は新しく送る。残っていれば、再実行はその送信の決着をもう一度待つ (送り直さない) |
| `Publish deployment`・`Wait for publication` | 公開を指示したかもしれない (取り消せない) | 再実行で、公開の処理中なら送り直さずに公開済みを待ち、公開済みなら tag へ進む |
| `Check tags before tagging` | Maven Central は公開済み | tag が別のものを指している。止まって調べる |
| `Tag SPM repository`・`Tag main repository`・`Create release` | Maven Central は公開済み | 再実行で、ある tag と Release は飛ばし、残りを作る |

公開の指示の前に失敗したときは、後始末の `Drop pending deployment` が保留の送信の取り下げを試みる。公開の指示の後は取り下げない。run が打ち切られると後始末は走らない。そのときは「残った保留の送信を取り下げる」を行う。

### 公開の後の確認で止まったとき

公開したものは取り消せない (Maven Central は消せない)。tag と Release は残したままにする。

| 止まったジョブ | すること |
|---|---|
| `wait-for-registries` (上限) | 取得先への反映が遅れている。失敗したジョブを再実行して待つ |
| `smoke-ios`・`smoke-android` | 外部の依存の取得の失敗なら、再実行する。配布物の誤りなら、直した新しい版を出す |
| `check-release` | 最新の Release が今回の版を指していない。止まって、API と URL の値をオーナーに示す (直し方は決めていない) |

## 残った保留の送信を取り下げる

送信の控えは、同じ run の試行の間でだけ引き継ぐ。次のときは、Central Portal に保留の送信が残り、後の run からは扱えない。

- run が打ち切られ、後始末 (`Drop pending deployment`) が走らなかった
- `Extract deployment id` が、ログから送信の ID を読めなかった

オーナーが、Central Portal にログインして送信の一覧 (`https://central.sonatype.com/publishing/deployments`) を開き、今回の版の送信 (名前は `jp.kamusoft-kscollectionview-<版>`) の状態を見る。

| 状態 | すること |
|---|---|
| `VALIDATED`・`FAILED` | 画面の取り下げ (Drop) で取り下げる。または、下のコマンドで取り下げる |
| `PENDING`・`VALIDATING` | 決着を待ってから取り下げる (下のコマンドは、決着を待ってから取り下げる) |
| `PUBLISHING`・`PUBLISHED` | 取り下げられない。公開済みとして扱い、その run の失敗したジョブを再実行して tag と Release を作る |

送信の ID は、その run の `Upload to Maven Central` のログの `deployment id:` の行か、送信の控えの artifact から読める。

```bash
gh run view <run の ID> --repo kamusoft/KsCollectionView --log | grep 'deployment id:'
gh run download <run の ID> --repo kamusoft/KsCollectionView -p 'central-portal-receipt-*' -D "$(mktemp -d)"
```

コマンドで取り下げるときは、オーナーが user token を、画面に出さずに環境変数へ入れてから流す。

```bash
read -rs KS_CENTRAL_USERNAME && export KS_CENTRAL_USERNAME
read -rs KS_CENTRAL_PASSWORD && export KS_CENTRAL_PASSWORD
python3 scripts/release/central-portal.py drop --deployment-id <送信の ID>
unset KS_CENTRAL_USERNAME KS_CENTRAL_PASSWORD
```

終了コード 0 で `dropped=true` なら取り下げた。`dropped=false` は、送信が見つからなかった (取り下げ済み)。終了コード 1 は、公開の処理に入っていたか、上限 (既定 10 分) までに決着しなかった。

同じ版の保留の送信が残ったまま新しく送ったときに、Central Portal がどう扱うかは確かめていない。新しく起動する前に、残った送信を取り下げておく。

## workflow の作りで知っておくこと

| こと | 内容 |
|---|---|
| 送信のログの受け方 | `Upload to Maven Central` は、Gradle の出力をファイルに受けてから表示し、Gradle の終了コードをそのまま返す。パイプ (`\| tee`) にしない (終了コードが失われる)。step のシェルは失敗したコマンドで即座に終わる (`-e`) ので、Gradle の失敗は `\|\| status=$?` で受け、ログを表示してから元の終了コードで終わる。後の `Extract deployment id` がこのファイルを読む |
| 写しの push | `Push SPM snapshot` は、写しを作り直さず、`package-ios` が作って `consumer-ios` が確かめた artifact `spm-snapshot` の中身を、配信用リポジトリの作業コピーに置いて push する (`scripts/release/place-spm-snapshot.py`)。置く前に、その中身が起動した commit から作った写しと同じ git の tree であること (配信用リポジトリの tag の照合と同じ比べ方) を、置いた後に、作業コピーの index の tree が artifact と同じであることを確かめる |
| 送信の ID | 公開のプラグインは、ID をファイルに書かず、ログに `Uploaded bundle to Central Portal as USER_MANAGED, deployment id: <ID>` を出す。`Extract deployment id` がこの 1 行を読む |
| 送信の控え | artifact の名前は `central-portal-receipt-<試行の番号>`。`publish` は、名前の型 (`central-portal-receipt-*`) で前の試行の控えを集め、試行の番号がいちばん大きいものを読む。控えは消さない |
| 自動の公開 | Gradle のプロパティ `mavenCentralAutomaticPublishing` を渡さない。渡すと、送った後は workflow と関わりなく公開まで進み、取り下げの道が消える |
| 元の commit | `package-android` と `publish` は、Gradle に `-PksCollectionViewSourceCommit=<起動した commit>` を渡す。POM の `scm` の `tag` に書かれ、公開済みの版の元の commit を照らすのに使う |
| 元の commit の形 | 40 桁の小文字の 16 進でなければ、Gradle の設定の時点で止まる。渡さないと、Maven Central へ送るタスクが止まる (手元への発行は止まらない) |
| 配信用リポジトリのブランチ | 写しは常に `main` へ push する (`HEAD:refs/heads/main`)。配信用リポジトリの既定のブランチが `main` である前提で、空のリポジトリへの最初の push で決まる |
| 配信用リポジトリへの接続 | deploy key は、step の中だけで ssh-agent に標準入力から載せる。github.com のホスト鍵は workflow に書いた値と照らし、初めての接続で受け入れない |
| 本リポジトリの tag | `gh api` で git の ref を作る (`contents: write`)。commit は作らない |
| 発行物の一致 | 署名して組み立て直した発行物は、組み立ての段の発行物とバイト単位で同じであることを前提に照らす (Gradle の既定で、アーカイブの時刻とファイルの順が固定される) |

## 確かめていないこと

次は、実物でまだ確かめていない。初回の試しと本番で確かめ、結果をここに書き足す。

| こと | 確かめる段 |
|---|---|
| 空の配信用リポジトリへの `git ls-remote` と `git clone` が成功し、最初の push で既定のブランチが `main` になること | 初回の 7 (試し)・10 (本番) |
| `ssh-add -` が標準入力から鍵を受けること | 初回の本番 |
| `Push SPM snapshot` で、artifact `spm-snapshot` から取り込んだ写しが、起動した commit から作り直した写しと同じ git の tree になること (artifact はファイルの実行の権限を保たない見込みで、今の写しに実行の権限を持つファイルは無い。手元では、作った写しをそのまま置く形をスクリプトのテストで確かめた) | 初回の本番 |
| `validate` の `contents: read` の token で、Pull Request と Release の一覧を読めること | 初回の 10 (`main` からの試し) |
| 失敗したジョブの再実行で、前の試行の artifact (`release-notes`・`android-maven`・送信の控え) を読めること | 初回の本番で失敗したとき (失敗しなければ未確認のまま) |
| `package-android` と `publish` を別のランナーで組み立てたとき、発行物がバイト単位で一致すること。手元の同じ機械の、別々のパスの clone では一致した (2026-10-15。使い捨ての鍵で `Build signed publication` と `Check signed publication` と同じコマンドを通した) | 初回の本番の `Check signed publication` |
| 送る束 (`Upload to Maven Central` の `publishToMavenCentral` の出力) の中身が、確かめた `signed-maven` と同じであること。同じ作業ツリーでの後の起動では、AAR と署名のタスクが up-to-date になり、出力がバイト単位で同じだった (手元の `publishToMavenLocal` で確かめた。送るタスクは流していない) | 初回の本番 |
| 本番の署名の鍵 (オーナーが登録するもの) の種類と形で署名できること。パスフレーズつきの鍵と 8 桁の鍵の ID を渡す形は、使い捨ての RSA の鍵で手元で通した (2026-10-15) | 初回の本番の `Build signed publication` |
| `gh release view` の「無い」の出力に `release not found` が含まれること | 初回の本番の `Create release` |
| `gh api` と `contents: write` で本リポジトリの tag を作れること・`--latest` で最新の Release になること | 初回の本番 |
| 待ちの上限 (検証の決着 60 分・公開済みまで 120 分・取得先まで 120 分) の妥当さ | 初回の本番の所要時間 |
| 同じ版の保留の送信が残ったまま新しく送ったときの扱い | 起きたとき |
| 手元での `build-release-notes.py` (token なし) | 初回の 9 |

## 関連

- [ブランチの運用と GitHub の設定](branch-and-github-settings.md) — `develop` と `main` の役割、`main` 宛ての Pull Request の進め方、secret を検出したときの手順
- [検証 CI](verification-ci.md) — リリースの workflow が呼ぶ検証と、workflow の定義の検査
- [利用者の立場のビルドの確認](consumer-build-check.md) — 利用者役の切り替え (`local`・`artifact`・`published`)
- [配布物の形と作り方](package-distribution.md) — SwiftPM の写しと Android の発行物の作り方
- [利用者向け Skill の追従](user-skill-refresh.md) — 事前の確認で使う、追従の Skill の確かめるだけの使い方
- [cross/ADR-0021](../../decisions/cross/0021-single-version-and-plain-tag-across-repositories.md) — 1 つの版と、接頭辞の無い tag
- [cross/ADR-0022](../../decisions/cross/0022-manual-release-dispatch-reversible-steps-first.md) — 手動の起動と、取り消せる操作から公開する順序
- [cross/ADR-0023](../../decisions/cross/0023-release-notes-from-main-pull-request-bodies.md) — リリースノートの材料
- [cross/ADR-0024](../../decisions/cross/0024-release-in-main-repository-marked-latest.md) — Release の置き場所と印

出典: kasane/changes/archive/<archive の日付>-release-pipeline/design.md (Decision 1〜13) / kasane/changes/archive/<archive の日付>-release-pipeline/deviation.md / kasane/changes/archive/<archive の日付>-release-pipeline/evidence/ (外部の挙動の調査・初回の証跡) / ../KsSettingsView/kasane/handbook/cross/release-procedure.md (手順の形)
