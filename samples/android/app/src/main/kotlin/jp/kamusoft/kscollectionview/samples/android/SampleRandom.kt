package jp.kamusoft.kscollectionview.samples.android

/**
 * Sample のデータ生成とシャッフルに使う、種から決まる擬似乱数。
 *
 * iOS Sample の同名の定義と同じ式・同じ種で、同じ数列を出す。標準ライブラリの乱数は
 * プラットフォームごとに式が違い、同じ種でも同じ並びにならないため、式をここで固定する。
 *
 * 式は 32 ビットの xorshift (シフト量 13 / 17 / 5)。状態は符号なし 32 ビットで、
 * 左シフトであふれたビットは捨て、右シフトは論理シフト。種に 0 を与えると 0 しか
 * 出さないため、種は 0 以外にする。
 *
 * 状態は [state] で読める。読んだ値を種にして作り直すと、同じ続きの数列を出す
 * (画面の状態の保存と復元に使う)。
 *
 * @param seed 種。0 以外
 */
class SampleRandom(seed: UInt) {
    init {
        require(seed != 0u) { "種に 0 は使えません" }
    }

    /** 今の状態。これを種にして作り直すと、ここから先の数列が同じになる。 */
    var state: UInt = seed
        private set

    /** 次の値 (符号なし 32 ビット) を返す。 */
    fun next(): UInt {
        var x = state
        x = x xor (x shl 13)
        x = x xor (x shr 17)
        x = x xor (x shl 5)
        state = x
        return x
    }

    /**
     * 0 以上 [bound] 未満の整数を返す。次の値を [bound] で割った余り。
     *
     * @param bound 上限 (含まない)。1 以上
     */
    fun next(bound: Int): Int {
        require(bound > 0) { "上限は 1 以上にします" }
        return (next() % bound.toUInt()).toInt()
    }

    /**
     * 配列をその場で混ぜる (Fisher–Yates)。
     *
     * 末尾の位置 i から 1 まで順に、`next(bound = i + 1)` で選んだ位置 j と i を入れ替える。
     */
    fun <T> shuffle(elements: MutableList<T>) {
        for (index in elements.lastIndex downTo 1) {
            val other = next(bound = index + 1)
            val kept = elements[index]
            elements[index] = elements[other]
            elements[other] = kept
        }
    }
}
