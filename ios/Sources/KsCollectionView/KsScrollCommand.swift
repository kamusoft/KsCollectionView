import Foundation

internal enum KsScrollCommand {
    case item(id: AnyHashable, position: KsScrollPosition, animated: Bool)
    case start(animated: Bool)
    case end(animated: Bool)
}
