# iOS エンジン基盤

UICollectionView + diffable data source + `UIHostingConfiguration` によるエンジンと、SwiftUI DSL ラッパー。リスト・グリッドの表示まで。

## 論点

- Sample scaffold (初手): `samples/ios/` の器 — Local Swift Package 参照、`SampleScreen` / `SampleTheme` / ルートメニューの対称構造 (Android 側 phase-3 と sample-parity 準拠で一致させる)
- エンジン構成: `UICollectionViewDiffableDataSource` + `UICollectionViewCompositionalLayout` の構成。KsSettingsViewUI (`../../../../../KsSettingsView/ios/Sources/KsSettingsViewUI/`) からの流用範囲
- セルホスティング: `UIHostingConfiguration` の適用方針 (state 保持・再利用時の挙動・セル自己サイズ)
- テンプレート種別 → `CellRegistration` のマッピング機構 (phase-1 の宣言形式を受ける)
- レイアウト: リスト / 固定列グリッド / adaptive グリッドの Compositional Layout 実装
- SwiftUI DSL ラッパー: `UIViewControllerRepresentable` 構成 (KsSettingsViewSwiftUI のパターン踏襲)
- 旧 `../../../../../AiForms.CollectionView/CollectionView.iOS/` (ContentCellContainer 等) から参照する先行実装
- 大量件数での性能検証方法 (実機・件数・計測手順)。規約化の参考: `../KsSettingsView/kasane/handbook/maui/performance-verification.md` (kasane-initial-assets の申し送り — スクロール性能計測の規約として同種の必要性)
- `UICollectionViewDataSourcePrefetching` の口を基盤段階から開けておく (画像プリフェッチ接続は phase-8-image-loading が使う)

### phase-1 からの申し送り (2026-09-01)

DSL の外形は core/ADR-0002〜0009 と [dsl-samples.md](../phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md) で確定済み。本フェーズで詰める残課題:

- 混在配列の要素型と安定 ID の取り出し方 (Swift `any Identifiable` の制約をどう扱うか)
- 未登録テンプレート型が現れた場合の挙動 (debug 警告 + 空セル等 — ADR-0004 残課題)
- セル自己サイズ計測の成立 (旧 `ColumnHeight` 系を廃止した根拠。`UIHostingConfiguration` の self-sizing で担保)
- スクロール命令の「データ反映後実行」の順序保証 (snapshot apply との待ち合わせ — ADR-0007 要件)
- `onItemTap` / `onItemLongTap` / フィードバック色を UICollectionView のセル選択・ハイライト機構の正道で実装 (ADR-0009)

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
