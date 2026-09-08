# Exploration: android-scrollbar-parity

## 課題 / 動機

Android の `KsCollectionView` ではスクロールバー (スクロールインジケータ) が表示されない。iOS は `UICollectionView` が標準で表示するため、同じ Sample「大量件数」を両基準機で並べるとスクロールバーの有無が違う。プラットフォーム間パリティの穴 (cross/ADR-0004 の観点)。

発見の文脈: `performance-criteria-review` の探索中、cross/ADR-0006 (proposed) の手順で Pixel 4a の「大量件数」をオーナーが手動フリックした際に気づいた (2026-09-08)。性能とは無関係で、オーナー判断で別 change として起票。

現状の把握 (起票時点の grep): Compose の Lazy 系 (`LazyVerticalGrid`) にはスクロールバーの標準実装が無く、ライブラリ (`android/library`) にもスクロールバーに相当する実装は無い。iOS 側にも明示的な設定は無く UIKit の既定に任せている。

## 検討した選択肢 (却下案と理由を含む)

(未探索)

## 決定事項

(未探索)

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

(なし)

## 未決の論点

**未探索 (簡易起票)** — 深掘りはこのメモを出発点に通常の探索で行う。現時点で見えている疑問:

- 「表示する」がパリティのゴールか: iOS の既定 (スクロール中だけ出て消えるインジケータ) に Android を寄せるのか、両方を DSL の設定 (表示 / 非表示) にするのか
- Compose 側の実装手段: `LazyGridState` から可視範囲と総件数を取って自前で描くか、外部ライブラリを使うか (直接依存の方針は core/ADR-0012 の画像ローダーと同型の判断になる)。可変行高の混在で位置と長さをどう推定するか
- 10,000 件のような大量件数で、インジケータの描画がスクロール性能 (cross/ADR-0006 の体感ゲート) に影響しないか
- Sample のパリティ規約 (handbook/cross/sample-parity.md) 上、片側先行の追跡をどう書くか

## UI 素材 (ui/references/ の一覧と注釈)

(なし)

## 変更級の推奨

未判定 (暫定: M。Android 側の新規描画と、DSL に設定を足すなら core の契約が絡むため)
