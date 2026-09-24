package jp.kamusoft.kscollectionview.samples.android.benchmark

/**
 * 計測対象アプリの座標と、計測用の入口の経路。
 *
 * 計測モジュールは対象アプリのコードを参照できないため、経路の文字列はここに写して持つ。
 * 対象アプリ側の組み立て規則を変えるときは、ここもあわせて直す。
 */
object MeasurementTarget {
    /** 計測対象アプリのアプリケーション ID。 */
    const val PackageName = "jp.kamusoft.kscollectionview.samples.android"

    /** 計測対象アプリの入口。 */
    const val ActivityName = "$PackageName.MainActivity"

    /** 起動時に開く経路を渡す追加情報のキー。 */
    const val StartRouteExtra = "ks_start_route"

    /**
     * 起動時に画像キャッシュを空にすることを求める追加情報のキー。
     *
     * 対象アプリ側のキー (`SampleRoutes.ResetImageCacheExtra`) をここに写して持つ。
     */
    const val ResetImageCacheExtra = "ks_reset_image_cache"

    /** 走査の進捗を読むための印。 */
    const val StatusDescription = "measurement-status"

    /**
     * 目的の画面が載ったことを読むための印。
     *
     * 計測は `setupBlock` でこの印の出現を待ってから始める。対象アプリ側の組み立て規則
     * (`MeasurementRoutes.screenDescription`) と同じ形をここに写して持つ。
     */
    fun screenDescription(route: String): String = "measurement-screen:$route"

    /** ライブラリで描く土俵。 */
    fun ksLargeData(count: Int): String = "measurement/ks/$count"

    /** 素の LazyVerticalGrid で描く比較対象。 */
    fun baselineLargeData(count: Int): String = "measurement/baseline/$count"

    /** ライブラリで描く 1 列の土俵。 */
    fun ksLargeList(count: Int): String = "measurement/ks-list/$count"

    /** 素の LazyColumn で描く 1 列の比較対象。 */
    fun baselineLargeList(count: Int): String = "measurement/baseline-list/$count"

    /** メモリの定常判定のための自動往復。 */
    fun memoryRoundTrip(count: Int, maxRoundTrips: Int): String =
        "measurement/memory/$count/$maxRoundTrips"

    /** ライブラリで描く画像グリッドの土俵。プリフェッチの形は "none" / "disk" / "memory" / "memory-column"。 */
    fun imageGrid(count: Int, destination: String): String =
        "measurement/image/$count/$destination"

    /** 画像グリッドのメモリの定常判定のための自動往復。 */
    fun imageMemoryRoundTrip(count: Int, maxRoundTrips: Int, destination: String): String =
        "measurement/image-memory/$count/$maxRoundTrips/$destination"
}
