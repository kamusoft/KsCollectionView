package jp.kamusoft.kscollectionview

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import java.io.File

/** 公開面に現れる型と引数の存在・既定値を確かめる。 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = "w400dp-h800dp")
internal class KsCollectionViewPublicApiTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    /** プリフェッチの到達点は disk と memory の 2 種で表す。 */
    @Test
    fun prefetchDestinationHasDiskAndMemory() {
        assertEquals(
            listOf(KsPrefetchDestination.Disk, KsPrefetchDestination.Memory),
            KsPrefetchDestination.entries.toList(),
        )
    }

    /** 画像ソースはリモート・ファイル・リソースの 3 種を表せる。 */
    @Test
    fun imageSourceCoversThreeKinds() {
        val remote: KsImageSource = KsImageSource.Remote("https://example.com/1.jpg")
        val file: KsImageSource = KsImageSource.File(File("/tmp/1.jpg"))
        val resource: KsImageSource = KsImageSource.Resource(id = 42)

        assertNotEquals(remote, file)
        assertNotEquals(file, resource)
        assertEquals(KsImageSource.Remote("https://example.com/1.jpg"), remote)
    }

    /** 読み込み中と失敗の表示は、両方既定・片方だけ・両方指定のいずれでも書ける。 */
    @Test
    fun imageSlotsCanBeSubstitutedIndependently() {
        val source = KsImageSource.Remote("https://example.com/slot.jpg")
        composeTestRule.setContent {
            TestContainer {
                KsImage(source, modifier = Modifier.height(20.dp).testTag("both-default"))
                KsImage(
                    source,
                    modifier = Modifier.height(20.dp).testTag("loading-only"),
                    loading = { Text("読み込み中") },
                )
                KsImage(
                    source,
                    modifier = Modifier.height(20.dp).testTag("failure-only"),
                    failure = { Text("表示できません") },
                )
                KsImage(
                    source,
                    modifier = Modifier.height(20.dp).testTag("both-given"),
                    contentMode = KsImageContentMode.Fit,
                    loading = { Text("読み込み中") },
                    failure = { Text("表示できません") },
                )
            }
        }

        for (tag in listOf("both-default", "loading-only", "failure-only", "both-given")) {
            assertEquals(tag, 1, composeTestRule.countNodesWithTag(tag))
        }
    }

    /**
     * URL の便宜形は、位置引数の並びが画像ソースの形と同じ (modifier・説明・当てはめ方) で、
     * 3 番目の文字列は説明に結び付く (キーに化けない)。末尾のラムダは失敗の表示になる。
     */
    @Test
    fun urlOverloadKeepsPositionalArgumentsOfTheSourceOverload() {
        composeTestRule.setContent {
            TestContainer {
                KsImage("https://example.com/positional.jpg", Modifier.height(20.dp), "位置引数の説明")
                KsImage("https://example.com/trailing.jpg", Modifier.height(20.dp).testTag("trailing")) {
                    Text("表示できません")
                }
            }
        }

        assertEquals(
            1,
            composeTestRule.onAllNodesWithContentDescription("位置引数の説明").fetchSemanticsNodes().size,
        )
        assertEquals(1, composeTestRule.countNodesWithTag("trailing"))
    }

    /** プリフェッチの宣言を省略しても組み立てられる (既定は宣言なし・到達点 disk)。 */
    @Test
    fun composesWithoutPrefetchDeclaration() {
        composeTestRule.setContent {
            TestContainer {
                KsCollectionView(items = testItems(3), key = { it.id }) {
                    template { item -> ItemRow(item) }
                }
            }
        }

        assertTrue(composeTestRule.countNodesWithTag("cell") > 0)
    }

    /** プリフェッチの宣言と到達点を名前付き引数で渡せる。 */
    @Test
    fun composesWithPrefetchDeclaration() {
        composeTestRule.setContent {
            TestContainer {
                KsCollectionView(
                    items = testItems(3),
                    key = { it.id },
                    prefetchResources = { item ->
                        listOf(
                            KsResource("https://example.com/${item.id}.jpg", width = KsWidth.Column),
                            KsResource("https://example.com/${item.id}-avatar.jpg", width = KsWidth.Fixed(40.dp)),
                            KsResource("https://example.com/${item.id}-banner.jpg"),
                            KsResource("https://example.com/${item.id}.jpg?sig=1", key = item.id),
                        )
                    },
                    prefetchDestination = KsPrefetchDestination.Memory,
                ) {
                    template { item -> ItemRow(item) }
                }
            }
        }

        assertTrue(composeTestRule.countNodesWithTag("cell") > 0)
    }

    /** 先読みの要素は URL・任意の幅・任意のキーを持ち、幅とキーの既定は省略 (null)。 */
    @Test
    fun resourceHasOptionalWidthAndKey() {
        val plain = KsResource("https://example.com/1.jpg")

        assertEquals(null, plain.width)
        assertEquals(null, plain.key)
        assertEquals(
            KsResource("https://example.com/1.jpg", width = KsWidth.Column, key = "p1"),
            KsResource(url = "https://example.com/1.jpg", width = KsWidth.Column, key = "p1"),
        )
        assertNotEquals(KsWidth.Fixed(40.dp), KsWidth.Column)
        assertEquals(KsWidth.Fixed(40.dp), KsWidth.Fixed(40.dp))
    }

    /** リモートの画像ソースは任意のキーを持てる。既定は省略 (null)。 */
    @Test
    fun remoteSourceHasOptionalKey() {
        assertEquals(null, KsImageSource.Remote("https://example.com/1.jpg").key)
        assertNotEquals(
            KsImageSource.Remote("https://example.com/1.jpg"),
            KsImageSource.Remote("https://example.com/1.jpg", key = "p1"),
        )
    }
}

@androidx.compose.runtime.Composable
private fun ItemRow(item: TestItem) {
    Text(
        text = item.text,
        modifier = Modifier.fillMaxWidth().height(50.dp).testTag("cell"),
    )
}
