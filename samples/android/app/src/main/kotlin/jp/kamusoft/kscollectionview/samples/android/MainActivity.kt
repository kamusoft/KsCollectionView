package jp.kamusoft.kscollectionview.samples.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme

/**
 * Sample の入口。
 *
 * 起動時の追加情報で経路を指定できる。計測は人の操作を挟まずに目的の画面を開く必要があるため、
 * この入口を使う。
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val startRoute = intent?.getStringExtra(SampleRoutes.StartRouteExtra)
        setContent {
            MaterialTheme {
                SampleNavHost(startRoute = startRoute)
            }
        }
    }
}
