# Design: paging-state-machine

## Context

ページングの公開契約の外形は core/ADR-0005 (利用者の VM が 5 状態を持ち、DSL に状態と次ページ要求を渡す。ライブラリは発火・多重発火の抑止・標準の表示・Pull to Refresh の接続を担う) で決まっており、phase-5 の議論で細部が core/ADR-0019〜0024 (proposed) に確定した。本 design はそれを両プラットフォームの実装方式に落とす。Android の Paging 3 には依存せず、状態機械は自前で持つ (phase-5 agenda の決定。ADR-0005 が却下した「ライブラリがページング全体を内包する」案の理由が今も成り立つため)。

今のコードの前提 (提案時の調査で確認):

- iOS は `KsCollectionView` (SwiftUI の View) が `KsCollectionConfiguration` を組み、`KsCollectionRepresentable` が `KsCollectionViewController` (`UICollectionViewController`) の `update(configuration:)` を毎回呼ぶ。`update` は毎回 `apply` を呼び、配列が同値なら snapshot を当てずに見えているセルの作り直しだけで戻る (ios/Sources/KsCollectionView/KsCollectionViewController.swift の `apply` 冒頭)。ルートのヘッダー / フッターはレイアウト全体の boundary supplementary で、中身は毎回の update で見えているものにかけ直している。SwiftUI の環境値を一覧が読む前例は無く、`scrollViewDidScroll` も受けていない。`contentInsetAdjustmentBehavior = .never` で、行はバーの裏を流れる (core/ADR-0017)
- iOS の snapshot は「グループ × 内部の塊」のセクションで組まれ (ios/ADR-0009・0010)、セクションの番号から列数・余白・見出しを引く箇所 (sectionProvider の `makeSection`・区切り線・ハイライト・位置の控え・`KsItemOffsetLookup`) が多い。項目でないセルを足すと、これらの前提が崩れる
- Android は `KsCollectionView` の引数で設定を受け、`LazyVerticalGrid` に「ルートのヘッダー → (見出し → 項目) × グループ → ルートのフッター」の順で並べる。lazy の index と項目の添字の対応は `KsGroupPlan` が持ち、画像の先読みは `snapshotFlow` で表示中の項目の範囲を観測している (KsImagePrefetchWindow.kt の `visibleItemRange`)。端への挿入は `KsPositionKeeper` が配列の参照が変わった回に判定する
- 端への挿入の判定は、iOS は `edgeToKeep(previous:next:)` と `KsCompositionalLayout.finalizeCollectionViewUpdates`、Android は `KsPositionKeeper.keepEdge` の 1 か所ずつ。iOS は塊の件数が変わる差し替えでアニメーションを切り、そのときは端を留めない

## Goals / Non-Goals

**Goals:** core/ADR-0019〜0024 の決定を、両プラットフォームで同じ観察可能な振る舞いとして実装する。既存の添字の対応 (iOS のセクション・Android の lazy index) を壊さずに表示を足す。ページングを付けない一覧の振る舞いを変えない。

**Non-Goals:** proposal.md の Non-Goals のとおり。加えて、スクロール命令「末尾へ」の指す先が両プラットフォームで違う既存の差 (iOS は最後の項目の下端、Android は最後の lazy 要素 = ルートのフッター) は本変更で変えない (ページングの表示をフッターの枠に置くため、Android の「末尾へ」はページングの表示を含めた末尾へ送る。差の性質は変わらない)。

## Decisions

### Decision 1: 公開 API の形

**採用案:** 語彙は両プラットフォームで 1 対 1 に揃え、記法は各流儀とする (core/ADR-0002)。

| 語彙 | Swift | Kotlin |
|---|---|---|
| 状態 | `public enum KsPagingState: Hashable, Sendable { case idle, refreshing, appending, failed, endReached }` | `public enum class KsPagingState { Idle, Refreshing, Appending, Failed, EndReached }` |
| ページングの設定 | `.paging(_ state: KsPagingState, threshold: Double = 1, onLoadMore: @escaping @MainActor () async -> Void)` | `KsCollectionView(..., paging: KsPaging? = null)` / `public class KsPaging(state: KsPagingState, onLoadMore: suspend () -> Unit, threshold: Float = 1f, ...)` |
| 次のページの読み込み中 | `.pagingAppendingFooter { }` | `KsPaging(appendingFooter = { })` |
| 次のページの失敗 | `.pagingFailedFooter { retry in }` | `KsPaging(failedFooter = { retry -> })` |
| 終端 | `.pagingEndReachedFooter { }` | `KsPaging(endReachedFooter = { })` |
| 最初の読み込み中 (0 件) | `.pagingLoadingPlaceholder { }` | `KsPaging(loadingPlaceholder = { })` |
| 失敗 (0 件) | `.pagingFailedPlaceholder { retry in }` | `KsPaging(failedPlaceholder = { retry -> })` |
| 空 (0 件で終端) | `.pagingEmptyPlaceholder { }` | `KsPaging(emptyPlaceholder = { })` |
| Pull to Refresh | SwiftUI 標準の `.refreshable { await }` を一覧に付ける (ライブラリの modifier は無い) | `KsCollectionView(..., onRefresh: (suspend () -> Unit)? = null)` |

- 6 つの表示は、指定しなければ既定 (2 つの読み込み中は各プラットフォームの標準の読み込み中の表示、残りの 4 つは何も出さない)。読み込み中の既定を消したいときは空の View / Composable を渡す
- 表示の modifier は `.paging` の前後どちらに付けてもよい (設定の値をコピーして書き換える既存の modifier と同じ形)。`.paging` を付けていない一覧では何の効果もない
- 再試行の操作 `retry` は Swift が `@escaping @MainActor () -> Void`、Kotlin が `() -> Unit`
- Kotlin の `KsPaging` は `KsGroups` と同じく普通の public class (data class にしない。`@Stable` は付けない)
- `onRefresh` は phase-3 で決めた外形のとおり `KsCollectionView` の引数に置き、ページングを付けない一覧でも使える。iOS は `.refreshable` を付けた View の環境値 (`EnvironmentValues.refresh`) を `KsCollectionView` が読む

**理由:** 6 つの表示と差し替え口を 1 対 1 にする決定 (core/ADR-0024) を、今の DSL の `.header { }` / `header =` と同じ書き方で実現する。Swift は modifier の名前に `paging` を前置してページングの設定だと分かるようにし、Kotlin はページングの設定をまとめた `KsPaging` の引数にする (グループの `KsGroups` と同じ置き方)。`onRefresh` をページングの外に置くのは、Pull to Refresh がページングなしでも成り立つ機能で、iOS の `.refreshable` も一覧の外から付くため。

**代替案:**
- **A: 表示の名前を場所で付ける (いちばん下 = footer / 0 件 = placeholder) のではなく、状態だけで付ける (`appending` / `failed` / `endReached` + 0 件用に別名)** — 0 件の 3 つが状態の名前と 1 対 1 にならず (0 件で追加読み込み中 = 最初の読み込み中)、6 つの表示の絵と対応しない
- **B: Kotlin も modifier の形 (`Modifier.ksPaging(...)`) にする** — Compose の Modifier は見た目・レイアウトの装飾に使い、挙動の設定は名前付き引数が慣習 (core/ADR-0005 の決定)

### Decision 2: 項目があるときの表示の置き場 — ルートのフッターの枠に同居させる

**採用案:** 「次のページの読み込み中 / 失敗 / 終端」の表示は、ルートのフッターの枠 (iOS はレイアウト全体の下端の補助ビュー、Android は `KsRootSlotKey.Footer` の全幅の項目) の中に置く。枠の中は、ページングの表示を上、利用者のフッターを下に縦に並べる。ページングを付けた一覧では、利用者のフッターが無くてもフッターの枠を常に置き、ページングの表示が何も無い状態では高さを持たない。状態だけが変わったとき (配列は同値) は、見えているフッターの中身をかけ直し、高さの変化をレイアウトに測り直させる。項目が 0 件のときは、枠のページングの部分には何も出さない (0 件の表示は Decision 3)。

**理由:** 最後の項目の後ろ・ルートのフッターの前という位置 (ADR-0024 の「いちばん下の項目のすぐ下」) を、既存の添字の対応に触れずに作れる。iOS のセクション・項目の ID と Android の lazy index の数え方は、フッターの枠の有無の違いとしてすでに扱われている。状態だけが変わったときに中身をかけ直す経路 (ルートのフッターの中身を毎回の update でかけ直す) も既にある。端への挿入 (core/ADR-0018) の「末尾 = ルートのフッターの下端」も、ページングの表示を含めた末尾としてそのまま成り立つ。

**代替案:**
- **A: 専用の最後のセクション (iOS) / 専用の lazy 要素 (Android) を足し、表示をセル / 項目として置く** — iOS は sectionProvider が項目でないセクションでも列数の控え (`resolvedColumnCount`) を上書きして塊の件数と回転時の位置の復元を狂わせ、区切り線・タッチ時の色・ハイライト・位置の控え・`KsItemOffsetLookup` の全件の数え方・`positionsChanged` と `edgeToKeep` の比較 (番兵が末尾に来る) に手当てが要る。Android は `KsGroupPlan` の全件数・行数・contentType の推定・プランの等価と remember のキー・`KsRootSlotKey` の Parcelable の 2 値決め打ちを直す必要がある
- **B: iOS で最後のセクションの補助ビューとして置く** — 添字の対応には触れないが、項目が増えると補助ビューが付く塊が移り (差分の適用の中で別のセクションへ移る)、塊の組み直しでも付け直される。Android に対応物が無く、両プラットフォームの作りが揃わない
- **C: iOS でレイアウト全体の下端の補助ビューをもう 1 つ足す** — 同じ位置に揃えた 2 つの補助ビューの並び順が保証されるか確かめられていない

### Decision 3: 項目が 0 件のときの表示の置き場 — 一覧の見えている範囲の真ん中に重ねる

**採用案:** 「最初の読み込み中 / 失敗 / 空」の表示は、項目の代わりに一覧の見えている範囲の真ん中に 1 つ重ねる。真ん中は、上下の安全領域 (iOS は一覧の `safeAreaInsets`、Android はシステムバーとの重なり) を除いた範囲で求める。両プラットフォームとも一覧の前面 (ルートのヘッダー / フッターより手前) に重ね、0 件の表示の外へのタッチは下 (一覧) へ通す。iOS は一覧の上に重ねたホスティングの入れ物に置き (`backgroundView` はヘッダー / フッターの背面になるため使わない)、入れ物は表示の外のタッチを受けない。Android は一覧を包む `BoxWithConstraints` の中でグリッドの前面に中央揃えで重ねる。ルートのヘッダー / フッターは 0 件でも従来どおり表示し、0 件の表示はそれを避けないが、重なったら 0 件の表示が手前になる。0 件の表示の中のボタン (再試行) は押せ、0 件でも Pull to Refresh で引っ張れる。

**理由:** 0 件のときは項目のセル / lazy 要素が無く、表示を項目の流れの中に置く理由が無い。背景 / 前面に重ねれば添字の対応に触れない。安全領域を除くのは、行をバーの裏に流す全画面の一覧 (core/ADR-0017) で真ん中がバーの分だけ上にずれないようにするため。ADR-0017 は安全領域を使う箇所を固定中の見出しに絞っていたため、提案の自己レビューで衝突を検出してオーナーに諮り、core/ADR-0025 (proposed、amends ADR-0017) で安全領域に合わせる箇所に足した。

**代替案:**
- **A: ルートのヘッダーとフッターの間の、残りの高さの真ん中に置く** — ヘッダーとの重なりは避けられるが、iOS は残りの高さをレイアウトに求めさせる仕組みが要り、Android の `LazyGridItemScope` には親の高さいっぱいに広げる修飾が無い。ヘッダーの高い一覧は少なく、重なったときは 0 件の表示を手前にして操作を保つ
- **B: iOS は `collectionView.backgroundView` に置く** — 一覧の背景として自然に広がるが、ルートのヘッダー / フッター (補助ビュー) の背面になり、重なると再試行を押せない。Android (前面) と重なり方も揃わない (相方の提案レビューの指摘)

### Decision 4: 発火の判定の実装

**採用案:** 判定の材料は「画面に出ている項目の数」「その中でいちばん後ろの項目の配列上の位置」「配列の件数」「状態」「しきい値」の 5 つで、次の式が真なら頼む。

- 項目が 0 件で状態が待機なら頼む (初回の読み込み。しきい値によらない)
- 項目が 1 件以上あるのに画面に出ている項目が 1 つも無いなら頼まない (ルートのヘッダーだけで表示範囲が埋まっている等。項目が画面に出てから判定する)
- それ以外は、状態が待機で、`件数 − 1 − いちばん後ろの位置 ≦ ceil(しきい値 × 画面に出ている項目の数)` なら頼む

判定の式と待ち方 (Decision 5) は、両プラットフォームとも UI から切り離した内部の型 (`KsPagingRequester`) に置き、単体で試験する。材料の取り方は各プラットフォームで取る。

- iOS: 画面に出ているセルは `indexPathsForVisibleItems` を表示範囲 (一覧の bounds) と交わるものに絞り (既存の `leadingVisibleID` と同じ絞り方)、配列上の位置は `appliedChunkTable.sectionItemRanges[section].lowerBound + indexPath.item` で求める。判定するのは `scrollViewDidScroll` (新たに override する)、差分の適用の完了時、`update(configuration:)` で状態・しきい値が変わったとき、`viewDidLayoutSubviews` で大きさが変わったとき。ページングを付けていなければ何もしない
- Android: `snapshotFlow` で `layoutInfo.visibleItemsInfo` を `KsGroupPlan.itemIndexOfLazy` で項目の添字に変え (見出し・ルートのヘッダー / フッターは -1 で除く。画像の先読みと同じ取り方)、いちばん後ろの位置と数を観測する。状態・配列・しきい値の変化と合わせて判定する。ページングを付けていなければ観測しない
- 「画面に出ている」は一覧の表示範囲と少しでも交わる項目で、バーの裏に流れている項目も含む (両プラットフォームとも表示範囲の全体で数える)

**理由:** core/ADR-0020 の式をそのまま両プラットフォームの同じ材料で計算する。判定を内部の型に置くのは、スクロール・状態・配列の組み合わせを実機のスクロールなしに試験するため。iOS の配列上の位置は塊の表から O(1) で引ける。

**代替案:**
- **A: iOS も UIKit の先読みの通知 (`prefetchItemsAt`) を契機にする** — 通知の範囲が UIKit の判断で決まり、画面に出ている項目の数も分からず、ADR-0020 の式を計算できない
- **B: 判定を各プラットフォームの UI の中に直接書く** — 組み合わせの試験に実レイアウトとスクロールが要り、両プラットフォームで式がずれても気づきにくい

### Decision 5: 頼む処理の実行と待ち方

**採用案:** `KsPagingRequester` が次ページ要求の処理を実行し、待ち方 (core/ADR-0022) を持つ。

- 頼むときに、そのときの状態と「配列の版」(配列の中身が変わるたびに進む数) を控え、処理を起動する。iOS は `Task { @MainActor in await onLoadMore() }`、Android は一覧の composition に結びついた `CoroutineScope` で `launch { onLoadMore() }`
- 次に頼めるのは、処理が終わり、かつ控えた状態か配列の版が変わったとき。配列の中身の比較は、iOS は同値比較 (`Equatable`)、Android は参照が変わった回だけ中身を比べる
- 再試行の操作は、状態が失敗のときに次ページ要求を呼ぶ (状態が待機でなくても呼ぶ)。処理が実行中なら何もしない。項目が空かどうかと Pull to Refresh の有無によらない (core/ADR-0019)
- 一覧が破棄されたら (iOS は `KsCollectionRepresentable` の dismantle から呼ばれる `disconnect()`、Android は composition を離れたとき) 実行中の処理を取り消す。別の画面へ進んでも一覧が破棄されずに残る間 (iOS の `NavigationStack` で次の画面を積んだとき等) は取り消さない。一覧が残るかはナビゲーションの仕組みしだいで、両プラットフォームで同じとは限らない (Android の Navigation Compose は前の画面の composition を離れる)

**理由:** ADR-0022 の「処理が終わるまで、かつ状態か配列が変わるまで」を 1 か所で持つ。一覧が破棄されたときの取り消しは、ライブラリが一覧の表示の中で処理を実行する帰結 (ADR-0022 の Consequences)。「画面から見えなくなったら」まで広げると、表示・非表示の観測が両プラットフォームで別の仕組みになり、戻ってきたときに読み込みが途切れる (相方の提案レビューの指摘で契約を破棄に狭めた)。

**代替案:**
- **A: iOS の処理をアプリ全体の Task (`Task.detached` 等) で実行し、画面を離れても続ける** — 利用者が処理の中で待つ書き方をしたとき、閉じた画面の読み込みが止まらず、VM が生きていれば状態が書き換わり続ける。続けたい読み込みは VM のスコープで起動すれば足りる (ADR-0022)

### Decision 6: 表示範囲の置き方 (core/ADR-0021 の実装)

**採用案:** 差し替えのたびに「直前の状態」(前回の設定の反映時のページングの状態) を控え、端への挿入の判定の前に分岐する。

- 直前の状態が取り直し中なら、差し替えと同時に表示範囲をコンテンツの先頭 (ルートのヘッダーの上端) にする。iOS は `edgeToKeep` に先頭を返させ、塊の件数が変わってアニメーションを切る差し替えでは、適用の直後に先頭へ位置を合わせる。Android は `keepEdge` の先頭で `requestScrollToItem(0)` を要求する
- 直前の状態が終端以外なら、末尾への挿入でも末尾に留めない (iOS は `edgeToKeep` が末尾を返さない、Android は末尾への追従を要求しない)。各プラットフォームの既定の位置の保ち方にする
- 直前の状態が終端なら、既存の判定 (core/ADR-0018) のまま
- ページングを付けない一覧は、既存の判定のまま
- iOS は `KsCollectionViewController` が前回の状態を控え、Android は `KsPositionKeeper` が前回の配列と同じく前回の状態を控える (onUpdate の冒頭で取り出して上書きする)

**理由:** ADR-0021 の「差し替えの直前の状態で決める」を、既存の判定の 1 か所に足す。取り直しの先頭は、塊の件数が変わる差し替え (10,000 件の一覧を 1 ページ目に戻す等) でも効く必要があるため、アニメーションを切る経路にも入れる。

**代替案:**
- **A: 状態の変化 (取り直し中 → 待機) を見た回に先頭へ送る** — 状態と配列が別の回に届く書き方で、配列の差し替えより前に送ってしまう。ADR-0021 は差し替えの直前の状態で決めると決めている

### Decision 7: Pull to Refresh の接続

**採用案:**

- iOS: `KsCollectionView` が `@Environment(\.refresh)` を読み、設定に載せる。処理があれば `UIRefreshControl` を一覧に付け、引っ張られたら `Task { await refresh() }` を実行する。一覧は 0 件でも引っ張れるよう縦方向の弾みを常に許す (`alwaysBounceVertical`)
- Android: 一覧を `Modifier.pullToRefresh(isRefreshing, state, enabled, onRefresh)` を付けた Box で包み、`PullToRefreshDefaults.Indicator` を上端に重ねる (`PullToRefreshBox` には引っ張りを止める設定が無いため。core/ADR-0023)。material3 1.4.0 のこの API が実験的なら、ライブラリの内部で opt-in する
- インジケータ (両プラットフォーム): 引っ張ってから処理が終わるまで出し、処理が終わった後は状態が取り直し中の間だけ出し続ける。処理が終わった時点で状態が取り直し中でなければ消す。引っ張っていないのに状態が取り直し中になっても出さない (ADR-0023)
- 追加読み込みの間は引っ張れない: 状態が追加読み込み中の間と、`KsPagingRequester` が次ページ要求の処理を実行中の間。iOS はこの間 `refreshControl` を外し (取り直し中のインジケータを出していないときだけ)、それ以外で付け直す。Android は `enabled = !(状態 == 追加読み込み中 || 処理の実行中)`。処理から戻った後に状態を書き換える VM の隙間と、VM が自分で始める取り直しとの競合は VM が扱う (core/ADR-0023 の負の帰結。phase-7 のガイドに申し送る)
- インジケータの位置: 全画面の一覧 (core/ADR-0017) でインジケータがバーやステータスバーの裏に隠れないよう、上端の安全領域の分だけ下げる (core/ADR-0025、amends ADR-0017)。iOS は `contentInsetAdjustmentBehavior = .never` のため `UIRefreshControl` がバーの裏に出うる。下げる手段 (引っ張りの部品の位置の調整) は実装の最初に Simulator で確かめ、行をバーの裏に流す作りを保ったまま下げられなければ、作業を止めてオーナーに諮る。Android は一覧の上端とシステムバーの重なり (`KsTopSafeArea` と同じ値) の分だけインジケータを下げる

**理由:** 両プラットフォームとも標準の引っ張りの部品とインジケータを使い、Pull to Refresh の自然な形 (引っ張ったときだけ出る) に従う (ADR-0023)。iOS は SwiftUI 標準の `.refreshable` をそのまま使えるようにし、ライブラリ独自の modifier を足さない。

**代替案:**
- **A: iOS もライブラリ独自の `.onRefresh { }` modifier を用意する** — SwiftUI の利用者が一覧に付けるのは標準の `.refreshable` で、別名を覚えさせる理由が無い
- **B: iOS で Pull to Refresh があるときは上端に安全領域の分の inset を入れる** — 行がバーの裏を流れる作り (core/ADR-0017) が、Pull to Refresh の有無で変わってしまう

### Decision 8: 不正なしきい値

**採用案:** しきい値が負の数、または有限でない数 (NaN・無限大) なら不正入力として、既存の報告の仕組み (iOS `KsInvalidInput.report`、Android `KsDiagnostics`) で報告し、0 として扱う (core/ADR-0011: debug は assertion、release は表示を続けて警告ログ)。報告は値が変わった回に 1 度だけ行う。

**理由:** 議論で「提案時に決める」とした細部を、既存の不正入力の方針に合わせて決める。0 として扱えば、発火は「最後の項目が画面に入ったら」になり、読み込みが止まらない。

**代替案:**
- **A: 既定の 1 として扱う** — 利用者が小さい値を意図していた場合と大きい値を意図していた場合を区別できず、0 のほうが「頼まない」側に倒れず「遅めに頼む」側に倒れて読み込みが止まらない点は同じ。既定値に戻すと、不正な値を入れたことに release で気づきにくい (0 なら毎ページ読み込み中が見えて気づける)

### Decision 9: Sample「ページング」

**採用案:**

- ルートメニューの「差分更新」の次に「ページング」を両プラットフォーム同じ位置・同じ文言で追加する
- 偽の取得元: 全 10,000 件 (「Item 1」〜「Item 10000」、ID は整数)、1 ページ 50 件、取得の遅延は既定 1 秒で起動引数 (iOS `--paging-delay-ms`、Android は起動の Intent の追加値) で変えられる。「次の読み込みを失敗させる」がオンの間はすべての取得が失敗し (次の取得から効き、切り替えただけでは再読み込みしない)、「中身を 0 件にする」がオンの間は取り直しと最初の読み込みが 0 件・終端を返す (切り替えたらその場で再読み込みする)
- VM: iOS は `@Observable @MainActor final class`、Android は Compose の状態を持つ class を画面で remember する (「差分更新」の値型のモデルと違い非同期の処理を持つため)。次ページ要求は待機か失敗のときに受け付け (失敗からの再試行)、取り直しは項目があるときに失敗したら元の状態に戻して「更新できませんでした」を画面に出し、項目が空なら失敗の状態にする (ADR-0019 のガイドの実演)。取り直しを始めたら世代を進め、それより前の世代の読み込みの結果は捨てる (追加読み込み中の再読み込みで古いページが混ざらないようにする。ADR-0023 の負の帰結の実演)
- 操作: list / 2 列グリッドの切り替え、「次の読み込みを失敗させる」「中身を 0 件にする」の 2 つの切り替え、VM が始める「再読み込み」(引っ張らない取り直し。取り直し中でも項目は並んだまま)、Pull to Refresh。「中身を 0 件にする」を変えたら、その場で再読み込みする (「次の読み込みを失敗させる」は再読み込みしない。失敗の表示を出したまま切り替えをオフにして「再試行」を試せるようにするため)。操作は背景が透けるパネルにまとめて一覧の上に浮かせ、左端の丸いボタンに畳める (オーナーの指示。一覧の上下の様子が操作に遮られないため)。一覧の下の余白にパネルの高さの分を入れ、末尾の表示がパネルの裏に隠れないようにする
- 表示の設定: 失敗 (いちばん下 / 0 件) は「読み込めませんでした」と「再試行」、終端は「これ以上ありません」、空は「項目がありません」。読み込み中は既定のまま
- 操作と表示の置き場・見た目は承認 mock に従う (ui/brief.md)

**理由:** ADR-0019〜0024 の決定を 1 画面で目で確かめられるようにする。10,000 件は性能の体感ゲートの土俵の決まり (cross/ADR-0006)。遅延を変えられるのは、体感ゲートと UI テストで待ち時間を縮めるため。

**代替案:**
- **A: グループ化の切り替えも付ける** — ページの境目でグループが伸びる動きは「差分更新」画面で確かめられるため、agenda の決定で平らな一覧にした

### Decision 10: 検証

**採用案:**

- 自動テスト: デルタスペックの Scenario ごとに、iOS は SwiftPM のテスト (`KsPagingRequester` の単体と、`KsEdgeInsertionTests` と同じ形の実レイアウト上の結合テスト、`.refreshable` の受け取りは `KsSwiftUIIntegrationTests` の形)、Android は Robolectric + compose ui-test で書く。Sample は Android の単体テスト (メニューの一致・VM・偽の取得元) と iOS の UI テスト (起動引数で遅延を縮めて、最初の読み込み・追加読み込み・失敗と再試行・0 件)
- 読み上げ: 既定の読み込み中の表示が、各プラットフォームの読み込み中の要素として読み上げに出ること (iOS は UI テストで読み込み中の要素が見つかること、Android は semantics の不定の進捗) を自動テストで確かめる
- 性能: 「ページング」画面で、両プラットフォームの基準機の体感ゲート (handbook/cross/scroll-performance-gate.md) を 1 回行う。取得の遅延は 200 ms に縮めた構成で行い、構成を証跡に残す。Android の相対計測は行わない (ページングは既定機能ではない)
- UI: 承認 mock との視覚照合 (ksn-ui) を両プラットフォームで行う

**理由:** 挙動の組み合わせ (状態 × 配列 × スクロール) は自動テストで網羅し、見え方と滑らかさはオーナーの目で確かめる。遅延 1 秒のままの体感ゲートは、フリックのたびに読み込みを待って未訪問の範囲を十分に通れない。

**代替案:**
- **A: 性能の体感ゲートを行わない (ページングは付けた一覧だけで動くため)** — 追加読み込みの差し替えがスクロール中に走るのは新しい経路で、proposal のリスクに挙げた。1 回の体感で確かめる

## Risks / Trade-offs

- iOS の `UIRefreshControl` と `contentInsetAdjustmentBehavior = .never` の組み合わせで、インジケータを安全領域の下に出す手段が確かめられていない (Decision 7)。実装の最初に確かめ、無理なら止めて諮る
- iOS の `UIRefreshControl` が取り直し中に content inset を足すと、`adjustedContentInset.top` を使う箇所 (先頭の判定・先頭への位置合わせ・「先頭へ」の命令・固定中の見出しの位置など) の値が変わりうる。取り直し中の見出しの固定と先頭の判定を試験で確かめる
- フッターの枠の高さが状態だけで変わる (読み込み中の表示が出る / 消える)。iOS の自己サイズの補助ビューが測り直されるか、測り直しでスクロール位置が跳ねないかを試験と目視で確かめる
- 追加読み込みの差し替えがスクロール中に走る。iOS は 500 件の塊の境目を越える差し替えでアニメーションを切る (ios/ADR-0009・0010)。体感ゲートと目視で確かめる
- 状態と配列が別の回に届く VM の書き方では、表示範囲の置き方 (Decision 6) と待ち方 (Decision 5) が意図どおりにならない (ADR-0021・0022 の負の帰結)。Sample の VM は同じ回に書く
- 次ページ要求の処理から戻った後に状態を追加読み込み中にする VM では、戻ってから書き換えるまでの間に引っ張れ、その取り直しに古いページが混ざりうる。VM が自分で始める取り直しと読み込みの競合もライブラリは防がない (ADR-0023 の負の帰結)。Sample の VM は世代で古い結果を捨てる
- Android の Pull to Refresh の土台の修飾が material3 1.4.0 で実験的 API なら、将来の版で形が変わりうる

## Migration Plan

追加のみ。ページングを付けない一覧・Pull to Refresh を付けない一覧の振る舞いは変わらない。配布前のため互換の手当ては不要。

## Open Questions

- iOS の Pull to Refresh のインジケータを安全領域の下に出す手段 (Decision 7)。実装の最初に確かめる

## ADR 候補

新規の候補はなし。本変更の決定は phase-5 の議論で起票済みの core/ADR-0019〜0024 と、提案作成中に起票した core/ADR-0025 (Decision 3・7 の安全領域の扱い。ADR-0017 を一部置き換える) がいずれも proposed で持ち、実装の merge 後に ksn-distill が昇格させる。昇格時の作業: core/ADR-0021 の昇格で core/ADR-0018 に `amended-by: 0021`、core/ADR-0024 の昇格で core/ADR-0005 に `amended-by: 0024`、core/ADR-0025 の昇格で core/ADR-0017 に `amended-by: 0025` を追記し、index の旧 ADR の行に「一部改訂」を書く。core/ADR-0005 の footer に `関連: core/ADR-0019` を足す (phase-5 agenda の TODO)。Decision 2 (フッターの枠への同居) と Decision 3 (0 件の表示を重ねる) は実装の置き場の選択で、公開の契約や他の能力の境界を変えないため ADR にしない。

## 提案の自己レビューの記録

lessons/spec-review.md [L-001] に従い、新設・変更した契約ごとに、同じ契約を書いている他の成果物と、前提が変わる既存コードの経路を突き合わせた (2026-09-27)。既存コードの経路は、提案時の調査 (ksn-scout 2 回) の結果で確かめた。

| 契約 | 突き合わせた成果物 | 突き合わせた既存コードの経路 | 結果 |
|---|---|---|---|
| 発火の式・画面に出ている項目の数え方 (spec: 追加読み込みの発火) | core/ADR-0020、design Decision 4、tasks 2.x | iOS: `indexPathsForVisibleItems` に画面外のセルが残りうる点 (`leadingVisibleID` の絞り方)、配列上の位置は重複 ID を後勝ちで畳んだ後の並びであること (`KsSnapshotPlanner`)。Android: `visibleItemRange` が見出し・ヘッダー / フッターを -1 で除く点 | 一致。iOS は表示範囲と交わるセルに絞ると design に明記した |
| 初回の読み込み (spec) | core/ADR-0020、agenda の決定、tasks 2.1 | Android の `keepEdge` はどちらかの配列が空なら判定しない (0 件 → 取り直しは端の規則に入らない) | 一致。0 件の一覧は先頭にいるため、取り直しの先頭の規則と食い違わない |
| 待ち方・再試行 (spec) | core/ADR-0022・0019、design Decision 5、Sample の VM (Decision 9) | iOS の `update` は毎回 `apply` を呼び、同値の配列では早期 return する (配列の版を進める条件を同値比較にした) | 一致。DSL サンプルの VM が失敗から再試行を受け付けない点は Sample の VM (tasks 6.2) で直す |
| ページングの表示の置き場 (spec: ページングの表示) | core/ADR-0024・0019、design Decision 2・3、brief、mock 2 案 | iOS: 同値の配列で `apply` が早期 return するため、状態だけの変化はフッターの中身のかけ直しで反映する (ルートのフッターの既存の経路)。専用セクションを足した場合の `resolvedColumnCount` の上書き・区切り線・ハイライト・`KsItemOffsetLookup` を避けるためフッターの枠に同居させた。Android: `KsGroupPlan` の `hasFooter` とプランの等価・remember のキーにページングの有無を入れる。フッターの枠は `rows()` の行数に 1 行として数えられる (高さ 0 の枠でもインジケータの全体の行数が 1 増える) | 一致。インジケータの行数の差は tasks 3.5 の既存テストで確かめる |
| 端への挿入の例外・取り直しの先頭 (spec: collection-core) | core/ADR-0018・0021、design Decision 6、tasks 4.x | iOS: `edgeToKeep` は `animates` のときだけ渡る (塊の件数が変わる適用では端を留めない) ため、取り直しの先頭はアニメーションを切る経路にも入れた。`edgeToKeep` は新しい配列が空なら判定しない。Android: `onUpdate` は毎コンポジション呼ばれ、`keepEdge` は配列の参照が変わった回だけ判定する。前回の状態は毎回の `onUpdate` で控える | 一致。状態と配列が別の回に届く書き方の限界は ADR-0021 の負の帰結と design の Risks にある |
| Pull to Refresh (spec: 接続・インジケータ・引っ張れない) | core/ADR-0023・0025、phase-3 の外形、design Decision 7、brief | iOS: `contentInsetAdjustmentBehavior = .never` のため標準の引っ張りの部品がバーの裏に出うる → core/ADR-0017 と衝突 (安全領域を使う箇所を固定の上端に絞っていた) を検出し、オーナー判断で core/ADR-0025 を起票。取り直し中の inset の変化が `adjustedContentInset.top` を使う箇所に効きうる点は Risks と tasks 5.3 に置いた。Android: `topSafeArea.modifier` の測る位置が変わらない場所に Box を置く (tasks 5.2) | 衝突は ADR-0025 で解消。未確認点は tasks 0.1 で最初に確かめる |
| 0 件の表示の安全領域 (spec: ページングの表示) | core/ADR-0025・0017、design Decision 3、brief | iOS: `backgroundView` は bounds 全体 (バーの裏を含む) を覆い、ホスティングの安全領域の扱い (`KsHostingCell` の `safeAreaInsets` の上書き) と揃える必要がある | 一致 (ADR-0025 で決定)。実装で安全領域の値の求め方を揃える |
| 不正なしきい値 (spec) | core/ADR-0011、design Decision 8 | 既存の報告の仕組み (`KsInvalidInput.report` / `KsDiagnostics`) | 一致 |
| Sample「ページング」(spec: samples) | handbook/cross/sample-parity、cross/ADR-0006・0007、brief、mock 2 案 | 既存のメニューの定義 (`SampleScreen`) と起動引数の処理 (iOS `SampleLaunchView`、Android `SampleNavHost` の開始ルート) | 一致。体感ゲートの 10,000 件の決まりに合わせた。件数を変えて比べる Scenario は無い |

1 周目で直したもの: design の Context に「Paging 3 には依存しない」(agenda の決定) を書き足した。上位層の衝突 (core/ADR-0017) はオーナーに諮り、core/ADR-0025 を起票して design・proposal に反映した。2 周目で新たな問題は見つからなかった。

その後の相方の提案レビュー (second-opinion-spec-001.md) で、自己レビューが拾えなかった 5 件 (Sample の切り替えと再試行の手順の矛盾・引っ張りを止める条件の隙間・0 件の表示とヘッダーの重なり順・取り消しの契約の広さ・画面に項目が出ていないときの発火) を採用して反映した。いずれも、契約と既存コードの経路 (Sample の操作の順序・VM の状態の書き換えの時機・iOS の補助ビューと `backgroundView` の重なり順・`disconnect()` の呼ばれる時機・画面に出ている項目が 0 のときの式) の突き合わせの漏れだった。
