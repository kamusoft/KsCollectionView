# Exploration: ios-hosting-content-reuse

## 課題 / 動機

iOS エンジンで、セル (`KsHostingCell`) そのものは再利用されているが、`prepareForReuse` で `contentConfiguration = nil` にしているため (`ios/Sources/KsCollectionView/KsHostingCell.swift:161` 付近)、表示に入る項目ごとにセルの中身の hosting (`UIHostingConfiguration` の中身) が作られて捨てられている。

`drag-reorder` (L 級) の tasks 6.2 (基準機 iPhone 11 の体感ゲート、2026-09-30) で、「並べ替え」画面の hitch の数値がページング画面より大きく悪かったため原因を切り分けて見つかった (`kasane/changes/archive/2026-10-01-drag-reorder/evidence/perf-diag-ios-reorder-cells.md`)。

- 基準機の trace: 主スレッドのコミット中の処理の内訳はセルの生成 42%・hosting の layoutSubviews 37%・自己サイズ 18%・hosting view の解放 10.5%。解放は、次のセルを用意する最中の `objc_autoreleasePoolPop` の中で、再利用で捨てた前の中身の解放 (`tearDown` → `GraphHost.invalidate`) として起きていた
- Simulator の計数 (iPhone 11 / iOS 18.6、10,000 件・100 件ずつのグループ・見出しの固定・下向き 450 フレーム): セルの生成は 9 件だけ、hosting の生成 / 解放は表示した項目 1 件ごとに 1 回 (399 / 390)。変更前のコード (HEAD) でも同じ計数で、drag-reorder の変更で入ったものではない
- 参考の変種 (`contentConfiguration = nil` を外したもの、1 走行ずつ): hosting の生成・解放が 0 になり、主スレッドの CPU 時間が 4〜8% 下がった
- 体感ゲート (cross/ADR-0006) はオーナーの体感で合格しており、実害は数値の側だけ

オーナー判断で別 change として簡易起票した (drag-reorder のスコープ外で、nil にしている前提の確認が要るため)。

## 検討した選択肢 (却下案と理由を含む)

## 決定事項

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

## 未決の論点

- 未探索 (簡易起票)
- `contentConfiguration = nil` にしている理由の確認: 中身と計測のハンドラを一緒に外すためと見られる (切り分けのワーカーの推測)。外さずに使い回したとき、前の項目の中身・ハンドラ・読み上げの操作・高さの計測が次の項目に残らないか
- 使い回したときに SwiftUI の中身の状態 (`@State` など) が項目をまたいで残る問題が起きないか (項目の識別子との関係)
- ios/ADR-0006・0008 (可視セルの作り直し) や `ios-prefetched-cell-content-refresh` (先行組み立てのセルの内容) との関係
- 効果の確かめ方: 基準機の体感ゲートと hitch の数値で、変更前と同じ fixture・同じ操作列で比べられるか

## UI 素材 (ui/references/ の一覧と注釈)

## 変更級の推奨: S / M / L (理由)

未判定 (エンジンのセルの寿命に触れるため M 以上の見込み)
