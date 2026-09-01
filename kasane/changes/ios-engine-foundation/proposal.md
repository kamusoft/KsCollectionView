# Proposal: ios-engine-foundation

## Why

phase-1 で対称 DSL の外形 (core/ADR-0002〜0009) が確定し、phase-2 の議論で iOS 側の実現方式 (ios/ADR-0001〜0004) が固まった。iOS エンジン基盤はロードマップの全機能フェーズ (画像ロード・セクション・ページング・D&D) の土台であり、最初の動く実装として DSL の書き味と性能要件 (大量件数での仮想化・再利用) を実証する。

## What Changes

- `ios/` ビルドルートに SwiftPM パッケージ `KsCollectionView` を新設 — UICollectionView + diffable data source + `UIHostingConfiguration` エンジン (KsSettingsViewUI からの翻案移植、ios/ADR-0001)
- 公開 DSL: `KsCollectionView(items, layout:, contentPadding:)` + 値キーテンプレート切り替え (core/ADR-0004) + `id:` キーパス指定 (core/ADR-0003) + `onItemTap` / `onItemLongTap` / `touchFeedback` (core/ADR-0009) + `KsScrollController` (core/ADR-0007) + ルートヘッダー/フッター + list 区切り線 (既定表示、core/ADR-0006)
- レイアウト: list / 固定列 / adaptive / 向き別列数 + `rowSpacing` / `columnSpacing` を自前 compositional セクションで統一実装 (ios/ADR-0003)
- `UICollectionViewDataSourcePrefetching` の接続口 (画像プリフェッチは phase-8 が接続)
- `samples/ios/` scaffold (`SampleScreen` / `SampleTheme` / ルートメニュー) + デモ 9 画面 (sample-parity 準拠、phase-3 の Android が追随)
- 性能検証 (iPhone 11 実機、hitch time ratio 5ms/s 未満、可変行高混在 10,000 件) と `handbook/ios/` への performance-verification 規約の追加
- phase-1 成果物 dsl-samples.md の phase-2 決定 (値キー・`id:`・スペーシング・区切り線・ヘッダー/フッター) への追随

影響する能力: collection-core (データ・テンプレート・更新) / collection-layout (レイアウト・スペーシング・区切り線・ヘッダーフッター) / collection-interaction (タップ・スクロール制御) / samples (検証装置)

## Non-Goals

- 型ベースのテンプレート切り替え (混在配列を型で分ける副次変種) — v1 実装から除外 (spec-review でオーナー判断)。存在型の ID 取り出し・型間衝突・比較の設計がまるごと必要になる一方、値キー + enum で異種セルは全て書ける。API の将来余地としてのみ残す (core/ADR-0004)
- ページング・Pull to Refresh — phase-5 (状態機械の設計判断が別能力)
- セクション/グループ化・sticky ヘッダ・グループ単位余白 — phase-4 (別能力)
- D&D 並べ替え — phase-6 (別能力)
- 画像ロードと `KsImage`・プリフェッチの実接続 — phase-8 (口だけ開ける。ローダ設計が別判断)
- Android 実装 — phase-3 (別ビルドルート。Sample の画面集合・文言は本 change の確定値へ追随する)
- 配布設定 (SPM リリース・CI) — phase-7 (配布専業フェーズ)

## Impact

- 破壊的変更なし (初実装)。ただし公開 API はこの change で初めて世に出るため、以後の変更コストが高い — dsl-samples.md と ADR 群への整合を必須とする
- リスク: `UIHostingConfiguration` self-sizing の性能が可変行高混在 10,000 件で基準未達の場合、セルホスティング方式の再検討 (ios/ADR-0002 の再訪) が必要。性能検証タスクを実装の後段ではなくエンジン中核の直後に置いて早期に検知する

## 級: L

新規エンジン導入 (アーキテクチャ) + 公開 DSL 初実装 (覆すコスト高) + 複数能力横断

domain: ios
roadmap: v1-foundation/phase-2-ios-engine-foundation
