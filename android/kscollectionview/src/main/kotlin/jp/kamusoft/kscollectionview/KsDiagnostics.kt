package jp.kamusoft.kscollectionview

import android.content.Context
import android.content.pm.ApplicationInfo
import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect

/**
 * 不正入力の扱いを 1 か所にまとめる (core/ADR-0011)。
 *
 * debug ビルドでは即座に停止して開発中に気づかせ、release ビルドでは落とさず・消さず・黙らずに
 * 表示を継続する。debug 判定は組み込み先アプリの debuggable フラグで行う — ライブラリ自身の
 * ビルド種別ではなく、利用者が今どちらのビルドを動かしているかが判定したい対象のため。
 */
internal object KsDiagnostics {
    private const val TAG = "KsCollectionView"

    /** テストから debug / release の両挙動を確かめるための差し替え口。 */
    internal var debugOverride: Boolean? = null

    internal fun isDebugBuild(context: Context): Boolean =
        debugOverride ?: ((context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0)

    /**
     * 不正入力を報告する。release では警告ログだけを残して呼び出し元が処理を続ける。
     *
     * @throws IllegalStateException debug ビルドのとき
     */
    internal fun invalidInput(context: Context, message: String) {
        Log.w(TAG, message)
        check(!isDebugBuild(context)) { message }
    }

    /**
     * 集めた不正入力のうち debug ビルドでの停止だけを行う。
     *
     * release 向けの警告ログは [WarnOnce] が受け持つ。検査結果を純粋な値として組み立ててから
     * 停止と報告に分けることで、再コンポジションのたびに同じ警告が繰り返されないようにする。
     *
     * @throws IllegalStateException debug ビルドで [messages] が空でないとき
     */
    internal fun assertValid(context: Context, messages: List<String>) {
        if (messages.isEmpty()) return
        check(!isDebugBuild(context)) { messages.first() }
    }

    /** 停止を伴わない警告。 */
    internal fun warn(message: String) {
        Log.w(TAG, message)
    }

    /**
     * 同じ内容の診断は 1 回だけ警告ログに出す。
     *
     * コンポジションの副作用として出すため、再コンポジションが起きても内容が変わらない限り
     * 再報告しない。破棄されたコンポジションからログだけが残ることもない。
     */
    @Composable
    internal fun WarnOnce(messages: List<String>) {
        if (messages.isEmpty()) return
        LaunchedEffect(messages) {
            messages.forEach { warn(it) }
        }
    }
}
