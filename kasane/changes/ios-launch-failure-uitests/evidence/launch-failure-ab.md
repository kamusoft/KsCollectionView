# 起動の失敗の確かめ方の A/B (2026-09-26)

環境: Xcode 26.5、iPhone 17e / iOS 26.5 Simulator。対象は `samples/ios/KsCollectionViewSamplesUITests/LargeDataCountUITests.swift` の `test件数に0を指定すると起動しない`・`test件数に数値でない値を指定すると起動しない`。

「クラッシュの記録が届かない環境」は再現しないため、アプリ側の止め方 (`LargeDataCount.failIfInvalid()` の `fatalError`) を一時的に書き換えて作った。書き換えは各実行の後に戻し、`git diff` で `samples/ios/KsCollectionViewSamples/` に差分が無いことを確かめた。

| # | アプリ側 (一時的) | テスト | 結果 | 失敗の文言 |
|---|---|---|---|---|
| 1 | 理由を出力して `exit(1)` (クラッシュレポートが出ない終了) | 修正前 | 2 tests / 2 failures (各約 82 秒) | `Expected failure '受け取れない件数では起動が止まる' but none recorded` (当時の症状と同じ文言・所要時間) |
| 2 | 同上 | 修正後 | 2 tests / 0 failures (各約 81 秒) | — |
| 3 | 受け取れない件数でも止めずに戻る (既定の 10,000 件で開く退行) | 修正後 | 2 tests / 2 failures (各約 3 秒)。結果ファイルの集計で expectedFailures 0 | `XCTAssertNotEqual failed ... 受け取れない件数なのに起動しています` |

1 の結果ファイルの操作記録では、約 80 秒の内訳は「自動操作の準備 (Setting up automation session) の 60 秒の待ち切り」と「後片付けでのクラッシュレポートの探索 20 秒」で、状態の検査 (`app.state` が前面で動いていない) は通っていた。

## 完了判定の実行 (書き換えを戻した後、修正後のテスト)

- `samples/ios/` で `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples` (iPhone 17e / iOS 26.5): **18 tests / 0 failures**。内訳は GroupingDemo 6 / ImageGridCount 1 / ImageLoadingSlotShownClipping 2 / ImageLoadingSlot 2 / InteractiveControl 3 / LargeDataCount 4 (計測ドライバは含まれない)。対象 2 本はクラッシュの記録が届き、各約 8 秒・1 秒で成功。結果ファイルの集計では、この 2 本は passed ではなく expected failure として数えられる (passed 16 / expectedFailures 2)。記録が届かない環境では同じ 2 本が passed として数えられる (上の 2 で expectedFailures 0)
- ライブラリ本体 (`ios/`) は変更していないため実行していない
