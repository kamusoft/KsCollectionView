# コード再レビュー: ios-engine-foundation

## メタデータ

- 日付: 2026-09-02
- 対象: 修正サイクル 1 後
- 判定: **CHANGES_REQUESTED**

## サマリー

前回確定した指摘のうち、iOS 16 下限、区切り線、header / footer、touch feedback、ロングタップ、テスト観測点、実レイアウト検証、handbook、性能ハーネス、区切り線色は修正されている。Debug 32 件、Release 33 件、Sample Debug build、iOS 16 build、標準 lint もすべて成功した。一方、必須性能 Requirement は意図どおり未完了であり、スクロール順序保証と hosted SwiftUI Button の競合は実際の SwiftUI 経路を通した検証になっていないため、現時点では承認できない。

重要度別件数: **Critical 0 / Major 3 / Minor 0 / Suggestion 0**

## 前回指摘の追跡

| 出典 | 状態 | 確認結果 |
|---|---|---|
| `review-001.md` #1 性能受け入れ | 未解消 | tasks 8.1〜8.3 と実測値が未完了 |
| `review-001.md` #2 iOS 16 下限 | 解消 | Package と Sample は 16、iOS 16 build 成功 |
| `review-001.md` #3 長押し後の次タップ | 解消 | ID 持越しを撤去し、別タッチの回帰テスト成功 |
| second-opinion #3 区切り線の位置追随 | 解消 | snapshot 後の再構成と挿入・削除・並べ替えテスト成功 |
| second-opinion #4 header / footer 更新 | 解消 | 表示中 supplementary の再構成と動的内容テスト成功 |
| second-opinion #6 touch feedback の重なり | 解消 | content より前面の overlay と描画比較テスト成功 |
| second-opinion #7 スクロール順序保証 | **未解消** | controller 直呼びテストは追加されたが SwiftUI 更新経路を通らない |
| second-opinion #8 子 control 競合 | **未解消** | 実際の hosted SwiftUI Button ではなく、未接続の合成 UIButton で判定している |
| second-opinion #9 検証根拠の過大計上 | 解消 | Public API / release fallback の観測点とアサーションを追加 |
| second-opinion #10 実レイアウト未検証 | 解消 | adaptive の padding・spacing・最小幅を実レイアウト属性で検証 |
| second-opinion #11 tasks の過大チェック | 一部解消 | prefetch 変換は解消。6.3 の順序保証は上記 #7 と同じ理由で未完了 |
| second-opinion #12 handbook 未追随 | 解消 | iOS build / test / Sample と実行時観測点を現行手順へ更新 |
| second-opinion #15 性能ハーネス未コンパイル | 解消 | SwiftPM target 化し、自己完結した README へ更新 |
| second-opinion #16 separator token 未使用 | 解消 | 固定 RGBA と deviation、描画色テストを追加 |

降格済みの second-opinion 指摘は再評価対象から外し、Major へ再昇格していない。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`
- `kasane/handbook/cross/sample-parity.md`
- `kasane/handbook/cross/test-execution.md`
- `kasane/handbook/cross/runtime-behavior-verification.md`
- `kasane/handbook/cross/public-identifiers.md`
- `kasane/handbook/cross/local-development-setup.md`
- `swift-ui-impl-skill`

## Findings

### 🔴 Major

#### 1. 必須の性能受け入れ条件が未検証

- **場所**: `kasane/changes/ios-engine-foundation/tasks.md:49`
- **問題**: collection-core の必須要件である iPhone 11 実機・可変行高混在 10,000 件・3 試行すべて 5 ms/s 未満・メモリ定常化が未検証である。tasks 8.1〜8.3 は未チェックで、`kasane/changes/ios-engine-foundation/evidence/performance-early-measurement.md:5` と結果表も未実施・未計測のままである。意図的な未完了であっても Requirement 未充足であることは変わらない。
- **推奨修正**: 規定の iPhone 11 実機と Release 構成で 3 試行およびメモリ計測を行い、サニタイズ済み結果と判定を `evidence/` に保存して tasks 8.1〜8.3 を完了する。

#### 2. データ更新直後のスクロール順序保証を実際の SwiftUI 更新経路で検証していない

- **場所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:319`
- **問題**: 追加されたテストは `scrollToEnd()` の直後に `controller.update(configuration:)` を同期的に直接呼ぶため、`DispatchQueue.main.async` の flush より先に snapshot apply が始まる状況をテスト自身が保証している。利用者の実経路は `@State` / Observation の配列更新から `UIViewControllerRepresentable.updateUIViewController` が呼ばれる経路であり、SwiftUI の更新コミットと `DispatchQueue.main.async` の実行順をこのテストは通していない。Sample にも「データ追加と同一処理で末尾へ移動」の操作がない。したがって spec の「追加された新要素まで確実にスクロールする」という順序保証に対し、元の scheduling 仮定が成立する証拠がまだない。
- **推奨修正**: `UIHostingController` 上の SwiftUI View と `@State` / Observation を使い、利用者向けコードと同じ「append → scrollToEnd」を発火して新しい末尾 ID への到達を確認する Simulator 統合テストを追加する。必要なら Sample に同じ操作を追加し、実行時挙動の検証規約に従って結果を保存する。テストで失敗する場合は、SwiftUI 更新の到達を scheduling heuristic に依存せず command と snapshot 世代で結び付ける。

#### 3. 子 SwiftUI Button 競合のテストが実際の hosted Button を検証していない

- **場所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:266`
- **問題**: テンプレートには SwiftUI `Button` を置いているが、その実際の view hierarchy を hit test していない。代わりにセルへ接続されていない `UIButton` を生成し、`cell.updateInteractionTarget(controlSurface)` を直接呼んでいる。このため確認できるのは「UIControl を渡せば internal helper が true にする」ことだけで、元の懸念だった `UIHostingConfiguration` 内の SwiftUI Button が `.button` trait または UIControl として検出され、実タッチ時に item tap と feedback を抑止することは未検証である。Sample にセル内 Button がなく、`verification-matrix.md:19` の実機手動欄を実行できる画面・証拠もない。
- **推奨修正**: 実際にホストされた SwiftUI Button の hit 対象を使う Simulator 統合テスト、または Button 入りセルの Sample / UI test を追加し、Button action のみが 1 回発火し item tap と feedback が発火しないことを確認する。合成 UIButton による helper 単体テストは補助として残してよい。

### 🟡 Minor

なし。

### 🔵 Suggestion

なし。

## 実行したコマンドと結果

個体識別子を成果物へ残さないため、Simulator は名前と OS で表記する。

| コマンド | 結果 |
|---|---|
| `python3 scripts/comment-policy-lint.py` | 成功。対象 54 ファイル、違反 0 件 |
| `python3 scripts/local-path-lint.py` | 成功 |
| `python3 scripts/identity-lint.py` | 成功 |
| `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' -configuration Debug` | 成功。32 tests、0 failures、`TEST SUCCEEDED` |
| `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' -configuration Release ENABLE_TESTABILITY=YES` | 成功。33 tests、0 failures、`TEST SUCCEEDED` |
| `xcodebuild build -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' -configuration Debug CODE_SIGNING_ALLOWED=NO` (`samples/ios/`) | 成功、exit 0 |
| `xcodebuild build -scheme KsCollectionView -destination 'generic/platform=iOS Simulator' -configuration Debug IPHONEOS_DEPLOYMENT_TARGET=16.0 CODE_SIGNING_ALLOWED=NO` (`ios/`) | 成功、exit 0 |

最初に指定した Simulator OS `26.0` は、Xcode が列挙する実 runtime `26.0.1` と一致せず destination 解決で exit 70 となった。上表のとおり実在する `26.0.1` を指定して全件を再実行し、製品コード・テストの失敗ではないことを確認した。

## 推奨アクションプラン

1. hosted SwiftUI Button の実タッチ経路を通す競合テストと証拠を追加する。
2. SwiftUI 状態更新と同一処理の scroll command を実経路で検証し、必要なら順序保証を再設計する。
3. iPhone 11 実機で性能・メモリ受け入れ判定を完了する。
4. Debug / Release、Sample、iOS 16 build、lint を再実行して再レビューを依頼する。
