# 証跡: 公開リポジトリでの確認と保護の更新 (tasks グループ 9)

GitHub への操作は、それぞれオーナーの承認を得てから指揮側が行った。時刻は UTC。

## 9.1 develop への push (2026-10-09)

オーナーの承認: 実装を commit して `develop` に push することを、指揮側が行う形で承認 (2026-10-09)。

実行したコマンド:

```
git push origin develop
```

- push した範囲: `c29b598..6e420a7` (提案の commit `192a10b` と、実装の commit `6e420a7` の 2 つ)
- 起動した実行: workflow `CI`、実行の番号 37890909399、起動の種類 push、対象の commit `6e420a7`

読み直したコマンド:

```
gh run view 37890909399 --json status,conclusion,jobs
```

| ジョブ | 結果 | 開始 | 終了 | 所要 |
|---|---|---|---|---|
| `lint` | success | 05:55:40 | 05:55:58 | 18 秒 |
| `ios / verify` | success | 05:55:47 | 05:58:23 | 2 分 36 秒 |
| `android / verify` | success | 05:55:52 | 06:00:42 | 4 分 50 秒 |
| `consumer-ios` | skipped | — | — | — |
| `consumer-android` | skipped | — | — | — |

- 実行の全体の結果は success。走ったのは 3 つの検査だけで、利用者の立場のビルドの確認の 2 つのジョブは、条件 (Pull Request で起動したときだけ) により飛ばされた。ランナーは起きていない
- `lint` が成功したので、スクリプトのテスト (写しを作る道具のテストを含む 262 件) が Linux のランナーの上でも通ることが分かった

## 9.2 main 宛ての Pull Request (2026-10-09)

オーナーの承認: `develop` から `main` 宛ての Pull Request を作ることを承認 (2026-10-09。マージは含まない)。

実行したコマンド:

```
gh pr create --repo kamusoft/KsCollectionView --base main --head develop --title "配布物の設定と利用者の立場のビルドの確認を追加" --body-file <本文のファイル>
```

- できた Pull Request: 2 番 (`develop` → `main`。対象の commit `6e420a7`)
- 起動した実行: workflow `CI`、実行の番号 37891421543、起動の種類 pull_request

読み直したコマンド:

```
gh run view 37891421543 --json status,conclusion,event,headSha,jobs
gh pr view 2 --repo kamusoft/KsCollectionView --json mergeable,mergeStateStatus,isCrossRepository,statusCheckRollup
```

| 検査の名前 | 結果 | 開始 | 終了 | 所要 |
|---|---|---|---|---|
| `lint` | success | 06:01:51 | 06:02:08 | 17 秒 |
| `ios / verify` | success | 06:01:59 | 06:06:03 | 4 分 4 秒 |
| `android / verify` | success | 06:01:51 | 06:06:53 | 5 分 2 秒 |
| `consumer-ios / verify` | success | 06:01:57 | 06:03:55 | 1 分 58 秒 |
| `consumer-android / verify` | success | 06:01:51 | 06:05:07 | 3 分 16 秒 |

- 5 つの検査が、決めたとおりの名前で報告された。変更したパスによる絞り込みは無く、5 つとも走った
- 実行の全体の結果は success。Pull Request の状態は `mergeable` が MERGEABLE、`mergeStateStatus` が CLEAN、`isCrossRepository` が false
- Pull Request の検査の一覧には、同じ commit に対する push の実行 (9.1) の結果も並ぶ。そちらの `consumer-ios`・`consumer-android` は SKIPPED で、名前に ` / verify` が付かない。必須の検査に登録する名前は、Pull Request の実行が報告した `consumer-ios / verify`・`consumer-android / verify` である
- 利用者の立場のビルドの確認がランナーの上で走ったのは、これが初めてである。どちらも、時間の上限 (暫定の 15 分) に対して十分に短い

## 9.3 main の保護の必須の検査を 5 つに更新 (2026-10-09)

オーナーの承認: `main` の保護の必須の検査に 2 つを足して 5 つにすることを承認 (2026-10-09)。

更新の前に読んだ値 (`gh api repos/kamusoft/KsCollectionView/branches/main/protection`):

| 読む項目 | 値 |
|---|---|
| `required_status_checks.strict` | false |
| `required_status_checks.checks` | 3 件。`context` が `lint`・`ios / verify`・`android / verify`、`app_id` がどれも 15368 |
| `enforce_admins.enabled` | false |
| `required_pull_request_reviews` | 承認の必要数 0、`dismiss_stale_reviews`・`require_code_owner_reviews`・`require_last_push_approval` は false |
| `allow_force_pushes.enabled`・`allow_deletions.enabled` | どちらも false |
| `required_linear_history`・`required_signatures`・`required_conversation_resolution`・`lock_branch`・`block_creations`・`allow_fork_syncing` の `enabled` | どれも false |

実行したコマンド (PUT は部分の更新にならないので、項目をすべて書いて送った。必須の検査の配列のほかは、前の値と同じ):

```
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

更新の後に読み直した値 (同じコマンド):

| 読む項目 | 値 |
|---|---|
| `required_status_checks.strict` | false (変わらない) |
| `required_status_checks.checks` | 5 件。`context` が `lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify`、`app_id` がどれも 15368 |
| そのほかの項目 | 更新の前と同じ (応答から URL の項目を除いて、必須の検査のほかを前後で突き合わせ、一致した) |

`develop` の保護 (`gh api repos/kamusoft/KsCollectionView/branches/develop/protection`) は、更新の前後で読み、一致した。必須の検査と Pull Request の必須は無く、強制 push と削除は禁止、管理者には強制しない設定のままである。

更新の後の Pull Request 2 番の状態は、`mergeable` が MERGEABLE、`mergeStateStatus` が CLEAN (5 つの検査が成功済みなので、必須を足してもマージできる状態のまま)。

## 9.4 Pull Request のマージ (2026-10-09)

オーナーの承認: Pull Request 2 番を merge commit で `main` にマージすることを承認 (2026-10-09)。

マージの直前に読んだ状態 (`gh pr view 2 --json mergeable,mergeStateStatus,headRefOid`): `mergeable` が MERGEABLE、`mergeStateStatus` が CLEAN、先端の commit は `6e420a7` (5 つの検査が成功した commit と同じ)。

実行したコマンド:

```
gh pr merge 2 --repo kamusoft/KsCollectionView --merge
```

読み直した値 (`gh pr view 2 --json state,mergedAt,mergeCommit,baseRefName,headRefName`・`git log origin/main -1`・`git ls-remote origin develop main`):

| 読む項目 | 値 |
|---|---|
| Pull Request の状態 | MERGED (06:10:44) |
| merge commit | `f2c1473`。親は 2 つで、前の `main` の先端 `479fcdc` と、`develop` の先端 `6e420a7` |
| `main` の先端 | `f2c1473` |
| `develop` の先端 | `6e420a7` (変わらない。ブランチは消していない) |

- `main` には、5 つの必須の検査が成功した `develop` が、merge commit で入った
- マージの後に、`main` への push で起動した実行は無い (検証 CI の起動の対象は `develop` への push と `main` 宛ての Pull Request)

## 9.5 利用者の立場のビルドの確認の時間の上限 (2026-10-09)

ランナーでの所要時間 (9.2 の実行 37891421543):

| workflow | ジョブ | 所要 | 今の上限 |
|---|---|---|---|
| `verify-consumer-ios.yml` | `consumer-ios / verify` | 1 分 58 秒 | 15 分 |
| `verify-consumer-android.yml` | `consumer-android / verify` | 3 分 16 秒 | 15 分 |

判断: 2 本とも、上限は 15 分のまま変えない。

- 測れたのは 1 回だけで、どちらも依存のキャッシュが無い状態の最初の実行である。ばらつきはまだ分からない
- 既存の 2 つの検証の workflow も、上限は 15 分である (同じ実行での実測は 4 分 4 秒と 5 分 2 秒)。利用者の立場の確認の実測はそれより短く、同じ上限にしておけば、4 つの検証の上限が揃う
- 外部の依存の取得 (Nuke・Maven の依存) に頼るので、取得が遅い日の余裕を残す。上限を詰めて得るものは、止まった実行が早く切れることだけである
- 値を変えないので、次の `main` 宛ての Pull Request で入れる変更は無い

## 補足: 利用者の立場のビルドの確認の、ランナーの記録から読んだ値 (2026-10-09)

9.2 の実行 37891421543 の 2 つのジョブの記録を、後から読み直した (読み取りだけ。`gh run view 37891421543 --json jobs`・`gh run view --job <ジョブの番号> --log`)。あわせて、9.3 の PUT は終了コード 0 で入った。

`consumer-ios / verify` (ランナー `xcode-27`):

| 読む項目 | 値 |
|---|---|
| 選ばれた Xcode | Xcode 27.0 (Build version 27A266a) |
| Swift | Apple Swift version 6.4 |
| `python3` の版 | Python 3.14.8 |
| step `Verify consumer` | 06:02:07〜06:03:50 (1 分 43 秒) |
| Simulator 向けのビルド | 06:02:08 に開始、06:03:13 に `** BUILD SUCCEEDED **` (約 1 分 5 秒。Nuke の取得を含む) |
| 実機向けのビルド | 06:03:13 に開始、06:03:50 に `** BUILD SUCCEEDED **` (約 37 秒) |

`consumer-android / verify` (ランナー `ubuntu-24.04`):

| 読む項目 | 値 |
|---|---|
| JDK | openjdk 21.0.12.1 |
| `python3` の版 | Python 3.12.3 |
| Gradle のキャッシュの復元 | 無かった (`Cache not found`。このキーでの最初の実行) |
| Android SDK の platform | ランナーにあった (`Android SDK Platform 36 はランナーにある`)。取得する枝は通っていない |
| 本体の発行 | 06:01:56 に開始、`BUILD SUCCESSFUL in 1m 34s` |
| 利用者役のリリースの組み立て (コード縮小あり) | 06:03:31 に開始、`BUILD SUCCESSFUL in 1m 26s` |
| 実行時の依存の確認 | `jp.kamusoft:kscollectionview:0.1.0-SNAPSHOT` が現れた |
| Gradle のキャッシュの保存 | 保存された (`Cache saved`) |

確かめていないこと: 保存したキャッシュが次の実行で復元されること (復元される実行がまだ無い)。Android SDK の platform を取得する枝。
