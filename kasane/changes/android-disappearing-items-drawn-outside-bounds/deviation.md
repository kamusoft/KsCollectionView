# Deviation: android-disappearing-items-drawn-outside-bounds

- 蒸留時に反映: handbook cross/test-execution.md の「Android: 差分なし再実行と Robolectric の描画限界」 — `@GraphicsMode(NATIVE)` でも、View をソフトウェアの Canvas に描いて画素を読む方法 (`readPixels`) は、層 (`drawLayer`) で描かれるもの (配列の差し替えで消えていく項目など) を描かず、修正前でもアサーションが通ってしまう。そうした層を画素で確かめるテストは、`PixelCopy` とハードウェア描画 (`robolectric.pixelCopyRenderMode=hardware`) で画面を読む (出典: 本 change の `KsDisappearingItemsClipTest`)。足すかどうかは蒸留時にオーナーと決める
