package jp.kamusoft.kscollectionview

import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics

/**
 * 項目に、読み上げ (TalkBack) 用の「1 つ前へ動かす」「1 つ後ろへ動かす」の操作を付ける (core/ADR-0032)。
 *
 * 読み上げの焦点は項目の中の要素 (テンプレートの文字など) に当たりうるため、項目の中身をまとめて 1 つの
 * 焦点にし、その焦点に操作を付ける。項目の中の押せる部品 (ボタンなど) は、まとめた後も別の焦点として残る。
 *
 * @param hasPrevious 1 つ前へ動かす操作を出すか
 * @param hasNext 1 つ後ろへ動かす操作を出すか
 * @param move 操作を実行する。後ろへなら true を受け取る。受け入れられたかを返す
 */
internal fun Modifier.ksReorderAccessibility(
    actions: KsReorderAccessibilityActions,
    hasPrevious: Boolean,
    hasNext: Boolean,
    move: (forward: Boolean) -> Boolean,
): Modifier {
    if (!hasPrevious && !hasNext) return this
    val list = buildList {
        if (hasPrevious) add(CustomAccessibilityAction(actions.previous) { move(false) })
        if (hasNext) add(CustomAccessibilityAction(actions.next) { move(true) })
    }
    return semantics(mergeDescendants = true) { customActions = list }
}
