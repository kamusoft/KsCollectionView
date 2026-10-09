package jp.kamusoft.kscollectionview.verification.android

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

/** 一覧の 1 行。 */
data class VerificationItem(val id: Int, val title: String)

/** 表示する行の数。画面に収まらない数にして、スクロールできる一覧にする。 */
private const val ItemCount = 100

/**
 * 本ライブラリの最小の利用例。行を縦に並べた一覧を 1 つ表示する。
 *
 * 配布物を利用者の立場でビルドできることを確かめるための画面で、機能の見本ではない。
 */
@Composable
fun VerificationListScreen(modifier: Modifier = Modifier) {
    val items = remember { List(ItemCount) { index -> VerificationItem(id = index, title = "Item $index") } }
    KsCollectionView(
        items = items,
        key = { it.id },
        // システムバーと重ならない範囲に収める。
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
