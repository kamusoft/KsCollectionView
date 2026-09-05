package jp.kamusoft.kscollectionview

import androidx.compose.runtime.Composable

/**
 * `KsCollectionView` のテンプレート宣言ブロックであることを示すマーカーです。
 *
 * 入れ子になったブロックから外側のブロックの宣言を誤って呼ぶことを防ぎます。
 */
@DslMarker
public annotation class KsCollectionDsl

/**
 * `KsCollectionView` の中でテンプレートを宣言するためのスコープです。
 *
 * 値キーごとのテンプレートは [template]`(key)`、単一のテンプレートだけを使う場合は
 * 引数なしの [template] で宣言します。
 */
@KsCollectionDsl
public class KsCollectionViewScope<Item> internal constructor() {
    /** 宣言順を保つテンプレートの対応表。同じキーが再宣言された場合は後の宣言で置き換える。 */
    internal val templates: MutableMap<Any, @Composable (Item) -> Unit> = LinkedHashMap()

    /** 二重に宣言されたキー。警告と assertion のメッセージに使う。 */
    internal val duplicatedKeys: MutableList<Any> = mutableListOf()

    /**
     * 指定したキー値を持つ要素の描画内容を宣言します。
     *
     * キー値は `KsCollectionView` の `template` セレクタが返す値と突き合わせます。
     * 同じキーを 2 回宣言した場合は後の宣言が使われます。
     *
     * @param key この描画内容を使う要素のキー値
     * @param content 要素を受け取って描画する内容
     */
    public fun template(key: Any, content: @Composable (Item) -> Unit) {
        if (templates.put(key, content) != null) {
            duplicatedKeys += key
        }
    }

    /**
     * すべての要素に共通の描画内容を宣言します。
     *
     * `template` セレクタを指定しない場合に使う軽量形です。
     *
     * @param content 要素を受け取って描画する内容
     */
    public fun template(content: @Composable (Item) -> Unit) {
        template(KsSingleTemplateKey, content)
    }
}

/** 単一テンプレート形の内部キー。利用者からは到達できないため利用者のキー値と衝突しない。 */
internal object KsSingleTemplateKey
