# レビュー結果: ios-launch-failure-uitests (001 回目)

**日付**: 2026-09-26
**判定**: APPROVED

## サマリー

`samples/ios/KsCollectionViewSamplesUITests/LargeDataCountUITests.swift` の変更は、`XCTExpectFailure` を非厳格 (`options.isStrict = false`) にして判定を起動後の `app.state` に置くもので、exploration.md の決定事項 (論点 1 の A) と「実装への申し送り」の 4 点をすべて満たしている。証跡 `evidence/launch-failure-ab.md` の A/B 3 通りと全件実行を別の Simulator (iPhone 17 Pro / iOS 26.5) で再実行し、すべて同じ結果になった。Critical / Major はなく、Suggestion が 1 件だけある。

## 照合した規約

- ソースコメント規約 (always)。`scripts/comment-policy-lint.py` は禁止 0 件 (検査対象 320 ファイル)。書き換えた doc コメントに作業文書・ローカル通番・履歴を書いた記述はなく、ファイルだけを読んで意味が通る
- テスト実行規約 (テストを実行するとき・テスト結果を報告するとき)。通常スキームの全件実行で件数を併記していること、計測ドライバが通常スキームに含まれていないことを照合した
- 実行時挙動の検証規約 (不具合修正の完了を判定するとき)。当時の症状は現在は再現しないため、アプリ側を一時的に差し替えて「記録が届かない」状態を作り、修正前後の A/B を取っている。証跡は change 配下にある。規約 1 の「実環境で症状を再現する」は、差し替えで症状を作ったものとして満たすと判断した。修正前のテストで当時と同じ文言・同じ所要時間 (約 80 秒) の失敗が出ており、再現できていると言える
- Sample のプラットフォーム間一致: 当たらない (デモ画面や文言を変えていない。UI テストだけの変更)

## 確認した観点

- **合意スコープとの一致**: 変更はテスト 1 ファイルだけで、`main` との差分はほかに change 配下の exploration.md (探索の成果) と evidence/ だけ。`samples/ios/KsCollectionViewSamples/` に差分はなく、アプリ側の止め方 (`fatalError`) は変わっていない。論点 3 (`--image-count`) を見送った決定どおり、`ImageGridCountUITests.swift` にも触れていない
- **一致条件を残していること**: `issueMatcher` はそのまま残っている。記録が届いた場合は期待した失敗として吸収され (全件実行の結果ファイルで `expectedFailures: 2`)、条件に当たらない記録は非厳格でも失敗として残る
- **起動できてしまった場合の失敗が吸収されないこと**: `XCTAssertNotEqual` の失敗の文言 (`XCUIApplicationState(rawValue: 4)` と日本語のメッセージ) には `failIfInvalid` / `crashed` / `Failed to launch` / `terminated` のどれも入らない。下の C で実際に失敗し、`expectedFailures: 0` だった
- **doc コメント**: 判定の置き場所、記録が届くかどうかが環境で揺れること、届かない環境では 1 本 80 秒ほどかかることが、現在形で自己完結に書かれている。実測 (A で約 82〜84 秒) と合っている
- **堅牢性**: 非厳格にしたことで失われる検出は「起動したのに状態の検査が通ってしまう」場合だけだが、そのときは起動していないので問題にならない。一致条件の語が広く、別の原因のクラッシュも吸収しうる点は変更前からあり、今回の範囲外
- **swift-ui-impl-skill の観点**: `@MainActor` の付け方、強制アンラップの有無、命名は既存のテストと揃っている。指摘はない

### 証跡の再実行 (lessons L-001)

iPhone 17 Pro (iOS 26.5) で、DerivedData は作業ツリーの外に置いて実行した。アプリ側 (`LargeDataCount.failIfInvalid()`) と修正前のテストへの一時的な書き換えは、実行ごとに退避しておいた原本で戻し、`shasum` の一致と `git diff` で `samples/ios/KsCollectionViewSamples/` に差分がないことを確かめた。

| # | アプリ側 (一時的) | テスト | 結果 (本レビュー) | 証跡の値 |
|---|---|---|---|---|
| A | `print(reason); exit(1)` (クラッシュレポートが出ない終了) | 修正後 | 2 tests / 0 failures (83.8 秒・81.3 秒)。`expectedFailures: 0` | 2 tests / 0 failures (各約 81 秒) |
| B | 同上 | 修正前 (`isStrict = false` の行を外す) | 2 tests / 2 failures (82.1 秒・81.8 秒)。`Expected failure '受け取れない件数では起動が止まる' but none recorded` | 2 tests / 2 failures (各約 82 秒)、同じ文言 |
| C | `print(reason)` のみ (止めずに既定の件数で開く退行) | 修正後 | 2 tests / 2 failures (3.4 秒・3.7 秒)。`XCTAssertNotEqual failed ... 受け取れない件数なのに起動しています`。`expectedFailures: 0` | 2 tests / 2 failures (各約 3 秒)、expectedFailures 0 |

戻した後の通常スキームの全件実行 (`xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples`): **18 tests / 0 failures**。内訳は GroupingDemo 6 / ImageGridCount 1 / ImageLoadingSlotShownClipping 2 / ImageLoadingSlot 2 / InteractiveControl 3 / LargeDataCount 4 で、計測ドライバは含まれない。結果ファイルの集計は `passedTests: 16` / `expectedFailures: 2` / `failedTests: 0` で、対象の 2 本はクラッシュの記録が届いて吸収され、14.6 秒と 1.3 秒で終わった。

## 指摘事項

### 🔵 Suggestion 全件実行の件数の内訳に「期待した失敗 2」を書き添える

**該当箇所**: `evidence/launch-failure-ab.md:17`
**問題点**: 「18 tests / 0 failures」の内訳で、対象の 2 本は結果ファイルでは passed ではなく expected failure (`expectedFailures: 2`) として数えられる。記録が届かない環境では同じ 2 本が passed に数えられる (A で `expectedFailures: 0`)。この違いが書かれていないため、後から結果ファイルと照らし合わせた人が、passed が 16 しかないことに戸惑うおそれがある。判定には影響しない。
**推奨修正**: 「対象 2 本はクラッシュの記録が届き」の後に、「結果ファイルの集計では passed 16 / expected failures 2」を書き添える。

## アクションプラン

1. (任意) 上の Suggestion を証跡に反映する。対応しなくても完了判定に影響しない
