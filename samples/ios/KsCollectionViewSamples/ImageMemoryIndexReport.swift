#if DEBUG
import Nuke
import UIKit
@testable import KsCollectionView

/// 画像グリッドのメモリ計測の走行の後に、引き当ての索引とローダーのメモリキャッシュを突き合わせて
/// 出します。Debug 構成だけに載せる計測用の足場で、本体の内部 (索引) を読むために本体を
/// テスト用に読み込みます (本体に計測のための公開面を足さないため)。
///
/// 出すものは 2 つです。
/// - 索引の充足: メモリキャッシュにある項目のうち、索引が鍵を覚えている割合。索引から外れた項目は
///   表示が引き当てられないため、この割合が下がると到達点をメモリまでにした効果が落ちる
/// - 解放: コレクションを画面から外した後に、コレクションとセルが解放されること。索引は鍵 (要求の値)
///   だけを持ち、ビューを持たないことを確かめる
///
/// 結果は `KS_INDEX` を先頭に付けた行として標準出力へ出します。
@MainActor
enum ImageMemoryIndexReport {
    /// 突き合わせを出した後に、`removeFixture` でコレクションを外して解放を確かめます。
    ///
    /// - Parameters:
    ///   - prefetch: 走行したプリフェッチの形
    ///   - removeFixture: コレクションを画面から外す操作
    static func run(prefetch: ImagePrefetchChoice, removeFixture: () -> Void) async {
        reportSufficiency(prefetch: prefetch)
        await reportRelease(removeFixture: removeFixture)
    }

    /// 全項目について、索引に現れる形の鍵 (縮小の指定ごと) でメモリキャッシュを引き、索引と突き合わせます。
    ///
    /// メモリキャッシュは鍵を列挙できないため、候補の鍵は「縮小なし」と「索引のどこかに現れた縮小の
    /// 指定」から作ります。この走行でライブラリ以外が要求を出すことは無いので、キャッシュにある項目は
    /// これで尽くせます。
    private static func reportSufficiency(prefetch: ImagePrefetchChoice) {
        let index = KsImageMemoryIndex.shared
        let cache = ImagePipeline.shared.cache
        let urls = ImageGridFixture.items.map { DemoData.imageURL(for: $0.id) }

        var variants: Set<ImageRequest.ThumbnailOptions?> = [nil]
        for url in urls {
            for request in index.requests(forEffectiveID: effectiveID(of: url)) {
                variants.insert(request.thumbnail)
            }
        }

        // 縮小の指定は中身を外から読めないため、現れた順の番号で呼び分け、中身は別の行に出す。
        let orderedVariants = variants.compactMap { $0 }.sorted { "\($0)" < "\($1)" }
        func variantName(_ variant: ImageRequest.ThumbnailOptions?) -> String {
            guard let variant, let position = orderedVariants.firstIndex(of: variant) else {
                return "original"
            }
            return "thumb\(position)"
        }
        for (position, variant) in orderedVariants.enumerated() {
            print("KS_INDEX_VARIANT thumb\(position)=\(variant)")
        }

        var cachedByVariant: [String: Int] = [:]
        var bytesByVariant: [String: Int] = [:]
        var cached = 0
        var cachedAndIndexed = 0
        for url in urls {
            let indexed = Set(index.requests(forEffectiveID: effectiveID(of: url)).map(\.thumbnail))
            for variant in variants {
                var request = ImageRequest(url: url)
                request.thumbnail = variant
                guard let container = cache[request] else { continue }
                let name = "\(variantName(variant)):\(pixelText(container.image))"
                let pixels = container.image.size.width * container.image.scale
                    * container.image.size.height * container.image.scale
                cached += 1
                cachedByVariant[name, default: 0] += 1
                bytesByVariant[name, default: 0] += Int(pixels) * 4
                if indexed.contains(variant) {
                    cachedAndIndexed += 1
                }
            }
        }
        let memoryCache = ImagePipeline.shared.configuration.imageCache as? ImageCache
        let ratio = cached == 0 ? 0 : Double(cachedAndIndexed) / Double(cached)
        print(
            "KS_INDEX_SUFFICIENCY prefetch=\(prefetch) indexKeys=\(index.count) "
                + "cached=\(cached) cachedAndIndexed=\(cachedAndIndexed) "
                + "ratio=\(String(format: "%.4f", ratio))"
        )
        print(
            "KS_INDEX_CACHED prefetch=\(prefetch) byVariant=\(cachedByVariant.sorted { $0.key < $1.key }) "
                + "bytesByVariant=\(bytesByVariant.sorted { $0.key < $1.key }) "
                + "costLimit=\(memoryCache?.costLimit ?? -1) totalCost=\(memoryCache?.totalCost ?? -1)"
        )
    }

    /// コレクションを外し、コレクションと可視セルへの弱参照が空になるのを待ちます。
    private static func reportRelease(removeFixture: () -> Void) async {
        let indexKeysBefore = KsImageMemoryIndex.shared.count
        weak var collectionView = findCollectionView()
        let cells = collectionView?.visibleCells.map { WeakCell(cell: $0) } ?? []
        let foundCollection = collectionView != nil
        removeFixture()

        let deadline = ContinuousClock.now + .seconds(10)
        while ContinuousClock.now < deadline {
            if collectionView == nil, cells.allSatisfy({ $0.cell == nil }) { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        let releasedCells = cells.filter { $0.cell == nil }.count
        print(
            "KS_INDEX_RELEASE foundCollection=\(foundCollection) "
                + "collectionReleased=\(collectionView == nil) "
                + "cellsReleased=\(releasedCells)/\(cells.count) "
                + "indexKeysBefore=\(indexKeysBefore) indexKeysAfter=\(KsImageMemoryIndex.shared.count)"
        )
    }

    private static func effectiveID(of url: URL) -> String {
        KsImageIdentity.effectiveID(forIdentifier: url.absoluteString)
    }

    private static func pixelText(_ image: UIImage) -> String {
        "\(Int(image.size.width * image.scale))x\(Int(image.size.height * image.scale))"
    }

    private static func findCollectionView() -> UICollectionView? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                if let found = firstCollectionView(in: window) { return found }
            }
        }
        return nil
    }

    private static func firstCollectionView(in view: UIView) -> UICollectionView? {
        if let collectionView = view as? UICollectionView { return collectionView }
        for subview in view.subviews {
            if let found = firstCollectionView(in: subview) { return found }
        }
        return nil
    }

    /// セルへの弱参照。
    private struct WeakCell {
        weak var cell: UICollectionViewCell?
    }
}
#endif
