import Foundation
import Nuke
import os

/// 画像の読み込みを観測できるようにします。起動引数 `--observe-image-loading` を付けたときだけ働きます。
///
/// 共有パイプラインに観測用の割り込み処理を付けて置き換えます。プリフェッチも表示も同じ共有
/// パイプラインを通るため、開始・取り消し・成功 (どの層に当たったか) を 1 箇所で数えられます。
/// 置き換えでは現在の構成 (ディスクキャッシュを含む) をそのまま引き継ぎます。
///
/// 計測の対照として、起動引数 `--data-loading-limit <数>` で元データの取得の同時数の上限
/// (`dataLoadingQueue`) だけを差し替えられます。差し替えは Sample の共有パイプラインの構成を
/// 変えるだけで、本体の既定には触れません。指定が無い起動ではローダーの既定のままです。
enum ImageLoadingObservation {
    /// 観測を出す先。`log stream` の絞り込みに使います。
    static let subsystem = "jp.kamusoft.kscollectionview.samples.ios"

    /// 観測の分類。
    static let category = "image-loading"

    static let isRequested = ProcessInfo.processInfo.arguments.contains("--observe-image-loading")

    /// 元データの取得の同時数の上限を与える起動引数の名前。
    static let dataLoadingLimitArgumentName = "--data-loading-limit"

    /// 起動引数で指定された、元データの取得の同時数の上限。指定が無ければ `nil`。
    ///
    /// 正の整数でない指定は起動を止めます。黙って既定へ戻すと、対照を測ったつもりで既定の
    /// 構成を測った証跡が残るためです。
    static let requestedDataLoadingLimit: Int? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let position = arguments.firstIndex(of: dataLoadingLimitArgumentName) else { return nil }
        let valuePosition = arguments.index(after: position)
        guard valuePosition < arguments.endIndex,
              let limit = Int(arguments[valuePosition]), limit > 0 else {
            fatalError("\(dataLoadingLimitArgumentName) には正の整数を指定してください")
        }
        return limit
    }()

    /// 観測か同時数の差し替えが要求されていれば、共有パイプラインを作り直して置き換えます。
    ///
    /// 最初の読み込みより前 (アプリの起動時) に呼ぶ必要があります。
    @MainActor
    static func enableIfRequested() {
        let limit = requestedDataLoadingLimit
        guard isRequested || limit != nil else { return }
        if isRequested {
            // 到達点がディスクまでの先読みは、画像ではなく元データの取得として走る。この経路は
            // 割り込み処理に通知が来ないため、ローダー自身の計測記録も併せて有効にする。
            ImagePipeline.Configuration.isSignpostLoggingEnabled = true
        }
        var configuration = ImagePipeline.shared.configuration
        if let limit {
            configuration.dataLoadingQueue = TaskQueue(maxConcurrentOperationCount: limit)
            // 差し替えた走行と既定の走行を出力で見分けられるようにする。
            print("KS_CONTROL dataLoadingLimit=\(limit)")
        }
        ImagePipeline.shared = ImagePipeline(
            configuration: configuration,
            delegate: isRequested ? ImageLoadingObserver() : nil
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
    /// `KsImage` の表示要求。表示枠の実サイズから決めた縮小の指定を持ち、通常の優先度で出ます。
    ///
    /// メモリにある項目を引き当てた `KsImage` は要求を出さないため、ここには現れません。
    static let display = "display"

    /// 表示幅を宣言した、到達点がメモリまでのプリフェッチ。縮小の指定を持ち、プリフェッチの
    /// 低い優先度で出ます (表示要求とは優先度で見分けます)。
    static let widthPrefetch = "width-prefetch"

    /// 到達点がメモリまでで表示幅の無いプリフェッチか、ローダー付属のビュー (`LazyImage`) を直接使った
    /// 表示のどちらか。**この 2 つは要求からは区別できません** — どちらも縮小の指定を持たない
    /// 素の要求になります。
    ///
    /// 到達点がディスクまでのプリフェッチは元データの取得として走り、そもそも割り込み処理へ
    /// 通知が来ないため、ここには現れません (件数はローダー自身の計測記録の側で数えます)。
    static let prefetchOrLoaderDisplay = "prefetch-or-loader-display"

    /// 要求の種別を決めます。副作用を持たない純粋な写像です。
    static func of(_ request: ImageRequest) -> String {
        guard request.thumbnail != nil else { return prefetchOrLoaderDisplay }
        // プリフェッチの要求は、プリフェッチの層がすべて低い優先度に揃えて出します。
        return request.priority == .low ? widthPrefetch : display
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
            let source = Self.sourceName(of: response)
            record("success", task.request, extra: "source=\(source)", source: source)
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

    private func record(_ event: String, _ request: ImageRequest, extra: String = "", source: String? = nil) {
        let kind = ImageRequestKind.of(request)
        let suffix = extra.isEmpty ? "" : " \(extra)"
        let url = request.url?.absoluteString ?? ""
        logger.info("\(event, privacy: .public) kind=\(kind, privacy: .public)\(suffix, privacy: .public) url=\(url, privacy: .public)")
        // 同じ節目をプロセスの中にも残す (計測用の起動経路が記録を始めた実行でだけ溜まる)。
        ImageLoadingLedger.shared.append(
            ImageLoadingLedger.Entry(
                time: .now, event: event, kind: kind, source: source, url: url
            )
        )
    }

    private static func sourceName(of response: ImageResponse) -> String {
        switch response.cacheType {
        case .memory: "memory"
        case .disk: "disk"
        case .none: "network"
        }
    }
}
