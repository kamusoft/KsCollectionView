---
kind: guide
applies-when:
  always: false
  paths: ["scripts/distribution/**", "android/kscollectionview/build.gradle.kts", "android/gradle/libs.versions.toml", "ios/Package.swift"]
  tasks: [配布物を手元で作って確かめる, 配布物の中身・公開の設定の変更, 検証で使う Xcode の版の引き上げ]
title: 配布物の形と作り方
description: SwiftPM の写しと Android の発行物の中身、手元での作り方、マニフェストが要求する Swift のツールの版の決まり、確かめていないこと
timestamp: 2026-10-09
---

# 配布物の形と作り方

この文書は、利用者に届ける配布物 (SwiftPM の写しと、Android の Maven の発行物) が何でできているかと、手元でどう作るかをまとめる。配布物を作る道具や、Android の公開の設定を変えるときに読む。`ios/Package.swift` が要求する Swift のツールの版の決まりも、ここに置く。

配布物を利用者と同じ書き方で取ってビルドする確認は、[利用者の立場のビルドの確認](consumer-build-check.md) が持つ。

実際に公開する工程 (配信用リポジトリへの写しの送信と、そこに付ける版を表す tag・Maven Central への送信) は、この文書の範囲の外である。2026-10-09 時点では、まだ作っていない。SwiftPM を配信用の別リポジトリから配る理由は [cross/ADR-0015](../../decisions/cross/0015-swiftpm-via-distribution-repository.md) にある。

## 配布物の全体

| プラットフォーム | 配布物 | 利用者の書き方 | 作るもの |
|---|---|---|---|
| iOS | 配信用リポジトリ `kamusoft/KsCollectionView-SPM` のルートに置く、本体の写し | package `KsCollectionView-SPM` の product `KsCollectionView` に依存する | `scripts/distribution/sync-spm-snapshot.py` |
| Android | Maven の発行物 `jp.kamusoft:kscollectionview` | `implementation("jp.kamusoft:kscollectionview:<版>")` の 1 行 | `android/kscollectionview/build.gradle.kts` の公開の設定 |

iOS の利用者がマニフェストに書く 2 行 (Package URL と product への依存) は、[公開識別子と配布座標](public-identifiers.md) にある。

Sample は、両プラットフォームとも本体のソースを直接参照する。Sample がビルドできても、配布物が正しいことは言えない。配布物は、[利用者の立場のビルドの確認](consumer-build-check.md) が確かめる。

## Swift のツールの版は、検証で確かめている Xcode の版に合わせる

`ios/Package.swift` が要求する Swift のツールの版 (先頭の行の `// swift-tools-version:`) は、検証で確かめている Xcode の版に合わせる。Xcode の版を上げるときは、マニフェストの宣言も同じ変更の中で上げる。

2026-10-09 時点で、検証 (手元と検証 CI) が使う Xcode は 27.0 (Swift 6.4) で、宣言は `// swift-tools-version: 6.4` である。写しのマニフェストは同じ内容なので、利用者は Xcode 27 以上でなければ依存を解決できない。

宣言を、確かめていない古い版のままにしない。宣言はそのまま利用者に届き、「この版のツールから使える」という約束になる。古い版でビルドできるかは確かめていないので、宣言と確認を一致させておく。宣言が合っていれば、古い Xcode の利用者は、依存を解決する時点で理由が分かる。

Xcode の版を上げるときに、同時に直す場所:

| 直す場所 | 中身 |
|---|---|
| `.github/workflows/verify-ios.yml`・`verify-consumer-ios.yml` の `KS_XCODE_VERSION` | 検証 CI が選ぶ Xcode の版。メジャーとマイナーを文字列で書く (2026-10-09 時点で `"27.0"`)。2 本は同じ値にする (ずれると、スクリプトのテストが落ちる) |
| `ios/Package.swift` の先頭の行 | 要求する Swift のツールの版 |
| `scripts/ci/tests/test_sync_spm_snapshot.py` の `ManifestTest` | マニフェストの先頭の行が、決めた宣言と一致することを確かめるテスト。期待する値を同時に直す |
| `verification/ios/Package.swift.template` の先頭の行 | 利用者役のマニフェストの宣言。本体と同じ版に揃えてある |

宣言だけを変えると、`ManifestTest` が落ちる。このテストは、スクリプトのテストの 1 つで、検証 CI の `lint` の中で毎回走る。手元では、リポジトリのルートで `python3 scripts/ci/run-tests.py` を流すと、スクリプトのテストがすべて走る ([検証 CI](verification-ci.md) の「手元で確かめる」)。テストが縛るのは宣言の文字だけで、宣言と検証 CI の Xcode の版が対応していることは、機械では確かめていない。上の表を見て、人が揃える。

## SwiftPM の写し

SwiftPM は、git のリポジトリのルートにあるマニフェストしか解決できない。本リポジトリのマニフェストは `ios/` の下にあるので、ルートに置く形の写しを作って配る。

### 中身

写しは、次の 5 点だけでできている。

| 写しの中の場所 | 元 |
|---|---|
| `Package.swift` | `ios/Package.swift` (内容を変えない) |
| `Sources/` | `ios/Sources/` のうち、git が追跡しているファイル |
| `Tests/` | `ios/Tests/` のうち、git が追跡しているファイル |
| `LICENSE` | ルートの `LICENSE` |
| `README.md` | `scripts/distribution/spm-readme.template.md` (本リポジトリへ案内する英語の固定文) |

2026-10-09 時点の写しは、141 ファイル (`Sources/` 93・`Tests/` 45・直下の 3)、展開した状態で約 1.7 MB である。

### 作り方

```bash
python3 scripts/distribution/sync-spm-snapshot.py <行き先のディレクトリ>
```

成功すると、「写しを作った: <行き先> (Sources N ファイル / Tests M ファイル)」と出る。終了コードは、0 が成功、1 が失敗 (下の表の確認のどれかを満たさなかった、または写している途中で失敗した)、2 が引数の誤りである。

道具は、行き先の中身を `.git` を除いて消してから、5 点を置く。消す前に次を確かめ、1 つでも満たさなければ、行き先を作りも消しもせずに終了コード 1 で終わる。そのときは、`エラー: ` に続けて理由が出る。

| 確かめること | 満たさないときの出力 (`エラー: ` の後ろ) |
|---|---|
| 元の 5 点がすべてある。追跡しているのに作業ツリーに無いファイルも、欠けとして数える | `写しの元が欠けている:` |
| 行き先が、本リポジトリの中でも、本リポジトリを含むディレクトリでもない | `行き先がこのリポジトリの中にある:`・`行き先がこのリポジトリを含むディレクトリである:` |
| 行き先が、ディレクトリか、まだ無いパスである | `行き先がディレクトリではない:` |
| 行き先が、まだ無いパスか、空のディレクトリか、配信用リポジトリの作業コピーである | `行き先に中身があり、配信用リポジトリ (…) の作業コピーでもない:` |
| 行き先が作業コピーなら、その git の管理情報の場所が、行き先そのものでも、消す対象 (行き先の直下の `.git` 以外) の中でもない | `行き先の git の管理情報の場所が、行き先そのものである:`・`行き先の git の管理情報が、消す対象の中にある:` |

道具は commit・push・tag をしない。写した結果は、行き先の作業ツリーの変更として残る。ネットワークは使わない。

### 行き先にできる作業コピー

中身のある行き先は、配信用リポジトリの作業コピーだけを受け付ける。作業コピーと認めるのは、行き先が git の最上位で、`origin` が `github.com` の `kamusoft/KsCollectionView-SPM` を指すものである。`origin` は、次の 3 つの形を受け付ける。末尾の `/` と `.git` の有無は問わない。

- `https://github.com/kamusoft/KsCollectionView-SPM`
- `ssh://git@github.com/kamusoft/KsCollectionView-SPM`
- `git@github.com:kamusoft/KsCollectionView-SPM`

| 作業コピーの形 | 扱い |
|---|---|
| git の管理情報を、行き先の直下の `.git` に置いた形 (ふつうの clone) | 受け付ける |
| 管理情報を行き先の外に置いた形 (`.git` が外を指すファイルになっている。worktree など) | 受け付ける |
| `.git` が、行き先の中の別のディレクトリを指す形 (`git init --separate-git-dir` で、管理情報を行き先の中に置いた形) | 拒否する。`.git` だけを残して消すと、commit と tag が消える |
| 管理情報 (`HEAD`・`objects` など) が行き先の直下に並び、`.git` が行き先自身を指す形 | 拒否する (同じ理由) |

この確認が見るのは、git の管理ディレクトリと、共通の管理ディレクトリ (worktree で commit と tag を持つ側) の場所だけである。通常の clone・worktree でない構成は確かめない。オブジェクトの借用先 (`objects/info/alternates`) や、管理ディレクトリの中のシンボリックリンクが、行き先の中を指す作業コピーが該当する。そういう作業コピーを渡すと、道具は成功を報告するが、行き先の commit を読めなくなることがある。そのときは、配信用リポジトリから clone し直す。

### 知っておくこと

- **道具が自分で作った写しには、2 回目を流せない。** まだ無いパスに作った写しは git のリポジトリではないので、同じ行き先への 2 回目は拒否される。作り直すときは、行き先のディレクトリを消してから流す
- **写すのは、作業ツリーにある今の内容である。** 追跡しているファイルの、commit していない変更も写る。追跡していないファイル (手元のビルドの出力など) は写らない
- commit した内容だけの写しが要るときは、変更の無い作業ツリーで流す
- `origin` は、git の設定に書かれた値をそのまま読む。利用者の設定 (`insteadOf`) で書き換えた後の値では比べない
- 道具は、git を呼ぶ前に、git の場所を外から固定する環境変数 (`GIT_DIR`・`GIT_WORK_TREE` など) を外す。hook の中から呼ばれても、呼び出し元のリポジトリではなく行き先を読む
- 写しの中で依存を解決したりビルドしたりすると、写しの中に `.build/` と `Package.resolved` ができる。配信用リポジトリに送る写しでは、解決もビルドもしない

写しをルートにして SwiftPM が読めることは、写しの中で `swift package describe` と `swift package resolve` を流して確かめられる (2026-10-09 に成功。名前 `KsCollectionView`・Tools version 6.4・Nuke は 13.2.0 に解決)。

## Android の発行物

公開の設定は、`com.vanniktech.maven.publish` プラグインで組んである (版はバージョンカタログ `android/gradle/libs.versions.toml` の `maven-publish`)。

### 中身

出すのは release の 1 種類である。座標の場所 (`jp/kamusoft/kscollectionview/<版>/`) に、次の 5 点ができる。名前はどれも `kscollectionview-<版>` で始まる。

| 発行物 | 中身 (2026-10-09 の実測) |
|---|---|
| `.aar` | 約 449 KB。コード縮小の規則のファイルは入っていない |
| `-sources.jar` | 約 132 KB |
| `-javadoc.jar` | 中身は空 (Maven Central が求めるので置いている。IDE は sources jar からコメントを表示できる) |
| `.pom` | 名前・説明・URL・開始年・MIT License・開発者 (`kamusoft`)・リポジトリの場所を持つ |
| `.module` | Gradle のメタデータ。variant は API・実行時・ソースの 3 つ |

署名の鍵を渡すと、5 点それぞれに `.asc` が付く。AAR の中身は、版と鍵の有無で変わらない。

### 依存の範囲

| 範囲 | 依存 (2026-10-09) |
|---|---|
| 依存の管理 (import) | Compose の BOM |
| compile | Compose の runtime・ui・foundation-layout、Coil の Compose 連携、androidx の annotation (1.9.1)、Kotlin の標準ライブラリ |
| runtime | Compose の foundation・animation-core・animation・material3、androidx の startup-runtime、Coil の OkHttp 連携 |

公開 API の宣言に現れる外部の型は、すべて利用者の compile の範囲に届く。2026-10-09 に、ソースと AAR のバイトコードの両方から型を洗い出して突き合わせた。公開 API に現れる型を増やしたら、この突き合わせをやり直す。利用者の立場のビルドの確認は、利用者役が触る API の範囲でしか、宣言の漏れを見つけられない。

突き合わせで見るものは、次の 3 つである。洗い出した型の一覧と、使ったコマンドの記録は、`kasane/changes/archive/2026-10-09-package-distribution/evidence/android-publishing.md` の「公開 API に現れる外部の型と、依存の範囲の突き合わせ」にある。

| 見るもの | 見方 |
|---|---|
| 公開の宣言に現れる外部の型 | ソースの `public`・`protected` の宣言と、発行した AAR の `classes.jar` (`javap` で読む) の両方から拾う。値クラス (`Dp`・`Color`) はバイトコードでは基本の型に置き換わるので、ソースの側でしか拾えない |
| 型を持つ成果物の、POM での範囲 | 発行した `.pom` の依存が、compile の範囲にその成果物を持つか、compile にある依存がそれを届けるかを見る |
| 利用する側の compile のクラスパスに届く版 | 本ライブラリに依存するプロジェクトの、リリースの compile のクラスパスの依存の木を読む。利用者役なら `:app:dependencies --configuration releaseCompileClasspath` |

`Color`・`Dp` を持つ成果物 (`ui-graphics`・`ui-unit`) は、POM に名前では現れない。compile にある Compose UI (`ui`) が、自分の API の依存として届ける。Compose UI への依存を `api` から外すと、これらの型が利用者に届かなくなる。

`@DrawableRes` を持つ `androidx.annotation:annotation` は、Compose の BOM の対象の外なので、版 (1.9.1) をバージョンカタログに持ち (キーは `androidx-annotation`)、compile の範囲に直接宣言している。1.9.1 は、宣言を足す前に Compose UI を通って利用者の compile のクラスパスに届いていた版と同じである。Compose の BOM を上げたときは、Compose UI を通って届く版を確かめ、食い違っていたら合わせる。確かめ方は、上の表の 3 行目である。依存の木で、Compose UI とその先の依存が求めている `androidx.annotation:annotation` の版を読む (2026-10-09 時点で、求められている版の最大は 1.9.1)。この宣言の形 (annotation だけを直接宣言し、`ui-graphics`・`ui-unit` は Compose UI に任せる) は、兄弟ライブラリ KsSettingsView と同じである。

Coil の Compose 連携は、公開 API に型が現れないが、利用者が直接使う前提で compile の範囲に置いている ([core/ADR-0012](../../decisions/core/0012-image-loader-direct-dependency.md))。外さない。

### 手元のディレクトリへ発行する

`android/` で、手元への発行のタスクに、発行先のディレクトリを渡して流す。

```bash
ANDROID_HOME=<Android SDK の場所> ./gradlew -Dmaven.repo.local=<発行先のディレクトリ> :kscollectionview:publishToMavenLocal
```

`-Dmaven.repo.local` は、Maven の手元のリポジトリの場所を上書きするシステムプロパティである。確認のスクリプトも同じ名前を使う (`scripts/ci/verify-consumer-android.py` の定数 `LOCAL_REPOSITORY_PROPERTY`)。`ANDROID_HOME` の前置きは、そのビルドルートに `local.properties` があれば要らない。

発行する側と、発行物を取る側では、渡すものが違う。確認のスクリプト ([利用者の立場のビルドの確認](consumer-build-check.md)) を通せば、どちらも自分で渡さずに済む。

| 側 | 渡すもの | 意味 |
|---|---|---|
| 発行する側 (`android/`) | Maven のシステムプロパティ `-Dmaven.repo.local=<ディレクトリ>` | 手元への発行のタスクが、発行物を置くディレクトリ |
| 取る側 (利用者役 `verification/android/`) | Gradle のプロパティ `-PksCollectionViewRepository=<ディレクトリ>` | 利用者役が `jp.kamusoft` を取りに行くディレクトリ。発行する側に渡したのと同じ場所を渡す |

- **`-Dmaven.repo.local` を付け忘れると、利用者の既定の手元の Maven リポジトリ (`~/.m2/repository`) に発行される。** 手元の環境に発行物が残り、後で誤って参照し得る。確かめるための発行は、必ず発行先を渡す
- 忘れて発行してしまったときは、`~/.m2/repository/jp/kamusoft/kscollectionview/` を消す
- 版は、`-Pversion=<版>` で外から渡せる。渡さなければ、バージョンカタログの版 (2026-10-09 時点で `0.1.0-SNAPSHOT`) になる
- 署名の鍵が無ければ、署名は飛ばされる (`signMavenPublication SKIPPED`)。鍵を Gradle のプロパティ `signingInMemoryKey` で渡すと署名が付く。環境変数なら `ORG_GRADLE_PROJECT_signingInMemoryKey` で渡せる
- `android/local.properties` に SDK の場所を書いてあれば、`ANDROID_HOME` の前置きは要らない ([ローカル開発環境と Sample の実行](local-development-setup.md))

### 開発中の版は Maven Central へ送れない

版が `-SNAPSHOT` で終わるあいだは、名前に `MavenCentral` を含むタスク (取り下げ用の `dropMavenCentralDeployment` を除く) を含むビルドが、どのタスクも動き出す前に失敗する。開発中の版を誤って公開しないための仕組みで、ビルドファイルが持つ。出力に「開発中の版 (…) は Maven Central へ送れない」と出る。手元への発行は止まらない。

2026-10-09 に、`:kscollectionview:publishToMavenCentral`・`:kscollectionview:publishAndReleaseToMavenCentral`・`:kscollectionview:publish` の 3 つで、止まることを確かめた。`publish` は、名前に `MavenCentral` を含むタスクに依存するので、同じく止まる。

認証の情報 (`mavenCentralUsername`・`mavenCentralPassword`) が無い環境では、Gradle 自身も、同じ時点で認証の情報の不足を報告して止まる。2 つの理由は並んで出る。認証の情報の不足だけを見て、この仕組みが効いていないと読まない。

### 署名を手元で試すとき

使い捨ての鍵で署名の経路を試すときの要点は、次のとおり。2026-10-09 に試したときの鍵の作り方と結果の記録は、`kasane/changes/archive/2026-10-09-package-distribution/evidence/android-publishing.md` の「使い捨ての鍵の扱い」にある。鍵を作るコマンドと、環境変数に入れる鍵の文字の形は、証跡に残っていないので、ここには書いていない。

| 段 | 要点 |
|---|---|
| 鍵束を置く場所 | 環境変数 `GNUPGHOME` で、リポジトリの外の一時のディレクトリにする。利用者の既定の鍵束は使わない。短いパスにする (GnuPG は鍵束の場所の下にソケットを作り、パスが長いと鍵を作れない) |
| 作る鍵 | 試したのは、署名だけができる RSA 2048 ビット・パスフレーズなし・有効期間 1 日の鍵である |
| 鍵を Gradle に渡す | 環境変数 `ORG_GRADLE_PROJECT_signingInMemoryKey` で渡す。コマンドの引数と記録に、鍵の中身を出さない |
| 流すコマンド | 上の「手元のディレクトリへ発行する」と同じ。鍵があると、`signMavenPublication` が実行される |
| 署名を確かめる | 発行物の `.asc` を、同じ鍵束の公開鍵で検証する (`gpg --verify`)。試したときは、5 つとも検証できた |
| 後片付け | 鍵束のディレクトリごと消し、鍵束のための常駐のプロセスを止める |

## 確かめていないこと

2026-10-09 時点で、配布物を作る側について確かめていないことは次のとおり。利用者役でのビルドについては、[利用者の立場のビルドの確認](consumer-build-check.md) の「確かめた範囲と確かめていないこと」にある。

| 確かめていないこと | 分かっていること |
|---|---|
| 本物の配信用リポジトリの作業コピーを行き先にした写しの作成 | 配信用リポジトリは、まだ無い。作業コピーを行き先にした形は、道具のテストが使い捨ての git のリポジトリで確かめている |
| Maven Central への実際の送信と、Maven Central の側の検査 (署名・POM の項目・javadoc jar) | 送信は 1 回も行っていない |
| 本番の形の署名 (パスフレーズつきの鍵・鍵の ID を指定する形) | 確かめたのは、パスフレーズなしの使い捨ての鍵を `signingInMemoryKey` だけで渡す形である |
| Gradle の configuration cache を有効にしたときの、開発中の版を Maven Central へ送らせない仕組みの動き | このビルドは有効にしていない |
| Xcode 27.0 以外での写しのビルド、Windows での道具の実行 | 対象にしていない |

写しを作る道具のテスト (31 件) は、macOS の手元のほかに、Linux のランナーの上でも通っている (2026-10-09。検証 CI の `lint` の中のスクリプトのテスト 262 件に含まれる)。

## 関連

- [cross/ADR-0015](../../decisions/cross/0015-swiftpm-via-distribution-repository.md) — SwiftPM を配信用の別リポジトリから配る決定
- [core/ADR-0012](../../decisions/core/0012-image-loader-direct-dependency.md) — Coil の Compose 連携を利用者に届ける決定
- [利用者の立場のビルドの確認](consumer-build-check.md) — 配布物を利用者役でビルドして確かめる流し方と、失敗したときの見方
- [検証 CI](verification-ci.md) — スクリプトのテストと、5 つの検査が走る時点
- [公開識別子と配布座標](public-identifiers.md) — Maven の座標と、SwiftPM の package の名前
- [ローカル開発環境と Sample の実行](local-development-setup.md) — Android SDK の場所の渡し方

出典: kasane/changes/archive/2026-10-09-package-distribution/design.md (Decision 1・2) / kasane/changes/archive/2026-10-09-package-distribution/proposal.md (マニフェストの宣言を、確かめている版に合わせて上げる変更) / kasane/changes/archive/2026-10-09-package-distribution/evidence/ios-manifest-and-spm-snapshot.md (写しの中身・大きさ・拒否される行き先) / kasane/changes/archive/2026-10-09-package-distribution/evidence/android-publishing.md (発行物・POM・依存の範囲の突き合わせ・開発中の版を送らせない仕組み・使い捨ての鍵)