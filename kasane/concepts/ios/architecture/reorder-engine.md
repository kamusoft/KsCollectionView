---
type: concept
title: iOS 並べ替えの実現
description: 並べ替えの契約を iOS のコレクションエンジンの上で、UIKit 標準の並べ替え (差分データソースの並べ替えハンドラ + ドラッグ & ドロップの delegate) として実現する部品の責務境界と、隙間の予測・確定位置のずれ・戻し方・置く絵の影・上端の自動スクロール・読み上げの部品で避けている罠
tags: [ios, engine, reorder, drag-and-drop, accessibility]
timestamp: 2026-10-01
---

# iOS 並べ替えの実現

この文書を読むと、[並べ替え](../../core/core-model/collection-reorder.md) の契約を iOS 側がどの部品で実現し、UIKit のドラッグ & ドロップのどの挙動を避けているかが分かる。契約の文書と、一覧全体の仕組みを書いた [iOS コレクションエンジン](collection-engine.md) (内部の塊・塊の表・固定の見出し) を先に読むと分かりやすい。Android の対応物は [Android 並べ替えの実現](../../android/architecture/reorder-wrapper.md)。

## 全体像

```
KsCollectionView (SwiftUI)
  │  .reorder(...) の設定を KsReorder として構成 (KsCollectionConfiguration) に載せる
  └ KsCollectionViewController (+Reorder.swift の extension が KsReorderInteractionOwner)
       ├ KsReorderDragDropDelegate … UIKit の drag / drop delegate。呼び出しを controller へ渡す
       ├ dataSource.reorderingHandlers … 差分データソースの並べ替えハンドラ。UIKit が並びを確定したら呼ばれる
       ├ KsReorderDrag            … ドラッグ 1 回分の状態 (隙間・取りやめ・結果の適用待ち)
       │    └ KsReorderGapTracker … UIKit が次に隙間を空ける位置の予測
       ├ KsReorderPlanner         … 配列の並びとグループの区切りから行き先を求める (UI を知らない)
       ├ KsReorderTopAutoScroll   … 上端の自動スクロールの計算 (KsDisplayLinkTarget がフレームを渡す)
       ├ KsCompositionalLayout    … UIKit が動かした隙間の位置を受け取り、戻る動きの間のセルを隠す
       └ KsHostingCell            … KsReorderAccessibilityModel を持ち、中身に読み上げの操作を付ける
```

隙間の位置・持ち上げの見た目・置く動き・下端の自動スクロールは UIKit に任せる (ios/ADR-0011)。UIKit との受け渡しでエンジン (用語節) がすることは 3 つである。UIKit の位置 (セクションとその中の番号) を項目の行き先に読み替えること、置けない場所を UIKit に返すこと、UIKit が並びを確定した後に置いたときの処理 (`onMove`) を呼んで、受け入れたかの戻り値に従って結果を表示に適用することである。

指を離すまでの UIKit の呼び出しと、エンジンの処理は次のとおり。

| UIKit の呼び出し | エンジンの処理 |
|---|---|
| `itemsForBeginning` (長押しで持ち上げ) | 並べ替えのスイッチ・ドラッグ中でないこと・`canMove` を確かめる。項目の識別子を `localObject` に、一覧の目印 (`KsReorderDragContext`) を `localContext` に付け、持ち上げた時点の構成を記録する |
| `dragSessionWillBegin` (指を動かし始めた) | `KsReorderDrag` を作ってドラッグ中に入る。持ち上げた時点の構成と今の構成を比べ、違えば取りやめる。上端の自動スクロールのフレームを回し始める |
| `dropSessionDidUpdate` (ドラッグ中に何度も) | 指の位置を記録し、予測の隙間で置けるかを判定して提案を返す |
| レイアウトの `invalidationContext(forInteractivelyMovingItems:…)` (UIKit が隙間を動かすたび) | 動いた先の位置を記録する (`shownGap`。この文書では「見せていた隙間」と呼ぶ) |

指を離した後は、UIKit が並びを動かしたかどうかで経路が分かれる。主な経路は並べ替えハンドラで、`performDropWith` が呼ばれるのは UIKit が並びを動かさなかったときだけである。「ドラッグ中」(配列の保留などを続ける間) の終わりも経路で違う。

| 経路 | UIKit の呼び出しの順 | ドラッグ中の終わり |
|---|---|---|
| 指を離した時点で、隙間が元の位置と違う位置にあった → UIKit が並びを確定する | `didReorder` → `dragSessionDidEnd` (置いてから 0.03〜0.08 秒) → `dropSessionDidEnd` (0.93〜0.99 秒) | 結果の snapshot を適用し終え、かつ `dragSessionDidEnd` が届いた時点。`onMove` が受け入れを返し、揃え (下記「行き先は見せていた隙間から求め…」) が要らなければ、次の実行機会に適用して終わる。受け入れない・揃えが要るときは、`dropSessionDidEnd` の後に適用して終わる |
| UIKit が並びを動かさなかった (元の位置・取りやめ・隙間が動く前に指を離した) | `performDropWith` の後に 2 つのセッションの終わりが届く (元の位置へ戻る動きのときは `dropSessionDidEnd` が先) | `dragSessionDidEnd` |
| 置けない提案 (`.forbidden`) を返した状態で指を離した・一覧の外で指を離した | `didReorder` も `performDropWith` も呼ばれない。UIKit がドラッグを取り消して項目を元の位置へ戻し、`dropSessionDidEnd` → `dragSessionDidEnd` が届く | `dragSessionDidEnd` |

ドラッグ中が終わると (`endReorderDrag`)、保留した構成を適用し、溜めたスクロール命令を実行し、次ページ要求を判定し直す。隙間が別の位置へ動いた後に置けない場所の上で離した場合に、1 行目と 3 行目のどちらになるかは確かめていない。どの経路でも置く直前に `canDrop` を判定し直すので、置けない行き先で `onMove` は呼ばない。

## 責務境界

| 部品 | 責務 |
|---|---|
| `KsReorderDragDropDelegate` | 型引数を持つ controller は Objective-C の delegate に直接なれないため、呼び出しを `KsReorderInteractionOwner` へ渡す。並べ替えに共通の決まり (1 項目ずつ・アプリの外へ持ち出させない・置く絵の影) だけを自分で持つ |
| `KsCollectionViewController` (`+Reorder.swift`) | 持ち上げの可否、提案の返し方、移動の内容の組み立てと `onMove` の呼び出し、受け入れた並びの適用と戻し、ドラッグ中に届いた構成の保留、読み上げの操作の付け直し |
| `KsReorderPlanner` / `KsReorderPlacement` / `KsReorderTarget` | `KsReorderPlanner` は「あるグループの中の、動かした項目を除いた何番目」から行き先を求める。元の位置の行き先、1 つ前 / 1 つ後ろの行き先、置いた後の並びも求める。行き先の内部の形が `KsReorderPlacement` で、`KsReorderTarget` (この識別子の項目の前 / 末尾) と行き先のグループの番号の組 |
| `KsReorderGapTracker` | 提案を受けたときに UIKit が次に隙間を空ける位置 (予測の隙間) を求める (下記) |
| `KsReorderDrag` | 持ち上げた項目・`KsReorderGapTracker` (予測の隙間を持つ)・見せていた隙間・元の位置の中心・取りやめたか・結果の適用を待っているか・ドロップのセッションの終わりまで待たせる処理 |
| `KsGroupChunkTable.movingItem(fromSection:toSection:)` | 項目 1 つを別の塊へ移した後の塊の表。塊を区切り直さず、件数と範囲だけを変える |
| `KsCompositionalLayout` | UIKit が隙間を動かした位置の受け取りと、見せない項目 (`hiddenItemIndexPath`) の属性の書き換え |
| `KsReorderTopAutoScroll` / `KsDisplayLinkTarget` | 上端の自動スクロールで 1 フレームに進める量の計算と、`CADisplayLink` の受け手 (controller を強く持たせない) |
| `KsHostingCell` / `KsReorderAccessibilityModel` / `KsReorderAccessibilityModifier` | セルが持つ読み上げの操作の一覧と、それをセルの中身 (SwiftUI) に付ける修飾 |

## 保証すること (実測で確かめた罠対策)

### 一覧を UIKit が並びを動かす形にし、隙間は指を止めてから動かす (ios/ADR-0011)

差分データソースの `reorderingHandlers` (`canReorderItem` / `didReorder`) を設定すると、一覧は、UIKit が自分で並びを動かして項目を置く形 (reorder-capable) になる。置いた位置への移動と置く動きは UIKit が行い、エンジンは `didReorder` で確定を知る。隙間が動く速さは `reorderingCadence = .slow` にし、指を止めてから隙間が動くようにする。

並べ替えハンドラを使わずに、いつも `performDropWith` の中で `onMove` を呼んで項目を置く作りは採らない。その作りでは `reorderingCadence` が効かず、自動スクロールの間も隙間が動き続けて触覚が鳴り続けた。slow にした後は、下端のすぐ近くに指を 5 秒止めたときの隙間の動きが 69〜81 回から 0〜2 回になった。端から遠くスクロールが遅い所では、UIKit 標準と同じく 1 行スクロールするごとに動く。

`canReorderItem` は並べ替えのスイッチだけを見る。動かせるかは持ち上げ (`itemsForBeginning`) で判定済みのためである。

### 置けるかは予測の隙間で判定する (`KsReorderGapTracker`)

`dropSessionDidUpdate` に渡る位置は、隙間の位置そのものではない。指の下のセルの「動かす前の配列での位置」で、指が隙間の上にあれば持ち上げた項目の元の位置、セルの無い所 (見出し・グループの間) では nil になる。この位置のまま `canDrop` を判定すると、見えている隙間と判定がずれ、置けない位置に隙間が空く。そこで提案を受けるたびに、UIKit が次に隙間を空ける位置 (予測の隙間) を求めて判定し、置けなければ `.forbidden` を返して隙間を動かさせない。

予測は、隙間が動く先の規則から求める。動く先の規則は、このライブラリの設定 (slow) でも同じである (Simulator で観測)。表の「セクション」は内部の塊のことで、同じグループの中でも塊が違えば別のセクションになる。

| 提案の位置 (指の下のセル) | 隙間が動く先 |
|---|---|
| 今の隙間と同じセクションのセル | そのセルと隙間を入れ替えた位置 (隙間が前にあればセルの後ろ、後ろにあればセルの前) |
| 別のセクションのセル | そのセルの前 |
| セルが無い (nil) | まだ隙間に反映されていない最後の提案の位置。無ければ動かない |
| 隙間そのもの (持ち上げた項目の元の位置が渡る) | 動かない。それまでの提案は捨てる |
| 置けないとして断った提案 | UIKit がその位置を覚えていて、次に置ける提案を受けたときに、指が止まっていてもそこへ隙間を動かす |

予測は最後の行の持ち越しも含めて求める。持ち越した位置が置けない間は、どの提案にも置けないと返し続けるので、置けない位置に隙間は空かない。

動く時機は設定で違う。既定の設定では指が動くたびに隙間が動き、slow では提案の位置へ、指を止めてから動く。どちらでも判定は提案を受けたときに行う。予測の隙間と見せていた隙間の位置は、「持ち上げた項目を元の位置から抜いた並び」での番号で表す (`dropSessionDidUpdate` に渡る位置は、抜く前の並びでの番号)。

UIKit が実際に隙間を動かすと、レイアウトの `invalidationContext(forInteractivelyMovingItems:…)` が呼ばれる。レイアウトはその位置を controller へ渡し (`onInteractivelyMovingTargetChange`)、controller が見せていた隙間 (`shownGap`) と予測の隙間の両方を実際の位置に合わせる。予測が外れても、次の判定からは合う。

隙間の位置を差し替える公開の口は無い。delegate の `targetIndexPathForMoveOfItemFromOriginalIndexPath` もレイアウトの `targetIndexPath(forInteractivelyMovingItem:)` も、ドラッグ & ドロップの間は呼ばれなかった。グループの境目 (見出し・グループの間) で置く位置を指の位置から決めず、UIKit の隙間に従うのはこのためである。

### 行き先は見せていた隙間から求め、確定位置とのずれは後で揃える

セクション (塊) をまたいで後ろへ動かすと、差分データソースが確定する位置が、見せていた隙間より 1 つ後ろになる。位置を (セクションの番号, その中の番号) で書くと、見せていた隙間が (1,1) のとき確定は (1,2) だった (UIKit 標準の並べ替えでも同じ)。確定した位置をそのまま使うと、セルは隙間の位置にあるのにデータソースの並びが食い違い、置いた後の一覧で同じ項目が 2 つ並んで別の項目が 1 つ消える。次の処理で、置いた後の並びを正しくする。

| 処理 | 内容 |
|---|---|
| 行き先の求め方 | 見せていた隙間 (`shownGap`) を正にする。`didReorder` が渡す確定した位置は使わない |
| 揃え | ドロップのセッションが終わってから、差分データソースの並びを見せていた並びへ動きなしで適用し直す (`alignedReorderSnapshot`。食い違った項目は中身を作り直す) |
| 揃えるまでの間 | 位置から項目を引く処理 (タップ・読み上げの操作) は、UIKit が見せていた並びで引く (`shownItemIdentifier(at:)`) |

直したのは置いた後の並びである。指を離した直後の置く動きの間 (約 0.3 秒) に同じ項目が一瞬 2 つ見えるのは、UIKit 標準と同じ見え方で、直していない。

### 受け入れた並びは snapshot の中で項目だけを動かす (core/ADR-0027)

受け入れた直後は、動かした項目のグループの値 (グループの宣言が項目から取り出す値) がまだ古い。書き換えるのは VM で、書き換えた配列はまだ届いていないためである。同じグループの値は配列の中で続いていなければならず、離れて現れると不正入力になる (core/ADR-0015)。通常の `apply` はグループの値からグループを組むため、ここで通すとグループをまたいだ移動がその不正入力になる。そこで `applyAcceptedReorder` は、今の snapshot の中で項目だけを動かし、動かした項目を行き先のグループに属するものとして、次の表のものも合わせて作り直す。

| 作り直すもの | 理由 |
|---|---|
| 適用済みの並び (`appliedIdentifiers` / `appliedItems`) | ページングの判定・スクロール命令・表示位置の控えが配列の位置で引くため、VM の配列が届くまでの間もずらさない |
| 塊の表 (`appliedChunkTable`) | 塊を区切り直さず、抜いた塊と入れた塊の件数だけを変える。塊の識別子は変えず、残った塊を作り直させない |
| 項目が無くなったグループ | セクションと見出しをこの時点で取り除く。固定の見出しの位置の計算が、グループに最初と最後の項目があることを前提にしている |
| 見出しの中身 | 見出しのクロージャに渡すグループ内の項目を、グループの値からではなく、作り直した塊の表の範囲から引く |

受け入れてから VM の配列が届くまでは、次の順に進む。

| 段階 | 処理 |
|---|---|
| `onMove` を呼ぶ直前 | その時点までに届いていた最新の配列を取っておく (`reorderAwaitedItems`)。ドラッグ中に保留した構成があればその配列、無ければ今の配列 |
| 受け入れた直後 | 置いた並びを表示に適用する (上の表) |
| その後に `update(configuration:)` が届いた (ドラッグ中に届いた分は、保留した構成としてドラッグ中の終わりに同じ処理を通る) | 届いた配列が `reorderAwaitedItems` と同値なら (配列が同じまま、ほかの状態の変化で SwiftUI の更新が届いたとき)、配列だけは置いた並びのままにして、ほかの設定を適用する。違えば `reorderAwaitedItems` を捨て、通常の `apply` でグループと塊を組み直す |

`onMove` の中で VM が渡し直した配列は、取っておいた配列と並びが違うので、最後の行で通常の `apply` に入る。置いた並びでは塊の件数が基準からずれているため、この `apply` は塊の件数が変わる差し替えになり、アニメーションなしで適用される ([iOS コレクションエンジン](collection-engine.md))。VM が移動の内容のとおりに並べ替えていれば、並びは置いた並びと同じなので見た目は変わらない。

`didReorder` の中では snapshot を適用できないため、適用は次の実行機会以降にする。いつ適用するかは `KsReorderSnapshotTiming` (その場 / 次の実行機会 / ドロップのセッションの後) で選ぶ。適用し終わるまではドラッグ中の扱いを続ける (`KsReorderDrag.isResolving`)。

### 受け入れないときは、ドロップのセッションの終わりを待って戻す

UIKit は並びを確定してから `didReorder` を呼ぶので、受け入れないときは動いた並びを元へ戻す必要がある。UIKit は置いた項目の絵をドロップのセッションが終わるまで置いた位置に残し、動かした項目のセルを隠す。その前に並びを戻すと、項目が置いた位置に止まったまま、絵が消えた瞬間に元の位置に現れる。そこで `dropSessionDidEnd` まで待ってから元の並びを適用する。

置く動きが終わったことを受け取れる経路は、ほかに無かった。`dragSessionDidEnd` とセルの `dragStateDidChange` は置いてから 0.03〜0.08 秒で呼ばれて早すぎ、`hasActiveDrop` は KVO の変化の通知が来ず、`reorderingHandlers` には置く動きの完了を渡すものが無い。

帰結として、受け入れなかったドラッグでは、ドラッグ中の扱い (配列の保留・次ページ要求の判定の停止・スクロール命令の溜め置き) が戻し終えるまで最長で約 1 秒続き、その間は次の持ち上げを受けない。

受け入れたドラッグでは、ドラッグ中がドロップのセッションより先に終わる。前のドロップのセッションの終わりが次のドラッグの間に届きうるので、どのドラッグのセッションのものかを見分け、次のドラッグの状態には反映しない。

### UIKit が並びを動かさなかったときは `performDropWith` で後の処理をする

元の位置・取りやめたドラッグ・隙間が動く前に指を離したとき、UIKit は並びを動かさずに `performDropWith` を呼ぶ。

| 場合 | 処理 |
|---|---|
| 元の位置・取りやめ・置けない行き先・受け入れない | 持ち上げた項目の絵を、持ち上げたときに記録した元の位置の中心へ動かして戻す (`returnDraggedItemToSource`)。その間は元の位置のセルを隠す |
| 隙間が動く前に、置ける別の位置で離した | UIKit が渡す置く位置 (`destinationIndexPath`) から移動の内容を求めて `onMove` を呼ぶ。受け入れたら置いた並びを適用し、項目をそこへ置く |

戻すときに何もせずに返すと、UIKit は置いた場所で絵を縮めて消し、元の位置の項目と 2 つ同時に見える。セルを隠すのはセルではなくレイアウトの側 (`hiddenItemIndexPath` の属性を透明にする) で行う。セルの見え方は UIKit がレイアウトの属性で上書きするためである。

### 置く絵の影を空にする

行の中身に不透明な背景があると、置いた項目の影が薄れずに、ドロップのセッションの終わり (置いてから約 0.9 秒) まで残って一度に消えることがある。iOS 18.6 ではグループの宣言と読み上げの移動操作の修飾 (`KsReorderAccessibilityModifier`) の両方を付けた一覧で、26.5 では UIKit 標準の並べ替えでも同じ行で起きた。根本の原因は特定できていない。

`dropPreviewParametersForItemAt` で置く絵の影の形 (`shadowPath`) を空に、背景を透明にする。置く動きで、影付きの持ち上げた絵と影の無い置く絵が入れ替わる間に、影が約 0.3〜0.4 秒で途切れずに薄れる。持ち上げたときの絵は既定のまま変えない。この delegate のメソッドは、並べ替えハンドラで置くときにも呼ばれる (観測)。

### 取りやめは「隙間を空けない提案」と、持ち上げた時点の構成との比べ直しで行う

取りやめるのは、並べ替えのスイッチが無効になったときと、layout 値かグループの宣言が変わったときである (`cancelsReorderDrag`)。判定の時機は 2 つある。ドラッグ中に届いた構成を保留するとき (今の構成と比べる) と、指を動かし始めた時点 (下記) である。

UIKit には、進行中のドラッグのセッションを取り消す公開の手段が無い。`dragInteractionEnabled` を false にしても進行中のドラッグは続く。そこで取りやめた後は `KsReorderDrag.isCancelled` を立て、以後の提案を「隙間を空けない」(`.move` + `.unspecified`) にする。指を離すと `performDropWith` が呼ばれるので、元の位置へ動かして戻す。変わった構成と保留した配列は、ドラッグ中が終わってから適用する。

持ち上げ (`itemsForBeginning`) の時点では、そのときの構成を記録するだけにする (`reorderLiftConfiguration`)。持ち上げて動かさずに離したとき、UIKit は `dragSessionWillBegin` も `dragSessionDidEnd` も呼ばず、取り消しを伝える呼び出しが無い。持ち上げからドラッグ中の扱いを始めると、後始末が確実にできない。指を動かし始めた時点 (`dragSessionWillBegin`) で、記録した構成と今の構成を同じ条件で比べ、変わっていれば取りやめる。持ち上げてから指を動かし始めるまでに届いた構成は、保留されずにその場で適用されているためである。

### バーの裏まで広げた一覧では、上端の自動スクロールを自前で足す (`KsReorderTopAutoScroll`)

UIKit の上端の自動スクロールが反応する帯は、一覧の枠の上端の内側の余白 (`adjustedContentInset.top`) のすぐ下にある。一覧は `contentInsetAdjustmentBehavior = .never` で、ナビゲーションバーの裏まで広げた置き方 (core/ADR-0017) ではこの帯がバーの裏に入り、指を置けない。そこで上端の安全領域が 0 より大きいときだけ、安全領域の下端 (バーのすぐ下) から下へ自前の帯を取り、指がその中にある間 `CADisplayLink` で `setContentOffset` を進める。下端は UIKit 標準のままで足りる。

速さは、安全領域の下端から指までの距離 d (pt) だけで決まり、d が小さいほど速い。時間では加速しない。

| 項目 | iOS 26 以降 | それより前 |
|---|---|---|
| 帯の幅 (d がこれより小さい間だけ反応する) | 60pt | 50pt |
| 最大の速さ (d = 0) | 1100pt/秒 | 830pt/秒 |
| 速さの形 | `(1 − d / 60)` を 1.7 乗した値に、最大の速さを掛ける | `(1 − d / 65)` を 1.6 乗した値に、最大の速さを掛ける |
| スクロールを始めるまでの待ち | なし | 帯に入ってから 0.75 秒 |

値は、一覧を安全領域の内側に置いたときの UIKit 標準の上端の反応を、iOS 18.6・26.5 の Simulator で測って合わせたものである (iOS 16・17 は 18 と同じとみなす)。iOS 26 より前の式の 65 は、速さの落ち方を UIKit の実測に合わせるための長さで、帯の幅 (50pt) とは別に持つ。そのため iOS 26 より前は、帯の端 (d = 50) でも速さは 0 にならない。

| 規則 | 無いと起きること |
|---|---|
| UIKit の帯 (`adjustedContentInset.top` から帯の幅) に入る所では自前でスクロールしない。2 つの帯が重なるのは、上端の安全領域が帯の幅より短い置き方のとき | 両方がスクロールして速さが足し合わさる (26.5 で、枠の上端から 40pt の位置で 613pt/秒を観測。同じ位置で UIKit だけなら約 180) |
| 指の位置は提案のたびに記録し、指が一覧の外へ出た (`dropSessionDidExit`。バーの上へ移ったときなど)・ドロップのセッションが終わった・置いたときに捨てる | 指がバーの上へ移った後や、置いて戻る動きの間もスクロールし続ける |
| 先頭 (`-adjustedContentInset.top`) で止める | 先頭を行き過ぎて空白が見える |
| 待ちは、自前と UIKit のどちらの帯にも入っていないときだけ数え直す | UIKit の帯から自前の帯へ下へまたいだときに、待ちでスクロールが止まる |
| 1 回に進める時間は 0.1 秒まで | アプリが裏から戻った直後の飛んだフレームで大きく跳ぶ |

`contentInset` に安全領域の分を持たせる形は採らない。常に入れると固定の見出しの位置の計算が安全領域を二重に数え、ドラッグの間だけ足すと先頭で行き過ぎて、指を離したときに位置が飛ぶ。

### 読み上げの部品は文言を渡した構成にだけ付け、操作は中身を作る前に入れる (core/ADR-0032)

読み上げの焦点はセルの中の SwiftUI の要素に当たるため、操作はセル (UIKit の入れ物) ではなく中身に付ける (`KsReorderAccessibilityModifier` の `accessibilityActions`)。UIKit がドラッグ & ドロップに付ける標準の読み上げの操作はそのまま残り、並んで出る。

| 規則 | 理由 |
|---|---|
| 部品は、並べ替えを付けて文言を渡した構成にだけ付ける (`attachesReorderAccessibility`) | セルの中身 (`UIHostingConfiguration` が作る SwiftUI のビュー) は表示に入る項目ごとに組み立てられるため、全一覧に付けると並べ替えを使わない一覧にも費用がかかる |
| 並べ替えのスイッチでは付け外しせず、無効の間は操作を空にする | 付け外しは中身の型が変わり、切り替えのたびに表示中のセルのテンプレート (利用者が書いた項目の中身のクロージャ) を呼び直すことになる |
| 文言の有無が変わったら、全項目の中身を作り直す | 作ってあるセルの中身と部品の有無が食い違う |
| 操作は中身を作る前に `KsReorderAccessibilityModel` へ入れる | 後から入れると、操作の変化が通知されて、作ったばかりの中身がもう一度描き直される |
| 向きと名前が同じなら、操作の一覧を入れ替えない | 実行する処理は項目の識別子と向きだけで決まり、行き先は実行するときに求め直すため、入れ替えは描き直しを起こすだけになる |
| 「後ろへ」を先に付ける | SwiftUI は付けた順の逆に並べるため、「前へ」「後ろへ」の順に出すには逆に付ける |

操作を出すかは、並び・並べ替えのスイッチ・判定が変わりうる更新のたびに世代 (`reorderAccessibilityGeneration`) を進め、表示中のセルと表示に入るセルで求め直す。操作で動かした後は、`UIAccessibility.post(notification: .layoutChanged, …)` で焦点を動かした項目のセルに残す。

### 並べ替えのスイッチで、ドラッグと長押しの認識器を切り替える (core/ADR-0031)

drag / drop の delegate は常に付け、`syncReorderInteraction` が `update` のたびに切り替える。並べ替えのスイッチが有効の間は `dragInteractionEnabled` を立てて、`onItemLongTap` 用の長押しの認識器を止める。無効の間はドラッグを受け付けず、長押しの認識器を `onItemLongTap` の有無で決める。タップしたときに項目を強調するのは、`onItemTap` か `onItemLongTap` を宣言した一覧だけである (`handlesItemTouch`)。有効の間は `onItemLongTap` を宣言していないものとして扱う。

`installsStandardGestureForInteractiveMovement` は false にする。データソースが並べ替えに対応すると、`UICollectionViewController` (controller の基底クラス) は既定で対話的な移動の長押しを一覧に付け、並べ替えのスイッチが無効の間の `onItemLongTap` を奪うためである。

ドラッグの項目はアプリの外へ渡す中身を持たず (`NSItemProvider()` は空)、`dragSessionIsRestrictedToDraggingApplication` を真にして iPad でもアプリの外へ持ち出させない。同じアプリの別の一覧から来たセッションは、`localContext` の目印が自分のものでないので受けない。

### ドラッグ中に届いた構成は丸ごと保留する (core/ADR-0033・0034)

ドラッグ中 (`isReorderDragging`) に届いた `update(configuration:)` は適用せずに、最新の 1 つを保留する (`deferredConfiguration`。配列だけでなく layout 値などの設定も含む)。並べ替えの設定 (並べ替えのスイッチ・判定・`onMove`) だけは、ドラッグの続きに使うためすぐ入れ替える。次ページ要求の判定 (`evaluatePaging`) はドラッグ中は行わず、スクロール命令は `pendingCommands` に溜めたままにする。

## 分かっている限界

| 限界 | 内容 |
|---|---|
| iOS 16・17 (配布先の下限) で確かめていない | 隙間の予測の規則・確定位置のずれ・`dropSessionDidEnd` の時刻・上端の帯の値は、iOS 18.6・26.5 の Simulator の観測から組んだ。規則が外れると置けない位置に一時的に隙間が空きうるが、置いたときに判定し直すため、置けない行き先で `onMove` は呼ばれない |
| 一覧の外で絵が小さくなる | 指が一覧の外 (バーの上など) へ出ると、持ち上げた項目の絵が UIKit の既定の小さい板に切り替わる。`UIDragItem.previewProvider` と `UIDropProposal.prefersFullSizePreview` では大きさを保てなかった |
| 上端の安全領域が UIKit の帯より短い置き方 (ナビゲーションバーが無く、ステータスバーだけの画面など) | UIKit の帯のすぐ下でスクロールの速さが上がる (UIKit の帯の下の端では UIKit の速さがほぼ 0 で、そのすぐ下から自前の帯の速い所が始まるため)。iOS 26 より前は、指が自前の帯から UIKit の帯へ上向きにまたぐと、UIKit 自身の待ちでスクロールが約 0.75 秒止まる |
| 下端の自動スクロールの自動テストが無い | UIKit 標準に任せた部分で、Simulator での観測と基準機 (性能と見え方の合否を下す実機。iPhone 11) の目視で確かめた |
| 読み上げは実機で未確認 | Simulator で読み上げの要素とその操作の一覧を取り出して見る所までしか確かめていない。実機の VoiceOver での聞こえ方・動かした後の焦点・標準のドラッグの操作と並ぶ紛らわしさは未確認である |

## してはいけないこと

- 置けるかを、`dropSessionDidUpdate` に渡された位置のままで判定しない。見えている隙間とずれ、置けない位置に隙間が空く。
- 受け入れた並びを、通常の `apply` (グループの値から組む) で適用しない。グループの値が古い間は、同じグループの値が離れて現れる不正入力になる。
- 受け入れないときの戻しを、`didReorder` の直後や固定の待ち時間で行わない。置いた項目の絵が残っている間に並びが戻る。
- `performDropWith` で、置かないときに何もせずに返さない。持ち上げた項目が置いた場所で縮んで消え、元の位置の項目と 2 つ見える。
- 上端でスクロールさせるために、一覧の `contentInset` へ安全領域の分を足さない (常時でも、ドラッグの間だけでも)。固定の見出しがずれるか、先頭で行き過ぎる。
- UIKit の帯と重なる所で、自前のスクロールを足さない。速さが足し合わさる。
- 読み上げの部品を全一覧に付けたり、並べ替えのスイッチで付け外ししたりしない。スクロールの費用が増えるか、切り替えのたびにテンプレートを呼び直す。
- 持ち上げ (`itemsForBeginning`) の時点で、配列の保留などドラッグ中の扱いを始めない。動かさずに離したときの後始末の呼び出しが無い。
- `installsStandardGestureForInteractiveMovement` を既定に戻さない。`onItemLongTap` が呼ばれなくなる。

## 性能

「並べ替え」画面 (10,000 件・100 件ずつのグループ・見出しの固定・list、並べ替えのスイッチは有効) は、基準機 iPhone 11 (iOS 18.7.8、Release) の手動フリックで体感合格だった (2026-09-30、[証跡](../../../changes/archive/2026-10-01-drag-reorder/evidence/perf-ios-reorder.md))。数値は体感と食い違い、操作中の hitch time ratio は 175〜329 ms/s だった。この数値は、読み上げの部品の付け方の修正と、並べ替えハンドラを使う形への組み替えより前のビルドのもので、測り直していない (どちらもフリックの負荷を増やさない変更のため)。切り分けでは、数値の大半は表示に入る項目ごとにセルの中身を作り直す既存の作りによるもので、並べ替えに由来しない (`kasane/changes/ios-hosting-content-reuse` で扱う)。判定規則は [スクロール性能の体感ゲート](../../../handbook/cross/scroll-performance-gate.md)。

並べ替えに由来する費用は、読み上げの操作の組み立てである。並べ替えのスイッチが有効で文言を渡した一覧では、Simulator の診断用の自動スクロールで主スレッドの CPU 時間が約 5〜8% 増える ([証跡](../../../changes/archive/2026-10-01-drag-reorder/evidence/perf-diag-ios-reorder-cells.md))。並べ替えを付けない一覧・文言を渡さない一覧・並べ替えのスイッチが無効の一覧には上乗せが無い。支援技術が無効の間は操作を組み立てない形 (SwiftUI の `accessibilityEnabled`) は、どの支援技術で真になるかが定まっておらず、VoiceOver 以外で操作が消えるおそれがあるため採っていない。

## 用語

| 用語 | 意味 |
|---|---|
| 並べ替えのスイッチ | 並べ替えを受け付けるかの真偽値 (`.reorder(isEnabled:)` の `isEnabled`)。構成の `isReorderEnabled` で読む |
| エンジン | `KsCollectionViewController` と、その周りの internal の部品の全体 |
| 置いたときの処理 (`onMove`) / 移動の内容 / 受け入れ | 指を離したときに呼ぶ利用者の処理と、それに渡す `KsReorderMove` (動かした項目・行き先・行き先のグループの値)。処理は並べ替えを受け入れたかを真偽値で返す |
| 判定 (`canMove` / `canDrop`) / 読み上げの文言 | 利用者が任意で渡す「動かせるか」「ここに置けるか」の判定と、読み上げの移動操作の名前にする文字列 (`accessibilityActions`) |
| グループの宣言 / グループの値 | `.groups(by:)` の宣言と、それが項目から取り出す値。同じ値が続く範囲が 1 つのグループになる |
| 行き先 | 置いた位置を項目で表した値 (この項目の前 / 末尾)。内部では `KsReorderPlacement`、公開の型は `KsReorderDestination` |
| 構成 | 一覧に渡された設定一式 (`KsCollectionConfiguration`。配列・layout 値・グループの宣言・並べ替えの設定など)。SwiftUI の更新のたびに `update(configuration:)` で届く |
| layout 値 | list / グリッド・列数・間隔を表す公開の値 ([レイアウト語彙](../../core/styling/collection-layout.md)) |
| reorder-capable | データソースが並べ替えハンドラを持ち、UIKit が自分で並びを動かして項目を置く一覧の形。`reorderingCadence` はこの形でだけ効く |
| 隙間 | ドラッグ中に UIKit が置く先に空ける空き ([並べ替え](../../core/core-model/collection-reorder.md) の用語「置く先の空き」の iOS での形)。行き先は隙間の位置から求める |
| 予測の隙間 / 見せていた隙間 | 提案を受けたときに次に空くと予測した位置 (`KsReorderGapTracker` が持つ) / UIKit が実際に隙間を動かした最後の位置 (`shownGap`)。指を離した時点から見て「見せていた」と呼ぶ |
| 提案 | `dropSessionDidUpdate` で返す `UICollectionViewDropProposal`。置けるなら隙間を空けさせ、置けなければ禁止、取りやめた後は隙間を空けない形にする |
| 保留する | ドラッグ中に届いた構成を適用せず、最新の 1 つを持っておくこと。持ち上げた時点の構成の記録 (取りやめの判定用) とは別 |
| 揃え | 差分データソースが確定した並びを、UIKit が見せていた並びへ動きなしで適用し直すこと |
| 置く絵 | 指を離した後、置いた位置へ動いて収まる項目の絵 (drop preview)。持ち上げたときの絵とは別に指定する |
| 帯 | 端での自動スクロールが反応する、端からの一定の幅の範囲 |
| 塊 (内部セクション) / 塊の表 | 配列をグループごとに固定件数へ区切って載せた差分データソースのセクションと、その区切りの表 `KsGroupChunkTable` ([iOS コレクションエンジン](collection-engine.md) の用語) |
| 表示位置の控え | 行の並びが変わる更新の前後で位置を保つために、エンジンが記録する項目とオフセット ([iOS コレクションエンジン](collection-engine.md) の用語) |
| 次の実行機会 | 今の処理を抜けた後にメインキューで実行される処理 ([iOS コレクションエンジン](collection-engine.md) の用語) |

## 関連

- [並べ替え](../../core/core-model/collection-reorder.md) — 実現している契約と、Android との動きの差
- [iOS コレクションエンジン](collection-engine.md) — 内部の塊・塊の表・固定の見出し・スクロール命令のキュー
- [iOS ページングと Pull to Refresh の実現](paging-engine.md) — ドラッグ中に止める次ページ要求の判定
- [Android 並べ替えの実現](../../android/architecture/reorder-wrapper.md) — 同じ契約の Android 側の実現
- ios/ADR-0011 (UIKit 標準の並べ替えで作る)、ios/ADR-0009・0010 (内部の塊)
- core/ADR-0026〜0034 (並べ替えの契約)、core/ADR-0015 (グループの宣言)、core/ADR-0017 (安全領域)、cross/ADR-0006 (性能の完了判定)
- 出典: kasane/changes/archive/2026-10-01-drag-reorder/ (deviation.md、evidence/ios-6.3-rework.md、evidence/ios-precheck-uikit-drag-and-drop.md)
