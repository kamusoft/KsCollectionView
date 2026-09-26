package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/**
 * ルートメニューの項目群の間に置く、下地の色の隙間。読み上げの対象にしない。
 *
 * 高さは iOS Sample の `SampleMenuGapRow` と同じ値にする。
 */
@Composable
fun SampleMenuGap() {
    Spacer(
        modifier = Modifier
            .fillMaxWidth()
            .height(20.dp)
            .background(SampleTheme.background),
    )
}
