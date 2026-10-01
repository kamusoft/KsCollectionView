package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.displayCutout
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.union
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsColumns
import jp.kamusoft.kscollectionview.KsGroups
import jp.kamusoft.kscollectionview.KsLayout
import jp.kamusoft.kscollectionview.KsReorder
import jp.kamusoft.kscollectionview.KsReorderAccessibilityActions

/**
 * 「並べ替え」画面。10,000 件の一覧に並べ替えを付け、長押しからのドラッグで項目を並べ替える。
 *
 * 一覧は上部バーの下から画面の下端 (ナビゲーションバーの裏) まで広げ、操作は一覧の上に浮かせた背景の
 * 透けるパネルにまとめる。パネルは左端の丸いボタンに畳める。長押しの知らせと、並べ替えを受け入れなかった
 * 知らせは、上部バーのすぐ下に帯を一覧の上へ浮かせて出す (一覧の余白は変えない)。
 *
 * 一覧の下の余白は全画面の一覧として入れる下端の安全領域の分だけにし、操作の都合では変えない。
 * パネル (畳んだときは丸いボタン) は画面の下端から [SamplePanelMetrics.bottomMargin] だけ上げて浮かせる
 * (「ページング」と同じ置き方)。件数・文言・操作の規則は iOS Sample の同名画面とそろえる。呼び出し側は、
 * この画面を下端の安全領域の内側に収めずに置く ([SampleScaffold] の `extendsBehindBottomBar`)。
 *
 * @param modifier 画面全体に付ける修飾
 */
@Composable
fun ReorderDemoScreen(modifier: Modifier = Modifier) {
    val scope = rememberCoroutineScope()
    val model = rememberSaveable(saver = ReorderDemoModel.saver(scope)) { ReorderDemoModel(noticeScope = scope) }
    var layoutChoice by rememberSaveable { mutableStateOf(ReorderLayoutChoice.List) }
    var isPanelFolded by rememberSaveable { mutableStateOf(false) }
    val bottomSafeArea = WindowInsets.systemBars.union(WindowInsets.displayCutout)
        .asPaddingValues().calculateBottomPadding()

    Box(modifier = modifier.fillMaxSize()) {
        ReorderCollection(model = model, layoutChoice = layoutChoice, bottomPadding = bottomSafeArea)

        // 長押しと受け入れなかったことの知らせは、一覧の上端 (上部バーのすぐ下) に浮かせた帯で出す。
        // 一覧の余白は変えず、帯は一覧の上端の行に重なる。
        AnimatedVisibility(
            visible = model.notice != null,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(
                    top = SamplePanelMetrics.bannerTopMargin,
                    start = SamplePanelMetrics.horizontalMargin,
                    end = SamplePanelMetrics.horizontalMargin,
                ),
            enter = fadeIn(tween(SamplePanelMetrics.BannerFadeMillis)),
            exit = fadeOut(tween(SamplePanelMetrics.BannerFadeMillis)),
        ) {
            // 消えていく間も直前の文言を出し続ける。
            SampleNoticeBanner(text = model.lastNotice)
        }

        val controlModifier = Modifier
            .align(Alignment.BottomStart)
            .padding(
                start = SamplePanelMetrics.horizontalMargin,
                end = SamplePanelMetrics.horizontalMargin,
                bottom = bottomSafeArea + SamplePanelMetrics.bottomMargin,
            )
        if (isPanelFolded) {
            SamplePanelHandle(onUnfold = { isPanelFolded = false }, modifier = controlModifier)
        } else {
            ReorderControlPanel(
                layoutChoice = layoutChoice,
                onSelectLayout = { layoutChoice = it },
                model = model,
                onFold = { isPanelFolded = true },
                modifier = controlModifier.fillMaxWidth(),
            )
        }
    }
}

/**
 * 「並べ替え」画面の一覧。並べ替え・長押し・グループの有無をつなぐ。
 *
 * @param model 項目と切り替えの値
 * @param layoutChoice 表示の形
 * @param bottomPadding 一覧の下の余白 (下端の安全領域の分)
 */
@Composable
private fun ReorderCollection(model: ReorderDemoModel, layoutChoice: ReorderLayoutChoice, bottomPadding: Dp) {
    KsCollectionView(
        items = model.items,
        key = { it.id },
        modifier = Modifier.fillMaxSize(),
        layout = when (layoutChoice) {
            ReorderLayoutChoice.List -> ReorderListLayout
            ReorderLayoutChoice.Grid -> ReorderGridLayout
        },
        contentPadding = PaddingValues(bottom = bottomPadding),
        groups = if (model.isGrouped) ReorderGroups else null,
        onItemLongTap = model::didLongPress,
        reorder = KsReorder(
            enabled = model.isReorderEnabled,
            onMove = model::move,
            canMove = { it.isMovable },
            canDrop = model::canDrop,
            accessibilityActions = ReorderAccessibilityActions,
        ),
    ) {
        template { item -> ReorderDemoRow(item) }
    }
}

/** リストの形。「差分更新」と同じグループの間隔。 */
private val ReorderListLayout: KsLayout = KsLayout.List(groupSpacing = GroupHeaderMetrics.groupSpacing)

/** 2 列のグリッドの形。「差分更新」のグリッドと同じ間隔。 */
private val ReorderGridLayout: KsLayout = KsLayout.Grid(
    columns = KsColumns.Fixed(2),
    rowSpacing = GroupHeaderMetrics.gridSpacing,
    columnSpacing = GroupHeaderMetrics.gridSpacing,
    groupSpacing = GroupHeaderMetrics.groupSpacing,
    headerItemSpacing = GroupHeaderMetrics.gridSpacing,
)

/** グループありのときのグループ分けと見出し。見出しは固定する (既定)。 */
private val ReorderGroups: KsGroups<ReorderDemoItem, Int> = KsGroups(by = { it.group }) { group, itemsInGroup ->
    GroupHeaderBand(name = ReorderDemoText.groupName(group), itemCount = itemsInGroup.size)
}

/** 読み上げの移動の操作の文言。 */
private val ReorderAccessibilityActions = KsReorderAccessibilityActions(
    previous = ReorderDemoText.MoveBackward,
    next = ReorderDemoText.MoveForward,
)
