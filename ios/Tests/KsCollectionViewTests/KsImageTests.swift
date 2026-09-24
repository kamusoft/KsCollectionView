import CoreImage
import Nuke
import SwiftUI
import UIKit
import XCTest
@testable import KsCollectionView

/// `KsImage` が組み立てる要求と、キャッシュ操作が表示へ及ぼす影響を確かめる。
@MainActor
final class KsImageTests: XCTestCase {
    private let remote = URL(string: "https://images.example.com/a.jpg")!
    private let other = URL(string: "https://images.example.com/b.jpg")!
    // 表示レベルの検査で開いた窓。テストをまたいで生き残ると、次のテストのパイプラインへ
    // 読み込みを出し続けるため、必ず片付ける。
    private var windows: [UIWindow] = []

    override func setUp() async throws {
        try await super.setUp()
        KsImageIdentity.resetGenerations()
        KsImageInvalidation.shared.reset()
        KsImageMemoryIndex.shared.removeAll()
        KsInvalidInput.reset()
    }

    override func tearDown() async throws {
        dismissWindows()
        KsImageIdentity.resetGenerations()
        KsImageInvalidation.shared.reset()
        KsImageMemoryIndex.shared.removeAll()
        KsInvalidInput.reset()
        try await super.tearDown()
    }

    // MARK: - ソースの経路

    func test3種のソースがそれぞれの経路へ振り分けられる() {
        let file = URL(fileURLWithPath: "/tmp/local.jpg")

        XCTAssertEqual(KsImageRequestFactory.route(for: .remote(remote)), .loader(remote))
        XCTAssertEqual(KsImageRequestFactory.route(for: .remote(remote, key: "p1")), .loader(remote))
        XCTAssertEqual(KsImageRequestFactory.route(for: .file(file)), .loader(file))
        XCTAssertEqual(KsImageRequestFactory.route(for: .asset("logo")), .asset("logo"))
    }

    func test便宜形はリモートのソースと同じ宣言になる() {
        XCTAssertEqual(KsImage(remote).source, KsImage(.remote(remote)).source)
        XCTAssertEqual(KsImage(remote).source, .remote(remote))
        XCTAssertEqual(KsImage(remote, key: "p1").source, .remote(remote, key: "p1"))
        XCTAssertEqual(KsImage(remote, key: "p1", loading: { Color.clear }).source, .remote(remote, key: "p1"))
        XCTAssertEqual(KsImage(remote, key: "p1", failure: { Color.clear }).source, .remote(remote, key: "p1"))
        XCTAssertEqual(
            KsImage(remote, key: "p1", loading: { Color.clear }, failure: { Color.clear }).source,
            .remote(remote, key: "p1")
        )
    }

    func test当てはめ方の既定はfillになる() {
        XCTAssertEqual(KsImage(remote).contentMode, .fill)
        XCTAssertEqual(KsImage(.remote(remote), contentMode: .fit).contentMode, .fit)
    }

    func testアセットのソースではローダーへの要求を作らない() {
        let prepared = KsImageRequestFactory.prepare(
            source: .asset("logo"),
            size: CGSize(width: 50, height: 50),
            contentMode: .fill,
            displayScale: 2
        )

        XCTAssertNil(prepared)
    }

    // MARK: - 縮小デコード

    func testサイズが確定するまで要求を発行しない() {
        for size in [CGSize.zero, CGSize(width: 50, height: 0), CGSize(width: 0, height: 50)] {
            XCTAssertNil(
                KsImageRequestFactory.prepare(
                    source: .remote(remote),
                    size: size,
                    contentMode: .fill,
                    displayScale: 2
                ),
                "サイズ \(size) で要求が発行されました"
            )
        }

        XCTAssertNotNil(
            KsImageRequestFactory.prepare(
                source: .remote(remote),
                size: CGSize(width: 50, height: 50),
                contentMode: .fill,
                displayScale: 2
            )
        )
    }

    func test表示枠と当てはめ方から決まる縮小指定が付く() throws {
        let size = CGSize(width: 50, height: 25)

        let fit = try makeDisplayRequest(size: size, contentMode: .fit)
        let fill = try makeDisplayRequest(size: size, contentMode: .fill)

        XCTAssertEqual(
            fit.thumbnail,
            ImageRequest.ThumbnailOptions(
                size: CGSize(width: 100, height: 50), unit: .pixels, contentMode: .aspectFit
            )
        )
        XCTAssertEqual(
            fill.thumbnail,
            ImageRequest.ThumbnailOptions(
                size: CGSize(width: 100, height: 50), unit: .pixels, contentMode: .aspectFill
            )
        )
    }

    func test枠より大きい画像は当てはめ方に応じた寸法へ縮小される() throws {
        // 元寸 200x100 の画像を 50x50 の枠 (表示倍率 2 → 100x100 ピクセル) へ表示する。
        let data = try XCTUnwrap(Self.makePNG(width: 200, height: 100))
        let size = CGSize(width: 50, height: 50)

        let fit = try XCTUnwrap(makeDisplayRequest(size: size, contentMode: .fit).thumbnail)
        let fill = try XCTUnwrap(makeDisplayRequest(size: size, contentMode: .fill).thumbnail)

        let fitImage = try XCTUnwrap(fit.makeThumbnail(with: data)?.cgImage)
        let fillImage = try XCTUnwrap(fill.makeThumbnail(with: data)?.cgImage)

        // fit は枠に収まる最大 (100x50)、fill は枠を覆う最小 (200x100)。どちらも元寸を超えない。
        XCTAssertEqual(fitImage.width, 100)
        XCTAssertEqual(fitImage.height, 50)
        XCTAssertEqual(fillImage.width, 200)
        XCTAssertEqual(fillImage.height, 100)
    }

    // MARK: - メモリ項目の引き当て

    func test先読みの縮小済み項目を枠にそのまま使い要求を出さない() throws {
        try withIsolatedPipeline { pipeline in
            // 列幅 100pt (表示倍率 2 → 200 ピクセル) で先読みした項目。
            let placed = try place(pixels: CGSize(width: 200, height: 200), widthPixels: 200, in: pipeline)

            let prepared = try makePrepared(size: CGSize(width: 100, height: 100))

            XCTAssertTrue(prepared.matchedImage === placed, "先読みの項目が使われていません")
            // 引き当てに成功したときは表示の要求を索引に覚えさせない (要求を出さないため)。
            XCTAssertEqual(indexedRequests().count, 1)
        }
    }

    func test原寸の項目も許容範囲の内側なら枠にそのまま使う() throws {
        try withIsolatedPipeline { pipeline in
            // 幅なしで先読みした原寸 800x600 を、200x200 ピクセルの枠に fill で使う (必要な拡大率 1/3)。
            let placed = try place(pixels: CGSize(width: 800, height: 600), widthPixels: nil, in: pipeline)

            let prepared = try makePrepared(size: CGSize(width: 100, height: 100))

            XCTAssertTrue(prepared.matchedImage === placed, "原寸の項目が使われていません")
        }
    }

    func test小さすぎる項目は使わず枠の実サイズで縮小する要求を出す() throws {
        try withIsolatedPipeline { pipeline in
            // 200 ピクセルの枠に 90 ピクセルの項目 (必要な拡大率 2.2 倍) は下限を下回る。
            try place(pixels: CGSize(width: 90, height: 90), widthPixels: 90, in: pipeline)

            let prepared = try makePrepared(size: CGSize(width: 100, height: 100))

            XCTAssertNil(prepared.matchedImage, "小さすぎる項目が使われました")
            XCTAssertEqual(
                prepared.request.thumbnail,
                ImageRequest.ThumbnailOptions(
                    size: CGSize(width: 200, height: 200), unit: .pixels, contentMode: .aspectFill
                )
            )
            // 出す要求は索引に覚えさせる。
            XCTAssertTrue(
                indexedRequests().contains { $0.thumbnail == prepared.request.thumbnail },
                "表示の要求が索引に登録されていません"
            )
        }
    }

    func test大きすぎる項目は使わない() throws {
        try withIsolatedPipeline { pipeline in
            // 200 ピクセルの枠に 1000 ピクセルの項目 (必要な拡大率 0.2 倍) は上限を超える。
            try place(pixels: CGSize(width: 1000, height: 1000), widthPixels: nil, in: pipeline)

            XCTAssertNil(try makePrepared(size: CGSize(width: 100, height: 100)).matchedImage)
        }
    }

    func test縦長の枠にfillするときは高さで判定する() throws {
        try withIsolatedPipeline { pipeline in
            // 幅は枠と同じ 100 ピクセルだが高さが 80 ピクセルの横長の項目。
            try place(pixels: CGSize(width: 100, height: 80), widthPixels: nil, in: pipeline)
            // 50x100pt の縦長の枠 (100x200 ピクセル)。fill では高さを 2.5 倍に拡大する必要がある。
            let tall = CGSize(width: 50, height: 100)

            XCTAssertNil(try makePrepared(size: tall, contentMode: .fill).matchedImage, "高さの足りない項目が使われました")
            // fit なら拡大率は 1 倍で、同じ項目を使える。
            XCTAssertNotNil(try makePrepared(size: tall, contentMode: .fit).matchedImage)
        }
    }

    func test範囲内の候補が複数あれば必要な寸法に最も近い項目を使う() throws {
        try withIsolatedPipeline { pipeline in
            try place(pixels: CGSize(width: 150, height: 150), widthPixels: 150, in: pipeline)
            let closest = try place(pixels: CGSize(width: 210, height: 210), widthPixels: 210, in: pipeline)
            try place(pixels: CGSize(width: 300, height: 300), widthPixels: 300, in: pipeline)

            let prepared = try makePrepared(size: CGSize(width: 100, height: 100))

            XCTAssertTrue(prepared.matchedImage === closest)
        }
    }

    func test枠が変わっても範囲内なら同じ項目を使い続ける() throws {
        try withIsolatedPipeline { pipeline in
            let placed = try place(pixels: CGSize(width: 200, height: 200), widthPixels: 200, in: pipeline)

            // 縦向きの枠 (200 ピクセル) から横向きの枠 (260 ピクセル) へ変わる。
            XCTAssertTrue(try makePrepared(size: CGSize(width: 100, height: 100)).matchedImage === placed)
            XCTAssertTrue(
                try makePrepared(size: CGSize(width: 130, height: 130)).matchedImage === placed,
                "枠が変わっただけで再デコードの要求になりました"
            )
        }
    }

    func test消した項目は引き当てない() throws {
        try withIsolatedPipeline { pipeline in
            try place(pixels: CGSize(width: 200, height: 200), widthPixels: 200, in: pipeline)

            KsImageCache.remove(.remote(remote))

            XCTAssertNil(try makePrepared(size: CGSize(width: 100, height: 100)).matchedImage)
        }
    }

    func testメモリ全体を消した後は引き当てない() throws {
        try withIsolatedPipeline { pipeline in
            try place(pixels: CGSize(width: 200, height: 200), widthPixels: 200, in: pipeline)

            KsImageCache.clear(.memory)

            XCTAssertEqual(KsImageMemoryIndex.shared.count, 0, "索引が残っています")
            XCTAssertNil(try makePrepared(size: CGSize(width: 100, height: 100)).matchedImage)
        }
    }

    func test画素の置き場に関わらず実物の寸法だけで判定する() throws {
        try withIsolatedPipeline { pipeline in
            // 画素を直接読めない (CGImage を持たない) 画像でも、寸法が範囲内なら使う。
            let image = try XCTUnwrap(Self.makeCIImageBacked(pixels: CGSize(width: 200, height: 200)))
            XCTAssertNil(image.cgImage)
            let request = KsPrefetchRequest(url: remote, imageID: nil, widthPixels: 200).imageRequest
            pipeline.cache[request] = ImageContainer(image: image)
            KsImageMemoryIndex.shared.register(request)

            XCTAssertTrue(try makePrepared(size: CGSize(width: 100, height: 100)).matchedImage === image)
        }
    }

    // MARK: - 索引

    func test先読みの完了前に照会しても完了後の次の照会で引き当てる() throws {
        try withIsolatedPipeline { pipeline in
            // 要求は出したがまだ完了していない (キャッシュに無い) 先読みの鍵。表示の要求とは別の鍵にする。
            let pending = KsPrefetchRequest(url: remote, imageID: nil, widthPixels: 190).imageRequest
            KsImageMemoryIndex.shared.register(pending)

            XCTAssertNil(try makePrepared(size: CGSize(width: 100, height: 100)).matchedImage, "完了していない鍵が候補になりました")
            XCTAssertTrue(
                indexedRequests().contains { $0.thumbnail == pending.thumbnail },
                "照会しただけで先読みの鍵が索引から外れました"
            )

            // 先読みが完了して同じ鍵に項目が載る (登録は要求を出した時点の 1 回だけ)。
            let image = try XCTUnwrap(Self.makeImage(pixels: CGSize(width: 190, height: 190)))
            pipeline.cache[pending] = ImageContainer(image: image)

            XCTAssertTrue(
                try makePrepared(size: CGSize(width: 100, height: 100)).matchedImage === image,
                "完了した先読みの項目を引き当てませんでした"
            )
        }
    }

    func test先読みの鍵は取り消しか項目を見るまで取得中の可能性として数える() throws {
        try withIsolatedPipeline { pipeline in
            let index = KsImageMemoryIndex(capacity: 10)
            let prefetch = KsPrefetchRequest(url: remote, imageID: nil, widthPixels: 190).imageRequest
            let display = try makeDisplayRequest(size: CGSize(width: 100, height: 100))
            index.register(display)
            XCTAssertFalse(
                index.mayBeLoadingPrefetch(forEffectiveID: remote.absoluteString, excluding: display, in: pipeline.cache),
                "表示の要求の鍵を先読みとして数えました"
            )

            index.registerPrefetch(prefetch)
            XCTAssertTrue(
                index.mayBeLoadingPrefetch(forEffectiveID: remote.absoluteString, excluding: display, in: pipeline.cache)
            )
            // 表示と同じ鍵の先読みは、表示の要求が同じ取得に合流するので数えない。
            XCTAssertFalse(
                index.mayBeLoadingPrefetch(forEffectiveID: remote.absoluteString, excluding: prefetch, in: pipeline.cache)
            )
            XCTAssertFalse(
                index.mayBeLoadingPrefetch(forEffectiveID: other.absoluteString, excluding: display, in: pipeline.cache),
                "別の画像の先読みを数えました"
            )

            index.cancelPrefetch(prefetch)
            XCTAssertFalse(
                index.mayBeLoadingPrefetch(forEffectiveID: remote.absoluteString, excluding: display, in: pipeline.cache),
                "取り消した先読みを数えました"
            )
            XCTAssertEqual(index.requests(forEffectiveID: remote.absoluteString).count, 2, "取り消しで鍵が索引から外れました")

            // 項目がキャッシュにあるのを一度見た鍵は、追い出された後も数えない。
            index.registerPrefetch(prefetch)
            let image = try XCTUnwrap(Self.makeImage(pixels: CGSize(width: 190, height: 190)))
            pipeline.cache[prefetch] = ImageContainer(image: image)
            XCTAssertFalse(
                index.mayBeLoadingPrefetch(forEffectiveID: remote.absoluteString, excluding: display, in: pipeline.cache)
            )
            pipeline.cache[prefetch] = nil
            XCTAssertFalse(
                index.mayBeLoadingPrefetch(forEffectiveID: remote.absoluteString, excluding: display, in: pipeline.cache),
                "完了を見た先読みを取得中とみなしました"
            )

            // 索引から外れた鍵は数えない。
            index.registerPrefetch(prefetch)
            index.remove(effectiveID: remote.absoluteString)
            XCTAssertFalse(
                index.mayBeLoadingPrefetch(forEffectiveID: remote.absoluteString, excluding: display, in: pipeline.cache)
            )
            index.registerPrefetch(prefetch)
            index.removeAll()
            XCTAssertFalse(
                index.mayBeLoadingPrefetch(forEffectiveID: remote.absoluteString, excluding: display, in: pipeline.cache)
            )
        }
    }

    func test索引は上限を超えると最も長く使われていない鍵から外す() {
        let index = KsImageMemoryIndex(capacity: 2)
        let requests = [100, 200, 300].map {
            KsPrefetchRequest(url: remote, imageID: nil, widthPixels: $0).imageRequest
        }

        index.register(requests[0])
        index.register(requests[1])
        // 1 件目を使ったので、次に外れるのは 2 件目になる。
        index.markUsed(requests[0])
        index.register(requests[2])

        XCTAssertEqual(index.count, 2)
        XCTAssertEqual(
            Set(index.requests(forEffectiveID: remote.absoluteString).compactMap { $0.thumbnail }),
            Set([requests[0], requests[2]].compactMap { $0.thumbnail })
        )
    }

    func test同じ鍵を重ねて登録しても1件として数える() {
        let index = KsImageMemoryIndex(capacity: 10)
        let request = KsPrefetchRequest(url: remote, imageID: nil, widthPixels: 100).imageRequest

        index.register(request)
        index.register(request)

        XCTAssertEqual(index.count, 1)
    }

    func test削除はその識別子の鍵だけを索引から外す() throws {
        try withIsolatedPipeline { _ in
            let target = KsPrefetchRequest(url: remote, imageID: nil, widthPixels: 100).imageRequest
            let kept = KsPrefetchRequest(url: other, imageID: nil, widthPixels: 100).imageRequest
            KsImageMemoryIndex.shared.register(target)
            KsImageMemoryIndex.shared.register(kept)

            KsImageCache.remove(.remote(remote))

            XCTAssertTrue(KsImageMemoryIndex.shared.requests(forEffectiveID: remote.absoluteString).isEmpty)
            XCTAssertEqual(KsImageMemoryIndex.shared.requests(forEffectiveID: other.absoluteString).count, 1)
        }
    }

    // MARK: - 識別子と任意キー

    func testキーなしの表示の要求は世代が進むまで識別子を付けない() throws {
        // ローダーを直接使う素の要求と同じ識別子になり、同じキャッシュ項目を指す。
        XCTAssertEqual(try makeDisplayRequest(size: CGSize(width: 50, height: 50)).imageID, remote.absoluteString)
        XCTAssertNil(KsImageIdentity.imageID(forIdentifier: remote.absoluteString))
    }

    func testキーを付けた表示の要求は世代に関わらずキーの識別子を持つ() throws {
        let request = try XCTUnwrap(
            KsImageRequestFactory.prepare(
                source: .remote(remote, key: "p1"),
                size: CGSize(width: 50, height: 50),
                contentMode: .fill,
                displayScale: 2
            )
        ).request

        let identifier = KsImageIdentity.identifier(url: remote, key: "p1")
        XCTAssertEqual(request.imageID, KsImageIdentity.imageID(forIdentifier: identifier))
        XCTAssertNotNil(KsImageIdentity.imageID(forIdentifier: identifier))
        XCTAssertNotEqual(request.imageID, remote.absoluteString)
        // 取得には URL を使う。
        XCTAssertEqual(request.url, remote)
    }

    func testキーの識別子はURLの識別子と衝突しない() {
        // 別の画像のキーに、ある URL と同じ文字列を付けても別の識別子になる。
        XCTAssertNotEqual(
            KsImageIdentity.identifier(url: other, key: remote.absoluteString),
            KsImageIdentity.identifier(url: remote, key: nil)
        )
    }

    func test削除の世代は別のキーや別のURLと衝突しない() {
        let p1 = KsImageIdentity.identifier(url: remote, key: "p1")
        KsImageIdentity.advanceGeneration(forIdentifier: p1)
        // キーに世代の区切りらしき文字を連ねた別の画像。
        let q = KsImageIdentity.identifier(url: remote, key: "p1#1")
        XCTAssertNotEqual(KsImageIdentity.effectiveID(forIdentifier: p1), KsImageIdentity.effectiveID(forIdentifier: q))

        // キーなしでも、世代付きの識別子は断片付きの別の URL と重ならない。
        KsImageIdentity.advanceGeneration(forIdentifier: remote.absoluteString)
        let fragment = URL(string: remote.absoluteString + "#1")!
        XCTAssertNotEqual(
            KsImageIdentity.effectiveID(forIdentifier: remote.absoluteString),
            KsImageIdentity.effectiveID(forIdentifier: fragment.absoluteString)
        )
    }

    func test空文字のキーは警告してURLで見分ける() throws {
        KsInvalidInput.assertsInDebug = false

        let request = try XCTUnwrap(
            KsImageRequestFactory.prepare(
                source: .remote(remote, key: ""),
                size: CGSize(width: 50, height: 50),
                contentMode: .fill,
                displayScale: 2
            )
        ).request

        XCTAssertEqual(request.imageID, remote.absoluteString)
        XCTAssertFalse(KsInvalidInput.reportedWarnings.isEmpty, "警告が記録されていません")
    }

    func test空文字のキーの警告は表示を評価し直しても同じ文面につき1回だけ記録する() throws {
        KsInvalidInput.assertsInDebug = false

        // 表示の評価のたびに同じソースから要求を組み立て直す。
        for _ in 0..<3 {
            _ = KsImageRequestFactory.prepare(
                source: .remote(remote, key: ""),
                size: CGSize(width: 50, height: 50),
                contentMode: .fill,
                displayScale: 2
            )
            _ = KsImageIdentity.identifier(url: remote, key: "")
        }

        XCTAssertEqual(KsInvalidInput.reportedWarnings.count, 1, "同じ警告を繰り返しました")
    }

    // MARK: - キャッシュのクリアと世代

    func test全消去は世代を進めメモリのみ消去は進めない() {
        let pipeline = Self.makeIsolatedPipeline()
        let original = ImagePipeline.shared
        ImagePipeline.shared = pipeline
        defer { ImagePipeline.shared = original }

        XCTAssertEqual(KsImageInvalidation.shared.globalGeneration, 0)

        KsImageCache.clear(.memory)
        XCTAssertEqual(KsImageInvalidation.shared.globalGeneration, 0, "メモリのみ消去で世代が進みました")

        KsImageCache.clear(.all)
        XCTAssertEqual(KsImageInvalidation.shared.globalGeneration, 1)
    }

    func testソース単位の削除は対象のソースの識別子だけを変える() throws {
        let pipeline = Self.makeIsolatedPipeline()
        let original = ImagePipeline.shared
        ImagePipeline.shared = pipeline
        defer { ImagePipeline.shared = original }

        XCTAssertNil(KsImageIdentity.imageID(forIdentifier: remote.absoluteString))

        KsImageCache.remove(.remote(remote))

        XCTAssertNotNil(KsImageIdentity.imageID(forIdentifier: remote.absoluteString))
        XCTAssertNotEqual(KsImageIdentity.effectiveID(forIdentifier: remote.absoluteString), remote.absoluteString)
        XCTAssertNil(KsImageIdentity.imageID(forIdentifier: other.absoluteString), "他のソースの識別子が変わりました")
        // 範囲消去ではないので、他のソースの表示は読み込み直しにならない。
        XCTAssertEqual(KsImageInvalidation.shared.globalGeneration, 0)
    }

    func testアセットの削除は何もしない() {
        let pipeline = Self.makeIsolatedPipeline()
        let original = ImagePipeline.shared
        ImagePipeline.shared = pipeline
        defer { ImagePipeline.shared = original }

        KsImageCache.remove(.asset("logo"))

        XCTAssertNil(KsImageIdentity.imageID(forIdentifier: "logo"))
        XCTAssertEqual(KsImageInvalidation.shared.revision, 0)
    }

    func test削除後はどの表示サイズの要求も削除前の項目に当たらない() throws {
        let pipeline = Self.makeIsolatedPipeline()
        let original = ImagePipeline.shared
        ImagePipeline.shared = pipeline
        defer { ImagePipeline.shared = original }

        let sizes = [CGSize(width: 50, height: 50), CGSize(width: 120, height: 90)]
        let before = try sizes.map { try makeDisplayRequest(size: $0) }
        // 削除前の項目をメモリへ置く。
        for request in before {
            pipeline.cache[request] = ImageContainer(image: UIImage())
            XCTAssertNotNil(pipeline.cache[request])
        }

        KsImageCache.remove(.remote(remote))

        for size in sizes {
            let after = try makeDisplayRequest(size: size)
            XCTAssertEqual(after.imageID, KsImageIdentity.effectiveID(forIdentifier: remote.absoluteString))
            XCTAssertNotEqual(after.imageID, remote.absoluteString)
            XCTAssertNil(pipeline.cache[after], "サイズ \(size) の要求が削除前の項目に当たりました")
        }
    }

    /// 本番の表示と同じ入口で組み立てた、表示に使う要求と初回描画用の画像。
    private func makePrepared(
        size: CGSize,
        contentMode: KsImageContentMode = .fill
    ) throws -> KsPreparedImageRequest {
        try XCTUnwrap(
            KsImageRequestFactory.prepare(
                source: .remote(remote), size: size, contentMode: contentMode, displayScale: 2
            )
        )
    }

    private func makeDisplayRequest(
        size: CGSize,
        contentMode: KsImageContentMode = .fill
    ) throws -> ImageRequest {
        try makePrepared(size: size, contentMode: contentMode).request
    }

    /// 共有パイプラインを、他のテストのキャッシュを持ち込まないものに差し替えて本体を実行する。
    private func withIsolatedPipeline(_ body: (ImagePipeline) throws -> Void) throws {
        let pipeline = Self.makeIsolatedPipeline()
        let original = ImagePipeline.shared
        ImagePipeline.shared = pipeline
        defer { ImagePipeline.shared = original }
        try body(pipeline)
    }

    /// 先読みが載せたのと同じ鍵で、指定したピクセル寸法の画像をメモリへ置き、索引に覚えさせる。
    @discardableResult
    private func place(pixels: CGSize, widthPixels: Int?, in pipeline: ImagePipeline) throws -> UIImage {
        let image = try XCTUnwrap(Self.makeImage(pixels: pixels))
        let request = KsPrefetchRequest(url: remote, imageID: nil, widthPixels: widthPixels).imageRequest
        pipeline.cache[request] = ImageContainer(image: image)
        KsImageMemoryIndex.shared.register(request)
        return image
    }

    /// このテストの画像について索引が覚えている要求。
    private func indexedRequests() -> [ImageRequest] {
        KsImageMemoryIndex.shared.requests(forEffectiveID: remote.absoluteString)
    }

    // MARK: - 失敗後の再試行

    func test失敗した表示はビューが作り直されると再び取得を試みる() async {
        KsFailingURLProtocol.reset()
        let original = ImagePipeline.shared
        ImagePipeline.shared = Self.makeFailingPipeline()
        defer { ImagePipeline.shared = original }

        let firstWindow = show(KsImage(.remote(remote)))
        await waitUntil("1 回目の取得", value: { KsFailingURLProtocol.requestCount }) { $0 >= 1 }
        firstWindow.isHidden = true

        // セルの再利用・画面への再入場に相当する、同じソースの新しいビュー。
        let secondWindow = show(KsImage(.remote(remote)))
        await waitUntil("再生成後の取得", value: { KsFailingURLProtocol.requestCount }) { $0 >= 2 }
        secondWindow.isHidden = true

        XCTAssertEqual(KsFailingURLProtocol.requestCount, 2)
    }

    private func show(_ view: some View) -> UIWindow {
        let host = UIHostingController(rootView: view.frame(width: 50, height: 50))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.loadViewIfNeeded()
        host.view.layoutIfNeeded()
        windows.append(window)
        return window
    }

    private func dismissWindows() {
        for window in windows {
            window.isHidden = true
            window.rootViewController = nil
        }
        windows.removeAll()
    }

    private func waitUntil<Value>(
        _ label: String,
        value: () -> Value,
        predicate: (Value) -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(10)
        while clock.now < deadline {
            if predicate(value()) {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("\(label) が期限内に収束しませんでした。実測値: \(String(describing: value()))")
    }

    // MARK: - 補助

    /// 取得が必ず失敗するパイプライン。
    private static func makeFailingPipeline() -> ImagePipeline {
        var configuration = ImagePipeline.Configuration()
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [KsFailingURLProtocol.self]
        configuration.dataLoader = DataLoader(configuration: sessionConfiguration)
        configuration.imageCache = ImageCache()
        configuration.dataCache = nil
        return ImagePipeline(configuration: configuration)
    }

    /// 他のテストのキャッシュを持ち込まない、この場限りのパイプライン。
    private static func makeIsolatedPipeline() -> ImagePipeline {
        var configuration = ImagePipeline.Configuration()
        configuration.imageCache = ImageCache()
        configuration.dataCache = nil
        return ImagePipeline(configuration: configuration)
    }

    /// 指定したピクセル寸法の画像。
    private static func makeImage(pixels: CGSize) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: pixels, format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: pixels))
        }
    }

    /// 画素を CPU 側に持たない (CGImage を持たない) 画像。画素の置き場が違う画像の代わりに使う。
    private static func makeCIImageBacked(pixels: CGSize) -> UIImage? {
        let ciImage = CIImage(color: .blue).cropped(to: CGRect(origin: .zero, size: pixels))
        return UIImage(ciImage: ciImage, scale: 1, orientation: .up)
    }

    /// 指定した大きさの不透明な PNG。
    private static func makePNG(width: Int, height: Int) -> Data? {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData()
    }
}

/// 常に失敗を返し、取得の回数を数える取得層。
private final class KsFailingURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var count = 0

    static var requestCount: Int {
        lock.withLock { count }
    }

    static func reset() {
        lock.withLock { count = 0 }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.withLock { Self.count += 1 }
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() { }
}
