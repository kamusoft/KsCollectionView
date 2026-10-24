# Deviation: android-disappearing-items-drawn-outside-bounds

- 蒸留時に反映: handbook cross/test-execution.md の「Android: 差分なし再実行と Robolectric の描画限界」 — `@GraphicsMode(NATIVE)` でも、View をソフトウェアの Canvas に描いて画素を読む方法 (`readPixels`) は、層 (`drawLayer`) で描かれるもの (配列の差し替えで消えていく項目など) を描かず、修正前でもアサーションが通ってしまう。そうした層を画素で確かめるテストは、`PixelCopy` とハードウェア描画 (`robolectric.pixelCopyRenderMode=hardware`) で画面を読む (出典: 本 change の `KsDisappearingItemsClipTest`)。足すかどうかは蒸留時にオーナーと決める
- 決定事項のテスト: 探索では Robolectric + `captureToImage` で画素を読む → 実際は `PixelCopy` とハードウェア描画 (`robolectric.pixelCopyRenderMode=hardware`) で読んでいる。理由: 消えていく項目は `drawLayer` で直接描かれ、ソフトウェアの Canvas の読み方では描かれず、修正前でも通ってしまうため (2026-10-24 蒸留時に補完)
