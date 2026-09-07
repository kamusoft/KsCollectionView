# Android 到達点メモリのクラッシュ — 修正前後の A/B

## 状態

**解消済み。** 修正前は基準機で必ず落ち、修正後は同じ操作で落ちない。実機で走る回帰テストも
併せて追加し、そちらでも修正前 3 件失敗 / 修正後 3 件成功の A/B を取った。

環境: Pixel 4a / Android 13 (SDK 33) / Sample の debug 構成 / Compose BOM 2026.06.01 /
Coil 3.5.0 / compileSdk 36。

## 症状と原因

到達点をメモリにした先読みは元寸の画像をメモリキャッシュへ載せる。端末のデコードはこのとき
画素をグラフィックス側に置く構成 (`Bitmap.Config.HARDWARE`) を選ぶため、その画像は画素を
読み出せない。表示側は元寸をその場で枠の大きさへ縮小する作りなので、読み出しに入った時点で
落ちる。JVM 上のテスト環境の画像は常にソフトウェア側の構成のため、この分岐は踏まれない。

## 手順

1. `adb shell am start -n <Sample>/.MainActivity --es ks_start_route "measurement/image/10000/memory" --ez ks_reset_image_cache true`
2. 画像が出てから縦方向のフリックを繰り返す

## 修正前 (再現)

数回のフリックでプロセスが落ちる。

```text
FATAL EXCEPTION: main
java.lang.IllegalArgumentException: can't create mutable bitmap with Config.HARDWARE
    at android.graphics.Bitmap.createBitmap(Bitmap.java:1114)
    at coil3.Image_androidKt.toBitmap(Image.android.kt:162)
    at jp.kamusoft.kscollectionview.KsImageRequestFactory.downscale(KsImageRequestFactory.kt:124)
    at jp.kamusoft.kscollectionview.KsImageRequestFactory.prepare(KsImageRequestFactory.kt:95)
    at jp.kamusoft.kscollectionview.KsImageKt.KsLoaderImageContent$lambda$0(KsImage.kt:157)
```

## 修正後 (解消)

同じ手順で、送り 20 回 + 戻り 20 回のフリックを行っても `FATAL EXCEPTION` は 0 件、プロセスは
生存したまま。画像は読み込み中を挟まずに出る。画面の状態は
`image-grid-memory-prefetch-after-fix-android.png`。

## 実機で走る回帰テスト

`android/kscollectionview/src/androidTest/kotlin/jp/kamusoft/kscollectionview/KsImageDeviceDecodeTest.kt`
(`./gradlew :kscollectionview:connectedDebugAndroidTest`)。

| 検証 | 修正前 | 修正後 |
|---|---|---|
| 先読みが載せた元寸の画素を読み出せる | 失敗 (構成: HARDWARE) | 成功 |
| 元寸から作った表示用の画像が枠を超えない | 失敗 (同じ例外で落ちる) | 成功 |
| 読み出せない元寸があっても落ちず枠も超えない | 失敗 (同じ例外で落ちる) | 成功 |

修正前の失敗は 2 件が製品と同じ `IllegalArgumentException: can't create mutable bitmap with
Config.HARDWARE` であり、テストが再現しているのが同じ欠陥であることを示す。
