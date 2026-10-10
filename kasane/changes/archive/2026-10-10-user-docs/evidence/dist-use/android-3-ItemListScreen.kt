import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.io.IOException
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsPaging
import jp.kamusoft.kscollectionview.KsPagingState
import kotlin.random.Random
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay

// ---------------------------------------------------------------------------
// モデル
// ---------------------------------------------------------------------------

/** 一覧の 1 件。ID は Int で、一覧の中で一意かつ不変。 */
data class ListItem(val id: Int, val title: String, val subtitle: String)

/** 1 ページ分の取得結果。 */
private data class ListItemPage(val items: List<ListItem>, val hasMore: Boolean)

private const val PageSize = 20
private const val DefaultTotalCount = 95
private const val DefaultFailureRate = 0.3f
private const val FetchDelayMillis = 900L

/**
 * ファイル内で完結する偽のデータ源。
 * 遅延のあと、一定の確率で IOException を投げる。
 */
private class FakeItemService(
    private val totalCount: Int,
    private val failureRate: Float,
    private val random: Random = Random.Default,
) {
    /** afterId が null なら最初のページ、そうでなければその ID の次からのページを返す。 */
    suspend fun fetchPage(afterId: Int?): ListItemPage {
        delay(FetchDelayMillis)
        if (random.nextFloat() < failureRate) {
            throw IOException("偽のデータ源の失敗")
        }
        val start = if (afterId == null) 0 else afterId + 1
        val end = minOf(start + PageSize, totalCount)
        val items = (start until end).map { index ->
            ListItem(id = index, title = "Item ${index + 1}", subtitle = "Page ${index / PageSize + 1}")
        }
        return ListItemPage(items = items, hasMore = end < totalCount)
    }
}

/**
 * 配列とページングの状態を持つモデル。
 * 状態の遷移はライブラリが強制しないので、Skill (paging.md) の FeedModel の形に従う。
 */
private class ItemListModel(private val service: FakeItemService) {
    var items by mutableStateOf(listOf<ListItem>())
        private set

    var pagingState by mutableStateOf(KsPagingState.Idle)
        private set

    /** 項目が表示されている状態で引っ張って更新が失敗したときの通知。 */
    var refreshFailed by mutableStateOf(false)
        private set

    // 更新を始めたら、それより前に始めた読み込みの結果を捨てるための世代番号。
    private var generation = 0

    /** 次のページ (配列が空なら最初のページ) を読む。Failed からの再試行もここに来る。 */
    suspend fun loadNextPage() {
        if (pagingState != KsPagingState.Idle && pagingState != KsPagingState.Failed) return
        val started = generation
        pagingState = KsPagingState.Appending
        try {
            val page = service.fetchPage(afterId = items.lastOrNull()?.id)
            if (started != generation) return
            // 配列と次の状態は、間に中断点を置かずに続けて書く。
            items = items + page.items
            pagingState = if (page.hasMore) KsPagingState.Idle else KsPagingState.EndReached
        } catch (cancellation: CancellationException) {
            // キャンセルを Failed にしない。状態を戻して投げ直す。
            if (started == generation) pagingState = KsPagingState.Idle
            throw cancellation
        } catch (failure: IOException) {
            if (started != generation) return
            pagingState = KsPagingState.Failed
        }
    }

    /** 最初のページから読み直す (引っ張って更新)。 */
    suspend fun refresh() {
        generation += 1
        val started = generation
        val previous = pagingState
        pagingState = KsPagingState.Refreshing
        refreshFailed = false
        try {
            val page = service.fetchPage(afterId = null)
            if (started != generation) return
            items = page.items
            pagingState = if (page.hasMore) KsPagingState.Idle else KsPagingState.EndReached
        } catch (cancellation: CancellationException) {
            if (started == generation) pagingState = restored(previous)
            throw cancellation
        } catch (failure: IOException) {
            if (started != generation) return
            if (items.isEmpty()) {
                // 項目が無いときは Failed にして「項目なしの失敗」の表示を出す。
                pagingState = KsPagingState.Failed
            } else {
                // 項目があるときは Failed にせず、状態を戻して自前で知らせる。
                pagingState = restored(previous)
                refreshFailed = true
            }
        }
    }

    fun dismissRefreshFailed() {
        refreshFailed = false
    }

    private fun restored(previous: KsPagingState): KsPagingState = when (previous) {
        KsPagingState.Appending, KsPagingState.Refreshing -> KsPagingState.Idle
        KsPagingState.Idle, KsPagingState.Failed, KsPagingState.EndReached -> previous
    }
}

// ---------------------------------------------------------------------------
// 色 (Material が無いので、システムのダークテーマに合わせて自前で決める)
// ---------------------------------------------------------------------------

private data class ScreenColors(
    val background: Color,
    val text: Color,
    val secondaryText: Color,
    val accent: Color,
    val onAccent: Color,
    val noticeBackground: Color,
    val noticeText: Color,
)

@Composable
private fun screenColors(): ScreenColors =
    if (isSystemInDarkTheme()) {
        ScreenColors(
            background = Color(0xFF121212),
            text = Color(0xFFEDEDED),
            secondaryText = Color(0xFFA0A0A0),
            accent = Color(0xFF8AB4F8),
            onAccent = Color(0xFF10233F),
            noticeBackground = Color(0xFFEDEDED),
            noticeText = Color(0xFF202020),
        )
    } else {
        ScreenColors(
            background = Color(0xFFFFFFFF),
            text = Color(0xFF1C1C1C),
            secondaryText = Color(0xFF6B6B6B),
            accent = Color(0xFF1A5FB4),
            onAccent = Color(0xFFFFFFFF),
            noticeBackground = Color(0xFF323232),
            noticeText = Color(0xFFFFFFFF),
        )
    }

// ---------------------------------------------------------------------------
// 部品
// ---------------------------------------------------------------------------

/** Foundation の部品だけで作ったボタン。 */
@Composable
private fun SimpleButton(
    text: String,
    onClick: () -> Unit,
    colors: ScreenColors,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .background(colors.accent, RoundedCornerShape(50))
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 10.dp),
        contentAlignment = Alignment.Center,
    ) {
        BasicText(
            text = text,
            style = TextStyle(color = colors.onAccent, fontSize = 14.sp, fontWeight = FontWeight.Medium),
        )
    }
}

@Composable
private fun ItemRow(item: ListItem, colors: ScreenColors, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        BasicText(text = item.title, style = TextStyle(color = colors.text, fontSize = 16.sp))
        BasicText(text = item.subtitle, style = TextStyle(color = colors.secondaryText, fontSize = 13.sp))
    }
}

/** メッセージと再試行ボタンを縦に並べた失敗の表示。フッターと項目なしの両方で使う。 */
@Composable
private fun FailureDisplay(
    message: String,
    retry: () -> Unit,
    colors: ScreenColors,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        BasicText(text = message, style = TextStyle(color = colors.text, fontSize = 14.sp))
        SimpleButton(text = "Retry", onClick = retry, colors = colors)
    }
}

// ---------------------------------------------------------------------------
// 画面
// ---------------------------------------------------------------------------

/**
 * ページングと引っ張って更新を備えた一覧の画面。
 *
 * @param totalCount 偽のデータ源が持つ全件数。0 にすると「項目なし」の表示を確かめられる。
 * @param failureRate 偽のデータ源が 1 回の取得で失敗する確率 (0〜1)。
 */
@Composable
fun ItemListScreen(
    modifier: Modifier = Modifier,
    totalCount: Int = DefaultTotalCount,
    failureRate: Float = DefaultFailureRate,
) {
    val model = remember(totalCount, failureRate) {
        ItemListModel(FakeItemService(totalCount = totalCount, failureRate = failureRate))
    }
    val colors = screenColors()

    Box(modifier = modifier.fillMaxSize().background(colors.background).safeDrawingPadding()) {
        KsCollectionView(
            items = model.items,
            key = { it.id },
            modifier = Modifier.fillMaxSize(),
            paging = KsPaging(
                state = model.pagingState,
                // 最初の読み込みも一覧からの要求に任せる (自分では始めない)。
                onLoadMore = { model.loadNextPage() },
                failedFooter = { retry ->
                    FailureDisplay(
                        message = "Could not load more items",
                        retry = retry,
                        colors = colors,
                        modifier = Modifier.fillMaxWidth().padding(16.dp),
                    )
                },
                endReachedFooter = {
                    BasicText(
                        text = "No more items",
                        style = TextStyle(color = colors.secondaryText, fontSize = 13.sp),
                        modifier = Modifier.padding(16.dp),
                    )
                },
                failedPlaceholder = { retry ->
                    FailureDisplay(
                        message = "Could not load items",
                        retry = retry,
                        colors = colors,
                        modifier = Modifier.padding(24.dp),
                    )
                },
                emptyPlaceholder = {
                    BasicText(
                        text = "No items",
                        style = TextStyle(color = colors.secondaryText, fontSize = 16.sp),
                        modifier = Modifier.padding(24.dp),
                    )
                },
            ),
            onRefresh = { model.refresh() },
            loadingIndicatorColor = colors.accent,
        ) {
            template { item -> ItemRow(item, colors) }
        }

        // 項目が表示されたまま更新が失敗したときの通知。タップで消える。
        if (model.refreshFailed) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .padding(top = 8.dp)
                    .background(colors.noticeBackground, RoundedCornerShape(50))
                    .clickable(onClick = model::dismissRefreshFailed)
                    .padding(horizontal = 14.dp, vertical = 8.dp),
            ) {
                BasicText(
                    text = "Could not refresh",
                    style = TextStyle(color = colors.noticeText, fontSize = 13.sp),
                )
            }
        }
    }
}
