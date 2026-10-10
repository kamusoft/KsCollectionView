import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsColumns
import jp.kamusoft.kscollectionview.KsImage
import jp.kamusoft.kscollectionview.KsImageSource
import jp.kamusoft.kscollectionview.KsLayout
import jp.kamusoft.kscollectionview.KsPrefetchDestination
import jp.kamusoft.kscollectionview.KsResource
import jp.kamusoft.kscollectionview.KsWidth

/**
 * 一覧の 1 件。
 *
 * [id] は変わらない識別子で、一覧の ID と画像のキーの両方に使う。
 * [signedUrl] は期限付きの署名が付いた URL で、同じ画像でも取り直すたびに変わる。
 */
data class Item(
    val id: String,
    val title: String,
    val signedUrl: String,
)

// 表示用の画像の指定。URL はダウンロードにだけ使われ、キャッシュは key で識別される。
private val Item.imageSource: KsImageSource
    get() = KsImageSource.Remote(signedUrl, key = id)

// 先読み用の指定。表示側と同じ key を 1 か所 (id) から作り、食い違いを防ぐ。
private val Item.prefetchResource: KsResource
    get() = KsResource(signedUrl, width = KsWidth.Column, key = id)

private const val ItemCount = 120
private const val ColumnCount = 3

/**
 * サンプルデータを作る。
 *
 * [generation] が変わると署名のクエリ文字列だけが変わり、id (= 画像のキー) は変わらない。
 * サムネイルの大きさで配信される URL を想定している。
 */
private fun sampleItems(generation: Int): List<Item> =
    List(ItemCount) { index ->
        val id = "image-$index"
        Item(
            id = id,
            title = "Image $index",
            signedUrl = "https://example.com/thumbnails/$id.jpg" +
                "?expires=${1_800_000_000L + generation * 3_600L}&signature=sig-$generation-$index",
        )
    }

@Composable
fun ItemListScreen(modifier: Modifier = Modifier) {
    // 署名付き URL を取り直した回数。増やすと URL だけが変わった新しいリストになる。
    var generation by rememberSaveable { mutableIntStateOf(0) }
    val items = remember(generation) { sampleItems(generation) }

    Column(modifier = modifier.fillMaxSize().safeDrawingPadding()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BasicText(text = "URL generation: $generation")
            RenewButton(onClick = { generation += 1 })
        }
        KsCollectionView(
            items = items,
            key = { it.id },
            modifier = Modifier.weight(1f),
            layout = KsLayout.Grid(
                columns = KsColumns.Fixed(ColumnCount),
                rowSpacing = 2.dp,
                columnSpacing = 2.dp,
            ),
            contentPadding = PaddingValues(2.dp),
            // もうすぐ表示される項目の画像を先読みする。
            prefetchResources = { item -> listOf(item.prefetchResource) },
            // デコードしてメモリまで載せ、表示時に読み込み中の表示を出さない。
            prefetchDestination = KsPrefetchDestination.Memory,
        ) {
            template { item -> ItemCell(item) }
        }
    }
}

@Composable
private fun ItemCell(item: Item, modifier: Modifier = Modifier) {
    Column(modifier = modifier.fillMaxWidth()) {
        KsImage(
            source = item.imageSource,
            // KsImage は大きさを与えないと高さ 0 になるので、必ず指定する。
            modifier = Modifier.fillMaxWidth().aspectRatio(1f),
            contentDescription = item.title,
        )
        BasicText(
            text = item.title,
            modifier = Modifier.padding(4.dp),
            style = TextStyle(fontSize = 12.sp),
        )
    }
}

// Material が使えないので、Foundation の部品でボタンを組み立てる。
@Composable
private fun RenewButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    BasicText(
        text = "Renew URLs",
        modifier = modifier
            .background(Color(0xFF3366CC))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        style = TextStyle(color = Color.White, fontSize = 14.sp),
    )
}
