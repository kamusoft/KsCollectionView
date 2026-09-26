import KsCollectionView
import SwiftUI

/// 「グループ化」画面。10,000 件を大小のグループに分けたグリッドを、固定される見出しつきで表示する。
///
/// 下部バーの 2 つの操作は配列をデータ側で組み替えて渡すだけで、触れなければ表示やスクロールの
/// 仕事は増えない。件数・グループ分け・文言は Android Sample の同名画面とそろえる。
struct GroupingDemoView: View {
    @State private var items = GroupingDemoData.items
    @State private var probe = VisibleItemProbe()

    var body: some View {
        VStack(spacing: 0) {
            GroupingFixture.collection(items: items)
                .background(VisibleItemProbeAnchor(probe: probe))
            Divider()
                .overlay(SampleTheme.separator)
            controlBar
        }
    }

    private var controlBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button("並び順を反転") {
                    items = GroupingDemoEdits.reversingGroups(items)
                }
                Button("項目を別のグループへ") {
                    moveVisibleItem()
                }
            }
            .buttonStyle(SampleBarButtonStyle())

            // 件数と列数を含む説明。Android Sample の同じ行と一字一句そろえる。
            Text("10,000 件・縦 2 列 / 横 4 列・見出しは固定")
                .font(.caption)
                .foregroundStyle(SampleTheme.secondaryText)
        }
        .padding(.horizontal, SampleTheme.horizontalPadding)
        .padding(.vertical, SampleTheme.controlVerticalPadding)
        .background(SampleTheme.cell)
    }

    /// 表示中の項目のうち真ん中のものを、隣のグループへ移す。
    private func moveVisibleItem() {
        let offsets = probe.visibleItemOffsets()
        guard !offsets.isEmpty else { return }
        items = GroupingDemoEdits.movingItem(at: offsets[offsets.count / 2], in: items)
    }
}
