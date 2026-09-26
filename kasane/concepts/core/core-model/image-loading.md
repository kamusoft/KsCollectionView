---
type: concept
title: 画像の先読みと KsImage
description: prefetchResources による画像の先読み (到達点・表示幅・任意キー・取り消し・共有キャッシュ)、専用画像コンポーネント KsImage の表示契約 (許容範囲での引き当て)、KsImageCache によるキャッシュ操作の契約と限界 (iOS / Android 共通)
tags: [core-model, image, prefetch, cache]
timestamp: 2026-09-24
---

# 画像の先読みと KsImage

この文書を読むと、コレクションが「もうすぐ表示される項目」の画像を先読みする仕組みを利用者がどう宣言し、先読みした画像がどこまで・どの大きさで届き、`KsImage` がそれをどう引き当てて表示し、キャッシュをどう消せるかが分かる。あわせて、両プラットフォームで揃わない箇所とその理由が分かる。項目モデルの契約は [collection-items](collection-items.md) を先に読むと分かりやすい。実現方法は [iOS 画像の先読みと KsImage の実現](../../ios/architecture/image-pipeline.md) と [Android 画像の先読みと KsImage の実現](../../android/architecture/image-pipeline.md) にある。ADR は `kasane/decisions/<domain>/` にあり、本文では `core/ADR-0012` の形で指す。

## 目的

画像グリッドはこのライブラリの最頻ユースケースで、「もうすぐ表示される項目」を知っているのはライブラリだけである。その情報を外に出す代わりに、項目 → 先読みする画像の対応をクロージャで宣言させ (core/ADR-0008)、同じローダー・同じキャッシュを見る `KsImage` を対で提供する。ローダーはライブラリのパッケージ本体 (iOS の `KsCollectionView` product / Android の `kscollectionview` モジュール) が直接依存する Nuke (iOS) と Coil 3 (Android) で、ローダーの共有インスタンスをそのまま共有キャッシュにする (core/ADR-0012)。利用者は本体を入れるだけで先読みと表示が繋がる。

先読みの要素には、表示のおおよその幅と、URL の代わりに画像を識別するキーを任意で添えられる。幅を添えるとその幅に縮小した画像をメモリに載せ (core/ADR-0013)、キーを添えると署名付き URL のように取得のたびに URL が変わる画像でもキャッシュが当たる (core/ADR-0014)。

## 公開 API

```swift
KsCollectionView(photos) { photo in
    KsImage(.remote(photo.thumbnailURL, key: photo.id)).aspectRatio(1, contentMode: .fill)
}
.prefetchResources(destination: .memory) { photo in                  // destination は省略可 (既定 .disk)
    [
        KsResource(photo.thumbnailURL, width: .column, key: photo.id), // 列幅に縮小してメモリへ
        KsResource(photo.avatarURL, width: .fixed(40)),                // 40pt 四方を覆う大きさ
        KsResource(photo.bannerURL),                                   // 幅なし = 元寸
    ]
}

KsImage(.remote(url), contentMode: .fit) { ProgressView() } failure: { Text("表示できません") }
KsImage(url, key: photo.id)                                           // .remote(url, key:) の便宜形 (key は省略可)
KsImageCache.clear(.all)                                              // .memory / .all
KsImageCache.remove(.remote(url, key: photo.id))
KsImagePipeline.enableSharedDiskCache()                               // iOS のみ。アプリ起動時に一度
```

```kotlin
KsCollectionView(
    items = photos, key = { it.id },
    prefetchResources = { photo ->
        listOf(
            KsResource(photo.thumbnailUrl, width = KsWidth.Column, key = photo.id),
            KsResource(photo.avatarUrl, width = KsWidth.Fixed(40.dp)),
            KsResource(photo.bannerUrl),
        )
    },
    prefetchDestination = KsPrefetchDestination.Memory,               // 省略可 (既定 Disk)
) {
    template { photo -> KsImage(KsImageSource.Remote(photo.thumbnailUrl, key = photo.id), modifier = Modifier.fillMaxWidth().aspectRatio(1f)) }
}

KsImage(KsImageSource.Remote(url), contentMode = KsImageContentMode.Fit, loading = { CircularProgressIndicator() }, failure = { Text("表示できません") })
KsImage(url, key = photo.id)                                          // KsImageSource.Remote(url, key) の便宜形 (url は String)
KsImageCache.clear(KsImageCacheScope.All)
KsImageCache.remove(KsImageSource.Remote(url, key = photo.id))
```

| 語彙 | Swift | Kotlin |
|---|---|---|
| 先読みの宣言 | `.prefetchResources(destination:_:)` modifier。クロージャは `[KsResource]` を返す | `prefetchResources` / `prefetchDestination` 引数。ラムダは `List<KsResource>` を返す |
| 先読みの要素 | `KsResource(_ url: URL, width: KsWidth? = nil, key: String? = nil)` | `KsResource(url: String, width: KsWidth? = null, key: String? = null)` |
| 先読みの幅 | `KsWidth` の `.column` / `.fixed(Double)` (pt) | `KsWidth.Column` / `KsWidth.Fixed(Dp)` |
| 到達点 | `KsPrefetchDestination` の `.disk` / `.memory` | `KsPrefetchDestination.Disk` / `Memory` |
| 画像ソース | `KsImageSource` の `.remote(URL, key: String? = nil)` / `.file(URL)` / `.asset(String)` | `KsImageSource.Remote(String, key: String? = null)` / `File(java.io.File)` / `Resource(@DrawableRes Int)` |
| 当てはめ方 | `KsImageContentMode` の `.fit` / `.fill` (既定 `.fill`) | `KsImageContentMode.Fit` / `Fill` (既定 `Fill`) |
| 読み込み中・失敗の表示 | `loading:` / `failure:` の `@ViewBuilder` スロット | `loading` / `failure` の Composable スロット |
| 画像の説明 (アクセシビリティ) | `.accessibilityLabel(_:)` modifier | `contentDescription` 引数 |
| キャッシュの消去範囲 | `KsImageCacheScope` の `.memory` / `.all` | `KsImageCacheScope.Memory` / `All` |
| ディスクキャッシュの有効化 | `KsImagePipeline.enableSharedDiskCache()` | 無し (Coil は既定で有効) |

Kotlin には modifier に当たる構文が無いため、到達点はフラットな名前付き引数 `prefetchDestination` になる (`destination` だけでは何の到達点か読めないので接頭辞を付ける。core/ADR-0002 の記法差)。Swift で末尾クロージャを 1 つだけラベルなしで書く形 (`KsImage(source) { … }`) は、読み込み中と失敗のどちらにも当たりうるため書けず、上の例のように `failure:` のラベルを付けて 2 つ並べるか、片方だけをラベル付きで書く。`KsWidth` は独立した型で、Kotlin では Compose の `Column` と衝突しないよう `KsWidth.Column` と型名を付けて書く。

## 責務境界

| 責務 | 持つ側 | 具体 |
|---|---|---|
| 項目 → 先読みする画像の対応 | 利用者 | 先読みの宣言で `KsResource` を返す。対象はリモート URL だけで、ファイル・リソースのソースは先読みの対象外。モデルにライブラリの型を持ち込まない |
| 先読みの幅の概算 | 利用者 | グリッドの幅いっぱいに置く画像は列幅、セル内の固定サイズの画像は固定値。大きめに書く (「先読みの幅」の節) |
| 先読みとセルで同じ任意キーを書くこと・キーの一意性 | 利用者 | 同じ画像には両方に同じキーを書き、違う画像には違うキーを付ける (「任意キー」の節) |
| 宣言する URL の寸法 | 利用者 | サムネイル一覧には、その用途の寸法で配信される URL を宣言する (表の直後の段落) |
| `KsImage` の表示枠の大きさ | 利用者 | `.frame` / `.aspectRatio` (Swift)、`Modifier.size` / `aspectRatio` (Kotlin) で与える (表の直後の段落) |
| iOS のディスクキャッシュの有効化 | 利用者 | アプリ起動時に `enableSharedDiskCache()` を一度呼ぶ (「共有キャッシュ」の節) |
| 先読みの対象の決定と開始・取り消し | ライブラリ | iOS はシステムの先読み通知、Android は自前の先読み窓 (進行方向の一定件数を対象にする窓。用語の節) |
| 列幅の解決と到達点の対応付け | ライブラリ | 列幅を現在のコンテナから解き、到達点と幅をローダーの取得方針に対応付ける |
| キャッシュ項目の引き当てと縮小デコード | ライブラリ | `KsImage` はメモリに許容範囲内のキャッシュ項目があればそのまま使い、無ければ枠の実サイズへ縮小してデコードする |
| キャッシュの保持と追い出し | ローダー | メモリ・ディスクとも Nuke / Coil の既定 (LRU) に乗せる。ライブラリ独自のキャッシュ領域は持たない |

先読みは取得とディスクへの保存を元データのまま行い、幅はメモリに載せるときのデコードにだけ効く。原寸画像の URL をグリッドに宣言すると、通信量とディスク使用量は原寸のままで、幅を省略した要素を到達点 `memory` で先読みするとメモリも原寸を使う。`KsImage` は枠が決まるまで取得を始めないため、枠の大きさを与えないと iOS は親から与えられた領域いっぱいに広がり、Android は高さ 0 で見えない。

## 保証すること

### 先読みは項目単位で始まり、離れたら取り消される

先読みの対象は「可視範囲の外側で、進行方向に並ぶ項目」で、可視範囲内の項目は含めない (表示側の `KsImage` が読む)。対象の決め方はプラットフォームで異なるが契約は同じ。

| | iOS | Android |
|---|---|---|
| 対象と取り消しのタイミング | `UICollectionViewDataSourcePrefetching` の判定に従う | 可視範囲の観測から、進行方向へ可視件数と同数の項目を窓にする。静止時は直前の進行方向を保ち、初期表示は末尾方向 |
| 配列の差し替えで消えた項目 | snapshot 適用時にライブラリが取り消す (システムからは通知が来ない) | 窓の作り直しで取り消す |
| コレクションの破棄 | controller の解放で全停止 | コンポジション離脱で全停止 |

取り消しは進行中の取得にだけ作用し、完了してキャッシュに入ったものは消さない。ライブラリは台帳を 2 層で持つ。上の層は項目の安定 ID ごとの宣言 (識別子・URL・幅の種類) で、下の層は取得単位ごとの参照数と、取得を開始したときに作った要求である。取得単位は、到達点 `disk` では識別子、`memory` では識別子 + 幅の px (幅なしは識別子のみ) になる。同じ取得単位を複数の項目が必要とする場合、その取得は参照数が 0 になるまで止めない。`disk` では幅違いの宣言も 1 つの取得にまとまる (ローダーが同じ取得を統合するので、別に数えると一方の取り消しが他方を止める)。

取り消しは取得を開始したときの要求で行うので、回転などで列幅が変わった後でも開始時と違う鍵を消すことはない。宣言の突き合わせは幅の種類で行い、列幅の px が変わっただけでは既存の取得を取り消さない。宣言が無いコレクションでは先読みも可視範囲の観測も起きず、空配列を返した項目は何も取得しない。先読みのクロージャ自体と到達点は、表示中に別のものへ差し替えない前提の宣言である。差し替えた場合は、次に先読みの対象が更新されたとき (iOS の先読み通知 / Android の窓の更新) か配列更新から、新しい要求に反映される。

### 到達点は「どこまで持ってくるか」を決める

| 到達点 | 意味 | iOS (Nuke `ImagePrefetcher`) | Android (Coil `ImageRequest`) |
|---|---|---|---|
| `disk` (既定) | 元データをディスクキャッシュに保存するまで。デコードせず、幅は使わない | `destination: .diskCache` | `memoryCachePolicy(DISABLED)` + デコード省略 |
| `memory` | ディスクに保存した上で、デコードしてメモリキャッシュにも載せる。幅ありは幅に縮小、幅なしは元寸 | `destination: .memoryCache`。幅ありは `ThumbnailOptions(幅 × 幅, .aspectFill)` | 幅ありは `size(幅, 幅)` + `Scale.FILL` + `Precision.INEXACT`、幅なしはサイズ指定なし |

どちらでも、先読みした画像は同じ識別子の `KsImage` に再ダウンロードなしで使われる。到達点 `memory` では、先読みの完了後に画面に出た `KsImage` は取得もデコードもせず、読み込み中を経由しない (両プラットフォームの基準機 = 性能の合否を下す実機で確認。Android のハードウェアビットマップでも成立する)。到達点 `disk` の先読みはメモリに何も載せないので、表示時に枠の大きさでデコードする。

### 先読みの幅 — 幅 × 幅の正方形を覆う大きさに縮小して載せる

幅のある要素は、幅 × 幅の正方形を覆う最小の大きさ (短辺を幅にそろえた大きさ) に縮小デコードする。元がそれより小さければ拡大しない。短辺をそろえるので、縦長・横長どちらの画像でも正方形以下の枠に `fill` で当てはめられる。幅は表示倍率を掛けて四捨五入した px に正規化し、1〜16384 px に収める (16384 を超える指定は黙って頭打ちにする)。

| 幅の種類 | 解き方 | 向く配置 |
|---|---|---|
| 列幅 (`.column` / `KsWidth.Column`) | `(コンテナ幅 − 水平の余白 − 列間隔 × (列数 − 1)) / 列数`。list は列数 1。先読みのたびに現在のコンテナから解く | グリッドの幅いっぱいに置く画像 |
| 固定値 (`.fixed(40)` / `KsWidth.Fixed(40.dp)`) | 宣言した pt / dp を px に直す | セル内の固定サイズの画像 |

列幅が 0 以下に解ける間 (コンテナ幅が未確定、または余白と列間隔の合計がコンテナ幅を超える) は、列幅の要素の先読みを始めない。回転や列数の変更で列幅が変わると以後の先読みは新しい幅で出て、旧い幅で載ったキャッシュ項目は消さず、表示側の許容範囲の判定に任せる。固定値の 0・負数・NaN・無限大・`Dp.Unspecified` は不正入力 (core/ADR-0011) で、debug は assertion、release は警告ログを出してその要素を幅なし (元寸) として扱う。

同じ URL を幅なしと幅ありの両方で宣言すると、到達点 `memory` では別々の取得になり両方がメモリに載る (表示は拡大率が 1 に近い方を選ぶ)。`disk` では 1 つの取得にまとまる。

### 引き当て — KsImage はメモリのキャッシュ項目を許容範囲で使う

`KsImage` は、同じ識別子でメモリにあるキャッシュ項目の実物の寸法と枠を比べ、許容範囲の内側ならローダーへ表示要求を出さずにそのキャッシュ項目を成功状態として描き、描画時に枠へ合わせる (core/ADR-0013)。判定には、キャッシュ項目を枠に当てはめるのに必要な拡大率 `s` を使う。`fill` は `max(枠幅/幅, 枠高/高)`、`fit` は `min(枠幅/幅, 枠高/高)` である。`s` = 2 (キャッシュ項目が必要な寸法の半分) から `s` = 0.25 (4 倍) までなら使う。範囲内のキャッシュ項目が複数あれば、`s` が 1 に最も近いものを選ぶ。許容範囲は公開 API ではなく、ライブラリ内部の定数である。

範囲内のキャッシュ項目が無ければ、表示要求 (枠の実サイズへ縮小してデコードする要求) をローダーへ出す (読み込み中を経由する)。引き当てたキャッシュ項目は表示中だけ参照を持つので、ローダーの LRU で追い出されても表示中の画像は消えない。枠のサイズが変わったときは引き当てをやり直し、範囲内なら同じキャッシュ項目を使い続ける。

候補は、ライブラリが識別子ごとに覚えている「メモリへ載せるよう要求した鍵」の索引から得る。索引は寸法も画像も持たない手掛かりで、候補の鍵を使う直前にローダーのメモリキャッシュへ問い合わせ、返った画像の寸法で判定する。登録するのは、到達点 `memory` の先読みの要求を出した時点と、`KsImage` が表示要求を出した時点である。索引は上限 20,000 件の LRU で、`clear` / `remove` とも同期する。索引の上限から外れた鍵や到達点 `disk` の先読みは引き当ての候補にならず、表示要求に落ちる。

コレクションはセルを画面に出る前に組み立てる (iOS の UIKit のセル先行組み立て、Android のフリング中の先行合成)。組み立ての時点では、まだ先読みが完了していないことがある。そのため、組み立てで引き当てに外れ、同じ識別子の到達点 `memory` の先読みが取得中のときだけ、表示要求の開始を画面に出る時点まで遅らせ、その時点でもう一度引き当てを試す。当たればそのキャッシュ項目を描き、外れたときだけ表示要求を出す。それ以外 (先読みが無い・完了した・取り消された) は、組み立ての時点で表示要求を出す。失敗した先読みは、Android では取得中から外れるが、iOS では見分けられず取得中の可能性として残る (影響は画面に出る時点の引き当てのやり直しが 1 回余計に走ることだけ)。

ローダー付属ビュー (iOS は NukeUI の `LazyImage`、Android は Coil の `AsyncImage`。SwiftUI 標準の `AsyncImage` は別物で対象外) を直接使う場合は、この引き当てを通らないため縮小済みのキャッシュ項目に当たらない (共有キャッシュによる再ダウンロードなしは維持)。

### KsImage は 3 状態を持ち、ソースで描画経路が変わる

`KsImage` は読み込み中・成功・失敗の 3 状態を持ち、読み込み中と失敗の表示はスロットで差し替えられる (未指定なら無地の既定表示)。縮小デコードするときの目標は当てはめ方で決まり、`fit` は枠に収まる最大寸法、`fill` は枠を覆う最小寸法 (はみ出しは表示されない) にする。

| ソース | 描画経路 | 読み込み中の状態 |
|---|---|---|
| リモート / ファイル | 範囲内のキャッシュ項目があればそれを直接描く。無ければローダー (iOS `LazyImage`、Android は `rememberAsyncImagePainter` で状態を観測し Composable スロットを自前で切り替える) | 範囲内のキャッシュ項目があれば経由せず成功になる。無ければ経由する |
| アセット (iOS) / リソース (Android) | ローダーを通さない同期描画 (SwiftUI `Image` / Compose `painterResource`) | 経由せず、成功か失敗になる。Android で描画リソースとして読めない ID は debug ビルドでは assertion で停止、release は警告ログと失敗表示 (core/ADR-0011) |

画面外に出て破棄された `KsImage` の未完了の読み込みは取り消され、完了した画像はローダーのメモリキャッシュに残る。再び表示されたときは引き当てで再デコードなしに表示され、追い出されていればディスクの元データ (無ければ再取得) またはローカルソースから再デコードする。失敗した `KsImage` は、ビューが作り直されたとき (セルの再利用・画面への再入場) と、`KsImageCache` の `clear(.all)` / `remove` でそのビューに関わる世代 (キャッシュ消去を表示中の `KsImage` へ伝える番号。用語の節) が進んだときに再試行し、同じビューが表示され続けている間は自動で再試行しない。

### 任意キー — 指定した画像は取得以外のすべてでキーを使う

リモートの画像ソースと先読みの要素は、任意のキー `key` を持てる (core/ADR-0014)。キーを指定した画像は、取得 (ネットワーク) にだけ URL を使い、メモリの鍵・ディスクの鍵・削除の世代・索引・先読みの取得単位と停止・`remove` のすべてで URL の代わりにキーを使う。ライブラリはこの識別子 (キーがあればキー、無ければ URL) を 1 か所で求める。ディスクの鍵もキーになるので、署名付き URL が起動のたびに変わっても保存済みのキャッシュ項目に当たる。

| 場面 | 挙動 |
|---|---|
| キーの文字列が別の画像の URL と同じ | 衝突しない。キーの識別子は URL と別の名前空間に置かれる |
| 空文字のキー | 不正入力 (core/ADR-0011)。debug は assertion、release は警告ログを出してキーなしとして扱う |
| ファイル・アセット / リソース | キーを持てない (取得のたびに変わる URL の問題はリモートにしか無い) |
| 配列更新などで、同じ項目に対してクロージャが返すキー付きの要素の URL だけが変わった | 旧 URL の取得を取り消し、新しい URL で出し直す (失効した署名付き URL の取得を残さないため)。取得済みならキーでキャッシュに当たり、ネットワークは使わない |
| 同じキーで URL が違う取得が同時に走る | 統合されず、同じ鍵へ保存される (内容は同じ画像という前提) |
| ローダー付属ビューを URL で直接使う | キー付きのキャッシュ項目とは共有しない (別のキャッシュ項目になるだけで壊れない) |

### 共有キャッシュ — 先読みと表示は同じキャッシュを見る

先読みと `KsImage` は iOS が `ImagePipeline.shared`、Android が `SingletonImageLoader` を使う。同じローダーの付属ビュー (`LazyImage` / `AsyncImage`) を利用者が直接使っても、キーなしの画像なら同じキャッシュを見るので先読みが効く。Android は `coil-compose` が Gradle の `api` 構成で推移的に公開されるため、利用者は Coil を自分で依存に足さずに `AsyncImage` を使える。

iOS の共有パイプラインは既定でディスクキャッシュを持たない。`KsImagePipeline.enableSharedDiskCache()` を呼ぶと、`dataCache` が未設定のときだけ現在の構成を引き継いでディスクキャッシュを足した構成に差し替える (アプリが先に構成していれば何もしない)。呼ばない限り、到達点 `disk` でも元データはディスクに残らず、アプリを再起動すると再ダウンロードになる。呼び出しには 2 つの帰結がある。

| 帰結 | 利用者がすること |
|---|---|
| 共有パイプラインの `ImagePipeline.Delegate` が既定に戻る | 要求の加工 (認証ヘッダ等) を delegate で行うアプリは呼ばず、`dataCache` を設定した `ImagePipeline` を自分で `ImagePipeline.shared` に置く |
| 表示を始めた後に呼んでも、既に生きているコレクションの先読みには反映されない | アプリ起動時 (`@main` の `init` 等) に一度だけ呼ぶ |

delegate が戻るのは、Nuke 13 が共有パイプラインの delegate を外から読む API を公開していないため。既存のコレクションに反映されないのは、先読みの経路がコレクション生成時の共有パイプラインを捕捉するためで、`KsImage` の表示側は要求のたびに現在の共有パイプラインを使うので、遅れて呼ぶと同じ画面で先読みと表示が別のパイプラインを使う状態になりうる。

### キャッシュ操作は戻った時点で完了している

`clear(scope)` と `remove(source)` は共有インスタンスのキャッシュを消すので、同じローダーを使う他画面の画像も対象になる。呼び出しから戻った時点で、ローダーのキャッシュと引き当ての索引の両方で削除は完了しており、以後の同じソースの要求はキャッシュにも引き当てにも当たらない。ライブラリは消す前に、先読み層が出した進行中の取得を止める (止めないと、消した後に完了した取得が書き戻す)。

| 操作 | 消えるもの | 表示中の `KsImage` | 世代 |
|---|---|---|---|
| `clear(.memory)` | メモリ上のデコード済み画像と索引 | 置き換えない。次に表示されるときにディスクから再デコード (ディスクに無ければ再取得。iOS で `enableSharedDiskCache()` を呼んでいない場合など) | 進まない |
| `clear(.all)` | メモリとディスクの両方と索引 | 読み込み中の表示に戻って再取得する | 全体の世代が進む |
| `remove(source)` | そのソースの識別子のキャッシュ項目 (あらゆる表示サイズ)・ディスクの元データ・索引の鍵 | そのソースの表示だけが読み込み中に戻る | そのソースの世代が進む (iOS では要求の鍵にも混ざる) |

`remove` はソースの識別子で消すので、キー付きで保存した画像は同じキーを付けたソースで消え、URL だけのソースでは消えない (逆にキーなしで保存した画像は、同じ URL にキーを付けたソースでは消えない)。消去範囲に「ディスクだけ」は無い。ディスクの元データを消しつつそこから作られたメモリのキャッシュ項目を残す動きはローダーの構造上作れず、同じ動きをする選択肢を 2 つ公開すると誤解を招くため 2 択にしている。

## してはいけないこと

- 先読みの宣言に原寸画像の URL を返さない。グリッドには表示用途の寸法で配信される URL を宣言する (幅は取得とディスクの量を減らさない。責務境界)。
- 先読みの幅を小さめに書かない。必要な寸法の 0.5 倍を下回ると引き当てられず表示要求に落ち、0.5〜1 倍では拡大表示になって見た目が甘くなる。
- 先読みの要素とセルの `KsImage` で任意キーを食い違わせない。先読みしたキャッシュ項目が表示で使われない (壊れず、表示要求に落ちる)。
- 違う画像に同じ任意キーを付けない。取り違えて別の画像が表示される。
- iOS で `enableSharedDiskCache()` を表示開始後に呼ばない。起動時に一度だけ呼ぶ (「共有キャッシュ」の節)。
- iOS で `KsImage` と `LazyImage` を同じ URL で混在させるアプリでは、個別削除に `remove` を使わない (理由はこの一覧の直後の段落)。`clear` を使うか、削除後の再表示を両方の経路で確認する。
- Android でファイル・リソースのソースを確実に消したいときに `remove` に頼らない。`remove(File)` は Coil の鍵の作り方に依存する best-effort で、`remove(Resource)` はローダーを通らないため何もしない (iOS のアセットと対称)。`clear` を使う。
- Android で `androidx.startup.InitializationProvider` をマニフェストから取り除いた構成でキャッシュ操作を期待しない (理由はこの一覧の後の段落)。

iOS で `remove` したソースは、以後 `KsImage` と先読みの要求が世代付きの鍵を持つようになり、`LazyImage` が素の URL で引くキャッシュ項目とは別になる。直接使いの側には LRU で追い出されるまで古い画像が出うる。`clear` は識別子を変えないので共有に影響せず、一度も `remove` していないキーなしのソースも共有される。

Android のライブラリは `InitializationProvider` に相乗りしてアプリケーションのコンテキストを捕捉している (android/ADR-0005)。無い環境では `clear` / `remove` は警告ログだけで何もせず、表示は動くため消えないキャッシュが残る。

## 性能

スクロール性能の合否は、基準機でのオーナーの体感で下し、計測器の数値は証跡として残す (cross/ADR-0006。判定規則は [スクロール性能の体感ゲート](../../../handbook/cross/scroll-performance-gate.md))。画像の先読みや `KsImage` に触れる変更の計測の土俵 (fixture) は、リポジトリ同梱のサンプルアプリ (Sample) の「画像グリッド」画面 (10,000 件・3 列・正方形 `KsImage`、公開のプレースホルダー画像サービス) である。画面の先読み設定は「なし / ディスクまで / メモリまで / メモリまで (列幅)」から選べる。

| 観点 | iOS (基準機 iPhone 11) | Android (基準機 Pixel 4a) |
|---|---|---|
| スクロールの滑らかさ (体感) | なし以外の 3 設定 (ディスクまで・メモリまで・メモリまで (列幅)) とも合格 (2026-09-24)。全セルが同じ高さで、推定高さの解き直しが起きない | 同じく 3 設定とも合格 (2026-09-24)。画像 1 枚ごとに表示枠を読む subcomposition (`BoxWithConstraints`) が 1 段増え、文字だけのグリッドより重い |
| 先読み後の表示 | 到達点 `memory` (幅なし・列幅) で、先読みの完了後に画面に出たセルは表示要求・取得・デコード・読み込み中がすべて 0 件 | 同左 (フリングを含む) |
| 画像の表示待ち (止めてから画像が揃うまで) | 「メモリまで」で早く、列幅でさらに早い向き。残る待ちの主因は Nuke の元データ取得の同時数 6 | 到達点による差を体感で感じない。主因は取得経路 (OkHttp) の同一ホスト同時取得数 5 で、上限を 64 にすると中央値 0 秒になる |
| メモリ | 往復で定常化し、索引は上限の内側で止まる。列幅では元寸がメモリに載らない (キャッシュ項目の寸法で確認) | 往復で定常化し、索引は上限で頭打ちになる。60 件の往復の定常値は幅なし約 133 MB・列幅約 124 MB。画面離脱で索引はコレクションやセルを保持しない |

画像の表示待ちは滑らかさとは別の観測点で、体感の合否に混ぜない。表示待ちの主因 (取得の同時数と優先度) は変更 `kasane/changes/image-fetch-concurrency-priority` で扱う。手順は [iOS](../../../handbook/ios/performance-verification.md) / [Android](../../../handbook/android/performance-verification.md) の性能検証規約。

## 用語

| 用語 | 意味 |
|---|---|
| 先読み (プリフェッチ) | もうすぐ表示される項目の画像を、表示の要求より前に到達点まで取得すること。宣言は `prefetchResources` |
| 到達点 | 先読みがどこまで画像を持ってくるか。`disk` (元データをディスクまで) と `memory` (デコード済みをメモリまで) |
| 先読みの幅 | 先読みの要素 `KsResource` に任意で添える概算の表示幅 (`KsWidth`)。列幅と固定値の 2 種類で、到達点 `memory` のデコードの大きさを決める |
| 列幅 | 現在のコンテナ幅・列数・余白・列間隔から解いた 1 列の幅 |
| 項目 | コレクションの要素 (利用者の配列の 1 件。安定 ID を持つ)。キャッシュに入った画像の 1 件はキャッシュ項目と呼んで区別する |
| キャッシュ項目 | ローダーのメモリ・ディスクのキャッシュに入った画像の 1 件。鍵で引く |
| 先読み窓 | Android で先読みの対象になる項目の集合。可視範囲の外側・進行方向・可視件数と同数 |
| 基準機 | 性能の合否を下す実機。iOS は iPhone 11、Android は Pixel 4a |
| 取得単位 | 先読みの台帳が参照数を数える単位。`disk` は識別子、`memory` は識別子 + 幅の px |
| 任意キー (`key`) | リモートの画像ソースと先読みの要素に任意で添える、画像を識別する文字列。指定すると URL の代わりに識別子になる。本文の「キー」はこれを指し、ローダーの「鍵」とは別物 |
| 識別子 | 鍵を作る基準の文字列。キーがあればキー (URL と別の名前空間)、無ければ URL |
| 共有キャッシュ | ローダーの共有インスタンス (`ImagePipeline.shared` / `SingletonImageLoader`) が持つメモリ・ディスクのキャッシュ。ライブラリ独自の領域ではない |
| 鍵 | ローダーがキャッシュ項目を引く文字列。識別子を基準に作り、ディスクは識別子そのもの、メモリは識別子に表示サイズ・当てはめ方 (表示要求) や幅 (先読み)、世代 (iOS の `remove` 後) を加える |
| 許容範囲 | `KsImage` がメモリのキャッシュ項目をそのまま使ってよい大きさの範囲。必要な寸法の 0.5〜4 倍 |
| 引き当て | `KsImage` がメモリのキャッシュ項目の中から、許容範囲に入るものを探して使うこと |
| 表示要求 | `KsImage` がローダーへ出す、枠の実サイズへ縮小してデコードする要求。引き当てに外れたときだけ出す |
| 索引 | 引き当ての候補を得るために、ライブラリが識別子ごとに覚える「メモリへ載せるよう要求した鍵」の一覧。キャッシュではなく手掛かり |
| 世代 | キャッシュを消したことを表示中の `KsImage` へ伝える番号。`clear(.all)` は全体の世代、`remove` はソースごとの世代を進める。iOS ではソースの世代を要求の鍵にも混ぜ、削除前のキャッシュ項目に二度と当たらないようにする |
| ソース | `KsImageSource` の値。リモート URL・端末内のファイル・バンドル済みリソース (iOS はアセット名、Android はリソース ID) の 3 種 |

## 関連

- [collection-items](collection-items.md) — 項目モデルと安定 ID (先読みの台帳は安定 ID で項目を追う)
- [collection-layout](../styling/collection-layout.md) — layout 値・contentPadding・列間隔 (列幅の解決に使う)
- [iOS 画像の先読みと KsImage の実現](../../ios/architecture/image-pipeline.md) — Nuke への接続、索引と引き当て、画面に出る時点の引き当てのやり直し、世代付きの鍵の実現
- [Android 画像の先読みと KsImage の実現](../../android/architecture/image-pipeline.md) — 先読み窓、表示要求の鍵、画面に出る時点の引き当てのやり直し、アプリケーションコンテキストの捕捉
- core/ADR-0008 (DSL 外形)、core/ADR-0013 (先読みの幅と許容範囲の引き当て)、core/ADR-0014 (任意キー)
- core/ADR-0012 (ローダーの直接依存と共有キャッシュ・iOS のディスクキャッシュの明示的な有効化)、core/ADR-0002 (記法差)、core/ADR-0011 (不正入力)、android/ADR-0005 (アプリケーションコンテキストの捕捉)
- [dsl-samples](../../../roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md) のシナリオ 5 — 利用形の全体 (先読みの要素が URL だった時点の形)
