package jp.kamusoft.kscollectionview.samples.android

import android.util.Log
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import kotlinx.coroutines.delay

/** 離脱後の同時生存が 0 になるのを待つ上限 (ミリ秒)。 */
private const val ReleaseDeadlineMillis = 10_000L

/** 同時生存の標本を取る間隔 (ミリ秒)。 */
private const val ReleaseSampleMillis = 100L

/**
 * 自動走査が画面を離れた後の結果を、外から読める進捗の印として出す画面。
 *
 * 離脱後にライブラリが項目単位の保持を手放したかどうかは、走査していた画面自身では読めない
 * (読む相手が画面と一緒に消えるため)。離脱先のこの画面がプロセスに属する計数を読むことで、
 * 「置換後」と「離脱後」の同時生存を 1 つの印にまとめて出す。
 *
 * 印の形は
 * `steady:<往復> peak:<最大同時生存> visible:<最大可視件数> replaced:<置換後> left:<離脱後>`。
 */
@Composable
fun MeasurementResultScreen(modifier: Modifier = Modifier) {
    var status by remember { mutableStateOf("running") }

    LaunchedEffect(Unit) {
        // 離脱した画面の後始末は、この画面が最初に組まれた時点では終わっていないことがある。
        // 0 になるのを実時間の上限つきで待ち、超えたらその時点の実測値をそのまま出す
        // (黙って 0 を出すと、解放されていない状態が解放済みとして記録される)。
        val deadline = System.currentTimeMillis() + ReleaseDeadlineMillis
        while (System.currentTimeMillis() < deadline && MeasurementLifetime.alive > 0) {
            delay(ReleaseSampleMillis)
        }
        val left = MeasurementLifetime.alive
        status = "steady:${MeasurementScanResult.settledRoundTrips}" +
            " peak:${MeasurementScanResult.peakAlive}" +
            " visible:${MeasurementScanResult.peakVisible}" +
            " replaced:${MeasurementScanResult.aliveAfterReplacement}" +
            " left:$left"
        Log.i("KsMemoryRoundTrip", "result=$status")
    }

    Column(modifier = modifier.fillMaxSize()) {
        Text(
            text = status,
            color = SampleTheme.secondaryText,
            modifier = Modifier.semantics { contentDescription = MeasurementStatusDescription },
        )
    }
}
