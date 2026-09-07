package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.PaddingValues
import jp.kamusoft.kscollectionview.KsColumns
import jp.kamusoft.kscollectionview.KsLayout
import jp.kamusoft.kscollectionview.KsPrefetchDestination

/**
 * 「画像グリッド」の土俵の宣言元。
 *
 * デモ画面と計測用の入口は、要素・配置・外周の余白・プリフェッチの宣言をすべてここから取る。
 * 計測はデモ画面と同じ土俵で測って初めて意味を持つため、両者が別々の宣言を持たないよう
 * 1 箇所に集めている (件数だけは計測で変えられるよう引数にする)。
 *
 * 寸法そのものは [ImageGridMetrics]、要素の作り方は [DemoData.imageGridItems] が持つ。
 */
object ImageGridFixture {

    /** 土俵の配置。3 列・セル間の間隔はデモ画面と計測で同じ。 */
    val layout: KsLayout = KsLayout.Grid(
        columns = KsColumns.Fixed(ImageGridMetrics.ColumnCount),
        rowSpacing = ImageGridMetrics.spacing,
        columnSpacing = ImageGridMetrics.spacing,
    )

    /** グリッドの外周の余白。 */
    val contentPadding: PaddingValues = PaddingValues(ImageGridMetrics.spacing)

    /**
     * 土俵の要素を、要求された件数だけ作る。
     *
     * @param count 作る件数
     */
    fun items(count: Int = DemoData.ImageGridItemCount): List<DemoItem> =
        DemoData.imageGridItems(count)

    /**
     * プリフェッチする URL の宣言。
     *
     * 到達点を選ばない (「なし」) ときは宣言そのものを行わず null を返す。宣言が無いことと
     * 「空の宣言がある」ことは本体の動きが変わるため、null で区別する。
     *
     * @param destination 選んだ到達点。宣言しないときは null
     */
    fun resources(destination: KsPrefetchDestination?): ((DemoItem) -> List<String>)? =
        destination?.let { { item: DemoItem -> listOf(DemoData.imageUrl(item.id)) } }
}
