# Showing a list

Recipes for showing an array with `KsCollectionView`, updating it, handling taps, and scrolling from code. The examples leave out the `import` lines: each needs the Compose and Material 3 names it uses and the library names from `jp.kamusoft.kscollectionview`. Later examples on this page reuse the types declared in earlier ones (`Contact`, `ContactRow`).

This Skill calls the `List` you pass "the array", to keep it apart from the list layout.

## Show an array of items

Pass the array, a `key` lambda that returns the stable ID of an item, and a template that draws one item. The array is your own model as it is: no wrapper type and no interface of the library is needed, so a model that comes from a module you cannot change (shared Kotlin Multiplatform code, for example) works as well.

```kotlin
data class Contact(val id: Int, val name: String)

@Composable
fun ContactRow(contact: Contact, modifier: Modifier = Modifier) {
    Text(
        text = contact.name,
        modifier = modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
    )
}

@Composable
fun ContactListScreen(contacts: List<Contact>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = contacts,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
    ) {
        template { contact -> ContactRow(contact) }
    }
}
```

Rules:

- The ID must be unique within the array and stable over time. The ID, not the whole value, is the identity of an item: an item whose content changes but whose ID stays the same keeps its cell and has only its content recomposed.
- The ID must be a type that can be saved in a `Bundle`: a string, a number, an enum, or a `Serializable` or `Parcelable` value. A plain `data class` or `value class` that implements neither is invalid input (see the last section).
- `KsCollectionView` also takes `layout` and `contentPadding` (see [layout.md](layout.md)). Without them you get a one-column list with separators and no padding.
- The list scrolls vertically. The template lambda may call any composable; the height of the row is measured from its content.
- A list with no items shows nothing of its own (an empty-list display exists only with paging, see [paging.md](paging.md)). For a list without paging, show your own composable while the array is empty, in place of the list or in a `Box` on top of it.
- A row whose natural width is smaller than the item width is centered horizontally. Give the row `Modifier.fillMaxWidth()` to make it fill the width, as the examples do.
- The trailing block has the receiver `KsCollectionViewScope<Item>`, which offers only `template` (`Item` is the type parameter and stands for your item type). The scope carries the `@DslMarker` annotation `@KsCollectionDsl`; you use neither name yourself.
- You may create the lambdas and the values `KsGroups(...)`, `KsPaging(...)`, and `KsReorder(...)` inline on every recomposition, as the examples do. No `remember` is needed: a new instance that does the same thing is not treated as a change.

`KsCollectionView` takes these parameters, in this order. Only `items`, `key`, and the trailing block are required; the examples pass the others by name.

| Parameter | Type | Default |
|---|---|---|
| `items` | `List<Item>` | required |
| `key` | `(Item) -> Any` | required |
| `modifier` | `Modifier` | `Modifier` |
| `template` | `((Item) -> Any)?` | `null` |
| `layout` | `KsLayout` | `KsLayout.List` |
| `contentPadding` | `PaddingValues` | `PaddingValues(0.dp)` |
| `header` | `(@Composable () -> Unit)?` | `null` |
| `footer` | `(@Composable () -> Unit)?` | `null` |
| `groups` | `KsGroups<Item, *>?` | `null` |
| `onItemTap` | `((Item) -> Unit)?` | `null` |
| `onItemLongTap` | `((Item) -> Unit)?` | `null` |
| `touchFeedbackColor` | `Color?` | `null` |
| `listSeparators` | `Boolean` | `true` |
| `listSeparatorColor` | `Color?` | `null` |
| `scrollController` | `KsScrollController?` | `null` |
| `prefetchResources` | `((Item) -> List<KsResource>)?` | `null` |
| `prefetchDestination` | `KsPrefetchDestination` | `KsPrefetchDestination.Disk` |
| `paging` | `KsPaging?` | `null` |
| `onRefresh` | `(suspend () -> Unit)?` | `null` |
| `reorder` | `KsReorder<Item>?` | `null` |
| `loadingIndicatorColor` | `Color?` | `null` |
| `content` (the trailing block) | `KsCollectionViewScope<Item>.() -> Unit` | required |

## Switch templates by item type

To draw different kinds of items with different composables, pass a `template` lambda that returns the template key of an item, and declare one `template(key) { ... }` per template key in the block.

```kotlin
enum class FeedKind { Message, Notice }

data class FeedEntry(val id: Int, val kind: FeedKind, val text: String)

@Composable
fun MixedFeedScreen(entries: List<FeedEntry>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = entries,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        template = { it.kind },
    ) {
        template(FeedKind.Message) { entry ->
            Text(text = entry.text, modifier = Modifier.fillMaxWidth().padding(16.dp))
        }
        template(FeedKind.Notice) { entry ->
            Row(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(text = "!", color = MaterialTheme.colorScheme.error)
                Text(text = entry.text)
            }
        }
    }
}
```

Rules:

- Declare a template for every value the `template` lambda can return. An item whose template key has no template is invalid input (see the last section).
- The template key is any value with `equals` and `hashCode`; an enum is the usual choice.
- The lambda of every `template` receives the item as the item type of the list (`FeedEntry` here), whatever the template key. With a sealed item type, cast to the subtype inside the lambda.
- `template { ... }` without a template key, as in the first example, is the form for a list with one template. Use it only when you do not pass the `template` argument.
- The composition of a row that scrolls off screen is reused for another item, but only for an item with the same template key. Different templates never exchange them.
- When the template key of an item changes while its ID stays the same, its cell is replaced, not recomposed in place.
- The block runs on every recomposition. Declare the same set of templates each time; do not add or drop a `template` call depending on state.
- On iOS the same registration is written with values of a type named `KsTemplate`. On Android it is the function `template`, so there is no type of that name here.

## Update the list by replacing the array

The list has no insert, delete, or move methods. Build a new array and pass it; the library computes the difference by ID and animates insertions, deletions, and moves. Sorting and filtering are done in your data layer in the same way.

```kotlin
class ContactListModel {
    var contacts by mutableStateOf(listOf<Contact>())
        private set

    fun add(contact: Contact) {
        contacts = listOf(contact) + contacts
    }

    fun remove(id: Int) {
        contacts = contacts.filterNot { it.id == id }
    }

    fun rename(id: Int, name: String) {
        contacts = contacts.map { if (it.id == id) it.copy(name = name) else it }
    }

    fun sortByName() {
        contacts = contacts.sortedBy { it.name }
    }
}

@Composable
fun EditableContactListScreen(model: ContactListModel, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = model.contacts,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
    ) {
        template { contact -> ContactRow(contact) }
    }
}
```

What the library guarantees:

- Items with the same ID and different content (`rename` above) keep their cell; only that cell's content is recomposed.
- While the start of the content is visible, an item inserted at the start of the array appears inside the visible range with an animation, and the list stays at the start. The same holds for the end. A list with paging replaces the rule for the end (see [paging.md](paging.md)).
- Only the cells in and near the visible range are composed. Memory does not grow in proportion to the number of items.

Rules:

- Pass a new `List` for every change. Do not keep one `MutableList`, change it in place, and pass the same instance again: the library looks at the array only when it receives a different one, so such a change does not reach the screen. "Different" means not equal by `equals`; the same instance is always equal to itself, and a new `List` with equal content changes nothing.
- Do not replace, while the list is on screen, the `key` or `template` lambda with one that computes something else, and do not change the set of declared templates. Write them as fixed parts of the call, not as values chosen by state. (An item whose own data changes so that `template` returns another template key is fine; see the previous section.) The `by` lambda of `KsGroups` is the one exception and may be switched (see [layout.md](layout.md)).
- When the list is scrolled to the middle and items are inserted or removed above the visible range, what is on screen does not move: the list keeps the first visible item in place, by its ID. (On iOS the list keeps its scroll offset instead, so what is on screen shifts.)
- The scroll position is saved with Compose's saved instance state. It comes back when the list is composed again with that state (after a rotation, or when returning to a screen on the Navigation Compose back stack), provided the array holds the items again by then. This is why IDs must be types that a `Bundle` can hold.
- Do not put elements that are not items (section titles, for example) into the array. Group headers are declared with `groups` (see [layout.md](layout.md)).

## Read parent state inside a row

A template may read state that lives outside the array, such as a set of expanded IDs or the selected ID. Read it directly: Compose tracks the read, and the visible rows are recomposed when the state changes.

```kotlin
@Composable
fun ExpandableContactListScreen(contacts: List<Contact>, modifier: Modifier = Modifier) {
    var expandedIds by remember { mutableStateOf(emptySet<Int>()) }
    KsCollectionView(
        items = contacts,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        onItemTap = { contact ->
            expandedIds = if (contact.id in expandedIds) expandedIds - contact.id else expandedIds + contact.id
        },
    ) {
        template { contact ->
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(16.dp),
            ) {
                Text(text = contact.name)
                if (contact.id in expandedIds) {
                    Text(text = "ID ${contact.id}", style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}
```

Rules:

- There is nothing to declare for this on Android. (On iOS such state has to be handed to the list with a dedicated modifier; that modifier has no counterpart here.)
- When the row height changes because of the state, as in the example, the change of height is animated. During that animation the outermost element of the template receives the animated row height as a constraint. Paint the row background on the outermost element, as the example does, or, if the outermost element is a `Box` that only wraps the content, give it `propagateMinConstraints = true`. Otherwise a gap shows through while the row collapses.
- The same holds for state read inside group headers.

## Keep state that must survive scrolling in your model

A row that scrolls far enough off screen leaves the composition, and the state it held with `remember` (expanded or not, text being typed) is discarded. When the item comes back, its row starts from its initial state. A `LaunchedEffect` in a row runs each time the row enters the composition.

- Keep anything that must survive scrolling (expanded or collapsed, selection, draft text) in the array or in parent state, as in the previous section.
- `remember` inside a row is fine for state that may reset, such as a press animation.
- State inside a row is kept while the row stays on screen, including when the array changes and the row is recomposed.

## Handle taps and long taps

```kotlin
@Composable
fun TappableContactListScreen(
    contacts: List<Contact>,
    onOpen: (Contact) -> Unit,
    onShowMenu: (Contact) -> Unit,
    modifier: Modifier = Modifier,
) {
    KsCollectionView(
        items = contacts,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        onItemTap = onOpen,
        onItemLongTap = onShowMenu,
        touchFeedbackColor = MaterialTheme.colorScheme.primary,
    ) {
        template { contact -> ContactRow(contact) }
    }
}
```

What the library guarantees:

- The callback receives the element of the array itself, on the main thread.
- A list with `onItemTap` or `onItemLongTap` presents each item to TalkBack as a clickable (and long-clickable) element. There is no parameter for the labels of those actions.
- Only lists that pass `onItemTap` or `onItemLongTap` show touch feedback. Without `touchFeedbackColor` the feedback is the standard Material ripple.
- Controls inside the row win. When a `Button`, a `Switch`, or anything `clickable` in the row handles the touch, neither the item callback nor the feedback fires. The item tap fires for touches on the rest of the row.
- A tap and a long tap are exclusive. A touch that became a long tap does not call `onItemTap`.
- While reordering is enabled, a long press starts a drag and `onItemLongTap` is not called (see [reorder.md](reorder.md)).

Rules:

- `touchFeedbackColor` sets only the hue of the ripple. The strength is decided by the standard ripple, so the opacity of the color you pass has no effect: an opaque color and a translucent one look the same while pressed.
- On iOS the same setting paints the color over the whole cell exactly as given, including its opacity, so the same color value does not look identical on the two platforms. A translucent color gives a similar look on both.

## Scroll from code

Create a `KsScrollController`, pass it as `scrollController`, and send commands to it. The controller is a plain object. When the screen owns it, create it with `rememberKsScrollController()`; when a `ViewModel` or another state holder owns it, construct `KsScrollController()` directly.

```kotlin
@Composable
fun ScrollableContactListScreen(contacts: List<Contact>, modifier: Modifier = Modifier) {
    val controller = rememberKsScrollController()
    Column(modifier = modifier.fillMaxSize()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Button(onClick = { controller.scrollToStart() }) { Text("Top") }
            Button(onClick = { controller.scrollTo(id = 50, position = KsScrollPosition.Center) }) {
                Text("Contact 50")
            }
            Button(onClick = { controller.scrollToEnd(animated = false) }) { Text("Bottom") }
        }
        KsCollectionView(
            items = contacts,
            key = { it.id },
            modifier = Modifier.weight(1f),
            scrollController = controller,
        ) {
            template { contact -> ContactRow(contact) }
        }
    }
}
```

| Command | Meaning |
|---|---|
| `scrollTo(id, position, animated)` | Scroll to the item with that ID. `position` is a `KsScrollPosition`: `Start` (default) puts the item at the top of the visible range, `Center` in the middle, `End` at the bottom |
| `scrollToStart(animated)` | Scroll to the start of the content (the top of the header, if there is one) |
| `scrollToEnd(animated)` | Scroll to the very end of the content, including what lies below the last item (the footer, and the "next page failed" and "end of list" paging displays) (on iOS the same command stops with the last item at the bottom of the visible range and does not bring a footer into view) |

`animated` defaults to `true` in all three.

What the library guarantees:

- A command runs after the latest array is on screen. If you append an item and call `scrollToEnd()` in the same function, the list reaches the new last item.
- Commands sent to a connected controller run in the order they were sent, and none is lost because an update or an earlier animation is in progress. A later command interrupts the animation of an earlier one, so the final position is that of the last command.
- Two kinds of command have no effect, and neither crashes: a command for an ID that is not in the array when it runs, and a command sent while the controller is not connected to a list (it is not kept for later).
- Positions are measured inside `contentPadding`: `Start` puts the top of the item at the lower edge of the top padding, and `End` puts its bottom at the upper edge of the bottom padding. (On iOS the item goes to the edge of the list itself.) A position that cannot be reached is clamped to the scrollable range, so items near either end stop at the end.
- A scroll caused by a command checks the paging condition like any other scroll (see [paging.md](paging.md)).
- The scroll position cannot be read: there are no scroll callbacks, and the internal `LazyGridState` is not exposed.
- With pinned group headers, `Start` places the item just below the pinned header, not behind it.

Rules:

- Pass an ID that is equal to what `key` returns for the item, with the same type. `scrollTo(id = "50")` and `scrollTo(id = 50L)` do not find an item whose ID is the `Int` `50`.
- Call the controller from the main thread. A call from another thread is invalid input (see the next section).
- Connect one controller to one list. If it is connected to several, only the last connection receives commands.
- Do not expect a command to run against the array as it was before an update. It is always resolved after the update.

## What happens with invalid input

For input that is a programming mistake, the library stops in debug builds so that you notice, and in release builds it keeps the screen working without crashing and leaves a warning in the log; the table says what is shown in each case. "Debug" and "release" mean your app: a build is treated as debug when the app is debuggable (`android:debuggable`, which the `debug` build type sets). In a debug build the stop is an `IllegalStateException` whose message names the mistake. Warnings go to Logcat at the warning level with the tag `KsCollectionView`.

| Invalid input | Debug build | Release build |
|---|---|---|
| An item whose template key has no declared `template` | Exception | An empty cell 1 dp high is shown at that position; the item count still matches the array |
| The same ID twice in the array | Exception | Only the later element is shown; the earlier one is not. The list keeps showing |
| Two `template` declarations for the same template key | Exception | The later declaration wins |
| A `key` that returns a type that cannot be saved in a `Bundle` | Exception | The library logs the warning and goes on, but Compose itself may throw when the item is first shown. Always return a savable type |
| The same group value at two separate places in the array (see [layout.md](layout.md)) | Exception | The items stay in array order and are shown as separate groups |
| A group value of a type that cannot be saved in a `Bundle` (see [layout.md](layout.md)) | Exception | Same as for `key` |
| A negative spacing in the layout (see [layout.md](layout.md)) | Exception | Treated as 0 |
| A column count of 0 or less (see [layout.md](layout.md)) | Exception | Treated as 1 column |
| A `minItemWidth` of 0 or less in `KsColumns.Adaptive` (see [layout.md](layout.md)) | Exception | Treated as 1 dp |
| A paging threshold that is negative or not finite (see [paging.md](paging.md)) | Exception | Treated as 0 |
| A fixed prefetch width that is 0, negative, not finite, or `Dp.Unspecified` (see [images.md](images.md)) | Exception | The resource is treated as having no width |
| An empty string as an image key (see [images.md](images.md)) | Exception | Treated as having no key |
| A resource ID in `KsImageSource.Resource` that cannot be read as a drawable (see [images.md](images.md)) | Exception | The failure display is shown |
| A `KsScrollController` command sent from a thread other than the main thread | Exception | Logged; do not rely on what happens next |

Scroll commands for a missing ID or an unconnected controller are not invalid input, because they can happen legitimately when a deletion races with the command. They are ignored in both configurations.
