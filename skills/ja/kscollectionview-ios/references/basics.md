# 一覧を出す

`KsCollectionView` で配列を表示する、更新する、タップを受ける、コードからスクロールするためのレシピです。どの例も `import SwiftUI` と `import KsCollectionView` を前提にしています。このページの後ろの例は、前の例で宣言した型 (`Contact`・`ContactRow`) をそのまま使います。

## 配列を表示する

配列と、項目 1 つを描くクロージャを渡します。項目の型は `Equatable` かつ `Identifiable` でなければなりません。配列は自分のモデルのままでよく、ラッパーの型も、ライブラリの protocol への準拠も要りません。

```swift
struct Contact: Identifiable, Equatable {
    let id: Int
    var name: String
}

struct ContactRow: View {
    let contact: Contact

    var body: some View {
        Text(contact.name)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }
}

struct ContactListScreen: View {
    let contacts: [Contact]

    var body: some View {
        KsCollectionView(contacts) { contact in
            ContactRow(contact: contact)
        }
    }
}
```

型が `Identifiable` でなく、自分では変えられないとき (ほかのモジュールと共有しているモデルなど) は、ID をキーパスで指します。この場合も、型は `Equatable` でなければなりません。

```swift
struct SharedContact: Equatable {
    let contactId: String
    let name: String
}

struct SharedContactListScreen: View {
    let contacts: [SharedContact]

    var body: some View {
        KsCollectionView(contacts, id: \.contactId) { contact in
            Text(contact.name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
}
```

約束ごと:

- ID は、配列の中で一意で、時間がたっても変わらない値にします。項目を同じものと見なす基準は、値の全体ではなく ID です。ID が同じまま内容が変わった項目は、セルを保ったまま、中身だけが作り直されます。
- イニシャライザは `layout:` と `contentPadding:` も受け取ります ([layout.md](layout.md) を参照)。渡さなければ、区切り線つき・余白なしの 1 列のリストになります。どのイニシャライザも、引数の順は同じで、使わないものを省きます。配列・`id:`・`template:`・`layout:`・`contentPadding:`・末尾のクロージャの順です。たとえば `KsCollectionView(contacts, id: \.contactId, layout: .list(rowSpacing: 8), contentPadding: EdgeInsets()) { ... }` と書きます。
- 項目の型に要るのは、`Equatable` と ID だけです。`Sendable` は要らず、ID は `Hashable` な値なら何でも構いません。項目には値型を使います。class のインスタンスをその場で書き換えても、変わったとは見なされません。
- この View は、親から与えられた領域いっぱいに広がり、縦にスクロールします。行のクロージャはどんな SwiftUI の View を返してもよく、行の高さは中身から測られます。
- 項目の無い一覧は、自分では何も表示しません (空の表示があるのは、ページングを付けた一覧だけです。[paging.md](paging.md) を参照)。ページングを付けない一覧では、配列が空の間、一覧の代わりに、または一覧に `.overlay` で重ねて、自分の View を出します。
- 自然な幅が項目の幅より小さい行は、水平の中央に置かれます。行を幅いっぱいに広げて中身を寄せるには、例のように `.frame(maxWidth: .infinity, alignment: .leading)` を付けます。

## 項目の種類でテンプレートを切り替える

種類の違う項目を別々の View で描くには、`template:` に `Hashable` な値へのキーパスを渡し、値ごとに `KsTemplate` を 1 つずつ登録します。

```swift
enum FeedKind: Hashable {
    case message
    case notice
}

struct FeedEntry: Identifiable, Equatable {
    let id: Int
    let kind: FeedKind
    let text: String
}

struct MixedFeedScreen: View {
    let entries: [FeedEntry]

    var body: some View {
        KsCollectionView(entries, template: \.kind) {
            KsTemplate(.message) { entry in
                Text(entry.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            KsTemplate(.notice) { entry in
                Label(entry.text, systemImage: "exclamationmark.circle.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
    }
}
```

約束ごと:

- キーパスが返しうるすべての値に、テンプレートを登録します。テンプレートの無い値を持つ項目は、不正入力です (最後の節を参照)。
- 画面の外へ出たセルは、ほかの項目に使い回されます。使い回す先は、同じテンプレートの値を持つ項目だけです。違うテンプレートのセルが入れ替わることはありません。
- どの `KsTemplate` のクロージャも、キーが何であっても、項目を一覧の項目の型 (ここでは `FeedEntry`) で受け取ります。
- ID が同じまま項目のテンプレートの値が変わると、そのセルは中身の作り直しではなく、セルごと置き換えられます。
- `Identifiable` でない型では、2 つのキーパスを両方渡します: `KsCollectionView(entries, id: \.entryId, template: \.kind) { ... }`。
- `KsTemplate` を並べたブロックは、result builder の `KsTemplateBuilder` が集めます。このビルダーを自分で呼ぶことはありません。ブロックに書けるのは `KsTemplate` の式だけです (`if` や `for` は書けません)。
- Android では、同じ登録を、中身のブロックの中で `template` という名前の関数を呼んで書くため、`KsTemplate` という名前の型はありません。

## 配列を差し替えて一覧を更新する

一覧には、挿入・削除・移動のメソッドがありません。自分の配列を変えて、新しい配列を渡します。ライブラリが ID で差分を求め、挿入・削除・移動をアニメーションで見せます。並べ替えと絞り込みも、同じように自分のデータの側で行います。

```swift
@MainActor
final class ContactListModel: ObservableObject {
    @Published private(set) var contacts: [Contact] = []

    func add(_ contact: Contact) {
        contacts.insert(contact, at: 0)
    }

    func remove(id: Contact.ID) {
        contacts.removeAll { $0.id == id }
    }

    func rename(id: Contact.ID, to name: String) {
        guard let index = contacts.firstIndex(where: { $0.id == id }) else { return }
        contacts[index].name = name
    }

    func sortByName() {
        contacts.sort { $0.name < $1.name }
    }
}

struct EditableContactListScreen: View {
    @StateObject private var model = ContactListModel()

    var body: some View {
        KsCollectionView(model.contacts) { contact in
            ContactRow(contact: contact)
        }
    }
}
```

ライブラリが保証すること:

- ID が同じで内容が違う項目 (上の `rename`) は、セルを保ちます。作り直されるのは、そのセルの中身だけです。
- コンテンツの先頭を表示しているときに配列の先頭へ項目を入れると、その項目は表示範囲の中にアニメーションで現れ、一覧は先頭に留まります。末尾でも同じです。ページングを付けた一覧では、末尾の側の決まりが置き換わります ([paging.md](paging.md) を参照)。
- 存在するセルは、表示範囲とその近くの分だけです。メモリは項目の件数に比例して増えません。

約束ごと:

- `id:` と `template:` に渡したキーパスと、登録したテンプレートの集合を、一覧の表示中に変えないでください。変えても反映されません。これらは、状態で選ぶ値にせず、`KsCollectionView(...)` の式に固定して書きます。(項目自身のテンプレートの値が変わるのは構いません。前の節を参照してください。) `.groups(by:)` のキーパスだけは例外で、切り替えられます ([layout.md](layout.md) を参照)。
- 「新しい配列」とは、表示中の配列と等しくない (`==` でない) 配列のことです。等しい配列を渡し直しても、何も変わりません。
- 一覧を途中までスクロールした状態で、表示範囲より上に項目を足したり消したりすると、一覧が保つのはスクロールの量で、画面に出ている項目ではありません。画面に出ているものは、足した・消した高さの分だけずれます。(Android では、表示範囲の先頭の項目がその場に留まります。)
- 項目でない要素 (セクションの題名など) を配列に混ぜないでください。グループの見出しは `.groups` で宣言します ([layout.md](layout.md) を参照)。

## 行の中で親の状態を読む

行のクロージャが、配列の外にある状態 (展開中の ID の集合や、選択中の ID など) を読むときは、その状態を `.observedValue(_:)` に渡します。値は `Hashable` でなければなりません。

```swift
struct ExpandableContactListScreen: View {
    let contacts: [Contact]
    @State private var expandedIDs: Set<Int> = []

    var body: some View {
        KsCollectionView(contacts) { contact in
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                if expandedIDs.contains(contact.id) {
                    Text("ID \(contact.id)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .observedValue(expandedIDs)
        .onItemTap { contact in
            expandedIDs.formSymmetricDifference([contact.id])
        }
    }
}
```

これが要る理由: 行のクロージャは、SwiftUI が `body` を評価し終えた後に実行されます。そのため、クロージャの中でしか読まれない状態は、SwiftUI に追跡されません。その状態を変えても `body` は評価し直されず、表示中のセルには何も届きません。状態を `.observedValue` に渡すと、`body` の中で読んだことになり、セルを作り直す時機もライブラリに伝わります。

約束ごと:

- 行のクロージャが読む状態は、すべてこの 1 つの値に入れます。状態が複数あるときは、`Hashable` な 1 つの構造体にまとめます。配列が変わっていないとき、表示中のセルが作り直されるのは、観測する値が変わったときだけです。ほかの変化は届きません。
- 例のように、状態によって行の高さが変わるときは、高さの変化がアニメーションします。
- `.observedValue` を付けていない一覧は、代わりに、等しい配列のまま `body` が評価し直されるたびに、表示中のセルを作り直します。この代わりの動きでセルに届くのは、ほかの何かが `body` を評価し直させるときだけです (その状態がクロージャの外の `body` でも読まれている、または、画面が観測しているモデルの `@Published` のプロパティである)。しかも穴があります。同じ更新で配列も変わると、内容の変わっていない項目のセルは、古い状態のまま残ります。行が読む状態には、必ず `.observedValue` を使ってください。
- グループの見出しの中で読む状態にも、同じ決まりが当てはまります。
- ヘッダー・フッター・ページングの表示は、`.observedValue` の対象ではありません。`body` が評価し直されるたびに、作り直されます。そこで読む状態は、`body` を評価し直させさえすれば届きます。画面が観測しているモデルの `@Published` のプロパティは、評価し直させます。これらのクロージャの中でしか読まない `@State` は評価し直させないので、`body` の中でも読んでください。
- 行・全体のヘッダーとフッター・グループの見出し・ページングの表示は UIKit のセルの中に載っていて、ライブラリは、画面の SwiftUI の環境をそこへ引き継ぎません。`.environmentObject`・自分で定義した `@Environment` の値・一覧の外側に付けた `.font` などの modifier が行に届くことを、当てにしないでください。行に要るものは、行の View のイニシャライザで渡します。ライトとダークの外観は、一覧が置かれた場所に従います。
- この modifier は iOS にしかありません。Android では Compose が状態を自動で購読するので、宣言するものはありません。

## スクロールしても残したい状態はモデルに持たせる

画面の外へ出たセルは、ほかの項目のために再利用されます。行の中の SwiftUI の状態 (`@State`・フォーカス・入力途中の文字) は、再利用をまたいで残りません。その項目が戻ってきたとき、行は初期の状態から始まります。行に付けた `onAppear` と `.task` は、行が表示範囲に入るたびに動きます。

- スクロールしても残したいもの (開閉・選択・下書きの文字) は、配列に持たせるか、前の節のように `.observedValue` で渡す親の状態に持たせます。
- 行の中の `@State` は、初期値に戻っても構わない状態 (押したときのアニメーションなど) には使えます。
- 行のクロージャは、項目を `Binding` ではなく値で受け取ります。行の中のコントロール (`Toggle`・`TextField`) からデータを変えるには、配列を差し替えるモデルの関数を呼びます。残したい下書きは、モデルに持たせます。
- 行が画面に出ている間は、行の中の状態は保たれます。配列や観測する値が変わって表示中のセルが作り直されるときも、保たれます。

## タップと長押しを受ける

```swift
struct TappableContactListScreen: View {
    let contacts: [Contact]
    @State private var opened: Contact?
    @State private var menuTarget: Contact?

    var body: some View {
        KsCollectionView(contacts) { contact in
            ContactRow(contact: contact)
        }
        .onItemTap { contact in
            opened = contact
        }
        .onItemLongTap { contact in
            menuTarget = contact
        }
        .touchFeedback(color: .accentColor.opacity(0.1))
    }
}
```

ライブラリが保証すること:

- コールバックには、配列の要素そのものが渡ります。メインスレッドで呼ばれます。型は、`@MainActor` も `@Sendable` も付かない、ふつうの `(Item) -> Void` です (`Item` は、自分の項目の型のことです)。上の例のように `body` の中に書けば、そのまま `@State` を書き換え、`@MainActor` のモデルを呼べます。
- タッチ中の色 (フィードバック) が出るのは、`.onItemTap` か `.onItemLongTap` を宣言した一覧だけです。`.touchFeedback(color:)` を付けなければ、標準のハイライトになります。押している間、セルの全面がシステムの塗りの色 (`UIColor.systemFill`。半透明の灰色) で覆われます。
- 行の中のコントロールが優先されます。行の中の `Button` や `Toggle` がタッチを処理したときは、項目のコールバックもフィードバックも働きません。項目のタップは、行の残りの部分へのタッチで働きます。
- タップと長押しは、どちらか一方だけです。長押しになったタッチでは、`.onItemTap` は呼ばれません。
- 並べ替えが有効の間は、長押しでドラッグが始まり、`.onItemLongTap` は呼ばれません ([reorder.md](reorder.md) を参照)。

約束ごと:

- `.touchFeedback(color:)` は、渡した色を、不透明度も含めてそのままセルの全面に塗ります。不透明な色を渡すと、押している間は行が隠れるので、半透明の色を渡します。フィードバックを出したくないときは、`.clear` を渡します。`.onItemTap` と `.onItemLongTap` はそのまま呼ばれるので、行が選ばれた見た目を自分で描くときに、フィードバックだけを消す手段になります。
- Android の同じ設定は、色みだけを使い、濃さは Android 標準のタッチの効果 (波紋) が決めます。そのため、同じ色の値でも 2 つのプラットフォームで同じ見え方にはなりません。半透明の色を渡すと、近い見え方になります。完全に透明な色を渡したときは、Android でもフィードバックが出ません。

## コードからスクロールする

`KsScrollController` を作り、`.scrollController(_:)` でつないで、命令を送ります。コントローラはプレーンなオブジェクトです。View が `@State` で持っても、モデルが持っても構いません。

```swift
struct ScrollableContactListScreen: View {
    let contacts: [Contact]
    @State private var controller = KsScrollController()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Top") { controller.scrollToStart() }
                Spacer()
                Button("Contact 50") { controller.scrollTo(id: 50, position: .center) }
                Spacer()
                Button("Bottom") { controller.scrollToEnd(animated: false) }
            }
            .padding()

            KsCollectionView(contacts) { contact in
                ContactRow(contact: contact)
            }
            .scrollController(controller)
        }
    }
}
```

| 命令 | 意味 |
|---|---|
| `scrollTo(id:position:animated:)` | その ID の項目へスクロールします。`position` は `KsScrollPosition` で、`.start` (既定) は項目を表示範囲の上端に、`.center` は中央に、`.end` は下端に置きます |
| `scrollToStart(animated:)` | コンテンツの先頭 (ヘッダーがあれば、その上端) へスクロールします |
| `scrollToEnd(animated:)` | 最後の項目が表示範囲の下端に来るまでスクロールします。最後の項目の下にあるもの (フッターと、ページングの「次のページの失敗」「終端」の表示) は、表示範囲に入りません (Android の同じ命令は、フッターを含むいちばん最後まで進みます) |

`animated` の既定は、3 つとも `true` です。

ライブラリが保証すること:

- 命令は、最新の配列が画面に出た後に実行されます。項目を末尾に足して、同じ関数の中で `scrollToEnd()` を呼ぶと、足した後の最後の項目まで届きます。
- 一覧につながっているコントローラに送った命令は、送った順に実行されます。更新や前のアニメーションの途中だからという理由で、失われることはありません。後の命令は前の命令のアニメーションを中断するので、最後の位置は、最後の命令のものになります。
- 何も起こさない命令が 2 種類あり、どちらもクラッシュしません。実行する時点で配列に無い ID への命令と、コントローラが一覧につながっていない間に送った命令です (後のために取っておかれもしません)。
- 位置の基準は、一覧自身の端です。`.start` は項目の上端を一覧の上端に、`.end` は項目の下端を一覧の下端に合わせます。上下の `contentPadding` はスクロールするコンテンツの一部で、空けたままにはなりません。(Android では、項目は余白の内側で止まります。) 届かない位置はスクロールできる範囲に丸められるので、先頭や末尾の近くの項目は端で止まります。
- 命令によるスクロールでも、ほかのスクロールと同じように、ページングの条件が判定されます ([paging.md](paging.md) を参照)。
- スクロールの位置は読み取れず、保存もされません。位置は、SwiftUI がその View を保っている間 (次の画面を積んでいる間や、回転の前後) は続きます。作り直された一覧は、コンテンツの先頭から始まります。
- グループの見出しを固定している一覧では、`.start` は項目を、固定中の見出しの裏ではなく、すぐ下に置きます。

約束ごと:

- ID は、項目の ID と同じ型で渡します。ID が整数の `50` の項目は、`scrollTo(id: "50")` では見つかりません。
- `KsScrollController` は、メインアクターに隔離されています。メインアクターから呼んでください。
- 1 つのコントローラは、1 つの一覧につなぎます。複数につなぐと、最後につないだ一覧だけが命令を受け取ります。
- 命令が、更新する前の配列に対して実行されることを期待しないでください。命令は、いつも更新の後に解決されます。

## 不正な入力を渡したとき

プログラムの誤りに当たる入力に対して、ライブラリは、デバッグビルドでは気付けるように停止し、リリースビルドでは、クラッシュさせずにログに警告を残して、画面を動かし続けます。それぞれの場合に何が表示されるかは、表のとおりです。この動きと違う 2 つの行は、表の中に書いてあります。「デバッグ」と「リリース」は、自分のアプリのビルドの構成のことです。警告は、Apple の統合ログ (Unified Logging) に、subsystem `jp.kamusoft.kscollectionview` で出ます。Xcode のコンソールか、「コンソール」アプリで、その subsystem に絞って読みます。

| 不正入力 | デバッグビルド | リリースビルド |
|---|---|---|
| テンプレートの値に対応する `KsTemplate` が登録されていない項目 | assertion で停止 | その位置に高さ 1 ポイントの空のセルを出します。項目の数は配列と一致したままです |
| 配列の中に同じ ID が 2 つある | assertion で停止 | 後ろの要素だけを表示し、前の要素は表示しません。表示は続けます |
| 同じキーに `KsTemplate` を 2 つ登録した | 停止しません。後の登録を採用し、ログに警告を残します | 後の登録を採用します |
| 同じグループの値が、配列の離れた 2 か所に現れる ([layout.md](layout.md) を参照) | assertion で停止 | 項目を配列の順のまま、別々のグループとして表示します |
| layout の間隔に負の値を渡した ([layout.md](layout.md) を参照) | assertion で停止 | 0 として扱います |
| 列数が 0 以下 ([layout.md](layout.md) を参照) | assertion で停止 | 1 列として扱います。ログに警告は出ません |
| ページングのしきい値が負の数か、有限でない数 ([paging.md](paging.md) を参照) | assertion で停止 | 0 として扱います |
| 先読みの固定の幅が 0・負の数・有限でない数 ([images.md](images.md) を参照) | assertion で停止 | 幅を指定しなかったものとして扱います |
| 画像のキーが空文字 ([images.md](images.md) を参照) | assertion で停止 | キーを指定しなかったものとして扱います |

`KsGridColumns.adaptive(minItemWidth:)` も、幅が 0 以下のときにデバッグビルドで停止します。上の表の行と違い、リリースビルドでの決まった扱いがありません。必ず正の幅を渡してください。

配列に無い ID へのスクロール命令と、つながっていないコントローラへの命令は、不正入力ではありません。削除と命令が競合して、正しいコードでも起こりうるためです。どちらの構成でも、無視されます。
