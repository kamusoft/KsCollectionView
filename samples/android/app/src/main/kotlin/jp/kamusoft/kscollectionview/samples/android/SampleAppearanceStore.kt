package jp.kamusoft.kscollectionview.samples.android

import android.content.Context
import android.content.res.Configuration

/**
 * 外観の選択 ([SampleAppearance]) の保存と、Activity に与える表示モードの上書きの組み立て。
 *
 * 反映は Activity 自身の Configuration の上書きで行い、OS のアプリ単位の夜間モード設定
 * (`UiModeManager.setApplicationNightMode`) は使わない。後者は「端末に追随する」値を持たないため、
 * 「システム」を選び直したときに端末の設定へ戻せなくなる。
 *
 * 上書きした Configuration は Activity の Resources に効くため、`values-night/` のテーマ・Compose の
 * `isSystemInDarkTheme()`・ライブラリの既定の色がすべて同じ外観で解決される。
 */
object SampleAppearanceStore {
    /** 保存先の SharedPreferences の名前。 */
    private const val PreferencesName = "sample_appearance"

    /** 保存済みの選択を返す。未保存・未知の値なら [SampleAppearance.Initial]。 */
    fun load(context: Context): SampleAppearance =
        SampleAppearance.fromStorageValue(
            preferences(context).getString(SampleAppearance.StorageKey, null),
        )

    /** 選択を保存する。次の起動や Activity の作り直しでは [load] がこの値を返す。 */
    fun save(context: Context, appearance: SampleAppearance) {
        // 保存の直後に Activity を作り直すため、作り直しより前にディスクへの書き込みを終える commit を使う。
        preferences(context).edit()
            .putString(SampleAppearance.StorageKey, appearance.storageValue)
            .commit()
    }

    /**
     * 保存済みの選択に対応する Configuration の上書き。「システム」なら null (上書きなし) を返し、
     * 端末の表示モードがそのまま効く。
     *
     * 返す Configuration は夜間モードだけを持つ差分である。引数なしの `Configuration()` は全項目を
     * 未設定で作り、`Configuration.updateFrom` は未設定の項目を取り込まない。`uiMode` も種別と夜間の
     * 部分を別々に取り込むため、端末の文字の大きさ・表示密度・種別はそのまま残る。
     */
    fun nightModeOverride(context: Context): Configuration? {
        val night = load(context).nightModeOverride ?: return null
        return Configuration().apply { uiMode = night }
    }

    private fun preferences(context: Context) =
        context.applicationContext.getSharedPreferences(PreferencesName, Context.MODE_PRIVATE)
}
