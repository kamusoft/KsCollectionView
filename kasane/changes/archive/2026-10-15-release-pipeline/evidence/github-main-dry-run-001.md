# main からの試し (tasks 10.8)

日付: 2026-10-15 / 承認: オーナーがチャットで、版 0.1.0-beta.1 で main からの試しを指示 / 手順: drafts/release-procedure.md の「試し」 / 起動した commit: df659f24e39f3129816bd9d9673b1bfb364d4da5 (`origin/main` の先端。#4 の merge commit)

## 起動の前の外の状態

本リポジトリの tag `0.1.0-beta.1` 無し・配信用リポジトリは空・Release 無し (0 件)・Maven Central の POM は 404。

## run

```bash
gh workflow run release.yml --repo kamusoft/KsCollectionView --ref main -f version=0.1.0-beta.1 -f dry-run=true
```

run: https://github.com/kamusoft/KsCollectionView/actions/runs/38724949662 (結論 `success`、11:06:15〜11:12:42Z、約 6 分 30 秒)

| ジョブ | 結果 | 所要 |
|---|---|---|
| `validate` | success | 9 秒 |
| `verify-ios / verify` | success | 3 分 8 秒 |
| `verify-android / verify` | success | 6 分 15 秒 |
| `package-ios` | success | 8 秒 |
| `package-android` | success | 2 分 4 秒 |
| `consumer-ios / verify` | success | 1 分 30 秒 |
| `consumer-android / verify` | success | 3 分 13 秒 |
| `publish`・`wait-for-registries`・`smoke-ios`・`smoke-android`・`check-release` | skipped | — |

`validate` の出力 (ログの「出力:」の行):

| 出力 | 値 | 読み |
|---|---|---|
| `version` | `0.1.0-beta.1` | |
| `production` | `false` | 試し |
| `on-main` | `true` | main からの起動 |
| `main-tag`・`spm-tag` | `absent`・`absent` | 両リポジトリに同じ名前の tag が無い |
| `published` | `false` | Maven Central に未公開 |
| (ログ) | `範囲の起点: main の最初 / Pull Request: #1, #2, #3, #4` | 前回の Release が無いので main の最初から。範囲の 4 本を読んだ |
| `built` | `true` | ノートを組み立てた (`Upload release notes` は success) |

## 組み立てたリリースノート (artifact `release-notes`、244 バイト)

```markdown
### Features

- First public beta release for iOS (Swift Package Manager) and Android (Maven Central) (#4)
```

- #1〜#3 は `- none` なので載らず、#4 の確定した 1 行だけが「Features」に入った。オーナーが確定した文面と一致する
- validate のジョブの権限は `contents: read` だけで、GitHub の API で範囲の Pull Request (#1〜#4) の本文を読めた (tasks 2・4 の実装で「実物でしか確かめられない」としていた点)
- artifact: `release-notes` (244 バイト)・`spm-snapshot` (380,729 バイト)・`android-maven` (579,663 バイト)

## 起動の後の外の状態

起動の前と同じ (本リポジトリの tag 無し・配信用リポジトリは空・Release 0 件・POM は 404)。外へは何も送っていない。tasks 10.8 は完了。
