# Images

Recipes for showing images in cells with `KsImage`, prefetching the images of items that are about to appear, and managing the image cache. The examples leave out the `import` lines: each needs the Compose and Material 3 names it uses, the library names from `jp.kamusoft.kscollectionview`, and, where it appears, `java.io.File`. Later examples on this page reuse the types declared in earlier ones (`Picture`, `PictureCell`, `SignedPicture`).

How the parts fit: the list knows which items are about to come on screen. You tell it, per item, which remote images that item will need, and it fetches them ahead of time. `KsImage` is the image composable that looks into the same cache, so a prefetched image appears without being downloaded again. Both use Coil, an open-source image loading library, and its singleton image loader (`SingletonImageLoader`, the one app-wide loader through which Coil downloads and caches images); the library keeps no cache of its own. You need no knowledge of Coil unless a section below says so. Remote images need the `android.permission.INTERNET` permission in your app's manifest.

## Show an image in a cell

`KsImage` shows a remote URL, a local file, or a drawable resource of the app. You give it its size.

```kotlin
data class Picture(
    val id: String,
    val title: String,
    val thumbnailUrl: String,
    val avatarUrl: String,
)

@Composable
fun PictureCell(picture: Picture, modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxWidth()) {
        KsImage(
            url = picture.thumbnailUrl,
            modifier = Modifier.fillMaxWidth().aspectRatio(1f),
            contentDescription = picture.title,
        )
        Text(
            text = picture.title,
            style = MaterialTheme.typography.bodySmall,
            modifier = Modifier.padding(4.dp),
        )
    }
}

@Composable
fun PictureGridScreen(pictures: List<Picture>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = pictures,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        layout = KsLayout.Grid(columns = KsColumns.Fixed(3), rowSpacing = 2.dp, columnSpacing = 2.dp),
    ) {
        template { picture -> PictureCell(picture) }
    }
}
```

| Source (`KsImageSource`) | Meaning |
|---|---|
| `KsImageSource.Remote(url)` or `KsImageSource.Remote(url, key = "...")` | An image on the network; `url` is a `String`. `KsImage(url)` and `KsImage(url, key = "...")` are shorthands for it |
| `KsImageSource.File(file)` | A file on the device, as a `java.io.File` |
| `KsImageSource.Resource(R.drawable.name)` | A drawable resource bundled with the app. Drawn synchronously, without a loading state |

`contentMode` is a `KsImageContentMode`: `Fill` (default) covers the whole frame and clips what does not fit; `Fit` shows the whole image and may leave empty space.

The loading and failure displays can be replaced, both or either:

```kotlin
@Composable
fun ImageVariations(
    remoteUrl: String,
    file: File,
    logoResourceId: Int,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(16.dp)) {
        KsImage(
            source = KsImageSource.Remote(remoteUrl),
            modifier = Modifier.fillMaxWidth().height(200.dp),
            contentMode = KsImageContentMode.Fit,
            loading = { CircularProgressIndicator() },
            failure = { Text(text = "Could not load") },
        )
        KsImage(
            source = KsImageSource.File(file),
            modifier = Modifier.size(80.dp),
            failure = { Text(text = "?") },
        )
        KsImage(
            source = KsImageSource.Resource(logoResourceId),
            modifier = Modifier.size(44.dp),
            contentDescription = "Logo",
        )
    }
}
```

Rules:

- The parameters come in this order: `source` (or `url`), `modifier`, `contentDescription = null`, `contentMode = KsImageContentMode.Fill`, `loading = null`, `failure = null`. The URL shorthand has one more, `key = null`, between `contentMode` and `loading`. `url` is a `String`, not nullable: for an item that has no image, show a composable of your own instead of a `KsImage`.
- Always give `KsImage` a size through `modifier`, with `Modifier.size(...)` or `Modifier.fillMaxWidth().aspectRatio(...)`, for example. Without one its height is 0 and the image is not visible. It does not start loading until its size is known.
- `KsImage` decodes the image at the size of its frame, not at its original size, so a large original does not fill memory just to be shown small.
- A failed image is retried when its composable is created again (the row re-enters the composition or the screen is entered again) and after the cache operations described below that remove it from the disk as well (`clear` with `KsImageCacheScope.All`, and `remove`); clearing only the memory cache does not retry it. It is not retried automatically while it stays on screen.
- `contentDescription` describes the image for TalkBack. Leave it `null` for a decorative image; it is then not announced.
- When you pass the image key to the URL shorthand, pass it by name: `KsImage(url, key = picture.id)`. `KsImage` has no parameter for request headers; set them on Coil's loader (see Setup in SKILL.md).
- The default loading display is a plain fill and the default failure display is a fill with a small picture mark (an outlined square with a dot). A `loading` or `failure` composable that you supply is placed at the top start corner of the frame at its own size; fill the frame or center it yourself, with `Modifier.fillMaxSize()` and an alignment. The default colors are fixed by the library, with one set for light and one for dark mode (loading fill `#E5E5EA` / `#2C2C2E`, failure fill `#D1D1D6` / `#3A3A3C`, failure mark `#8E8E93` in both), chosen by `isSystemInDarkTheme()`; the Material color scheme is not consulted. There is no setting for these colors; replace the display to change them, which is also what an app that turns dark only through its Material color scheme should do.
- `KsImage` can also be used outside a `KsCollectionView`.

## Prefetch the images of items about to appear

Declare, per item, the remote images it shows with `prefetchResources`. The lambda returns a list of `KsResource`. The list calls it, on the main thread, for items just outside the visible range in the direction of scrolling, and starts fetching.

```kotlin
@Composable
fun PrefetchingPictureGridScreen(pictures: List<Picture>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = pictures,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        layout = KsLayout.Grid(columns = KsColumns.Fixed(3), rowSpacing = 2.dp, columnSpacing = 2.dp),
        prefetchResources = { picture -> listOf(KsResource(picture.thumbnailUrl)) },
    ) {
        template { picture -> PictureCell(picture) }
    }
}
```

`prefetchDestination` is a `KsPrefetchDestination` and says how far the image is brought:

| Destination | Meaning |
|---|---|
| `Disk` (default) | The original data is stored in the disk cache. Nothing is decoded |
| `Memory` | In addition, the image is decoded and placed in the memory cache. An image whose prefetch has finished appears without a loading display |

What the library guarantees:

- A prefetched image is used by a `KsImage` with the same URL (or the same key) without another download.
- A fetch whose item moves away from the visible range before it finishes is cancelled, as are the fetches of items removed from the array. Images that have already arrived stay in the cache.
- A list without this declaration prefetches nothing. For an item that needs no image, return an empty list.
- The disk cache needs no preparation on Android: Coil's disk cache is on by default. (On iOS the disk cache has to be turned on once at launch.)

Rules:

- Only remote images can be prefetched. File and resource sources are not prefetch targets.
- Declare URLs that are served at the size you display. For a grid of thumbnails, declare thumbnail URLs, not the URLs of the original images. Prefetching always downloads and stores the data as served, so original-size URLs cost the full download and disk space for every item scrolled past.
- Treat the lambda and the destination as fixed while the list is on screen. If you change them, only fetches started afterwards use the new ones.

## Give the prefetch a display width

With the `Memory` destination, tell the library roughly how wide the image is shown by adding `width` to the `KsResource`. The image is then decoded at about that size instead of its original size, which saves memory.

```kotlin
@Composable
fun PictureWithAvatarCell(picture: Picture, modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxWidth()) {
        KsImage(url = picture.thumbnailUrl, modifier = Modifier.fillMaxWidth().aspectRatio(1f))
        Row(
            modifier = Modifier.padding(4.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            KsImage(url = picture.avatarUrl, modifier = Modifier.size(40.dp).clip(CircleShape))
            Text(text = picture.title, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
fun MemoryPrefetchingPictureGridScreen(pictures: List<Picture>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = pictures,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        layout = KsLayout.Grid(columns = KsColumns.Fixed(3), rowSpacing = 2.dp, columnSpacing = 2.dp),
        prefetchResources = { picture ->
            listOf(
                KsResource(picture.thumbnailUrl, width = KsWidth.Column),
                KsResource(picture.avatarUrl, width = KsWidth.Fixed(40.dp)),
            )
        },
        prefetchDestination = KsPrefetchDestination.Memory,
    ) {
        template { picture -> PictureWithAvatarCell(picture) }
    }
}
```

| Width (`KsWidth`) | Meaning | Use for |
|---|---|---|
| `KsWidth.Column` | The width of one column of the list, worked out from the current size, column count, `contentPadding`, and `columnSpacing`. In a list it is the full row width | An image that spans the cell width |
| `KsWidth.Fixed(40.dp)` | That width | An image with a fixed size inside the cell |
| omitted (`null`) | The original size | Only when you really show the original size |

`KsResource` is a data class and exposes what you passed as the properties `url`, `width`, and `key`. Write `KsWidth.Column` with its type name, so that it is not confused with Compose's `Column`.

Rules:

- The width is an estimate, and it is safer to err on the large side. `KsImage` uses a cached image as it is when that image is between half and four times the size it needs. A prefetched image outside that range (smaller than half, or larger than four times) is not used and the image is loaded again for display; one between half and full size is used but looks blurry.
- The image is decoded to the smallest size that covers a square of width × width (never enlarged beyond its original size). That is enough for any frame that fits inside that square, whether the image is portrait or landscape.
- The width affects only what is decoded into memory. It does not reduce the download or the disk usage, and with the `Disk` destination it is not used at all.
- After a rotation or a change of the column count, later prefetches use the new column width. Images already cached at the old width stay and are used if they are within the range above.
- `KsWidth.Fixed` takes a finite width greater than 0. Other values, including `Dp.Unspecified`, are invalid input (see [basics.md](basics.md)).

## Use a key for images whose URL changes

When the URL of the same image changes from one fetch to the next, as with signed URLs, give the image a key. The URL is then used only to download; everything in the cache is identified by the key, so the image is found even though its URL changed, also after the app restarts.

```kotlin
data class SignedPicture(val id: String, val signedUrl: String)

val SignedPicture.imageSource: KsImageSource
    get() = KsImageSource.Remote(signedUrl, key = id)

val SignedPicture.prefetchResource: KsResource
    get() = KsResource(signedUrl, width = KsWidth.Column, key = id)

@Composable
fun SignedPictureGridScreen(pictures: List<SignedPicture>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = pictures,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        layout = KsLayout.Grid(columns = KsColumns.Fixed(3)),
        prefetchResources = { picture -> listOf(picture.prefetchResource) },
        prefetchDestination = KsPrefetchDestination.Memory,
    ) {
        template { picture ->
            KsImage(source = picture.imageSource, modifier = Modifier.fillMaxWidth().aspectRatio(1f))
        }
    }
}
```

Rules:

- Write the same key in both places: the `KsResource` of the prefetch and the `KsImage` in the cell. If they differ, the prefetched image is simply not used for display. Building both from one place, as the two extension properties above do, keeps them from drifting apart.
- A key must identify the content of one image. Giving the same key to different images makes one of them appear in place of the other.
- An empty string is not a valid key (invalid input, see [basics.md](basics.md)).
- Only remote sources take a key. A key never collides with a URL, even if the two strings are equal.

## Clear or remove cached images

`KsImageCache` operates on the shared cache, so images shown on other screens are affected too. When a call returns, the removal is complete. The calls may be made from any thread. They do their work, including the deletion on disk, on the calling thread before they return, so a call on the main thread holds the screen until it is done.

```kotlin
fun clearAllImages() {
    KsImageCache.clear(KsImageCacheScope.All)
}

fun freeDecodedImages() {
    KsImageCache.clear(KsImageCacheScope.Memory)
}

fun removeCachedImage(picture: SignedPicture) {
    KsImageCache.remove(picture.imageSource)
}
```

| Call | What is removed | What a `KsImage` on screen does |
|---|---|---|
| `KsImageCache.clear(KsImageCacheScope.Memory)` | Decoded images in memory. `Memory` and `All` are the values of `KsImageCacheScope` | Keeps showing its image. The next time it appears, the image is decoded again from the disk data |
| `KsImageCache.clear(KsImageCacheScope.All)` | Memory and disk | Goes back to the loading display and loads again |
| `KsImageCache.remove(source)` | Everything cached for that one source, at every size, in memory and on disk | Only the images of that source go back to loading; others stay |

Rules:

- These calls work only while the library's startup initializer is in place. The library registers it by itself through `androidx.startup.InitializationProvider`. If your app removes that provider, or the library's entry in it (the `<meta-data>` named `jp.kamusoft.kscollectionview.KsAppContextInitializer`), from the merged manifest with `tools:node="remove"`, `clear` and `remove` only log a warning and do nothing, while images are still displayed and cached. Check your `AndroidManifest.xml` if cached images do not go away.
- `remove` identifies the image the same way display does. An image stored with a key is removed by a source with the same key (the URL may differ) and is not removed by a source with only the URL. An image stored without a key is not removed by a source that adds a key.
- `remove` does nothing for `KsImageSource.Resource`, and for `KsImageSource.File` it is best effort. Use `clear` when a file image must be gone for certain.
- There is no "disk only" scope.

## Use Coil's own composables next to KsImage

Because the cache is that of Coil's singleton image loader, Coil's own composable (`AsyncImage`) showing the same URL uses the same cache, and benefits from prefetching. Coil's Compose artifact reaches your compile classpath through the library, so you can use `AsyncImage` (import `coil3.compose.AsyncImage`) without declaring Coil. This has two limits:

- An image with a key is not shared with an `AsyncImage` that is given the plain URL. They become two separate cache entries; nothing breaks.
- `AsyncImage` does not use the reduced images that a prefetch with a declared `width` placed in memory; only `KsImage` does. It still avoids the download.
