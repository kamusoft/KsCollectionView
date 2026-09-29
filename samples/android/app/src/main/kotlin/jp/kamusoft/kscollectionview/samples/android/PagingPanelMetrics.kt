package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.ui.unit.dp

/**
 * 「ページング」画面の操作のパネルまわりの寸法と透け方。
 *
 * 値は iOS Sample の同名の定義とそろえる (iOS の pt をそのまま dp にする)。この画面だけの値のため
 * [SampleTheme] には置かない。
 */
object PagingPanelMetrics {
    /** パネル (畳んだときは丸いボタン) と画面の左右の端との間の余白。 */
    val horizontalMargin = 16.dp

    /**
     * パネル (畳んだときは丸いボタン) の下端と、画面の下の安全領域の境目との間隔。
     *
     * パネルを画面の下端から上げて浮かせ、その下に一覧の底の帯を見せる。一覧の下の余白にはパネルの分を
     * 入れないため、末尾までスクロールしたときの表示 (次のページの読み込み中・失敗と「再試行」・終端) は
     * この帯に出る。いちばん高い失敗の表示 (上下の余白 16 と文言と「再試行」) が丸ごと収まる高さにする。
     *
     * 決め方は iOS Sample と同じで、値は失敗の表示の背の高さの差で分ける (iOS は 100pt)。Android は
     * 「再試行」の押せる範囲が 48dp あり、その分だけ失敗の表示の背が高い。
     */
    val bottomMargin = 128.dp

    /** パネルの面の上の色 (セル背景) の不透明度。一覧が透けて見える。 */
    const val SurfaceOpacity: Float = 0.72f

    /** パネルの角丸の半径。 */
    val cornerRadius = 18.dp

    /** パネルの中身の左右の余白。 */
    val horizontalPadding = 12.dp

    /** パネルの中身の上下の余白。 */
    val verticalPadding = 10.dp

    /** パネルの中身の行と行の間隔。 */
    val rowSpacing = 6.dp

    /** パネル左上の畳むボタンの直径。 */
    val foldButtonSize = 30.dp

    /** 畳んだときに残る丸いボタンの直径。 */
    val handleSize = 44.dp

    /** パネルの影のぼかしの半径と下へのずれ。 */
    val shadowRadius = 8.dp
    val shadowOffset = 4.dp

    /** パネルの影の不透明度。 */
    const val ShadowOpacity: Float = 0.10f

    /** ページングの表示 (失敗・終端) の上下の余白。 */
    val footerVerticalPadding = 16.dp

    /** 失敗の表示の文言と「再試行」の間隔。 */
    val messageSpacing = 8.dp

    /** 「再試行」の文言の上下 / 左右の余白と角丸の半径。 */
    val retryVerticalPadding = 6.dp
    val retryHorizontalPadding = 16.dp
    val retryCornerRadius = 10.dp

    /** 「更新できませんでした」の帯と一覧の上端 (上部バーの下端) との間の余白。左右は [horizontalMargin] と同じ。 */
    val bannerTopMargin = 8.dp

    /** 帯の角丸の半径。 */
    val bannerCornerRadius = 12.dp

    /** 帯の文言の上下の余白。 */
    val bannerVerticalPadding = 10.dp

    /** 帯を出しておく時間 (ミリ秒)。 */
    const val BannerDurationMillis: Long = 3_000

    /** 帯が出る・消えるときのフェードの時間 (ミリ秒)。 */
    const val BannerFadeMillis: Int = 200
}
