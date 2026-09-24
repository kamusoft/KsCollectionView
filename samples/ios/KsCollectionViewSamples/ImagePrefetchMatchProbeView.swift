import Darwin
import SwiftUI

/// 先読みした画像を、表示が読み込み中を経ずにそのまま使うかを観測する計測用の画面です。
/// 起動引数 `--verify-image-prefetch-match-auto` で開き、走査・集計・終了まで自身で行います。
///
/// 土俵は「画像グリッド」と同じ宣言元 (``ImageGridFixture``) から取り、プリフェッチの形は起動引数
/// `--prefetch` で選びます。読み込みの節目は観測 (`--observe-image-loading`) の割り込み処理から、
/// 読み込み中の表示は計数 (`--count-image-loading-slots`) から取るため、両方の引数を併せて渡します。
///
/// 手順は 3 段です。
/// 1. 送り: 初回表示が落ち着いたら基準点を切り、可視範囲の高さの半分ずつ先へ送る
/// 2. 戻し: 基準点を切り直し、同じ刻みで先頭側へ戻す
/// 3. メモリのみの消去: 基準点を切り直し、メモリのみを消してから 1 段送って戻す
///
/// 段ごとの待ち方は起動引数 `--probe-pace` で選びます。`settle` (既定) は、メモリまでの先読みなら
/// 取得中の先読みが無くなるまで、ディスクまでの先読みなら 3 秒待ちます。数値を渡すとその
/// ミリ秒だけ待ちます (取得が追いつかない速さの送りを作るときに使います)。
///
/// 結果は `KS_PROBE` を先頭に付けた行として標準出力へ出します。判定は持たず (観測のための
/// 駆動)、合否は証跡の側で読みます。
struct ImagePrefetchMatchProbeView: View {
    private let prefetch = ImagePrefetchChoice.resolved

    var body: some View {
        ImageGridFixture.collection(prefetch: prefetch)
            .task {
                let probe = ImagePrefetchMatchProbe(prefetch: prefetch)
                await probe.run()
                exit(EXIT_SUCCESS)
            }
    }
}
