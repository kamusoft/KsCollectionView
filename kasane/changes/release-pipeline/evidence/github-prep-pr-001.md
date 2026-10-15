# 準備の Pull Request (tasks 10.2)

日付: 2026-10-15 / 承認: オーナーがチャットで、記録の commit と push・準備の Pull Request の作成を指示 (マージの前に一度止まる) / 手順: drafts/release-procedure.md の「初回だけ行うこと」の 6

- Pull Request: https://github.com/kamusoft/KsCollectionView/pull/3 (`develop` → `main`、題 `Add the release workflow`)
- 対象の commit: d8ec4c19fb25b513daf21c7552fd78423a264637 (`origin/develop` の先端。記録の commit を push した後)
- 本文: `## Summary` (workflow を既定のブランチに入れる)・`## Changes` (`- none`)・`## Notes` (署名の行)

## 本文の確かめ

出す前に、本文をリリースノートの組み立ての読み方 (`scripts/release/build-release-notes.py` の `parse_changes`) で読んだ。

| 本文 | 読んだ結果 |
|---|---|
| 変更の節の `- none` の後ろに、見出しを置かずに署名の行を足した形 | 「`- none` とほかの行が混ざっている」で止まる |
| 署名の行を `## Notes` の見出しの下に移した形 (出した本文) | 利用者向けの変更なし (読めない行 0) |

本文の末尾に付ける署名の行が、見出しを置かないと変更の節の読めない行になる。Skill と草稿に 1 文を足した (deviation.md の付随修正)。

## 必須の検査 (マージの前)

```bash
gh pr checks 3 --repo kamusoft/KsCollectionView --required --json name,bucket,startedAt,completedAt
gh pr view 3 --repo kamusoft/KsCollectionView --json headRefOid,mergeable,mergeStateStatus,isCrossRepository
```

| 必須の検査 | 結果 | 所要 |
|---|---|---|
| `lint` | pass | 32 秒 |
| `ios / verify` | pass | 4 分 12 秒 |
| `android / verify` | pass | 5 分 23 秒 |
| `consumer-ios / verify` | pass | 1 分 18 秒 |
| `consumer-android / verify` | pass | 2 分 29 秒 |

| 読んだ項目 | 期待する値 | 読んだ値 |
|---|---|---|
| `headRefOid` | 対象の commit | d8ec4c19fb25b513daf21c7552fd78423a264637 (一致) |
| `mergeable`・`mergeStateStatus` | `MERGEABLE`・`CLEAN` | `MERGEABLE`・`CLEAN` |
| `isCrossRepository` | `false` | `false` |

マージは、オーナーの指示でこの時点で止めている。

## マージと手動の起動 (承認: オーナーがチャットで、先端が d8ec4c1 のときだけ merge commit でマージすることを指示)

```bash
gh pr merge 3 --repo kamusoft/KsCollectionView --merge --match-head-commit d8ec4c19fb25b513daf21c7552fd78423a264637
git fetch origin
git rev-parse origin/main origin/main^1 origin/main^2
gh workflow view release.yml --repo kamusoft/KsCollectionView
gh workflow view release.yml --repo kamusoft/KsCollectionView --ref main --yaml
```

| 確かめたこと | 期待する値 | 読んだ値 |
|---|---|---|
| マージ | merge commit | 36ca60b628dae1aa913fc9af6b2ec81d58850517 (2026-10-15T10:30:49Z、`Merge pull request #3 from kamusoft/develop`) |
| `origin/main^1` | マージの前の `main` | f2c14738337531a4a1be0ac4038a062e08b24e11 (#2 のマージ) |
| `origin/main^2` | 対象の commit | d8ec4c19fb25b513daf21c7552fd78423a264637 (一致) |
| workflow `Release` | 既定のブランチで手動の起動ができる | `Release - release.yml` (ID 385406920、`active`、run 0 件)。`main` の定義の起動は `workflow_dispatch` だけで、入力は `version` (必須の文字列)・`dry-run` (真偽、既定は偽) |

`main` を `develop` へ取り込み直していない (決まりどおり)。tasks 10.2 は完了。
