import UIKit

// 表示中の `KsImage` がメモリから引き当てて描いている画像を、表示の条件が変わらない間だけ持ち続ける箱。
//
// 引き当ての手掛かり (`KsImageMemoryIndex`) とローダーのメモリキャッシュはメモリのみの消去で空になる。
// 箱が無いと、消去の後に親の状態変化などで `KsImage` が組み立て直されたとき、引き当てに失敗して
// 読み込み中の表示へ戻ってしまう。メモリのみの消去は表示中の画像を置き換えないので、ここで描いている
// 画像を持ち続ける。
//
// 持ち続けるのは、同じソースを表示し続けている間で、かつソースの識別子と削除の世代・範囲消去の世代・
// 枠の大きさ・表示倍率・当てはめ方がすべて同じ間に限る。ソース単位の削除や全消去で世代が進むと条件が
// 変わるため、持っていた画像は使われず、表示は読み込み中へ戻って取得をやり直す。ローダーを通さない
// ソース (アセット) へ切り替わったときや、枠の大きさが決まらず引き当てをしない間は `discard()` で
// 捨てる。捨てないと、その間にメモリのみの消去を挟んで元のソースへ戻したとき、消去前の画像を使って
// しまい、ディスクから再デコードされない。
//
// 同じ理由で、画面に出る時点まで要求を待つ表示 (`KsImageDeferredLoad`) を選んだことも条件ごとに覚える。
// 待つかどうかの判定の材料 (取得中の先読みの記録) もメモリのみの消去で消えるため、覚えずに組み立てのたびに
// 選び直すと、待つ表示で読み込んで描いている画像が、ローダー付属の表示への切り替えで捨てられて読み込み中へ
// 戻り、ディスクから再デコードされる。条件が変われば選び直す。
//
// 組み立ての最中に書き換えるが、描画の更新を起こす値ではないので観測対象にしない。表示の組み立てと
// 同じ主スレッドだけで読み書きする。
@MainActor
internal final class KsImageRetainedMatch {
    // 持っている画像を使ってよい表示の条件。画面に出る時点の引き当てをやり直すかの判定にも、この値を
    // 表示の識別子として使う。
    struct Condition: Hashable {
        // ソースの識別子・削除の世代・範囲消去の世代をまとめた値。
        let reloadToken: String
        let size: CGSize
        let displayScale: CGFloat
        let contentMode: KsImageContentMode
    }

    private var condition: Condition?
    private var retainedImage: UIImage?
    // 画面に出る時点まで要求を待つ表示を選んだ条件。
    private var deferredLoadCondition: Condition?

    // 今回の組み立てで描く画像を決める。引き当てた画像があればそれを持ち直して返し、無ければ同じ条件で
    // 持っている画像を返す。条件が変わっていれば持っていた画像を捨てて nil を返す。
    func resolve(matched: UIImage?, for condition: Condition) -> UIImage? {
        if let matched {
            self.condition = condition
            retainedImage = matched
            return matched
        }
        guard self.condition == condition, let retainedImage else {
            self.condition = nil
            self.retainedImage = nil
            return nil
        }
        return retainedImage
    }

    // 画面に出る時点まで要求を待つ表示を使うかを決める。先読みが取得中の可能性があれば待つ表示を選んで
    // その条件を覚え、無くても同じ条件でいったん選んでいれば選び続ける。
    func usesDeferredLoad(mayBeLoadingPrefetch: Bool, for condition: Condition) -> Bool {
        if mayBeLoadingPrefetch {
            deferredLoadCondition = condition
            return true
        }
        guard deferredLoadCondition == condition else {
            deferredLoadCondition = nil
            return false
        }
        return true
    }

    // 持っている画像と選んだ表示を捨てる。引き当ての経路を通らない表示へ移ったときに呼ぶ。
    func discard() {
        condition = nil
        retainedImage = nil
        deferredLoadCondition = nil
    }
}
