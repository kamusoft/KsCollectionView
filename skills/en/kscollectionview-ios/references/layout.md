# Layout and appearance

Recipes for choosing a list or a grid, spacing, separators, header and footer, groups with pinned headers, and full-screen placement. Every example assumes `import SwiftUI` and `import KsCollectionView`. Later examples on this page reuse the types declared in the first one (`Photo`, `PhotoCell`).

## Choose a list or a grid

The form is one value, `KsCollectionLayout`, passed as `layout:`. There is one component for both forms, so you can switch between them while the list is on screen.

```swift
struct Photo: Identifiable, Equatable {
    let id: Int
    let title: String
    let album: String
    let place: String
}

struct PhotoCell: View {
    let photo: Photo

    var body: some View {
        Text(photo.title)
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Color.gray.opacity(0.2))
    }
}

struct PhotoGridScreen: View {
    let photos: [Photo]

    var body: some View {
        KsCollectionView(
            photos,
            layout: .grid(columns: .fixed(portrait: 2, landscape: 4), rowSpacing: 8, columnSpacing: 8)
        ) { photo in
            PhotoCell(photo: photo)
        }
    }
}
```

| Layout | Meaning |
|---|---|
| `.list` | One column. This is the default when `layout:` is omitted |
| `.list(rowSpacing:groupSpacing:headerItemSpacing:)` | One column with spacing |
| `.grid(columns:rowSpacing:columnSpacing:groupSpacing:headerItemSpacing:)` | Several columns. `columns` is a `KsGridColumns` |

| Columns (`KsGridColumns`) | Meaning |
|---|---|
| `.fixed(3)` | Always that many columns |
| `.fixed(portrait: 2, landscape: 4)` | The first count while the component is taller than wide, the second otherwise |
| `.adaptive(minItemWidth: 120)` | As many columns as fit without any item becoming narrower than the width. Leftover width is shared equally among the items |

Rules:

- All spacings are `Double` values in points, default to 0, and must not be negative. Column counts are `Int` and `minItemWidth` is a `Double`; both must be greater than 0. See "What happens with invalid input" in [basics.md](basics.md).
- Portrait and landscape are decided by the size of the `KsCollectionView` itself, not by the device orientation. In split view or on an iPad, a component that is wider than tall uses the landscape count even when the device is upright.
- The width available to one column is: component width, minus the leading and trailing `contentPadding`, minus `columnSpacing` × (columns − 1), divided by the number of columns.
- `KsCollectionLayout` is `Equatable` and exposes its four spacings as read-only properties (`rowSpacing`, `columnSpacing`, `groupSpacing`, `headerItemSpacing`).
- The list and its cells have no background of their own: whatever is behind the list shows through. Put a background on the rows, or on the list with SwiftUI's `.background` (after the library's modifiers).

Switching the layout while the list is on screen keeps the data and the position: the item that was at the top of the visible range stays visible after the switch.

```swift
struct SwitchableLayoutScreen: View {
    let photos: [Photo]
    @State private var showsGrid = false

    private var layout: KsCollectionLayout {
        showsGrid
            ? .grid(columns: .adaptive(minItemWidth: 120), rowSpacing: 8, columnSpacing: 8)
            : .list(rowSpacing: 4)
    }

    var body: some View {
        VStack(spacing: 0) {
            Toggle("Grid", isOn: $showsGrid)
                .padding()
            KsCollectionView(photos, layout: layout) { photo in
                PhotoCell(photo: photo)
            }
        }
    }
}
```

## Set spacing and content padding

`contentPadding:` is an `EdgeInsets` around the whole content, inside the component. It scrolls with the content.

```swift
struct PaddedPhotoGridScreen: View {
    let photos: [Photo]

    var body: some View {
        KsCollectionView(
            photos,
            layout: .grid(columns: .fixed(3), rowSpacing: 8, columnSpacing: 8),
            contentPadding: EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        ) { photo in
            PhotoCell(photo: photo)
        }
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

A list draws separators by default. A grid never draws them, even with `.listSeparators(true)`.

```swift
struct SeparatorColorScreen: View {
    let photos: [Photo]

    var body: some View {
        KsCollectionView(photos) { photo in
            PhotoCell(photo: photo)
        }
        .listSeparatorColor(.blue)
    }
}

struct NoSeparatorScreen: View {
    let photos: [Photo]

    var body: some View {
        KsCollectionView(photos, layout: .list(rowSpacing: 8)) { photo in
            PhotoCell(photo: photo)
        }
        .listSeparators(false)
    }
}
```

| Aspect | Behavior |
|---|---|
| Position | Above the first row, between rows, and below the last row. With groups, the lines are drawn per group |
| Size | The full width of the cell with no inset, 1 point thick |
| Color | By default a fixed color of the library: `#D9D9DE` in light appearance and `#38383A` in dark, following the appearance of the place where the list is shown. A color set with `.listSeparatorColor(_:)` is used exactly as given and does not change with the appearance |
| Drawing order | In front of the row content, so a row with an opaque background does not hide it |

Rules:

- Do not draw a `Divider` inside the row as a separator. It doubles with the library's line. Turn the library's separators off first if you draw your own.
- With `rowSpacing` greater than 0, the line is drawn at the bottom edge of each cell, not in the middle of the gap.
- With groups that have no header, the top line of the second and later groups is not drawn, so two lines never touch at a group boundary.

## Add a header and a footer for the whole collection

`.header` and `.footer` each place one view at the very start and the very end of the content.

```swift
struct PhotoListWithHeaderScreen: View {
    let photos: [Photo]

    var body: some View {
        KsCollectionView(photos) { photo in
            PhotoCell(photo: photo)
        }
        .header {
            Text("Photos")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .footer {
            Text("\(photos.count) photos")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        }
    }
}
```

- They scroll with the content and are never pinned.
- They are shown even when the array is empty.
- In a grid they span the full width.
- They are different from group headers (next section). A list can have both.
- For state read inside them, see "Read parent state inside a row" in [basics.md](basics.md).

## Group items under group headers

Declare groups with `.groups(by:pinnedHeaders:header:)`. `by` is a key path to a `Hashable` value of the item. Each run of consecutive items with the same value becomes one group, and the header closure receives the group value and the items of the group. The array stays flat: you do not nest arrays and you do not put header elements into it.

```swift
struct GroupedPhotoScreen: View {
    let photos: [Photo]

    var body: some View {
        KsCollectionView(
            photos.sorted { ($0.album, $0.id) < ($1.album, $1.id) },
            layout: .grid(
                columns: .fixed(3),
                rowSpacing: 8,
                columnSpacing: 8,
                groupSpacing: 24,
                headerItemSpacing: 8
            )
        ) { photo in
            PhotoCell(photo: photo)
        }
        .groups(by: \.album) { album, photosInAlbum in
            Text("\(album) (\(photosInAlbum.count))")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.background)
        }
    }
}
```

Your responsibility:

- Keep the items of one group next to each other in the array. The library makes a group out of each consecutive run and does not gather equal values from separate places, unlike `Dictionary(grouping:)`. The same value appearing again later in the array is invalid input (see [basics.md](basics.md)). Sort or regroup in your data layer, as the example does before passing the array.
- The order of the groups and the order inside each group are the order of the array.

What the library guarantees:

- The header is placed once, before the first row of its group. Its height comes from its content; in a grid it spans the full width and the first item of the group starts a new row. There are no group footers.
- By default the header of the group in view is pinned to the top of the visible range, and the next header pushes it out when it arrives. `groupSpacing` and `headerItemSpacing` are not pinned with the header; they scroll with the rows. The top `contentPadding` scrolls away with the content and does not lower the pinned header: it pins at the top edge of the list.
- When you replace the array, an item whose group value changed moves to its new group with an animation, a group whose last item left disappears together with its header, a new group value appears together with its header, and a header whose group only changed in count or content is updated in place. A group with no items does not exist.
- The key path passed to `by` may be switched while the list is on screen. The groups are rebuilt from the new values. Pass an array ordered for the new key in the same update.

Two more forms (the remaining examples assume that `photos` is already ordered by the grouping key):

```swift
struct UnpinnedGroupScreen: View {
    let photos: [Photo]

    var body: some View {
        KsCollectionView(photos, layout: .list(groupSpacing: 24)) { photo in
            PhotoCell(photo: photo)
        }
        .groups(by: \.album, pinnedHeaders: false) { album, _ in
            Text(album)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
    }
}

struct HeaderlessGroupScreen: View {
    let photos: [Photo]

    var body: some View {
        KsCollectionView(photos, layout: .list(groupSpacing: 24)) { photo in
            PhotoCell(photo: photo)
        }
        .groups(by: \.album)
    }
}
```

- `pinnedHeaders: false` lets the headers scroll away with the content.
- `.groups(by:)` without a header closure makes groups that show no header. They only separate the content with `groupSpacing` and decide where list separators are drawn (the lines are drawn per group; see the separator table above).

Switching the grouping key while the list is on screen:

```swift
struct RegroupablePhotoScreen: View {
    let photos: [Photo]
    @State private var groupsByPlace = false

    private var groupKey: KeyPath<Photo, String> {
        groupsByPlace ? \.place : \.album
    }

    private var groupedPhotos: [Photo] {
        let key = groupKey
        return photos.sorted { ($0[keyPath: key], $0.id) < ($1[keyPath: key], $1.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Toggle("Group by place", isOn: $groupsByPlace)
                .padding()
            KsCollectionView(groupedPhotos) { photo in
                PhotoCell(photo: photo)
            }
            .groups(by: groupKey) { name, _ in
                Text(name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.background)
            }
        }
    }
}
```

Rules:

- To switch the key, keep one `KsCollectionView` expression and choose the key path with a value, as above. Writing two `KsCollectionView` expressions in the branches of an `if` inside `body` makes two separate lists, and the scroll position is lost on the switch.
- Do not add vertical padding to the header view to make a gap. The empty space is pinned together with the header. Use `groupSpacing` and `headerItemSpacing`.
- Give a pinned header an opaque background. Rows scroll behind it.
- State read inside the header closure follows the same rule as rows: pass it with `.observedValue(_:)` (see [basics.md](basics.md)).
- On Android the group value must additionally be a type that Android can save as instance state. iOS has no such restriction; any `Hashable` value works.

## Place the list full screen under the bars

When you extend the list under the status bar, navigation bar, or home indicator with `.ignoresSafeArea()`, rows scroll behind the bars. Within the scrolling content, the library adjusts only one thing to the safe area: a pinned group header stops at the bottom edge of the top bar instead of going behind it. It does not add any inset to the start or the end of the content, so the header (or first row) and the footer (or last row) may sit under a bar. You make that room yourself, with `contentPadding` or with the size of your header.

```swift
struct FullScreenPhotoScreen: View {
    let photos: [Photo]

    var body: some View {
        GeometryReader { proxy in
            KsCollectionView(
                photos,
                contentPadding: EdgeInsets(
                    top: proxy.safeAreaInsets.top,
                    leading: 0,
                    bottom: proxy.safeAreaInsets.bottom,
                    trailing: 0
                )
            ) { photo in
                PhotoCell(photo: photo)
            }
            .groups(by: \.album) { album, _ in
                Text(album)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.background)
            }
            .ignoresSafeArea()
        }
    }
}
```

- `.ignoresSafeArea()` is a SwiftUI modifier, so it comes after the library's modifiers.
- Do not expect the first row or the header to move below the bar automatically.
- The leading and trailing safe areas (landscape) get no special treatment: rows run from edge to edge, under the sensor housing. To keep them clear, extend the list only vertically with `.ignoresSafeArea(edges: .vertical)`.
- For a list placed normally, inside the safe area, the rules of this section change nothing about how it looks.
- The displays the library overlays on a list with paging or pull to refresh also respect the safe area (see [paging.md](paging.md)).
- The same holds on Android for a list drawn under the system bars.

## Know how cells are sized and placed

- The height of a cell comes from its content. There is no height setting and nothing to precompute.
- The content is placed at the top of its cell. Content narrower than the item is centered horizontally; content that takes the full width (with `.frame(maxWidth: .infinity)`, for example) fills the item.
- In a grid, the height of a row is that of its tallest cell, but each cell's content keeps its own natural height at the top. Do not use `.frame(maxHeight: .infinity)` or `Spacer()` expecting a cell to stretch to the row height. To paint whole rows evenly, give every cell's content the same height yourself, with a fixed `.frame(height:)` or `.aspectRatio`, for example.
- When the height of a row changes (for example, a row expands), the change is animated, and so is the movement of the rows below it.

## Know what the scroll indicator does

A vertical scroll indicator is shown while scrolling and disappears about a second after scrolling stops. There is no setting to hide it; SwiftUI's `.scrollIndicators(.hidden)` does not reach the inside of the component. It sits at the trailing edge of the component and is not affected by `contentPadding`. Scrolling caused by a `KsScrollController` command does not show it.
