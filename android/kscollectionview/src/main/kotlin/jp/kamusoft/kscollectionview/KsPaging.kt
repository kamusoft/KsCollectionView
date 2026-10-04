package jp.kamusoft.kscollectionview

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * 一覧に付けるページング (無限スクロール) の設定です。
 *
 * `KsCollectionView` の `paging` 引数に渡します。一覧は、画面に出ているいちばん後ろの項目より後に
 * 残っている項目の数が「[threshold] × 画面に出ている項目の数 (端数は切り上げ)」以下になったときに、
 * [onLoadMore] を呼んで次のページを頼みます。項目が 1 件も無いときは、しきい値によらず最初のページを
 * 頼みます。数えるのは項目だけで、グループの見出しやヘッダー / フッターは数えません。
 *
 * 頼むのは [state] が [KsPagingState.Idle] のときだけです。一度頼んだら、[onLoadMore] が終わり、かつ
 * [state] か配列の中身が変わるまで、次を頼みません。[state] は一覧が書き換えることはないため、読み込みの
 * 進み具合に合わせて呼び出し側で書き換えてください。[onLoadMore] から戻る前に [state] を
 * [KsPagingState.Appending] にしておくと、その間の Pull to Refresh も受け付けません。
 *
 * ```
 * KsCollectionView(
 *     items = viewModel.items,
 *     key = { it.id },
 *     paging = KsPaging(
 *         state = viewModel.pagingState,
 *         onLoadMore = { viewModel.loadNextPage() },
 *     ),
 *     onRefresh = { viewModel.reload() },
 * ) { template { item -> Row(item) } }
 * ```
 *
 * [onLoadMore] は一覧の表示の中で実行され、一覧がコンポジションから取り除かれると取り消されます。
 * 画面を閉じても続けたい読み込みは、呼び出し側の ViewModel のスコープで始めてください。
 *
 * 状態が [KsPagingState.Appending] の間は、項目があれば一覧の見えている範囲の下端に、項目が 1 件も
 * 無ければ一覧の真ん中に、標準の読み込み中の表示が出ます。見えている範囲の下端の表示はスクロールしても
 * 動かず、項目はその裏を流れます。失敗・終端の表示は最後の項目の後ろに、空の表示は一覧の真ん中に出ますが、
 * 既定では何も出ません。6 つの表示はそれぞれの引数で差し替えられます。読み込み中の既定を消したいときは、
 * 何も描かない Composable を渡してください。標準の読み込み中の表示の色は、`KsCollectionView` の
 * `loadingIndicatorColor` で指定できます (省略するとテーマの primary)。差し替えた表示には効きません。
 *
 * ページングを付けた一覧では、状態が [KsPagingState.Refreshing] の間に配列を差し替えると、差し替えと
 * 同時にコンテンツの先頭を表示します。また、状態が [KsPagingState.EndReached] になるまでは、末尾を
 * 表示しているときに末尾へ項目を足しても、表示範囲は末尾へ動きません。
 *
 * Pull to Refresh (`KsCollectionView` の `onRefresh`) で始めた取り直しでは、取り直しの処理が呼ばれてから
 * インジケータが消えるまでの間に届いた差し替えは、取得の速さによらず先頭から表示します。呼び出し側が
 * 自分で始める取り直し (引っ張らない再読み込み) では、先頭を表示するかは差し替えの直前に一覧へ渡した
 * 状態で決まります。取得がすぐ終わり、[KsPagingState.Refreshing] への書き換えと配列の差し替えが 1 回の
 * 描画にまとまると、一覧は取り直し中を受け取らないため先頭へ送りません。先頭から表示したいときは、
 * [KsPagingState.Refreshing] が一覧に届いてから (その状態で一度描画されてから) 配列を差し替えるか、
 * 差し替えと一緒に [KsScrollController.scrollToStart] で先頭へのスクロールを命じてください。
 *
 * @property state ページングの状態
 * @property onLoadMore 次のページを読み込む処理
 * @property threshold 何画面分手前で次のページを頼むかを表す画面数。0 は最後の項目が画面に入ったときに
 *   頼みます。負の数と有限でない数は誤りで、デバッグビルドでは停止して知らせ、リリースビルドでは
 *   警告を記録して 0 として扱います
 * @property appendingIndicator 項目があり、状態が [KsPagingState.Appending] のときに、一覧の見えている
 *   範囲の下端 (下端のシステムバーに重なっていればその分だけ上) の中央に重ねて出す表示。下の余白
 *   (`contentPadding`) では位置は変わりません。スクロールしても動きません。省略すると、標準の読み込み中の
 *   表示が下地なしで出て、タッチは受けずに下の項目へ通します。標準の表示の色は `KsCollectionView` の
 *   `loadingIndicatorColor` で指定できます。差し替えた表示はそのまま置き (色の指定は効きません)、押せる部品を
 *   持たなくても表示の範囲のタップを受け止めて下の項目へ通しません。表示の範囲から始めたドラッグは
 *   一覧のスクロールになります。表示の範囲の外のタッチは下へ通します
 * @property failedFooter 項目があり、状態が [KsPagingState.Failed] のときに最後の項目の後ろへ出す表示。
 *   次のページを頼み直す再試行の操作を受け取ります。省略すると何も出ません
 * @property endReachedFooter 項目があり、状態が [KsPagingState.EndReached] のときに最後の項目の後ろへ
 *   出す表示。省略すると何も出ません
 * @property loadingPlaceholder 項目が 1 件も無く、状態が [KsPagingState.Appending] か
 *   [KsPagingState.Refreshing] のときに一覧の真ん中へ出す表示。省略すると標準の読み込み中の表示が出ます。
 *   標準の表示の色は `KsCollectionView` の `loadingIndicatorColor` で指定できます。差し替えた表示には
 *   色の指定は効きません
 * @property failedPlaceholder 項目が 1 件も無く、状態が [KsPagingState.Failed] のときに一覧の真ん中へ
 *   出す表示。再試行の操作を受け取ります。Pull to Refresh を付けていても、再試行で呼ばれるのは
 *   [onLoadMore] です。省略すると何も出ません
 * @property emptyPlaceholder 項目が 1 件も無く、状態が [KsPagingState.EndReached] のときに一覧の
 *   真ん中へ出す表示。省略すると何も出ません
 */
public class KsPaging(
    public val state: KsPagingState,
    public val onLoadMore: suspend () -> Unit,
    public val threshold: Float = 1f,
    public val appendingIndicator: (@Composable () -> Unit)? = null,
    public val failedFooter: (@Composable (retry: () -> Unit) -> Unit)? = null,
    public val endReachedFooter: (@Composable () -> Unit)? = null,
    public val loadingPlaceholder: (@Composable () -> Unit)? = null,
    public val failedPlaceholder: (@Composable (retry: () -> Unit) -> Unit)? = null,
    public val emptyPlaceholder: (@Composable () -> Unit)? = null,
) {
    /**
     * 表示 [display] の中身。差し替えていない読み込み中は標準の読み込み中の表示、差し替えていない
     * 失敗・終端・空は null (何も出さない)。
     *
     * [loadingIndicatorColor] は標準の読み込み中の表示にだけ渡す。差し替えた表示は利用者が色を決めるため、
     * 色を渡さずそのまま返す (core/ADR-0035)。
     */
    internal fun content(
        display: KsPagingDisplay,
        retry: () -> Unit,
        loadingIndicatorColor: Color?,
    ): (@Composable () -> Unit)? =
        when (display) {
            KsPagingDisplay.AppendingIndicator ->
                appendingIndicator ?: { KsPagingAppendingIndicatorDefault(loadingIndicatorColor) }
            KsPagingDisplay.FailedFooter -> failedFooter?.let { content -> { content(retry) } }
            KsPagingDisplay.EndReachedFooter -> endReachedFooter
            KsPagingDisplay.LoadingPlaceholder ->
                loadingPlaceholder ?: { KsPagingDefaultProgress(loadingIndicatorColor) }
            KsPagingDisplay.FailedPlaceholder -> failedPlaceholder?.let { content -> { content(retry) } }
            KsPagingDisplay.EmptyPlaceholder -> emptyPlaceholder
        }

    /** しきい値の誤りを知らせる文言。正しい値なら null。 */
    internal fun invalidThresholdMessage(): String? =
        if (KsPagingRequester.isValidThreshold(threshold)) {
            null
        } else {
            "ページングのしきい値に $threshold が指定されました。しきい値は 0 以上の有限の数で指定してください。" +
                "0 として扱います"
        }
}
