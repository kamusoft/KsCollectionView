package jp.kamusoft.kscollectionview

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.MutatePriority
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.lazy.grid.LazyGridItemInfo
import androidx.compose.foundation.lazy.grid.LazyGridLayoutInfo
import androidx.compose.foundation.lazy.grid.LazyGridState
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.AwaitPointerEventScope
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.PointerId
import androidx.compose.ui.input.pointer.PointerInputScope
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.util.fastFirstOrNull
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/**
 * 一覧 1 つ分の並べ替えの状態 (android/ADR-0007)。
 *
 * 長押しで持ち上げた項目のドラッグ、ドラッグ中の仮の並び、置いた後の戻りの動き、受け入れた後に VM の配列を
 * 待つ間の並びを持つ。利用者の配列は書き換えず、表示する並びだけを [shown] で差し替える (core/ADR-0026)。
 *
 * ドラッグが始まってから、置いて受け入れの結果が出るまで (受け入れなかったときは元の位置へ戻り終えるまで) を
 * 「控えている間」とし、その間に届いた配列は表示に当てない (core/ADR-0033)。次ページ要求の判定と
 * スクロール命令の実行も、控えている間は止める (core/ADR-0034、core/ADR-0007)。
 *
 * 状態のうちコンポジション・配置が読むものは snapshot state に置く。一覧の最新の値 (表示中の並び・構成・
 * 設定) は、コンポジションの反映のたびに [bind] で受け取る。
 */
@Stable
internal class KsReorderController<Item>(
    private val gridState: LazyGridState,
    private val scope: CoroutineScope,
) {
    /** ドラッグ中 (と、受け入れなかったときの戻りの間) の状態。控えている間だけ non-null。 */
    var drag: KsReorderDrag<Item>? by mutableStateOf(null)
        private set

    /** 置いた後に、持ち上げた項目を置き場所へ落ち着かせる動き。 */
    var settle: KsReorderSettle? by mutableStateOf(null)
        private set

    /** 受け入れた後、VM の配列を待つ間の並び。 */
    var awaiting: KsReorderAwait<Item>? by mutableStateOf(null)
        private set

    /** 表示に届いた配列を当てずに控えている間か。 */
    val isHolding: Boolean get() = drag != null

    /** 持ち上げて描いている項目のキー。無ければ null。 */
    val liftedKey: Any?
        get() {
            val current = drag
            if (current != null && !current.isReleased) return current.key
            return settle?.key
        }

    private var binding: KsReorderBinding<Item>? = null
    private var autoScrollJob: Job? = null

    /** 一覧の最新の値を受け取る。コンポジションの反映のたびに呼ぶ。 */
    fun bind(binding: KsReorderBinding<Item>) {
        this.binding = binding
        // 描いた並びを控える。指の下の項目を lazy の index から引くときに、配置と同じ並びで引くため。
        drag?.let { current ->
            current.composedItems = binding.items
            current.composedPlan = binding.plan
        }
    }

    /** 受け入れた後に待っていた配列と違う配列が届いた、または構成が変わったので、待つのをやめる。 */
    fun stopAwaiting() {
        awaiting = null
    }

    /**
     * 今表示する並び。控えている間はドラッグの並び、受け入れた後に待っている間は置いた並び。
     * それ以外 (届いた配列をそのまま表示する) は null。
     *
     * @param incoming 届いた配列
     * @param originalPlan 控えている間に元の並びを表示するときの構成 (今のグループの宣言で組んだもの)
     * @param leadingCount ルートのヘッダーの数
     * @param hasFooter ルートのフッターの枠を置くか
     */
    fun shown(
        incoming: List<Item>,
        originalPlan: () -> KsGroupPlan,
        leadingCount: Int,
        hasFooter: Boolean,
        cancelsDrag: Boolean,
        awaitingMatches: (KsReorderAwait<Item>) -> Boolean,
    ): KsReorderShown<Item>? {
        val current = drag
        if (current != null) {
            val placement = current.placement
            if (cancelsDrag || current.isCancelled || placement == current.original) {
                return KsReorderShown(current.baseItems, originalPlan())
            }
            return KsReorderShown(
                items = current.renderedItems(placement),
                plan = current.planner.movedPlan(current.source, placement, keepsEmptyGroups = true)
                    .withRootSlots(leadingCount, hasFooter),
            )
        }
        val waiting = awaiting ?: return null
        if (!awaitingMatches(waiting) || !(incoming === waiting.incoming || incoming == waiting.incoming)) return null
        return KsReorderShown(waiting.items, waiting.plan.withRootSlots(leadingCount, hasFooter))
    }

    // ---- 持ち上げ・ドラッグ・置く ----

    /** 長押しの位置 [pointer] (一覧の座標) の項目を持ち上げる。持ち上げたら true。 */
    fun lift(pointer: Offset): Boolean {
        val bound = binding ?: return false
        val reorder = bound.reorder ?: return false
        if (!reorder.enabled || drag != null || settle != null) return false
        val info = gridState.layoutInfo
        val point = info.toItemSpace(pointer)
        val touched = info.visibleItemsInfo.filter { it.contains(point) }
        // 見出し・ルートのヘッダー / フッターは項目より手前に描かれるため、重なっていればそちらを触ったとみなす。
        if (touched.any { bound.plan.itemIndexOfLazy(it.index) < 0 }) return false
        val entry = touched.firstOrNull() ?: return false
        val index = bound.plan.itemIndexOfLazy(entry.index)
        if (index !in bound.items.indices) return false
        val item = bound.items[index]
        if (reorder.canMove?.invoke(item) == false) return false
        val planner = KsReorderPlanner(bound.plan)
        drag = KsReorderDrag(
            key = entry.key,
            source = index,
            baseItems = bound.items,
            basePlan = bound.plan,
            valuesPlan = bound.valuesPlan,
            isGrouped = bound.isGrouped,
            planner = planner,
            original = planner.originalPlacement(index),
            layout = bound.layout,
            groupDeclaration = bound.groupDeclaration,
            pointer = pointer,
        )
        drag?.liftHeight = entry.size.height
        drag?.liftGrabY = point.y - entry.offset.y
        bound.haptics?.performHapticFeedback(HapticFeedbackType.LongPress)
        startAutoScroll()
        return true
    }

    /**
     * ドラッグ中の指が [pointer] (一覧の座標) へ動いた。
     *
     * 指が一覧の外枠の外で離されたら元の位置へ戻す (ほかの一覧やアプリの外には置けない)。外枠の左右の外にある
     * 間は行き先を動かさない。上下の外は端での自動スクロールの範囲なので、いちばん近い項目で行き先を求める。
     *
     * @param size 一覧の外枠の大きさ
     */
    fun moveTo(pointer: Offset, size: IntSize) {
        val current = drag ?: return
        if (current.isReleased || current.isCancelled) return
        current.pointer = pointer
        val outsideHorizontally = pointer.x < 0f || pointer.x > size.width
        current.isOutside = outsideHorizontally || pointer.y < 0f || pointer.y > size.height
        if (!outsideHorizontally) retarget()
    }

    /** 指を離した。行き先に置いて知らせるか、元の位置へ戻す。 */
    fun drop() {
        val current = drag ?: return
        if (current.isReleased) return
        current.isReleased = true
        stopAutoScroll()
        if (current.isCancelled) return
        val from = current.visualTopLeft()
        val placement = current.placement
        if (current.isOverForbidden || current.isOutside || placement == current.original) {
            returnToOriginal(current, from)
            return
        }
        val bound = binding
        val reorder = bound?.reorder
        val move = current.moveFor(placement)
        // 置く直前に、最新の「ここに置けるか」で判定し直す。ドラッグ中に判定の条件が変わり、指が同じ行き先に
        // 留まっている間に置けなくなった場合も、置かずに元の位置へ戻す (core/ADR-0030)。
        if (move != null && reorder?.canDrop?.invoke(move) == false) {
            returnToOriginal(current, from)
            return
        }
        val accepted = reorder != null && reorder.enabled && move != null && reorder.onMove(move)
        if (!accepted) {
            returnToOriginal(current, from)
            return
        }
        // 受け入れたら、控えた配列を捨てて置いた並びのまま VM の配列を待つ (core/ADR-0027、core/ADR-0033)。
        // 項目が無くなったグループは、この時点で見出しごと取り除く (core/ADR-0029)。
        val target = current.planner.targetIndex(current.source, placement)
        awaiting = KsReorderAwait(
            incoming = bound.incoming,
            items = KsReorderedList(current.baseItems, current.source, target),
            plan = current.planner.movedPlan(current.source, placement, keepsEmptyGroups = false),
            groupDeclaration = current.groupDeclaration,
        )
        drag = null
        startSettle(current.key, from, onEnd = null)
    }

    /**
     * ドラッグを取りやめる (スイッチの無効化・layout 値かグループの宣言の変化・操作の中断)。項目を元の位置へ
     * 戻し、置いたときの処理は呼ばない。控えた配列は戻り終えてから当てる。
     */
    fun cancel() {
        val current = drag ?: return
        if (current.isCancelled) return
        current.isCancelled = true
        stopAutoScroll()
        if (current.isReleased) return
        current.isReleased = true
        returnToOriginal(current, current.visualTopLeft())
    }

    private fun returnToOriginal(current: KsReorderDrag<Item>, from: Offset?) {
        current.placement = current.original
        current.isOverForbidden = false
        startSettle(current.key, from) {
            if (drag === current) drag = null
        }
    }

    private fun startSettle(key: Any, from: Offset?, onEnd: (() -> Unit)?) {
        if (from == null) {
            onEnd?.invoke()
            return
        }
        val motion = KsReorderSettle(key, from, Animatable(0f))
        settle = motion
        scope.launch {
            try {
                motion.progress.animateTo(1f, KsReorderSettleSpec)
            } finally {
                if (settle === motion) settle = null
                onEnd?.invoke()
            }
        }
    }

    // ---- 読み上げの移動操作 ----

    /**
     * 読み上げの操作で、キー [key] の項目を 1 つ前 ([forward] が false) か 1 つ後ろへ動かす。
     * 行き先が無い・置けない・受け入れられなかったときは false。
     */
    fun performAccessibilityMove(key: Any, forward: Boolean): Boolean {
        if (drag != null) return false
        val bound = binding ?: return false
        val reorder = bound.reorder ?: return false
        if (!reorder.enabled) return false
        val index = bound.items.indexOfFirst { bound.key(it) == key }
        if (index < 0) return false
        val planner = KsReorderPlanner(bound.plan)
        val placement = (if (forward) planner.nextPlacement(index) else planner.previousPlacement(index)) ?: return false
        val move = moveFor(bound, index, placement) ?: return false
        if (reorder.canDrop?.invoke(move) == false) return false
        if (!reorder.onMove(move)) return false
        awaiting = KsReorderAwait(
            incoming = bound.incoming,
            items = KsReorderedList(bound.items, index, planner.targetIndex(index, placement)),
            plan = planner.movedPlan(index, placement, keepsEmptyGroups = false),
            groupDeclaration = bound.groupDeclaration,
        )
        return true
    }


    // ---- 持ち上げた項目の描き方 ----

    /**
     * キー [key] の項目を、配置された位置 [placed] (一覧の座標の左上) からどれだけずらして描くか。持ち上げて
     * いない項目は null。
     *
     * ドラッグ中は指の下に、置いた後は置いた位置からの戻りの途中に描く。持ち上げてから最初に配置されたときに、
     * 項目の左上から指までの距離を控える (持ち上げた時点では置き場所は動いていない)。
     */
    fun liftOffset(key: Any, placed: Offset): IntOffset? {
        val current = drag
        if (current != null && !current.isReleased && current.key == key) {
            val grab = current.grab ?: (current.liftPointer - placed).also { current.grab = it }
            return (current.pointer - grab - placed).round()
        }
        val motion = settle
        if (motion != null && motion.key == key) {
            val remaining = 1f - motion.progress.value
            return ((motion.from - placed) * remaining).round()
        }
        return null
    }

    /** 持ち上げた項目の影の濃さ (0〜1)。ドラッグ中は 1、戻りの途中は残りの割合。 */
    fun liftAmount(key: Any): Float {
        val current = drag
        if (current != null && !current.isReleased && current.key == key) return 1f
        val motion = settle
        if (motion != null && motion.key == key) return 1f - motion.progress.value
        return 0f
    }

    // ---- 行き先の追従 ----

    /** 指の位置から行き先を求め直し、置けるなら仮の並びを動かす。 */
    private fun retarget() {
        val current = drag ?: return
        if (current.isReleased || current.isCancelled) return
        val bound = binding ?: return
        val info = gridState.layoutInfo
        val composedPlan = current.composedPlan ?: return
        val composedItems = current.composedItems ?: return
        // 配置がまだ描いた並びに追いついていない (件数が食い違う) 間は求めない。
        if (info.totalItemsCount != composedPlan.totalLazyCount) return
        val point = info.toItemSpace(current.pointer)
        val candidate = current.placementAt(point, info, composedPlan, composedItems, bound.columns) ?: return
        if (candidate == current.placement) {
            current.isOverForbidden = false
            return
        }
        if (candidate != current.original) {
            val move = current.moveFor(candidate) ?: return
            if (bound.reorder?.canDrop?.invoke(move) == false) {
                current.isOverForbidden = true
                return
            }
        }
        current.isOverForbidden = false
        keepFirstVisibleItem(current, composedPlan, candidate, bound)
        current.placement = candidate
    }

    /**
     * 仮の並びの入れ替えが表示範囲の先頭の項目にかかるときは、スクロール位置を index で保つ。
     *
     * `LazyGridState` は表示範囲の先頭の項目のキーで位置を保つため、その項目が入れ替わると、持ち上げた項目の
     * 置き場所が表示範囲の外へ押し出されたり、一覧が入れ替わった分だけ跳んだりする。
     */
    private fun keepFirstVisibleItem(
        current: KsReorderDrag<Item>,
        composedPlan: KsGroupPlan,
        candidate: KsReorderPlacement,
        bound: KsReorderBinding<Item>,
    ) {
        val placement = current.placement
        val oldTarget = if (placement == current.original) current.source else current.planner.targetIndex(current.source, placement)
        val oldLazy = composedPlan.lazyIndexOfItem(oldTarget)
        val newPlan = current.planner.movedPlan(current.source, candidate, keepsEmptyGroups = true)
            .withRootSlots(bound.plan.leadingCount, bound.plan.hasFooter)
        val newLazy = newPlan.lazyIndexOfItem(current.planner.targetIndex(current.source, candidate))
        val first = gridState.firstVisibleItemIndex
        if (first in minOf(oldLazy, newLazy)..maxOf(oldLazy, newLazy)) {
            gridState.requestScrollToItem(first, gridState.firstVisibleItemScrollOffset)
        }
    }

    // ---- 端での自動スクロール ----

    private fun startAutoScroll() {
        autoScrollJob?.cancel()
        autoScrollJob = scope.launch {
            while (isActive) {
                // 指が端の近くに入るまで待つ。
                snapshotFlow { autoScrollVelocity() != 0f }.first { it }
                gridState.scroll(MutatePriority.UserInput) {
                    var last = withFrameNanos { it }
                    while (isActive) {
                        val now = withFrameNanos { it }
                        val velocity = autoScrollVelocity()
                        if (velocity == 0f) break
                        scrollBy(velocity * (now - last) / 1_000_000_000f)
                        last = now
                        // スクロールで指の下の項目が変わるため、行き先を求め直す。
                        retarget()
                    }
                }
            }
        }
    }

    private fun stopAutoScroll() {
        autoScrollJob?.cancel()
        autoScrollJob = null
    }

    /**
     * 指の位置に応じた自動スクロールの速さ (px/秒。上向きは負)。端の近くでなければ 0。
     *
     * 反応する範囲は一覧の外枠の上端と下端から測る (安全領域は使わない。core/ADR-0017)。端に近いほど速く、
     * 外枠の外へ出たら最も速くする。その向きにもうスクロールできなければ 0。
     */
    private fun autoScrollVelocity(): Float {
        val current = drag ?: return 0f
        if (current.isReleased || current.isCancelled) return 0f
        val density = binding?.density ?: return 0f
        val height = gridState.layoutInfo.viewportSize.height.toFloat()
        if (height <= 0f) return 0f
        val zone = minOf(with(density) { KsAutoScrollEdge.toPx() }, height / 4f)
        val maxSpeed = with(density) { KsAutoScrollMaxSpeed.toPx() }
        val y = current.pointer.y
        // 端まで送り切った向きには進めない (フレームを回し続けない)。
        return when {
            y < zone && gridState.canScrollBackward -> -maxSpeed * ((zone - y) / zone).coerceIn(0f, 1f)
            y > height - zone && gridState.canScrollForward -> maxSpeed * ((y - (height - zone)) / zone).coerceIn(0f, 1f)
            else -> 0f
        }
    }

    // ---- 知らせ ----

    private fun moveFor(bound: KsReorderBinding<Item>, source: Int, placement: KsReorderPlacement): KsReorderMove<Item>? =
        buildMove(bound.items, bound.valuesPlan, bound.isGrouped, source, placement)
}

/**
 * 表示中の並び [items] の位置 [index] の項目に、読み上げの「1 つ前へ」「1 つ後ろへ」の操作を出せるか。
 * 行き先が無い (一覧の先頭・最後) か、「ここに置けるか」が偽の行き先には出さない (core/ADR-0032)。
 *
 * @param valuesPlan [planner] と同じ構成で、グループの値が最新のもの
 */
internal fun <Item> ksReorderAccessibilityTargets(
    items: List<Item>,
    planner: KsReorderPlanner,
    valuesPlan: KsGroupPlan,
    isGrouped: Boolean,
    canDrop: ((KsReorderMove<Item>) -> Boolean)?,
    index: Int,
): Pair<Boolean, Boolean> {
    fun allowed(placement: KsReorderPlacement?): Boolean {
        if (placement == null) return false
        if (canDrop == null) return true
        val move = buildMove(items, valuesPlan, isGrouped, index, placement) ?: return false
        return canDrop(move)
    }
    return allowed(planner.previousPlacement(index)) to allowed(planner.nextPlacement(index))
}

/** 置いた後に項目を置き場所へ落ち着かせる動きの速さ。配置のアニメーションの既定と同じばね。 */
private val KsReorderSettleSpec = spring<Float>(stiffness = Spring.StiffnessMediumLow)

/** 自動スクロールが反応する、一覧の上端・下端からの範囲。 */
private val KsAutoScrollEdge = 64.dp

/** 自動スクロールの最も速いときの速さ (1 秒あたり)。 */
private val KsAutoScrollMaxSpeed = 1200.dp

/**
 * 一覧 (ラッパー) から並べ替えへ渡す最新の値。
 *
 * @property incoming 利用者から届いた配列 (重複を畳んだもの)
 * @property items 表示中の並び
 * @property plan 表示中の並びのグループの構成 (構成が等しい間は最初に求めたもの)
 * @property valuesPlan [plan] と同じ構成で、グループの値が最新のもの
 * @property isGrouped グループを宣言しているか
 * @property groupDeclaration グループの宣言の目印。ドラッグ中に宣言が変わったかを比べる
 * @property columns 今の列数
 */
internal class KsReorderBinding<Item>(
    val incoming: List<Item>,
    val items: List<Item>,
    val key: (Item) -> Any,
    val plan: KsGroupPlan,
    val valuesPlan: KsGroupPlan,
    val isGrouped: Boolean,
    val groupDeclaration: KsGroupDeclaration,
    val layout: KsLayout,
    val columns: Int,
    val reorder: KsReorder<Item>?,
    val haptics: HapticFeedback?,
    val density: androidx.compose.ui.unit.Density,
)

/**
 * グループの宣言の目印。宣言の有無・グループの値のラムダ・見出しの有無・固定の有無で表す。
 *
 * @property by グループの値のラムダ。宣言していなければ null
 */
internal class KsGroupDeclaration(
    val by: ((Any?) -> Any?)?,
    val hasHeaders: Boolean,
    val pinsHeaders: Boolean,
) {
    /** 宣言が同じか (ラムダは同一性で比べる)。 */
    fun isSame(other: KsGroupDeclaration): Boolean =
        by === other.by && isSameShape(other)

    /** 宣言の有無・見出しの有無・固定の有無が同じか (ラムダは比べない)。 */
    fun isSameShape(other: KsGroupDeclaration): Boolean =
        (by == null) == (other.by == null) && hasHeaders == other.hasHeaders && pinsHeaders == other.pinsHeaders
}

/** 表示する並びと、そのグループの構成。 */
internal class KsReorderShown<Item>(val items: List<Item>, val plan: KsGroupPlan)

/**
 * 受け入れた後、VM の配列を待つ間の並び。
 *
 * @property incoming 受け入れた時点に届いていた配列。これと同じ配列の間は [items] を表示し続ける
 * @property items 置いた並び
 * @property plan 置いた並びのグループの構成 (項目が無くなったグループは取り除いたもの)
 */
internal class KsReorderAwait<Item>(
    val incoming: List<Item>,
    val items: List<Item>,
    val plan: KsGroupPlan,
    val groupDeclaration: KsGroupDeclaration,
)

/**
 * 置いた後に、持ち上げた項目を置き場所へ落ち着かせる動き。
 *
 * @property from 指を離したときに描いていた位置 (一覧の座標の左上)
 * @property progress 0 から 1 へ進む。1 で置き場所に重なる
 */
internal class KsReorderSettle(
    val key: Any,
    val from: Offset,
    val progress: Animatable<Float, *>,
)

/**
 * 1 回のドラッグの状態。
 *
 * @property source 持ち上げた項目の、持ち上げたときの並びでの位置
 * @property baseItems 持ち上げたときの並び
 * @property basePlan 持ち上げたときの並びのグループの構成
 * @property original 元の位置の行き先
 */
@Stable
internal class KsReorderDrag<Item>(
    val key: Any,
    val source: Int,
    val baseItems: List<Item>,
    val basePlan: KsGroupPlan,
    private val valuesPlan: KsGroupPlan,
    private val isGrouped: Boolean,
    val planner: KsReorderPlanner,
    val original: KsReorderPlacement,
    val layout: KsLayout,
    val groupDeclaration: KsGroupDeclaration,
    pointer: Offset,
) {
    /** 持ち上げたときの指の位置 (一覧の座標)。 */
    val liftPointer: Offset = pointer

    /** 持ち上げた項目の左上から指までの距離。持ち上げてから最初に配置されたときに控える。 */
    var grab: Offset? = null

    /** 持ち上げたときの項目の高さ (間隔を含む)。置き場所が表示範囲の外にあるときに使う。 */
    var liftHeight: Int = 0

    /** 持ち上げたときの、項目の上端から指までの縦の距離 (lazy の配置の座標)。 */
    var liftGrabY: Float = 0f

    /** 指の位置 (一覧の座標)。 */
    var pointer: Offset by mutableStateOf(pointer)

    /** 仮の並びの行き先。 */
    var placement: KsReorderPlacement by mutableStateOf(original)

    /** 指を離した (または取りやめた) か。以後は指に付いて描かない。 */
    var isReleased: Boolean by mutableStateOf(false)

    /** 取りやめたか。 */
    var isCancelled: Boolean by mutableStateOf(false)

    /** 指が置けない場所の上にあるか。 */
    var isOverForbidden: Boolean = false

    /** 指が一覧の外枠の外にあるか。 */
    var isOutside: Boolean = false

    /** 最後に描いた並びとその構成。指の下の項目を lazy の index から引くのに使う。 */
    var composedItems: List<Item>? = null
    var composedPlan: KsGroupPlan? = null

    /** 行き先 [placement] に置いた仮の並び。 */
    fun renderedItems(placement: KsReorderPlacement): List<Item> =
        KsReorderedList(baseItems, source, planner.targetIndex(source, placement))

    /** 行き先 [placement] の知らせ。 */
    fun moveFor(placement: KsReorderPlacement): KsReorderMove<Item>? =
        buildMove(baseItems, valuesPlan, isGrouped, source, placement)

    /** 今描いている位置の左上 (一覧の座標)。まだ一度も配置されていなければ null。 */
    fun visualTopLeft(): Offset? = grab?.let { pointer - it }

    /**
     * lazy の配置の座標の点 [point] に置いたときの行き先。
     *
     * list の求め方は [listPlacementAt]。グリッドでは、指の下の項目の位置を持ち上げた項目が
     * 引き継ぐ (前の項目なら前、後ろの項目なら後ろに置く)。グループの見出しの上半分は前のグループの末尾、
     * 下半分はそのグループの先頭とする (core/ADR-0029)。ルートのヘッダーの上は最初のグループの先頭、
     * ルートのフッターの上は最後のグループの末尾とする。どの項目にも重ならない点は、上下にいちばん近い
     * 項目で決める。
     */
    fun placementAt(
        point: Offset,
        info: LazyGridLayoutInfo,
        plan: KsGroupPlan,
        items: List<Item>,
        columns: Int,
    ): KsReorderPlacement? {
        val entries = info.visibleItemsInfo
        if (entries.isEmpty()) return null
        if (columns <= 1) return listPlacementAt(point, entries, plan, items)
        var candidates = entries.filter { point.y >= it.offset.y && point.y < it.offset.y + it.size.height }
        // 固定中の見出しの裏に項目が重なるときは、項目を選ぶ。
        if (candidates.size > 1 && candidates.any { plan.itemIndexOfLazy(it.index) >= 0 }) {
            candidates = candidates.filter { plan.itemIndexOfLazy(it.index) >= 0 }
        }
        // 行の中で最後の項目より右 (行の余り) にいるか。そこはその項目の後ろとして扱う。
        var pastRowEnd = false
        val entry: LazyGridItemInfo = when {
            candidates.isEmpty() -> entries.minBy { entry ->
                val top = entry.offset.y
                val bottom = top + entry.size.height
                if (point.y < top) top - point.y else point.y - bottom
            }
            else -> candidates.firstOrNull { point.x >= it.offset.x && point.x < it.offset.x + it.size.width }
                ?: candidates.maxBy { it.offset.x }.takeIf { point.x >= it.offset.x }?.also { pastRowEnd = true }
                ?: candidates.minBy { it.offset.x }
        }
        val renderIndex = plan.itemIndexOfLazy(entry.index)
        if (renderIndex >= 0) {
            val base = (items as? KsReorderedList<Item>)?.baseIndexOf(renderIndex) ?: renderIndex
            if (base == source) return placement
            val group = planner.groupOf(base)
            val before = KsReorderPlacement(group, base)
            val after = planner.placement(source, group, positionExcludingSource(base, group) + 1)
            if (pastRowEnd) return after
            // グリッドでは、指の下の項目の位置を持ち上げた項目が引き継ぐ。持ち上げた項目より後ろの項目なら
            // その後ろ、前の項目ならその前に置く。置いた後は持ち上げた項目が指の下の枠に入るため、指が
            // 止まっている間に行き先が行き来しない。
            val draggedRender = planner.targetIndex(source, placement)
            return if (renderIndex > draggedRender) after else before
        }
        val headerGroup = plan.groupOfHeaderLazy(entry.index)
        if (headerGroup >= 0) {
            val upperHalf = point.y < entry.offset.y + entry.size.height / 2f
            return if (upperHalf && headerGroup > 0) {
                KsReorderPlacement(headerGroup - 1, KsReorderPlacement.End)
            } else {
                planner.placement(source, headerGroup, 0)
            }
        }
        if (plan.isRootHeader(entry.index)) return planner.placement(source, 0, 0)
        return KsReorderPlacement(planner.groupCount - 1, KsReorderPlacement.End)
    }

    /**
     * list で、指が lazy の配置の座標の点 [point] にあるときの行き先。
     *
     * 持ち上げた項目は指に付いて動くため、指の位置から持ち上げた項目の上端を求め、持ち上げた項目の置き場所を
     * 取り除いて詰めた並び (置き場所がどこにあっても変わらない並び) の上で、いちばん近い置き場所を選ぶ。
     * 持ち上げた項目の上端より下に中心がある最初の項目の前がそれに当たる。持ち上げた項目がほかの項目の
     * 半分を越えて重なったら入れ替わるため、隙間はいつも持ち上げた項目の近くにあり、項目に重なったまま隙間だけが
     * 離れて残ることがない。詰めた並びは置いた後も変わらないため、指が止まっている間に行き先が行き来しない。
     *
     * グループの見出しは項目と同じく数え、見出しより上なら前のグループの末尾、下ならそのグループの先頭になる。
     * 見出しの無い一覧のグループの境目は、次のグループの最初の項目の上端とし、持ち上げた項目の上端がそれより
     * 上なら前のグループの末尾、下なら次のグループの先頭とする (境目の前後の 2 つの置き場所は同じ位置に
     * 並ぶため、その位置へ入る範囲を境目で上下に分ける。core/ADR-0029)。固定されて項目に重なっている
     * 見出しは数えない。
     */
    private fun listPlacementAt(
        point: Offset,
        entries: List<LazyGridItemInfo>,
        plan: KsGroupPlan,
        items: List<Item>,
    ): KsReorderPlacement {
        val reordered = items as? KsReorderedList<Item>
        val draggedRender = reordered?.target ?: source
        val slotLazy = plan.lazyIndexOfItem(draggedRender)
        val sorted = entries.sortedBy { it.index }
        val slotHeight = sorted.firstOrNull { it.index == slotLazy }?.size?.height ?: liftHeight
        // 持ち上げた項目の上端 (指の位置から、持ち上げたときのつかんだ位置を引く)。
        val liftedTop = point.y - liftGrabY
        // 走査した中でいちばん下の (置き場所を除く) 項目・見出し。
        var lastCounted: LazyGridItemInfo? = null
        for ((position, entry) in sorted.withIndex()) {
            if (entry.index == slotLazy) continue
            val headerGroup = plan.groupOfHeaderLazy(entry.index)
            if (headerGroup >= 0) {
                val next = sorted.getOrNull(position + 1)
                // 固定されて次の項目に重なっている見出しは、本来の位置にないため数えない。
                if (next != null && next.offset.y < entry.offset.y + entry.size.height - 1) continue
            }
            lastCounted = entry
            val top = entry.offset.y - (if (entry.index > slotLazy) slotHeight else 0)
            if (liftedTop >= top + entry.size.height / 2f) continue
            if (headerGroup >= 0) {
                return if (headerGroup == 0) {
                    planner.placement(source, 0, 0)
                } else {
                    KsReorderPlacement(headerGroup - 1, KsReorderPlacement.End)
                }
            }
            if (plan.isRootHeader(entry.index)) return planner.placement(source, 0, 0)
            val renderIndex = plan.itemIndexOfLazy(entry.index)
            if (renderIndex < 0) break
            val base = reordered?.baseIndexOf(renderIndex) ?: renderIndex
            val group = planner.groupOf(base)
            // 見出しの無いグループの最初の項目の前は、境目 (その項目の上端) より上なら前のグループの末尾。
            if (!plan.hasHeaders && group > 0 && positionExcludingSource(base, group) == 0 && liftedTop < top) {
                return KsReorderPlacement(group - 1, KsReorderPlacement.End)
            }
            return KsReorderPlacement(group, base)
        }
        // 持ち上げた項目より下に数える項目が表示範囲に無い。一覧の末尾が表示されているときだけ最後のグループの
        // 末尾にし、そうでなければ表示範囲のいちばん下の項目の後ろにする (端での自動スクロールの途中に、表示
        // されていない遠い位置へ飛ばさない)。数える項目が 1 つも無い (見えているのが持ち上げた項目だけの)
        // ときは、今の行き先を保つ。
        val listEndShown = sorted.lastOrNull()?.index == plan.totalLazyCount - 1
        if (listEndShown) return KsReorderPlacement(planner.groupCount - 1, KsReorderPlacement.End)
        val last = lastCounted ?: return placement
        val lastHeaderGroup = plan.groupOfHeaderLazy(last.index)
        if (lastHeaderGroup >= 0) return planner.placement(source, lastHeaderGroup, 0)
        if (plan.isRootHeader(last.index)) return planner.placement(source, 0, 0)
        val lastRender = plan.itemIndexOfLazy(last.index)
        if (lastRender < 0) return KsReorderPlacement(planner.groupCount - 1, KsReorderPlacement.End)
        val lastBase = reordered?.baseIndexOf(lastRender) ?: lastRender
        val lastGroup = planner.groupOf(lastBase)
        return planner.placement(source, lastGroup, positionExcludingSource(lastBase, lastGroup) + 1)
    }

    /** 位置 [base] の項目の、グループ [group] の中での、持ち上げた項目を除いた番号。 */
    private fun positionExcludingSource(base: Int, group: Int): Int {
        val start = basePlan.groupStart(group)
        val shift = if (source in start until base) 1 else 0
        return base - start - shift
    }
}

/** 行き先 [placement] の知らせを組む。項目は配列の要素そのもの、グループの値は最新の構成から引く。 */
private fun <Item> buildMove(
    items: List<Item>,
    valuesPlan: KsGroupPlan,
    isGrouped: Boolean,
    source: Int,
    placement: KsReorderPlacement,
): KsReorderMove<Item>? {
    if (source !in items.indices || placement.groupIndex !in 0 until valuesPlan.groupCount) return null
    val destination: KsReorderDestination<Item> = if (placement.isEnd) {
        KsReorderDestination.End
    } else {
        if (placement.beforeIndex !in items.indices) return null
        KsReorderDestination.Before(items[placement.beforeIndex])
    }
    val group = if (isGrouped) valuesPlan.groupValue(placement.groupIndex) else null
    return KsReorderMove(items[source], destination, group)
}

/** 一覧の座標の点を、lazy の配置の座標 (項目の `offset` と同じ座標) に直す。 */
private fun LazyGridLayoutInfo.toItemSpace(point: Offset): Offset =
    Offset(point.x, point.y + viewportStartOffset)

/** lazy の項目の範囲に点が入るか。 */
private fun LazyGridItemInfo.contains(point: Offset): Boolean =
    point.x >= offset.x && point.x < offset.x + size.width &&
        point.y >= offset.y && point.y < offset.y + size.height

private fun Offset.round(): IntOffset = IntOffset(x.roundToInt(), y.roundToInt())

/**
 * 並べ替えの長押しとドラッグを受ける。一覧 (lazy のグリッド) の修飾に付ける。
 *
 * 長押しの判定は子 (項目のタップ・一覧のスクロール) と同じ段で見て、子がスクロールを始めたら (指が
 * タッチの遊びを越えて動いたら) 長押しにしない。持ち上げた後は子より先の段でタッチを消費し、一覧の
 * スクロールと項目のタップを起こさない。
 */
internal suspend fun <Item> PointerInputScope.ksReorderGestures(controller: KsReorderController<Item>) {
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false)
        val position = awaitLongPress(down.id, down.position) ?: return@awaitEachGesture
        if (!controller.lift(position)) return@awaitEachGesture
        var finished = false
        try {
            while (true) {
                val event = awaitPointerEvent(PointerEventPass.Initial)
                val change = event.changes.fastFirstOrNull { it.id == down.id }
                event.changes.forEach { it.consume() }
                if (change == null) {
                    controller.cancel()
                    break
                }
                if (!change.pressed) {
                    controller.moveTo(change.position, size)
                    controller.drop()
                    break
                }
                controller.moveTo(change.position, size)
            }
            finished = true
        } finally {
            // 操作が途中で打ち切られた (一覧から外された等) ときは取りやめる。
            if (!finished) controller.cancel()
        }
    }
}

/**
 * 長押しを待つ。長押しの時間が経つまで指が遊びの範囲に留まれば、その時点の指の位置を返す。途中で指が
 * 離れた・遊びを越えて動いた・別の指が触れたときは null。
 */
private suspend fun AwaitPointerEventScope.awaitLongPress(id: PointerId, start: Offset): Offset? {
    var position = start
    val slop = viewConfiguration.touchSlop
    val interrupted = withTimeoutOrNull(viewConfiguration.longPressTimeoutMillis) {
        while (true) {
            val event = awaitPointerEvent()
            if (event.changes.any { it.id != id && it.pressed }) return@withTimeoutOrNull true
            val change = event.changes.fastFirstOrNull { it.id == id } ?: return@withTimeoutOrNull true
            if (!change.pressed) return@withTimeoutOrNull true
            position = change.position
            if ((position - start).getDistance() > slop) return@withTimeoutOrNull true
        }
        @Suppress("UNREACHABLE_CODE")
        true
    }
    return if (interrupted == null) position else null
}
