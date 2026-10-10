---
name: kscollectionview-ios
description: KsCollectionView で iOS のリスト・グリッド画面 (list / grid screen) を作る - プレーンな配列をリストやグリッドとして表示する SwiftUI の View で、項目の種類ごとのテンプレート切り替え、グループと固定見出し (pinned group headers)、ページングと Pull to Refresh (KsPagingState)、ドラッグ & ドロップの並べ替え (KsReorderMove)、KsImage と KsResource による画像の先読み (prefetch)、タップと長押し、コードからのスクロール (KsScrollController) を扱う。KsCollectionView を import する Swift アプリで、リストやグリッドの画面を追加・変更・レビューするときに使う。
license: MIT
metadata:
  language: ja
  source: https://github.com/kamusoft/KsCollectionView
---

# KsCollectionView for iOS

KsCollectionView は、リストとグリッドの画面を作るための UI ライブラリです。自分のモデルのプレーンな配列と、項目 1 つを描く SwiftUI のクロージャを渡すと、スクロールするリストやグリッドとして表示します。配列を差し替えると差分をアニメーションで反映し、セルを再利用するので 10,000 件でも軽く動きます。グループ・ページング・Pull to Refresh・並べ替え・画像の先読みといった、一覧の画面で繰り返し必要になる機能も備えています。この Skill が扱うのは iOS 版で、`UICollectionView` を土台にした `KsCollectionView` という 1 つの SwiftUI の View です。同じ考え方を、対応する名前で持つ Android 版 (Jetpack Compose) もあり、そちらは別の Skill `kscollectionview-android` が扱います。

## できること

| やりたいこと | 参照先 |
|---|---|
| 配列をリストとして表示する、安定 ID を決める、項目の種類でセルのテンプレートを切り替える | [references/basics.md](references/basics.md) |
| 配列を差し替えて一覧を更新する、セルの中で親の状態を読む、スクロールしても残したい状態を持つ | [references/basics.md](references/basics.md) |
| タップと長押しを受ける、タッチ中の色を決める、コードから項目や先頭・末尾へスクロールする | [references/basics.md](references/basics.md) |
| 不正な入力を渡したときの、デバッグビルドとリリースビルドでの動きを知る | [references/basics.md](references/basics.md) |
| リストかグリッドかを選ぶ、列数・間隔・内側の余白・リストの区切り線を決める、セルの大きさの決まり方とスクロールインジケータの動きを知る | [references/layout.md](references/layout.md) |
| ヘッダーとフッターを付ける、項目をグループに分けて見出しを固定する、バーの裏まで全画面に広げる | [references/layout.md](references/layout.md) |
| 末尾に近づいたら続きを読み込む、読み込み中・失敗・終端・空の表示を出す | [references/paging.md](references/paging.md) |
| Pull to Refresh を付ける、自分のコードから読み込み直す、読み込み中の表示の色を決める、ページングの状態を持つモデルを書く、実行中の読み込みが取り消される時機を知る、ページングを付けた一覧をバーの裏まで広げる | [references/paging.md](references/paging.md) |
| ドラッグ & ドロップで項目を並べ替える (グループをまたぐ移動を含む)、動かせる項目と置ける場所を限る、ソートしている一覧を並べ替える、ドラッグ中に保留されるものを知る、VoiceOver に移動の操作を出す | [references/reorder.md](references/reorder.md) |
| リモート・ファイル・アセットの画像をセルに表示する、もうすぐ表示される項目の画像を先読みする、URL が変わる画像にキーを使う、起動時にディスクキャッシュを有効にする、画像のキャッシュを操作する、Nuke 自身の View を `KsImage` と並べて使う | [references/images.md](references/images.md) |

次のものには、ライブラリの API がありません。探さないでください: 行のスワイプの操作、選択や複数選択のモード、コンテキストメニュー、横スクロール、複数の列にまたがる項目、段違いのグリッド、グループの折りたたみ、グループのフッター、スクロール位置の読み取りやスクロールのコールバック、スクロール位置の保存と復元、先頭へ向かって前のページを読み込むこと、差分のアニメーションの調整や無効化。グループの見出しは自分の View なので、見出しのタップは、そこに置いた `Button` で受けます。

## 導入

ライブラリは Swift パッケージとして配布しています。`Package.swift` では、パッケージと product を追加します。

```swift
dependencies: [
    .package(url: "https://github.com/kamusoft/KsCollectionView-SPM", exact: "{version}"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "KsCollectionView", package: "KsCollectionView-SPM"),
        ]
    ),
]
```

`{version}` はプレースホルダです。使う版に置き換えてください。そのままでは依存の解決に失敗します。最新の版は、Releases のページ https://github.com/kamusoft/KsCollectionView/releases で確かめられます。

Xcode のアプリのプロジェクトでは、*File > Add Package Dependencies...* から同じ Package URL (`https://github.com/kamusoft/KsCollectionView-SPM`) を追加し、Dependency Rule で版を決め (上の宣言に合わせるなら *Exact Version*)、product の `KsCollectionView` を選びます。`.product(name:package:)` に書く package の名前は、Package URL の末尾の `KsCollectionView-SPM` です。product の名前と、import するモジュールの名前は、どちらも `KsCollectionView` です。

| 必要なもの | 下限 |
|---|---|
| iOS の deployment target | iOS 16。このライブラリに依存する `Package.swift` は、`platforms: [.iOS(.v16)]` 以上を宣言します |
| Xcode | Xcode 27 以上 (パッケージのマニフェストが Swift tools 6.4 を宣言しているため、それより古い Xcode ではパッケージを解決できません) |

ライブラリを使うソースファイルには、それぞれ `import KsCollectionView` が要ります。Nuke (オープンソースの画像読み込みライブラリ。メジャー 13 系) は、このパッケージ自身の依存として入ります。Nuke の型を直接使わない限り、自分で依存に書く必要はありません。画像がアプリの再起動をまたいでディスクに残るのは、起動時に `KsImagePipeline.enableSharedDiskCache()` を 1 度呼んだ後だけです。[references/images.md](references/images.md) の「起動時にディスクキャッシュを有効にする」を参照してください。このライブラリは SwiftUI の View だけで、UIKit の API はありません。UIKit のアプリでは、この View を置いた SwiftUI の画面を `UIHostingController` で表示します。

ライブラリがこの Skill の説明どおりに動かないときは、https://github.com/kamusoft/KsCollectionView/issues に報告してください。

## 最小の動く例

100 行のリストを 1 つ表示する、ファイル全体の例です。

```swift
import KsCollectionView
import SwiftUI

struct Item: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
}

struct ItemListScreen: View {
    private static let itemCount = 100

    private let items = (0..<itemCount).map { index in
        Item(id: index, title: "Item \(index)")
    }

    var body: some View {
        KsCollectionView(items) { item in
            Text(item.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }
}
```

このライブラリのどの使い方にも、次の 3 つの決まりが当てはまります。

- 項目の型は `Equatable` でなければなりません。ライブラリは項目を比べて、内容の変わったセルを見つけます。`id:` で ID へのキーパスを渡さない限り、`Identifiable` も必要です。ID は、`Hashable` な値なら何でも構いません。`Sendable` は要りません。例は、項目が `async` の境界を越えるところにだけ付けています。項目には値型 (struct と enum) を使います。class のインスタンスをその場で書き換えると、自分自身と比べることになり、変化が見つかりません。
- 機能は、`.onItemTap`・`.groups`・`.paging`・`.reorder` のような、`KsCollectionView` 自身が持つ modifier で足します。これらは `KsCollectionView` を返すので、`KsCollectionView(...)` の式のすぐ後ろ、SwiftUI の modifier (`.refreshable`・`.ignoresSafeArea()`・`.frame` など) より前に書きます。SwiftUI の modifier の後ろでは値が `KsCollectionView` でなくなり、ライブラリの modifier はコンパイルできません。
- セルの高さは、中身から決まります。行の高さは指定しません。

この Skill が使う言葉: 「項目」は、配列の要素 1 つです。「セル」は、ライブラリが項目 1 つのために画面に作る入れ物で、再利用されます (画面の外へ出たセルは、ほかの項目に使い回されます)。「行」は、クロージャがセルの中に描く View です。グリッドでも行と呼びます。ただし layout.md の間隔の決まりでは、「行」は横に並ぶセルの 1 段を指します。「一覧」は、layout が何であっても、画面の上の `KsCollectionView` 1 つのことで、「配列」は、そこに渡すものです。

この Skill の例は、iOS 16 向けにコンパイルできるよう、モデルを `ObservableObject` で書いています。`@Observable` マクロで書いたモデル (iOS 17 以上) も使えますが、違いが 1 つあります。SwiftUI が `body` を評価し直すのは、`body` 自身が読んだプロパティについてだけです。行のクロージャ・ヘッダー・ページングの表示の中でしか読まないプロパティは追跡されないので、`body` の中でも読んでください。行とグループの見出しでは、`.observedValue(_:)` に渡せば、それで読んだことになります ([references/basics.md](references/basics.md) を参照)。

Swift 6 の言語モードでの扱い: `KsCollectionView` は `View` なので、イニシャライザと modifier は、メインアクターに隔離されています。そこに渡すクロージャ (行とテンプレートの中身・タップのコールバック・ヘッダーとフッター・グループの見出し・ページングの表示・`prefetchResources`・`canMove`・`canDrop`) は、`@MainActor` も `@Sendable` も付かない、ふつうのクロージャとして宣言されています。`body` の中に書けば、`body` と同じメインアクターの隔離を引き継ぐので、`await` なしで `@State` を読み、`@MainActor` のモデルを呼べます。`@MainActor` と宣言されているのは 3 つで、`onLoadMore` (`async` でもあります)・失敗の表示に渡される `retry`・`onMove` です。

## リファレンス

- [references/basics.md](references/basics.md) - 項目と安定 ID、テンプレート、配列の差し替え、セルの中で読む親の状態、タップと長押し、コードからのスクロール、不正入力。
- [references/layout.md](references/layout.md) - リストとグリッド、列数、間隔、内側の余白、区切り線、ヘッダーとフッター、グループと固定見出し、全画面に広げたときの安全領域。
- [references/paging.md](references/paging.md) - ページングの 5 つの状態 (`KsPagingState`)、次のページの要求、読み込み中・失敗・終端・空の 6 つの表示、Pull to Refresh、状態を持つモデルの書き方。
- [references/reorder.md](references/reorder.md) - 並べ替えのスイッチ (`isEnabled` のフラグ)、置いたときに受け取る移動の内容、受け入れと元に戻す動き、グループをまたぐ移動、VoiceOver の移動の操作。
- [references/images.md](references/images.md) - `KsImage`、`KsResource` による先読み、ディスクキャッシュ、`KsImageCache` によるキャッシュの操作。
