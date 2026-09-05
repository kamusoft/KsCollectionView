package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsScrollPosition
import jp.kamusoft.kscollectionview.rememberKsScrollController

/**
 * 「スクロール制御」画面。外から先頭・指定 ID・末尾へスクロールさせる。
 */
@Composable
fun ScrollControlDemoScreen(modifier: Modifier = Modifier) {
    val controller = rememberKsScrollController()

    Column(modifier = modifier.fillMaxSize()) {
        SampleControlBar {
            Row(verticalAlignment = Alignment.CenterVertically) {
                ControlButton(text = "先頭") { controller.scrollToStart() }
                Spacer(modifier = Modifier.weight(1f))
                ControlButton(text = "Item 50") {
                    controller.scrollTo(id = 50, position = KsScrollPosition.Center)
                }
                Spacer(modifier = Modifier.weight(1f))
                ControlButton(text = "末尾") { controller.scrollToEnd() }
            }
        }

        KsCollectionView(
            items = DemoData.scrollItems,
            key = { it.id },
            scrollController = controller,
        ) {
            template { item -> DemoListRow(item) }
        }
    }
}

/** 操作列のボタン。 */
@Composable
private fun ControlButton(text: String, onClick: () -> Unit) {
    TextButton(onClick = onClick) {
        Text(text = text, color = SampleTheme.accent)
    }
}
