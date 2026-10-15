# Reordering by drag and drop

Recipes for letting the user reorder items with a long press and a drag. Every example assumes `import SwiftUI` and `import KsCollectionView`. The examples on this page share the types declared in the first section (`TaskSection`, `TaskItem`, `TaskRow`, `TaskListModel`).

The division of work: the library detects the long press, lifts the item, scrolls at the edges, and works out where the item was dropped. It never changes your array. When the user drops the item, it tells your model what moved where, once, and your model reorders its own array and passes it back.

## Turn on reordering

Attach `.reorder(isEnabled:canMove:canDrop:accessibilityActions:onMove:)`. `isEnabled` is the reorder switch, a `Bool` that you own. `onMove` is called when the user drops an item, and returns whether you accept the move.

```swift
enum TaskSection: String, Hashable {
    case today
    case later
    case archived
}

struct TaskItem: Identifiable, Equatable, Sendable {
    let id: Int
    var title: String
    var section: TaskSection
    var isLocked = false
}

struct TaskRow: View {
    let task: TaskItem

    var body: some View {
        Text(task.title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
    }
}

@MainActor
final class TaskListModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem]
    @Published var isReordering = false

    init(tasks: [TaskItem]) {
        self.tasks = tasks
    }

    func move(_ move: KsReorderMove<TaskItem>) -> Bool {
        var next = tasks
        guard let from = next.firstIndex(where: { $0.id == move.item.id }) else { return false }
        var moved = next.remove(at: from)
        let section = move.group?.base as? TaskSection
        switch move.destination {
        case .before(let target):
            guard let index = next.firstIndex(where: { $0.id == target.id }) else { return false }
            moved.section = section ?? next[index].section
            next.insert(moved, at: index)
        case .end:
            if let section {
                moved.section = section
                let last = next.lastIndex(where: { $0.section == section })
                next.insert(moved, at: last.map { $0 + 1 } ?? next.count)
            } else {
                moved.section = next.last?.section ?? moved.section
                next.append(moved)
            }
        }
        tasks = next
        return true
    }

    func restore(_ tasks: [TaskItem]) {
        self.tasks = tasks
    }
}

struct TaskListScreen: View {
    @StateObject private var model: TaskListModel

    init(tasks: [TaskItem]) {
        _model = StateObject(wrappedValue: TaskListModel(tasks: tasks))
    }

    var body: some View {
        VStack(spacing: 0) {
            Toggle("Reorder", isOn: $model.isReordering)
                .padding()
            KsCollectionView(model.tasks) { task in
                TaskRow(task: task)
            }
            .reorder(isEnabled: model.isReordering) { move in
                model.move(move)
            }
        }
    }
}
```

While the switch is on:

- A long press anywhere on an item lifts it and starts the drag. There is no drag handle.
- The long press belongs to reordering, so `.onItemLongTap` is not called, not even for items that cannot be moved. `.onItemTap` is still called. A list whose switch is always on therefore cannot use `.onItemLongTap`.
- It works the same in a list and in a grid.

While the switch is off, or on a list without `.reorder`, a long press does not start a drag and `.onItemLongTap` works as usual.

## Apply the move to your array

`onMove` receives a `KsReorderMove<Item>` (`Item` stands for your item type) and is called exactly once per drop, when the finger is lifted. It is declared `@MainActor` and runs on the main actor. It is not called while the item passes over other items during the drag.

| Property of `KsReorderMove` | Meaning |
|---|---|
| `item` | The item that was moved. It is the element of your array itself |
| `destination` | A `KsReorderDestination<Item>`: `.before(other)` when an item of the same group follows the drop position, or `.end` when the item was dropped at the end of the group (the end of the list when no groups are declared) |
| `group` | The group value of the group it was dropped in, as `AnyHashable?`. `nil` when the list declares no groups. Cast it back with `move.group?.base as? YourGroupType` |

The destination is expressed by an item, not by an index, so it keeps its meaning even if your array changed between the drop and your handler. `KsReorderMove` has a public initializer, `KsReorderMove(item:destination:group:)`, so you can unit-test your model's `move` function without a list.

`onMove` is not called when the item is dropped back at its original position, dropped where `canDrop` returns `false`, dropped outside the bounds of the list, or when the drag is cancelled. In those cases the item goes back to where it was. An item cannot be dragged to another list or out of the app.

What you return:

| Return value | What the list does |
|---|---|
| `true` (accepted) | Keeps the item where it was dropped and waits for your reordered array. When an array arrives that is not equal (`==`) to the array the list had at the drop, the list follows it. An array equal to that one changes nothing. It never reverts by itself after some time |
| `false` (not accepted) | Moves the item back to its original position |

Rules:

- If you return `true`, reorder your array and pass it to the list, inside `onMove` or later. If you accept without reordering, the list and your array stay out of step until the next different array arrives.
- If the destination item is no longer in your array when you handle the move, return `false`, as the two `guard` statements in `move(_:)` do.
- `onMove` returns synchronously, and the library does not wait for saving. Reorder the array at once, save afterwards, and if saving fails, pass the array in its previous order again. It is shown as an ordinary replacement. Anything that only the server can decide is handled this way, as a failed save.

```swift
extension TaskListModel {
    func moveAndSave(
        _ move: KsReorderMove<TaskItem>,
        save: @escaping @Sendable ([TaskItem]) async throws -> Void
    ) -> Bool {
        let original = tasks
        guard self.move(move) else { return false }
        let reordered = tasks
        Task {
            do {
                try await save(reordered)
            } catch {
                restore(original)
            }
        }
        return true
    }
}
```

This short version puts back the whole array as it was before this move, so it also undoes everything that changed while the save was running (a second move, an edit). If moves can overlap, do not restore a snapshot: undo only the move that failed, or load the order again from the server.

There is no helper that applies a move to an array, because how the group value is written depends on your model. Copy `move(_:)` above and adapt it; it handles lists with and without groups.

## Move items across groups

On a list that declares groups with `.groups` (see [layout.md](layout.md)), an item can be dropped into another group. The library reports the group value of the destination in `move.group` and does not change your item. To accept, write that group value into the moved item and pass the array, as `move(_:)` does with `moved.section = section`.

```swift
struct GroupedTaskListScreen: View {
    @ObservedObject var model: TaskListModel

    var body: some View {
        KsCollectionView(model.tasks, layout: .list(groupSpacing: 16)) { task in
            TaskRow(task: task)
        }
        .groups(by: \.section) { section, tasksInSection in
            Text("\(section.rawValue.capitalized) (\(tasksInSection.count))")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.background)
        }
        .reorder(
            isEnabled: model.isReordering,
            canMove: { task in !task.isLocked },
            canDrop: { move in move.group != AnyHashable(TaskSection.archived) },
            accessibilityActions: KsReorderAccessibilityActions(previous: "Move up", next: "Move down")
        ) { move in
            model.move(move)
        }
    }
}
```

Rules:

- If you accept a move into another group without changing the item's group value, the same group value appears at two separate places in the array, which is invalid input (see [basics.md](basics.md)).
- A group with no items is not displayed, so nothing can be dropped into it. If a group can become empty and must still receive items, offer another way to move items into it (a menu, for example).
- While the last item of a group is being dragged, the header of that group stays. When the move is accepted, the emptied group disappears together with its header. If a failed save later brings back the old array, the group comes back too.
- If the screen can turn the group declaration on and off, also update the group value of items moved while it is off: give the item the group value of its new neighbor, as `move(_:)` does when `move.group` is `nil` (`section ?? next[index].section` in the `.before` case, and the `else` branch in the `.end` case). Otherwise the array becomes invalid when groups are turned back on.

## Limit what can move and where it can be dropped

| Parameter | When it is called | Returning `false` |
|---|---|---|
| `canMove: ((Item) -> Bool)?` | Per item, before it is lifted | The item does not lift |
| `canDrop: ((KsReorderMove<Item>) -> Bool)?` | During the drag, for each candidate destination (many times), and just before the drop | The item cannot go there. Lifting the finger there sends the item back, and `onMove` is not called |

- `canDrop` receives the same kind of value as `onMove`. To keep items within their own group, compare `move.group` with the group value of `move.item`: `canDrop: { move in move.group == AnyHashable(move.item.section) }`. To close one group to items from other groups while its own items still move inside it, combine the two comparisons: `canDrop: { move in move.group != AnyHashable(TaskSection.archived) || move.item.section == .archived }`.
- The original position is never checked; the item can always go back.
- Omitting both lets every item move to every position.
- Keep `canDrop` a light, synchronous check. It is called many times while the finger moves, and slow work makes the drag lag. Do not query a server in it; decide such cases after the drop, as a failed save.
- `canMove` and `canDrop` are called on the main thread. Unlike `onMove`, they are not declared `@MainActor` (and not `@Sendable`); written inside `body`, they can still read a `@MainActor` model directly.

## Offer move actions to VoiceOver users

Pass `accessibilityActions:` a `KsReorderAccessibilityActions(previous:next:)`, as in the grouped example above. While the switch is on, each movable item then offers two accessibility actions, named with the two strings you gave: move one position back, and move one position forward.

- Without the strings the actions are not offered, and VoiceOver users cannot reorder. The library has no texts of its own. `previous` and `next` are `String` values (not `LocalizedStringKey`), so pass strings that are already localized, for example with `String(localized:)`.
- Moving back from the first item of a group goes to the end of the previous group. Moving forward from the last item of a group goes to the start of the next group.
- An action is not offered where it has no destination (back on the first item of the list, forward on the last) or where `canDrop` returns `false` for the destination.
- An action calls `onMove` once, just as a drop does, and accepting works the same way.
- While the strings are set and the switch is on, building rows costs somewhat more on iOS (about 5 to 8 percent of main-thread CPU in the Simulator). Turn the switch off when the user is not reordering.

## Reorder a list that is sorted

The library knows nothing about sorting. If your model keeps handing back the sorted array after it accepted a move, the drop does not last. An array equal to the one before the drop leaves the item where it was dropped, out of step with your array, and the next array that differs shows the item at its sorted position again. Choose one of two designs:

- Turn the reorder switch off while the list is sorted: `.reorder(isEnabled: model.isReordering && !model.isSorted) { ... }`. Here `isSorted` is a flag of your own model; the models on this page do not have one.
- In `onMove`, switch to manual order: take the array as currently displayed, apply the move to it, keep the result as the manual order, and stop sorting.

```swift
@MainActor
final class SortableTaskListModel: ObservableObject {
    @Published private(set) var manualOrder: [TaskItem]
    @Published private(set) var sortsByTitle = true

    init(tasks: [TaskItem]) {
        manualOrder = tasks
    }

    var displayedTasks: [TaskItem] {
        sortsByTitle ? manualOrder.sorted { $0.title < $1.title } : manualOrder
    }

    func move(_ move: KsReorderMove<TaskItem>) -> Bool {
        var next = displayedTasks
        guard let from = next.firstIndex(where: { $0.id == move.item.id }) else { return false }
        let moved = next.remove(at: from)
        switch move.destination {
        case .before(let target):
            guard let index = next.firstIndex(where: { $0.id == target.id }) else { return false }
            next.insert(moved, at: index)
        case .end:
            next.append(moved)
        }
        manualOrder = next
        sortsByTitle = false
        return true
    }
}
```

`SortableTaskListModel` shows only the switch to manual order. It has no way back to the sorted order (add a function that sets `sortsByTitle` to `true` if you need one), and its `move` ignores `move.group`, so use it only on a list without groups.

## Know what is held back during a drag

While an item is being dragged, the displayed order differs from your array, so the library holds back what arrives from outside until the drag is over (the item is dropped and has come to rest, or has returned to its place).

| Arrives during the drag | What happens |
|---|---|
| A new array | Not shown during the drag. The latest one is kept. If the move is accepted, the kept array is never shown; it only takes the place of "the array the list had at the drop" in the rule above, so the list keeps the dropped order until an array that is not equal to the kept one arrives. If the move is not accepted, the item goes back first and the kept array is then shown |
| The condition for requesting the next page (see [paging.md](paging.md)) | Not checked. It is checked again when the drag ends, so the list does not grow while you drag toward the end |
| `KsScrollController` commands | Queued and run in order after the drag ends |

The drag is cancelled, with the item returning to its place and `onMove` not called, when any of these happens during it: the reorder switch is turned off, the layout value changes, the group declaration changes (added, removed, a different key path, header or pinning changed), or the system interrupts the touch. Do not change these while you want the drag to continue.

Dragging near the top or bottom edge of the visible range scrolls the list in that direction. There are no settings for the speed or the size of the edge zone. On a full-screen list, the top zone starts below the top bar.

## Know how the drag behaves on iOS

On iOS the drag is the system's own drag-and-drop reordering of collection views (UIKit), the motion users know from the system's lists; you do not need to know UIKit, because the table describes what the user sees. On Android the drag follows the finger position directly. The value you receive in `onMove`, accepting, and the final order follow the same rules on both, but the motion differs. Two words in the table: the *gap* is the empty place that opens among the other items to show where the dragged item would land, and the *lifted preview* is the picture of the item that follows the finger. The following was observed on iOS 18 and iOS 26; read it as a description of those versions, not as a guarantee for every version the library supports (iOS 16 and later).

| Situation | iOS |
|---|---|
| When the gap moves | After the finger stops. It does not move while the finger is moving or during fast auto-scrolling. (On Android the gap moves while the finger is still moving: in a list, when the lifted item overlaps another item by more than half; in a grid, when the finger enters another item) |
| Dropping at the start of the next group | Come from above and stop over its first item |
| Dropping at the end of the previous group | Come from below and stop over its last item; the gap opens before that item. Once the gap is inside that group, stop over the last item again to move the gap to the end. (On Android, a position above the header is the end of the previous group and a position below it is the start of the next) |
| Stopping over a group header or between groups | The gap does not move there. Lifting the finger drops the item at the gap's current position |
| A move that is not accepted | The item first comes to rest where it was dropped, pauses, then moves back; about 1.3 seconds in total. (On Android it moves straight back from where it was released) |
| A cancelled drag | The drag continues until the finger is lifted, but the item can no longer be dropped anywhere; it returns when the finger is lifted, and changed settings are applied after that. (On Android the item returns at once) |
| When incoming arrays start being held | From the moment the finger starts moving after the lift. An array that arrives between the lift and the first movement is applied immediately |
| Dragging outside the bounds of the list | The lifted preview changes to the small default preview of the system |
| Dropping into a group further down | For about 0.1 to 0.2 seconds the item may be visible twice, as in the system's own reordering |

Do not expect the gap to move identically on the two platforms, and do not design around multi-item drags, dragging a whole group by its header, or dragging between lists; none of these is provided.
