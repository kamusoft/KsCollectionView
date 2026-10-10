import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsColumns
import jp.kamusoft.kscollectionview.KsGroups
import jp.kamusoft.kscollectionview.KsLayout

/** 一覧に表示する 1 件。不変の値として扱い、表示を変えるときは新しい List を渡す。 */
data class Item(val id: Int, val title: String, val category: String)

/** 画面で使う色。ライブラリが自前で描く色と同じく isSystemInDarkTheme() に合わせる。 */
private data class ScreenColors(
    val background: Color,
    val cell: Color,
    val groupHeader: Color,
    val text: Color,
    val subText: Color,
)

private val LightColors = ScreenColors(
    background = Color(0xFFFFFFFF),
    cell = Color(0xFFE8EAF0),
    groupHeader = Color(0xFFF5F5F7),
    text = Color(0xFF1C1C1E),
    subText = Color(0xFF6C6C70),
)

private val DarkColors = ScreenColors(
    background = Color(0xFF000000),
    cell = Color(0xFF2C2C2E),
    groupHeader = Color(0xFF1C1C1E),
    text = Color(0xFFF2F2F7),
    subText = Color(0xFFAEAEB2),
)

private val Categories = listOf("Fruits", "Vegetables", "Grains", "Dairy", "Seafood", "Sweets")
private const val ItemsPerCategory = 14

/**
 * ファイル内で完結するデータを作る。
 * 同じグループの項目が配列の中で隣り合うように、カテゴリごとに続けて並べる。
 */
private fun buildItems(): List<Item> =
    Categories.flatMapIndexed { categoryIndex, category ->
        List(ItemsPerCategory) { index ->
            Item(
                id = categoryIndex * 1000 + index,
                title = "$category ${index + 1}",
                category = category,
            )
        }
    }

@Composable
fun ItemListScreen(modifier: Modifier = Modifier) {
    val items = remember { buildItems() }
    val colors = if (isSystemInDarkTheme()) DarkColors else LightColors

    KsCollectionView(
        items = items,
        key = { it.id },
        modifier = modifier
            .fillMaxSize()
            .background(colors.background)
            .safeDrawingPadding(),
        // 列数は、縦長のとき 2 列、横長のとき 4 列。
        layout = KsLayout.Grid(
            columns = KsColumns.Fixed(portrait = 2, landscape = 4),
            rowSpacing = 8.dp,
            columnSpacing = 8.dp,
            groupSpacing = 24.dp,
            headerItemSpacing = 8.dp,
        ),
        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 12.dp),
        // コレクション全体のヘッダー。最初のグループの上に置かれ、内容と一緒にスクロールする。
        header = { CollectionHeader(itemCount = items.size, colors = colors) },
        // グループヘッダー。pinnedHeaders は既定で true なので、グループが見えている間は上端に留まる。
        groups = KsGroups(by = { it.category }) { category, itemsInGroup ->
            GroupHeader(title = category, count = itemsInGroup.size, colors = colors)
        },
    ) {
        template { item -> ItemCell(item = item, colors = colors) }
    }
}

@Composable
private fun CollectionHeader(itemCount: Int, colors: ScreenColors) {
    Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 16.dp)) {
        BasicText(
            text = "Items",
            style = TextStyle(color = colors.text, fontSize = 28.sp, fontWeight = FontWeight.Bold),
        )
        BasicText(
            text = "$itemCount items in ${Categories.size} groups",
            style = TextStyle(color = colors.subText, fontSize = 14.sp),
        )
    }
}

@Composable
private fun GroupHeader(title: String, count: Int, colors: ScreenColors) {
    // 留まっているヘッダーの後ろを行がスクロールするので、背景は不透明にする。
    // 余白を作るための上下の padding は付けない (間隔は groupSpacing と headerItemSpacing で作る)。
    BasicText(
        text = "$title ($count)",
        style = TextStyle(color = colors.text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold),
        modifier = Modifier
            .fillMaxWidth()
            .background(colors.groupHeader)
            .padding(8.dp),
    )
}

@Composable
private fun ItemCell(item: Item, colors: ScreenColors) {
    // グリッドの行の高さを揃えるため、どのセルも同じ高さにする。
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(80.dp)
            .background(colors.cell),
        contentAlignment = Alignment.Center,
    ) {
        BasicText(
            text = item.title,
            style = TextStyle(color = colors.text, fontSize = 14.sp),
        )
    }
}
