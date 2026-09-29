---
type: concept
title: iOS ページングと Pull to Refresh の実現
description: ページングと Pull to Refresh の契約を iOS のコレクションエンジンの上で実現する部品 (KsPagingRequester・重ねる表示の入れ物・KsRefreshControl) の責務境界と、実測で確かめた罠対策
tags: [ios, engine, paging, pull-to-refresh]
timestamp: 2026-09-29
---

# iOS ページングと Pull to Refresh の実現

この文書を読むと、[ページングと Pull to Refresh](../../core/core-model/collection-paging.md) の契約を iOS 側がどの部品で実現し、UIKit のどの挙動を避けているかが分かる。契約の文書と、一覧全体の仕組みを書いた [iOS コレクションエンジン](collection-engine.md) (内部の塊・補助ビュー・端への挿入) を先に読むと分かりやすい。

## 全体像

```
KsCollectionView (SwiftUI)
  │  .paging(...) の設定と、@Environment(\.refresh) で読んだ .refreshable の処理を構成に載せる
  └ KsCollectionViewController
       ├ KsPagingRequester        … 次ページ要求の判定と待ち方 (判定の材料は controller が集めて渡す)
       ├ KsPagingFooterStack      … ルートのフッターの枠に載せる中身 (失敗・終端の表示 + 利用者のフッター)
       ├ KsPagingIndicatorView    … 次のページの読み込み中を表示範囲の下端に重ねる入れ物
       ├ KsPagingPlaceholderView  … 0 件のときの表示を表示範囲の真ん中に重ねる入れ物
       └ KsRefreshControl         … UIRefreshControl の派生。描く位置を上端の安全領域の分だけ下げる
```

ページングの表示のために項目でないセルやセクションは足さない。塊 (内部セクション) の番号から列数・余白・見出しを引く箇所が多く、そこに手当てが要るためである (下記「表示は 3 つの置き場に分ける」)。

## 責務境界

| 部品 | 責務 |
|---|---|
| `KsPagingRequester` | 発火の式・しきい値の検査・待ち方の控え・再試行・取り消しを、UI から切り離して持つ。件数と画面に出ている項目は controller が渡す |
| `KsCollectionViewController` | 判定の材料集め (`visiblePagingItems()`)、配列の版の更新、6 つの表示の出し分け、差し替えで先頭を表示する判定、`refreshControl` の付け外しと取り直しの間の余白 |
| `KsPagingFooterStack` | ページングを付けた一覧のフッターの枠の中身。失敗・終端の表示を上、利用者のフッターを下に、左右の `contentPadding` の内側で縦に並べ、下の `contentPadding` をその下に置く |
| `KsPagingIndicatorView` / `KsPagingPlaceholderView` | 次のページの読み込み中 / 0 件の表示を載せる入れ物。`frameLayoutGuide` に固定し、`zPosition` 1000 でセルと補助ビューより手前に描く。自分自身に当たったタッチは下の一覧へ通す。上下の `safeAreaInsets` を中身のホスティングへ渡さない (置く位置は入れ物の側で安全領域を含めて決めるため、渡すと中身がさらに押し上げ / 押し下げられる) |
| `KsRefreshControl` | 引っ張りの部品を描く位置 (`bounds.origin.y`) を、表示範囲の上端 + 上端の安全領域まで下げる (下記) |

## 保証すること (実測で確かめた罠対策)

### 判定は表示範囲と交わるセルで数える (core/ADR-0020)

`visiblePagingItems()` は `indexPathsForVisibleItems` を、レイアウト属性の矩形が bounds (バーの裏を含む表示範囲の全体) と交わる項目に絞って数え、配列上の位置を塊の表 (`sectionItemRanges[section].lowerBound + indexPath.item`) から O(1) で引く。可視セルの一覧には表示範囲の外のセルが残りうるためで、表示位置の控え (用語節) で使う `leadingVisibleID()` と同じ絞り方である。UIKit の先読みの通知 (`prefetchItemsAt`) は範囲が UIKit の判断で決まり、画面に出ている項目の数も分からないため契機にしない。

判定するのは `scrollViewDidScroll`・差分の適用の完了・`update(configuration:)`・`viewDidLayoutSubviews`・`viewDidAppear` と、次ページ要求の処理が終わったときである。`scrollViewDidScroll` の時点の可視セルは新しい位置のレイアウトより前のものなので、レイアウトの確定後にも判定する。差分の適用中と画面に載る前 (`window` が無い) は判定しない。

配列の版は `update` で配列を同値比較して進める。状態と版は判定しない間も毎回 `KsPagingRequester` に知らせる。知らせないと、その間の状態の往復 (待機 → 追加読み込み中 → 待機) を見逃して待ち方の控えが残り、次を頼まなくなる。

### 表示は 3 つの置き場に分ける (core/ADR-0024)

| 表示 | 置き方 | そうする理由 |
|---|---|---|
| 次のページの失敗 / 終端 | ルートのフッターの枠 (レイアウト全体の boundary supplementary) の中に `KsPagingFooterStack` で置く。ページングを付けた一覧では、利用者のフッターが無くても枠を常に置く | 専用のセクションやセルを足すと、sectionProvider の列数の控え・区切り線・ハイライト・位置の控え・`KsItemOffsetLookup` (画面の indexPath を配列全体の通し番号へ変換する計測の入口) など、セクション番号から引く箇所すべてに手当てが要る |
| 次のページの読み込み中 | `KsPagingIndicatorView` を一覧の子として置き、下端から「下端の安全領域 + 8pt」に合わせる。出入りは 0.2 秒のフェード | 一覧 (`UICollectionView`) の子なので、差し替えた表示の範囲から始めたドラッグもそのまま一覧のパンになる |
| 0 件の 3 つ | `KsPagingPlaceholderView` を同じく一覧の子として置き、上下の `safeAreaInsets` を除いた範囲の真ん中に合わせる | `backgroundView` はルートのヘッダー / フッター (補助ビュー) の背面になり、重なると再試行を押せない |

次のページの読み込み中の入れ物は、差し替えていない既定の表示では中身へのタッチも下へ通し、差し替えた表示では中身の範囲だけタッチを受ける。入れ物の中身は、別の表示に切り替わったときに作り直す。ホスティングの中身の差し替えは次の描画まで大きさに反映されず、前の中身の大きさのまま描かれて切れるためである。

状態だけが変わってフッターの枠に出す表示が変わったとき (配列は同じ) は、枠を名指しで測り直させる。補助ビューは中身が変わっても自分では測り直されないためで、仕組みは [iOS コレクションエンジン](collection-engine.md) の「補助ビューは名指しで測り直させる」にある。

### 取り直しの結果を先頭から表示する経路 (core/ADR-0021)

差し替えの直前に、どの端に表示範囲を留めるかは controller の `edgeToKeep` が決める ([iOS コレクションエンジン](collection-engine.md) の「端を表示中の端への挿入」)。ページングを付けた一覧では、`edgeToKeep` が差し替えの直前の状態を読み、取り直し中なら位置によらず先頭を返し、終端以外なら末尾を返さない。先頭を表示する経路は差し替えの種類で 4 つに分かれる。

| 差し替えの種類 | 経路 |
|---|---|
| アニメーションする差分 | `edgeToKeep` が先頭を返し、端への挿入と同じく `KsCompositionalLayout` が差分のアニメーションの中で位置を留める |
| 塊の件数が変わる差分 (エンジンはこの差分をアニメーションを切って適用する) | 差分の適用の中では位置を動かせないため、適用の完了の直後に `scrollToContentTopAfterReplacement` で先頭へ置く。控えていた位置は戻さない |
| 配列が同値で差分を適用しない更新 (VM が始めた取り直し) | 状態が取り直し中から抜ける回を、結果が届いた回とみなして先頭を表示する。取り直し中のままの描き直しでは動かさない |
| 配列が同値で差分を適用しない更新 (Pull to Refresh) | 同値の更新は描き直しと見分けられないため、インジケータを出し終えるとき (`finishPullRefresh`) に先頭を表示する |

Pull to Refresh の間は、`edgeToKeep` が直前の状態によらず先頭を返す。今回の取り直しで先頭を表示したかを `pullRefreshShowedContentTop` に控え、出し終えるときに二重に動かさない。配列を中身で比べるため「取り直しが失敗して配列がそのまま」も最後の行の経路に入り、取り直しの間に下へスクロールしていても先頭へ戻る (Android との差として受け入れた。[collection-paging](../../core/core-model/collection-paging.md))。

### UIRefreshControl を安全領域の分だけ下げる (core/ADR-0025)

一覧は `contentInsetAdjustmentBehavior = .never` のため、標準の `UIRefreshControl` をそのまま付けると、全画面の一覧ではインジケータがバーの裏に出る。安全領域の分の inset を常に入れる形は、行がバーの裏を流れる作り (core/ADR-0017) を Pull to Refresh の有無で変えてしまうため採らない。`KsRefreshControl` は部品の位置は UIKit に任せ、描く位置だけを `bounds.origin.y` で下げ、スクロールのたびに求め直す。

下げる量は「表示範囲の上端 + 上端の安全領域」までとし、部品の下端がコンテンツの先頭の空白 (上の `contentPadding`) の下端を越えない範囲に留める。部品を下げてよいのはその空白の中までで、それより下へ下げると先頭の中身に重なるためである。上の `contentPadding` に安全領域の分を入れた一覧では、引っ張り始めてバーの下に隙間が空けば部品がバーのすぐ下に見える。余白の無い一覧では、引っ張った量が安全領域に満たない間は部品がバーの裏に留まり、バーの下に空いた隙間に上から現れる。

取り直し中は、標準の部品が自分の高さの分だけ上端に余白を足してコンテンツを部品の下で止める。部品を安全領域の下に出すとその余白だけではコンテンツが部品に被るため、取り直しの間だけ「上端の安全領域 − 上の `contentPadding`」(正のときだけ) を `contentInset.top` に足し、終われば外す。この間、固定中のグループの見出しを置く位置 (controller の `pinnedGroupHeaderTopInset`) と、`KsCompositionalLayout` が見出しの属性を書き換えるときの上端 (`refreshExtraTopInset` で受け取る) からは足した分を差し引く。足した inset ですでに表示範囲の上端が下がっているため、差し引かないと見出しが二重に下がる。

余白を外しても表示範囲は元の位置に残る。標準の部品は、取り直しの間に利用者のスクロールや差し替えで先頭を表示する処理によって表示範囲が動いていると、自分の余白の分を戻さず、上端に空白が残る。そこで出し終えたとき、利用者がドラッグ中でなければ余白を外した先頭まで戻す。表示範囲がコンテンツの先頭より上 (引っ張って空いた余白の中) にあれば、余白を外す動きと一緒に 0.3 秒で動かし、下から先頭を表示するときはアニメーションせずに先頭へ置く (途中の行を組み立てながら流さないため)。

引っ張れなくする間 (追加読み込み中・次ページ要求の処理の実行中) は `collectionView.refreshControl` を外し、それ以外で付け直す。取り直しのインジケータを出している間は外さない。一覧は 0 件でも引っ張れるよう `alwaysBounceVertical` を常に立てている。

### 処理の寿命

次ページ要求と取り直しの処理は `Task { @MainActor in … }` で起動し、representable の dismantle から呼ばれる `disconnect()` で取り消す。取り消した処理が後から終わったときは `Task.isCancelled` で見分け、実行中の印を下ろさない。下ろすと、取り消しの後に始めた次の処理がまだ実行中なのに、終わったものとして扱ってしまう。

## 分かっている限界

- 差し替えた「次のページの読み込み中」の表示の範囲から始めたドラッグで一覧がスクロールすることは、試験では構造 (入れ物が一覧の子で、パンを妨げない) だけを確かめ、ドラッグを合成していない。

## してはいけないこと

- ページングの表示のために、項目でないセルやセクションを足さない。セクション番号から引く箇所すべてが崩れる (上記)。
- `indexPathsForVisibleItems` をそのまま「画面に出ている項目」として数えない。表示範囲の外のセルが残りうる。
- 0 件の表示を `backgroundView` に置かない。補助ビューの背面になり、重なると操作できない。
- インジケータを安全領域の下に出すために、一覧に安全領域の分の inset を常に入れない。行がバーの裏を流れる作りが変わる (core/ADR-0017)。

## 性能

「ページング」画面 (10,000 件・1 ページ 50 件・取得の遅延 200 ms、list) は、基準機 iPhone 11 (iOS 18.7.8、Release) で体感合格だった (2026-09-29)。High の hitch は 0、最長 16.68 ms で、体感と数値が食い違わなかった ([証跡](../../../changes/archive/2026-09-29-paging-state-machine/evidence/perf-ios-paging.md))。判定規則は [スクロール性能の体感ゲート](../../../handbook/cross/scroll-performance-gate.md)。

## 用語

| 用語 | 意味 |
|---|---|
| フッターの枠 | ルートのフッターを置く、レイアウト全体の下端の補助ビュー。ページングを付けた一覧では利用者のフッターが無くても置き、失敗・終端の表示を利用者のフッターの上に並べる ([collection-paging](../../core/core-model/collection-paging.md) の用語) |
| 配列の版 | ページングを付けた一覧で、配列の中身が変わるたびに 1 進む数。頼んだ後の待ち方を解く目印に使う |
| 待ち方の控え | 次ページ要求を頼んだ時点の状態と配列の版。どちらかが変わったのを見たら捨て、捨てるまで次を頼まない |
| 実行中の印 | 次ページ要求 / 取り直しの処理が終わっていないことを表す値 (`isRunning` など)。実行中は次を頼まず、引っ張りも受け付けない |
| 塊 (内部セクション) | 配列をグループごとに固定件数へ区切って載せた diffable のセクション ([iOS コレクションエンジン](collection-engine.md) の用語) |
| 表示位置の控え | 行の並びが変わる更新 (layout 値の変更・塊の組み直しなど) の前に、表示範囲の先頭にある項目と上端からのオフセットを控え、適用の後に同じ位置へ戻すエンジンの仕組み ([iOS コレクションエンジン](collection-engine.md) の「表示位置の控えと復元」)。取り直しで先頭を表示するときは、控えを捨てて戻さない |
| 重ねる表示の入れ物 | `KsPagingIndicatorView` / `KsPagingPlaceholderView`。一覧の表示範囲に固定され、スクロールしても動かない |

## 関連

- [ページングと Pull to Refresh](../../core/core-model/collection-paging.md) — 実現している契約
- [iOS コレクションエンジン](collection-engine.md) — 内部の塊・補助ビューの測り直し・端への挿入・表示位置の控え
- [Android ページングの実現](../../android/architecture/paging-wrapper.md) — 同じ契約の Android 側の実現
- core/ADR-0020 (発火の条件)、core/ADR-0021 (表示範囲の置き方)、core/ADR-0022 (待ち方)、core/ADR-0023 (Pull to Refresh)、core/ADR-0024 (6 つの表示)、core/ADR-0025 (重ねる表示と安全領域)
- core/ADR-0017 (安全領域)、ios/ADR-0009・0010 (内部の塊)、cross/ADR-0006 (性能の完了判定)
