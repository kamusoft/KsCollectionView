import Foundation
import NukeUI
import SwiftUI

/// 画像を表示するビュー。
///
/// リモート URL・端末内のファイル・アセットカタログの画像を表示します。リモートとファイルの
/// 画像は非同期に読み込み、読み込み中と失敗の表示を差し替えられます。
///
/// ```swift
/// KsImage(.remote(url))
/// KsImage(.remote(url), contentMode: .fit) {
///     ProgressView()
/// } failure: {
///     Text("表示できません")
/// }
/// KsImage(.remote(url), failure: { Text("表示できません") })
/// KsImage(url, key: photo.id)   // 取得のたびに URL が変わる画像はキーで見分ける
/// ```
///
/// 読み込み中と失敗の表示は片方だけを指定でき、指定しなかった側は既定の表示になります。
///
/// 既定の表示の色は、この画像が置かれた場所の外観 (ライト / ダーク。アプリが上書きした外観を含む) で
/// 変わります。表示中に外観が切り替わると、出ている既定の表示の色もその場で切り替わります。外観の
/// 切り替えで画像を読み込み直すことはありません。指定した読み込み中・失敗の表示には色を当てず、
/// そのまま表示します。
///
/// メモリに表示枠と大きく違わない大きさの同じ画像があれば、デコードし直さずにそれで表示します
/// (読み込み中の表示を経由しません)。無ければ表示枠の大きさに縮小してデコードするため、表示のために
/// 元の大きさの画像をメモリへ展開しません。表示枠の大きさが決まるまでは読み込みを始めません。
///
/// 表示枠の大きさは利用者が与えてください (`.frame(...)` や `.aspectRatio(...)` など)。
/// 与えない場合は与えられた空間をすべて占めるため、他のビューと横に並べると相手が潰れます。
///
/// ```swift
/// HStack {
///     KsImage(.remote(url)).frame(width: 44, height: 44)
///     Text(title)
/// }
/// ```
@MainActor
public struct KsImage<Loading: View, Failure: View>: View {
    internal let source: KsImageSource
    internal let contentMode: KsImageContentMode

    private let loading: (() -> Loading)?
    private let failure: (() -> Failure)?

    @ObservedObject private var invalidation = KsImageInvalidation.shared
    @Environment(\.displayScale) private var displayScale
    // メモリから引き当てて描いている画像。メモリのみの消去の後に組み立て直されても描き続けるために持つ。
    @State private var retainedMatch = KsImageRetainedMatch()

    /// 読み込み中と失敗の表示を指定して画像を表示します。
    public init(
        _ source: KsImageSource,
        contentMode: KsImageContentMode = .fill,
        @ViewBuilder loading: @escaping () -> Loading,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.source = source
        self.contentMode = contentMode
        self.loading = loading
        self.failure = failure
    }

    /// 読み込み中と失敗の表示を指定して、リモート URL の画像を表示します。
    ///
    /// `key` は ``KsImageSource/remote(_:key:)`` と同じ意味です。
    public init(
        _ url: URL,
        key: String? = nil,
        contentMode: KsImageContentMode = .fill,
        @ViewBuilder loading: @escaping () -> Loading,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.init(.remote(url, key: key), contentMode: contentMode, loading: loading, failure: failure)
    }

    fileprivate init(
        source: KsImageSource,
        contentMode: KsImageContentMode,
        loading: (() -> Loading)?,
        failure: (() -> Failure)?
    ) {
        self.source = source
        self.contentMode = contentMode
        self.loading = loading
        self.failure = failure
    }

    public var body: some View {
        GeometryReader { proxy in
            content(size: proxy.size)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        switch KsImageRequestFactory.route(for: source) {
        case .asset(let name):
            // 引き当てで持っていた別のソースの画像は、このソースの表示に使わないので捨てる。
            let _ = retainedMatch.discard()
            assetContent(name: name)
        case .loader:
            loaderContent(size: size)
        }
    }

    // アセットカタログの画像はローダーを通さず SwiftUI が直接読む。同期で取れるため
    // 読み込み中の状態を経由しない。
    @ViewBuilder
    private func assetContent(name: String) -> some View {
        if let image = UIImage(named: name) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode.swiftUIContentMode)
        } else {
            failureContent
        }
    }

    @ViewBuilder
    private func loaderContent(size: CGSize) -> some View {
        // 表示の組み立てと同時に、メモリから枠にそのまま使える画像を引き当てる。引き当てられれば
        // それで表示が完了し、ローダーへ要求を出さないので読み込み中の表示も挟まらない。
        // 枠の大きさ・表示倍率・世代が変わって組み立て直されたときも引き当てからやり直すため、
        // 新しい枠に対して許容範囲の内側にある項目なら、デコードし直さずに同じ項目で表示を続ける。
        // メモリのみの消去で引き当てられなくなっても、ソース・世代・枠・表示倍率・当てはめ方が
        // 変わらない間は、引き当てて描いていた画像で表示を続ける。
        // 組み立ての時点で引き当てられず、同じ画像の先読みが取得中の可能性があるときは、要求を画面に出る
        // 時点まで始めず、画面に出る時点でもう一度引き当てを試す (`KsImageDeferredLoad`)。先読みが取得中で
        // なければ待っても引き当てられる見込みが無いので、ローダー付属のビューへそのまま任せる (このビューも
        // 要求を始めるのは画面に出る時点)。画面に出る時点の処理を増やさないためである。いったん待つ表示を
        // 選んだら、引き当ての条件が変わらない間は選び続ける。メモリのみの消去で取得中の記録が消えた後の
        // 組み立て直しで選び直すと、待つ表示で読み込んだ画像が捨てられて読み込み中へ戻るためである。
        let reloadToken = reloadToken
        if let prepared = KsImageRequestFactory.prepare(
            source: source,
            size: size,
            contentMode: contentMode,
            displayScale: displayScale
        ) {
            let condition = KsImageRetainedMatch.Condition(
                reloadToken: reloadToken,
                size: size,
                displayScale: displayScale,
                contentMode: contentMode
            )
            let shown = retainedMatch.resolve(matched: prepared.matchedImage, for: condition)
            Group {
                if let shown {
                    matchedContent(shown)
                } else if retainedMatch.usesDeferredLoad(
                    mayBeLoadingPrefetch: prepared.mayBeLoadingPrefetch,
                    for: condition
                ) {
                    KsImageDeferredLoad(
                        request: prepared.request,
                        rematch: { [source, contentMode, retainedMatch] in
                            Self.rematch(
                                source: source,
                                contentMode: contentMode,
                                condition: condition,
                                retainedMatch: retainedMatch
                            )
                        },
                        placeholder: { loadingContent },
                        matched: { matchedContent($0) },
                        loaded: { loadedContent($0) },
                        failure: { failureContent }
                    )
                } else {
                    LazyImage(request: prepared.request) { state in
                        if let image = state.image {
                            loadedContent(image)
                        } else if state.error != nil {
                            failureContent
                        } else {
                            loadingContent
                        }
                    }
                }
            }
            // 引き当ての条件 (枠の大きさ・表示倍率・当てはめ方・世代) が変わったら表示の状態ごと作り直し、
            // 新しい条件の要求からやり直す。画面に出る時点で引き当てた画像はその条件でしか使えず、作り直さないと
            // 新しい枠に対して許容範囲の外にある項目を描き続けて縮小デコードの要求を出さない。ローダー付属の
            // ビューも、縮小の指定だけが違う要求への差し替えでは読み込みをやり直さない。
            .id(condition)
            // 識別子が変わると読み込みが最初からやり直しになる。キャッシュを消したときに
            // 表示中の画像を読み込み中へ戻すのはこの経路。
            .id(reloadToken)
        } else {
            // 表示枠の大きさが決まるまでは読み込みを始めない。引き当てもしないので、持っていた画像は捨てる。
            let _ = retainedMatch.discard()
            loadingContent
        }
    }

    // 引き当てた画像の表示。
    private func matchedContent(_ image: UIImage) -> some View {
        loadedContent(Image(uiImage: image))
    }

    // 読み込んだ (または引き当てた) 画像の表示。
    private func loadedContent(_ image: Image) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: contentMode.swiftUIContentMode)
    }

    // 画面に出る時点の引き当て。組み立ての時点と同じ枠・表示倍率・当てはめ方で照会し、引き当てた画像は
    // 組み立ての時点で引き当てたときと同じく持ち続ける (メモリのみの消去の後の組み立て直しでも描き続けるため)。
    // 組み立ての外で呼ばれるため、環境の値を読まずに組み立ての時点の値だけで照会する。
    private static func rematch(
        source: KsImageSource,
        contentMode: KsImageContentMode,
        condition: KsImageRetainedMatch.Condition,
        retainedMatch: KsImageRetainedMatch
    ) -> UIImage? {
        guard let matched = KsImageRequestFactory.prepare(
            source: source,
            size: condition.size,
            contentMode: contentMode,
            displayScale: condition.displayScale
        )?.matchedImage else {
            return nil
        }
        return retainedMatch.resolve(matched: matched, for: condition)
    }

    @ViewBuilder
    private var loadingContent: some View {
        if let loading {
            loading()
        } else {
            KsImageDefaultLoadingView()
        }
    }

    @ViewBuilder
    private var failureContent: some View {
        if let failure {
            failure()
        } else {
            KsImageDefaultFailureView()
        }
    }

    // 読み込みをやり直すかの判定に使う識別子。ソース単位の削除では該当ソースの識別子だけが
    // 変わり、範囲消去ではすべての識別子が変わる。
    private var reloadToken: String {
        guard let resolved = KsImageIdentity.resolve(source) else {
            return "\(source)"
        }
        return "\(KsImageIdentity.effectiveID(forIdentifier: resolved.identifier))@\(invalidation.globalGeneration)"
    }
}

extension KsImage where Failure == EmptyView {
    /// 読み込み中の表示だけを指定して画像を表示します。失敗のときは既定の表示になります。
    public init(
        _ source: KsImageSource,
        contentMode: KsImageContentMode = .fill,
        @ViewBuilder loading: @escaping () -> Loading
    ) {
        self.init(source: source, contentMode: contentMode, loading: loading, failure: nil)
    }

    /// 読み込み中の表示だけを指定して、リモート URL の画像を表示します。
    ///
    /// `key` は ``KsImageSource/remote(_:key:)`` と同じ意味です。
    public init(
        _ url: URL,
        key: String? = nil,
        contentMode: KsImageContentMode = .fill,
        @ViewBuilder loading: @escaping () -> Loading
    ) {
        self.init(source: .remote(url, key: key), contentMode: contentMode, loading: loading, failure: nil)
    }
}

extension KsImage where Loading == EmptyView {
    /// 失敗したときの表示だけを指定して画像を表示します。読み込み中は既定の表示になります。
    public init(
        _ source: KsImageSource,
        contentMode: KsImageContentMode = .fill,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.init(source: source, contentMode: contentMode, loading: nil, failure: failure)
    }

    /// 失敗したときの表示だけを指定して、リモート URL の画像を表示します。
    ///
    /// `key` は ``KsImageSource/remote(_:key:)`` と同じ意味です。
    public init(
        _ url: URL,
        key: String? = nil,
        contentMode: KsImageContentMode = .fill,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.init(source: .remote(url, key: key), contentMode: contentMode, loading: nil, failure: failure)
    }
}

extension KsImage where Loading == EmptyView, Failure == EmptyView {
    /// 画像を表示します。読み込み中と失敗のときは既定の表示になります。
    public init(_ source: KsImageSource, contentMode: KsImageContentMode = .fill) {
        self.init(source: source, contentMode: contentMode, loading: nil, failure: nil)
    }

    /// リモート URL の画像を表示します。読み込み中と失敗のときは既定の表示になります。
    ///
    /// `key` は ``KsImageSource/remote(_:key:)`` と同じ意味です。
    public init(_ url: URL, key: String? = nil, contentMode: KsImageContentMode = .fill) {
        self.init(source: .remote(url, key: key), contentMode: contentMode, loading: nil, failure: nil)
    }
}

extension KsImageContentMode {
    // SwiftUI の当てはめ方に対応させる。
    var swiftUIContentMode: SwiftUI.ContentMode {
        switch self {
        case .fit: .fit
        case .fill: .fill
        }
    }
}

// 読み込み中の既定の表示。枠全体を無地で塗るだけで、文字や図形は置かない。
// 色はライブラリが持つライト用とダーク用の値で、置かれた場所の外観で解決される (core/ADR-0036)。
internal struct KsImageDefaultLoadingView: View {
    var body: some View {
        Color(uiColor: KsDefaultColors.imageLoading)
            // この表示自体を読み上げの単位にする。利用者が KsImage に付けた説明は状態が
            // 変わってもここへ引き継がれ、説明が無ければ読み上げる名前を持たない。
            .accessibilityElement(children: .ignore)
            // 成功の表示 (SwiftUI の Image) は画像として読み上げられるため、読み込み中も
            // 同じ性格にする。付けないと状態が変わるたびに読み上げの性格が変わる。
            .accessibilityAddTraits(.isImage)
    }
}

// 失敗の既定の表示。無地の上に画像が無いことを示す小さな印だけを置く。
// 下地と印の色はライブラリが持つライト用とダーク用の値で、置かれた場所の外観で解決される (core/ADR-0036)。
internal struct KsImageDefaultFailureView: View {
    var body: some View {
        GeometryReader { proxy in
            Color(uiColor: KsDefaultColors.imageFailureBackground)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: min(proxy.size.width, proxy.size.height) * 0.3))
                        .foregroundStyle(Color(uiColor: KsDefaultColors.imageFailureMark))
                }
        }
        // 印は画像が無いことを目で示すための飾りで、名前を読み上げても利用者の役に立たない。
        // 表示自体を読み上げの単位にして、利用者が KsImage に付けた説明だけが読まれるようにする。
        .accessibilityElement(children: .ignore)
        // 成功の表示 (SwiftUI の Image) は画像として読み上げられるため、失敗も同じ性格にする。
        // 付けないと状態が変わるたびに読み上げの性格が変わる。
        .accessibilityAddTraits(.isImage)
    }
}
