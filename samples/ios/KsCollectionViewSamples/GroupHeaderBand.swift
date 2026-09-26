import SwiftUI

/// グループの見出しの帯。グループ名を左、件数を右に置く。
///
/// 背景は画面の背景と同じ色で、上端に固定されている間もこの帯のまま表示される。
struct GroupHeaderBand: View {
    let name: String
    let itemCount: Int

    var body: some View {
        HStack {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SampleTheme.text)
            Spacer()
            Text(verbatim: "\(Self.formatted(itemCount)) 件")
                .font(.footnote)
                .foregroundStyle(SampleTheme.secondaryText)
        }
        .padding(.horizontal, SampleTheme.horizontalPadding)
        .frame(maxWidth: .infinity, minHeight: GroupHeaderMetrics.height)
        .background(SampleTheme.background)
        .accessibilityElement(children: .combine)
    }

    /// 件数を 3 桁区切りで書く。端末の言語設定によらず「1,200」の形にする (Android Sample と同じ文言)。
    private static func formatted(_ count: Int) -> String {
        count.formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US")))
    }
}
