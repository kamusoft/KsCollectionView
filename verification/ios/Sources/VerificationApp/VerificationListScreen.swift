import KsCollectionView
import SwiftUI

/// 本ライブラリの最小の利用例。行を縦に並べた一覧を 1 つ表示する。
///
/// 配布物を利用者の立場でビルドできることを確かめるための画面で、機能の見本ではない。
public struct VerificationListScreen: View {
    /// 表示する行の数。画面に収まらない数にして、スクロールできる一覧にする。
    private static let itemCount = 100

    private let items = (0..<itemCount).map { index in
        VerificationItem(id: index, title: "Item \(index)")
    }

    public init() {}

    public var body: some View {
        KsCollectionView(items) { item in
            Text(item.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }
}
