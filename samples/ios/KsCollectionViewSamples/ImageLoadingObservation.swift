import Foundation
import Nuke
import os

/// 画像の読み込みを観測できるようにします。起動引数 `--observe-image-loading` を付けたときだけ働きます。
///
/// 共有パイプラインに観測用の割り込み処理を付けて置き換えます。プリフェッチも表示も同じ共有
/// パイプラインを通るため、開始・取り消し・成功 (どの層に当たったか) を 1 箇所で数えられます。
/// 置き換えでは現在の構成 (ディスクキャッシュを含む) をそのまま引き継ぎます。
enum ImageLoadingObservation {
    /// 観測を出す先。`log stream` の絞り込みに使います。
    static let subsystem = "jp.kamusoft.kscollectionview.samples.ios"

    /// 観測の分類。
    static let category = "image-loading"

    static let isRequested = ProcessInfo.processInfo.arguments.contains("--observe-image-loading")

    /// 観測が要求されていれば、共有パイプラインを観測付きに置き換えます。
    ///
    /// 最初の読み込みより前 (アプリの起動時) に呼ぶ必要があります。
    @MainActor
    static func enableIfRequested() {
        guard isRequested else { return }
        // 到達点がディスクまでの先読みは、画像ではなく元データの取得として走る。この経路は
        // 割り込み処理に通知が来ないため、ローダー自身の計測記録も併せて有効にする。
        ImagePipeline.Configuration.isSignpostLoggingEnabled = true
        let current = ImagePipeline.shared
        ImagePipeline.shared = ImagePipeline(
            configuration: current.configuration,
            delegate: ImageLoadingObserver()
        )
    }
}

/// 観測した要求に付ける種別。
///
/// 要求に付いた指定だけで見分けられる範囲でしか分けません。**区別できない組み合わせは、
/// 区別できないことが分かる名前を出します** (単一の種別を出すと、集計する側が実態と違う数を
/// 確定値として読んでしまうためです)。
///
/// 割り込み処理はローダーのスレッドから呼ばれるため、主アクターに閉じません。
nonisolated enum ImageRequestKind {
    /// `KsImage` の表示要求。表示枠の実サイズから決めた縮小の指定を持つのはこれだけです。
    static let display = "display"

    /// 到達点がメモリまでのプリフェッチか、ローダー付属のビュー (`LazyImage`) を直接使った
    /// 表示のどちらか。**この 2 つは要求からは区別できません** — どちらも縮小の指定を持たない
    /// 素の要求になります。
    ///
    /// 到達点がディスクまでのプリフェッチは元データの取得として走り、そもそも割り込み処理へ
    /// 通知が来ないため、ここには現れません (件数はローダー自身の計測記録の側で数えます)。
    static let prefetchOrLoaderDisplay = "prefetch-or-loader-display"

    /// 要求の種別を決めます。副作用を持たない純粋な写像です。
    static func of(_ request: ImageRequest) -> String {
        request.thumbnail == nil ? prefetchOrLoaderDisplay : display
    }
}

/// 読み込みの節目を 1 件ずつ記録する割り込み処理です。
///
/// 要求の種別は `ImageRequestKind` が決めます。
private final class ImageLoadingObserver: ImagePipeline.Delegate {
    private let logger: Logger

    init() {
        logger = Logger(subsystem: "jp.kamusoft.kscollectionview.samples.ios", category: "image-loading")
    }

    func imageTaskCreated(_ task: ImageTask, pipeline: ImagePipeline) {
        record("start", task.request)
    }

    func imageTask(_ task: ImageTask, didReceiveEvent event: ImageTask.Event, pipeline: ImagePipeline) {
        switch event {
        case .finished(.success(let response)):
            // どの層に当たったかは、プリフェッチが効いているかの判定にそのまま使えます。
            record("success", task.request, extra: "source=\(Self.sourceName(of: response))")
        case .finished(.failure(let error)):
            record(Self.isCancelled(error) ? "cancel" : "error", task.request)
        default:
            break
        }
    }

    /// 取り消しは失敗の一種として届くため、種別で見分けます。
    private static func isCancelled(_ error: ImagePipeline.Error) -> Bool {
        if case .cancelled = error { return true }
        return false
    }

    private func record(_ event: String, _ request: ImageRequest, extra: String = "") {
        let kind = ImageRequestKind.of(request)
        let suffix = extra.isEmpty ? "" : " \(extra)"
        let url = request.url?.absoluteString ?? ""
        logger.info("\(event, privacy: .public) kind=\(kind, privacy: .public)\(suffix, privacy: .public) url=\(url, privacy: .public)")
    }

    private static func sourceName(of response: ImageResponse) -> String {
        switch response.cacheType {
        case .memory: "memory"
        case .disk: "disk"
        case .none: "network"
        }
    }
}
