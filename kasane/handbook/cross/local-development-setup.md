---
kind: guide
applies-when:
  always: false
  tasks: [環境構築, Sample の起動, 本体のビルド・lint, 本体 source へのステップイン]
title: ローカル開発環境と Sample の実行
description: iOS / Android のローカル環境設定、Sample の起動、本体のビルドとステップインの手引き。両プラットフォームとも実際に確認した手順を記す
timestamp: 2026-09-17
---

# ローカル開発環境と Sample の実行

この文書は、リポジトリを clone した開発者が iOS・Android の Sample を開いて実行し、本体をビルドし、本体 source へデバッガでステップインするまでの手順をまとめる。

iOS の SwiftPM パッケージと Android の Gradle ビルドルート、および両者の Sample はいずれも成立済みであり、本書には実際に確認した手順を記す。**未検証の手順を現行の手引きとして書かないこと** — 動かない手順は、無い手順より読み手の時間を奪う。

[cross/ADR-0002](../../decisions/cross/0002-monorepo-platform-build-roots.md) を先に読むと、プラットフォームごとに独立したビルドルートを持つ理由が分かる。

## 必要環境

決定済みの下限は次のとおり。

| 対象 | 決定済みの下限 |
|---|---|
| iOS | iOS 16 以上 (`UIHostingConfiguration` 依存) の Simulator または実機 |
| Android | minSdk 29 (Android 10) 以上の Emulator または実機 |

Android の開発ツール側は次を要する。Gradle と AGP・Kotlin・Compose BOM は手で入れるものではなく、
wrapper とバージョンカタログがビルド時に取得する (版の宣言元は次節の表を見る)。

| 対象 | 要件 | 確かめ方 |
|---|---|---|
| JDK | 17 (`jvmToolchain(17)` と `compileOptions` が要求) | `/usr/libexec/java_home -v 17` が場所を返す |
| Android SDK Platform | android-36 (`compileSdk = 36`。minor 指定なし) | SDK の `platforms/` に `android-36` がある |
| Android Build-Tools | 36.0.0 (AGP が compileSdk から選ぶ既定) | SDK の `build-tools/` に `36.0.0` がある |

JDK 17 が既定の JDK でない環境では、Gradle を呼ぶときに `JAVA_HOME=$(/usr/libexec/java_home -v 17)` を
前置きする。Xcode・Swift・Android Studio の版は下限を定めていない。

iOS の開発ツール側の要件 (Xcode・Swift の版) は、下限を定める必要が生じた時点でここへ追記する。

## 版の定義元

手元の版が要件に合うか調べるときは、**版を書き写した資料ではなく定義元のファイルを見る**。書き写した一覧は更新に追随せず、食い違ったときにどちらが正か分からなくなる。

定義元を追記するときは、次の原則で選ぶ。

- 版ごとに**単一の宣言元**を決め、他の箇所はそれを読む。同じ版を 2 箇所に書かない
- ビルドが実際に読むファイルを定義元にする。ドキュメントや README を定義元にしない
- 定義元が決まっていない版は「未確定」と書く。仮の値を書いて既成事実にしない

| 対象 | 定義元ファイル |
|---|---|
| Swift tools version・iOS 最低対応版・product / target | `ios/Package.swift` |
| iOS Sample の最低対応版・bundle ID | `samples/ios/KsCollectionViewSamples.xcodeproj/project.pbxproj` |
| AGP・Kotlin・Compose BOM・Navigation・compileSdk / targetSdk・ライブラリの版 | `android/gradle/libs.versions.toml` |
| Gradle の版 (本体 / Sample それぞれの wrapper) | `android/gradle/wrapper/gradle-wrapper.properties` と `samples/android/gradle/wrapper/gradle-wrapper.properties` |
| Android の minSdk・JDK・namespace | `android/kscollectionview/build.gradle.kts` |
| Android Sample の application ID・minSdk・ビルド構成 | `samples/android/app/build.gradle.kts` |
| Sample でしか使わない依存 (Activity Compose・計測) の版 | `samples/android/gradle/sample.versions.toml` |

Sample は本体のカタログを `settings.gradle.kts` の `versionCatalogs` で `libs` として読み込むため、
共有する版を Sample 側で宣言し直さない。Sample 固有の依存だけが `sampleLibs` に分かれている。

## 環境変数と SDK ロケーション

Android SDK の場所は、ビルドルートごとの `local.properties` に `sdk.dir=<Android SDK の場所>` として書く。
このファイルはローカル環境固有のため git 管理外であり、clone した直後には存在しない。

**`android/` と `samples/android/` は独立したビルドルートであり、`local.properties` もそれぞれに要る。**
片方だけを置くと、置いた側のビルドは通り、もう片方だけが SDK を見つけられずに失敗する。片方の成功を
「設定できた」と読み違える落とし穴は翻案元でも実際に起きている
(参考: `../KsSettingsView/kasane/handbook/cross/local-development-setup.md`)。

JDK 17 が既定でない環境では、Gradle を呼ぶコマンドに `JAVA_HOME=$(/usr/libexec/java_home -v 17)` を前置きする。
実機・エミュレータが複数つながっている環境では、導入先を 1 台に絞るのに `ANDROID_SERIAL=<端末の識別子>` を使う
(指定しないと接続中の全端末へ導入される)。

複数の Xcode を併用する環境での選択の固定方法は、必要になった時点でここへ追記する。

## Sample を開く / 実行する

iOS Sample は `samples/ios/KsCollectionViewSamples.xcodeproj` を Xcode で開き、scheme `KsCollectionViewSamples` と利用可能な iOS Simulator を選んで実行する。本体は `../../ios` の Local Package として解決される。

CLI のビルドは `samples/ios/` で `xcodebuild build -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,name=<利用可能な機種名>,OS=<利用可能な版>' -configuration Debug CODE_SIGNING_ALLOWED=NO` を実行する。

iOS の実機で実行・計測するときは、機体を UDID で指名する (`-destination 'platform=iOS,id=<UDID>'`)。
接続中の機体は `xcrun xctrace list devices` の Devices 節に出る。

実機へ入れるビルドの署名は、`xcodebuild` に `DEVELOPMENT_TEAM=<チーム ID> CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates` を渡して行い、Xcode の画面では設定しない。画面で設定するとチーム ID が `samples/ios/` のプロジェクトファイルへ書き戻され、commit 前の識別子の検査で止まる。チーム ID は、以前に実機へ入れたビルドの `embedded.mobileprovision` を `security cms -D -i <ファイル>` で開いた `TeamIdentifier` で確かめられる。

**実機が一覧に出るのに使えないときは、端末側ではなく Mac 側のペアリングが確立していないことがある。**
`xcrun devicectl list devices -v` で該当機体の `developerModeStatus` が `nil`、`ddiServicesAvailable` が
`false` になっているのがその状態で、UDID や OS 版のような基本情報は読めるのにデベロッパモードの状態を
問い合わせられていないことを意味する (一覧の State は `unavailable`、`xcodebuild -showdestinations` の
候補にも現れない)。次で張り直す:

```
xcrun devicectl manage pair --device <UDID>
```

成功すると State が `available (paired)` になり、ビルド先の候補にも現れる。**端末の解錠・信頼・
デベロッパモードがすべて済んでいてもこの状態になる**ため、端末を疑う前に張り直しを試す。

Android Sample は `samples/android/` を Android Studio で開く (このディレクトリがビルドルートであり、
リポジトリ直下や `android/` を開くのではない)。CLI からは `samples/android/` で
`./gradlew :app:installDebug` を実行すると、接続中の端末へ導入される。導入先を 1 台に絞るときは
`ANDROID_SERIAL` を前置きする。

起動時に開く画面を指定できる。ルートメニューを経由せず目的の画面を直接開くための入口で、
静止画の撮影や計測でも同じ指定を使う。

```
adb shell am start -n jp.kamusoft.kscollectionview.samples.android/.MainActivity \
  --es ks_start_route "demo/LargeData"
```

経路の文字列は `demo/<SampleScreen の名前>` と `verification/<VerificationScreen の名前>`。
組み立ては `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/SampleRoutes.kt`
の 1 か所にあり、名前は enum の宣言 (次節の定義元) がそのまま入る。

性能計測は Sample と同じビルドルートの計測モジュールが行う。`samples/android/` で
`./gradlew :benchmark:connectedBenchmarkAndroidTest` を実行する。**実機が要る** (計測対象を
別プロセスとして観測するため、エミュレータでは計測しない)。

Sample の識別子は [cross/ADR-0003](../../decisions/cross/0003-public-identifier-namespace.md) の `jp.kamusoft.kscollectionview.samples.ios` / `.android` に従う。

## 本体をビルドする

Sample ではなく本体だけをビルドする場合は `ios/` で `xcodebuild build -scheme KsCollectionView -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO` を実行する。

Android は `android/` で `./gradlew :kscollectionview:assemble` を実行すると debug / release の AAR が
できる。`android/` の Gradle は Sample を知らないため、本体だけを速く回したいときはこちらを使う。

テストの実行方法と完了判定は [テスト実行規約](test-execution.md) が正であり、本節はビルドのみを扱う。本節にテスト実行コマンドを書かないこと (二重管理になり、片方だけが更新される)。

## 本体 source へステップインする

iOS Sample の Xcode project navigator で Package Dependencies の `KsCollectionView` を開くと、`ios/Sources/KsCollectionView/` の source を直接参照できる。そこへ breakpoint を置き、Sample scheme を Debug 実行してステップインする。

Android Sample は本体を Gradle の composite build で取り込む。`:app` の依存は利用者と同じ配布座標
`jp.kamusoft:kscollectionview` 1 行だが、`samples/android/settings.gradle.kts` の明示置換によって
`android/` のプロジェクトへ差し替わる。`android/kscollectionview/src/main/kotlin/` の source へ
breakpoint を置き、`:app` を debug 実行すればそのまま止まる。

置換が効いていることは、Sample のビルド出力に本体側のタスク (`:android:kscollectionview:...`) が
現れることで分かる。置換先を失った場合は公開版へ静かに落ちるのではなくビルドが失敗する。

## デモ画面一覧はどこを見るか

画面の集合・表示名・遷移先は、**各 Sample の `SampleScreen` 実装が正である**。一覧を書き写した資料は増減に追随しないので、実装ファイルを直接見る。

- iOS の定義元は `samples/ios/KsCollectionViewSamples/SampleScreen.swift`
- Android の定義元は `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/SampleScreen.kt`
- プラットフォーム固有の検証画面は別区分で、Android は同じディレクトリの `VerificationScreen.kt` が定義元
- プラットフォーム間で揃える範囲と例外は [Sample のプラットフォーム間一致](sample-parity.md) を参照する

## 関連

- [cross/ADR-0002](../../decisions/cross/0002-monorepo-platform-build-roots.md) — `ios/` `android/` を独立したビルドルートとする決定
- [テスト実行規約](test-execution.md) — テストの実行方法と完了判定
- [Sample のプラットフォーム間一致](sample-parity.md) — Sample の一致規約
- [実行時挙動の検証規約](runtime-behavior-verification.md) — 実環境での確認が要る不具合の完了判定

出典: ../KsSettingsView/kasane/handbook/cross/local-development-setup.md (章立て・版の定義元の考え方・デモ画面一覧の原則)
