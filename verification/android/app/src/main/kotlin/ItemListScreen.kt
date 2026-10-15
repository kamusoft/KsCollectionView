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
