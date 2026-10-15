# 画像

`KsImage` でセルに画像を表示する、もうすぐ表示される項目の画像を先読みする、画像のキャッシュを操作するためのレシピです。どの例も `import SwiftUI` と `import KsCollectionView` を前提にしています。このページの後ろの例は、前の例で宣言した型 (`Picture`・`PictureCell`・`SignedPicture`) をそのまま使います。

全体のつながり: どの項目がもうすぐ画面に出るかを知っているのは、一覧です。その項目がどのリモート画像を使うかを項目ごとに宣言しておくと、一覧が前もって取得します。`KsImage` は、同じキャッシュを見る画像の View なので、先読みした画像は、ダウンロードし直さずに表示されます。どちらも、オープンソースの画像読み込みライブラリの Nuke と、その共有のパイプライン (`ImagePipeline.shared`。Nuke が画像のダウンロードとキャッシュに使う、アプリに 1 つのオブジェクト) を使います。ライブラリは、自分のキャッシュを持ちません。下の節が断っている場合を除いて、Nuke の知識は要りません。

## セルに画像を表示する

`KsImage` は、リモートの URL・端末の中のファイル・アセットカタログの画像を表示します。大きさは、利用する側が与えます。

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

| ソース (`KsImageSource`) | 意味 |
|---|---|
| `.remote(url)` または `.remote(url, key: "...")` | ネットワーク上の画像。`KsImage(url)` と `KsImage(url, key: "...")` は、これを短く書く形です |
| `.file(url)` | 端末の中のファイル |
| `.asset("Name")` | アプリのアセットカタログの画像。同期で描かれ、読み込み中の状態を持ちません |

`contentMode:` は `KsImageContentMode` です。`.fill` (既定) は、枠の全体を覆い、収まらない部分を切り取ります。`.fit` は、画像の全体を表示し、枠に空きが出ることがあります。

読み込み中と失敗の表示は、両方でも、片方だけでも、差し替えられます。

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

約束ごと:

- `KsImage` には、必ず `.frame(...)` か `.aspectRatio(...)` で大きさを与えます。与えないと、与えられた領域をすべて占め、隣の View を押しつぶします。大きさが決まるまでは、読み込みを始めません。
- 引数の順は、ソース (または URL と、その後の `key:`)・`contentMode:`・`loading:`・`failure:` です。URL を短く書く形も、ソースを渡す形と同じ `contentMode:`・`loading:`・`failure:` を受け取ります。URL は `URL` で、オプショナルではありません。画像の無い項目では、`KsImage` を作らずに、自分の View を出します。
- ラベルの無い末尾クロージャを 1 つだけ書く形 (`KsImage(source) { ... }`) は、コンパイルできません。どちらの表示にも当たりうるためです。クロージャを 2 つ書いて 2 つ目に `failure:` のラベルを付けるか、1 つのクロージャをラベル (`loading:` か `failure:`) 付きで括弧の中に書きます。
- `KsImage` は、画像を元の大きさではなく、枠の大きさでデコードします。大きな元画像を小さく表示するだけで、メモリが埋まることはありません。
- 失敗した画像は、その View が作り直されたとき (セルが再利用されたときや、画面に入り直したとき) と、後で説明するキャッシュの操作のうち、ディスクからも消すもの (`KsImageCache.clear(.all)` と `remove`) の後に、もう一度試されます。メモリのキャッシュだけを消しても、試し直しは起きません。画面に出続けている間は、自動では試されません。
- VoiceOver に画像を説明するには、SwiftUI の `.accessibilityLabel(_:)` を使います。飾りの画像は、`.accessibilityHidden(true)` で隠します。
- 既定の読み込み中の表示は無地の塗りで、既定の失敗の表示は、塗りと写真のアイコンです。自分で渡した表示は、枠の中央に置かれます。既定の色はライブラリが決めた固定の値で、ライト用とダーク用の 2 組があり (読み込み中の塗りは `#E5E5EA` / `#2C2C2E`、失敗の塗りは `#D1D1D6` / `#3A3A3C`、失敗のアイコンはどちらも `#8E8E93`)、画像が置かれた場所の外観に従います。この色を変える設定はありません。変えたいときは、表示を差し替えます。
- `KsImage` は、`KsCollectionView` の外でも使えます。

## もうすぐ表示される項目の画像を先読みする

項目が表示するリモート画像を、`.prefetchResources(destination:_:)` で項目ごとに宣言します。クロージャは `KsResource` の配列を返します。一覧は、表示範囲のすぐ外にある、スクロールの進む向きの項目について、メインスレッドでクロージャを呼び、取得を始めます。クロージャは、`@MainActor` も `@Sendable` も付かない、ふつうの `(Item) -> [KsResource]` です (`Item` は、自分の項目の型のことです)。

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

`destination:` は `KsPrefetchDestination` で、画像をどこまで持ってくるかを表します。

| 到達点 | 意味 |
|---|---|
| `.disk` (既定) | 元のデータを、ディスクのキャッシュに保存します。デコードはしません。ディスクキャッシュを有効にしておく必要があります (「起動時にディスクキャッシュを有効にする」を参照) |
| `.memory` | それに加えて、画像をデコードして、メモリのキャッシュに載せます。先読みが終わっている画像は、読み込み中の表示を出さずに表示されます |

ライブラリが保証すること:

- 先読みした画像は、同じ URL (または同じキー) の `KsImage` に、ダウンロードし直さずに使われます。
- 取得が終わる前に項目が表示範囲から離れると、その取得は取り消されます。配列から消えた項目の取得も同じです。届き終えた画像は、キャッシュに残ります。
- この宣言の無い一覧は、何も先読みしません。画像の要らない項目では、空の配列を返します。

約束ごと:

- 先読みできるのは、リモートの画像だけです。ファイルとアセットのソースは、先読みの対象ではありません。
- 表示する大きさで配信される URL を宣言します。サムネイルのグリッドには、元の画像の URL ではなく、サムネイルの URL を宣言してください。先読みは、いつも配信されたままのデータをダウンロードして保存します。元の大きさの URL を宣言すると、通り過ぎる項目のすべてで、元の大きさの分の通信とディスクを使います。
- クロージャと到達点は、一覧の表示中は変えないものとして扱います。変えた場合、新しいものが使われるのは、その後に始まる取得だけです。

## 先読みに表示の幅を伝える

到達点が `.memory` のときは、`KsResource` に `width:` を足して、画像を表示するおおよその幅をライブラリに伝えます。画像は、元の大きさではなく、その幅に近い大きさでデコードされるので、メモリを節約できます。

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

| 幅 (`KsWidth`) | 意味 | 向く使い方 |
|---|---|---|
| `.column` | 一覧の 1 列分の幅。今の大きさ・列数・`contentPadding`・`columnSpacing` から求めます。リストでは、行の幅いっぱいです | セルの幅いっぱいに置く画像 |
| `.fixed(40)` | そのポイント数 | セルの中に固定の大きさで置く画像 |
| 省略 (`nil`) | 元の大きさ | 本当に元の大きさで表示するときだけ |

`KsResource` は、渡した値を、読み取り専用のプロパティ `url`・`width`・`key` として持ちます。

約束ごと:

- 幅は概算でよく、大きめに書くほうが安全です。`KsImage` は、キャッシュにある画像が、必要な大きさの半分から 4 倍までの間なら、そのまま使います。この範囲の外 (半分より小さい、または 4 倍より大きい) の先読みの画像は使われず、表示のために読み込み直されます。半分から等倍までの画像は使われますが、ぼやけて見えます。
- 画像は、幅 × 幅の正方形を覆う最小の大きさにデコードされます (元の大きさを超えて拡大はしません)。その正方形に収まる枠なら、縦長の画像でも横長の画像でも足ります。
- 幅が効くのは、メモリにデコードする大きさだけです。ダウンロードの量とディスクの使用量は減りません。到達点が `.disk` のときは、幅はまったく使われません。
- 回転や列数の変更の後は、その後の先読みが新しい列の幅を使います。古い幅でキャッシュに載った画像は残り、上の範囲に入っていれば使われます。
- `.fixed` には、0 より大きい有限の値を渡します。ほかの値は不正入力です ([basics.md](basics.md) を参照)。

## URL が変わる画像にキーを使う

署名付きの URL のように、同じ画像の URL が取得のたびに変わるときは、画像にキーを付けます。URL はダウンロードにだけ使われ、キャッシュの中のものはすべてキーで見分けられます。そのため、URL が変わっても、アプリを再起動した後でも、画像が見つかります。再起動の後に見つかるには、ディスクキャッシュが要ります。ディスクキャッシュは、有効にするまで無効です (次の節を参照)。無効のままでは、キーの有無にかかわらず、ディスクには何も残りません。

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

約束ごと:

- 同じキーを、2 か所に書きます。先読みの `KsResource` と、セルの `KsImage` です。食い違うと、先読みした画像が表示に使われないだけになります。上の extension のように、両方を 1 か所から作ると、食い違いません。
- キーは、1 つの画像の中身を特定する値にします。違う画像に同じキーを付けると、一方がもう一方の代わりに表示されます。
- 空文字はキーに使えません (不正入力。[basics.md](basics.md) を参照)。
- キーを持てるのは、リモートのソースだけです。キーと URL は、文字列が同じでも衝突しません。

## 起動時にディスクキャッシュを有効にする

iOS では、共有の画像パイプラインは、有効にするまでディスクキャッシュを持ちません。アプリの起動時に、`KsImagePipeline.enableSharedDiskCache()` を 1 度呼びます。

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

- この呼び出しに、引数はありません。足されるディスクキャッシュは Nuke 自身のもので、容量の上限と置き場所は Nuke の既定です。`KsImageCache.clear(.all)` で空になります。
- これを呼ばないと、ダウンロードしたデータはディスクに残りません。到達点が `.disk` の先読みは表示のために何も残さず、アプリを再起動すると、画像はダウンロードし直しになります。
- 起動時に、どの一覧も表示する前に呼びます。呼ぶ前に作られた一覧は、前のパイプラインで先読みを続けます。
- アプリが Nuke の共有のパイプラインにディスクキャッシュを設定済みなら、この呼び出しは何もしません。
- この呼び出しは、共有のパイプラインを、今の構成を引き継いだものに置き換えますが、delegate は既定に戻ります。要求を Nuke の `ImagePipeline.Delegate` で加工しているアプリ (認証のヘッダーを足すなど) は、これを呼ばないでください。代わりに、`dataCache` とその delegate を設定した `ImagePipeline` を、自分で `ImagePipeline.shared` に置きます。そのコードは Nuke の型を使うので、そうしたアプリは、自分の依存に Nuke (メジャー 13 系) を書き、Nuke の文書に従って組みます。この Skill は、そこを扱いません。`KsImage` 自身には、要求のヘッダーを渡す引数はありません。
- この手順は iOS にしかありません。Android では、ローダーのディスクキャッシュが既定で有効です。

## キャッシュした画像を消す

`KsImageCache` は共有のキャッシュを操作するので、ほかの画面に出ている画像にも影響します。呼び出しから戻った時点で、削除は終わっています。

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

| 呼び出し | 消えるもの | 画面に出ている `KsImage` の動き |
|---|---|---|
| `KsImageCache.clear(.memory)` | メモリの上のデコード済みの画像。`.memory` と `.all` は `KsImageCacheScope` の値です | 画像を表示し続けます。次に表示されるときに、ディスクのデータからデコードし直します (ディスクキャッシュを有効にしていなければ、ダウンロードし直します) |
| `KsImageCache.clear(.all)` | メモリとディスク | 読み込み中の表示に戻り、読み込み直します |
| `KsImageCache.remove(source)` | その 1 つのソースについてキャッシュしたものすべて (どの大きさのものも。メモリもディスクも) | そのソースの画像だけが読み込み中に戻り、ほかは残ります |

約束ごと:

- `KsImageCache` は、メインアクターに隔離されています。
- `remove` は、表示と同じやり方で画像を見分けます。キーを付けて保存した画像は、同じキーを付けたソースで消えます (URL は違っていても構いません)。URL だけのソースでは消えません。キーなしで保存した画像は、キーを足したソースでは消えません。
- `remove` は、`.asset` のソースには何もしません。`.file` のソースは、リモートのソースと同じように扱います。キャッシュしたものを消し、ファイル自体には触りません。
- 「ディスクだけ」を消す範囲はありません。

## Nuke 自身の View を KsImage と並べて使う

キャッシュは Nuke の共有のパイプラインなので、Nuke 自身の画像の View (NukeUI の `LazyImage`) で同じ URL を表示すると、同じキャッシュが使われ、先読みも効きます。ただし、限界が 3 つあります。

- キーを付けた画像は、素の URL を渡した `LazyImage` とは共有されません。別々の 2 つのキャッシュの項目になるだけで、壊れはしません。
- キーの無いソースを `KsImageCache.remove` で消すと、そのソースは、同じ URL を表示する `LazyImage` と共有されなくなります。`LazyImage` の側には、キャッシュから追い出されるまで、消す前の画像が出続けることがあります。同じ URL に `KsImage` と `LazyImage` を混ぜて使うアプリでは、`remove` の代わりに `KsImageCache.clear` を使うか、消した後に、`KsImage` と `LazyImage` の両方が新しい画像を表示することを確かめてください。
- `LazyImage` は、`width:` を宣言した先読みがメモリに載せた縮小済みの画像を使いません。使うのは `KsImage` だけです。ダウンロードが省かれることは変わりません。

SwiftUI の `AsyncImage` は、このキャッシュとは関係がありません。
