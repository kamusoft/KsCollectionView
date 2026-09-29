package jp.kamusoft.kscollectionview.samples.android

/**
 * 「ページング」画面の偽の取得元が 1 回の取得に置く遅延です。
 *
 * 既定は 1 秒で、起動の追加情報 [SampleRoutes.PagingDelayExtra] を付けたときだけその長さにします。
 * 遅延を変えるのは、テストと性能の体感で読み込みの待ち時間を縮めるため (0 で遅延なし) と、
 * 読み込み中の様子を長く見せるためです。iOS Sample の同名の定義と同じ規則にします。
 */
object PagingDelay {
    /** 指定が無いときの遅延 (ミリ秒)。 */
    const val DefaultMilliseconds: Int = 1_000

    /** 起動の追加情報の読み取り結果。 */
    sealed interface Resolution {
        /** 指定が無い。 */
        data object Unspecified : Resolution

        /** 0 以上の整数が指定された。 */
        data class Specified(val milliseconds: Int) : Resolution

        /** 指定はあるが受け取れない。 */
        data class Invalid(val reason: String) : Resolution
    }

    /**
     * 起動の追加情報の値から遅延を読み取ります。
     *
     * 受け取るのは 0 以上の整数 (整数の追加情報、または整数として読める文字列) だけです。負数・数値でない
     * 値は、既定の遅延へ戻さずに受け取れないものとして返します。黙って既定へ戻すと、縮めたつもりの
     * 待ち時間で測った結果が実際には既定の遅延のまま残るためです。
     *
     * @param value 追加情報の値。指定が無ければ null
     */
    fun resolve(value: Any?): Resolution {
        val milliseconds = when (value) {
            null -> return Resolution.Unspecified
            is Int -> value
            is Long -> value.takeIf { it in 0..Int.MAX_VALUE }?.toInt()
            is String -> value.trim().toIntOrNull()
            else -> null
        }
        if (milliseconds == null || milliseconds < 0) {
            return Resolution.Invalid(
                "${SampleRoutes.PagingDelayExtra} に 0 以上の整数以外が指定されました: $value",
            )
        }
        return Resolution.Specified(milliseconds)
    }

    /**
     * 読み取り結果から、この起動で使う遅延 (ミリ秒) を返します。受け取れない指定なら起動を止めます。
     *
     * @param resolution [resolve] の結果
     */
    fun millisecondsOrFail(resolution: Resolution): Int = when (resolution) {
        Resolution.Unspecified -> DefaultMilliseconds
        is Resolution.Specified -> resolution.milliseconds
        is Resolution.Invalid -> throw IllegalArgumentException(resolution.reason)
    }
}
