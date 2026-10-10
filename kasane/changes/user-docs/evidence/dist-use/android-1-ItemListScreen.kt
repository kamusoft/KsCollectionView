import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.rememberKsScrollController

/** 行の種類。テンプレートの切り替えに使う。 */
enum class ListItemKind { Message, Notice }

/** 一覧の 1 件。ID は Int (Bundle に保存できる型) で、一覧の中で重複しない。 */
data class ListItem(val id: Int, val kind: ListItemKind, val title: String, val detail: String)

private const val ListItemCount = 200

// 5 件に 1 件をお知らせにする
private const val NoticeInterval = 5

private val ScreenBackground = Color(0xFFFFFFFF)
private val PrimaryText = Color(0xFF1B1B1F)
private val SecondaryText = Color(0xFF5E5E66)
private val NoticeBackground = Color(0xFFFFF3E0)
private val NoticeAccent = Color(0xFFB3261E)
private val ButtonBackground = Color(0xFF3B5BA9)
private val ButtonText = Color(0xFFFFFFFF)
private val StatusBackground = Color(0xFFECEFF7)

/** ファイルの中だけで完結するデータを作る。 */
private fun buildListItems(): List<ListItem> = List(ListItemCount) { index ->
    if (index % NoticeInterval == 0) {
        ListItem(
            id = index,
            kind = ListItemKind.Notice,
            title = "Notice $index",
            detail = "This row uses the notice template.",
        )
    } else {
        ListItem(
            id = index,
            kind = ListItemKind.Message,
            title = "Message $index",
            detail = "This row uses the message template.",
        )
    }
}

@Composable
fun ItemListScreen(modifier: Modifier = Modifier) {
    val items = remember { buildListItems() }
    // タップされた項目は一覧の外 (親) の状態として持つ
    var tappedItem by remember { mutableStateOf<ListItem?>(null) }
    val scrollController = rememberKsScrollController()

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(ScreenBackground)
            .safeDrawingPadding(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(StatusBackground)
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BasicText(
                text = tappedItem?.let { "Tapped: ${it.title} (id ${it.id})" } ?: "Tapped: none",
                modifier = Modifier.weight(1f),
                style = TextStyle(color = PrimaryText, fontSize = 14.sp),
            )
            SimpleButton(label = "Scroll to top", onClick = { scrollController.scrollToStart() })
        }

        // 高さを限るために weight(1f) を渡す (一覧は自分で縦にスクロールする)
        KsCollectionView(
            items = items,
            key = { it.id },
            modifier = Modifier.weight(1f),
            template = { it.kind },
            onItemTap = { item -> tappedItem = item },
            scrollController = scrollController,
        ) {
            template(ListItemKind.Message) { item -> MessageRow(item) }
            template(ListItemKind.Notice) { item -> NoticeRow(item) }
        }
    }
}

/** 通常の行のテンプレート。 */
@Composable
private fun MessageRow(item: ListItem, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        BasicText(text = item.title, style = TextStyle(color = PrimaryText, fontSize = 16.sp))
        BasicText(text = item.detail, style = TextStyle(color = SecondaryText, fontSize = 13.sp))
    }
}

/** お知らせの行のテンプレート。 */
@Composable
private fun NoticeRow(item: ListItem, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(NoticeBackground)
            .padding(horizontal = 16.dp, vertical = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BasicText(
            text = "!",
            style = TextStyle(color = NoticeAccent, fontSize = 20.sp, fontWeight = FontWeight.Bold),
        )
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            BasicText(
                text = item.title,
                style = TextStyle(color = NoticeAccent, fontSize = 16.sp, fontWeight = FontWeight.Bold),
            )
            BasicText(text = item.detail, style = TextStyle(color = SecondaryText, fontSize = 13.sp))
        }
    }
}

/** Material を使わず、Foundation の部品だけで作るボタン。 */
@Composable
private fun SimpleButton(label: String, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .background(ButtonBackground)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        BasicText(text = label, style = TextStyle(color = ButtonText, fontSize = 14.sp))
    }
}
