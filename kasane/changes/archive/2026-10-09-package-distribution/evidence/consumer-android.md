# 証跡: Android の利用者役と確認 (tasks 5.1〜5.7)

実施日: 2026-10-09。環境: macOS 27.0、JDK 21.0.12 (Microsoft の OpenJDK)、Gradle 9.7.0 (wrapper)、AGP 9.4.0、Kotlin 2.4.10 (AGP の組み込み)、Compose BOM 2026.06.01、Android SDK Platform 36・Build-Tools 36.0.0、Python 3.14.8。

生ログの全文は手元保管で、ここには判定に要る行だけを書く。

- Android SDK の場所は、どの実行でも環境変数 `ANDROID_HOME` で渡した。`android/local.properties` は読んでおらず、変えていない。`verification/android/` に `local.properties` は作っていない
- 本体の発行先は、どの実行でもリポジトリの外の一時のディレクトリにした。発行先を変えるシステムプロパティは、`android-publishing.md` の冒頭に書いたものと同じである (名前を続けて書くと識別の lint が止めるので、ここでも書かない)
- Maven Central への送信のタスクは 1 回も呼んでいない。呼んだ発行のタスクは `:kscollectionview:publishToMavenLocal` だけである

## 5.1 置いた利用者役

| ファイル | 中身 |
|---|---|
| `verification/android/settings.gradle.kts` | 取得元の切り替え。`jp.kamusoft` を exclusiveContent で 1 つの取得元に固定する。本体のバージョンカタログを共有する |
| `verification/android/build.gradle.kts`・`gradle.properties` | プラグインの版の固定と、Gradle の設定 |
| `verification/android/gradlew`・`gradlew.bat`・`gradle/wrapper/` | `android/` のものの写し (Gradle 9.7.0)。スクリプトのテストが、wrapper の設定が本体と同じであることを確かめる |
| `verification/android/app/build.gradle.kts` | アプリのモジュール。本ライブラリへの依存は `implementation("jp.kamusoft:kscollectionview:$ksCollectionViewVersion")` の 1 行。リリースは `isMinifyEnabled = true`、規則は `proguard-android-optimize.txt` だけ、署名はデバッグ用の鍵 |
| `verification/android/app/src/main/` | マニフェストと、Activity・一覧の画面の 2 つのソース。100 行の文字の一覧を 1 つ表示する |

Gradle のプロパティ:

| プロパティ | 値 |
|---|---|
| `ksCollectionViewMode` | `local` (既定) か `published`。ほかの値は settings の評価で失敗する |
| `ksCollectionViewRepository` | `local` のときに必須。発行物を置いた Maven リポジトリのディレクトリ。無い・ディレクトリでないときは settings の評価で失敗する |
| `ksCollectionViewVersion` | 取る版。無ければ本体のバージョンカタログの版 |

`local` の取得元に、既定の手元の Maven リポジトリは使っていない (渡したディレクトリだけ)。プロパティを何も渡さずに `./gradlew help` を流すと、settings の評価で「`-PksCollectionViewRepository=<ディレクトリ>` で渡す」と出て失敗することを確かめた。

利用者役が自分で宣言する依存は、本ライブラリのほかに 2 つである。

- `androidx.compose.foundation:foundation` (行の文字を描く `BasicText`)。版を書いていない。版は、本ライブラリが届ける Compose の BOM が決める (解決の結果は 1.11.4)
- `androidx.activity:activity-compose:1.11.0` (Sample が使う版と同じ)

Compose の BOM を利用者役の側で宣言していないので、本ライブラリを解決できないと、`foundation` の版も決まらずに失敗する (下の 5.6 の出力に現れる)。

ビルドの出力 (`verification/android/.gradle/`・`.kotlin/`・`app/build/`) は、既存の `.gitignore` の行 (`build/`・`.gradle/`・`.kotlin/`) で追跡の対象外になる。`.gitignore` は変えていない。

## 5.2 最初の確認: コード縮小を有効にした組み立て

今の本体を一時のディレクトリへ発行し、利用者役のリリースを組み立てた。

```
(android/)              ./gradlew --console=plain <発行先の指定> -Pversion=0.1.0-SNAPSHOT :kscollectionview:publishToMavenLocal
(verification/android/) ./gradlew --console=plain -PksCollectionViewMode=local -PksCollectionViewRepository=<一時のディレクトリ> -PksCollectionViewVersion=0.1.0-SNAPSHOT :app:assembleRelease
```

| 項目 | 結果 |
|---|---|
| 発行 | BUILD SUCCESSFUL。発行物 5 点 (`.aar`・`-sources.jar`・`-javadoc.jar`・`.pom`・`.module`) |
| 組み立て | BUILD SUCCESSFUL in 23s。49 のタスクを実行。`:app:minifyReleaseWithR8` が実行された |
| 組み立ての出力の中の警告・エラー・`Missing class` の行 | 0 行 (大文字と小文字を区別せずに `warning`・`error`・`missing` を探した) |
| `app/build/outputs/apk/release/app-release.apk` | 2,138,228 バイト (デバッグ用の鍵で署名済み) |
| `app/build/outputs/mapping/release/mapping.txt` | 151,683 行。`jp.kamusoft.kscollectionview` を含む行は 1,911 行 |

コード縮小で不整合は出なかった。配布物にも利用者役にも、規則は足していない。

起動時に Android の仕組み (androidx App Startup) が名前で探す `KsAppContextInitializer` は、対応表で名前が変わっていない。保っているのは、androidx App Startup が自分の AAR に同梱している規則 (`-keep class * extends androidx.startup.Initializer`) で、R8 が実際に使った規則の一覧 (`mapping/release/configuration.txt`) に入っていることを確かめた。本ライブラリの AAR には規則が無い。

対応表があることを、コード縮小が走った印として使えるかも確かめた。リポジトリの外の一時のツリーに利用者役を写し、`isMinifyEnabled` を `false` に変えて組み立てると、`app/build/outputs/mapping/` はできなかった (組み立て自体は成功)。

## 5.3 確認のスクリプト

`scripts/ci/verify-consumer-android.py`。

```
python3 scripts/ci/verify-consumer-android.py --mode local [--version <版>]
python3 scripts/ci/verify-consumer-android.py --mode published --version <版>
```

| 終了コード | 意味 |
|---|---|
| 0 | 組み立てと依存の確認が、どちらも成功した |
| 1 | 発行・組み立て・確認のどれかが失敗した |
| 2 | 引数の誤り (知らない切り替え・`published` で版が無い・版に使えない文字)。何も始めていない |

- `--version` が空の文字列のときは、渡していないのと同じに扱う (workflow が、版の入力が空のときに空の文字列を渡せるようにするため)
- `local` の発行先は、スクリプトが作る一時のディレクトリで、確認が終わると消える
- 組み立ての前に、前の回の対応表 (`mapping.txt`) を消す。組み立ての後に対応表が無ければ、失敗にする
- 依存の一覧 (`:app:dependencies --configuration releaseRuntimeClasspath`) は、Gradle の終了コードをそのまま受け取りながら、出力を流して読む。本ライブラリの座標の行が無い・`FAILED` が付く・指定の版と違う版に解決されている、はどれも失敗にする
- 成功したときは、概要 (切り替え・確かめた座標) を出す。GitHub Actions の上では、実行の結果のページにも出る

## 5.4 スクリプトのテスト

`scripts/ci/tests/test_verify_consumer_android.py` (47 件)。一時のディレクトリに、スクリプトの写しと、呼ばれ方を記録する偽物の `gradlew` を置き、スクリプトを別のプロセスとして流す。発行も組み立ても、実際には走らない。

```
python3 scripts/ci/run-tests.py
実行 186 件 / 失敗 0 件 / スキップ 0 件      (Ran 186 tests in 9.9s。足す前は 139 件)
```

## 5.5 手元で local の確認を流した

```
ANDROID_HOME=<Android SDK の場所> python3 scripts/ci/verify-consumer-android.py --mode local
```

| 回 | 状態 | 所要時間 | 結果 |
|---|---|---|---|
| 1 | 本体と利用者役のビルドの出力が、どちらも残っている | 5.1 秒 (発行 2 秒・組み立て 1 秒・依存の一覧 1 秒ほど) | 終了コード 0 |
| 2 | 利用者役のビルドの出力 (`verification/android/app/build/`) を消してから。本体のビルドの出力は残っている | 22.7 秒 (発行 2 秒・組み立て 19 秒) | 終了コード 0。`:app:minifyReleaseWithR8` が実行された |

どちらも、Gradle のデーモンが動いていて、依存の取得が済んでいる状態である。依存を 1 から取得する状態・本体のビルドの出力が無い状態での所要時間は、測っていない (ランナーでの値は tasks 9.2 で見る)。

依存の一覧の、本ライブラリの行 (2 回とも同じ):

```
+--- jp.kamusoft:kscollectionview:0.1.0-SNAPSHOT
|    +--- androidx.compose.foundation:foundation -> 1.11.4
```

スクリプトが最後に出した概要:

```
### Android の利用者の立場のビルドの確認

- 切り替え: `local` (取得元: 作業用の Maven リポジトリ (今の本体を発行したもの))
- 確かめた座標: `jp.kamusoft:kscollectionview:0.1.0-SNAPSHOT`
- 利用者役のリリースの組み立て (コード縮小あり): 成功
- 実行時の依存 (`releaseRuntimeClasspath`) に、上の座標が指定の版で現れる: 確認した
```

確認の前後で比べたもの (2 回とも):

| 比べたもの | 比べ方 | 結果 |
|---|---|---|
| 追跡しているファイル | `git diff` の出力を、確認の前に取ったものと比べた | 差なし |
| 追跡していないファイルの一覧 | `git status --porcelain -uall` の出力を、確認の前に取ったものと比べた | 差なし (ビルドの出力は、追跡の対象外の場所にだけできた) |
| 既定の手元の Maven リポジトリ | `~/.m2/repository/jp/kamusoft/` の下のファイルの一覧 (大きさと更新の時刻つき、431 行) を、確認の前に取ったものと比べた | 差なし。`kscollectionview` のディレクトリは、前も後も無い |
| スクリプトが作った一時のディレクトリ | 一時のディレクトリの置き場で、名前が `kscollectionview-maven-` で始まるものを探した | 残っていない |

作業ツリーには、この変更のほかのグループの未 commit の変更があるので、「変更が無い作業ツリー」からは始めていない。確かめたのは、確認の前と後で差が無いことである。

## 5.6 作業用のリポジトリに発行物が無いと失敗する

空のディレクトリを取得元に渡して、利用者役を組み立てた。

```
(verification/android/) ./gradlew --console=plain -PksCollectionViewMode=local -PksCollectionViewRepository=<空のディレクトリ> -PksCollectionViewVersion=0.1.0-SNAPSHOT :app:assembleRelease
```

終了コード 1。出力の要点:

```
> Task :app:mergeReleaseNativeLibs FAILED

* What went wrong:
Execution failed for task ':app:mergeReleaseNativeLibs' (registered by plugin 'com.android.internal.application').
> Could not resolve all files for configuration ':app:releaseRuntimeClasspath'.
   > Could not find jp.kamusoft:kscollectionview:0.1.0-SNAPSHOT.
     Searched in the following locations:
       - file:<空のディレクトリ>/jp/kamusoft/kscollectionview/0.1.0-SNAPSHOT/maven-metadata.xml
       - file:<空のディレクトリ>/jp/kamusoft/kscollectionview/0.1.0-SNAPSHOT/kscollectionview-0.1.0-SNAPSHOT.pom
     Required by:
         project ':app'
   > Could not find androidx.compose.foundation:foundation:.
     Required by:
         project ':app'

BUILD FAILED in 1s
```

- 探した場所は、渡したディレクトリだけである。Google のリポジトリと Maven Central は、`jp.kamusoft` を探していない
- 2 つ目の `foundation` の失敗は、版を決める BOM が本ライブラリから届かなかったためである

確認のスクリプトを通した失敗は、スクリプトのテスト (組み立ての失敗が終了コード 1 になり、失敗の本文が出力に出て、依存の確認を始めない) で確かめている。スクリプトは毎回発行するので、発行物が無い状態を、スクリプトを通して実物で作ることはしていない。

## `published` の取得元 (公開物が無いので、取得の成功は確かめていない)

公開されていない版を渡して、確認のスクリプトを流した。Maven Central に、無い版を 1 回問い合わせている。

```
python3 scripts/ci/verify-consumer-android.py --mode published --version 0.0.0-unpublished
```

終了コード 1。本体の発行は始まらず、利用者役の組み立てから始まった。出力の要点:

```
==== 利用者役のリリースを組み立てる (コード縮小あり) ====
> Task :app:mergeReleaseNativeLibs FAILED
   > Could not find jp.kamusoft:kscollectionview:0.0.0-unpublished.
     Searched in the following locations:
       - https://repo.maven.apache.org/maven2/jp/kamusoft/kscollectionview/0.0.0-unpublished/kscollectionview-0.0.0-unpublished.pom
BUILD FAILED in 774ms
::error::利用者役の組み立てが失敗した (Gradle の終了コード 1)。理由は、上の Gradle の出力にある
```

探した場所は、Maven Central だけである。

引数の誤りも、実物で 2 つ流した (どちらも終了コード 2 で、Gradle は呼ばれていない)。

```
--mode smoke       → ::error::--mode は local か published のどちらかにする: 'smoke'
--mode published   → ::error::--mode published では --version が必須である (取る版を決められない)
```

## 5.7 コード縮小を有効にした利用者役の起動

| 項目 | 値 |
|---|---|
| 入れたもの | 5.5 と同じコマンド (`--mode local`) で組み立てた `app-release.apk` (2,138,228 バイト。コード縮小あり・デバッグ用の鍵で署名) |
| エミュレータ | 作業専用に作った AVD `ksn-package-distribution-pixel8` (機種の定義 Pixel 8、Android 16・API 36、Google APIs の arm64 のイメージ、Android Emulator 37.1.11)。画面を出さずに起動した |
| 操作 | `adb` は、作業専用のエミュレータのシリアルを毎回指定した。つながっていた実機 2 台と、既存の AVD には触っていない |

手順と結果:

1. APK を入れた (`Success`)
2. 端末の記録を消してから、`am start -W` で `MainActivity` を起動した。`Status: ok`・`LaunchState: COLD`・`TotalTime: 538` (ミリ秒)
3. 4 秒待って、画面の写しを取り、画面の要素の一覧 (`uiautomator dump`) を取った。要素の文字に `Item 0` 〜 `Item 20` の 21 行があった
4. 一覧を上へスワイプして、もう 1 度要素の一覧を取った。`Item 21` 〜 `Item 41` に変わった (スクロールしている)。プロセスの番号は、起動のときと同じだった (落ちて起動し直していない)
5. 端末の記録を取り出した (2,553 行)。`FATAL EXCEPTION` の行は 0 行。`AndroidRuntime` のエラーの行も 0 行 (`AndroidRuntime` を含む行は 5 行あり、どれも `uiautomator` のコマンド自身の起動と終了の記録)
6. エミュレータを止め、AVD を削除した。`emulator -list-avds` に、作った AVD が残っていないことを確かめた

画面の写し: `consumer-android-list-minified.png` (1080 × 2400。`Item 0` 〜 `Item 20` の行と、行の間の区切り線が出ている。個人を特定する要素は写っていない)

端末の記録の抜粋: `consumer-android-launch-logcat.txt` (29 行。起動の 2 行と、利用者役のプロセスが出した行のうち、長い一覧の 1 行を除いたもの。`log-sanitize.py` を通した。置き換えの対象は無かった)。要点:

```
ActivityTaskManager: START u0 {... cmp=jp.kamusoft.kscollectionview.verification.android/.MainActivity} ...
ActivityTaskManager: Displayed jp.kamusoft.kscollectionview.verification.android/.MainActivity for user 0: +538ms
```

利用者役のプロセスが出したエラーの水準の行は 2 行で、どちらも本ライブラリに由来しない (デバッガを始めないという知らせと、`ashmem` の非推奨の知らせ)。

確かめた範囲は、最小の利用例が通る経路 (一覧の表示・区切り線・スクロール・起動時のコンテキストの捕捉) である。画像の読み込み・ページング・並べ替えなど、利用例が触らない機能は、コード縮小の後の動きを確かめていない。

## 標準の lint

| 検査 | 結果 |
|---|---|
| `python3 scripts/ci/run-tests.py` | 実行 186 件 / 失敗 0 件 / スキップ 0 件 |
| `python3 scripts/ci/check-workflows.py` | 違反は無い (workflow は変えていない) |
| `python3 scripts/local-path-lint.py`・`identity-lint.py`・`comment-policy-lint.py` | 引数なし (全体) と、足したファイルを名指しした形の両方で、どれも終了コード 0。コメントの規約は禁止 0 件 |

コメントの規約の検査は、禁止する参照だけを機械で見る。足したコメントは、規約の本文の禁止の類型 (作業文書への参照・議論やタスクの通番・履歴の記述・デルタスペックの語) と、目で突き合わせた。

## 確かめていないこと

- `published` での取得の成功 (公開物が無い。最初のリリースで確かめる)
- ランナー (Linux) の上での確認の実行と所要時間 (tasks 9.2)
- 依存を 1 から取得する状態での所要時間
- 利用例が触らない機能の、コード縮小の後の動き
- Windows での確認のスクリプトの実行 (`gradlew` を直に呼ぶので、対象にしていない)
