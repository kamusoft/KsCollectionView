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
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.Dp
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsColumns
import jp.kamusoft.kscollectionview.KsLayout
import jp.kamusoft.kscollectionview.KsPaging

/**
 * 「ページング」画面。偽の取得元から 1 ページずつ読み込む一覧に、ページングと Pull to Refresh を付ける。
 *
 * 一覧は上部バーの下から画面の下端 (ナビゲーションバーの裏) まで広げ、操作は一覧の上に浮かせた
 * 背景の透けるパネルにまとめる。パネルは左端の丸いボタンに畳める。パネルは一覧の本来の動きと表示を
 * 見るための操作のため、一覧の余白はパネルに合わせて変えない。下の余白は全画面の一覧として入れる
 * 下端の安全領域の分だけにし、かわりにパネル (畳んだときは丸いボタン) を画面の下端から
 * [SamplePanelMetrics.bottomMargin] だけ上げて、その下に一覧の底 (末尾までスクロールしたときの
 * ページングの表示) が見えるようにする。上部バーは画面の上端の安全領域を自分で覆うため、一覧の上端は
 * 安全領域に重ならず、上の余白は入れない。
 *
 * 件数・文言・操作の規則は iOS Sample の同名画面とそろえる。呼び出し側は、この画面を下端の
 * 安全領域の内側に収めずに置く ([SampleScaffold] の `extendsBehindBottomBar`)。
 *
 * @param delayMilliseconds 偽の取得元が 1 回の取得に置く遅延 (ミリ秒)
 * @param modifier 画面全体に付ける修飾
 */
@Composable
fun PagingDemoScreen(
    delayMilliseconds: Int = PagingDelay.DefaultMilliseconds,
    modifier: Modifier = Modifier,
) {
    val scope = rememberCoroutineScope()
    val source = remember(delayMilliseconds) { PagingDemoSource(delayMilliseconds) }
    val model = rememberSaveable(saver = PagingDemoModel.saver(source::fetch, scope)) {
        PagingDemoModel(fetch = source::fetch, noticeScope = scope)
    }
    var layoutChoice by rememberSaveable { mutableStateOf(PagingLayoutChoice.List) }
    var isPanelFolded by rememberSaveable { mutableStateOf(false) }
    val bottomSafeArea = WindowInsets.systemBars.union(WindowInsets.displayCutout)
        .asPaddingValues().calculateBottomPadding()

    Box(modifier = modifier.fillMaxSize()) {
        PagingCollection(
            model = model,
            layoutChoice = layoutChoice,
            bottomPadding = bottomSafeArea,
        )

        // 項目があるときの取り直しの失敗は、一覧の上端 (上部バーのすぐ下) に浮かせた帯で知らせる。
        // 一覧の余白は変えず、帯は一覧の上端の行に重なる。
        AnimatedVisibility(
            visible = model.refreshFailed,
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
            SampleNoticeBanner(text = PagingDemoText.RefreshFailed)
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
            PagingControlPanel(
                layoutChoice = layoutChoice,
                onSelectLayout = { layoutChoice = it },
                failsNextLoad = model.failsNextLoad,
                onFailsNextLoadChange = { model.failsNextLoad = it },
                isEmpty = model.isEmpty,
                onIsEmptyChange = { model.setEmpty(it, scope) },
                onReload = { model.reload(scope) },
                onFold = { isPanelFolded = true },
                modifier = controlModifier.fillMaxWidth(),
            )
        }
    }
}

/**
 * 「ページング」画面の一覧。ページングの状態・失敗 / 終端 / 空の表示・Pull to Refresh をつなぐ。
 *
 * @param model 項目と状態
 * @param layoutChoice 表示の形
 * @param bottomPadding 一覧の下の余白 (下端の安全領域の分)
 */
@Composable
private fun PagingCollection(model: PagingDemoModel, layoutChoice: PagingLayoutChoice, bottomPadding: Dp) {
    KsCollectionView(
        items = model.items,
        key = { it.id },
        modifier = Modifier.fillMaxSize(),
        layout = when (layoutChoice) {
            PagingLayoutChoice.List -> KsLayout.List
            PagingLayoutChoice.Grid -> PagingGridLayout
        },
        contentPadding = PaddingValues(bottom = bottomPadding),
        paging = KsPaging(
            state = model.state,
            onLoadMore = model::loadNextPage,
            failedFooter = { retry ->
                PagingMessage(
                    message = PagingDemoText.LoadFailed,
                    retry = retry,
                    modifier = Modifier.fillMaxWidth().padding(vertical = PagingMessageMetrics.footerVerticalPadding),
                )
            },
            endReachedFooter = {
                PagingMessage(
                    message = PagingDemoText.EndReached,
                    modifier = Modifier.fillMaxWidth().padding(vertical = PagingMessageMetrics.footerVerticalPadding),
                )
            },
            failedPlaceholder = { retry -> PagingMessage(message = PagingDemoText.LoadFailed, retry = retry) },
            emptyPlaceholder = { PagingMessage(message = PagingDemoText.Empty) },
        ),
        onRefresh = model::refresh,
    ) {
        template { item -> DemoListRow(item) }
    }
    // 一覧に渡した状態をモデルへ知らせる。取り直しは、取り直し中が一覧に届いてから取得する。
    val displayedState = model.state
    SideEffect { model.onDisplayed(displayedState) }
}

/** 2 列のグリッドの形。「差分更新」のグリッドと同じ間隔。 */
private val PagingGridLayout: KsLayout = KsLayout.Grid(
    columns = KsColumns.Fixed(2),
    rowSpacing = GroupHeaderMetrics.gridSpacing,
    columnSpacing = GroupHeaderMetrics.gridSpacing,
)
