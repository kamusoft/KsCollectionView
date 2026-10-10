# 証跡: ルートの README とスクリーンショット (tasks グループ 4)

2026-10-10 に手元で確かめた結果。パスはリポジトリのルートからの相対で書く。

## 4.1 対応プラットフォームの表の値と出どころ

### iOS

| 表の値 | 出どころ | 読んだ値 |
|---|---|---|
| 最低の OS: iOS 16 | `ios/Package.swift` の `platforms` | `.iOS(.v16)` |
| 利用する側に必要: Xcode 27 以上 | `ios/Package.swift` の先頭の行 | `// swift-tools-version: 6.4` (Swift 6.4 のツールを持つのは Xcode 27 から。`kasane/handbook/cross/package-distribution.md` の決まりと同じ) |
| ビルドに使っているもの: Xcode 27.0 (Swift tools 6.4) | `.github/workflows/verify-ios.yml`・`verify-consumer-ios.yml` の `KS_XCODE_VERSION` と、手元の `xcodebuild -version` | `"27.0"` / Xcode 27.0 (Build version 27A266a) |

### Android: 最低の OS と、ライブラリのビルドに使っているもの

| 表の値 | 出どころ | 読んだ値 |
|---|---|---|
| 最低の OS: Android 10 (API 29) | `android/kscollectionview/build.gradle.kts` の `defaultConfig` | `minSdk = 29` |
| Android Gradle Plugin 9.4.0 | `android/gradle/libs.versions.toml` の `agp` | `9.4.0` |
| Kotlin 2.4.10 | 同 `kotlin` | `2.4.10` |
| Compose BOM 2026.06.01 | 同 `compose-bom` | `2026.06.01` |
| Gradle 9.7.0 | `android/gradle/wrapper/gradle-wrapper.properties` の `distributionUrl` | `gradle-9.7.0-bin.zip` |
| JDK 21 | `.github/workflows/verify-android.yml`・`verify-consumer-android.yml` の `java-version` と、手元の `java -version` | `"21"` / 21.0.12.1 |
| 配布物の対象は Java 17 | `android/kscollectionview/build.gradle.kts` の `compileOptions`・`jvmTarget` と、発行した AAR のクラスファイル | `VERSION_17`・`JVM_17` / `major version: 61` (Java 17) |

### Android: 利用する側のビルドに必要なもの

本体を、スクラッチのディレクトリの Maven リポジトリへ発行し (`:kscollectionview:publishToMavenLocal` に `-Dmaven.repo.local=<スクラッチ>`)、発行物と、利用者役の実行時の依存の木 (`verification/android/` で `:app:dependencies --configuration releaseRuntimeClasspath`) を読んだ。

| 表の値 | 出どころ | 読んだ値 |
|---|---|---|
| minSdk 29 以上 | 発行した AAR の `AndroidManifest.xml` | `<uses-sdk android:minSdkVersion="29" />`。利用者役の `minSdk` も 29 (`verification/android/app/build.gradle.kts`) |
| compileSdk 36 以上 | 発行した AAR の `META-INF/com/android/build/gradle/aar-metadata.properties` | `minCompileSdk=36`。本ライブラリが持ち込む Coil 3.5.0 の AAR 6 つも `minCompileSdk=36`。Compose 1.11.4 の AAR は 34 か 35。利用者役の `compileSdk` は 36 |
| Android Gradle Plugin 8.6.0 以上 | 本ライブラリの依存の部分木にある AAR の `minAndroidGradlePluginVersion` の最大 | `8.6.0` (Compose 1.11.4 の `ui`・`foundation`・`foundation-layout`・`animation`・`animation-core`・`ui-graphics`・`ui-text`・`runtime-saveable`、`material3` 1.4.0、`material-ripple` 1.11.4、`androidx.core` 1.16.0、`lifecycle-runtime-compose` 2.9.4、`transition` 1.6.0)。本ライブラリ自身の AAR は `1.0.0` |
| Kotlin 2.3 以上 | 発行した AAR のクラスの Kotlin のメタデータの版 (`javap -v` で `KsCollectionViewKt` を読んだ) と、発行した `.module` の依存 | `mv=[2,4,0]`・`kotlin-stdlib` は `2.4.10` を要求。Kotlin のコンパイラは、自分の版の 1 つ先までのメタデータを読めるので、2.4 のメタデータを読める最も古いコンパイラは 2.3 |

- 依存の木に現れる `androidx.activity` 1.11.0 (AGP の下限 8.9.1) は、利用者役が自分で足している `activity-compose` が引き上げた版である。本ライブラリが持ち込む版は `activity-compose:1.8.2` (AGP の下限 1.0.0) なので、表の値には数えていない
- AAR のメタデータの値は、Gradle のキャッシュにある、依存の木が解決した版の AAR から読んだ (68 個)

確かめていないこと: 表の下限の組み合わせ (Android Gradle Plugin 8.6.0・Kotlin 2.3・compileSdk 36) で、利用する側のプロジェクトを実際にビルドすること。ビルドして確かめたのは、利用者役の今の設定 (Android Gradle Plugin 9.4.0・Kotlin 2.4.10・compileSdk 36・minSdk 29) だけである。Kotlin と Android Gradle Plugin の下限は、メタデータから読み取った値である。

## 4.2 ライセンスの確認

### Sample に、第三者の通知が要る素材が無いこと

`git ls-files samples` を、拡張子と置き場で調べた。

| 調べたもの | 結果 |
|---|---|
| 画像・フォント (`png`・`jpg`・`jpeg`・`webp`・`gif`・`svg`・`pdf`・`heic`・`ttf`・`otf`・`ttc`・`woff`・`woff2`) | 0 件 |
| Android のリソースの置き場 (`res/drawable`・`res/mipmap`・`res/font`・`res/raw`) | 0 件 |
| iOS のアセットカタログ (`xcassets`) | 0 件 |
| Sample だけの依存 (`samples/android/app/build.gradle.kts`・`samples/android/gradle/sample.versions.toml`) | Compose・Navigation Compose・Activity Compose・計測用の AndroidX だけ。アイコンの素材を持ち込む依存は無い |

Sample に同梱の画像・フォントは無いので、README に第三者の通知の節は置いていない。画像グリッドの画面は、実行時に外から画像を取得するが、同梱はしていない (この画面は撮っていない)。

### 本ライブラリが依存するライブラリのライセンス

| プラットフォーム | ライブラリ (直接の依存) | ライセンス | 読んだ場所 |
|---|---|---|---|
| iOS | Nuke 13.2.0 (`Nuke`・`NukeUI`) | MIT License | SwiftPM が取得したソースの `LICENSE` (先頭の行が `The MIT License (MIT)`)。版は `ios/Package.resolved` |
| Android | Compose (`runtime`・`ui`・`foundation`・`foundation-layout`・`animation`・`animation-core` 1.11.4、`material3` 1.4.0) | Apache License 2.0 | Gradle のキャッシュの各 POM の `<licenses>` |
| Android | `androidx.startup:startup-runtime` 1.1.1・`androidx.annotation:annotation` 1.9.1 | Apache License 2.0 | 同上 |
| Android | Coil 3.5.0 (`coil-compose`・`coil-network-okhttp`) | Apache License 2.0 | 同上 |
| Android | Kotlin の標準ライブラリ 2.4.10 | Apache License 2.0 | 同上 |

README の表は、直接の依存を 4 行 (Nuke / Compose とそのほかの AndroidX / Coil / Kotlin の標準ライブラリ) にまとめ、その先の依存も一緒に取得されることを文で書いた。Coil が持ち込む OkHttp (4.12.0) も、POM のライセンスは Apache License 2.0 である。

本ライブラリのライセンスは、`LICENSE` (MIT License・名義 kamusoft) と、発行の設定の POM の `licenses` (MIT License) が一致している。

## 4.3 スクリーンショット

### 撮った環境

| 項目 | iOS | Android |
|---|---|---|
| 作業専用の端末 | 新しく作った Simulator `ksn-user-docs-readme-ip17` (iPhone 17・iOS 27.0) | 新しく作った AVD `ksn-user-docs-readme-pixel8` (機種の定義 Pixel 8・Android 16 (API 36)・Google APIs の arm64 のイメージ)。空いているポートを指定し、画面を出さずに起動した |
| 操作の宛先 | 毎回、作った Simulator の UDID を指定した | 毎回、作ったエミュレータのシリアルを指定した。入れる前と止める前に、`adb -s <android-serial> emu avd name` が `ksn-user-docs-readme-pixel8` を返すことを確かめた |
| 触っていないもの | 既存の Simulator (起動していたものは無かった) | つながっていた実機 2 台と、既存の AVD 1 つ |
| Sample のビルド | `samples/ios/` の scheme `KsCollectionViewSamples` を Debug でビルド。出力先はスクラッチのディレクトリ。署名なし (`CODE_SIGNING_ALLOWED=NO`) | `samples/android/` で `:app:assembleDebug`。できた APK を `adb install` で入れた |
| 表示 | ライト (`simctl ui <uuid> appearance light`。Sample の外観の選択は初期値の「システム」) | ライト (`cmd uimode night` が `Night mode: no`。Sample の外観の選択は初期値) |
| ステータスバー | `simctl status_bar` で、時刻 9:41・電波と電池を固定の表示にした | システムのデモ表示で、時刻 9:41・通知のアイコンなし・電池 100% にした |
| 画面の開き方 | 起動引数 `--screen <画面の名前>` で直接開いた | `am start` の `--es ks_start_route "demo/<画面の名前>"` で直接開いた |
| 状態 | 開いた直後 (スクロールしていない。操作していない) | 同じ |

Sample のソースは変えていない。

### 6 枚に写っているもの

保存した後に 1 枚ずつ開いて確かめた。

| ファイル (`assets/`) | 大きさ | 写っているもの | 外から取得した画像 | 個人を特定する情報 |
|---|---|---|---|---|
| `ios-list.png` | 1206 × 2622 | 画面「リスト」。区切り線の切り替え (既定を選択)、Apple〜Fig の 6 行と区切り線 | 無い | 無い |
| `ios-grid.png` | 1206 × 2622 | 画面「グリッド (固定列)」。レイアウトの切り替え (grid を選択)、3 列 × 3 行の色の四角と Item 1〜9 | 無い | 無い |
| `ios-grouping.png` | 1206 × 2622 | 画面「グループ化」。固定された見出し「グループ 1・1,200 件」、2 列の Item 1〜22 (Item 7 と 14 は長い文)、下の操作のバー | 無い | 無い |
| `android-list.png` | 1080 × 2400 | 画面「リスト」。iOS と同じ切り替えと、Apple〜Fig の 6 行と区切り線 | 無い | 無い |
| `android-grid.png` | 1080 × 2400 | 画面「グリッド (固定列)」。iOS と同じ切り替えと、3 列 × 3 行の色の四角と Item 1〜9 | 無い | 無い |
| `android-grouping.png` | 1080 × 2400 | 画面「グループ化」。固定された見出し「グループ 1・1,200 件」、2 列の Item 1〜22、下の操作のバー | 無い | 無い |

- 写っている文字は、Sample の固定のデモデータ (果物の名前・`Item <番号>`・Sample の文言) と、固定にしたステータスバーだけである。端末の名前・アカウント・通知・通信事業者の名前は写っていない
- 色の四角は、Sample が色で描いているもので、画像のファイルではない
- 6 枚の PNG に、文字のコメント・位置・機種の名前の埋め込みは無い。PNG のチャンクの種類を読んで確かめた。Android の 3 枚は画素と色の情報のチャンクだけを持つ。iOS の 3 枚は、ほかに Exif のチャンクを 1 つ持ち、中身は色空間と画素の幅・高さの 3 項目だけである
- 両プラットフォームは、同じ 3 つの画面を、同じ状態 (開いた直後・先頭) で写している。README では、6 枚を同じ幅 (220) で表に並べ、列を画面、行をプラットフォームにした

両プラットフォームで揃っていない点:

- iOS は、画面の上のバーに戻るボタンが無い (起動引数で直接開いたため)。Android は、同じ開き方でも戻る矢印が出る
- Android のステータスバーの時刻とアイコンは、白で描かれていて、明るい背景の上でほとんど見えない。デモ表示を外しても同じだった (Sample の今の表示である。Sample は変えていない)
- 画像の縦横比が、機種の違いで少し違う (iOS 1206 × 2622・Android 1080 × 2400)

### 後片付け

| 確かめたこと | 結果 |
|---|---|
| 作った Simulator を止めて削除した | `simctl list devices` に `ksn-user-docs-readme` を含む行が 0 行 |
| 作ったエミュレータを止め、AVD を削除した | エミュレータのプロセスが 0 個。`emulator -list-avds` と AVD の置き場に、作った AVD が無い。残っているのは、既存の AVD 1 つだけ |
| Sample のビルドが、追跡しているファイルを変えていない | 撮った後の `git status --short` に、`samples/` の下の行が無い (Xcode のプロジェクトのファイルに、開発者の識別子は書き戻されていない) |

## 4.4 README の検査

`python3 scripts/ci/check-readme-examples.py .` の結果: 違反 4 件。4 件とも、`SKILL.md` がまだ無いこと (`skills/{en,ja}/kscollectionview-{ios,android}/SKILL.md`: ファイルが無い) である。README の 2 枚に由来する違反は 0 件 (最小コード例の 4 か所・インストール例の値と `{version}`・最新の版の確かめ先・英日の例の種類と数)。

README の Skill への導線のリンクの先 (`skills/` の下の 6 つ) は、まだ無い。Skill の制作 (tasks グループ 5〜7) で作る。

## 流した確認 (グループ 4 の終わり)

| 確認 | コマンド | 結果 |
|---|---|---|
| README の検査 | `python3 scripts/ci/check-readme-examples.py .` | 違反 4 件 (上のとおり、どれも `SKILL.md` が無いこと) |
| スクリプトのテスト | `python3 scripts/ci/run-tests.py` | 実行 385 件 / 失敗 0 件 / スキップ 0 件 (着手の前と同じ件数。README の既存のテスト 3 件 (英日の見出しの一致・ライセンスと貢献の案内への導線・互いを指す) を含む) |
| ローカル絶対パスの lint | `python3 scripts/local-path-lint.py` | 終了コード 0 |
| 識別の lint | `python3 scripts/identity-lint.py` | 終了コード 0 (範囲は `kasane`・`skills`・`samples`。撮った後の `samples/` を含む) |
| 識別の lint (README と Xcode のプロジェクト) | `python3 scripts/identity-lint.py --paths README.md README_ja.md samples/ios/KsCollectionViewSamples.xcodeproj` | 終了コード 0 |
| コメントの規約の lint | `python3 scripts/comment-policy-lint.py` | 禁止 0 件 (検査対象 504 ファイル) |
| workflow の定義の検査 | `python3 scripts/ci/check-workflows.py` | 違反は無い |

## 検収での決定: Android の利用する側の下限 (2026-10-10)

- 4.1 で、利用する側の下限として載せた 4 つの値のうち、Android Gradle Plugin 8.6.0 以上と Kotlin 2.3 以上は、メタデータから読んだ値で、その版でのビルドは確かめていなかった (レビューと、読ませる確認でも挙がった)
- オーナーの決定 (2026-10-10): 確かめていない 2 つを、下限から外す。利用する側の下限は minSdk 29・compileSdk 36 だけにし、Android Gradle Plugin と Kotlin は「ライブラリのビルドに使っているもの」の側にだけ残す
- 直した場所: `README.md`・`README_ja.md` の対応プラットフォームの表と、その下の説明 / `skills/{en,ja}/kscollectionview-android/SKILL.md` の導入の表 (2 行を外し、下限を示していないことと、確かめてある版を 1 文で書いた)
- 直した後: スクリプトのテスト 504 件・失敗 0 / 2 本の検査は違反なし / 網羅の道具は漏れ 0 件

## 検収での決定: iOS のスクリーンショットの戻るボタン (2026-10-10)

- iOS の 3 枚に戻るボタンが写っていない差は、今回は直さない (オーナーの決定)。Android の 3 枚を撮り直すとき (簡易起票 `android-sample-status-bar-contrast`) に、iOS もメニューからたどって開いた状態で撮り直して揃える。簡易起票の未決の論点に書き足した
