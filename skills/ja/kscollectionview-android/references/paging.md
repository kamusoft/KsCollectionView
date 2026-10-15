# ページングと Pull to Refresh

一覧の末尾に近づいたら続きを読み込む仕組み (ページング。無限スクロールとも呼びます) と、Pull to Refresh、それらを動かすモデルのレシピです。例は `import` の行を省いています。どの例にも、使っている Compose と Material 3 の名前と、`jp.kamusoft.kscollectionview` にあるライブラリの名前の import が要ります。出てくる場所では、`kotlinx.coroutines` の名前と `java.io.IOException` の import も要ります。このページの例は、最初の 2 つの節で宣言した型 (`Post`・`PostRow`・`PostService`・`FeedModel`) を共有します。

役割の分け方: 配列とページングの状態を持ち、何を取得するかを決めるのは、利用する側のモデルです。ライブラリは状態を読み、末尾に近づいたことに気付いて、モデルに次のページを頼み (`onLoadMore` を呼ぶことを、このページでは「頼む」と書きます)、読み込み中・失敗・終端・空の表示を出します。ライブラリが状態や配列を書き換えることはありません。

このページの 2 つの言葉: 「取り直し」は、最初のページを読み込み直して、配列をそれで置き換えることです。利用者が引っ張って始めるもの (Pull to Refresh) と、自分のコードが始めるものがあり、後者を「読み込み直し」とも呼びます。

## 一覧にページングを付ける

`paging` に、今の状態と、次のページを読み込む関数を持たせた `KsPaging` を渡します。

```kotlin
data class Post(val id: Int, val title: String)

@Composable
fun PostRow(post: Post, modifier: Modifier = Modifier) {
    Text(text = post.title, modifier = modifier.fillMaxWidth().padding(16.dp))
}

@Composable
fun FeedScreen(model: FeedModel, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = model.posts,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        paging = KsPaging(
            state = model.pagingState,
            onLoadMore = { model.loadNextPage() },
            failedFooter = { retry ->
                Button(onClick = retry, modifier = Modifier.padding(16.dp)) { Text("Retry") }
            },
            failedPlaceholder = { retry ->
                Button(onClick = retry) { Text("Retry") }
            },
            emptyPlaceholder = { Text("No posts") },
        ),
    ) {
        template { post -> PostRow(post) }
    }
}
```

状態は `KsPagingState` という enum です。書き換えるのは利用する側で、ライブラリはそれに応じて動きます。

| 状態 | ライブラリの動き |
|---|---|
| `Idle` | 末尾に近づいたら `onLoadMore` を呼びます。項目が 1 件も無ければ、すぐに呼びます。これが最初の読み込みです |
| `Appending` | `onLoadMore` を呼びません。項目があれば下端に「次のページの読み込み中」の表示を、無ければ真ん中に「最初の読み込み中」の表示を出します。Pull to Refresh は受け付けません |
| `Refreshing` | `onLoadMore` を呼びません。項目が無ければ「最初の読み込み中」の表示を出します。一覧がこの状態で一度コンポーズされた後なら、次の配列の差し替えを、コンテンツの先頭から表示します (条件は「自分のコードから読み込み直す」を参照) |
| `Failed` | 自分からは `onLoadMore` を呼びません。再試行の操作があったときだけ呼びます |
| `EndReached` | `onLoadMore` を呼びません |

状態が `Idle` のとき、ライブラリは次の式が成り立つと `onLoadMore` を呼びます。

```text
itemsAfterLastVisible <= ceil(threshold * visibleItemCount)
```

- `itemsAfterLastVisible` は、画面に出ているいちばん後ろの項目より後ろに、配列に残っている項目の数です。`visibleItemCount` は、画面に出ている項目の数です。
- `threshold` (しきい値) は `Float` で、単位は画面の数、既定は `1f` です。残りがおよそ 1 画面分になったときに、次のページを頼みます。`0f` は、最後の項目が画面に入ったときに頼みます。負の数と有限でない数は、不正入力です ([basics.md](basics.md) を参照)。
- 数えるのは項目だけです。グループの見出し・ヘッダー・フッターは数えません。行ではなく項目で数えるので、頼む時機はリストでもグリッドでも同じになります。
- 式は、スクロールしたとき、配列や状態が変わったとき、しきい値が変わったとき、一覧の大きさが変わったとき、`onLoadMore` から戻ったときに、判定し直されます。そのため、1 ページが画面に満たないときは、スクロールしなくても、残りの項目が足りるまで頼み続けます。
- 一度頼んだら、次の 2 つがそろうまで、次を頼みません。`onLoadMore` から戻ったことと、状態か配列が頼んだ時点と違う形で、一覧が再コンポーズされたことです。二重に頼まないのは、この仕組みによります。状態が `Idle`・`Appending`・`Idle` と移ったときは、配列が同じでも、変わったものと数えます。途中で一覧が `Appending` を受け取っているためです。空のページを返して `Idle` のままにするモデルが何度も頼まれるのは、このためです。
- `onLoadMore` は `suspend () -> Unit` で、メインスレッドで呼ばれます。ライブラリは、この処理が投げたものを捕まえません。取り消し以外の例外は、捕まえられなかったコルーチンの例外と同じように伝わり、ふつうはアプリがクラッシュします。失敗はモデルの中で捕まえて、`Failed` として表します。`onRefresh` も同じです。(iOS の対応するコールバックは、エラーを投げられない型です。)
- コンストラクタは `KsPaging(state, onLoadMore, threshold = 1f, appendingIndicator = null, failedFooter = null, endReachedFooter = null, loadingPlaceholder = null, failedPlaceholder = null, emptyPlaceholder = null)` です。6 つの表示の型は `(@Composable () -> Unit)?` で、失敗の 2 つだけは `(@Composable (retry: () -> Unit) -> Unit)?` です。`KsPaging` は、渡した値を、引数と同じ名前の読み取り専用のプロパティとして持ちます。

## ページングの状態を持つモデルを書く

ライブラリは状態の移り方を強制しないので、次のモデルを写して、自分のアプリに合わせて使ってください。`PostService` は自分の API クライアントの代わりで、`IOException` は、そのクライアントが取得に失敗したときに投げるものの代わりです。自分のクライアントが取得の失敗に使う例外の型を (HTTP のエラーや、パースの失敗も)、すべてその `catch` に並べてください。そこで捕まえなかった例外は、状態を `Appending` のまま残して `onLoadMore` の外へ出ていき、ふつうはアプリがクラッシュします。

このモデルは 3 つの機能を受け持っていて、画面に無い機能の部分は削れます。ページングに要るのは `loadNextPage()`、Pull to Refresh で足すのは `refresh()` と `refreshFailed`、自分のコードからの読み込み直しで足すのは `reload()`・`scrollController`・引数の `scrollsToStart` です。`generation` と `restored` が要るのは、モデルが `refresh()` か `reload()` も持つときだけです。2 つの `catch` は、どの場合も残してください。

```kotlin
data class PostPage(val posts: List<Post>, val hasMore: Boolean)

interface PostService {
    suspend fun fetchPage(afterId: Int?): PostPage
}

class FeedModel(private val service: PostService) {
    var posts by mutableStateOf(listOf<Post>())
        private set

    var pagingState by mutableStateOf(KsPagingState.Idle)
        private set

    var refreshFailed by mutableStateOf(false)
        private set

    val scrollController = KsScrollController()

    private var generation = 0

    suspend fun loadNextPage() {
        if (pagingState != KsPagingState.Idle && pagingState != KsPagingState.Failed) return
        val started = generation
        pagingState = KsPagingState.Appending
        try {
            val page = service.fetchPage(afterId = posts.lastOrNull()?.id)
            if (started != generation) return
            posts = posts + page.posts
            pagingState = if (page.hasMore) KsPagingState.Idle else KsPagingState.EndReached
        } catch (cancellation: CancellationException) {
            if (started == generation) pagingState = KsPagingState.Idle
            throw cancellation
        } catch (failure: IOException) {
            if (started != generation) return
            pagingState = KsPagingState.Failed
        }
    }

    suspend fun refresh() {
        reloadFirstPage(scrollsToStart = false)
    }

    suspend fun reload() {
        reloadFirstPage(scrollsToStart = true)
    }

    private suspend fun reloadFirstPage(scrollsToStart: Boolean) {
        generation += 1
        val started = generation
        val previous = pagingState
        pagingState = KsPagingState.Refreshing
        refreshFailed = false
        try {
            val page = service.fetchPage(afterId = null)
            if (started != generation) return
            posts = page.posts
            pagingState = if (page.hasMore) KsPagingState.Idle else KsPagingState.EndReached
            if (scrollsToStart) scrollController.scrollToStart(animated = false)
        } catch (cancellation: CancellationException) {
            if (started == generation) pagingState = restored(previous)
            throw cancellation
        } catch (failure: IOException) {
            if (started != generation) return
            if (posts.isEmpty()) {
                pagingState = KsPagingState.Failed
            } else {
                pagingState = restored(previous)
                refreshFailed = true
            }
        }
    }

    private fun restored(previous: KsPagingState): KsPagingState = when (previous) {
        KsPagingState.Appending, KsPagingState.Refreshing -> KsPagingState.Idle
        KsPagingState.Idle, KsPagingState.Failed, KsPagingState.EndReached -> previous
    }
}
```

| モデルが守る書き方 | 守らないと |
|---|---|
| 最初の読み込みを、自分で始めない。配列を空にして状態を `Idle` にしておけば、一覧が最初のページを頼みます | 自分で始めた読み込みが状態を書き換えるのが遅れると、一覧も頼み、最初のページを 2 回読み込みます |
| `loadNextPage` を、2 つの状態で動かす。`Idle` (次のページ。配列が空なら最初のページ) と、`Failed` (再試行) です。項目の無い一覧の再試行も、取り直しではなく `onLoadMore` として届くので、同じ関数が最初のページも読み込める必要があります。例では、`posts.lastOrNull()?.id` が `null` になることで、そうなります | `Failed` を受け付けないと、再試行しても何も起きません |
| `onLoadMore` から戻る前に、状態を `Appending` にする。上の例のように関数の中で取得を待つか、先に状態を書き換えてから自分のコルーチンを始めます | 状態が変わるまでの間に Pull to Refresh ができてしまい、遅れて届いたページが、取り直した一覧の後ろに足されます |
| 新しい配列と次の状態 (`Idle` か `EndReached`) を、間に中断点を挟まずに続けて書く。両方が 1 回の再コンポーズで一覧に届くようにするためです。取り直した配列とその状態も同じです | 配列より先に `EndReached` にすると、一覧は末尾の位置を保ち、届いたページを飛び越えます。取り直した配列が届く前に `Idle` に戻すと、結果が先頭から表示されません |
| 最後まで読み込んだら `EndReached` にする。空のページを返して `Idle` のままにしない | 状態が `EndReached` になるまで、一覧は頼み続けます。項目の無い一覧が空の表示を出すのは、`EndReached` のときだけです |
| 項目が表示されているときに取り直しが失敗したら、`Failed` にしない。状態を元に戻し、利用者への知らせは自分で出します (上の `refreshFailed`) | 最後の項目のすぐ下に再試行の表示が出て、押すと取り直しではなく次のページを頼みます |
| 取り直しを始めたら、それより前に始めた読み込みの結果を捨てる (上の `generation`) | 自分で始めた取り直しとページの読み込みが競合するのを、ライブラリは防ぎません。古いページが新しい一覧の後ろに足されます |
| 捕まえる例外を、取得の失敗を表すものに絞る。`CancellationException` を `Failed` にしない。上の例のように、状態を戻して投げ直します。自分のクライアントが、取り消された呼び出しを独自の型の例外で知らせるなら、その型も `CancellationException` と同じように扱います | 広く `catch (e: Exception)` で捕まえると、一覧が無くなったときの取り消しも捕まります。状態が `Failed` のまま残り、利用者が戻ってきても、一覧はもう頼みません |
| 一覧が無くなっても取り消されては困る読み込みは、モデルが持つスコープ (`viewModelScope` など) で始める | `onLoadMore` と `onRefresh` は、一覧に結びついたコルーチンで動き、一覧と一緒に取り消されます (最後の節を参照) |
| グループの項目を、ページをまたいでも続けて並べる。次のページが、前のページの最後と同じグループの値で始まれば、そのグループがそのまま伸びます。全体の並びを正しく保つのは、利用する側の責任です | 同じグループの値が離れた 2 か所に現れ、不正入力になります ([layout.md](layout.md) を参照) |

取り直しが失敗したとき、例は、取り直しの前の状態が `Appending` か `Refreshing` なら `Idle` に戻します。前の読み込みは `generation` の判定で捨てられているので、`Appending` に戻すと一覧が先へ進めなくなるためです。

## 読み込み中・失敗・終端・空の表示を出す

ページングを付けた一覧は、状態と、項目があるかどうかで、6 つの表示のうち多くても 1 つを出します。それぞれに、中身を渡す `KsPaging` の引数があります。

| 状態 | 項目がある | 項目が無い |
|---|---|---|
| `Appending` | 次のページの読み込み中: `appendingIndicator = { }` | 最初の読み込み中: `loadingPlaceholder = { }` |
| `Failed` | 次のページの失敗: `failedFooter = { retry -> }` | 失敗 (項目なし): `failedPlaceholder = { retry -> }` |
| `EndReached` | 終端: `endReachedFooter = { }` | 空: `emptyPlaceholder = { }` |
| `Refreshing` | 何も出しません | 最初の読み込み中: `loadingPlaceholder = { }` |
| `Idle` | 何も出しません | 何も出しません |

```kotlin
@Composable
fun FeedWithAllDisplaysScreen(model: FeedModel, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = model.posts,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        paging = KsPaging(
            state = model.pagingState,
            onLoadMore = { model.loadNextPage() },
            threshold = 2f,
            appendingIndicator = {
                Text(
                    text = "Loading more",
                    modifier = Modifier
                        .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(50))
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                )
            },
            failedFooter = { retry ->
                Column(
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(text = "Could not load more posts")
                    Button(onClick = retry) { Text("Retry") }
                }
            },
            endReachedFooter = {
                Text(text = "No more posts", modifier = Modifier.padding(16.dp))
            },
            loadingPlaceholder = {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    CircularProgressIndicator()
                    Text(text = "Loading")
                }
            },
            failedPlaceholder = { retry ->
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(text = "Could not load posts")
                    Button(onClick = retry) { Text("Retry") }
                }
            },
            emptyPlaceholder = { Text(text = "No posts yet") },
        ),
    ) {
        template { post -> PostRow(post) }
    }
}
```

既定の動き:

- 既定で出るのは、2 つの読み込み中の表示だけです。文字も下地も無い、Material 標準の `CircularProgressIndicator` が出ます。何も出したくないときは、空のラムダを渡します (`appendingIndicator = { }`)。
- 失敗・終端・空の表示は、渡さない限り何も出ません。失敗の表示が無いと再試行の手段が無く、Pull to Refresh も無い一覧は、失敗したまま止まります。空の表示が無いと、項目の無い一覧は真っ白です。少なくとも `failedFooter`・`failedPlaceholder`・`emptyPlaceholder` は渡してください。このページの後ろの例のいくつかは、短くするために、これらを省いています (`ReloadableFeedScreen` には `failedFooter` が無く、`TintedFeedScreen` と `EdgeToEdgeFeedScreen` には 3 つとも無い)。それらの例を写すときは、足してください。
- これらの表示があるのは、`paging` を渡した一覧だけです。ページングを付けない一覧の空の表示は、[basics.md](basics.md) の「配列を表示する」を参照してください。
- ライブラリは、文言を持ちません。エラーの文言とその翻訳は利用する側のもので、表示の中でモデルから読みます。
- `retry` は `() -> Unit` です。状態が `Failed` なら、項目があるかどうかにも、Pull to Refresh があるかどうかにもよらず、`onLoadMore` を呼びます。`onLoadMore` がまだ動いている間は、何もしません。
- 項目のある一覧を自分のコードで取り直している間 (状態が `Refreshing`)、ライブラリは何も重ねません。進行中だと見せたいときは、自分で出します。

出る場所:

| 表示 | 場所 |
|---|---|
| 次のページの読み込み中 | 表示範囲の下端の中央に重ねます。下のシステムバーから 8 dp 上です。スクロールしても動かず、項目はその裏を流れます。フェードで出入りします |
| 次のページの失敗・終端 | 最後の項目の後ろ、フッターの前に、スクロールするコンテンツの一部として置きます。左右の `contentPadding` の内側で、コンテンツの幅いっぱい (グリッドでは、すべての列) が与えられ、渡した Composable は、その中の水平の中央に置かれます |
| 最初の読み込み中・失敗 (項目なし)・空 | 項目の代わりに、表示範囲 (上下のシステムバーを除く) の真ん中に重ねます。ヘッダーとフッターは、項目が無くても表示されます。重なったときは、この表示が手前になります |

タッチ:

- 既定の「次のページの読み込み中」の表示は、タッチを受けません。下の項目をタップできます。
- 自分で渡した「次のページの読み込み中」の表示は、ボタンなどのコントロールが無くても、その範囲のタップを受け止めます。そこでは、下の項目をタップできません。その表示の上から始めたドラッグは、一覧のスクロールになります。
- 項目が無いときの 3 つの表示の中のコントロール (再試行のボタン) は、表示がヘッダーやフッターに重なっていても押せます。

## Pull to Refresh を付ける

取り直しの関数を、`onRefresh` に渡します。`onRefresh` は `KsPaging` ではなく `KsCollectionView` の引数なので、ページングの無い一覧でも、項目の無い一覧でも使えます。

```kotlin
@Composable
fun RefreshableFeedScreen(model: FeedModel, modifier: Modifier = Modifier) {
    Box(modifier = modifier.fillMaxSize()) {
        KsCollectionView(
            items = model.posts,
            key = { it.id },
            modifier = Modifier.fillMaxSize(),
            paging = KsPaging(
                state = model.pagingState,
                onLoadMore = { model.loadNextPage() },
                failedFooter = { retry ->
                    Button(onClick = retry, modifier = Modifier.padding(16.dp)) { Text("Retry") }
                },
                failedPlaceholder = { retry ->
                    Button(onClick = retry) { Text("Retry") }
                },
                emptyPlaceholder = { Text("No posts") },
            ),
            onRefresh = { model.refresh() },
        ) {
            template { post -> PostRow(post) }
        }
        if (model.refreshFailed) {
            Text(
                text = "Could not refresh",
                color = MaterialTheme.colorScheme.inverseOnSurface,
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 8.dp)
                    .background(MaterialTheme.colorScheme.inverseSurface, RoundedCornerShape(50))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            )
        }
    }
}
```

ライブラリが保証すること:

- インジケータは、Material 3 の Pull to Refresh のインジケータです。引っ張ってから `onRefresh` が戻るまで出ます。ページングを付けた一覧では、状態が `Refreshing` の間も出し続けます。関数がすぐに戻り、後から状態を書き換えるモデルのためです。
- 引っ張って始めた取り直しの間に差し替えた配列は、取得がどれだけ速くても、状態が何であっても、コンテンツの先頭から表示します。ページングの無い一覧でも同じです。
- 状態が `Appending` の間と、`onLoadMore` が動いている間は、引っ張っても受け付けません。遅れて届いたページが、取り直した一覧の後ろに足されるのを防ぐためです。自分のコードで取り直している間 (状態が `Refreshing`) の引っ張りは、受け付けます。そのときは、例の `generation` の判定が、古いほうの結果を捨てます。
- 引っ張らずに状態を `Refreshing` にしても、インジケータは出ません。

約束ごと:

- 項目が画面に出ているときに取り直しが失敗したら、`Failed` にせずに状態を元に戻し、上の `refreshFailed` のように、自分の知らせを出します (例の知らせは、次の取り直しが始まるまで出たままです。自分の知らせは、画面の作りに合わせて消してください)。項目が無いときは `Failed` で構いません。「失敗 (項目なし)」の表示が出ます。
- インジケータが出ている間に下へスクロールし、その後、配列が変わらないまま取り直しが失敗すると、一覧はスクロールした位置に残ります。iOS では、この場合、一覧は先頭へ戻ります。

ページングを付けた一覧で配列を差し替えたときの位置は、一般に、次のように決まります。

| 差し替えの直前の状態 | 位置 |
|---|---|
| `Refreshing` で、一覧がその状態で一度コンポーズされている | 一覧がどこまでスクロールしていても、コンテンツの先頭を表示します |
| `EndReached` | 末尾を表示しているときに末尾へ項目が足されると、一覧は末尾に留まります |
| `Idle`・`Appending`・`Failed` | 一覧は位置を保ち、新しいページは下に現れます。末尾には留まりません。留まると、すぐに次の要求が起きるためです |

## 自分のコードから読み込み直す

自分のコードが始める読み込み直し (再読み込みのボタンや、絞り込みの変更) は、モデルにとっては取り直しと同じですが、気を付ける点が 1 つ増えます。結果を先頭から見せることです。一覧が先頭を表示するのは、配列が差し替わる前に、状態が `Refreshing` のまま一度コンポーズされていたときだけです。取得がすぐに終わると、`Refreshing` への書き換えと新しい配列が 1 回の再コンポーズにまとまって一覧に届き、一覧からは取り直しだと分かりません。

簡単な手当ては、新しい配列と一緒に `scrollToStart` を送ることです。`FeedModel.reload()` は、自分が持つ `KsScrollController` を通して、そうしています。スクロールの命令は、新しい配列が画面に出た後に実行されます。

```kotlin
@Composable
fun ReloadableFeedScreen(model: FeedModel, modifier: Modifier = Modifier) {
    val scope = rememberCoroutineScope()
    Column(modifier = modifier.fillMaxSize()) {
        Button(onClick = { scope.launch { model.reload() } }, modifier = Modifier.padding(16.dp)) {
            Text("Reload")
        }
        KsCollectionView(
            items = model.posts,
            key = { it.id },
            modifier = Modifier.weight(1f),
            scrollController = model.scrollController,
            paging = KsPaging(
                state = model.pagingState,
                onLoadMore = { model.loadNextPage() },
                failedPlaceholder = { retry ->
                    Button(onClick = retry) { Text("Retry") }
                },
                emptyPlaceholder = { Text("No posts") },
            ),
        ) {
            template { post -> PostRow(post) }
        }
    }
}
```

- もう 1 つ、一覧が `Refreshing` の状態でコンポーズされた後にだけ配列を差し替える、というやり方もあります。ただし、ライブラリはその時機を知らせません。この Skill は、そのコードを載せていません。`scrollToStart` の手当てを使ってください。
- 引っ張って始めた取り直しには、どちらも要りません。ライブラリが、自分で始めた取り直しだと知っているためです。

## 読み込み中の表示の色を決める

`loadingIndicatorColor` は、ライブラリが描く 3 つの読み込み中の表示に、1 つの色を当てます。既定の「次のページの読み込み中」の表示、既定の「最初の読み込み中」の表示、Pull to Refresh のインジケータの 3 つです。

```kotlin
@Composable
fun TintedFeedScreen(model: FeedModel, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = model.posts,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        paging = KsPaging(
            state = model.pagingState,
            onLoadMore = { model.loadNextPage() },
        ),
        onRefresh = { model.refresh() },
        loadingIndicatorColor = Color(0xFFEF6C00),
    ) {
        template { post -> PostRow(post) }
    }
}
```

- `paging` の無い一覧でも使え、Pull to Refresh のインジケータに色が付きます。
- 自分で渡した表示には効きません。その色は、自分で決めます。
- 渡さなければ、2 つの読み込み中の表示は Material のテーマの `primary` の色に、Pull to Refresh のインジケータは Material の既定の色になります。
- Pull to Refresh のインジケータでは、指定した色がそのまま矢印に付き、丸い下地はテーマの色のままです。下地と見分けにくい色 (ライトのテーマで白など) は避けてください。(iOS では、インジケータは色みだけが指定した色になり、薄く描かれます。)
- 表示ごとに色を分ける設定はありません。

## ページングを付けた一覧を、バーの裏まで全画面に広げる

edge-to-edge のアクティビティで一覧をシステムバーの裏まで広げたとき ([layout.md](layout.md) を参照)、ライブラリが重ねて出す 3 種類の表示は、バーに合わせます。これらはコンテンツの一部ではないので、`contentPadding` では動きません。

| 重ねる表示 | 位置 |
|---|---|
| Pull to Refresh のインジケータ | ステータスバーの下端より下 |
| 最初の読み込み中・失敗 (項目なし)・空 | 上下のシステムバーの間の範囲の真ん中 |
| 次のページの読み込み中 | ナビゲーションバーの上端より上 |

```kotlin
@Composable
fun EdgeToEdgeFeedScreen(model: FeedModel, modifier: Modifier = Modifier) {
    val systemBars = WindowInsets.systemBars.union(WindowInsets.displayCutout).asPaddingValues()
    KsCollectionView(
        items = model.posts,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            top = systemBars.calculateTopPadding(),
            bottom = systemBars.calculateBottomPadding(),
        ),
        paging = KsPaging(
            state = model.pagingState,
            onLoadMore = { model.loadNextPage() },
        ),
        onRefresh = { model.refresh() },
    ) {
        template { post -> PostRow(post) }
    }
}
```

- 一覧の上に浮かせた自分の Composable を避けるために、下の `contentPadding` を広げて「次のページの読み込み中」の表示を持ち上げようとしないでください。この表示の位置は、システムバーだけで決まります。

## 実行中の読み込みが取り消される時機を知る

`onLoadMore` と `onRefresh` は、一覧に属するコルーチンで動きます。一覧がコンポジションから外れると、取り消されます。

- Navigation Compose (Compose 向けの Jetpack のナビゲーションのライブラリ) で次の画面へ進むと、前の画面はコンポジションから外れます。そのため、前の画面で動いていた読み込みは取り消されます。(iOS では、次の画面を積んでも一覧は残り、読み込みは続きます。)
- 取り消された取得は `CancellationException` を投げます。これを `Failed` にしないでください。`loadNextPage()` のように `Idle` に戻して投げ直せば、一覧が戻ってきたときに、また頼まれます。
- 一覧が無くなっても終わらせたい読み込みは、モデルが持つスコープで動かします。そのとき `onLoadMore` は、中断しないモデルの関数を呼びます。その関数は、状態を `Appending` にし、モデルのスコープで取得を始めて (`ViewModel` なら `viewModelScope.launch { ... }`)、すぐに戻ります。そのコルーチンは、一覧と一緒には取り消されません。結果は、`loadNextPage()` と同じ `generation` の判定を通してから反映します。
- 並べ替えで項目をドラッグしている間は、ライブラリは次のページを頼みません ([reorder.md](reorder.md) を参照)。
