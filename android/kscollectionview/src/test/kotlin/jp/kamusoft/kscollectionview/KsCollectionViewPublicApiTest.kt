package jp.kamusoft.kscollectionview

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
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

    /** layout 値のグループ間の間隔と見出しの下の間隔は既定で 0 で、名前付き引数で指定できる。 */
    @Test
    fun layoutGroupSpacingsDefaultToZero() {
        assertEquals(0.dp, KsLayout.List.groupSpacing)
        assertEquals(0.dp, KsLayout.List.headerItemSpacing)
        val grid = KsLayout.Grid(KsColumns.Fixed(2))
        assertEquals(0.dp, grid.groupSpacing)
        assertEquals(0.dp, grid.headerItemSpacing)

        val list = KsLayout.List(rowSpacing = 1.dp, groupSpacing = 24.dp, headerItemSpacing = 8.dp)
        assertEquals(24.dp, list.groupSpacing)
        assertEquals(8.dp, list.headerItemSpacing)
        assertEquals(KsLayout.List(rowSpacing = 1.dp, groupSpacing = 24.dp, headerItemSpacing = 8.dp), list)
        assertNotEquals(KsLayout.List(rowSpacing = 1.dp, groupSpacing = 24.dp), list)
        assertEquals(
            KsLayout.Grid(KsColumns.Fixed(portrait = 2, landscape = 4), rowSpacing = 8.dp, groupSpacing = 24.dp, headerItemSpacing = 8.dp),
            KsLayout.Grid(KsColumns.Fixed(2, 4), 8.dp, 0.dp, 24.dp, 8.dp),
        )
    }

    /** グループの宣言は、見出しの固定が既定で有効、見出しは省略できる。 */
    @Test
    fun groupsDeclarationDefaults() {
        val withoutHeader = KsGroups<TestItem, TestKind>(by = { it.kind })
        assertTrue("見出しの固定は既定で有効", withoutHeader.pinnedHeaders)
        assertEquals("見出しは省略できる", null, withoutHeader.header)
        assertEquals(TestKind.Ad, withoutHeader.by(TestItem("a", "a", TestKind.Ad)))

        val unpinned = KsGroups<TestItem, TestKind>(by = { it.kind }, pinnedHeaders = false) { _, _ -> }
        assertEquals(false, unpinned.pinnedHeaders)
        assertTrue(unpinned.header != null)
    }

    /**
     * 利用者向けの書き方 (基本形・固定を外す・見出しなし・間隔) で、項目とグループの値の型を
     * 書かずに組み立てられ、見出しにグループの値と項目が型を保ったまま渡る。
     */
    @Test
    fun groupsComposeWithInferredTypes() {
        val items = listOf(
            TestItem("a", "a", TestKind.Message),
            TestItem("b", "b", TestKind.Message),
            TestItem("c", "c", TestKind.Ad),
        )
        composeTestRule.setContent {
            TestContainer {
                KsCollectionView(
                    items = items,
                    key = { it.id },
                    groups = KsGroups(by = { it.kind }) { kind, itemsInGroup ->
                        // 型引数は推論され、グループの値は enum、項目は TestItem のまま受け取れる。
                        val name: String = kind.name
                        val firstId: String = itemsInGroup.first().id
                        Text("$name ${itemsInGroup.size} $firstId", Modifier.testTag("basic-${kind.name}"))
                    },
                ) {
                    template { item -> ItemRow(item) }
                }
            }
        }

        composeTestRule.onNodeWithTag("basic-Message").assertTextEquals("Message 2 a")
        composeTestRule.onNodeWithTag("basic-Ad").assertTextEquals("Ad 1 c")
    }

    /** 固定を外す形・見出しなしの形・間隔の指定も同じ引数で書ける。 */
    @Test
    fun groupsVariantsCompose() {
        composeTestRule.setContent {
            TestContainer {
                KsCollectionView(
                    items = testItems(3),
                    key = { it.id },
                    groups = KsGroups(by = { it.kind }, pinnedHeaders = false) { kind, _ ->
                        Text(kind.name, Modifier.testTag("unpinned"))
                    },
                ) {
                    template { item -> ItemRow(item) }
                }
                KsCollectionView(
                    items = testItems(3),
                    key = { it.id },
                    layout = KsLayout.Grid(
                        KsColumns.Fixed(portrait = 2, landscape = 4),
                        rowSpacing = 8.dp,
                        groupSpacing = 24.dp,
                        headerItemSpacing = 8.dp,
                    ),
                    groups = KsGroups(by = { it.kind }),
                ) {
                    template { item -> ItemRow(item) }
                }
            }
        }

        assertEquals(1, composeTestRule.countNodesWithTag("unpinned"))
    }

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

    /** ページングの状態は待機・取り直し中・追加読み込み中・失敗・終端の 5 値で、付属の値を持たない。 */
    @Test
    fun pagingStateHasFiveValues() {
        assertEquals(
            listOf(
                KsPagingState.Idle,
                KsPagingState.Refreshing,
                KsPagingState.Appending,
                KsPagingState.Failed,
                KsPagingState.EndReached,
            ),
            KsPagingState.entries.toList(),
        )
    }

    /** ページングの設定は、状態と次ページ要求 (suspend 関数) だけで作れ、しきい値は既定 1、6 つの表示は既定で省略 (null)。 */
    @Test
    fun pagingDefaults() {
        val loadMore: suspend () -> Unit = {}
        val paging = KsPaging(state = KsPagingState.Idle, onLoadMore = loadMore)
        assertEquals(KsPagingState.Idle, paging.state)
        assertEquals(1f, paging.threshold)
        assertTrue(paging.onLoadMore === loadMore)
        assertEquals(null, paging.appendingIndicator)
        assertEquals(null, paging.failedFooter)
        assertEquals(null, paging.endReachedFooter)
        assertEquals(null, paging.loadingPlaceholder)
        assertEquals(null, paging.failedPlaceholder)
        assertEquals(null, paging.emptyPlaceholder)
    }

    /** しきい値と 6 つの表示は名前付き引数で差し替えられ、失敗の表示は再試行の操作を受け取る。 */
    @Test
    fun pagingDisplaysAreNamedArguments() {
        val paging = KsPaging(
            state = KsPagingState.Appending,
            onLoadMore = {},
            threshold = 2.5f,
            appendingIndicator = { Text("読み込み中") },
            failedFooter = { retry -> Text("再試行", Modifier.clickable(onClick = retry)) },
            endReachedFooter = { Text("終端") },
            loadingPlaceholder = { Text("最初の読み込み中") },
            failedPlaceholder = { retry: () -> Unit -> Text("再試行", Modifier.clickable(onClick = retry)) },
            emptyPlaceholder = { Text("空") },
        )
        assertEquals(2.5f, paging.threshold)
        assertTrue(paging.appendingIndicator != null && paging.failedFooter != null && paging.endReachedFooter != null)
        assertTrue(paging.loadingPlaceholder != null && paging.failedPlaceholder != null && paging.emptyPlaceholder != null)
    }

    /** 一覧はページングの設定と取り直しの処理 (suspend 関数) を名前付き引数で受け取る。どちらも省略できる。 */
    @Test
    fun collectionAcceptsPagingAndRefresh() {
        composeTestRule.setContent {
            TestContainer {
                KsCollectionView(
                    items = testItems(3),
                    key = { it.id },
                    paging = KsPaging(state = KsPagingState.EndReached, onLoadMore = {}),
                    onRefresh = {},
                ) {
                    template { item -> ItemRow(item) }
                }
            }
        }

        assertEquals(3, composeTestRule.countNodesWithTag("cell"))
    }

    /** 並べ替えの設定は、スイッチと置いたときの処理だけで作れ、判定 2 つと読み上げの文言は既定で省略 (null)。 */
    @Test
    fun reorderDefaults() {
        val onMove: (KsReorderMove<TestItem>) -> Boolean = { true }
        val reorder = KsReorder(enabled = true, onMove = onMove)
        assertEquals(true, reorder.enabled)
        assertTrue(reorder.onMove === onMove)
        assertEquals(null, reorder.canMove)
        assertEquals(null, reorder.canDrop)
        assertEquals(null, reorder.accessibilityActions)
    }

    /** 判定 2 つと読み上げの文言は名前付き引数で渡せ、判定は置いたときと同じ形の知らせを受け取る。 */
    @Test
    fun reorderNamedArguments() {
        val actions = KsReorderAccessibilityActions(previous = "前へ移動", next = "後ろへ移動")
        val reorder = KsReorder<TestItem>(
            enabled = false,
            onMove = { false },
            canMove = { it.id != "fixed" },
            canDrop = { move -> move.group == TestKind.Message },
            accessibilityActions = actions,
        )
        assertEquals("前へ移動", reorder.accessibilityActions?.previous)
        assertEquals("後ろへ移動", reorder.accessibilityActions?.next)
        assertEquals(false, reorder.canMove?.invoke(TestItem("fixed", "fixed")))
        val move = KsReorderMove(TestItem("a", "a"), KsReorderDestination.End, TestKind.Message)
        assertEquals(true, reorder.canDrop?.invoke(move))
    }

    /** 知らせは動かした項目・行き先 (項目の前 / 末尾)・グループの値 (宣言していなければ null) を持つ。 */
    @Test
    fun reorderMoveShape() {
        val a = TestItem("a", "a")
        val b = TestItem("b", "b")
        val before = KsReorderMove(a, KsReorderDestination.Before(b), group = null)
        assertTrue(before.item === a)
        val destination: KsReorderDestination<TestItem> = before.destination
        assertTrue(destination is KsReorderDestination.Before && destination.item === b)
        assertEquals(null, before.group)

        // 末尾はどの項目の型の行き先にもなる。
        val end: KsReorderDestination<TestItem> = KsReorderDestination.End
        val grouped = KsReorderMove(a, end, group = TestKind.Ad)
        assertEquals(KsReorderDestination.End, grouped.destination)
        assertEquals(TestKind.Ad, grouped.group)
    }

    /** 一覧は並べ替えの設定を名前付き引数で受け取る。省略できる。 */
    @Test
    fun collectionAcceptsReorder() {
        composeTestRule.setContent {
            TestContainer {
                KsCollectionView(
                    items = testItems(3),
                    key = { it.id },
                    paging = KsPaging(state = KsPagingState.EndReached, onLoadMore = {}),
                    onRefresh = {},
                    reorder = KsReorder(enabled = true, onMove = { true }),
                ) {
                    template { item -> ItemRow(item) }
                }
            }
        }

        assertEquals(3, composeTestRule.countNodesWithTag("cell"))
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
