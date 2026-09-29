package jp.kamusoft.kscollectionview

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * ページングを付けた一覧が出す 6 つの表示。状態と項目が 0 件かどうかで高々 1 つに決まる (core/ADR-0024)。
 *
 * 項目があるときの次のページの読み込み中 (`AppendingIndicator`) は一覧の見えている範囲の下端に止めて
 * 重ね、失敗と終端 (`*Footer`) は最後の項目の後ろ・ルートのフッターの前に、0 件のときの 3 つ
 * (`*Placeholder`) は一覧の見えている範囲の真ん中に出す。
 */
internal enum class KsPagingDisplay {
    /** 次のページの読み込み中。見えている範囲の下端に止めて重ねる。 */
    AppendingIndicator,

    /** 次のページの失敗。 */
    FailedFooter,

    /** 終端。 */
    EndReachedFooter,

    /** 最初の読み込み中 (0 件)。 */
    LoadingPlaceholder,

    /** 失敗 (0 件)。 */
    FailedPlaceholder,

    /** 空 (0 件で終端)。 */
    EmptyPlaceholder,
    ;

    /** 最後の項目の後ろ (フッターの枠の中) に出す表示かどうか。 */
    val isFooter: Boolean
        get() = this == FailedFooter || this == EndReachedFooter

    internal companion object {
        /**
         * 状態と件数から、出す表示を決める。待機中、および項目があるときの取り直し中は何も出さない。
         * 項目があるときの取り直し中に出さないのは、利用者が自分で始めた取り直しの間は並んでいる項目に
         * 何も重ねないため (core/ADR-0024)。
         */
        fun resolve(state: KsPagingState, isEmpty: Boolean): KsPagingDisplay? = when (state) {
            KsPagingState.Appending -> if (isEmpty) LoadingPlaceholder else AppendingIndicator
            KsPagingState.Refreshing -> if (isEmpty) LoadingPlaceholder else null
            KsPagingState.Failed -> if (isEmpty) FailedPlaceholder else FailedFooter
            KsPagingState.EndReached -> if (isEmpty) EmptyPlaceholder else EndReachedFooter
            KsPagingState.Idle -> null
        }
    }
}

/**
 * 既定の読み込み中の表示 (0 件のときの真ん中)。標準の不定の読み込み中の表示をそのまま使い、文言・色・
 * 大きさはテーマの既定に任せる (core/ADR-0024)。
 */
@Composable
internal fun KsPagingDefaultProgress() {
    CircularProgressIndicator()
}

/**
 * 次のページの読み込み中の既定の表示の直径と線の太さ。項目の上に小さく重ねるため、Material の既定 (40dp) より
 * 小さく、iOS の標準の読み込み中の表示に近い大きさにする。
 */
private val KsAppendingIndicatorSize = 24.dp
private val KsAppendingIndicatorStrokeWidth = 2.5.dp

/**
 * 次のページの読み込み中の既定の表示。標準の不定の読み込み中の表示を下地なしでそのまま出す。文言は持たない。
 * タッチを受ける修飾は付けず、下の項目へ通す。
 */
@Composable
internal fun KsPagingAppendingIndicatorDefault() {
    CircularProgressIndicator(
        modifier = Modifier.size(KsAppendingIndicatorSize),
        strokeWidth = KsAppendingIndicatorStrokeWidth,
    )
}

/**
 * ページングを付けた一覧のフッターの枠の中身。ページングの表示を上、利用者のフッターを下に縦に並べる。
 * ページングの表示は全幅で横方向の中央に揃える。どちらも無いときは高さを持たない。
 */
@Composable
internal fun KsPagingFooterStack(
    paging: (@Composable () -> Unit)?,
    footer: (@Composable () -> Unit)?,
) {
    Column(Modifier.fillMaxWidth()) {
        if (paging != null) {
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) { paging() }
        }
        footer?.invoke()
    }
}
