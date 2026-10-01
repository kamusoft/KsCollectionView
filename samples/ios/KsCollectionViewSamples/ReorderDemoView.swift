import KsCollectionView
import SwiftUI
import UIKit

/// 「並べ替え」画面。10,000 件の一覧に並べ替えを付け、長押しからのドラッグで項目を並べ替える。
///
/// 一覧は画面の全体 (上端のバーの裏と下端のホームインジケータの裏) まで広げ、操作は一覧の上に浮かせた
/// 背景の透けるパネルにまとめる。パネルは左端の丸いボタンに畳める。長押しの知らせと、並べ替えを
/// 受け入れなかった知らせは、バーのすぐ下に帯を一覧の上へ浮かせて出す (一覧の余白は変えない)。
///
/// 一覧の上下の余白は、全画面の一覧として入れる上端・下端の安全領域の分だけにし、操作の都合では変えない。
/// パネルと丸いボタンは画面の下端から ``SamplePanelMetrics/bottomMargin`` だけ上げて浮かせる
/// (「ページング」と同じ置き方)。件数・文言・操作の規則は Android Sample の同名画面とそろえる。
struct ReorderDemoView: View {
    @StateObject private var model = ReorderDemoModel()
    @State private var layoutChoice = ReorderLayoutChoice.list
    @State private var isPanelFolded = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                collection(safeArea: proxy.safeAreaInsets)
                    .ignoresSafeArea()
                if let notice = model.notice {
                    SampleNoticeBanner(text: notice)
                        .padding(.top, SamplePanelMetrics.bannerTopMargin)
                        .padding(.horizontal, SamplePanelMetrics.horizontalMargin)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.opacity)
                }
                controls
                    .padding(.horizontal, SamplePanelMetrics.horizontalMargin)
                    .padding(.bottom, SamplePanelMetrics.bottomMargin)
            }
            .animation(.easeInOut(duration: SamplePanelMetrics.bannerFadeDuration), value: model.notice)
            .onChange(of: model.notice) { notice in
                // 帯が出たことを読み上げでも知らせる。
                if let notice {
                    UIAccessibility.post(notification: .announcement, argument: notice)
                }
            }
        }
    }

    /// 操作のパネル。畳んでいるときは丸いボタンだけ。
    @ViewBuilder
    private var controls: some View {
        if isPanelFolded {
            SamplePanelHandle { isPanelFolded = false }
        } else {
            ReorderControlPanel(
                layoutChoice: $layoutChoice,
                isReorderEnabled: $model.isReorderEnabled,
                isGrouped: $model.isGrouped,
                keepsGroups: $model.keepsGroups,
                rejectsMoves: $model.rejectsMoves,
                onFold: { isPanelFolded = true }
            )
        }
    }

    private func collection(safeArea: EdgeInsets) -> KsCollectionView<ReorderDemoItem> {
        let view = KsCollectionView(
            model.items,
            layout: layout,
            contentPadding: EdgeInsets(
                top: safeArea.top,
                leading: 0,
                bottom: safeArea.bottom,
                trailing: 0
            )
        ) { item in
            ReorderDemoRow(item: item)
        }
        .onItemLongTap { item in
            model.didLongPress(item)
        }
        .reorder(
            isEnabled: model.isReorderEnabled,
            canMove: { $0.isMovable },
            canDrop: { model.canDrop($0) },
            accessibilityActions: KsReorderAccessibilityActions(
                previous: ReorderDemoText.moveBackward,
                next: ReorderDemoText.moveForward
            )
        ) { move in
            model.move(move)
        }
        guard model.isGrouped else { return view }
        return view.groups(by: \.group) { group, itemsInGroup in
            GroupHeaderBand(name: ReorderDemoText.groupName(group), itemCount: itemsInGroup.count)
        }
    }

    /// 表示の形。リスト・グリッドとも「差分更新」と同じ間隔 (グリッドは 2 列)。
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
}
