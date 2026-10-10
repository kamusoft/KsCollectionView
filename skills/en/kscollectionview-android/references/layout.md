# Layout and appearance

Recipes for choosing a list or a grid, spacing, separators, header and footer, groups with pinned headers, and edge-to-edge placement. The examples leave out the `import` lines: each needs the Compose and Material 3 names it uses and the library names from `jp.kamusoft.kscollectionview`. Later examples on this page reuse the types declared in the first one (`Photo`, `PhotoCell`).

## Choose a list or a grid

The form is one value, a `KsLayout`, passed as `layout`. There is one component for both forms, so you can switch between them while the list is on screen.

```kotlin
data class Photo(val id: Int, val title: String, val album: String, val place: String)

@Composable
fun PhotoCell(photo: Photo, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .heightIn(min = 80.dp)
            .background(MaterialTheme.colorScheme.surfaceVariant),
        contentAlignment = Alignment.Center,
    ) {
        Text(text = photo.title)
    }
}

@Composable
fun PhotoGridScreen(photos: List<Photo>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = photos,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        layout = KsLayout.Grid(
            columns = KsColumns.Fixed(portrait = 2, landscape = 4),
            rowSpacing = 8.dp,
            columnSpacing = 8.dp,
        ),
    ) {
        template { photo -> PhotoCell(photo) }
    }
}
```

| Layout | Meaning |
|---|---|
| `KsLayout.List` | One column without spacing. This is the default when `layout` is omitted |
| `KsLayout.List(rowSpacing, groupSpacing, headerItemSpacing)` | One column with spacing |
| `KsLayout.Grid(columns, rowSpacing, columnSpacing, groupSpacing, headerItemSpacing)` | Several columns. `columns` is a `KsColumns` |

| Columns (`KsColumns`) | Meaning |
|---|---|
| `KsColumns.Fixed(3)` | Always that many columns |
| `KsColumns.Fixed(portrait = 2, landscape = 4)` | The first count while the component is taller than wide, the second otherwise |
| `KsColumns.Adaptive(minItemWidth = 120.dp)` | As many columns as fit without any item becoming narrower than the width. Leftover width is shared equally among the items |

Rules:

- All spacings are `Dp`, default to `0.dp`, and must not be negative. Column counts and `minItemWidth` must be greater than 0. See "What happens with invalid input" in [basics.md](basics.md).
- Portrait and landscape are decided by the size of the `KsCollectionView` itself, not by the device orientation. In split-screen mode, on a tablet, or on a foldable, a component that is wider than tall uses the landscape count even when the device is upright.
- The width available to one column is: component width, minus the start and end `contentPadding`, minus `columnSpacing` × (columns − 1), divided by the number of columns.
- `KsLayout` values are compared by value, and they expose what you passed as read-only properties: `KsLayout.List` has `rowSpacing`, `groupSpacing`, and `headerItemSpacing`, and `KsLayout.Grid` has those three plus `columns` and `columnSpacing`. `KsLayout` itself has no properties, so check which of the two a value is before reading them.
- `KsLayout.List` written without parentheses is a ready-made value, a list with no spacing. `KsLayout.List(...)` with parentheses constructs a list with the spacings you pass, and `KsLayout.List()` is equal to the ready-made value. To tell a list from a grid, test the type: `layout is KsLayout.List` or `layout is KsLayout.Grid`.

Switching the layout while the list is on screen keeps the data and the scroll position.

```kotlin
@Composable
fun SwitchableLayoutScreen(photos: List<Photo>, modifier: Modifier = Modifier) {
    var showsGrid by remember { mutableStateOf(false) }
    val layout = if (showsGrid) {
        KsLayout.Grid(
            columns = KsColumns.Adaptive(minItemWidth = 120.dp),
            rowSpacing = 8.dp,
            columnSpacing = 8.dp,
        )
    } else {
        KsLayout.List(rowSpacing = 4.dp)
    }
    Column(modifier = modifier.fillMaxSize()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text = "Grid")
            Switch(checked = showsGrid, onCheckedChange = { showsGrid = it })
        }
        KsCollectionView(
            items = photos,
            key = { it.id },
            modifier = Modifier.weight(1f),
            layout = layout,
        ) {
            template { photo -> PhotoCell(photo) }
        }
    }
}
```

## Set spacing and content padding

`contentPadding` is a `PaddingValues` around the whole content, inside the component. It scrolls with the content.

```kotlin
@Composable
fun PaddedPhotoGridScreen(photos: List<Photo>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = photos,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        layout = KsLayout.Grid(columns = KsColumns.Fixed(3), rowSpacing = 8.dp, columnSpacing = 8.dp),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp),
    ) {
        template { photo -> PhotoCell(photo) }
    }
}
```

| Place | What goes there |
|---|---|
| Above the header and below the footer (or above the first row and below the last row when there is none) | The top and bottom of `contentPadding` |
| Between the header and the first group header or first row; between the last row and the footer | Nothing |
| Between two rows of the same group | `rowSpacing` |
| Between two columns | `columnSpacing` |
| Between the last row of a group and the header of the next group | `groupSpacing` |
| Between a group header and the first row of its group | `headerItemSpacing` |

Rules:

- `rowSpacing` goes only between rows. It is not added before or after the header, the footer, or a group header.
- The scroll indicator and the displays the library overlays on the list (the pull-to-refresh indicator and the paging displays in [paging.md](paging.md)) are not moved by `contentPadding`.
- Changing `contentPadding` while the list is on screen is reflected immediately.

## Show, hide, or color the list separators

A list draws separators by default. A grid never draws them.

```kotlin
@Composable
fun SeparatorColorScreen(photos: List<Photo>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = photos,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        listSeparatorColor = Color.Blue,
    ) {
        template { photo -> PhotoCell(photo) }
    }
}

@Composable
fun NoSeparatorScreen(photos: List<Photo>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = photos,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        layout = KsLayout.List(rowSpacing = 8.dp),
        listSeparators = false,
    ) {
        template { photo -> PhotoCell(photo) }
    }
}
```

| Aspect | Behavior |
|---|---|
| Position | Above the first row, between rows, and below the last row. With groups, the lines are drawn per group |
| Size | The full width of the cell with no inset, 1 dp thick |
| Color | By default a fixed color of the library: `#D9D9DE` in light mode and `#38383A` in dark mode. A color passed as `listSeparatorColor` is used exactly as given and does not change with the mode |
| Drawing order | In front of the row content, so a row with an opaque background does not hide it |

Rules:

- Light or dark is decided by `isSystemInDarkTheme()`, that is, by the night mode of the screen's configuration. The Material color scheme is not consulted. An app that turns dark only by switching its Material color scheme, without changing the configuration, should pass `listSeparatorColor` itself.
- Do not draw a `HorizontalDivider` inside the row as a separator. It doubles with the library's line. Turn the library's separators off first if you draw your own.
- With `rowSpacing` greater than 0, the line is drawn at the bottom edge of each cell, not in the middle of the gap.
- With groups that have no header, the top line of the second and later groups is not drawn, so two lines never touch at a group boundary.

## Add a header and a footer for the whole collection

`header` and `footer` each place one composable at the very start and the very end of the content.

```kotlin
@Composable
fun PhotoListWithHeaderScreen(photos: List<Photo>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = photos,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        header = {
            Text(
                text = "Photos",
                style = MaterialTheme.typography.headlineMedium,
                modifier = Modifier.fillMaxWidth().padding(16.dp),
            )
        },
        footer = {
            Text(
                text = "${photos.size} photos",
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(16.dp),
            )
        },
    ) {
        template { photo -> PhotoCell(photo) }
    }
}
```

- They scroll with the content and are never pinned.
- They are shown even when the array is empty.
- In a grid they span the full width.
- They are different from group headers (next section). A list can have both.
- A header, footer, or group header that is narrower than the content width is not centered the way rows are: it starts at the start edge. Give it `Modifier.fillMaxWidth()` and place its content yourself, as the header of the example does.

## Group items under group headers

Declare groups by passing a `KsGroups` as `groups`. Its `by` lambda returns the group value of an item. Each run of consecutive items with an equal value becomes one group, and the header lambda receives the group value and the items of the group. The array stays flat: you do not nest lists and you do not put header elements into it.

```kotlin
@Composable
fun GroupedPhotoScreen(photos: List<Photo>, modifier: Modifier = Modifier) {
    val grouped = remember(photos) { photos.sortedWith(compareBy({ it.album }, { it.id })) }
    KsCollectionView(
        items = grouped,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        layout = KsLayout.Grid(
            columns = KsColumns.Fixed(3),
            rowSpacing = 8.dp,
            columnSpacing = 8.dp,
            groupSpacing = 24.dp,
            headerItemSpacing = 8.dp,
        ),
        groups = KsGroups(by = { it.album }) { album, photosInAlbum ->
            Text(
                text = "$album (${photosInAlbum.size})",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(8.dp),
            )
        },
    ) {
        template { photo -> PhotoCell(photo) }
    }
}
```

Your responsibility:

- Keep the items of one group next to each other in the array. The library makes a group out of each consecutive run and does not gather equal values from separate places, unlike `groupBy`. The same value appearing again later in the array is invalid input (see [basics.md](basics.md)). Sort or regroup in your data layer, as the example does before passing the array.
- The order of the groups and the order inside each group are the order of the array.
- The group value must be a type that can be saved in a `Bundle`, exactly like the item `key`: a string, a number, an enum, or a `Serializable` or `Parcelable` value. The library uses it to identify the header. Another type is invalid input (see [basics.md](basics.md)). A group value may be equal to an item ID without any conflict. (iOS has no such restriction on the type.)

What the library guarantees:

- The header is placed once, before the first row of its group. Its height comes from its content; in a grid it spans the full width and the first item of the group starts a new row. There are no group footers.
- By default the header of the group in view is pinned to the top of the visible range, and the next header pushes it out when it arrives. `groupSpacing` and `headerItemSpacing` are not pinned with the header; they scroll with the rows. The top `contentPadding` scrolls away with the content and does not lower the pinned header: it pins at the top edge of the list.
- When you replace the array, an item whose group value changed moves to its new group with an animation, a group whose last item left disappears together with its header, a new group value appears together with its header, and a header whose group only changed in count or content is updated in place. A group with no items does not exist.
- The `by` lambda may be switched while the list is on screen. The groups are rebuilt from the new values. Pass an array ordered for the new grouping in the same recomposition.

`KsGroups<Item, Group>` has two type parameters, the item type and the type that `by` returns, and three properties, in this order: `by`, `pinnedHeaders` (default `true`), and `header` (default `null`; a `@Composable (group: Group, items: List<Item>) -> Unit`). Inside the `KsCollectionView` call the types are inferred. When you keep one in a variable, write them: `val groups: KsGroups<Photo, String> = KsGroups(by = { it.album })`. Two more forms (the remaining examples assume that `photos` is already ordered by the grouping value):

```kotlin
@Composable
fun UnpinnedGroupScreen(photos: List<Photo>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = photos,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        layout = KsLayout.List(groupSpacing = 24.dp),
        groups = KsGroups(by = { it.album }, pinnedHeaders = false) { album, _ ->
            Text(text = album, modifier = Modifier.fillMaxWidth().padding(8.dp))
        },
    ) {
        template { photo -> PhotoCell(photo) }
    }
}

@Composable
fun HeaderlessGroupScreen(photos: List<Photo>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = photos,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        layout = KsLayout.List(groupSpacing = 24.dp),
        groups = KsGroups(by = { it.album }),
    ) {
        template { photo -> PhotoCell(photo) }
    }
}
```

- `pinnedHeaders = false` lets the headers scroll away with the content.
- `KsGroups(by = ...)` without a header makes groups that show no header. They only separate the content with `groupSpacing` and decide where list separators are drawn (the lines are drawn per group; see the separator table above).

Switching the grouping while the list is on screen:

```kotlin
@Composable
fun RegroupablePhotoScreen(photos: List<Photo>, modifier: Modifier = Modifier) {
    var groupsByPlace by remember { mutableStateOf(false) }
    val groupOf: (Photo) -> String = if (groupsByPlace) Photo::place else Photo::album
    val grouped = remember(photos, groupsByPlace) {
        photos.sortedWith(compareBy({ groupOf(it) }, { it.id }))
    }
    Column(modifier = modifier.fillMaxSize()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text = "Group by place")
            Switch(checked = groupsByPlace, onCheckedChange = { groupsByPlace = it })
        }
        KsCollectionView(
            items = grouped,
            key = { it.id },
            modifier = Modifier.weight(1f),
            groups = KsGroups(by = groupOf) { name, _ ->
                Text(
                    text = name,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.surface)
                        .padding(8.dp),
                )
            },
        ) {
            template { photo -> PhotoCell(photo) }
        }
    }
}
```

Rules:

- To switch the grouping, keep one `KsCollectionView` call and choose the `by` lambda with a value, as above. Writing two `KsCollectionView` calls in the branches of an `if` makes two separate lists, and the scroll position is lost on the switch.
- Do not add vertical padding around the header composable to make a gap. The empty space is pinned together with the header. Use `groupSpacing` and `headerItemSpacing`.
- Give a pinned header an opaque background. Rows scroll behind it.
- State read inside the header lambda is tracked by Compose, as in rows (see [basics.md](basics.md)).

## Place the list full screen under the bars

When the activity draws edge to edge (`enableEdgeToEdge()`) and the list extends under the status bar or the navigation bar, rows scroll behind the bars. Within the scrolling content, the library adjusts only one thing to the system bars: a pinned group header stops at the bottom edge of the status bar instead of going behind it. It does not add any inset to the start or the end of the content, so the header (or first row) and the footer (or last row) may sit under a bar. You make that room yourself, with `contentPadding` or with the size of your header.

```kotlin
@Composable
fun EdgeToEdgePhotoScreen(photos: List<Photo>, modifier: Modifier = Modifier) {
    val systemBars = WindowInsets.systemBars.union(WindowInsets.displayCutout).asPaddingValues()
    KsCollectionView(
        items = photos,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        contentPadding = PaddingValues(
            top = systemBars.calculateTopPadding(),
            bottom = systemBars.calculateBottomPadding(),
        ),
        groups = KsGroups(by = { it.album }) { album, _ ->
            Text(
                text = album,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(8.dp),
            )
        },
    ) {
        template { photo -> PhotoCell(photo) }
    }
}
```

- The area the library treats as covered is the system bars plus the display cutout, minus what an ancestor has already consumed (with `Modifier.windowInsetsPadding`, `Modifier.safeDrawingPadding()`, or `Modifier.consumeWindowInsets`), and only as far as the list really overlaps it. A list placed inside the padding that a `Scaffold` hands to its content does not overlap the bars, and the rules of this section change nothing about how it looks.
- Do not expect the first row or the header to move below the bar automatically.
- The left and right insets (landscape) get no special treatment. To keep rows clear of a cutout or a side navigation bar, add the start and end values of the same insets to `contentPadding` yourself.
- The displays the library overlays on a list with paging or pull to refresh also respect the system bars (see [paging.md](paging.md)).
- The same holds on iOS for a list that ignores the safe area.

## Know how cells are sized and placed

- The height of a cell comes from its content. There is no height setting and nothing to precompute.
- The content is placed at the top of its cell. Content narrower than the item is centered horizontally; content that takes the full width (with `Modifier.fillMaxWidth()`) fills the item.
- In a grid, the height of a row is that of its tallest cell, but each cell's content keeps its own natural height at the top. Do not use `Modifier.fillMaxHeight()` or a `Spacer` with `weight` expecting a cell to stretch to the row height. To paint whole rows evenly, give every cell's content the same height yourself, with `Modifier.height(...)` or `Modifier.aspectRatio(...)`, for example.
- When the height of a row changes (for example, a row expands), the change is animated, and so is the movement of the rows below it. While it animates, the outermost element of the template receives the row height as a constraint, so paint the background there (see "Read parent state inside a row" in [basics.md](basics.md)).

## Know what the scroll indicator does

A vertical scroll indicator is shown while the user scrolls and disappears about a second after scrolling stops. Compose's lazy layouts have none, so the library draws it. There is no setting to hide it or to change its color. It sits at the end edge of the list and is not affected by `contentPadding`. Scrolling caused by a `KsScrollController` command does not show it.

- Its color follows `isSystemInDarkTheme()`: dark on light mode, light on dark mode. If the app paints a fixed light background while the configuration is in night mode, the indicator is hard to see.
- Its length and position are estimates based on the rows currently on screen, so the length may change slightly while scrolling a list whose rows differ in height.
