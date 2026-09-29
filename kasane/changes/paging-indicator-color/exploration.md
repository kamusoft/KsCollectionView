# Exploration: paging-indicator-color

## 課題 / 動機

ページングと Pull to Refresh の読み込み中のインジケータ (次のページの読み込み中・最初の読み込み中の既定のくるくる、Pull to Refresh のインジケータ) の色を、利用者が一覧のプロパティで指定できるようにする (2026-09-27、オーナー指示で起票)。

発見の文脈: `paging-state-machine` の mock との照合 (tasks 7.1) で、ライブラリの既定の読み込み中の表示が、承認 mock のグレーではなく Sample のアクセント色 (青) に見えた。iOS は既定の `ProgressView` が環境の tint (Sample の `.tint(SampleTheme.accent)`) を受け、Android は既定の `CircularProgressIndicator` が Material のテーマの primary (Sample では accent) を受けるため。一方 Pull to Refresh のインジケータは両プラットフォームとも OS / Material の既定 (グレー系) で、同じ一覧の中で読み込み中の色がそろわない (比較画像: `kasane/changes/archive/2026-09-29-paging-state-machine/ui/verification/` の ios-01・android-01 と `evidence/` の ios / android-pull-to-refresh-refreshing。画像は archive 時に削除したため git の履歴から辿る)。オーナーは「インジケータの色はプロパティで持たせる (別タスクで良い)」と判断した。

関連: `library-default-colors-dark-mode` (ライブラリの既定の色の表示モード対応。既定値をどう決めるかはそちらと重なりうる)。

## 検討した選択肢 (却下案と理由を含む)

## 決定事項

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

## 未決の論点

**未探索 (簡易起票)** — 深掘りはこのメモを出発点に通常の探索で行う。現時点で見えている疑問は次のとおり。

- どのインジケータに効かせるか (次のページの読み込み中・最初の読み込み中・Pull to Refresh の 3 つを 1 つの色でそろえるか、別々に持つか)
- 指定しないときの既定の色: 今の「プラットフォームのテーマ (iOS の tint / Android の primary) に従う」のままか、ライブラリの固定の既定色にするか (core/ADR-0010 の「両プラットフォームで同じ実値」の方針との関係、`library-default-colors-dark-mode` のライト / ダーク 2 組の扱いとの関係)
- 公開 API の置き場 (iOS は modifier、Android は `KsPaging` の引数か `KsCollectionView` の引数か。Pull to Refresh はページングを付けない一覧でも使えるため、ページングの設定の外に置く必要があるか)
- Android の Pull to Refresh のインジケータ (`PullToRefreshDefaults.Indicator`) と iOS の `UIRefreshControl` の `tintColor` で、同じ色の指定が同じ見え方になるか

## UI 素材 (ui/references/ の一覧と注釈)

## 変更級の推奨

未判定 (暫定: M。両プラットフォームの公開 API 追加)

追記 (2026-09-29): `paging-state-machine` で次のページの読み込み中の表示から円の下地を外した結果、iOS の既定の表示の型 `KsPagingDefaultIndicator` (下端に重ねる表示) と `KsPagingDefaultProgress` (0 件の真ん中の表示) が、どちらも標準の `ProgressView` だけの同じ中身になった (review-004.md の Suggestion)。色を足すときに 1 つにまとめるかを決める。
