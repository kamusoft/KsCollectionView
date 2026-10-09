# 証跡: iOS の利用者役と確認 (tasks 4.1〜4.5)

実施日: 2026-10-09。環境: macOS 27.0.1、Xcode 27.0 (27A266a、Swift 6.4)、Python 3.14.8。

生ログの全文は手元保管で、ここには判定に要る行だけを書く。

- Simulator は、どの実行でも選んでおらず、起動もしていない。ビルドの行き先は、総称の指定 (`generic/platform=iOS Simulator`・`generic/platform=iOS`) だけである。作業専用の Simulator も作っていない
- Xcode は、手元で選んである 27.0 をそのまま使った (環境変数 `DEVELOPER_DIR` は渡していない)
- 写し・利用者役の写し・ビルドの出力は、どの実行でもリポジトリの外の一時のディレクトリに置いた

## 4.1 置いた利用者役

| ファイル | 中身 |
|---|---|
| `verification/ios/Package.swift.template` | 利用者役のマニフェストのひな形。ライブラリの target を 1 つ持つ SwiftPM のパッケージ (名前 `VerificationApp`、対象 iOS 16、Swift 6.4 のツール)。target の依存は `.product(name: "KsCollectionView", package: "KsCollectionView-SPM")` の 1 行。`dependencies` の中に、参照の行の差し込み口 (`@KSCV_DEPENDENCY@`) が 1 つある |
| `verification/ios/Sources/VerificationApp/VerificationItem.swift` | 一覧の 1 行の型 |
| `verification/ios/Sources/VerificationApp/VerificationListScreen.swift` | 100 行の文字の一覧を 1 つ表示する、最小の利用例。`import KsCollectionView` して、`KsCollectionView(items) { item in … }` を呼ぶ |

`verification/ios/` に `Package.swift` は置いていない。マニフェストは、確認のスクリプトが作業用のディレクトリにだけ書く。

差し込む行は、切り替えで決まる。

| 切り替え | 差し込む行 |
|---|---|
| `local` | `.package(path: "../KsCollectionView-SPM"),` (利用者役の写しの隣に作った写しを、相対のパスで指す) |
| `published` | `.package(url: "https://github.com/kamusoft/KsCollectionView-SPM", exact: "<版>"),` |

`published` の形のマニフェストは、SwiftPM に読ませて確かめた (取得は行っていない。配信用リポジトリがまだ無い)。`swift package dump-package` の結果:

| 項目 | 値 |
|---|---|
| ツールの版 | 6.4.0 |
| 依存 | identity `kscollectionview-spm`、場所 `https://github.com/kamusoft/KsCollectionView-SPM`、要求 `exact: 1.2.3` |
| target の依存 | product `KsCollectionView`、package `KsCollectionView-SPM` |

## 4.2 確認のスクリプト

`scripts/ci/verify-consumer-ios.py`。引数の形・終了コード・失敗の理由の出し方・概要の追記は、`scripts/ci/verify-consumer-android.py` と同じである。

行うことは、順に次のとおり。どれかが失敗したら、後ろを始めずに終了コード 1 で終わる。

1. 引数を確かめる (範囲の外なら、何も始めずに終了コード 2)
2. `local` だけ: 一時のディレクトリの下のまだ無いパス `KsCollectionView-SPM` を行き先にして、`scripts/distribution/sync-spm-snapshot.py` を子プロセスで呼ぶ。終わった後に、行き先に `Package.swift` があることを確かめる
3. 一時のディレクトリの下の `consumer/` に、利用者役の `Sources/` を写し、ひな形に参照の行を差し込んだ `Package.swift` を書く。差し込み口がちょうど 1 つでなければ失敗にする
4. `consumer/` で `xcodebuild build -scheme VerificationApp -destination "generic/platform=iOS Simulator" -configuration Release -derivedDataPath <一時のディレクトリ>/DerivedData`
5. 同じコマンドを、行き先 `generic/platform=iOS` と `CODE_SIGNING_ALLOWED=NO` で流す

子プロセスの出力は、出力先をそのまま継がせて流している (読み取りも加工もしない)。

## 4.3 スクリプトのテスト

`python3 scripts/ci/run-tests.py` — 実行 234 件 / 失敗 0 件 / スキップ 0 件 (14 秒)。この担当範囲の前は 186 件で、足したのは `scripts/ci/tests/test_verify_consumer_ios.py` の 48 件である。

テストは、使い捨てのリポジトリの形の中で確認のスクリプトを別のプロセスとして流す。写しを作る道具と `xcodebuild` は、呼ばれ方を記録する偽物に差し替えてあり、ビルドは実際には走らない。

| Scenario | テスト |
|---|---|
| iOS の利用者役が package の名前で product を指す | `test_targetの依存はpackageの名前とproductを指す`・`test_targetはpackageの名前でproductに依存する` (実物のひな形を、2 つの切り替えで) |
| iOS の local は写しのディレクトリをパスで参照する | `test_利用者役は写しをパスで参照する`・`test_写しはpackageの名前のまだ無いディレクトリに作る`・`test_localはpackageの名前のディレクトリをパスで参照する` |
| iOS の published は配信用リポジトリを版の完全一致で参照する | `test_利用者役は配信用リポジトリを版の完全一致で参照する`・`test_publishedは配信用リポジトリを版の完全一致で参照する` |
| 本体のソースを参照しない (iOS) | `test_本体のソースを参照しない`・`test_利用者役のソースは本ライブラリをモジュールとして使う` |
| 片方の行き先だけが失敗しても失敗する | `test_実機向けのビルドだけが失敗しても失敗する` |
| published では写しを作らずに同じビルドを行う | `test_publishedでは写しを作らずに同じ2つのビルドを始める`・`test_ビルドは切り替えによって変わらない`・`test_publishedでも成功の条件は同じである` |
| 知らない切り替えでは始めない | `test_知らない切り替えでは何も始めない`・`test_切り替えが無ければ何も始めない` |
| published で版が無いと始めない | `test_publishedで版が無ければ何も始めない`・`test_publishedで版が空なら何も始めない` |
| 追跡しているファイルを変えない | `test_リポジトリの中を何も変えない`・`test_利用者役の写しをリポジトリの外でビルドする`・`test_作業用のディレクトリを残さない` (実物での確認は下の 4.4) |
| 準備が失敗した理由が記録に出る | `test_写しの作成の失敗は本文が出てビルドの前に止まる`・`test_子プロセスの出力をそのままの内容と順序で流す` |
| 準備が失敗したらビルドを始めない | `test_写しの作成の失敗は本文が出てビルドの前に止まる`・`test_写しにマニフェストが無ければビルドの前に止まる`・`test_写しを作る道具が無ければビルドの前に止まる`・`test_ひな形の差し込み口がちょうど1つでなければビルドの前に止まる`・`test_利用者役のファイルが無ければビルドの前に止まる` |
| 配布物が正しければ成功する / 写しに本体のソースが欠けていると失敗する | 自動のテストは無い (実際のビルドが要る)。下の 4.4・4.5 で実物を流して確かめた |

テストが判定を実際に見ていることは、確認のスクリプトの判定を 1 つずつ無効にした写しをリポジトリの外に作り、その写しに対してテストを流して確かめた (作業ツリーのファイルは変えていない)。18 通りのすべてで、1 件以上のテストが落ちた。

| 無効にした判定 | 落ちたテストの数 |
|---|---:|
| `local` で写しを作る | 10 |
| `published` で写しを作らない | 3 |
| 実機向けをビルドする | 7 |
| ビルドの失敗で止まる | 4 |
| 写しの作成の失敗で止まる | 2 |
| 写しにマニフェストがあることの確認 | 1 |
| 実機向けの署名なしの指定 | 1 |
| リリースの構成 | 1 |
| `published` の版の完全一致 | 4 |
| `local` の参照が指すディレクトリの名前 | 5 |
| 差し込み口がちょうど 1 つであることの確認 | 2 |
| 版に使える文字の確認 | 1 |
| `published` での版の必須 | 2 |
| 知らない切り替えの拒否 | 2 |
| 写しをリポジトリの外に作る | 5 |
| 一時のディレクトリを残さない | 2 |
| 利用者役をリポジトリの外でビルドする | 9 |
| 失敗の理由を注釈として出す | 8 |

## 4.4 手元での local の確認

```
$ python3 scripts/ci/verify-consumer-ios.py --mode local
```

2 回流し、どちらも終了コード 0 だった。所要は 32.1 秒と 29.8 秒 (壁時計)。Nuke の取得は、手元のキャッシュが効いた状態である。ビルドの出力は毎回一時のディレクトリに作るので、2 回とも何も無い状態からのビルドである。

2 回目の出力の、判定に要る行 (一時のディレクトリの名前は置き換えてある):

```
==== 今の ios/ から写しを作る (KsCollectionView-SPM) ====
写しを作った: <一時のディレクトリ>/KsCollectionView-SPM (Sources 93 ファイル / Tests 45 ファイル)
==== 利用者役を作業用のディレクトリに写す ====
配布物への参照: .package(path: "../KsCollectionView-SPM"),
==== 利用者役をビルドする: Simulator 向け (generic/platform=iOS Simulator・Release) ====
Resolved source packages:
  KsCollectionView: <一時のディレクトリ>/KsCollectionView-SPM @ local
  VerificationApp: <一時のディレクトリ>/consumer
  Nuke: https://github.com/kean/Nuke.git @ 13.2.0
** BUILD SUCCEEDED **
==== 利用者役をビルドする: 実機向け (generic/platform=iOS・Release) ====
** BUILD SUCCEEDED **

### iOS の利用者の立場のビルドの確認

- 切り替え: `local` (取得元: 今の ios/ から作った写し)
- 配布物への参照: `.package(path: "../KsCollectionView-SPM"),`
- 利用者が書く依存: package `KsCollectionView-SPM` の product `KsCollectionView`
- ビルド: Simulator 向け (`generic/platform=iOS Simulator`・Release): 成功
- ビルド: 実機向け (`generic/platform=iOS`・Release): 成功
```

本体は、写しのディレクトリから解決されている (`ios/` からではない)。出力は全部で 1619 行で、Simulator 向けのビルドが 1023 行、実機向けが 580 行ほどを占める。

追跡しているファイルに変更が無いことは、2 回目の実行の前後で次の 4 つを取り、すべて一致することで確かめた。

| 取ったもの | 前後 |
|---|---|
| `git status --short --untracked-files=all` の出力 | 一致 |
| `git diff` の出力のハッシュ | 一致 |
| 追跡しているファイルすべての内容のハッシュ | 一致 |
| 追跡していない (無視の対象でもない) ファイルの一覧 | 一致 |

作業ツリーには、この変更のほかの担当範囲の未 commit の変更があるので、「変更が無い」ではなく「実行の前後で同じ」で確かめている。確認の後、一時のディレクトリ (`kscollectionview-consumer-ios-*`) は残っていなかった。`verification/ios/` の中身も、ひな形と `Sources/` のままである。

## 4.5 写しに本体のソースが欠けていると失敗する

リポジトリの外の一時のディレクトリに、確認に要る範囲 (`ios/`・`scripts/`・`verification/ios/`・`LICENSE`) の、追跡しているファイルと追跡前のファイルを写し、そこを新しい git のリポジトリにした (168 ファイル)。このリポジトリの作業ツリーと履歴には触れていない。

一時のツリーで、同じ確認を 2 回流した。

| 一時のツリーの状態 | 終了コード | 所要 | 結果 |
|---|---:|---|---|
| 写したまま | 0 | 29.8 秒 | 写しは Sources 93 ファイル。2 つの行き先とも `** BUILD SUCCEEDED **` |
| `ios/Sources/KsCollectionView/KsCollectionView.swift` (利用者役が呼ぶ型の定義) を消して commit した | 1 | 11.4 秒 | 写しは Sources 92 ファイル。Simulator 向けが `** BUILD FAILED **` (xcodebuild の終了コード 65)。実機向けのビルドは始まっていない |

2 つ目の出力の、判定に要る行:

```
写しを作った: <一時のディレクトリ>/KsCollectionView-SPM (Sources 92 ファイル / Tests 45 ファイル)
==== 利用者役をビルドする: Simulator 向け (generic/platform=iOS Simulator・Release) ====
Sources/KsCollectionView/KsCollectionView+Paging.swift:3:11: error: cannot find type 'KsCollectionView' in scope
Sources/KsCollectionView/KsCollectionView+Reorder.swift:3:11: error: cannot find type 'KsCollectionView' in scope
** BUILD FAILED **
The following build commands failed:
	SwiftCompile normal arm64 (in target 'KsCollectionView' from project 'KsCollectionView')
(5 failures)
::error::利用者役のビルドが失敗した: Simulator 向け (xcodebuild の終了コード 65)。理由は、上の xcodebuild の出力にある
```

- 失敗の理由 (`error:` の行) は、xcodebuild の出力のまま確認の出力に出ている。成功の概要は出ていない
- 1 つ目 (写したまま) が成功しているので、2 つ目の失敗は、一時のツリーの形ではなく、欠いたソースによるものである
- 欠いたファイルは、消して commit している。追跡しているのに作業ツリーに無いファイルは、写しを作る道具が「写しの元が欠けている」として先に拒むので、ビルドまで進まない

## 標準の lint と workflow の定義の検査

| コマンド | 結果 |
|---|---|
| `python3 scripts/local-path-lint.py` | 終了コード 0 |
| `python3 scripts/identity-lint.py` | 終了コード 0 |
| `python3 scripts/comment-policy-lint.py` | 禁止 0 件 (検査対象 502 ファイル) |
| `python3 scripts/ci/check-workflows.py` | 違反は無い (workflow 3 本。workflow はこの担当範囲では足していない) |

## 確かめていないこと

- `published` での取得とビルドの実行 (配信用リポジトリも公開物もまだ無い)。確かめたのは、差し込む行の書き方・その行を持つマニフェストが SwiftPM に読めること・写しを作らずに同じ 2 つのビルドを始めること (偽物の `xcodebuild` で) までである
- ランナー (`xcode-27`) の上での実行と所要時間。手元の所要は、Nuke の取得のキャッシュが効いた状態の値である
- Linux の上でのスクリプトのテストの実行 (検証 CI の lint のジョブが流す)。手元は macOS だけである
- Xcode 27.0 以外でのビルド
- iOS のテスト 2 系統 (本体・Sample)。この担当範囲は `ios/` と `samples/ios/` のファイルを変えていないので、流していない
