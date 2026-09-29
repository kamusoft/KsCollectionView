package jp.kamusoft.kscollectionview.samples.android

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.style.TextOverflow

/**
 * 全画面で共通のはこ。上部バーにタイトル (と戻る導線) を出し、本体を下に敷く。
 *
 * タイトルは呼び出し側が [SampleScreen] / [VerificationScreen] から渡す。ここで文言を
 * 組み立てないことで、メニューと画面タイトルの宣言元を 1 つに保つ。
 *
 * @param title 上部バーに出すタイトル
 * @param onBack 戻る導線を出す場合の処理。null ならルート画面として扱い戻る導線を出さない
 * @param extendsBehindBottomBar 内容を画面の下端 (ナビゲーションバーの裏) まで広げるか。広げた内容は
 *   下端の安全領域の分を自分で空ける
 * @param content 上部バーの下に敷く内容
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SampleScaffold(
    title: String,
    onBack: (() -> Unit)? = null,
    extendsBehindBottomBar: Boolean = false,
    content: @Composable () -> Unit,
) {
    Scaffold(
        containerColor = SampleTheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = title,
                        color = SampleTheme.text,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                },
                navigationIcon = {
                    if (onBack != null) {
                        // 戻るの図案は Compose の版によって提供元が変わるため、Sample では
                        // 依存を増やさずに読める文字で表す。
                        IconButton(onClick = onBack) {
                            Text(
                                text = "←",
                                style = MaterialTheme.typography.titleLarge,
                                color = SampleTheme.text,
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = SampleTheme.background,
                    titleContentColor = SampleTheme.text,
                ),
            )
        },
    ) { innerPadding ->
        val layoutDirection = LocalLayoutDirection.current
        val contentPadding = if (extendsBehindBottomBar) {
            PaddingValues(
                start = innerPadding.calculateStartPadding(layoutDirection),
                top = innerPadding.calculateTopPadding(),
                end = innerPadding.calculateEndPadding(layoutDirection),
            )
        } else {
            innerPadding
        }
        Box(modifier = Modifier.fillMaxSize().padding(contentPadding)) {
            content()
        }
    }
}
