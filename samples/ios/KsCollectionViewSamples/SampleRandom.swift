/// Sample のデータ生成とシャッフルに使う、種から決まる擬似乱数です。
///
/// Android Sample の同名の定義と同じ式・同じ種で、同じ数列を出します。標準ライブラリの乱数は
/// プラットフォームごとに式が違い、同じ種でも同じ並びにならないため、式をここで固定します。
///
/// 式は 32 ビットの xorshift (シフト量 13 / 17 / 5) です。状態は符号なし 32 ビットで、
/// 左シフトであふれたビットは捨て、右シフトは論理シフトです。種に 0 を与えると 0 しか
/// 出さないため、種は 0 以外にします。
struct SampleRandom {
    private var state: UInt32

    /// - Parameter seed: 種。0 以外
    init(seed: UInt32) {
        precondition(seed != 0, "種に 0 は使えません")
        state = seed
    }

    /// 次の値 (符号なし 32 ビット) を返します。
    mutating func next() -> UInt32 {
        state ^= state << 13
        state ^= state >> 17
        state ^= state << 5
        return state
    }

    /// 0 以上 `bound` 未満の整数を返します。次の値を `bound` で割った余りです。
    ///
    /// - Parameter bound: 上限 (含まない)。1 以上
    mutating func next(below bound: Int) -> Int {
        precondition(bound > 0, "上限は 1 以上にします")
        return Int(next() % UInt32(bound))
    }

    /// 配列をその場で混ぜます (Fisher–Yates)。
    ///
    /// 末尾の位置 i から 1 まで順に、`next(below: i + 1)` で選んだ位置 j と i を入れ替えます。
    mutating func shuffle<Element>(_ elements: inout [Element]) {
        guard elements.count > 1 else { return }
        for index in stride(from: elements.count - 1, to: 0, by: -1) {
            elements.swapAt(index, next(below: index + 1))
        }
    }
}
