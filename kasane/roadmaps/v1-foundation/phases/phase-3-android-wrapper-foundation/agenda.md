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

### phase-2 からの申し送り (2026-09-02、着手前に対応する)

iOS エンジン基盤 ([ios-engine-foundation](../../../../changes/ios-engine-foundation/proposal.md)) の実装で判明した、対称 DSL の外形に関わる 2 点。**本フェーズの着手前に対応する** (オーナー判断。iOS 側の暫定形は deviation.md に記録)。

- **値キーテンプレートの推論形が書けない**: core/ADR-0004 と dsl-samples の Swift 例 `Template(.message) { item in ... }` は、result builder 文脈で `Item` / `Key` が同時に未確定になり型推論が失敗する (コンパイラの内部エラー)。iOS 実装は暫定で明示形 `Template(TemplateDemoKind.message) { (item: TemplateDemoItem) in ... }` に揃えたが、これはオーナーの本意ではない。推論形を成立させる API の候補: builder のクロージャに型を渡す初期化子 / `Template` を `KsCollectionView` の入れ子型にして親から型を引き継ぐ / 明示形を正式化して ADR-0004 と dsl-samples を改訂。Kotlin の `template(Kind.Message) { }` との対称性を軸に決める
- **`Template` の無接頭辞命名**: 他の公開型はすべて `Ks` 接頭辞だが `Template` だけ無接頭辞で、利用者側の同名型と衝突しやすい (phase-1 の確定語彙)。上記と同じタイミングで `KsTemplate` にするかを決める (dsl-samples・ADR-0004 の例・Sample の追随で済む)

### phase-2 ライブ調整からの申し送り (2026-09-03)

iOS 側に「検証: 行の高さ変化」画面 (行タップで展開/折りたたみ、親 state / テンプレート内 state の 2 経路、list / grid 切替) を追加し、`UIHostingConfiguration` のはみ出し検出と対策の A/B に使った (ios-engine-foundation の evidence/height-change-*)。オーナー示唆: Android にも同種の画面があった方がよい。

- **行の高さ変化の検証画面を Android にも置くか**: Compose Lazy 系で item の高さ変化のアニメーション (`animateItem` / `animateContentSize`) を確認する場になる
- 親 state の観測は iOS 側の論点 [template-parent-state-observation](../../../../changes/template-parent-state-observation/exploration.md) と対称性を見る
- 置き方: sample-parity の「プラットフォーム固有の技術検証画面」とするか、両 platform 共通のデモに昇格させるかを決める

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
