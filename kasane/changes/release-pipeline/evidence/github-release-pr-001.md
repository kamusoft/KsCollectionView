# リリースの Pull Request (tasks 10.7)

日付: 2026-10-15 / 承認: オーナーがチャットで、変更の節の文面を確定し、commit・push・リリースの Pull Request の作成・必須の検査の成功と先端の照合の後のマージを指示 / 手順: drafts/release-procedure.md の「リリースのたびに行うこと」の 2・3

## 変更の節 (オーナーが確定した文面)

```markdown
## Changes

- feature: First public beta release for iOS (Swift Package Manager) and Android (Maven Central)
```

- 範囲 (`main` へ新しく持ち込む commit): 769bb85 (README のインストールの節の段落の削除・Skill と手順の草稿の 1 文・開発の記録)。初回の決まりで、初めての公開であることを 1 行で書いた。README の段落の削除は、この 1 行に含まれるので行にしていない
- 本文: `## Summary` (`Release 0.1.0-beta.1.`)・`## Changes`・`## Notes` (署名の行)
- 出した後の本文を GitHub から読み直し、リリースノートの読み方 (`parse_changes`) で `feature` の 1 行・読めない行 0 と読めた

## Pull Request とマージ

- Pull Request: https://github.com/kamusoft/KsCollectionView/pull/4 (`develop` → `main`、題 `Release 0.1.0-beta.1`)
- 対象の commit: 769bb852cc2e8b3752f0cae0a6015108617857e8 (commit と push の後の `origin/develop` の先端。push の前に手元と `origin/develop` が揃っていることを確かめた)

| 必須の検査 | 結果 | 所要 |
|---|---|---|
| `lint` | pass | 30 秒 |
| `ios / verify` | pass | 2 分 1 秒 |
| `android / verify` | pass | 5 分 15 秒 |
| `consumer-ios / verify` | pass | 1 分 42 秒 |
| `consumer-android / verify` | pass | 3 分 19 秒 |

(同じ commit への `develop` の push の検証 CI の `lint`・`ios / verify`・`android / verify` も、同じ名前で一覧に出て、どれも pass)

| 読んだ項目 | 期待する値 | 読んだ値 |
|---|---|---|
| `headRefOid` | 対象の commit | 769bb852cc2e8b3752f0cae0a6015108617857e8 (一致) |
| `mergeable`・`mergeStateStatus` | `MERGEABLE`・`CLEAN` | `MERGEABLE`・`CLEAN` |
| `isCrossRepository` | `false` | `false` |

```bash
gh pr merge 4 --repo kamusoft/KsCollectionView --merge --match-head-commit 769bb852cc2e8b3752f0cae0a6015108617857e8
```

| マージの後 | 読んだ値 |
|---|---|
| merge commit (`origin/main`) | df659f24e39f3129816bd9d9673b1bfb364d4da5 (2026-10-15T11:04:31Z、`Merge pull request #4 from kamusoft/develop`) |
| `origin/main^1` | 36ca60b628dae1aa913fc9af6b2ec81d58850517 (#3 のマージ) |
| `origin/main^2` | 769bb852cc2e8b3752f0cae0a6015108617857e8 (対象の commit と一致) |

`main` を `develop` へ取り込み直していない。tasks 10.7 は完了。本番 (10.9) の起動は、`origin/main` の先端 df659f2 で行う。
