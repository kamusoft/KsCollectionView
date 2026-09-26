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

### phase-3 からの申し送り (2026-09-05 実装結果)

`touchFeedbackColor` の意味論が両プラットフォームで非対称: iOS は渡された色をそのままセル全面の塗りにし、Android は material3 の `ripple` が渡された色に自前で不透明度を掛ける (android/ADR-0003 の帰結)。同じ生値を渡すと Android では不可視になるため、Sample「リスト」は描画結果を揃える別の生値を渡している (iOS は accent の 15%、Android は accent そのまま — `kasane/changes/archive/2026-09-05-android-wrapper-foundation/deviation.md` 4 件目)。本フェーズは両プラットフォームの DSL に同時に触るため、ここで統一の方向 (iOS が不透明度を掛ける側に寄せる / Android が生値をそのまま塗る / 語彙を分ける) を決めて sample-parity の生値一致を回復する。

### phase-4 からの申し送り (2026-09-26 実装結果)

- 端を表示中の端への挿入 (core/ADR-0018): いちばん下を表示中に末尾へ項目を足すと、表示範囲は末尾へ送られて末尾に留まる。末尾への追加読み込みでこれがそのまま働くと、フッター (末尾ローディング) が見え続けて次の読み込みが連鎖しうる。追加読み込みの反映を「端への挿入」として扱うか (発火の抑止・フッターを含めた末尾の定義) を本フェーズで決める
- グループとの組み合わせ: 追加読み込みで末尾のグループと同じグループの値の項目が続くと、既存のグループが伸びる (見出しの件数が変わる)。グループの値の不連続は不正入力 (core/ADR-0015) なので、ページの境目でグループが割れない順に並べる責任は利用者にある。この前提と見出しの件数の見え方を、Sample と利用者ドキュメントで扱うかを決める
- 実装の実際: `kasane/changes/archive/2026-09-26-sections-grouping/deviation.md`、Android は末尾への送りを `KsPositionKeeper` の `followEnd` が行う

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
