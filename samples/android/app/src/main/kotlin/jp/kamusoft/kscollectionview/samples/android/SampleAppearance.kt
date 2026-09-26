package jp.kamusoft.kscollectionview.samples.android

import android.content.res.Configuration

/**
 * ルートメニューで選ぶアプリ全体の外観。
 *
 * 見出し・項目の文言・選択中の読み上げ文言・初期値・保存のキーはここ 1 箇所に置き、
 * iOS Sample の `SampleAppearance.swift` と同じ値にそろえる。
 *
 * @property title ルートメニューに出す項目名
 * @property storageValue 保存に使う値。iOS Sample の同じ項目の保存値と同じ文字列
 */
enum class SampleAppearance(val title: String, val storageValue: String) {
    /** 端末の表示モードに従う。 */
    System("システム", "system"),

    /** 端末の表示モードに関わらずライト。 */
    Light("ライト", "light"),

    /** 端末の表示モードに関わらずダーク。 */
    Dark("ダーク", "dark"),
    ;

    /**
     * Activity の表示モードに上書きする夜間モードの値。null は上書きなし (端末の表示モードが
     * そのまま効く)。
     */
    val nightModeOverride: Int?
        get() = when (this) {
            System -> null
            Light -> Configuration.UI_MODE_NIGHT_NO
            Dark -> Configuration.UI_MODE_NIGHT_YES
        }

    companion object {
        /** ルートメニューで外観の項目群につける見出し。 */
        const val SectionTitle = "外観"

        /** 選択中の項目で、項目名とあわせて読み上げる文言。 */
        const val SelectedStateDescription = "選択中"

        /** 選んだ値が保存されていないとき (初回起動) の選択。 */
        val Initial = System

        /** 選択の保存に使うキー。 */
        const val StorageKey = "appearance"

        /** 保存値から外観を引く。未保存・未知の値なら [Initial]。 */
        fun fromStorageValue(value: String?): SampleAppearance =
            entries.firstOrNull { it.storageValue == value } ?: Initial
    }
}
