package jp.kamusoft.kscollectionview.samples.android

/**
 * デモ画面の集合と表示名の単一の宣言元。
 *
 * ルートメニューの項目文言と遷移先の画面タイトルはここだけから引く。両方を別々に持つと
 * 表記ゆれが生まれ、iOS Sample と文言が一致していることを目視で確かめられなくなる。
 * 並び順と文言は iOS Sample の同名 enum と一字一句そろえる。
 */
enum class SampleScreen(val title: String) {
    List("リスト"),
    FixedGrid("グリッド (固定列)"),
    AdaptiveGrid("グリッド (adaptive)"),
    OrientationGrid("向きで列数変更"),
    Templates("テンプレート切り替え"),
    HeaderFooter("ルートヘッダー/フッター"),
    Scrolling("スクロール制御"),
    Spacing("スペーシングと余白"),
    LargeData("大量件数"),
    ImageGrid("画像グリッド"),
}
