package jp.kamusoft.kscollectionview.verification.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent

/** 利用者役の入口。一覧を 1 つ表示する。 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { VerificationListScreen() }
    }
}
