// KsCollectionView Android Sample — :app モジュール
//
// 役割:
//   - デモ画面と Android 固有の検証画面のルートメニューと遷移 (Navigation Compose)
//   - 本体 KsCollectionView を利用者と同じ配布座標 1 行の依存で使う
//   - 計測用の入口 (素の LazyVerticalGrid による比較対象画面) を release 以外に同梱する

plugins {
    // Kotlin のコンパイルは Android Gradle Plugin の組み込み Kotlin が担うため、
    // Kotlin Android プラグインは適用しない (本体モジュールと同じ形)。
    alias(libs.plugins.android.application)
    // Compose Compiler プラグイン (Kotlin 2.0+ で必須)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "jp.kamusoft.kscollectionview.samples.android"
    // コンパイル対象の SDK。版の宣言元は本体のバージョンカタログ 1 箇所。
    compileSdk = libs.versions.compile.sdk.get().toInt()

    defaultConfig {
        // 公開識別子の規約 (cross/ADR-0003) による Sample の application ID。
        applicationId = "jp.kamusoft.kscollectionview.samples.android"
        minSdk = 29
        targetSdk = libs.versions.compile.sdk.get().toInt()
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = false
    }

    buildTypes {
        named("release") {
            isMinifyEnabled = false
            // Sample のため署名構成は割り当てない (debug 鍵で署名される)。
        }
        // 計測専用の構成。Macrobenchmark は計測対象がデバッグ可能でないことを求めるため、
        // release と同じ最適化のまま profileable にしたビルドを別に用意する。
        create("benchmark") {
            initWith(buildTypes.getByName("release"))
            signingConfig = signingConfigs.getByName("debug")
            isDebuggable = false
            isProfileable = true
            matchingFallbacks += "release"
        }
    }

    testOptions {
        unitTests {
            // Robolectric は Android リソース・Resources 系 API を要求するため有効化
            isIncludeAndroidResources = true

            all {
                // Compose の描画結果を検証するテストが実 Skia を使うため、
                // 既定より広いヒープを与える。
                it.maxHeapSize = "2g"
            }
        }
    }

    // Kotlin ソースルートは `src/<構成>/kotlin` に揃える (本体モジュールと同じ形)。
    //
    // 計測用の画面と計数の仕組みは構成ごとに実体を差し替える。
    //   - measurement / noMeasurement: 比較対象画面と、その画面への入口の登録
    //   - counterEnabled / counterDisabled: テンプレート呼び出しと読み込み中スロットの
    //     計数の実体と空実装
    // release にはどちらも空実装だけが入り、計測用のコードは含まれない。
    //
    // unit test は全構成共通の `src/test` に加えて debug 専用の `src/testDebug` を持つ。
    // 計数の実体 (counterEnabled) を前提にするテストは後者に置き、置き場が前提を表すようにする。
    sourceSets {
        named("main") {
            kotlin.directories += "src/main/kotlin"
        }
        named("test") {
            kotlin.directories += "src/test/kotlin"
        }
        named("testDebug") {
            kotlin.directories += "src/testDebug/kotlin"
        }
        named("debug") {
            kotlin.directories += "src/measurement/kotlin"
            kotlin.directories += "src/counterEnabled/kotlin"
        }
        named("benchmark") {
            kotlin.directories += "src/measurement/kotlin"
            kotlin.directories += "src/counterDisabled/kotlin"
        }
        named("release") {
            kotlin.directories += "src/noMeasurement/kotlin"
            kotlin.directories += "src/counterDisabled/kotlin"
        }
    }
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    // KsCollectionView 本体。settings.gradle.kts の composite build と明示置換により、
    // この 1 行 (利用者が書くものと同じ) がソース参照へ置き換わる。版は本体と共有する
    // バージョンカタログから取り、本体の version と必ず一致させる。
    implementation("jp.kamusoft:kscollectionview:${libs.versions.kscollectionview.get()}")

    // Compose (版は BOM が揃える)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.runtime)
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)

    // setContent を持つ ComponentActivity
    implementation(sampleLibs.activity.compose)

    // 画面遷移
    implementation(libs.navigation.compose)

    // ---- テスト専用依存 ----
    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.androidx.test.ext.junit)

    // Compose UI Test (Robolectric バックエンドで createComposeRule を動かす)
    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test.junit4)

    // テスト実行時の Activity (ComponentActivity) の AndroidManifest を供給する。
    // アプリのマニフェスト併合を経由して届ける必要があるため debug 構成に置く
    // (release の配布物には含まれない)。
    debugImplementation(libs.compose.ui.test.manifest)
}
