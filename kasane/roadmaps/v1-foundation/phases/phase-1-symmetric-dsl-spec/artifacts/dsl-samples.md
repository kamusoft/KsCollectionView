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
        KsCollectionView(fruits, layout: .list) {
            Template(for: Fruit.self) { fruit in
                Text(fruit.name)
            }
        }
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
        layout = KsLayout.List,
        onItemTap = { fruit: Fruit -> println("tapped: ${fruit.name}") },
        touchFeedbackColor = Color.Yellow,   // 省略時は標準 ripple
    ) {
        template<Fruit> { fruit ->
            Text(fruit.name)
        }
    }
}
```

対称性チェック: `items` / `layout` / テンプレート / `onItemTap` / フィードバック色 — 語彙5点が1対1。
ID 宣言だけ流儀差 (Swift: `Identifiable` 準拠 / Kotlin: `key` ラムダ)。

## 2. 異種セル + 向き可変グリッド

ADR-0004 (複数テンプレート) / ADR-0006 (向き別列数)。

```swift
struct FeedScreen: View {
    let items: [any Identifiable]   // Message と AdBanner が混在 (実型の表現は実装フェーズで確定)

    var body: some View {
        KsCollectionView(items, layout: .grid(columns: .fixed(portrait: 2, landscape: 4))) {
            Template(for: Message.self) { msg in MessageCard(msg) }
            Template(for: AdBanner.self) { ad in AdCard(ad) }
        }
    }
}
```

```kotlin
@Composable
fun FeedScreen(items: List<Any>) {   // Message と AdBanner が混在 (実型の表現は実装フェーズで確定)
    KsCollectionView(
        items = items,
        key = { it.stableId },       // 混在型の ID 取り出し方は実装フェーズで確定
        layout = KsLayout.Grid(KsColumns.Fixed(portrait = 2, landscape = 4)),
    ) {
        template<Message> { msg -> MessageCard(msg) }
        template<AdBanner> { ad -> AdCard(ad) }
    }
}
```

**申し送り (phase-2/3)**: 混在配列の要素型と安定 ID の取り出し方 (Swift `any Identifiable` の制約 / Kotlin マーカー interface の要否) は基盤実装で確定する。未登録型が現れた場合の挙動 (debug 警告 + 空セル等) も同時に決める (ADR-0004 の残課題)。

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
        KsCollectionView(vm.items, layout: .list) {
            Template(for: Message.self) { msg in MessageRow(msg) }
        }
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
        template<Message> { msg -> MessageRow(msg) }
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
            Template(for: Product.self) { p in ProductCard(p) }
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
            template<Product> { p -> ProductCard(p) }
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
        KsCollectionView(photos, layout: .grid(columns: .fixed(portrait: 3, landscape: 5))) {
            Template(for: Photo.self) { photo in
                KsImage(photo.thumbnailURL)   // プリフェッチと同一ローダ・キャッシュ
            }
        }
        .prefetchResources { (photo: Photo) in [photo.thumbnailURL] }
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
    ) {
        template<Photo> { photo ->
            KsImage(photo.thumbnailUrl)
        }
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
| テンプレート登録 | `Template(for:)` | `template<T> { }` | 0004 |
| レイアウト | `.list` / `.grid(columns:)` | `KsLayout.List` / `KsLayout.Grid(...)` | 0006 |
| 列指定 | `.fixed(_)` / `.fixed(portrait:landscape:)` / `.adaptive(minItemWidth:)` | `KsColumns.Fixed(...)` / `KsColumns.Adaptive(...)` | 0006 |
| ページング | `.paging(_:onLoadMore:)` + `KsPagingState` | `paging = KsPaging(state, onLoadMore)` + `KsPagingState` | 0005 |
| スクロール | `KsScrollController` + `.scrollController(_)` | `KsScrollController` / `rememberKsScrollController()` + `scrollController =` | 0007, 0009 |
| タップ | `.onItemTap { }` / `.onItemLongTap { }` / `.touchFeedback(color:)` | `onItemTap =` / `onItemLongTap =` / `touchFeedbackColor =` | 0009 |
| 画像 | `.prefetchResources { }` + `KsImage` | `prefetchResources =` + `KsImage` | 0008 |

## 実装フェーズへの申し送り

- 混在配列の要素型と安定 ID の取り出し方 (Swift `any Identifiable` / Kotlin マーカー interface の要否) — phase-2 / phase-3
- 未登録テンプレート型の挙動 (debug 警告 + 空セル等) — phase-2 / phase-3 (ADR-0004 残課題)
- Compose の Pull to Refresh 接続の最終形 (`onRefresh` 引数 vs 標準 `PullToRefreshBox` との住み分け) — phase-3
- `KsPagingState.failed` にエラー内容を持たせるか — phase-5 (ADR-0005 残課題)
- `LoadMoreMargin` 相当 (発火しきい値設定) — phase-5
- セル自己サイズ計測 (旧 `ColumnHeight` 系の廃止根拠) — phase-2 要件
- グループ化・sticky ヘッダの DSL — phase-4 (旧語彙の申し送りは core/ADR-0009)
