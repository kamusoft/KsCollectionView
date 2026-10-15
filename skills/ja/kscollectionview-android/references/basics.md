# 一覧を出す

`KsCollectionView` で配列を表示する、更新する、タップを受ける、コードからスクロールするためのレシピです。例は `import` の行を省いています。どの例にも、使っている Compose と Material 3 の名前と、`jp.kamusoft.kscollectionview` にあるライブラリの名前の import が要ります。このページの後ろの例は、前の例で宣言した型 (`Contact`・`ContactRow`) をそのまま使います。

この Skill は、渡す `List` を「配列」と呼びます。リストの layout と区別するためです。

## 配列を表示する

配列と、項目の安定 ID を返す `key` のラムダと、項目 1 つを描くテンプレートを渡します。配列は自分のモデルのままでよく、ラッパーの型も、ライブラリの interface の実装も要りません。そのため、自分では変えられないモジュールのモデル (Kotlin Multiplatform の共有コードなど) も、そのまま表示できます。

```kotlin
data class Contact(val id: Int, val name: String)

@Composable
fun ContactRow(contact: Contact, modifier: Modifier = Modifier) {
    Text(
        text = contact.name,
        modifier = modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
    )
}

@Composable
fun ContactListScreen(contacts: List<Contact>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = contacts,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
    ) {
        template { contact -> ContactRow(contact) }
    }
}
```

約束ごと:

- ID は、配列の中で一意で、時間がたっても変わらない値にします。項目を同じものと見なす基準は、値の全体ではなく ID です。ID が同じまま内容が変わった項目は、セルを保ったまま、中身だけが再コンポーズされます。
- ID は、`Bundle` に保存できる型にします。文字列・数値・enum・`Serializable` か `Parcelable` の値です。どちらも実装していないただの `data class` や `value class` は、不正入力です (最後の節を参照)。
- `KsCollectionView` は `layout` と `contentPadding` も受け取ります ([layout.md](layout.md) を参照)。渡さなければ、区切り線つき・余白なしの 1 列のリストになります。
- 一覧は、縦にスクロールします。テンプレートのラムダはどんな Composable を呼んでもよく、行の高さは中身から測られます。
- 項目の無い一覧は、自分では何も表示しません (空の表示があるのは、ページングを付けた一覧だけです。[paging.md](paging.md) を参照)。ページングを付けない一覧では、配列が空の間、一覧の代わりに、または `Box` で一覧の上に重ねて、自分の Composable を出します。
- 自然な幅が項目の幅より小さい行は、水平の中央に置かれます。行を幅いっぱいに広げるには、例のように `Modifier.fillMaxWidth()` を付けます。
- 末尾のブロックのレシーバは `KsCollectionViewScope<Item>` で、使えるのは `template` だけです (`Item` は型引数で、自分の項目の型のことです)。このスコープには、`@DslMarker` のアノテーション `@KsCollectionDsl` が付いています。どちらの名前も、自分で書くことはありません。
- ラムダと、`KsGroups(...)`・`KsPaging(...)`・`KsReorder(...)` の値は、例のように、再コンポーズのたびにその場で作って構いません。`remember` は要りません。同じことをする新しいインスタンスは、変更とは見なされません。

`KsCollectionView` の引数は、次の順に並んでいます。必須なのは `items`・`key`・末尾のブロックだけです。例は、ほかの引数を名前付きで渡しています。

| 引数 | 型 | 既定 |
|---|---|---|
| `items` | `List<Item>` | 必須 |
| `key` | `(Item) -> Any` | 必須 |
| `modifier` | `Modifier` | `Modifier` |
| `template` | `((Item) -> Any)?` | `null` |
| `layout` | `KsLayout` | `KsLayout.List` |
| `contentPadding` | `PaddingValues` | `PaddingValues(0.dp)` |
| `header` | `(@Composable () -> Unit)?` | `null` |
| `footer` | `(@Composable () -> Unit)?` | `null` |
| `groups` | `KsGroups<Item, *>?` | `null` |
| `onItemTap` | `((Item) -> Unit)?` | `null` |
| `onItemLongTap` | `((Item) -> Unit)?` | `null` |
| `touchFeedbackColor` | `Color?` | `null` |
| `listSeparators` | `Boolean` | `true` |
| `listSeparatorColor` | `Color?` | `null` |
| `scrollController` | `KsScrollController?` | `null` |
| `prefetchResources` | `((Item) -> List<KsResource>)?` | `null` |
| `prefetchDestination` | `KsPrefetchDestination` | `KsPrefetchDestination.Disk` |
| `paging` | `KsPaging?` | `null` |
| `onRefresh` | `(suspend () -> Unit)?` | `null` |
| `reorder` | `KsReorder<Item>?` | `null` |
| `loadingIndicatorColor` | `Color?` | `null` |
| `content` (末尾のブロック) | `KsCollectionViewScope<Item>.() -> Unit` | 必須 |

## 項目の種類でテンプレートを切り替える

種類の違う項目を別々の Composable で描くには、項目のテンプレートのキーを返す `template` のラムダを渡し、ブロックの中で、テンプレートのキーごとに `template(key) { ... }` を 1 つずつ宣言します。

```kotlin
enum class FeedKind { Message, Notice }

data class FeedEntry(val id: Int, val kind: FeedKind, val text: String)

@Composable
fun MixedFeedScreen(entries: List<FeedEntry>, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = entries,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        template = { it.kind },
    ) {
        template(FeedKind.Message) { entry ->
            Text(text = entry.text, modifier = Modifier.fillMaxWidth().padding(16.dp))
        }
        template(FeedKind.Notice) { entry ->
            Row(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(text = "!", color = MaterialTheme.colorScheme.error)
                Text(text = entry.text)
            }
        }
    }
}
```

約束ごと:

- `template` のラムダが返しうるすべての値に、テンプレートを宣言します。テンプレートの無いテンプレートのキーを持つ項目は、不正入力です (最後の節を参照)。
- テンプレートのキーは、`equals` と `hashCode` を持つ値なら何でも構いません。ふつうは enum を使います。
- どの `template` のラムダも、テンプレートのキーが何であっても、項目を一覧の項目の型 (ここでは `FeedEntry`) で受け取ります。項目の型が sealed のときは、ラムダの中で下位の型にキャストします。
- 最初の例のように、テンプレートのキーを付けない `template { ... }` は、テンプレートが 1 つだけの一覧のための形です。引数の `template` を渡さないときにだけ使います。
- 画面の外へ出た行のコンポジションは、ほかの項目に使い回されます。使い回す先は、同じテンプレートのキーを持つ項目だけです。違うテンプレートの間で入れ替わることはありません。
- ID が同じまま項目のテンプレートのキーが変わると、そのセルは中身の再コンポーズではなく、セルごと置き換えられます。
- ブロックは、再コンポーズのたびに実行されます。毎回、同じテンプレートの集合を宣言してください。状態によって `template` の呼び出しを足したり外したりしません。
- iOS では、同じ登録を `KsTemplate` という名前の型の値で書きます。Android では `template` という関数なので、その名前の型はありません。

## 配列を差し替えて一覧を更新する

一覧には、挿入・削除・移動のメソッドがありません。新しい配列を作って渡します。ライブラリが ID で差分を求め、挿入・削除・移動をアニメーションで見せます。並べ替えと絞り込みも、同じように自分のデータの側で行います。

```kotlin
class ContactListModel {
    var contacts by mutableStateOf(listOf<Contact>())
        private set

    fun add(contact: Contact) {
        contacts = listOf(contact) + contacts
    }

    fun remove(id: Int) {
        contacts = contacts.filterNot { it.id == id }
    }

    fun rename(id: Int, name: String) {
        contacts = contacts.map { if (it.id == id) it.copy(name = name) else it }
    }

    fun sortByName() {
        contacts = contacts.sortedBy { it.name }
    }
}

@Composable
fun EditableContactListScreen(model: ContactListModel, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = model.contacts,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
    ) {
        template { contact -> ContactRow(contact) }
    }
}
```

ライブラリが保証すること:

- ID が同じで内容が違う項目 (上の `rename`) は、セルを保ちます。再コンポーズされるのは、そのセルの中身だけです。
- コンテンツの先頭を表示しているときに配列の先頭へ項目を入れると、その項目は表示範囲の中にアニメーションで現れ、一覧は先頭に留まります。末尾でも同じです。ページングを付けた一覧では、末尾の側の決まりが置き換わります ([paging.md](paging.md) を参照)。
- 組み立てられるセルは、表示範囲とその近くの分だけです。メモリは項目の件数に比例して増えません。

約束ごと:

- 変更のたびに、新しい `List` を渡します。1 つの `MutableList` を持ち続け、その場で書き換えて、同じインスタンスをもう一度渡すことはしないでください。ライブラリが配列を調べるのは、違う配列を受け取ったときだけなので、その変更は画面に届きません。「違う」とは、`equals` で等しくないことです。同じインスタンスは、いつも自分自身と等しくなります。中身の等しい新しい `List` を渡しても、何も変わりません。
- 一覧の表示中に、`key` や `template` のラムダを、別のことを計算するラムダに差し替えないでください。宣言したテンプレートの集合も変えないでください。これらは、状態で選ぶ値にせず、呼び出しに固定して書きます。(項目自身のデータが変わって、`template` が別のテンプレートのキーを返すようになるのは構いません。前の節を参照してください。) `KsGroups` の `by` のラムダだけは例外で、切り替えられます ([layout.md](layout.md) を参照)。
- 一覧を途中までスクロールした状態で、表示範囲より上に項目を足したり消したりしても、画面に出ているものは動きません。一覧が、表示範囲の先頭の項目を、ID を手掛かりにその場に保ちます。(iOS では、一覧が保つのはスクロールの量なので、画面に出ているものがずれます。)
- スクロールの位置は、Compose の状態の保存の仕組みで保存されます。その状態と一緒に一覧がコンポーズし直されたとき (回転の後や、Navigation Compose のバックスタックの画面に戻ったとき) に、位置が戻ります。その時点で、配列に項目がそろっていることが条件です。ID を `Bundle` に入る型にするのは、このためです。
- 項目でない要素 (セクションの題名など) を配列に混ぜないでください。グループの見出しは `groups` で宣言します ([layout.md](layout.md) を参照)。

## 行の中で親の状態を読む

テンプレートは、配列の外にある状態 (展開中の ID の集合や、選択中の ID など) を読めます。そのまま読んでください。Compose がその読み取りを追跡し、状態が変わると、表示中の行が再コンポーズされます。

```kotlin
@Composable
fun ExpandableContactListScreen(contacts: List<Contact>, modifier: Modifier = Modifier) {
    var expandedIds by remember { mutableStateOf(emptySet<Int>()) }
    KsCollectionView(
        items = contacts,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        onItemTap = { contact ->
            expandedIds = if (contact.id in expandedIds) expandedIds - contact.id else expandedIds + contact.id
        },
    ) {
        template { contact ->
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(16.dp),
            ) {
                Text(text = contact.name)
                if (contact.id in expandedIds) {
                    Text(text = "ID ${contact.id}", style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}
```

約束ごと:

- Android では、このために宣言するものはありません。(iOS では、こうした状態を専用の modifier で一覧に渡す必要があります。その modifier に当たるものは、Android にはありません。)
- 例のように、状態によって行の高さが変わるときは、高さの変化がアニメーションします。そのアニメーションの間、テンプレートのいちばん外側の要素には、変化の途中の行の高さが制約として渡ります。例のように、行の背景はいちばん外側の要素で塗ります。いちばん外側の要素が中身を包むだけの `Box` なら、`propagateMinConstraints = true` を付けます。そうしないと、行が畳まれる途中で、隙間が透けて見えます。
- グループの見出しの中で読む状態にも、同じ決まりが当てはまります。

## スクロールしても残したい状態はモデルに持たせる

画面の外へ十分に離れた行は、コンポジションから外れます。その行が `remember` で持っていた状態 (開閉・入力途中の文字) は、捨てられます。その項目が戻ってきたとき、行は初期の状態から始まります。行の中の `LaunchedEffect` は、行がコンポジションに入るたびに動きます。

- スクロールしても残したいもの (開閉・選択・下書きの文字) は、配列に持たせるか、前の節のように親の状態に持たせます。
- 行の中の `remember` は、戻ってよい状態 (押したときのアニメーションなど) には使えます。
- 行が画面に出ている間は、行の中の状態は保たれます。配列が変わって行が再コンポーズされるときも、保たれます。

## タップと長押しを受ける

```kotlin
@Composable
fun TappableContactListScreen(
    contacts: List<Contact>,
    onOpen: (Contact) -> Unit,
    onShowMenu: (Contact) -> Unit,
    modifier: Modifier = Modifier,
) {
    KsCollectionView(
        items = contacts,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        onItemTap = onOpen,
        onItemLongTap = onShowMenu,
        touchFeedbackColor = MaterialTheme.colorScheme.primary,
    ) {
        template { contact -> ContactRow(contact) }
    }
}
```

ライブラリが保証すること:

- コールバックには、配列の要素そのものが渡ります。メインスレッドで呼ばれます。
- `onItemTap` か `onItemLongTap` を渡した一覧は、項目のそれぞれを、押せる (長押しできる) 要素として TalkBack に伝えます。その操作のラベルを渡す引数はありません。
- タッチ中の色 (フィードバック) が出るのは、`onItemTap` か `onItemLongTap` を渡した一覧だけです。`touchFeedbackColor` を渡さなければ、Material の標準の波紋 (ripple) になります。
- 行の中のコントロールが優先されます。行の中の `Button` や `Switch`、そのほか `clickable` なものがタッチを処理したときは、項目のコールバックもフィードバックも働きません。項目のタップは、行の残りの部分へのタッチで働きます。
- タップと長押しは、どちらか一方だけです。長押しになったタッチでは、`onItemTap` は呼ばれません。
- 並べ替えが有効の間は、長押しでドラッグが始まり、`onItemLongTap` は呼ばれません ([reorder.md](reorder.md) を参照)。

約束ごと:

- `touchFeedbackColor` が決めるのは、波紋の色みだけです。濃さは標準の波紋が決めるので、渡した色の不透明度は効きません。不透明な色と半透明の色で、押している間の見え方は同じになります。
- iOS の同じ設定は、渡した色を、不透明度も含めてそのままセルの全面に塗ります。そのため、同じ色の値でも 2 つのプラットフォームで同じ見え方にはなりません。半透明の色を渡すと、近い見え方になります。

## コードからスクロールする

`KsScrollController` を作り、`scrollController` に渡して、命令を送ります。コントローラはプレーンなオブジェクトです。画面が持つときは `rememberKsScrollController()` で作り、`ViewModel` などの状態を持つ側が持つときは、`KsScrollController()` を直接作ります。

```kotlin
@Composable
fun ScrollableContactListScreen(contacts: List<Contact>, modifier: Modifier = Modifier) {
    val controller = rememberKsScrollController()
    Column(modifier = modifier.fillMaxSize()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Button(onClick = { controller.scrollToStart() }) { Text("Top") }
            Button(onClick = { controller.scrollTo(id = 50, position = KsScrollPosition.Center) }) {
                Text("Contact 50")
            }
            Button(onClick = { controller.scrollToEnd(animated = false) }) { Text("Bottom") }
        }
        KsCollectionView(
            items = contacts,
            key = { it.id },
            modifier = Modifier.weight(1f),
            scrollController = controller,
        ) {
            template { contact -> ContactRow(contact) }
        }
    }
}
```

| 命令 | 意味 |
|---|---|
| `scrollTo(id, position, animated)` | その ID の項目へスクロールします。`position` は `KsScrollPosition` で、`Start` (既定) は項目を表示範囲の上端に、`Center` は中央に、`End` は下端に置きます |
| `scrollToStart(animated)` | コンテンツの先頭 (ヘッダーがあれば、その上端) へスクロールします |
| `scrollToEnd(animated)` | コンテンツのいちばん最後までスクロールします。最後の項目の下にあるもの (フッターと、ページングの「次のページの失敗」「終端」の表示) も含みます (iOS の同じ命令は、最後の項目が表示範囲の下端に来たところで止まり、フッターは表示範囲に入りません) |

`animated` の既定は、3 つとも `true` です。

ライブラリが保証すること:

- 命令は、最新の配列が画面に出た後に実行されます。項目を末尾に足して、同じ関数の中で `scrollToEnd()` を呼ぶと、足した後の最後の項目まで届きます。
- 一覧につながっているコントローラに送った命令は、送った順に実行されます。更新や前のアニメーションの途中だからという理由で、失われることはありません。後の命令は前の命令のアニメーションを中断するので、最後の位置は、最後の命令のものになります。
- 何も起こさない命令が 2 種類あり、どちらもクラッシュしません。実行する時点で配列に無い ID への命令と、コントローラが一覧につながっていない間に送った命令です (後のために取っておかれもしません)。
- 位置は `contentPadding` の内側で測ります。`Start` は項目の上端を上の余白の下の端に、`End` は項目の下端を下の余白の上の端に合わせます。(iOS では、項目は一覧自身の端まで行きます。) 届かない位置はスクロールできる範囲に丸められるので、先頭や末尾の近くの項目は端で止まります。
- 命令によるスクロールでも、ほかのスクロールと同じように、ページングの条件が判定されます ([paging.md](paging.md) を参照)。
- スクロールの位置は読み取れません。スクロールのコールバックは無く、内部の `LazyGridState` も公開していません。
- グループの見出しを固定している一覧では、`Start` は項目を、固定中の見出しの裏ではなく、すぐ下に置きます。

約束ごと:

- ID は、`key` がその項目に対して返す値と等しい値を、同じ型で渡します。ID が `Int` の `50` の項目は、`scrollTo(id = "50")` でも `scrollTo(id = 50L)` でも見つかりません。
- コントローラは、メインスレッドから呼んでください。ほかのスレッドからの呼び出しは、不正入力です (次の節を参照)。
- 1 つのコントローラは、1 つの一覧につなぎます。複数につなぐと、最後につないだ一覧だけが命令を受け取ります。
- 命令が、更新する前の配列に対して実行されることを期待しないでください。命令は、いつも更新の後に解決されます。

## 不正な入力を渡したとき

プログラムの誤りに当たる入力に対して、ライブラリは、デバッグビルドでは気付けるように停止し、リリースビルドでは、クラッシュさせずにログに警告を残して、画面を動かし続けます。それぞれの場合に何が表示されるかは、表のとおりです。「デバッグ」と「リリース」は、自分のアプリのことです。アプリがデバッグ可能 (`android:debuggable`。ビルドタイプの `debug` が設定します) なら、デバッグビルドとして扱います。デバッグビルドでの停止は、誤りの内容をメッセージに持つ `IllegalStateException` です。警告は、タグが `KsCollectionView` の警告のレベルで、Logcat に出ます。

| 不正入力 | デバッグビルド | リリースビルド |
|---|---|---|
| テンプレートのキーに対応する `template` が宣言されていない項目 | 例外で停止 | その位置に高さ 1 dp の空のセルを出します。項目の数は配列と一致したままです |
| 配列の中に同じ ID が 2 つある | 例外で停止 | 後ろの要素だけを表示し、前の要素は表示しません。表示は続けます |
| 同じテンプレートのキーに `template` を 2 つ宣言した | 例外で停止 | 後の宣言を採用します |
| `key` が、`Bundle` に保存できない型を返す | 例外で停止 | ライブラリは警告を残して続けますが、項目を最初に表示するときに、Compose 自身が例外を投げることがあります。必ず、保存できる型を返してください |
| 同じグループの値が、配列の離れた 2 か所に現れる ([layout.md](layout.md) を参照) | 例外で停止 | 項目を配列の順のまま、別々のグループとして表示します |
| グループの値が、`Bundle` に保存できない型 ([layout.md](layout.md) を参照) | 例外で停止 | `key` と同じです |
| layout の間隔に負の値を渡した ([layout.md](layout.md) を参照) | 例外で停止 | 0 として扱います |
| 列数が 0 以下 ([layout.md](layout.md) を参照) | 例外で停止 | 1 列として扱います |
| `KsColumns.Adaptive` の `minItemWidth` が 0 以下 ([layout.md](layout.md) を参照) | 例外で停止 | 1 dp として扱います |
| ページングのしきい値が負の数か、有限でない数 ([paging.md](paging.md) を参照) | 例外で停止 | 0 として扱います |
| 先読みの固定の幅が 0・負の数・有限でない数・`Dp.Unspecified` ([images.md](images.md) を参照) | 例外で停止 | 幅を指定しなかったものとして扱います |
| 画像のキーが空文字 ([images.md](images.md) を参照) | 例外で停止 | キーを指定しなかったものとして扱います |
| `KsImageSource.Resource` のリソース ID を、ドローアブルとして読めない ([images.md](images.md) を参照) | 例外で停止 | 失敗の表示を出します |
| `KsScrollController` の命令を、メインスレッド以外のスレッドから送った | 例外で停止 | ログに残します。その後の動きを当てにしないでください |

配列に無い ID へのスクロール命令と、つながっていないコントローラへの命令は、不正入力ではありません。削除と命令が競合して、正しいコードでも起こりうるためです。どちらの構成でも、無視されます。
