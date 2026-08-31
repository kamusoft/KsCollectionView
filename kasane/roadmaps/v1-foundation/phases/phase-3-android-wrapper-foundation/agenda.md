# Android ラッパー基盤

Compose Lazy 系 (`LazyColumn` / `LazyVerticalGrid`) の薄いラッパー。リスト・グリッドの表示まで。phase-2 と並行可。

## 論点

- ラッパー構成: DSL → Lazy DSL への変換層の設計 (ks-settingsview-compose の DSL 変換パターン参照)
- テンプレート種別 → `contentType` のマッピング (phase-1 の宣言形式を受ける)
- レイアウト: `GridCells.Fixed` / `GridCells.Adaptive` の対応、画面向き可変の下準備
- 再利用効率の確認: 安定 `key` + `contentType` が意図通り効いているかの検証方法
- `LazyLayoutCacheWindow` (Compose 1.9+) を既定で設定するか利用者に委ねるか
- スクロール制御: `LazyListState` / `LazyGridState` の公開方針 (ラップするか素通しか)
- Compose BOM の最低バージョンと minSdk 29 での制約確認

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
