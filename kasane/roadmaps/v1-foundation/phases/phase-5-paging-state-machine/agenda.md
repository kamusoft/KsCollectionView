# ページング状態機械

無限スクロール・Pull to Refresh・ローディング/エラー/empty 表示を統一した状態モデルで提供する。両プラットフォーム。

## 論点

- 状態機械の契約: idle / refreshing / appending / failed / endReached の分離 (旧 `SetLoadMoreCompletion(bool)` では表現不足)
- 追加ロードの発火: 旧 `LoadMoreMargin` 方式 (アイテム出現契機) は Compose の prefetch 拡大で不成立 — `layoutInfo` / `onScrollGeometryChange` ベースの発火設計
- 重複発火防止・refresh と append の競合・キャンセル・スクロール位置維持
- Android で Paging 3 に依存するか自前状態機械にするか (対称性の観点では自前、実装コストでは Paging 3)
- Pull to Refresh: `.refreshable` / `PullToRefreshBox` の対称ラップ
- 表示部品: 末尾ローディング・エラー + 再試行・empty ビューの提供範囲 (shimmer/skeleton を含めるか)

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
