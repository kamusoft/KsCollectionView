# ios-6.3-fix: 基準機の目視の指摘 3 件 (iOS) の調査

- 環境: 作業専用の Simulator `ksn-drag-reorder-fix63-ios18` (iPhone 11 / iOS 18.6) と `ksn-drag-reorder-fix63-ios26` (iPhone 17 / iOS 26.5)。Release
- 対象: Sample「並べ替え」の複製 (スクラッチ。本体は作業ツリーの複製にログだけを足したもの) と、比べる相手として同じアプリに置いた UIKit 標準の並べ替え (10,000 件・1 セクションの list。差分データソースの並べ替えハンドラ `reorderingHandlers` + ドラッグ & ドロップの delegate。`performDropWith` では何もしない)。本体・Sample の作業ツリーには何も入れていない
- 操作: XCTest の合成タッチ (`press(forDuration: 1.0, thenDragTo:, withVelocity:, thenHoldForDuration:)`)。動きは `simctl io recordVideo` の録画から 60fps のコマを取り出し、前のコマとの差分で動いている区間を求めた
- 抜粋ログ: `ios-6.3-fix-probe.log` (隙間が動いた回・置いた処理・置く動きの完了・`hasActiveDrag` / `hasActiveDrop` の切り替わり)
- 本体は直していない (下の「結論」のとおり、指摘 1・2 は iOS の組み込み方 (design Decision 3) を変える判断が要り、指摘 3 は UIKit 標準の並べ替えでも同じ見え方のため)。このため「直した後」の観測は無い

## 指摘 1: 自動スクロール中に隙間が動きすぎる

公式の根拠: UICollectionView.h の `reorderingCadence` は「reorder-capable な置き先の上をドラッグしているときに、並べ替えがどれだけ起きやすいか」(既定は immediate)。

| # | OS | 構成 | 手順 | 隙間が動いた回数 (自動スクロール中) |
|---|---|---|---|---|
| 1-1 | 18.6 | 本体 (immediate) | Item 3 を持ち上げ、下端の帯 (画面の下端から 45pt) へ運んで 5 秒止める | 12 回 (約 0.37 秒ごと、1 行ごと。持ち上げてから帯へ運ぶ間にさらに 8 回) |
| 1-2 | 18.6 | 本体 (fast) | 同上 | 13 回 (帯へ運ぶ間は 1 回だけ) |
| 1-3 | 18.6 | 本体 (slow) | 同上 | 13 回 (帯へ運ぶ間は 1 回だけ) |
| 1-4 | 18.6 | UIKit 標準 (immediate) | 同上 | 77 回 (約 0.05〜0.07 秒ごと、1 行ごと) |
| 1-5 | 18.6 | UIKit 標準 (slow) | 同上 | **0 回** (自動スクロールの間は隙間が元の位置のまま) |
| 1-6 | 26.5 | 本体 immediate / slow | 同上 | 持ち上げから離すまでの合計 21 回 / 13 回 (slow で減るのは帯へ運ぶ間の分) |
| 1-7 | 26.5 | UIKit 標準 immediate / slow | 同上 | 持ち上げから離すまでの合計 79 回 / **0 回** |

- 本体の置き方 (置いたときに `performDropWith` で受ける形。データソースに移動の処理 (`collectionView(_:moveItemAt:to:)`) が無い) では、`reorderingCadence` は指を動かしている間の隙間の動きを減らすだけで、自動スクロール中に 1 行ごと隙間が動くのは変わらない
- UIKit 標準の並べ替え (データソースが移動の処理を持つ = reorder-capable) では、slow にすると自動スクロール中は隙間が動かない。ヘッダの「reorder-capable な置き先」の条件と合う
- 触覚が隙間の動きごとに鳴っているかは Simulator では確かめられない (隙間の動く回数・間隔で比べた)。基準機での確認に回す

## 指摘 2: 置いた後の収まりが遅い

| # | OS | 構成 | 指を離してから | 数値 |
|---|---|---|---|---|
| 2-1 | 18.6 | 本体 (受け入れ) | 持ち上げた項目は置いた位置で影を付けたまま止まり、約 0.9 秒後に一度に消えて一覧のセルに替わる (`ios-6.3-fix-drop-accepted-before-18.png` の 14.00〜14.90 秒。14.03 秒が指を離したコマ) | `performDropWith` → 置く動きの完了 0.98 秒 (2 回とも)。差分の適用 (animatingDifferences) は 0.36 秒で終わる |
| 2-2 | 18.6 | UIKit 標準 | 影が約 0.25〜0.35 秒で薄れて収まる (`ios-6.3-fix-drop-uikit-standard-18.png` の 11.15〜11.40 秒) | `hasActiveDrop` は約 1.2 秒真のまま (見た目は先に収まる) |
| 2-3 | 18.6 | 本体 (受け入れない) | 元の位置へ戻る | `performDropWith` → 戻る動きの完了 1.24 秒 |
| 2-4 | 18.6 | 本体、差分をアニメーションなしで当てる試行 | 当てた瞬間に周りの行が一度上へずれて戻り、持ち上げた項目は同じく約 0.9 秒止まる | 置く動きの完了 0.98 秒 (変わらない) |
| 2-5 | 18.6 | 本体、`coordinator.drop(_:to: UIDragPreviewTarget)` でセルの中心へ置く試行 | 一覧のセルが見えたまま動き、持ち上げた項目と 2 つ見える。持ち上げた項目は約 0.8 秒止まる | — |
| 2-6 | 18.6 | UIKit 標準で、置いた後に元の並びを当て直す (受け入れない場合の試し) | 並べ替えの知らせの中で当てると落ちる。次の周回へ回すと 0.32 秒で元の位置へ動いて戻る | — |
| 2-7 | 26.5 | 本体 / UIKit 標準 | 2-1・2-2 と同じ傾向 | 置く動きの完了 0.99 秒 / `hasActiveDrop` 約 1.2 秒 |

- 遅さを決めているのは、`performDropWith` の中で `coordinator.drop` を呼ぶ置き方そのもの (UIKit の置く動き。どこへ置いても約 0.9〜1 秒持ち上げたまま) で、差分の当て方 (2-4) や置き先の渡し方 (2-5) では変わらない
- UIKit 標準の並べ替え (データソースの移動の処理で確定し、`performDropWith` は呼ばれない) の収まりは約 0.3 秒

## 指摘 3: 一覧の外 (バーの上) でプレビューが小さくなる

| # | 構成 | 手順 | 観測 |
|---|---|---|---|
| 3-1 | 本体 | Item 5 を持ち上げ、画面の上端から 30pt (バーの上) へ運んで 2 秒止める | 一覧の外へ出ると小さい横長の板になる (`ios-6.3-fix-notch-preview-before-18.png` の 12.65 秒以降)。オーナーの静止画と同じ |
| 3-2 | UIKit 標準 | 同上 | 同じく小さくなる (`ios-6.3-fix-notch-preview-uikit-standard-18.png` の 11.10 秒以降) |
| 3-3 | 本体 + `UIDragItem.previewProvider` (持ち上げたセルの写し) | 同上 | バーの上では同じく小さい。持ち上げの途中に小さい板が一瞬出る崩れが増える (`ios-6.3-fix-notch-preview-provider-trial-18.png` の 11.40 秒) |
| 3-4 | 本体 + ウィンドウにドロップの受け口 (`UIDropProposal.prefersFullSizePreview = true`、`.forbidden`) | 同上 | 受け口に提案は届く (ログの win-update) が、同じく小さい (`ios-6.3-fix-notch-preview-window-drop-trial-18.png`) |

- 公式の根拠: UIDragItem.h の `previewProvider` はプレビューの中身の差し替えで、大きさの指定は無い。UIDropInteraction.h の `prefersFullSizePreview` は「この提案の間、縮めずに元の大きさで見せたい」という置き先の側の希望。UIDragInteraction.h の `dragInteraction(_:prefersFullSizePreviewsForSession:)` はドラッグの側の希望だが、一覧のドラッグの受け口の delegate は UIKit が持っていて差し替えられない (UICollectionViewDragDelegate に相当するメソッドは無い)
- UIKit 標準の並べ替えでも同じ見え方で、試した公開の手段では一覧の外で大きさを保てなかった (観測の範囲)

## 結論

- 指摘 1・2 は、並べ替えを UIKit の reorder-capable な形 (データソースの移動の処理で確定する) に組み替え、`reorderingCadence` を slow にすると UIKit 標準の並べ替えと同じ動きになる見込み。ただし受け入れの判定 (置いたときの処理) を UIKit が並びを確定した後に呼ぶことになり、design Decision 3 (置いたときに知らせを求め、受け入れたら置き、受け入れなければ置かずに戻す) と組み替えの範囲 (隙間の予測・行き先の読み替え・受け入れない場合の戻り方) に及ぶため、判断を仰ぐ
- 指摘 3 は UIKit 標準の並べ替えでも同じ見え方
