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
/// ```
///
/// 読み込み中と失敗の表示は片方だけを指定でき、指定しなかった側は既定の表示になります。
///
/// 画像は表示枠の大きさに縮小してデコードするため、元の大きさの画像をメモリに置きません。
/// 表示枠の大きさが決まるまでは読み込みを始めません。
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
    public init(
        _ url: URL,
        contentMode: KsImageContentMode = .fill,
        @ViewBuilder loading: @escaping () -> Loading,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.init(.remote(url), contentMode: contentMode, loading: loading, failure: failure)
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
        // 表示の組み立てと同時に、初回の描画に使える画像を同期で用意する。ここで用意しないと
        // ローダーの状態が決まるまでの間に読み込み中の表示が挟まる。副作用として共有ローダーの
        // メモリキャッシュへ書くことがあるが、同じ入力には同じ結果を書くため、枠の大きさ・
        // 表示倍率・世代が変わって組み立て直されても増えない。
        if let prepared = KsImageRequestFactory.prepare(
            source: source,
            size: size,
            contentMode: contentMode,
            displayScale: displayScale
        ) {
            LazyImage(request: prepared.request) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode.swiftUIContentMode)
                } else if state.error != nil {
                    failureContent
                } else if let cached = prepared.cachedImage {
                    // ローダーの状態が決まるのは表示が組み上がった後なので、メモリにある
                    // 画像はその間だけ自分で描く。読み込み中の表示を挟まないための経路。
                    Image(uiImage: cached)
                        .resizable()
                        .aspectRatio(contentMode: contentMode.swiftUIContentMode)
                } else {
                    loadingContent
                }
            }
            // 識別子が変わると読み込みが最初からやり直しになる。キャッシュを消したときに
            // 表示中の画像を読み込み中へ戻すのはこの経路。
            .id(reloadToken)
        } else {
            // 表示枠の大きさが決まるまでは読み込みを始めない。
            loadingContent
        }
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
        guard case .loader(let url) = KsImageRequestFactory.route(for: source) else {
            return "\(source)"
        }
        let key = url.absoluteString
        return "\(KsImageIdentity.imageID(forKey: key) ?? key)@\(invalidation.globalGeneration)"
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
    public init(
        _ url: URL,
        contentMode: KsImageContentMode = .fill,
        @ViewBuilder loading: @escaping () -> Loading
    ) {
        self.init(source: .remote(url), contentMode: contentMode, loading: loading, failure: nil)
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
    public init(
        _ url: URL,
        contentMode: KsImageContentMode = .fill,
        @ViewBuilder failure: @escaping () -> Failure
    ) {
        self.init(source: .remote(url), contentMode: contentMode, loading: nil, failure: failure)
    }
}

extension KsImage where Loading == EmptyView, Failure == EmptyView {
    /// 画像を表示します。読み込み中と失敗のときは既定の表示になります。
    public init(_ source: KsImageSource, contentMode: KsImageContentMode = .fill) {
        self.init(source: source, contentMode: contentMode, loading: nil, failure: nil)
    }

    /// リモート URL の画像を表示します。読み込み中と失敗のときは既定の表示になります。
    public init(_ url: URL, contentMode: KsImageContentMode = .fill) {
        self.init(source: .remote(url), contentMode: contentMode, loading: nil, failure: nil)
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
internal struct KsImageDefaultLoadingView: View {
    var body: some View {
        Color(uiColor: .systemGray5)
            // この表示自体を読み上げの単位にする。利用者が KsImage に付けた説明は状態が
            // 変わってもここへ引き継がれ、説明が無ければ読み上げる名前を持たない。
            .accessibilityElement(children: .ignore)
            // 成功の表示 (SwiftUI の Image) は画像として読み上げられるため、読み込み中も
            // 同じ性格にする。付けないと状態が変わるたびに読み上げの性格が変わる。
            .accessibilityAddTraits(.isImage)
    }
}

// 失敗の既定の表示。無地の上に画像が無いことを示す小さな印だけを置く。
internal struct KsImageDefaultFailureView: View {
    var body: some View {
        GeometryReader { proxy in
            Color(uiColor: .systemGray4)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: min(proxy.size.width, proxy.size.height) * 0.3))
                        .foregroundStyle(Color(uiColor: .systemGray))
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
