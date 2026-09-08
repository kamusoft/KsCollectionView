package jp.kamusoft.kscollectionview

import android.content.Context
import androidx.startup.Initializer

/**
 * ライブラリが持つアプリケーションのコンテキスト。
 *
 * 画像の共有ローダーを引くには Context が要るが、公開 API の引数構成は両プラットフォームで
 * 揃える (core/ADR-0002) ため、Context を引数で受け取らずここから読む (android/ADR-0005)。値は
 * [KsAppContextInitializer] がアプリの起動時に入れる。
 */
internal object KsAppContext {

    private var applicationContext: Context? = null

    // 捕捉済みのアプリケーションのコンテキスト。起動時の初期化が動いていない環境では null。
    // 呼び出し側は null を落ちない縮退で扱う (core/ADR-0011)。初期化を外す構成は
    // androidx.startup が案内する正規の運用であり、そこでライブラリが例外を投げると
    // 利用者に回避手段が無くなる。
    val currentOrNull: Context?
        get() = applicationContext

    /** 与えられた Context のアプリケーション側を保持する。 */
    fun install(context: Context) {
        applicationContext = context.applicationContext
    }

    /** テストから初期化前の状態を作るための差し戻し。 */
    fun reset() {
        applicationContext = null
    }
}

/**
 * アプリケーションのコンテキストを [KsAppContext] へ入れる起動時の初期化。
 *
 * androidx.startup の仕組みで動くため、ライブラリ単独の ContentProvider は増えない
 * (利用者のアプリに既にある `androidx.startup.InitializationProvider` へ相乗りする)。
 * この型の名前は AndroidManifest.xml の meta-data に文字列で書かれている。
 */
internal class KsAppContextInitializer : Initializer<Context> {

    override fun create(context: Context): Context {
        KsAppContext.install(context)
        return context.applicationContext
    }

    override fun dependencies(): List<Class<out Initializer<*>>> = emptyList()
}
