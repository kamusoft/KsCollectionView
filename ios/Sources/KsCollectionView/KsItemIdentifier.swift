import Foundation

internal struct KsItemIdentifier: Hashable, @unchecked Sendable {
    let value: AnyHashable

    init(_ value: AnyHashable) {
        self.value = value
    }
}
