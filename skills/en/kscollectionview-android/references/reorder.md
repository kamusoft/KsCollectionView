# Reordering by drag and drop

Recipes for letting the user reorder items with a long press and a drag. The examples leave out the `import` lines: each needs the Compose and Material 3 names it uses, the library names from `jp.kamusoft.kscollectionview`, and, where they appear, `kotlinx.coroutines` names and `java.io.IOException`. The examples on this page share the types declared in the first section (`TaskSection`, `TaskItem`, `TaskRow`, `TaskListModel`).

The division of work: the library detects the long press, lifts the item, scrolls at the edges, and works out where the item was dropped. It never changes your array. When the user drops the item, it tells your model what moved where, once, and your model reorders its own array and passes it back.

## Turn on reordering

Pass a `KsReorder` as `reorder`. `enabled` is the reorder switch, a `Boolean` that you own. `onMove` is called when the user drops an item, and returns whether you accept the move.

```kotlin
enum class TaskSection { Today, Later, Archived }

data class TaskItem(
    val id: Int,
    val title: String,
    val section: TaskSection,
    val isLocked: Boolean = false,
)

@Composable
fun TaskRow(task: TaskItem, modifier: Modifier = Modifier) {
    Text(
        text = task.title,
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .padding(16.dp),
    )
}

class TaskListModel(tasks: List<TaskItem>) {
    var tasks by mutableStateOf(tasks)
        private set

    var isReordering by mutableStateOf(false)

    fun move(move: KsReorderMove<TaskItem>): Boolean {
        val next = tasks.toMutableList()
        val from = next.indexOfFirst { it.id == move.item.id }
        if (from < 0) return false
        val moved = next.removeAt(from)
        val section = move.group as? TaskSection
        when (val destination = move.destination) {
            is KsReorderDestination.Before -> {
                val index = next.indexOfFirst { it.id == destination.item.id }
                if (index < 0) return false
                next.add(index, moved.copy(section = section ?: next[index].section))
            }
            KsReorderDestination.End -> if (section != null) {
                val last = next.indexOfLast { it.section == section }
                next.add(if (last < 0) next.size else last + 1, moved.copy(section = section))
            } else {
                next.add(moved.copy(section = next.lastOrNull()?.section ?: moved.section))
            }
        }
        tasks = next
        return true
    }

    fun restore(tasks: List<TaskItem>) {
        this.tasks = tasks
    }
}

@Composable
fun TaskListScreen(model: TaskListModel, modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxSize()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text = "Reorder")
            Switch(checked = model.isReordering, onCheckedChange = { model.isReordering = it })
        }
        KsCollectionView(
            items = model.tasks,
            key = { it.id },
            modifier = Modifier.weight(1f),
            reorder = KsReorder(
                enabled = model.isReordering,
                onMove = { move -> model.move(move) },
            ),
        ) {
            template { task -> TaskRow(task) }
        }
    }
}
```

While the switch is on:

- A long press anywhere on an item lifts it and starts the drag. There is no drag handle.
- The long press belongs to reordering, so `onItemLongTap` is not called, not even for items that cannot be moved. `onItemTap` is still called. A list whose switch is always on therefore cannot use `onItemLongTap`.
- It works the same in a list and in a grid.

While the switch is off, or on a list without `reorder`, a long press does not start a drag and `onItemLongTap` works as usual.

Give the outermost element of the template an opaque background, as `TaskRow` does. The lifted item is drawn with a shadow and is not scaled; if the outermost element is transparent, the shadow and the rows underneath show through the lifted item.

## Apply the move to your array

`onMove` receives a `KsReorderMove<Item>` (`Item` stands for your item type) and is called exactly once per drop, when the finger is lifted, on the main thread. It is not called while the item passes over other items during the drag.

| Property of `KsReorderMove` | Meaning |
|---|---|
| `item` | The item that was moved. It is the element of your array itself |
| `destination` | A `KsReorderDestination<Item>`: `KsReorderDestination.Before` (whose `item` is the item that follows the drop position) when an item of the same group follows, or `KsReorderDestination.End` when the item was dropped at the end of the group (the end of the list when no groups are declared) |
| `group` | The group value of the group it was dropped in, as `Any?`. `null` when the list declares no groups. Cast it back with `move.group as? YourGroupType` |

The destination is expressed by an item, not by an index, so it keeps its meaning even if your array changed between the drop and your handler. `KsReorderMove` and `KsReorderDestination.Before` have public constructors, so you can unit-test your model's `move` function without a list: `KsReorderMove(item, destination, group)` takes all three arguments (pass `null` as `group` for a list without groups), `KsReorderDestination.Before(item)` takes the item, and `KsReorderDestination.End` is an object.

`onMove` is not called when the item is dropped back at its original position, dropped where `canDrop` returns `false`, dropped outside the bounds of the list, or when the drag is cancelled. In those cases the item goes back to where it was. An item cannot be dragged to another list or out of the app.

What you return:

| Return value | What the list does |
|---|---|
| `true` (accepted) | Keeps the item where it was dropped and waits for your reordered array. When an array arrives that is not equal (`equals`) to the array the list had at the drop, the list follows it. An array equal to that one changes nothing. It never reverts by itself after some time |
| `false` (not accepted) | Moves the item back to its original position |

Rules:

- If you return `true`, reorder your array and pass it to the list, inside `onMove` or later. If you accept without reordering, the list and your array stay out of step until the next different array arrives.
- If the destination item is no longer in your array when you handle the move, return `false`, as the two `return false` lines in `move` do.
- `onMove` returns synchronously, and the library does not wait for saving. Reorder the array at once, save afterwards, and if saving fails, pass the array in its previous order again. It is shown as an ordinary replacement. Anything that only the server can decide is handled this way, as a failed save.

```kotlin
fun TaskListModel.moveAndSave(
    move: KsReorderMove<TaskItem>,
    scope: CoroutineScope,
    save: suspend (List<TaskItem>) -> Unit,
): Boolean {
    val original = tasks
    if (!this.move(move)) return false
    val reordered = tasks
    scope.launch {
        try {
            save(reordered)
        } catch (failure: IOException) {
            restore(original)
        }
    }
    return true
}
```

This short version puts back the whole array as it was before this move, so it also undoes everything that changed while the save was running (a second move, an edit). If moves can overlap, do not restore a snapshot: undo only the move that failed, or load the order again from the server. As in [paging.md](paging.md), `IOException` stands for the failures of your own client; catch every exception type it uses for a failed save.

There is no helper that applies a move to an array, because how the group value is written depends on your model. Copy `move` above and adapt it; it handles lists with and without groups.

## Move items across groups

On a list that declares groups with `groups` (see [layout.md](layout.md)), an item can be dropped into another group. The library reports the group value of the destination in `move.group` and does not change your item. To accept, write that group value into the moved item and pass the array, as `move` does with `moved.copy(section = section)`.

```kotlin
@Composable
fun GroupedTaskListScreen(model: TaskListModel, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = model.tasks,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        layout = KsLayout.List(groupSpacing = 16.dp),
        groups = KsGroups(by = { it.section }) { section, tasksInSection ->
            Text(
                text = "${section.name} (${tasksInSection.size})",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(8.dp),
            )
        },
        reorder = KsReorder(
            enabled = model.isReordering,
            onMove = { move -> model.move(move) },
            canMove = { task -> !task.isLocked },
            canDrop = { move -> move.group != TaskSection.Archived },
            accessibilityActions = KsReorderAccessibilityActions(previous = "Move up", next = "Move down"),
        ),
    ) {
        template { task -> TaskRow(task) }
    }
}
```

Rules:

- If you accept a move into another group without changing the item's group value, the same group value appears at two separate places in the array, which is invalid input (see [basics.md](basics.md)).
- A group with no items is not displayed, so nothing can be dropped into it. If a group can become empty and must still receive items, offer another way to move items into it (a menu, for example).
- While the last item of a group is being dragged, the header of that group stays. When the move is accepted, the emptied group disappears together with its header. If a failed save later brings back the old array, the group comes back too.
- If the screen can turn the group declaration on and off, also update the group value of items moved while it is off: give the item the group value of its new neighbor, as the `?:` fallbacks in `move` do. Otherwise the array becomes invalid when groups are turned back on.

## Limit what can move and where it can be dropped

| Parameter | When it is called | Returning `false` |
|---|---|---|
| `canMove: ((Item) -> Boolean)?` | Per item, before it is lifted | The item does not lift |
| `canDrop: ((KsReorderMove<Item>) -> Boolean)?` | During the drag, for each candidate destination (many times), and just before the drop | The item cannot go there. Lifting the finger there sends the item back, and `onMove` is not called |

- `canDrop` receives the same kind of value as `onMove`. To keep items within their own group, compare `move.group` with the group value of `move.item`: `canDrop = { move -> move.group == move.item.section }`. To close one group to items from other groups while its own items still move inside it, combine the two comparisons: `canDrop = { move -> move.group != TaskSection.Archived || move.item.section == TaskSection.Archived }`.
- The original position is never checked; the item can always go back.
- Omitting both lets every item move to every position.
- Keep `canDrop` a light, synchronous check. It is called many times while the finger moves, and slow work makes the drag lag. Do not query a server in it; decide such cases after the drop, as a failed save.
- `canMove` and `canDrop` are called on the main thread.
- The constructor is `KsReorder(enabled, onMove, canMove = null, canDrop = null, accessibilityActions = null)`. `KsReorder` exposes what you passed as read-only properties with the same names as its parameters.

## Offer move actions to TalkBack users

Pass `accessibilityActions` a `KsReorderAccessibilityActions(previous, next)`, as in the grouped example above. While the switch is on, each movable item then offers two custom accessibility actions, named with the two strings you gave: move one position back, and move one position forward.

- Without the strings the actions are not offered, and TalkBack users cannot reorder. The library has no texts of its own. `previous` and `next` are `String` values, so pass strings that are already localized, for example from `stringResource(...)`.
- Moving back from the first item of a group goes to the end of the previous group. Moving forward from the last item of a group goes to the start of the next group.
- An action is not offered where it has no destination (back on the first item of the list, forward on the last) or where `canDrop` returns `false` for the destination.
- An action calls `onMove` once, just as a drop does, and accepting works the same way.

## Reorder a list that is sorted

The library knows nothing about sorting. If your model keeps handing back the sorted array after it accepted a move, the drop does not last. An array equal to the one before the drop leaves the item where it was dropped, out of step with your array, and the next array that differs shows the item at its sorted position again. Choose one of two designs:

- Turn the reorder switch off while the list is sorted: `enabled = model.isReordering && !model.isSorted`. Here `isSorted` is a flag of your own model; the models on this page do not have one.
- In `onMove`, switch to manual order: take the array as currently displayed, apply the move to it, keep the result as the manual order, and stop sorting.

```kotlin
class SortableTaskListModel(tasks: List<TaskItem>) {
    var manualOrder by mutableStateOf(tasks)
        private set

    var sortsByTitle by mutableStateOf(true)
        private set

    val displayedTasks: List<TaskItem>
        get() = if (sortsByTitle) manualOrder.sortedBy { it.title } else manualOrder

    fun move(move: KsReorderMove<TaskItem>): Boolean {
        val next = displayedTasks.toMutableList()
        val from = next.indexOfFirst { it.id == move.item.id }
        if (from < 0) return false
        val moved = next.removeAt(from)
        when (val destination = move.destination) {
            is KsReorderDestination.Before -> {
                val index = next.indexOfFirst { it.id == destination.item.id }
                if (index < 0) return false
                next.add(index, moved)
            }
            KsReorderDestination.End -> next.add(moved)
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

The drag is cancelled, with the item returning to its place and `onMove` not called, when any of these happens during it: the reorder switch is turned off, the layout value changes, the group declaration changes (added, removed, different group values, header or pinning changed), or the system interrupts the touch. Do not change these while you want the drag to continue.

Dragging near the top or bottom edge of the list scrolls the list in that direction: within 64 dp of the edge (a quarter of the list's height when the list is less than 256 dp tall), and faster the closer the finger is to it. There are no settings for the speed or the size of the edge zone. The zone is measured from the edge of the list's own bounds, also on an edge-to-edge list.

## Know how the drag behaves on Android

On Android the library runs the drag itself and decides everything from the finger position; on iOS the drag is the system's own reordering of its lists. The value you receive in `onMove`, accepting, and the final order follow the same rules on both, but the motion differs. One word in the table: the *open slot* is the empty place that opens among the other items to show where the lifted item would land (the iOS Skill calls it the gap).

| Situation | Android |
|---|---|
| When the open slot moves | In a list, when the lifted item overlaps another item by more than half. In a grid, when the finger enters another item: the slot moves to that item's position and the items in between shift by one. (On iOS the open slot moves only after the finger stops) |
| Dropping near a group boundary | A position above the group header (above the space between the groups when there is no header) is the end of the previous group; a position below it is the start of the next group. Both can be reached directly. (On iOS the open slot does not appear at the boundary itself, and the end of the previous group takes a second stop over its last item) |
| A move that is not accepted | The item is not placed; it moves straight back from where it was released. (On iOS it first comes to rest where it was dropped, pauses, then moves back) |
| A cancelled drag | The item returns at once, and the changed settings are applied at once. (On iOS the drag continues until the finger is lifted) |
| When incoming arrays start being held | From the moment the long press lifts the item |
| Dragging outside the bounds of the list | The lifted item keeps its size. While the finger is outside to the left or right, the slot does not move; above or below, auto-scrolling continues. Releasing outside sends the item back |
| The look of the lifted item | A shadow only; the item is not scaled. A template whose outermost element is transparent lets the rows underneath show through, so paint an opaque background on that element |

Do not expect the open slot to move identically on the two platforms, and do not design around multi-item drags, dragging a whole group by its header, or dragging between lists; none of these is provided.
