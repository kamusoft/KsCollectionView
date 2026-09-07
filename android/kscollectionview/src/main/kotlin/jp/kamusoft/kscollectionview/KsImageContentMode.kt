package jp.kamusoft.kscollectionview

/** 画像を表示枠にどう当てはめるかを表します。 */
public enum class KsImageContentMode {
    /** 画像全体が表示枠に収まるように当てはめます。枠に余白が出ることがあります。 */
    Fit,

    /** 表示枠全体が画像で覆われるように当てはめます。枠からはみ出た部分は表示されません。 */
    Fill,
}
