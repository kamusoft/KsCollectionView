package jp.kamusoft.kscollectionview.samples.android

import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import coil3.memory.MemoryCache
import coil3.request.CachePolicy
import coil3.request.ImageRequest
import coil3.size.Precision
import coil3.size.Scale
import coil3.size.Size
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * 観測ログの種別が、要求から本当に分かることだけを名乗ることを確かめる。
 *
 * 計測資料はこの種別で件数を集計するため、分けられないものを単一の種別で出すと、実態と違う数を
 * 確定値として読んでしまう。そこで「分けられる要求は分かれること」と「分けられない要求は
 * 曖昧さの分かる名前になること」の両方を、それぞれの経路が実際に作る形の要求で確かめる。
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34])
class ImageRequestKindTest {

    private val context = ApplicationProvider.getApplicationContext<android.content.Context>()

    /** 到達点をディスクまでにした先読みだけが、メモリキャッシュを使わない指定で分かれる。 */
    @Test
    fun `到達点がディスクまでの先読みは先読みとして記録される`() {
        val request = ImageRequest.Builder(context)
            .data(Url)
            .memoryCachePolicy(CachePolicy.DISABLED)
            .build()

        assertEquals(ImageRequestKind.PrefetchDisk, ImageRequestKind.of(request))
    }

    /**
     * 到達点をメモリまでにした先読みは寸法を付けない素の要求になる。
     * ローダー付属のビューを直接使った表示も同じ形になるため、曖昧な名前で記録する。
     */
    @Test
    fun `到達点がメモリまでの先読みは曖昧な種別として記録される`() {
        val request = ImageRequest.Builder(context).data(Url).build()

        assertEquals(ImageRequestKind.DisplayOrMemoryPrefetch, ImageRequestKind.of(request))
    }

    /**
     * 表示要求は寸法と鍵を持つが、寸法の一致を求める指定は要求の既定値でもあるため、
     * 到達点がメモリまでの先読みと**区別できない**。区別できたかのような種別を出さない。
     *
     * 本体の要求の組み立ては internal でこの module から呼べないため、要求の形は
     * `KsImageRequestFactory` の実装に合わせて手で組んでいる。本体側の形が変わると、
     * このテストは緑のまま実態を映さなくなる (そのときは本体側の変更で気付く想定)。
     */
    @Test
    fun `表示要求は先読みと区別できないため曖昧な種別として記録される`() {
        val request = ImageRequest.Builder(context)
            .data(Url)
            .size(Size(100, 100))
            .scale(Scale.FILL)
            .precision(Precision.EXACT)
            .memoryCacheKey(MemoryCache.Key(Url, mapOf("coil#size" to "100x100")))
            .build()

        assertEquals(ImageRequestKind.DisplayOrMemoryPrefetch, ImageRequestKind.of(request))
    }

    private companion object {
        const val Url = "https://images.example.com/1.jpg"
    }
}
