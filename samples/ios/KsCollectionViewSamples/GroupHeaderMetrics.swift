/// 「グループ化」「差分更新」の 2 画面が使う、グループまわりの寸法。
///
/// 値は Android Sample の同名定義とそろえる。この 2 画面だけの値のため `SampleTheme` には置かない。
enum GroupHeaderMetrics {
    /// 見出しの帯の高さ。
    static let height = 40.0

    /// グループとグループの間の間隔。
    static let groupSpacing = 16.0

    /// グリッドの行と行・列と列の間隔。グリッドの見出しと先頭行の間も同じ間隔にする。
    static let gridSpacing = 1.0
}
