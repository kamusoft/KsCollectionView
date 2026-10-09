# 証跡: 手元の完了判定 (tasks 8.1・8.2)

実施日: 2026-10-09。環境: macOS 27.0.1、Xcode 27.0 (27A266a、Swift 6.4)、JDK 21.0.12 (Microsoft の OpenJDK)、Gradle 9.7.0 (wrapper)、Python 3.14.8、actionlint (PATH の上のもの)。

対象は、tasks のグループ 1〜6 の実装がすべて入った作業ツリーである (未 commit の変更として残っている状態)。グループ 7 の草稿 4 枚 (`drafts/`) も、lint を流した時点で作業ツリーにある。

生ログの全文は手元保管で、ここには要約行だけを書く。

## 8.1 テスト 4 系統の全件実行

4 系統を、絞り込みなしで順に流した。同時には流していない。

| 系統 | コマンド (作業ディレクトリ) | 実行 | 失敗 | スキップ | 所要 (差分ビルド込み) |
|---|---|---:|---:|---:|---|
| iOS 本体 | `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,id=<uuid>' -configuration Debug -collect-test-diagnostics never` (`ios/`) | 567 | 0 | 0 | 3 分 40 秒 |
| iOS Sample | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,id=<uuid>' -configuration Debug -collect-test-diagnostics never` (`samples/ios/`) | 48 (ユニットテスト 37 + UI テスト 11) | 0 | 0 | 2 分 55 秒 (2 回目の値。下の「iOS Sample の 1 回目」) |
| Android 本体 | `./gradlew --console=plain :kscollectionview:testDebugUnitTest --rerun-tasks` (`android/`) | 512 (31 クラス) | 0 | 0 | 22 秒 |
| Android Sample | `./gradlew --console=plain :app:testDebugUnitTest --rerun-tasks` (`samples/android/`) | 163 (21 クラス) | 0 | 0 | 13 秒 |

4 系統の所要の合計は 7 分 10 秒で、10 分の上限 (`kasane/handbook/cross/test-execution.md`) に収まる。合計には、失敗で終わった iOS Sample の 1 回目 (25 秒) を入れていない。

件数は、どの系統も、後続のグループが入る前の記録 (`ios-manifest-and-spm-snapshot.md` の 1.1、`android-publishing.md` の 3.5) と同じである。

### 端末と OS

| 系統 | 端末と OS |
|---|---|
| iOS 本体・iOS Sample | この作業のために新しく作った Simulator 1 台 (名前 `ksn-package-distribution-iPhone-17`、iPhone 17・iOS 27.0)。2 系統を流し終えた後に削除し、一覧に残っていないことを確かめた。既存の Simulator は使っていない |
| Android 本体・Android Sample | 端末なし (JVM の上のユニットテスト)。エミュレータも実機も使っていない |

Android SDK の場所は、環境変数 `ANDROID_HOME` で渡した。`android/local.properties` は読んでおらず、変えていない。

### 出力の要約行

```
# iOS 本体
Test Suite 'KsCollectionViewTests.xctest' passed
	 Executed 567 tests, with 0 failures (0 unexpected) in 181.743 (181.976) seconds
** TEST SUCCEEDED **

# iOS Sample (2 回目)
Test Suite 'KsCollectionViewSamplesTests.xctest' passed
	 Executed 37 tests, with 0 failures (0 unexpected) in 0.415 (0.428) seconds
Test Suite 'KsCollectionViewSamplesUITests.xctest' passed
	 Executed 11 tests, with 0 failures (0 unexpected) in 157.608 (157.623) seconds
** TEST SUCCEEDED **

# Android 本体
BUILD SUCCESSFUL in 22s
30 actionable tasks: 30 executed

# Android Sample
BUILD SUCCESSFUL in 12s
45 actionable tasks: 45 executed
```

件数の得方:

- iOS は、`xcodebuild` の出力の `Executed N tests, with M failures` の行で確かめた。成功したテストの行 (`Test Case … passed`) の数も、本体 567・Sample 48 で一致した。スキップ 0 は、出力にテストのスキップの行が無いことで確かめた
- Android は、結果の XML (`build/test-results/testDebugUnitTest/TEST-*.xml`) の `tests`・`failures`・`errors`・`skipped` を、クラスごとのファイルから合計した。エラーは、どちらも 0 である。XML は、この実行で書かれたものである (集計の時点で、最も新しいファイルの更新から 1 分以内)

### iOS Sample の 1 回目 (テストが 1 件も実行されずに失敗した)

iOS 本体のテストに続けて、同じ Simulator で iOS Sample のテストを流した 1 回目は、25 秒で `** TEST FAILED **` で終わった。テストは 1 件も実行されていない (出力に `Test Case` の行が 0 行)。

出力の要点:

```
Testing failed:
	KsCollectionViewSamples encountered an error (Failed to install or launch the test runner. (Underlying Error: Simulator device failed to launch jp.kamusoft.kscollectionview.samples.ios. No such process. …
	KsCollectionViewSamplesUITests-Runner encountered an error (Failed to install or launch the test runner. (Underlying Error: Simulator device failed to launch jp.kamusoft.kscollectionview.samples.ios.uitests.xctrunner. The request was denied by service delegate (SBMainWorkspace) for reason: NotFound …
** TEST FAILED **
```

- 落ちたのは、Simulator がアプリとテストのランナーを起動するところである。ビルドは通っていて、テストのアサーションの失敗ではない
- 失敗の後に見ると、Simulator は止まった状態 (`Shutdown`) だった
- Simulator を `xcrun simctl boot` で起動し、起動が終わるのを `xcrun simctl bootstatus` で待ってから、同じコマンドを流し直すと、48 件が全件成功した (上の表の値)。ソース・テスト・プロジェクトのファイルは、1 回目と 2 回目の間で変えていない
- 原因は確かめていない。iOS 本体のテストが終わった直後に、同じ Simulator へ続けて流したことが関わっている見込みだが、同じ流し方の前の記録 (`ios-manifest-and-spm-snapshot.md` の 1.1) では起きていない

## 8.2 スクリプトのテストと標準の lint

リポジトリのルートで流した。

| コマンド | 終了コード | 結果 |
|---|---:|---|
| `python3 scripts/ci/run-tests.py` | 0 | 実行 259 件 / 失敗 0 件 / スキップ 0 件 (`Ran 259 tests in 13.037s`) |
| `python3 scripts/ci/check-workflows.py` | 0 | 確かめた workflow: 5 本 (uses 13 箇所 / runs-on 5 箇所 / permissions 5 箇所)。違反は無い |
| `python3 scripts/local-path-lint.py` | 0 | 出力なし |
| `python3 scripts/identity-lint.py` | 0 | 出力なし |
| `python3 scripts/comment-policy-lint.py` | 0 | 合計: 0 ファイル / 禁止 0 件 (検査対象 502 ファイル) |
| `actionlint` (タスクが求める範囲の外の、追加の確認) | 0 | 出力なし |

スクリプトのテストの 259 件は、前の記録 (`consumer-ci-workflows.md` の 6.4) と同じである。

lint の 3 本は、グループ 7 の草稿 4 枚を `drafts/` に置いた後に流した。草稿は、識別の lint の検査の範囲 (`kasane/`) に入る。

## 追跡しているファイルに変更が無いこと

テスト 4 系統を流す前と、すべてを流し終えた後で、次の 2 つを比べた。

| 比べたもの | 結果 |
|---|---|
| `git diff` の出力のハッシュ | 一致 (追跡しているファイルの内容は、実行の前後で変わっていない) |
| `git status --short` の出力 | 増えたのは、この担当範囲で足した `kasane/changes/package-distribution/drafts/` の 1 行だけ |

作業ツリーには、グループ 1〜6 の未 commit の変更があるので、「変更が無い作業ツリー」からは始めていない。確かめたのは、実行の前と後で差が無いことである。

## 確かめていないこと

- 公開リポジトリでの確認 (tasks のグループ 9)。ランナーの上では、利用者の立場のビルドの確認の 2 本は、まだ 1 度も走っていない
- Linux の上でのスクリプトのテストの実行 (検証 CI の lint のジョブが流す)。手元は macOS だけである
- iOS Sample の 1 回目の失敗の原因
- 端末をつないで走らせる Android のテスト (`android/kscollectionview/src/androidTest/`)。テスト 4 系統に入っておらず、この変更は画像のデコードに触っていない
- 利用者の立場のビルドの確認そのもの (`verify-consumer-ios.py`・`verify-consumer-android.py` の `local`)。この担当範囲では流していない。グループ 4〜6 の証跡 (`consumer-ios.md`・`consumer-android.md`・`consumer-ci-workflows.md`) が流している
