# Tasks: ios-engine-foundation

## 1. パッケージ scaffold
- [ ] 1.1 `ios/Package.swift` — package / product `KsCollectionView` 単一構成 (design Decision 1、handbook: public-identifiers)
- [ ] 1.2 テストターゲットと最小のビルド確認

## 2. エンジン中核 (翻案移植 — ios/ADR-0001)
- [ ] 2.1 diffable data source 構成: `AnyHashable` 安定 ID 識別子 + 単一 section (design Decision 2) (→ Requirement: プレーンな配列と安定 ID による表示)
- [ ] 2.2 snapshot 構築 + 差分適用 + 内容変更検知 (`FullSnapshotContentTargets` 翻案 → `reconfigureItems`) (→ Requirement: 差分更新)
- [ ] 2.3 値キー → `CellRegistration` の遅延登録機構 (`KsCellRegistry` 翻案) (→ Requirement: 値キーによるテンプレート切り替え)
- [ ] 2.5 未登録キーのフォールバック (debug assertion / release 空セル + 警告ログ) (→ Requirement: 未登録キーの挙動)
- [ ] 2.6 `UICollectionViewDataSourcePrefetching` の接続口 (内部 protocol のみ、phase-8 が実装を接続)。最小契約 (indexPath → アイテム変換・cancel 通知) の unit test を含める

## 3. セルホスティング (ios/ADR-0002)
- [ ] 3.1 `UIHostingConfiguration` セル + `prepareForReuse` でのホスティング破棄 (→ Requirement: セル再利用時の状態非保持)
- [ ] 3.2 自己サイズ補正 (`KsCellViewSupport` / `CustomCellRowPlacement` 翻案) (→ Requirement: セル自己サイズ)

## 4. レイアウト (ios/ADR-0003)
- [ ] 4.1 自前 compositional sectionProvider: list / fixed / adaptive (→ Requirement: layout 値による表示形態)
- [ ] 4.2 向き別列数 (environment 参照 — design Decision 4) (→ Requirement: layout 値による表示形態 / 向き別列数)
- [ ] 4.3 layout 値の実行時参照 + `invalidateLayout()` 切り替え (→ Requirement: レイアウトの動的切り替え)
- [ ] 4.4 `rowSpacing` / `columnSpacing` (→ Requirement: スペーシング)
- [ ] 4.5 `contentPadding` (内側余白、インジケータ不動) (→ Requirement: contentPadding)
- [ ] 4.6 list 区切り線 (hairline サブビュー — design Decision 3、既定表示 + opt-out) (→ Requirement: list の区切り線)

## 5. DSL / SwiftUI ラッパー (ios/ADR-0004)
- [ ] 5.1 `UIViewControllerRepresentable` + Coordinator 薄層 (→ Requirement: プレーンな配列と安定 ID による表示)
- [ ] 5.2 `id:` キーパス指定の overload (→ Requirement: プレーンな配列と安定 ID による表示 / 非準拠型)
- [ ] 5.3 `Template` result builder (値キー / 型 / 単一クロージャの 3 形)
- [ ] 5.4 `header:` / `footer:` (boundary supplementary + ホスティング) (→ Requirement: ルートヘッダー / フッター)
- [ ] 5.5 `onItemTap` / `onItemLongTap` / `touchFeedback` (セル選択・ハイライト機構) (→ Requirement: アイテムタップ / ロングタップ)
- [ ] 5.6 `KsScrollController` + コマンドキュー + apply completion flush (→ Requirement: スクロール制御)

## 6. テスト
- [ ] 6.1 collection-core の全 Scenario に対応する単体テスト (差分更新・テンプレート解決・未登録キー・id: 指定)
- [ ] 6.2 collection-layout の Scenario テスト (レイアウト計算・スペーシング・切り替え)
- [ ] 6.3 collection-interaction の Scenario テスト (タップ・スクロール命令キュー・未接続 no-op)
- [ ] 6.4 テスト実行と結果報告 (handbook: test-execution)
- [ ] 6.5 Requirement ⇔ 検証層 (unit / Simulator 統合 / 実機手動) の対応表を整理 (verify / review の指標。実機手動でしか検証できない Scenario — 性能・状態非保持・回転 — を明示)

## 7. Sample (sample-parity / design Decision 5)
- [ ] 7.1 `samples/ios/` scaffold: Xcode プロジェクト + Local Package 参照 + `SampleScreen` / `SampleTheme` / ルートメニュー
- [ ] 7.2 SampleTheme のトークンを承認モックの値で定義 (mock との視覚照合)
- [ ] 7.3 デモ 9 画面 (agenda 決定の画面タイトル・検証対象の表の通り) — mock との視覚照合 (ルートメニュー / リスト / グリッド固定列)
- [ ] 7.4 デモデータ・文言を phase-3 追随可能な形で確定 (sample-parity: 一字一句の正はこの実装)

## 8. 性能検証 (design Decision 6)
※ 8.1 はグループ 4 完了直後に実施する (Sample 完成を待たない — 最小の計測ハーネス画面で行う)
- [ ] 8.1 エンジン中核 + レイアウト完成時点での早期計測 (iPhone 11、可変行高混在 10,000 件、固定シード) (→ Requirement: 大量件数での仮想化・再利用)
- [ ] 8.2 計測手順・合格基準の草案を evidence/ に計測結果と共に記録 (handbook への昇格は ksn-distill で実施 — design Decision 6)
- [ ] 8.3 最終計測 (Sample「大量件数」画面) と evidence/ への記録 (計測値・条件)

## 9. ドキュメント追随
- [ ] 9.1 dsl-samples.md を phase-2 決定へ追随 (値キー・`id:`・スペーシング・contentPadding・区切り線・ヘッダー/フッター、「実装フェーズへの申し送り」の解消済み項目の整理)
- [ ] 9.2 セル再利用の state 非保持を利用者向け注意書きとして記載 (置き場: dsl-samples の注記または README。skills/ 方式の本文書化は phase-7)
