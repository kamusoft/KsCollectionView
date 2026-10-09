---
kind: guide
applies-when:
  always: false
  tasks: [develop への push, main 宛ての Pull Request の作成とマージ, GitHub のリポジトリの設定の変更・確認, ブランチの保護の変更・確認]
title: ブランチの運用と GitHub の設定
description: develop と main の役割、develop への push と main 宛ての Pull Request の進め方、GitHub のリポジトリの設定とブランチの保護の値・入れ方・確かめ方
timestamp: 2026-10-09
---

# ブランチの運用と GitHub の設定

この文書は、公開リポジトリ `kamusoft/KsCollectionView` の 2 本のブランチをどう使うかと、GitHub の側に入れてある設定の値・入れ方・確かめ方をまとめる。文中の「オーナー」は、リポジトリの持ち主である開発者を指す。日々の push と、`main` 宛ての Pull Request は、ここに書いた順で進める。設定を変えるとき・入れ直すときも、ここの値を正とする。

ブランチを 2 本に分けた理由は [cross/ADR-0010](../../decisions/cross/0010-develop-and-main-branch-roles.md) にある。検証 CI の中身は [検証 CI](verification-ci.md) が持つ。必須の検査の名前を固定した理由は [cross/ADR-0014](../../decisions/cross/0014-ci-reusable-platform-workflows-and-fixed-check-names.md) にある。`main` 宛ての Pull Request で、配布物を利用者役 (配布物を利用者と同じ書き方で取る最小のプロジェクト) でビルドして確かめ、必須の検査にした理由は [cross/ADR-0016](../../decisions/cross/0016-consumer-build-check-on-main-pull-requests.md) にある。

## ブランチの役割

| ブランチ | 先端が表すもの | 入れ方 | 検証 CI |
|---|---|---|---|
| `develop` | 開発の最新 | 直接 push する | push の後に走る (事後の検証) |
| `main` | リリース候補。リポジトリの既定のブランチ | 同じリポジトリの `develop` からの Pull Request だけ | Pull Request で走り、5 つの検査が必須 |

`develop` への push で走る検査は 3 つで、`main` 宛ての Pull Request ではそこに利用者の立場のビルドの確認の 2 つが加わる。`develop` の検証は事後なので、壊れた状態が `develop` に載り得る。失敗を見て `develop` の上で直す。

外部からの Pull Request は受け付けない ([cross/ADR-0011](../../decisions/cross/0011-contributions-via-issues-no-external-pull-requests.md))。Pull Request を作れるのは共同作業者だけで、`main` 宛てに限っては出どころも `develop` に限る。

## develop へ push する

作業用のブランチと worktree は `develop` から切る。作業を手元で `develop` にマージし、`develop` を直接 push する。

- push すると、その時点で内容が公開される。commit の前と push の前に手元の検査が走る状態にしておく (有効化は [ローカル開発環境と Sample の実行](local-development-setup.md))
- push の後に検証 CI が走る。結果は `gh run list --branch develop --workflow ci.yml --limit 1` で見られる
- `kasane/` 配下・Issue のフォーム・貢献の案内だけを変えた push では、検証 CI は起動しない。その push に入った lint の違反は、次に起動した回か、`main` 宛ての Pull Request で見つかる
- 検証が走っている間に、起動の対象になる push を重ねると、古い実行は打ち切られる
- `develop` は強制 push と削除を禁じてある。履歴を書き換えて push し直す運用はしない

## main 宛ての Pull Request を作ってマージする

`main` に入れるのは、リリース候補にする節目である。次の順で進める。

1. `develop` の最新の検証 CI が成功で終わっていることを確かめる
2. Pull Request を作る: `gh pr create --repo kamusoft/KsCollectionView --base main --head develop --title <タイトル> --body-file <本文のファイル>`
3. 5 つの必須の検査 (`lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify`) が成功で終わるのを待ち、マージできる状態を読む: `gh pr view <番号> --json mergeable,mergeStateStatus,isCrossRepository`
4. merge commit でマージする: `gh pr merge <番号> --repo kamusoft/KsCollectionView --merge` (ブランチの削除の指定は付けない)
5. 手元の `main` を GitHub の `main` まで早送りする: `git fetch origin main:main`

`main` 宛ての Pull Request では、変更したパスに関わらず 5 つの検査が走る。`lint` は、出どころが同じリポジトリの `develop` であることを確かめ、結果を step `Pull request head restriction` の記録に出す。`develop` 以外のブランチや、別のリポジトリから作った Pull Request は、ここで落ちる。

5 つのうち、利用者の立場のビルドの確認の 2 つ (`consumer-ios / verify`・`consumer-android / verify`) は、`main` 宛ての Pull Request でだけ走る。`develop` の最新の検証 CI が成功していても、この 2 つは Pull Request を作って初めて結果が出る。配布物の形に関わる変更を含むときは、Pull Request を作る前に、手元で同じ確認を流しておく ([利用者の立場のビルドの確認](consumer-build-check.md) の「手元で流す」)。

マージの方法は merge commit に決めてある。squash と rebase は使わない (`develop` の commit がそのまま `main` に入り、節目が merge commit として残る)。

管理者は `main` と `develop` の保護を迂回できる設定にしてある。開発者が 1 人で、ランナーの不調などで必須の検査が止まったときの逃げ道が要るためである。ランナー `xcode-27` は public preview で、止まったときに `main` 宛ての Pull Request を進める手段は、この迂回だけになる。

利用者の立場のビルドの確認の 2 つは、外部の依存の取得 (Nuke・Maven の依存) に頼る。コードの誤りではない理由で止まったときは、実行をやり直す。やり直しても進まないときの手段も、この迂回である。

### これまでの Pull Request の記録

| 項目 | 1 番 (2026-10-08) | 2 番 (2026-10-09) |
|---|---|---|
| その時点の必須の検査 | 3 つ (`lint`・`ios / verify`・`android / verify`) | 作った時点は 3 つ。5 つの検査が成功した後、マージの前に 5 つに更新した |
| 走った検査 | 3 つが走って成功した。先端の commit は `kasane/` の下だけを変えたものだった | 5 つが走って成功した (`lint` 17 秒・`ios / verify` 4 分 4 秒・`android / verify` 5 分 2 秒・`consumer-ios / verify` 1 分 58 秒・`consumer-android / verify` 3 分 16 秒) |
| マージできる状態 | `MERGEABLE`・`CLEAN`。別のリポジトリからの Pull Request ではない | 同じ。必須の検査を 5 つに更新した後も、同じ状態だった |
| マージ | merge commit | merge commit (`gh pr merge 2 --repo kamusoft/KsCollectionView --merge`) |
| マージの後 | `main` への push による検証の実行は作られなかった。`develop` は残っている | 同じ |

1 番の `lint` の step の記録には、`出どころは kamusoft/KsCollectionView の develop` と出た。

## GitHub の設定の値

入れてある値は次のとおり。値を変えるときは、先にこの表を直す。

| 設定 | 値 |
|---|---|
| 公開の範囲 | public |
| 既定のブランチ | `main` |
| Issues | 有効 |
| Wiki・Discussions・Projects | 無効 |
| Pull Request を作れる人 | 共同作業者だけ |
| secret の検査 (secret scanning)・secret を含む push を止める保護 (push protection。以下「push の保護」)・依存の脆弱性の通知 | 有効 |
| ラベル | `bug`・`enhancement`・`question` がある (Issue のフォームが付ける) |
| `main` の保護 | 下の節 |
| `develop` の保護 | 下の節 |

Pull Request を作れる人の設定は、API では `pull_request_creation_policy` という項目で、値は `collaborators_only` である。

### 保護の値

| 項目 | `main` | `develop` |
|---|---|---|
| Pull Request の必須 | 必須。承認の必須の数は 0 | なし (直接 push を受ける) |
| 必須の検査 | `lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify`。GitHub Actions が出したものに限る | なし |
| 強制 push | 禁止 | 禁止 |
| 削除 | 禁止 | 禁止 |
| 管理者への強制 | しない | しない |
| `main` の最新を取り込んでいないとマージできない (`strict`) | しない | — |
| 古い承認の取り消し・コードオーナーの承認 | どちらもしない | — |
| push できる人の限定 | なし | なし |

この表の最後の 3 行 (`strict`・古い承認の取り消しとコードオーナーの承認・push できる人の限定) は、設計の文書 (末尾の出典の `design.md`) の表に無い値で、兄弟ライブラリ KsSettingsView と同じにした (オーナーに示して承認を得た)。

必須の検査の名前は、検証 CI のジョブの名前と一致していなければならない。再利用 workflow を呼ぶジョブの検査の名前は「呼ぶ側のジョブの名前 / 呼ばれる側のジョブの名前」になる。ジョブの名前を変えるときは、保護の側も同時に直す。検査を足すときは、下の「必須の検査を足すとき」の順で行う。

## 設定を入れる順

保護は、public に切り替えて検証 CI が 1 度成功した後に入れる。順番には次の理由がある。

| 順 | 行うこと | この順にする理由 |
|---|---|---|
| 1 | 非公開でリポジトリを作り、`main` だけを push する | 公開の前に、オーナーが GitHub の画面で中身を確かめる機会を持つ。その時点の `main` には workflow が無いので、非公開の利用枠を使わない |
| 2 | public に切り替える | Free プランでは、ブランチの保護は public のリポジトリでだけ使える |
| 3 | 機能の設定・Pull Request を作れる人の制限・secret の検査と push の保護・依存の脆弱性の通知を入れる | `develop` を push する前に、外向きの受け口と検査を決めた形にする |
| 4 | `develop` を push する | 検証 CI がここで初めて走る |
| 5 | `main` と `develop` の保護を入れる | 必須の検査の名前が、実際に報告された名前と合うことを見てから入れる |
| 6 | `develop` から `main` 宛ての Pull Request を作り、マージする | 上の「main 宛ての Pull Request を作ってマージする」の経路を、最初の変更で通す |

GitHub への操作は取り消せない外向きの操作なので、1 つずつオーナーの承認を得てから行い、実行したコマンドと読み直しの結果を証跡に残す。

## 入れ方と確かめ方

設定は `gh` のコマンドで入れ、入れた直後に同じ項目を読み直して、節「GitHub の設定の値」の 2 つの表と突き合わせる。画面からは入れない (入れた値の記録が残らず、入れ忘れに気付きにくい)。

### リポジトリの作成と最初の push

```bash
gh repo create kamusoft/KsCollectionView --private
git remote set-url origin git@github.com:kamusoft/KsCollectionView.git
git push origin main
```

2026-10-08 の実施では、作成の後に読んだ時点で HTTPS の形の remote `origin` があった (作成のコマンドが足したのか、手で足したのかは確かめていない)。`origin` が無ければ `git remote add origin <URL>` で足す。オーナーの希望で、SSH の形 (GitHub の SSH の URL。ホストは `github.com`、パスは `kamusoft/KsCollectionView.git`) に変えてから push した。

`--push` は付けない (付けると、手元の commit がまとめて push される)。push の前の検査 (`.githooks/pre-push`) は、まだどの remote にも無い commit をすべて検査するので、最初の push では全履歴が対象になる。

確かめ方: GitHub の `main` の先端が、手元と同じ commit の ID であること。あわせて、GitHub にあるブランチ・公開の範囲・既定のブランチ・検証の実行の数を読む。

```bash
git rev-parse main
git ls-remote origin
gh repo view kamusoft/KsCollectionView --json visibility,defaultBranchRef
gh api repos/kamusoft/KsCollectionView/actions/runs
```

結果 (2026-10-08): 実行はオーナーが手元の端末で行った。読み直しは次のとおりで、決めたとおりだった。

| 確かめたこと | 結果 |
|---|---|
| GitHub の `main` の先端と手元の `main` | 2 つの ID が一致した (`a76c380…`) |
| GitHub にあるブランチ | `main` だけ (`develop` は無い) |
| 公開の範囲と既定のブランチ | private、既定のブランチは `main` |
| 検証の実行 | 0 件 (`main` に workflow が無いため) |

### 公開の範囲

```bash
gh repo edit kamusoft/KsCollectionView --visibility public --accept-visibility-change-consequences
```

切り替えは、オーナーが GitHub の画面で中身 (ルートのファイルの並び・開発の記録・commit の一覧とメッセージ・過去の証跡) を見て、指示を出した後に行う。

確かめ方: `gh repo view kamusoft/KsCollectionView --json visibility,isPrivate` が public (`isPrivate` は false) を返すこと。`gh api repos/kamusoft/KsCollectionView` の `disabled` と `archived` がどちらも false であること。`git ls-remote origin` で `main` の先端が変わっていないこと。

結果 (2026-10-08): 終了コード 0 で切り替わり、公開の範囲は public、既定のブランチは `main`、`disabled` と `archived` はどちらも false、`main` の先端は `a76c380…` のままだった。

切り替えの直後の 1 回だけ、SSH での読み取りが「リポジトリが無効になっている」という応答で失敗した。数秒後にやり直すと 3 回続けて成功した。切り替えの直後の一時的な応答と見ている (原因は確かめていない)。

### 機能・検査・通知・Pull Request を作れる人

入れる前にいまの値を読み、節「GitHub の設定の値」の表と違う値だけを入れる。2026-10-08 に実行したのは、値が違っていた 4 つ (Projects・Pull Request を作れる人・secret の検査・push の保護) を変える次の 3 つである。

```bash
gh repo edit kamusoft/KsCollectionView --enable-projects=false
gh api -X PATCH repos/kamusoft/KsCollectionView -f pull_request_creation_policy=collaborators_only
gh api -X PATCH repos/kamusoft/KsCollectionView --input - <<'JSON'
{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}
JSON
```

secret の検査と push の保護は、1 回の PATCH で 2 つとも `enabled` になった。Pull Request を作れる人の制限は、Pull Request の機能そのものは有効のまま、作れる人だけを絞る設定である (機能を無効にすると、`main` 宛ての Pull Request も作れなくなる)。

既定のブランチ・Issues・Wiki・Discussions・依存の脆弱性の通知は、最初から決めた値だったので、入れるコマンドは実行していない (`gh repo create --private` で作って public に切り替えた場合)。

確かめ方: 次の 3 つを読み直し、節「GitHub の設定の値」の表と突き合わせる。

```bash
gh api repos/kamusoft/KsCollectionView
gh api repos/kamusoft/KsCollectionView/vulnerability-alerts
gh api repos/kamusoft/KsCollectionView/labels
```

1 つ目は `visibility`・`default_branch`・`has_issues`・`has_wiki`・`has_discussions`・`has_projects`・`pull_request_creation_policy`・`security_and_analysis` を読む。依存の脆弱性の通知は、有効なら 2 つ目の応答が 204 になる。ラベルは 3 つがあることを確かめる。

結果 (2026-10-08): 読み直した値は、すべて節「GitHub の設定の値」の表と一致した。

| 設定 | 入れる前 | 読み直した値 |
|---|---|---|
| 公開の範囲 | public | `visibility: public` |
| 既定のブランチ | `main` | `default_branch: main` |
| Issues | 有効 | `has_issues: true` |
| Wiki | 無効 | `has_wiki: false` |
| Discussions | 無効 | `has_discussions: false` |
| Projects | 有効 | `has_projects: false` |
| Pull Request を作れる人 | 誰でも (`all`) | `pull_request_creation_policy: collaborators_only` |
| secret の検査 | 無効 | `secret_scanning: enabled` |
| push の保護 | 無効 | `secret_scanning_push_protection: enabled` |
| 依存の脆弱性の通知 | 有効 | 応答 204 (有効) |
| ラベル | ある | 9 つのラベルに 3 つとも含まれる |

新しいリポジトリには、ラベル `bug`・`enhancement`・`question` が最初からあった (ほかに 6 つ)。ラベルを作るコマンドは実行していない。

### main の保護

保護は、項目をすべて書いた payload を PUT する。PUT は部分の更新にならず、書かなかった項目は消える。必須の検査を足すだけのときも、項目をすべて書いて送る。下は、必須の検査が 5 つの今の payload である。

```bash
gh api -X PUT repos/kamusoft/KsCollectionView/branches/main/protection --input - <<'JSON'
{
  "required_status_checks": {
    "strict": false,
    "checks": [
      { "context": "lint", "app_id": 15368 },
      { "context": "ios / verify", "app_id": 15368 },
      { "context": "android / verify", "app_id": 15368 },
      { "context": "consumer-ios / verify", "app_id": 15368 },
      { "context": "consumer-android / verify", "app_id": 15368 }
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
```

`app_id` の 15368 は GitHub Actions を指す。省くと、同じ名前の検査を出すほかのアプリでも必須が満たせてしまう。`strict` は false にする (true にすると、`main` にしか無い merge commit を `develop` に取り込むまで、次の Pull Request をマージできなくなる)。

確かめ方: `gh api repos/kamusoft/KsCollectionView/branches/main/protection` を読み直し、次の表の値になっていることを確かめる (値の元は、節「保護の値」の表)。

| 読む項目 | 期待する値 |
|---|---|
| `required_status_checks.checks` | 5 件。`context` が `lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify`、`app_id` がどれも 15368 |
| `required_pull_request_reviews.required_approving_review_count` | 0 |
| `enforce_admins.enabled` | false |
| `allow_force_pushes.enabled` | false |
| `allow_deletions.enabled` | false |

結果 (2026-10-08、必須の検査が 3 つの payload で最初に入れたとき): 終了コード 0 で入り、読み直した値は渡した値とすべて同じだった。

| 項目 | 読み直した値 |
|---|---|
| Pull Request の必須 | `required_pull_request_reviews` が置かれている。承認の必須の数は 0 |
| 必須の検査 | 3 件 (`lint`・`ios / verify`・`android / verify`)。名前と `app_id` (15368) が渡した値と同じ |
| 強制 push・削除・管理者への強制 | どれも false |
| `strict` | false |
| 古い承認の取り消し・コードオーナーの承認 | どちらも false |
| push できる人の限定 | 無い |

結果 (2026-10-09、必須の検査を 5 つにした更新): 上の payload の PUT は終了コード 0 で入った。同じコマンドで、更新の前と後に値を読んだ。必須の検査だけが 3 件から 5 件に変わり、ほかの項目は変わらなかった。

| 読む項目 | 更新の前 | 更新の後 |
|---|---|---|
| `required_status_checks.checks` | 3 件。`context` が `lint`・`ios / verify`・`android / verify`、`app_id` がどれも 15368 | 5 件。上の 3 つに `consumer-ios / verify`・`consumer-android / verify` が加わった。`app_id` はどれも 15368 |
| `required_status_checks.strict` | false | false |
| `enforce_admins.enabled` | false | false |
| `required_pull_request_reviews` | 承認の必要数 0。古い承認の取り消し・コードオーナーの承認・最後の push の承認は false | 同じ |
| `allow_force_pushes.enabled`・`allow_deletions.enabled` | どちらも false | どちらも false |
| `required_linear_history`・`required_signatures`・`required_conversation_resolution`・`lock_branch`・`block_creations`・`allow_fork_syncing` の `enabled` | どれも false | どれも false |

必須の検査のほかの項目は、応答から URL の項目を除いて前後で突き合わせ、一致した。`develop` の保護も更新の前後で読み、一致した。

### develop の保護

```bash
gh api -X PUT repos/kamusoft/KsCollectionView/branches/develop/protection --input - <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
```

確かめ方: `gh api repos/kamusoft/KsCollectionView/branches/develop/protection` を読み直し、強制 push と削除が禁じられていること、必須の検査と Pull Request の必須が無いこと、管理者に強制しない設定であることを確かめる。

結果 (2026-10-08): 終了コード 0 で入った。読み直すと、強制 push と削除はどちらも false (禁止)、必須の検査と Pull Request の必須は無く、管理者への強制は false だった。

### Issue のフォーム

Issue のフォームと、空の Issue を作れなくする指定は、リポジトリのファイル (`.github/ISSUE_TEMPLATE/`) が持つ。GitHub の側に入れる設定は無い。確かめ方は、Issue を新しく作る画面を開き、3 本のフォームだけが選べることと、必須の項目が空だと送れないことを見る。送信はしない。GitHub にログインした画面でしか見られないので、オーナーが見る。

結果 (2026-10-08): オーナーが Issue を新しく作る画面のスクリーンショットを示し、「問題なさそう」と報告した。

| 確かめたこと | 結果 |
|---|---|
| 選べるフォーム | `Bug report`・`Feature request`・`Question` の 3 本が並ぶ (スクリーンショットで確認) |
| 空の Issue | 管理する側 (オーナーと共同作業者) の画面にだけ、`Blank issue` の行が `Maintainers only` の印つきで出る。見たのはオーナーの画面である |
| 必須の項目が空だと送れない | オーナーの報告による。作業を進めたエージェントの側は、画面を見ていない |

`Blank issue (Maintainers only)` の行は、管理する側 (オーナーと共同作業者) の画面にだけ出る。GitHub の仕様で、設定では消せない。空の Issue を作れなくする指定 (`blank_issues_enabled: false`) は入っていて、管理する側を除いて、空の Issue は作れない。外から来た人に 3 本のフォームを使ってもらう受け口には影響しないので、オーナーがこの形に合意した。管理する側でない人の画面は見ていない。

## 必須の検査を足すとき

`main` の必須の検査を足すときは、検査が実際に報告されるのを見てから、保護に登録する。次の順で行う。GitHub への操作は、1 つずつオーナーの承認を得てから行い、実行したコマンドと読み直しの結果を証跡に残す。

| 順 | 行うこと | この順にする理由 |
|---|---|---|
| 1 | 検査を足した実装を `develop` に push し、検証 CI が成功することを確かめる。足した検査が push で走らない形なら、走らないことも確かめる | `develop` の検証が壊れたまま、`main` 宛ての Pull Request を作らない |
| 2 | `develop` から `main` 宛ての Pull Request を作り、足した検査が報告されることと、名前が決めたとおりであることを確かめる | 検査の名前は、実際に報告されて初めて確かめられる。この時点では、保護はまだ前の検査だけを必須にしているので、名前が違っていても Pull Request は止まらない |
| 3 | `main` の保護の必須の検査を更新し、読み直して確かめる (上の「main の保護」)。ほかの保護の値は変えない。`develop` の保護も読み直して、変わっていないことを確かめる | 名前が食い違ったまま登録すると、登録した名前の検査が報告されず、Pull Request をマージできなくなる |
| 4 | 足した検査を含めて、すべての必須の検査が成功した状態で、Pull Request を merge commit でマージする | 足した検査を通った内容だけが `main` に入る |

先に保護へ登録してから Pull Request を作る順にはしない。名前が食い違っていたとき、その Pull Request が止まる。

戻し方: 保護の必須の検査を、前の値で PUT し直す。必須の検査を外しても、検査そのものは走り続ける。

### 実施の結果 (利用者の立場のビルドの確認の 2 つを足したとき、2026-10-09)

| 順 | 結果 |
|---|---|
| 1 (`develop` への push) | `lint` (18 秒)・`ios / verify` (2 分 36 秒)・`android / verify` (4 分 50 秒) の 3 つだけが走り、どれも成功した。利用者の立場のビルドの確認の 2 つのジョブ (`consumer-ios`・`consumer-android`) は、条件により飛ばされた (skipped)。ランナーは起きていない |
| 2 (Pull Request で報告された名前) | Pull Request 2 番で、5 つが決めたとおりの名前で報告され、どれも成功した。検査の一覧には、同じ commit に対する push の実行の結果も並ぶ。そちらの 2 つは SKIPPED で、名前に ` / verify` が付かない (`consumer-ios`・`consumer-android`)。保護に登録する名前は、Pull Request の実行が報告した ` / verify` の付くほうである |
| 3・4 (保護の更新とマージ) | 必須の検査を 3 つから 5 つに更新し、読み直して確かめた。ほかの保護の値と、`develop` の保護は変わらなかった。更新の後も、Pull Request 2 番は MERGEABLE・CLEAN のままだった。5 つの検査が成功した commit のまま、merge commit でマージした (06:10:44 UTC)。`main` の先端は merge commit になり、`develop` の先端は変わらない |

## 実施の記録

2026-10-08 の行の証跡は、`kasane/changes/archive/2026-10-08-public-repo-verify-ci/evidence/publication-log.md` にある。表の「証跡」の列には、その中の節の番号を書く。それより後の行は、証跡のファイルの場所を書く。

| 行ったこと | 日付 | 証跡 |
|---|---|---|
| リポジトリの作成と `main` の push | 2026-10-08 | 7.1 |
| public への切り替え | 2026-10-08 | 7.2 |
| 機能・検査・通知・Pull Request を作れる人の設定 | 2026-10-08 | 7.3 |
| `develop` の push と、最初の検証 CI の成功 | 2026-10-08 | 7.4 |
| `main` と `develop` の保護 | 2026-10-08 | 7.5 |
| `develop` から `main` への最初の Pull Request のマージ | 2026-10-08 | 7.6 |
| Issue のフォームの確認 | 2026-10-08 | 7.7 |
| 利用者の立場のビルドの確認の 2 つを、`main` の必須の検査に足した (3 つから 5 つ) | 2026-10-09 | `kasane/changes/archive/2026-10-09-package-distribution/evidence/public-repository-checks.md` |

`develop` の最初の検証 CI は、1 回目の実行で `ios / verify` だけが失敗し、iOS をビルドだけにした後 (iOS のテストの実行を CI から外した後) の 2 回目の実行で、当時の 3 つの検査がすべて成功した ([検証 CI](verification-ci.md))。保護は、2 回目の成功の後に入れた。

## 関連

- [cross/ADR-0010](../../decisions/cross/0010-develop-and-main-branch-roles.md) — ブランチを 2 本に分けた決定
- [cross/ADR-0011](../../decisions/cross/0011-contributions-via-issues-no-external-pull-requests.md) — 外部からの Pull Request を受け付けない決定
- [cross/ADR-0009](../../decisions/cross/0009-publish-existing-history-as-is.md) — 履歴を書き換えずに公開した決定
- [cross/ADR-0014](../../decisions/cross/0014-ci-reusable-platform-workflows-and-fixed-check-names.md) — 検証 CI の構成と、必須の検査の名前を固定した決定
- [cross/ADR-0016](../../decisions/cross/0016-consumer-build-check-on-main-pull-requests.md) — 配布物を利用者役でビルドして確かめ、必須の検査にする決定
- [検証 CI](verification-ci.md) — 5 つの検査の中身と、失敗したときの見方
- [利用者の立場のビルドの確認](consumer-build-check.md) — `main` 宛ての Pull Request でだけ走る 2 つの検査の、手元での流し方と失敗の見方
- [ローカル開発環境と Sample の実行](local-development-setup.md) — clone の後の準備と、手元の検査の有効化

出典: kasane/changes/archive/2026-10-08-public-repo-verify-ci/design.md (Decision 8・9) / kasane/changes/archive/2026-10-08-public-repo-verify-ci/evidence/publication-log.md (公開の実施と読み直しの記録) / kasane/changes/archive/2026-10-08-public-repo-verify-ci/deviation.md (管理する側の画面にだけ出る空の Issue の行) / ../KsSettingsView/kasane/handbook/cross/release-procedure.md (保護の payload の形と `app_id`) / kasane/changes/archive/2026-10-09-package-distribution/design.md (Decision 8) / kasane/changes/archive/2026-10-09-package-distribution/evidence/public-repository-checks.md (必須の検査を 5 つにした更新と読み直しの記録)
