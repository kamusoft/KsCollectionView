import SwiftUI
import UIKit
import os

// アンカーが表示範囲に残る最小の長さ。切り替えでアンカーの高さが大きく縮んだとき、
// 控えたオフセットのままだとアンカー全体が表示範囲の外へ出てしまうため、この分だけは必ず残す。
private let ksMinimumVisibleAnchorLength: CGFloat = 4

#if DEBUG
// 生存しているセルだけを数えるための弱参照の入れ物。
private struct KsWeakCell {
    weak var cell: KsHostingCell?
}

// 破棄済みセルの記録を畳むしきい値。可視範囲と再利用プールの規模から十分に離した値にする。
private let ksLiveCellCompactionThreshold = 512
#endif

@MainActor
internal final class KsCollectionViewController<Item: Equatable>: UICollectionViewController,
    UICollectionViewDataSourcePrefetching,
    UIGestureRecognizerDelegate {
    private(set) var configuration: KsCollectionConfiguration<Item>
    private(set) var dataSource: UICollectionViewDiffableDataSource<KsSectionID, KsItemIdentifier>!
    private(set) var itemsByID: [AnyHashable: Item] = [:]
    private var keysByID: [AnyHashable: AnyHashable] = [:]
    private var registrations: [AnyHashable: UICollectionView.CellRegistration<KsHostingCell, KsItemIdentifier>] = [:]
    private var pendingCommands: [KsScrollCommand] = []
    private var appliedItems: [Item] = []
    private(set) var appliedIdentifiers: [KsItemIdentifier] = [] {
        didSet { reorderPlannerCache = nil }
    }
    // 控えた位置。`offsetFromTop` は表示範囲の上端 (固定中のグループの見出しが上端を覆っていれば
    // その下端) からの距離で、`belowPinnedHeader` は控えたときに固定中の見出しが上端を覆っていたか。
    private var pendingAnchor: (
        identifier: AnyHashable,
        offsetFromTop: CGFloat,
        belowPinnedHeader: Bool,
        previousOrder: [AnyHashable]
    )?
    // 控えた位置の世代。位置を控え直すたびに増える。遅らせた復元にはこの番号を持たせ、
    // 番号が変わっていたら (別の経路が控え直したか、控えが捨てられたら) その復元は捨てる。
    // 番号を持たないと、重なって届いた適用の最後の完了で最初の控えまで戻してしまう。
    private var anchorGeneration = 0
    private(set) var longPressRecognizer: UILongPressGestureRecognizer?
    private var applyingSnapshotCount = 0
    private var hasAppliedSnapshot = false
    private var isCommandFlushScheduled = false
    private var lastContainerSize: CGSize = .zero
    // 直近のレイアウトパスで解決した列数。列数が表示領域の幅で決まる layout では、塊の件数を
    // この値の倍数に合わせる。レイアウトを 1 度も解いていない間は未解決 (nil) とする。
    private var resolvedColumnCount: Int?
    // 表示領域の大きさが変わる直前に控えた列数と、そのとき控えた位置の世代。変化の後に解けた
    // 列数と突き合わせて、列数が変わったときだけ控えた位置を戻す。世代を併せて持つのは、
    // 控えた位置が別の経路のものへ差し替わっていないことを確かめてから捨てるためである。
    private var containerTransitionAnchor: (columnCount: Int, generation: Int)?
    // 適用済みの snapshot を組んだときの塊の件数。列数の変化で件数が変われば組み直す必要がある。
    private var appliedChunkSize = 0
    // 適用済みの snapshot に載っている塊の表。塊のグループの中での位置 (先頭・末尾) で内側余白・
    // 見出し・区切り線を切り替えるために、セクションの番号から引く。
    private(set) var appliedChunkTable = KsGroupChunkTable.empty {
        didSet { reorderPlannerCache = nil }
    }
    // 塊の組み直しを次の実行機会へ予約したかどうか。レイアウトの途中で snapshot を適用しないため、
    // 発火は同じ実行を抜けてから行う。
    private var isChunkRebuildScheduled = false
    // 塊の件数が変わる適用が復元を要求した、控えた位置の世代。適用の後の実行機会まで待ってから
    // 戻すが、その間に控えが差し替われば番号が合わなくなり、その復元は行わない。
    private var anchorGenerationAwaitingApply: Int?
    // プリフェッチ宣言がある間だけ持つ URL 解決層。台帳を持つため、構成の差し替えでは作り直さない。
    private var imagePrefetcher: KsImagePrefetcher<Item>?
    // 推定高さは固定値ではなく実測から決める。固定値だと推定と実測の差がそのまま
    // 行位置の飛びとスクロールインジケータのずれになる。
    private var estimatedHeight = KsEstimatedHeight()
    private(set) var lastScrollTargetIdentifier: AnyHashable?
    private(set) var processedCommandCount = 0
    // 塊を組み直した回数。列数が変わっても現在の塊の件数が割り切れるうちは組み直さないことを、
    // この値が動かないことで観測できる。計数そのものは構成を問わず持つ (`processedCommandCount`
    // と同じく、値の更新に費用が掛からず計測対象の挙動を変えないため)。
    private(set) var chunkRebuildCount = 0
    // snapshot を適用した回数。グループの値の取り出し方だけが差し替わり、グループの値の並びが
    // 変わらない更新で組み直さないことを、この値が動かないことで観測できる。
    private(set) var snapshotApplyCount = 0
    // 次ページ要求の判定と待ち方 (core/ADR-0020、core/ADR-0022)。ページングを付けていない間は使わない。
    let pagingRequester = KsPagingRequester()
    // 配列の版。ページングを付けた一覧で、配列の中身が変わるたびに進む。頼んだ後の待ち方に使う。
    private(set) var itemsVersion = 0
    // 最後にレイアウトへ測らせたときの、最後の項目の後ろのページングの表示。変わったらフッターの枠の
    // 高さを測り直させる。
    private var displayedPagingFooter: KsPagingDisplay?
    // 次のページの読み込み中の表示を載せる入れ物。初めて要るときに作る。
    private(set) var pagingIndicatorView: KsPagingIndicatorView?
    // 次のページの読み込み中の表示を出しているか (消えるフェードの途中は false)。
    private(set) var isPagingIndicatorShown = false
    // 0 件の入れ物に出しているページングの表示。
    private var displayedPagingPlaceholder: KsPagingDisplay?
    // 項目が 0 件のときのページングの表示を載せる入れ物。初めて要るときに作る。
    private(set) var pagingPlaceholderView: KsPagingPlaceholderView?
    // Pull to Refresh の部品。取り直しの処理が渡されている間だけ一覧に付ける。
    private(set) lazy var pullRefreshControl: KsRefreshControl = {
        let control = KsRefreshControl()
        control.addTarget(self, action: #selector(handlePullRefresh), for: .valueChanged)
        return control
    }()
    // 引っ張って始めた取り直しのインジケータを出しているか (core/ADR-0023)。
    private(set) var isPullRefreshing = false
    // 引っ張って始めた取り直しの処理を実行中か。
    private var isRefreshActionRunning = false
    private var refreshTask: Task<Void, Never>?
    // 取り直し中に、コンテンツを引っ張りの部品の下で止めるために上端に足している余白 (上端の安全領域の分)。
    private(set) var refreshExtraTopInset: CGFloat = 0
    // 見えているルートのヘッダー / フッターの中身を作り直した回数 (内側余白の変化と、最後の項目の後ろの
    // ページングの表示の切り替わり)。余白が変わらない更新で作り直さないことを、この値が動かないことで観測できる。
    private(set) var rootSupplementaryRebuildCount = 0
    // 引っ張って取り直しの処理を呼んだ回数。
    private(set) var pullRefreshCount = 0
    // 引っ張って始めた今回の取り直しの間に、差し替えと同時に先頭を表示したか。表示していなければ、取り直しを
    // 終えるときに先頭を表示する (結果が前と同じ配列で、差し替えが起きなかった場合)。
    private var pullRefreshShowedContentTop = false
    // 一覧が参照しているページングの状態。一覧が状態を書き換えないことを観測するために読む。
    var pagingState: KsPagingState? { configuration.paging?.state }
    // 表示の変化に備えて控えた位置を持っているかどうか。控えが捨てられる契機を観測するために読む。
    var hasPendingAnchor: Bool { pendingAnchor != nil }
    // 適用済みの並びとグループの区切りで行き先を求める部品の控え。並びか塊の表が変わったら捨てる。
    var reorderPlannerCache: KsReorderPlanner?
    // 持ち上げた時点の構成。指を動かし始めた時点で今の構成と比べ、配置を組み直す変化やスイッチの無効化が
    // あればドラッグを取りやめる。持ち上げの取り消しを知らせる通知が無いため、次の持ち上げで上書きするだけにする。
    var reorderLiftConfiguration: KsCollectionConfiguration<Item>?
    // 上端の自動スクロールを進めるフレームの通知。ドラッグのセッションの間だけ持つ。
    private var reorderAutoScrollLink: CADisplayLink?
    private var reorderAutoScrollTimestamp: CFTimeInterval?
    // 上端の自動スクロールの計算 (帯に入ってからの時間を持つ)。回している間だけ持つ。
    private var reorderTopAutoScroll: KsReorderTopAutoScroll?
    // 指の位置 (一覧の枠の上端から、画面に対しての縦の距離)。ドラッグ中の提案のたびに控え、指が一覧の外へ
    // 出たとき・ドロップのセッションが終わったとき・置いたときに捨てる。
    var reorderFingerY: CGFloat?
    // 上端の自動スクロールを回しているか。
    var isReorderAutoScrollRunning: Bool { reorderAutoScrollLink != nil }
    // 進行中の並べ替えのドラッグ。持ち上げたドラッグのセッションが始まってから終わるまで持つ。
    var reorderDrag: KsReorderDrag?
    // ドラッグのセッションに付ける、この一覧の目印。ほかの一覧から来たセッションを見分けるために使う。
    let reorderDragContext = KsReorderDragContext()
    // ドラッグ & ドロップの delegate。受けた呼び出しをこの一覧へ渡す。
    private let reorderDelegate = KsReorderDragDropDelegate()
    // ドラッグの間に届いた構成の最新の 1 つ。ドラッグが終わってから当てる (core/ADR-0033)。
    private(set) var deferredConfiguration: KsCollectionConfiguration<Item>?
    // 並べ替えを受け入れた時点に届いていた配列。受け入れた後、これと同じ配列の更新では置いた並びのまま待ち、
    // 違う配列が届いたらその並びに従う (core/ADR-0027)。受け入れを待っていないときは nil。
    private(set) var reorderAwaitedItems: [Item]?
    // 読み上げの移動操作の付け直しの世代。配列・スイッチ・判定が変わりうる更新のたびに進め、可視セルの操作を
    // 求め直させる。
    private(set) var reorderAccessibilityGeneration = 0
    // セルの中身に読み上げの移動操作の部品を付けるか。並べ替えを付けて文言を渡した構成でだけ付け、並べ替えを
    // 使わない一覧・文言を渡さない一覧の中身には付けない (部品の組み立ては表示に入る項目ごとに走るため)。
    // スイッチの状態では付け外しせず、無効の間は操作を空にする。付け外しは中身の作り直しを伴い、切り替えの
    // たびに表示中のセルのテンプレートを呼び直すことになるため。構成の値から毎回求めず控えるのは、ドラッグの
    // 間に並べ替えの設定だけが先に入れ替わっても、表示中のセルの中身と食い違わないようにするため。
    private(set) var attachesReorderAccessibility = false
    // 並べ替えのドラッグ中か。ドラッグ中は配列を当てず、次ページ要求の判定とスクロール命令の実行を止める
    // (core/ADR-0033、core/ADR-0034)。
    var isReorderDragging: Bool { reorderDrag != nil }
    #if DEBUG
    // 仮想化・再利用が効いていることを観測するための計数。生存中のセルだけを弱参照で保持し、
    // 再利用プールから外れて破棄されたセルは数から外れる。計測のための仕組みが計測対象に混ざらないよう、
    // この計数は debug ビルドにだけ載せる。
    private var liveCells: [ObjectIdentifier: KsWeakCell] = [:]
    private(set) var cellProviderCallCount = 0

    // 現在生存しているセルの数。可視範囲と再利用プールの規模に留まることが仮想化の成立を表す。
    var liveCellCount: Int {
        compactLiveCells()
        return liveCells.count
    }

    // 可視セルの位置依存の表示を揃え直した回数。区切り線を出さない構成でレイアウト確定のたびに
    // 可視セルを走査しないことを、この値が動かないことで観測する。
    private(set) var visibleCellSeparatorUpdateCount = 0

    // 現在の推定高さ。推定が多数派の高さに達したかを観測するために読む。
    // 自己サイズの計数は `KsLayoutDiagnostics` が 1 か所で持つ。
    var currentEstimatedHeight: CGFloat {
        estimatedHeight.value
    }
    #endif
    // 未登録テンプレートキーは snapshot の準備時点で検知する。検知結果だけを観測したい呼び出しでは
    // このフラグを下ろして assertion の発生を抑止する。
    var assertsUnregisteredTemplateKeys = true
    private(set) var unregisteredTemplateKeysAtPreparation: [AnyHashable] = []
    private let logger = Logger(subsystem: "jp.kamusoft.kscollectionview", category: "engine")

    // 差分の適用中か (重ねて適用した snapshot のどれかが終わっていない間)。
    var isApplyingSnapshot: Bool {
        applyingSnapshotCount > 0
    }

    var appliedItemIdentifiers: [AnyHashable] {
        dataSource.snapshot().itemIdentifiers.map(\.value)
    }

    // 適用済みの snapshot に載っている塊の識別子 (載せた順)。グループと塊の区切り方を観測するために読む。
    var appliedSectionIdentifiers: [KsSectionID] {
        dataSource.snapshot().sectionIdentifiers
    }

    init(configuration: KsCollectionConfiguration<Item>) {
        var configuration = configuration
        configuration.layout = Self.validatedLayout(configuration.layout)
        self.configuration = configuration
        attachesReorderAccessibility = Self.attachesReorderAccessibility(configuration)
        super.init(collectionViewLayout: UICollectionViewFlowLayout())
        collectionView.setCollectionViewLayout(makeLayout(), animated: false)
        configureCollectionView()
        configureDataSource()
        syncImagePrefetching()
        apply(items: configuration.items, animatingDifferences: false)
        configuration.scrollController?.attach(self)
        pagingRequester.onFinish = { [weak self] in
            self?.pagingRequestDidFinish()
        }
        reportInvalidPagingThresholdIfNeeded(previous: nil)
        displayedPagingFooter = currentPagingFooterDisplay
        updatePagingPlaceholder()
        updatePagingIndicator()
        syncPullRefreshControl()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) は使用しません")
    }

    func update(configuration: KsCollectionConfiguration<Item>) {
        var configuration = configuration
        configuration.layout = Self.validatedLayout(configuration.layout)
        // ドラッグの間に届いた構成は当てずに最新の 1 つを控え、ドラッグが終わってから当てる (core/ADR-0033)。
        // 並べ替えの設定 (スイッチ・判定・置いたときの処理) だけは、ドラッグの続きに使うためすぐに入れ替える。
        if isReorderDragging {
            deferDuringReorderDrag(configuration)
            return
        }
        // 並べ替えを受け入れた後は、受け入れた時点と同じ配列の更新では置いた並びのまま待つ (core/ADR-0027)。
        // 違う配列が届いたら待つのをやめ、その並びに従う。
        if let awaited = reorderAwaitedItems {
            if configuration.items == awaited {
                configuration.items = self.configuration.items
            } else {
                reorderAwaitedItems = nil
            }
        }
        reorderAccessibilityGeneration &+= 1
        let previousLayout = self.configuration.layout
        let previousPadding = self.configuration.contentPadding
        let previousShowsSeparators = self.configuration.showsSeparators
        let previousSeparatorColor = self.configuration.separatorColor
        let previousController = self.configuration.scrollController
        let previousObservedValue = self.configuration.observedValue
        let previousPaging = self.configuration.paging
        // 頼んだ後の待ち方は「配列の中身が変わったか」で解く。ページングを付けた一覧でだけ比べる。
        if configuration.paging != nil, configuration.items != self.configuration.items {
            itemsVersion &+= 1
        }
        // 状態と配列の版は、判定をしない間 (差分の適用中・画面に載っていない間) も毎回知らせる。知らせないと、
        // その間の状態の往復 (待機 → 追加読み込み中 → 待機) を見逃して待ち方の控えが残り、次を頼まなくなる。
        if let paging = configuration.paging {
            pagingRequester.observe(state: paging.state, itemsVersion: itemsVersion)
        }
        // 観測する値が宣言されているときは、その値が変わった更新でだけテンプレートを呼び直す (ios/ADR-0008)。
        // 宣言が無いときは配列が同値の更新が届くたびに呼び直す (ios/ADR-0006)。
        let observedValueChanged = configuration.observedValue != nil
            && configuration.observedValue != previousObservedValue
        let rebuildsVisibleCellContent = configuration.observedValue == nil || observedValueChanged
        let supplementaryStructureChanged = (self.configuration.header == nil) != (configuration.header == nil)
            || (self.configuration.footer == nil) != (configuration.footer == nil)
            || (self.configuration.paging == nil) != (configuration.paging == nil)
        // グループの宣言の有無が変わると、配列が同じでも塊の区切り方が変わる。
        let groupingDeclarationChanged = (self.configuration.grouping == nil) != (configuration.grouping == nil)
        // グループの値の取り出し方が差し替わると、配列が同じでもグループの値の並びが変わりうる。
        // 取り出し方が同じなら同じ配列から同じ並びが得られるため、ここでは求め直さない。
        let groupValueSourceChanged = self.configuration.grouping != nil
            && configuration.grouping != nil
            && self.configuration.grouping?.valueSource != configuration.grouping?.valueSource
        // 見出しの有無と固定の有無は、塊の区切り方は変えずにレイアウトだけを変える。
        let groupHeaderLayoutChanged = (self.configuration.grouping?.header == nil)
            != (configuration.grouping?.header == nil)
            || self.configuration.grouping?.pinsHeaders != configuration.grouping?.pinsHeaders
        let layoutKindChanged = previousLayout.kind != configuration.layout.kind
        // 読み上げの部品の有無が変わったら、作ってあるセルの中身を新しい有無で作り直す。
        let reorderAccessibilityAttachmentChanged =
            attachesReorderAccessibility != Self.attachesReorderAccessibility(configuration)
        attachesReorderAccessibility = Self.attachesReorderAccessibility(configuration)
        // 表示形態だけでなく行間・列間・内側余白の差し替えでも要素の位置が動くため、
        // layout 値と contentPadding のいずれかが変わったらアンカーを控える。
        let layoutChanged = previousLayout != configuration.layout || previousPadding != configuration.contentPadding
        if layoutChanged {
            captureAnchor()
        }

        self.configuration = configuration
        syncReorderInteraction()

        if previousController !== configuration.scrollController {
            previousController?.detach(self)
            configuration.scrollController?.attach(self)
        }

        // ルートのヘッダー / フッターと上下の内側余白はレイアウト全体の補助ビューに載るため、
        // 有無や余白が変わったらレイアウト全体の構成を作り直す。
        if supplementaryStructureChanged || previousPadding != configuration.contentPadding {
            compositionalLayout?.configuration = makeLayoutConfiguration()
        }
        if layoutChanged || supplementaryStructureChanged || groupHeaderLayoutChanged || groupingDeclarationChanged {
            collectionView.collectionViewLayout.invalidateLayout()
        }
        if previousShowsSeparators != configuration.showsSeparators
            || previousSeparatorColor != configuration.separatorColor
            || layoutKindChanged
            || groupHeaderLayoutChanged {
            updateVisibleCellSeparators()
        }
        updateVisibleRootSupplementaryViews()
        // グループの見出しは項目のテンプレートと同じ条件で内容を作り直す (ios/ADR-0006、ios/ADR-0008)。
        // 配列が変わる更新では、差分の適用の完了時にも新しいグループの内容で作り直す。
        // 取り出し方が差し替わった更新では、ここで作り直すと表示中の (古いグループの) 見出しに新しい
        // 取り出し方の値が入り、消えていく間に新しいグループの名前が出る。このため差分の適用の側
        // (適用の完了時、または適用しない場合はその場) で新しい構成に合わせて作り直す。
        // 新しい構成に見出しの宣言がない更新では、表示中の見出しはすべて消えていくビューになる。
        // ここで作り直すと中身が外れ、空のビューがフェードすることになるため、前の中身のまま残す。
        let declaresGroupHeaders = configuration.grouping?.header != nil
        if (rebuildsVisibleCellContent || groupHeaderLayoutChanged) && !groupValueSourceChanged && declaresGroupHeaders {
            updateVisibleGroupHeaders()
        }

        syncImagePrefetching()
        reportInvalidPagingThresholdIfNeeded(previous: previousPaging?.threshold)
        // 差し替え後の配列に無い項目は、システムから取り消し通知が来ないためここで取り消す。
        // ID が同じまま画像が差し替わった項目も、ここで新しい URL へ切り替える。
        imagePrefetcher?.retain(items: configuration.items)

        apply(
            items: configuration.items,
            animatingDifferences: true,
            reconfiguringAllItems: layoutKindChanged || reorderAccessibilityAttachmentChanged,
            rebuildingVisibleCellContentOnEqualItems: rebuildsVisibleCellContent,
            rebuildingSurvivingVisibleCellContent: observedValueChanged,
            regroupingSections: groupingDeclarationChanged || groupValueSourceChanged,
            precedingPagingState: configuration.paging != nil ? previousPaging?.state : nil
        )
        // 上下の内側余白はルートのヘッダー / フッターの枠の中に入る。余白が変わったら、見えている枠を新しい余白で
        // 測り直させる。変わらない更新では作り直さない。
        if previousPadding != configuration.contentPadding {
            rebuildVisibleRootSupplementaryViews(ofKinds: [KsSupplementaryKind.rootHeader, KsSupplementaryKind.rootFooter])
        }
        invalidatePagingFooterIfNeeded()
        updatePagingPlaceholder()
        updatePagingIndicator()
        endPullRefreshIfFinished()
        syncPullRefreshControl()
        evaluatePaging()
    }

    // 表示領域の大きさが変わる直前。ここでは contentOffset もレイアウト属性もまだ変化前の値で
    // 揃っているため、変化前の並びでの「表示範囲の先頭にある項目」を正しく控えられる。
    // 自身の view が collectionView そのものであるため、`viewWillLayoutSubviews` まで待つと
    // bounds だけが新しい値に差し替わり、古い contentOffset と新しい属性という食い違った対になる。
    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        // 向き別列数では、回転で列数が変わっても塊の件数は列数の最小公倍数のまま変わらない
        // (ios/ADR-0009)。塊を組み直さないぶん組み直しの経路では位置を控えられないため、
        // 列数の変化で行の並びが変わる分をここで控えて、新しい列数が解けた後に戻す。
        // 既に他の経路が位置を控えているときは、そちらの控えた位置の方が先に取られたもの
        // なので上書きしない。
        guard pendingAnchor == nil, let previousColumnCount = resolvedColumnCount else { return }
        captureAnchor()
        // 可視セルが無いなどで控えられなかったときは、戻す対象も無い。
        guard pendingAnchor != nil else { return }
        containerTransitionAnchor = (previousColumnCount, anchorGeneration)
    }

    // 利用者が自分で動かし始めたら、控えた位置は捨てる。控えは変化の前後で表示を保つためのもので、
    // 利用者が動かした後にその位置へ引き戻す理由は無い。
    // これは UIScrollViewDelegate の任意メソッドで、UICollectionViewController 自身は実装を
    // 持たないため super へは委ねない (実体の無い呼び出しになる)。
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        discardPendingAnchor()
    }

    // 固定中のグループの見出しの位置は上端の安全領域に合わせるため、安全領域が変わったら置き直す。
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        // 0 件のときのページングの表示は、上下の安全領域を除いた範囲の真ん中に置く (core/ADR-0025)。
        updatePagingPlaceholderArea()
        updatePagingIndicatorPosition()
        guard pinsGroupHeaders else { return }
        collectionView.collectionViewLayout.invalidateLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        evaluatePaging()
    }

    // スクロールのたびに引っ張りの部品を描く位置を合わせ、次ページ要求を判定し直す。この時点の可視セルは
    // 新しい位置のレイアウトより前のものであるため、判定はレイアウトの確定後 (`viewDidLayoutSubviews`) にも行う。
    // これは UIScrollViewDelegate の任意メソッドで、UICollectionViewController 自身は実装を
    // 持たないため super へは委ねない。
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if collectionView.refreshControl != nil {
            pullRefreshControl.updateDrawingOffset()
        }
        evaluatePaging()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 位置依存の表示 (先頭行の Top 区切り線) を、差分適用後のレイアウト確定に合わせて揃える。
        // スクロール中は毎フレーム通るため、揃える対象 (区切り線) を持たない構成では走査しない。
        // グリッドは区切り線を出さず、ヘッダー・フッターは補助ビューの経路で揃える。タッチ時の背景色の
        // 変更は、差分の適用完了からの揃え直し (配列が変わる更新)、同値配列の更新での可視セルの再構成
        // (`reconfigureVisibleCells`)、セルが表示に入る時点 (`willDisplay`) の揃え直しで届き、
        // いずれも構成を問わず行う。
        if showsListSeparators {
            updateVisibleCellSeparators()
        }
        // 列数はレイアウトを解いて初めて決まる。解けた列数で塊の件数が割り切れなくなっていたら
        // 組み直す。未解決から確定した最初のレイアウトもこの判定に入るため、表示領域の大きさが
        // 一度も変わらない画面でも不完全な行が残らない。
        scheduleChunkRebuildIfNeeded()
        restoreAnchorAfterColumnCountChangeIfNeeded()
        // 次ページ要求はレイアウトが確定した位置で判定する。スクロール中も毎フレームここを通るため、
        // スクロール・一覧の大きさの変化 (回転を含む)・自己サイズの解き直しのどれで画面に出る項目が
        // 変わっても、そのフレームの可視セルで数え直せる (core/ADR-0020)。
        evaluatePaging()
        updatePagingPlaceholderArea()
        updatePagingIndicatorPosition()
        let containerSize = collectionView.bounds.size
        guard containerSize != lastContainerSize else { return }
        lastContainerSize = containerSize
        collectionView.collectionViewLayout.invalidateLayout()
    }

    func disconnect() {
        stopReorderAutoScroll()
        configuration.scrollController?.detach(self)
        // 画面から消えたときは未完了の取得をすべて取り消す。
        imagePrefetcher?.cancelAll()
        // 一覧が破棄されたら、一覧の表示の中で実行している次ページ要求と取り直しの処理を取り消す
        // (core/ADR-0022)。
        pagingRequester.cancel()
        refreshTask?.cancel()
        refreshTask = nil
        isRefreshActionRunning = false
    }

    // プリフェッチ宣言の有無に合わせて URL 解決層を組み立て直す。宣言が続いている間は同じ
    // インスタンスを使い続け、台帳 (どの項目がどの URL を要求しているか) を保つ。
    private func syncImagePrefetching() {
        guard let resources = configuration.prefetchResources else {
            imagePrefetcher?.cancelAll()
            imagePrefetcher = nil
            return
        }

        let prefetcher: KsImagePrefetcher<Item>
        if let existing = imagePrefetcher {
            prefetcher = existing
            prefetcher.resources = resources
            prefetcher.destination = configuration.prefetchDestination
        } else {
            // 先読みは Nuke の共有パイプラインへそのまま流し、ライブラリ独自のキャッシュ層を挟まない。
            // ローダー付属のビューを直接使う利用者とも同じキャッシュを見る (core/ADR-0012)。
            prefetcher = KsImagePrefetcher(
                loading: configuration.imageLoading ?? KsNukeImageLoading(pipeline: .shared),
                id: configuration.id,
                resources: resources,
                destination: configuration.prefetchDestination
            )
            // 列の幅は先読みの通知が来た時点の表示領域から解く。回転や列数の変化の後に始まる
            // 先読みは、その時点の列の幅で出る。
            prefetcher.metrics = { [weak self] in
                self?.prefetchMetrics() ?? KsPrefetchMetrics(columnWidth: 0, displayScale: 1)
            }
            imagePrefetcher = prefetcher
        }
        configuration.prefetcher = KsAnyPrefetcher(prefetcher)
    }

    // 先読みの幅をピクセルへ解くための、現在の表示領域の寸法。列の幅はレイアウトが列数を決めるのと
    // 同じ規則 (表示領域の大きさ・内側余白・列の間隔) で求める。
    func prefetchMetrics() -> KsPrefetchMetrics {
        let insets = collectionView.adjustedContentInset
        let bounds = collectionView.bounds.size
        let container = CGSize(
            width: bounds.width - insets.left - insets.right,
            height: bounds.height - insets.top - insets.bottom
        )
        let padding = configuration.contentPadding
        let columnWidth = KsLayoutMetrics.columnWidth(
            for: configuration.layout,
            containerSize: container,
            horizontalPadding: padding.leading + padding.trailing
        )
        // 画面に載る前は表示倍率が決まっていない (0) ことがある。その間は 1 として解く。
        let scale = traitCollection.displayScale
        return KsPrefetchMetrics(columnWidth: columnWidth, displayScale: scale > 0 ? scale : 1)
    }

    private func configureCollectionView() {
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.prefetchDataSource = self
        collectionView.contentInsetAdjustmentBehavior = .never
        // 指を止めるまで置く先の隙間を動かさない。端での自動スクロールの間も、隙間は指を止めた位置のまま動かない
        // (UIKit 標準の並べ替えと同じ。reorder-capable な置き先でだけ効く)。
        collectionView.reorderingCadence = .slow
        // データソースが並べ替えに対応すると、この controller は既定で対話的な移動の長押しを一覧に付ける
        // (installsStandardGestureForInteractiveMovement)。並べ替えはドラッグ & ドロップで行い、長押しは
        // スイッチが無効の間の長押しの知らせに使うため付けない。
        installsStandardGestureForInteractiveMovement = false

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.cancelsTouchesInView = true
        longPress.delegate = self
        collectionView.addGestureRecognizer(longPress)
        longPressRecognizer = longPress
        // 並べ替えは UIKit 標準のドラッグ & ドロップで行う (ios/ADR-0011)。delegate は常に付け、
        // ドラッグを受け付けるかはスイッチに合わせて切り替える。
        reorderDelegate.owner = self
        collectionView.dragDelegate = reorderDelegate
        collectionView.dropDelegate = reorderDelegate
        syncReorderInteraction()
    }

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource<KsSectionID, KsItemIdentifier>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, identifier in
            guard
                let self,
                let item = itemsByID[identifier.value]
            else {
                return nil
            }

            let key = configuration.templateKey(item)
            let registration = registration(for: key)
            let cell = collectionView.dequeueConfiguredReusableCell(
                using: registration,
                for: indexPath,
                item: identifier
            )
            configure(cell: cell, at: indexPath)
            #if DEBUG
            recordLiveCell(cell)
            #endif
            return cell
        }

        let headerRegistration = UICollectionView.SupplementaryRegistration<KsHostingSupplementaryView>(
            elementKind: KsSupplementaryKind.rootHeader
        ) { [weak self] view, _, _ in
            self?.configureHeader(view)
        }
        let footerRegistration = UICollectionView.SupplementaryRegistration<KsHostingSupplementaryView>(
            elementKind: KsSupplementaryKind.rootFooter
        ) { [weak self] view, _, _ in
            self?.configureFooter(view)
        }
        let groupHeaderRegistration = UICollectionView.SupplementaryRegistration<KsHostingSupplementaryView>(
            elementKind: KsSupplementaryKind.groupHeader
        ) { [weak self] view, _, indexPath in
            self?.configureGroupHeader(view, section: indexPath.section)
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            switch kind {
            case KsSupplementaryKind.rootHeader:
                collectionView.dequeueConfiguredReusableSupplementary(
                    using: headerRegistration,
                    for: indexPath
                )
            case KsSupplementaryKind.rootFooter:
                collectionView.dequeueConfiguredReusableSupplementary(
                    using: footerRegistration,
                    for: indexPath
                )
            default:
                collectionView.dequeueConfiguredReusableSupplementary(
                    using: groupHeaderRegistration,
                    for: indexPath
                )
            }
        }
        // 並べ替えは一覧が自分で並びを動かす形 (reorder-capable) で行う (ios/ADR-0011)。置いた位置への移動は
        // 差分データソースが確定し、確定した後に知らせを求める。動かせるかは持ち上げ (itemsForBeginning) で
        // 判定済みのため、ここではスイッチだけを見る。
        dataSource.reorderingHandlers.canReorderItem = { [weak self] _ in
            self?.configuration.isReorderEnabled ?? false
        }
        dataSource.reorderingHandlers.didReorder = { [weak self] transaction in
            guard
                let self,
                let identifier = reorderDrag.map({ KsItemIdentifier($0.identifier) }),
                let indexPath = Self.indexPath(of: identifier, in: transaction.finalSnapshot)
            else {
                return
            }
            reorderDidReorder(movingTo: indexPath)
        }
    }

    // snapshot の中の項目の位置。
    private static func indexPath(
        of identifier: KsItemIdentifier,
        in snapshot: NSDiffableDataSourceSnapshot<KsSectionID, KsItemIdentifier>
    ) -> IndexPath? {
        guard
            let sectionID = snapshot.sectionIdentifier(containingItem: identifier),
            let section = snapshot.indexOfSection(sectionID),
            let item = snapshot.itemIdentifiers(inSection: sectionID).firstIndex(of: identifier)
        else {
            return nil
        }
        return IndexPath(item: item, section: section)
    }

    #if DEBUG
    // 取り出したセルを弱参照で控える。破棄されたセルは自動的に外れるため、
    // 生存しているセルだけが `liveCellCount` に残る。
    private func recordLiveCell(_ cell: KsHostingCell) {
        cellProviderCallCount += 1
        liveCells[ObjectIdentifier(cell)] = KsWeakCell(cell: cell)
        // 破棄されたセルの記録が溜まり続けないよう、一定量を超えたところで畳む。
        if liveCells.count > ksLiveCellCompactionThreshold {
            compactLiveCells()
        }
    }

    private func compactLiveCells() {
        liveCells = liveCells.filter { $0.value.cell != nil }
    }
    #endif

    private func registration(
        for key: AnyHashable
    ) -> UICollectionView.CellRegistration<KsHostingCell, KsItemIdentifier> {
        if let registration = registrations[key] {
            return registration
        }

        let registration = UICollectionView.CellRegistration<KsHostingCell, KsItemIdentifier> {
            [weak self] cell, indexPath, identifier in
            guard
                let self,
                let item = itemsByID[identifier.value]
            else {
                return
            }
            applyContent(to: cell, item: item, at: indexPath)
        }
        registrations[key] = registration
        return registration
    }

    // snapshot に載せるキーのセル登録をまとめて用意し、未登録のキーはこの時点で検知する。
    // 画面外の要素でも不正なキーを見逃さないため、検知はセル構成まで遅らせない。
    private func prepareRegistrations(for keys: Set<AnyHashable>) {
        keys.forEach { _ = registration(for: $0) }
        let unregistered = keys.filter { !configuration.registry.contains($0) }.map { $0 }
        unregisteredTemplateKeysAtPreparation = unregistered
        #if DEBUG
        if assertsUnregisteredTemplateKeys, !unregistered.isEmpty {
            assertionFailure(
                "キー \(unregistered.map { String(describing: $0) }.joined(separator: ", ")) に対応するテンプレートが登録されていません"
            )
        }
        #endif
    }

    private func applyContent(to cell: KsHostingCell, item: Item, at indexPath: IndexPath) {
        let key = configuration.templateKey(item)
        let content = configuration.registry.content(for: key, item: item)
        // 内容を適用したセルの計測だけを推定高さに数えるため、content と対で設定する
        // (prepareForReuse で内容と一緒に解除される)。
        cell.onMeasuredSize = { [weak self] size, original in
            self?.recordMeasuredSize(size, original: original)
        }
        // 行の高さが content のサイズ変化に 1 パス遅れて追いつく間、ホスト View の既定の
        // 中央配置だと content が上方向にもはみ出す。KsRowContentPlacement で上端へ固定する。
        guard attachesReorderAccessibility else {
            cell.contentConfiguration = UIHostingConfiguration {
                KsRowContentPlacement { content }
            }
            .margins(.all, 0)
            #if DEBUG
            cell.recordContentApplied(withReorderAccessibility: false)
            #endif
            return
        }
        // 読み上げの移動操作は、中身を作る前にモデルへ入れる。作った後に入れると、操作の変化の知らせで
        // 作ったばかりの中身がもう一度描き直される。
        updateReorderAccessibility(of: cell, at: indexPath)
        let reorderAccessibility = cell.reorderAccessibility
        cell.contentConfiguration = UIHostingConfiguration {
            KsRowContentPlacement { content }
                .modifier(KsReorderAccessibilityModifier(model: reorderAccessibility))
        }
        .margins(.all, 0)
        #if DEBUG
        cell.recordContentApplied(withReorderAccessibility: true)
        #endif
    }

    // セルが自己サイズで返した高さを推定高さへ入れます。
    // 一致の判定は、そのセルに渡されていた高さ (original) と測った高さの比較で行います。
    // レイアウトの解き直しが起きるかを決めるのはこの 2 つの比較であり、比較の相手を
    // 「いまの推定値」にすると、レイアウトを渡した後に推定値が動いた分だけ数え違えます。
    // 標本に加えるのは比較を終えてからです。
    private func recordMeasuredSize(_ size: CGSize, original: CGSize) {
        let scale = collectionView.traitCollection.displayScale
        #if DEBUG
        KsLayoutDiagnostics.recordSelfSizedCell(
            matchesEstimate: KsLayoutDiagnostics.matchesLayout(
                measured: size.height,
                original: original.height
            )
        )
        #endif
        estimatedHeight.record(height: size.height, width: size.width, scale: scale)
    }

    // 区切り線を出す構成か。区切り線はリストでだけ描く。
    private var showsListSeparators: Bool {
        switch configuration.layout.kind {
        case .list:
            configuration.showsSeparators
        case .grid:
            false
        }
    }

    private func configure(cell: KsHostingCell, at indexPath: IndexPath) {
        let showsSeparators = showsListSeparators
        cell.configureSeparators(
            showsTop: showsSeparators && showsTopSeparator(at: indexPath),
            showsBottom: showsSeparators,
            color: configuration.separatorColor ?? KsHostingCell.defaultSeparatorColor
        )
        // 既定はプラットフォーム標準のハイライト相当の半透明色。不透明色にするとセル内容を覆い隠す。
        cell.configureTouchFeedback(
            color: configuration.touchFeedbackColor ?? KsHostingCell.defaultTouchFeedbackColor
        )
        updateReorderAccessibility(of: cell, at: indexPath)
    }

    // 上端の区切り線を出す項目か。線はグループごとに先頭行の上端へ引く (core/ADR-0016)。
    // 塊の境界では item が 0 に戻るため、グループの先頭の塊かどうかも合わせて見る。
    // 見出しを宣言しないグループでは、境目で前のグループの下端の線と重なるため最初のグループにだけ出す。
    private func showsTopSeparator(at indexPath: IndexPath) -> Bool {
        guard indexPath.item == 0 else { return false }
        guard let chunk = appliedChunkTable.chunk(at: indexPath.section) else {
            return indexPath.section == 0
        }
        guard chunk.isFirstChunkInGroup else { return false }
        return chunk.isFirstGroup || groupHasHeader(groupIndex: chunk.groupIndex)
    }

    // グループに見出しを表示するか。見出しの宣言があり、グループに項目があるときだけ表示する。
    private func groupHasHeader(groupIndex: Int) -> Bool {
        guard
            configuration.grouping?.header != nil,
            appliedChunkTable.groups.indices.contains(groupIndex)
        else {
            return false
        }
        return !appliedChunkTable.groups[groupIndex].itemRange.isEmpty
    }

    // ルートのヘッダー。上の内側余白は、ヘッダーもコンテンツの一部として、その上に入れる (core/ADR-0006)。
    // ヘッダーが無いときは、上の内側余白の分の空白だけを置く。
    private func configureHeader(_ view: KsHostingSupplementaryView) {
        guard let content = configuration.header?() else {
            view.clear()
            return
        }
        let padding = configuration.contentPadding
        view.configure(
            using: UIHostingConfiguration { content }
                .margins(.all, EdgeInsets(top: padding.top, leading: padding.leading, bottom: 0, trailing: padding.trailing))
        )
    }

    // ルートのフッター。下の内側余白はフッターの下に入れる。
    // ページングを付けた一覧では、同じ枠の中でページングの表示をフッターの上に置く。
    private func configureFooter(_ view: KsHostingSupplementaryView) {
        if configuration.paging != nil {
            configurePagingFooter(view)
            return
        }
        guard let content = configuration.footer?() else {
            view.clear()
            return
        }
        let padding = configuration.contentPadding
        view.configure(
            using: UIHostingConfiguration { content }
                .margins(.all, EdgeInsets(top: 0, leading: padding.leading, bottom: padding.bottom, trailing: padding.trailing))
        )
    }

    // グループの見出しに、そのグループのグループの値と項目で内容を設定する。塊に割れたグループでは、
    // どの塊の見出しにも同じ内容を設定する。
    private func configureGroupHeader(_ view: KsHostingSupplementaryView, section: Int) {
        guard
            let header = configuration.grouping?.header,
            let group = appliedChunkTable.group(containingSection: section),
            !group.itemRange.isEmpty,
            group.itemRange.upperBound <= appliedIdentifiers.count
        else {
            view.clear()
            return
        }
        // グループ内の項目は、適用済みの並びの項目の位置の範囲から、見出しを組み立てるときにだけ引く。
        // 配列全体の写しを持ち続けないため、見出しを宣言しない一覧では項目を複製しない。
        let items = appliedIdentifiers[group.itemRange].compactMap { itemsByID[$0.value] }
        guard let first = items.first else {
            view.clear()
            return
        }
        let content = header(first, items)
        view.configure(using: UIHostingConfiguration { content }.margins(.all, 0))
    }

    private func updateVisibleRootSupplementaryViews() {
        collectionView.visibleSupplementaryViews(
            ofKind: KsSupplementaryKind.rootHeader
        ).compactMap { $0 as? KsHostingSupplementaryView }.forEach(configureHeader)
        collectionView.visibleSupplementaryViews(
            ofKind: KsSupplementaryKind.rootFooter
        ).compactMap { $0 as? KsHostingSupplementaryView }.forEach(configureFooter)
    }

    // 表示中のグループの見出し (塊の見出しを含む) の内容を、現在の構成と塊の表で設定し直す。
    // 見出しのビューは作り直さず、ホスティングの構成だけを差し替える。
    private func updateVisibleGroupHeaders() {
        for indexPath in collectionView.indexPathsForVisibleSupplementaryElements(
            ofKind: KsSupplementaryKind.groupHeader
        ) {
            guard let view = collectionView.supplementaryView(
                forElementKind: KsSupplementaryKind.groupHeader,
                at: indexPath
            ) as? KsHostingSupplementaryView else {
                continue
            }
            configureGroupHeader(view, section: indexPath.section)
        }
    }

    private func updateVisibleCellSeparators() {
        #if DEBUG
        visibleCellSeparatorUpdateCount += 1
        #endif
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let cell = collectionView.cellForItem(at: indexPath) as? KsHostingCell else {
                continue
            }
            configure(cell: cell, at: indexPath)
        }
    }

    // 可視セルを現在の構成 (テンプレート・位置依存の表示・タッチ時の背景色) で作り直す。
    // 画面外のセルは表示されるときに最新の構成で作られるため対象にしない。
    // `rebuildingContent` が false のときはテンプレートのクロージャを呼び直さず、
    // 位置依存の表示とタッチ時の背景色だけを現在の構成に揃える。
    private func reconfigureVisibleCells(rebuildingContent: Bool = true) {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard
                let cell = collectionView.cellForItem(at: indexPath) as? KsHostingCell,
                let identifier = dataSource.itemIdentifier(for: indexPath)?.value,
                let item = itemsByID[identifier]
            else {
                continue
            }
            if rebuildingContent {
                _ = registration(for: configuration.templateKey(item))
                applyContent(to: cell, item: item, at: indexPath)
            }
            configure(cell: cell, at: indexPath)
        }
    }

    private func apply(
        items: [Item],
        animatingDifferences: Bool,
        reconfiguringAllItems: Bool = false,
        rebuildingVisibleCellContentOnEqualItems: Bool = true,
        rebuildingSurvivingVisibleCellContent: Bool = false,
        regroupingSections: Bool = false,
        precedingPagingState: KsPagingState? = nil
    ) {
        // 塊の件数は現在の layout と解決済みの列数から決まる (ios/ADR-0009)。件数が変われば
        // 塊の切れ目が列の途中に落ちるため、配列が同値でも組み直す。
        let chunkSize = currentChunkSize()
        let chunkSizeChanged = hasAppliedSnapshot && chunkSize != appliedChunkSize

        // 項目もレイアウト種別も変わらない更新でも、テンプレートのクロージャは呼び出し側の状態を
        // 捕捉しうるため可視セルは作り直す (ios/ADR-0006)。塊の件数が変わって組み直しへ進む場合も
        // この作り直しは要る。後段の再構成は差分 (位置の変化・残存する可視セル) からしか作られず、
        // 同値配列ではどちらも空になるため、ここを通さないと作り直しが一度も起きない。
        let itemsAreEqual = !reconfiguringAllItems && hasAppliedSnapshot && items == appliedItems
        if itemsAreEqual {
            reconfigureVisibleCells(rebuildingContent: rebuildingVisibleCellContentOnEqualItems)
        }
        // 差分計算も snapshot 適用も要らない更新はここで終わる。グループの宣言の有無やグループの値の
        // 取り出し方が変わった更新は、配列が同じでも塊の区切り方が変わりうるため先へ進む。新しい
        // グループの値の並びが適用済みと同じなら、塊の表が一致して snapshot の適用には進まない。
        if itemsAreEqual, !chunkSizeChanged, !regroupingSections {
            settleAnchorIfNeeded()
            showContentTopIfRefreshEnded(precedingPagingState: precedingPagingState)
            if !isApplyingSnapshot {
                flushPendingCommands()
            }
            return
        }

        let oldItems = itemsByID
        let oldKeys = keysByID
        let plan = KsSnapshotPlanner.makePlan(
            newItems: items,
            oldItems: oldItems,
            oldKeys: oldKeys,
            id: configuration.id,
            key: configuration.templateKey
        )

        appliedItems = items
        // 重複した安定 ID は不正入力。debug では KsSnapshotPlanner の assertion が検知し、
        // release では後勝ちで 1 件へ畳んで警告ログを残す (未登録テンプレートキーと同じ縮退方針)。
        itemsByID = Dictionary(
            items.map { (configuration.id($0), $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        keysByID = Dictionary(
            items.map { (configuration.id($0), configuration.templateKey($0)) },
            uniquingKeysWith: { _, latest in latest }
        )
        if itemsByID.count != items.count {
            logger.warning("重複した安定 ID を後勝ちで解決しました")
        }
        prepareRegistrations(for: Set(keysByID.values))

        let identifiers = plan.identifiers.map(KsItemIdentifier.init)
        // 配列をグループごとに、その先頭から塊の件数ずつ区切る (ios/ADR-0010)。件数は列数の倍数
        // なので、塊の境界は必ず行の切れ目に落ち、列数に満たない行は各グループの最終行にだけ現れる。
        let chunkTable = KsGroupChunkTable.make(
            groupValues: configuration.grouping.map { grouping in
                plan.identifiers.compactMap { itemsByID[$0].map(grouping.value) }
            },
            itemCount: identifiers.count,
            chunkSize: chunkSize
        )
        reportReappearingGroupValues(chunkTable.reappearingValues)
        let sectionsChanged = chunkTable != appliedChunkTable
        let currentIdentifiers = dataSource.snapshot().itemIdentifiers
        let positionsChanged = identifiers != currentIdentifiers
        // 観測する値が変わった更新では、内容が同値のまま残る可視セルもテンプレートを呼び直す (ios/ADR-0008)。
        // 配列の変化と同時に届いた場合に、既存のセルが古い観測値のまま取り残されるのを防ぐ。
        // 画面外のセルは表示されるときに最新の構成で作られるため対象にしない。
        let survivingVisibleIdentifiers: Set<KsItemIdentifier>
        if rebuildingSurvivingVisibleCellContent {
            let newIdentifiers = Set(identifiers)
            survivingVisibleIdentifiers = Set(
                collectionView.indexPathsForVisibleItems
                    .compactMap { dataSource.itemIdentifier(for: $0) }
                    .filter(newIdentifiers.contains)
            )
        } else {
            survivingVisibleIdentifiers = []
        }
        // 初回は section を載せるために必ず適用する (項目が空でも header / footer を表示するため)。
        let hasSnapshotChanges = !hasAppliedSnapshot
            || chunkSizeChanged
            || sectionsChanged
            || positionsChanged
            || !plan.reconfigure.isEmpty
            || !plan.reload.isEmpty
            || reconfiguringAllItems
            || !survivingVisibleIdentifiers.isEmpty
        guard hasSnapshotChanges else {
            // 組み直しを求められたが構成が変わらなかった場合は、見出しの内容だけを新しい宣言で
            // 作り直す (区切りが同じなので、表示中の見出しと新しいグループの値は食い違わない)。
            if regroupingSections {
                updateVisibleGroupHeaders()
            }
            settleAnchorIfNeeded()
            showContentTopIfRefreshEnded(precedingPagingState: precedingPagingState)
            if !isApplyingSnapshot {
                flushPendingCommands()
            }
            return
        }

        // 塊ごとのセクションへ載せる。項目が空でも塊を 1 つ載せる。
        var snapshot = NSDiffableDataSourceSnapshot<KsSectionID, KsItemIdentifier>()
        snapshot.appendSections(chunkTable.sectionIDs)
        for (sectionID, range) in zip(chunkTable.sectionIDs, chunkTable.sectionItemRanges) where !range.isEmpty {
            snapshot.appendItems(Array(identifiers[range]), toSection: sectionID)
        }
        appliedChunkSize = chunkSize
        appliedChunkTable = chunkTable
        let existingIdentifiers = Set(currentIdentifiers)
        let reloadIdentifiers = plan.reload.map(KsItemIdentifier.init).filter(existingIdentifiers.contains)
        let reloadedIdentifiers = Set(reloadIdentifiers)
        // 位置の変化は再構成の理由にしない (位置依存の表示は apply 完了後の可視セル更新で揃える)。
        // 作り直す要素は再構成の対象から外す。同じ snapshot で同一要素の再構成と作り直しを
        // 同時に指示することはできない。
        let planReconfigureIdentifiers = Set(plan.reconfigure.map(KsItemIdentifier.init))
        let reconfigureIdentifiers = (
            reconfiguringAllItems
                ? identifiers.filter(existingIdentifiers.contains)
                : identifiers.filter {
                    (planReconfigureIdentifiers.contains($0) || survivingVisibleIdentifiers.contains($0))
                        && existingIdentifiers.contains($0)
                }
        ).filter { !reloadedIdentifiers.contains($0) }
        snapshot.reconfigureItems(reconfigureIdentifiers)
        snapshot.reloadItems(reloadIdentifiers)

        appliedIdentifiers = identifiers
        hasAppliedSnapshot = true
        applyingSnapshotCount += 1
        snapshotApplyCount += 1
        // 塊の件数が変わる再適用は、それ自体は動かして見せる変化ではない。塊の件数が 1 件でも
        // 動けば先頭の塊を除くほぼ全項目が隣の塊へ移る差分になり、アニメーションを付けると
        // 位置の復元と重なって表示が乱れる。配列の増減が同時に届いていても、その増減だけを
        // 動かして見せる手立ては差分の側に無いため、塊の件数の変化を契機に一律で抑止する。
        let animates = animatingDifferences && !chunkSizeChanged
        // 塊の件数が変わる適用では、適用の直後に UIKit が表示位置を自分で動かす。その動きの
        // 後に戻さないと、控えた位置が上書きされて表示範囲が 1 画面ぶんずれる。控えた位置が
        // 無ければ復元は空振りするだけなので、契機は塊の件数の変化だけで判定する。
        if chunkSizeChanged {
            anchorGenerationAwaitingApply = anchorGeneration
        }
        // 端を表示中にその端へ項目が入る差し替えでは、差分のアニメーションの中で表示範囲をその端へ
        // 留める。留めないと、末尾への挿入は表示範囲の下へ足されて見えない。レイアウトは差分の適用の
        // 中で更新の後の表示位置を問い合わせるので、その間だけ留める端を渡す。
        compositionalLayout?.edgeToKeepAfterUpdate = animates
            ? edgeToKeep(previous: currentIdentifiers, next: identifiers, precedingPagingState: precedingPagingState)
            : nil
        defer { compositionalLayout?.edgeToKeepAfterUpdate = nil }
        // 取り直しの結果は差し替えと同時に先頭から表示する (core/ADR-0021)。アニメーションを切る差し替え
        // (塊の件数が変わる適用) では差分の適用の中で位置を動かせないため、適用の直後に先頭へ合わせる。
        let showsTopAfterApply = !animates && showsTopOnReplacement(precedingPagingState: precedingPagingState)
        dataSource.apply(snapshot, animatingDifferences: animates) { [weak self] in
            guard let self else { return }
            applyingSnapshotCount = max(0, applyingSnapshotCount - 1)
            updateVisibleCellSeparators()
            updateVisibleRootSupplementaryViews()
            // 見出しの識別はグループの値なので、項目の数や内容だけが変わったグループの見出しは
            // 差分の適用では作り直されない。適用の完了時に新しいグループの内容を設定し直す。
            updateVisibleGroupHeaders()
            // 保留中の命令は、重ねて適用された snapshot がすべて反映されてから実行する。
            guard applyingSnapshotCount == 0 else { return }
            collectionView.layoutIfNeeded()
            if showsTopAfterApply {
                anchorGenerationAwaitingApply = nil
                scrollToContentTopAfterReplacement()
            } else if let requestedGeneration = anchorGenerationAwaitingApply {
                anchorGenerationAwaitingApply = nil
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    // 控えが差し替わっていたら、この適用が要求した復元ではない。遅らせている間に
                    // 利用者がスクロールを始めていた場合も、控えが捨てられて番号が合わなくなる。
                    guard anchorGeneration == requestedGeneration else { return }
                    collectionView.layoutIfNeeded()
                    restorePendingAnchor()
                }
            } else {
                restorePendingAnchor()
            }
            flushPendingCommands()
            scheduleChunkRebuildIfNeeded()
            evaluatePaging()
        }
    }

    // 差し替えの直前に表示範囲がコンテンツの先頭 / 末尾にあり (1pt 未満の差は一致とみなす)、
    // 差し替えでその端に新しい項目が入るとき、表示範囲を留める端。どちらでもなければ nil で、
    // 表示範囲はコンテンツの位置を保つ既定のままにする。先頭と末尾の両方に当たるときは先頭を採る。
    //
    // ページングを付けた一覧では、差し替えの直前のページングの状態で置き方を変える (core/ADR-0021)。
    // 直前が取り直し中なら位置によらず先頭を留め、直前が終端以外なら末尾には留めない。
    private func edgeToKeep(
        previous: [KsItemIdentifier],
        next: [KsItemIdentifier],
        precedingPagingState: KsPagingState?
    ) -> KsContentEdge? {
        guard hasAppliedSnapshot, !next.isEmpty else { return nil }
        if showsTopOnReplacement(precedingPagingState: precedingPagingState) {
            if isPullRefreshing {
                pullRefreshShowedContentTop = true
            }
            return .top
        }
        let insets = collectionView.adjustedContentInset
        let offset = collectionView.contentOffset.y
        let top = -insets.top
        let bottom = max(top, collectionView.contentSize.height + insets.bottom - collectionView.bounds.height)
        let previousIdentifiers = Set(previous)
        if offset - top < 1, let first = next.first, !previousIdentifiers.contains(first) {
            return .top
        }
        if bottom - offset < 1, let last = next.last, !previousIdentifiers.contains(last) {
            if let precedingPagingState, precedingPagingState != .endReached {
                return nil
            }
            return .bottom
        }
        return nil
    }

    // 差し替えと同時にコンテンツの先頭を表示する差し替えか (core/ADR-0021)。
    // - 引っ張って始めた取り直しの間 (取り直しの処理を呼んでから、インジケータを出し終えるまで) の差し替えは、
    //   差し替えの直前の状態によらない。ページングを付けない一覧でも同じ。取得がすぐ終わり、取り直し中の
    //   状態と差し替えが 1 回の更新にまとまっても効く
    // - それ以外は、ページングを付けた一覧で差し替えの直前の状態が取り直し中のとき (利用者が自分で始めた取り直し)
    private func showsTopOnReplacement(precedingPagingState: KsPagingState?) -> Bool {
        isPullRefreshing || (configuration.paging != nil && precedingPagingState == .refreshing)
    }

    // 取り直しの結果が前と同じ配列で、差分を適用しない更新でも、状態が取り直し中から抜ける回を取り直しの
    // 結果が届いた回として先頭を表示する (core/ADR-0021)。取り直し中のままの描き直しでは動かさない。
    // 引っ張って始めた取り直しで配列が変わらなかった場合は、取り直しを終えるときに先頭を表示する
    // (`finishPullRefresh`)。同じ配列の更新は描き直しと見分けられないため、その場では動かさない。
    private func showContentTopIfRefreshEnded(precedingPagingState: KsPagingState?) {
        guard
            configuration.paging != nil,
            precedingPagingState == .refreshing,
            configuration.paging?.state != .refreshing
        else {
            return
        }
        scrollToContentTopAfterReplacement()
    }

    // 差分の適用の後に表示範囲をコンテンツの先頭へ合わせる。控えていた位置は戻さない。
    private func scrollToContentTopAfterReplacement() {
        if isPullRefreshing {
            pullRefreshShowedContentTop = true
        }
        discardPendingAnchor()
        collectionView.setContentOffset(
            CGPoint(x: collectionView.contentOffset.x, y: -collectionView.adjustedContentInset.top),
            animated: false
        )
    }

    // 塊の件数が現在の列数と合わなくなっていたら、次の実行機会に組み直しを予約する。
    private func scheduleChunkRebuildIfNeeded() {
        guard hasAppliedSnapshot, !isChunkRebuildScheduled else { return }
        guard currentChunkSize() != appliedChunkSize else { return }
        isChunkRebuildScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isChunkRebuildScheduled = false
            rebuildChunksIfNeeded()
        }
    }

    // 塊だけを組み直す。配列は変わらないためテンプレートは呼び直さず、表示範囲の先頭にある
    // 項目を控えて組み直しの後に同じ位置へ戻す。
    private func rebuildChunksIfNeeded() {
        guard hasAppliedSnapshot, !isApplyingSnapshot else { return }
        guard currentChunkSize() != appliedChunkSize else { return }
        chunkRebuildCount += 1
        captureAnchor()
        apply(
            items: configuration.items,
            animatingDifferences: false,
            rebuildingVisibleCellContentOnEqualItems: false
        )
    }

    // 同じグループの値が配列の離れた位置に再び現れる入力は不正入力 (core/ADR-0011、core/ADR-0015)。
    // 表示は配列の順のまま別々のグループとして続け、並べ替えたり消したりしない。
    private func reportReappearingGroupValues(_ values: [AnyHashable]) {
        for value in values {
            KsInvalidInput.report(
                "同じグループの値 \(String(describing: value.base)) が配列の離れた位置に再び現れました。"
                    + "同じグループの値を持つ項目は配列の中で続けて並べてください"
            )
        }
    }

    // layout 値の間隔の負の値は不正入力 (core/ADR-0011)。検知したら知らせ、0 として表示を続ける。
    private static func validatedLayout(_ layout: KsCollectionLayout) -> KsCollectionLayout {
        let names = layout.negativeSpacingNames
        guard !names.isEmpty else { return layout }
        KsInvalidInput.report(
            "layout 値の \(names.joined(separator: ", ")) に負の値が指定されました。0 として表示します"
        )
        return layout.clampingNegativeSpacings()
    }

    // 現在の layout と解決済みの列数から決まる、1 つの塊に載せる件数。
    private func currentChunkSize() -> Int {
        KsSectionChunking.chunkSize(
            columnMultiple: KsSectionChunking.columnMultiple(
                layout: configuration.layout,
                resolvedColumnCount: resolvedColumnCount
            )
        )
    }

    var compositionalLayout: KsCompositionalLayout? {
        collectionView.collectionViewLayout as? KsCompositionalLayout
    }

    private func makeLayout() -> KsCompositionalLayout {
        let layout = KsCompositionalLayout(
            sectionProvider: { [weak self] sectionIndex, environment in
                self?.makeSection(at: sectionIndex, environment: environment)
            },
            configuration: makeLayoutConfiguration()
        )
        layout.groupHeaderPinning = { [weak self] in
            self?.groupHeaderPinning()
        }
        layout.onInteractivelyMovingTargetChange = { [weak self] targets in
            self?.reorderGapDidMove(to: targets)
        }
        return layout
    }

    // グループの見出しを固定する構成か。見出しの宣言があり、固定を外していないとき。
    private var pinsGroupHeaders: Bool {
        guard let grouping = configuration.grouping else { return false }
        return grouping.header != nil && grouping.pinsHeaders
    }

    // 見出しを固定する構成のときに、レイアウトが見出しの属性を書き換える材料。
    // 固定しないときは書き換えない (nil)。
    private func groupHeaderPinning() -> KsGroupHeaderPinning? {
        guard pinsGroupHeaders else { return nil }
        return KsGroupHeaderPinning(
            chunkTable: appliedChunkTable,
            headerItemSpacing: configuration.layout.headerItemSpacing,
            rowSpacing: configuration.layout.rowSpacing
        )
    }

    // レイアウト全体の構成。ルートのヘッダー / フッターは塊ではなくレイアウト全体に 1 つずつ付け、
    // 上下の内側余白をその外側 (ヘッダーの上・フッターの下) に置く (core/ADR-0006)。ヘッダー /
    // フッターの前後には行間を入れない。ヘッダー / フッターが無くても余白があれば、余白の分だけの
    // 空白を同じ位置に置く (グループの見出しの上に余白を置くため、塊の内側余白では代わりにならない)。
    private func makeLayoutConfiguration() -> UICollectionViewCompositionalLayoutConfiguration {
        let padding = configuration.contentPadding
        var items: [NSCollectionLayoutBoundarySupplementaryItem] = []
        if configuration.header != nil || padding.top > 0 {
            items.append(
                makeRootBoundaryItem(
                    kind: KsSupplementaryKind.rootHeader,
                    alignment: .top,
                    height: configuration.header != nil
                        ? .estimated(KsEstimatedHeight.defaultValue)
                        : .absolute(padding.top)
                )
            )
        }
        // ページングを付けた一覧では、ページングの表示を載せるためにフッターの枠を常に置く。
        // 表示もフッターも余白も無いときは高さを持たない。
        let hostsFooterContent = configuration.footer != nil || configuration.paging != nil
        if hostsFooterContent || padding.bottom > 0 {
            items.append(
                makeRootBoundaryItem(
                    kind: KsSupplementaryKind.rootFooter,
                    alignment: .bottom,
                    height: hostsFooterContent
                        ? .estimated(KsEstimatedHeight.defaultValue)
                        : .absolute(padding.bottom)
                )
            )
        }
        let layoutConfiguration = UICollectionViewCompositionalLayoutConfiguration()
        layoutConfiguration.boundarySupplementaryItems = items
        return layoutConfiguration
    }

    private func makeSection(
        at sectionIndex: Int,
        environment: any NSCollectionLayoutEnvironment
    ) -> NSCollectionLayoutSection {
        // 配列はグループごとに内部の塊へ分かれて載る。塊の境界が見た目に出ないよう、内側余白・
        // 行間・見出しを塊のグループの中での位置で切り替える (ios/ADR-0009、ios/ADR-0010)。
        // 塊の表は snapshot を組んだ時点で決まる。まだ組んでいない間や表より後ろの塊を解いて
        // いるときは、1 つのグループの末尾の塊として扱う。
        let chunk = appliedChunkTable.chunk(at: sectionIndex) ?? KsChunkInfo(
            groupIndex: 0,
            chunkInGroup: sectionIndex,
            chunkCountInGroup: sectionIndex + 1,
            itemCount: 0,
            isFirstGroup: true,
            isLastGroup: true
        )
        let hasHeader = appliedChunkTable.chunk(at: sectionIndex) != nil
            && groupHasHeader(groupIndex: chunk.groupIndex)
        let layout = configuration.layout
        let padding = configuration.contentPadding
        let horizontalPadding = padding.leading + padding.trailing
        let columnCount: Int

        switch layout.kind {
        case .list:
            columnCount = 1
        case let .grid(columns):
            columnCount = KsLayoutMetrics.columnCount(
                for: columns,
                containerSize: environment.container.effectiveContentSize,
                horizontalPadding: horizontalPadding,
                columnSpacing: layout.columnSpacing
            )
        }
        resolvedColumnCount = columnCount

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1 / CGFloat(columnCount)),
            heightDimension: .estimated(estimatedHeight.value)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(estimatedHeight.value)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            repeatingSubitem: item,
            count: columnCount
        )
        group.interItemSpacing = .fixed(layout.columnSpacing)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = layout.rowSpacing
        // 行間は行と行の間にだけ入れ、見出しの前後には入れない (core/ADR-0015)。
        // - グループの先頭の塊の上端: 見出しがあれば見出しの下の間隔 (見出しはこの余白の外側に置かれる)
        // - グループの 2 つめ以降の塊の上端: 行間 (セクションの間には行間が入らないため、境界の間隔を他の行間と同じにする)
        // - グループの末尾の塊の下端: 次のグループがあればグループ間の間隔
        // 上下の内側余白はルートのヘッダー / フッターの位置に置くため、塊には付けない。
        // 間隔を行や見出しの側に置くのは、固定中の見出しと一緒に空白が上端へ貼り付かないため。
        let top: CGFloat
        if chunk.isFirstChunkInGroup {
            top = hasHeader ? layout.headerItemSpacing : 0
        } else {
            top = layout.rowSpacing
        }
        let bottom: CGFloat = chunk.isLastChunkInGroup && !chunk.isLastGroup
            ? layout.groupSpacing
            : 0
        section.contentInsets = NSDirectionalEdgeInsets(
            top: top,
            leading: padding.leading,
            bottom: bottom,
            trailing: padding.trailing
        )

        // 見出しはグループの先頭の塊に場所を取る形で付ける。塊に割れたグループを固定するときは、
        // 2 つめ以降の塊にも同じ見出しを場所を取らない形で付け、グループ全体で 1 つの見出しとして
        // 固定する (ios/ADR-0010)。固定しないときは先頭の塊にだけ付ける。
        if hasHeader {
            let pinsHeaders = configuration.grouping?.pinsHeaders ?? false
            if chunk.isFirstChunkInGroup {
                section.boundarySupplementaryItems = [
                    makeGroupHeaderItem(extendsBoundary: true, pinned: pinsHeaders),
                ]
            } else if pinsHeaders {
                section.boundarySupplementaryItems = [
                    makeGroupHeaderItem(extendsBoundary: false, pinned: true),
                ]
            }
        }
        return section
    }

    private func makeRootBoundaryItem(
        kind: String,
        alignment: NSRectAlignment,
        height: NSCollectionLayoutDimension
    ) -> NSCollectionLayoutBoundarySupplementaryItem {
        NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: height
            ),
            elementKind: kind,
            alignment: alignment
        )
    }

    private func makeGroupHeaderItem(
        extendsBoundary: Bool,
        pinned: Bool
    ) -> NSCollectionLayoutBoundarySupplementaryItem {
        let item = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(KsEstimatedHeight.defaultValue)
            ),
            elementKind: KsSupplementaryKind.groupHeader,
            alignment: .top
        )
        item.extendsBoundary = extendsBoundary
        item.pinToVisibleBounds = pinned
        // 固定中の見出しが行の上に重なって描かれるよう、行より手前に置く。
        item.zIndex = 2
        return item
    }

    // 表示範囲。内容の原点 (contentOffset) から見た bounds をバー等の余白で狭めた矩形。
    // 余白で潰れる構成では狭める前の bounds を使う。`configureCollectionView()` が
    // `contentInsetAdjustmentBehavior = .never` を立てているためバー由来の値は入らず、
    // ここで狭まるのは `contentInset` を自ら持つ構成だけである。一覧が上端の安全領域に重なって
    // 置かれたときも、行は安全領域に被ったまま流れるため、表示範囲は安全領域の分を狭めない。
    private var visibleRect: CGRect {
        let bounds = collectionView.bounds
        let insetBounds = bounds.inset(by: collectionView.adjustedContentInset)
        return insetBounds.isEmpty ? bounds : insetBounds
    }

    // 固定中のグループの見出しを置く位置の、表示範囲の上端からの距離。一覧が上端の安全領域に
    // 重なって置かれたときは、見出しを安全領域の境目 (バーのすぐ下) に固定するため、その重なりの分になる。
    // 安全領域に重ならない置き方では 0。
    // 取り直し中は、上端に足した余白 (安全領域の分) で表示範囲の上端が下がっているため、その分を差し引く。
    private var pinnedGroupHeaderTopInset: CGFloat {
        max(0, collectionView.safeAreaInsets.top - refreshExtraTopInset)
    }

    // 固定中のグループの見出しが表示範囲の上端から覆っている長さ。上端から、固定する位置にある
    // 見出しの下端までで、上端の安全領域に重なる分を含む。固定中の見出しが無ければ 0。
    // 透明にした塊の見出しは数えない。
    private func pinnedGroupHeaderCoverage(in visibleRect: CGRect) -> CGFloat {
        guard pinsGroupHeaders else { return 0 }
        let attributes = collectionView.collectionViewLayout.layoutAttributesForElements(in: visibleRect) ?? []
        let pinnedTop = visibleRect.minY + pinnedGroupHeaderTopInset
        var coverage: CGFloat = 0
        for header in attributes where header.representedElementKind == KsSupplementaryKind.groupHeader
            && header.alpha > 0.01 {
            let frame = header.frame
            guard frame.minY <= pinnedTop + 0.5, frame.maxY > pinnedTop else { continue }
            coverage = max(coverage, frame.maxY - visibleRect.minY)
        }
        return min(coverage, visibleRect.height)
    }

    // セクションの塊が属するグループの見出しを固定する場合の、その塊の項目の上に固定される見出しの高さ。
    // 固定しないとき、グループに見出しが無いときは 0。固定するときは全塊に見出しが付き、上端がその塊に
    // あるときはその塊の見出しを見せるため、その塊の見出しの書き換える前の属性から読む。見出しの高さは
    // 表示されたときに中身から決まり、それまでは推定の値である。
    private func pinnedGroupHeaderHeight(forSection section: Int) -> CGFloat {
        guard
            pinsGroupHeaders,
            let chunk = appliedChunkTable.chunk(at: section),
            groupHasHeader(groupIndex: chunk.groupIndex),
            let header = compositionalLayout?.unadjustedGroupHeaderAttributes(section: section)
        else {
            return 0
        }
        return header.frame.height
    }

    // 表示範囲と実際に重なっている項目のうち、全体の順番が最も先頭のものを返す。
    // 可視セルの一覧には、遠くへ送った直後に送る前のセルがまだ残っていることがあるため、
    // 一覧の先頭をそのまま採ると画面外の項目をアンカーにしてしまい、復元で先頭へ飛ぶ。
    // 固定中のグループの見出しが上端を覆っている範囲は表示範囲から除く。見出しの裏に隠れた項目を
    // 先頭として控えると、戻したときにも見出しの裏へ戻してしまう。
    private func leadingVisibleID() -> AnyHashable? {
        var visibleRect = visibleRect
        let coverage = pinnedGroupHeaderCoverage(in: visibleRect)
        if coverage > 0, coverage < visibleRect.height {
            visibleRect.origin.y += coverage
            visibleRect.size.height -= coverage
        }
        let indexPath = collectionView.indexPathsForVisibleItems.filter { indexPath in
            guard let attributes = collectionView.collectionViewLayout
                .layoutAttributesForItem(at: indexPath) else {
                return false
            }
            return attributes.frame.intersects(visibleRect)
        }.min()
        guard let indexPath else { return nil }
        return dataSource.itemIdentifier(for: indexPath)?.value
    }

    // 表示範囲の先頭にある要素と、その要素の表示範囲上端からのオフセットを控える。
    // 固定中のグループの見出しが上端を覆っているときは、オフセットを見出しの下端から測る。
    // 復元は新しい items の適用とレイアウトの確定が済んでから行う。
    // 旧順序は、アンカー自身が同時に削除されたときの近傍解決に使う。
    private func captureAnchor() {
        guard
            let identifier = leadingVisibleID(),
            let indexPath = dataSource.indexPath(for: KsItemIdentifier(identifier)),
            let attributes = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)
        else {
            return
        }
        let coverage = pinnedGroupHeaderCoverage(in: visibleRect)
        pendingAnchor = (
            identifier,
            attributes.frame.minY - collectionView.bounds.minY - coverage,
            coverage > 0,
            appliedIdentifiers.map(\.value)
        )
        anchorGeneration &+= 1
    }

    // 控えた位置を捨てる。世代を進めることで、遅らせてある復元もこの控えを戻さなくなる。
    private func discardPendingAnchor() {
        guard pendingAnchor != nil else { return }
        pendingAnchor = nil
        anchorGeneration &+= 1
    }

    // 表示領域の変化の直前に控えた位置を、新しい列数が解けた後に戻す。
    // 列数が変わらなかった変化では行の並びも変わらないため、控えた位置は使わずに捨てる。
    private func restoreAnchorAfterColumnCountChangeIfNeeded() {
        guard
            let transition = containerTransitionAnchor,
            let currentColumnCount = resolvedColumnCount
        else {
            return
        }
        containerTransitionAnchor = nil
        guard transition.columnCount != currentColumnCount else {
            // 控えた位置がここで控えたものである (世代が一致する) ときだけ捨てる。別の経路が
            // 後から控え直していれば、その経路が待っている復元まで落としてしまう。
            if anchorGeneration == transition.generation {
                discardPendingAnchor()
            }
            return
        }
        // 塊の件数まで変わる変化では、組み直しの経路が同じ控えた位置を適用の後に戻す。
        guard !isChunkRebuildScheduled, currentChunkSize() == appliedChunkSize else { return }
        // 復元は塊の組み直しと同じく、レイアウトが確定した後の実行機会まで遅らせる。
        // 同じ実行の中で戻すと、この後に UIKit 自身が行う表示位置の調整に上書きされる。
        let requestedGeneration = anchorGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard anchorGeneration == requestedGeneration else { return }
            collectionView.layoutIfNeeded()
            restorePendingAnchor()
        }
    }

    // 差分適用を伴わない更新でも位置を保つため、レイアウトを確定させてから復元する。
    private func settleAnchorIfNeeded() {
        guard pendingAnchor != nil else { return }
        collectionView.layoutIfNeeded()
        restorePendingAnchor()
    }

    private func restorePendingAnchor() {
        guard let anchor = pendingAnchor else { return }
        // 控えは 1 度だけ使う。使った時点で世代を進め、遅らせてある別の復元が同じ控えを
        // もう一度戻そうとしないようにする。
        discardPendingAnchor()
        guard
            let target = survivingAnchor(
                for: anchor.identifier,
                previousOrder: anchor.previousOrder
            ),
            let indexPath = dataSource.indexPath(for: KsItemIdentifier(target)),
            let attributes = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)
        else {
            return
        }
        // 表示範囲の上端へ吸着させず、変更前と同じオフセットへ戻す。
        // 値を連続して変えても表示が跳ねないようにするため。
        var offsetFromTop = clampedAnchorOffsetFromTop(
            anchor.offsetFromTop,
            anchorHeight: attributes.frame.height
        )
        // 控えたときに固定中の見出しが上端を覆っていたなら、戻した位置でもそのグループの見出しが
        // 上端に固定される。項目をその見出しのすぐ下へ置き、見出しの裏に隠さない。
        if anchor.belowPinnedHeader {
            let headerHeight = pinnedGroupHeaderHeight(forSection: indexPath.section)
            if headerHeight > 0 {
                offsetFromTop = max(0, offsetFromTop) + pinnedGroupHeaderTopInset + headerHeight
            }
        }
        collectionView.setContentOffset(
            CGPoint(
                x: collectionView.contentOffset.x,
                y: clampedVerticalOffset(attributes.frame.minY - offsetFromTop)
            ),
            animated: false
        )
    }

    // 控えた「表示範囲上端からのオフセット」を、新しいレイアウトでのアンカーの高さと表示範囲の高さで挟み込む。
    private func clampedAnchorOffsetFromTop(
        _ value: CGFloat,
        anchorHeight: CGFloat
    ) -> CGFloat {
        let visibleHeight = collectionView.bounds.height
        guard visibleHeight > 0 else { return value }
        let margin = min(ksMinimumVisibleAnchorLength, anchorHeight)
        let minimum = -max(anchorHeight - margin, 0)
        let maximum = max(minimum, visibleHeight - margin)
        return min(max(value, minimum), maximum)
    }

    private func clampedVerticalOffset(_ value: CGFloat) -> CGFloat {
        let minimum = -collectionView.adjustedContentInset.top
        let maximum = max(
            minimum,
            collectionView.contentSize.height
                + collectionView.adjustedContentInset.bottom
                - collectionView.bounds.height
        )
        return min(max(value, minimum), maximum)
    }

    // アンカー自身が残っていればそれを、消えていれば旧順序で最も近い生存要素 (直後、無ければ直前) を返す。
    private func survivingAnchor(
        for identifier: AnyHashable,
        previousOrder: [AnyHashable]
    ) -> AnyHashable? {
        let surviving = Set(appliedIdentifiers.map(\.value))
        if surviving.contains(identifier) {
            return identifier
        }
        guard let index = previousOrder.firstIndex(of: identifier) else { return nil }
        if let following = previousOrder[previousOrder.index(after: index)...].first(where: surviving.contains) {
            return following
        }
        return previousOrder[..<index].last(where: surviving.contains)
    }

    // MARK: - 並べ替え

    // スイッチに合わせて、ドラッグと長押しの認識器を切り替える (core/ADR-0031)。有効の間は長押しを並べ替えの
    // 操作にして長押しの認識器を止める。無効の間はドラッグを受け付けず、長押しの認識器は長押しの知らせの
    // 有無で決める (有効なままだと、長押し相当の保持でタッチがキャンセルされ、通常タップのコールバックが失われる)。
    func syncReorderInteraction() {
        let isEnabled = configuration.isReorderEnabled
        if collectionView.dragInteractionEnabled != isEnabled {
            collectionView.dragInteractionEnabled = isEnabled
        }
        longPressRecognizer?.isEnabled = configuration.onItemLongTap != nil && !isEnabled
    }

    // タップのフィードバックを出す構成か。並べ替えのスイッチが有効の間は、長押しの知らせをハンドラに数えない。
    var handlesItemTouch: Bool {
        configuration.onItemTap != nil
            || (configuration.onItemLongTap != nil && !configuration.isReorderEnabled)
    }

    // 並べ替えのドラッグを始める。以後、ドラッグが終わるまで届いた構成は控えに回す。
    // 持ち上げた後、指を動かし始めるまでに配置を組み直す変化やスイッチの無効化があれば、ここで取りやめる
    // (その間の変化は控えに回さずに当たっているため、持ち上げた時点の構成と比べる)。
    func beginReorderDrag(identifier: AnyHashable) {
        guard let indexPath = dataSource.indexPath(for: KsItemIdentifier(identifier)) else { return }
        let center = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.center
        reorderDrag = KsReorderDrag(identifier: identifier, sourceIndexPath: indexPath, sourceCenter: center)
        if let lifted = reorderLiftConfiguration, Self.cancelsReorderDrag(from: lifted, to: configuration) {
            reorderDrag?.isCancelled = true
        }
        reorderLiftConfiguration = nil
        startReorderAutoScroll()
    }

    // UIKit が置く先の隙間を動かした。見えている隙間の位置を控え、置けるかの判定をこの位置に合わせる。
    func reorderGapDidMove(to targetIndexPaths: [IndexPath]) {
        guard isReorderDragging, let target = targetIndexPaths.first else { return }
        reorderDrag?.gapTracker.gapDidMove(to: target)
        reorderDrag?.shownGap = target
    }

    // 並べ替えのドラッグを終える。控えた構成があれば当て、溜めたスクロール命令を実行し、次ページ要求を
    // 判定し直す (core/ADR-0033、core/ADR-0034)。受け入れた並べ替えは、控えた構成の配列が受け入れた時点と
    // 同じなら置いた並びのまま待つ。
    // 置いた結果 (受け入れた並び・元の並びへの戻し) を表示に当てるのを次の周回へ回している間にドラッグの
    // セッションが終わったら、当て終わるまでドラッグ中の扱いを続け、当て終わった時点で終える。
    func endReorderDrag() {
        stopReorderAutoScroll()
        guard isReorderDragging else { return }
        if reorderDrag?.isResolving == true {
            reorderDrag?.isSessionEnded = true
            return
        }
        reorderDrag = nil
        if let deferred = deferredConfiguration {
            deferredConfiguration = nil
            update(configuration: deferred)
        }
        // 差分の適用中なら、適用の完了時に実行と判定が行われる。
        if !isApplyingSnapshot {
            flushPendingCommands()
        }
        evaluatePaging()
    }

    // ドラッグ中に届いた構成を控える。並べ替えの設定だけはすぐ入れ替え、ドラッグを取りやめる変化なら取りやめる。
    private func deferDuringReorderDrag(_ configuration: KsCollectionConfiguration<Item>) {
        if Self.cancelsReorderDrag(from: self.configuration, to: configuration) {
            reorderDrag?.isCancelled = true
        }
        self.configuration.reorder = configuration.reorder
        deferredConfiguration = configuration
        syncReorderInteraction()
    }

    // セルの中身に読み上げの移動操作の部品を付ける構成か。並べ替えを付けて文言を渡した構成でだけ付ける。
    static func attachesReorderAccessibility(_ configuration: KsCollectionConfiguration<Item>) -> Bool {
        configuration.reorder?.accessibilityActions != nil
    }

    // ドラッグを取りやめる変化か。スイッチの無効化と、配置を組み直す設定 (layout 値・グループの宣言) の変化。
    // 配置が組み直されると、ドラッグ中の仮の並びと行き先の対応が崩れる。
    static func cancelsReorderDrag(
        from current: KsCollectionConfiguration<Item>,
        to next: KsCollectionConfiguration<Item>
    ) -> Bool {
        guard next.isReorderEnabled else { return true }
        if current.layout != next.layout {
            return true
        }
        switch (current.grouping, next.grouping) {
        case (nil, nil):
            return false
        case let (current?, next?):
            return current.valueSource != next.valueSource
                || (current.header == nil) != (next.header == nil)
                || current.pinsHeaders != next.pinsHeaders
        default:
            return true
        }
    }

    // 上端の自動スクロールを回し始める。一覧をバーの裏まで広げた置き方で、UIKit の上端の反応の帯がバーの裏に
    // 入る分を補う (KsReorderTopAutoScroll)。安全領域の上が 0 の間は、フレームごとの判定で何もしない。
    private func startReorderAutoScroll() {
        stopReorderAutoScroll()
        let target = KsDisplayLinkTarget { [weak self] link in
            self?.reorderAutoScrollFrame(link)
        }
        let link = CADisplayLink(target: target, selector: #selector(KsDisplayLinkTarget.frame(_:)))
        link.add(to: .main, forMode: .common)
        reorderAutoScrollLink = link
        reorderTopAutoScroll = KsReorderTopAutoScroll(
            profile: KsReorderTopAutoScroll.profile(
                osMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion
            )
        )
    }

    private func stopReorderAutoScroll() {
        reorderAutoScrollLink?.invalidate()
        reorderAutoScrollLink = nil
        reorderAutoScrollTimestamp = nil
        reorderTopAutoScroll = nil
        reorderFingerY = nil
    }

    private func reorderAutoScrollFrame(_ link: CADisplayLink) {
        defer { reorderAutoScrollTimestamp = link.timestamp }
        guard let previous = reorderAutoScrollTimestamp else { return }
        advanceReorderAutoScroll(elapsed: link.timestamp - previous)
    }

    // 上端の自動スクロールを 1 フレーム分進める。指が一覧の中の帯にある間だけ上へ送り、先頭で止める。
    // UIKit の帯と重なる所・iOS 26 より前で帯に入ってからの待ちの間・指が一覧の外へ出た後・置いた後
    // (指の位置を捨てた後)・取りやめたドラッグでは送らない (KsReorderTopAutoScroll)。
    func advanceReorderAutoScroll(elapsed: TimeInterval) {
        guard let drag = reorderDrag, !drag.isCancelled, var autoScroll = reorderTopAutoScroll else { return }
        let next = autoScroll.nextOffset(
            fingerY: reorderFingerY,
            safeAreaTop: collectionView.safeAreaInsets.top,
            systemBandTop: collectionView.adjustedContentInset.top,
            currentOffset: collectionView.contentOffset.y,
            minimumOffset: -collectionView.adjustedContentInset.top,
            elapsed: elapsed
        )
        reorderTopAutoScroll = autoScroll
        guard let next else { return }
        collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x, y: next), animated: false)
    }

    // 受け入れた並べ替えを表示に当てる (core/ADR-0027)。
    //
    // 項目のグループの値はまだ変わっていないため、グループの値から組み直さず、今の snapshot の中で項目だけを
    // 動かす。配列の並びと塊の表も、動かした項目を行き先のグループに属させた仮の所属で組み直す。塊の区切り
    // 直しはせず、動かした項目を抜いた塊と入れた塊の件数だけを変える。項目が無くなったグループは、固定の
    // 見出しの位置の計算がグループに項目があることを前提にしているため、この時点でセクションと見出しを
    // 取り除く。受け入れた時点に届いていた配列を控え、それと同じ配列の更新では置いた並びのまま待つ。
    //
    // `destinationSection` は項目を入れる塊のセクション。UIKit が並びを動かした後は、UIKit が入れたセクションを
    // 渡して塊の割り当てを揃える (渡さなければ行き先から求める)。`snapshotTiming` で snapshot を当てる時点を
    // 選ぶ (差分データソースの並べ替えの確定の中では snapshot を当てられないため、その後は次の周回以降)。
    // `aligning` を渡すと、先に差分データソースの並びを UIKit が見せている並びへ揃える (alignedReorderSnapshot)。
    // 表の組み直しはその場で行う。
    func applyAcceptedReorder(
        moving source: Int,
        to placement: KsReorderPlacement,
        planner: KsReorderPlanner,
        latestItems: [Item],
        destinationSection proposedSection: Int? = nil,
        snapshotTiming: KsReorderSnapshotTiming = .immediate,
        aligning alignment: (identifier: KsItemIdentifier, indexPath: IndexPath)? = nil,
        completion: (() -> Void)? = nil
    ) {
        let table = appliedChunkTable
        guard
            let sourceSection = table.section(containingItemAt: source),
            let destinationSection = proposedSection ?? destinationSection(of: placement, in: table)
        else {
            completion?()
            return
        }
        let reorderedIDs = planner.reorderedIdentifiers(moving: source, to: placement)
        let movedTable = table.movingItem(fromSection: sourceSection, toSection: destinationSection)
        let identifiers = reorderedIDs.map(KsItemIdentifier.init)
        var snapshot = NSDiffableDataSourceSnapshot<KsSectionID, KsItemIdentifier>()
        snapshot.appendSections(movedTable.sectionIDs)
        for (sectionID, range) in zip(movedTable.sectionIDs, movedTable.sectionItemRanges) where !range.isEmpty {
            snapshot.appendItems(Array(identifiers[range]), toSection: sectionID)
        }
        let reorderedItems = reorderedIDs.compactMap { itemsByID[$0] }
        appliedIdentifiers = identifiers
        appliedItems = reorderedItems
        appliedChunkTable = movedTable
        configuration.items = reorderedItems
        reorderAwaitedItems = latestItems
        reorderAccessibilityGeneration &+= 1
        applyReorderSnapshot(snapshot, timing: snapshotTiming, aligning: alignment) { [weak self] in
            self?.updateVisibleGroupHeaders()
            completion?()
        }
    }

    // 並べ替えを受け入れなかったとき、UIKit が動かした並びを、適用済みの並び (動かす前の並び) へ動かして戻す。
    // ドロップのセッションが終わってから当てる (reorderDidReorder)。
    func revertReorderedSnapshot(
        aligning alignment: (identifier: KsItemIdentifier, indexPath: IndexPath)?,
        completion: @escaping () -> Void
    ) {
        let table = appliedChunkTable
        var snapshot = NSDiffableDataSourceSnapshot<KsSectionID, KsItemIdentifier>()
        snapshot.appendSections(table.sectionIDs)
        for (sectionID, range) in zip(table.sectionIDs, table.sectionItemRanges) where !range.isEmpty {
            snapshot.appendItems(Array(appliedIdentifiers[range]), toSection: sectionID)
        }
        applyReorderSnapshot(snapshot, timing: .afterDropSession, aligning: alignment, completion: completion)
    }

    // 並べ替えの snapshot を `timing` の時点で当てる。待つ間も差分の適用中として数え、スクロール命令と次ページ
    // 要求の判定を当て終わるまで待たせる。`aligning` を渡すと、当てる直前に差分データソースの並びを UIKit が
    // 見せている並びへ動きなしに揃える。
    func applyReorderSnapshot(
        _ snapshot: NSDiffableDataSourceSnapshot<KsSectionID, KsItemIdentifier>,
        timing: KsReorderSnapshotTiming,
        aligning alignment: (identifier: KsItemIdentifier, indexPath: IndexPath)? = nil,
        completion: @escaping () -> Void
    ) {
        applyingSnapshotCount += 1
        let apply = { [weak self] in
            guard let self else { return }
            if let alignment, let aligned = alignedReorderSnapshot(moving: alignment.identifier, to: alignment.indexPath) {
                dataSource.apply(aligned, animatingDifferences: false)
                reorderDrag?.shownSnapshot = nil
            }
            snapshotApplyCount += 1
            dataSource.apply(snapshot, animatingDifferences: true) { [weak self] in
                guard let self else { return }
                applyingSnapshotCount = max(0, applyingSnapshotCount - 1)
                updateVisibleCellSeparators()
                updateVisibleRootSupplementaryViews()
                completion()
                guard applyingSnapshotCount == 0 else { return }
                flushPendingCommands()
                evaluatePaging()
            }
        }
        switch timing {
        case .immediate:
            apply()
        case .nextRunLoop:
            DispatchQueue.main.async(execute: apply)
        case .afterDropSession:
            runAfterReorderDropSession(apply)
        }
    }

    // 見えているセルの位置にある項目。並べ替えの後、差分データソースの並びを UIKit が見せている並びへ揃えるまでは、
    // 見せている並びで引く (差分データソースの並びと見えているセルが食い違うため)。
    func shownItemIdentifier(at indexPath: IndexPath) -> KsItemIdentifier? {
        guard let shown = reorderDrag?.shownSnapshot else {
            return dataSource.itemIdentifier(for: indexPath)
        }
        guard shown.sectionIdentifiers.indices.contains(indexPath.section) else { return nil }
        let items = shown.itemIdentifiers(inSection: shown.sectionIdentifiers[indexPath.section])
        return items.indices.contains(indexPath.item) ? items[indexPath.item] : nil
    }

    // 差分データソースの今の並びの中で、動かした項目を `destination` (UIKit が見せている位置) に置いた snapshot。
    // 確定した位置と見せている位置の間の項目は、セルの中身を作り直す (セルは UIKit が見せている位置のまま、
    // データソースの項目だけが食い違っているため)。
    func alignedReorderSnapshot(
        moving identifier: KsItemIdentifier,
        to destination: IndexPath
    ) -> NSDiffableDataSourceSnapshot<KsSectionID, KsItemIdentifier>? {
        var snapshot = dataSource.snapshot()
        let before = snapshot.itemIdentifiers
        guard snapshot.sectionIdentifiers.indices.contains(destination.section), before.contains(identifier) else {
            return nil
        }
        snapshot.deleteItems([identifier])
        let sectionID = snapshot.sectionIdentifiers[destination.section]
        let items = snapshot.itemIdentifiers(inSection: sectionID)
        if destination.item < items.count {
            snapshot.insertItems([identifier], beforeItem: items[destination.item])
        } else {
            snapshot.appendItems([identifier], toSection: sectionID)
        }
        let changed = zip(before, snapshot.itemIdentifiers).filter { $0 != $1 }.flatMap { [$0, $1] }
        snapshot.reconfigureItems(Array(Set(changed)))
        return snapshot
    }

    // 行き先の項目が入る塊のセクションの番号。項目の前なら、その項目の塊。末尾なら、行き先のグループの最後の塊。
    private func destinationSection(of placement: KsReorderPlacement, in table: KsGroupChunkTable) -> Int? {
        switch placement.target {
        case let .before(identifier):
            guard let index = appliedIdentifiers.firstIndex(of: KsItemIdentifier(identifier)) else { return nil }
            return table.section(containingItemAt: index)
        case .end:
            guard table.groups.indices.contains(placement.groupIndex) else { return nil }
            let sections = table.groups[placement.groupIndex].sectionRange
            return sections.isEmpty ? nil : sections.upperBound - 1
        }
    }

    // MARK: - ページング

    // 最後の項目の後ろに出すページングの表示。項目が 0 件のときと、出す表示が無い状態では nil。
    private var currentPagingFooterDisplay: KsPagingDisplay? {
        guard let paging = configuration.paging else { return nil }
        let display = KsPagingDisplay.resolve(state: paging.state, isEmpty: configuration.items.isEmpty)
        guard let display, display.placement == .footer else { return nil }
        return display
    }

    // ページングを付けた一覧のフッターの枠。ページングの表示を上、利用者のフッターを下に縦に並べ、
    // 下の内側余白をその下に入れる。ページングの表示も利用者のフッターと同じく左右の内側余白の内側に
    // 置き、その幅の中で横方向の中央に揃える (core/ADR-0024)。表示もフッターも無いときは余白の分の
    // 高さだけになる。
    private func configurePagingFooter(_ view: KsHostingSupplementaryView) {
        let display = currentPagingFooterDisplay
        let pagingContent = display.flatMap {
            configuration.pagingDisplays.content(for: $0, retry: pagingRetryAction)
        }
        let footer = configuration.footer?()
        let padding = configuration.contentPadding
        view.configure(
            using: UIHostingConfiguration {
                KsPagingFooterStack(paging: pagingContent, footer: footer, padding: padding)
            }
            .margins(.all, 0)
        )
    }

    // 最後の項目の後ろに出す表示が変わったら (状態だけが変わった更新を含む)、見えているフッターの
    // 中身をかけ直し、フッターの枠の高さをレイアウトに測り直させる。
    private func invalidatePagingFooterIfNeeded() {
        guard currentPagingFooterDisplay != displayedPagingFooter else { return }
        displayedPagingFooter = currentPagingFooterDisplay
        rebuildVisibleRootSupplementaryViews(ofKinds: [KsSupplementaryKind.rootFooter])
    }

    // ルートのヘッダー / フッターの中身を作り直し、その枠を名指しで測り直させる。補助ビューは中身が変わっても
    // 自分では測り直されず、ホスティングの中身の差し替えも次の描画まで大きさに反映されないため、見えている
    // 枠の中身を一度外してから作り直す。見えていない枠も、次に見えたときに測り直されるよう名指しする。
    // レイアウト全体の補助ビューは 1 要素の位置で指す。
    private func rebuildVisibleRootSupplementaryViews(ofKinds kinds: [String]) {
        rootSupplementaryRebuildCount += 1
        let context = UICollectionViewLayoutInvalidationContext()
        for kind in kinds {
            for view in collectionView.visibleSupplementaryViews(ofKind: kind) {
                guard let view = view as? KsHostingSupplementaryView else { continue }
                view.clear()
                if kind == KsSupplementaryKind.rootHeader {
                    configureHeader(view)
                } else {
                    configureFooter(view)
                }
            }
            context.invalidateSupplementaryElements(ofKind: kind, at: [IndexPath(index: 0)])
        }
        collectionView.collectionViewLayout.invalidateLayout(with: context)
    }

    // 項目が 0 件のときのページングの表示を、状態に合わせて出す / 消す。
    private func updatePagingPlaceholder() {
        let display: KsPagingDisplay? = {
            guard let paging = configuration.paging, configuration.items.isEmpty else { return nil }
            guard
                let display = KsPagingDisplay.resolve(state: paging.state, isEmpty: true),
                display.placement == .center
            else {
                return nil
            }
            return display
        }()
        guard
            let display,
            let content = configuration.pagingDisplays.content(for: display, retry: pagingRetryAction)
        else {
            displayedPagingPlaceholder = nil
            pagingPlaceholderView?.clear()
            pagingPlaceholderView?.isHidden = true
            return
        }
        let placeholder = pagingPlaceholderView ?? makePagingPlaceholderView()
        placeholder.isHidden = false
        // ホスティングの中身の差し替えは次の描画まで大きさに反映されず、前の中身の大きさのまま描かれて
        // 切れる。別の表示に切り替わったときは中身を作り直して、新しい中身の大きさで置く。
        if displayedPagingPlaceholder != display {
            placeholder.clear()
            displayedPagingPlaceholder = display
        }
        placeholder.configure(using: UIHostingConfiguration { content }.margins(.all, 0))
        updatePagingPlaceholderArea()
    }

    // 入れ物は一覧の表示範囲 (frameLayoutGuide) に固定し、スクロールしても動かさない。
    private func makePagingPlaceholderView() -> KsPagingPlaceholderView {
        let placeholder = KsPagingPlaceholderView()
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        collectionView.addSubview(placeholder)
        let frame = collectionView.frameLayoutGuide
        NSLayoutConstraint.activate([
            placeholder.topAnchor.constraint(equalTo: frame.topAnchor),
            placeholder.bottomAnchor.constraint(equalTo: frame.bottomAnchor),
            placeholder.leadingAnchor.constraint(equalTo: frame.leadingAnchor),
            placeholder.trailingAnchor.constraint(equalTo: frame.trailingAnchor),
        ])
        pagingPlaceholderView = placeholder
        return placeholder
    }

    private func updatePagingPlaceholderArea() {
        guard let placeholder = pagingPlaceholderView, !placeholder.isHidden else { return }
        let safeArea = collectionView.safeAreaInsets
        placeholder.setExcludedVerticalInsets(top: safeArea.top, bottom: safeArea.bottom)
    }

    // 次のページの読み込み中の表示の下端と、一覧の見えている範囲の下端 (下端の安全領域の上) の間隔。
    static var pagingIndicatorBottomSpacing: CGFloat { 8 }

    // 次のページの読み込み中の表示を、状態に合わせて出す / 消す。項目があり、状態が追加読み込み中の間だけ、
    // 一覧の見えている範囲の下端に止めて重ねる。出る・消えるときは短くフェードする。
    private func updatePagingIndicator() {
        let content: AnyView? = {
            guard
                let paging = configuration.paging,
                let display = KsPagingDisplay.resolve(state: paging.state, isEmpty: configuration.items.isEmpty),
                display.placement == .bottomOverlay
            else {
                return nil
            }
            return configuration.pagingDisplays.content(for: display, retry: pagingRetryAction)
        }()
        guard let content else {
            hidePagingIndicator()
            return
        }
        let indicator = pagingIndicatorView ?? makePagingIndicatorView()
        indicator.configure(
            using: UIHostingConfiguration { content }.margins(.all, 0),
            receivesTouches: configuration.pagingDisplays.isReplaced(.appendingIndicator)
        )
        updatePagingIndicatorPosition()
        guard !isPagingIndicatorShown else { return }
        isPagingIndicatorShown = true
        indicator.layer.removeAllAnimations()
        indicator.isHidden = false
        indicator.alpha = 0
        UIView.animate(withDuration: KsPagingIndicatorView.fadeDuration) {
            indicator.alpha = 1
        }
    }

    private func hidePagingIndicator() {
        guard isPagingIndicatorShown, let indicator = pagingIndicatorView else { return }
        isPagingIndicatorShown = false
        UIView.animate(withDuration: KsPagingIndicatorView.fadeDuration) {
            indicator.alpha = 0
        } completion: { [weak self] _ in
            // フェードの間にまた出すことになっていれば、消さない。
            guard let self, !isPagingIndicatorShown else { return }
            indicator.isHidden = true
            indicator.clear()
        }
    }

    // 入れ物は一覧の表示範囲 (frameLayoutGuide) に固定し、スクロールしても動かさない。
    private func makePagingIndicatorView() -> KsPagingIndicatorView {
        let indicator = KsPagingIndicatorView()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.isHidden = true
        collectionView.addSubview(indicator)
        let frame = collectionView.frameLayoutGuide
        NSLayoutConstraint.activate([
            indicator.topAnchor.constraint(equalTo: frame.topAnchor),
            indicator.bottomAnchor.constraint(equalTo: frame.bottomAnchor),
            indicator.leadingAnchor.constraint(equalTo: frame.leadingAnchor),
            indicator.trailingAnchor.constraint(equalTo: frame.trailingAnchor),
        ])
        pagingIndicatorView = indicator
        return indicator
    }

    // 表示の下端を、一覧の見えている範囲の下端から「下端の安全領域 + 間隔」だけ上に合わせる。
    // 下の内側余白 (contentPadding) は中身の周りの余白で、中身の外に重ねるこの表示の置き場には使わない。
    private func updatePagingIndicatorPosition() {
        guard let indicator = pagingIndicatorView else { return }
        indicator.setBottomDistance(collectionView.safeAreaInsets.bottom + Self.pagingIndicatorBottomSpacing)
    }

    // 失敗の表示に渡す再試行の操作。
    private var pagingRetryAction: KsPagingDisplays.Retry {
        { [weak self] in
            self?.retryPaging()
        }
    }

    // 再試行: 状態が失敗なら、項目が 0 件かどうかと Pull to Refresh の有無によらず次ページ要求を呼ぶ
    // (core/ADR-0019)。
    func retryPaging() {
        guard let paging = configuration.paging else { return }
        if pagingRequester.retry(state: paging.state, itemsVersion: itemsVersion, action: paging.onLoadMore) {
            syncPullRefreshControl()
        }
    }

    private func pagingRequestDidFinish() {
        syncPullRefreshControl()
        evaluatePaging()
    }

    // 次ページ要求を判定し、条件を満たせば頼む (core/ADR-0020)。ページングを付けていない一覧、画面に
    // 載る前、差分の適用中は判定しない (適用の完了時に判定し直す)。並べ替えのドラッグ中も判定せず、
    // ドラッグが終わってから判定し直す (core/ADR-0034)。
    func evaluatePaging() {
        guard
            let paging = configuration.paging,
            hasAppliedSnapshot,
            !isApplyingSnapshot,
            !isReorderDragging,
            collectionView.window != nil
        else {
            return
        }
        let visible = visiblePagingItems()
        let requested = pagingRequester.requestIfNeeded(
            state: paging.state,
            itemsVersion: itemsVersion,
            itemCount: appliedIdentifiers.count,
            visibleItemCount: visible.count,
            lastVisibleIndex: visible.lastIndex,
            threshold: paging.threshold,
            action: paging.onLoadMore
        )
        if requested {
            syncPullRefreshControl()
        }
    }

    // 画面に出ている項目の数と、その中でいちばん後ろの項目の配列上の位置。画面に出ているのは一覧の
    // 表示範囲 (バーの裏を含む bounds 全体) と少しでも重なる項目で、見出し・ヘッダー / フッターは数えない。
    // 可視セルの一覧には表示範囲の外のセルが残りうるため、レイアウトの位置で絞る。
    func visiblePagingItems() -> (count: Int, lastIndex: Int?) {
        let bounds = collectionView.bounds
        let layout = collectionView.collectionViewLayout
        let ranges = appliedChunkTable.sectionItemRanges
        var count = 0
        var lastIndex: Int?
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard
                ranges.indices.contains(indexPath.section),
                let attributes = layout.layoutAttributesForItem(at: indexPath),
                attributes.frame.intersects(bounds)
            else {
                continue
            }
            let index = ranges[indexPath.section].lowerBound + indexPath.item
            guard index < appliedIdentifiers.count else { continue }
            count += 1
            lastIndex = max(lastIndex ?? index, index)
        }
        return (count, lastIndex)
    }

    // しきい値の負の数・有限でない数は不正入力 (core/ADR-0011)。値が変わった回に知らせ、0 として扱う。
    private func reportInvalidPagingThresholdIfNeeded(previous: Double?) {
        guard let threshold = configuration.paging?.threshold else { return }
        if let previous, previous.bitPattern == threshold.bitPattern {
            return
        }
        guard !KsPagingRequester.isValidThreshold(threshold) else { return }
        KsInvalidInput.report(
            "ページングのしきい値に \(threshold) が指定されました。しきい値は 0 以上の有限の数で指定してください。0 として扱います"
        )
    }

    // MARK: - Pull to Refresh

    // 引っ張りの部品を付け外しする (core/ADR-0023)。取り直しの処理が無ければ外す。ページングの状態が
    // 追加読み込み中の間と、次ページ要求の処理の実行中は、引っ張って始めた取り直しのインジケータを
    // 出していなければ外して引っ張れなくする。
    private func syncPullRefreshControl() {
        pullRefreshControl.emptyTopSpace = configuration.contentPadding.top
        guard configuration.refresh != nil else {
            if collectionView.refreshControl != nil {
                finishPullRefresh()
                collectionView.refreshControl = nil
            }
            return
        }
        let blocksPull = configuration.paging?.state == .appending || pagingRequester.isRunning
        if blocksPull, !isPullRefreshing {
            if collectionView.refreshControl != nil {
                collectionView.refreshControl = nil
            }
        } else if collectionView.refreshControl !== pullRefreshControl {
            collectionView.refreshControl = pullRefreshControl
        }
    }

    // 引っ張って取り直しが始まった。取り直しの処理を一覧の表示の中で実行する。
    @objc
    private func handlePullRefresh() {
        guard let refresh = configuration.refresh, !isPullRefreshing else { return }
        isPullRefreshing = true
        pullRefreshShowedContentTop = false
        isRefreshActionRunning = true
        pullRefreshCount += 1
        addRefreshExtraTopInset()
        refreshTask = Task { @MainActor [weak self] in
            await refresh()
            guard let self, !Task.isCancelled else { return }
            refreshTask = nil
            isRefreshActionRunning = false
            endPullRefreshIfFinished()
            syncPullRefreshControl()
        }
    }

    // 引っ張って始めた取り直しのインジケータは、処理が終わるまで出し、終わった後は状態が取り直し中の
    // 間だけ出し続ける (core/ADR-0023)。
    private func endPullRefreshIfFinished() {
        guard isPullRefreshing, !isRefreshActionRunning, configuration.paging?.state != .refreshing else {
            return
        }
        finishPullRefresh()
    }

    private func finishPullRefresh() {
        guard isPullRefreshing else { return }
        isPullRefreshing = false
        pullRefreshControl.endRefreshing()
        // 取り直しの間に先頭を表示していなければ (取り直しの結果の配列が同値だった等)、ここで取り直しの結果として
        // 先頭を表示する (core/ADR-0021)。表示していれば、上端に空白を残さない戻しだけを行う。
        removeRefreshExtraTopInset(showsContentTop: !pullRefreshShowedContentTop)
        pullRefreshShowedContentTop = false
    }

    // 取り直しの間に足した上端の余白 (部品の高さと安全領域の分) を外しても、表示範囲は元の位置に残る。
    // 標準の部品は、取り直しの間に表示範囲が動かされていると (結果の差し替えで先頭を表示した等) 自分の
    // 余白の分を戻さず、止まっている間に取り直しが終わると上端に空白が残る。利用者が動かしていなければ、
    // 余白を外した先頭まで一緒に戻す。
    // showsContentTop が true なら、下へスクロールしていても先頭まで戻す。
    private func returnToContentTopAfterRefresh(showsContentTop: Bool) {
        let collectionView = collectionView!
        let top = -collectionView.adjustedContentInset.top
        guard !collectionView.isDragging else { return }
        let isAboveTop = collectionView.contentOffset.y < top - 0.5
        let isBelowTop = collectionView.contentOffset.y > top + 0.5
        guard isAboveTop || (showsContentTop && isBelowTop) else { return }
        if showsContentTop {
            discardPendingAnchor()
        }
        // 上端の空白を閉じる戻しは余白を外す動きと一緒に動かす。下から先頭へ送るときは、途中の行を
        // 組み立てながら流さないよう動かさずに置く (差し替えと同時に先頭を表示するのと同じ置き方)。
        guard isAboveTop else {
            collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x, y: top), animated: false)
            return
        }
        UIView.animate(withDuration: 0.3) {
            collectionView.contentOffset.y = top
        }
    }

    // 取り直し中は、標準の部品が自分の高さの分だけ上端に余白を足してコンテンツを部品の下で止める。
    // 一覧は安全領域の分を空けていないため、部品を安全領域の下に出すと、その余白だけではコンテンツが
    // 部品に被る。取り直しの間だけ、安全領域のうち上の内側余白で覆えない分の余白を足す (core/ADR-0025)。
    // 上の内側余白に安全領域の分を入れた一覧では、部品はその余白の中に描くため足さない (足すと部品の下に
    // 空白が二重にできる)。取り直しが終われば外し、行がバーの裏を流れる作り (core/ADR-0017) に戻す。
    private func addRefreshExtraTopInset() {
        let extra = max(0, collectionView.safeAreaInsets.top - configuration.contentPadding.top)
        guard extra > 0, refreshExtraTopInset == 0 else { return }
        refreshExtraTopInset = extra
        compositionalLayout?.refreshExtraTopInset = extra
        collectionView.contentInset.top += extra
    }

    private func removeRefreshExtraTopInset(showsContentTop: Bool) {
        let extra = refreshExtraTopInset
        defer { returnToContentTopAfterRefresh(showsContentTop: showsContentTop) }
        guard extra > 0 else { return }
        refreshExtraTopInset = 0
        compositionalLayout?.refreshExtraTopInset = 0
        let collectionView = collectionView!
        UIView.animate(withDuration: 0.3) {
            collectionView.contentInset.top -= extra
        }
    }

    @objc
    private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard
            recognizer.state == .began,
            configuration.onItemLongTap != nil,
            !configuration.isReorderEnabled
        else {
            return
        }
        let point = recognizer.location(in: collectionView)
        guard
            let indexPath = collectionView.indexPathForItem(at: point),
            dataSource.itemIdentifier(for: indexPath) != nil
        else {
            return
        }
        performLongPress(at: indexPath)
    }

    // 長押しの知らせを呼ぶ。並べ替えのスイッチが有効の間は、長押しは並べ替えの操作なので呼ばない
    // (core/ADR-0031)。
    func performLongPress(at indexPath: IndexPath) {
        guard
            !configuration.isReorderEnabled,
            let identifier = dataSource.itemIdentifier(for: indexPath)?.value,
            let item = itemsByID[identifier]
        else {
            return
        }
        configuration.onItemLongTap?(item)
    }

    private func execute(_ command: KsScrollCommand) {
        switch command {
        case let .item(identifier, position, animated):
            guard let indexPath = dataSource.indexPath(for: KsItemIdentifier(identifier)) else {
                #if DEBUG
                logger.warning("存在しない ID へのスクロール命令を無視しました: \(String(describing: identifier), privacy: .public)")
                #endif
                return
            }
            lastScrollTargetIdentifier = identifier
            // 項目のグループの見出しが上端に固定される場合、先頭へ送る命令は項目を見出しのすぐ下に置く。
            if position == .start, pinnedGroupHeaderHeight(forSection: indexPath.section) > 0 {
                scrollBelowPinnedGroupHeader(to: indexPath, animated: animated)
            } else {
                collectionView.scrollToItem(
                    at: indexPath,
                    at: position.collectionViewPosition,
                    animated: animated
                )
            }
        case let .start(animated):
            // 先頭へのスクロールは対象要素の解決を必要としないため、項目が空でも header の先頭へ戻す。
            lastScrollTargetIdentifier = nil
            collectionView.setContentOffset(
                CGPoint(x: collectionView.contentOffset.x, y: -collectionView.adjustedContentInset.top),
                animated: animated
            )
        case let .end(animated):
            guard let identifier = appliedIdentifiers.last,
                  let indexPath = dataSource.indexPath(for: identifier)
            else {
                return
            }
            lastScrollTargetIdentifier = identifier.value
            collectionView.scrollToItem(at: indexPath, at: .bottom, animated: animated)
        }
    }

    // 項目を、そのグループの固定中の見出しのすぐ下へ送る。行と見出しの高さは表示されたときに推定から
    // 実測へ変わるため、アニメーションしないときは送った先でレイアウトを確定させて数回送り直す。
    private func scrollBelowPinnedGroupHeader(to indexPath: IndexPath, animated: Bool) {
        func targetOffset() -> CGFloat? {
            guard let attributes = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath) else {
                return nil
            }
            let headerHeight = pinnedGroupHeaderHeight(forSection: indexPath.section)
            return clampedVerticalOffset(
                attributes.frame.minY - headerHeight - pinnedGroupHeaderTopInset
                    - collectionView.adjustedContentInset.top
            )
        }
        collectionView.layoutIfNeeded()
        guard let first = targetOffset() else { return }
        collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x, y: first), animated: animated)
        guard !animated else { return }
        for _ in 0..<3 {
            collectionView.layoutIfNeeded()
            guard let next = targetOffset() else { return }
            if abs(next - collectionView.contentOffset.y) >= 0.5 {
                collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x, y: next), animated: false)
            }
        }
    }

    // 保留中のスクロール命令を受けた順に実行する。並べ替えのドラッグ中は指の下の一覧を動かさないよう
    // 溜めたままにし、ドラッグが終わって配列を当てた後に実行する (core/ADR-0007)。
    func flushPendingCommands() {
        guard !isReorderDragging else { return }
        let commands = pendingCommands
        pendingCommands.removeAll()
        commands.forEach(execute)
        // 命令が処理し切られたこと自体を待てるようにするための計数。無効な命令のように
        // 表示へ何の変化も起こさない命令でも、処理が済んだ時点をこの値の変化で観測できる。
        processedCommandCount += commands.count
    }

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let items = indexPaths.compactMap { indexPath -> Item? in
            guard let identifier = dataSource.itemIdentifier(for: indexPath)?.value else { return nil }
            return itemsByID[identifier]
        }
        configuration.prefetcher?.prefetch(items: items)
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let items = indexPaths.compactMap { indexPath -> Item? in
            guard let identifier = dataSource.itemIdentifier(for: indexPath)?.value else { return nil }
            return itemsByID[identifier]
        }
        configuration.prefetcher?.cancel(items: items)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UIControl
                || current.accessibilityTraits.contains(.button)
                || current.accessibilityTraits.contains(.link)
                || current.accessibilityTraits.contains(.adjustable) {
                return false
            }
            view = current.superview
        }
        return true
    }

    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        guard let cell = collectionView.cellForItem(at: indexPath) as? KsHostingCell else {
            return false
        }
        return !cell.lastHitWasInteractive && handlesItemTouch
    }

    // セルが表示に入る時点で、位置依存の表示とタッチ時の背景色を現在の構成に揃える。
    // 先行して組み立てられたセルは、表示に入るときにセルの生成を通らず、画面外にある間の構成の差し替えは
    // 可視セルだけを対象にする揃え直しでは届かない。レイアウト確定の揃え直しは区切り線を出す構成に
    // 限っているため、構成を問わずここで揃える。色が変わっていなければセル側で書き込みを省く。
    override func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let cell = cell as? KsHostingCell else { return }
        configure(cell: cell, at: indexPath)
    }

    override func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? KsHostingCell else { return }
        cell.setTouchFeedbackVisible(true)
    }

    override func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        (collectionView.cellForItem(at: indexPath) as? KsHostingCell)?.setTouchFeedbackVisible(false)
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if let cell = collectionView.cellForItem(at: indexPath) as? KsHostingCell,
           cell.lastHitWasInteractive {
            return
        }
        guard
            let identifier = shownItemIdentifier(at: indexPath)?.value,
            let item = itemsByID[identifier]
        else {
            return
        }
        configuration.onItemTap?(item)
    }
}

extension KsCollectionViewController: KsScrollCommandReceiver {
    func receive(_ command: KsScrollCommand) {
        pendingCommands.append(command)
        guard !isApplyingSnapshot, !isReorderDragging, !isCommandFlushScheduled else { return }

        isCommandFlushScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isCommandFlushScheduled = false
            guard !isApplyingSnapshot else { return }
            flushPendingCommands()
        }
    }
}

private extension KsScrollPosition {
    var collectionViewPosition: UICollectionView.ScrollPosition {
        switch self {
        case .start: .top
        case .center: .centeredVertically
        case .end: .bottom
        }
    }
}
