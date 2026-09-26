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
    private var appliedChunkTable = KsGroupChunkTable.empty
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

    private var isApplyingSnapshot: Bool {
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
        var configuration = configuration
        configuration.layout = Self.validatedLayout(configuration.layout)
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
        // 差し替え後の配列に無い項目は、システムから取り消し通知が来ないためここで取り消す。
        // ID が同じまま画像が差し替わった項目も、ここで新しい URL へ切り替える。
        imagePrefetcher?.retain(items: configuration.items)

        apply(
            items: configuration.items,
            animatingDifferences: true,
            reconfiguringAllItems: layoutKindChanged,
            rebuildingVisibleCellContentOnEqualItems: rebuildsVisibleCellContent,
            rebuildingSurvivingVisibleCellContent: observedValueChanged,
            regroupingSections: groupingDeclarationChanged || groupValueSourceChanged
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

    // 固定中のグループの見出しの位置は上端の安全領域に合わせるため、安全領域が変わったら置き直す。
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        guard pinsGroupHeaders else { return }
        collectionView.collectionViewLayout.invalidateLayout()
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
    private func configureFooter(_ view: KsHostingSupplementaryView) {
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
        rebuildingSurvivingVisibleCellContent: Bool = false,
        regroupingSections: Bool = false
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
            ? edgeToKeep(previous: currentIdentifiers, next: identifiers)
            : nil
        defer { compositionalLayout?.edgeToKeepAfterUpdate = nil }
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

    // 差し替えの直前に表示範囲がコンテンツの先頭 / 末尾にあり (1pt 未満の差は一致とみなす)、
    // 差し替えでその端に新しい項目が入るとき、表示範囲を留める端。どちらでもなければ nil で、
    // 表示範囲はコンテンツの位置を保つ既定のままにする。先頭と末尾の両方に当たるときは先頭を採る。
    private func edgeToKeep(previous: [KsItemIdentifier], next: [KsItemIdentifier]) -> KsContentEdge? {
        guard hasAppliedSnapshot, !next.isEmpty else { return nil }
        let insets = collectionView.adjustedContentInset
        let offset = collectionView.contentOffset.y
        let top = -insets.top
        let bottom = max(top, collectionView.contentSize.height + insets.bottom - collectionView.bounds.height)
        let previousIdentifiers = Set(previous)
        if offset - top < 1, let first = next.first, !previousIdentifiers.contains(first) {
            return .top
        }
        if bottom - offset < 1, let last = next.last, !previousIdentifiers.contains(last) {
            return .bottom
        }
        return nil
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

    private var compositionalLayout: KsCompositionalLayout? {
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
        if configuration.footer != nil || padding.bottom > 0 {
            items.append(
                makeRootBoundaryItem(
                    kind: KsSupplementaryKind.rootFooter,
                    alignment: .bottom,
                    height: configuration.footer != nil
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
    private var pinnedGroupHeaderTopInset: CGFloat {
        collectionView.safeAreaInsets.top
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
