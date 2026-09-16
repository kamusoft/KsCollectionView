# Exploration: ios-self-sizing-layout-loop

## 課題 / 動機

iOS エンジンで、2 列グリッド (`.grid(columns: .fixed(2))` = 列幅が表示幅の 1/2) に自己サイズの行 (一様な高さの文字セル) を載せた 2,000 件の配列を、エンジンテストの走査ヘルパで**半画面ずつ 450 行ぶん送り続ける**と、セルの推奨サイズ (`preferredLayoutAttributesFitting` の高さ) が毎レイアウトパスで 1/3 pt ずつ伸び続け (68.0 → 68.33 → 68.67 → 69.0 …)、UIKit のレイアウトループ検出 (`_UICollectionViewFeedbackLoopDebugger`) が fatal error を出してテストプロセスが落ちた。iPhone 16e Simulator / iOS 26.0.1 (倍率 3)。送り先へ一度に送る経路では再現しない。

`performance-criteria-review` (L 級) の review-010 の修正サイクル (2026-09-16) で、アンカーテストの送り方をレビューの推奨 (半画面ずつの段階送り) に変えようとして発見した。本務とは無関係の既存経路の挙動のため、オーナー判断 (2026-09-17) で別 change として簡易起票し、本務側は一度に送る形で回避した (`kasane/changes/performance-criteria-review/deviation.md` の「アンカーテストの送り方」の項。archive 後は `kasane/changes/archive/*-performance-criteria-review/`)。

伸び幅 1/3 pt は倍率 3 の 1 画素に一致し、以前の実測 (同 deviation.md「推定高さと一致するセルの自己サイズ (iOS)」の項: 推定と実測の半画素未満の差が解き直しを起こさないまま「渡した高さのまま行が積まれる」) と同根の可能性がある。列幅が整数にならない 2 列 (390 pt ÷ 2 = 195 pt は整数だが、余白・行間の端数や `UIHostingConfiguration` の測定の丸めが噛み合わない) が疑わしい。

該当箇所の見当: `ios/Sources/KsCollectionView/KsHostingCell.swift` (自己サイズの測定)、`ios/Sources/KsCollectionView/KsCollectionViewController.swift` (`makeLayout` の item / group の寸法)、`ios/Sources/KsCollectionView/KsEstimatedHeight.swift` (推定値の返し方)。テストの再現手順は `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift` の `advanceToSolvedPosition` (半画面ずつの段階送り) を 2 列グリッド 2,000 件に適用する形。

## 検討した選択肢 (却下案と理由を含む)

(未探索)

## 決定事項

(未探索)

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

(なし)

## 未決の論点

**未探索 (簡易起票)** — 深掘りはこのメモを出発点に通常の探索で行う。現時点で見えている疑問:

- 実利用 (利用者の手のスクロール) で同じ往復が起きるか。テストの段階送り (`setContentOffset` を静止を待たずに重ねる) 特有の条件なのか
- 製品構成 (レイアウトループ検出の環境変数なし) では落ちずに CPU を食い続けるだけなのか、それとも高さが実際に伸び続けて表示が崩れるのか
- 伸びる 1/3 pt が倍率依存 (倍率 2 では 1/2 pt) か、`UIHostingConfiguration` の測定と compositional layout の丸めのどちら側で生じているか
- 収束させる手段の候補: 測定結果を画素格子に丸めて返す (現行は「実測値そのものを返す」設計。deviation.md の項に理由がある)、または列幅の端数を無くす

## 変更級の推奨

未判定 (まずは条件の特定だけの調査。修正が要るなら S〜M)
