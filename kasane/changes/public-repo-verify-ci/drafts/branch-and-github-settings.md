> **草稿の扱い (蒸留のときに、この囲みごと消す)**
>
> - 置き先の案: `kasane/handbook/cross/branch-and-github-settings.md` (新設)
> - index に足す行の案: 適用のきっかけ「`develop` へ push するとき・`main` 宛ての Pull Request を作る / マージするとき・GitHub のリポジトリの設定やブランチの保護を変える / 確かめ直すとき」、種別 guide
> - 文書の中のリンクは、置き先から見た相対パスで書いてある (この草稿の場所からは辿れない)
> - GitHub のリポジトリは、この草稿を書いた時点でまだ作られていない。`gh` のコマンドは、どれも本リポジトリに対しては実行していない。フラグの名前は手元の `gh` 2.102.0 のヘルプで確かめ、保護の payload の形と `app_id` は兄弟ライブラリの手順 (`../KsSettingsView/kasane/handbook/cross/release-procedure.md`) から取った
> - 実行した結果・読み直しの結果を書く箇所は、`【公開の実施後に記入】` の印を付けて空けてある。tasks 7・8 の後に指揮側が埋める。コマンドを変えて実行したときは、コマンドの側も実行したものに直す
> - `timestamp` は、蒸留で置く日にする

---
kind: guide
applies-when:
  always: false
  tasks: [develop への push, main 宛ての Pull Request の作成とマージ, GitHub のリポジトリの設定の変更・確認, ブランチの保護の変更・確認]
title: ブランチの運用と GitHub の設定
description: develop と main の役割、develop への push と main 宛ての Pull Request の進め方、GitHub のリポジトリの設定とブランチの保護の値・入れ方・確かめ方
timestamp: 【蒸留で置く日】
---

# ブランチの運用と GitHub の設定

この文書は、公開リポジトリ `kamusoft/KsCollectionView` の 2 本のブランチをどう使うかと、GitHub の側に入れてある設定の値・入れ方・確かめ方をまとめる。日々の push と、`main` 宛ての Pull Request は、ここに書いた順で進める。設定を変えるとき・入れ直すときも、ここの値を正とする。

ブランチを 2 本に分けた理由は [cross/ADR-0010](../../decisions/cross/0010-develop-and-main-branch-roles.md) にある。検証 CI の中身は [検証 CI](verification-ci.md) が持つ。

## ブランチの役割

| ブランチ | 先端が表すもの | 入れ方 | 検証 CI |
|---|---|---|---|
| `develop` | 開発の最新 | 直接 push する | push の後に走る (事後の検証) |
| `main` | リリース候補。リポジトリの既定のブランチ | 同じリポジトリの `develop` からの Pull Request だけ | Pull Request で走り、3 つの検査が必須 |

`develop` の検証は事後なので、壊れた状態が `develop` に載り得る。失敗を見て `develop` の上で直す。

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
2. Pull Request を作る: `gh pr create --base main --head develop --title <タイトル> --body <本文>`
3. 3 つの必須の検査 (`lint`・`ios / verify`・`android / verify`) が成功で終わるのを待つ: `gh pr checks <番号> --watch`
4. merge commit でマージする: `gh pr merge <番号> --merge`

`main` 宛ての Pull Request では、変更したパスに関わらず 3 つの検査が走る。`lint` は、出どころが同じリポジトリの `develop` であることを確かめ、結果を step `Pull request head restriction` の記録に出す。`develop` 以外のブランチや、別のリポジトリから作った Pull Request は、ここで落ちる。

マージの方法は merge commit に決めてある。squash と rebase は使わない (`develop` の commit がそのまま `main` に入り、節目が merge commit として残る)。

管理者は `main` と `develop` の保護を迂回できる設定にしてある。開発者が 1 人で、ランナーの不調などで必須の検査が止まったときの逃げ道が要るためである。ランナー `xcode-27` は public preview で、止まったときに `main` 宛ての Pull Request を進める手段は、この迂回だけになる。

## GitHub の設定の値

入れてある値は次のとおり。値を変えるときは、先にこの表を直す。

| 設定 | 値 |
|---|---|
| 公開の範囲 | public |
| 既定のブランチ | `main` |
| Issues | 有効 |
| Wiki・Discussions・Projects | 無効 |
| Pull Request を作れる人 | 共同作業者だけ |
| secret の検査・push の保護・依存の脆弱性の通知 | 有効 |
| ラベル | `bug`・`enhancement`・`question` がある (Issue のフォームが付ける) |
| `main` の保護 | 下の節 |
| `develop` の保護 | 下の節 |

### 保護の値

| 項目 | `main` | `develop` |
|---|---|---|
| Pull Request の必須 | 必須。承認の必須の数は 0 | なし (直接 push を受ける) |
| 必須の検査 | `lint`・`ios / verify`・`android / verify`。GitHub Actions が出したものに限る | なし |
| 強制 push | 禁止 | 禁止 |
| 削除 | 禁止 | 禁止 |
| 管理者への強制 | しない | しない |

必須の検査の名前は、検証 CI のジョブの名前と一致していなければならない。再利用 workflow を呼ぶジョブの検査の名前は「呼ぶ側のジョブの名前 / 呼ばれる側のジョブの名前」になる。ジョブの名前を変える・検査を足すときは、保護の側も同時に直す。

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

設定は `gh` のコマンドで入れ、入れた直後に同じ項目を読み直して、上の表と突き合わせる。画面からは入れない (入れた値の記録が残らず、入れ忘れに気付きにくい)。

### リポジトリの作成と最初の push

```bash
gh repo create kamusoft/KsCollectionView --private --source . --remote origin
git push origin main
```

`--push` は付けない (付けると、手元の commit がまとめて push される)。push の前の検査 (`.githooks/pre-push`) は、まだどの remote にも無い commit をすべて検査するので、最初の push では全履歴が対象になる。

確かめ方: GitHub の `main` の先端が、手元と同じ commit の ID であること。

```bash
git rev-parse main
gh api repos/kamusoft/KsCollectionView/git/ref/heads/main --jq .object.sha
```

結果: 【公開の実施後に記入: 実行した日・2 つの ID が一致したこと】

### 公開の範囲

```bash
gh repo edit kamusoft/KsCollectionView --visibility public --accept-visibility-change-consequences
```

確かめ方: `gh api repos/kamusoft/KsCollectionView --jq .visibility` が `public` を返すこと。

結果: 【公開の実施後に記入】

### 機能・検査・通知・Pull Request を作れる人

```bash
gh repo edit kamusoft/KsCollectionView \
  --default-branch main \
  --enable-issues \
  --enable-wiki=false \
  --enable-discussions=false \
  --enable-projects=false
gh repo edit kamusoft/KsCollectionView --enable-secret-scanning
gh repo edit kamusoft/KsCollectionView --enable-secret-scanning-push-protection
gh api -X PUT repos/kamusoft/KsCollectionView/vulnerability-alerts
gh api -X PATCH repos/kamusoft/KsCollectionView -f pull_request_creation_policy=collaborators_only
```

push の保護は、secret の検査を有効にした後でないと有効にできないので、2 回に分ける。Pull Request を作れる人の制限は、Pull Request の機能そのものは有効のまま、作れる人だけを絞る設定である (機能を無効にすると、`main` 宛ての Pull Request も作れなくなる)。

確かめ方:

```bash
gh api repos/kamusoft/KsCollectionView --jq '{visibility, default_branch, has_issues, has_wiki, has_discussions, has_projects, pull_request_creation_policy, security_and_analysis}'
gh api repos/kamusoft/KsCollectionView/vulnerability-alerts --silent && echo enabled
gh label list --repo kamusoft/KsCollectionView --json name --jq '.[].name'
```

依存の脆弱性の通知は、有効なら 2 つ目のコマンドが成功で終わる (無効なら失敗で終わる)。ラベルは 3 つがあることを確かめる。Issue のフォームは、無いラベルを自分では作らないので、欠けていたら `gh label create <名前> --repo kamusoft/KsCollectionView` で作る。

結果: 【公開の実施後に記入: 読み直した値と表の突き合わせ。新しいリポジトリに 3 つのラベルが最初からあったか】

### main の保護

保護は、項目をすべて書いた payload を PUT する。PUT は部分の更新にならず、書かなかった項目は消える。

```bash
gh api -X PUT repos/kamusoft/KsCollectionView/branches/main/protection --input - <<'JSON'
{
  "required_status_checks": {
    "strict": false,
    "checks": [
      { "context": "lint", "app_id": 15368 },
      { "context": "ios / verify", "app_id": 15368 },
      { "context": "android / verify", "app_id": 15368 }
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

確かめ方: `gh api repos/kamusoft/KsCollectionView/branches/main/protection` を読み直し、次を表と突き合わせる。

| 読む項目 | 期待する値 |
|---|---|
| `required_status_checks.checks` | 3 件。`context` が `lint`・`ios / verify`・`android / verify`、`app_id` がどれも 15368 |
| `required_pull_request_reviews.required_approving_review_count` | 0 |
| `enforce_admins.enabled` | false |
| `allow_force_pushes.enabled` | false |
| `allow_deletions.enabled` | false |

結果: 【公開の実施後に記入】

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

結果: 【公開の実施後に記入】

### Issue のフォーム

Issue のフォームと、空の Issue を作れなくする指定は、リポジトリのファイル (`.github/ISSUE_TEMPLATE/`) が持つ。GitHub の側に入れる設定は無い。確かめ方は、Issue を新しく作る画面を開き、3 本のフォームだけが選べることと、必須の項目が空だと送れないことを見る。送信はしない。

結果: 【公開の実施後に記入】

## 実施の記録

| 行ったこと | 日付 | 証跡 |
|---|---|---|
| リポジトリの作成と `main` の push | 【公開の実施後に記入】 | 【公開の実施後に記入: 証跡のファイル】 |
| public への切り替え | 【公開の実施後に記入】 | 【公開の実施後に記入】 |
| 機能・検査・通知・Pull Request を作れる人の設定 | 【公開の実施後に記入】 | 【公開の実施後に記入】 |
| `develop` の push と、最初の検証 CI の成功 | 【公開の実施後に記入】 | 【公開の実施後に記入】 |
| `main` と `develop` の保護 | 【公開の実施後に記入】 | 【公開の実施後に記入】 |
| `develop` から `main` への最初の Pull Request のマージ | 【公開の実施後に記入】 | 【公開の実施後に記入】 |

## 関連

- [cross/ADR-0010](../../decisions/cross/0010-develop-and-main-branch-roles.md) — ブランチを 2 本に分けた決定
- [cross/ADR-0011](../../decisions/cross/0011-contributions-via-issues-no-external-pull-requests.md) — 外部からの Pull Request を受け付けない決定
- [cross/ADR-0009](../../decisions/cross/0009-publish-existing-history-as-is.md) — 履歴を書き換えずに公開した決定
- [検証 CI](verification-ci.md) — 3 つの検査の中身と、失敗したときの見方
- [ローカル開発環境と Sample の実行](local-development-setup.md) — clone の後の準備と、手元の検査の有効化

出典: kasane/changes/archive/【蒸留の日付】-public-repo-verify-ci/design.md (Decision 8・9) / ../KsSettingsView/kasane/handbook/cross/release-procedure.md (保護の payload の形と `app_id`)
