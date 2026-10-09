---
kind: guide
applies-when:
  always: false
  paths: ["scripts/ci/verify-consumer-*.py", "verification/**", ".github/workflows/verify-consumer-*.yml"]
  tasks: [利用者の立場のビルドの確認を手元で流す, 利用者の立場のビルドの確認の失敗の調査, 利用者役・確認のスクリプト・確認の workflow の変更]
title: 利用者の立場のビルドの確認
description: 配布物を利用者と同じ書き方で取る利用者役の形、手元での流し方、検証 CI での走り方、失敗したときの見方、確かめた範囲と確かめていないこと、変えるときの注意
timestamp: 2026-10-09
---

# 利用者の立場のビルドの確認

この文書は、配布物を利用者と同じ書き方で取ってビルドできることを、どう確かめるかをまとめる。確かめるための最小のプロジェクト (利用者役) の形、手元での流し方、検証 CI での走り方、落ちたときにどこを見るかを書く。配布物の中身と作り方は、[配布物の形と作り方](package-distribution.md) を先に読むと分かりやすい。

Sample は本体のソースを直接参照するので、配布物だけが壊れたことには、この確認でしか気付けない。配布物を専用の利用者役で確かめ、`main` 宛ての Pull Request の必須の検査にした理由と範囲は、[cross/ADR-0016](../../decisions/cross/0016-consumer-build-check-on-main-pull-requests.md) にある。

## 利用者役

利用者役は、配布物を利用者と同じ書き方で取る、最小のプロジェクトである。本体のソースを参照しない。

| プラットフォーム | 置き場 | 形 | 確かめること |
|---|---|---|---|
| iOS | `verification/ios/` | ライブラリの target を 1 つ持つ SwiftPM のパッケージ。一覧を 1 つ表示する。本体を、package `KsCollectionView-SPM` の product `KsCollectionView` として取る | リリースの構成で、Simulator 向けと実機向け (署名なし) の両方がビルドできる |
| Android | `verification/android/` | アプリのモジュール `:app` を 1 つ持つ、独立した Gradle のビルド。一覧を 1 つ表示する。本体を、座標の 1 行で取る | コード縮小 (R8) を有効にしたリリースが組み立てられ、実行時の依存に座標が指定の版で現れる |

どちらも、起動はしない。Simulator もエミュレータも使わない ([cross/ADR-0013](../../decisions/cross/0013-ci-runs-no-simulator-or-device-tests.md))。利用者役のテストも無い。

### 切り替え

配布物をどこから取るかを、切り替えで決める。ビルドと成功の条件は、どちらの切り替えでも同じである。

| 切り替え | iOS | Android |
|---|---|---|
| `local` (公開の前の成果物) | 今の `ios/` から一時のディレクトリに写しを作り、パスで参照する | 今の `android/` を一時のディレクトリの Maven リポジトリへ発行し、`jp.kamusoft` をそこだけから取る |
| `published` (公開済みの配布物) | 配信用リポジトリの URL ([公開識別子と配布座標](public-identifiers.md) の Package URL) を、版の完全一致で参照する。写しは作らない | `jp.kamusoft` を Maven Central だけから取る。発行はしない |

`verification/ios/` に `Package.swift` は無い。マニフェストは、確認のスクリプトが、ひな形 (`Package.swift.template`) に参照の行を差し込んで、一時のディレクトリにだけ書く。

## 手元で流す

```bash
python3 scripts/ci/verify-consumer-ios.py --mode local
ANDROID_HOME=<Android SDK の場所> python3 scripts/ci/verify-consumer-android.py --mode local
```

準備 (写しの作成・発行) からビルドと確認までを、スクリプトが順に行う。どれかが失敗すると、後ろを始めずに失敗で終わる。

| 引数 | 意味 |
|---|---|
| `--mode local` / `--mode published` | 切り替え。必須 |
| `--version <版>` | 取る版 (例: `1.2.3`)。`published` では必須。iOS の `local` では使わない。Android の `local` で渡さなければ、バージョンカタログの版 (`android/gradle/libs.versions.toml` の `kscollectionview`) になる。空の文字列は、渡していないのと同じに扱う |

版に使える文字は、英数字と `.`・`+`・`_`・`-` で、先頭は英数字に限る (`0.1.0-SNAPSHOT` は通り、`v` で始まる `v1.2.3` も通る。先頭が `-` のものや、引用符などほかの文字を含むものは引数の誤りになる)。スクリプトが見るのは文字だけで、その版が実在するかは見ない。

| 終了コード | 意味 |
|---:|---|
| 0 | 確認が成功した |
| 1 | 準備 (写しの作成・発行)・ビルド・確認のどれかが失敗した |
| 2 | 引数の誤り (知らない切り替え・`published` で版が無い・版に使えない文字)。何も始めていない |

| プラットフォーム | 必要なもの |
|---|---|
| iOS | Xcode 27 以上。スクリプトは PATH の上の `xcodebuild` をそのまま使い、版を確かめない。別の Xcode を使うときは、環境変数 `DEVELOPER_DIR` か `xcode-select` で選ぶ |
| Android | JDK 17 以上と Android SDK。SDK の場所は、環境変数 `ANDROID_HOME` で渡す (`android/` と `verification/android/` の両方の `local.properties` に書いてあれば、それでもよい) |

- 確認は、git が追跡しているファイルを変えない。iOS は一時のディレクトリで作業し、終わると消す。Android のビルドの出力は、`android/` と `verification/android/` の下の、追跡の対象外の場所にだけできる
- Android の確認は、既定の手元の Maven リポジトリに発行せず、そこから取りもしない
- `develop` への push では、検証 CI はこの確認を走らせない。配布物の形に関わる変更をしたら、push の前に手元で流す。該当する変更は、`ios/Package.swift`・`ios/Sources/` のファイルの増減・Android の公開の設定と依存の宣言・`scripts/distribution/`・`verification/` である

手元の所要時間 (2026-10-09、依存の取得が済んだ状態): iOS は 30 秒ほど (毎回、何も無い状態からビルドする)。Android は、利用者役のビルドの出力が無い状態で 23 秒ほど、残っている状態で 5 秒ほどである。

### Android の利用者役を Gradle や IDE から直接開くとき

確認は、スクリプトを通して流すのが基本である。スクリプトが、発行と、下のプロパティの受け渡しをすべて行う。

**`verification/android/` を、プロパティを渡さずに開くと (`./gradlew help` や IDE での読み込み)、settings の評価で失敗する。** 既定の切り替えが `local` で、発行物を置いたディレクトリが必須だからである。直接開くときは、先に本体を手元のディレクトリへ発行し ([配布物の形と作り方](package-distribution.md))、次の Gradle のプロパティを `-P<名前>=<値>` で渡す。`verification/android/gradle.properties` は、これらを持たない。

| プロパティ | 値 | 渡さないとき |
|---|---|---|
| `ksCollectionViewMode` | `local` か `published` | `local` になる。ほかの値は失敗する |
| `ksCollectionViewRepository` | 発行物を置いた Maven リポジトリのディレクトリ | `local` では必須で、無いと失敗する。実在しないディレクトリを渡しても失敗する。`published` では使わない |
| `ksCollectionViewVersion` | 取る版 | バージョンカタログの版になる |

Android SDK の場所は、ほかのビルドと同じく `ANDROID_HOME` か `verification/android/local.properties` で渡す。

## 検証 CI での走り方

検証 CI では、`consumer-ios / verify`・`consumer-android / verify` の 2 つの検査として、`main` 宛ての Pull Request のときだけ走る。入口 (`.github/workflows/ci.yml`) が、再利用 workflow (`verify-consumer-ios.yml`・`verify-consumer-android.yml`) を、切り替えを `local` にして、版を渡さずに呼ぶ。走る時点の全体と、検査の名前は [検証 CI](verification-ci.md) にある。

workflow は、手元と同じスクリプトを `--mode "${KS_MODE}" --version "${KS_VERSION}"` の形で 1 行で呼ぶ。入口が渡すのは `local` と空の版なので、上の手元のコマンドと同じ動きになる。認証の情報と署名の鍵は受け取らない。

### consumer-ios / verify

step は、Checkout・Select Xcode・Show toolchain・Verify consumer の 4 つである。行うことは次のとおり。

1. workflow の `KS_XCODE_VERSION` で決めた版 (2026-10-09 時点で 27.0) の Xcode を選ぶ。無ければ、ビルドを始める前に失敗で終わる
2. 今の `ios/` から、配信用リポジトリのルートに置くのと同じ写しを、一時のディレクトリに作る
3. 利用者役を一時のディレクトリに写し、写しをパスで参照するマニフェストを書く
4. 利用者役を、リリースの構成で、Simulator 向け (`generic/platform=iOS Simulator`) にビルドする
5. 同じ利用者役を、実機向け (`generic/platform=iOS`、署名なし) にビルドする

2〜5 は `scripts/ci/verify-consumer-ios.py` が行う。Simulator 向けのビルドが落ちた回では、実機向けのビルドは走らない。

### consumer-android / verify

step は、Checkout・Setup JDK・Cache Gradle dependencies・Show toolchain・Ensure Android SDK platform・Verify consumer の 6 つである。行うことは次のとおり。

1. JDK 21 を入れ、コンパイル対象の Android SDK がランナーに無ければ取得する
2. 今の `android/` の本体を、一時のディレクトリの Maven リポジトリへ発行する
3. 利用者役のリリースを、コード縮小 (R8) を有効にして組み立てる。本ライブラリは、2 で発行した場所だけから取る
4. コード縮小の対応表 (`mapping.txt`) ができていることを確かめる
5. 実行時の依存の一覧に、座標 `jp.kamusoft:kscollectionview` が指定の版で現れることを確かめる

2〜5 は `scripts/ci/verify-consumer-android.py` が行う。

キャッシュするのは、依存の解決の結果と、wrapper が取得する Gradle だけである。キーは `gradle-consumer-` で始まり、既存の検証のキャッシュと分けてある。ビルドの出力と、既定の手元の Maven リポジトリは、キャッシュしない。

### ランナーの上での最初の実行 (2026-10-09)

`main` 宛ての Pull Request 2 番で、2 つとも 1 回ずつ走り、成功した。依存のキャッシュが無い状態の実行である。

| 読んだ項目 | `consumer-ios / verify` (ランナー `xcode-27`) | `consumer-android / verify` (ランナー `ubuntu-24.04`) |
|---|---|---|
| ジョブの所要時間 | 1 分 58 秒 | 3 分 16 秒 |
| 道具の版 | Xcode 27.0 (Build version 27A266a)・Swift 6.4・`python3` 3.14.8 | JDK 21.0.12.1・`python3` 3.12.3 |
| 準備 | 写しの作成と利用者役の準備は 1 秒ほど (step `Verify consumer` の開始から、Simulator 向けのビルドの開始まで) | 本体の発行は 1 分 34 秒 |
| ビルド | Simulator 向けが約 1 分 5 秒 (Nuke の取得を含む)、実機向けが約 37 秒 | 利用者役のリリースの組み立てが 1 分 26 秒 |
| 確認の結果 | 2 つのビルドとも `** BUILD SUCCEEDED **` | 実行時の依存に `jp.kamusoft:kscollectionview:0.1.0-SNAPSHOT` が現れた |
| そのほか | step `Verify consumer` は 1 分 43 秒 | コンパイル対象の SDK (Platform 36) はランナーにあり、SDK を取得する側の処理は動いていない。キャッシュは復元されず (`Cache not found`)、終わりに保存された (`Cache saved`) |

### 時間の上限

2 つのジョブの時間の上限は、どちらも 15 分である。手元の所要時間しか無い時点で 15 分を暫定の値として置き、2026-10-09 にランナーでの所要時間を見て、15 分のまま変えないと決めた。

| 理由 | 中身 |
|---|---|
| 測れた回数が少ない | 測れたのは 1 回だけで、どちらも依存のキャッシュが無い状態の最初の実行である。ばらつきはまだ分からない |
| 既存の検証と揃う | 既存の 2 つの検証 (`ios / verify`・`android / verify`) の上限も 15 分である。同じ値にしておけば、検証 CI の 5 つの検査のうち `lint` (上限 5 分) を除く 4 つの上限が揃う |
| 外部の依存の取得に頼る | Nuke と Maven の依存の取得が遅い日の余裕を残す。上限を詰めて得るものは、止まった実行が早く切れることだけである |

## 失敗したときの見方

確認のスクリプトは、子プロセス (写しを作る道具・`xcodebuild`・Gradle) の出力を加工せずにそのまま流す。スクリプトの最後の `::error::` の行は、どの段で落ちたかを言う。失敗の理由は、その上の子プロセスの出力にある。

どちらの確認も、外部の依存 (Nuke・Maven の依存) を取得できないと落ちる。コードを変えていないのに落ちたときは、取得の失敗を先に見る。

### iOS

| 出力 | 意味 |
|---|---|
| 写しを作る道具のエラー (`写しの元が欠けている:` など) | 写しを作れなかった。ビルドは始まっていない。[配布物の形と作り方](package-distribution.md) の「作り方」の表と照らす |
| Simulator 向けのビルドで `error:` の行と `** BUILD FAILED **` | 下の表で切り分ける |
| 実機向けのビルドだけで `error:` の行 | 実機向けでだけコンパイルできないコードがある |
| `::error::` が引数の誤りを言う | 渡した切り替えか版が範囲の外にある。検証 CI では、入口が渡す値が変わっている (入口は `mode: local` だけを渡す) |

Simulator 向けのビルドの失敗の原因は 4 つ考えられる。出力の手掛かりを実物で見たのは、1 つ目だけである (2026-10-09、一時のツリーで本体のソースを 1 つ欠いた)。

| 原因 | 出力の手掛かり |
|---|---|
| 写しに要るソースが欠けている | 見た。写しの中の本体のソース (`Sources/KsCollectionView/…`) の行に `error: cannot find type '…' in scope` が出て、失敗したコマンドの一覧に `in target 'KsCollectionView' from project 'KsCollectionView'` と出る。その上の「写しを作った: … (Sources N ファイル …)」の N が、前より減っている |
| 利用者役のソースが、本体の公開 API と合わなくなった | 見ていない。利用者役の target は `VerificationApp` なので、`error:` の行が利用者役のソース (`Sources/VerificationApp/…`) を指すかを見る |
| 依存 (Nuke) を取得できない | 見ていない。手掛かりは分からない。コンパイルが始まる前の、依存を解決する段の出力を見る |
| マニフェストが写しのルートで成り立たない | 見ていない。手掛かりは分からない。写しの中で `swift package describe` を流すと、マニフェストだけを切り分けられる ([配布物の形と作り方](package-distribution.md)) |

**Simulator 向けのビルドが落ちると、実機向けのビルドは始まらない。** Simulator 向けを直した後に、実機向けの失敗が初めて見えることがある。

本体から消したファイルを commit していないと (追跡しているのに作業ツリーに無い)、ビルドまで進まず、写しを作る道具が「写しの元が欠けている」で先に止まる。

### Android

| 出力 | 意味 |
|---|---|
| 発行 (`publishToMavenLocal`) の失敗 | 本体をビルドできない、または公開の設定が壊れている。組み立ては始まっていない |
| 組み立てで `Could not find jp.kamusoft:kscollectionview:<版>` | 取得元に発行物が無い。`Searched in the following locations` に、探した場所が出る。探す場所は、切り替えで決めた 1 つだけである |
| 上と一緒に `Could not find androidx.compose.foundation:foundation:.` | 上の失敗から副次的に出るエラーで、原因は同じである。利用者役は Compose の版を自分で決めず、本ライブラリが届ける BOM に任せている。本ライブラリを解決できないと BOM が届かず、版が決まらない。末尾の `:.` は、版が空のまま表示されたものである |
| `:app:minifyReleaseWithR8` の失敗や `Missing class` | コード縮小で不整合が出た。下の段落のとおりに扱う |
| 「組み立ては成功で終わったが、コード縮小の対応表が無い」 | 組み立ては成功したが、コード縮小が走っていない。利用者役のリリースの設定を見る |
| 依存の一覧に座標が無い・`FAILED` が付く・版が違う | 利用者役が、確かめたい配布物と違うものを取っている |

コード縮小で不整合が出たときは、利用者役の側に規則を足して通さない。配布物に規則を同梱するかの判断になるので、オーナー (リポジトリの持ち主である開発者) に諮る。利用者役には、本ライブラリのための規則を書かない。書くと、配布物に規則が足りないことが隠れる。

### 検証 CI の上で落ちたとき

落ちた step の記録に、上の出力がそのまま出る。成功したときは、実行の結果のページの概要に、切り替えと確かめたものが出る。

| 検査 | 落ちた step | 意味 |
|---|---|---|
| `consumer-ios / verify` | Select Xcode / Show toolchain | 決めた版の Xcode がランナーに無い、または選んだ Xcode の版が違う。`ios / verify` も同じ理由で落ちているはずである |
| `consumer-ios / verify` | Verify consumer | 写しの作成・利用者役の準備・2 つのビルドのどれかが失敗した。上の「iOS」の表で切り分ける |
| `consumer-android / verify` | Ensure Android SDK platform | コンパイル対象の SDK の版を読めない、`ANDROID_HOME` が無い、SDK を取得できない、のどれか (`android / verify` の同じ名前の step と同じ) |
| `consumer-android / verify` | Verify consumer | 本体の発行・利用者役の組み立て・対応表の確認・依存の確認のどれかが失敗した。上の「Android」の表で切り分ける |

`ios / verify` や `android / verify` が成功していて、こちらだけが落ちたときは、本体ではなく配布物の側を疑う。iOS は、配布物の形 (写しに入るファイル・マニフェストがルートで成り立つこと) か、利用者役の側である。Android は、公開の設定・発行物の依存の宣言・コード縮小である。

## 確かめた範囲と確かめていないこと

### コード縮小の後の動き

コード縮小を有効にした利用者役を、2026-10-09 に手元のエミュレータ (Android 16・API 36) で 1 回起動した。一覧が表示され、スクロールでき、落ちなかった。

確かめたのは、最小の利用例が通る経路 (一覧の表示・区切り線・スクロール・起動時のコンテキストの捕捉) だけである。画像の読み込み・ページング・並べ替えなど、利用例が触らない機能は、コード縮小の後の動きを確かめていない。

`KsAppContextInitializer` は、アプリの起動時にアプリケーションのコンテキストを捕捉する、本ライブラリの内部のクラスである。androidx App Startup が、マニフェストに書かれた名前で起動時に探す。名前で探されるクラスは、コード縮小で名前が変わると見つからなくなる。このクラスの名前は、androidx App Startup が自分の AAR に同梱している規則が保っている。本ライブラリの AAR には規則が無い。

### 配布物が壊れていると落ちること

「配布物が壊れていると確認が落ちる」ことは、ランナーの上で失敗する実行を見て確かめたものではない。手元で、次の形で確かめた。

| プラットフォーム | 手元で確かめた形 |
|---|---|
| iOS | 一時のツリーで本体のソースを 1 つ欠くと、確認が終了コード 1 で終わる |
| Android | 発行物の無い取得元を渡すと、組み立てが依存を解決できずに失敗する |

### 確かめていないこと

2026-10-09 時点で確かめていないことは、次のとおり。

| 確かめていないこと | 分かっていること |
|---|---|
| `published` での取得とビルド | 配信用リポジトリも公開物もまだ無く、取得は 1 度も実行していない。確かめたのは、参照の書き方・その行を持つマニフェストを SwiftPM が読めること・準備を飛ばして同じビルドを始めることまでである。最初のリリースで確かめる |
| 利用者役が触らない API についての、配布物の依存の宣言の漏れ | 利用者役が確かめられるのは、最小の利用例が触る API に限られる。公開 API に現れる型を増やしたら、[配布物の形と作り方](package-distribution.md) の「依存の範囲」の突き合わせをやり直す |
| ランナーの上で失敗する実行 | 見ていない。ランナーの上で確かめたのは、2 つが 1 回ずつ成功したことである |
| 2 回目からの所要時間とばらつき、保存したキャッシュが次の実行で復元されること | 測れたのは、キャッシュが無い状態の最初の 1 回だけである。キャッシュは、保存されるところまでを確かめた |
| ランナーの上で、コンパイル対象の Android SDK を取得する側の処理 (ランナーに SDK が無いときだけ動く) | コンパイル対象の SDK がランナーにあり、動かなかった |
| `Select Xcode` の step が Xcode を見つけて選ぶ側の処理を、手元で動かすこと | step は、`/Applications` の下の `Xcode_<版>.app` という名前のアプリを探す。手元の Xcode は、この名前では置いていない。同じ本文の step が、`ios / verify` でランナーの上で通っている。無い版を渡すと `DEVELOPER_DIR` を書く前に失敗で終わることは、step の本文を取り出して手元で確かめた |
| Xcode 27.0 以外でのビルド、Windows での確認のスクリプトの実行 | 対象にしていない |

## 変えるときの注意

| 変えるもの | 守ること |
|---|---|
| 入口のジョブ (`consumer-ios`・`consumer-android`) の条件 | Pull Request で起動したときだけ走る条件を外さない。外すと、`develop` への push のたびに macOS のランナーを起こす。条件は、呼ばれる側ではなく入口のジョブに付ける |
| 確認の workflow の入力 | 切り替えと版の 2 つだけにする。リリースの workflow (2026-10-09 時点ではまだ無く、作る予定) が、同じ workflow を切り替えを変えて呼ぶ前提である。入力の検査は workflow の step に書かず、スクリプトに持たせてある |
| 確認の workflow の step | 足す・名前を変えるときは、スクリプトのテスト (`scripts/ci/tests/test_workflow_files.py`) が持つ step の一覧も直す。iOS は 4 つ、Android は 6 つの step に決めてある。スクリプトのテストは、手元では `python3 scripts/ci/run-tests.py` で流す ([検証 CI](verification-ci.md) の「手元で確かめる」) |
| 確認の step (`Verify consumer`) | 後ろに別のコマンドをつながない。つないだ側の終了コードが step の合否になる。スクリプトのテストが、つないでいないことを確かめる |
| Xcode の版・JDK の版 | 既存の検証の workflow と、確認の workflow で、同時に上げる。値がずれると、スクリプトのテストが落ちる。Xcode の版を上げるときは、マニフェストの宣言も同時に上げる ([配布物の形と作り方](package-distribution.md)) |
| iOS の `Select Xcode` の step、Android のコンパイル対象の SDK を確かめる step | 既存の検証の workflow と同じ本文であることを、テストが確かめる。直すときは両方を直す |
| 利用者役のビルドの定義 (`verification/android/` の `*.gradle.kts`・wrapper の設定) | 変えると、Android の確認のキャッシュのキーが変わる。wrapper を上げるときは、`android/` と `verification/android/` の両方を同じ版にする (スクリプトのテストが、設定が同じであることを確かめる) |
| 利用者が書く依存の書き方 (Package URL・package の名前・座標) | 利用者役のひな形と依存の行を、同時に直す ([公開識別子と配布座標](public-identifiers.md)) |

知っておく制限:

- この確認は、外部の依存の取得 (Nuke・Maven の依存) に頼る。必須の検査が、コードの誤りではない理由で止まり得る。止まったときの進め方は [ブランチの運用と GitHub の設定](branch-and-github-settings.md) にある
- iOS の確認は、Simulator 向けのビルドが落ちると、実機向けのビルドを流さない。1 回の失敗で、両方の行き先の結果は分からない
- 確認のスクリプトのテストは、`xcodebuild` と `gradlew` を、呼ばれ方を記録する偽物に差し替えて流す。ビルドも発行も実際には走らない

## 関連

- [cross/ADR-0016](../../decisions/cross/0016-consumer-build-check-on-main-pull-requests.md) — 配布物を利用者役でビルドして確かめ、必須の検査にする決定
- [cross/ADR-0013](../../decisions/cross/0013-ci-runs-no-simulator-or-device-tests.md) — 検証 CI で Simulator・エミュレータを使わない決定
- [配布物の形と作り方](package-distribution.md) — 配布物の中身、写しの作り方、手元への発行
- [検証 CI](verification-ci.md) — 5 つの検査が走る時点と、緑が保証する範囲
- [ブランチの運用と GitHub の設定](branch-and-github-settings.md) — 必須の検査を参照する保護の値と、検査が止まったときの進め方

出典: kasane/changes/archive/2026-10-09-package-distribution/design.md (Decision 3〜7) / kasane/changes/archive/2026-10-09-package-distribution/evidence/consumer-ios.md・consumer-android.md (利用者役・確認のスクリプト・失敗の確認・コード縮小の後の起動) / kasane/changes/archive/2026-10-09-package-distribution/evidence/consumer-ci-workflows.md (確認の workflow の形・手元での確認) / kasane/changes/archive/2026-10-09-package-distribution/evidence/public-repository-checks.md (ランナーの上での実行・時間の上限)
