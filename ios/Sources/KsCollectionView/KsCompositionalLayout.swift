import UIKit

// エンジンが使う compositional layout。項目の配置は compositional layout に任せ、次の 2 つだけを足す。
//
// 1. 塊に割れたグループの見出しを、グループ全体で 1 つの見出しとして固定する (ios/ADR-0010)。
//    compositional layout の固定はセクション (内部の塊) 単位で、そのままでは塊の境目で見出しが
//    押し出されて差し替わる。全塊に同じ見出しを固定の形で付けたうえで、返す見出しの属性を複製して
//    位置・横位置と幅・透明度を書き換える。書き換えるのは見出しを固定する構成のときだけ。
//    一覧が画面上端の安全領域 (ステータスバー・ナビゲーションバー) に重なって置かれたときは、
//    固定する位置を安全領域の境目 (バーのすぐ下) にする。行とルートのヘッダーは安全領域に
//    被ったまま流れ、安全領域に合わせるのは固定中の見出しだけである。
// 2. 配列の差し替えで、端を表示中の端へ項目が入ったときに表示範囲をその端へ留める。差分の適用の
//    アニメーションの中で表示範囲も一緒に動くよう、更新のアニメーションの中で表示位置を動かす。
//    更新の後の位置を問い合わせる `targetContentOffset(forProposedContentOffset:)` の戻り値は、
//    差分の適用では使われない。
internal final class KsCompositionalLayout: UICollectionViewCompositionalLayout {
    // 見出しを固定する構成のときに書き換えの材料を返す。固定しないときは nil を返す。
    var groupHeaderPinning: (() -> KsGroupHeaderPinning?)?

    // 次の更新の後に表示範囲を留める端。差分を適用する間だけ設定する。
    var edgeToKeepAfterUpdate: KsContentEdge?

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let attributes = super.layoutAttributesForElements(in: rect)
        guard let attributes, let pinning = groupHeaderPinning?() else { return attributes }
        return attributes.map { original in
            guard original.representedElementKind == KsSupplementaryKind.groupHeader else { return original }
            return pinnedGroupHeaderAttributes(from: original, pinning: pinning)
        }
    }

    override func layoutAttributesForSupplementaryView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        let original = super.layoutAttributesForSupplementaryView(ofKind: elementKind, at: indexPath)
        guard
            let original,
            elementKind == KsSupplementaryKind.groupHeader,
            let pinning = groupHeaderPinning?()
        else {
            return original
        }
        return pinnedGroupHeaderAttributes(from: original, pinning: pinning)
    }

    // 差分の適用のアニメーションの中で呼ばれる。ここで表示位置を動かすと、項目の挿入・削除と
    // 同じアニメーションで表示範囲が動く。
    override func finalizeCollectionViewUpdates() {
        super.finalizeCollectionViewUpdates()
        guard let edge = edgeToKeepAfterUpdate, let collectionView else { return }
        let insets = collectionView.adjustedContentInset
        let top = -insets.top
        let target: CGFloat
        switch edge {
        case .top:
            target = top
        case .bottom:
            target = max(top, collectionViewContentSize.height + insets.bottom - collectionView.bounds.height)
        }
        guard abs(collectionView.contentOffset.y - target) >= 0.5 else { return }
        collectionView.contentOffset = CGPoint(x: collectionView.contentOffset.x, y: target)
    }

    // 固定中のグループの見出しを置く上端の位置 (内容の座標)。表示範囲の上端に、上端の安全領域に
    // 重なる分を足した位置。`contentInsetAdjustmentBehavior = .never` のため、安全領域は
    // `adjustedContentInset` に入らず `safeAreaInsets` からだけ得られる。
    func pinnedGroupHeaderTop(in collectionView: UICollectionView) -> CGFloat {
        collectionView.contentOffset.y
            + collectionView.adjustedContentInset.top
            + collectionView.safeAreaInsets.top
    }

    // 書き換える前の見出しの属性。固定したときの位置の計算と、固定中の見出しの高さを知るために使う。
    // 固定する見出しでも、高さと横位置は compositional layout が決めた値のままである。
    func unadjustedGroupHeaderAttributes(section: Int) -> UICollectionViewLayoutAttributes? {
        super.layoutAttributesForSupplementaryView(
            ofKind: KsSupplementaryKind.groupHeader,
            at: IndexPath(item: 0, section: section)
        )
    }

    // グループ全体で 1 つの見出しとして固定した属性を作る。キャッシュされた属性を書き換えないよう複製する。
    //
    // - 位置: グループの見出しの本来の位置と固定する上端 (`pinnedGroupHeaderTop(in:)`) の大きい方。
    //   ただしグループの最後の行の下端から見出しの高さを引いた位置まで (そこからは次のグループの
    //   見出しに押し上げられる)。行の下端は行の中でいちばん背の高い項目の下端で、グリッドでは最後の項目が
    //   同じ行の他の項目より背が低いことがあるため、最後の項目の下端では足りない
    // - 横位置と幅: グループの先頭の塊の見出しに揃える。場所を取らない見出しは塊の左右の内側余白を
    //   無視した位置に置かれるため、揃えないと塊の境目で横にずれる
    // - 透明度: 表示範囲の上端を含む塊の見出しだけを見せ (1)、他の塊の見出しは消す (0)。見せる見出しは
    //   押し上げられている間も 1 のままにする。compositional layout は押し出される固定見出しを透明度で
    //   薄めるが、薄めると押し上げの後半で上端に見出しの無い帯ができる
    private func pinnedGroupHeaderAttributes(
        from original: UICollectionViewLayoutAttributes,
        pinning: KsGroupHeaderPinning
    ) -> UICollectionViewLayoutAttributes {
        let section = original.indexPath.section
        guard
            let collectionView,
            let group = pinning.chunkTable.group(containingSection: section),
            !group.sectionRange.isEmpty,
            let lastChunk = pinning.chunkTable.chunk(at: group.sectionRange.upperBound - 1),
            lastChunk.itemCount > 0,
            let leading = section == group.sectionRange.lowerBound
                ? original
                : unadjustedGroupHeaderAttributes(section: group.sectionRange.lowerBound),
            let firstItem = layoutAttributesForItem(at: IndexPath(item: 0, section: group.sectionRange.lowerBound)),
            let lastItem = layoutAttributesForItem(
                at: IndexPath(item: lastChunk.itemCount - 1, section: group.sectionRange.upperBound - 1)
            ),
            let adjusted = original.copy() as? UICollectionViewLayoutAttributes
        else {
            return original
        }

        // 見出しはグループの先頭の塊の上端の内側余白 (見出しの下の間隔) の外側に、先頭の塊の見出しの
        // 高さで場所を取る。見出しの高さは塊ごとに表示されたときに決まるため、押し上げの位置には
        // この見出し自身の高さを使う。
        let groupTop = firstItem.frame.minY - pinning.headerItemSpacing - leading.frame.height
        let groupBottom = lastRowBottom(
            endingWith: lastItem,
            section: group.sectionRange.upperBound - 1
        )
        let pinnedTop = max(pinnedGroupHeaderTop(in: collectionView), groupTop)
        adjusted.frame = CGRect(
            x: leading.frame.minX,
            y: min(pinnedTop, groupBottom - adjusted.frame.height),
            width: leading.frame.width,
            height: adjusted.frame.height
        )
        let owner = owningSection(of: group, at: pinnedTop, pinning: pinning)
        adjusted.alpha = section == owner ? 1 : 0
        return adjusted
    }

    // 塊の最後の行の下端。最後の項目から前へ、同じ行に並ぶ項目 (上端が揃う項目) をたどり、
    // その中でいちばん下の下端を返す。list では最後の項目の下端と同じになる。
    private func lastRowBottom(endingWith lastItem: UICollectionViewLayoutAttributes, section: Int) -> CGFloat {
        var bottom = lastItem.frame.maxY
        var item = lastItem.indexPath.item - 1
        while item >= 0,
              let attributes = layoutAttributesForItem(at: IndexPath(item: item, section: section)),
              abs(attributes.frame.minY - lastItem.frame.minY) < 0.5 {
            bottom = max(bottom, attributes.frame.maxY)
            item -= 1
        }
        return bottom
    }

    // グループの塊のうち、指定した位置 (固定中の見出しの上端) を含む塊のセクションの番号。
    // 塊の上端は先頭の項目の上端から上端の内側余白 (2 つめ以降の塊では行間) を引いた位置で、
    // 位置がどの塊の上端よりも上ならグループの先頭の塊とする。
    private func owningSection(
        of group: KsGroupInfo,
        at position: CGFloat,
        pinning: KsGroupHeaderPinning
    ) -> Int {
        var owner = group.sectionRange.lowerBound
        for section in group.sectionRange.dropFirst() {
            guard let firstItem = layoutAttributesForItem(at: IndexPath(item: 0, section: section)) else {
                continue
            }
            guard firstItem.frame.minY - pinning.rowSpacing <= position else { break }
            owner = section
        }
        return owner
    }
}
