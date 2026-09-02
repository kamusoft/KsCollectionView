@MainActor
internal protocol KsScrollCommandReceiver: AnyObject {
    func receive(_ command: KsScrollCommand)
}
