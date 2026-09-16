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
        // 件数の指定が受け取れないときは、既定件数へ黙って戻さずに起動を止める。
        LargeDataCount.failIfInvalid()
    }

    var body: some Scene {
        WindowGroup {
            SampleLaunchView()
        }
    }
}
