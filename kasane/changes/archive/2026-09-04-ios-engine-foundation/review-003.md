# コード再レビュー: ios-engine-foundation

## メタデータ

- 日付: 2026-09-02
- 対象: 修正サイクル 2 後
- 判定: **CHANGES_REQUESTED**

## サマリー

`review-002.md` #2 のスクロール順序保証は、`UIHostingController`、`@State`、実 SwiftUI Button action、`UIViewControllerRepresentable` 更新を通る統合テストで新 snapshot の末尾 ID まで確認でき、解消した。#3 は実 SwiftUI Button の action 自体は確認するよう改善されたが、accessibility action はタッチ hit test と collection selection / highlight の競合を通らないため、元の Scenario の検証にはなっていない。必須性能 Requirement も未完了のため、現状では承認できない。

重要度別件数: **Critical 0 / Major 2 / Minor 0 / Suggestion 0**

## 前回指摘の追跡

| 出典 | 状態 | 確認結果 |
|---|---|---|
| `review-002.md` #1 性能受け入れ | 未解消 | tasks 8.1〜8.3 と実測値が未完了 |
| `review-002.md` #2 SwiftUI 更新直後のスクロール順序 | **解消** | `KsSwiftUIIntegrationTests` が実 SwiftUI 状態更新と同一 action の末尾命令を通し、新 snapshot の末尾 ID への到達を検証 |
| `review-002.md` #3 hosted SwiftUI Button 競合 | **未解消** | 実 Button の取得と action は確認するが、accessibility action のため touch / selection / highlight 競合を通らない |

降格済み指摘は再評価対象としていない。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`
- `kasane/handbook/cross/test-execution.md`
- `kasane/handbook/cross/runtime-behavior-verification.md`
- `swift-ui-impl-skill`

## Findings

### 🔴 Major

#### 1. 必須の性能受け入れ条件が未検証

- **場所**: `kasane/changes/ios-engine-foundation/tasks.md:49`
- **問題**: collection-core の必須要件である iPhone 11 実機・可変行高混在 10,000 件・3 試行すべて 5 ms/s 未満・メモリ定常化が未検証である。tasks 8.1〜8.3 は未チェックで、`kasane/changes/ios-engine-foundation/evidence/performance-early-measurement.md:5` と結果表も未実施・未計測のままである。
- **推奨修正**: 規定の iPhone 11 実機と Release 構成で 3 試行およびメモリ計測を行い、サニタイズ済み結果と判定を `evidence/` に保存して tasks 8.1〜8.3 を完了する。

#### 2. 子 SwiftUI Button の action テストが item tap / feedback との実タッチ競合を通していない

- **場所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:266`
- **問題**: テストは `UIHostingConfiguration` 内の実 SwiftUI Button を accessibility tree から取得しているが、`accessibilityActivate()` は Button action を直接起動する経路であり、`KsHostingCell.hitTest(_:with:)`、`lastHitWasInteractive`、collection view の `shouldHighlightItemAt` / `didSelectItemAt` を通らない。その状態で item tap が空、feedback が非表示なのは、collection selection / highlight を一度も発火していないためでも成立する。したがって「セル内 Button がタッチを処理した場合、Button action だけが発火し、item tap と feedback は発火しない」という SHALL NOT の競合動作は未検証であり、`kasane/changes/ios-engine-foundation/evidence/verification-matrix.md:19` の記述は実際の検証範囲を過大に表している。
- **推奨修正**: Button 入りセルを実アプリまたは UI test host に置き、実座標への tap で SwiftUI Button action、item tap、feedback の3観測点を同時に確認する。Button action が1回だけ発火し、item tapが0回、feedbackが出ないことを Simulator / XCUITest または同等の実タッチ経路で検証し、verification matrix と証拠を更新する。

### 🟡 Minor

なし。

### 🔵 Suggestion

なし。

## 解消を確認したスクロール順序保証

`ios/Tests/KsCollectionViewTests/KsSwiftUIIntegrationTests.swift:44` は、`UIHostingController` 上の `AppendAndScrollView` で次を実行している。

1. 実 SwiftUI Button action 内で `@State` 配列へ item を追加する。
2. 同じ action 内で `scrollToEnd(animated: false)` を発行する。
3. SwiftUI 配下の実 `KsCollectionViewController` について、適用済み snapshot と最後のスクロール対象がともに追加 ID 30 になるまで条件ベースで待つ。

これは `review-002.md` が求めた利用者向け SwiftUI 更新経路と観測点を満たしており、`verification-matrix.md:20` の記載とも一致する。

## 実行したコマンドと結果

個体識別子を成果物へ残さないため、Simulator は名前と OS で表記する。

| コマンド | 結果 |
|---|---|
| `python3 scripts/comment-policy-lint.py` | 成功。対象 55 ファイル、違反 0 件 |
| `python3 scripts/local-path-lint.py` | 成功 |
| `python3 scripts/identity-lint.py` | 成功 |
| `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' -configuration Debug` | 成功。33 tests、0 failures、`TEST SUCCEEDED` |
| `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' -configuration Release ENABLE_TESTABILITY=YES` | 成功。34 tests、0 failures、`TEST SUCCEEDED` |
| `xcodebuild build -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' -configuration Debug CODE_SIGNING_ALLOWED=NO` (`samples/ios/`) | 成功、exit 0 |
| `xcodebuild build -scheme KsCollectionView -destination 'generic/platform=iOS Simulator' -configuration Debug IPHONEOS_DEPLOYMENT_TARGET=16.0 CODE_SIGNING_ALLOWED=NO` (`ios/`) | 成功、exit 0 |

## 推奨アクションプラン

1. hosted SwiftUI Button を実タッチする競合テストと証拠を追加し、verification matrix を実態へ合わせる。
2. iPhone 11 実機で性能・メモリ受け入れ判定を完了する。
3. Debug / Release、Sample、iOS 16 build、lint を再実行して再レビューを依頼する。
