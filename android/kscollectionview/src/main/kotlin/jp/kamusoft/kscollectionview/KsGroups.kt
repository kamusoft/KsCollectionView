package jp.kamusoft.kscollectionview

import androidx.compose.runtime.Composable

/**
 * 項目をグループに分け、各グループの先頭に見出しを表示するための宣言です。
 *
 * `KsCollectionView` の `groups` 引数に渡します。配列の順に、[by] が返すグループの値が等しい項目が
 * 続く範囲が 1 つのグループになります。配列は平らなまま渡し、項目の型を変える必要はありません。
 * 同じグループの値を持つ項目は配列の中で続けて並べてください。離れた位置に同じ値が再び現れると、
 * デバッグビルドでは停止して知らせ、リリースビルドでは配列の順のまま別々のグループとして表示し、
 * 警告を記録します。
 *
 * グループの値は、項目の `key` と同じく文字列・数値・enum・`Serializable`・`Parcelable` の
 * いずれか (状態保存に載せられる型) にしてください。見出しの識別に使われ、グループの並べ替えや
 * 項目の移動で見出しが一緒に動きます。項目の `key` と同じ値でも衝突しません。
 *
 * 見出しの Composable には、グループの値とそのグループの項目が渡されます。見出しの高さは中身から
 * 決まり、グリッドでは全幅に表示されます。見出しは既定でスクロール時に表示範囲の上端へ固定され、
 * 次のグループの見出しが上端に達すると押し上げられて入れ替わります。
 *
 * ```
 * KsCollectionView(
 *     items = products,
 *     key = { it.id },
 *     groups = KsGroups(by = { it.category }) { category, productsInGroup ->
 *         Text("$category (${productsInGroup.size})")
 *     },
 * ) { template { product -> ProductRow(product) } }
 * ```
 *
 * 見出しを省略すると、グループの区切りに見出しは表示されず、グループとグループの間の間隔
 * ([KsLayout] の `groupSpacing`) と、リストの区切り線の単位としてだけ使われます。見出しと先頭行の
 * 間の間隔は [KsLayout] の `headerItemSpacing` で指定します。
 *
 * 表示中に [by] を別のラムダへ差し替えると、配列が同じでも新しいグループの値でグループを組み直します
 * (グループの値の並びが変わらなければ組み直しません)。
 *
 * @param Item 項目の型
 * @param Group グループの値の型
 * @property by 項目からグループの値を返すラムダ
 * @property pinnedHeaders 見出しをスクロール時に表示範囲の上端へ固定するかどうか。見出しを
 *   宣言しない場合は使われない
 * @property header 見出しの内容。グループの値とそのグループの項目を受け取る。省略すると見出しは
 *   表示されない
 */
public class KsGroups<Item, Group>(
    public val by: (Item) -> Group,
    public val pinnedHeaders: Boolean = true,
    public val header: (@Composable (group: Group, items: List<Item>) -> Unit)? = null,
) {
    // 平らな配列のまま、項目のグループの値を指してグループにする (core/ADR-0015)。

    /**
     * グループの値の型を消した見出しの内容。
     *
     * 呼び出し側 (`KsCollectionView`) はグループの値の型を知らずに受け取るため、値は [by] が
     * 返したものをそのまま渡す前提で型を戻す。
     */
    internal val erasedHeader: (@Composable (group: Any?, items: List<Item>) -> Unit)? =
        header?.let { content ->
            @Suppress("UNCHECKED_CAST")
            val erased: @Composable (Any?, List<Item>) -> Unit = { group, items ->
                content(group as Group, items)
            }
            erased
        }
}
