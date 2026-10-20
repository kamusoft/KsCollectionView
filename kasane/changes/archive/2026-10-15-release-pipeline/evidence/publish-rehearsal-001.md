# 公開のジョブの前半の手元の通し (レビュー 001 の提案) — 1 回目

実行した日: 2026-10-15 / 対象: 修正サイクル 1 の作業ツリー (HEAD c764358 と、`android/` の未 commit の変更) / 環境: macOS、JDK 21、手元の Android SDK (Platform 36 あり)、GnuPG 2.5

`publish` の前半 (`Build signed publication`・`Check signed publication`) は試しでは飛ばされ、初回の本番で初めて動く。取り消せない公開の前に、同じ組み立てを手元で一度通した。Maven Central と Central Portal には何も送っていない (送るタスク `publishToMavenCentral` は流していない。認証の情報も渡していない)。

## 準備

| 項目 | したこと |
|---|---|
| 署名の鍵 | 使い捨ての鍵を、一時の `GNUPGHOME` (作業用のディレクトリ) で作った。RSA 3072・署名用・期限 1 日・パスフレーズつき (パスフレーズは乱数で作り、ファイルにだけ置いた)。鍵は ASCII armor で書き出した |
| 2 つの組み立ての場所 | 本リポジトリを、作業用のディレクトリの別々の 2 つのパスへ `git clone` し、それぞれに `android/` の未 commit の変更 (`git diff HEAD -- android`) を当てた。`package-android` と `publish` が別のランナーで組み立てる形の代わり |
| 渡した値 | 版 `0.1.0-beta.1`、元の commit は HEAD の ID (40 桁) |
| Gradle | `--no-daemon --console=plain`。Gradle の利用者のディレクトリは手元のもの (依存と Gradle の本体は取得済みのものを使った。ランナーは毎回取得するので、所要時間はランナーより短い) |

鍵の値・パスフレーズ・鍵の ID は、この証跡に書かない。

## 結果

| 段 | コマンド (workflow の step と同じ形) | 結果 | 所要 |
|---|---|---|---|
| `package-android` の `Publish to working repository` | 1 つ目の clone の `android/` で `./gradlew --no-daemon --console=plain "-Dmaven.repo.local=<作業用>/android-maven" "-Pversion=0.1.0-beta.1" "-PksCollectionViewSourceCommit=<HEAD>" :kscollectionview:publishToMavenLocal` | BUILD SUCCESSFUL。28 タスクを実行し、署名のタスク (`signMavenPublication`) は SKIPPED (鍵を渡していない) | 7 秒 |
| `package-android` の `Check publication` | `python3 scripts/release/check-android-artifacts.py --version 0.1.0-beta.1 --reference <作業用>/android-maven --commit <HEAD>` | 終了コード 0 (5 ファイル) | 1 秒未満 |
| `publish` の `Build signed publication` | 2 つ目の clone の `android/` で、環境変数 `ORG_GRADLE_PROJECT_signingInMemoryKey`・`ORG_GRADLE_PROJECT_signingInMemoryKeyId` (`gpg --list-secret-keys --keyid-format short` の 8 桁)・`ORG_GRADLE_PROJECT_signingInMemoryKeyPassword` を付けて、`"-Dmaven.repo.local=<作業用>/signed-maven"` で同じコマンド | BUILD SUCCESSFUL。29 タスクを実行し、`signMavenPublication` が走った | 7 秒 |
| `publish` の `Check signed publication` | `python3 scripts/release/check-android-artifacts.py --version 0.1.0-beta.1 --reference <作業用>/android-maven --signed <作業用>/signed-maven --commit <HEAD>` | 終了コード 0。5 ファイル (AAR・POM・`.module`・sources・javadoc) がバイト単位で一致し、5 つの `.asc` がそろった | 1 秒未満 |
| 署名の検証 (追加) | `gpg --verify <ファイル>.asc <ファイル>` を 5 ファイルに | 5 つとも成功 (使い捨ての公開鍵で) | — |

分かったこと:

- 別々のパスの clone で組み立てた署名しない発行物と、署名して組み立て直した発行物は、バイト単位で一致した (手元の同じ機械で。別のランナーどうしでの一致は、まだ確かめていない)
- パスフレーズつきの鍵を ASCII armor の形で、鍵の ID を 8 桁の短い形で渡す署名を、公開のプラグインが受け付けた
- パスフレーズを誤ると、`signMavenPublication` が失敗し (`PGPException: checksum mismatch`)、Gradle が終了コード 1 で終わる。発行物は手元の Maven リポジトリに置かれない。確かめ方: 2 つ目の clone で、誤ったパスフレーズと `--rerun-tasks` を付けて同じコマンドを流した

## 同じ作業ツリーでの 2 回目の起動 (送る段の前提)

`publish` で実際に送るのは 3 回目の Gradle の起動 (`publishToMavenCentral`) の出力で、確かめた `signed-maven` と同じであることは、同じ作業ツリーで組み立ての成果物が up-to-date であることに依る (レビュー 001)。送るタスクは流せないので、近いものとして、署名した後の 2 つ目の clone で、`--rerun-tasks` を付けずに、誤ったパスフレーズで `publishToMavenLocal` をもう一度流した。

| 見たこと | 結果 |
|---|---|
| 組み立てと署名のタスク | `bundleReleaseAar`・`signMavenPublication` が UP-TO-DATE (署名のタスクは、鍵とパスフレーズを入力として見ていない)。POM の生成は再び走った |
| 置かれたもの | 1 回目の `signed-maven` と、`.asc` を含めて 10 ファイルすべてがバイト単位で同じ |

このことから、同じ作業ツリーの後の起動は、確かめたときの AAR と署名を作り直さずに使う見込みが高い。ただし `publishToMavenCentral` そのもの (送る束の組み立て) は流していないので、送った束の中身が `signed-maven` と同じことは確かめていない。また、署名のタスクが鍵を入力として見ないので、同じ作業ツリーで鍵を差し替えて流し直しても、前の署名が使われる (公開のジョブは毎回新しいランナーで走るので、この形にはならない)。

## 後片付け

使い捨ての鍵を置いた `GNUPGHOME` は、`gpgconf --kill all` で agent を止めてから `trash` で消した。2 つの clone・作業用の Maven リポジトリ・ログも `trash` で消した。`GNUPGHOME` は、agent のソケットのパスの長さの上限に当たったため、作業用のディレクトリを指す短いパスのシンボリックリンクを `/private/tmp/` の下に置いて使い、これも消した。
