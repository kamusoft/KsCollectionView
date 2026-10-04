import KsCollectionView
import SwiftUI
import UIKit

/// 「ページング」画面。偽の取得元から 1 ページずつ読み込む一覧に、ページングと Pull to Refresh を付ける。
///
/// 一覧は画面の全体 (上端のバーの裏と下端のホームインジケータの裏) まで広げ、操作は一覧の上に
/// 浮かせた背景の透けるパネルにまとめる。パネルは左端の丸いボタンに畳める。項目があるときの取り直しに
/// 失敗したら、バーのすぐ下に「更新できませんでした」の帯を一覧の上に浮かせて出す (一覧の余白は変えない)。
///
/// 一覧の上下の余白は、全画面の一覧として入れる上端・下端の安全領域の分だけにし、操作の都合では変えない
/// (パネルは一覧の本来の動きと表示を見るための、上に浮いた操作のため)。かわりにパネルと丸いボタンを
/// 画面の下端から ``SamplePanelMetrics/bottomMargin`` だけ上げて浮かせ、末尾までスクロールしたときの
/// 一覧の底 (次のページの読み込み中・失敗・終端の表示) がパネルの下に見えるようにする。
/// 件数・文言・操作の規則は Android Sample の同名画面とそろえる。
struct PagingDemoView: View {
    @StateObject private var model = PagingDemoModel()
    @State private var layoutChoice = PagingLayoutChoice.list
    @State private var isPanelFolded = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                collection(safeArea: proxy.safeAreaInsets)
                    .ignoresSafeArea()
                    // 取り直し中の状態で一覧を更新し終えたことをモデルに知らせ、取得を始めさせる。
                    // 取得がすぐ終わっても、取り直し中と結果の差し替えが別の回で一覧に届く。
                    .onChange(of: model.state) { state in
                        if state == .refreshing {
                            model.listDidReceiveRefreshing()
                        }
                    }
                    .onDisappear { model.listDidDisappear() }
                if model.refreshFailed {
                    SampleNoticeBanner(text: PagingDemoText.refreshFailed)
                        .padding(.top, SamplePanelMetrics.bannerTopMargin)
                        .padding(.horizontal, SamplePanelMetrics.horizontalMargin)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .transition(.opacity)
                }
                controls
                    .padding(.horizontal, SamplePanelMetrics.horizontalMargin)
                    .padding(.bottom, SamplePanelMetrics.bottomMargin)
            }
            .animation(.easeInOut(duration: SamplePanelMetrics.bannerFadeDuration), value: model.refreshFailed)
            .onChange(of: model.refreshFailed) { isShown in
                // 帯が出たことを読み上げでも知らせる。
                if isShown {
                    UIAccessibility.post(notification: .announcement, argument: PagingDemoText.refreshFailed)
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
            PagingControlPanel(
                layoutChoice: $layoutChoice,
                failsNextLoad: $model.failsNextLoad,
                isEmpty: Binding(get: { model.isEmpty }, set: { model.setEmpty($0) }),
                onReload: { model.reload() },
                onFold: { isPanelFolded = true }
            )
        }
    }

    private func collection(safeArea: EdgeInsets) -> some View {
        KsCollectionView(
            model.items,
            layout: layout,
            contentPadding: EdgeInsets(
                top: safeArea.top,
                leading: 0,
                bottom: safeArea.bottom,
                trailing: 0
            )
        ) { item in
            DemoListRow(item: item)
        }
        .paging(model.state) {
            await model.loadNextPage()
        }
        .pagingFailedFooter { retry in
            PagingMessageView(message: PagingDemoText.loadFailed, retry: retry)
                .padding(.vertical, PagingMessageMetrics.footerVerticalPadding)
        }
        .pagingEndReachedFooter {
            PagingMessageView(message: PagingDemoText.endReached)
                .padding(.vertical, PagingMessageMetrics.footerVerticalPadding)
        }
        .pagingFailedPlaceholder { retry in
            PagingMessageView(message: PagingDemoText.loadFailed, retry: retry)
        }
        .pagingEmptyPlaceholder {
            PagingMessageView(message: PagingDemoText.empty)
        }
        // 読み込み中の表示 (最初の読み込み中・次のページの読み込み中・Pull to Refresh) を補助の文字の色でそろえる。
        .loadingIndicatorColor(SampleTheme.secondaryText)
        .refreshable {
            await model.refresh()
        }
    }

    /// 表示の形。グリッドは「差分更新」のグリッドと同じ 2 列・同じ間隔。
    private var layout: KsCollectionLayout {
        switch layoutChoice {
        case .list:
            .list
        case .grid:
            .grid(
                columns: .fixed(2),
                rowSpacing: GroupHeaderMetrics.gridSpacing,
                columnSpacing: GroupHeaderMetrics.gridSpacing
            )
        }
    }
}
