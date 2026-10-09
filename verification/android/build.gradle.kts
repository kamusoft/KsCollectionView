// KsCollectionView Android の利用者役 — ルートプロジェクトのビルドファイル
//
// プラグインの版だけをここで固定し (apply false)、適用は :app が行う。

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
}
