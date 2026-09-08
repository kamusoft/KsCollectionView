import CoreFoundation
import Foundation
import os

/// 計測窓 (フリックしている区間) を記録側のデータで指せるようにする印です。
/// 起動引数 `--signpost-scroll-window` を付けたときだけ働きます。
///
/// スクロール性能の計測では「3 秒間の連続フリック」の区間だけを集計します。この区間を
/// 記録の中で指せないと、テストの終了時刻からの逆算に頼ることになり、窓の位置が
/// 計測の外側の事情 (テストの後始末にかかる時間) で動きます。
///
/// フリックを起こすのは計測用の駆動テスト (別プロセス) ですが、記録をアプリのプロセスに
/// 絞ると駆動側の印は記録に入りません。そこで**駆動側は Darwin 通知を送るだけ**にし、
/// 印はこのアプリ自身が出します。こうすると、アプリだけを対象にした記録でも窓が入ります。
enum ScrollWindowSignpost {
    /// 区間の開始を要求する通知の名前。
    static let beginNotification = "jp.kamusoft.kscollectionview.samples.scrollWindow.begin"

    /// 区間の終了を要求する通知の名前。
    static let endNotification = "jp.kamusoft.kscollectionview.samples.scrollWindow.end"

    /// 記録に出る区間の名前。
    static let intervalName: StaticString = "scroll-window"

    /// 印の出し先。区間として拾えるよう Points of Interest に出します。
    ///
    /// 名前を他所から借りずにここで綴じているのは、初期値の評価が主アクターに縛られないように
    /// するためです (通知はどのスレッドから届くか決まっていません)。
    nonisolated(unsafe) private static let log = OSLog(
        subsystem: "jp.kamusoft.kscollectionview.samples.ios",
        category: .pointsOfInterest
    )

    /// 区間の識別子。開始と終了を対にするために 1 本だけ持ちます。
    nonisolated(unsafe) private static let signpostID = OSSignpostID(log: log)

    /// 印が要求されていれば、駆動側からの通知を待ち受けます。
    ///
    /// 最初のフリックより前 (アプリの起動時) に呼ぶ必要があります。
    static func enableIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("--signpost-scroll-window") else { return }
        observe(beginNotification) {
            os_signpost(.begin, log: log, name: intervalName, signpostID: signpostID)
        }
        observe(endNotification) {
            os_signpost(.end, log: log, name: intervalName, signpostID: signpostID)
        }
    }

    /// 1 つの通知に対する待ち受けを登録します。解除はしません (アプリの生存期間と同じ長さで使います)。
    ///
    /// - Parameters:
    ///   - name: 待ち受ける通知の名前
    ///   - handler: 通知が届いたときに行うこと
    private static func observe(_ name: String, handler: @escaping () -> Void) {
        // C の呼び出し規約に渡せるのは文脈を持たない関数だけなので、行うことは箱に入れて
        // 生かしたまま渡す。印は計測する実行でしか登録されないため、解放は行わない。
        let box = Unmanaged.passRetained(ScrollWindowHandler(handler)).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            box,
            { _, observer, _, _, _ in
                guard let observer else { return }
                Unmanaged<ScrollWindowHandler>.fromOpaque(observer).takeUnretainedValue().run()
            },
            name as CFString,
            nil,
            .deliverImmediately
        )
    }
}

/// 通知が届いたときに行うことを、C の呼び出しへ渡せる形にして保持します。
private final class ScrollWindowHandler {
    private let handler: () -> Void

    /// - Parameter handler: 通知が届いたときに行うこと
    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    /// 保持している処理を実行します。
    func run() {
        handler()
    }
}
