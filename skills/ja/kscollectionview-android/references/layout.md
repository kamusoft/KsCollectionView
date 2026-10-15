# 並べ方と見た目

リストかグリッドかの選び方、間隔、区切り線、ヘッダーとフッター、グループと固定見出し、edge-to-edge への広げ方のレシピです。例は `import` の行を省いています。どの例にも、使っている Compose と Material 3 の名前と、`jp.kamusoft.kscollectionview` にあるライブラリの名前の import が要ります。このページの後ろの例は、最初の例で宣言した型 (`Photo`・`PhotoCell`) をそのまま使います。

## リストかグリッドかを選ぶ

表示の形は、`layout` に渡す `KsLayout` という 1 つの値で決めます。どちらの形も同じ 1 つの Composable なので、一覧を表示したまま切り替えられます。

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

| layout | 意味 |
|---|---|
| `KsLayout.List` | 間隔の無い 1 列。`layout` を省いたときの既定です |
| `KsLayout.List(rowSpacing, groupSpacing, headerItemSpacing)` | 間隔を指定した 1 列 |
| `KsLayout.Grid(columns, rowSpacing, columnSpacing, groupSpacing, headerItemSpacing)` | 複数の列。`columns` は `KsColumns` です |

| 列数 (`KsColumns`) | 意味 |
|---|---|
| `KsColumns.Fixed(3)` | いつもその列数 |
| `KsColumns.Fixed(portrait = 2, landscape = 4)` | 一覧が縦長の間は 1 つ目、そうでなければ 2 つ目の列数 |
| `KsColumns.Adaptive(minItemWidth = 120.dp)` | どの項目も指定した幅より狭くならない範囲で、入るだけの列数。余った幅は、項目に等しく配ります |

約束ごと:

- 間隔はどれも `Dp` で、既定は `0.dp` です。負の値は渡せません。列数と `minItemWidth` は、0 より大きい値にします。[basics.md](basics.md) の「不正な入力を渡したとき」を参照してください。
- 縦長か横長かは、端末の向きではなく、`KsCollectionView` 自身の大きさで決まります。分割画面・タブレット・折りたたみの端末では、端末が縦向きでも、横長に置かれた一覧は横長の側の列数を使います。
- 1 列が使える幅は、一覧の幅から、左右の `contentPadding` と、`columnSpacing` × (列数 − 1) を引いて、列数で割った値です。
- `KsLayout` の値は、値として比べられます。渡した値は、読み取り専用のプロパティとして持ちます。`KsLayout.List` は `rowSpacing`・`groupSpacing`・`headerItemSpacing` を、`KsLayout.Grid` はその 3 つと `columns`・`columnSpacing` を持ちます。`KsLayout` 自体はプロパティを持たないので、どちらの値かを見分けてから読みます。
- 括弧を付けない `KsLayout.List` は、用意済みの値 (間隔の無いリスト) です。括弧を付けた `KsLayout.List(...)` は、渡した間隔のリストを作ります。`KsLayout.List()` は、用意済みの値と等しくなります。リストかグリッドかを見分けるには、型を調べます (`layout is KsLayout.List`・`layout is KsLayout.Grid`)。

一覧を表示したまま layout を切り替えても、データとスクロールの位置は保たれます。

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

## 間隔と内側の余白を決める

`contentPadding` は、一覧の内側で、コンテンツ全体の周りに入る `PaddingValues` です。コンテンツと一緒にスクロールします。

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

リストは、既定で区切り線を描きます。グリッドは描きません。

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

| 項目 | 動き |
|---|---|
| 位置 | 最初の行の上・行と行の間・最後の行の下。グループがあるときは、グループごとに引きます |
| 大きさ | セルの幅いっぱい (インセットなし) で、太さは 1 dp |
| 色 | 既定は、ライブラリが持つ固定の色です。ライトでは `#D9D9DE`、ダークでは `#38383A` です。`listSeparatorColor` に渡した色は、そのまま使われ、表示モードでは変わりません |
| 描く順 | 行の中身の手前。行が不透明な背景を持っていても、隠れません |

約束ごと:

- ライトかダークかは、`isSystemInDarkTheme()`、つまり画面の構成の夜間モードで決まります。Material の配色は見ません。画面の構成を変えずに、Material の配色の切り替えだけでダークにするアプリは、`listSeparatorColor` を自分で渡してください。
- 区切り線の代わりに、行の中で `HorizontalDivider` を描かないでください。ライブラリの線と二重になります。自分で描くなら、先にライブラリの区切り線を消します。
- `rowSpacing` が 0 より大きいとき、線は行間の真ん中ではなく、各セルの下端に引かれます。
- 見出しの無いグループでは、2 つ目以降のグループの上の線を描きません。グループの境目で 2 本の線が並ばないようにするためです。

## 全体のヘッダーとフッターを付ける

`header` と `footer` は、コンテンツのいちばん先頭といちばん末尾に、Composable を 1 つずつ置きます。

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

- コンテンツと一緒にスクロールし、固定されません。
- 配列が空でも表示されます。
- グリッドでは、幅いっぱいに表示されます。
- グループの見出し (次の節) とは別のものです。1 つの一覧が両方を持てます。
- コンテンツの幅より狭いヘッダー・フッター・グループの見出しは、行と違って中央には置かれず、始端から始まります。例のヘッダーのように `Modifier.fillMaxWidth()` を付けて、中身の位置は自分で決めます。

## 項目をグループに分けて見出しを付ける

グループは、`groups` に `KsGroups` を渡して宣言します。`by` のラムダは、項目のグループの値を返します。等しい値を持つ項目が続く範囲が、それぞれ 1 つのグループになります。見出しのラムダには、グループの値と、そのグループの項目が渡ります。配列は平らなままです。配列を入れ子にすることも、見出しの要素を配列に混ぜることもしません。

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

利用する側の責任:

- 同じグループの項目は、配列の中で続けて並べます。ライブラリは、続いている範囲をそれぞれ 1 つのグループにします。`groupBy` と違い、離れた場所にある同じ値を集めはしません。同じ値が配列の後ろでもう一度現れるのは、不正入力です ([basics.md](basics.md) を参照)。例が配列を渡す前にしているように、自分のデータの側で並べ直します。
- グループの順と、グループの中の順は、配列の順です。
- グループの値は、項目の `key` とまったく同じく、`Bundle` に保存できる型にします。文字列・数値・enum・`Serializable` か `Parcelable` の値です。ライブラリは、この値で見出しを見分けます。ほかの型は不正入力です ([basics.md](basics.md) を参照)。グループの値が項目の ID と等しくても、衝突しません。(iOS には、型についてのこの制限がありません。)

ライブラリが保証すること:

- 見出しは、グループの最初の行の前に 1 つだけ置かれます。高さは中身から決まります。グリッドでは幅いっぱいに表示され、グループの最初の項目は新しい行から始まります。グループのフッターはありません。
- 既定では、表示範囲にあるグループの見出しが表示範囲の上端に固定され、次の見出しが届くと押し出されます。`groupSpacing` と `headerItemSpacing` は、見出しと一緒には固定されず、行と一緒に流れます。上の `contentPadding` はコンテンツと一緒に流れていき、固定中の見出しを下げません。見出しは、一覧の上端に固定されます。
- 配列を差し替えると、グループの値が変わった項目は新しいグループへアニメーションで移ります。最後の項目が出ていったグループは見出しごと消え、新しいグループの値は見出しごと現れます。件数や内容だけが変わったグループの見出しは、その場で更新されます。項目が 1 件も無いグループは存在しません。
- `by` のラムダは、一覧を表示したまま切り替えられます。グループは、新しい値で組み直されます。同じ再コンポーズで、新しいグループ分けに合わせて並べた配列を渡します。

`KsGroups<Item, Group>` の型引数は 2 つで、項目の型と、`by` が返す型です。プロパティは 3 つで、順に `by`・`pinnedHeaders` (既定は `true`)・`header` (既定は `null`。型は `@Composable (group: Group, items: List<Item>) -> Unit`) です。`KsCollectionView` の呼び出しの中では、型は推論されます。変数に持つときは、型を書きます: `val groups: KsGroups<Photo, String> = KsGroups(by = { it.album })`。ほかの 2 つの形 (ここから後の例は、`photos` がグループ分けの値の順に並んでいることを前提にしています):

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

- `pinnedHeaders = false` にすると、見出しはコンテンツと一緒に流れます。
- 見出しを渡さない `KsGroups(by = ...)` は、見出しを出さないグループを作ります。`groupSpacing` でコンテンツを区切ることと、リストの区切り線を引く場所を決めること (線はグループごとに引きます。上の区切り線の表を参照) だけに使われます。

一覧を表示したまま、グループ分けを切り替える例です。

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

約束ごと:

- グループ分けを切り替えるときは、上の例のように、`KsCollectionView` の呼び出しを 1 つにしたまま、`by` のラムダを値で選びます。`if` の分岐に `KsCollectionView` の呼び出しを 2 つ書くと、別々の 2 つの一覧になり、切り替えたときにスクロールの位置が失われます。
- 間隔の代わりに、見出しの Composable の上下に余白を付けないでください。空白が、見出しと一緒に固定されます。`groupSpacing` と `headerItemSpacing` を使います。
- 固定する見出しには、不透明な背景を付けます。行は見出しの裏を流れます。
- 見出しのラムダの中で読む状態は、行と同じく、Compose が追跡します ([basics.md](basics.md) を参照)。

## バーの裏まで全画面に広げる

アクティビティが edge-to-edge で描き (`enableEdgeToEdge()`)、一覧をステータスバーやナビゲーションバーの裏まで広げると、行はバーの裏を流れます。スクロールするコンテンツのうち、ライブラリがシステムバーに合わせるものは、1 つだけです。固定中のグループの見出しは、ステータスバーの裏へ行かずに、バーの下端で止まります。コンテンツの先頭と末尾には、何の余白も足しません。そのため、ヘッダー (または最初の行) とフッター (または最後の行) は、バーに被ることがあります。その分の空きは、`contentPadding` か、自分のヘッダーの大きさで、利用する側が作ります。

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

- ライブラリがバーに覆われていると見なす範囲は、システムバーと画面の切り欠きを合わせた範囲から、祖先がすでに消費した分 (`Modifier.windowInsetsPadding`・`Modifier.safeDrawingPadding()`・`Modifier.consumeWindowInsets`) を除いたものです。さらに、一覧が実際に重なっている分だけを使います。`Scaffold` が中身に渡す余白の内側に置いた一覧は、バーに重ならないので、この節の決まりで見え方が変わることはありません。
- 最初の行やヘッダーが、バーの下へ自動でずれることを期待しないでください。
- 左右の insets (横向き) は、特別に扱いません。行を切り欠きや横のナビゲーションバーに重ねたくないときは、同じ insets の左右の値を、自分で `contentPadding` に足します。
- ページングや Pull to Refresh を付けた一覧にライブラリが重ねて出す表示も、システムバーに合わせます ([paging.md](paging.md) を参照)。
- iOS の、安全領域を無視して広げた一覧でも、同じ決まりです。

## セルの大きさと置かれ方を知る

- セルの高さは、中身から決まります。高さの設定は無く、前もって計算するものもありません。
- 中身は、セルの上端に置かれます。項目の幅より狭い中身は、水平の中央に置かれます。幅いっぱいに広がる中身 (`Modifier.fillMaxWidth()` を付けたもの) は、項目の幅を埋めます。
- グリッドの行の高さは、その行でいちばん高いセルの高さになります。ただし、各セルの中身は自分の自然な高さのまま、上端に置かれます。`Modifier.fillMaxHeight()` や、`weight` を付けた `Spacer` で、セルが行の高さまで伸びることを期待しないでください。行の全体をそろえて塗りたいときは、すべてのセルの中身に、自分で同じ高さを与えます (`Modifier.height(...)` や `Modifier.aspectRatio(...)` など)。
- 行の高さが変わるとき (行を展開するときなど) は、その変化がアニメーションします。その下にある行が動くところも、アニメーションします。アニメーションの間、テンプレートのいちばん外側の要素には、行の高さが制約として渡ります。背景は、いちばん外側の要素で塗ってください ([basics.md](basics.md) の「行の中で親の状態を読む」を参照)。

## スクロールインジケータの動きを知る

縦のスクロールインジケータは、利用者がスクロールしている間だけ現れ、止まって約 1 秒後に消えます。Compose の lazy のレイアウトにはインジケータが無いので、ライブラリが描いています。隠す設定も、色を変える設定もありません。位置は一覧の末尾の側の端で、`contentPadding` の影響を受けません。`KsScrollController` の命令によるスクロールでは、現れません。

- 色は `isSystemInDarkTheme()` に従います。ライトでは暗い色、ダークでは明るい色です。画面の構成が夜間モードのまま、アプリが明るい固定の背景を塗ると、インジケータは見えにくくなります。
- 長さと位置は、今画面に出ている行からの見積もりです。行の高さがそろっていない一覧では、スクロールの途中で長さが少し変わることがあります。
