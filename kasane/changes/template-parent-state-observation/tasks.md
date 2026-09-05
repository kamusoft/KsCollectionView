# Tasks: template-parent-state-observation

## 1. 観測する値の modifier (collection-core)
- [ ] 1.1 `KsCollectionView` に観測する値を渡す modifier を追加する (仮称 `.observing(_:)`、`Hashable` を 1 つ受け取り `KsCollectionConfiguration` に型消去して保持)。名称は実装時に `swift-ui-impl-skill` の命名慣習で確定し、確定名を deviation.md に記録する (→ Requirement: 親の状態の観測)
- [ ] 1.2 `KsCollectionViewController.update(configuration:)` の同値配列経路で、観測する値が前回と異なるときだけ可視セルを再構成し、未指定時は従来どおり毎回再構成する。配列が変わった更新でも観測する値を記録する (→ Requirement: 親の状態の観測)
- [ ] 1.3 単体テスト: Scenario「観測する値の変化で可視セルが再構成される」「観測する値が同じなら可視セルを再構成しない」「観測する値を渡していなければ親の更新ごとに再構成する」「観測する値の変化は差分計算を伴わない」「配列の変化と観測する値の変化が同時に届く」「複数の状態をまとめて渡す」。SwiftUI 統合テストは既存の `test配列が同値でも親のState変更を可視セルへ反映する` と同じ枠組み (UIHostingController + 記録クロージャ) で、テンプレートの中でだけ状態を読む View を用いる (→ Requirement: 親の状態の観測)
- [ ] 1.4 公開 API テスト (`KsPublicAPITests`) に modifier の呼び出し形を追加する (→ Requirement: 親の状態の観測)

## 2. アニメーションの spike (契約外の探索。結果で採否を決める)
- [ ] 2.1 `updateUIViewController` の `context.transaction` を可視セル再構成に引き渡す (`withTransaction` で `reconfigureVisibleCells` を包む) 試作を行い、検証画面の親 state 経路でテンプレート内 state 経路と中身のアニメーションが揃うかを確認する。判定は静止画ではなくオーナー目視か offset / frame ログの A/B で行う (lessons inbox: capture-transient-layout-glitch-with-offset-logs)
- [ ] 2.2 成立した場合: 試作を本実装に取り込み、既存テスト全件の通過を確認する。不成立の場合: 試した構成と観測結果を deviation.md に記録して見送る (modifier の採用は結果に依存しない)

## 3. Sample (iOS 固有の検証画面)
- [ ] 3.1 `HeightChangeVerificationView` の親 state 経路で展開状態を観測する値として渡し、「展開中: N 行」の表示とそのコメントを撤去する。iOS 固有画面のため sample-parity の追随対象外 (→ Requirement: 行の高さ変化検証画面の親 state 経路)
- [ ] 3.2 Simulator で確認: 遷移直後の 1 タップ目から list / grid の両方で展開・折りたたみが効くこと、list と grid で追従に差が無いこと (差が残れば別起票の材料として記録)。手順は handbook/cross/runtime-behavior-verification.md の観測点表「検証: 行の高さ変化」に従う (→ Scenario: 遷移直後の最初のタップで展開される)
- [ ] 3.3 「展開中」表示の accessibilityIdentifier (`heightChange.expandedCount`) を参照する箇所が残っていないことを確認する (提案時点で UI テストに参照なし) (→ Scenario: 回避策の表示を持たない)

## 4. ドキュメント (実装完了後、蒸留前の追随)
- [ ] 4.1 `kasane/concepts/core/core-model/collection-items.md` の「保証すること」「してはいけないこと」を更新する: 親の状態を観測する値として渡す契約、Android では不要、状態を項目に持たせる書き方と参照型モデルをセルの中で観測する書き方は参考として併記 (推奨ではない)
- [ ] 4.2 `kasane/concepts/ios/architecture/collection-engine.md` の責務境界 (`KsCollectionViewController` の同値配列時の再構成条件) を更新する
- [ ] 4.3 ソースの doc コメント (modifier と `KsCollectionView` 型) に利用者契約と Android 不要の旨を書く (handbook/cross/comment-policy.md に従う)

## 5. 完了確認
- [ ] 5.1 `ios/` の全テストを実行し実行件数まで確認する (handbook/cross/test-execution.md)。レビューと verify で Simulator を分けるか直列にする (lessons inbox: do-not-run-review-and-verify-on-same-simulator)
- [ ] 5.2 Sample アプリ (iOS) のビルドと検証画面の起動確認
