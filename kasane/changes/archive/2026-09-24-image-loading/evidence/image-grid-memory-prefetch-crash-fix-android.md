# Android 到達点メモリのクラッシュ — 修正の記録

## 状態

**解消済み。** 修正前は基準機で必ず落ち、修正後は同じ操作で落ちない。落ちない仕組みは
「読み出せない元寸は初回の描画に使わず、ローダーの縮小デコードを待つ」という表示側の分岐
(`KsDownscaleResult.Unreadable`) であり、実機で走る回帰テストで固定してある。

到達までに 2 段階を踏んでおり、この文書も 2 節に分かれる。

- [暫定回避 (2026-09-07、撤去済み)](#暫定回避-2026-09-07撤去済み) — 先読み側でハードウェア支援を切っていた時期の記録
- [現行の実装と検証 (2026-09-08)](#現行の実装と検証-2026-09-08) — 暫定回避を撤去した後の実機での検証

## 症状と原因

到達点をメモリにした先読みは元寸の画像をメモリキャッシュへ載せる。端末のデコードはこのとき
画素をグラフィックス側に置く構成 (`Bitmap.Config.HARDWARE`) を選ぶため、その画像は画素を
読み出せない。表示側は元寸をその場で枠の大きさへ縮小する作りなので、読み出しに入った時点で
落ちる。JVM 上のテスト環境の画像は常にソフトウェア側の構成のため、この分岐は踏まれない。

## 手順

1. `adb shell am start -n <Sample>/.MainActivity --es ks_start_route "measurement/image/10000/memory" --ez ks_reset_image_cache true`
2. 画像が出てから縦方向のフリックを繰り返す

## 修正前 (再現)

環境: Pixel 4a / Android 13 (SDK 33) / Sample の debug 構成 / Compose BOM 2026.06.01 /
Coil 3.5.0 / compileSdk 36。

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

## 暫定回避 (2026-09-07、撤去済み)

この時期の修正は 2 段構えだった。①先読みの要求にハードウェア支援を使わない指定
(`allowHardware(false)`) を付けて材料側を読み出せる画素にする、②読み出せない元寸は初回描画に
使わない分岐を表示側に置く。以下はその状態で取った記録であり、**①は撤去済みのため現行実装の
説明ではない**。

- Pixel 4a で同じ手順の送り 20 回 + 戻り 20 回のフリックを行っても `FATAL EXCEPTION` は 0 件、
  プロセスは生存したまま。①が効いているため、画像は読み込み中を挟まずに出ていた。画面の状態は
  `image-grid-memory-prefetch-after-fix-android.png` — **この静止画は暫定回避の適用中に撮った
  ものであり、現行実装の初回表示 (読み込み中を一瞬経由する) とは異なる**
- 実機の回帰テストは 3 件で、契約は次のとおりだった。修正 (①②) を外すと 3 件とも失敗し、うち
  2 件は製品と同一の `IllegalArgumentException: can't create mutable bitmap with Config.HARDWARE`
  で落ちた

| 当時の検証 | 修正前 | 修正後 |
|---|---|---|
| 先読みが載せた元寸の画素を読み出せる | 失敗 (構成: HARDWARE) | 成功 |
| 元寸から作った表示用の画像が枠を超えない | 失敗 (同じ例外で落ちる) | 成功 |
| 読み出せない元寸があっても落ちず枠も超えない | 失敗 (同じ例外で落ちる) | 成功 |

①はグラフィックス側に置かれるはずの画素をソフトウェア側へ移すため、描画のたびに転送費用が
乗る。到達点メモリの性能が基準を満たせなかったこともあり、オーナー判断で①を撤去して②だけに
任せる形へ変えた。

## 現行の実装と検証 (2026-09-08)

現行の実装は②だけ。先読みは画素の置き場をローダーと端末の判断に委ね (指定を付けない)、
表示側は読み出せない元寸を初回の描画に使わずローダーの縮小デコードを待つ。帰結として、実機の
到達点メモリの初回表示は**読み込み中を一瞬経由し、表示サイズのデコードが 1 回増える**。

環境: Pixel 6a / Android 16 (SDK 36) / 本体モジュールの androidTest (debug) / Coil 3.5.0 /
compileSdk 36。基準機 (Pixel 4a) は別の計測が占有していたため、この節の実行機は Pixel 6a。

### 実機テスト

`android/kscollectionview/src/androidTest/kotlin/jp/kamusoft/kscollectionview/KsImageDeviceDecodeTest.kt`
の 4 件。実行は次の 3 手 (基準機を占有せずに実行機を固定するため、Gradle の接続実行タスクは
使わない)。

```text
./gradlew :kscollectionview:assembleDebugAndroidTest
adb -s <実行機> install -r -t kscollectionview/build/outputs/apk/androidTest/debug/kscollectionview-debug-androidTest.apk
adb -s <実行機> shell am instrument -w -e class jp.kamusoft.kscollectionview.KsImageDeviceDecodeTest \
    jp.kamusoft.kscollectionview.test/androidx.test.runner.AndroidJUnitRunner
```

結果: **4 件成功 / 0 失敗** (`OK (4 tests)`)。内訳は次のとおり。

| 検証 | 確かめること | 結果 |
|---|---|---|
| `memoryPrefetchStoresGraphicsBackedImage` | 到達点メモリの先読みが落ちずに元寸をメモリへ載せ、その画素がグラフィックス側 (`Bitmap.Config.HARDWARE`) に置かれる | 成功 (Pixel 6a では `HARDWARE`) |
| `preparedRequestDecodesInsideFrameAfterMemoryPrefetch` | 先読みの後に表示を組み立てても落ちず、初回画像を返さない (`cachedImage` が null = 読み込み中を経由する)。続くローダー要求が枠 (200×200) に収まる画像を返す | 成功 |
| `displayAfterMemoryPrefetchDecodesOnceInLoader` | 読み出せない元寸が載っていても、表示に必要なローダーのデコードはちょうど 1 回で済み、得られる画像が枠に収まる | 成功 |
| `preparedImageSkipsUnreadableOriginal` | 先読み以外の経路で読み出せない元寸が載った場合も、落ちず初回の描画に使わない | 成功 |

画素がグラフィックス側に置かれることは端末とローダーの判断で決まり、実機でも常には成立しない
(ローダーは端末の資源が逼迫すると自らハードウェア支援を止める)。そのため構成の確認は契約の
アサーションではなく前提 (`Assume`) として書いてあり、成立しない実行機では該当の検証が skip
としてレポートに残る。上記の実行では 4 件とも skip されず、前提が成立した状態で通っている。

### A/B (分岐の無効化による再現)

現行実装で落ちない理由が②の分岐であることを、分岐を無効化した版との対比で確かめた。
`KsImageRequestFactory.downscale` の `if (!image.isPixelReadable()) return KsDownscaleResult.Unreadable`
を通らないようにしたビルドを同じ実行機に入れ、同じ 4 件を実行した。

| ビルド | 結果 |
|---|---|
| 現行 (分岐あり) | 4 件成功 / 0 失敗 |
| 分岐を無効化 | **4 件中 3 件が失敗**。3 件とも製品と同一の `java.lang.IllegalArgumentException: can't create mutable bitmap with Config.HARDWARE` (`KsImageRequestFactory.downscale` → `coil3.Image_androidKt.toBitmap` → `android.graphics.Bitmap.createBitmap`) |

失敗しなかった 1 件は `memoryPrefetchStoresGraphicsBackedImage` で、表示の組み立てを呼ばず
先読みの結果だけを見るため、この分岐に掛からない。A/B の後、無効化は元に戻して再実行し
4 件成功に戻ることを確認した。

### 基準機 (Pixel 4a) での目視

環境: Pixel 4a / Android 13 (SDK 33) / Sample の debug 構成 / Compose BOM 2026.06.01 /
compileSdk 36。上の実機テスト (Pixel 6a) とは別の機材で、**基準機**での確認である。
手順は本文冒頭の「手順」と同じ (到達点メモリの計測用の経路をキャッシュを空にして開く)。

| 観測点 | 結果 |
|---|---|
| 送り 20 回 + 戻り 20 回のフリックで落ちないこと | `FATAL EXCEPTION` **0 件**。crash バッファも 0 行。プロセスの識別子はフリックの前後で変わらず、生存したまま |
| 初回表示が読み込み中を一瞬経由すること | **経由する**。フリング中の静止画 `image-grid-memory-prefetch-loading-android.png` に、まだ絵の届いていないセルが読み込み中の既定表示 (無地) で写っている |
| 同上を数で裏付ける | 計数の仕組みで数えると、送り先の初出の要素 24 件が各 1 回ずつ読み込み中を組み立てている (`image-behavior-observation.md` の到達点メモリの節。暫定回避の適用中は 0 件だった) |

**静止画の読み方**: 一瞬の出来事なので「写らないこと」は非発現の根拠にならない。ここでは
**写ったこと**を経由の証拠として使い、経由しないことの主張には使っていない (経由の有無の判定は
上表 3 行目の計数で行う)。

### 未取得

- **なし。** 到達点メモリの性能値 (frameOverrun・メモリ定常化) の再計測も、基準機での目視も
  取り終えた。性能値は `image-grid-measurement-android.md` を参照
