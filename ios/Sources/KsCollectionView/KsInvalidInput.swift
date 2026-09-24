import os

// 利用者が渡した値の誤りを知らせる窓口。デバッグビルドでは停止して気づかせ、リリースビルドでは
// 警告を記録して処理を続ける (core/ADR-0011)。続けるときの縮退の仕方は呼び出し側が決める。
@MainActor
internal enum KsInvalidInput {
    // デバッグビルドで停止するかどうか。リリースビルドの縮退を検証するテストだけが下ろす。
    static var assertsInDebug = true

    // 記録した警告の文面。縮退の経路を通ったことをテストが確かめるために読み、同じ文面を
    // 繰り返し出さないための記憶にも使う。表示の評価や先読みの通知のたびに同じ宣言を見直すため、
    // 覚えていないとスクロール中に同じ警告が出続ける。
    // 誤りが続く利用者のアプリで膨らみ続けないよう、新しいものから一定件数だけ残す。
    private(set) static var reportedWarnings: [String] = []
    private static let reportedWarningLimit = 256

    private static let logger = Logger(subsystem: "jp.kamusoft.kscollectionview", category: "image")

    static func report(_ message: String) {
        #if DEBUG
        if assertsInDebug {
            assertionFailure(message)
        }
        #endif
        // 同じ文面は 1 度だけ記録する。
        guard !reportedWarnings.contains(message) else { return }
        reportedWarnings.append(message)
        if reportedWarnings.count > reportedWarningLimit {
            reportedWarnings.removeFirst(reportedWarnings.count - reportedWarningLimit)
        }
        logger.warning("\(message, privacy: .public)")
    }

    // テストが互いの記録を持ち込まないために使う。
    static func reset() {
        assertsInDebug = true
        reportedWarnings.removeAll()
    }
}
