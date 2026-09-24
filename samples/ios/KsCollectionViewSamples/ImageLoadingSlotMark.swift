import SwiftUI

/// 読み込み中の計数を画面の印として出します。基準点を切る操作もここが受け持ちます。
///
/// 計数の読み出しがログだけだと、**ログが落ちた分はそのまま `sized` の減少に見え、
/// 「読み込み中を経由していない」= 合格の側に倒れます**。画面にも同じ数を出し、証跡では
/// ログとこの印を突き合わせて初めて判定に使います。
///
/// ## 見せる数
///
/// 主に見せるのは**基準点からの差分**です (`sized` / `unsized` / `lines` と要素ごとの内訳)。
/// 累計は `total=` に併記します。書式は Android Sample の同じ印とそろえています。
///
/// 印の数は読み込み中の表示が組み立てられた回数です。iOS では画面に出る前に組み立てられ、画面に出ない
/// まま画像に替わる読み込み中もここに数えられるため、「読み込み中を画面に出したか」の判定
/// (`Δshown` が 0) はログの `shown` の行と観測の経路の出力で読みます
/// (``ImageLoadingSlotCounter`` の「組み立てと、画面に出た読み込み中」)。
///
/// ## 基準点を切る
///
/// この印を叩くと観測区間が切り替わります (``ImageLoadingSlotCounter/beginSession()``)。
/// 「初回表示 → 基準点 → 画面外へ送る → 戻す」の手順では、初回表示が落ち着いた時点で 1 度
/// 叩いてから送り出します。区間の通し番号は `session=` に出るので、叩けたかどうかは画面で
/// 確かめられます。Android Sample の同じ印も同じ操作・同じ書式です。
///
/// ## 突き合わせ規則
///
/// 判定に使う前に、次の 3 つがすべて成り立つことを確かめます。成り立たないときはログが
/// 落ちているので、計測をやり直します (数が小さい側に倒れているため、そのまま合格にしません)。
///
/// - ログの各行の `session=` が印の `session=` と一致すること (違う番号の行は別の区間の記録
///   なので、突き合わせに混ぜません)
/// - その区間の行数が、印の `lines` と一致すること
/// - 要素ごとに、ログの `sized=` の値が 1 から印の内訳の値まで飛びなく現れること
///   (`unsized=` も同様。計数は 1 回ごとに 1 ずつ増えるため、飛びはそのまま欠落を意味します)
///
/// 数えることが要求されていない実行では何も出しません。印そのものが出ないことが、
/// 「この実行は数えていない」ことの表明になります。
struct ImageLoadingSlotMark: View {
    /// 印に並べる要素ごとの内訳の上限。読み取り側が扱える長さに収めます。
    private static let detailLimit = 20

    /// 印を書き換える間隔 (秒)。
    private static let refreshInterval = Duration.milliseconds(250)

    @State private var summary = ImageLoadingSlotMark.summary(
        session: 0,
        delta: [:],
        total: [:]
    )

    var body: some View {
        if ImageLoadingSlotCounter.isEnabled {
            Text(verbatim: summary)
                .font(.caption)
                .foregroundStyle(SampleTheme.secondaryText)
                .accessibilityIdentifier("imageLoadingSlot.tally")
                // 文字の隙間ではなく行全体で受けます。計測する人が実機で確実に叩けるように
                // するためで、数えない実行ではこの印自体が現れません。
                .contentShape(Rectangle())
                .onTapGesture {
                    ImageLoadingSlotCounter.beginSession()
                    refresh()
                }
                .task {
                    // 計数は表示の状態ではないため、書き換えは検知できません。一定間隔で
                    // 読み直します。
                    while !Task.isCancelled {
                        refresh()
                        try? await Task.sleep(for: Self.refreshInterval)
                    }
                }
        }
    }

    /// 印の文字列を現在の計数から作り直します。
    private func refresh() {
        summary = Self.summary(
            session: ImageLoadingSlotCounter.session,
            delta: ImageLoadingSlotCounter.deltaSnapshot(),
            total: ImageLoadingSlotCounter.snapshot()
        )
    }

    /// 計数を印の文字列に組み立てます。副作用を持たない写像です。
    ///
    /// 区間の通し番号 (`session`) と、基準点からの差分の総数 (`items` / `sized` / `unsized` /
    /// `lines`)、累計 (`total=<sized>/<unsized>/<lines>`) を並べ、その後ろに要素ごとの差分を
    /// `<識別子>:<sized>/<unsized>` の形で並べます。内訳は差分の大きい順 (`sized`、同値なら
    /// `unsized`) に、同値なら識別子の順に ``detailLimit`` 件までとし、収まらなかった件数を
    /// `more=` で残します (総数はすべての要素を数えているため、内訳を切ってもログとの
    /// 突き合わせに使う数は失われません)。Android Sample の同じ印と同じ書式・同じ並びに
    /// そろえます。
    ///
    /// - Parameters:
    ///   - session: 観測区間の通し番号
    ///   - delta: 要素ごとの、基準点からの差分
    ///   - total: 要素ごとの累計
    static func summary(
        session: Int,
        delta: [Int: ImageLoadingSlotTally],
        total: [Int: ImageLoadingSlotTally]
    ) -> String {
        let sized = delta.values.reduce(0) { $0 + $1.sized }
        let unsized = delta.values.reduce(0) { $0 + $1.unsized }
        let totalSized = total.values.reduce(0) { $0 + $1.sized }
        let totalUnsized = total.values.reduce(0) { $0 + $1.unsized }
        // 内訳の枠は限られるので、差分の大きい要素から並べる。判定は差分で行うため、
        // 溢れさせたくないのは差分が出ている側 (差分 0 の要素はログにも行が出ない)。
        // 同値の並びは、識別子を文字列として比べて Android と同じにそろえる。
        let entries = delta.sorted { lhs, rhs in
            if lhs.value.sized != rhs.value.sized { return lhs.value.sized > rhs.value.sized }
            if lhs.value.unsized != rhs.value.unsized {
                return lhs.value.unsized > rhs.value.unsized
            }
            return "\(lhs.key)" < "\(rhs.key)"
        }
        let detail = entries.prefix(detailLimit)
            .map { "\($0.key):\($0.value.sized)/\($0.value.unsized)" }
            .joined(separator: " ")
        let omitted = max(entries.count - detailLimit, 0)
        let head = "slots session=\(session) items=\(delta.count) "
            + "sized=\(sized) unsized=\(unsized) lines=\(sized + unsized) "
            + "total=\(totalSized)/\(totalUnsized)/\(totalSized + totalUnsized)"
        return [
            head,
            detail.isEmpty ? nil : detail,
            omitted > 0 ? "more=\(omitted)" : nil,
        ].compactMap { $0 }.joined(separator: " ")
    }
}
