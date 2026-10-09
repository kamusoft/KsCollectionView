> **草稿の扱い (蒸留のときに、この囲みごと消す)**
>
> - 置き先の案: `kasane/handbook/cross/package-distribution.md` (新設)
> - index に足す行の案: 適用のきっかけ「`scripts/distribution/`・`verification/`・Android の公開の設定・`ios/Package.swift` の宣言を触るとき・配布物を手元で作って確かめるとき・利用者の立場のビルドの確認の失敗を調べるとき」、種別 guide
> - 文書の中のリンクは、置き先から見た相対パスで書いてある (この草稿の場所からは辿れない)
> - 中身は、2026-10-09 時点の実物 (`scripts/distribution/`・`scripts/ci/verify-consumer-*.py`・`verification/`・`android/kscollectionview/build.gradle.kts`) と、手元での確認の記録 (`evidence/` の 5 枚) から書いた
> - 公開リポジトリでの確認 (tasks のグループ 9) は、この草稿を書いた時点ではまだ行っていない。ランナーの上での値が要る箇所は `【公開の実施後に記入】` の印で空けてある。蒸留の前に、グループ 9 の証跡から埋める
> - 冒頭のリンク先の cross/ADR-0015・0016 は、書いた時点では proposed である。蒸留で accepted にしてから置く
> - 手元への発行の発行先を変えるシステムプロパティの名前は、本文に続けて書いていない。続けて書くと、識別の lint (`scripts/identity-lint.py`) がホスト名と判定して書き込みを止める。名前を持つ定数 (`scripts/ci/verify-consumer-android.py` の `LOCAL_REPOSITORY_PROPERTY`) を指す形にしてある。配信用リポジトリの origin の形も、同じ理由で、SSH の形の URL を文字のまま書いていない。蒸留で lint の側を直すなら、本文を値そのものに書き換えられる
> - `timestamp` は、蒸留で置く日にする

---
kind: guide
applies-when:
  always: false
  paths: ["scripts/distribution/**", "scripts/ci/verify-consumer-*.py", "verification/**", "android/kscollectionview/build.gradle.kts", "ios/Package.swift"]
  tasks: [配布物を手元で作って確かめる, 利用者の立場のビルドの確認の失敗の調査, 配布物の中身・公開の設定の変更]
title: 配布物の形と利用者の立場の確認
description: SwiftPM の写しと Android の発行物の中身、手元での作り方、利用者役で配布物を確かめる流し方、失敗したときの見方、確かめていないこと
timestamp: 【蒸留で置く日】
---

# 配布物の形と利用者の立場の確認

この文書は、利用者に届ける配布物 (SwiftPM の写しと、Android の Maven の発行物) が何でできているか、手元でどう作るか、利用者と同じ書き方で取ってビルドできることをどう確かめるかをまとめる。配布物を作る道具や公開の設定を変えるとき、利用者の立場のビルドの確認が落ちたときに読む。

実際に公開する工程 (配信用リポジトリへの送信・Maven Central への送信・tag) は、この文書の範囲の外である。2026-10-09 時点では、まだ作っていない。

SwiftPM を配信用の別リポジトリから配る理由は [cross/ADR-0015](../../decisions/cross/0015-swiftpm-via-distribution-repository.md) にある。配布物を専用の利用者役で確かめる理由と範囲は [cross/ADR-0016](../../decisions/cross/0016-consumer-build-check-on-main-pull-requests.md) にある。

## 配布物の全体

| プラットフォーム | 配布物 | 利用者の書き方 | 作るもの |
|---|---|---|---|
| iOS | 配信用リポジトリ `kamusoft/KsCollectionView-SPM` のルートに置く、本体の写し | package `KsCollectionView-SPM` の product `KsCollectionView` に依存する | `scripts/distribution/sync-spm-snapshot.py` |
| Android | Maven の発行物 `jp.kamusoft:kscollectionview` | `implementation("jp.kamusoft:kscollectionview:<版>")` の 1 行 | `android/kscollectionview/build.gradle.kts` の公開の設定 |

Sample は、両プラットフォームとも本体のソースを直接参照する。Sample がビルドできても、配布物が正しいことは言えない。配布物は、下の「利用者役で確かめる」の確認が確かめる。

`ios/Package.swift` は Swift 6.4 のツールを要求する (`// swift-tools-version: 6.4`)。写しのマニフェストは同じ内容なので、利用者は Xcode 27 以上でなければ依存を解決できない。宣言は、確かめている Xcode の版に合わせてある。

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

成功すると、「写しを作った: <行き先> (Sources N ファイル / Tests M ファイル)」と出る。終了コードは、0 が成功、1 が確認の外れか写している途中の失敗、2 が引数の誤りである。

道具は、行き先の中身を `.git` を除いて消してから、5 点を置く。消す前に次の 4 つを確かめ、1 つでも外れたら、行き先を作りも消しもせずに終了コード 1 で終わる。

| 確かめること | 外れたときの出力 (先頭) |
|---|---|
| 元の 5 点がすべてある。追跡しているのに作業ツリーに無いファイルも、欠けとして数える | `写しの元が欠けている:` |
| 行き先が、本リポジトリの中でも、本リポジトリを含むディレクトリでもない | `行き先がこのリポジトリの中にある:`・`行き先がこのリポジトリを含むディレクトリである:` |
| 行き先が、まだ無いパスか、空のディレクトリか、配信用リポジトリの作業コピーである | `行き先に中身があり、配信用リポジトリ (…) の作業コピーでもない:` |
| 行き先が作業コピーなら、その git の管理情報の場所が、行き先そのものでも、消す対象 (行き先の直下の `.git` 以外) の中でもない | `行き先の git の管理情報の場所が、行き先そのものである:`・`行き先の git の管理情報が、消す対象の中にある:` |

道具は commit・push・tag をしない。写した結果は、行き先の作業ツリーの変更として残る。ネットワークは使わない。

### 知っておくこと

- **道具が自分で作った写しには、2 回目を流せない。** まだ無いパスに作った写しは git のリポジトリではないので、同じ行き先への 2 回目は「git のリポジトリではない」で拒否される。作り直すときは、行き先のディレクトリを消してから流す
- **写すのは、作業ツリーにある今の内容である。** 追跡しているファイルの、commit していない変更も写る。追跡していないファイル (手元のビルドの出力など) は写らない。commit した内容だけの写しが要るときは、変更の無い作業ツリーで流す
- 作業コピーと認めるのは、行き先が git の最上位で、`origin` が `github.com` の `kamusoft/KsCollectionView-SPM` を指すものだけである。`origin` は、HTTPS の形と、SSH の 2 つの形 (`ssh://` で始まる形と、ホストとパスを `:` で区切る形) を受け付ける。末尾の `/` と `.git` の有無は問わない
- git の管理情報を行き先の直下の `.git` に置いた作業コピー (ふつうの clone) と、行き先の外に置いた作業コピー (`.git` が外を指すファイルになっている形。worktree など) は受け付ける。`.git` が行き先の中の別のディレクトリを指す形 (`git init --separate-git-dir` で管理情報を行き先の中に置いた形) は、`.git` だけを残して消すと commit と tag が消えるので、拒否する。管理情報 (`HEAD`・`objects` など) が行き先の直下に並び、`.git` が行き先自身を指す形も、同じ理由で拒否する
- **この確認が見るのは、git の管理ディレクトリと、共通の管理ディレクトリ (worktree で commit と tag を持つ側) の場所だけである。** 通常の clone・worktree でない構成 (オブジェクトの借用先 `objects/info/alternates` や、管理ディレクトリの中のシンボリックリンクが、行き先の中を指す作業コピーなど) は確かめない。そういう作業コピーを渡すと、道具は成功を報告するが、行き先の commit を読めなくなることがある。そのときは、配信用リポジトリから clone し直す
- `origin` は、git の設定に書かれた値をそのまま読む。利用者の設定 (`insteadOf`) で書き換えた後の値では比べない
- 道具は、git を呼ぶ前に、git の場所を外から固定する環境変数 (`GIT_DIR`・`GIT_WORK_TREE` など) を外す。hook の中から呼ばれるとこれらが設定されていて、外さないと、行き先ではなく呼び出し元のリポジトリを読んでしまう
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

公開 API の宣言に現れる外部の型は、すべて利用者の compile の範囲に届く。2026-10-09 に、ソースと AAR のバイトコードの両方から型を洗い出して突き合わせた。

`Color`・`Dp` を持つ成果物 (`ui-graphics`・`ui-unit`) は、POM に名前では現れない。compile にある Compose UI (`ui`) が、自分の API の依存として届ける。Compose UI への依存を `api` から外すと、これらの型が利用者に届かなくなる。

`@DrawableRes` を持つ `androidx.annotation:annotation` は、Compose の BOM の対象の外なので、版 (1.9.1) をバージョンカタログに持ち、compile の範囲に直接宣言している。1.9.1 は、宣言を足す前に Compose UI を通って利用者の compile のクラスパスに届いていた版と同じである。Compose の BOM を上げたときは、Compose UI を通って届く版を確かめ、食い違っていたら合わせる。この宣言の形 (annotation だけを直接宣言し、`ui-graphics`・`ui-unit` は Compose UI に任せる) は、兄弟ライブラリ KsSettingsView と同じである。

Coil の Compose 連携は、公開 API に型が現れないが、利用者が直接使う前提で compile の範囲に置いている ([core/ADR-0012](../../decisions/core/0012-image-loader-direct-dependency.md))。外さない。

### 手元のディレクトリへ発行する

`android/` で、手元への発行のタスクに、発行先のディレクトリを渡して流す。

```bash
ANDROID_HOME=<Android SDK の場所> ./gradlew <発行先の指定> :kscollectionview:publishToMavenLocal
```

`<発行先の指定>` は、Maven の手元のリポジトリの場所を上書きするシステムプロパティを `-D<名前>=<ディレクトリ>` で渡すものである。プロパティの名前は、`scripts/ci/verify-consumer-android.py` の定数 `LOCAL_REPOSITORY_PROPERTY` が持つ。

- **発行先の指定を忘れると、利用者の既定の手元の Maven リポジトリ (`~/.m2/repository`) に発行される。** 手元の環境に発行物が残り、後で誤って参照し得る。確かめるための発行は、必ず発行先を渡す
- 版は、`-Pversion=<版>` で外から渡せる。渡さなければ、バージョンカタログの版 (2026-10-09 時点で `0.1.0-SNAPSHOT`) になる
- 署名の鍵が無ければ、署名は飛ばされる (`signMavenPublication SKIPPED`)。鍵を Gradle のプロパティ `signingInMemoryKey` で渡すと署名が付く。環境変数なら `ORG_GRADLE_PROJECT_signingInMemoryKey` で渡せる
- `android/local.properties` に SDK の場所を書いてあれば、`ANDROID_HOME` の前置きは要らない ([ローカル開発環境と Sample の実行](local-development-setup.md))

### 開発中の版は Maven Central へ送れない

版が `-SNAPSHOT` で終わるあいだは、名前に `MavenCentral` を含むタスク (取り下げ用の `dropMavenCentralDeployment` を除く) を含むビルドが、どのタスクも動き出す前に失敗する。出力に「開発中の版 (…) は Maven Central へ送れない」と出る。手元への発行は止まらない。

認証の情報 (`mavenCentralUsername`・`mavenCentralPassword`) が無い環境では、Gradle 自身も、同じ時点で認証の情報の不足を報告して止まる。2 つの理由は並んで出る。認証の情報の不足だけを見て、歯止めが効いていないと読まない。

### 署名を手元で試すとき

使い捨ての鍵で署名の経路を試すときは、GnuPG の鍵束の場所 (`GNUPGHOME`) を、リポジトリの外の一時のディレクトリにする。

- 鍵束の場所は、短いパスにする。GnuPG は鍵束の場所の下にソケットを作り、パスが長いと鍵を作れない
- 鍵は環境変数で Gradle に渡し、コマンドの引数と記録に鍵の中身を出さない
- 確かめた後は、鍵束のディレクトリごと消し、鍵束のための常駐のプロセスを止める

## 利用者役で確かめる

利用者役は、配布物を利用者と同じ書き方で取る、最小のプロジェクトである。本体のソースを参照しない。

| プラットフォーム | 置き場 | 形 | 確かめること |
|---|---|---|---|
| iOS | `verification/ios/` | ライブラリの target を 1 つ持つ SwiftPM のパッケージ。一覧を 1 つ表示する | リリースの構成で、Simulator 向けと実機向け (署名なし) の両方がビルドできる |
| Android | `verification/android/` | アプリのモジュール `:app` を 1 つ持つ、独立した Gradle のビルド。一覧を 1 つ表示する | コード縮小 (R8) を有効にしたリリースが組み立てられ、実行時の依存に座標が指定の版で現れる |

どちらも、起動はしない。Simulator もエミュレータも使わない。

### 切り替え

配布物をどこから取るかを、切り替えで決める。ビルドと成功の条件は、どちらの切り替えでも同じである。

| 切り替え | iOS | Android |
|---|---|---|
| `local` (公開の前の成果物) | 今の `ios/` から一時のディレクトリに写しを作り、パスで参照する | 今の `android/` を一時のディレクトリの Maven リポジトリへ発行し、`jp.kamusoft` をそこだけから取る |
| `published` (公開済みの配布物) | 配信用リポジトリの URL を、版の完全一致で参照する。写しは作らない | `jp.kamusoft` を Maven Central だけから取る。発行はしない |

`verification/ios/` に `Package.swift` は無い。マニフェストは、確認のスクリプトが、ひな形 (`Package.swift.template`) に参照の行を差し込んで、一時のディレクトリにだけ書く。

### 流し方

```bash
python3 scripts/ci/verify-consumer-ios.py --mode local
ANDROID_HOME=<Android SDK の場所> python3 scripts/ci/verify-consumer-android.py --mode local
```

| 引数 | 意味 |
|---|---|
| `--mode local` / `--mode published` | 切り替え。必須 |
| `--version <版>` | 取る版。`published` では必須。iOS の `local` では使わない。Android の `local` で渡さなければ、バージョンカタログの版になる。空の文字列は、渡していないのと同じに扱う |

| 終了コード | 意味 |
|---:|---|
| 0 | 確認が成功した |
| 1 | 準備 (写しの作成・発行)・ビルド・確認のどれかが失敗した |
| 2 | 引数の誤り (知らない切り替え・`published` で版が無い・版に使えない文字)。何も始めていない |

必要な環境:

| プラットフォーム | 必要なもの |
|---|---|
| iOS | Xcode 27 以上。スクリプトは PATH の上の `xcodebuild` をそのまま使い、版を確かめない。別の Xcode を使うときは、環境変数 `DEVELOPER_DIR` か `xcode-select` で選ぶ |
| Android | JDK 17 以上と Android SDK。SDK の場所は、環境変数 `ANDROID_HOME` で渡す (`android/` と `verification/android/` の両方の `local.properties` に書いてあれば、それでもよい) |

- 確認は、git が追跡しているファイルを変えない。iOS は一時のディレクトリで作業し、終わると消す。Android のビルドの出力は、`android/` と `verification/android/` の下の、追跡の対象外の場所にだけできる
- Android の確認は、既定の手元の Maven リポジトリに発行せず、そこから取りもしない
- **`verification/android/` を、プロパティを渡さずに開くと (`./gradlew help` や IDE での読み込み)、settings の評価で失敗する。** `local` では、発行物を置いたディレクトリを `-PksCollectionViewRepository=<ディレクトリ>` で渡す必要があるためである。確認は、スクリプトを通して流す

手元の所要時間 (2026-10-09、依存の取得が済んだ状態): iOS は 30 秒ほど (毎回、何も無い状態からビルドする)。Android は、利用者役のビルドの出力が無い状態で 23 秒ほど、残っている状態で 5 秒ほどである。

ランナーの上での所要時間: 【公開の実施後に記入】

## 失敗したときの見方

確認のスクリプトは、子プロセス (写しを作る道具・`xcodebuild`・Gradle) の出力を加工せずにそのまま流す。失敗の理由は、スクリプトの最後の `::error::` の行ではなく、その上の子プロセスの出力にある。

### iOS

| 出力 | 意味 |
|---|---|
| 写しを作る道具のエラー (`写しの元が欠けている:` など) | 写しを作れなかった。ビルドは始まっていない。上の「SwiftPM の写し」の表と照らす |
| Simulator 向けのビルドで `error:` の行 | 写しに要るソースが欠けている、またはマニフェストが写しのルートで成り立たない。依存 (Nuke) の取得の失敗もここに出る |
| 実機向けのビルドだけで `error:` の行 | 実機向けでだけコンパイルできないコードがある |

**Simulator 向けのビルドが落ちると、実機向けのビルドは始まらない。** Simulator 向けを直した後に、実機向けの失敗が初めて見えることがある。

本体から消したファイルを commit していないと (追跡しているのに作業ツリーに無い)、ビルドまで進まず、写しを作る道具が「写しの元が欠けている」で先に止まる。

### Android

| 出力 | 意味 |
|---|---|
| 発行 (`publishToMavenLocal`) の失敗 | 本体をビルドできない、または公開の設定が壊れている。組み立ては始まっていない |
| 組み立てで `Could not find jp.kamusoft:kscollectionview:<版>` | 取得元に発行物が無い。`Searched in the following locations` に、探した場所が出る。探す場所は、切り替えで決めた 1 つだけである |
| 上と一緒に `Could not find androidx.compose.foundation:foundation:.` | 本ライブラリを解決できなかったことの連れである。利用者役は Compose の版を自分で決めず、本ライブラリが届ける BOM に任せている |
| `:app:minifyReleaseWithR8` の失敗や `Missing class` | コード縮小で不整合が出た。配布物に規則の同梱が要るかの判断になるので、利用者役の側に規則を足して通さず、オーナーに諮る |
| 「組み立ては成功で終わったが、コード縮小の対応表が無い」 | 組み立ては成功したが、コード縮小が走っていない。利用者役のリリースの設定を見る |
| 依存の一覧に座標が無い・`FAILED` が付く・版が違う | 利用者役が、確かめたい配布物と違うものを取っている |

利用者役には、本ライブラリのための規則を書かない。書くと、配布物に規則が足りないことが隠れる。

検証 CI の上で落ちたときの見方は、[検証 CI](verification-ci.md) にある。

## 確かめた範囲と確かめていないこと

### コード縮小の後の動き

コード縮小を有効にした利用者役を、2026-10-09 に手元のエミュレータ (Android 16・API 36) で 1 回起動した。一覧が表示され、スクロールでき、落ちなかった。

確かめたのは、最小の利用例が通る経路 (一覧の表示・区切り線・スクロール・起動時のコンテキストの捕捉) だけである。画像の読み込み・ページング・並べ替えなど、利用例が触らない機能は、コード縮小の後の動きを確かめていない。

起動時に名前で探される `KsAppContextInitializer` は、androidx App Startup が自分の AAR に同梱している規則が保っている。本ライブラリの AAR には規則が無い。

利用者役が確かめられるのは、利用者役が触る API に限られる。最小の利用例が触らない型の依存の宣言の漏れは、利用者役では見つからない。公開 API に現れる型を増やしたら、上の「依存の範囲」の突き合わせをやり直す。

### 確かめていないこと (2026-10-09 時点)

| 確かめていないこと | 分かっていること |
|---|---|
| `published` での取得とビルド | 配信用リポジトリも公開物もまだ無い。確かめたのは、参照の書き方・その行を持つマニフェストを SwiftPM が読めること・準備を飛ばして同じビルドを始めることまでである。取得の実行は、最初のリリースで確かめる |
| 本物の配信用リポジトリの作業コピーを行き先にした写しの作成 | 作業コピーを行き先にした形は、道具のテストが使い捨ての git のリポジトリで確かめている |
| Maven Central への実際の送信と、Maven Central の側の検査 (署名・POM の項目・javadoc jar) | 送信は 1 回も行っていない |
| 本番の形の署名 (パスフレーズつきの鍵・鍵の ID を指定する形) | 確かめたのは、パスフレーズなしの使い捨ての鍵を `signingInMemoryKey` だけで渡す形である |
| Gradle の configuration cache を有効にしたときの、開発中の版の歯止めの動き | このビルドは有効にしていない |
| Linux の上での、写しを作る道具と確認のスクリプトのテスト、利用者役の組み立て | 【公開の実施後に記入】 (書いた時点では、手元の macOS でだけ流している) |
| ランナーの上での確認の実行と所要時間 | 【公開の実施後に記入】 |
| Xcode 27.0 以外でのビルド、Windows での確認のスクリプトの実行 | 対象にしていない |

## 関連

- [cross/ADR-0015](../../decisions/cross/0015-swiftpm-via-distribution-repository.md) — SwiftPM を配信用の別リポジトリから配る決定
- [cross/ADR-0016](../../decisions/cross/0016-consumer-build-check-on-main-pull-requests.md) — 配布物を利用者役で確かめる決定
- [core/ADR-0012](../../decisions/core/0012-image-loader-direct-dependency.md) — Coil の Compose 連携を利用者に届ける決定
- [検証 CI](verification-ci.md) — 利用者の立場のビルドの確認が走る時点と、検証 CI の上での失敗の見方
- [公開識別子と配布座標](public-identifiers.md) — Maven の座標と、SwiftPM の package の名前
- [ローカル開発環境と Sample の実行](local-development-setup.md) — Android SDK の場所の渡し方

出典: kasane/changes/archive/【蒸留の日付】-package-distribution/design.md (Decision 1〜6) / kasane/changes/archive/【蒸留の日付】-package-distribution/evidence/ios-manifest-and-spm-snapshot.md (写しの中身・大きさ・拒否される行き先) / kasane/changes/archive/【蒸留の日付】-package-distribution/evidence/android-publishing.md (発行物・POM・依存の範囲の突き合わせ・開発中の版の歯止め・使い捨ての鍵) / kasane/changes/archive/【蒸留の日付】-package-distribution/evidence/consumer-ios.md・consumer-android.md (利用者役・確認のスクリプト・失敗の確認・コード縮小の後の起動)
