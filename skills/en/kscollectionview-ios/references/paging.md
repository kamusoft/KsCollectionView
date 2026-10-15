# Paging and pull to refresh

Recipes for loading more items as the user nears the end of the list (paging, also called infinite scrolling), for pull to refresh, and for the model that drives them. Every example assumes `import SwiftUI` and `import KsCollectionView`. The examples on this page share the types declared in the first two sections (`Post`, `PostRow`, `PostService`, `FeedModel`).

The division of work: your model owns the array and a paging state, and decides what to fetch. The library reads the state, notices when the user is near the end, asks your model for the next page (that is, calls `onLoadMore`), and shows the loading, failure, end, and empty displays. The library never changes the state or the array.

Two words used on this page: a *refresh* loads the first page again and replaces the array with it. It is started either by the user's pull (pull to refresh) or by your own code; the second kind is also called a *reload*.

## Add paging to a list

Attach `.paging(_:threshold:onLoadMore:)` with the current state and the function that loads the next page.

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

The state is a `KsPagingState`, an enum without associated values. You set it; the library reacts to it.

| State | What the library does |
|---|---|
| `.idle` | Calls `onLoadMore` when the user is near the end. With no items at all, calls it right away: this is the first load |
| `.appending` | Does not ask. Shows the "loading the next page" display at the bottom when there are items, or the "first loading" display in the middle when there are none. Pull to refresh is not accepted |
| `.refreshing` | Does not ask. With no items, shows the "first loading" display. Once the list has been drawn in this state, the next replacement of the array is shown from the start of the content ("Reload from your own code" explains the condition) |
| `.failed` | Does not ask by itself. Asks only when the user triggers the retry action |
| `.endReached` | Never asks |

When the state is `.idle`, the library calls `onLoadMore` when this holds:

```text
itemsAfterLastVisible <= ceil(threshold * visibleItemCount)
```

- `itemsAfterLastVisible` is the number of items in the array after the last item that is on screen, and `visibleItemCount` is the number of items on screen.
- `threshold` is in screens and defaults to 1: the next page is requested when about one screen of items remains. `0` requests it when the last item comes on screen. A negative or non-finite threshold is invalid input (see [basics.md](basics.md)).
- Only items are counted, not group headers, the header, or the footer. Counting items rather than rows makes the timing the same for lists and grids.
- The condition is checked again on scrolling, when the array or the state changes, when the threshold changes, when the size of the list changes, and when `onLoadMore` returns. So when one page does not fill the screen, the library keeps asking, without any scrolling, until enough items remain.
- After asking once, the library does not ask again until two things have happened: `onLoadMore` has returned, and the list has received an update in which the state or the array is different from what it was at the request. This is what prevents double requests. A state that goes `.idle`, `.appending`, and back to `.idle` counts as changed, because the list saw `.appending` in between, even when the array is the same; this is why a model that returns an empty page and stays `.idle` is asked again and again.
- `threshold` is a `Double`. `onLoadMore` is `@MainActor () async -> Void`. It cannot throw; handle errors inside your model and express them as `.failed`. (On Android the corresponding callbacks may throw, and the library lets the exception propagate.)
- The display modifiers (`.pagingFailedFooter` and the others) can be written before or after `.paging`. On a list without `.paging` they have no effect.

## Write the model that owns the paging state

The library does not enforce the state transitions, so copy the following model and adapt it. `PostService` stands for your own API client. The model serves three features, and you can leave out the parts of a feature the screen does not have: paging needs `loadNextPage()`; pull to refresh adds `refresh()` and `refreshFailed`; reloading from your own code adds `reload()`, `scrollController`, and the `scrollsToStart` parameter. `generation` is needed only when the model also has `refresh()` or `reload()`; keep `isCancellation` in every case.

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

| Rule for your model | What happens otherwise |
|---|---|
| Do not start the first load yourself. Leave the state `.idle` with an empty array and the list asks for the first page | If your own first load is slow to set the state, the list asks too and the first page is loaded twice |
| Let `loadNextPage` run in two states: `.idle` (the next page, or the first page when the array is empty) and `.failed` (a retry). The retry of a list with no items also arrives as `onLoadMore`, not as a refresh, so the same function must be able to load the first page; the example gets this from `posts.last?.id` being `nil` | If it ignores `.failed`, retry does nothing |
| Set the state to `.appending` before `onLoadMore` returns: either await the fetch inside it, as above, or set the state first and then start your own task | Until the state changes, the user can pull to refresh, and the page that arrives late is appended to the refreshed list |
| Write the new array and the next state (`.idle` or `.endReached`) one right after the other, with no `await` between them, so that both reach the list in one update. The same for the refreshed array and its state | Setting `.endReached` before the array makes the list keep its end position and skip over the page that arrives. Returning to `.idle` before the refreshed array arrives means the result is not shown from the start |
| When everything is loaded, set `.endReached`. Do not return an empty page and stay `.idle` | The list keeps asking until the state becomes `.endReached`. A list with no items shows the empty display only in `.endReached` |
| When a refresh fails while items are shown, do not set `.failed`. Put the state back and tell the user yourself (the `refreshFailed` flag above) | A retry display appears right under the last item, and pressing it requests the next page, not a refresh |
| When you start a refresh, discard the results of loads started before it (the `generation` counter above) | The library does not prevent your own refresh from racing with a page load, so an old page is appended to the new list |
| Treat a cancelled load as cancelled, not as failed (the `isCancellation` function above) | The cancellation that happens when the list goes away is recorded as `.failed`, and the list does not ask again when the user comes back |
| If a load must not be cancelled when the list goes away, start it in a task owned by the model | `onLoadMore` and the refresh action run in tasks tied to the list and are cancelled with it (see the last section) |
| Keep the items of a group together across pages. If the next page starts with the group value the previous page ended with, that group simply grows; keeping the overall order valid is up to you | The same group value appears at two separate places, which is invalid input (see [layout.md](layout.md)) |

After a failed refresh the example returns to `.idle` when the state before it was `.appending` or `.refreshing`: that earlier load has been discarded by the generation check, so going back to `.appending` would leave the list stuck.

## Show the loading, failure, end, and empty displays

A list with paging shows at most one of six displays, chosen by the state and by whether there are items. Each has a modifier that supplies its content.

| State | With items | With no items |
|---|---|---|
| `.appending` | Loading the next page: `.pagingAppendingIndicator { }` | First loading: `.pagingLoadingPlaceholder { }` |
| `.failed` | Next page failed: `.pagingFailedFooter { retry in }` | Failed with no items: `.pagingFailedPlaceholder { retry in }` |
| `.endReached` | End of list: `.pagingEndReachedFooter { }` | Empty: `.pagingEmptyPlaceholder { }` |
| `.refreshing` | Nothing | First loading: `.pagingLoadingPlaceholder { }` |
| `.idle` | Nothing | Nothing |

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

Defaults:

- Only the two loading displays appear by default, as a standard `ProgressView` spinner without text or background. To show nothing, return `EmptyView()` from the modifier.
- The failure, end, and empty displays show nothing unless you supply them. Without a failure display there is no way to retry, and a list that also has no pull to refresh stays stopped after a failure. Without an empty display, a list with no items is blank. Supply at least `.pagingFailedFooter`, `.pagingFailedPlaceholder`, and `.pagingEmptyPlaceholder`. To stay short, some later examples on this page leave them out (`ReloadableFeedScreen` has no `.pagingFailedFooter`; `TintedFeedScreen` and `FullScreenFeedScreen` have none of the three). Add them when you copy those examples.
- These displays exist only on a list with `.paging`. For the empty display of a list without paging, see "Show an array of items" in [basics.md](basics.md).
- The library has no texts of its own. Error messages and their translations are yours, read from your model inside the display. The displays are rebuilt whenever `body` is re-evaluated (see "Read parent state inside a row" in [basics.md](basics.md)).
- `retry` is a `@MainActor () -> Void` closure. It calls `onLoadMore` whenever the state is `.failed`, whether or not there are items and whether or not the list has pull to refresh. It does nothing while `onLoadMore` is still running.
- While your own code refreshes a list that has items (state `.refreshing`), the library overlays nothing. Show your own progress if you want one.

Where they appear:

| Display | Place |
|---|---|
| Loading the next page | Overlaid at the bottom center of the visible range, 8 points above the bottom safe area. It does not scroll; items pass behind it. It fades in and out |
| Next page failed, end of list | After the last item and before the footer, as part of the scrolling content. They get the full width of the list inside the leading and trailing `contentPadding` (all columns in a grid), and your view is centered horizontally in it |
| First loading, failed with no items, empty | Overlaid in the middle of the visible range (excluding the top and bottom safe areas), in place of the items. The header and footer are still shown when there are no items; if they overlap, this display is in front |

Touches:

- The default "loading the next page" display does not take touches; the items under it can be tapped.
- A "loading the next page" display that you supply takes the taps within its bounds, even if it contains no button or other control, so the items under it cannot be tapped there. A drag that starts on it still scrolls the list.
- Controls inside the three no-items displays (the retry button) work even where the display overlaps the header or footer.

## Add pull to refresh

Use SwiftUI's own `.refreshable` on the list. The library has no modifier for it: `KsCollectionView` reads the refresh action from the environment. Because `.refreshable` is a SwiftUI modifier, it comes after all of the library's modifiers. It also works on a list without paging and on a list with no items.

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

What the library guarantees:

- The indicator is shown from the pull until the refresh action returns. On a list with paging it also stays while the state is `.refreshing`, for models whose action returns at once and sets the state later.
- An array replaced while the pull-initiated refresh is in progress is shown from the start of the content, however fast the fetch is and whatever the state was. If the refreshed array equals the old one, the list still returns to the start when the indicator goes away.
- A pull is not accepted while the state is `.appending` or while `onLoadMore` is running. This keeps a late page from being appended after the refreshed list. A pull is accepted while your own code is refreshing (state `.refreshing`); the `generation` check of the example then discards the older result.
- Setting the state to `.refreshing` without a pull does not show the indicator.

Rules:

- When the refresh fails and items are on screen, put the state back instead of setting `.failed`, and show your own notice, as `refreshFailed` does above (the notice of the example stays until the next refresh starts; dismiss yours as your design needs). With no items, `.failed` is right: the "failed with no items" display appears.
- If the user scrolls down while the indicator is showing and the refresh then fails with the array unchanged, the list goes back to the start when the indicator goes away. On Android the list stays where the user scrolled.

How the position is chosen when the array of a list with paging is replaced, in general:

| State just before the replacement | Position |
|---|---|
| `.refreshing`, and the list has been drawn in that state | The start of the content is shown, wherever the list was scrolled |
| `.endReached` | If the end was visible and items are added at the end, the list stays at the end |
| `.idle`, `.appending`, `.failed` | The list keeps its position; a new page appears below. It does not stick to the end, because that would immediately trigger the next request |

## Reload from your own code

A reload that your code starts (a reload button, a changed filter) is the same as a refresh for the model, with one extra concern: showing the result from the start. The list shows the start only if it has already been drawn once in the `.refreshing` state before the array is replaced. When the fetch finishes quickly, the change to `.refreshing` and the new array reach the list in a single update, and the list cannot tell that it was a refresh.

The simple remedy is to send `scrollToStart` together with the new array, as `FeedModel.reload()` does through the `KsScrollController` it owns. Scroll commands run after the new array is on screen.

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

- There is a second way, replacing the array only after the list has been drawn in the `.refreshing` state, but the library gives no signal for that moment. This Skill gives no code for it; use the `scrollToStart` remedy.
- A pull-initiated refresh needs neither: the library knows it started the refresh.

## Color the loading indicators

`.loadingIndicatorColor(_:)` sets one color for the three loading indicators the library draws: the default "loading the next page" display, the default "first loading" display, and the pull-to-refresh indicator.

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

- It also works on a list without `.paging`, where it colors the pull-to-refresh indicator.
- It does not affect displays you supply; color those yourself.
- Without it, the two loading displays use the `tint` of the surrounding SwiftUI view, and the pull-to-refresh indicator uses the system color.
- The pull-to-refresh indicator takes the hue of the color but is drawn lighter than the two loading displays, because the system control is translucent. Avoid colors close to the background. (On Android the color is applied to the indicator as it is.)
- There is no per-display color setting.

## Place a paged list full screen under the bars

When the list extends under the bars with `.ignoresSafeArea()` (see [layout.md](layout.md)), the three kinds of display that the library overlays respect the safe area. They are not part of the content, so `contentPadding` does not move them.

| Overlay | Position |
|---|---|
| Pull-to-refresh indicator | Below the bottom edge of the top bar |
| First loading, failed with no items, empty | The middle of the area between the top and bottom safe areas |
| Loading the next page | Above the top edge of the home indicator area |

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

- Do not enlarge the bottom `contentPadding` to lift the "loading the next page" display above something you float over the list. Its position depends only on the safe area.

## Know when a running load is cancelled

`onLoadMore` and the refresh action run in tasks that belong to the list. They are cancelled when the list is removed from the view hierarchy.

- Pushing another screen onto a `NavigationStack` keeps the list alive, so the load continues. (On Android, navigating forward discards the previous screen's UI and cancels the load.)
- Do not turn a cancelled load into `.failed`: go back to `.idle`, as `loadNextPage()` does, so that the list asks again when it returns. A cancelled fetch does not always throw `CancellationError`. The `async` functions of `URLSession` throw a `URLError` whose code is `.cancelled`, and other clients have errors of their own. `isCancellation` in `FeedModel` therefore checks `Task.isCancelled` first, so that any error that arrives after the task was cancelled counts as a cancellation, and then the two error types.
- A load that must finish even if the list goes away belongs in a task owned by the model. `onLoadMore` then calls a function of the model that is not `async`: it sets the state to `.appending`, starts the fetch in a `Task` that the model keeps, and returns at once. That task is not cancelled with the list; apply its result with the same `generation` check as `loadNextPage()`.
- While an item is being dragged for reordering, the library does not ask for the next page (see [reorder.md](reorder.md)).
