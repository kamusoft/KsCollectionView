import Foundation

internal struct KsSnapshotPlan {
    let identifiers: [AnyHashable]
    let reconfigure: [AnyHashable]
    let reload: [AnyHashable]
}
