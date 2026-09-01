# Android ラッパー基盤

Compose Lazy 系 (`LazyColumn` / `LazyVerticalGrid`) の薄いラッパー。リスト・グリッドの表示まで。phase-2 と並行可。

## 論点

- Sample scaffold (初手): `samples/android/` の器 — composite build (`includeBuild`) で本体をソース参照、`SampleScreen` / `SampleTheme` / ルートメニューの対称構造 (iOS 側 phase-2 と sample-parity 準拠で一致させる)
- ラッパー構成: DSL → Lazy DSL への変換層の設計 (ks-settingsview-compose の DSL 変換パターン参照)
- テンプレート種別 → `contentType` のマッピング (phase-1 の宣言形式を受ける)
- レイアウト: `GridCells.Fixed` / `GridCells.Adaptive` の対応、画面向き可変の下準備
- 再利用効率の確認: 安定 `key` + `contentType` が意図通り効いているかの検証方法
- `LazyLayoutCacheWindow` (Compose 1.9+) を既定で設定するか利用者に委ねるか
- スクロール制御: `LazyListState` / `LazyGridState` の公開方針 (ラップするか素通しか)
- Compose BOM の最低バージョンと minSdk 29 での制約確認

### phase-1 からの申し送り (2026-09-01)

DSL の外形は core/ADR-0002〜0009 と [dsl-samples.md](../phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md) で確定済み。既存論点への影響:

- 「スクロール制御: `LazyListState` の公開方針」は ADR-0007 で方向が決着 — 素通しせず `KsScrollController` (plain オブジェクト、UI ライフサイクル非依存) でラップする。attach/detach と未接続時 no-op の実装が本フェーズの課題
- レイアウト切替 (List ⇔ Grid) 時のスクロール位置維持 (ADR-0006 の負の帰結 — 内部 Composable が入れ替わるため)
- 混在配列の安定 ID の取り出し方 (`key` ラムダと混在型の噛み合わせ・マーカー interface の要否)
- 未登録テンプレート型の挙動 (ADR-0004 残課題)
- Pull to Refresh 接続の最終形 (`onRefresh` 引数 vs 標準 `PullToRefreshBox` との住み分け)
- `onItemTap` / `onItemLongTap` / `touchFeedbackColor` (既定 ripple) の提供 (ADR-0009)

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
