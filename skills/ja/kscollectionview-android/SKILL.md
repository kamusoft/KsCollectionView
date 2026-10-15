---
name: kscollectionview-android
description: KsCollectionView で Android のリスト・グリッド画面 (list / grid screen) を作る - プレーンな配列をリストやグリッドとして表示する Jetpack Compose の Composable で、項目の種類ごとのテンプレート切り替え、グループと固定見出し (KsGroups, pinned group headers)、ページングと Pull to Refresh (KsPaging, KsPagingState)、ドラッグ & ドロップの並べ替え (KsReorder, KsReorderMove)、KsImage と KsResource による画像の先読み (prefetch)、タップと長押し、コードからのスクロール (KsScrollController) を扱う。jp.kamusoft.kscollectionview を import する Kotlin アプリで、リストやグリッドの画面を追加・変更・レビューするときに使う。
license: MIT
metadata:
  language: ja
  source: https://github.com/kamusoft/KsCollectionView
---

# KsCollectionView for Android

KsCollectionView は、リストとグリッドの画面を作るための UI ライブラリです。自分のモデルのプレーンな `List` と、項目 1 つを描く Composable のラムダを渡すと、スクロールするリストやグリッドとして表示します。配列を差し替えると差分をアニメーションで反映し、表示範囲とその近くの項目だけを組み立てるので 10,000 件でも軽く動きます。グループ・ページング・Pull to Refresh・並べ替え・画像の先読みといった、一覧の画面で繰り返し必要になる機能も備えています。この Skill が扱うのは Android 版で、`LazyVerticalGrid` を土台にした `KsCollectionView` という 1 つの Jetpack Compose の Composable です。同じ考え方を、対応する名前で持つ iOS 版 (SwiftUI) もあり、そちらは別の Skill `kscollectionview-ios` が扱います。

## できること

| やりたいこと | 参照先 |
|---|---|
| 配列 (渡す `List`) をリストとして表示する、安定 ID を決める、項目の種類でセルのテンプレートを切り替える | [references/basics.md](references/basics.md) |
| 配列を差し替えて一覧を更新する、セルの中で親の状態を読む、スクロールしても残したい状態を持つ | [references/basics.md](references/basics.md) |
| タップと長押しを受ける、タッチ中の色を決める、コードから項目や先頭・末尾へスクロールする | [references/basics.md](references/basics.md) |
| 不正な入力を渡したときの、デバッグビルドとリリースビルドでの動きを知る | [references/basics.md](references/basics.md) |
| リストかグリッドかを選ぶ、列数・間隔・内側の余白・リストの区切り線を決める、セルの大きさの決まり方とスクロールインジケータの動きを知る | [references/layout.md](references/layout.md) |
| ヘッダーとフッターを付ける、項目をグループに分けて見出しを固定する、システムバーの裏まで edge-to-edge に広げる | [references/layout.md](references/layout.md) |
| 末尾に近づいたら続きを読み込む、読み込み中・失敗・終端・空の表示を出す | [references/paging.md](references/paging.md) |
| Pull to Refresh を付ける、自分のコードから読み込み直す、読み込み中の表示の色を決める、ページングの状態を持つモデルを書く、実行中の読み込みが取り消される時機を知る、ページングを付けた一覧をシステムバーの裏まで広げる | [references/paging.md](references/paging.md) |
| ドラッグ & ドロップで項目を並べ替える (グループをまたぐ移動を含む)、動かせる項目と置ける場所を限る、ソートしている一覧を並べ替える、ドラッグ中に保留されるものを知る、TalkBack に移動の操作を出す | [references/reorder.md](references/reorder.md) |
| リモート・ファイル・ドローアブルリソースの画像をセルに表示する、もうすぐ表示される項目の画像を先読みする、URL が変わる画像にキーを使う、画像のキャッシュを操作する (ライブラリの起動時の初期化が要ります。「導入」を参照)、Coil 自身の Composable を `KsImage` と並べて使う | [references/images.md](references/images.md) |

次のものには、ライブラリの API がありません。探さないでください: 横スクロール、行のスワイプの操作、選択や複数選択のモード、複数の列にまたがる項目、段違いのグリッド、グループの折りたたみ、グループのフッター、スクロール位置の読み取りやスクロールのコールバック (内部の `LazyGridState` は公開していません)、グループの見出しへのスクロール、先頭へ向かって前のページを読み込むこと、差分のアニメーションの調整や無効化、Jetpack Paging 3 (一覧が受け取るのはプレーンな `List` で、`LazyPagingItems` ではありません)。グループの見出しは自分の Composable なので、見出しのタップは、そこに置いた `clickable` なもので受けます。

## 導入

ライブラリは、1 つのアーティファクトとして Maven Central で配布しています。使うモジュールに依存を追加します。

```kotlin
dependencies {
    implementation("jp.kamusoft:kscollectionview:{version}")
}
```

`{version}` はプレースホルダです。使う版に置き換えてください。そのままでは依存の解決に失敗します。最新の版は、Releases のページ https://github.com/kamusoft/KsCollectionView/releases で確かめられます。

| 必要なもの | 下限 |
|---|---|
| Android の版 | Android 10 (`minSdk` 29) |
| `compileSdk` | 36 |
| Jetpack Compose | モジュールで有効にしていること (Compose のコンパイラプラグインと `buildFeatures { compose = true }`) |

Android Gradle Plugin と Kotlin の下限は示していません。ライブラリは、Android Gradle Plugin 9.4.0 と Kotlin 2.4.10 でビルドして確かめています。

公開している名前は、すべて package `jp.kamusoft.kscollectionview` にあります。使う名前を、ここから import します。下位の package はありません。型も関数も (`rememberKsScrollController` も)、すべて `jp.kamusoft.kscollectionview.<name>` の形で import します。このアーティファクトが自分のモジュールに届けるものと、届けないものは、次のとおりです。

- Compose Runtime・Compose UI・Compose Foundation Layout と、Coil の Compose 向けのアーティファクト (`io.coil-kt.coil3:coil-compose`) は、Compose の版をそろえる Compose BOM と一緒に、ライブラリを通して compile classpath に届きます。自分のモジュールも Compose BOM を宣言しているときは、Gradle が、Compose のライブラリごとに、2 つのうち新しいほうの版を選びます。
- Compose Foundation (`BasicText`・`clickable` など) と Material 3 (`Text`・`Button` など) は、ライブラリの内側で使っていますが、利用する側のコードには届けません。自分の Composable で使うときは、いつもどおり `androidx.compose.foundation:foundation` や `androidx.compose.material3:material3` を、版を書かずに自分のモジュールの依存に書きます。
- Coil (オープンソースの画像読み込みライブラリ。メジャー 3 系) と、OkHttp を使うそのネットワークの取得の機能は、ライブラリと一緒に入ります。Coil を自分で依存に書く必要はなく、準備のコードも要りません。ライブラリは、Coil のアプリ全体のローダーをそのまま使い、差し替えません。そのため、自分で行ったローダーの設定 (Coil の `SingletonImageLoader.Factory`。要求のヘッダーを足すなど) は、ライブラリの画像にも効きます。
- ライブラリのために、R8 や ProGuard の規則を足す必要はありません。
- リモートの画像を読み込むには、アプリのマニフェストに `android.permission.INTERNET` の権限が要ります。ライブラリは、この権限を足しません。
- ライブラリは、マニフェストのマージを通して、`androidx.startup` の初期化を 1 つ登録します。そのために書くものはありません。自分のマニフェストから `androidx.startup.InitializationProvider` を取り除かないことだけを守ってください ([references/images.md](references/images.md) を参照)。

ライブラリがこの Skill の説明どおりに動かないときは、https://github.com/kamusoft/KsCollectionView/issues に報告してください。

## 最小の動く例

100 行のリストを 1 つ表示する、ファイル全体の例です。

```kotlin
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import jp.kamusoft.kscollectionview.KsCollectionView

data class Item(val id: Int, val title: String)

private const val ItemCount = 100

@Composable
fun ItemListScreen(modifier: Modifier = Modifier) {
    val items = remember { List(ItemCount) { index -> Item(id = index, title = "Item $index") } }
    KsCollectionView(
        items = items,
        key = { it.id },
        modifier = modifier.fillMaxSize().safeDrawingPadding(),
    ) {
        template { item ->
            BasicText(
                text = item.title,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
            )
        }
    }
}
```

この例は、Material に依存しないよう、文字を Compose Foundation の `BasicText` で描いています。コンパイルするには、モジュールで Compose を有効にして、Compose Foundation への依存を書く必要があります。

このライブラリのどの使い方にも、次の 5 つの決まりが当てはまります。

- `key` は必須です。項目の安定 ID を返します。配列の中で一意で、時間がたっても変わらず、Android が `Bundle` に保存できる型 (文字列・数値・enum・`Serializable` か `Parcelable` の値) にします。
- 項目の型は、`equals` を持つ不変の値 (ふつうは `data class`) にして、表示を変えるときは新しい `List` を渡します。ライブラリが配列を書き換えることはありません。
- 機能はどれも、`onItemTap`・`groups`・`paging`・`reorder` のような、1 つの `KsCollectionView` の呼び出しの名前付き引数です。ライブラリ独自の modifier はありません。`modifier` は、ふつうの Compose の `Modifier` です。
- 末尾のブロックは、`template { ... }` でテンプレートを宣言するだけの場所です。ブロック自体は Composable ではないので、Composable の呼び出しは、`template` に渡すラムダの中に書きます。
- `KsCollectionView` は自分で縦にスクロールし、セルの高さは中身から決まります。`KsCollectionView` には、上限のある高さを与えます (`Modifier.fillMaxSize()` や、`Column` の中の `Modifier.weight(1f)`)。縦にスクロールするほかの入れ物の中には置きません。

この Skill が使う言葉: 「配列」は、渡す `List` のことです (Kotlin の `Array` のことではありません)。「項目」は、その要素 1 つです。「セル」は、ライブラリが項目 1 つのために画面に作る入れ物です。「行」は、テンプレートがセルの中に描くものです。グリッドでも行と呼びます。ただし layout.md の間隔の決まりでは、「行」は横に並ぶセルの 1 段を指します。「一覧」は、layout が何であっても、画面の上の `KsCollectionView` 1 つのことです。「キー」だけでは使いません。`key` のラムダが返すのは項目の「ID」、`template` のラムダが返すのは「テンプレートのキー」で、画像には「画像のキー」を付けられます。

ライブラリが自分で描く色 (リストの区切り線・スクロールインジケータ・画像の既定の表示) は、Material の配色ではなく、`isSystemInDarkTheme()` に従います。Material の配色の切り替えだけでダークにするアプリは、これらを自分で指定します。[references/layout.md](references/layout.md) と [references/images.md](references/images.md) を参照してください。

この Skill の例は、文字とボタンに Material 3 を使い、Compose のほかに何も要らないよう、状態を Compose の `mutableStateOf` を持つプレーンなクラスに置いています。`ViewModel` でも同じです。状態をどこに持っていても、Composable が今の配列と今の値を `KsCollectionView` に渡します。モデルの例には、見落としやすい import が 3 つ要ります。`by mutableStateOf(...)` のプロパティのための `androidx.compose.runtime.getValue` と `androidx.compose.runtime.setValue`、それに `kotlinx.coroutines.CancellationException` です。

Material 3 の無いモジュールでは、例の文字とボタンを、上の最小の動く例のように、Compose Foundation (`BasicText`・`Modifier.clickable`) で書きます。ライブラリ自身が Material 3 で描くもの (既定の読み込み中の表示・タップの波紋・Pull to Refresh のインジケータ) は、自分のモジュールに Material 3 の依存が無くても動きます。Material 3 は、実行時にライブラリと一緒に届くためです。一覧を `MaterialTheme` で包んでいないときは、読み込み中の表示と Pull to Refresh のインジケータの色は、Material 3 の既定のライトの配色になります (ダークモードでも同じです)。

## リファレンス

- [references/basics.md](references/basics.md) - 項目と安定 ID、テンプレート、配列の差し替え、セルの中で読む親の状態、タップと長押し、コードからのスクロール、不正入力。
- [references/layout.md](references/layout.md) - リストとグリッド、列数、間隔、内側の余白、区切り線、ヘッダーとフッター、グループと固定見出し、edge-to-edge に広げたときのシステムバー。
- [references/paging.md](references/paging.md) - ページングの 5 つの状態 (`KsPagingState`)、次のページの要求、読み込み中・失敗・終端・空の 6 つの表示、Pull to Refresh、状態を持つモデルの書き方。
- [references/reorder.md](references/reorder.md) - 並べ替えのスイッチ (`KsReorder` の `enabled` のフラグ)、置いたときに受け取る移動の内容、受け入れと元に戻す動き、グループをまたぐ移動、TalkBack の移動の操作。
- [references/images.md](references/images.md) - `KsImage`、`KsResource` による先読み、`KsImageCache` によるキャッシュの操作。
