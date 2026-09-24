# Design: image-loading

## Context

core/ADR-0008 で DSL 外形 (`prefetchResources` + `KsImage` の対) が、phase-8 の議論で core/ADR-0012 (proposed: 本体が iOS は Nuke・Android は Coil 3 に直接依存し、ローダーの共有インスタンスをそのまま共有キャッシュとする) と agenda の決定事項 10 件が確定した。本書はその決定を実装の判断に落とす。決定の経緯は `kasane/roadmaps/v1-foundation/phases/phase-8-image-loading/history.md`、調査の事実は同 history の 2026-09-05 各節にある。

現状のコード:

- iOS: `ios/Sources/KsCollectionView/KsPrefetching.swift` (internal protocol、アイテム単位の prefetch / cancel) と `KsAnyPrefetcher.swift` (型消去) があり、`KsCollectionViewController.swift:712-726` が `UICollectionViewDataSourcePrefetching` から IndexPath → Item に解決して流している。`KsCollectionConfiguration.prefetcher` は `KsCollectionView.swift:110` で `nil` 固定。`ios/Package.swift` は依存ゼロ・product 1 本
- Android: プリフェッチ機構なし。`KsCollectionView.kt` は `BoxWithConstraints` でコンテナ幅を持ち、`LazyVerticalGrid` に `LazyGridState` を渡している。依存は Compose のみ (`android/kscollectionview/build.gradle.kts`)

ローダーの事実 (history 2026-09-05「プリフェッチの宣言と到達点」の調査):

- Nuke 13: メモリ鍵は processors を含む。`ImagePrefetcher` は `destination` (`.memoryCache` 既定 / `.diskCache`) と URL 単位の `startPrefetching` / `stopPrefetching` を持つ。`.diskCache` はデコードせず元データのみ保存。`ImagePipeline.shared` の既定構成はディスクキャッシュ (`DataCache`) が無効。NukeUI `LazyImage` に自身のサイズへの自動縮小は無い
- Coil 3: 変換なし要求のメモリ鍵はサイズ非依存で、元寸のメモリ画像は `AsyncImage` の制約付き要求 (INEXACT) にヒットする。ディスク鍵は URL。`ImageLoader.enqueue` で描画なしに取得でき、`memoryCachePolicy(DISABLED)` でディスクのみ、`BlackholeDecoder` でデコード省略。`AsyncImage` は制約からサイズを解決して縮小デコードする。ネットワーク取得には fetcher artifact が別途必要

## Goals / Non-Goals

Goals: proposal.md の What Changes。Non-Goals: proposal.md の Non-Goals。

## Decisions

### Decision 1: 共有インスタンスの使い方 — iOS は `ImagePipeline.shared` を使い、ディスクキャッシュが無ければ初回利用時に有効化した構成で差し替える

**採用案:** iOS のプリフェッチと `KsImage` は `ImagePipeline.shared` を使う。ライブラリの初回利用時 (最初のプリフェッチまたは `KsImage` の表示) に、`ImagePipeline.shared.configuration.dataCache` が `nil` なら、**現在の共有パイプラインの `configuration` と `delegate` をそのまま引き継いだ上で `dataCache` だけを足した構成**で `ImagePipeline.shared` を差し替える。アプリが設定した DataLoader・URLCache・delegate・デコーダ等は失わない。既に `dataCache` が設定されていれば何もしない。Android は `SingletonImageLoader.get(context)` を使う。Coil 3 の既定構成はメモリ + ディスクキャッシュが有効なので差し替えは不要。ネットワーク fetcher は `coil-network-okhttp` を本体の依存に含め、ServiceLoader による自動登録に乗る。

```swift
// 初回利用時 (main actor)
enum KsImagePipeline {
    static func shared() -> ImagePipeline {
        let current = ImagePipeline.shared
        if current.configuration.dataCache == nil {
            var configuration = current.configuration          // DataLoader / URLCache / decoders 等を引き継ぐ
            configuration.dataCache = try? DataCache(name: "jp.kamusoft.kscollectionview")
            ImagePipeline.shared = ImagePipeline(configuration: configuration, delegate: current.delegate)
        }
        return ImagePipeline.shared
    }
}
```

**理由:** ADR-0012 の「共有インスタンスをそのまま共有キャッシュ」を守りつつ、agenda 決定「プリフェッチの到達点はディスク既定」を成立させるには、Nuke のディスクキャッシュが有効でなければならない (既定無効)。利用者に「Nuke のパイプラインを設定してから使う」手順を課すと ADR-0012 の「本体を入れるだけで効く」が崩れる。アプリが先に構成していればそれを尊重するので、共有の性質は保たれる。

**代替案:**
- **A: ライブラリ専用のパイプライン (`KsImagePipeline`) を持つ** — 却下。ローダー付属のビュー (`LazyImage`) を直接使う利用者とキャッシュが分断され、ADR-0012 が解こうとした二重ダウンロードが再発する
- **B: 利用者にパイプライン構成を要求する (ドキュメントで案内)** — 却下。「本体を入れるだけで効く」(ADR-0012 の正の帰結) が崩れる。構成忘れが「プリフェッチが効かない」という発見しにくい不具合になる
- **C: `ImagePipeline.shared` を常に差し替える** — 却下。アプリが自分で構成したパイプライン (認証ヘッダ・独自キャッシュ) を上書きしてしまう
- **D: `dataCache == nil` を「未構成」とみなし `.withDataCache()` の新規構成で差し替える (初案)** — 却下 (second-opinion-spec-001)。`dataCache` が nil でも独自 DataLoader・delegate を持つ構成はあり得て、それを失う。構成と delegate の引き継ぎで解消した

### Decision 2: Coil の版と Android の依存の置き方 — Coil 3.5.0 に固定し (3.6 系は利用者に compileSdk 37 を要求する)、`api` で公開する

**採用案:** Coil の版は **3.5.0** (2026-06-10、Compose 1.11.1 / compileSdk 36 でビルド) に固定する。3.6.0 以降は Compose 1.12.0 / compileSdk 37 でビルドされ、推移依存 `androidx.compose.foundation:foundation:1.12.0` が利用者アプリに compileSdk 37 を要求する (Compose 1.12.0 のリリースノート)。3.5.0 の推移依存は foundation 1.11.2 で、本体の BOM 2026.06.01 (1.11.4) に吸収され引き上げは起きない。理由は libs.versions.toml のコメントに残す (BOM と同じ扱い)。実装の最初のタスクで、本体 AAR を組んだ後に利用者側 (Sample の compileSdk 36) でビルドが通ることと、Gradle の依存レポートで Compose が 1.11.4 のままであることを確認する (lessons: check-consumer-compile-sdk-before-adopting-latest-dependency)。依存は `coil-compose` を `api` (公開 API に Coil の型は出さないが、利用者が `AsyncImage` を直接使ってキャッシュを共有する経路を ADR-0012 が想定するため、compile classpath に届ける)、`coil-network-okhttp` を `implementation` で置く。iOS は Nuke 13 系の最新 (from: "13.2.0") を `Package.swift` の dependencies に置き、product `Nuke` と `NukeUI` を本体 target に繋ぐ。

**理由:** android-wrapper-foundation で最新 BOM を採用した結果、本体 AAR が利用者に未普及の compileSdk 37 を強いた手戻りがある。Coil 3.6 系はまさに同じ経路 (Compose 1.12 の推移) で compileSdk 37 を強いる (history 2026-09-05 の追加調査: Coil CHANGELOG と Maven module metadata)。ADR-0012 の Revisit When (最低対応 OS を切り上げて追随できなくなったとき) の予兆でもあるので、版の固定理由を残す。`api` で公開するのは、ADR-0012 の「同じローダーの付属ビューを直接使えばキャッシュが共有される」を利用者が追加依存なしで使えるようにするため。

**代替案:**
- **A: Coil の最新版 3.6.2 を採用する (android/ADR-0002「最新安定に追随」)** — 却下。Compose 1.12.0 が推移して利用者に compileSdk 37 を要求する。BOM を 1.11 系に留めた判断 (deviation) と矛盾する
- **B: `coil-compose` を `implementation` にする** — 却下。利用者が `AsyncImage` を直接使うには自分で Coil を依存に足す必要があり、版の不一致 (二重の Coil) の温床になる
- **C: ネットワーク fetcher を利用者に選ばせる (`coil-network-ktor3` も可)** — 却下。ADR-0012 の「入れるだけで効く」に反する。OkHttp は Android の事実上の標準で、v1 はこれ 1 本でよい

### Decision 3: プリフェッチ到達点の実現 — 宣言の `destination` をローダーの取得方針に写像する

**採用案:** `KsPrefetchDestination` (Swift enum `.disk` / `.memory`、Kotlin `KsPrefetchDestination.Disk / Memory`、既定 `.disk`) を `prefetchResources` の任意引数として受け、次のとおり写像する。

| 到達点 | iOS (Nuke `ImagePrefetcher`) | Android (Coil `ImageRequest`) |
|---|---|---|
| disk | `destination: .diskCache` (元データのみ、デコードなし) | `memoryCachePolicy(DISABLED)` + `BlackholeDecoder.Factory()` (ディスクに元データ、デコードなし) |
| memory | `destination: .memoryCache` (元寸をデコードしてメモリへ。ディスクにも元データ) | 既定の `enqueue` (size 未指定 = ORIGINAL でデコードしメモリへ。ディスクにも元データ) |

プリフェッチの要求には縮小処理を付けない (元寸のまま)。優先度は Nuke の既定 (`.low`) のまま。

**寿命モデル (両プラットフォーム共通)**: URL 解決層が「アイテム ID → 解決した URL 集合」と「URL → 参照数」の台帳を持つ。開始はアイテム単位で受け、URL の参照数が 0 → 1 になったときだけローダーへ要求し、取り消しは参照数が 1 → 0 になったときだけローダーへ停止を伝える (複数アイテムが同じ URL を返しても、まだ必要としているアイテムが残る限り止めない)。配列の差し替え時は、新しい配列に無いアイテム ID の要求を台帳から引いて取り消す (iOS はシステムから取り消し通知が来ないため、snapshot 適用時にライブラリが行う)。コレクションの破棄 (iOS は controller の解放、Android はコンポジション離脱) で台帳の全要求を止める。`prefetchResources` クロージャと `destination` は、テンプレート宣言と同じく「表示中に差し替えない前提の宣言」として扱い (concepts core-model/collection-items の契約と同じ)、差し替えは以後の新規要求にだけ効く (進行中の要求は止めない)。

**理由:** agenda 決定「既定はディスク、メモリまでも指定可」の直接の写像。元寸でプリフェッチすれば、Nuke は表示時の縮小付き要求が元寸のメモリ画像を再利用し、Coil は INEXACT 照合で元寸がヒットするため、表示時に確実にキャッシュが効く (history「プリフェッチの宣言と到達点」の調査)。縮小付きでプリフェッチすると `KsImage` の実サイズと一致しない限りミスになる。

**代替案:**
- **A: Android のディスク到達点でデコードを省略しない (`memoryCachePolicy(DISABLED)` のみ)** — 却下。ディスクに置くだけの目的でデコードする CPU が無駄になる。Coil の FAQ が案内する `BlackholeDecoder` の併用が正攻法
- **B: 到達点を宣言ではなくライブラリ全体の設定に置く** — 却下。agenda 決定 (宣言の任意引数)。到達点は「そのコレクションの画像の使い方」で決まり、宣言に付くのが自然
- **C: 台帳を持たず URL 単位で素通しする (初案)** — 却下 (second-opinion-spec-001)。同じ URL を複数アイテムが返すと、一方の取り消しが他方の要求まで止める。配列差し替えで消えたアイテムは iOS のシステム通知では取り消せない

### Decision 4: Android の先読み窓 — 可視範囲の観測から進行方向へ表示件数分の窓を作り、差分でアイテム単位に enqueue / dispose する

**採用案:** `LazyGridState.layoutInfo.visibleItemsInfo` を `snapshotFlow` で観測し、先頭可視 index の変化からスクロール方向を判定する。窓は進行方向へ「現在の可視件数と同数」のアイテム (v1 の既定。利用者設定なし)。窓に新しく入ったアイテムは `prefetchResources` で URL に解決して Coil に `enqueue` (Decision 3 の写像)、窓から外れたアイテムは対応する `Disposable` を `dispose` する。可視範囲内のアイテムは窓に含めない (表示側の `KsImage` が読み込む)。配列の差し替えで消えたアイテムの要求は dispose する。コンポジション離脱時に全 dispose。

**理由:** agenda 決定「自前の先読み窓でアイテム単位に取得・取り消し」の実現形。iOS の `UICollectionView` のプリフェッチも進行方向の先読みなので契約が揃う。Compose Foundation の先読み窓は BOM 2026.06.01 では experimental で、セル合成の先読みのため到達点を制御できない。窓幅の「可視件数と同数」は、画面サイズと列数に比例して自然にスケールし、固定件数より画面差に強い。

**代替案:**
- **A: 固定件数 (例: 20 件) の窓** — 却下。列数と画面高で可視件数が 6〜40 件と変わるため、固定値は小画面で過剰・大画面で不足になる
- **B: 前後両方向に窓を張る** — 却下。戻り方向は表示済みで既にキャッシュにある可能性が高く、取得の無駄が多い。iOS の挙動とも揃わない
- **C: `LazyLayoutPrefetchStrategy` を実装する** — 却下。experimental (opt-in 必須) で、1.13 系で `LazyGridState` 経由の提供が deprecated になる過渡期にある

### Decision 5: `KsImage` の縮小 — iOS はレイアウト後の実サイズで縮小処理を付けて要求し、Android は Coil の制約解決に乗る

**採用案:** iOS の `KsImage` は自身のレイアウトサイズを `onGeometryChange` (iOS 16 では `GeometryReader` 相当の内部実装) で取得し、サイズが確定してから **`ImageRequest.ThumbnailOptions` (デコード時の縮小。`ImageProcessors.Resize` より省メモリ)** を付けて `LazyImage` に要求する。縮小の目標は当てはめ方で決める: `fit` は枠に収まる最大寸法 (`maxPixelSize` = 枠の長辺 × 表示倍率)、`fill` は枠を覆う最小寸法 (枠と画像の縦横比から、短辺側が枠に一致する寸法。デコード後の画像は片方の辺で枠を超え得るが、枠を覆う最小サイズを超えない) にし、はみ出しは SwiftUI 側で `clipped()` する。サイズ未確定 (0) の間は要求せず読み込み中の表示を出す。サイズが変わったら (向き変更等) 新しいサイズで再要求する (メモリ鍵は縮小処理を含むので、旧サイズのキャッシュとは別項目になる)。Android は `AsyncImage` にそのまま渡す (制約からサイズを解決し縮小デコードするのが既定)。`contentMode` / `contentScale` は `.fit` / `.fill` の 2 値 (Swift `KsImageContentMode`、Kotlin `ContentScale` をそのまま受ける — 記法差は core/ADR-0002)。

**理由:** agenda 決定「縮小の既定は自身のレイアウトサイズ」。`LazyImage` に自動縮小が無いためライブラリが補う。`ThumbnailOptions` は `CGImageSource` のサムネイル生成で元寸をメモリに展開せずに縮小でき、Nuke が省メモリ手段として案内している (second-opinion-spec-001 の指摘で `Resize` から変更)。サイズ 0 で要求すると元寸でデコードされてしまう (縮小処理のサイズが 0 だと無効) ので、確定を待つ。

**代替案:**
- **A: セルサイズ (列幅) をライブラリが計算して `KsImage` に渡す** — 却下。`KsImage` がセル全体を占めるとは限らず (サムネイル + テキストの行など)、実サイズと食い違う。実サイズは `KsImage` 自身が一番よく知っている
- **B: 縮小しない (元寸でデコード)** — 却下。グリッドのメモリ対策 (agenda の主目的の 1 つ) が成立しない
- **C: 利用者に縮小サイズを指定させる** — 却下。agenda 決定 (手動指定は持たない)
- **D: `ImageProcessors.Resize` で縮小する (初案)** — 却下 (second-opinion-spec-001)。デコード後の画像処理なので元寸が一度メモリに展開され、グリッドのメモリ対策として劣る

### Decision 6: `KsImageSource` の描画経路 — リモート / ファイルはローダー、iOS のアセットは SwiftUI `Image`

**採用案:** `KsImageSource` は Swift `enum { case remote(URL), file(URL), asset(String) }`、Kotlin `sealed interface { Remote(String), File(java.io.File), Resource(@DrawableRes Int) }`。描画経路は次のとおり。

| ソース | iOS | Android |
|---|---|---|
| remote | `LazyImage` (Nuke、Decision 5 の縮小付き) | `AsyncImage` (Coil) |
| file | `LazyImage` (`file://` URL を Nuke がそのまま扱う) | `AsyncImage` (`File` を Coil がそのまま扱う) |
| asset / resource | SwiftUI `Image(name)` を `resizable()` で当てはめ方に従わせる (Nuke を通さない) | `AsyncImage` (リソース ID を Coil がそのまま扱う) |

`KsImage(url)` は `KsImage(.remote(url))` の便宜初期化子。

**公開シグネチャ (両プラットフォーム。core/ADR-0002 の「パラメータ名は 1 対 1」に従い、当てはめ方は共通の値型 `KsImageContentMode` で揃える)**:

```swift
public struct KsImage<Loading: View, Failure: View>: View {
    public init(_ source: KsImageSource, contentMode: KsImageContentMode = .fill,
                @ViewBuilder loading: () -> Loading, @ViewBuilder failure: () -> Failure)
    public init(_ source: KsImageSource, contentMode: KsImageContentMode = .fill)   // 既定表示
    public init(_ url: URL, contentMode: KsImageContentMode = .fill, ...)          // 便宜形
}
public enum KsImageContentMode { case fit, fill }
public enum KsImageSource: Hashable { case remote(URL), file(URL), asset(String) }
public enum KsPrefetchDestination { case disk, memory }
extension KsCollectionView { public func prefetchResources(destination: KsPrefetchDestination = .disk, _ resolve: @escaping (Item) -> [URL]) -> Self }
```

```kotlin
@Composable public fun KsImage(
    source: KsImageSource, modifier: Modifier = Modifier, contentDescription: String? = null,
    contentMode: KsImageContentMode = KsImageContentMode.Fill,
    loading: (@Composable () -> Unit)? = null, failure: (@Composable () -> Unit)? = null,
)
@Composable public fun KsImage(url: String, ...)   // 便宜形
public enum class KsImageContentMode { Fit, Fill }
public sealed interface KsImageSource { data class Remote(val url: String); data class File(val file: java.io.File); data class Resource(@DrawableRes val id: Int) }
public enum class KsPrefetchDestination { Disk, Memory }
// KsCollectionView の引数: prefetchResources: ((Item) -> List<String>)? = null, prefetchDestination: KsPrefetchDestination = KsPrefetchDestination.Disk
```

Kotlin 側の `prefetchDestination` は、フラットな名前付き引数で `destination` だけでは何の到達点か読めないため接頭辞を付ける (`touchFeedback(color:)` ⇔ `touchFeedbackColor` と同じ扱い。宣言構造の対応は保つ)。Android の `contentDescription` は Compose の画像コンポーネントの慣例 (アクセシビリティ) で、iOS は `accessibilityLabel` modifier を利用者が付ける流儀 (記法差)。

**Android のスロットの実現**: `AsyncImage` の `placeholder` / `error` は `Painter` しか受けず、Composable スロットを持つ `SubcomposeAsyncImage` は Lazy 系で遅いと公式が注意している。よって `KsImage` は `rememberAsyncImagePainter` + `rememberConstraintsSizeResolver()` (制約からのサイズ解決を保つ) で読み込み状態を観測し、状態に応じてスロットの Composable を自前で切り替える (`SubcomposeAsyncImage` は使わない)。`KsImage(source)` の読み込み中・失敗時のスロットは remote / file で有効、asset / resource では読み込みが同期のため読み込み中は出ず、存在しない名前は失敗表示になる。

**理由:** agenda 決定「ソース型を導入」の実現形。iOS のアセットカタログは Nuke の守備範囲外で、SwiftUI `Image` が OS のキャッシュに乗る最短経路。Android はリソースも Coil が扱えるので経路を分けない。

**代替案:**
- **A: iOS のアセットも Nuke に流す (`UIImage(named:)` → `ImageRequest(id:data:)`)** — 却下。同期で取れるものを非同期経路に通す意味がなく、OS のアセットキャッシュと Nuke のメモリに二重に載る
- **B: `KsImageSource` にプラットフォーム共通の `Data` / `ByteArray` ケースも足す** — 却下。用途が見えず (agenda で要望なし)、v1 では持たない。必要なら後から追加できる
- **C: Android の当てはめ方を Compose の `ContentScale` で受ける (初案)** — 却下 (second-opinion-spec-001)。パラメータ名と値の語彙が iOS と揃わず core/ADR-0002 に反する。内部で `ContentScale.Fit / Crop` に写像する
- **D: Android のスロットを `Painter` に限定する** — 却下。iOS の `ViewBuilder` スロットと非対称になり、読み込み中に文言やインジケータを置く利用形が Android だけ書けない
- **E: `SubcomposeAsyncImage` でスロットを実現する** — 却下。Lazy 系での性能低下を公式が注意している

### Decision 7: `KsImageCache` の写像 — ローダーのキャッシュ操作の薄い包み

**採用案:** `KsImageCache.clear(scope)` (`.memory` / `.disk` / `.all`) と `KsImageCache.remove(source)` を両プラットフォーム同名で提供する。

| 操作 | iOS (Nuke `ImagePipeline.shared`) | Android (Coil `SingletonImageLoader`) |
|---|---|---|
| clear(.memory) | `cache.removeAll(caches: [.memory])` | `memoryCache?.clear()` |
| clear(.disk) | `cache.removeAll(caches: [.disk])` | `diskCache?.clear()` |
| clear(.all) | 両方 | 両方 |
| remove(remote / file) | `cache.removeCachedImage(for:)` (縮小処理付き鍵は全処理分) + `cache.removeCachedData(for:)` | `memoryCache?.remove(Key)` + `diskCache?.remove(url)` |
| remove(asset) | no-op (Nuke を通らない) | `memoryCache?.remove(Key)` (resource) |

iOS の `remove` は「同じ URL のあらゆる縮小サイズのメモリ項目」に二度と当たらないようにする必要がある。Nuke のメモリ鍵は縮小オプションを含み、ライブラリはどのサイズで要求したかを後から列挙できない。そこで **ソースごとの世代番号でキャッシュ識別子を切り替える**: `remove(source)` はそのソースの世代を進め、以後の `KsImage` とプリフェッチの要求は `ImageRequest.userInfo[.imageIdKey]` に「URL + 世代」を入れて発行する (世代 0 = 一度も消していないソースは素の URL のまま。ローダー付属ビューとの共有を保つ)。過去の世代の項目 (あらゆるサイズ) には二度と当たらず、メモリの旧項目は LRU で追い出される。ディスクの元データは `remove` 時に素の URL と現世代の識別子の両方で消す。覚える状態は「消されたソース → 世代」の写像だけで、`remove` の回数に比例する小さなもの。Android は Coil のメモリ鍵が URL で引けるため世代は不要で、`memoryCache.remove` / `diskCache.remove` で直接消す。

限界 (spec と concepts に書く): `remove` したソースは以後 `KsImage` 側の識別子が変わるため、利用者がローダー付属ビュー (`LazyImage`) で同じ URL を直接使っている場合、その側とはキャッシュが共有されなくなる (直接使いの側は LRU で追い出されるまで古い画像が出得る)。`clear` は識別子を変えないので共有に影響しない。

**表示中の `KsImage` の無効化**: `clear` / `remove` はローダーのキャッシュを消すだけでは表示中のビューが持つ画像を置き換えない。`KsImageCache` は世代番号 (iOS: `@Observable` な共有オブジェクト、Android: `mutableStateOf`) を持ち、`clear(.all / .disk)` と `remove` は該当する `KsImage` (全体、またはそのソース) の世代を進める。`KsImage` は世代を読み、進んだら読み込み中の表示に戻して再要求する。`clear(.memory)` は世代を進めない (表示中の画像はそのまま。次の表示でディスクから再デコード)。`clear` / `remove` は同期的にキャッシュを消してから世代を進め、戻った時点で「以後の要求はキャッシュに当たらない」ことが保証される。

**理由:** agenda 決定「範囲付き全消去 + ソース単位の削除」の実現形。Coil は URL 鍵でメモリ項目を消せるが、Nuke は鍵が縮小オプション込みで列挙できない。世代付き識別子なら「消したら確実に消えたように見える」が状態を増やさずに成立する (オーナーの選択: 消去の確実さを、消したソースに限った共有の喪失より優先)。

**代替案:**
- **A: iOS の `remove` は元データ (ディスク) だけ消し、メモリは触らない** — 却下。差し替わった画像が表示中の画面に古いまま残る (メモリヒットが続く)
- **B: Nuke のメモリ鍵を URL のみにする (`ImageRequest` の `userInfo[.imageIdKey]` でサイズを鍵から外す)** — 却下。サイズ違いの画像が同じ鍵で衝突し、小さい縮小画像が大きな枠に返る
- **C: `remove` のメモリ消去を全消去で代用する** — 却下 (agenda)
- **D: 弱参照の台帳 (初案)** — 却下 (second-opinion-spec-001)。表示ビューが破棄されるとキャッシュに残る鍵を列挙できない
- **E: 上限なしの台帳** — 却下。1 万件のグリッドを走査すると台帳が増え続け、メモリの定常化 (performance-verification) を損なう
- **F: 上限付き LRU の台帳 (第 2 案)** — 却下 (オーナー判断)。台帳から落ちた鍵の項目が残り、`remove` 後に古い画像が出る窓が残る

### Decision 8: 検査用の受け口 — ローダー操作を internal な 1 段の境界に集め、テストは差し替えて記録する

**採用案:** ローダーへの操作を internal な境界 (iOS `KsImageLoading` protocol: `prefetch(urls:destination:)` / `cancel(urls:)`、Android `KsImageLoading` interface: `enqueue(url, destination): Disposable` 相当) に集め、既存の `KsPrefetching` (アイテム単位) の実装がこの境界を呼ぶ。本番は Nuke / Coil の adapter、テストは記録用の fake を注入する (iOS は `KsCollectionConfiguration` 経由、Android は `CompositionLocal` または内部引数)。テストは (1) 可視範囲の先のアイテムが URL に解決されて到達点付きで開始されること、(2) 離れたアイテムが取り消されること、(3) 配列差し替えで消えたアイテムが取り消されること、(4) 宣言が無ければ何も起きないことを、ローダーの実 I/O なしで確かめる。`KsImage` の縮小は、iOS は要求された `ImageRequest` の processors をテストダブルで観測、Android は Coil の `AsyncImage` の既定に乗るため縮小自体はテストせず、ソース種別ごとの経路 (どの model を渡したか) を観測する。

**キャッシュ契約の統合テスト**: 受け口の fake で判定できるのは「到達点付きで開始・取り消しが伝わった」ことまで。「ディスク到達点の後にネットワークが走らない」「メモリ到達点の後に再デコードしない」「ローダー付属ビューと共有できる」「ソース単位の削除で対象だけ消える」は実 Nuke / Coil のキャッシュ鍵とデコーダの挙動に依存するため、**取得回数・デコード回数を数えられる制御可能な取得層を差し込んだ実ローダー**で統合テストする。iOS はテスト専用の `ImagePipeline` (DataLoader を `URLProtocol` スタブに差し替え、デコード回数を数える `ImageDecoding` を登録) を受け口経由で注入し、Android は `ImageLoader.Builder` にカウンタ付きの `Fetcher.Factory` / `Decoder.Factory` を登録したテスト用ローダーを注入する。テストは Simulator / Robolectric で決定的に走る (ネットワークなし)。

**理由:** agenda 決定「配線は自動テスト」の実現形。既存テスト `ios/Tests/KsCollectionViewTests/KsPrefetcherTests.swift` が同じ型 (記録用 fake) で書かれており、その延長で書ける。外部ネットワークを伴うテストは遅く不安定なので、取得層をスタブした実ローダーで契約を判定する (second-opinion-spec-001 の指摘で追加)。

**代替案:**
- **A: 実ローダー + ローカル HTTP サーバでエンドツーエンドにテストする** — 却下。テスト実行規約 (handbook/cross/test-execution.md) の範囲を超える重さで、契約の検証に I/O は不要
- **B: 受け口を public にして利用者にも差し替えを許す** — 却下。ADR-0012 で却下したローダー抽象の再導入になる

## Risks / Trade-offs

- `ImagePipeline.shared` の差し替え (Decision 1) はアプリ全体に影響する。アプリが後から `ImagePipeline.shared` を構成し直すと本体の初回設定は上書きされるが、それはアプリの意図として尊重する (ディスクキャッシュを外せばプリフェッチのディスク到達点が効かなくなる。concepts に明記)
- Android の先読み窓 (Decision 4) はスクロール中の `snapshotFlow` 観測と集合差分がフレームに乗る。handbook/android/performance-verification の**全系統** (相対 P90/P99・絶対 frameOverrun・メモリ定常化と 1,000 件対 10,000 件、各 3 試行) を既存の固定 fixture (「大量件数」画面、宣言なし) で回帰計測し、宣言なしのときは観測自体を起動しない。宣言ありの負荷はプリフェッチ機能そのもののコストなので相対基準では測らず (比較対象に同等機能が無い)、画像グリッドの固定 fixture で絶対基準 (frameOverrun P99) とメモリ定常化で評価する。iOS はエンジンの描画・再利用・レイアウト経路に触れない (プリフェッチ配線は既存、`KsImage` はセル content) が、画像グリッド fixture で hitch time ratio (3 試行) とメモリ定常化を計測する
- `remove` したソース (Decision 7) は以後 `KsImage` の識別子が世代付きになり、利用者が `LazyImage` で直接使う同じ URL とはキャッシュが共有されなくなる (concepts に限界として明記。`clear` は影響しない)
- Coil の版固定 (Decision 2: 3.5.0) は 3.6 系以降の機能・修正を取り込めない期間を生む。利用者に推移する OkHttp は 4.12.0。利用者側の compileSdk 普及に合わせて上げる (android/ADR-0002 の運用)
- デモ画像の公開サービスはネットワーク環境に依存する。実機計測はオンラインで行い、オフラインではプレースホルダー表示の確認だけになる

## Migration Plan

- 破壊的変更なし。既存の利用コードは影響を受けない
- iOS: `Package.swift` に Nuke の依存を足す。Sample は既存の本体参照のまま (依存は推移)
- Android: libs.versions.toml に Coil の版を足し、本体に `api(coil-compose)` / `implementation(coil-network-okhttp)`。Sample の `INTERNET` permission を追加 (デモ画像の取得)
- 既存の internal な `KsPrefetching` / `KsAnyPrefetcher` は残し、その実装として URL 解決 + 受け口呼び出しの層を足す

## Open Questions

- Coil 3.5.0 の実 AAR の `aar-metadata.properties` は未確認 (ネットワーク制約で module metadata と CHANGELOG からの確認)。実装の最初のタスクで Sample (compileSdk 36) のビルドと依存レポートで裏を取る
- Android の `KsImageSource.File` に `java.io.File` を採るか `Uri` も受けるか — v1 は `File` のみ。`Uri` (content://) の需要が出たら追加

## ADR 候補

- Decision 1 (共有パイプラインの初回差し替え): core/ADR-0012 (proposed) の Decision に「iOS はディスクキャッシュ未設定なら初回利用時に有効化した構成で `ImagePipeline.shared` を差し替える」を追記して accepted 化する候補。単独 ADR にはしない (ADR-0012 の帰結)
- Decision 2 (Coil の版固定): 実 AAR が compileSdk 37 を要求し版を下げた場合、android/ADR-0002 の「最新安定に追随」の読み替えとして deviation.md と libs.versions.toml のコメントに残す (BOM と同じ扱い)。ADR 化は不要
- Decision 4 (先読み窓の既定「進行方向へ可視件数分」): 覆すコストは低い (内部定数)。ADR 化は不要。concepts に契約として書く
- Decision 7 (`remove` の世代付き識別子と、`clear` / `remove` による表示中ビューの無効化): ADR 化は不要。concepts に限界 (消したソースの共有喪失) と挙動を書く
