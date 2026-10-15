package jp.kamusoft.kscollectionview.verification.android

// 画面のファイル (ItemListScreen.kt) は package の宣言を持たない。package を持つこのファイルからは、
// 名前だけの import が無いと解決できない。
import ItemListScreen
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent

/** 利用者役の入口。一覧を 1 つ表示する。 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { ItemListScreen() }
    }
}
