# Showing a list

Recipes for showing an array with `KsCollectionView`, updating it, handling taps, and scrolling from code. Every example assumes `import SwiftUI` and `import KsCollectionView`. Later examples on this page reuse the types declared in earlier ones (`Contact`, `ContactRow`).

## Show an array of items

Pass the array and a closure that draws one item. The item type must be `Equatable` and `Identifiable`. The array is your own model as it is: no wrapper type and no protocol of the library is needed.

```swift
struct Contact: Identifiable, Equatable {
    let id: Int
    var name: String
}

struct ContactRow: View {
    let contact: Contact

    var body: some View {
        Text(contact.name)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}

struct ContactListScreen: View {
    let contacts: [Contact]

    var body: some View {
        KsCollectionView(contacts) { contact in
            ContactRow(contact: contact)
        }
    }
}
```

When the type is not `Identifiable` and you cannot change it (a model shared from another module, for example), point at the ID with a key path. The type still has to be `Equatable`.

```swift
struct SharedContact: Equatable {
    let contactId: String
    let name: String
}

struct SharedContactListScreen: View {
    let contacts: [SharedContact]

    var body: some View {
        KsCollectionView(contacts, id: \.contactId) { contact in
            Text(contact.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
}
```

Rules:

- The ID must be unique within the array and stable over time. The ID, not the whole value, is the identity of an item: an item whose content changes but whose ID stays the same keeps its cell and has only its content rebuilt.
- The initializers also take `layout:` and `contentPadding:` (see [layout.md](layout.md)). Without them you get a one-column list with separators and no padding. Every initializer takes its arguments in the same order, and you leave out the ones you do not use: the array, `id:`, `template:`, `layout:`, `contentPadding:`, then the trailing closure. For example: `KsCollectionView(contacts, id: \.contactId, layout: .list(rowSpacing: 8), contentPadding: EdgeInsets()) { ... }`.
- The item type needs nothing beyond `Equatable` and an ID: `Sendable` is not required, and the ID is any `Hashable` value. Use value types; a class instance changed in place is not seen as changed.
- The view fills the space its parent offers and scrolls vertically. The row closure may return any SwiftUI view; its height is measured from its content.
- A list with no items shows nothing of its own (an empty-list display exists only with paging, see [paging.md](paging.md)). For a list without paging, show your own view while the array is empty, in place of the list or in an `.overlay` on it.
- A row whose natural width is smaller than the item width is centered horizontally. Give the row `.frame(maxWidth: .infinity, alignment: .leading)` to make it fill the width and align its content, as the examples do.

## Switch templates by item type

To draw different kinds of items with different views, pass a key path to a `Hashable` value with `template:` and register one `KsTemplate` per value.

```swift
enum FeedKind: Hashable {
    case message
    case notice
}

struct FeedEntry: Identifiable, Equatable {
    let id: Int
    let kind: FeedKind
    let text: String
}

struct MixedFeedScreen: View {
    let entries: [FeedEntry]

    var body: some View {
        KsCollectionView(entries, template: \.kind) {
            KsTemplate(.message) { entry in
                Text(entry.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            KsTemplate(.notice) { entry in
                Label(entry.text, systemImage: "exclamationmark.circle.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
    }
}
```

Rules:

- Register a template for every value the key path can return. An item whose value has no template is invalid input (see the last section).
- A cell that scrolls off screen is reused for another item, but only for an item with the same template value. Cells of different templates are never exchanged.
- The closure of every `KsTemplate` receives the item as the item type of the list (`FeedEntry` here), whatever the key.
- When the template value of an item changes while its ID stays the same, its cell is replaced, not rebuilt in place.
- For a type that is not `Identifiable`, use both key paths: `KsCollectionView(entries, id: \.entryId, template: \.kind) { ... }`.
- The block of `KsTemplate` values is collected by the result builder `KsTemplateBuilder`. You do not call the builder yourself, and the block takes only `KsTemplate` expressions (no `if` or `for`).
- On Android the same registration is written by calling a function named `template` inside the content block, so there is no type named `KsTemplate` there.

## Update the list by replacing the array

The list has no insert, delete, or move methods. Change your array and pass the new array; the library computes the difference by ID and animates insertions, deletions, and moves. Sorting and filtering are done in your data layer in the same way.

```swift
@MainActor
final class ContactListModel: ObservableObject {
    @Published private(set) var contacts: [Contact] = []

    func add(_ contact: Contact) {
        contacts.insert(contact, at: 0)
    }

    func remove(id: Contact.ID) {
        contacts.removeAll { $0.id == id }
    }

    func rename(id: Contact.ID, to name: String) {
        guard let index = contacts.firstIndex(where: { $0.id == id }) else { return }
        contacts[index].name = name
    }

    func sortByName() {
        contacts.sort { $0.name < $1.name }
    }
}

struct EditableContactListScreen: View {
    @StateObject private var model = ContactListModel()

    var body: some View {
        KsCollectionView(model.contacts) { contact in
            ContactRow(contact: contact)
        }
    }
}
```

What the library guarantees:

- Items with the same ID and different content (`rename` above) keep their cell; only that cell's content is rebuilt.
- While the start of the content is visible, an item inserted at the start of the array appears inside the visible range with an animation, and the list stays at the start. The same holds for the end. A list with paging replaces the rule for the end (see [paging.md](paging.md)).
- Only the cells in and near the visible range exist. Memory does not grow in proportion to the number of items.

Rules:

- Do not change, while the list is on screen, the key paths passed as `id:` and `template:`, or the set of registered templates. Such a change is not reflected. Write them as fixed parts of the `KsCollectionView(...)` expression, not as values chosen by state. (An item whose own template value changes is fine; see the previous section.) The key path of `.groups(by:)` is the one exception and may be switched (see [layout.md](layout.md)).
- "A new array" means an array that is not equal (`==`) to the one on screen. Passing an equal array again changes nothing.
- When the list is scrolled to the middle and items are inserted or removed above the visible range, the list keeps its scroll offset, not the items on screen: what is on screen shifts by the height that was added or removed. (On Android the first visible item stays where it is.)
- Do not put elements that are not items (section titles, for example) into the array. Group headers are declared with `.groups` (see [layout.md](layout.md)).

## Read parent state inside a row

When the row closure reads state that lives outside the array, such as a set of expanded IDs or the selected ID, pass that state to `.observedValue(_:)`. The value must be `Hashable`.

```swift
struct ExpandableContactListScreen: View {
    let contacts: [Contact]
    @State private var expandedIDs: Set<Int> = []

    var body: some View {
        KsCollectionView(contacts) { contact in
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                if expandedIDs.contains(contact.id) {
                    Text("ID \(contact.id)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .observedValue(expandedIDs)
        .onItemTap { contact in
            expandedIDs.formSymmetricDifference([contact.id])
        }
    }
}
```

Why it is needed: the row closure runs after SwiftUI has finished evaluating `body`, so SwiftUI does not track state that is read only inside the closure. Changing such state does not re-evaluate `body`, and nothing reaches the visible cells. Passing the state to `.observedValue` reads it in `body` and tells the library when to rebuild the cells.

Rules:

- Put every piece of state the row closure reads into the one value. With several pieces, wrap them in one `Hashable` struct. When the array is unchanged, the visible cells are rebuilt only when the observed value changes; changes to anything else do not reach them.
- When the row height changes because of the state, as in the example, the change of height is animated.
- A list without `.observedValue` falls back to rebuilding the visible cells every time `body` is re-evaluated with an equal array. This fallback reaches the cells only when something else re-evaluates `body` (the state is also read in `body` outside the closure, or it is a `@Published` property of a model the screen observes), and it has a gap: when the array changes in the same update, the cells of unchanged items keep the old state. Always use `.observedValue` for state that rows read.
- The same rule applies to state read inside group headers.
- The header, the footer, and the paging displays are not governed by `.observedValue`: they are rebuilt every time `body` is re-evaluated. State they read only has to re-evaluate `body`. A `@Published` property of a model the screen observes does; a `@State` that is read only inside those closures does not, so read it in `body` too.
- Rows, the header and footer, group headers, and the paging displays are hosted inside UIKit cells, and the library does not pass the SwiftUI environment of the screen on to them. Do not rely on `.environmentObject`, custom `@Environment` values, or modifiers such as `.font` applied outside the list reaching a row; hand a row what it needs through its initializer. Light and dark appearance does follow the place where the list is shown.
- This modifier exists only on iOS. On Android, Compose subscribes to the state automatically and there is nothing to declare.

## Keep state that must survive scrolling in your model

A cell that scrolls off screen is reused for another item, and the SwiftUI state inside the row (`@State`, focus, text being typed) does not survive that. When the item comes back, its row starts from its initial state. `onAppear` and `.task` in a row run each time the row comes into the visible range.

- Keep anything that must survive scrolling (expanded or collapsed, selection, draft text) in the array or in parent state passed with `.observedValue`, as in the previous section.
- `@State` inside a row is fine for state that may go back to its initial value, such as a press animation.
- The row closure receives the item as a value, not as a `Binding`. To change data from a control in a row (a `Toggle`, a `TextField`), call a function of your model that replaces the array, and keep a draft that must survive in the model.
- State inside a row is kept while the row stays on screen, including when the visible cells are rebuilt after the array or the observed value changes.

## Handle taps and long taps

```swift
struct TappableContactListScreen: View {
    let contacts: [Contact]
    @State private var opened: Contact?
    @State private var menuTarget: Contact?

    var body: some View {
        KsCollectionView(contacts) { contact in
            ContactRow(contact: contact)
        }
        .onItemTap { contact in
            opened = contact
        }
        .onItemLongTap { contact in
            menuTarget = contact
        }
        .touchFeedback(color: .accentColor.opacity(0.1))
    }
}
```

What the library guarantees:

- The callback receives the element of the array itself, on the main thread. Its type is a plain `(Item) -> Void` (`Item` stands for your item type), with neither `@MainActor` nor `@Sendable`; written inside `body`, as above, it can change `@State` and call a `@MainActor` model directly.
- Only lists that declare `.onItemTap` or `.onItemLongTap` show touch feedback. Without `.touchFeedback(color:)` the feedback is the standard highlight: while pressed, the cell is covered with the system fill color (`UIColor.systemFill`, a translucent gray).
- Controls inside the row win. When a `Button` or `Toggle` in the row handles the touch, neither the item callback nor the feedback fires. The item tap fires for touches on the rest of the row.
- A tap and a long tap are exclusive. A touch that became a long tap does not fire `.onItemTap`.
- While reordering is enabled, a long press starts a drag and `.onItemLongTap` is not called (see [reorder.md](reorder.md)).

Rules:

- `.touchFeedback(color:)` paints the color over the whole cell exactly as given, including its opacity. An opaque color hides the row while it is pressed, so pass a translucent color. To show no feedback, pass `.clear`.
- On Android the same setting uses only the hue of the color and the standard Android touch effect (the ripple) decides the strength, so the same color value does not look identical on the two platforms. A translucent color gives a similar look on both.

## Scroll from code

Create a `KsScrollController`, connect it with `.scrollController(_:)`, and send commands to it. The controller is a plain object: a view can hold it in `@State`, or a model can own it.

```swift
struct ScrollableContactListScreen: View {
    let contacts: [Contact]
    @State private var controller = KsScrollController()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Top") { controller.scrollToStart() }
                Spacer()
                Button("Contact 50") { controller.scrollTo(id: 50, position: .center) }
                Spacer()
                Button("Bottom") { controller.scrollToEnd(animated: false) }
            }
            .padding()

            KsCollectionView(contacts) { contact in
                ContactRow(contact: contact)
            }
            .scrollController(controller)
        }
    }
}
```

| Command | Meaning |
|---|---|
| `scrollTo(id:position:animated:)` | Scroll to the item with that ID. `position` is a `KsScrollPosition`: `.start` (default) puts the item at the top of the visible range, `.center` in the middle, `.end` at the bottom |
| `scrollToStart(animated:)` | Scroll to the start of the content (the top of the header, if there is one) |
| `scrollToEnd(animated:)` | Scroll until the last item sits at the bottom of the visible range. What lies below the last item (the footer, and the "next page failed" and "end of list" paging displays) is not brought into view (on Android the same command goes to the very end, footer included) |

`animated` defaults to `true` in all three.

What the library guarantees:

- A command runs after the latest array is on screen. If you append an item and call `scrollToEnd()` in the same function, the list reaches the new last item.
- Commands sent to a connected controller run in the order they were sent, and none is lost because an update or an earlier animation is in progress. A later command interrupts the animation of an earlier one, so the final position is that of the last command.
- Two kinds of command have no effect, and neither crashes: a command for an ID that is not in the array when it runs, and a command sent while the controller is not connected to a list (it is not kept for later).
- Positions refer to the edges of the list itself: `.start` puts the top of the item at the top edge of the list, and `.end` puts its bottom at the bottom edge. The top and bottom `contentPadding` are part of the scrolling content and are not kept clear. (On Android the item stops inside the padding instead.) A position that cannot be reached is clamped to the scrollable range, so items near either end stop at the end.
- A scroll caused by a command checks the paging condition like any other scroll (see [paging.md](paging.md)).
- The scroll position cannot be read, and it is not saved. It lasts as long as SwiftUI keeps the view (under a pushed screen, through a rotation); a list that is created anew starts at the start of the content.
- With pinned group headers, `.start` places the item just below the pinned header, not behind it.

Rules:

- Pass the ID with the same type as the item's ID. `scrollTo(id: "50")` does not find an item whose ID is the integer `50`.
- `KsScrollController` is isolated to the main actor. Call it from the main actor.
- Connect one controller to one list. If it is connected to several, only the last connection receives commands.
- Do not expect a command to run against the array as it was before an update. It is always resolved after the update.

## What happens with invalid input

For input that is a programming mistake, the library stops in debug builds so that you notice, and in release builds it keeps the screen working without crashing and leaves a warning in the log; the table says what is shown in each case, and marks the two rows that differ from this. "Debug" and "release" mean the build configuration of your app. Warnings go to Apple's unified logging system with the subsystem `jp.kamusoft.kscollectionview`; read them in the Xcode console or in the Console app, filtered by that subsystem.

| Invalid input | Debug build | Release build |
|---|---|---|
| An item whose template value has no registered `KsTemplate` | Assertion failure | An empty cell 1 point high is shown at that position; the item count still matches the array |
| The same ID twice in the array | Assertion failure | Only the later element is shown; the earlier one is not. The list keeps showing |
| Two `KsTemplate` values registered for the same key | Does not stop: the later registration wins, with a warning in the log | The later registration wins |
| The same group value at two separate places in the array (see [layout.md](layout.md)) | Assertion failure | The items stay in array order and are shown as separate groups |
| A negative spacing in the layout (see [layout.md](layout.md)) | Assertion failure | Treated as 0 |
| A column count of 0 or less (see [layout.md](layout.md)) | Assertion failure | Treated as 1 column, with no warning in the log |
| A paging threshold that is negative or not finite (see [paging.md](paging.md)) | Assertion failure | Treated as 0 |
| A fixed prefetch width that is 0, negative, or not finite (see [images.md](images.md)) | Assertion failure | The resource is treated as having no width |
| An empty string as an image key (see [images.md](images.md)) | Assertion failure | Treated as having no key |

`KsGridColumns.adaptive(minItemWidth:)` also asserts in debug builds when the width is 0 or less. Unlike the rows above, it has no defined fallback in release builds, so always pass a positive width.

Scroll commands for a missing ID or an unconnected controller are not invalid input, because they can happen legitimately when a deletion races with the command. They are ignored in both configurations.
