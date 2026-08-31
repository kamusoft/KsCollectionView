# iOS エンジン基盤

UICollectionView + diffable data source + `UIHostingConfiguration` によるエンジンと、SwiftUI DSL ラッパー。リスト・グリッドの表示まで。

## 論点

- エンジン構成: `UICollectionViewDiffableDataSource` + `UICollectionViewCompositionalLayout` の構成。KsSettingsViewUI (`../../../../../KsSettingsView/ios/Sources/KsSettingsViewUI/`) からの流用範囲
- セルホスティング: `UIHostingConfiguration` の適用方針 (state 保持・再利用時の挙動・セル自己サイズ)
- テンプレート種別 → `CellRegistration` のマッピング機構 (phase-1 の宣言形式を受ける)
- レイアウト: リスト / 固定列グリッド / adaptive グリッドの Compositional Layout 実装
- SwiftUI DSL ラッパー: `UIViewControllerRepresentable` 構成 (KsSettingsViewSwiftUI のパターン踏襲)
- 旧 `../../../../../AiForms.CollectionView/CollectionView.iOS/` (ContentCellContainer 等) から参照する先行実装
- 大量件数での性能検証方法 (実機・件数・計測手順)
- `UICollectionViewDataSourcePrefetching` の口を基盤段階から開けておく (画像プリフェッチ接続は phase-8-image-loading が使う)

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
