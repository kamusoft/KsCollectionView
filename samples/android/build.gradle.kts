// KsCollectionView Android Sample — ルートプロジェクトのビルドファイル
//
// プラグインの版だけをここで固定し (apply false)、適用は各モジュールが行う。
// :benchmark が使う `com.android.test` はここで classpath に載る Android Gradle Plugin に
// 同梱されるため、モジュール側は版を書かずに id だけで参照できる。

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
}
