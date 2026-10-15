---
name: kscollectionview-ios
description: Build list and grid screens on iOS with KsCollectionView - a SwiftUI view that shows a plain array of items as a list or a grid, with templates switched by item type, grouping with pinned group headers, paging and pull to refresh (KsPagingState), drag-and-drop reordering (KsReorderMove), image prefetching with KsImage and KsResource, tap and long-tap callbacks, and programmatic scrolling (KsScrollController). Use when adding, changing, or reviewing a list or grid screen in a Swift app that imports KsCollectionView.
license: MIT
metadata:
  language: en
  source: https://github.com/kamusoft/KsCollectionView
---

# KsCollectionView for iOS

KsCollectionView is a UI library for list and grid screens. You hand it a plain array of your own model values and a SwiftUI closure that draws one item, and it displays them as a scrolling list or grid: it animates the differences when you replace the array, reuses cells so that 10,000 items stay cheap, and provides the features that list screens keep needing, such as grouping, paging, pull to refresh, reordering, and image prefetching. This Skill covers the iOS library, which is a single SwiftUI view named `KsCollectionView` backed by `UICollectionView`. The library also exists for Android (Jetpack Compose), with the same concepts under matching names; that one is covered by the separate Skill `kscollectionview-android`.

## What you can do

| What you want to do | Where to look |
|---|---|
| Show an array as a list, choose the stable ID, switch the cell template by item type | [references/basics.md](references/basics.md) |
| Update the list by replacing the array, read parent state inside a cell, keep state across scrolling | [references/basics.md](references/basics.md) |
| React to taps and long taps, set the touch feedback color, scroll to an item or to either end from code | [references/basics.md](references/basics.md) |
| Know what the library does with invalid input in debug and release builds | [references/basics.md](references/basics.md) |
| Choose a list or a grid, set the column count, spacing, content padding, and list separators, know how cells are sized and what the scroll indicator does | [references/layout.md](references/layout.md) |
| Add a header and a footer, group items under pinned group headers, place the list full screen under the bars | [references/layout.md](references/layout.md) |
| Load more items as the user nears the end, show loading, failure, end-of-list, and empty displays | [references/paging.md](references/paging.md) |
| Add pull to refresh, reload from your own code, color the loading indicators, write the model that owns the paging state, know when a running load is cancelled, place a paged list under the bars | [references/paging.md](references/paging.md) |
| Let the user reorder items by drag and drop, including across groups, limit what can move and where, reorder a sorted list, know what is held back during a drag, and offer move actions to VoiceOver | [references/reorder.md](references/reorder.md) |
| Show remote, file, and asset images in cells, prefetch the images of items about to appear, use a key for images whose URL changes, enable the disk cache at launch, manage the image cache, use Nuke's own views next to `KsImage` | [references/images.md](references/images.md) |

The library has no API for the following, so do not look for one: swipe actions on rows, a selection or multi-selection mode, context menus, horizontal scrolling, items that span several columns, staggered grids, collapsing groups, group footers, reading the scroll position or receiving scroll callbacks, saving and restoring the scroll position, loading earlier pages toward the start, and tuning or turning off the animation of differences. A group header is your own view, so a tap on it is handled by a `Button` you put there.

## Setup

The library is distributed as a Swift package. In a `Package.swift`, add the package and the product:

```swift
dependencies: [
    .package(url: "https://github.com/kamusoft/KsCollectionView-SPM", exact: "{version}"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "KsCollectionView", package: "KsCollectionView-SPM"),
        ]
    ),
]
```

`{version}` is a placeholder. Replace it with the version you want to use; left as it is, dependency resolution fails. To find the latest version, see the releases page at https://github.com/kamusoft/KsCollectionView/releases.

In an Xcode app project, add the same package URL (`https://github.com/kamusoft/KsCollectionView-SPM`) through *File > Add Package Dependencies...*, set the version with the dependency rule (*Exact Version*, to match the declaration above), and choose the `KsCollectionView` product. The package name you write in `.product(name:package:)` is `KsCollectionView-SPM`, the last component of the package URL; the product and the module you import are both `KsCollectionView`.

| Requirement | Minimum |
|---|---|
| iOS deployment target | iOS 16. A `Package.swift` that depends on the library declares `platforms: [.iOS(.v16)]` or later |
| Xcode | Xcode 27 or later (the package manifest declares Swift tools 6.4, so an older Xcode cannot resolve the package) |

Every source file that uses the library needs `import KsCollectionView`. The package brings in Nuke (an open-source image loading library, major version 13) as its own dependency; you do not declare it yourself unless you use Nuke's types directly. Images are kept on disk across launches only after you call `KsImagePipeline.enableSharedDiskCache()` once at launch; see "Enable the disk cache at launch" in [references/images.md](references/images.md). The library is a SwiftUI view only and has no UIKit API; in a UIKit app, show the SwiftUI screen that contains it with a `UIHostingController`.

If the library does not behave as this Skill describes, report it at https://github.com/kamusoft/KsCollectionView/issues.

## Minimal working example

A complete file that shows one list of 100 rows:

```swift
import KsCollectionView
import SwiftUI

struct Item: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
}

struct ItemListScreen: View {
    private static let itemCount = 100

    private let items = (0..<itemCount).map { index in
        Item(id: index, title: "Item \(index)")
    }

    var body: some View {
        KsCollectionView(items) { item in
            Text(item.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }
}
```

Three rules apply to every use of the library:

- The item type must be `Equatable`. The library compares items to find the cells whose content changed. It must also be `Identifiable`, unless you pass a key path to the ID with `id:`. The ID is any `Hashable` value. `Sendable` is not required; the examples add it only where an item crosses an `async` boundary. Use value types (structs and enums) for items: a class instance that is changed in place is compared with itself, so the change is not seen.
- Features are added with modifiers defined on `KsCollectionView` itself, such as `.onItemTap`, `.groups`, `.paging`, and `.reorder`. They return `KsCollectionView`, so write them directly after the `KsCollectionView(...)` expression and before any SwiftUI modifier (`.refreshable`, `.ignoresSafeArea()`, `.frame`, and so on). After a SwiftUI modifier the value is no longer a `KsCollectionView` and the library's modifiers do not compile.
- The height of each cell comes from its content. You do not give row heights.

Words this Skill uses: an *item* is one element of your array. A *cell* is the container the library creates on screen for one item, and cells are *reused*: a cell that scrolls off screen is given to another item. A *row* is the view your closure draws inside a cell; the word is used for grids too, except in the spacing rules of layout.md, where a row is one horizontal line of cells. *The list* is one `KsCollectionView` on screen, whatever its layout, and *the array* is what you pass to it.

The examples in this Skill use `ObservableObject` models so that they compile for iOS 16. A model written with the `@Observable` macro (iOS 17 and later) works too, with one difference: SwiftUI re-evaluates `body` only for the properties that `body` itself reads. A property that is read only inside a row closure, a header, or a paging display is not tracked, so read it in `body` as well; for rows and group headers, passing it to `.observedValue(_:)` does that (see [references/basics.md](references/basics.md)).

In the Swift 6 language mode: `KsCollectionView` is a `View`, so its initializers and modifiers are isolated to the main actor. The closures you pass to them (row and template content, tap callbacks, headers and footers, group headers, paging displays, `prefetchResources`, `canMove`, `canDrop`) are declared as plain closures, with neither `@MainActor` nor `@Sendable`; written inside `body`, they take the main-actor isolation of `body`, so they can read `@State` and call a `@MainActor` model without `await`. Three are declared `@MainActor`: `onLoadMore` (which is also `async`), the `retry` action handed to the failure displays, and `onMove`.

## References

- [references/basics.md](references/basics.md) - items and stable IDs, templates, replacing the array, parent state in cells, taps and long taps, programmatic scrolling, invalid input.
- [references/layout.md](references/layout.md) - list and grid, columns, spacing, content padding, separators, header and footer, groups and pinned group headers, full-screen placement and the safe area.
- [references/paging.md](references/paging.md) - the five paging states (`KsPagingState`), the next-page request, the six displays for loading, failure, end of list, and empty, pull to refresh, and how to write the model that owns the state.
- [references/reorder.md](references/reorder.md) - the reorder switch (the `isEnabled` flag), the move you receive on drop, accepting and reverting, moves across groups, VoiceOver move actions.
- [references/images.md](references/images.md) - `KsImage`, prefetching with `KsResource`, the disk cache, and cache operations with `KsImageCache`.
