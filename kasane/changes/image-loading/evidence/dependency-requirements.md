# 依存追加後の利用者側要求値の確認 (tasks 1.1 / 1.2 / 1.3)

Nuke (iOS) と Coil (Android) を本体の依存に追加した後、**利用者アプリに要求される値**が現時点の
配布済み SDK に収まっていることを確認した記録。確認日 2026-09-06。

## Android: 利用者への compileSdk 要求

### 確認 1: 本体 AAR の aar-metadata

`android/` で `./gradlew :kscollectionview:assemble` を実行して得た
`android/kscollectionview/build/outputs/aar/kscollectionview-release.aar` の
`META-INF/com/android/build/gradle/aar-metadata.properties`:

```
aarFormatVersion=1.0
aarMetadataVersion=1.0
minCompileSdk=36
minCompileSdkExtension=0
minAndroidGradlePluginVersion=1.0.0
coreLibraryDesugaringEnabled=false
```

Coil 追加前と同じ `minCompileSdk=36` のまま。37 への引き上げは起きていない。

### 確認 2: Coil 3.5.0 の各 AAR の aar-metadata

依存グラフに入る Coil の AAR (`coil`, `coil-core`, `coil-compose`, `coil-compose-core`,
`coil-network-core`, `coil-network-okhttp`) をすべて読んだ。6 本とも `minCompileSdk=36` /
`minAndroidGradlePluginVersion=1.0.0`。Coil 3.6 系が要求するとされた compileSdk 37 は 3.5.0 には現れない。

### 確認 3: Sample (compileSdk 36) のビルド

`samples/android/` で `./gradlew :app:assembleDebug` → BUILD SUCCESSFUL。
Sample は利用者と同じ配布座標 1 行で本体を参照する構成であり、AGP は依存 AAR の `minCompileSdk` が
コンシューマの `compileSdk` を超えるとビルドを失敗させる。したがってこの成功は、
**依存グラフ全体のどの成果物も compileSdk 36 を超える要求を持たない**ことの確認でもある。

### 確認 4: 依存レポートの Compose の版

`samples/android/` で `./gradlew :app:dependencies --configuration debugRuntimeClasspath`:

```
androidx.compose.foundation:foundation:1.11.2 -> 1.11.4
androidx.compose.foundation:foundation-android:1.11.4
androidx.compose.foundation:foundation-layout:1.11.2 -> 1.11.4
io.coil-kt.coil3:coil-compose:3.5.0
io.coil-kt.coil3:coil-network-okhttp:3.5.0
```

Coil 3.5.0 が持ち込む foundation は 1.11.2 で、本体の Compose BOM 2026.06.01 (1.11.4) に吸収されて
**1.11.4 のまま**。BOM を超える引き上げは起きていない。

### 確認 5: `api` / `implementation` の届き方

`--configuration debugCompileClasspath` では `io.coil-kt.coil3:coil-compose:3.5.0` が現れ、
`coil-network-okhttp` は現れない。利用者は追加依存なしで Coil の Compose 連携 (`AsyncImage` 等) を
使え、ネットワーク fetcher は実行時のみに閉じる — 意図した置き方になっている。

## iOS: ビルドと警告

`ios/` で `swift package resolve` → `https://github.com/kean/Nuke.git` が **13.2.0** で解決。
`git ls-remote --tags` で公開タグを見ると 13 系の最大は 13.2.0 で、14 系のタグは存在しない
(`from: "13.2.0"` の許容範囲 `<14.0.0` の中で最新である)。
`ios/Package.resolved` は `.gitignore` 済み (追加はしていない)。

`ios/` で `xcodebuild clean build -scheme KsCollectionView -destination 'generic/platform=iOS Simulator'
-configuration Debug CODE_SIGNING_ALLOWED=NO` → `** BUILD SUCCEEDED **`。
出力全文の `warning:` は **0 件** (本体・Nuke・NukeUI を含むクリーンビルド)。
Swift 6 言語モード (`-swift-version 6`) で通っていることをコンパイラ引数で確認した。

iOS 側には Android の `aar-metadata` に相当する「利用者への SDK 要求値」の宣言はない。
利用者に効く下限は Nuke 13 系の deployment target であり、本体の `.iOS(.v16)` の方が高いため
利用者側の下限は変わらない。

## 残る注意

- Coil の版を 3.6 系へ上げるときは、この 5 つの確認をやり直す。特に確認 2 と 4
  (Compose 1.12 の推移で利用者に compileSdk 37 が要求される経路) が判定の中心になる
- 確認 3 は「compileSdk 36 で通る」ことしか言わない。利用者の compileSdk がこれより低い場合は
  本体の `compileSdk = 36` 自体が下限として効く (Coil の追加で変わった値ではない)
