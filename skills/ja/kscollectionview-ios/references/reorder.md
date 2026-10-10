# 並べ替え

長押しとドラッグで項目を並べ替えられるようにするレシピです。どの例も `import SwiftUI` と `import KsCollectionView` を前提にしています。このページの例は、最初の節で宣言した型 (`TaskSection`・`TaskItem`・`TaskRow`・`TaskListModel`) を共有します。

役割の分け方: 長押しに気付き、項目を持ち上げ、端でスクロールし、どこに置かれたかを求めるのは、ライブラリです。ライブラリが配列を書き換えることはありません。項目が置かれたときに、何がどこへ動いたかを 1 回だけモデルに知らせます。モデルは自分の配列を並べ替えて、渡し直します。

## 並べ替えを有効にする

`.reorder(isEnabled:canMove:canDrop:accessibilityActions:onMove:)` を付けます。`isEnabled` は並べ替えのスイッチで、利用する側が持つ `Bool` です。`onMove` は項目が置かれたときに呼ばれ、その移動を受け入れるかどうかを返します。

```swift
enum TaskSection: String, Hashable {
    case today
    case later
    case archived
}

struct TaskItem: Identifiable, Equatable, Sendable {
    let id: Int
    var title: String
    var section: TaskSection
    var isLocked = false
}

struct TaskRow: View {
    let task: TaskItem

    var body: some View {
        Text(task.title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
    }
}

@MainActor
final class TaskListModel: ObservableObject {
    @Published private(set) var tasks: [TaskItem]
    @Published var isReordering = false

    init(tasks: [TaskItem]) {
        self.tasks = tasks
    }

    func move(_ move: KsReorderMove<TaskItem>) -> Bool {
        var next = tasks
        guard let from = next.firstIndex(where: { $0.id == move.item.id }) else { return false }
        var moved = next.remove(at: from)
        let section = move.group?.base as? TaskSection
        switch move.destination {
        case .before(let target):
            guard let index = next.firstIndex(where: { $0.id == target.id }) else { return false }
            moved.section = section ?? next[index].section
            next.insert(moved, at: index)
        case .end:
            if let section {
                moved.section = section
                let last = next.lastIndex(where: { $0.section == section })
                next.insert(moved, at: last.map { $0 + 1 } ?? next.count)
            } else {
                moved.section = next.last?.section ?? moved.section
                next.append(moved)
            }
        }
        tasks = next
        return true
    }

    func restore(_ tasks: [TaskItem]) {
        self.tasks = tasks
    }
}

struct TaskListScreen: View {
    @StateObject private var model: TaskListModel

    init(tasks: [TaskItem]) {
        _model = StateObject(wrappedValue: TaskListModel(tasks: tasks))
    }

    var body: some View {
        VStack(spacing: 0) {
            Toggle("Reorder", isOn: $model.isReordering)
                .padding()
            KsCollectionView(model.tasks) { task in
                TaskRow(task: task)
            }
            .reorder(isEnabled: model.isReordering) { move in
                model.move(move)
            }
        }
    }
}
```

スイッチが有効の間:

- 項目のどこを長押ししても、その項目が持ち上がり、ドラッグが始まります。つかむためのハンドルはありません。
- 長押しは並べ替えの操作になるので、`.onItemLongTap` は呼ばれません。動かせない項目でも呼ばれません。`.onItemTap` は呼ばれます。そのため、スイッチを常に有効にする一覧では、`.onItemLongTap` を使えません。
- リストでもグリッドでも、同じように働きます。

スイッチが無効の間と、`.reorder` を付けていない一覧では、長押ししてもドラッグは始まらず、`.onItemLongTap` はいつもどおり働きます。

## 移動の内容を配列に当てはめる

`onMove` は `KsReorderMove<Item>` を受け取ります (`Item` は、自分の項目の型のことです)。呼ばれるのは、置くたびに 1 回だけ、指を離したときです。`@MainActor` と宣言されていて、メインアクターで動きます。ドラッグの途中で項目がほかの項目の上を通っても、呼ばれません。

| `KsReorderMove` のプロパティ | 意味 |
|---|---|
| `item` | 動かした項目。配列の要素そのものです |
| `destination` | `KsReorderDestination<Item>` です。置いた位置の後ろに同じグループの項目があれば `.before(other)`、グループの最後 (グループを宣言していなければ一覧の最後) に置いたときは `.end` です |
| `group` | 置いた先のグループの値で、型は `AnyHashable?` です。グループを宣言していない一覧では `nil` です。`move.group?.base as? YourGroupType` で元の型に戻します |

行き先は、位置の番号ではなく項目で表します。置いてから処理するまでの間に配列が変わっても、行き先の意味が変わらないためです。`KsReorderMove` には公開のイニシャライザ `KsReorderMove(item:destination:group:)` があるので、モデルの `move` の関数を、一覧なしで単体テストできます。

元の位置に置いたとき、`canDrop` が `false` を返す場所に置いたとき、一覧の枠の外で指を離したとき、ドラッグが取りやめになったときは、`onMove` は呼ばれません。項目は元の位置に戻ります。項目を、ほかの一覧やアプリの外へ持ち出すことはできません。

返す値:

| 返す値 | 一覧の動き |
|---|---|
| `true` (受け入れた) | 項目を置いた位置のままにして、並べ替えた配列が届くのを待ちます。置いた時点で一覧が持っていた配列と等しくない (`==` でない) 配列が届くと、その並びに従います。その配列と等しい配列が届いても、何も変わりません。時間がたっても、ひとりでに元へは戻しません |
| `false` (受け入れない) | 項目を元の位置に戻します |

約束ごと:

- `true` を返したら、配列を並べ替えて一覧に渡します。`onMove` の中でも、後からでも構いません。並べ替えずに受け入れると、次に違う配列が届くまで、一覧と配列がずれたままになります。
- 処理する時点で行き先の項目が配列から消えていたら、`move(_:)` の 2 つの `guard` のように、`false` を返します。
- `onMove` は同期で値を返し、ライブラリは保存を待ちません。配列はすぐに並べ替え、保存はその後に行います。保存に失敗したら、前の並びの配列を渡し直します。それは、普通の差し替えとして表示されます。サーバーにしか決められない可否も、このように、保存の失敗として扱います。

```swift
extension TaskListModel {
    func moveAndSave(
        _ move: KsReorderMove<TaskItem>,
        save: @escaping @Sendable ([TaskItem]) async throws -> Void
    ) -> Bool {
        let original = tasks
        guard self.move(move) else { return false }
        let reordered = tasks
        Task {
            do {
                try await save(reordered)
            } catch {
                restore(original)
            }
        }
        return true
    }
}
```

この短い例は、配列をこの移動の前の姿に丸ごと戻します。そのため、保存が動いている間に変わったこと (2 回目の移動や、編集) も、一緒に取り消されます。移動が重なりうるときは、控えた配列に戻すのではなく、失敗した移動だけを取り消すか、並びをサーバーから読み込み直してください。

移動の内容を配列に当てはめる補助の関数は、ありません。グループの値の書き換え方が、利用する側のモデルで決まるためです。上の `move(_:)` を写して、自分のモデルに合わせて使ってください。グループのある一覧にも、無い一覧にも使えます。

## グループをまたいで動かす

`.groups` でグループを宣言した一覧 ([layout.md](layout.md) を参照) では、項目を別のグループに置けます。ライブラリは、行き先のグループの値を `move.group` で知らせるだけで、項目は書き換えません。受け入れるときは、`move(_:)` が `moved.section = section` としているように、動かした項目にそのグループの値を書き込んでから、配列を渡します。

```swift
struct GroupedTaskListScreen: View {
    @ObservedObject var model: TaskListModel

    var body: some View {
        KsCollectionView(model.tasks, layout: .list(groupSpacing: 16)) { task in
            TaskRow(task: task)
        }
        .groups(by: \.section) { section, tasksInSection in
            Text("\(section.rawValue.capitalized) (\(tasksInSection.count))")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(.background)
        }
        .reorder(
            isEnabled: model.isReordering,
            canMove: { task in !task.isLocked },
            canDrop: { move in move.group != AnyHashable(TaskSection.archived) },
            accessibilityActions: KsReorderAccessibilityActions(previous: "Move up", next: "Move down")
        ) { move in
            model.move(move)
        }
    }
}
```

約束ごと:

- 項目のグループの値を変えずに、別のグループへの移動を受け入れると、同じグループの値が配列の離れた 2 か所に現れます。これは不正入力です ([basics.md](basics.md) を参照)。
- 項目が 1 件も無いグループは表示されないので、そこには何も置けません。空になりうるグループへ項目を移せるようにしたいときは、別の手段 (メニューなど) を用意します。
- グループの最後の 1 件をドラッグしている間、そのグループの見出しは残ります。移動を受け入れた時点で、空になったグループは見出しごと消えます。その後、保存の失敗で前の配列が戻ってくれば、グループも戻ります。
- グループの宣言を付け外しできる画面では、外している間に動かした項目のグループの値も書き換えます。`move.group` が `nil` のときの `move(_:)` のように (`.before` の場合の `section ?? next[index].section` と、`.end` の場合の `else` の分岐)、新しい隣の項目のグループの値に合わせます。そうしないと、グループを戻したときに、配列が不正になります。

## 動かせる項目と置ける場所を限る

| 引数 | 呼ばれる時機 | `false` を返すと |
|---|---|---|
| `canMove: ((Item) -> Bool)?` | 項目ごとに、持ち上げる前 | その項目は持ち上がりません |
| `canDrop: ((KsReorderMove<Item>) -> Bool)?` | ドラッグ中に、行き先の候補ごとに (何度も)。それと、置く直前 | その場所には項目が入りません。そこで指を離すと項目は元に戻り、`onMove` は呼ばれません |

- `canDrop` は、`onMove` と同じ形の値を受け取ります。項目を自分のグループの中に留めるには、`move.group` と `move.item` のグループの値を比べます: `canDrop: { move in move.group == AnyHashable(move.item.section) }`。あるグループだけ、ほかのグループからの項目を受け入れず、そのグループの中の移動は許すには、2 つの比べ方を組み合わせます: `canDrop: { move in move.group != AnyHashable(TaskSection.archived) || move.item.section == .archived }`。
- 元の位置は判定されません。項目は、いつでも元に戻せます。
- どちらも渡さなければ、すべての項目を、すべての位置へ動かせます。
- `canDrop` は、軽い同期の判定にします。指が動く間に何度も呼ばれるので、重い処理をするとドラッグが遅れます。この中でサーバーに問い合わせないでください。問い合わせが要る可否は、置いた後に、保存の失敗として決めます。
- `canMove` と `canDrop` は、メインスレッドで呼ばれます。`onMove` と違って、`@MainActor` とは宣言されていません (`@Sendable` でもありません)。`body` の中に書けば、そのまま `@MainActor` のモデルを読めます。

## VoiceOver に移動の操作を出す

上のグループの例のように、`accessibilityActions:` に `KsReorderAccessibilityActions(previous:next:)` を渡します。スイッチが有効の間、動かせる項目のそれぞれに、渡した 2 つの文字列を名前にした 2 つのアクセシビリティの操作が出ます。1 つ前へ動かす操作と、1 つ後ろへ動かす操作です。

- 文字列を渡さなければ操作は出ず、VoiceOver を使う人は並べ替えられません。ライブラリは文言を持ちません。`previous` と `next` は `String` です (`LocalizedStringKey` ではありません)。`String(localized:)` などで翻訳を済ませた文字列を渡してください。
- グループの先頭の項目を前へ動かすと、前のグループの末尾へ移ります。グループの最後の項目を後ろへ動かすと、次のグループの先頭へ移ります。
- 行き先の無い操作 (一覧の先頭の項目の「前へ」、最後の項目の「後ろへ」) と、行き先について `canDrop` が `false` を返す操作は、出ません。
- 操作は、置いたときと同じく `onMove` を 1 回呼びます。受け入れの扱いも同じです。
- 文字列を渡してスイッチが有効の間、iOS では行の組み立ての負荷がいくらか増えます (Simulator で、メインスレッドの CPU の約 5〜8%)。並べ替えていないときは、スイッチを無効にしてください。

## ソートしている一覧を並べ替える

ライブラリは、ソートを知りません。移動を受け入れた後も、モデルがソートした配列を渡し続けると、置いた並びは残りません。置く前と等しい配列が届いている間は、項目は置いた位置のまま、配列とずれた状態になります。次に違う配列が届くと、項目はまたソートの位置に表示されます。次の 2 つの作りのどちらかを選びます。

- ソートしている間は、並べ替えのスイッチを無効にする: `.reorder(isEnabled: model.isReordering && !model.isSorted) { ... }`。ここの `isSorted` は、自分のモデルが持つフラグのことです。このページのモデルは、持っていません。
- `onMove` で手動の並びに切り替える: 今表示している配列を取り、それに移動を当てはめ、その結果を手動の並びとして持って、ソートをやめます。

```swift
@MainActor
final class SortableTaskListModel: ObservableObject {
    @Published private(set) var manualOrder: [TaskItem]
    @Published private(set) var sortsByTitle = true

    init(tasks: [TaskItem]) {
        manualOrder = tasks
    }

    var displayedTasks: [TaskItem] {
        sortsByTitle ? manualOrder.sorted { $0.title < $1.title } : manualOrder
    }

    func move(_ move: KsReorderMove<TaskItem>) -> Bool {
        var next = displayedTasks
        guard let from = next.firstIndex(where: { $0.id == move.item.id }) else { return false }
        let moved = next.remove(at: from)
        switch move.destination {
        case .before(let target):
            guard let index = next.firstIndex(where: { $0.id == target.id }) else { return false }
            next.insert(moved, at: index)
        case .end:
            next.append(moved)
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

ドラッグ中に次のどれかが起きると、ドラッグは取りやめになります。項目は元の位置に戻り、`onMove` は呼ばれません: 並べ替えのスイッチを無効にした、layout の値が変わった、グループの宣言が変わった (付けた・外した・キーパスを変えた・見出しや固定を変えた)、システムがタッチを中断した。ドラッグを続けさせたい間は、これらを変えないでください。

表示範囲の上端や下端の近くまでドラッグすると、一覧はその向きにスクロールします。速さや、反応する範囲の大きさの設定はありません。全画面に広げた一覧では、上の反応する範囲は、上のバーの下から始まります。

## iOS でのドラッグの動きを知る

iOS のドラッグは、システムが持つコレクションビューのドラッグ & ドロップの並べ替え (UIKit) そのもので、システムの一覧で見慣れた動きをします。UIKit を知っている必要はありません。利用者に見える動きは、表のとおりです。Android のドラッグは、指の位置にそのまま従います。`onMove` で受け取る値・受け入れ・最後の並びは、どちらも同じ決まりですが、動きは違います。表の 2 つの言葉: 「隙間」は、ドラッグ中の項目が置かれる場所を示すために、ほかの項目の間に空く場所です。「持ち上げた項目の絵」は、指に付いて動く、項目の写しです。以下は、iOS 18 と iOS 26 で観測した動きです。この 2 つの版の説明として読んでください。ライブラリが対応するすべての版 (iOS 16 以上) での保証ではありません。

| 場面 | iOS |
|---|---|
| 隙間が動く時機 | 指を止めてから動きます。指を動かしている間と、速い自動スクロールの間は動きません。(Android では、指を動かしている間にも動きます。リストでは持ち上げた項目がほかの項目に半分を越えて重なったとき、グリッドでは指がほかの項目の上に入ったときです) |
| 次のグループの先頭に置く | 上から運んで、先頭の項目の上で止めます |
| 前のグループの末尾に置く | 下から運んで、最後の項目の上で止めると、その項目の前に隙間が空きます。隙間がそのグループの中に入ったら、もう一度最後の項目の上で止めると、隙間が末尾へ動きます。(Android では、見出しより上が前のグループの末尾、下が次のグループの先頭です) |
| グループの見出しの上や、グループの間で止める | 隙間はそこへは動きません。指を離すと、項目はそのときの隙間の位置に置かれます |
| 受け入れなかった移動 | 項目はいったん置いた位置に収まり、少し止まってから、元へ戻ります。全体で約 1.3 秒です。(Android では、離した位置からまっすぐ戻ります) |
| 取りやめになったドラッグ | ドラッグは指を離すまで続きますが、項目はもうどこにも置けません。指を離したときに元へ戻り、変えた設定はその後に反映されます。(Android では、項目はその場で戻ります) |
| 届いた配列を保留し始める時点 | 持ち上げた後、指を動かし始めた時点からです。持ち上げてから最初に動かすまでの間に届いた配列は、その場で反映されます |
| 一覧の枠の外へドラッグする | 持ち上げた項目の絵が、システムの既定の小さい絵に切り替わります |
| 下の方のグループへ置く | 約 0.1〜0.2 秒、項目が 2 つ見えることがあります。システムの並べ替えと同じ見え方です |

隙間の動きが 2 つのプラットフォームで同じだと期待しないでください。また、複数の項目をまとめて動かす・グループを見出しごと動かす・一覧の間で動かす、を前提にした作りにしないでください。どれも提供していません。
