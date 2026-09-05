package jp.kamusoft.kscollectionview

/** コントローラからコレクションへ送られる 1 件のスクロール命令。 */
internal sealed interface KsScrollCommand {

    /** アニメーションさせるかどうか。 */
    val animated: Boolean

    /** 安定 ID で指した要素へのスクロール。 */
    data class ToItem(
        val id: Any,
        val position: KsScrollPosition,
        override val animated: Boolean,
    ) : KsScrollCommand

    /** コンテンツ先頭へのスクロール。ヘッダーがあればヘッダーの先頭。 */
    data class ToStart(override val animated: Boolean) : KsScrollCommand

    /** コンテンツ末尾へのスクロール。フッターがあればフッターの末尾。 */
    data class ToEnd(override val animated: Boolean) : KsScrollCommand
}
