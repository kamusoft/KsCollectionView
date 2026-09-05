// KsCollectionView Android — ビルドルートの入口 (settings)
//
// 公開ライブラリ本体の 1 モジュールだけで構成する (android/ADR-0002)。

pluginManagement {
    repositories {
        google()
        mavenCentral()
        // AGP / Kotlin プラグインを `plugins { ... }` 形式で解決するために必要。
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "kscollectionview"

// 公開ライブラリ本体。Compose Lazy 系の薄いラッパーを単一モジュールに収め、
// `jp.kamusoft:kscollectionview` 1 artifact として発行する (android/ADR-0002)。
include(":kscollectionview")
