/// 一覧の 1 行。
public struct VerificationItem: Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String

    public init(id: Int, title: String) {
        self.id = id
        self.title = title
    }
}
