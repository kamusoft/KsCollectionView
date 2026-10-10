# Paging and pull to refresh

Recipes for loading more items as the user nears the end of the list (paging, also called infinite scrolling), for pull to refresh, and for the model that drives them. The examples leave out the `import` lines: each needs the Compose and Material 3 names it uses, the library names from `jp.kamusoft.kscollectionview`, and, where they appear, `kotlinx.coroutines` names and `java.io.IOException`. The examples on this page share the types declared in the first two sections (`Post`, `PostRow`, `PostService`, `FeedModel`).

The division of work: your model owns the array and a paging state, and decides what to fetch. The library reads the state, notices when the user is near the end, asks your model for the next page (that is, calls `onLoadMore`), and shows the loading, failure, end, and empty displays. The library never changes the state or the array.

Two words used on this page: a *refresh* loads the first page again and replaces the array with it. It is started either by the user's pull (pull to refresh) or by your own code; the second kind is also called a *reload*.

## Add paging to a list

Pass a `KsPaging` as `paging`, with the current state and the function that loads the next page.

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

The state is a `KsPagingState`, an enum. You set it; the library reacts to it.

| State | What the library does |
|---|---|
| `Idle` | Calls `onLoadMore` when the user is near the end. With no items at all, calls it right away: this is the first load |
| `Appending` | Does not ask. Shows the "loading the next page" display at the bottom when there are items, or the "first loading" display in the middle when there are none. Pull to refresh is not accepted |
| `Refreshing` | Does not ask. With no items, shows the "first loading" display. Once the list has been composed in this state, the next replacement of the array is shown from the start of the content ("Reload from your own code" explains the condition) |
| `Failed` | Does not ask by itself. Asks only when the user triggers the retry action |
| `EndReached` | Never asks |

When the state is `Idle`, the library calls `onLoadMore` when this holds:

```text
itemsAfterLastVisible <= ceil(threshold * visibleItemCount)
```

- `itemsAfterLastVisible` is the number of items in the array after the last item that is on screen, and `visibleItemCount` is the number of items on screen.
- `threshold` is a `Float`. Its unit is screens and its default is `1f`: the next page is requested when about one screen of items remains. `0f` requests it when the last item comes on screen. A negative or non-finite threshold is invalid input (see [basics.md](basics.md)).
- Only items are counted, not group headers, the header, or the footer. Counting items rather than rows makes the timing the same for lists and grids.
- The condition is checked again on scrolling, when the array or the state changes, when the threshold changes, when the size of the list changes, and when `onLoadMore` returns. So when one page does not fill the screen, the library keeps asking, without any scrolling, until enough items remain.
- After asking once, the library does not ask again until two things have happened: `onLoadMore` has returned, and the list has been recomposed with a state or an array that is different from what it was at the request. This is what prevents double requests. A state that goes `Idle`, `Appending`, and back to `Idle` counts as changed, because the list saw `Appending` in between, even when the array is the same; this is why a model that returns an empty page and stays `Idle` is asked again and again.
- `onLoadMore` is `suspend () -> Unit` and is called on the main thread. The library does not catch what it throws: an exception other than cancellation propagates like any uncaught coroutine exception and normally crashes the app. Catch failures inside your model and express them as `Failed`. The same holds for `onRefresh`. (On iOS the corresponding callbacks cannot throw.)
- The constructor is `KsPaging(state, onLoadMore, threshold = 1f, appendingIndicator = null, failedFooter = null, endReachedFooter = null, loadingPlaceholder = null, failedPlaceholder = null, emptyPlaceholder = null)`. The six displays are `(@Composable () -> Unit)?`, except the two failure displays, which are `(@Composable (retry: () -> Unit) -> Unit)?`. `KsPaging` exposes what you passed as read-only properties with the same names as its parameters.

## Write the model that owns the paging state

The library does not enforce the state transitions, so copy the following model and adapt it. `PostService` stands for your own API client, and `IOException` for whatever your client throws when a fetch fails. List every exception type your client uses for a failed fetch (HTTP errors and parse errors too) in those `catch` clauses: an exception that is not caught there leaves the state `Appending` and travels out of `onLoadMore`, which normally crashes the app.

The model serves three features, and you can leave out the parts of a feature the screen does not have: paging needs `loadNextPage()`; pull to refresh adds `refresh()` and `refreshFailed`; reloading from your own code adds `reload()`, `scrollController`, and the `scrollsToStart` parameter. `generation` and `restored` are needed only when the model also has `refresh()` or `reload()`; keep the two `catch` clauses in every case.

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

| Rule for your model | What happens otherwise |
|---|---|
| Do not start the first load yourself. Leave the state `Idle` with an empty array and the list asks for the first page | If your own first load is slow to set the state, the list asks too and the first page is loaded twice |
| Let `loadNextPage` run in two states: `Idle` (the next page, or the first page when the array is empty) and `Failed` (a retry). The retry of a list with no items also arrives as `onLoadMore`, not as a refresh, so the same function must be able to load the first page; the example gets this from `posts.lastOrNull()?.id` being `null` | If it ignores `Failed`, retry does nothing |
| Set the state to `Appending` before `onLoadMore` returns: either suspend on the fetch inside it, as above, or set the state first and then launch your own coroutine | Until the state changes, the user can pull to refresh, and the page that arrives late is appended to the refreshed list |
| Write the new array and the next state (`Idle` or `EndReached`) one right after the other, with no suspension point between them, so that both reach the list in one recomposition. The same for the refreshed array and its state | Setting `EndReached` before the array makes the list keep its end position and skip over the page that arrives. Returning to `Idle` before the refreshed array arrives means the result is not shown from the start |
| When everything is loaded, set `EndReached`. Do not return an empty page and stay `Idle` | The list keeps asking until the state becomes `EndReached`. A list with no items shows the empty display only in `EndReached` |
| When a refresh fails while items are shown, do not set `Failed`. Put the state back and tell the user yourself (the `refreshFailed` flag above) | A retry display appears right under the last item, and pressing it requests the next page, not a refresh |
| When you start a refresh, discard the results of loads started before it (the `generation` counter above) | The library does not prevent your own refresh from racing with a page load, so an old page is appended to the new list |
| Catch only the exceptions that mean a failed fetch. Never turn `CancellationException` into `Failed`; put the state back and rethrow it, as above. If your client reports a cancelled call with an exception type of its own, treat that type like `CancellationException` | A broad `catch (e: Exception)` also catches the cancellation that happens when the list goes away. The state stays `Failed`, and the list does not ask again when the user comes back |
| If a load must not be cancelled when the list goes away, launch it in a scope owned by the model (`viewModelScope`, for example) | `onLoadMore` and `onRefresh` run in coroutines tied to the list and are cancelled with it (see the last section) |
| Keep the items of a group together across pages. If the next page starts with the group value the previous page ended with, that group simply grows; keeping the overall order valid is up to you | The same group value appears at two separate places, which is invalid input (see [layout.md](layout.md)) |

After a failed refresh the example returns to `Idle` when the state before it was `Appending` or `Refreshing`: that earlier load has been discarded by the generation check, so going back to `Appending` would leave the list stuck.

## Show the loading, failure, end, and empty displays

A list with paging shows at most one of six displays, chosen by the state and by whether there are items. Each has a parameter of `KsPaging` that supplies its content.

| State | With items | With no items |
|---|---|---|
| `Appending` | Loading the next page: `appendingIndicator = { }` | First loading: `loadingPlaceholder = { }` |
| `Failed` | Next page failed: `failedFooter = { retry -> }` | Failed with no items: `failedPlaceholder = { retry -> }` |
| `EndReached` | End of list: `endReachedFooter = { }` | Empty: `emptyPlaceholder = { }` |
| `Refreshing` | Nothing | First loading: `loadingPlaceholder = { }` |
| `Idle` | Nothing | Nothing |

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

Defaults:

- Only the two loading displays appear by default, as a standard Material `CircularProgressIndicator` without text or background. To show nothing, pass an empty lambda (`appendingIndicator = { }`).
- The failure, end, and empty displays show nothing unless you supply them. Without a failure display there is no way to retry, and a list that also has no pull to refresh stays stopped after a failure. Without an empty display, a list with no items is blank. Supply at least `failedFooter`, `failedPlaceholder`, and `emptyPlaceholder`. To stay short, some later examples on this page leave them out (`ReloadableFeedScreen` has no `failedFooter`; `TintedFeedScreen` and `EdgeToEdgeFeedScreen` have none of the three). Add them when you copy those examples.
- These displays exist only on a list with `paging`. For the empty display of a list without paging, see "Show an array of items" in [basics.md](basics.md).
- The library has no texts of its own. Error messages and their translations are yours, read from your model inside the display.
- `retry` is a `() -> Unit`. It calls `onLoadMore` whenever the state is `Failed`, whether or not there are items and whether or not the list has pull to refresh. It does nothing while `onLoadMore` is still running.
- While your own code refreshes a list that has items (state `Refreshing`), the library overlays nothing. Show your own progress if you want one.

Where they appear:

| Display | Place |
|---|---|
| Loading the next page | Overlaid at the bottom center of the visible range, 8 dp above the bottom system bar. It does not scroll; items pass behind it. It fades in and out |
| Next page failed, end of list | After the last item and before the footer, as part of the scrolling content. They get the full width of the content inside the horizontal `contentPadding` (all columns in a grid), and your composable is centered horizontally in it |
| First loading, failed with no items, empty | Overlaid in the middle of the visible range (excluding the top and bottom system bars), in place of the items. The header and footer are still shown when there are no items; if they overlap, this display is in front |

Touches:

- The default "loading the next page" display does not take touches; the items under it can be tapped.
- A "loading the next page" display that you supply takes the taps within its bounds, even if it contains no button or other control, so the items under it cannot be tapped there. A drag that starts on it still scrolls the list.
- Controls inside the three no-items displays (the retry button) work even where the display overlaps the header or footer.

## Add pull to refresh

Pass the refresh function as `onRefresh`. It is an argument of `KsCollectionView`, not of `KsPaging`, so it also works on a list without paging, and on a list with no items.

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

What the library guarantees:

- The indicator is the Material 3 pull-to-refresh indicator. It is shown from the pull until `onRefresh` returns. On a list with paging it also stays while the state is `Refreshing`, for models whose function returns at once and sets the state later.
- An array replaced while the pull-initiated refresh is in progress is shown from the start of the content, however fast the fetch is and whatever the state was. This also holds on a list without paging.
- A pull is not accepted while the state is `Appending` or while `onLoadMore` is running. This keeps a late page from being appended after the refreshed list. A pull is accepted while your own code is refreshing (state `Refreshing`); the `generation` check of the example then discards the older result.
- Setting the state to `Refreshing` without a pull does not show the indicator.

Rules:

- When the refresh fails and items are on screen, put the state back instead of setting `Failed`, and show your own notice, as `refreshFailed` does above (the notice of the example stays until the next refresh starts; dismiss yours as your design needs). With no items, `Failed` is right: the "failed with no items" display appears.
- If the user scrolls down while the indicator is showing and the refresh then fails with the array unchanged, the list stays where the user scrolled. On iOS the list goes back to the start in that case.

How the position is chosen when the array of a list with paging is replaced, in general:

| State just before the replacement | Position |
|---|---|
| `Refreshing`, and the list has been composed in that state | The start of the content is shown, wherever the list was scrolled |
| `EndReached` | If the end was visible and items are added at the end, the list stays at the end |
| `Idle`, `Appending`, `Failed` | The list keeps its position; a new page appears below. It does not stick to the end, because that would immediately trigger the next request |

## Reload from your own code

A reload that your code starts (a reload button, a changed filter) is the same as a refresh for the model, with one extra concern: showing the result from the start. The list shows the start only if it has already been composed once in the `Refreshing` state before the array is replaced. When the fetch finishes quickly, the change to `Refreshing` and the new array reach the list in a single recomposition, and the list cannot tell that it was a refresh.

The simple remedy is to send `scrollToStart` together with the new array, as `FeedModel.reload()` does through the `KsScrollController` it owns. Scroll commands run after the new array is on screen.

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

- There is a second way, replacing the array only after the list has been composed in the `Refreshing` state, but the library gives no signal for that moment. This Skill gives no code for it; use the `scrollToStart` remedy.
- A pull-initiated refresh needs neither: the library knows it started the refresh.

## Color the loading indicators

`loadingIndicatorColor` sets one color for the three loading indicators the library draws: the default "loading the next page" display, the default "first loading" display, and the pull-to-refresh indicator.

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

- It also works on a list without `paging`, where it colors the pull-to-refresh indicator.
- It does not affect displays you supply; color those yourself.
- Without it, the two loading displays use the `primary` color of the Material theme, and the pull-to-refresh indicator uses the Material default.
- On the pull-to-refresh indicator the color is applied to the arrow as it is, and the round container keeps the theme color. Avoid a color that does not stand out from the container (white in a light theme, for example). (On iOS the indicator takes the hue of the color but is drawn lighter.)
- There is no per-display color setting.

## Place a paged list full screen under the bars

When the list extends under the system bars in an edge-to-edge activity (see [layout.md](layout.md)), the three kinds of display that the library overlays respect the bars. They are not part of the content, so `contentPadding` does not move them.

| Overlay | Position |
|---|---|
| Pull-to-refresh indicator | Below the bottom edge of the status bar |
| First loading, failed with no items, empty | The middle of the area between the top and bottom system bars |
| Loading the next page | Above the top edge of the navigation bar |

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

- Do not enlarge the bottom `contentPadding` to lift the "loading the next page" display above something you float over the list. Its position depends only on the system bars.

## Know when a running load is cancelled

`onLoadMore` and `onRefresh` run in coroutines that belong to the list. They are cancelled when the list leaves the composition.

- Navigating forward with Navigation Compose (the Jetpack navigation library for Compose) removes the previous screen from the composition, so a load running on that screen is cancelled. (On iOS, pushing another screen keeps the list alive and the load continues.)
- A cancelled fetch throws `CancellationException`. Do not turn it into `Failed`: go back to `Idle` and rethrow, as `loadNextPage()` does, so that the list asks again when it returns.
- A load that must finish even if the list goes away belongs in a scope owned by the model. `onLoadMore` then calls a function of the model that does not suspend: it sets the state to `Appending`, launches the fetch in the model's scope (`viewModelScope.launch { ... }` in a `ViewModel`), and returns at once. That coroutine is not cancelled with the list; apply its result with the same `generation` check as `loadNextPage()`.
- While an item is being dragged for reordering, the library does not ask for the next page (see [reorder.md](reorder.md)).
