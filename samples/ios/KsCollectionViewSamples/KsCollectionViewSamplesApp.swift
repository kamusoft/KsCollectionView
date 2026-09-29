import KsCollectionView
import SwiftUI

@main
struct KsCollectionViewSamplesApp: App {
    /// 外観の選択。ルートメニューが同じキーに書き込む。
    @AppStorage(SampleAppearance.storageKey) private var appearance = SampleAppearance.initial

    init() {
        // 保存した外観を読む前に消す (UI テストが保存の無い状態から始めるため)。
        SampleAppearance.resetIfRequested()
        // 画像のディスクキャッシュは明示的に有効化したときだけ働き、表示を始めた後に
        // 呼んでも既存のコレクションには反映されない。起動時に一度だけ呼ぶ。
        KsImagePipeline.enableSharedDiskCache()
        // 観測を要求されたときだけ、共有パイプラインを観測付きに置き換える。
        ImageLoadingObservation.enableIfRequested()
        // 件数の指定が受け取れないときは、既定件数へ黙って戻さずに起動を止める。
        LargeDataCount.failIfInvalid()
        ImageGridCount.failIfInvalid()
        PagingDelay.failIfInvalid()
    }

    var body: some Scene {
        WindowGroup {
            // 起動の分岐より上で掛け、起動引数で直接開く画面にも選んだ外観を効かせる。
            SampleLaunchView()
                .sampleAppearanceWindowStyle(appearance)
        }
    }
}
