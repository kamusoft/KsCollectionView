# Design: prefetch-display-size

## Context

到達点 `memory` の先読みは URL だけの鍵で元寸をメモリに載せ、`KsImage` は「URL + 枠の実サイズ + 当てはめ方」の鍵で探す (iOS は `ImageRequest.thumbnail`、Android は自前の `coil#size` / `ks#scale` extras)。表示側はメモリの元寸を同期で縮小して初回描画に使うが、Android 実機では元寸がハードウェアビットマップで画素を読めず (`KsDownscaleResult.Unreadable`)、読み込み中を経由してディスクから再デコードする。先読みの台帳 (iOS `KsImagePrefetcher`、Android `KsImagePrefetchWindow`) は URL → 参照数のみで、呼び出し元にはレイアウト値・コンテナ幅・余白が揃っている (iOS `KsLayoutMetrics` + bounds、Android `BoxWithConstraints` + `resolveGridCells`)。

方針は core/ADR-0013 と core/ADR-0014 (どちらも proposed。本 proposal の承認で確定し、蒸留で accepted にする) のとおり: (1) 表示は鍵の完全一致をやめ、実物の寸法を許容範囲で引き当てる (2) 先読み宣言の要素に URL ごとの概算の幅 (列幅 / 固定値) を持たせる (3) 幅なしの要素は原寸のまま (4) 先読みの要素とリモートの画像ソースに任意キー `key` を持たせ、指定時は取得以外のすべてで URL の代わりに使う。本 design はそれを両プラットフォームの実装形に落とす。

鍵の基準は現状どこも URL: iOS は `url.absoluteString` で世代 (`KsImageIdentity`) を引き、世代 0 では `imageID` を付けない (ローダー付属ビューと同じ項目を指すため)。Android は `KsImageSource.cacheKey` (リモートは URL そのもの) をメモリの鍵の本体・`remove` の照合・ディスクの鍵 (Coil の既定 = データの文字列) に使う。

裏取り済みの外部挙動: Coil 3.5.0 の `MemoryCacheService.isCacheValueValidForSize` は `Precision.INEXACT` で「キャッシュ項目が要求以上なら有効 (縮小済みで要求より小さければ無効)」= 下限 1.0・上限なし。鍵に `coil#size` があるときは文字列の完全一致を求める。Nuke 13 の `ImagePipeline.cache` は要求 (鍵) 単位の subscript のみで、近似の引き当ても鍵の列挙も無い。Nuke の `ImageRequest.imageID` (設定可能) はメモリの鍵 (`MemoryCacheKey`) とディスクの鍵 (`makeDataCacheKey`) の両方の基になり、ネットワーク取得の統合 (`TaskFetchOriginalDataKey`) は設定値ではなく元の URL (`originalImageID`) で行う。Coil 3 は `ImageRequest.Builder.memoryCacheKey` / `diskCacheKey` で鍵を指定できる。

## Goals / Non-Goals

Goals:
- 到達点 `memory` を選んだコレクションで、要素の幅の有無に関わらず、両プラットフォームの実機で初回表示が読み込み中もデコードのやり直しも経由しない
- 幅を宣言した要素では元寸をメモリに載せない
- CPU で画素を読む同期縮小を廃止し、ハードウェアビットマップのままで成立させる
- 署名付き URL のように取得のたびに URL が変わる画像でも、利用者が `key` を指定すれば、先読みした項目とディスクに保存済みの項目を起動をまたいで使える

Non-Goals (proposal と同じ): 表示から学ぶ方式、到達点 `disk` の初回表示の速さ、ローダー付属ビューの直接使い、高さ・当てはめ方の宣言。

## Decisions

### Decision 1: 引き当ての規則 — 当てはめ方に必要な拡大率が許容範囲 [1/上限, 1/下限] の内側なら使う

**採用案:** `KsImage` は枠の実サイズ (px) と当てはめ方から、メモリ項目 (実物の幅・高さ px) を枠に当てはめるのに必要な拡大率 `s` を求める。`fill` は `max(枠幅/幅, 枠高/高)`、`fit` は `min(枠幅/幅, 枠高/高)`。`s ≤ 1/下限` (項目が小さすぎない) かつ `s ≥ 1/上限` (項目が大きすぎない) なら使う。初版の値は **下限 0.5、上限 4** (項目の寸法が必要寸法の 0.5〜4 倍)。値は internal の定数 1 か所に置き、実機の見た目で調整する (公開 API にしない)。

同じ識別子 (Decision 9) に範囲内の項目が複数あれば、`s` が 1 に最も近い (必要寸法に最も近い) 項目を選ぶ。

**理由:** 拡大率を当てはめ方で計算すれば、幅だけの宣言 (Decision 4) で困る唯一のケース (画像より縦長の枠に `fill`) も実物判定で弾ける。下限は拡大ぼやけ、上限は GPU 縮小のざらつきとテクスチャ上限 (端末依存、4096〜16384 px) の回避 (ADR-0013)。

**代替案:**
- **A: 幅だけで判定する (宣言と同じ軸)** — 却下。縦長の枠に `fill` する画像で高さが足りず拡大ぼやけになる
- **B: 下限だけ持つ (原寸は常にそのまま使う)** — 却下 (ADR-0013)。巨大な原寸の描画品質とテクスチャ上限
- **C: 許容範囲を公開 API にして利用者が調整する** — 却下。`KsImage` に縮小の個別引数を持たせない agenda 決定 (2026-09-05) と衝突し、値の意味を利用者に説明する負担に見合わない。実機で決めた定数で始め、必要になれば別 change

### Decision 2: 範囲内の項目があればローダーへ要求を出さず、その項目を表示の完了状態として描く

**採用案:** 引き当てに成功した `KsImage` は成功状態から始まり、ローダーの要求 (iOS `LazyImage`、Android `rememberAsyncImagePainter`) を作らない。項目への参照は表示中だけ保持し、ビューの破棄で手放す (LRU で追い出されても表示中は消えない)。引き当てに失敗したときだけ、従来どおり枠の実サイズの縮小要求をローダーへ出す (iOS `ThumbnailOptions`、Android `size + Precision.EXACT + coil#size` の鍵)。要求を出した時点でその鍵を索引 (Decision 3) に登録する。

**理由:** 範囲内の項目を初回描画に使いつつローダーへも要求を出すと、ローダー側の妥当性判定 (Coil は下限 1.0) が本 change の許容範囲と食い違い、範囲内でも再デコードが走る。要求を出さなければローダーの判定に依存しない。現行の「同期で引いた画像をローダーの状態が決まるまでの間だけ描く」二重構造も消える。

**代替案:**
- **A: 現行どおり要求も出し、ローダーの判定 (`Precision.INEXACT`) に寄せる** — 却下。Coil の下限が 1.0 で「概算は少し小さくてもよい」が成立せず、上限は判定されない。iOS にはそもそも近似判定が無い
- **B: 引き当てた項目を表示鍵へ書き戻す (現行の `cache[display] = …`)** — 却下。CPU で縮小しないので書き戻す価値がなく、同じ画像がサイズ違いの鍵で二重にメモリを占める

### Decision 3: ライブラリが識別子 (URL または `key`) ごとの鍵の索引を持ち、実在と寸法の正はローダーのキャッシュに置く

**採用案:** プロセス共有の internal な索引 `KsImageMemoryIndex` を両プラットフォームに置く。項目は「識別子 (Decision 9。`key` があれば `key`、無ければ URL。世代付き) → [鍵]」で、寸法は持たない。書くのは (a) 到達点 `memory` の先読み要求を出した時点と (b) `KsImage` が縮小要求を出した時点 (完了を待たない)。読むのは `KsImage` の引き当てで、候補の鍵をローダーのメモリキャッシュに問い合わせ、返った画像の実物の寸法で Decision 1 の判定を行う。キャッシュに無い鍵 (未完了・失敗・LRU で追い出し済み) はその時点の候補にならない。追い出し済みと未完了は区別できないので、消去以外では索引から消さず上限つき LRU に任せる。`KsImageCache.clear(.memory / .all)` で全消去、`remove(source)` でその識別子の項目を消す (世代が進むので旧項目は識別子でも当たらない)。項目数は上限つきの LRU で、上限はローダーのメモリキャッシュが実用上保持できる項目数を十分に上回る値にする (初版 20,000。基準機の既定のメモリキャッシュ量と画像グリッドの項目 1 件の大きさから、ローダー側が数千件を超えて保持することはない)。引き当て時にキャッシュに無かった鍵はその場で索引から外す (刈り込み)。それでも索引から外れた項目は引き当てられず通常の縮小要求に落ちる — spec はこの限定を「ライブラリが把握している項目」として明記し、契約違反にしない。

索引は thread-safe にする。登録・検索・LRU 更新・全消去・識別子単位の削除は 1 つの錠で直列化し (現行の Android 台帳 `KsImagePrefetchWindow` と同じ方式。iOS は `@MainActor` に閉じる)、`KsImageCache.clear` / `remove` はローダーのキャッシュを消してから索引を消し、復帰時点で両方が無効になっていることを保証する。消去と登録が競合した場合、消去後に登録された鍵は世代付きの識別子が違うため旧項目を指さない (`remove`)、または消去より後の要求なので新しい項目を指す (`clear`)。

鍵の形は現行を維持: iOS は先読み・表示とも `ImageRequest` (縮小指定 + `imageID`) がそのまま鍵。Android は `MemoryCache.Key(識別子, {"coil#size": …})` を幅ありの先読みと表示の両方に付け、`ks#scale` は付けない。幅なしの先読みは鍵に extras を付けない (`key` なしの画像はローダー付属ビューと同じ項目を共有する現行の性質を保つ)。`key` を指定した画像の鍵の本体は Decision 9 のとおり `key` になる。

**理由:** Nuke は鍵の列挙が無く、Coil の `keys` の全走査は 10,000 件グリッドで毎セル O(n) になる。索引を手掛かりにし、実在と寸法の判定をローダーのキャッシュに任せれば、追い出しの同期も完了の通知も自前で持たずに済む (Nuke の `ImagePrefetcher` には要求ごとの完了通知が無い)。

**代替案:**
- **A: Coil の `memoryCache.keys` を走査して同じ URL の項目を探す (Android)、iOS は候補サイズの総当たり** — 却下。走査は件数に比例、総当たりは候補が無限
- **B: 索引を正とし、追い出しをローダーの通知で同期する** — 却下。Nuke / Coil とも追い出しの通知 API を持たない
- **D: 先読みの完了時に寸法つきで登録する** — 却下。Nuke の `ImagePrefetcher` は要求ごとの完了を通知せず、完了を観測するために先読みの経路を作り直すことになる。寸法はキャッシュから取り出した画像が持っている
- **C: ライブラリ独自のメモリキャッシュを持つ** — 却下 (core/ADR-0012: ローダーの共有インスタンスをそのまま共有キャッシュにする)

### Decision 4: 先読みの幅は幅だけを受け取り、その幅の正方形を覆う大きさに縮小デコードする

**採用案:** 要素 `KsResource` の幅は `KsWidth` の 2 値: **列幅** (`.column` / `Column`) と **固定値** (`.fixed(Double)` / `Fixed(Dp)`)。幅なしの要素は元寸。ライブラリは幅を px に正規化し (表示倍率を掛けて四捨五入)、先読みの要求を「幅 × 幅の正方形を覆う最小の大きさ、ただし元がそれより小さければそのまま (拡大しない)」で出す。iOS は `ThumbnailOptions(size: (w, w), unit: .pixels, contentMode: .aspectFill)`、Android は `.size(w, w).scale(Scale.FILL).precision(Precision.INEXACT)` + `coil#size` 鍵。到達点 `disk` では幅を使わない (現行どおり元データの保存まで)。固定値は有限かつ 0 より大きい値だけを有効とし、無効な値 (0・負数・NaN・無限大・`Dp.Unspecified`) は core/ADR-0011 の不正入力 (debug は assertion、release は警告ログを出してその要素を幅なし = 元寸の扱い) にする。px への正規化は四捨五入の後に 1 以上へ丸める。

**理由:** 「幅 = 宣言値」で高さを画像の縦横比なりにする素朴な定義は、横長の画像で高さが宣言幅より小さくなり、正方形の枠を `fill` で覆えない。短辺を宣言幅に揃える (正方形を覆う) 定義なら、幅も高さも宣言値以上が保証され、縦長・横長どちらでも正方形以下の枠に `fill` できる。両ローダーとも 1 つの指定で表現でき、Decision 1 の判定とも整合する (`s ≤ 1` になる)。

**代替案:**
- **A: 幅を長辺の上限にする (`maxPixelSize` 相当)** — 却下。縦長の画像で幅が宣言値より小さくなり、`fill` で拡大ぼやけになる
- **B: 幅と高さ (または縦横比) を受け取る** — 却下 (ADR-0013)。当てはめ方と同じく View の仕事
- **C: 列幅を「セル幅 × 比率」で受け取る** — 却下。比率を書く場面 (セルの半分に画像) は固定値で書けるし、列幅の派生を増やすと Decision 5 の解決が複雑になる。必要になれば追加

### Decision 5: 列幅は先読みの呼び出し元が現在のコンテナから解き、変わったら以後の先読みが新しい幅で出る

**採用案:** 列幅 (pt / dp) = `(コンテナ幅 − 水平の contentPadding − 列間隔 × (列数 − 1)) / 列数`。list は列数 1。列数は iOS `KsLayoutMetrics.columnCount` (bounds と向きから)、Android は `resolveGridCells` と同じ規則 (`Fixed` は向きで解決、`Adaptive` は `LazyVerticalGrid` の規則 `floor((利用可能幅 + 列間隔) / (最小幅 + 列間隔))` を再現) で求める。iOS は `KsCollectionViewController` が prefetch 通知の時点で解いて台帳へ渡し、Android は `KsPrefetchWindowEffect` に `layout` と `contentPadding` とコンテナ幅を渡して `update` のたびに解く。列幅が変わる (回転・列数変更・contentPadding 変更) と、以後の `update` / 通知で出る先読みは新しい幅の要求になる。既に載っている旧幅の項目は取り消さず、Decision 1 の許容範囲に任せる (範囲内なら使われ、範囲外なら使われず LRU で消える)。列幅が 0 以下に解ける間 (余白と列間隔の合計がコンテナ幅を超える、コンテナ幅が未確定) は、列幅で宣言した URL の先読みを開始しない (正になった後に対象になったアイテムから始まる)。

**理由:** 列幅は表示前でも決定的に解ける値で、`KsImage` の実測を待つ必要がない。回転で旧幅の項目を積極的に消しても、共有キャッシュの他利用者に影響するだけで得るものが無い。

**代替案:**
- **A: 可視セルの実測 (`visibleItemsInfo[].size` / セルの frame) から列幅を取る** — 却下。初期表示の先読み (可視セルが無い時点) で解けない
- **B: 列幅が変わったら旧幅の先読みを取り消して新幅で出し直す** — 却下。取り消し対象はまだ表示されていないアイテムなので、旧幅の項目が残っても許容範囲で吸収できる。往復の要求が増えるだけ

### Decision 6: 先読み台帳は「アイテム → 要求集合」「要求 → 参照数と開始時のハンドル」の 2 段にする

**採用案:** 台帳を 2 層にする。上層は「アイテム → 宣言の集合 (識別子 + URL + 幅の種類: なし / 列幅 / 固定値 pt・dp)」で、アイテムの再評価 (配列の差し替え・窓の更新) はこの宣言で突き合わせる — 列幅の px が変わっても宣言は変わらないため、回転だけでは既存の要求を release しない。宣言には URL も含め、`key` を指定した要素でも URL が変われば release して新しい URL で出し直す (失効した署名付き URL の取得が失敗したまま窓に残らないため。取得済みなら新しい要求は `key` でキャッシュに当たりネットワークを使わない。相方 spec レビュー 002 #3、オーナー判断 2026-09-23)。下層は「取得単位 → 参照数 + 開始時に作った要求オブジェクト (iOS は `ImageRequest`、Android は `Disposable` の包み) + 開始時の幅 px」。取得単位は到達点で決まり、`disk` は識別子、`memory` は識別子 + 幅 px (幅なしの要素は識別子のみ)。`disk` で幅違いの宣言が同じ識別子を指せば同じ取得単位に参照数をまとめる (Nuke は同一要求を統合し `stopPrefetching` に参照数が無いため、幅違いを別に数えると一方の取り消しが他方を止める)。取り消しは開始時のオブジェクトで行う (取り消し時に幅を解き直すと、列幅が変わった後は開始時と違う鍵を消す)。`fence` は幅に関わらずその識別子の全取得を止める (引数を URL から識別子に変える)。到達点ごとの `ImagePrefetcher` (iOS) は維持。

**理由:** `memory` で同じ URL の幅違いを独立に数えないと、一方の取り消しが他方を巻き込む。逆に `disk` は要求に幅が無いので独立には数えられない。宣言と解決済み要求を分けるのは、現行 Android 台帳の「再評価で URL 集合が変われば release」の構造を素直に拡張すると回転のたびに旧幅の取消・再発行 (代替案 B) になってしまうため。開始時のオブジェクトで取り消すのは explore で挙がった落とし穴 (取消時に学習値から作り直すと違う鍵を消す) の直接の対策。

**代替案:**
- **D: `key` を指定した要素は識別子と幅の種類だけで突き合わせ、URL の変更では出し直さない** — 却下 (相方 spec レビュー 002 #3)。旧 URL が失効して取得が失敗すると、窓に残る間は新しい URL で出し直されず先読みの効果が消える
- **E: 失敗を検知して新しい URL で再試行する** — 却下。Nuke の `ImagePrefetcher` は要求ごとの完了を通知しないため、先読みの経路を作り直すことになる (Decision 3 代替案 D と同じ理由)
- **A: URL 単位のまま、幅は最新の値で上書きする** — 却下。幅違いの要求が同じ参照数を共有し、片方の取り消しで両方止まる
- **B: 幅が変わったら別の台帳インスタンスを作る** — 却下。`fence` と `cancelAll` が複数台帳をまたぐ
- **C: `disk` でも幅違いを別取得として数える** — 却下。Nuke の `ImagePrefetcher` は同一要求を統合し参照数を持たないため、片方の `stopPrefetching` で残る方も止まる。購読ハンドルを個別に持つ別方式が要り、`disk` では幅を使わないので得るものが無い

### Decision 7: 宣言の入口は `prefetchResources` 1 本のまま、要素を `KsResource` (URL + 任意の幅) にして URL だけの配列は廃止する

**採用案:** `prefetchResources` のクロージャの戻り値を `[KsResource]` / `List<KsResource>` に変える。`KsResource(url)` は幅なし (元寸)、`KsResource(url, width: .column)` / `KsResource(url, width = KsWidth.Column)` は列幅、`KsResource(url, width: .fixed(40))` / `KsWidth.Fixed(40.dp)` は固定値。`KsResource(url, key: photo.id)` のように任意キー `key` も持てる (Decision 9)。`KsWidth` は独立した公開型 (Swift enum `column` / `fixed(Double)`、Kotlin sealed `Column` / `Fixed(Dp)`)。従来の `[URL]` / `List<String>` は受け付けない (配布は phase-7 でまだ先なので、破壊的変更のコストはいま最小)。1 つの宣言の中で幅あり・幅なしを混ぜられる。

```swift
.prefetchResources(destination: .memory) { photo in
    [
        KsResource(photo.thumbnailURL, width: .column),
        KsResource(photo.avatarURL,    width: .fixed(40)),
        KsResource(photo.bannerURL),                        // 幅なし = 元寸
        KsResource(photo.signedURL, width: .column, key: photo.id), // 署名付き URL は key で識別
    ]
}
```

```kotlin
prefetchResources = { photo ->
    listOf(
        KsResource(photo.thumbnailUrl, width = KsWidth.Column),
        KsResource(photo.avatarUrl,    width = KsWidth.Fixed(40.dp)),
        KsResource(photo.bannerUrl),
        KsResource(photo.signedUrl, width = KsWidth.Column, key = photo.id),
    )
},
prefetchDestination = KsPrefetchDestination.Memory,
```

**理由:** Kotlin の `KsCollectionView` は引数の多い 1 つの Composable で、名前付き引数の型を 2 種類にするには Composable 全体を複製するしかない。別名の入口 (`prefetchImages` 等) は「画像」と「リソース」で区別がつかず (オーナー指摘)、幅あり・幅なしの混在もできない。入口を 1 本にして区別を型ではなく値 (幅の有無) に持たせれば、同時宣言の不正入力という論点も消える。Swift の `[URL]` は残せるが、Kotlin で残せない以上、対称性 (core/ADR-0002) を優先して両方落とす。`KsWidth` を独立型にするのは、Kotlin で `KsResource.Width.Column` の入れ子より短く、`import` で `Column` を裸にすると Compose の `Column` と衝突するため型名を付けて書く前提にしたから。ファクトリ (`KsResource.column(url)`) と番兵値 (`width = 40.dp` + `ColumnWidth` 定数) はオーナー判断で却下。

**代替案:**
- **A: 別名の入口 (`prefetchImages`) を足して `[URL]` の形を残す** — 却下。名前で区別がつかない。混在不可。同時宣言の不正入力の扱いが要る
- **B: `prefetchResources` を `[URL]` と `[KsResource]` でオーバーロード** — 却下。Swift は `@_disfavoredOverload` で成立するが、Kotlin は Composable の複製になる
- **C: 列幅をファクトリ (`KsResource.column(url)`)、固定値をコンストラクタ (`width = 40.dp`) にする** — 却下 (オーナー判断)。コンストラクタとファクトリが混ざり読みにくい
- **D: `width` を `Dp` で受け、列幅は `Dp` の番兵値にする** — 却下。番兵に対する計算 (`+ 8.dp`) を防げない。型で表す A の方が直感的 (オーナー判断)
- **E: Swift だけ `[URL]` を残す** — 却下。Kotlin と非対称になる

### Decision 8: 検証は「先頭の手動計測 → 実機テストの契約書き換え → 完了時の手動計測」の 3 点で行い、表示待ちは滑らかさと別に記録する

**採用案:** (1) 本実装の前に、基準機 Pixel 4a と iPhone 11 で Sample「画像グリッド」を到達点 `memory` にして手動フリックし、cross の体感ゲート規約の証跡 6 節で「画像の出方」を記録する (現状の対照)。(2) `KsImageDeviceDecodeTest` の 4 本を新契約 (原寸はハードウェアビットマップのまま引き当てられる / 幅ありは宣言幅の項目が載る / 範囲外は縮小デコードに落ちる) に書き換え、iPhone 実機でも同型の確認を 1 本残す (lessons: 実行環境で実体が変わる資源)。(3) 完了時に (1) と同じ操作列で `memory` (幅なし / 列幅) と `disk` を測り、体感の合否と表示待ちの変化、取得・デコード回数 (ローダーの通知) を証跡に残す。滑らかさの合否は体感ゲート、表示待ちは別の観測点として同じ証跡に併記する。

**理由:** 「同じ鍵にすれば体感が良くなる」は未証明で、`disk` 側に残る別要因 (subcomposition・cold 取得) と切り分けるには現状の対照が要る。実機だけで挙動が変わる資源 (ハードウェアビットマップ) を扱うため、単体テストの緑では完了にしない。

**代替案:**
- **A: Macrobenchmark の絶対基準 (frameOverrun) で判定する** — 却下。cross/ADR-0006 で合否は体感、数値は証跡。表示待ちは frameOverrun に現れない
- **B: 先頭の手動計測を省き完了時だけ測る** — 却下。到達点未記録の 2026-09-08 の観測と比較できず、本 change の効果を帰属できない

### Decision 9: 任意キー `key` は先読みの要素とリモートの画像ソースの両方に持たせ、指定時は取得以外のすべてで URL の代わりに使う

**採用案:** core/ADR-0014 のとおり。`KsResource(url, width:, key:)` と `KsImageSource.remote(URL, key: String? = nil)` / `KsImageSource.Remote(url: String, key: String? = null)`、便宜形 `KsImage(url, key:)` に同じ任意キーを持たせる。ライブラリ内部では「識別子 = `key` があれば `key`、無ければ URL の文字列」を 1 か所の関数で求め、`key` の識別子はライブラリの接頭辞で URL と別の名前空間に置く (`key` の文字列がたまたま別の画像の URL と同じでも衝突しない)。削除の世代を識別子に付ける規則 (iOS の `imageID`) も、他の `key` が作れない形にする (現行の `URL#世代` の形のままだと `key: "p1"` の世代 1 と `key: "p1#1"` が衝突する)。具体的な文字列の形は実装に任せ、衝突しないことを契約テストで固定する。鍵を作るすべての箇所 (表示の要求・先読みの要求・索引・台帳・世代・`fence`・`remove`) がこの識別子を使う。取得 (ネットワーク) にだけ URL を使う。

```swift
KsImage(source: .remote(photo.signedURL, key: photo.id))
KsImage(photo.signedURL, key: photo.id)   // 便宜形
```

```kotlin
KsImage(source = KsImageSource.Remote(photo.signedUrl, key = photo.id))
```

ローダーへの写像:
- iOS: `key` を指定した要求は、世代 0 でも `imageID` = `key` の識別子 (世代が進んでいれば世代付き) を常に付ける。`imageID` がメモリとディスクの両方の鍵になる。`key` なしは現行どおり世代 0 では `imageID` を付けない
- Android: `key` を指定した要求は `memoryCacheKey` の本体と `diskCacheKey` を `key` にする。`remove` はメモリの鍵の完全一致 (`key == 識別子`) とディスクの `remove(識別子)` で消す。`key` なしは現行どおり (ディスクの鍵は Coil の既定 = URL)。削除の扱いも `key` なしと同じ: 世代は鍵に入れず、先読みの `fence` と世代による `KsImage` の作り直しで削除前の要求を捨てる (`key` の追加で削除との競合の性質は変わらない。相方 spec レビュー 002 #2)

範囲と扱い:
- `key` を持てるのはリモートだけ。端末内のファイル (`file` / `File`) とアセット / リソースには持たせない
- 空文字の `key` は不正入力 (core/ADR-0011): debug は assertion、release は警告ログを出して `key` なし (URL が識別子) として扱う。先読みの要素と画像ソースの両方で同じ
- `KsImageCache.remove(source)` はソースの識別子で消す。`key` 付きで保存した画像を消すには同じ `key` を付けたソースを渡す (URL だけのソースでは消えない)
- 同じ `key` で URL が違う取得が同時に走った場合は統合しない。Nuke はネットワーク取得を元の URL で統合するため別々に取得され、同じ鍵へ保存される (内容は同じ画像という前提で、後に書いた側が残る)。Coil も同様
- `key` を指定した画像は、ローダー付属ビューを URL で直接使う側とキャッシュを共有しない (基底 spec「共有キャッシュ」の例外)

**理由:** 先読み・表示・消去のどれか 1 か所でも URL が残ると、URL が変わる画像ではそこだけ毎回食い違う。識別子を 1 か所で求めれば、鍵を作る箇所の食い違いを実装の側で防げる。リモートに限るのは、取得のたびに URL が変わる問題がリモートにしか無く、先読みもリモートだけが対象のため。空文字を不正入力にするのは、無効な固定値の幅 (Decision 4) と扱いをそろえ、書き誤りを debug で気づけるようにするため。

**代替案:**
- **A: `KsResource` にだけキーを持たせる** — 却下 (ADR-0014)。表示側が URL で鍵を作るため先読みが当たらない
- **B: アプリ全体で 1 つの「URL → キー」変換を登録する** — 却下 (ADR-0014)。URL から作れないキーを書けない・大域状態。ADR-0014 の Revisit When で後から足す余地は残す
- **C: `KsResource` にだけ書き、先読みの宣言 (とセル表示時の評価) から URL → キーの対応を覚える** — 却下 (ADR-0014)。先読みは画面内のアイテムを宣言の対象にしないため起動直後の 1 画面が URL の鍵になり、セル表示時に評価しても、コレクションの外や先読みを宣言していない `KsImage` で黙って URL の鍵へ戻る
- **D: ファイル・アセットにも `key` を持たせる** — 却下。取得のたびに変わる URL の問題が無く、使い道が無いまま公開面だけが増える。使い道が出たら足す
- **F: `key` の文字列をそのまま識別子にする (名前空間を分けない)** — 却下 (相方 spec レビュー 002 #1)。`key` が別の画像の URL と同じ文字列だと同じ項目・同じ削除対象になり、「`key` なしのソースでは `key` 付きの画像は消えない」が成り立たない
- **E: 空文字の `key` を省略と同じに黙って扱う** — 却下。書き誤り (モデルの ID が空のまま等) に気づけず、すべての画像が URL の鍵に落ちる

## Risks / Trade-offs

- 許容範囲の初期値 (0.5 / 4) は根拠が経験則。実機の見た目で調整する前提で、Decision 1 の定数を 1 か所に置く
- 索引とローダーのキャッシュのずれは「使う直前にローダーへ問い合わせる」で吸収するが、問い合わせ (iOS `cache[request]`、Android `memoryCache.get`) 自体の費用が候補数分かかる。URL あたりの候補は数個なので許容。未完了の先読みの鍵も候補に入るが、問い合わせで空になるだけ
- Coil の `Precision.INEXACT` + `Scale.FILL` で「元が小さければそのまま」が期待どおりか (拡大しない) は実装時に単体テストで固定する。iOS の `ThumbnailOptions` は元寸より大きくしないことを Nuke の仕様で確認済み (CGImageSource のサムネイル生成)
- 索引の上限は「ローダーが保持できる項目数を上回る」見積もりに依存する。見積もりが外れて索引が先に追い出されると、メモリにある項目を引き当てられず再要求になる (壊れないが `memory` の効果が落ちる)。tasks 8.3 の定常化計測で索引の充足 (キャッシュにある項目が索引に残っている率) も記録する
- 同じ URL を幅なし (原寸) と幅あり の両方で先読みすると (同じ宣言内でも別コレクションでも)、索引に原寸と縮小の両方が載り、引き当ては Decision 1 の「s が 1 に最も近い項目」で解決する
- `key` は利用者が先読みの要素とセルの `KsImage` の 2 か所に同じ値を書く前提で、食い違うと先読みが当たらない (壊れず、表示は通常の縮小要求に落ちる)。違う画像に同じ `key` を付けると取り違える。どちらも concepts と公開型の doc コメントに注意として書く
- Swift の `KsImageSource.remote` に関連値が 1 つ増えるため、利用者コードの `case .remote(let url)` のパターンマッチは形が変わる (配布前なので許容)
- 幅なしの要素 + `memory` の利用者は、実機の初回表示が「読み込み中を経由」から「原寸を即描画」に変わる。見た目は改善だが、原寸が上限を超えるほど大きい URL を宣言している画面では従来どおり縮小デコードに落ちる (concepts の「原寸画像の URL を宣言しない」の注意は維持)

## Migration Plan

公開 API の破壊的変更: `prefetchResources` の戻り値が `[URL]` / `List<String>` から `[KsResource]` / `List<KsResource>` になる (配布前。Sample と内部利用者は `KsResource(url)` に書き換える)。`KsImageSource.remote` / `Remote` と便宜形 `KsImage(url)` に任意の `key` が加わる (既定値は省略なので既存の呼び出しは変更不要)。Sample「画像グリッド」の到達点の選択肢に「メモリまで (列幅)」を足す (両プラットフォーム同文言)。image-loading の deviation / concepts の「Android 実機では引き当てが成立しない」の記述は、本 change の蒸留で concepts から消す。

## Open Questions

- 許容範囲の初期値 (0.5 / 4) は実機で見て確定する (Decision 1)。tasks に実機での目視確認を置く
- iOS の実機 (iPhone 11) で到達点 `memory` の原寸引き当てを実行した証跡はまだ無い (コード読解のみ)。Decision 8 (2) で作る

## ADR 候補

- core/ADR-0013 (proposed、起票済み): Decision 1・2・4・7 の骨格はここに含まれている (Decision 7 の「入口 1 本・`[URL]` 廃止」は本 propose で ADR 本文へ反映済み)。蒸留時に Decision 1 の判定式 (当てはめ方で拡大率を求める)・Decision 4 の「正方形を覆う」定義を追記して accepted にする
- Decision 3 (索引を持ち、正はローダー): core/ADR-0012「ライブラリ独自のキャッシュ領域を持たない」との境界を定める決定なので、ADR-0013 の Consequences に「索引はキャッシュではなく手掛かり」として 1 項目で残す (単独 ADR は不要)
- core/ADR-0014 (proposed、起票済み): Decision 9 の骨格 (置き場所と効く範囲) はここに含まれている。蒸留時に「リモートだけ」「空文字は不正入力」「便宜形にも `key`」を追記して accepted にする
- Decision 5・6・8: 局所的な実装形。コード + テストに任せる (ADR 不要)
