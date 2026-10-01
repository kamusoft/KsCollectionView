package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.ui.unit.dp

/**
 * 「ページング」画面の失敗・終端・空の表示の寸法。
 *
 * 値は iOS Sample の同名の定義とそろえる (iOS の pt をそのまま dp にする)。この画面だけの値のため
 * [SampleTheme] には置かない。
 */
object PagingMessageMetrics {
    /** ページングの表示 (失敗・終端) の上下の余白。 */
    val footerVerticalPadding = 16.dp

    /** 失敗の表示の文言と「再試行」の間隔。 */
    val messageSpacing = 8.dp

    /** 「再試行」の文言の上下 / 左右の余白と角丸の半径。 */
    val retryVerticalPadding = 6.dp
    val retryHorizontalPadding = 16.dp
    val retryCornerRadius = 10.dp
}
