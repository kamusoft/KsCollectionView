package jp.kamusoft.kscollectionview.samples.android

/** 行の高さが変わるときに、展開状態をどこが持つかの経路。 */
enum class HeightChangeExpansionPath(val title: String) {
    /** 親の状態でテンプレート内容を変え、可視セルを作り直す経路。 */
    ParentState("親 state"),

    /** テンプレート内の内容が自分の状態で展開し、親はタップを知らない経路。 */
    TemplateState("テンプレート内 state"),
}
