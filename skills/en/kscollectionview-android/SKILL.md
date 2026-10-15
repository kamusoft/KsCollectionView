---
name: kscollectionview-android
description: Build list and grid screens on Android with KsCollectionView - a Jetpack Compose composable that shows a plain list of items as a list or a grid, with templates switched by item type, grouping with pinned group headers (KsGroups), paging and pull to refresh (KsPaging, KsPagingState), drag-and-drop reordering (KsReorder, KsReorderMove), image prefetching with KsImage and KsResource, tap and long-tap callbacks, and programmatic scrolling (KsScrollController). Use when adding, changing, or reviewing a list or grid screen in a Kotlin app that imports jp.kamusoft.kscollectionview.
license: MIT
metadata:
  language: en
  source: https://github.com/kamusoft/KsCollectionView
---

# KsCollectionView for Android

KsCollectionView is a UI library for list and grid screens. You hand it a plain `List` of your own model values and a composable lambda that draws one item, and it displays them as a scrolling list or grid: it animates the differences when you replace the list, composes only the items in and near the visible range so that 10,000 items stay cheap, and provides the features that list screens keep needing, such as grouping, paging, pull to refresh, reordering, and image prefetching. This Skill covers the Android library, which is a single Jetpack Compose composable named `KsCollectionView` built on `LazyVerticalGrid`. The library also exists for iOS (SwiftUI), with the same concepts under matching names; that one is covered by the separate Skill `kscollectionview-ios`.

## What you can do

| What you want to do | Where to look |
|---|---|
| Show an array (the `List` you pass) as a list, choose the stable ID, switch the cell template by item type | [references/basics.md](references/basics.md) |
| Update the list by replacing the array, read parent state inside a cell, keep state across scrolling | [references/basics.md](references/basics.md) |
| React to taps and long taps, set the touch feedback color, scroll to an item or to either end from code | [references/basics.md](references/basics.md) |
| Know what the library does with invalid input in debug and release builds | [references/basics.md](references/basics.md) |
| Choose a list or a grid, set the column count, spacing, content padding, and list separators, know how cells are sized and what the scroll indicator does | [references/layout.md](references/layout.md) |
| Add a header and a footer, group items under pinned group headers, place the list edge to edge under the system bars | [references/layout.md](references/layout.md) |
| Load more items as the user nears the end, show loading, failure, end-of-list, and empty displays | [references/paging.md](references/paging.md) |
| Add pull to refresh, reload from your own code, color the loading indicators, write the model that owns the paging state, know when a running load is cancelled, place a paged list under the system bars | [references/paging.md](references/paging.md) |
| Let the user reorder items by drag and drop, including across groups, limit what can move and where, reorder a sorted list, know what is held back during a drag, and offer move actions to TalkBack | [references/reorder.md](references/reorder.md) |
| Show remote, file, and drawable-resource images in cells, prefetch the images of items about to appear, use a key for images whose URL changes, manage the image cache (this needs the library's startup initializer, see Setup), use Coil's own composables next to `KsImage` | [references/images.md](references/images.md) |

The library has no API for the following, so do not look for one: horizontal scrolling, swipe actions on rows, a selection or multi-selection mode, items that span several columns, staggered grids, collapsing groups, group footers, reading the scroll position or receiving scroll callbacks (the internal `LazyGridState` is not exposed), scrolling to a group header, loading earlier pages toward the start, tuning or turning off the animation of differences, and Jetpack Paging 3 (the list takes a plain `List`, not `LazyPagingItems`). A group header is your own composable, so a tap on it is handled by something `clickable` you put there.

## Setup

The library is distributed through Maven Central as one artifact. Add the dependency to the module that uses it:

```kotlin
dependencies {
    implementation("jp.kamusoft:kscollectionview:{version}")
}
```

`{version}` is a placeholder. Replace it with the version you want to use; left as it is, dependency resolution fails. To find the latest version, see the releases page at https://github.com/kamusoft/KsCollectionView/releases.

| Requirement | Minimum |
|---|---|
| Android version | Android 10 (`minSdk` 29) |
| `compileSdk` | 36 |
| Jetpack Compose | Enabled in the module (the Compose compiler plugin and `buildFeatures { compose = true }`) |

No minimum is stated for the Android Gradle Plugin or Kotlin. The library is built and verified with Android Gradle Plugin 9.4.0 and Kotlin 2.4.10.

Everything is in the package `jp.kamusoft.kscollectionview`; import the names you use from it. There are no sub-packages: every type and every function, `rememberKsScrollController` included, is imported as `jp.kamusoft.kscollectionview.<name>`. What the artifact brings to your module, and what it does not:

- Compose Runtime, Compose UI, Compose Foundation Layout, and Coil's Compose artifact (`io.coil-kt.coil3:coil-compose`) reach your compile classpath through the library, together with the Compose BOM that aligns the Compose versions. If your module declares a Compose BOM of its own, Gradle resolves each Compose library to the higher of the two versions.
- Compose Foundation (`BasicText`, `clickable`, and so on) and Material 3 (`Text`, `Button`, and so on) are used inside the library but are not passed on to your code. If your own composables use them, declare `androidx.compose.foundation:foundation` or `androidx.compose.material3:material3` in your module as usual, without a version.
- Coil (an open-source image loading library, major version 3) and its OkHttp-based network support come with the library. You do not declare Coil yourself, and you need no setup code for it. The library uses Coil's app-wide image loader as it is and never replaces it, so a loader configuration of your own (Coil's `SingletonImageLoader.Factory`, for request headers for example) applies to the library's images too.
- No R8 or ProGuard rules are needed for the library.
- Loading remote images needs the `android.permission.INTERNET` permission in your app's manifest. The library does not add it.
- The library registers one `androidx.startup` initializer through manifest merging. You write nothing for it; just do not remove `androidx.startup.InitializationProvider` from your manifest (see [references/images.md](references/images.md)).

If the library does not behave as this Skill describes, report it at https://github.com/kamusoft/KsCollectionView/issues.

## Minimal working example

A complete file that shows one list of 100 rows:

```kotlin
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import jp.kamusoft.kscollectionview.KsCollectionView

data class Item(val id: Int, val title: String)

private const val ItemCount = 100

@Composable
fun ItemListScreen(modifier: Modifier = Modifier) {
    val items = remember { List(ItemCount) { index -> Item(id = index, title = "Item $index") } }
    KsCollectionView(
        items = items,
        key = { it.id },
        modifier = modifier.fillMaxSize().safeDrawingPadding(),
    ) {
        template { item ->
            BasicText(
                text = item.title,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
            )
        }
    }
}
```

The example draws its text with `BasicText` from Compose Foundation so that it does not depend on Material. Your module needs Compose enabled and a dependency on Compose Foundation to compile it.

Five rules apply to every use of the library:

- `key` is required. It returns the stable ID of an item: unique within the list, unchanged over time, and of a type that Android can save in a `Bundle` (a string, a number, an enum, or a `Serializable` or `Parcelable` value).
- Make the item type an immutable value with `equals`, typically a `data class`, and change what is shown by passing a new `List`. The library never changes your list.
- Every feature is a named argument of the one `KsCollectionView` call, such as `onItemTap`, `groups`, `paging`, and `reorder`. The library has no modifiers of its own; `modifier` is an ordinary Compose `Modifier`.
- The trailing block only declares templates with `template { ... }`. The block itself is not composable, so composable calls go inside the lambda you pass to `template`.
- `KsCollectionView` scrolls vertically by itself and the height of each cell comes from its content. Give it a bounded height (`Modifier.fillMaxSize()`, or `Modifier.weight(1f)` in a `Column`), and do not put it inside another vertically scrolling container.

Words this Skill uses: *the array* is the `List` you pass (the Skill does not mean a Kotlin `Array`), and an *item* is one element of it. A *cell* is the container the library creates on screen for one item. A *row* is what your template draws inside a cell; the word is used for grids too, except in the spacing rules of layout.md, where a row is one horizontal line of cells. *The list* is one `KsCollectionView` on screen, whatever its layout. *Key* alone is never used: the `key` lambda returns the *ID* of an item, the `template` lambda returns its *template key*, and an image can have an *image key*.

The colors the library draws by itself (list separators, the scroll indicator, the default image displays) follow `isSystemInDarkTheme()`, not your Material color scheme. An app that turns dark only through its Material color scheme sets them itself; see [references/layout.md](references/layout.md) and [references/images.md](references/images.md).

The examples in this Skill use Material 3 for texts and buttons, and keep state in plain classes with Compose's `mutableStateOf` so that they need nothing beyond Compose. A `ViewModel` works the same way: whatever holds the state, the composable passes the current list and the current values to `KsCollectionView`. The model examples need three imports that are easy to miss: `androidx.compose.runtime.getValue` and `androidx.compose.runtime.setValue` for the `by mutableStateOf(...)` properties, and `kotlinx.coroutines.CancellationException`.

In a module without Material 3, write the texts and buttons of the examples with Compose Foundation (`BasicText`, `Modifier.clickable`), as the minimal example above does. What the library itself draws with Material 3 (the default loading displays, the tap ripple, and the pull-to-refresh indicator) needs no Material 3 dependency in your module, because Material 3 comes with the library at run time; without a `MaterialTheme` around the list, the loading displays and the pull-to-refresh indicator take their colors from Material 3's default light color scheme, in dark mode too.

## References

- [references/basics.md](references/basics.md) - items and stable IDs, templates, replacing the array, parent state in cells, taps and long taps, programmatic scrolling, invalid input.
- [references/layout.md](references/layout.md) - list and grid, columns, spacing, content padding, separators, header and footer, groups and pinned group headers, edge-to-edge placement and the system bars.
- [references/paging.md](references/paging.md) - the five paging states (`KsPagingState`), the next-page request, the six displays for loading, failure, end of list, and empty, pull to refresh, and how to write the model that owns the state.
- [references/reorder.md](references/reorder.md) - the reorder switch (the `enabled` flag of `KsReorder`), the move you receive on drop, accepting and reverting, moves across groups, TalkBack move actions.
- [references/images.md](references/images.md) - `KsImage`, prefetching with `KsResource`, and cache operations with `KsImageCache`.
