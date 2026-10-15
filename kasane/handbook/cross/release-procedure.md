---
kind: guide
applies-when:
  always: false
  paths: [".agents/skills/release/**", ".github/workflows/release.yml", "scripts/release/**"]
  tasks: [リリースの実施, リリースの試し (dry-run), 失敗したリリースの再実行, 残った保留の送信の取り下げ, リリースの workflow・道具の変更]
title: リリースの手順
description: リリースの workflow で iOS (配信用リポジトリ) と Android (Maven Central) に同じ版を公開する手順。毎回の手順 (事前の確認・変更の節・リリースの Pull Request・起動・見守り・公開の後の確認)、試し、失敗したときのやり直し、残った保留の送信の取り下げ、workflow の作りで知っておくこと、初回のリリースで確かめたこと
timestamp: 2026-10-15
---

# リリースの手順

この文書は、版を入力してリリースの workflow (`.github/workflows/release.yml`) を起動し、iOS と Android の配布物を同じ版で公開して、tag と Release を作るまでの手順をまとめる。文中の「オーナー」は、リポジトリの持ち主である開発者を指す。コマンドの `<版>` は `0.1.0` や `0.1.0-beta.1` の形の値に、`<対象の commit>` は 40 桁の commit の ID (`git rev-parse` の出力。短い ID にしない) に、`<番号>` はリリースの Pull Request の番号に、`<run の ID>` はリリースの workflow の run の ID に読み替える。

扱うリポジトリは 2 つある。本リポジトリ `kamusoft/KsCollectionView` と、SwiftPM の配信用リポジトリ `kamusoft/KsCollectionView-SPM` である ([cross/ADR-0015](../../decisions/cross/0015-swiftpm-via-distribution-repository.md))。版と tag の付け方は [cross/ADR-0021](../../decisions/cross/0021-single-version-and-plain-tag-across-repositories.md)、起動のしかたと公開の順序は [cross/ADR-0022](../../decisions/cross/0022-manual-release-dispatch-reversible-steps-first.md)、リリースノートの材料は [cross/ADR-0023](../../decisions/cross/0023-release-notes-from-main-pull-request-bodies.md)、Release の置き場所と印は [cross/ADR-0024](../../decisions/cross/0024-release-in-main-repository-marked-latest.md) にある。

## この文書の使い方

この文書がリリースの手順の正である。リリースの Skill `release` (`.agents/skills/release/`) は、起動のたびにこの文書を先頭から読み、書かれた順とコマンドのとおりに進める。Skill は段の順序もコマンドも持たないので、手順を変えるときはこの文書だけを直す。Skill がこの文書の節を名前で指しているので、節の名前を変えるときは Skill の本文も同じ回に直す。

| 場面 | 読む節 |
|---|---|
| リリースする | 「リリースのたびに行うこと」の 1〜6 を順に |
| 試しをする (外へ何も送らずに、公開の前の段までを通す) | 「試し」 |
| 実行が止まった・失敗した実行の続きをする | 「失敗したとき」 |
| 打ち切られた run などで、Central Portal に保留の送信が残った | 「残った保留の送信を取り下げる」 |
| リリースの workflow や `scripts/release/` を変える | 「workflow の作りで知っておくこと」を読んでから変え、「試し」で通す |
| 配信用リポジトリ・Environment・secret を作る・作り直す・確かめ直す | [ブランチの運用と GitHub の設定](branch-and-github-settings.md) の「リリースのための設定」と、[secret の扱い](secret-handling.md) |
| secret が漏れた疑いがある・secret の検出の知らせが来た | [secret の扱い](secret-handling.md) の「secret を検出したとき」 |

判断はオーナーが行う: 出す版の番号・変更の節の文面・失敗したときに再実行するか・どの形で再実行するか・中止するか。オーナーへの確認は、版と変更の節の文面を 1 回のメッセージ (確認のメッセージ) でまとめて行う。確定した後は、リリースの Pull Request の作成とマージ・起動・公開の後の確認まで、段ごとに確認せずに進める。止まるのは、失敗したときと、この文書に書かれていない状況に当たったときである。

GitHub と Maven Central への操作は外向きで、多くは取り消せない。確定の前に、公開を伴う操作 (リリースの Pull Request のマージ・本番の起動・tag の作成) をしない。secret の値は、オーナーが登録する。エージェントは値を扱わない。

## この文書の言葉

| 言葉 | 意味 |
|---|---|
| 本番 | 入力 `dry-run` を偽にした起動。`main` からだけ受け付け、公開まで進む |
| 試し | 入力 `dry-run` を真にした起動。どのブランチからでもよく、公開の前の段で終わる。外へ何も送らず、secret を使わない |
| 対象の commit | 事前の確認を終えた時点の `origin/develop` の先端。リリースの Pull Request で `main` に入れ、公開する |
| 変更の節 | `main` 宛ての Pull Request の本文の `## Changes` の節。リリースノートの材料になる。書き方は `.github/pull_request_template.md` の注釈にある |
| リリースの Pull Request | 対象の commit を `develop` から `main` へ入れる Pull Request |
| 範囲の Pull Request | リリースノートの材料になる Pull Request。前回の Release の tag から起動した commit までに `main` に入ったもの (Release が 1 つも無ければ、`main` の最初から) |
| 確認のメッセージ | オーナーに版と変更の節の文面を確定してもらう、1 回のメッセージ (「2.」で出す) |
| 配布物 | 利用者に届けるもの。iOS は写し、Android は発行物 |
| 写し | 配信用リポジトリのルートに置く、本体の SwiftPM の写し ([配布物の形と作り方](package-distribution.md)) |
| 発行物 | Android の Maven の成果物 5 点 (AAR・POM など) と、署名 (`.asc`) |
| 公開物 | 公開した後の配布物。配信用リポジトリの tag の付いた写しと、Maven Central の発行物 |
| 利用者役 | 配布物を利用者と同じ書き方で取ってビルドする、最小のプロジェクト ([利用者の立場のビルドの確認](consumer-build-check.md)) |
| 公開の前の段 | ジョブ `verify-*`・`package-*`・`consumer-*`。検証 CI と同じ検証と、配布物の組み立てと、利用者役でのビルドを行う (`validate` は含まない) |
| 公開の後の段 | ジョブ `wait-for-registries`・`smoke-*`・`check-release` |
| 取得先 | 利用者が発行物を取る Maven Central のリポジトリ (`https://repo1.maven.org/maven2/`)。公開済みになってから、ここに現れる |
| 送信 | Maven Central (Central Portal) への発行物の送信 (deployment)。保留 (`USER_MANAGED`) で送り、公開を指示するまでは取り下げられる |
| 検査と決着 | Central Portal は、送信を受け取ると中身 (署名・POM など) を検査する。検査が終わって `VALIDATED` (公開できる) か `FAILED` になることを、決着と呼ぶ。step の名前では validation |
| 送信の控え | 送信の ID を書いたファイル。run の artifact `central-portal-receipt-<試行の番号>` に置き、同じ run の次の試行が読む |
| 試行 | 同じ run の実行の回。「失敗したジョブの再実行」をするたびに増える (`GITHUB_RUN_ATTEMPT`) |

## workflow の形

リリースの workflow は、手動の起動 (`workflow_dispatch`) でだけ走る。入力は `version` (必須) と `dry-run` (真偽。既定は偽) の 2 つである。同時に 1 本だけ流れ、走っている間に起動したものは待つ (走っているものは打ち切られない。待っているものがあるときにさらに起動すると、待っていた方が取り消される)。

| ジョブ | すること | 試しで走るか |
|---|---|---|
| `validate` | 版の形・起動したブランチ・両リポジトリの tag・Maven Central の公開済みの版を確かめ、`main` からの起動ならリリースノートを組み立てる | 走る |
| `verify-ios`・`verify-android` | 検証 CI と同じ検証 (ビルドと Android のテスト) | 走る |
| `package-ios`・`package-android` | SwiftPM の写しと、入力の版の Android の発行物 (署名しない) を作って artifact に置く | 走る |
| `consumer-ios`・`consumer-android` | 組み立てた配布物そのものを、利用者役でビルドする | 走る |
| `publish` | 公開する。Environment `release` を指定し、secret を持つのはこのジョブだけ | 飛ばす |
| `wait-for-registries` | 取得先に版が現れるまで待つ (上限 120 分) | 飛ばす |
| `smoke-ios`・`smoke-android`・`check-release` | 公開物を取得する利用者役と、最新の Release の確認 | 飛ばす |

`publish` の step は、取り消せる操作から順に並ぶ: 利用者役 (`consumer-ios`) で確かめた写しの push (`Push SPM snapshot`) → 署名して組み立て直す → 保留の送信 (`Upload to Maven Central`) → 検査の決着の待ち (`Wait for validation`、上限 60 分) → 公開の指示 (`Publish deployment`) → 公開済みの待ち (`Wait for publication`、上限 120 分) → 配信用リポジトリの tag → 本リポジトリの tag → Release。`Publish deployment` より後は取り消せない。

secret は 6 つで、Environment `release` にだけ置く。それぞれの中身と、どの step が使うかは、[secret の扱い](secret-handling.md) の「リリースの secret」にある。

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
| run が無い (この段で push した直後) | run は、push の後に少し遅れて一覧に現れる。同じコマンドで 1 分おきに最大 5 分読み直し、現れたら上の行に従う。5 分読み直しても無ければ、直近で成功した run で代えられるかを確かめる (下の段落) |
| run が無い (この段で push していない) | 読み直さずに、直近で成功した run で代えられるかを確かめる (下の段落) |

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
| 終了コード 0 (`代えてよい`) | その run の成功で代えて進む。確認のメッセージ (「2.」で出す) に、代えた run と、出力の「起動しないパス」の一覧を添える |
| 終了コード 1 で、出力に「起動するパス」がある | 止まる。出力の「起動するパス」の一覧をオーナーに示す |
| 終了コード 1 で、「祖先でない」・「手元に無い」・「読めない」 | 止まる。出力のエラーの行をオーナーに示す (この文書に書いていない状況) |

代えてよいのは、起動しないパスのファイルがビルドとテストに入らず、lint が読むものはリリースの Pull Request の必須の検査 (`lint`) で確かめられるからである。

利用者向け Skill の追従が要るかを、追従の Skill `docs-refresh` の確かめるだけの使い方 (引数 `check`) で調べる ([利用者向け Skill の追従](user-skill-refresh.md))。追従そのものはしない。要ると出たら、確認のメッセージに添える (追従するかはオーナーが決め、追従した commit を入れてから、この段をやり直す)。

### 2. 変更の節の下書きと、オーナーの確認

到達状態: オーナーが、版と変更の節の文面を確定している。

下書きの材料は、リリースの Pull Request が `main` へ新しく持ち込む commit だけである。前回のリリースからのすべての変更ではない (すでに `main` に入った変更は、それを持ち込んだ Pull Request の変更の節が持っている)。

```bash
git fetch origin main develop
git log --no-merges --reverse origin/main..<対象の commit> --pretty=format:'%h %s%n%b%n--'
```

前回の版 (版の候補を決める材料。Release が 1 つも無ければ何も出ないので、初めての版として候補を決める):

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

下書きは、まだ `main` に入っていないので、手元の道具でノートに組み立てて確かめることはできない。形は上の表で確かめる。

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

変更の節は、次の `## ` で始まる見出しか、本文の終わりまで続く。変更の節の後ろに何かを書くとき (Pull Request を作る道具が本文の末尾に足す署名の行など) は、`## ` で始まる見出し (`## Notes` など) を置いてから書く。`###` などほかの水準の見出しでは変更の節が終わらない。見出しを置かずに足すと、その行が変更の節の読めない行になり、リリースが `validate` で止まる (2026-10-15 に、署名の行を足した本文をリリースノートの組み立ての読み方で読んで確かめた)。

Pull Request を作り、5 つの必須の検査 (`lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify`) を待つ。2026-10-15 の 2 回では、いちばん長い `android / verify` が 5 分 15〜23 秒だった。

```bash
gh pr create --repo kamusoft/KsCollectionView --base main --head develop --title "Release <版>" --body-file <本文のファイル>
gh pr checks <番号> --repo kamusoft/KsCollectionView --required --watch --interval 60
gh pr checks <番号> --repo kamusoft/KsCollectionView --required --json name,bucket
gh pr view <番号> --repo kamusoft/KsCollectionView --json headRefOid,mergeable,mergeStateStatus,isCrossRepository
```

| 読む項目 | 期待する値 |
|---|---|
| 必須の検査 | 5 つとも `bucket` が `pass` |
| `headRefOid` | 対象の commit |
| `mergeable`・`mergeStateStatus` | `MERGEABLE`・`CLEAN` |
| `isCrossRepository` | `false` |

どれかが期待と違えば、マージせずに止まり、読んだ値をオーナーに示す。リリースの Pull Request は開いたまま残す。閉じるか、そのまま直して進めるか、「1. 事前の確認」からやり直すかは、オーナーが決める。よくある理由は次のとおり。

| 違い | 理由の見当 |
|---|---|
| `headRefOid` が対象の commit でない | 確定の後に `develop` が進んだ |
| `mergeable` が `CONFLICTING` | `main` と `develop` が競合している。このとき検査は 1 つも走らない |
| `mergeStateStatus` が `BLOCKED` | 必須の検査が成功していない、または走っていない |

外部の依存の取得などで検査が止まったときは、止まる前に、失敗したジョブを再実行して待つ (`gh run rerun <その検査の run の ID> --repo kamusoft/KsCollectionView --failed`)。管理者も保護を迂回しない ([ブランチの運用と GitHub の設定](branch-and-github-settings.md))。

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

一覧の先頭が、`headBranch` が `main`、`headSha` が `origin/main` の先端、`createdAt` が起動の後のものであること。run は起動の後に少し遅れて一覧に現れるので、そういう run が無ければ、同じコマンドで 10 秒おきに最大 2 分読み直す。それでも無いとき・`headSha` が違うときは、もう一度起動せずに止まり、読んだ一覧をオーナーに示す。別のリリースの run が走っていると、今回の run は待ちの状態 (`pending`) になる。

### 5. 見守り

到達状態: run のすべてのジョブが成功で終わっている。

```bash
gh run watch <run の ID> --repo kamusoft/KsCollectionView --exit-status --interval 60
gh run view <run の ID> --repo kamusoft/KsCollectionView --json jobs --jq '.jobs[] | [.name, .conclusion] | @tsv'
```

`gh run watch` の終了コードだけで判定せず、ジョブごとの結果を読み直す。止まったら「失敗したとき」へ。

所要時間の目安 (初回のリリース `0.1.0-beta.1`、2026-10-15):

| 区切り | 所要 | 内訳 |
|---|---|---|
| 起動から `publish` の開始まで | 約 5 分 20 秒 | いちばん長いのは `verify-android / verify` (約 5 分) |
| `publish` | 9 分 6 秒 | 署名して組み立て直す 1 分 36 秒・検査の決着の待ち約 30 秒・公開済みの待ち約 6 分 33 秒 |
| `wait-for-registries` | 6 秒 | 公開済みになった時点で、取得先に版が現れていた |
| `smoke-ios`・`smoke-android`・`check-release` | 最長 2 分 4 秒 (`smoke-android`) | 3 つが並んで走る |

合わせて、失敗が無ければ 20 分ほどで終わる。`publish` の時間の上限は 345 分で、待ちの上限 (決着 60 分・公開済み 120 分) を含む。初回の待ちは上限よりずっと短かった。

### 6. 公開の後の確認

到達状態: 2 つの公開物・Release・最新の Release を指す URL を、実物で確かめている。

`smoke-ios`・`smoke-android`・`check-release` の成功は、公開物を取得してビルドできたことと、最新の Release が今回の版であることを示す。加えて、次を読む。

```bash
# 本リポジトリの tag が、起動した commit を指すこと
git fetch origin
git ls-remote --tags origin "refs/tags/<版>"
gh run view <run の ID> --repo kamusoft/KsCollectionView --json headSha --jq .headSha
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
| 本リポジトリの tag | 起動した commit (run の `headSha`) を指す。起動の後に `main` へ別の Pull Request が入っていなければ、`origin/main` の先端と同じである |
| 配信用リポジトリ | tag がある。既定のブランチは `main` |
| Release | tag と題が `<版>`。`isDraft`・`isPrerelease` は `false`。本文は run のリリースノート |
| 最新の Release | API と URL の行き先 (`/releases/tag/<版>`) の両方が今回の版 |
| Maven Central | POM が取れ、`<scm>` の `<tag>` が起動した commit |

どれかが期待と違えば、止まり、読んだ値をオーナーに示す。公開物は取り消せないので、直し方はオーナーが決める。

あわせて、オーナーが画面で次を見る: 配信用リポジトリのページ (README が本リポジトリへ案内していること)・Maven Central の `jp.kamusoft:kscollectionview` の今回の版・本リポジトリの Release のページ。

Release の本文は、変更の節から組み立てたものである。手で直さない。文面を直したいときは、次の版の変更の節の書き方を直す。

## 試し

試し (`dry-run` を真) は、`validate` と公開の前の段だけを走らせ、`publish` 以降を飛ばし、外へ何も送らない。secret も使わない。起動するブランチは問わない。workflow を変えたときは、試しで `validate` から利用者役までを通しておく。2026-10-15 の試しは、`develop` から約 5 分、`main` から約 6 分 30 秒で終わった。

```bash
gh workflow run release.yml --repo kamusoft/KsCollectionView --ref <ブランチ> -f version=<版> -f dry-run=true
```

`<版>` には、実際に出す予定の値を入れる (`validate` が、その版の tag と公開済みの版を確かめる)。

| 起動したブランチ | リリースノート |
|---|---|
| `main` | 範囲の Pull Request を読んで検査し、組み立てて artifact `release-notes` に置く (Release は作らない)。リリースの Pull Request をマージした後に流すと、変更の節の誤りで本番の `validate` が止まる事態を前もって見つけられる |
| `main` 以外 | 読まず、組み立てない (`Build release notes` が `built=false` で終わる) |

`main` から流した試しのノートは、`gh run download <run の ID> --repo kamusoft/KsCollectionView -n release-notes -D "$(mktemp -d)"` で読める。

同じノートは、手元でも組み立てられる (GitHub の API を読むだけで、token は要らない。2026-10-15 に確かめた)。

```bash
git fetch origin main --tags
python3 scripts/release/build-release-notes.py --version <版> --output "$(mktemp -d)/notes.md" \
  --commit "$(git rev-parse origin/main)" --ref refs/heads/main --repository kamusoft/KsCollectionView
```

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

再実行するか・どの形で再実行するか・中止するかは、オーナーが決める。オーナーの指示が無いまま、再実行のコマンドを流さない。オーナーが形を選んで指示したら、エージェントがその形のコマンドを流してよい (2026-10-15 の初回も、そうした)。

### 再実行の形

| 形 | コマンド | 使う場面 |
|---|---|---|
| 失敗したジョブの再実行 | `gh run rerun <run の ID> --repo kamusoft/KsCollectionView --failed` | 原因を取り除いた後。起動した commit のまま、失敗したジョブとその後ろのジョブだけが走る。前の試行の artifact と送信の控えは引き継がれる |
| 同じ版での新しい起動 | 「リリースのたびに行うこと」の 4 | `validate` か公開の前の段で止まり、起動した commit から直す必要があるとき。直した commit を `develop` に入れ、「リリースのたびに行うこと」の 1〜3 で `main` に入れてから起動する。外へ何も送っていないので、同じ版で出し直してよい |

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

### 公開の前の段で止まったとき

`verify-*`・`package-*`・`consumer-*` で止まったときも、外へは何も送っていない。

| 原因 | すること |
|---|---|
| 外部の依存の取得の失敗など、コードの誤りでない | 失敗したジョブを再実行する |
| コードや配布物の誤り | `develop` で直し、「リリースのたびに行うこと」の 1 からやり直す (新しいリリースの Pull Request と、同じ版での新しい起動) |

### publish で止まったとき

`publish` の step は、同じ版でもう一度走らせても、済んだ工程を飛ばす。原因を取り除いてから、失敗したジョブを再実行する。

| 止まった step | 外の状態 | 再実行で起きること・すること |
|---|---|---|
| (ジョブが始まらない) Environment の保護 | 何も送っていない | `main` 以外から本番が来た。`validate` が止めるので通常は起きない。起きたら止まって調べる |
| `Check published deployment`・`Inspect previous deployment` | 何も送っていない | 認証の誤り (401・403) なら、オーナーが `MAVEN_CENTRAL_*` を確かめる ([secret の扱い](secret-handling.md)) |
| `Check published commit` | 公開済みの版が別の commit から作られている | その版はこの commit からは出せない。次の版で出す |
| `Push SPM snapshot` (確かめた写しが、起動した commit から作った写しと違う・作業コピーの index が確かめた写しと違う) | 何も push していない | `package-ios` が作った写しと、`publish` で作り直した写しが食い違った。止まって調べる (ログに 2 つの tree の ID が出る)。原因の候補: 写しに、名前が `.` で始まるファイル (artifact に入らない) か、実行の権限が要るファイル (artifact が保たない見込み) が入った |
| `Push SPM snapshot` (それ以外) | 写しが配信用リポジトリの `main` に入ったかもしれない (tag は無い) | deploy key・ホスト鍵を調べる。再実行では、差分が無ければ commit を作らない |
| `Build signed publication` | Maven Central へは送っていない | 署名の鍵の誤り。`SIGNING_KEY` に公開鍵を登録していると `Could not read PGP secret key` で、パスフレーズを誤ると `PGPException` で止まる。オーナーが [secret の扱い](secret-handling.md) の「署名の鍵」の確かめ方で登録し直す |
| `Check signed publication` | Maven Central へは送っていない | `package-android` が作った発行物と、`publish` で署名して組み立て直した発行物の中身が違う。止まって調べる (初回は、別のランナーどうしで 5 ファイルとも一致した) |
| `Upload to Maven Central`・`Extract deployment id` | 保留の送信があるかもしれない | ID が読めれば、後始末 (`Drop pending deployment`) が取り下げる。読めなければ「残った保留の送信を取り下げる」を行ってから再実行する |
| `Wait for validation` (決着が `FAILED`) | 送信は取り下げ済み | ログに出た検査の誤りを直す。再実行は新しく送る |
| `Wait for validation` (上限) | 後始末の `Drop pending deployment` が、決着を最大 10 分待ってから取り下げる。その間に決着すれば取り下げ済み、決着しなければ送信が検査中のまま残る (`Drop pending deployment` も失敗する) | `Drop pending deployment` のログを読む。取り下げていれば、再実行は新しく送る。残っていれば、再実行はその送信の決着をもう一度待つ (送り直さない) |
| `Publish deployment`・`Wait for publication` | 公開を指示したかもしれない (取り消せない) | 再実行で、公開の処理中なら送り直さずに公開済みを待ち、公開済みなら tag へ進む |
| `Check tags before tagging` | Maven Central は公開済み | tag が別のものを指している。止まって調べる |
| `Tag SPM repository`・`Tag main repository`・`Create release` | Maven Central は公開済み | 再実行で、ある tag と Release は飛ばし、残りを作る |

公開の指示の前に失敗したときは、後始末の `Drop pending deployment` が保留の送信の取り下げを試みる。公開の指示の後は取り下げない。run が打ち切られると後始末は走らない。そのときは「残った保留の送信を取り下げる」を行う。

### 公開の後の段で止まったとき

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

`release.yml` や `scripts/release/` を変えるときは、次を崩さない。workflow の定義 (起動・Environment・公開の step の順・自動の公開を渡さないこと) は、スクリプトのテスト (`scripts/ci/tests/test_workflow_files.py`) が確かめる ([検証 CI](verification-ci.md))。

| こと | 内容 |
|---|---|
| 起動できる定義 | 手動で起動する workflow は、既定のブランチ (`main`) にそのファイルがあるときだけ起動できる。本番は `main` の定義で走るので、`release.yml` の変更は、`main` に入るまで本番に効かない。試しは、起動したブランチの定義で走る |
| 送信のログの受け方 | `Upload to Maven Central` は、Gradle の出力をファイルに受けてから表示し、Gradle の終了コードをそのまま返す。パイプ (`\| tee`) にしない (終了コードが失われる)。step のシェルは失敗したコマンドで即座に終わる (`-e`) ので、Gradle の失敗は `\|\| status=$?` で受け、ログを表示してから元の終了コードで終わる。後の `Extract deployment id` がこのファイルを読む |
| 写しの push | `Push SPM snapshot` は、写しを作り直さず、`package-ios` が作って `consumer-ios` が確かめた artifact `spm-snapshot` の中身を、配信用リポジトリの作業コピーに置いて push する (`scripts/release/place-spm-snapshot.py`)。置く前に、その中身が起動した commit から作った写しと同じ git の tree であること (配信用リポジトリの tag の照合と同じ比べ方) を、置いた後に、作業コピーの index の tree が artifact と同じであることを確かめる |
| 送信の ID | 公開のプラグインは、ID をファイルに書かず、ログに `Uploaded bundle to Central Portal as USER_MANAGED, deployment id: <ID>` を出す。`Extract deployment id` がこの 1 行を読む |
| 送信の控え | artifact の名前は `central-portal-receipt-<試行の番号>`。`publish` は、名前の型 (`central-portal-receipt-*`) で前の試行の控えを集め、試行の番号がいちばん大きいものを読む。控えは消さない |
| 自動の公開 | Gradle のプロパティ `mavenCentralAutomaticPublishing` を渡さない。渡すと、送った後は workflow と関わりなく公開まで進み、取り下げの道が消える |
| 元の commit | `package-android` と `publish` は、Gradle に `-PksCollectionViewSourceCommit=<起動した commit>` を渡す。POM の `scm` の `tag` に書かれ、公開済みの版の元の commit を照らすのに使う。形と、渡さないときの止まり方は [配布物の形と作り方](package-distribution.md) |
| 配信用リポジトリのブランチ | 写しは常に `main` へ push する (`HEAD:refs/heads/main`)。配信用リポジトリの既定のブランチが `main` である前提で、空のリポジトリへの最初の push で決まる (初回の本番で `main` になった) |
| 配信用リポジトリへの接続 | deploy key は、step の中だけで ssh-agent に標準入力から載せる。github.com のホスト鍵は workflow に書いた値と照らし、初めての接続で受け入れない |
| 本リポジトリの tag | `gh api` で git の ref を作る (`contents: write`)。commit は作らない |
| 発行物の一致 | `publish` で署名して組み立て直した発行物は、`package-android` の発行物とバイト単位で同じであることを前提に照らす (Gradle の既定で、アーカイブの時刻とファイルの順が固定される) |

## 初回のリリースで確かめたこと

2026-10-15 に、初回の版 `0.1.0-beta.1` を公開した。本番の試行 1 は、`SIGNING_KEY` に公開鍵が登録されていて `Build signed publication` で止まった (送信の前)。秘密鍵で登録し直し、失敗したジョブの再実行 (試行 2) で最後まで通った。記録は `kasane/changes/archive/2026-10-15-release-pipeline/evidence/github-release-run-001.md` にある。設定の実施の記録は [ブランチの運用と GitHub の設定](branch-and-github-settings.md) の「実施の記録」にある。

| 確かめたこと | 結果 |
|---|---|
| 空の配信用リポジトリへの `git ls-remote` と `git clone`、最初の push | どれも成功し、既定のブランチは `main` になった |
| `ssh-add -` が標準入力から鍵を受けること | 受けた (`Identity added: (stdin)`) |
| artifact `spm-snapshot` の写しと、起動した commit から作り直した写しの tree の一致 | 一致して push できた |
| `validate` の `contents: read` の token で、範囲の Pull Request を読むこと | `main` からの試しで、#1〜#4 の本文を読んでノートを組み立てた (前回の Release が無く、範囲の起点は `main` の最初) |
| 失敗したジョブの再実行で、前の試行の artifact を読むこと | 試行 2 の `publish` が、試行 1 の `release-notes`・`android-maven`・`spm-snapshot` を読んだ |
| 別のランナーで組み立てた発行物のバイトの一致 | `package-android` と `publish` の発行物が、5 ファイルとも一致した |
| Maven Central へ送ったものが、確かめた署名つきの発行物と同じであること | 送る step で、組み立てと署名のタスクが作り直されなかった (`30 actionable tasks: 4 executed, 26 up-to-date`)。送ったものそのものの中身は比べていない |
| 本番の署名の鍵で署名できること | 秘密鍵で登録し直した後に通った |
| 送信の ID の読み取り | プラグインは決着を待たずに終わり (`Skipping deployment validation!`)、ログの 1 行から ID が読めた |
| `gh release view` の「無い」の判定・`gh api` での tag の作成・`--latest` | どれも通り、Release はプレリリースの印なしで最新に選ばれた |
| 公開物の取得 | tag を付けた写しを SwiftPM が解決でき (`smoke-ios`)、Maven Central から発行物を取れた (`smoke-android`) |
| 待ちの上限の妥当さ | 決着約 30 秒・公開済みまで約 6 分 33 秒・取得先まで 6 秒で、上限 (60 分・120 分・120 分) には遠かった。上限は変えていない |
| 手元での `build-release-notes.py` (token なし) | 初回のノートと同じものが組み立てられた |

まだ確かめていないこと:

| こと | 確かめる時点 |
|---|---|
| 試行をまたいだ送信の控えの引き継ぎ | 送信の後に失敗して再実行したとき (初回は送信の前に止まったので、控えが無かった) |
| artifact がファイルの実行の権限を保つか | 写しに実行の権限を持つファイルが入ったとき (今の写しには無い。保たない見込み) |
| 同じ版の保留の送信が残ったまま新しく送ったときの扱い | 起きたとき |
| Environment の決まりが、`main` 以外の run の `publish` を止めること | 起きたとき (`develop` からの本番は、`validate` が先に止めた) |

## 関連

- [ブランチの運用と GitHub の設定](branch-and-github-settings.md) — `develop` と `main` の役割、`main` 宛ての Pull Request の進め方、配信用リポジトリと Environment の設定
- [secret の扱い](secret-handling.md) — リリースの secret の中身と登録・差し替え、secret を検出したときの手順
- [検証 CI](verification-ci.md) — リリースの workflow が呼ぶ検証と、workflow の定義の検査
- [利用者の立場のビルドの確認](consumer-build-check.md) — 利用者役の切り替え (`local`・`artifact`・`published`)
- [配布物の形と作り方](package-distribution.md) — SwiftPM の写しと Android の発行物の作り方、元の commit の渡し方
- [利用者向け Skill の追従](user-skill-refresh.md) — 事前の確認で使う、追従の Skill の確かめるだけの使い方
- [cross/ADR-0021](../../decisions/cross/0021-single-version-and-plain-tag-across-repositories.md) — 1 つの版と、接頭辞の無い tag
- [cross/ADR-0022](../../decisions/cross/0022-manual-release-dispatch-reversible-steps-first.md) — 手動の起動と、取り消せる操作から公開する順序
- [cross/ADR-0023](../../decisions/cross/0023-release-notes-from-main-pull-request-bodies.md) — リリースノートの材料
- [cross/ADR-0024](../../decisions/cross/0024-release-in-main-repository-marked-latest.md) — Release の置き場所と印

出典: kasane/changes/archive/2026-10-15-release-pipeline/design.md (Decision 1〜13) / kasane/changes/archive/2026-10-15-release-pipeline/deviation.md / kasane/changes/archive/2026-10-15-release-pipeline/drafts/release-procedure.md (この文書の草稿) / kasane/changes/archive/2026-10-15-release-pipeline/evidence/ (外部の挙動の調査・初回の試しと本番の証跡) / kasane/changes/archive/2026-10-15-release-pipeline/review-003.md (読み直しの条件と artifact の書き方) / ../KsSettingsView/kasane/handbook/cross/release-procedure.md (手順の形)
