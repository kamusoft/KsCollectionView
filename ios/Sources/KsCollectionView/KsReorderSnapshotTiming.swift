// 並べ替えで UIKit が並びを動かした後に、一覧が snapshot を当てる時点。
internal enum KsReorderSnapshotTiming {
    // その場で当てる (読み上げの移動操作のように、UIKit が並びを動かしていないとき)。
    case immediate
    // 次の周回で当てる。差分データソースの並べ替えの確定の中では snapshot を当てられない。
    case nextRunLoop
    // ドロップのセッションが終わってから当てる。UIKit が置いた項目の絵を消す前に並びを動かすと、項目が置いた
    // 位置に止まったまま別の位置に現れるため、見せている並びと違う並びにするときはこの時点まで待つ。
    case afterDropSession
}
