# ページングと Pull to Refresh

一覧の末尾に近づいたら続きを読み込む仕組み (ページング。無限スクロールとも呼びます) と、Pull to Refresh、それらを動かすモデルのレシピです。どの例も `import SwiftUI` と `import KsCollectionView` を前提にしています。このページの例は、最初の 2 つの節で宣言した型 (`Post`・`PostRow`・`PostService`・`FeedModel`) を共有します。

役割の分け方: 配列とページングの状態を持ち、何を取得するかを決めるのは、利用する側のモデルです。ライブラリは状態を読み、末尾に近づいたことに気付いて、モデルに次のページを頼み (`onLoadMore` を呼ぶことを、このページでは「頼む」と書きます)、読み込み中・失敗・終端・空の表示を出します。ライブラリが状態や配列を書き換えることはありません。

このページの 2 つの言葉: 「取り直し」は、最初のページを読み込み直して、配列をそれで置き換えることです。利用者が引っ張って始めるもの (Pull to Refresh) と、自分のコードが始めるものがあり、後者を「読み込み直し」とも呼びます。

## 一覧にページングを付ける

`.paging(_:threshold:onLoadMore:)` に、今の状態と、次のページを読み込む関数を渡します。

```swift
struct Post: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
}

struct PostRow: View {
    let post: Post

    var body: some View {
        Text(post.title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
    }
}

struct FeedScreen: View {
    @StateObject private var model: FeedModel

    init(service: any PostService) {
        _model = StateObject(wrappedValue: FeedModel(service: service))
    }

    var body: some View {
        KsCollectionView(model.posts) { post in
            PostRow(post: post)
        }
        .paging(model.pagingState) {
            await model.loadNextPage()
        }
        .pagingFailedFooter { retry in
            Button("Retry", action: retry)
                .padding()
        }
        .pagingFailedPlaceholder { retry in
            Button("Retry", action: retry)
        }
        .pagingEmptyPlaceholder {
            Text("No posts")
        }
    }
}
```

状態は `KsPagingState` で、関連値 (associated value) を持たない enum です。書き換えるのは利用する側で、ライブラリはそれに応じて動きます。

| 状態 | ライブラリの動き |
|---|---|
| `.idle` | 末尾に近づいたら `onLoadMore` を呼びます。項目が 1 件も無ければ、すぐに呼びます。これが最初の読み込みです |
| `.appending` | `onLoadMore` を呼びません。項目があれば下端に「次のページの読み込み中」の表示を、無ければ真ん中に「最初の読み込み中」の表示を出します。Pull to Refresh は受け付けません |
| `.refreshing` | `onLoadMore` を呼びません。項目が無ければ「最初の読み込み中」の表示を出します。一覧がこの状態で一度描かれた後なら、次の配列の差し替えを、コンテンツの先頭から表示します (条件は「自分のコードから読み込み直す」を参照) |
| `.failed` | 自分からは `onLoadMore` を呼びません。再試行の操作があったときだけ呼びます |
| `.endReached` | `onLoadMore` を呼びません |

状態が `.idle` のとき、ライブラリは次の式が成り立つと `onLoadMore` を呼びます。

```text
itemsAfterLastVisible <= ceil(threshold * visibleItemCount)
```

- `itemsAfterLastVisible` は、画面に出ているいちばん後ろの項目より後ろに、配列に残っている項目の数です。`visibleItemCount` は、画面に出ている項目の数です。
- `threshold` (しきい値) の単位は画面の数で、既定は 1 です。残りがおよそ 1 画面分になったときに、次のページを頼みます。`0` は、最後の項目が画面に入ったときに頼みます。負の数と有限でない数は、不正入力です ([basics.md](basics.md) を参照)。
- 数えるのは項目だけです。グループの見出し・ヘッダー・フッターは数えません。行ではなく項目で数えるので、頼む時機はリストでもグリッドでも同じになります。
- 式は、スクロールしたとき、配列や状態が変わったとき、しきい値が変わったとき、一覧の大きさが変わったとき、`onLoadMore` から戻ったときに、判定し直されます。そのため、1 ページが画面に満たないときは、スクロールしなくても、残りの項目が足りるまで頼み続けます。
- 一度頼んだら、次の 2 つがそろうまで、次を頼みません。`onLoadMore` から戻ったことと、状態か配列が頼んだ時点と違う更新を、一覧が受け取ったことです。二重に頼まないのは、この仕組みによります。状態が `.idle`・`.appending`・`.idle` と移ったときは、配列が同じでも、変わったものと数えます。途中で一覧が `.appending` を受け取っているためです。空のページを返して `.idle` のままにするモデルが何度も頼まれるのは、このためです。
- `threshold` は `Double` です。`onLoadMore` は `@MainActor () async -> Void` です。エラーを投げられないので、エラーはモデルの中で扱い、`.failed` として表します。(Android の対応するコールバックは例外を投げることができ、ライブラリはその例外をそのまま伝えます。)
- 表示の modifier (`.pagingFailedFooter` など) は、`.paging` の前に書いても後ろに書いても構いません。`.paging` の無い一覧では、効きません。

## ページングの状態を持つモデルを書く

ライブラリは状態の移り方を強制しないので、次のモデルを写して、自分のアプリに合わせて使ってください。`PostService` は、自分の API クライアントの代わりです。このモデルは 3 つの機能を受け持っていて、画面に無い機能の部分は削れます。ページングに要るのは `loadNextPage()`、Pull to Refresh で足すのは `refresh()` と `refreshFailed`、自分のコードからの読み込み直しで足すのは `reload()`・`scrollController`・引数の `scrollsToStart` です。`generation` が要るのは、モデルが `refresh()` か `reload()` も持つときだけです。`isCancellation` は、どの場合も残してください。

```swift
struct PostPage: Sendable {
    let posts: [Post]
    let hasMore: Bool
}

protocol PostService: Sendable {
    func fetchPage(after lastID: Int?) async throws -> PostPage
}

@MainActor
final class FeedModel: ObservableObject {
    @Published private(set) var posts: [Post] = []
    @Published private(set) var pagingState = KsPagingState.idle
    @Published private(set) var refreshFailed = false

    let scrollController = KsScrollController()

    private let service: any PostService
    private var generation = 0

    init(service: any PostService) {
        self.service = service
    }

    func loadNextPage() async {
        guard pagingState == .idle || pagingState == .failed else { return }
        let started = generation
        pagingState = .appending
        do {
            let page = try await service.fetchPage(after: posts.last?.id)
            guard started == generation else { return }
            posts += page.posts
            pagingState = page.hasMore ? .idle : .endReached
        } catch {
            guard started == generation else { return }
            pagingState = Self.isCancellation(error) ? .idle : .failed
        }
    }

    func refresh() async {
        await reloadFirstPage(scrollsToStart: false)
    }

    func reload() async {
        await reloadFirstPage(scrollsToStart: true)
    }

    private func reloadFirstPage(scrollsToStart: Bool) async {
        generation += 1
        let started = generation
        let previous = pagingState
        pagingState = .refreshing
        refreshFailed = false
        do {
            let page = try await service.fetchPage(after: nil)
            guard started == generation else { return }
            posts = page.posts
            pagingState = page.hasMore ? .idle : .endReached
            if scrollsToStart {
                scrollController.scrollToStart(animated: false)
            }
        } catch {
            guard started == generation else { return }
            let isCancelled = Self.isCancellation(error)
            if posts.isEmpty && !isCancelled {
                pagingState = .failed
            } else {
                pagingState = (previous == .appending || previous == .refreshing) ? .idle : previous
                refreshFailed = !isCancelled
            }
        }
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled
    }
}
```

| モデルが守る書き方 | 守らないと |
|---|---|
| 最初の読み込みを、自分で始めない。配列を空にして状態を `.idle` にしておけば、一覧が最初のページを頼みます | 自分で始めた読み込みが状態を書き換えるのが遅れると、一覧も頼み、最初のページを 2 回読み込みます |
| `loadNextPage` を、2 つの状態で動かす。`.idle` (次のページ。配列が空なら最初のページ) と、`.failed` (再試行) です。項目の無い一覧の再試行も、取り直しではなく `onLoadMore` として届くので、同じ関数が最初のページも読み込める必要があります。例では、`posts.last?.id` が `nil` になることで、そうなります | `.failed` を受け付けないと、再試行しても何も起きません |
| `onLoadMore` から戻る前に、状態を `.appending` にする。上の例のように関数の中で取得を待つか、先に状態を書き換えてから自分のタスクを始めます | 状態が変わるまでの間に Pull to Refresh ができてしまい、遅れて届いたページが、取り直した一覧の後ろに足されます |
| 新しい配列と次の状態 (`.idle` か `.endReached`) を、間に `await` を挟まずに続けて書く。両方が 1 回の更新で一覧に届くようにするためです。取り直した配列とその状態も同じです | 配列より先に `.endReached` にすると、一覧は末尾の位置を保ち、届いたページを飛び越えます。取り直した配列が届く前に `.idle` に戻すと、結果が先頭から表示されません |
| 最後まで読み込んだら `.endReached` にする。空のページを返して `.idle` のままにしない | 状態が `.endReached` になるまで、一覧は頼み続けます。項目の無い一覧が空の表示を出すのは、`.endReached` のときだけです |
| 項目が表示されているときに取り直しが失敗したら、`.failed` にしない。状態を元に戻し、利用者への知らせは自分で出します (上の `refreshFailed`) | 最後の項目のすぐ下に再試行の表示が出て、押すと取り直しではなく次のページを頼みます |
| 取り直しを始めたら、それより前に始めた読み込みの結果を捨てる (上の `generation`) | 自分で始めた取り直しとページの読み込みが競合するのを、ライブラリは防ぎません。古いページが新しい一覧の後ろに足されます |
| 取り消された読み込みを、失敗ではなく取り消しとして扱う (上の `isCancellation` の関数) | 一覧が無くなったときの取り消しが `.failed` として残り、利用者が戻ってきても、一覧はもう頼みません |
| 一覧が無くなっても取り消されては困る読み込みは、モデルが持つタスクで始める | `onLoadMore` と取り直しの処理は、一覧に結びついたタスクで動き、一覧と一緒に取り消されます (最後の節を参照) |
| グループの項目を、ページをまたいでも続けて並べる。次のページが、前のページの最後と同じグループの値で始まれば、そのグループがそのまま伸びます。全体の並びを正しく保つのは、利用する側の責任です | 同じグループの値が離れた 2 か所に現れ、不正入力になります ([layout.md](layout.md) を参照) |

取り直しが失敗したとき、例は、取り直しの前の状態が `.appending` か `.refreshing` なら `.idle` に戻します。前の読み込みは `generation` の判定で捨てられているので、`.appending` に戻すと一覧が先へ進めなくなるためです。

## 読み込み中・失敗・終端・空の表示を出す

ページングを付けた一覧は、状態と、項目があるかどうかで、6 つの表示のうち多くても 1 つを出します。それぞれに、中身を渡す modifier があります。

| 状態 | 項目がある | 項目が無い |
|---|---|---|
| `.appending` | 次のページの読み込み中: `.pagingAppendingIndicator { }` | 最初の読み込み中: `.pagingLoadingPlaceholder { }` |
| `.failed` | 次のページの失敗: `.pagingFailedFooter { retry in }` | 失敗 (項目なし): `.pagingFailedPlaceholder { retry in }` |
| `.endReached` | 終端: `.pagingEndReachedFooter { }` | 空: `.pagingEmptyPlaceholder { }` |
| `.refreshing` | 何も出しません | 最初の読み込み中: `.pagingLoadingPlaceholder { }` |
| `.idle` | 何も出しません | 何も出しません |

```swift
struct FeedWithAllDisplaysScreen: View {
    @ObservedObject var model: FeedModel

    var body: some View {
        KsCollectionView(model.posts) { post in
            PostRow(post: post)
        }
        .paging(model.pagingState, threshold: 2) {
            await model.loadNextPage()
        }
        .pagingAppendingIndicator {
            ProgressView("Loading more")
                .padding(8)
                .background(.thinMaterial, in: Capsule())
        }
        .pagingFailedFooter { retry in
            VStack(spacing: 8) {
                Text("Could not load more posts")
                Button("Retry", action: retry)
            }
            .padding()
        }
        .pagingEndReachedFooter {
            Text("No more posts")
                .foregroundStyle(.secondary)
                .padding()
        }
        .pagingLoadingPlaceholder {
            ProgressView("Loading")
        }
        .pagingFailedPlaceholder { retry in
            VStack(spacing: 8) {
                Text("Could not load posts")
                Button("Retry", action: retry)
            }
        }
        .pagingEmptyPlaceholder {
            Text("No posts yet")
        }
    }
}
```

既定の動き:

- 既定で出るのは、2 つの読み込み中の表示だけです。文字も下地も無い、標準の `ProgressView` のスピナーが出ます。何も出したくないときは、modifier から `EmptyView()` を返します。
- 失敗・終端・空の表示は、渡さない限り何も出ません。失敗の表示が無いと再試行の手段が無く、Pull to Refresh も無い一覧は、失敗したまま止まります。空の表示が無いと、項目の無い一覧は真っ白です。少なくとも `.pagingFailedFooter`・`.pagingFailedPlaceholder`・`.pagingEmptyPlaceholder` は渡してください。このページの後ろの例のいくつかは、短くするために、これらを省いています (`ReloadableFeedScreen` には `.pagingFailedFooter` が無く、`TintedFeedScreen` と `FullScreenFeedScreen` には 3 つとも無い)。それらの例を写すときは、足してください。
- これらの表示があるのは、`.paging` を付けた一覧だけです。ページングを付けない一覧の空の表示は、[basics.md](basics.md) の「配列を表示する」を参照してください。
- ライブラリは、文言を持ちません。エラーの文言とその翻訳は利用する側のもので、表示の中でモデルから読みます。表示は、`body` が評価し直されるたびに作り直されます ([basics.md](basics.md) の「行の中で親の状態を読む」を参照)。
- `retry` は `@MainActor () -> Void` のクロージャです。状態が `.failed` なら、項目があるかどうかにも、Pull to Refresh があるかどうかにもよらず、`onLoadMore` を呼びます。`onLoadMore` がまだ動いている間は、何もしません。
- 項目のある一覧を自分のコードで取り直している間 (状態が `.refreshing`)、ライブラリは何も重ねません。進行中だと見せたいときは、自分で出します。

出る場所:

| 表示 | 場所 |
|---|---|
| 次のページの読み込み中 | 表示範囲の下端の中央に重ねます。下端の安全領域から 8 ポイント上です。スクロールしても動かず、項目はその裏を流れます。フェードで出入りします |
| 次のページの失敗・終端 | 最後の項目の後ろ、フッターの前に、スクロールするコンテンツの一部として置きます。左右の `contentPadding` の内側で、一覧の幅いっぱい (グリッドでは、すべての列) が与えられ、渡した View は、その中の水平の中央に置かれます |
| 最初の読み込み中・失敗 (項目なし)・空 | 項目の代わりに、表示範囲 (上下の安全領域を除く) の真ん中に重ねます。ヘッダーとフッターは、項目が無くても表示されます。重なったときは、この表示が手前になります |

タッチ:

- 既定の「次のページの読み込み中」の表示は、タッチを受けません。下の項目をタップできます。
- 自分で渡した「次のページの読み込み中」の表示は、ボタンなどのコントロールが無くても、その範囲のタップを受け止めます。そこでは、下の項目をタップできません。その表示の上から始めたドラッグは、一覧のスクロールになります。
- 項目が無いときの 3 つの表示の中のコントロール (再試行のボタン) は、表示がヘッダーやフッターに重なっていても押せます。

## Pull to Refresh を付ける

一覧に、SwiftUI 標準の `.refreshable` を付けます。ライブラリの modifier はありません。`KsCollectionView` が、取り直しの処理を環境から読みます。`.refreshable` は SwiftUI の modifier なので、ライブラリのすべての modifier の後ろに書きます。ページングの無い一覧でも、項目の無い一覧でも使えます。

```swift
struct RefreshableFeedScreen: View {
    @ObservedObject var model: FeedModel

    var body: some View {
        KsCollectionView(model.posts) { post in
            PostRow(post: post)
        }
        .paging(model.pagingState) {
            await model.loadNextPage()
        }
        .pagingFailedFooter { retry in
            Button("Retry", action: retry)
                .padding()
        }
        .pagingFailedPlaceholder { retry in
            Button("Retry", action: retry)
        }
        .pagingEmptyPlaceholder {
            Text("No posts")
        }
        .refreshable {
            await model.refresh()
        }
        .overlay(alignment: .top) {
            if model.refreshFailed {
                Text("Could not refresh")
                    .padding(8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 8)
            }
        }
    }
}
```

ライブラリが保証すること:

- インジケータは、引っ張ってから取り直しの処理が戻るまで出ます。ページングを付けた一覧では、状態が `.refreshing` の間も出し続けます。処理がすぐに戻り、後から状態を書き換えるモデルのためです。
- 引っ張って始めた取り直しの間に差し替えた配列は、取得がどれだけ速くても、状態が何であっても、コンテンツの先頭から表示します。取り直した配列が前と同じでも、インジケータが消えるときに先頭へ戻ります。
- 状態が `.appending` の間と、`onLoadMore` が動いている間は、引っ張っても受け付けません。遅れて届いたページが、取り直した一覧の後ろに足されるのを防ぐためです。自分のコードで取り直している間 (状態が `.refreshing`) の引っ張りは、受け付けます。そのときは、例の `generation` の判定が、古いほうの結果を捨てます。
- 引っ張らずに状態を `.refreshing` にしても、インジケータは出ません。

約束ごと:

- 項目が画面に出ているときに取り直しが失敗したら、`.failed` にせずに状態を元に戻し、上の `refreshFailed` のように、自分の知らせを出します (例の知らせは、次の取り直しが始まるまで出たままです。自分の知らせは、画面の作りに合わせて消してください)。項目が無いときは `.failed` で構いません。「失敗 (項目なし)」の表示が出ます。
- インジケータが出ている間に下へスクロールし、その後、配列が変わらないまま取り直しが失敗すると、一覧はインジケータが消えるときに先頭へ戻ります。Android では、スクロールした位置に残ります。

ページングを付けた一覧で配列を差し替えたときの位置は、一般に、次のように決まります。

| 差し替えの直前の状態 | 位置 |
|---|---|
| `.refreshing` で、一覧がその状態で一度描かれている | 一覧がどこまでスクロールしていても、コンテンツの先頭を表示します |
| `.endReached` | 末尾を表示しているときに末尾へ項目が足されると、一覧は末尾に留まります |
| `.idle`・`.appending`・`.failed` | 一覧は位置を保ち、新しいページは下に現れます。末尾には留まりません。留まると、すぐに次の要求が起きるためです |

## 自分のコードから読み込み直す

自分のコードが始める読み込み直し (再読み込みのボタンや、絞り込みの変更) は、モデルにとっては取り直しと同じですが、気を付ける点が 1 つ増えます。結果を先頭から見せることです。一覧が先頭を表示するのは、配列が差し替わる前に、状態が `.refreshing` のまま一度描かれていたときだけです。取得がすぐに終わると、`.refreshing` への書き換えと新しい配列が 1 回の更新にまとまって一覧に届き、一覧からは取り直しだと分かりません。

簡単な手当ては、新しい配列と一緒に `scrollToStart` を送ることです。`FeedModel.reload()` は、自分が持つ `KsScrollController` を通して、そうしています。スクロールの命令は、新しい配列が画面に出た後に実行されます。

```swift
struct ReloadableFeedScreen: View {
    @ObservedObject var model: FeedModel

    var body: some View {
        VStack(spacing: 0) {
            Button("Reload") {
                Task { await model.reload() }
            }
            .padding()

            KsCollectionView(model.posts) { post in
                PostRow(post: post)
            }
            .paging(model.pagingState) {
                await model.loadNextPage()
            }
            .pagingFailedPlaceholder { retry in
                Button("Retry", action: retry)
            }
            .pagingEmptyPlaceholder {
                Text("No posts")
            }
            .scrollController(model.scrollController)
        }
    }
}
```

- もう 1 つ、一覧が `.refreshing` の状態で描かれた後にだけ配列を差し替える、というやり方もあります。ただし、ライブラリはその時機を知らせません。この Skill は、そのコードを載せていません。`scrollToStart` の手当てを使ってください。
- 引っ張って始めた取り直しには、どちらも要りません。ライブラリが、自分で始めた取り直しだと知っているためです。

## 読み込み中の表示の色を決める

`.loadingIndicatorColor(_:)` は、ライブラリが描く 3 つの読み込み中の表示に、1 つの色を当てます。既定の「次のページの読み込み中」の表示、既定の「最初の読み込み中」の表示、Pull to Refresh のインジケータの 3 つです。

```swift
struct TintedFeedScreen: View {
    @ObservedObject var model: FeedModel

    var body: some View {
        KsCollectionView(model.posts) { post in
            PostRow(post: post)
        }
        .paging(model.pagingState) {
            await model.loadNextPage()
        }
        .loadingIndicatorColor(.orange)
        .refreshable {
            await model.refresh()
        }
    }
}
```

- `.paging` の無い一覧でも使え、Pull to Refresh のインジケータに色が付きます。
- 自分で渡した表示には効きません。その色は、自分で決めます。
- 付けなければ、2 つの読み込み中の表示は、周りの SwiftUI の View の `tint` の色に、Pull to Refresh のインジケータは、システムの色になります。
- Pull to Refresh のインジケータは、色みは指定した色になりますが、2 つの読み込み中の表示より薄く描かれます。システムのインジケータが半透明のためです。背景に近い色は避けてください。(Android では、指定した色がそのままインジケータに付きます。)
- 表示ごとに色を分ける設定はありません。

## ページングを付けた一覧を、バーの裏まで全画面に広げる

`.ignoresSafeArea()` で一覧をバーの裏まで広げたとき ([layout.md](layout.md) を参照)、ライブラリが重ねて出す 3 種類の表示は、安全領域に合わせます。これらはコンテンツの一部ではないので、`contentPadding` では動きません。

| 重ねる表示 | 位置 |
|---|---|
| Pull to Refresh のインジケータ | 上のバーの下端より下 |
| 最初の読み込み中・失敗 (項目なし)・空 | 上下の安全領域の間の範囲の真ん中 |
| 次のページの読み込み中 | ホームインジケータの領域の上端より上 |

```swift
struct FullScreenFeedScreen: View {
    @ObservedObject var model: FeedModel

    var body: some View {
        GeometryReader { proxy in
            KsCollectionView(
                model.posts,
                contentPadding: EdgeInsets(
                    top: proxy.safeAreaInsets.top,
                    leading: 0,
                    bottom: proxy.safeAreaInsets.bottom,
                    trailing: 0
                )
            ) { post in
                PostRow(post: post)
            }
            .paging(model.pagingState) {
                await model.loadNextPage()
            }
            .refreshable {
                await model.refresh()
            }
            .ignoresSafeArea()
        }
    }
}
```

- 一覧の上に浮かせた自分の View を避けるために、下の `contentPadding` を広げて「次のページの読み込み中」の表示を持ち上げようとしないでください。この表示の位置は、安全領域だけで決まります。

## 実行中の読み込みが取り消される時機を知る

`onLoadMore` と取り直しの処理は、一覧に属するタスクで動きます。一覧が View の階層から取り除かれると、取り消されます。

- `NavigationStack` で次の画面を積んでも、一覧は残るので、読み込みは続きます。(Android では、次の画面へ進むと前の画面の表示が破棄され、読み込みは取り消されます。)
- 取り消された読み込みを `.failed` にしないでください。`loadNextPage()` のように `.idle` に戻せば、一覧が戻ってきたときに、また頼まれます。取り消された取得が投げるのは、`CancellationError` とは限りません。`URLSession` の `async` の関数は、コードが `.cancelled` の `URLError` を投げます。ほかのクライアントにも、それぞれのエラーがあります。そのため `FeedModel` の `isCancellation` は、最初に `Task.isCancelled` を見て、タスクが取り消された後に届いたエラーをすべて取り消しとして扱い、その後で 2 つのエラーの型を見ます。
- 一覧が無くなっても終わらせたい読み込みは、モデルが持つタスクで動かします。そのとき `onLoadMore` は、`async` でないモデルの関数を呼びます。その関数は、状態を `.appending` にし、モデルが持つ `Task` で取得を始めて、すぐに戻ります。そのタスクは、一覧と一緒には取り消されません。結果は、`loadNextPage()` と同じ `generation` の判定を通してから反映します。
- 並べ替えで項目をドラッグしている間は、ライブラリは次のページを頼みません ([reorder.md](reorder.md) を参照)。
