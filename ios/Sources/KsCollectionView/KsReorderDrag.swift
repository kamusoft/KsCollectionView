import CoreGraphics
import UIKit

// 進行中の並べ替えのドラッグ 1 回分の状態。
internal struct KsReorderDrag {
    // 持ち上げた項目の識別子。
    let identifier: AnyHashable
    // 置く先の隙間の位置を追う部品。持ち上げた直後の隙間は元の位置。
    var gapTracker: KsReorderGapTracker
    // UIKit が実際に見せている隙間の位置 (レイアウトが知らせた位置。持ち上げた直後は元の位置)。置く先の予測を
    // 含む `gapTracker.gap` と違い、UIKit が動かした位置だけで進む。
    var shownGap: IndexPath
    // 持ち上げた項目の元の位置の中心 (一覧の内容の座標)。置かずに終えるとき、持ち上げた項目をここへ戻す。
    let sourceCenter: CGPoint?
    // 取りやめたか。スイッチの無効化や、配置を組み直す設定の変化で取りやめる (ドラッグの途中で
    // セッションは終わらせられないため、以後は置けない扱いにして、指を離したら元の位置に戻す)。
    var isCancelled = false
    // UIKit が並びを動かした後、受け入れた並びか元の並びを表示に当て終えるのを待っているか。
    var isResolving = false
    // 当て終えるのを待っている間に、ドラッグのセッションが終わったか。
    var isSessionEnded = false
    // ドロップのセッションが終わったか。
    var hasDropSessionEnded = false
    // ドロップのセッションが終わった後に行う処理 (受け入れなかった並びの戻し・並びの揃え)。
    var workAfterDropSession: [() -> Void] = []
    // このドラッグのセッション。ドロップのセッションの終わりが、このドラッグのものかを確かめるのに使う。
    var dragSession: ObjectIdentifier?
    // 差分データソースの並びを見せている並びへ揃えるまでの間、UIKit が見せている並び。揃えが要らなければ nil。
    var shownSnapshot: NSDiffableDataSourceSnapshot<KsSectionID, KsItemIdentifier>?

    init(identifier: AnyHashable, sourceIndexPath: IndexPath, sourceCenter: CGPoint?) {
        self.identifier = identifier
        gapTracker = KsReorderGapTracker(source: sourceIndexPath)
        shownGap = sourceIndexPath
        self.sourceCenter = sourceCenter
    }
}
