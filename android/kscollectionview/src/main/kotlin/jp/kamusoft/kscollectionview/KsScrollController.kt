package jp.kamusoft.kscollectionview

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember

/** ID 指定スクロールで項目を置く位置です。 */
public enum class KsScrollPosition {
    /** 表示範囲の先頭に合わせます。 */
    Start,

    /** 表示範囲の中央に合わせます。 */
    Center,

    /** 表示範囲の末尾に合わせます。 */
    End,
}

/**
 * `KsCollectionView` を外からスクロールさせるコントローラです。
 *
 * `scrollController` 引数で接続したコンポーネントに対して命令を送ります。命令はメインスレッドから
 * 呼び、どのコンポーネントにも接続していない間は何も起きません。
 *
 * 命令は呼んだ順に処理され、後の命令は先行する命令のアニメーションを中断して優先します。配列を
 * 差し替えた直後に命令を出した場合も、差し替え後の配列で解決されます。
 */
public class KsScrollController {

    /** 接続中の受け口。複数接続時は最後の接続だけが残る。 */
    private var receiver: KsScrollCommandReceiver? = null

    /** 処理済みの命令の件数。テストが命令の処理完了を待つために読む。 */
    internal val processedCommandCount: Int get() = receiver?.processedCommandCount ?: 0

    /**
     * 指定した ID の要素までスクロールします。
     *
     * 配列に存在しない ID を指定した場合は何も起きません。
     *
     * @param id スクロール先の要素の安定 ID
     * @param position 要素を置く位置
     * @param animated アニメーションさせるかどうか
     */
    public fun scrollTo(
        id: Any,
        position: KsScrollPosition = KsScrollPosition.Start,
        animated: Boolean = true,
    ) {
        send(KsScrollCommand.ToItem(id = id, position = position, animated = animated))
    }

    /**
     * 先頭までスクロールします。
     *
     * @param animated アニメーションさせるかどうか
     */
    public fun scrollToStart(animated: Boolean = true) {
        send(KsScrollCommand.ToStart(animated = animated))
    }

    /**
     * 末尾までスクロールします。
     *
     * @param animated アニメーションさせるかどうか
     */
    public fun scrollToEnd(animated: Boolean = true) {
        send(KsScrollCommand.ToEnd(animated = animated))
    }

    /** 未接続・接続解除後は何もしない (警告も出さない)。 */
    private fun send(command: KsScrollCommand) {
        receiver?.enqueue(command)
    }

    internal fun attach(receiver: KsScrollCommandReceiver) {
        val current = this.receiver
        if (current != null && current !== receiver && KsDiagnostics.isDebugBuild(receiver.context)) {
            KsDiagnostics.warn(
                "1 つの KsScrollController が複数のコレクションへ接続されました。最後の接続を使います",
            )
        }
        this.receiver = receiver
    }

    internal fun detach(receiver: KsScrollCommandReceiver) {
        if (this.receiver !== receiver) return
        this.receiver = null
    }
}

/**
 * コンポジションの生存期間だけ保持される [KsScrollController] を返します。
 *
 * 画面が所有する場合はこの関数を、ViewModel などが所有する場合は [KsScrollController] を
 * 直接生成して使います。
 */
@Composable
public fun rememberKsScrollController(): KsScrollController = remember { KsScrollController() }
