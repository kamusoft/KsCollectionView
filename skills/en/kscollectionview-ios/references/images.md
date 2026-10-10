# Images

Recipes for showing images in cells with `KsImage`, prefetching the images of items that are about to appear, and managing the image cache. Every example assumes `import SwiftUI` and `import KsCollectionView`. Later examples on this page reuse the types declared in earlier ones (`Picture`, `PictureCell`, `SignedPicture`).

How the parts fit: the list knows which items are about to come on screen. You tell it, per item, which remote images that item will need, and it fetches them ahead of time. `KsImage` is the image view that looks into the same cache, so a prefetched image appears without being downloaded again. Both use Nuke, an open-source image loading library, and its shared pipeline (`ImagePipeline.shared`, the one app-wide object through which Nuke downloads and caches images); the library keeps no cache of its own. You need no knowledge of Nuke unless a section below says so.

## Show an image in a cell

`KsImage` shows a remote URL, a local file, or an image from the asset catalog. You give it its size.

```swift
struct Picture: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let thumbnailURL: URL
    let avatarURL: URL
}

struct PictureCell: View {
    let picture: Picture

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            KsImage(picture.thumbnailURL)
                .aspectRatio(1, contentMode: .fit)
                .accessibilityLabel(picture.title)
            Text(picture.title)
                .font(.caption)
                .padding(.horizontal, 4)
        }
    }
}

struct PictureGridScreen: View {
    let pictures: [Picture]

    var body: some View {
        KsCollectionView(
            pictures,
            layout: .grid(columns: .fixed(3), rowSpacing: 2, columnSpacing: 2)
        ) { picture in
            PictureCell(picture: picture)
        }
    }
}
```

| Source (`KsImageSource`) | Meaning |
|---|---|
| `.remote(url)` or `.remote(url, key: "...")` | An image on the network. `KsImage(url)` and `KsImage(url, key: "...")` are shorthands for it |
| `.file(url)` | A file on the device |
| `.asset("Name")` | An image in the app's asset catalog. Drawn synchronously, without a loading state |

`contentMode:` is a `KsImageContentMode`: `.fill` (default) covers the whole frame and clips what does not fit; `.fit` shows the whole image and may leave empty space.

The loading and failure displays can be replaced, both or either:

```swift
struct ImageVariationsView: View {
    let remoteURL: URL
    let fileURL: URL

    var body: some View {
        VStack(spacing: 16) {
            KsImage(.remote(remoteURL), contentMode: .fit) {
                ProgressView()
            } failure: {
                Text("Could not load")
            }
            .frame(height: 200)

            KsImage(.file(fileURL), failure: { Image(systemName: "photo") })
                .frame(width: 80, height: 80)

            KsImage(.remote(remoteURL), loading: { Color.gray })
                .frame(width: 80, height: 80)

            KsImage(.asset("Logo"))
                .frame(width: 44, height: 44)
        }
    }
}
```

Rules:

- Always give `KsImage` a size with `.frame(...)` or `.aspectRatio(...)`. Without one it takes all the space it is offered, which squeezes the views next to it. It does not start loading until its size is known.
- The arguments come in this order: the source (or the URL, then `key:`), `contentMode:`, `loading:`, `failure:`. The URL shorthand takes the same `contentMode:`, `loading:`, and `failure:` as the source form. The URL is a `URL`, not an optional: for an item that has no image, show a view of your own instead of a `KsImage`.
- A single unlabeled trailing closure (`KsImage(source) { ... }`) does not compile, because it could be either display. Write both closures, the second labeled `failure:`, or one closure with its label (`loading:` or `failure:`) inside the parentheses.
- `KsImage` decodes the image at the size of its frame, not at its original size, so a large original does not fill memory just to be shown small.
- A failed image is retried when its view is created again (the cell is reused or the screen is entered again) and after the cache operations described below that remove it from the disk as well (`KsImageCache.clear(.all)` and `remove`); clearing only the memory cache does not retry it. It is not retried automatically while it stays on screen.
- Describe the image for VoiceOver with SwiftUI's `.accessibilityLabel(_:)`, or hide a decorative one with `.accessibilityHidden(true)`.
- The default loading display is a plain fill and the default failure display is a fill with a photo icon. A display you supply is centered in the frame. The default colors are fixed by the library, with one set for light and one for dark appearance (loading fill `#E5E5EA` / `#2C2C2E`, failure fill `#D1D1D6` / `#3A3A3C`, failure icon `#8E8E93` in both), and follow the appearance of the place where the image is shown. There is no setting for these colors; replace the display to change them.
- `KsImage` can also be used outside a `KsCollectionView`.

## Prefetch the images of items about to appear

Declare, per item, the remote images it shows with `.prefetchResources(destination:_:)`. The closure returns an array of `KsResource`. The list calls it, on the main thread, for items just outside the visible range in the direction of scrolling, and starts fetching. The closure is a plain `(Item) -> [KsResource]` (`Item` stands for your item type), with neither `@MainActor` nor `@Sendable`.

```swift
struct PrefetchingPictureGridScreen: View {
    let pictures: [Picture]

    var body: some View {
        KsCollectionView(
            pictures,
            layout: .grid(columns: .fixed(3), rowSpacing: 2, columnSpacing: 2)
        ) { picture in
            PictureCell(picture: picture)
        }
        .prefetchResources { picture in
            [KsResource(picture.thumbnailURL)]
        }
    }
}
```

`destination:` is a `KsPrefetchDestination` and says how far the image is brought:

| Destination | Meaning |
|---|---|
| `.disk` (default) | The original data is stored in the disk cache. Nothing is decoded. Needs the disk cache to be enabled (see "Enable the disk cache at launch") |
| `.memory` | In addition, the image is decoded and placed in the memory cache. An image whose prefetch has finished appears without a loading display |

What the library guarantees:

- A prefetched image is used by a `KsImage` with the same URL (or the same key) without another download.
- A fetch whose item moves away from the visible range before it finishes is cancelled, as are the fetches of items removed from the array. Images that have already arrived stay in the cache.
- A list without this declaration prefetches nothing. For an item that needs no image, return an empty array.

Rules:

- Only remote images can be prefetched. File and asset sources are not prefetch targets.
- Declare URLs that are served at the size you display. For a grid of thumbnails, declare thumbnail URLs, not the URLs of the original images. Prefetching always downloads and stores the data as served, so original-size URLs cost the full download and disk space for every item scrolled past.
- Treat the closure and the destination as fixed while the list is on screen. If you change them, only fetches started afterwards use the new ones.

## Give the prefetch a display width

With the `.memory` destination, tell the library roughly how wide the image is shown by adding `width:` to the `KsResource`. The image is then decoded at about that size instead of its original size, which saves memory.

```swift
struct PictureWithAvatarCell: View {
    let picture: Picture

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            KsImage(picture.thumbnailURL)
                .aspectRatio(1, contentMode: .fit)
            HStack {
                KsImage(picture.avatarURL)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                Text(picture.title)
                    .font(.caption)
            }
            .padding(4)
        }
    }
}

struct MemoryPrefetchingPictureGridScreen: View {
    let pictures: [Picture]

    var body: some View {
        KsCollectionView(
            pictures,
            layout: .grid(columns: .fixed(3), rowSpacing: 2, columnSpacing: 2)
        ) { picture in
            PictureWithAvatarCell(picture: picture)
        }
        .prefetchResources(destination: .memory) { picture in
            [
                KsResource(picture.thumbnailURL, width: .column),
                KsResource(picture.avatarURL, width: .fixed(40)),
            ]
        }
    }
}
```

| Width (`KsWidth`) | Meaning | Use for |
|---|---|---|
| `.column` | The width of one column of the list, worked out from the current size, column count, `contentPadding`, and `columnSpacing`. In a list it is the full row width | An image that spans the cell width |
| `.fixed(40)` | That many points | An image with a fixed size inside the cell |
| omitted (`nil`) | The original size | Only when you really show the original size |

`KsResource` exposes what you passed as the read-only properties `url`, `width`, and `key`.

Rules:

- The width is an estimate, and it is safer to err on the large side. `KsImage` uses a cached image as it is when that image is between half and four times the size it needs. A prefetched image outside that range (smaller than half, or larger than four times) is not used and the image is loaded again for display; one between half and full size is used but looks blurry.
- The image is decoded to the smallest size that covers a square of width × width (never enlarged beyond its original size). That is enough for any frame that fits inside that square, whether the image is portrait or landscape.
- The width affects only what is decoded into memory. It does not reduce the download or the disk usage, and with the `.disk` destination it is not used at all.
- After a rotation or a change of the column count, later prefetches use the new column width. Images already cached at the old width stay and are used if they are within the range above.
- `.fixed` takes a finite value greater than 0. Other values are invalid input (see [basics.md](basics.md)).

## Use a key for images whose URL changes

When the URL of the same image changes from one fetch to the next, as with signed URLs, give the image a key. The URL is then used only to download; everything in the cache is identified by the key, so the image is found even though its URL changed, also after the app restarts. Finding it after a restart needs the disk cache, which is off until you enable it (see the next section); without it nothing is kept on disk, with or without a key.

```swift
struct SignedPicture: Identifiable, Equatable, Sendable {
    let id: String
    let signedURL: URL
}

extension SignedPicture {
    var imageSource: KsImageSource {
        .remote(signedURL, key: id)
    }

    var prefetchResource: KsResource {
        KsResource(signedURL, width: .column, key: id)
    }
}

struct SignedPictureGridScreen: View {
    let pictures: [SignedPicture]

    var body: some View {
        KsCollectionView(pictures, layout: .grid(columns: .fixed(3))) { picture in
            KsImage(picture.imageSource)
                .aspectRatio(1, contentMode: .fit)
        }
        .prefetchResources(destination: .memory) { picture in
            [picture.prefetchResource]
        }
    }
}
```

Rules:

- Write the same key in both places: the `KsResource` of the prefetch and the `KsImage` in the cell. If they differ, the prefetched image is simply not used for display. Building both from one place, as the extension above does, keeps them from drifting apart.
- A key must identify the content of one image. Giving the same key to different images makes one of them appear in place of the other.
- An empty string is not a valid key (invalid input, see [basics.md](basics.md)).
- Only remote sources take a key. A key never collides with a URL, even if the two strings are equal.

## Enable the disk cache at launch

On iOS the shared image pipeline has no disk cache until you turn it on. Call `KsImagePipeline.enableSharedDiskCache()` once when the app starts.

```swift
@main
struct PictureApp: App {
    init() {
        KsImagePipeline.enableSharedDiskCache()
    }

    var body: some Scene {
        WindowGroup {
            PictureGridScreen(pictures: [])
        }
    }
}
```

- The call takes no arguments. The disk cache it adds is Nuke's own, with Nuke's default size limit and location; `KsImageCache.clear(.all)` empties it.
- Without this call, downloaded data is not kept on disk: the `.disk` prefetch destination leaves nothing behind for display, and images are downloaded again after the app restarts.
- Call it at launch, before any list is shown. A list created before the call keeps prefetching through the previous pipeline.
- If the app has already set a disk cache on Nuke's shared pipeline, the call does nothing.
- The call replaces the shared pipeline with one that keeps the current configuration but has the default delegate. An app that customizes requests through Nuke's `ImagePipeline.Delegate` (to add authentication headers, for example) should not call it; instead, set an `ImagePipeline` configured with a `dataCache` and that delegate as `ImagePipeline.shared` yourself. That code uses Nuke's types, so such an app declares Nuke (major version 13) in its own dependencies and follows Nuke's documentation; this Skill does not cover it. `KsImage` itself has no parameter for request headers.
- This step exists only on iOS. On Android the loader's disk cache is on by default.

## Clear or remove cached images

`KsImageCache` operates on the shared cache, so images shown on other screens are affected too. When a call returns, the removal is complete.

```swift
@MainActor
func clearAllImages() {
    KsImageCache.clear(.all)
}

@MainActor
func freeDecodedImages() {
    KsImageCache.clear(.memory)
}

@MainActor
func removeCachedImage(of picture: SignedPicture) {
    KsImageCache.remove(picture.imageSource)
}
```

| Call | What is removed | What a `KsImage` on screen does |
|---|---|---|
| `KsImageCache.clear(.memory)` | Decoded images in memory. `.memory` and `.all` are the cases of `KsImageCacheScope` | Keeps showing its image. The next time it appears, the image is decoded again from the disk data (or downloaded again if the disk cache is not enabled) |
| `KsImageCache.clear(.all)` | Memory and disk | Goes back to the loading display and loads again |
| `KsImageCache.remove(source)` | Everything cached for that one source, at every size, in memory and on disk | Only the images of that source go back to loading; others stay |

Rules:

- `KsImageCache` is isolated to the main actor.
- `remove` identifies the image the same way display does. An image stored with a key is removed by a source with the same key (the URL may differ) and is not removed by a source with only the URL. An image stored without a key is not removed by a source that adds a key.
- `remove` does nothing for `.asset` sources. A `.file` source is handled like a remote one: what was cached for it is removed, and the file itself is not touched.
- There is no "disk only" scope.

## Use Nuke's own views next to KsImage

Because the cache is Nuke's shared pipeline, Nuke's own image view (`LazyImage` from NukeUI) showing the same URL uses the same cache, and benefits from prefetching. This has three limits:

- An image with a key is not shared with a `LazyImage` that is given the plain URL. They become two separate cache entries; nothing breaks.
- After `KsImageCache.remove` of a source without a key, that source is no longer shared with a `LazyImage` showing the same URL, and the `LazyImage` side may keep showing the image from before the removal until the cache evicts it. In an app that mixes `KsImage` and `LazyImage` for the same URLs, use `KsImageCache.clear` instead of `remove`, or check after removing that both the `KsImage` and the `LazyImage` show the new image.
- `LazyImage` does not use the reduced images that a prefetch with a declared `width:` placed in memory; only `KsImage` does. It still avoids the download.

SwiftUI's `AsyncImage` is unrelated to this cache.
