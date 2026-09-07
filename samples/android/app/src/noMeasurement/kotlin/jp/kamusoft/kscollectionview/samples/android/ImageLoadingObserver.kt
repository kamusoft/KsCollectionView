package jp.kamusoft.kscollectionview.samples.android

/**
 * 画像の読み込みを観測できるようにする。この構成では何もしない。
 *
 * 観測は共有インスタンスの ImageLoader を置き換えて行うため、配布する構成には入れない。
 */
fun installImageLoadingObserver() {
    // 配布する構成に観測用の差し替えは入れない。
}

/**
 * 計測の前処理として画像キャッシュを空にする。この構成では何もしない。
 *
 * @param requested 消去が要求されたかどうか (使わない)
 */
@Suppress("UNUSED_PARAMETER")
fun resetImageCacheForMeasurement(requested: Boolean) {
    // 配布する構成に計測の前処理は入れない。
}
