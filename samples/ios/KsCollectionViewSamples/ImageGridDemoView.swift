import KsCollectionView
import SwiftUI

/// 「画像グリッド」画面。10,000 件のリモート画像を 3 列で並べ、プリフェッチの
/// 形 (到達点と表示幅) を切り替えながらスクロールの見え方を比べる。
///
/// 件数・列数・間隔・文言・初期選択は Android Sample の同名画面とそろえる。
struct ImageGridDemoView: View {
    /// 初期選択は「ディスクまで」。起動引数 `--prefetch` があればそれに従う (計測用)。
    @State private var choice = ImagePrefetchChoice.resolved

    var body: some View {
        VStack(spacing: 0) {
            // 数えることを要求した実行でだけ現れる印。要求しない既定のデモでは何も出ない。
            ImageLoadingSlotMark()
            collection
            Divider()
                .overlay(SampleTheme.separator)
            controlBar
        }
    }

    /// 土俵は ``ImageGridFixture`` から取る。計測用の画面と同じ宣言元にすることで、
    /// 計測がこの画面と違う土俵を測ってしまうのを型の上で防ぐ。
    /// 「なし」の選択ではプリフェッチを宣言せず、プリフェッチが無い状態を見せる。
    private var collection: KsCollectionView<DemoItem> {
        ImageGridFixture.collection(prefetch: choice)
    }

    private var controlBar: some View {
        VStack(spacing: SampleTheme.controlVerticalPadding) {
            // 選択肢の文言が長く横に並べると切れるため、いまの選択を 1 行で出すメニューにする
            // (Android Sample と同じ形)。
            Picker("プリフェッチ", selection: $choice) {
                ForEach(ImagePrefetchChoice.allCases) { choice in
                    Text(choice.rawValue).tag(choice)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(SampleTheme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                // 件数と列数を含む説明。Android Sample の同じ行と一字一句そろえる。
                Text("プリフェッチ · 10,000 件 · 3 列")
                    .font(.footnote)
                    .foregroundStyle(SampleTheme.secondaryText)
                Spacer()
                Button("キャッシュを消去") {
                    KsImageCache.clear(.all)
                }
                .foregroundStyle(SampleTheme.accent)
            }
        }
        .padding(.horizontal, SampleTheme.horizontalPadding)
        .padding(.vertical, SampleTheme.controlVerticalPadding)
        .background(SampleTheme.cell)
    }
}
