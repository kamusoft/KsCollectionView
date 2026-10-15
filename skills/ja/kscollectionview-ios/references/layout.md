# 並べ方と見た目

リストかグリッドかの選び方、間隔、区切り線、ヘッダーとフッター、グループと固定見出し、全画面への広げ方のレシピです。どの例も `import SwiftUI` と `import KsCollectionView` を前提にしています。このページの後ろの例は、最初の例で宣言した型 (`Photo`・`PhotoCell`) をそのまま使います。

## リストかグリッドかを選ぶ

表示の形は、`layout:` に渡す `KsCollectionLayout` という 1 つの値で決めます。どちらの形も同じ 1 つの View なので、一覧を表示したまま切り替えられます。

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

| layout | 意味 |
|---|---|
| `.list` | 1 列。`layout:` を省いたときの既定です |
| `.list(rowSpacing:groupSpacing:headerItemSpacing:)` | 間隔を指定した 1 列 |
| `.grid(columns:rowSpacing:columnSpacing:groupSpacing:headerItemSpacing:)` | 複数の列。`columns` は `KsGridColumns` です |

| 列数 (`KsGridColumns`) | 意味 |
|---|---|
| `.fixed(3)` | いつもその列数 |
| `.fixed(portrait: 2, landscape: 4)` | 一覧が縦長の間は 1 つ目、そうでなければ 2 つ目の列数 |
| `.adaptive(minItemWidth: 120)` | どの項目も指定した幅より狭くならない範囲で、入るだけの列数。余った幅は、項目に等しく配ります |

約束ごと:

- 間隔はどれもポイントの `Double` の値で、既定は 0 です。負の値は渡せません。列数は `Int`、`minItemWidth` は `Double` で、どちらも 0 より大きい値にします。[basics.md](basics.md) の「不正な入力を渡したとき」を参照してください。
- 縦長か横長かは、端末の向きではなく、`KsCollectionView` 自身の大きさで決まります。Split View や iPad では、端末が縦向きでも、横長に置かれた一覧は横長の側の列数を使います。
- 1 列が使える幅は、一覧の幅から、左右の `contentPadding` と、`columnSpacing` × (列数 − 1) を引いて、列数で割った値です。
- `KsCollectionLayout` は `Equatable` で、4 つの間隔を読み取り専用のプロパティ (`rowSpacing`・`columnSpacing`・`groupSpacing`・`headerItemSpacing`) として持ちます。
- 一覧とセルは、自分の背景を持ちません。一覧の後ろにあるものが、そのまま透けて見えます。背景は、行に付けるか、SwiftUI の `.background` で一覧に付けます (ライブラリの modifier の後ろに書きます)。

一覧を表示したまま layout を切り替えても、データと位置は保たれます。切り替える直前に表示範囲の先頭にあった項目は、切り替えた後も表示範囲に残ります。

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

## 間隔と内側の余白を決める

`contentPadding:` は、一覧の内側で、コンテンツ全体の周りに入る `EdgeInsets` です。コンテンツと一緒にスクロールします。

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

| 場所 | 入るもの |
|---|---|
| ヘッダーの上とフッターの下 (無ければ、最初の行の上と最後の行の下) | `contentPadding` の上と下 |
| ヘッダーと、最初のグループの見出し (または最初の行) の間。最後の行とフッターの間 | 何も入りません |
| 同じグループの行と行の間 | `rowSpacing` |
| 列と列の間 | `columnSpacing` |
| グループの最後の行と、次のグループの見出しの間 | `groupSpacing` |
| グループの見出しと、そのグループの最初の行の間 | `headerItemSpacing` |

約束ごと:

- `rowSpacing` は、行と行の間にだけ入ります。ヘッダー・フッター・グループの見出しの前後には入りません。
- スクロールインジケータと、ライブラリが一覧に重ねて出す表示 (Pull to Refresh のインジケータと、[paging.md](paging.md) のページングの表示) の位置は、`contentPadding` では変わりません。
- 一覧を表示したまま `contentPadding` を変えると、その場で反映されます。

## リストの区切り線を出す・消す・色を変える

リストは、既定で区切り線を描きます。グリッドは、`.listSeparators(true)` を付けても描きません。

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

| 項目 | 動き |
|---|---|
| 位置 | 最初の行の上・行と行の間・最後の行の下。グループがあるときは、グループごとに引きます |
| 大きさ | セルの幅いっぱい (インセットなし) で、太さは 1 ポイント |
| 色 | 既定は、ライブラリが持つ固定の色です。ライトの外観では `#D9D9DE`、ダークでは `#38383A` で、一覧が置かれた場所の外観に従います。`.listSeparatorColor(_:)` で指定した色は、そのまま使われ、外観では変わりません |
| 描く順 | 行の中身の手前。行が不透明な背景を持っていても、隠れません |

約束ごと:

- 区切り線の代わりに、行の中で `Divider` を描かないでください。ライブラリの線と二重になります。自分で描くなら、先にライブラリの区切り線を消します。
- `rowSpacing` が 0 より大きいとき、線は行間の真ん中ではなく、各セルの下端に引かれます。
- 見出しの無いグループでは、2 つ目以降のグループの上の線を描きません。グループの境目で 2 本の線が並ばないようにするためです。

## 全体のヘッダーとフッターを付ける

`.header` と `.footer` は、コンテンツのいちばん先頭といちばん末尾に、View を 1 つずつ置きます。

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

- コンテンツと一緒にスクロールし、固定されません。
- 配列が空でも表示されます。
- グリッドでは、幅いっぱいに表示されます。
- グループの見出し (次の節) とは別のものです。1 つの一覧が両方を持てます。
- この中で読む状態については、[basics.md](basics.md) の「行の中で親の状態を読む」を参照してください。

## 項目をグループに分けて見出しを付ける

グループは `.groups(by:pinnedHeaders:header:)` で宣言します。`by` は、項目の `Hashable` な値へのキーパスです。同じ値を持つ項目が続く範囲が、それぞれ 1 つのグループになります。見出しのクロージャには、グループの値と、そのグループの項目が渡ります。配列は平らなままです。配列を入れ子にすることも、見出しの要素を配列に混ぜることもしません。

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

利用する側の責任:

- 同じグループの項目は、配列の中で続けて並べます。ライブラリは、続いている範囲をそれぞれ 1 つのグループにします。`Dictionary(grouping:)` と違い、離れた場所にある同じ値を集めはしません。同じ値が配列の後ろでもう一度現れるのは、不正入力です ([basics.md](basics.md) を参照)。例が配列を渡す前にしているように、自分のデータの側で並べ直します。
- グループの順と、グループの中の順は、配列の順です。

ライブラリが保証すること:

- 見出しは、グループの最初の行の前に 1 つだけ置かれます。高さは中身から決まります。グリッドでは幅いっぱいに表示され、グループの最初の項目は新しい行から始まります。グループのフッターはありません。
- 既定では、表示範囲にあるグループの見出しが表示範囲の上端に固定され、次の見出しが届くと押し出されます。`groupSpacing` と `headerItemSpacing` は、見出しと一緒には固定されず、行と一緒に流れます。上の `contentPadding` はコンテンツと一緒に流れていき、固定中の見出しを下げません。見出しは、一覧の上端に固定されます。
- 配列を差し替えると、グループの値が変わった項目は新しいグループへアニメーションで移ります。最後の項目が出ていったグループは見出しごと消え、新しいグループの値は見出しごと現れます。件数や内容だけが変わったグループの見出しは、その場で更新されます。項目が 1 件も無いグループは存在しません。
- `by` に渡すキーパスは、一覧を表示したまま切り替えられます。グループは、新しい値で組み直されます。同じ更新で、新しいキーに合わせて並べた配列を渡します。

ほかの 2 つの形 (ここから後の例は、`photos` がグループ分けのキーの順に並んでいることを前提にしています):

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

- `pinnedHeaders: false` にすると、見出しはコンテンツと一緒に流れます。
- 見出しのクロージャを渡さない `.groups(by:)` は、見出しを出さないグループを作ります。`groupSpacing` でコンテンツを区切ることと、リストの区切り線を引く場所を決めること (線はグループごとに引きます。上の区切り線の表を参照) だけに使われます。

一覧を表示したまま、グループ分けのキーを切り替える例です。

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

約束ごと:

- キーを切り替えるときは、上の例のように、`KsCollectionView` の式を 1 つにしたまま、キーパスを値で選びます。`body` の中の `if` の分岐に `KsCollectionView` の式を 2 つ書くと、別々の 2 つの一覧になり、切り替えたときにスクロールの位置が失われます。
- 間隔の代わりに、見出しの View に上下の余白を付けないでください。空白が、見出しと一緒に固定されます。`groupSpacing` と `headerItemSpacing` を使います。
- 固定する見出しには、不透明な背景を付けます。行は見出しの裏を流れます。
- 見出しのクロージャの中で読む状態は、行と同じ決まりに従います。`.observedValue(_:)` で渡してください ([basics.md](basics.md) を参照)。
- Android では、これに加えて、グループの値が、Android が画面の状態として保存できる型でなければなりません。iOS にはこの制限が無く、`Hashable` な値なら何でも使えます。

## バーの裏まで全画面に広げる

`.ignoresSafeArea()` で、一覧をステータスバー・ナビゲーションバー・ホームインジケータの裏まで広げると、行はバーの裏を流れます。スクロールするコンテンツのうち、ライブラリが安全領域に合わせるものは、1 つだけです。固定中のグループの見出しは、上のバーの裏へ行かずに、バーの下端で止まります。コンテンツの先頭と末尾には、何の余白も足しません。そのため、ヘッダー (または最初の行) とフッター (または最後の行) は、バーに被ることがあります。その分の空きは、`contentPadding` か、自分のヘッダーの大きさで、利用する側が作ります。

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

- `.ignoresSafeArea()` は SwiftUI の modifier なので、ライブラリの modifier の後ろに書きます。
- 最初の行やヘッダーが、バーの下へ自動でずれることを期待しないでください。
- 左右の安全領域 (横向き) は、特別に扱いません。行は端から端まで、センサーの切り欠きの下にも広がります。そこを空けたいときは、`.ignoresSafeArea(edges: .vertical)` で、縦の方向にだけ広げます。
- 安全領域の内側に普通に置いた一覧では、この節の決まりで見え方が変わることはありません。
- ページングや Pull to Refresh を付けた一覧にライブラリが重ねて出す表示も、安全領域に合わせます ([paging.md](paging.md) を参照)。
- Android の、システムバーの裏まで広げた一覧でも、同じ決まりです。

## セルの大きさと置かれ方を知る

- セルの高さは、中身から決まります。高さの設定は無く、前もって計算するものもありません。
- 中身は、セルの上端に置かれます。項目の幅より狭い中身は、水平の中央に置かれます。幅いっぱいに広がる中身 (`.frame(maxWidth: .infinity)` を付けたものなど) は、項目の幅を埋めます。
- グリッドの行の高さは、その行でいちばん高いセルの高さになります。ただし、各セルの中身は自分の自然な高さのまま、上端に置かれます。`.frame(maxHeight: .infinity)` や `Spacer()` で、セルが行の高さまで伸びることを期待しないでください。行の全体をそろえて塗りたいときは、すべてのセルの中身に、自分で同じ高さを与えます (固定の `.frame(height:)` や `.aspectRatio` など)。
- 行の高さが変わるとき (行を展開するときなど) は、その変化がアニメーションします。その下にある行が動くところも、アニメーションします。

## スクロールインジケータの動きを知る

縦のスクロールインジケータは、スクロールしている間だけ現れ、止まって約 1 秒後に消えます。隠す設定はありません。SwiftUI の `.scrollIndicators(.hidden)` を付けても、一覧の内側には届きません。位置は一覧の末尾の側の端で、`contentPadding` の影響を受けません。`KsScrollController` の命令によるスクロールでは、現れません。
