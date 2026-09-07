import KsCollectionView
import SwiftUI

@main
struct KsCollectionViewSamplesApp: App {
    init() {
        // 画像のディスクキャッシュは明示的に有効化したときだけ働き、表示を始めた後に
        // 呼んでも既存のコレクションには反映されない。起動時に一度だけ呼ぶ。
        KsImagePipeline.enableSharedDiskCache()
        // 観測を要求されたときだけ、共有パイプラインを観測付きに置き換える。
        ImageLoadingObservation.enableIfRequested()
    }

    var body: some Scene {
        WindowGroup {
            SampleLaunchView()
        }
    }
}
