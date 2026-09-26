import KsCollectionView
import SwiftUI

/// 「差分更新」画面。20 件の配列を操作で組み替え、挿入・削除・更新・移動がアニメーションで
/// 反映されるのを目で追う。
///
/// 件数・グループ分け・操作の規則・文言は Android Sample の同名画面とそろえる。
struct DiffUpdateDemoView: View {
    @State private var model = DiffUpdateModel()
    @State private var layoutChoice = DiffUpdateLayoutChoice.list
    @State private var position = DiffUpdatePosition.head

    var body: some View {
        VStack(spacing: 0) {
            displayControls
            Divider()
                .overlay(SampleTheme.separator)
            collection
            Divider()
                .overlay(SampleTheme.separator)
            operationBar
        }
    }

    /// 表示の切り替え (リスト / グリッド と グループの有無)。
    private var displayControls: some View {
        HStack(spacing: 12) {
            Picker("表示", selection: $layoutChoice) {
                ForEach(DiffUpdateLayoutChoice.allCases) { choice in
                    Text(choice.rawValue).tag(choice)
                }
            }
            .pickerStyle(.segmented)

            // グループの有無の切り替えと並べ直しをモデルの 1 回の変更で行う。別々の更新にすると、
            // 並べ直す前の配列が一度グループありで渡り、離れた同じグループの値 (不正な入力) になる。
            Toggle("グループ", isOn: Binding(
                get: { model.grouped },
                set: { model.setGrouped($0) }
            ))
                .font(.footnote)
                .foregroundStyle(SampleTheme.text)
                .tint(SampleTheme.accent)
                .fixedSize()
        }
        .padding(.horizontal, SampleTheme.horizontalPadding)
        .padding(.vertical, SampleTheme.controlVerticalPadding)
        .background(SampleTheme.cell)
    }

    private var collection: KsCollectionView<DiffUpdateItem> {
        let view = KsCollectionView(model.items, layout: layout) { item in
            DemoListRow(item: item.row)
        }
        guard model.grouped else { return view }
        return view.groups(by: \.group) { group, itemsInGroup in
            GroupHeaderBand(name: DiffUpdateModel.groupName(group), itemCount: itemsInGroup.count)
        }
    }

    private var layout: KsCollectionLayout {
        switch layoutChoice {
        case .list:
            .list(groupSpacing: GroupHeaderMetrics.groupSpacing)
        case .grid:
            .grid(
                columns: .fixed(2),
                rowSpacing: GroupHeaderMetrics.gridSpacing,
                columnSpacing: GroupHeaderMetrics.gridSpacing,
                groupSpacing: GroupHeaderMetrics.groupSpacing,
                headerItemSpacing: GroupHeaderMetrics.gridSpacing
            )
        }
    }

    /// 操作の位置の切り替えと、位置ごとの操作・位置によらない操作。
    private var operationBar: some View {
        VStack(spacing: 8) {
            Picker("位置", selection: $position) {
                ForEach(DiffUpdatePosition.allCases) { position in
                    Text(position.rawValue).tag(position)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Button("挿入") { model.insert(at: position) }
                Button("削除") { model.delete(at: position) }
                Button("更新") { model.update(at: position) }
                Button("移動") { model.move(at: position) }
            }
            HStack(spacing: 8) {
                Button("反転") { model.reverse() }
                Button("シャッフル") { model.shuffle() }
                Button("元に戻す") { model.reset() }
            }
        }
        .buttonStyle(SampleBarButtonStyle())
        .padding(.horizontal, SampleTheme.horizontalPadding)
        .padding(.vertical, SampleTheme.controlVerticalPadding)
        .background(SampleTheme.cell)
    }
}
