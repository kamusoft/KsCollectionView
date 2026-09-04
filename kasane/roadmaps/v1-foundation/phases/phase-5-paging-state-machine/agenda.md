# ページング状態機械

無限スクロール・Pull to Refresh・ローディング/エラー/empty 表示を統一した状態モデルで提供する。両プラットフォーム。

## 論点

- 状態機械の契約: idle / refreshing / appending / failed / endReached の分離 (旧 `SetLoadMoreCompletion(bool)` では表現不足)
- 追加ロードの発火: 旧 `LoadMoreMargin` 方式 (アイテム出現契機) は Compose の prefetch 拡大で不成立 — `layoutInfo` / `onScrollGeometryChange` ベースの発火設計
- 重複発火防止・refresh と append の競合・キャンセル・スクロール位置維持
- Android で Paging 3 に依存するか自前状態機械にするか (対称性の観点では自前、実装コストでは Paging 3)
- Pull to Refresh: `.refreshable` / `PullToRefreshBox` の対称ラップ
- 表示部品: 末尾ローディング・エラー + 再試行・empty ビューの提供範囲 (shimmer/skeleton を含めるか)

### phase-1 からの申し送り (2026-09-01)


公開契約は core/ADR-0005 で確定: 5状態 enum `KsPagingState` を利用者 (VM) が所有し、DSL に状態 + `onLoadMore` を渡す。ライブラリはトリガー発火・多重発火抑止・標準フッター (差し替え可)・Pull to Refresh 接続。利用形は [dsl-samples.md](../phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md) シナリオ3

- 論点「Paging 3 依存か自前か」は ADR-0005 の帰結として自前が既定路線 (状態機械はライブラリ内包でなく利用者所有のため Paging 3 のデータ所有モデルと不整合)
- 残課題: `failed` にエラー内容を持たせるか / 発火しきい値 (旧 `LoadMoreMargin` 相当) を paging 設定に持つか

### phase-3 からの申し送り (2026-09-04)

Pull to Refresh の Compose 側の流儀を確認済み (phase-3 agenda「決定事項」論点 6)。Android の外形は `onRefresh: (suspend () -> Unit)?` 引数で、Swift の `.refreshable { await }` と同じ「非同期処理が終わるまでインジケータを出す」意味論。ライブラリが `LazyVerticalGrid` を material3 `PullToRefreshBox` (1.4 系で stable) で内包し、`isRefreshing` は「`onRefresh` 実行中」または `KsPagingState.Refreshing`。`onRefresh` 未指定なら挟まない。利用者側で包む形は非対称のため不採用。実装は本フェーズで両プラットフォーム同時に行う。

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
