---
kind: guide
applies-when:
  always: false
  paths: [".gitleaksignore", ".gitleaks.toml"]
  tasks: [リリースの secret の登録・差し替え, 配信用リポジトリの deploy key の作成・作り直し, secret の検出への対応, secret の検査の誤検出への対応]
title: secret の扱い
description: リリースの secret 6 つの中身と使う step、オーナーが登録・差し替えるときの手順 (署名の鍵の見分け方・deploy key の作り方・登録の確かめ方)、secret を検出したときの手順 (GitHub に届く前と後)、誤検出の扱い
timestamp: 2026-10-15
---

# secret の扱い

この文書は、リリースに使う secret (鍵・token・パスワード) をどう登録・差し替えるかと、secret がリポジトリの内容に入ったと分かったときに何をするかをまとめる。文中の「オーナー」は、リポジトリの持ち主である開発者を指す。

secret の値は、オーナーが作り、登録し、差し替える。この文書の登録と差し替えのコマンドは、オーナーが自分の手元の端末で打つ。エージェントは、コマンドを示して案内するだけで、値を扱うコマンド (鍵の書き出し・`gh secret set`・鍵の作成) を自分では打たない。エージェントが打ってよいのは、名前の一覧や公開鍵の情報のような、値を含まない読み直しだけである。

コマンドの前提: `gh` に、本リポジトリと配信用リポジトリの管理の権限を持つアカウントでログインしていること・`gpg` と `trash` が入っていること。

リリースの workflow のジョブと step、配信用リポジトリ・写し・送信 (保留の送信) などの言葉は、[リリースの手順](release-procedure.md) の「この文書の言葉」と「workflow の形」にある。secret を置く Environment の設定の値は、[ブランチの運用と GitHub の設定](branch-and-github-settings.md) の「Environment `release` の値」にある。この文書では、次の言葉を使う。

| 言葉 | 意味 |
|---|---|
| 問い | `gh secret set` を値なしで打ったときに、値を尋ねる入力の問い。打った値は画面に出ない |
| 流す | ファイルの中身を、`< <ファイル>` でコマンドの標準入力から渡すこと |
| 1 行目 | 鍵を書き出したファイルの、最初の行。コードの塊の何行目かは「コードの N 行目」と書いて区別する |

## リリースの secret

secret は 6 つで、本リポジトリの Environment `release` にだけ置く (リポジトリの secret には置かない)。使うのは、リリースの workflow の `publish` のジョブだけである。

| secret | 中身 | 使う step |
|---|---|---|
| `SIGNING_KEY` | 署名に使う GPG の秘密鍵 (ASCII armor の形で書き出したもの) | 署名して組み立て直す (`Build signed publication`)・保留の送信 (`Upload to Maven Central`) |
| `SIGNING_KEY_ID` | その鍵の ID (8 桁の 16 進) | 同上 |
| `SIGNING_PASSWORD` | その鍵のパスフレーズ | 同上 |
| `MAVEN_CENTRAL_USERNAME` | Central Portal の user token のユーザー名 | 保留の送信・Central Portal の API の呼び出し |
| `MAVEN_CENTRAL_PASSWORD` | Central Portal の user token のパスワード | 同上 |
| `SPM_DEPLOY_KEY` | 配信用リポジトリの書き込み用の deploy key の秘密鍵 | 写しの push (`Push SPM snapshot`)・配信用リポジトリの tag |

前もってオーナーが確かめておくこと: 署名の鍵の公開鍵が鍵サーバーに上がっていること (Central Portal の検査が署名を照らすため)、名前空間 `jp.kamusoft` が Central Portal で検証済みであること (ドメイン `kamusoft.jp` の DNS の TXT レコードで検証する)。名前空間は、2026-10-15 にオーナーが検証済みと答えた。公開鍵は、同じ日の初回の本番で Central Portal の検査を通ったことで確かめられた (どの鍵サーバーに上げたかは記録に無い)。

鍵を作り直したときは、登録の前に公開鍵を鍵サーバーに上げる。Central Portal が照らす鍵サーバーは `keyserver.ubuntu.com`・`keys.openpgp.org`・`pgp.mit.edu` である (Central Portal の案内による。このリポジトリでは流していない)。

```bash
gpg --keyserver keyserver.ubuntu.com --send-keys <鍵の ID>
```

## 登録と差し替え

### 守ること

登録した値は、後から読み直せない (名前の一覧しか読めない)。値の形を確かめられるのは登録の前だけなので、登録の前の確かめだけが、取り違えを止められる。

- 何行もある値 (`SIGNING_KEY`・`SPM_DEPLOY_KEY`) は、ファイルから流す。問いに貼り付けない (1 行の入力の問いに何行も貼ると、値が正しく入らず、残りの行がシェルに入るおそれがある。確かめてはいない)
- 1 行の値 (`SIGNING_KEY_ID`・`SIGNING_PASSWORD`・`MAVEN_CENTRAL_USERNAME`・`MAVEN_CENTRAL_PASSWORD`) は、問いに貼り付けてよい
- `--body` で値をコマンドに書かない (シェルの履歴に残る)
- 下のコードの塊は、コマンドを 1 つずつ打つ (行末の `\` で次の行に続くものは、続きの行まで含めて 1 つのコマンド)。まとめて貼ると、問いが続く行を値として読む
- 鍵を書き出したファイルは、登録の後に `trash` で消す。`trash` はゴミ箱へ移すだけなので、登録が済んだら、オーナーがゴミ箱から消す

### 署名の鍵

`SIGNING_KEY` に入れるのは秘密鍵である。次の表のとおり、書き出したファイルの 1 行目で見分ける。

| 書き出しのコマンド | 中身 | 1 行目 | `SIGNING_KEY` に |
|---|---|---|---|
| `gpg --armor --export-secret-keys <鍵の ID>` | 秘密鍵 | `BEGIN PGP PRIVATE KEY BLOCK` | 入れる |
| `gpg --armor --export <鍵の ID>` | 公開鍵 (鍵サーバーに上げる方) | `BEGIN PGP PUBLIC KEY BLOCK` | 入れない |

実際の 1 行目は、この表の「1 行目」の列の文字列の前後に `-----` が付いた形である。この文書では、secret の検査が鍵と見なさないよう、前後の `-----` を外して書く。

取り違えて公開鍵を入れると、リリースの本番が `Build signed publication` で `Could not read PGP secret key` で止まる (送信の前)。初回の本番 (2026-10-15) は、これで 1 回止まった。

`SIGNING_KEY` は、一時のファイルに書き出し、そのファイルの 1 行目が秘密鍵の形のときだけ、同じファイルを流す。

```bash
key_file=$(mktemp)
gpg --armor --export-secret-keys <鍵の ID> > "$key_file"
head -1 "$key_file" | grep -q 'BEGIN PGP PRIVATE KEY BLOCK' && gh secret set SIGNING_KEY --env release --repo kamusoft/KsCollectionView < "$key_file"
trash "$key_file"
gh secret set SIGNING_KEY_ID --env release --repo kamusoft/KsCollectionView
gh secret set SIGNING_PASSWORD --env release --repo kamusoft/KsCollectionView
```

コードの 3 行目が何も出さずに終わり、`gh secret set` が登録の知らせを出さなければ、ファイルの 1 行目が秘密鍵の形でない。書き出しのコマンドを見直す。

鍵の控え (パスワード管理などに保管したもの) から登録するときは、控えを一時のファイルに書き出し、コードの 1・2 行目の代わりに `key_file=<書き出したファイル>` として、3 行目以降を打つ。`trash` で消すのは書き出した一時のファイルで、控えの原本は消さない。

`SIGNING_KEY_ID` には、`gpg --list-secret-keys --keyid-format short` が示す 8 桁の 16 進の ID (短い形) を入れる。署名用の副鍵 (`[S]` の付いた `ssb` の行) を持つ鍵では、主鍵ではなく、その副鍵の ID を入れる (署名はこの ID の鍵で行われる)。手元の試しと初回の本番で通ったのは、短い形の ID である。長い形 (16 桁) と、副鍵を持つ鍵では確かめていない。パスフレーズを誤ると、`Build signed publication` が署名のタスクで `PGPException` で失敗する (送る前に止まる)。

### Central Portal の user token

```bash
gh secret set MAVEN_CENTRAL_USERNAME --env release --repo kamusoft/KsCollectionView
gh secret set MAVEN_CENTRAL_PASSWORD --env release --repo kamusoft/KsCollectionView
```

token の誤りは、リリースの本番の `publish` の最初の問い合わせ (`Check published deployment`) が 401・403 で止まって分かる (何も送る前)。

### 配信用リポジトリの deploy key

鍵は、リポジトリの外の、作業用のディレクトリに作る。パスフレーズは付けない (workflow が標準入力から ssh-agent に載せるため)。公開鍵を配信用リポジトリに書き込みの権限で登録し、秘密鍵を `SPM_DEPLOY_KEY` に流す。

作り直すときは、先に古い鍵を外す (`gh repo deploy-key list --repo kamusoft/KsCollectionView-SPM` で ID を読み、`gh repo deploy-key delete <ID> --repo kamusoft/KsCollectionView-SPM`)。外してから新しい鍵を登録し終えるまでは、リリースの本番を起動しない (写しを push できない)。

```bash
key_dir=$(mktemp -d)
ssh-keygen -t ed25519 -C "KsCollectionView release workflow" -N "" -f "$key_dir/spm-deploy-key"
gh repo deploy-key add "$key_dir/spm-deploy-key.pub" --repo kamusoft/KsCollectionView-SPM \
  --title "release workflow (kamusoft/KsCollectionView)" --allow-write
gh secret set SPM_DEPLOY_KEY --env release --repo kamusoft/KsCollectionView < "$key_dir/spm-deploy-key"
trash "$key_dir"
```

確かめ方: `gh api repos/kamusoft/KsCollectionView-SPM/keys --jq '[.[] | {title, read_only}]'` に、付けた題の鍵が `read_only: false` で 1 つだけあること。公開鍵の情報だけを読み、秘密鍵は読まない。2 つの鍵が組であることは、値を読まないので、リリースの本番の写しの push で分かる。

### 登録の確かめ方

名前の一覧だけを読む (値は読めないし、読まない)。

```bash
gh secret list --env release --repo kamusoft/KsCollectionView
gh secret list --repo kamusoft/KsCollectionView
```

1 つ目に 6 つの名前がすべてあり、2 つ目 (Environment の外のリポジトリの secret) が空であること。名前がそろっていても、値の形 (秘密鍵か公開鍵か) は分からない。署名の鍵を登録した・差し替えたときは、リリースの本番を起動する前に、オーナーが鍵のファイルの 1 行目を確かめた (コードの 3 行目で登録の知らせが出た) かを、オーナーに確かめる。

## secret を検出したとき

secret が、リポジトリの内容に入ったと分かったときの手順である。値が GitHub に届いたかどうかで、することを分ける (オーナーの決定 2026-10-14)。検出が誤検出 (secret でない値) のときは、下の「誤検出の扱い」へ。

| 見つかった時点 | 知らせたもの | すること |
|---|---|---|
| GitHub に届く前 | commit の前の検査 (gitleaks)・push の保護 (GitHub が push を拒んだ) | push していない手元の commit から値を除いて、やり直す。値の無効化はしない |
| GitHub に届いた後 | 検証 CI の `Secret scan (gitleaks)`・GitHub の secret の検査の通知 | すぐに値を無効化して作り直し、登録先の secret を差し替える。その後、ファイルから値を除いた commit を push する。履歴は書き換えない |

履歴を書き換えないのは、公開済みの写しや fork から値が消えないうえ、`develop` の強制 push の禁止と、履歴をそのまま公開する決まり ([cross/ADR-0009](../../decisions/cross/0009-publish-existing-history-as-is.md)) にぶつかるためである。届いた値は、すでに公開されたものとして扱う。

### 届く前に止まったとき

- 値を除いて、push していない commit を作り直す (例: `git reset --soft origin/<作業しているブランチ>` で、push していない手元の commit を取り消し、値を除いてから commit し直す。まだ push していないブランチなら、`origin/develop` などの切り出した元の commit にする)
- push の保護に止められたときは、値を書き換えてから push し直す。GitHub が示す、検出を許して push を通す道は使わない
- `--no-verify` で commit の前の検査を迂回しない

### 届いた後に見つかったとき

値の種類ごとの、無効化と作り直しと差し替え。どれもオーナーが行う。

| 値 | 無効化と作り直し | 差し替え |
|---|---|---|
| 署名の鍵 (`SIGNING_KEY`・`SIGNING_KEY_ID`・`SIGNING_PASSWORD`) | 鍵を失効させ、失効を鍵サーバーに上げる (`gpg --output <失効の証明書> --gen-revoke <鍵の ID>`・`gpg --import <失効の証明書>`・`gpg --keyserver keyserver.ubuntu.com --send-keys <鍵の ID>`。このリポジトリでは流していない)。新しい鍵を作り、公開鍵を鍵サーバーに上げる (上の「リリースの secret」)。公開済みの版の署名は、失効した鍵のまま残る | 上の「署名の鍵」の手順で 3 つを登録し直す |
| Central Portal の user token (`MAVEN_CENTRAL_USERNAME`・`MAVEN_CENTRAL_PASSWORD`) | Central Portal で token を取り消し、新しく作る | 上の「Central Portal の user token」の手順で 2 つを登録し直す |
| 配信用リポジトリの deploy key (`SPM_DEPLOY_KEY`) | 古い鍵を外す (上の「配信用リポジトリの deploy key」の作り直し) | 同じ節の手順で、新しい鍵を作って足す |
| そのほか (個人の token など) | 発行元で取り消し、作り直す | 登録先があれば登録し直す |

GitHub の secret の検査の通知は、`gh api repos/kamusoft/KsCollectionView/secret-scanning/alerts` で読める。値を無効化した後に、通知を閉じる。

### 誤検出の扱い

gitleaks や push の保護が、secret でない値 (テスト用の値など) を検出したときは、次の順で扱う (除外が増えるほど、本物の secret を見落とすため)。

1. まず、その値を secret の形に見えない値に書き換える
2. 書き換えられないとき (実物と同じ形が要るテストなど) だけ、その検出の指紋 (fingerprint) を `.gitleaksignore` に足す。足す行の直前に、理由を書いた注釈の行を置く。1 件ずつ足し、まとめて足さない
3. push の保護に止められたときは、値を書き換えてから push し直す

gitleaks の規則そのもの (`.gitleaks.toml`) を置いて緩めることはしない (除外の範囲が、その 1 件より広くなる)。行の末尾に検出を許す印 (`gitleaks:allow`) を付ける形も使わない (理由が残らない)。2026-10-15 時点で、`.gitleaksignore` と `.gitleaks.toml` はどちらも無い。

文書に鍵の見出し (秘密鍵・公開鍵の 1 行目) を書くときは、前後の `-----` を外して書く。前後の `-----` 付きで書いた文書を、commit の前の検査 (gitleaks の private-key の規則) が鍵として検出した (2026-10-15)。これは上の 1 の「書き換える」に当たる。

commit の前の検査 (`.githooks/pre-commit`) は、止まったときに「誤検出なら `.gitleaks.toml` の allowlist か、行の末尾の `gitleaks:allow`」を案内する。この hook はハーネスが配る標準の装備で、このリポジトリでは案内を書き換えない (オーナーの決定 2026-10-15)。誤検出のときは、hook の案内より、この節の決まりを優先する (上の 1〜3 の順で扱い、allowlist と `gitleaks:allow` は使わない)。

### 確かめていないこと・決めていないこと

| こと | 分かっていること |
|---|---|
| gitleaks の指紋の形が、走査のしかたで違うか | 違う見込みである。commit の前の検査は git の履歴として走査し、指紋に commit が入る。検証 CI は取り出したディレクトリを走査し、指紋にそのディレクトリの中のパスが入る。片方の指紋を `.gitleaksignore` に足しても、もう片方の検出は消えない見込みである。初めて誤検出を除外するときに確かめ、この節に書き足す |
| GitHub の secret の検査の通知が誤検出だったときの閉じ方 (理由の選び方) | 決めていない |

## 関連

- [リリースの手順](release-procedure.md) — secret を使うリリースの workflow と、署名・認証の誤りで止まったときの見方
- [ブランチの運用と GitHub の設定](branch-and-github-settings.md) — Environment `release` と配信用リポジトリの設定の値・実施の記録
- [検証 CI](verification-ci.md) — `Secret scan (gitleaks)` の step と、落ちたときの見方
- [cross/ADR-0009](../../decisions/cross/0009-publish-existing-history-as-is.md) — 履歴を書き換えずに公開した決定

出典: kasane/roadmaps/v1-foundation/phases/phase-7-4-release-pipeline/agenda.md (決定事項 B3) / kasane/changes/archive/2026-10-15-release-pipeline/design.md (Decision 5・13) / kasane/changes/archive/2026-10-15-release-pipeline/drafts/branch-and-github-settings.md (5. secret を検出したとき) / kasane/changes/archive/2026-10-15-release-pipeline/drafts/release-procedure.md (初回だけ行うことの 1・3・5) / kasane/changes/archive/2026-10-15-release-pipeline/evidence/github-release-environment-001.md・github-release-run-001.md・publish-rehearsal-001.md・owner-decisions-1-3.md / kasane/changes/archive/2026-10-15-release-pipeline/review-006.md・review-007.md (登録の段の書き方)
