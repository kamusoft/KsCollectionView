# 画像

`KsImage` でセルに画像を表示する、もうすぐ表示される項目の画像を先読みする、画像のキャッシュを操作するためのレシピです。例は `import` の行を省いています。どの例にも、使っている Compose と Material 3 の名前と、`jp.kamusoft.kscollectionview` にあるライブラリの名前の import が要ります。出てくる場所では、`java.io.File` の import も要ります。このページの後ろの例は、前の例で宣言した型 (`Picture`・`PictureCell`・`SignedPicture`) をそのまま使います。

全体のつながり: どの項目がもうすぐ画面に出るかを知っているのは、一覧です。その項目がどのリモート画像を使うかを項目ごとに宣言しておくと、一覧が前もって取得します。`KsImage` は、同じキャッシュを見る画像の Composable なので、先読みした画像は、ダウンロードし直さずに表示されます。どちらも、オープンソースの画像読み込みライブラリの Coil と、その共有のローダー (`SingletonImageLoader`。Coil が画像のダウンロードとキャッシュに使う、アプリに 1 つのローダー) を使います。ライブラリは、自分のキャッシュを持ちません。下の節が断っている場合を除いて、Coil の知識は要りません。リモートの画像には、アプリのマニフェストに `android.permission.INTERNET` の権限が要ります。

## セルに画像を表示する

`KsImage` は、リモートの URL・端末の中のファイル・アプリのドローアブルリソースを表示します。大きさは、利用する側が与えます。

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

| ソース (`KsImageSource`) | 意味 |
|---|---|
| `KsImageSource.Remote(url)` または `KsImageSource.Remote(url, key = "...")` | ネットワーク上の画像。`url` は `String` です。`KsImage(url)` と `KsImage(url, key = "...")` は、これを短く書く形です |
| `KsImageSource.File(file)` | 端末の中のファイル。`java.io.File` で渡します |
| `KsImageSource.Resource(R.drawable.name)` | アプリに同梱したドローアブルリソース。同期で描かれ、読み込み中の状態を持ちません |

`contentMode` は `KsImageContentMode` です。`Fill` (既定) は、枠の全体を覆い、収まらない部分を切り取ります。`Fit` は、画像の全体を表示し、枠に空きが出ることがあります。

読み込み中と失敗の表示は、両方でも、片方だけでも、差し替えられます。

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

約束ごと:

- 引数の順は、`source` (または `url`)・`modifier`・`contentDescription = null`・`contentMode = KsImageContentMode.Fill`・`loading = null`・`failure = null` です。URL を短く書く形には、`contentMode` と `loading` の間に、もう 1 つ `key = null` があります。`url` は `String` で、null は渡せません。画像の無い項目では、`KsImage` を作らずに、自分の Composable を出します。
- `KsImage` には、必ず `modifier` で大きさを与えます。たとえば `Modifier.size(...)` や `Modifier.fillMaxWidth().aspectRatio(...)` です。与えないと、高さが 0 になり、画像が見えません。大きさが決まるまでは、読み込みを始めません。
- `KsImage` は、画像を元の大きさではなく、枠の大きさでデコードします。大きな元画像を小さく表示するだけで、メモリが埋まることはありません。
- 失敗した画像は、その Composable が作り直されたとき (行がコンポジションに入り直したときや、画面に入り直したとき) と、後で説明するキャッシュの操作のうち、ディスクからも消すもの (`KsImageCacheScope.All` の `clear` と、`remove`) の後に、もう一度試されます。メモリのキャッシュだけを消しても、試し直しは起きません。画面に出続けている間は、自動では試されません。
- `contentDescription` は、TalkBack に画像を説明します。飾りの画像では `null` のままにします。そのときは、読み上げられません。
- URL を短く書く形に画像のキーを渡すときは、名前を付けて渡します: `KsImage(url, key = picture.id)`。`KsImage` には、要求のヘッダーを渡す引数はありません。ヘッダーは、Coil のローダーに設定します (SKILL.md の「導入」を参照)。
- 既定の読み込み中の表示は無地の塗りで、既定の失敗の表示は、塗りと、小さな絵の印 (線で描いた四角と点) です。自分で渡した `loading` や `failure` の Composable は、自分の大きさのまま、枠の左上 (始端の上) に置かれます。枠を埋めるか中央に置くかは、`Modifier.fillMaxSize()` と配置の指定で、自分で決めます。既定の色はライブラリが決めた固定の値で、ライト用とダーク用の 2 組があり (読み込み中の塗りは `#E5E5EA` / `#2C2C2E`、失敗の塗りは `#D1D1D6` / `#3A3A3C`、失敗の印はどちらも `#8E8E93`)、`isSystemInDarkTheme()` で選ばれます。Material の配色は見ません。この色を変える設定はありません。変えたいときは、表示を差し替えます。Material の配色の切り替えだけでダークにするアプリも、表示を差し替えてください。
- `KsImage` は、`KsCollectionView` の外でも使えます。

## もうすぐ表示される項目の画像を先読みする

項目が表示するリモート画像を、`prefetchResources` で項目ごとに宣言します。ラムダは `KsResource` のリストを返します。一覧は、表示範囲のすぐ外にある、スクロールの進む向きの項目について、メインスレッドでラムダを呼び、取得を始めます。

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

`prefetchDestination` は `KsPrefetchDestination` で、画像をどこまで持ってくるかを表します。

| 到達点 | 意味 |
|---|---|
| `Disk` (既定) | 元のデータを、ディスクのキャッシュに保存します。デコードはしません |
| `Memory` | それに加えて、画像をデコードして、メモリのキャッシュに載せます。先読みが終わっている画像は、読み込み中の表示を出さずに表示されます |

ライブラリが保証すること:

- 先読みした画像は、同じ URL (または同じキー) の `KsImage` に、ダウンロードし直さずに使われます。
- 取得が終わる前に項目が表示範囲から離れると、その取得は取り消されます。配列から消えた項目の取得も同じです。届き終えた画像は、キャッシュに残ります。
- この宣言の無い一覧は、何も先読みしません。画像の要らない項目では、空のリストを返します。
- Android では、ディスクキャッシュに準備は要りません。Coil のディスクキャッシュは、既定で有効です。(iOS では、起動時に 1 度、ディスクキャッシュを有効にする必要があります。)

約束ごと:

- 先読みできるのは、リモートの画像だけです。ファイルとリソースのソースは、先読みの対象ではありません。
- 表示する大きさで配信される URL を宣言します。サムネイルのグリッドには、元の画像の URL ではなく、サムネイルの URL を宣言してください。先読みは、いつも配信されたままのデータをダウンロードして保存します。元の大きさの URL を宣言すると、通り過ぎる項目のすべてで、元の大きさの分の通信とディスクを使います。
- ラムダと到達点は、一覧の表示中は変えないものとして扱います。変えた場合、新しいものが使われるのは、その後に始まる取得だけです。

## 先読みに表示の幅を伝える

到達点が `Memory` のときは、`KsResource` に `width` を足して、画像を表示するおおよその幅をライブラリに伝えます。画像は、元の大きさではなく、その幅に近い大きさでデコードされるので、メモリを節約できます。

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

| 幅 (`KsWidth`) | 意味 | 向く使い方 |
|---|---|---|
| `KsWidth.Column` | 一覧の 1 列分の幅。今の大きさ・列数・`contentPadding`・`columnSpacing` から求めます。リストでは、行の幅いっぱいです | セルの幅いっぱいに置く画像 |
| `KsWidth.Fixed(40.dp)` | その幅 | セルの中に固定の大きさで置く画像 |
| 省略 (`null`) | 元の大きさ | 本当に元の大きさで表示するときだけ |

`KsResource` は data class で、渡した値を、プロパティ `url`・`width`・`key` として持ちます。`KsWidth.Column` は、Compose の `Column` と取り違えないよう、型の名前を付けて書きます。

約束ごと:

- 幅は概算でよく、大きめに書くほうが安全です。`KsImage` は、キャッシュにある画像が、必要な大きさの半分から 4 倍までの間なら、そのまま使います。この範囲の外 (半分より小さい、または 4 倍より大きい) の先読みの画像は使われず、表示のために読み込み直されます。半分から等倍までの画像は使われますが、ぼやけて見えます。
- 画像は、幅 × 幅の正方形を覆う最小の大きさにデコードされます (元の大きさを超えて拡大はしません)。その正方形に収まる枠なら、縦長の画像でも横長の画像でも足ります。
- 幅が効くのは、メモリにデコードする大きさだけです。ダウンロードの量とディスクの使用量は減りません。到達点が `Disk` のときは、幅はまったく使われません。
- 回転や列数の変更の後は、その後の先読みが新しい列の幅を使います。古い幅でキャッシュに載った画像は残り、上の範囲に入っていれば使われます。
- `KsWidth.Fixed` には、0 より大きい有限の幅を渡します。ほかの値 (`Dp.Unspecified` を含む) は不正入力です ([basics.md](basics.md) を参照)。

## URL が変わる画像にキーを使う

署名付きの URL のように、同じ画像の URL が取得のたびに変わるときは、画像にキーを付けます。URL はダウンロードにだけ使われ、キャッシュの中のものはすべてキーで見分けられます。そのため、URL が変わっても、アプリを再起動した後でも、画像が見つかります。

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

約束ごと:

- 同じキーを、2 か所に書きます。先読みの `KsResource` と、セルの `KsImage` です。食い違うと、先読みした画像が表示に使われないだけになります。上の 2 つの拡張プロパティのように、両方を 1 か所から作ると、食い違いません。
- キーは、1 つの画像の中身を特定する値にします。違う画像に同じキーを付けると、一方がもう一方の代わりに表示されます。
- 空文字はキーに使えません (不正入力。[basics.md](basics.md) を参照)。
- キーを持てるのは、リモートのソースだけです。キーと URL は、文字列が同じでも衝突しません。

## キャッシュした画像を消す

`KsImageCache` は共有のキャッシュを操作するので、ほかの画面に出ている画像にも影響します。呼び出しから戻った時点で、削除は終わっています。どのスレッドから呼んでも構いません。ディスクの削除を含む仕事を、呼び出したスレッドで済ませてから戻るので、メインスレッドで呼ぶと、終わるまで画面が待たされます。

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

| 呼び出し | 消えるもの | 画面に出ている `KsImage` の動き |
|---|---|---|
| `KsImageCache.clear(KsImageCacheScope.Memory)` | メモリの上のデコード済みの画像。`Memory` と `All` は `KsImageCacheScope` の値です | 画像を表示し続けます。次に表示されるときに、ディスクのデータからデコードし直します |
| `KsImageCache.clear(KsImageCacheScope.All)` | メモリとディスク | 読み込み中の表示に戻り、読み込み直します |
| `KsImageCache.remove(source)` | その 1 つのソースについてキャッシュしたものすべて (どの大きさのものも。メモリもディスクも) | そのソースの画像だけが読み込み中に戻り、ほかは残ります |

約束ごと:

- これらの呼び出しが働くのは、ライブラリの起動時の初期化が残っているときだけです。初期化は、ライブラリが `androidx.startup.InitializationProvider` を通して自分で登録します。アプリが、`tools:node="remove"` を使って、マージ後のマニフェストからこの provider か、その中のライブラリの項目 (名前が `jp.kamusoft.kscollectionview.KsAppContextInitializer` の `<meta-data>`) を取り除いていると、`clear` も `remove` も警告をログに残すだけで何もしません。その間も、画像の表示とキャッシュは動き続けます。キャッシュした画像が消えないときは、`AndroidManifest.xml` を確かめてください。
- `remove` は、表示と同じやり方で画像を見分けます。キーを付けて保存した画像は、同じキーを付けたソースで消えます (URL は違っていても構いません)。URL だけのソースでは消えません。キーなしで保存した画像は、キーを足したソースでは消えません。
- `remove` は、`KsImageSource.Resource` には何もしません。`KsImageSource.File` に対しては、できる範囲で消すだけです。ファイルの画像を確実に消したいときは、`clear` を使います。
- 「ディスクだけ」を消す範囲はありません。

## Coil 自身の Composable を KsImage と並べて使う

キャッシュは Coil の共有のローダーのものなので、Coil 自身の Composable (`AsyncImage`) で同じ URL を表示すると、同じキャッシュが使われ、先読みも効きます。Coil の Compose 向けのアーティファクトは、ライブラリを通して compile classpath に届くので、Coil を依存に書かなくても `AsyncImage` (import するのは `coil3.compose.AsyncImage`) を使えます。ただし、限界が 2 つあります。

- キーを付けた画像は、素の URL を渡した `AsyncImage` とは共有されません。別々の 2 つのキャッシュの項目になるだけで、壊れはしません。
- `AsyncImage` は、`width` を宣言した先読みがメモリに載せた縮小済みの画像を使いません。使うのは `KsImage` だけです。ダウンロードが省かれることは変わりません。
