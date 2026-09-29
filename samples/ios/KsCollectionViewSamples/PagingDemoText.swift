/// 「ページング」画面に出す文言。Android Sample の同名の定義と一字一句同じにする。
enum PagingDemoText {
    /// 表示の形の切り替えの名前 (読み上げ用)。
    static let layoutPicker = "表示"

    /// 失敗させる切り替え。
    static let failsNextLoad = "次の読み込みを失敗させる"

    /// 0 件にする切り替え。
    static let isEmpty = "中身を 0 件にする"

    /// 引っ張らずに取り直す操作。
    static let reload = "再読み込み"

    /// 操作のパネルの説明の一行 (通常)。
    static let summary = "全 10,000 件・1 ページ 50 件"

    /// 操作のパネルの説明の一行 (項目があるときの取り直しに失敗したとき)。
    static let refreshFailed = "更新できませんでした"

    /// 読み込みの失敗の表示 (最後の項目の後ろ / 0 件のとき)。
    static let loadFailed = "読み込めませんでした"

    /// 失敗の表示の中の再試行の操作。
    static let retry = "再試行"

    /// 終端の表示。
    static let endReached = "これ以上ありません"

    /// 空の表示。
    static let empty = "項目がありません"

    /// 操作のパネルを畳む操作 (読み上げ用)。
    static let fold = "操作を畳む"

    /// 畳んだ操作のパネルを広げる操作 (読み上げ用)。
    static let unfold = "操作を広げる"
}
