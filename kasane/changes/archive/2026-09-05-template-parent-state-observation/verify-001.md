# Verify 001: template-parent-state-observation

- 検証日: 2026-09-05
- 検証対象: 作業ツリーの未コミット変更 (`git diff HEAD` + 未追跡ファイル)
- デルタスペック: `specs/collection-core/spec.md` (Requirement「親の状態の観測」/ Scenario 6 件)、`specs/samples/spec.md` (Requirement「行の高さ変化検証画面の親 state 経路」/ Scenario 2 件)
- 合意済み差分: `deviation.md`

## 判定

**VALID**

全 8 Scenario が「✅ 一致」または「⚠️ deviation 記録済み」。虚偽チェックなし、逆流なし、テストは iOS 本体 91 件 / Sample 3 件がいずれも 0 failures。

---

## 対応表

### specs/collection-core — Requirement: 親の状態の観測

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 観測する値の変化で可視セルが再構成される | `ios/Sources/KsCollectionView/KsCollectionViewController.swift:97`-`99`, `:132`, `:371` / `ios/Sources/KsCollectionView/KsCollectionView.swift:136` | `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:905`、`ios/Tests/KsCollectionViewTests/KsSwiftUIIntegrationTests.swift:220` | ✅ 一致 |
| 観測する値が同じなら可視セルを再構成しない | `ios/Sources/KsCollectionView/KsCollectionViewController.swift:99`, `:344`-`:357`, `:371` | `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:928` | ⚠️ deviation 記録済み |
| 観測する値を渡していなければ親の更新ごとに再構成する | `ios/Sources/KsCollectionView/KsCollectionViewController.swift:99` (`configuration.observedValue == nil` の枝) | `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:1044`、既存 `ios/Tests/KsCollectionViewTests/KsSwiftUIIntegrationTests.swift:280` | ✅ 一致 |
| 観測する値の変化は差分計算を伴わない | `ios/Sources/KsCollectionView/KsCollectionViewController.swift:369`-`:378` (`items == appliedItems` の早期経路。差分計算と snapshot 適用の手前で戻る) | `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:953` | ✅ 一致 |
| 配列の変化と観測する値の変化が同時に届く | 値の記録: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:110` (配列の変化に関係なく configuration 全体を差し替え) / 差分更新経路: `:133`, `:409`-`:428`, `:446`-`:455` | `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:987` (記録)、`:1017` (生存可視セルの再構成)、`ios/Tests/KsCollectionViewTests/KsSwiftUIIntegrationTests.swift:240` | ✅ 一致 |
| 複数の状態をまとめて渡す | `ios/Sources/KsCollectionView/KsCollectionView.swift:136` (`observedValue<Value: Hashable>(_:)`) / `ios/Sources/KsCollectionView/KsCollectionConfiguration.swift:21` (`AnyHashable?` として保持) | `ios/Tests/KsCollectionViewTests/KsSwiftUIIntegrationTests.swift:259`、`ios/Tests/KsCollectionViewTests/KsPublicAPITests.swift:23`, `:55` | ✅ 一致 |

補足:

- Requirement 本文「観測する値は `Hashable` であればよく」: シグネチャ `public func observedValue<Value: Hashable>(_ value: Value) -> KsCollectionView<Item>` (`ios/Sources/KsCollectionView/KsCollectionView.swift:136`) で満たす。仮称 `.observing(_:)` からの改名は `deviation.md`「modifier の名称 (tasks 1.1)」に記録済み
- Requirement 本文「この契約は iOS のみに存在する。Android では…対応する API を設けない」: `android/` `samples/android/` に `observedValue` 相当の API は無く (grep 済み)、本 diff に Android の変更も無い。`ios/Sources/KsCollectionView/KsCollectionView.swift:134` の doc コメントにも Compose 版で不要である旨がある
- Scenario「配列の変化と観測する値の変化が同時に届く」に対し、実装は spec の要求 (値の記録) に加えて、観測する値が変わった配列変更の更新で**生き残った可視セルもテンプレートを呼び直す**。これは Scenario の THEN を狭めるものではなく、`deviation.md`「蒸留への申し送り」(ios/ADR-0006 の Consequences に 1 行残す) に「spec の合意範囲内」として記録済み

### specs/samples — Requirement: 行の高さ変化検証画面の親 state 経路

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 遷移直後の最初のタップで展開される | `samples/ios/KsCollectionViewSamples/HeightChangeVerificationView.swift:76` (`.observedValue(expandedIDs)`) | 自動テストなし。証跡 `evidence/height-change-tap-verification.md` の手順 2 (list) / 5 (grid) / 7 (画面遷移を挟む経路) と対応する静止画 | ✅ 一致 (証跡による) |
| 回避策の表示を持たない | `samples/ios/KsCollectionViewSamples/HeightChangeVerificationView.swift` から「展開中: N 行」の `Text` と `accessibilityIdentifier("heightChange.expandedCount")`、および依存を張るためのコメントを撤去 | 参照する UI テストは元から存在しない。リポジトリ全体の grep で iOS 側に `heightChange.expandedCount` の残存なし (残存は `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/HeightChangeVerificationScreen.kt:91` のみ = 対象外の Android 側) | ✅ 一致 |

Requirement 本文「body で状態を読むことで依存を張る回避策 (展開中の行数の表示) は持たない」は上記の撤去で満たす。

---

## 追加検査

### tasks.md

| 節 | 状態 | 確認 |
|---|---|---|
| 1.1〜1.4 | 全 `[x]` | 対応表のとおり実装・テストとも存在。虚偽なし |
| 2.1 / 2.2 | 全 `[x]` | spike のコードは `ios/` `samples/` に残骸なし (`withTransaction` / `CADisplayLink` は本 diff に該当なし)。試した構成 A/B/C と観測結果は `deviation.md`「アニメーションの spike」と `evidence/transaction-spike.md` に記録済みで、「不成立の場合は記録して見送る」に沿う |
| 3.1〜3.3 | 全 `[x]` | 対応表のとおり |
| 4.1 / 4.2 | `[ ]` 未完了 | 意図的な繰り越し。`deviation.md`「蒸留への申し送り」で ksn-distill Step 4 へ送ると記録済み。実装フェーズの虚偽ではない |
| 4.3 | `[x]` | `ios/Sources/KsCollectionView/KsCollectionView.swift:3`-`:7` (型 doc) と `:115`-`:135` (modifier doc) に利用者契約と Compose 版で不要の旨がある |
| 5.1 / 5.2 | `[x]` | 下記「テスト実行」のとおり再実行で確認 |

### 逆流検査

足場アーティファクト (`proposal.md` / `specs/`) は提案コミット `606b6c4` 以降に変更されておらず、作業ツリーにも未コミット差分なし。`tasks.md` の差分はチェックボックスの更新のみ。**逆流なし**。

### 未記録乖離

なし。対応表に ❌ はなく、`deviation.md` に記録のない差分は検出されなかった。`deviation.md` に `[付随修正]` 行は無く、diff にも Scenario / tasks に対応しない変更は含まれていない。

### テスト実行 (handbook/cross/test-execution.md)

Simulator は iPhone 17 Pro / iOS 26.5 (`<uuid>`、Booted) を id 指定で使用。他ワーカーとの同時実行なし。

| 対象 | コマンド | 結果 |
|---|---|---|
| 本体 | `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,id=<uuid>' -configuration Debug` (`ios/`) | **Executed 91 tests, with 0 failures** / `** TEST SUCCEEDED **`。11 スイート (KsCollectionEngineTests / KsCollectionScenarioTests / KsEstimatedHeightTests / KsLayoutMetricsTests / KsPrefetcherTests / KsPublicAPITests / KsRowContentPlacementTests / KsScrollControllerTests / KsSnapshotPlannerTests / KsSwiftUIIntegrationTests / KsTemplateRegistryTests) がすべて passed |
| Sample | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination '…同上…' -configuration Debug` (`samples/ios/`) | **Executed 3 tests, with 0 failures** / `** TEST SUCCEEDED **`。スイートは `InteractiveControlUITests` のみで、計測ドライバ (`KsCollectionViewSamplesPerformance`) は件数に含まれていない = スキーム分離が効いている |

本 change で追加された 10 件の実行を個別に確認済み: engine 6 件 (`test観測する値の変化で同値配列でも可視セルを再構成する` / `test観測する値が同じなら可視セルを再構成しない` / `test観測する値の変化ではID解決もsnapshot適用も行わない` / `test配列と観測する値が同時に変わった更新でも観測する値を記録する` / `test配列と観測する値が同時に変わった更新で既存の可視セルも再構成する` / `test観測する値を渡していなければ更新ごとに可視セルを再構成する`)、SwiftUI 統合 3 件、公開 API 1 件がいずれも passed。

### UI 変更の扱い

本 change に `ui/` は無い。Sample の変更は既存検証画面からの表示撤去であり、モック承認ゲートの対象外 (提案時点で `ui/` を持たない M 級変更)。実操作の証跡は `evidence/height-change-tap-verification.md` に静止画付きで残っている。

---

## 追加確認: レビュー後の直接修正 (review-002 Minor 1)

「modifier 未指定時の doc コメントの射程」の修正として直された 3 箇所を、spec の記述「観測する値を渡していない場合の挙動は変えない: 配列が同値でも親 View の更新が届くたびに可視セルを再構成する」と突き合わせた。

| 箇所 | 現在の記述 | 判定 |
|---|---|---|
| `ios/Sources/KsCollectionView/KsCollectionView.swift:133`-`:134` (`observedValue(_:)` doc 末尾) | 「渡さない場合は、**配列が同じまま**表示するビューが再評価されるたびに、表示中のセルの内容を作り直します (配列が変わる更新では、内容の変わった項目だけが作り直されます)」 | ✅ 整合。同値配列の更新に射程が限定され、配列が変わる更新は既存の差分更新の挙動として括弧内に分離されている |
| `ios/Sources/KsCollectionView/KsCollectionConfiguration.swift:19`-`:20` | 「宣言が無い (nil) ときは**配列が同値の更新**が届くたびに可視セルを作り直す (ios/ADR-0006)」 | ✅ 整合 |
| `ios/Sources/KsCollectionView/KsCollectionViewController.swift:95`-`:96` | 「宣言が無いときは**配列が同値の更新**が届くたびに呼び直す (ios/ADR-0006)」 | ✅ 整合 |

3 箇所とも spec の文言どおりに「配列が同値の更新」へ限定されており、過剰一般化 (配列が変わる更新でも毎回作り直すかのような読み) は残っていない。

`python3 scripts/comment-policy-lint.py` は `合計: 0 ファイル / 禁止 0 件 (検査対象 141 ファイル)` で **exit 0** (違反なし)。

---

## 対象外

- tasks 4.1 / 4.2 (`kasane/concepts/` の追随) — ksn-distill の担当。本検証では未完了を虚偽としない
- iOS 性能検証の計測 (`kasane/handbook/ios/performance-verification.md` の 2 系統) — `deviation.md`「iOS 性能検証の扱い」でオーナー判断に委ねると合意済み
- Android 側の `heightChange.expandedCount` 残存 — `review-001.md` / `review-002.md` で sample-parity の例外枠と判断済み。本 change のデルタスペックの射程外
