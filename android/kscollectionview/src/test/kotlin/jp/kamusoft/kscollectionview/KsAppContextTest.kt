package jp.kamusoft.kscollectionview

import android.content.Context
import android.content.pm.PackageManager
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * 起動時の初期化がアプリケーションのコンテキストを捕捉する経路を確かめる。
 *
 * ここが成り立たないと、Context を引数に取らない [KsImageCache] が共有ローダーを引けない。
 * 経路は「マニフェストへの登録」と「初期化の実体」の 2 つに分かれるため、別々に確かめる。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34])
internal class KsAppContextTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    /**
     * マージ済みのマニフェストで、初期化がアプリ起動時の初期化一覧に載っている。
     *
     * 名前は文字列で書かれているため、型の改名がここで検出できるようにクラスから組み立てる。
     */
    @Test
    fun theInitializerIsRegisteredForStartup() {
        val provider = context.packageManager.getProviderInfo(
            android.content.ComponentName(context, "androidx.startup.InitializationProvider"),
            PackageManager.GET_META_DATA,
        )

        val name = KsAppContextInitializer::class.java.name
        assertEquals(
            "起動時の初期化として登録されていません",
            "androidx.startup",
            provider.metaData?.getString(name),
        )
    }

    /**
     * 初期化が走ると、アプリケーションのコンテキストが入る。
     *
     * 初期化の入口 (AppInitializer) は一度動かした結果を同じ JVM で使い回すため、
     * ここでは初期化の実体を直接動かす。入口へ載っていることは登録の検査が担う。
     */
    @Test
    fun theInitializerInstallsTheApplicationContext() {
        val application = ApplicationProvider.getApplicationContext<Context>()

        KsAppContextInitializer().create(application)

        assertSame(
            "起動時の初期化がアプリケーションのコンテキストを入れていません",
            application,
            KsAppContext.currentOrNull,
        )
    }

    // 初期化が走らない構成でも、キャッシュ操作は落ちずに何もせずに戻る。
    // androidx.startup の初期化一覧をマニフェストから外す構成は正規の運用であり、そこで
    // ライブラリが例外を投げると利用者に回避手段が無くなる (core/ADR-0011)。
    @Test
    fun cacheOperationsAreNoOpWhenTheInitializerDidNotRun() {
        val saved = KsAppContext.currentOrNull
        KsAppContext.reset()
        try {
            KsImageCache.clear(KsImageCacheScope.All)
            KsImageCache.remove(KsImageSource.Remote("https://images.example.com/a.jpg"))
        } finally {
            saved?.let { KsAppContext.install(it) }
        }
    }
}
