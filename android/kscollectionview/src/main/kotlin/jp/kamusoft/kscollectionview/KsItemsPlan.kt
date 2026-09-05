package jp.kamusoft.kscollectionview

import android.content.Context
import android.os.Parcelable
import java.io.Serializable

/**
 * 配列を表示するために必要な、件数に比例しない情報。
 *
 * 正常系では利用者の配列をそのまま [items] に持ち、要素ごとの付随データは作らない。安定 ID と
 * テンプレートキーは表示中の要素の分だけ、その場で解決する。
 *
 * @property items 表示する要素。重複 ID がなければ利用者の配列そのもの
 * @property templateKeys 配列に現れたテンプレートキーの一覧 (重複なし)。件数ではなく種類数に比例する
 * @property diagnostics 解決の途中で見つかった不正入力のメッセージ
 */
internal class KsItemsPlan<Item>(
    val items: List<Item>,
    val templateKeys: List<Any>,
    val diagnostics: List<String>,
)

/**
 * 利用者の配列を表示用に検査する。
 *
 * - 安定 ID が状態保存に載せられる型かを確かめる
 * - 重複 ID があれば後勝ちで 1 件へ畳んだ配列を作る (後に現れた要素をその位置で採用する)
 * - 配列に現れるテンプレートキーの種類を集める
 *
 * 走査に使う集合は呼び出しの中だけで捨てるため、返り値が抱える情報は要素数に比例しない。
 * 不正入力は core/ADR-0011 に従い debug では停止する。release の警告ログは呼び出し元が出す。
 *
 * @throws IllegalStateException debug ビルドで不正入力を見つけたとき
 */
internal fun <Item> resolveItems(
    items: kotlin.collections.List<Item>,
    key: (Item) -> Any,
    template: ((Item) -> Any)?,
    context: Context,
): KsItemsPlan<Item> {
    val seenIds = HashSet<Any>(items.size)
    val templateKeys = LinkedHashSet<Any>()
    var duplicatedCount = 0
    var unsavableId: Any? = null

    for (item in items) {
        val id = key(item)
        if (unsavableId == null && !isSavableKey(id)) {
            unsavableId = id
        }
        if (!seenIds.add(id)) {
            duplicatedCount++
        }
        templateKeys += template?.invoke(item) ?: KsSingleTemplateKey
    }

    val diagnostics = buildList {
        if (unsavableId != null) {
            add(
                "key が状態保存に載せられない型です: ${unsavableId::class.java.name}。" +
                    "文字列・数値・enum・Serializable・Parcelable のいずれかを返してください",
            )
        }
        if (duplicatedCount > 0) {
            add("重複した key が $duplicatedCount 件あります。後に現れた要素を採用して表示を継続します")
        }
    }
    KsDiagnostics.assertValid(context, diagnostics)

    // 重複がある縮退時だけ補正した配列を作る。正常系は利用者の配列をそのまま使う。
    val displayed = if (duplicatedCount == 0) items else deduplicate(items, key)
    return KsItemsPlan(items = displayed, templateKeys = templateKeys.toList(), diagnostics = diagnostics)
}

/** 重複 ID を後勝ちで畳む。後に現れた要素をその位置で採用する。 */
private fun <Item> deduplicate(
    items: kotlin.collections.List<Item>,
    key: (Item) -> Any,
): kotlin.collections.List<Item> {
    val byId = LinkedHashMap<Any, Item>(items.size)
    for (item in items) {
        val id = key(item)
        // 後勝ちを「後の要素の位置」で成立させるため、一度取り除いてから入れ直す。
        byId.remove(id)
        byId[id] = item
    }
    return byId.values.toList()
}

/** Android の状態保存 (Bundle) に載せられる型かどうか。 */
private fun isSavableKey(id: Any): Boolean = when (id) {
    is String, is Char, is Boolean -> true
    is Number -> true
    is Parcelable, is Serializable -> true
    else -> false
}
