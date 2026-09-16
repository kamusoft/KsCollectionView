#if DEBUG
@_spi(KsMeasurement) import KsCollectionView
#endif
import SwiftUI

/// 件数を指定して「大量件数」画面を開いたときだけ出る、計測のための帯です。
///
/// 出しているのは、いま測っている件数と、自己サイズと推定高さの一致の計数です。計数は
/// デバッグ構成でだけ読めます (製品構成には計測のための仕組みを載せないため)。
///
/// 計数の表示はスクロール中には動かしません。周期的に読み直すと、その再描画が計測している
/// 画面そのものに載るためです。読み直しと数え直しは、スクロールを止めてから帯の操作で行います。
struct LargeDataMeasurementBar: View {
    #if DEBUG
    @State private var tally = ""
    #endif

    var body: some View {
        HStack(spacing: 12) {
            Text(verbatim: "件数: \(LargeDataCount.value)")
                .accessibilityIdentifier("largeData.itemCount")
            Spacer()
            #if DEBUG
            Text(verbatim: tally)
                .accessibilityIdentifier("largeData.selfSizingTally")
            Button("読む") {
                tally = Self.currentTally()
            }
            .accessibilityIdentifier("largeData.readTally")
            Button("数え直す") {
                KsLayoutDiagnostics.reset()
                tally = Self.currentTally()
            }
            .accessibilityIdentifier("largeData.resetTally")
            #endif
        }
        .font(.footnote)
        .foregroundStyle(SampleTheme.secondaryText)
        .padding(.horizontal, SampleTheme.horizontalPadding)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SampleTheme.cell)
        #if DEBUG
        .onAppear {
            tally = Self.currentTally()
        }
        #endif
    }

    #if DEBUG
    /// 自己サイズを返したセル数・推定と違った回数・その割合。
    private static func currentTally() -> String {
        let rate = String(format: "%.3f", KsLayoutDiagnostics.estimateMismatchRate)
        return "自己サイズ: \(KsLayoutDiagnostics.selfSizedCellCount)"
            + " / 不一致: \(KsLayoutDiagnostics.estimateMismatchCount) (\(rate))"
    }
    #endif
}
