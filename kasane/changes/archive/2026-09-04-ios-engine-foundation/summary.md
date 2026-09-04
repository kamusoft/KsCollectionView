# Live Summary: ios-engine-foundation (仕上げ切替 2026-09-03)

ADR ios/0001 (KsSettingsViewUI からの翻案移植) の照合調査を起点に、ライブ調整で実物確認しながら確定した内容。経緯は session.md。

## 最終状態 (何がどうなったか)

1. **中央配置はみ出し対策の翻案**: セルの content を `KsRowContentPlacement` (SwiftUI `Layout`) で包む。提案された行の高さをそのまま自分の高さとして返し、content は自然高のまま上端へ置く。行の高さが content の変化に 1 レイアウトパス遅れる間に content が上下へはみ出す (本文が上から降りてくる) 事象を消す。翻案元 `../KsSettingsView/ios/Sources/KsSettingsViewUI/CustomCellRowPlacement.swift` の核心のみを移植し、実効行高 (固定行高契約) の概念は持ち込まない。水平位置は素の `UIHostingConfiguration` と同じ (自然幅が提案幅より小さい content は中央、幅いっぱいに広がる content は先頭) に保ち、縦だけを変える
2. **推定高さの実測化**: `.estimated(44)` 固定をやめ、`KsEstimatedHeight` (未計測は 44、計測後は直近 32 件の実測平均) を sectionProvider クロージャ内で実行時参照する。`KsHostingCell.preferredLayoutAttributesFitting` の自己サイズ結果を「測ったときの行の幅」と対で記録し、違う幅の実測が来た時点で前の幅の分を捨てる (遅延破棄。幅変化直後は前の幅の平均を使い、新しい幅の実測で置き換わる。即時 reset は初回レイアウトで実測値を捨てる回帰 (review-013) を起こしたため採らない)。header / footer の推定値は 44 据え置き。invalidate の契機は追加していない
3. **高さ変化の検証画面** (Sample, iOS 固有の技術検証画面): 行タップで展開/折りたたみ、親 state / テンプレート内 state の 2 経路、list / grid 切替。「展開中: N 行」表示で親 state を body でも読む (回避策 — 下記 4)
4. **文書**: deviation.md の tasks 3.2 の行を実態に合わせて改訂し、推定高さの行を追加。handbook/cross/runtime-behavior-verification.md の観測点表に検証画面の行を追加

## 採用値と根拠 (却下試行の要点)

- **はみ出し対策は「必要」**: 当初 deviation は「翻案元の補正が不要だったため」としていたが、オーナー実操作で発現 (上から降りてくる)。A/B 実測: 遷移パス (行 44.3pt / content 141.7pt) で content の offsetY −48.7 → 0.0、上方向はみ出し 4 回 → 0 回 (list / grid 両方)。修正後はオーナー実操作で全解消を確認。ワーカーの静止画観測「非発現」は遷移の一瞬を捉えられていなかった (却下)
- **推定値は「実測平均」**: キー別推定は compositional layout の `estimated` が item/group 定義単位で index path ごとに変えられないため不成立 (却下)。中央値は短い行が多数派だと固定 44 とほぼ同じ値にしかならず不採用 (大量件数デモ初回 contentSize: 固定 44 = 225,244 / 中央値 = 226,906 / 平均 = 264,301 / 真値 ≈ 300,000)。平均を採る理由は、推定値がコンテンツ全体の高さの見積もりに使われ、合計を言い当てる推定量が平均であるため。A/B (スクロール制御デモ list, 実測行高 64.3): 初回 contentSize 誤差 −26.9% (4705.0) → 0% (6433.33)、末尾命令中に contentSize が変化した回数 25 → 1、到達位置は同一。オーナー確認で問題なし
- **既定値 44 は据え置き**: 実測が入れば数フレームで置き換わるため、変える根拠が測定から出なかった
- **残る乖離**: grid では行高が列内最大セル高で決まるが実測はセル単位のため、行高混在 grid では平均でもやや過小 (固定 44 比で誤差は約半分)。list では乖離なし
- **水平位置は従来どおり中央** (review-012 Major-2 → オーナー判断): 初版は `.topLeading` で先頭固定にしていたが、幅を明示しないテンプレートの見え方が変わるため、余白を等分して中央に置く形に戻した (実測: 短い `Text` が左端密着 → 中央、evidence/row-placement-horizontal-{before,after}.png)。翻案元は content が常に幅を埋めるため水平の指針にならず、縦で使っている「余白があれば等分」の規則を水平にも当てて一貫させた
- **検証画面の回避策**: 遷移直後にタップが効かない不具合は、テンプレート内でしか読まれない親 state の変化が SwiftUI の依存グラフに載らないことが原因 (ログと A/B で裏取り)。本体ではなく検証画面側で body から state を読むことで回避。根本解決は別 change (下記)

## 触ったファイル

本体 (ios/Sources/KsCollectionView/): 新規 `KsRowContentPlacement.swift` / `KsEstimatedHeight.swift`、変更 `KsCollectionViewController.swift` / `KsHostingCell.swift`
テスト (ios/Tests/KsCollectionViewTests/): 新規 `KsRowContentPlacementTests.swift` (7 件) / `KsEstimatedHeightTests.swift` (10 件)
Sample (samples/ios/KsCollectionViewSamples/): 新規 `HeightChangeVerificationView.swift` / `HeightChangeRowBody.swift` / `HeightChangeSelfStateCell.swift` / `HeightChangeItem.swift` / `HeightChangeExpansionPath.swift` / `HeightChangeLayoutChoice.swift` / `VerificationScreen.swift` / `VerificationDestinationView.swift`、変更 `RootMenuView.swift` / `SampleLaunchView.swift`
文書・証跡: `deviation.md` (改訂)、`kasane/handbook/cross/runtime-behavior-verification.md` (観測点追加)、`evidence/height-change-*` (A/B メモ・png 6 枚)、`evidence/row-placement-horizontal-{before,after,plain}.png` + `-measurement.md`、`evidence/estimated-height-*` (A/B メモ・png 6 枚)、`session.md`
公開 API は不変。テスト: 77 件通過 (着手前 60 + 追加 17)。lint (comment-policy / identity / local-path) 通過

## 決定事項 / ADR 候補

- ADR 候補なし (翻案の範囲内・公開 API 不変)。ADR ios/0001 の骨格リスト「Store 経由」が ios/ADR-0004 で棄却されている文書乖離は蒸留時の是正候補 (session.md)
- 別 change に簡易起票: `kasane/changes/template-parent-state-observation/` (テンプレート内でだけ読まれる親 state の変更検知。公開 API / ADR 級)。根本解決後は検証画面の回避策を外して再確認する
- phase-3 agenda に申し送り: 行の高さ変化の検証画面を Android にも置くか

## レビュー

- review-012 (CHANGES_REQUESTED: 動画証跡・水平位置の先頭固定) → review-013 (CHANGES_REQUESTED: 幅 reset の回帰) → review-014 (**APPROVED**。実装の是正を要する指摘なし。任意の Suggestion 3 件は見送り)
