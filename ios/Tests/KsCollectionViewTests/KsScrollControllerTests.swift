import XCTest
@testable import KsCollectionView

@MainActor
final class KsScrollControllerTests: XCTestCase {
    private final class Receiver: KsScrollCommandReceiver {
        var commands: [KsScrollCommand] = []

        func receive(_ command: KsScrollCommand) {
            commands.append(command)
        }
    }

    func test未接続命令は何も起こさない() {
        let controller = KsScrollController()

        controller.scrollToStart()
        controller.scrollToEnd()
        controller.scrollTo(id: 100)
    }

    func test最後に接続したReceiverだけが命令を受け取る() {
        let controller = KsScrollController()
        let first = Receiver()
        let last = Receiver()
        controller.attach(first)
        controller.attach(last)

        controller.scrollToEnd(animated: false)

        XCTAssertTrue(first.commands.isEmpty)
        XCTAssertEqual(last.commands.count, 1)
    }
}
