import Foundation
import SwiftUI
import os

/// 読み込み中の表示が組み立てられた回数を数えます。起動引数 `--count-image-loading-slots` を
/// 付けたときだけ働きます。
///
/// 「読み込み中を経由したか」は、要求の件数や取得元では代用できません。メモリにある画像を
/// 同期で引き当てて読み込み中を挟まない経路があるため、**要求が起きないこと**と
/// **読み込み中を出さないこと**は別の事実です。ここでは読み込み中の表示そのものが
/// 組み立てられた回数を、要素の識別子つきで 1 件ずつ記録します。
///
/// 数は 2 種類に分けます。表示枠の大きさが決まる前の読み込み中 (`unsized`) と、枠は決まって
/// いて取得を待っている読み込み中 (`sized`) です。`KsImage` は枠の大きさが決まるまで取得を
/// 始めず読み込み中を出す仕様なので、前者は取得の状況と無関係に現れることがあります。
/// 混ぜて数えると「読み込み中を経由していない」を判定できなくなるため、記録の時点で分けます。
///
/// ## 観測区間 (基準点) と判定規則
///
/// 読み込み中の数は**累計では判定できません**。「戻ってきたときの再表示」を見る手順は
/// 「初回表示 → 画面外へ送る → 戻す」であり、初回表示の時点で対象の数は通常 1 以上になります。
/// 累計が 0 であることを規則にすると、正しく即時再表示された場合まで不合格になります。
///
/// そこで**基準点** (``beginSession()``) を設けます。初回表示が終わった時点・画面外へ送る直前に
/// 基準点を切ると、そこから先の増分だけを数えた観測区間が始まります。判定は対象の要素ごとの
/// 基準点からの差分で行います (iOS で使う数は下の「組み立てと、画面に出た読み込み中」)。
///
/// 基準点は画面の印 (``ImageLoadingSlotMark``) を叩くと切れます (Android Sample も同じ操作)。
/// 区間には 1 から始まる通し番号 (``session``) が付き、印とログの両方に載ります。番号が違う
/// 記録は別の区間のものなので、突き合わせに混ぜてはいけません。
///
/// ## 組み立てと、画面に出た読み込み中
///
/// `sized` / `unsized` は読み込み中の表示が**組み立てられた**回数です。iOS の `KsImage` は、
/// 画面に出る前に組み立てられたとき、要求を出さずに読み込み中の表示を置いて待ち、画面に出る
/// 時点でメモリを照会し直します。そこで先読みの画像に当たると、読み込み中の表示は 1 度も
/// 画面に出ないまま画像に替わります。この場合も組み立ては `sized` に数えられるため、iOS では
/// `Δsized` が「読み込み中を画面に出した」ことを意味しません。
///
/// そこで、読み込み中の表示が実際に画面に出た回数を `shown` として別に数えます
/// (``ImageLoadingSlotShownProbe``)。**iOS の判定規則は、対象の要素ごとに「基準点からの差分
/// `Δshown` が 0」** です。`sized` / `unsized` は組み立ての回数として残し、印 (``ImageLoadingSlotMark``)
/// は Android Sample と同じ書式のまま組み立ての回数を出します。`shown` はログの各行と観測の
/// 経路 (``ImagePrefetchMatchProbe``) の出力で読みます。
@MainActor
enum ImageLoadingSlotCounter {
    /// 観測の分類。`log stream` の絞り込みに使います。
    static let category = "image-loading-slot"

    /// 数えることが要求されているかどうか。要求されていないときは読み込み中の表示を
    /// 差し込まず、本体の既定の表示に任せます。
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("--count-image-loading-slots")

    private static let logger = Logger(
        subsystem: ImageLoadingObservation.subsystem,
        category: category
    )

    /// 要素ごとの累計。ログの各行にその時点の累計を載せるために持ちます。
    private static var tallies: [Int: ImageLoadingSlotTally] = [:]

    /// 基準点を切った時点の累計。差分はここからの増分です。
    private static var baseline: [Int: ImageLoadingSlotTally] = [:]

    /// 観測区間の通し番号。0 は基準点をまだ切っていない状態 (差分 = 累計) を表します。
    private(set) static var session = 0

    /// 要素ごとの累計。画面の印が総数の併記に使います。
    static func snapshot() -> [Int: ImageLoadingSlotTally] { tallies }

    /// 要素ごとの、基準点からの差分。画面の印が主に見せる側です。
    ///
    /// 基準点より前から数えられている要素も差分 0 として残します (`items=` の件数に含まれ、
    /// ログ側で対象 ID の `sized` が増えた行が無いことと突き合わせる材料になります)。
    /// ただし印の内訳は差分の大きい順に並ぶため、差分 0 の要素は最後尾に回り、要素数が上限を
    /// 超えると内訳には現れません — 判定対象の差分はログ側で読みます。
    static func deltaSnapshot() -> [Int: ImageLoadingSlotTally] {
        tallies.reduce(into: [:]) { result, entry in
            result[entry.key] = entry.value.subtracting(baseline[entry.key] ?? ImageLoadingSlotTally())
        }
    }

    /// 1 要素の、基準点からの差分。iOS の判定はこの `shown` が 0 かどうかで行います。
    ///
    /// - Parameter itemID: 対象の要素の識別子
    static func delta(itemID: Int) -> ImageLoadingSlotTally {
        (tallies[itemID] ?? ImageLoadingSlotTally())
            .subtracting(baseline[itemID] ?? ImageLoadingSlotTally())
    }

    /// 観測区間を切り直します。この時点の累計を基準点として覚え、通し番号を 1 つ進めます。
    ///
    /// 累計は消しません。消してしまうと「初回表示で何回経由したか」が失われ、基準点の前後を
    /// 突き合わせられなくなります。
    static func beginSession() {
        baseline = tallies
        session += 1
    }

    /// 読み込み中の表示が 1 回組み立てられたことを記録します。
    ///
    /// - Parameters:
    ///   - itemID: 読み込み中を出している要素の識別子
    ///   - size: そのときの表示枠の大きさ。幅か高さが 0 なら枠が決まっていない状態です
    static func record(itemID: Int, size: CGSize) {
        let isSized = size.width > 0 && size.height > 0
        var tally = tallies[itemID] ?? ImageLoadingSlotTally()
        if isSized {
            tally.sized += 1
        } else {
            tally.unsized += 1
        }
        tallies[itemID] = tally
        let delta = tally.subtracting(baseline[itemID] ?? ImageLoadingSlotTally())
        // 1 回ごとに出す。数の正確さがそのまま判定の根拠になるため間引きません。
        // `sized` / `unsized` は基準点からの差分 (印と同じ側)、`total=` が累計です。
        logger.info(
            """
            loading session=\(session, privacy: .public) item=\(itemID, privacy: .public) \
            size=\(Int(size.width), privacy: .public)x\(Int(size.height), privacy: .public) \
            sized=\(delta.sized, privacy: .public) unsized=\(delta.unsized, privacy: .public) \
            total=\(tally.sized, privacy: .public)/\(tally.unsized, privacy: .public)
            """
        )
    }

    /// 読み込み中の表示が実際に画面に出たことを記録します。1 つの表示につき 1 回だけ呼ばれます。
    ///
    /// - Parameters:
    ///   - itemID: 読み込み中を出している要素の識別子
    ///   - size: そのときの表示枠の大きさ
    static func recordShown(itemID: Int, size: CGSize) {
        var tally = tallies[itemID] ?? ImageLoadingSlotTally()
        tally.shown += 1
        tallies[itemID] = tally
        let delta = tally.subtracting(baseline[itemID] ?? ImageLoadingSlotTally())
        // 組み立ての行 (`loading`) と区別できるよう、先頭の語を変えます。`shown` は基準点からの差分、
        // `total=` が累計です。
        logger.info(
            """
            shown session=\(session, privacy: .public) item=\(itemID, privacy: .public) \
            size=\(Int(size.width), privacy: .public)x\(Int(size.height), privacy: .public) \
            shown=\(delta.shown, privacy: .public) total=\(tally.shown, privacy: .public)
            """
        )
    }
}

/// 1 つの要素の読み込み中の表示の回数。
///
/// - `sized`: 表示枠が決まった状態で組み立てた回数
/// - `unsized`: 表示枠が決まる前に組み立てた回数
/// - `shown`: 実際に画面に出た回数 (iOS の判定に使う側)
struct ImageLoadingSlotTally {
    var sized = 0
    var unsized = 0
    var shown = 0

    /// 基準点の計数を差し引いた差分を返します。
    ///
    /// - Parameter other: 差し引く計数 (基準点の値)
    func subtracting(_ other: ImageLoadingSlotTally) -> ImageLoadingSlotTally {
        ImageLoadingSlotTally(
            sized: sized - other.sized,
            unsized: unsized - other.unsized,
            shown: shown - other.shown
        )
    }
}

/// 読み込み中の既定の表示に、組み立てられたことを数える働きだけを足したものです。
///
/// 見た目は本体の既定の表示 (無地) と同じにします。計測する土俵をデモ画面と同じに保つため、
/// 数えること以外は何も変えません。
struct CountedImageLoadingPlaceholder: View {
    /// 読み込み中を出している要素の識別子。
    let itemID: Int

    var body: some View {
        // 表示枠が決まる前かどうかを、この表示自身に与えられた大きさで見分けます。
        GeometryReader { proxy in
            counted(size: proxy.size)
        }
    }

    private func counted(size: CGSize) -> some View {
        ImageLoadingSlotCounter.record(itemID: itemID, size: size)
        let itemID = itemID
        return Color(uiColor: .systemGray5)
            // 組み立てとは別に、実際に画面に出たことを数えます。画面に出る前に組み立てられ、
            // 画面に出ないまま画像に替わった読み込み中を、画面に出た読み込み中と分けるためです。
            .background {
                ImageLoadingSlotShownProbe {
                    ImageLoadingSlotCounter.recordShown(itemID: itemID, size: size)
                }
            }
            // 読み上げの性格は本体の既定の表示に合わせます。差があると、数える構成でだけ
            // 読み上げが変わってしまいます。
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isImage)
    }
}
