# Exploration: ios-separator-update-guard

## 課題 / 動機

iOS エンジンで、レイアウト確定のたび (`viewDidLayoutSubviews`) に走る可視セルの再構成 (`KsCollectionViewController.updateVisibleCellSeparators()` → `configure(cell:at:)`) が、スクロール中の毎フレーム・全可視セルに対して**変化の有無に関わらず**タッチ時の背景色を代入している (`KsHostingCell.configureTouchFeedback(color:)` に変化ガードが無い。区切り線側の `configureSeparators` はガードを持つ)。代入のたびにアクセシビリティ差し替え済みの `setBackgroundColor` → 色の比較 → 動的色の trait 解決が走り、CA レイヤも dirty になる。さらにグリッド (区切り線を出さない構成) では `indexPathsForVisibleItems` の走査とセルごとの `cellForItem(at:)` 自体が毎レイアウト空回りしている。

`image-loading` (L 級) の tasks 7.1 (iOS 画像グリッドの hitch 計測) の不合格の切り分け (trace 解析、2026-09-08) で本務と無関係に発見した既存経路の無駄。オーナー判断で別 change として積んだ (image-loading への同梱は「画像ロードと無関係の既存経路」のため見送り)。

観測値 (iPhone 11 / iOS 18.7.8 / Release、3 秒〜6 秒のフリック窓): 背景色代入系のスタックが窓あたり 7〜15 サンプル (1 ms 刻み、主スレッド稼働率で 1〜2 pt)。グリッドでの走査の空回りが追加 4〜14 サンプル/窓。**hitch (1 フレーム落ち) を消す保証は無い**規模で、主スレッド費用の削減に留まる見込み。詳細は `kasane/changes/image-loading/deviation.md` の「iOS 7.1 の不合格の切り分け」の項 (archive 後は `kasane/changes/archive/*-image-loading/`)。

該当箇所: `ios/Sources/KsCollectionView/KsCollectionViewController.swift` (`viewDidLayoutSubviews` / `configure(cell:at:)` / `updateVisibleCellSeparators`)、`ios/Sources/KsCollectionView/KsHostingCell.swift` (`configureTouchFeedback(color:)`)。

## 検討した選択肢 (却下案と理由を含む)

(未探索。起票時点の見立て: `configureTouchFeedback` を `configureSeparators` と同じ「値が変わったときだけ書く」形にする / `isList == false` かつ区切り線非表示なら `updateVisibleCellSeparators` を早期リターンする)

## 決定事項

(未探索)

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

(なし)

## 未決の論点

**未探索 (簡易起票)** — 深掘りはこのメモを出発点に通常の探索で行う。現時点で見えている疑問:

- `updateVisibleCellSeparators` が毎レイアウトで全可視セルを再構成しているのは「先頭行の Top 区切り線」を差分適用後に揃えるためだが、それはリストかつ区切り線表示のときだけ要る。グリッドで丸ごと省いて、位置依存の表示が崩れる場面 (セクション・ヘッダ導入後) が無いか
- 変化ガードを入れる場合、`configuration.touchFeedbackColor` の差し替え (利用者が構成を変える経路) が確実に反映されるか (ガードの比較対象を UIColor の同値で行うと動的色で外れうる)
- 効果の実測: image-loading で立て直した iOS の hitch 計測手順 (signpost 区間 + プロセス指定の Instruments) で A/B を取り、差が測定誤差に埋もれるなら「主スレッド費用の削減に留まる」と証跡に書く

## 変更級の推奨

未判定 (暫定: S。数行の変化ガードと早期リターン。ただし A/B 計測を伴う)
