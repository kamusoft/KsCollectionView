# Exploration: ios-launch-failure-uitests

## 課題 / 動機

iOS Sample の UI テスト `samples/ios/KsCollectionViewSamplesUITests/LargeDataCountUITests.swift` のうち、起動を止めることを確かめる 2 本 (`test件数に0を指定すると起動しない`・`test件数に数値でない値を指定すると起動しない`) が失敗し、実行ごとに成否が揺れる。`prefetch-display-size` の実装中 (2026-09-23〜24) に発見。変更前 (HEAD 3e4a918) のコードでも同じく失敗することを、別の作業ツリーで確かめたため、その change の起因ではない (2026-09-24、オーナー指示で起票)。

- 症状: `Expected failure '受け取れない件数では起動が止まる' but none recorded` (約 80 秒で失敗)
- アプリ側は正しく止まっている: `simctl launch` で直接起動すると `samples/ios/KsCollectionViewSamples/LargeDataCount.swift` の `fatalError` で意図どおり止まる。XCTest がアプリの異常終了を失敗として記録していない
- 環境: Xcode 26.5、iOS 26.5 Simulator (iPhone 17 / 17e / Air / 17 Pro Max で再現)。以前の verify (iOS 26 系の別機種) では通っていた。同じ日の別の実行では 2 本とも、または 1 本だけ通ったこともある
- `samples/ios/KsCollectionViewSamplesUITests/ImageGridCountUITests.swift` (`prefetch-display-size` で追加) は、同じ形の検出の揺れを避けるため、不正な値で起動が止まるかのテストを持っていない

## 検討した選択肢 (却下案と理由を含む)

## 決定事項

## ADR 候補

## 未決の論点

- 未探索 (簡易起票)
- 起動の失敗をどう検出するか (XCTest の期待失敗に頼らず、プロセスの終了状態・`XCUIApplication.state`・起動直後の画面要素の不在などで判定できるか)
- 揺れの条件 (Simulator の機種・OS 版・連続実行の順序・並列実行) の切り分け
- 同じ検査を `ImageGridCount` (`--image-count`) にも入れるか

## UI 素材

## 変更級の推奨

未判定 (テストのみの修正なら S の見込み)
