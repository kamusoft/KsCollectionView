// KsCollectionView Android の利用者役 — ビルドルートの入口 (settings)
//
// 配布物を、利用者と同じ書き方 (Maven の座標 1 行の依存) で取ってビルドするアプリ。
// 本体 (android/) や Sample (samples/android/) とは独立したビルドルートで、本体のビルドを
// 取り込まない (composite build も依存の置き換えも持たない)。本体のソースが手元にあっても、
// 使われるのは発行物だけである。
//
// 配布物をどこから取るかは、Gradle のプロパティで受け取る。
//
//   ksCollectionViewMode        local (既定) か published
//   ksCollectionViewRepository  local のときに必須。発行物を置いた Maven リポジトリのディレクトリ
//   ksCollectionViewVersion     取る版 (:app が読む。無ければ本体のバージョンカタログの版)
//
// `jp.kamusoft` の取得元は、exclusiveContent で 1 つに固定する。リポジトリごとの絞り込み
// (content の include) だけでは、絞り込みを持たないほかのリポジトリも同じ group を探すので、
// 取得元に指定の版が無いときに、ほかのリポジトリにある版を黙って使う。exclusiveContent なら、
// 取得元に無い版は必ず解決の失敗になる。
//
// local の取得元に、既定の手元の Maven リポジトリ (mavenLocal()) は使わない。前の回の発行物が
// 残っていると、確かめたつもりの配布物と違うものをビルドするためである。
//
// 流し方は scripts/ci/verify-consumer-android.py が持つ。

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

val ksCollectionViewMode: String =
    settings.providers.gradleProperty("ksCollectionViewMode").orNull ?: "local"

require(ksCollectionViewMode == "local" || ksCollectionViewMode == "published") {
    "ksCollectionViewMode は local か published のどちらかにする: $ksCollectionViewMode"
}

val ksCollectionViewRepository: String? =
    settings.providers.gradleProperty("ksCollectionViewRepository").orNull?.takeIf { it.isNotBlank() }

if (ksCollectionViewMode == "local") {
    requireNotNull(ksCollectionViewRepository) {
        "ksCollectionViewMode が local のときは、発行物を置いた Maven リポジトリのディレクトリを " +
            "-PksCollectionViewRepository=<ディレクトリ> で渡す"
    }
    // 無いディレクトリを渡すと、Gradle は「発行物が見つからない」としか報告しない。
    // 場所の誤りを、発行物の欠けと区別できるようにする。
    require(file(ksCollectionViewRepository).isDirectory) {
        "ksCollectionViewRepository がディレクトリではない: $ksCollectionViewRepository"
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        exclusiveContent {
            forRepository {
                if (ksCollectionViewMode == "published") {
                    mavenCentral()
                } else {
                    maven {
                        name = "ksCollectionViewLocal"
                        url = uri(file(checkNotNull(ksCollectionViewRepository)))
                    }
                }
            }
            filter { includeGroup("jp.kamusoft") }
        }
        google()
        mavenCentral()
    }
    // AGP・Compose のプラグイン・コンパイル対象の SDK の版は、本体のバージョンカタログを
    // そのまま共有し、利用者役の側で二重に宣言しない。
    versionCatalogs {
        create("libs") {
            from(files("../../android/gradle/libs.versions.toml"))
        }
    }
}

rootProject.name = "kscollectionview-verification-android"

include(":app")
