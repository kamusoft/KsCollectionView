package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import jp.kamusoft.kscollectionview.KsCollectionView
import jp.kamusoft.kscollectionview.KsImageCache
import jp.kamusoft.kscollectionview.KsImageCacheScope
import jp.kamusoft.kscollectionview.KsPrefetchDestination

/**
 * 「画像グリッド」画面。10,000 件のネットワーク画像を 3 列で並べ、プリフェッチの到達点を
 * 切り替えながらスクロールの見え方を比べる。
 *
 * 件数・列数・間隔・文言・初期選択は iOS Sample の同名画面とそろえる (cross/ADR-0004)。
 */
@Composable
fun ImageGridDemoScreen(modifier: Modifier = Modifier) {
    // 選択は構成変更 (回転) をまたいで保つ。iOS の @State と同じ振る舞いにそろえる。
    var choice by rememberSaveable { mutableStateOf(ImagePrefetchChoice.Disk) }
    val items = remember { ImageGridFixture.items() }

    Column(modifier = modifier.fillMaxSize()) {
        val destination = choice.destination

        KsCollectionView(
            items = items,
            key = { it.id },
            modifier = Modifier.weight(1f),
            layout = ImageGridFixture.layout,
            contentPadding = ImageGridFixture.contentPadding,
            // 「なし」は宣言そのものを行わず、プリフェッチが無い状態を見せる。
            prefetchResources = ImageGridFixture.resources(destination),
            prefetchDestination = destination ?: KsPrefetchDestination.Disk,
        ) {
            template { item -> ImageGridCell(item) }
        }

        HorizontalDivider(color = SampleTheme.separator)

        SampleControlBar(
            verticalArrangement = Arrangement.spacedBy(SampleTheme.controlVerticalPadding),
        ) {
            SampleSegmentedControl(
                modifier = Modifier.fillMaxWidth(),
                options = ImagePrefetchChoice.entries.map { it.title },
                selectedIndex = choice.ordinal,
                onSelect = { choice = ImagePrefetchChoice.entries[it] },
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                // 件数と列数を含む説明。iOS Sample の同じ行と一字一句そろえる。
                Text(
                    text = "プリフェッチ · 10,000 件 · 3 列",
                    style = MaterialTheme.typography.bodySmall,
                    color = SampleTheme.secondaryText,
                )
                Spacer(modifier = Modifier.weight(1f))
                TextButton(
                    onClick = { KsImageCache.clear(KsImageCacheScope.All) },
                    // 文言をバーの右端の余白に合わせるため、ボタン自身の左右の余白は持たせない。
                    // 触れる範囲は Material の最小寸法が確保する。
                    contentPadding = PaddingValues(vertical = 8.dp),
                ) {
                    Text(
                        text = "キャッシュを消去",
                        style = MaterialTheme.typography.bodyMedium,
                        color = SampleTheme.accent,
                    )
                }
            }
        }
    }
}
