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
    private var configuration: KsCollectionConfiguration<Item>
    private var dataSource: UICollectionViewDiffableDataSource<KsSectionID, KsItemIdentifier>!
    private var itemsByID: [AnyHashable: Item] = [:]
    private var keysByID: [AnyHashable: AnyHashable] = [:]
    private var registrations: [AnyHashable: UICollectionView.CellRegistration<KsHostingCell, KsItemIdentifier>] = [:]
    private var pendingCommands: [KsScrollCommand] = []
    private var appliedItems: [Item] = []
    private var appliedIdentifiers: [KsItemIdentifier] = []
    private var pendingAnchor: (
        identifier: AnyHashable,
        offsetFromTop: CGFloat,
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
    // 適用済みの snapshot に載っている塊の数。塊の位置 (先頭・末尾) でレイアウトを切り替えるために読む。
    private var appliedChunkCount = 0
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
    // 表示の変化に備えて控えた位置を持っているかどうか。控えが捨てられる契機を観測するために読む。
    var hasPendingAnchor: Bool { pendingAnchor != nil }
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

    private var isApplyingSnapshot: Bool {
        applyingSnapshotCount > 0
    }

    var appliedItemIdentifiers: [AnyHashable] {
        dataSource.snapshot().itemIdentifiers.map(\.value)
    }

    init(configuration: KsCollectionConfiguration<Item>) {
        self.configuration = configuration
        super.init(collectionViewLayout: UICollectionViewFlowLayout())
        collectionView.setCollectionViewLayout(makeLayout(), animated: false)
        configureCollectionView()
        configureDataSource()
        syncImagePrefetching()
        apply(items: configuration.items, animatingDifferences: false)
        configuration.scrollController?.attach(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) は使用しません")
    }

    func update(configuration: KsCollectionConfiguration<Item>) {
        let previousLayout = self.configuration.layout
        let previousPadding = self.configuration.contentPadding
        let previousShowsSeparators = self.configuration.showsSeparators
        let previousSeparatorColor = self.configuration.separatorColor
        let previousController = self.configuration.scrollController
        let previousObservedValue = self.configuration.observedValue
        // 観測する値が宣言されているときは、その値が変わった更新でだけテンプレートを呼び直す (ios/ADR-0008)。
        // 宣言が無いときは配列が同値の更新が届くたびに呼び直す (ios/ADR-0006)。
        let observedValueChanged = configuration.observedValue != nil
            && configuration.observedValue != previousObservedValue
        let rebuildsVisibleCellContent = configuration.observedValue == nil || observedValueChanged
        let supplementaryStructureChanged = (self.configuration.header == nil) != (configuration.header == nil)
            || (self.configuration.footer == nil) != (configuration.footer == nil)
        let layoutKindChanged = previousLayout.kind != configuration.layout.kind
        // 表示形態だけでなく行間・列間・内側余白の差し替えでも要素の位置が動くため、
        // layout 値と contentPadding のいずれかが変わったらアンカーを控える。
        let layoutChanged = previousLayout != configuration.layout || previousPadding != configuration.contentPadding
        if layoutChanged {
            captureAnchor()
        }

        self.configuration = configuration
        longPressRecognizer?.isEnabled = configuration.onItemLongTap != nil

        if previousController !== configuration.scrollController {
            previousController?.detach(self)
            configuration.scrollController?.attach(self)
        }

        if layoutChanged || supplementaryStructureChanged {
            collectionView.collectionViewLayout.invalidateLayout()
        }
        if previousShowsSeparators != configuration.showsSeparators
            || previousSeparatorColor != configuration.separatorColor
            || layoutKindChanged {
            updateVisibleCellSeparators()
        }
        updateVisibleSupplementaryViews()

        syncImagePrefetching()
        // 差し替え後の配列に無い項目は、システムから取り消し通知が来ないためここで取り消す。
        // ID が同じまま画像が差し替わった項目も、ここで新しい URL へ切り替える。
        imagePrefetcher?.retain(items: configuration.items)

        apply(
            items: configuration.items,
            animatingDifferences: true,
            reconfiguringAllItems: layoutKindChanged,
            rebuildingVisibleCellContentOnEqualItems: rebuildsVisibleCellContent,
            rebuildingSurvivingVisibleCellContent: observedValueChanged
        )
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 位置依存の表示 (先頭行の Top 区切り線) を、差分適用後のレイアウト確定に合わせて揃える。
        updateVisibleCellSeparators()
        // 列数はレイアウトを解いて初めて決まる。解けた列数で塊の件数が割り切れなくなっていたら
        // 組み直す。未解決から確定した最初のレイアウトもこの判定に入るため、表示領域の大きさが
        // 一度も変わらない画面でも不完全な行が残らない。
        scheduleChunkRebuildIfNeeded()
        restoreAnchorAfterColumnCountChangeIfNeeded()
        let containerSize = collectionView.bounds.size
        guard containerSize != lastContainerSize else { return }
        lastContainerSize = containerSize
        collectionView.collectionViewLayout.invalidateLayout()
    }

    func disconnect() {
        configuration.scrollController?.detach(self)
        // 画面から消えたときは未完了の取得をすべて取り消す。
        imagePrefetcher?.cancelAll()
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

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.cancelsTouchesInView = true
        longPress.delegate = self
        // 長押しハンドラが宣言されていないときは認識器を無効にする。有効なままだと、
        // 長押し相当の保持でタッチがキャンセルされ、通常タップのコールバックが失われる。
        longPress.isEnabled = configuration.onItemLongTap != nil
        collectionView.addGestureRecognizer(longPress)
        longPressRecognizer = longPress
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
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] view, _, _ in
            self?.configureHeader(view)
        }
        let footerRegistration = UICollectionView.SupplementaryRegistration<KsHostingSupplementaryView>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { [weak self] view, _, _ in
            self?.configureFooter(view)
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            if kind == UICollectionView.elementKindSectionHeader {
                collectionView.dequeueConfiguredReusableSupplementary(
                    using: headerRegistration,
                    for: indexPath
                )
            } else {
                collectionView.dequeueConfiguredReusableSupplementary(
                    using: footerRegistration,
                    for: indexPath
                )
            }
        }
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
            [weak self] cell, _, identifier in
            guard
                let self,
                let item = itemsByID[identifier.value]
            else {
                return
            }
            applyContent(to: cell, item: item)
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

    private func applyContent(to cell: KsHostingCell, item: Item) {
        let key = configuration.templateKey(item)
        let content = configuration.registry.content(for: key, item: item)
        // 内容を適用したセルの計測だけを推定高さに数えるため、content と対で設定する
        // (prepareForReuse で内容と一緒に解除される)。
        cell.onMeasuredSize = { [weak self] size, original in
            self?.recordMeasuredSize(size, original: original)
        }
        // 行の高さが content のサイズ変化に 1 パス遅れて追いつく間、ホスト View の既定の
        // 中央配置だと content が上方向にもはみ出す。KsRowContentPlacement で上端へ固定する。
        cell.contentConfiguration = UIHostingConfiguration {
            KsRowContentPlacement { content }
        }
        .margins(.all, 0)
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

    private func configure(cell: KsHostingCell, at indexPath: IndexPath) {
        let isList: Bool
        switch configuration.layout.kind {
        case .list:
            isList = true
        case .grid:
            isList = false
        }
        let showsSeparators = isList && configuration.showsSeparators
        cell.configureSeparators(
            // 上端の線は配列全体の先頭の項目にだけ出す。塊の境界では item が 0 に戻るため、
            // 塊の順番も合わせて見ないと境界ごとに線が増える。
            showsTop: showsSeparators && indexPath.item == 0 && indexPath.section == 0,
            showsBottom: showsSeparators,
            color: configuration.separatorColor ?? KsHostingCell.defaultSeparatorColor
        )
        // 既定はプラットフォーム標準のハイライト相当の半透明色。不透明色にするとセル内容を覆い隠す。
        cell.configureTouchFeedback(color: configuration.touchFeedbackColor ?? .systemFill)
    }

    private func configureHeader(_ view: KsHostingSupplementaryView) {
        guard let content = configuration.header?() else {
            view.clear()
            return
        }
        view.configure(using: UIHostingConfiguration { content }.margins(.all, 0))
    }

    private func configureFooter(_ view: KsHostingSupplementaryView) {
        guard let content = configuration.footer?() else {
            view.clear()
            return
        }
        view.configure(using: UIHostingConfiguration { content }.margins(.all, 0))
    }

    private func updateVisibleSupplementaryViews() {
        collectionView.visibleSupplementaryViews(
            ofKind: UICollectionView.elementKindSectionHeader
        ).compactMap { $0 as? KsHostingSupplementaryView }.forEach(configureHeader)
        collectionView.visibleSupplementaryViews(
            ofKind: UICollectionView.elementKindSectionFooter
        ).compactMap { $0 as? KsHostingSupplementaryView }.forEach(configureFooter)
    }

    private func updateVisibleCellSeparators() {
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
                applyContent(to: cell, item: item)
            }
            configure(cell: cell, at: indexPath)
        }
    }

    private func apply(
        items: [Item],
        animatingDifferences: Bool,
        reconfiguringAllItems: Bool = false,
        rebuildingVisibleCellContentOnEqualItems: Bool = true,
        rebuildingSurvivingVisibleCellContent: Bool = false
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
        // 差分計算も snapshot 適用も要らない更新はここで終わる。
        if itemsAreEqual, !chunkSizeChanged {
            settleAnchorIfNeeded()
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
            || positionsChanged
            || !plan.reconfigure.isEmpty
            || !plan.reload.isEmpty
            || reconfiguringAllItems
            || !survivingVisibleIdentifiers.isEmpty
        guard hasSnapshotChanges else {
            settleAnchorIfNeeded()
            if !isApplyingSnapshot {
                flushPendingCommands()
            }
            return
        }

        // 配列を先頭から塊の件数ずつ区切って、塊ごとのセクションへ載せる (ios/ADR-0009)。
        // 件数は列数の倍数なので、塊の境界は必ず行の切れ目に落ちる。項目が空でも塊を 1 つ
        // 載せて、ヘッダー / フッターを表示できるようにする。
        var snapshot = NSDiffableDataSourceSnapshot<KsSectionID, KsItemIdentifier>()
        let chunkCount = KsSectionChunking.chunkCount(
            itemCount: identifiers.count,
            chunkSize: chunkSize
        )
        snapshot.appendSections((0..<chunkCount).map(KsSectionID.init(chunkIndex:)))
        for chunkIndex in 0..<chunkCount {
            let start = chunkIndex * chunkSize
            let end = min(start + chunkSize, identifiers.count)
            guard start < end else { continue }
            snapshot.appendItems(
                Array(identifiers[start..<end]),
                toSection: KsSectionID(chunkIndex: chunkIndex)
            )
        }
        appliedChunkSize = chunkSize
        appliedChunkCount = chunkCount
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
        dataSource.apply(snapshot, animatingDifferences: animates) { [weak self] in
            guard let self else { return }
            applyingSnapshotCount = max(0, applyingSnapshotCount - 1)
            updateVisibleCellSeparators()
            updateVisibleSupplementaryViews()
            // 保留中の命令は、重ねて適用された snapshot がすべて反映されてから実行する。
            guard applyingSnapshotCount == 0 else { return }
            collectionView.layoutIfNeeded()
            if let requestedGeneration = anchorGenerationAwaitingApply {
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
        }
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

    // 現在の layout と解決済みの列数から決まる、1 つの塊に載せる件数。
    private func currentChunkSize() -> Int {
        KsSectionChunking.chunkSize(
            columnMultiple: KsSectionChunking.columnMultiple(
                layout: configuration.layout,
                resolvedColumnCount: resolvedColumnCount
            )
        )
    }

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self else { return nil }
            // 配列は内部の塊へ分かれて載る。塊の境界が見た目に出ないよう、内側余白・行間・
            // ヘッダー / フッターを塊の位置で切り替える (ios/ADR-0009)。
            // 塊の数は snapshot を組んだ時点で決まる。まだ組んでいない間や記録より後ろの塊を
            // 解いているときは、その塊を末尾として扱う。
            let isFirstChunk = sectionIndex == 0
            let isLastChunk = sectionIndex == max(appliedChunkCount, sectionIndex + 1) - 1
            let padding = configuration.contentPadding
            let horizontalPadding = padding.leading + padding.trailing
            let columnCount: Int

            switch configuration.layout.kind {
            case .list:
                columnCount = 1
            case let .grid(columns):
                columnCount = KsLayoutMetrics.columnCount(
                    for: columns,
                    containerSize: environment.container.effectiveContentSize,
                    horizontalPadding: horizontalPadding,
                    columnSpacing: configuration.layout.columnSpacing
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
            group.interItemSpacing = .fixed(configuration.layout.columnSpacing)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = configuration.layout.rowSpacing
            section.contentInsets = NSDirectionalEdgeInsets(
                // 内側余白は配列全体の上下にだけ付ける。塊と塊の間には行間を入れて、境界の
                // 間隔を他の行間と同じにする (セクションの間には行間が入らないため)。
                top: isFirstChunk ? padding.top : configuration.layout.rowSpacing,
                leading: padding.leading,
                bottom: isLastChunk ? padding.bottom : 0,
                trailing: padding.trailing
            )

            var supplementaryItems: [NSCollectionLayoutBoundarySupplementaryItem] = []
            // ヘッダーは配列全体の先頭に、フッターは末尾に 1 つずつだけ付ける。
            if configuration.header != nil, isFirstChunk {
                supplementaryItems.append(makeBoundaryItem(kind: UICollectionView.elementKindSectionHeader, alignment: .top))
            }
            if configuration.footer != nil, isLastChunk {
                supplementaryItems.append(makeBoundaryItem(kind: UICollectionView.elementKindSectionFooter, alignment: .bottom))
            }
            section.boundarySupplementaryItems = supplementaryItems
            return section
        }
    }

    private func makeBoundaryItem(
        kind: String,
        alignment: NSRectAlignment
    ) -> NSCollectionLayoutBoundarySupplementaryItem {
        NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .estimated(KsEstimatedHeight.defaultValue)
            ),
            elementKind: kind,
            alignment: alignment
        )
    }

    // 表示範囲と実際に重なっている項目のうち、全体の順番が最も先頭のものを返す。
    // 可視セルの一覧には、遠くへ送った直後に送る前のセルがまだ残っていることがあるため、
    // 一覧の先頭をそのまま採ると画面外の項目をアンカーにしてしまい、復元で先頭へ飛ぶ。
    private func leadingVisibleID() -> AnyHashable? {
        let bounds = collectionView.bounds
        // 表示範囲は、内容の原点 (contentOffset) から見た bounds をバー等の余白で狭めた矩形。
        // 余白で潰れる構成では狭める前の bounds を使う。`configureCollectionView()` が
        // `contentInsetAdjustmentBehavior = .never` を立てているためバー由来の値は入らず、
        // ここで狭まるのは `contentInset` を自ら持つ構成だけである。
        let insetBounds = bounds.inset(by: collectionView.adjustedContentInset)
        let visibleRect = insetBounds.isEmpty ? bounds : insetBounds
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
        pendingAnchor = (
            identifier,
            attributes.frame.minY - collectionView.bounds.minY,
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
        let offsetFromTop = clampedAnchorOffsetFromTop(
            anchor.offsetFromTop,
            anchorHeight: attributes.frame.height
        )
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

    @objc
    private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard
            recognizer.state == .began,
            configuration.onItemLongTap != nil
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

    func performLongPress(at indexPath: IndexPath) {
        guard
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
            collectionView.scrollToItem(
                at: indexPath,
                at: position.collectionViewPosition,
                animated: animated
            )
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

    private func flushPendingCommands() {
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
        return !cell.lastHitWasInteractive
            && (configuration.onItemTap != nil || configuration.onItemLongTap != nil)
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
            let identifier = dataSource.itemIdentifier(for: indexPath)?.value,
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
        guard !isApplyingSnapshot, !isCommandFlushScheduled else { return }

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
