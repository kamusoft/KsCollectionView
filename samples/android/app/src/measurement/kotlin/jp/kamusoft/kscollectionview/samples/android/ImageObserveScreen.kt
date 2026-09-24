package jp.kamusoft.kscollectionview.samples.android

import android.os.SystemClock
import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.boundsInWindow
import androidx.compose.ui.layout.onGloballyPositioned
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsPrefetchDestination
import kotlinx.coroutines.delay

/** スクロールが止まったとみなすまでの、位置の変化が無い時間 (ミリ秒)。 */
private const val SettleQuietMillis = 300L

/** 止まったかどうかを確かめる間隔 (ミリ秒)。 */
private const val SettlePollMillis = 50L

/**
 * 「画像グリッド」の土俵で、セルの出入りとスクロールが止まった時点を logcat へ出す観測用の画面。
 *
 * 画像の読み込みの節目 ([installImageLoadingObserver] の行) と同じタグ・同じ時計 (`t=`、起動からの
 * 経過ミリ秒) で出すため、「止めてから画像が揃うまで」の内訳をログだけで組み立てられる。
 * - `cell-enter id=<ID>` / `cell-leave id=<ID>`: セルが組まれた / 破棄された時点。組まれるのは
 *   画面に入る前 (進行方向の先行合成) のこともある
 * - `cell-visible id=<ID>`: 組まれた後、セルが初めて見える範囲に重なった時点
 * - `settled t=<止まった時刻> visible=<ID,...>`: 位置の変化が止まった時点と、そのとき見える範囲に
 *   重なっているセル。止まった時刻は最後に位置が変わった時刻で、検出した時刻ではない
 * - `loading-enter id=<ID>`: 画像の読み込み中の表示が組み立てられた時点。画面に出る前 (先行合成)
 *   のこともあり、画面に出ないまま画像に替わることもある
 * - `loading-shown id=<ID>`: 読み込み中の表示が実際に画面に出た (置かれて描かれ、見える範囲に
 *   掛かった) 時点。1 つの表示につき 1 回
 *
 * メモリの項目を引き当てたセルはローダーへ要求を出さないため、読み込みの節目には現れない。
 * ただし要求の有無だけでは「読み込み中を経由したか」は決まらない。画面に出る前に組まれたセルは、
 * 先読みが未完了だと読み込み中の表示を組み立てて待ち、画面に出る時点で先読みの項目に当たれば
 * 読み込み中を描かずに画像を出す。読み込み中を経由したかは `loading-shown` の有無で読み、
 * `loading-enter` だけがあるセルは、読み込み中を組み立てたが画面には出さなかったと読む。
 *
 * 読み込み中の表示は観測のために差し替えるが、見た目は本体の既定の表示 (無地) と同じにする。
 * 数えることが要求された実行 ([ImageLoadingSlotCounter]) では、その数える表示を中に置き、
 * 観測の行と計数の両方を出す。
 *
 * 位置の観測のためにセルを箱で包み、位置の変化のたびに記録する。フレーム時間を測る土俵ではない。
 *
 * @param count 土俵の件数
 * @param choice プリフェッチの形
 */
@Composable
fun ImageObserveScreen(
    count: Int,
    choice: ImagePrefetchChoice,
    modifier: Modifier = Modifier,
) {
    val items = remember(count) { ImageGridFixture.items(count) }
    val tracker = remember { SettleTracker() }

    LaunchedEffect(tracker) {
        while (true) {
            delay(SettlePollMillis)
            tracker.reportIfSettled(SystemClock.uptimeMillis())
        }
    }

    KsCollectionView(
        items = items,
        key = { it.id },
        modifier = modifier.fillMaxSize().onGloballyPositioned { coordinates ->
            tracker.setViewport(coordinates.boundsInWindow())
        },
        layout = ImageGridFixture.layout,
        contentPadding = ImageGridFixture.contentPadding,
        prefetchResources = ImageGridFixture.resources(choice),
        prefetchDestination = choice.destination ?: KsPrefetchDestination.Disk,
    ) {
        template { item ->
            DisposableEffect(item.id) {
                log("cell-enter id=${item.id}")
                onDispose {
                    tracker.remove(item.id)
                    log("cell-leave id=${item.id}")
                }
            }
            Box(
                modifier = Modifier.fillMaxWidth().onGloballyPositioned { coordinates ->
                    tracker.update(item.id, coordinates.boundsInWindow(), SystemClock.uptimeMillis())
                },
            ) {
                val counted = ImageLoadingSlotCounter.rememberLoadingSlot(item.id)
                val loading: @Composable () -> Unit = remember(item.id, counted) {
                    { ObservedLoadingSlot(item.id, counted) }
                }
                ImageGridCell(item, loading = loading)
            }
        }
    }
}

/**
 * 観測用の読み込み中の表示。組み立てられた時点と、実際に画面に出た時点を 1 行ずつ出す。
 *
 * @param itemId 読み込み中を出している要素の識別子
 * @param inner 中に置く表示。数えることが要求されていれば数える表示、無ければ null
 */
@Composable
internal fun ObservedLoadingSlot(itemId: Int, inner: (@Composable () -> Unit)?) {
    // 1 つの表示につき 1 回。組み直し (再コンポジション) では出さない。
    DisposableEffect(Unit) {
        log("loading-enter id=$itemId")
        onDispose {}
    }
    Box(
        modifier = Modifier
            .fillMaxSize()
            .onLoadingSlotShown { log("loading-shown id=$itemId") },
    ) {
        if (inner != null) {
            inner()
        } else {
            Box(modifier = Modifier.fillMaxSize().background(ObservedLoadingColor))
        }
    }
}

// 本体の既定の読み込み中表示と同じ無彩色。テーマには依存しない固定値。
private val ObservedLoadingColor = Color(0xFFE0E0E0)

/** 観測の 1 行を出す。時刻は起動からの経過ミリ秒。 */
private fun log(message: String) {
    Log.i(ImageLoadingObserveTag, "$message t=${SystemClock.uptimeMillis()}")
}

/**
 * セルの位置を覚え、位置の変化が止まった時点を 1 度だけ報告する。
 *
 * すべて主スレッド (配置の通知とその上で動く効果) から触る。
 */
private class SettleTracker {
    private var viewport: Rect = Rect.Zero
    private val bounds = HashMap<Int, Rect>()
    // 組まれてから見える範囲に重なったことのあるセル。破棄で外す。
    private val shown = HashSet<Int>()
    private var lastMoveAt = 0L
    private var reported = true

    fun setViewport(rect: Rect) {
        viewport = rect
    }

    fun update(id: Int, rect: Rect, now: Long) {
        val previous = bounds.put(id, rect)
        if (previous != rect) {
            lastMoveAt = now
            reported = false
        }
        if (id !in shown && !viewport.isEmpty && !rect.isEmpty && rect.overlaps(viewport)) {
            shown += id
            Log.i(ImageLoadingObserveTag, "cell-visible id=$id t=$now")
        }
    }

    fun remove(id: Int) {
        bounds.remove(id)
        shown -= id
    }

    /** 最後の変化から一定時間動いていなければ、止まった時点と見えているセルを報告する。 */
    fun reportIfSettled(now: Long) {
        if (reported || now - lastMoveAt < SettleQuietMillis || viewport.isEmpty) return
        reported = true
        val visible = bounds.filterValues { !it.isEmpty && it.overlaps(viewport) }.keys.sorted()
        Log.i(
            ImageLoadingObserveTag,
            "settled t=$lastMoveAt detected=$now visible=${visible.joinToString(",")}",
        )
    }
}
