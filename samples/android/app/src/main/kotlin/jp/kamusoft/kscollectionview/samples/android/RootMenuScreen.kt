package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

/**
 * ルートメニュー。先頭に外観の項目群を置き、その下にデモ画面と、それとは区分を分けた検証画面を並べる。
 *
 * @param appearance 選択中として示す外観
 * @param onSelectAppearance 外観の項目が選ばれたときの処理
 * @param onSelectDemo デモ画面が選ばれたときの処理
 * @param onSelectVerification 検証画面が選ばれたときの処理
 */
@Composable
fun RootMenuScreen(
    appearance: SampleAppearance,
    onSelectAppearance: (SampleAppearance) -> Unit,
    onSelectDemo: (SampleScreen) -> Unit,
    onSelectVerification: (VerificationScreen) -> Unit,
) {
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(SampleTheme.background),
    ) {
        item(key = "appearance-heading") { SampleMenuHeading(title = SampleAppearance.SectionTitle) }
        // 各項目群の先頭の行の上端にも区切り線を置き、最終行の下端まで同じ間隔で並ぶようにする。
        item(key = "appearance-leading-separator") { HorizontalDivider(color = SampleTheme.separator) }
        items(items = SampleAppearance.entries, key = { "appearance-${it.name}" }) { entry ->
            SampleAppearanceRow(
                appearance = entry,
                isSelected = entry == appearance,
                onClick = { onSelectAppearance(entry) },
            )
        }
        item(key = "gap") { SampleMenuGap() }
        item(key = "leading-separator") { HorizontalDivider(color = SampleTheme.separator) }
        items(items = SampleScreen.entries, key = { "demo-${it.name}" }) { screen ->
            MenuRow(title = screen.title, onClick = { onSelectDemo(screen) })
        }
        items(items = VerificationScreen.entries, key = { "verification-${it.name}" }) { screen ->
            MenuRow(title = screen.title, onClick = { onSelectVerification(screen) })
        }
    }
}

/** メニューの 1 行。 */
@Composable
private fun MenuRow(title: String, onClick: () -> Unit) {
    Text(
        text = title,
        style = MaterialTheme.typography.bodyLarge,
        color = SampleTheme.text,
        modifier = Modifier
            .fillMaxWidth()
            .background(SampleTheme.cell)
            .clickable(onClick = onClick)
            .padding(
                horizontal = SampleTheme.horizontalPadding,
                vertical = SampleTheme.rowVerticalPadding,
            ),
    )
    HorizontalDivider(color = SampleTheme.separator)
}
