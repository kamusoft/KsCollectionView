> **草稿の扱い (蒸留のときに、この囲みごと消す)**
>
> - 置き先の案: `kasane/handbook/cross/branch-and-github-settings.md` (新設)
> - index に足す行の案: 適用のきっかけ「`develop` へ push するとき・`main` 宛ての Pull Request を作る / マージするとき・GitHub のリポジトリの設定やブランチの保護を変える / 確かめ直すとき」、種別 guide
> - 文書の中のリンクは、置き先から見た相対パスで書いてある (この草稿の場所からは辿れない)
> - GitHub のリポジトリは 2026-10-08 に作り、public にした。「入れ方と確かめ方」のコマンドと結果は、公開の実施の記録 (`evidence/publication-log.md`) にある、実行したものに合わせてある。草稿の案と違う形で実行したものは、実行したほうに直した
> - 実行していないコマンドは、実行していないと分かるように書いてある (値が最初から決めたとおりで、入れる必要が無かったもの)。フラグの名前は手元の `gh` 2.102.0 のヘルプで確かめただけである
> - 保護の payload の形と `app_id` は、兄弟ライブラリの手順 (`../KsSettingsView/kasane/handbook/cross/release-procedure.md`) から取り、実行して読み直した
> - `【公開の実施後に記入】` の印は、すべて埋めた。残る印は、蒸留で埋める `【蒸留で置く日】`・`【蒸留の日付】` だけである
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
2. Pull Request を作る: `gh pr create --repo kamusoft/KsCollectionView --base main --head develop --title <タイトル> --body-file <本文のファイル>`
3. 3 つの必須の検査 (`lint`・`ios / verify`・`android / verify`) が成功で終わるのを待ち、マージできる状態を読む: `gh pr view <番号> --json mergeable,mergeStateStatus,isCrossRepository`
4. merge commit でマージする: `gh pr merge <番号> --repo kamusoft/KsCollectionView --merge` (ブランチの削除の指定は付けない)
5. 手元の `main` を GitHub の `main` まで早送りする: `git fetch origin main:main`

`main` 宛ての Pull Request では、変更したパスに関わらず 3 つの検査が走る。`lint` は、出どころが同じリポジトリの `develop` であることを確かめ、結果を step `Pull request head restriction` の記録に出す。`develop` 以外のブランチや、別のリポジトリから作った Pull Request は、ここで落ちる。

最初の Pull Request (1 番、2026-10-08) は、先端の commit が `kasane/` の下だけを変えたものだったが、3 つの検査が走って成功した。step の記録には `出どころは kamusoft/KsCollectionView の develop` と出た。状態は `MERGEABLE`・`CLEAN` で、マージの後に `main` への push による検証の実行は作られなかった。`develop` はマージの後も残っている。

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

Pull Request を作れる人の設定は、API では `pull_request_creation_policy` という項目で、値は `collaborators_only` である。

### 保護の値

| 項目 | `main` | `develop` |
|---|---|---|
| Pull Request の必須 | 必須。承認の必須の数は 0 | なし (直接 push を受ける) |
| 必須の検査 | `lint`・`ios / verify`・`android / verify`。GitHub Actions が出したものに限る | なし |
| 強制 push | 禁止 | 禁止 |
| 削除 | 禁止 | 禁止 |
| 管理者への強制 | しない | しない |
| `main` の最新を取り込んでいないとマージできない (`strict`) | しない | — |
| 古い承認の取り消し・コードオーナーの承認 | どちらもしない | — |
| push できる人の限定 | なし | なし |

下の 3 行は design の表に無い値で、兄弟ライブラリと同じにした (オーナーに示して承認を得た)。

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
gh repo create kamusoft/KsCollectionView --private
git remote set-url origin <GitHub の SSH の URL>
git push origin main
```

公開のときは、作成の後に読んだ時点で HTTPS の形の remote `origin` があった (作成のコマンドが足したのか、手で足したのかは確かめていない)。`origin` が無ければ `git remote add origin <URL>` で足す。オーナーの希望で、SSH の形 (GitHub の SSH の URL。ホストは `github.com`、パスは `kamusoft/KsCollectionView.git`) に変えてから push した。

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

入れる前にいまの値を読み、上の表と違う値だけを入れる。2026-10-08 に実行したのは、値が違っていた 4 つ (Projects・Pull Request を作れる人・secret の検査・push の保護) を変える次の 3 つである。

```bash
gh repo edit kamusoft/KsCollectionView --enable-projects=false
gh api -X PATCH repos/kamusoft/KsCollectionView -f pull_request_creation_policy=collaborators_only
gh api -X PATCH repos/kamusoft/KsCollectionView --input - <<'JSON'
{"security_and_analysis":{"secret_scanning":{"status":"enabled"},"secret_scanning_push_protection":{"status":"enabled"}}}
JSON
```

secret の検査と push の保護は、1 回の PATCH で 2 つとも `enabled` になった。Pull Request を作れる人の制限は、Pull Request の機能そのものは有効のまま、作れる人だけを絞る設定である (機能を無効にすると、`main` 宛ての Pull Request も作れなくなる)。

既定のブランチ・Issues・Wiki・Discussions・依存の脆弱性の通知は、最初から決めた値だったので、入れるコマンドは実行していない (`gh repo create --private` で作って public に切り替えた場合)。

確かめ方: 次の 3 つを読み直し、上の表と突き合わせる。

```bash
gh api repos/kamusoft/KsCollectionView
gh api repos/kamusoft/KsCollectionView/vulnerability-alerts
gh api repos/kamusoft/KsCollectionView/labels
```

1 つ目は `visibility`・`default_branch`・`has_issues`・`has_wiki`・`has_discussions`・`has_projects`・`pull_request_creation_policy`・`security_and_analysis` を読む。依存の脆弱性の通知は、有効なら 2 つ目の応答が 204 になる。ラベルは 3 つがあることを確かめる。

結果 (2026-10-08): 読み直した値は、すべて表と一致した。

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

結果 (2026-10-08): 終了コード 0 で入り、読み直した値は渡した値とすべて同じだった。

| 項目 | 読み直した値 |
|---|---|
| Pull Request の必須 | `required_pull_request_reviews` が置かれている。承認の必須の数は 0 |
| 必須の検査 | 3 件。名前と `app_id` (15368) が渡した値と同じ |
| 強制 push・削除・管理者への強制 | どれも false |
| `strict` | false |
| 古い承認の取り消し・コードオーナーの承認 | どちらも false |
| push できる人の限定 | 無い |

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
| 空の Issue | 管理する側 (オーナー) の画面には、`Blank issue` の行が `Maintainers only` の印つきで出る |
| 必須の項目が空だと送れない | オーナーの報告による。指揮側は画面を見ていない |

`Blank issue (Maintainers only)` は、管理する側の画面にだけ出る GitHub の表示で、空の Issue を作れなくする指定 (`blank_issues_enabled: false`) は効いている。管理する側でない人の画面は見ていない。

## 実施の記録

| 行ったこと | 日付 | 証跡 |
|---|---|---|
| リポジトリの作成と `main` の push | 2026-10-08 | 出典の変更の `evidence/publication-log.md` の 7.1 |
| public への切り替え | 2026-10-08 | 出典の変更の `evidence/publication-log.md` の 7.2 |
| 機能・検査・通知・Pull Request を作れる人の設定 | 2026-10-08 | 出典の変更の `evidence/publication-log.md` の 7.3 |
| `develop` の push と、最初の検証 CI の成功 | 2026-10-08 | 出典の変更の `evidence/publication-log.md` の 7.4 |
| `main` と `develop` の保護 | 2026-10-08 | 出典の変更の `evidence/publication-log.md` の 7.5 |
| `develop` から `main` への最初の Pull Request のマージ | 2026-10-08 | 出典の変更の `evidence/publication-log.md` の 7.6 |
| Issue のフォームの確認 | 2026-10-08 | 出典の変更の `evidence/publication-log.md` の 7.7 |

`develop` の最初の検証 CI は、1 回目の実行で `ios / verify` だけが失敗し、iOS をビルドだけにした後の 2 回目の実行で 3 つとも成功した ([検証 CI](verification-ci.md))。保護は、2 回目の成功の後に入れた。

## 関連

- [cross/ADR-0010](../../decisions/cross/0010-develop-and-main-branch-roles.md) — ブランチを 2 本に分けた決定
- [cross/ADR-0011](../../decisions/cross/0011-contributions-via-issues-no-external-pull-requests.md) — 外部からの Pull Request を受け付けない決定
- [cross/ADR-0009](../../decisions/cross/0009-publish-existing-history-as-is.md) — 履歴を書き換えずに公開した決定
- [検証 CI](verification-ci.md) — 3 つの検査の中身と、失敗したときの見方
- [ローカル開発環境と Sample の実行](local-development-setup.md) — clone の後の準備と、手元の検査の有効化

出典: kasane/changes/archive/【蒸留の日付】-public-repo-verify-ci/design.md (Decision 8・9) / 同 evidence/publication-log.md (公開の実施と読み直しの記録) / ../KsSettingsView/kasane/handbook/cross/release-procedure.md (保護の payload の形と `app_id`)
