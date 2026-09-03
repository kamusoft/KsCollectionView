import KsCollectionView
import SwiftUI

/// 行の高さが変わる 2 経路を実タッチで確かめる検証用画面です。
///
/// タップで行を展開・折りたたみ、展開の瞬間と再利用後に本文が行の上端より上へ
/// はみ出さないか、初回表示で本文が上下にずれないかを目視で確認します。
struct HeightChangeVerificationView: View {
    private static let rowCount = 5

    @State private var path = HeightChangeExpansionPath.parentState
    @State private var layoutChoice = HeightChangeLayoutChoice.list
    @State private var expandedIDs: Set<Int> = []

    private let items = (1...rowCount).map(HeightChangeItem.init(id:))

    var body: some View {
        VStack(spacing: 0) {
            controls
            collection
        }
        .background(SampleTheme.background)
    }

    private var controls: some View {
        VStack(spacing: SampleTheme.controlVerticalPadding) {
            Text("行の高さ変化検証")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("heightChange.title")

            Picker("経路", selection: $path) {
                ForEach(HeightChangeExpansionPath.allCases) { path in
                    Text(path.rawValue).tag(path)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("heightChange.pathPicker")

            Picker("レイアウト", selection: $layoutChoice) {
                ForEach(HeightChangeLayoutChoice.allCases) { choice in
                    Text(choice.rawValue).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("heightChange.layoutPicker")

            // 展開中の行数を body で読む。テンプレートのクロージャは body の評価より後 (UIKit 側) で
            // 実行されるため、そこでしか読まれない state は SwiftUI の依存グラフに載らず、
            // 変化しても body が再評価されない = コレクションへ更新が届かない。
            // body の中でも読むことで依存を張り、タップでの開閉が最初から効くようにしている。
            Text("展開中: \(expandedIDs.count) 行")
                .font(.footnote)
                .foregroundStyle(SampleTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("heightChange.expandedCount")

            Text("行をタップして展開・折りたたみ、本文が行の上端より上へ出ないことを確認します。")
                .font(.footnote)
                .foregroundStyle(SampleTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("heightChange.instruction")
        }
        .padding(.horizontal, SampleTheme.horizontalPadding)
        .padding(.vertical, SampleTheme.controlVerticalPadding)
        .background(SampleTheme.cell)
    }

    private var layout: KsCollectionLayout {
        switch layoutChoice {
        case .list:
            .list
        case .grid:
            .grid(columns: .fixed(2), rowSpacing: 8, columnSpacing: 8)
        }
    }

    private var collection: KsCollectionView<HeightChangeItem> {
        switch path {
        case .parentState:
            // 配列は同値のまま、親の展開状態でテンプレート内容だけが変わる経路です。
            return KsCollectionView(items, layout: layout) { item in
                HeightChangeRowBody(item: item, isExpanded: expandedIDs.contains(item.id))
            }
            .onItemTap { item in
                if expandedIDs.contains(item.id) {
                    expandedIDs.remove(item.id)
                } else {
                    expandedIDs.insert(item.id)
                }
            }
        case .templateState:
            // 親はタップを知らず、テンプレート内の View が自分の状態で展開する経路です。
            return KsCollectionView(items, layout: layout) { item in
                HeightChangeSelfStateCell(item: item)
            }
        }
    }
}
