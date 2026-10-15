# 並べ替え

長押しとドラッグで項目を並べ替えられるようにするレシピです。例は `import` の行を省いています。どの例にも、使っている Compose と Material 3 の名前と、`jp.kamusoft.kscollectionview` にあるライブラリの名前の import が要ります。出てくる場所では、`kotlinx.coroutines` の名前と `java.io.IOException` の import も要ります。このページの例は、最初の節で宣言した型 (`TaskSection`・`TaskItem`・`TaskRow`・`TaskListModel`) を共有します。

役割の分け方: 長押しに気付き、項目を持ち上げ、端でスクロールし、どこに置かれたかを求めるのは、ライブラリです。ライブラリが配列を書き換えることはありません。項目が置かれたときに、何がどこへ動いたかを 1 回だけモデルに知らせます。モデルは自分の配列を並べ替えて、渡し直します。

## 並べ替えを有効にする

`reorder` に `KsReorder` を渡します。`enabled` は並べ替えのスイッチで、利用する側が持つ `Boolean` です。`onMove` は項目が置かれたときに呼ばれ、その移動を受け入れるかどうかを返します。

```kotlin
enum class TaskSection { Today, Later, Archived }

data class TaskItem(
    val id: Int,
    val title: String,
    val section: TaskSection,
    val isLocked: Boolean = false,
)

@Composable
fun TaskRow(task: TaskItem, modifier: Modifier = Modifier) {
    Text(
        text = task.title,
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .padding(16.dp),
    )
}

class TaskListModel(tasks: List<TaskItem>) {
    var tasks by mutableStateOf(tasks)
        private set

    var isReordering by mutableStateOf(false)

    fun move(move: KsReorderMove<TaskItem>): Boolean {
        val next = tasks.toMutableList()
        val from = next.indexOfFirst { it.id == move.item.id }
        if (from < 0) return false
        val moved = next.removeAt(from)
        val section = move.group as? TaskSection
        when (val destination = move.destination) {
            is KsReorderDestination.Before -> {
                val index = next.indexOfFirst { it.id == destination.item.id }
                if (index < 0) return false
                next.add(index, moved.copy(section = section ?: next[index].section))
            }
            KsReorderDestination.End -> if (section != null) {
                val last = next.indexOfLast { it.section == section }
                next.add(if (last < 0) next.size else last + 1, moved.copy(section = section))
            } else {
                next.add(moved.copy(section = next.lastOrNull()?.section ?: moved.section))
            }
        }
        tasks = next
        return true
    }

    fun restore(tasks: List<TaskItem>) {
        this.tasks = tasks
    }
}

@Composable
fun TaskListScreen(model: TaskListModel, modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxSize()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text = "Reorder")
            Switch(checked = model.isReordering, onCheckedChange = { model.isReordering = it })
        }
        KsCollectionView(
            items = model.tasks,
            key = { it.id },
            modifier = Modifier.weight(1f),
            reorder = KsReorder(
                enabled = model.isReordering,
                onMove = { move -> model.move(move) },
            ),
        ) {
            template { task -> TaskRow(task) }
        }
    }
}
```

スイッチが有効の間:

- 項目のどこを長押ししても、その項目が持ち上がり、ドラッグが始まります。つかむためのハンドルはありません。
- 長押しは並べ替えの操作になるので、`onItemLongTap` は呼ばれません。動かせない項目でも呼ばれません。`onItemTap` は呼ばれます。そのため、スイッチを常に有効にする一覧では、`onItemLongTap` を使えません。
- リストでもグリッドでも、同じように働きます。

スイッチが無効の間と、`reorder` を渡していない一覧では、長押ししてもドラッグは始まらず、`onItemLongTap` はいつもどおり働きます。

`TaskRow` のように、テンプレートのいちばん外側の要素に、不透明な背景を付けてください。持ち上げた項目は、影を付けて描かれ、拡大はされません。いちばん外側の要素が透明だと、持ち上げた項目を通して、影と下の行が透けて見えます。

## 移動の内容を配列に当てはめる

`onMove` は `KsReorderMove<Item>` を受け取ります (`Item` は、自分の項目の型のことです)。呼ばれるのは、置くたびに 1 回だけ、指を離したときで、メインスレッドで呼ばれます。ドラッグの途中で項目がほかの項目の上を通っても、呼ばれません。

| `KsReorderMove` のプロパティ | 意味 |
|---|---|
| `item` | 動かした項目。配列の要素そのものです |
| `destination` | `KsReorderDestination<Item>` です。置いた位置の後ろに同じグループの項目があれば `KsReorderDestination.Before` (その `item` が、置いた位置の後ろの項目です)、グループの最後 (グループを宣言していなければ一覧の最後) に置いたときは `KsReorderDestination.End` です |
| `group` | 置いた先のグループの値で、型は `Any?` です。グループを宣言していない一覧では `null` です。`move.group as? YourGroupType` で元の型に戻します |

行き先は、位置の番号ではなく項目で表します。置いてから処理するまでの間に配列が変わっても、行き先の意味が変わらないためです。`KsReorderMove` と `KsReorderDestination.Before` には公開のコンストラクタがあるので、モデルの `move` の関数を、一覧なしで単体テストできます。`KsReorderMove(item, destination, group)` は 3 つの引数をすべて取り (グループの無い一覧では、`group` に `null` を渡します)、`KsReorderDestination.Before(item)` は項目を取ります。`KsReorderDestination.End` は object です。

元の位置に置いたとき、`canDrop` が `false` を返す場所に置いたとき、一覧の枠の外で指を離したとき、ドラッグが取りやめになったときは、`onMove` は呼ばれません。項目は元の位置に戻ります。項目を、ほかの一覧やアプリの外へ持ち出すことはできません。

返す値:

| 返す値 | 一覧の動き |
|---|---|
| `true` (受け入れた) | 項目を置いた位置のままにして、並べ替えた配列が届くのを待ちます。置いた時点で一覧が持っていた配列と等しくない (`equals` でない) 配列が届くと、その並びに従います。その配列と等しい配列が届いても、何も変わりません。時間がたっても、ひとりでに元へは戻しません |
| `false` (受け入れない) | 項目を元の位置に戻します |

約束ごと:

- `true` を返したら、配列を並べ替えて一覧に渡します。`onMove` の中でも、後からでも構いません。並べ替えずに受け入れると、次に違う配列が届くまで、一覧と配列がずれたままになります。
- 処理する時点で行き先の項目が配列から消えていたら、`move` の 2 つの `return false` の行のように、`false` を返します。
- `onMove` は同期で値を返し、ライブラリは保存を待ちません。配列はすぐに並べ替え、保存はその後に行います。保存に失敗したら、前の並びの配列を渡し直します。それは、普通の差し替えとして表示されます。サーバーにしか決められない可否も、このように、保存の失敗として扱います。

```kotlin
fun TaskListModel.moveAndSave(
    move: KsReorderMove<TaskItem>,
    scope: CoroutineScope,
    save: suspend (List<TaskItem>) -> Unit,
): Boolean {
    val original = tasks
    if (!this.move(move)) return false
    val reordered = tasks
    scope.launch {
        try {
            save(reordered)
        } catch (failure: IOException) {
            restore(original)
        }
    }
    return true
}
```

この短い例は、配列をこの移動の前の姿に丸ごと戻します。そのため、保存が動いている間に変わったこと (2 回目の移動や、編集) も、一緒に取り消されます。移動が重なりうるときは、控えた配列に戻すのではなく、失敗した移動だけを取り消すか、並びをサーバーから読み込み直してください。[paging.md](paging.md) と同じく、`IOException` は自分のクライアントの失敗の代わりです。クライアントが保存の失敗に使う例外の型を、すべて捕まえてください。

移動の内容を配列に当てはめる補助の関数は、ありません。グループの値の書き換え方が、利用する側のモデルで決まるためです。上の `move` を写して、自分のモデルに合わせて使ってください。グループのある一覧にも、無い一覧にも使えます。

## グループをまたいで動かす

`groups` でグループを宣言した一覧 ([layout.md](layout.md) を参照) では、項目を別のグループに置けます。ライブラリは、行き先のグループの値を `move.group` で知らせるだけで、項目は書き換えません。受け入れるときは、`move` が `moved.copy(section = section)` としているように、動かした項目にそのグループの値を書き込んでから、配列を渡します。

```kotlin
@Composable
fun GroupedTaskListScreen(model: TaskListModel, modifier: Modifier = Modifier) {
    KsCollectionView(
        items = model.tasks,
        key = { it.id },
        modifier = modifier.fillMaxSize(),
        layout = KsLayout.List(groupSpacing = 16.dp),
        groups = KsGroups(by = { it.section }) { section, tasksInSection ->
            Text(
                text = "${section.name} (${tasksInSection.size})",
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(8.dp),
            )
        },
        reorder = KsReorder(
            enabled = model.isReordering,
            onMove = { move -> model.move(move) },
            canMove = { task -> !task.isLocked },
            canDrop = { move -> move.group != TaskSection.Archived },
            accessibilityActions = KsReorderAccessibilityActions(previous = "Move up", next = "Move down"),
        ),
    ) {
        template { task -> TaskRow(task) }
    }
}
```

約束ごと:

- 項目のグループの値を変えずに、別のグループへの移動を受け入れると、同じグループの値が配列の離れた 2 か所に現れます。これは不正入力です ([basics.md](basics.md) を参照)。
- 項目が 1 件も無いグループは表示されないので、そこには何も置けません。空になりうるグループへ項目を移せるようにしたいときは、別の手段 (メニューなど) を用意します。
- グループの最後の 1 件をドラッグしている間、そのグループの見出しは残ります。移動を受け入れた時点で、空になったグループは見出しごと消えます。その後、保存の失敗で前の配列が戻ってくれば、グループも戻ります。
- グループの宣言を付け外しできる画面では、外している間に動かした項目のグループの値も書き換えます。`move` の `?:` の後ろの値のように、新しい隣の項目のグループの値に合わせます。そうしないと、グループを戻したときに、配列が不正になります。

## 動かせる項目と置ける場所を限る

| 引数 | 呼ばれる時機 | `false` を返すと |
|---|---|---|
| `canMove: ((Item) -> Boolean)?` | 項目ごとに、持ち上げる前 | その項目は持ち上がりません |
| `canDrop: ((KsReorderMove<Item>) -> Boolean)?` | ドラッグ中に、行き先の候補ごとに (何度も)。それと、置く直前 | その場所には項目が入りません。そこで指を離すと項目は元に戻り、`onMove` は呼ばれません |

- `canDrop` は、`onMove` と同じ形の値を受け取ります。項目を自分のグループの中に留めるには、`move.group` と `move.item` のグループの値を比べます: `canDrop = { move -> move.group == move.item.section }`。あるグループだけ、ほかのグループからの項目を受け入れず、そのグループの中の移動は許すには、2 つの比べ方を組み合わせます: `canDrop = { move -> move.group != TaskSection.Archived || move.item.section == TaskSection.Archived }`。
- 元の位置は判定されません。項目は、いつでも元に戻せます。
- どちらも渡さなければ、すべての項目を、すべての位置へ動かせます。
- `canDrop` は、軽い同期の判定にします。指が動く間に何度も呼ばれるので、重い処理をするとドラッグが遅れます。この中でサーバーに問い合わせないでください。問い合わせが要る可否は、置いた後に、保存の失敗として決めます。
- `canMove` と `canDrop` は、メインスレッドで呼ばれます。
- コンストラクタは `KsReorder(enabled, onMove, canMove = null, canDrop = null, accessibilityActions = null)` です。`KsReorder` は、渡した値を、引数と同じ名前の読み取り専用のプロパティとして持ちます。

## TalkBack に移動の操作を出す

上のグループの例のように、`accessibilityActions` に `KsReorderAccessibilityActions(previous, next)` を渡します。スイッチが有効の間、動かせる項目のそれぞれに、渡した 2 つの文字列を名前にした 2 つのアクセシビリティのカスタムの操作が出ます。1 つ前へ動かす操作と、1 つ後ろへ動かす操作です。

- 文字列を渡さなければ操作は出ず、TalkBack を使う人は並べ替えられません。ライブラリは文言を持ちません。`previous` と `next` は `String` です。`stringResource(...)` などで翻訳を済ませた文字列を渡してください。
- グループの先頭の項目を前へ動かすと、前のグループの末尾へ移ります。グループの最後の項目を後ろへ動かすと、次のグループの先頭へ移ります。
- 行き先の無い操作 (一覧の先頭の項目の「前へ」、最後の項目の「後ろへ」) と、行き先について `canDrop` が `false` を返す操作は、出ません。
- 操作は、置いたときと同じく `onMove` を 1 回呼びます。受け入れの扱いも同じです。

## ソートしている一覧を並べ替える

ライブラリは、ソートを知りません。移動を受け入れた後も、モデルがソートした配列を渡し続けると、置いた並びは残りません。置く前と等しい配列が届いている間は、項目は置いた位置のまま、配列とずれた状態になります。次に違う配列が届くと、項目はまたソートの位置に表示されます。次の 2 つの作りのどちらかを選びます。

- ソートしている間は、並べ替えのスイッチを無効にする: `enabled = model.isReordering && !model.isSorted`。ここの `isSorted` は、自分のモデルが持つフラグのことです。このページのモデルは、持っていません。
- `onMove` で手動の並びに切り替える: 今表示している配列を取り、それに移動を当てはめ、その結果を手動の並びとして持って、ソートをやめます。

```kotlin
class SortableTaskListModel(tasks: List<TaskItem>) {
    var manualOrder by mutableStateOf(tasks)
        private set

    var sortsByTitle by mutableStateOf(true)
        private set

    val displayedTasks: List<TaskItem>
        get() = if (sortsByTitle) manualOrder.sortedBy { it.title } else manualOrder

    fun move(move: KsReorderMove<TaskItem>): Boolean {
        val next = displayedTasks.toMutableList()
        val from = next.indexOfFirst { it.id == move.item.id }
        if (from < 0) return false
        val moved = next.removeAt(from)
        when (val destination = move.destination) {
            is KsReorderDestination.Before -> {
                val index = next.indexOfFirst { it.id == destination.item.id }
                if (index < 0) return false
                next.add(index, moved)
            }
            KsReorderDestination.End -> next.add(moved)
        }
        manualOrder = next
        sortsByTitle = false
        return true
    }
}
```

`SortableTaskListModel` が見せているのは、手動の並びへの切り替えだけです。ソートの並びへ戻す手段は持っていません (要るなら、`sortsByTitle` を `true` にする関数を足します)。また、この `move` は `move.group` を見ないので、グループの無い一覧でだけ使ってください。

## ドラッグ中に保留されるものを知る

項目をドラッグしている間は、表示の並びと配列が違っています。そのためライブラリは、ドラッグが終わるまで (項目を置いて表示が落ち着くか、項目が元の位置に戻るまで)、外から届くものを保留します。

| ドラッグ中に届くもの | 動き |
|---|---|
| 新しい配列 | ドラッグの間は表示しません。最新の 1 つを持っておきます。移動を受け入れたときは、持っていた配列は表示されません。上の決まりの「置いた時点で一覧が持っていた配列」の役をするだけです。つまり一覧は、持っていた配列と等しくない配列が届くまで、置いた並びを保ちます。受け入れなかったときは、項目を先に元へ戻してから、持っていた配列を表示します |
| 次のページを頼む条件 ([paging.md](paging.md) を参照) | 判定しません。ドラッグが終わったときに判定し直します。そのため、末尾へ向けてドラッグしている間、一覧は伸びません |
| `KsScrollController` の命令 | 溜めておき、ドラッグが終わった後に、順に実行します |

ドラッグ中に次のどれかが起きると、ドラッグは取りやめになります。項目は元の位置に戻り、`onMove` は呼ばれません: 並べ替えのスイッチを無効にした、layout の値が変わった、グループの宣言が変わった (付けた・外した・グループの値が変わった・見出しや固定を変えた)、システムがタッチを中断した。ドラッグを続けさせたい間は、これらを変えないでください。

一覧の上端や下端の近くまでドラッグすると、一覧はその向きにスクロールします。反応するのは端から 64 dp の範囲 (一覧の高さが 256 dp に満たないときは、高さの 4 分の 1) で、指が端に近いほど速くスクロールします。速さや、反応する範囲の大きさの設定はありません。反応する範囲は、edge-to-edge の一覧でも、一覧自身の枠の端から測ります。

## Android でのドラッグの動きを知る

Android では、ライブラリが自分でドラッグを動かし、すべてを指の位置から決めます。iOS のドラッグは、システムが自分の一覧で使っている並べ替えそのものです。`onMove` で受け取る値・受け入れ・最後の並びは、どちらも同じ決まりですが、動きは違います。表の言葉を 1 つ: 「置き場所」は、持ち上げた項目が置かれる場所を示すために、ほかの項目の間に空く場所です (iOS の Skill は、これを「隙間」と呼びます)。

| 場面 | Android |
|---|---|
| 置き場所が動く時機 | リストでは、持ち上げた項目がほかの項目に半分を越えて重なったときです。グリッドでは、指がほかの項目の上に入ったときに、置き場所がその項目の位置へ移り、間の項目が 1 つずつずれます。(iOS では、指を止めてから置き場所が動きます) |
| グループの境目の近くに置く | グループの見出し (見出しが無ければ、グループとグループの間) より上は前のグループの末尾、下は次のグループの先頭です。どちらにも直接置けます。(iOS では、境目そのものには置き場所ができず、前のグループの末尾に置くには、最後の項目の上で 2 回止めます) |
| 受け入れなかった移動 | 項目は置かれず、離した位置からまっすぐ元へ戻ります。(iOS では、いったん置いた位置に収まり、少し止まってから戻ります) |
| 取りやめになったドラッグ | 項目はその場で元へ戻り、変えた設定もその場で反映されます。(iOS では、ドラッグは指を離すまで続きます) |
| 届いた配列を保留し始める時点 | 長押しで項目を持ち上げた時点からです |
| 一覧の枠の外へドラッグする | 持ち上げた項目の大きさは変わりません。指が左右の外にある間は、置き場所は動きません。上下の外では、自動のスクロールが続きます。外で指を離すと、項目は元へ戻ります |
| 持ち上げた項目の見た目 | 影だけで、拡大はしません。テンプレートのいちばん外側の要素が透明だと下の行が透けるので、その要素に不透明な背景を塗ります |

置き場所の動きが 2 つのプラットフォームで同じだと期待しないでください。また、複数の項目をまとめて動かす・グループを見出しごと動かす・一覧の間で動かす、を前提にした作りにしないでください。どれも提供していません。
