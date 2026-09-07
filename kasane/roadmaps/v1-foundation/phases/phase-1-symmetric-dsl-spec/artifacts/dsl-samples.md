# 対称 DSL サンプルコード (利用側視点)

phase-1 の全決定 (core/ADR-0002〜0009) を反映した、公開 API 形状を固めるための両言語対比サンプル。
左右で「宣言の並びが1対1対応し、記法だけが流儀で異なる」ことを検証する (ADR-0002)。

命名はこのサンプルをもって仕様候補とする。変更する場合はこのファイルを更新する。

---

## 1. 基本リスト (単一型・タップ)

ADR-0003 (配列 + 安定 ID) / ADR-0004 (テンプレート登録) / ADR-0006 (layout 値) / ADR-0009 (onItemTap)。

```swift
struct Fruit: Identifiable, Equatable {
    let id: String
    let name: String
}

struct FruitList: View {
    let fruits: [Fruit]

    var body: some View {
        KsCollectionView(
            fruits,
            layout: .list(rowSpacing: 4),
            contentPadding: EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        ) { fruit in
            Text(fruit.name)
        }
        .header { Text("果物") }
        .footer { Text("全 \(fruits.count) 件") }
        .onItemTap { (fruit: Fruit) in print("tapped: \(fruit.name)") }
        .touchFeedback(color: .yellow)   // 省略時はプラットフォーム標準のハイライト
    }
}
```

```kotlin
data class Fruit(val id: String, val name: String)

@Composable
fun FruitList(fruits: List<Fruit>) {
    KsCollectionView(
        items = fruits,
        key = { it.id },
        layout = KsLayout.List(rowSpacing = 4.dp),
        contentPadding = PaddingValues(
            top = 8.dp,
            start = 16.dp,
            bottom = 8.dp,
            end = 16.dp,
        ),
        header = { Text("果物") },
        footer = { Text("全 ${fruits.size} 件") },
        onItemTap = { fruit: Fruit -> println("tapped: ${fruit.name}") },
        touchFeedbackColor = Color.Yellow,   // 省略時は標準 ripple
    ) {
        template { fruit ->
            Text(fruit.name)
        }
    }
}
```

対称性チェック: `items` / `layout` / `contentPadding` / テンプレート / header / footer / `onItemTap` / フィードバック色 — 語彙8点が1対1。
ID 宣言だけ流儀差 (Swift: `Identifiable` 準拠 / Kotlin: `key` ラムダ)。

Swift でも KMP 共有モデルなど `Identifiable` に準拠しない型は、専用 protocol を追加せず `id:` で安定 ID を指定できる。

```swift
struct SharedFruit: Equatable {
    let itemId: String
    let name: String
}

KsCollectionView(sharedFruits, id: \.itemId) { fruit in
    Text(fruit.name)
}
```

list の区切り線は既定で表示される。非表示にする場合だけ `.listSeparators(false)` を指定し、grid では指定にかかわらず表示されない。

色を変える場合は表示の有無とは独立した語彙で指定する。未指定ならライブラリ既定の色になる。

```swift
KsCollectionView(fruits) { fruit in
    Text(fruit.name)
}
.listSeparatorColor(.blue)
```

```kotlin
KsCollectionView(
    items = fruits,
    key = { it.id },
    listSeparatorColor = Color.Blue,
) {
    template { fruit -> Text(fruit.name) }
}
```

## 2. 値キーによるセル切り替え + 向き可変グリッド

ADR-0004 (複数テンプレート) / ADR-0006 (向き別列数)。

```swift
struct FeedItem: Identifiable, Equatable {
    enum Kind: Hashable { case message, ad }

    let id: String
    let kind: Kind
    let text: String
}

struct FeedScreen: View {
    let items: [FeedItem]

    var body: some View {
        KsCollectionView(
            items,
            template: \.kind,
            layout: .grid(
                columns: .fixed(portrait: 2, landscape: 4),
                rowSpacing: 8,
                columnSpacing: 8
            )
        ) {
            KsTemplate(.message) { item in MessageCard(item) }
            KsTemplate(.ad) { item in AdCard(item) }
        }
    }
}
```

```kotlin
enum class FeedKind { Message, Ad }
data class FeedItem(val id: String, val kind: FeedKind, val text: String)

@Composable
fun FeedScreen(items: List<FeedItem>) {
    KsCollectionView(
        items = items,
        key = { it.id },
        template = { it.kind },
        layout = KsLayout.Grid(
            columns = KsColumns.Fixed(portrait = 2, landscape = 4),
            rowSpacing = 8.dp,
            columnSpacing = 8.dp,
        ),
    ) {
        template(FeedKind.Message) { item -> MessageCard(item) }
        template(FeedKind.Ad) { item -> AdCard(item) }
    }
}
```

型ベースの混在配列は v1 の対象外。単一の要素型に enum 等の値キーを持たせてテンプレートを切り替える。未登録キーは debug では assertion、release では最小高の空セルと警告ログになる。

テンプレートキーはセルの表示種別を表す**有限集合**にする。item の ID や毎要素で異なる値をキーにすると、キーごとにセルの再利用種別が作られてセルの再利用が働かなくなる。

## 3. 無限スクロール + Pull to Refresh

ADR-0005 (利用者所有の5状態 enum)。VM の状態遷移が両言語でほぼ同一 = KMP 共有可能な構造。

```swift
@Observable
final class FeedViewModel {
    var items: [Message] = []
    var pagingState: KsPagingState = .idle

    func loadNextPage() async {
        guard pagingState == .idle else { return }
        pagingState = .appending
        do {
            let page = try await api.fetch(after: items.last?.id)
            items += page.items
            pagingState = page.hasMore ? .idle : .endReached
        } catch {
            pagingState = .failed
        }
    }

    func refresh() async {
        pagingState = .refreshing
        do {
            let page = try await api.fetch(after: nil)
            items = page.items
            pagingState = page.hasMore ? .idle : .endReached
        } catch {
            pagingState = .failed
        }
    }
}

struct FeedList: View {
    @State var vm = FeedViewModel()

    var body: some View {
        KsCollectionView(vm.items, layout: .list) { msg in MessageRow(msg) }
        .paging(vm.pagingState) { await vm.loadNextPage() }
        .refreshable { await vm.refresh() }
    }
}
```

```kotlin
class FeedViewModel : ViewModel() {
    var items by mutableStateOf(listOf<Message>())
        private set
    var pagingState by mutableStateOf(KsPagingState.Idle)
        private set

    fun loadNextPage() {
        if (pagingState != KsPagingState.Idle) return
        pagingState = KsPagingState.Appending
        viewModelScope.launch {
            runCatching { api.fetch(after = items.lastOrNull()?.id) }
                .onSuccess { page ->
                    items = items + page.items
                    pagingState = if (page.hasMore) KsPagingState.Idle else KsPagingState.EndReached
                }
                .onFailure { pagingState = KsPagingState.Failed }
        }
    }

    fun refresh() { /* 同様に Refreshing を経由して先頭から取り直す */ }
}

@Composable
fun FeedList(vm: FeedViewModel) {
    KsCollectionView(
        items = vm.items,
        key = { it.id },
        layout = KsLayout.List,
        paging = KsPaging(state = vm.pagingState, onLoadMore = vm::loadNextPage),
        onRefresh = vm::refresh,   // Compose 側の Pull to Refresh 接続 (最終形は phase-3 で流儀確認)
    ) {
        template { msg -> MessageRow(msg) }
    }
}
```

ライブラリの責務 (ADR-0005): 末尾近傍でのコールバック発火・多重発火抑止・状態別フッター (appending → ローディング / failed → リトライ / endReached → 終端。テンプレート差し替え可)・Pull to Refresh と refreshing の接続。

## 4. スクロール制御

ADR-0007 / ADR-0009 (`scrollToStart` / `scrollToEnd`)。

### 4a. View 所有 (ドキュメント標準レシピ)

```swift
struct ProductGrid: View {
    let products: [Product]
    @State private var scroller = KsScrollController()

    var body: some View {
        KsCollectionView(products, layout: .grid(columns: .adaptive(minItemWidth: 120))) {
            ProductCard($0)
        }
        .scrollController(scroller)
        .toolbar {
            Button("先頭へ") { scroller.scrollToStart(animated: true) }
        }
    }
}
```

```kotlin
@Composable
fun ProductGrid(products: List<Product>) {
    val scroller = rememberKsScrollController()

    Scaffold(
        floatingActionButton = {
            FloatingActionButton(onClick = { scroller.scrollToStart(animated = true) }) {
                Icon(Icons.Default.ArrowUpward, contentDescription = "先頭へ")
            }
        },
    ) { padding ->
        KsCollectionView(
            items = products,
            key = { it.id },
            layout = KsLayout.Grid(KsColumns.Adaptive(minItemWidth = 120.dp)),
            scrollController = scroller,
            modifier = Modifier.padding(padding),
        ) {
            template { p -> ProductCard(p) }
        }
    }
}
```

### 4b. VM 所有 (新着で末尾へ)

```swift
@Observable
final class ChatViewModel {
    var items: [Message] = []
    let scroller = KsScrollController()   // plain オブジェクトなので VM が所有できる

    func onNewMessageReceived(_ msg: Message) {
        items.append(msg)
        scroller.scrollToEnd(animated: true)   // データ反映後に実行される (順序保証はライブラリ責務)
    }
}
```

```kotlin
class ChatViewModel : ViewModel() {
    var items by mutableStateOf(listOf<Message>())
        private set
    val scroller = KsScrollController()

    fun onNewMessageReceived(msg: Message) {
        items = items + msg
        scroller.scrollToEnd(animated = true)
    }
}
```

命令語彙 (両言語同形): `scrollTo(id:position:animated:)` (position: start / center / end) / `scrollToStart(animated:)` / `scrollToEnd(animated:)`。未接続時は no-op。

## 5. 画像グリッド + プリフェッチ

ADR-0008 (`prefetchResources` + `KsImage` の対)。

```swift
struct PhotoGrid: View {
    let photos: [Photo]

    var body: some View {
        KsCollectionView(photos, layout: .grid(columns: .fixed(portrait: 3, landscape: 5))) { photo in
            // プリフェッチと同一ローダ・キャッシュ。ソースは URL の便宜形でも書ける
            KsImage(.remote(photo.thumbnailURL), contentMode: .fill)
        }
        .prefetchResources(destination: .memory) { (photo: Photo) in [photo.thumbnailURL] }
    }
}
```

```kotlin
@Composable
fun PhotoGrid(photos: List<Photo>) {
    KsCollectionView(
        items = photos,
        key = { it.id },
        layout = KsLayout.Grid(KsColumns.Fixed(portrait = 3, landscape = 5)),
        prefetchResources = { photo: Photo -> listOf(photo.thumbnailUrl) },
        prefetchDestination = KsPrefetchDestination.Memory,
    ) {
        template { photo ->
            // プリフェッチと同一ローダ・キャッシュ。ソースは URL の便宜形でも書ける
            KsImage(KsImageSource.Remote(photo.thumbnailUrl), contentMode = KsImageContentMode.Fill)
        }
    }
}
```

到達点の既定はディスクまで。iOS はディスクのキャッシュが既定では働かないため、アプリの起動時に
`KsImagePipeline.enableSharedDiskCache()` を一度呼ぶ (Android は既定で働くため呼び出し不要)。

```swift
@main
struct PhotoApp: App {
    init() {
        KsImagePipeline.enableSharedDiskCache()
    }

    var body: some Scene {
        WindowGroup { PhotoGrid(photos: photos) }
    }
}
```

## 6. ソート切替 (レシピ — DSL に専用 API なし)

ADR-0003 の自動差分により、配列を並べ替えて差し替えるだけで移動アニメが付く。

```swift
@Observable
final class RankingViewModel {
    private var source: [Product] = []
    var sortOrder: SortOrder = .byName { didSet { apply() } }
    private(set) var items: [Product] = []

    private func apply() {
        items = switch sortOrder {
        case .byName:  source.sorted { $0.name < $1.name }
        case .byPrice: source.sorted { $0.price < $1.price }
        }
    }
}
```

```kotlin
class RankingViewModel : ViewModel() {
    private var source = listOf<Product>()
    var sortOrder by mutableStateOf(SortOrder.ByName)
        private set

    val items: List<Product>
        get() = when (sortOrder) {
            SortOrder.ByName -> source.sortedBy { it.name }
            SortOrder.ByPrice -> source.sortedBy { it.price }
        }

    fun changeSort(order: SortOrder) { sortOrder = order }
}
```

---

## 公開語彙一覧 (このサンプルから抽出)

| 語彙 | Swift | Kotlin | 出典 ADR |
|---|---|---|---|
| コンポーネント | `KsCollectionView(_:layout:)` | `KsCollectionView(items, key, layout, ...)` | 0002 |
| テンプレート登録 | `KsTemplate(_:)` (値キー) / 単一クロージャ | `template(key) { }` / 単一クロージャ | 0004 |
| レイアウト | `.list` / `.list(rowSpacing:)` / `.grid(columns:rowSpacing:columnSpacing:)` | `KsLayout.List(rowSpacing =)` / `KsLayout.Grid(columns =, rowSpacing =, columnSpacing =)` | 0006 |
| 列指定 | `.fixed(_)` / `.fixed(portrait:landscape:)` / `.adaptive(minItemWidth:)` | `KsColumns.Fixed(...)` / `KsColumns.Adaptive(...)` | 0006 |
| 余白・区切り線 | `contentPadding:` / `.listSeparators(_)` / `.listSeparatorColor(_)` | `contentPadding =` / `listSeparators =` / `listSeparatorColor =` | 0006, 0010 |
| ルート補助表示 | `.header { }` / `.footer { }` | `header =` / `footer =` | 0006 |
| ページング | `.paging(_:onLoadMore:)` + `KsPagingState` | `paging = KsPaging(state, onLoadMore)` + `KsPagingState` | 0005 |
| スクロール | `KsScrollController` + `.scrollController(_)` | `KsScrollController` / `rememberKsScrollController()` + `scrollController =` | 0007, 0009 |
| タップ | `.onItemTap { }` / `.onItemLongTap { }` / `.touchFeedback(color:)` | `onItemTap =` / `onItemLongTap =` / `touchFeedbackColor =` | 0009 |
| 画像 | `.prefetchResources(destination:_:)` + `KsImage(_:contentMode:)` | `prefetchResources =` / `prefetchDestination =` + `KsImage(source, contentMode =)` | 0008 |
| 画像の取得元・到達点 | `KsImageSource` (`.remote` / `.file` / `.asset`) / `KsPrefetchDestination` (`.disk` / `.memory`) / `KsImageContentMode` (`.fit` / `.fill`) | `KsImageSource` (`Remote` / `File` / `Resource`) / `KsPrefetchDestination` (`Disk` / `Memory`) / `KsImageContentMode` (`Fit` / `Fill`) | 0008 |

## 実装フェーズへの申し送り

- Compose の Pull to Refresh 接続の最終形 (`onRefresh` 引数 vs 標準 `PullToRefreshBox` との住み分け) — phase-3
- `KsPagingState.failed` にエラー内容を持たせるか — phase-5 (ADR-0005 残課題)
- `LoadMoreMargin` 相当 (発火しきい値設定) — phase-5
- グループ化・sticky ヘッダの DSL — phase-4 (旧語彙の申し送りは core/ADR-0009)

## iOS セル再利用の注意

iOS はセルが再利用されるたびに SwiftUI のホスティング内容を作り直すため、テンプレート内部の `@State` は画面外へのスクロールと再利用をまたいで保持されない。展開状態や選択状態など、残す必要がある値は項目モデルまたは画面の状態へ持たせる。

`id:` / `template:` の指定と `KsTemplate` の登録集合は、表示中に差し替えない前提の宣言として扱う。項目の配列が同じままこれらだけを差し替えても、その変更は表示へ反映されない。

## Android `key` の型の制約

`key` ラムダが返す値は、同じ配列の中で一意であることに加えて、**Android の状態保存 (Bundle) に載せられる型**でなければならない。Compose の Lazy 系は項目の識別に使う値をそのまま保存対象にするためで、載せられない型を返すと画面の再生成をまたいだ位置の復元が成り立たない。

| 使える | 使えない |
|---|---|
| `String` / `Char` / `Boolean` / 数値 / enum / `Serializable` / `Parcelable` を実装した型 | 上のいずれにも当たらない独自クラス (`data class` であっても該当しない) |

違反は不正入力として扱う。debug ビルドでは assertion で停止し、release ビルドでは警告ログを残して表示を続ける (core/ADR-0011 の「落とさず・消さず・黙らず」)。要素そのものを `key` に返す書き方は避け、ID となるプロパティを返す。

## Android テンプレート内の state の保持

Compose の Lazy 系は、可視範囲と先読み分の外へ出た項目のコンポジションを破棄する。**画面外へ十分に送った項目のテンプレート内の `remember` は、戻ってきたときに初期値へ戻っている。** 展開状態・選択状態など残す必要がある値は、項目モデルまたは画面の状態へ持たせる (iOS のセル再利用と同じ結論に、別の理由で行き着く)。

破棄と作り直しは実測でも確かめられている。10,000 件の画面でテンプレートの評価回数を数えると、初期表示は可視範囲の 22 回に留まり、371 件目付近まで送った時点の累計は 394 回 — 通過した項目の数とほぼ同数になる。範囲外へ出た項目は保持されず、戻ってくるときに作り直される。

`remember` 自体が無効なわけではない。可視範囲にいる間は保たれ、同じ ID・同じテンプレートキーのまま内容だけが変わる更新では作り直されない。保持されないのは「画面外へ十分に出て戻る」往復をまたいだときである。

## Android 行の高さ変化のアニメーション

行の高さが変わるとき (展開・折りたたみ) はライブラリが高さを補間し、後続の行もそれに追従して動く。補間中は**テンプレートの根の Composable に高さの制約が渡る**ため、根が `fillMaxWidth().background(...)` のように制約を使って背景を塗っていれば、背景も行の枠に追従して縮む。根が透明な箱 (`Box` / `Column` など制約を子へ渡さないもの) で本体を包んでいると、折りたたみの途中で箱と本体の間にページ背景が見える。本体へ制約を届けるには箱に `propagateMinConstraints = true` を付けるか、根で背景を塗る。
