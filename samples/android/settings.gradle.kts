// KsCollectionView Android Sample — ビルドルートの入口 (settings)
//
// Sample は本体 (android/) とは独立したビルドルートであり (cross/ADR-0002)、本体を
// Gradle の composite build でソース参照する。本体ソースへ直接ブレークポイントを置いて
// ステップインでき、本体修正 → Sample 動作確認のループが短くなる。

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    // Settings 段階のプラグイン解決のために本体 build を取り込む。実体の依存置換は
    // 下方のトップレベル includeBuild で改めて行う。
    includeBuild("../../android")
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
    versionCatalogs {
        // AGP / Kotlin / Compose BOM / Navigation / 本体ライブラリの版は本体のカタログを
        // そのまま共有し、Sample 側で二重に宣言しない。
        create("libs") {
            from(files("../../android/gradle/libs.versions.toml"))
        }
        // Sample でしか使わない依存 (Activity Compose・計測) の版。本体の配布物には
        // 関係しないため本体のカタログへは足さず、Sample 側の宣言元に分ける。
        create("sampleLibs") {
            from(files("gradle/sample.versions.toml"))
        }
    }
}

// 本体ライブラリ (android/) の build を Sample のビルドへ取り込む (依存置換あり)。
//
// 明示の dependencySubstitution を付ける理由: 自動置換に任せると、置換が発火しなかったときに
// 公開リポジトリの版へ静かにフォールバックし「本体の修正が Sample に映らない」壊れ方をする。
// 明示置換なら置換先を失った時点で必ずビルドエラーになる。
includeBuild("../../android") {
    dependencySubstitution {
        substitute(module("jp.kamusoft:kscollectionview"))
            .using(project(":kscollectionview"))
    }
}

rootProject.name = "kscollectionview-sample-android"

// :app: Sample アプリ本体 (デモ画面と Android 固有の検証画面)
include(":app")

// :benchmark: Macrobenchmark による性能計測 (:app を計測対象にする)
include(":benchmark")
