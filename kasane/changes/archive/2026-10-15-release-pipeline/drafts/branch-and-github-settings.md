# 草稿: branch-and-github-settings.md へ足す文面

変更 release-pipeline の tasks 7.2 の草稿。蒸留で `kasane/handbook/cross/branch-and-github-settings.md` に反映する。

各節は「置く場所」「今の文 (置き換えのときだけ)」「新しい文」の順に書く。置く場所は、反映先の節の名前と、2026-10-15 の時点の行の番号で示す。新しい文の中のリンクは、反映先 (`kasane/handbook/cross/`) からの相対で書いてある。

反映する内容の元:

| 内容 | 元 |
|---|---|
| 節目の基準を置かない・`main` を `develop` へ取り込み直さない | `kasane/roadmaps/v1-foundation/phases/phase-7-4-release-pipeline/agenda.md` の決定事項 B1 |
| 管理者も迂回しない | 同 B2 (オーナーの決定 2026-10-14) |
| secret を検出したときの手順 | 同 B3 (オーナーの決定 2026-10-14) と、design.md の Decision 13 (誤検出の扱い) |
| 配信用リポジトリと Environment の設定 | design.md の Decision 5 と、specs/repository-publication/spec.md |

## 1. frontmatter

置く場所: 先頭の frontmatter の `tasks`・`description`・`timestamp`。

新しい文:

~~~~yaml
applies-when:
  always: false
  tasks: [develop への push, main 宛ての Pull Request の作成とマージ, GitHub のリポジトリの設定の変更・確認, ブランチの保護の変更・確認, 配信用リポジトリ・Environment の設定の変更・確認, secret の検出への対応]
title: ブランチの運用と GitHub の設定
description: develop と main の役割、develop への push と main 宛ての Pull Request の進め方、管理者も保護を迂回しない決まり、GitHub のリポジトリ・配信用リポジトリ・Environment の設定の値と入れ方・確かめ方、secret を検出したときの手順と誤検出の扱い
timestamp: <蒸留の日>
~~~~

## 2. 冒頭の段落

置く場所: 「# ブランチの運用と GitHub の設定」の 2 つ目の段落 (15 行目) の末尾に 1 文を足す。

新しい文:

~~~~markdown
リリースの手順 (配信用リポジトリ・Environment・secret の初回の設定のコマンドを含む) は [リリースの手順](release-procedure.md) にある。
~~~~

## 3. 「main 宛ての Pull Request を作ってマージする」

### 3.1 節の冒頭の 1 文を置き換える

置く場所: 40 行目。

今の文:

~~~~markdown
`main` に入れるのは、リリース候補にする節目である。次の順で進める。
~~~~

新しい文:

~~~~markdown
`main` に入れる節目の基準は置かない。いつ `main` 宛ての Pull Request を出すかと、版の番号は、オーナーが決める。`main` 宛ての Pull Request は、リリースのとき以外にも出してよい。リリースのノートは、前回の Release から `main` に入った Pull Request の変更の節をまとめる ([cross/ADR-0023](../../decisions/cross/0023-release-notes-from-main-pull-request-bodies.md))。リリースのときの進め方は [リリースの手順](release-procedure.md) にあり、ここの順はそれ以外のときにも使う。次の順で進める。
~~~~

### 3.2 手順の 2 を置き換える

置く場所: 43 行目。

今の文:

~~~~markdown
2. Pull Request を作る: `gh pr create --repo kamusoft/KsCollectionView --base main --head develop --title <タイトル> --body-file <本文のファイル>`
~~~~

新しい文:

~~~~markdown
2. 本文を、ひな形 (`.github/pull_request_template.md`) の形で書き、Pull Request を作る: `gh pr create --repo kamusoft/KsCollectionView --base main --head develop --title <タイトル> --body-file <本文のファイル>`。変更の節 (`## Changes`) は必須で、利用者向けの変更が無ければ `- none` の 1 行にする。書き方はひな形の注釈にある
~~~~

### 3.3 手順の後に段落を足す

置く場所: 46 行目 (手順の 5) の次。48 行目の「`main` 宛ての Pull Request では、変更したパスに関わらず…」の前。

新しい文:

~~~~markdown
変更の節が無い・読めない行がある Pull Request が `main` に入ると、次のリリースの workflow が、公開の前に止まる。マージの前に本文を見直す。マージした後でも、本文を `gh pr edit` で直せば、次のリリースに反映される。

マージの後に、`main` を `develop` へ取り込み直さない。マージは merge commit だけなので、`develop` の履歴がそのまま `main` に入り、取り込み直す必要が無い。リリースのノートの範囲も、Release の tag で決まる。兄弟ライブラリの系列で、squash の後に `main` を取り込み直して、前の版の項目がノートに重複して載ったことがある。merge commit だけのマージでは、これは起きない。
~~~~

### 3.4 52 行目の括弧の中を直す

今の文:

~~~~markdown
マージの方法は merge commit に決めてある。squash と rebase は使わない (`develop` の commit がそのまま `main` に入り、節目が merge commit として残る)。
~~~~

新しい文:

~~~~markdown
マージの方法は merge commit に決めてある。squash と rebase は使わない (`develop` の commit がそのまま `main` に入り、取り込んだ区切りが merge commit として残る)。
~~~~

### 3.5 管理者の迂回の 2 段落を置き換える

置く場所: 54 行目と 56 行目。

今の文:

~~~~markdown
管理者は `main` と `develop` の保護を迂回できる設定にしてある。開発者が 1 人で、ランナーの不調などで必須の検査が止まったときの逃げ道が要るためである。ランナー `xcode-27` は public preview で、止まったときに `main` 宛ての Pull Request を進める手段は、この迂回だけになる。

利用者の立場のビルドの確認の 2 つは、外部の依存の取得 (Nuke・Maven の依存) に頼る。コードの誤りではない理由で止まったときは、実行をやり直す。やり直しても進まないときの手段も、この迂回である。
~~~~

新しい文:

~~~~markdown
管理者も、`main` の保護を迂回しない。必須の検査が、コードの誤りではない理由 (外部の依存 (Nuke・Maven の依存) の取得の失敗・ランナーの不調) で止まったときは、失敗したジョブを再実行して、通るまで待つ: `gh run rerun <run の ID> --repo kamusoft/KsCollectionView --failed`。ランナー `xcode-27` は public preview で、止まったまま進まないことがあるが、そのときも迂回せずに待つ。

迂回しないのは、リリースの workflow も、公開の前に同じ検証と利用者役の確認を流し、同じ外部の依存を取得するからである。迂回しても、リリースは早まらない。得られるのは、検査の通っていない commit が `main` に入ることだけである (オーナーの決定 2026-10-14)。

保護の設定は、管理者に強制しないまま (`enforce_admins` は false) にしてある。迂回しない決まりは、設定ではなく、この手順で守る。
~~~~

## 4. 「GitHub の設定の値」に、配信用リポジトリと Environment の値を足す

置く場所: 「### 保護の値」の節の末尾 (103 行目「必須の検査の名前は、…」の段落の次)、「## 設定を入れる順」の前。小節を 2 つ足す。

新しい文:

~~~~markdown
### 配信用リポジトリの設定の値

SwiftPM の配信用リポジトリ `kamusoft/KsCollectionView-SPM` は、リリースの workflow が写しと tag を push するだけのリポジトリである ([cross/ADR-0015](../../decisions/cross/0015-swiftpm-via-distribution-repository.md))。貢献は本リポジトリの Issue で受ける ([cross/ADR-0011](../../decisions/cross/0011-contributions-via-issues-no-external-pull-requests.md))。

| 設定 | 値 |
|---|---|
| 公開の範囲 | public |
| 既定のブランチ | `main` (最初の本番の push で決まる) |
| Issues・Wiki・Discussions・Projects | どれも無効 |
| Pull Request を作れる人 | 共同作業者だけ (`collaborators_only`) |
| 書き込み | 書き込み用の deploy key (題 `release workflow (kamusoft/KsCollectionView)`) 1 つと、管理者だけ |
| Release | 作らない ([cross/ADR-0024](../../decisions/cross/0024-release-in-main-repository-marked-latest.md)) |
| ルートの README | 写しに入る `scripts/distribution/spm-readme.template.md`。配信用の写しであることと、使い方と不具合の報告先が本リポジトリであることを示す |

### Environment `release` の値

リリースの secret は、本リポジトリの Environment `release` にだけ置く (リポジトリの secret には置かない)。リリースの workflow の `publish` のジョブだけが、この Environment を指定する。

| 設定 | 値 |
|---|---|
| 使えるブランチ | `main` だけ (`custom_branch_policies` を真にし、`main` を `type: branch` で 1 件足す)。`protected_branches` を真にする形は使わない (`develop` も保護されたブランチなので、`develop` から使えてしまう) |
| 承認者・待ち時間 | 付けない (起動そのものが手動の関門で、確定した後は止まらずに進める) |
| secret | 6 つ: `SIGNING_KEY`・`SIGNING_KEY_ID`・`SIGNING_PASSWORD`・`MAVEN_CENTRAL_USERNAME`・`MAVEN_CENTRAL_PASSWORD`・`SPM_DEPLOY_KEY`。値はオーナーが登録する |

入れ方と確かめ方のコマンドは、[リリースの手順](release-procedure.md) の「初回だけ行うこと」にある。値を変えるときは、先にこの 2 つの表を直す。
~~~~

## 5. 新しい節「secret を検出したとき」

置く場所: 「## 必須の検査を足すとき」の節の終わり (333 行目の表の次) と、「## 実施の記録」(334 行目) の間。

新しい文:

~~~~markdown
## secret を検出したとき

secret (鍵・token・パスワードなど) が、リポジトリの内容に入ったと分かったときの手順である。値が GitHub に届いたかどうかで、することを分ける (オーナーの決定 2026-10-14)。検出が誤検出 (secret でない値) のときは、下の「誤検出の扱い」へ。

| 見つかった時点 | 知らせたもの | すること |
|---|---|---|
| GitHub に届く前 | commit の前の検査 (gitleaks)・push の保護 (GitHub が push を拒んだ) | push していない手元の commit から値を除いて、やり直す。値の無効化はしない |
| GitHub に届いた後 | 検証 CI の `Secret scan (gitleaks)`・GitHub の secret の検査の通知 | すぐに値を無効化して作り直し、登録先の secret を差し替える。その後、ファイルから値を除いた commit を push する。履歴は書き換えない |

履歴を書き換えないのは、公開済みの写しや fork から値が消えないうえ、`develop` の強制 push の禁止と、履歴をそのまま公開する決まり ([cross/ADR-0009](../../decisions/cross/0009-publish-existing-history-as-is.md)) にぶつかるためである。届いた値は、すでに公開されたものとして扱う。

### 届く前に止まったとき

- 値を除いて、push していない commit を作り直す (例: `git reset --soft origin/develop` で手元の commit を取り消し、値を除いてから commit し直す)
- push の保護に止められたときは、値を書き換えてから push し直す。GitHub が示す、検出を許して push を通す道は使わない
- `--no-verify` で commit の前の検査を迂回しない

### 届いた後に見つかったとき

値の種類ごとの、無効化と作り直しと差し替え。どれもオーナーが行う (エージェントは値を扱わない)。

| 値 | 無効化と作り直し | 差し替え |
|---|---|---|
| 署名の鍵 (`SIGNING_KEY`・`SIGNING_KEY_ID`・`SIGNING_PASSWORD`) | 鍵の失効の証明書を鍵サーバーに上げ、新しい鍵を作って公開鍵を鍵サーバーに上げる。公開済みの版の署名は、失効した鍵のまま残る | 3 つを `gh secret set <名前> --env release --repo kamusoft/KsCollectionView` で登録し直す |
| Central Portal の user token (`MAVEN_CENTRAL_USERNAME`・`MAVEN_CENTRAL_PASSWORD`) | Central Portal で token を取り消し、新しく作る | 2 つを同じく登録し直す |
| 配信用リポジトリの deploy key (`SPM_DEPLOY_KEY`) | `gh repo deploy-key list --repo kamusoft/KsCollectionView-SPM` で ID を読み、`gh repo deploy-key delete <ID> --repo kamusoft/KsCollectionView-SPM` で外す。新しい鍵を作って足す | 秘密鍵を登録し直し、鍵のファイルを `trash` で消す |
| そのほか (個人の token など) | 発行元で取り消し、作り直す | 登録先があれば登録し直す |

鍵の作り方と登録のコマンドは、[リリースの手順](release-procedure.md) の「初回だけ行うこと」にある。値を標準入力から流し、使ったファイルは `trash` で消す。

GitHub の secret の検査の通知は、`gh api repos/kamusoft/KsCollectionView/secret-scanning/alerts` で読める。値を無効化した後に、通知を閉じる。

### 誤検出の扱い

gitleaks や push の保護が、secret でない値 (テスト用の値など) を検出したときは、次の順で扱う (除外が増えるほど、本物の secret を見落とすため)。

1. まず、その値を secret の形に見えない値に書き換える
2. 書き換えられないとき (実物と同じ形が要るテストなど) だけ、その検出の指紋 (fingerprint) を `.gitleaksignore` に足す。足す行の直前に、理由を書いた注釈の行を置く。1 件ずつ足し、まとめて足さない
3. push の保護に止められたときは、値を書き換えてから push し直す

gitleaks の規則そのもの (`.gitleaks.toml`) は緩めない (除外の範囲が、その 1 件より広くなる)。行の末尾に検出を許す印を付ける形も使わない (理由が残らない)。

commit の前の検査 (`.githooks/pre-commit`) は、止まったときに「誤検出なら `.gitleaks.toml` の allowlist か、行の末尾の `gitleaks:allow`」を案内する。この hook はハーネスが配る標準の装備で、このリポジトリでは案内を書き換えない。誤検出のときは、hook の案内より、この節の決まりを優先する (上の 1〜3 の順で扱い、allowlist と `gitleaks:allow` は使わない)。
~~~~

## 6. 「実施の記録」の表に行を足す

置く場所: 「## 実施の記録」の表の末尾 (349 行目の次)。日付と証跡は、初回の実施 (tasks 9・10) の後に埋める。

新しい文:

~~~~markdown
| 配信用リポジトリの作成と設定 | <日付> | `kasane/changes/archive/<archive の日付>-release-pipeline/evidence/<証跡のファイル>` |
| 配信用リポジトリの deploy key と、Environment `release` と secret の登録 | <日付> | 同上 |
| 準備の Pull Request (リリースの workflow を `main` に入れた) | <日付> | 同上 |
| #1・#2 の本文に変更の節 (`- none`) を足した | <日付> | 同上 |
~~~~

## 7. 「関連」と出典

置く場所: 「## 関連」の箇条の末尾と、末尾の「出典:」の行。

新しい文 (「関連」に足す):

~~~~markdown
- [リリースの手順](release-procedure.md) — リリースの workflow の起動と見守り、配信用リポジトリ・Environment・secret の初回の設定
- [cross/ADR-0023](../../decisions/cross/0023-release-notes-from-main-pull-request-bodies.md) — リリースのノートを `main` 宛ての Pull Request の変更の節から組み立てる決定
- [cross/ADR-0015](../../decisions/cross/0015-swiftpm-via-distribution-repository.md) — SwiftPM を配信用リポジトリで配る決定
~~~~

新しい文 (「出典:」の行の末尾に足す):

~~~~markdown
 / kasane/roadmaps/v1-foundation/phases/phase-7-4-release-pipeline/agenda.md (決定事項 B1・B2・B3) / kasane/changes/archive/<archive の日付>-release-pipeline/design.md (Decision 5・13)
~~~~

## 反映のときに確かめること

- gitleaks の指紋の形は、走査のしかたで違う見込みである (確かめていない)。commit の前の検査は git の履歴として走査し、指紋に commit が入る。検証 CI は取り出したディレクトリを走査し、指紋にそのディレクトリの中のパスが入る
- そのため、片方の指紋を `.gitleaksignore` に足しても、もう片方の検出は消えない見込みである。初めて誤検出を除外するときに確かめ、5 の「誤検出の扱い」に書き足す
- commit の前の検査 (`.githooks/pre-commit`) の案内 (allowlist か `gitleaks:allow`) は、5 の「誤検出の扱い」(design の Decision 13) と食い違う。hook は直さない (オーナーの決定 2026-10-15。ハーネスが配る標準の装備のため)。5 の末尾の段落で、この手順の決まりを優先すると書いた
- GitHub の secret の検査の通知が誤検出だったときの閉じ方 (理由の選び方) は、決めていない
