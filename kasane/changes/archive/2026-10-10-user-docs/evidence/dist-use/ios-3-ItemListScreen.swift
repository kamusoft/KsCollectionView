import KsCollectionView
import SwiftUI

// MARK: - モデル

/// 一覧に表示する 1 件。
struct ListItem: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
    let subtitle: String
}

/// 1 ページ分の結果。
private struct ListItemPage: Sendable {
    let items: [ListItem]
    let hasMore: Bool
}

/// 偽のデータ源が返すエラー。
private struct FakeLoadError: Error {}

/// ファイル内で完結する偽のデータ源。遅延があり、ときどき失敗する。
private struct FakeItemService: Sendable {
    private static let pageSize = 20
    private static let totalCount = 95
    private static let delayNanoseconds: UInt64 = 800_000_000

    /// `lastID` の次から 1 ページを返す。`nil` なら最初のページを返す。
    func fetchPage(after lastID: Int?) async throws -> ListItemPage {
        try await Task.sleep(nanoseconds: Self.delayNanoseconds)

        // およそ 4 回に 1 回失敗する。
        if Int.random(in: 0..<4) == 0 {
            throw FakeLoadError()
        }

        let start = (lastID ?? -1) + 1
        let end = min(start + Self.pageSize, Self.totalCount)
        let items = start < end
            ? (start..<end).map { index in
                ListItem(id: index, title: "Item \(index)", subtitle: "Page \(index / Self.pageSize + 1)")
            }
            : []
        return ListItemPage(items: items, hasMore: end < Self.totalCount)
    }
}

/// 配列とページングの状態を持つモデル。
@MainActor
private final class ItemListModel: ObservableObject {
    @Published private(set) var items: [ListItem] = []
    @Published private(set) var pagingState = KsPagingState.idle
    @Published private(set) var refreshFailed = false

    private let service = FakeItemService()
    /// 更新を始めるたびに増やし、それより前に始めた読み込みの結果を捨てる。
    private var generation = 0

    /// 次のページ (配列が空なら最初のページ) を読む。失敗後の再試行もここに来る。
    func loadNextPage() async {
        guard pagingState == .idle || pagingState == .failed else { return }
        let started = generation
        pagingState = .appending
        do {
            let page = try await service.fetchPage(after: items.last?.id)
            guard started == generation else { return }
            // 配列と次の状態は、間に await を挟まずに続けて書く。
            items += page.items
            pagingState = page.hasMore ? .idle : .endReached
        } catch {
            guard started == generation else { return }
            pagingState = Self.isCancellation(error) ? .idle : .failed
        }
    }

    /// 最初のページから読み直す (pull to refresh)。
    func refresh() async {
        generation += 1
        let started = generation
        let previous = pagingState
        pagingState = .refreshing
        refreshFailed = false
        do {
            let page = try await service.fetchPage(after: nil)
            guard started == generation else { return }
            items = page.items
            pagingState = page.hasMore ? .idle : .endReached
        } catch {
            guard started == generation else { return }
            let isCancelled = Self.isCancellation(error)
            if items.isEmpty && !isCancelled {
                // 項目が無いときは、項目なしの失敗の表示を出す。
                pagingState = .failed
            } else {
                // 項目があるときは状態を戻し、失敗は自前の表示で知らせる。
                pagingState = (previous == .appending || previous == .refreshing) ? .idle : previous
                refreshFailed = !isCancelled
            }
        }
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        Task.isCancelled || error is CancellationError
    }
}

// MARK: - 補助の View

/// 1 件分の行。
private struct ListItemRow: View {
    let item: ListItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.body)
            Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// 読み込みに失敗したときの表示。再試行のボタンを持つ。
private struct LoadFailedView: View {
    let message: String
    let retry: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(message)
                .foregroundStyle(.secondary)
            Button("Retry", action: retry)
        }
        .padding()
    }
}

// MARK: - 画面

/// ページング・失敗時の再試行・空の表示・pull to refresh を持つ一覧の画面。
struct ItemListScreen: View {
    @StateObject private var model = ItemListModel()

    init() {}

    var body: some View {
        KsCollectionView(model.items) { item in
            ListItemRow(item: item)
        }
        .paging(model.pagingState) {
            await model.loadNextPage()
        }
        .pagingFailedFooter { retry in
            LoadFailedView(message: "Could not load more items", retry: retry)
        }
        .pagingFailedPlaceholder { retry in
            LoadFailedView(message: "Could not load items", retry: retry)
        }
        .pagingEmptyPlaceholder {
            Text("No items")
                .foregroundStyle(.secondary)
        }
        .pagingEndReachedFooter {
            Text("No more items")
                .foregroundStyle(.secondary)
                .padding()
        }
        .refreshable {
            await model.refresh()
        }
        .overlay(alignment: .top) {
            if model.refreshFailed {
                Text("Could not refresh")
                    .padding(8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.top, 8)
            }
        }
    }
}
