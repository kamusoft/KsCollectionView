import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsGroups
import jp.kamusoft.kscollectionview.KsLayout
import jp.kamusoft.kscollectionview.KsReorder
import jp.kamusoft.kscollectionview.KsReorderAccessibilityActions
import jp.kamusoft.kscollectionview.KsReorderDestination
import jp.kamusoft.kscollectionview.KsReorderMove

// グループの値。enum なので Bundle に保存できる (グループの値の条件)。
enum class TaskSection(val title: String) {
    Today("Today"),
    Later("Later"),

    // このグループは、ほかのグループからの項目を受け入れない。
    Pinned("Pinned"),
}

// 項目は equals を持つ不変の値にする。
data class TaskItem(
    val id: Int,
    val title: String,
    val section: TaskSection,
    // true の項目は持ち上がらない (動かせない)。
    val isLocked: Boolean = false,
)

// 画面の状態を持つモデル。配列は同じグループの項目が隣り合う順に保つ。
class ItemListModel(tasks: List<TaskItem>) {
    var tasks by mutableStateOf(tasks)
        private set

    var isReordering by mutableStateOf(true)

    // 項目を持ち上げてよいか。
    fun canMove(task: TaskItem): Boolean = !task.isLocked

    // 候補の位置に落としてよいか。ドラッグ中に何度も呼ばれるので、軽い同期の判定だけにする。
    fun canDrop(move: KsReorderMove<TaskItem>): Boolean {
        val destinationSection = move.group as? TaskSection ?: return false
        // Pinned は、ほかのグループからの項目を受け入れない (Pinned の中での並べ替えはできる)。
        if (destinationSection == TaskSection.Pinned && move.item.section != TaskSection.Pinned) {
            return false
        }
        return true
    }

    // 落としたときに 1 回だけ呼ばれる。配列を並べ替えて、受け入れたかどうかを返す。
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
                // 行き先のグループの値を項目に書き込む。書かないと同じ値が離れた 2 か所に現れる。
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
}

private fun sampleTasks(): List<TaskItem> = listOf(
    TaskItem(id = 1, title = "Write the weekly report", section = TaskSection.Today),
    TaskItem(id = 2, title = "Stand-up meeting", section = TaskSection.Today, isLocked = true),
    TaskItem(id = 3, title = "Review pull requests", section = TaskSection.Today),
    TaskItem(id = 4, title = "Reply to the designer", section = TaskSection.Today),
    TaskItem(id = 5, title = "Plan the next sprint", section = TaskSection.Later),
    TaskItem(id = 6, title = "Update dependencies", section = TaskSection.Later),
    TaskItem(id = 7, title = "Renew the certificate", section = TaskSection.Later, isLocked = true),
    TaskItem(id = 8, title = "Clean up old branches", section = TaskSection.Later),
    TaskItem(id = 9, title = "Team rules", section = TaskSection.Pinned),
    TaskItem(id = 10, title = "On-call contacts", section = TaskSection.Pinned),
    TaskItem(id = 11, title = "Release checklist", section = TaskSection.Pinned),
)

// Material を使わないので、色は自前で持つ。
private class ScreenColors(
    val background: Color,
    val row: Color,
    val header: Color,
    val text: Color,
    val secondaryText: Color,
    val accent: Color,
    val track: Color,
)

@Composable
private fun screenColors(): ScreenColors = if (isSystemInDarkTheme()) {
    ScreenColors(
        background = Color(0xFF121212),
        row = Color(0xFF1E1E1E),
        header = Color(0xFF2A2A2A),
        text = Color(0xFFF2F2F2),
        secondaryText = Color(0xFFB0B0B0),
        accent = Color(0xFF82B1FF),
        track = Color(0xFF555555),
    )
} else {
    ScreenColors(
        background = Color(0xFFF4F4F4),
        row = Color(0xFFFFFFFF),
        header = Color(0xFFE6E6E6),
        text = Color(0xFF1A1A1A),
        secondaryText = Color(0xFF5F5F5F),
        accent = Color(0xFF1565C0),
        track = Color(0xFF9E9E9E),
    )
}

@Composable
fun ItemListScreen(modifier: Modifier = Modifier) {
    val model = remember { ItemListModel(sampleTasks()) }
    val colors = screenColors()

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(colors.background)
            .safeDrawingPadding(),
    ) {
        ReorderSwitchRow(
            checked = model.isReordering,
            onCheckedChange = { model.isReordering = it },
            colors = colors,
        )
        KsCollectionView(
            items = model.tasks,
            key = { it.id },
            // 縦方向に限りのある高さを与える。
            modifier = Modifier.weight(1f).fillMaxWidth(),
            layout = KsLayout.List(groupSpacing = 16.dp),
            groups = KsGroups(by = { it.section }) { section, tasksInSection ->
                SectionHeader(section = section, count = tasksInSection.size, colors = colors)
            },
            reorder = KsReorder(
                enabled = model.isReordering,
                onMove = { move -> model.move(move) },
                canMove = { task -> model.canMove(task) },
                canDrop = { move -> model.canDrop(move) },
                // TalkBack の利用者に出す移動のアクションの名前。ライブラリは文言を持たない。
                accessibilityActions = KsReorderAccessibilityActions(
                    previous = "Move up",
                    next = "Move down",
                ),
            ),
        ) {
            template { task -> TaskRow(task = task, colors = colors) }
        }
    }
}

// 並べ替えのスイッチ。Foundation の部品だけで作る。
@Composable
private fun ReorderSwitchRow(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    colors: ScreenColors,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .toggleable(value = checked, role = Role.Switch, onValueChange = onCheckedChange)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BasicText(
            text = "Reorder",
            style = TextStyle(color = colors.text, fontSize = 18.sp, fontWeight = FontWeight.Medium),
        )
        Box(
            modifier = Modifier
                .background(
                    color = if (checked) colors.accent else colors.track,
                    shape = RoundedCornerShape(50),
                )
                .padding(horizontal = 14.dp, vertical = 6.dp),
        ) {
            BasicText(
                text = if (checked) "ON" else "OFF",
                style = TextStyle(
                    color = colors.background,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                ),
            )
        }
    }
}

// グループの見出し。固定表示されるので、不透明な背景を塗る。
@Composable
private fun SectionHeader(
    section: TaskSection,
    count: Int,
    colors: ScreenColors,
    modifier: Modifier = Modifier,
) {
    val note = if (section == TaskSection.Pinned) " - items from other groups are not accepted" else ""
    BasicText(
        text = "${section.title} ($count)$note",
        style = TextStyle(color = colors.text, fontSize = 14.sp, fontWeight = FontWeight.Bold),
        modifier = modifier
            .fillMaxWidth()
            .background(colors.header)
            .padding(horizontal = 16.dp, vertical = 8.dp),
    )
}

// 1 行の表示。持ち上げたときに下の行が透けないよう、いちばん外側に不透明な背景を塗る。
@Composable
private fun TaskRow(task: TaskItem, colors: ScreenColors, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(colors.row)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BasicText(
            text = task.title,
            style = TextStyle(
                color = if (task.isLocked) colors.secondaryText else colors.text,
                fontSize = 16.sp,
            ),
            modifier = Modifier.weight(1f),
        )
        if (task.isLocked) {
            BasicText(
                text = "Locked",
                style = TextStyle(color = colors.secondaryText, fontSize = 12.sp),
                modifier = Modifier.padding(start = 12.dp),
            )
        }
    }
}
