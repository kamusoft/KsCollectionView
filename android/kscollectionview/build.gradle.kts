// kscollectionview: KsCollectionView Android 本体
//
// Compose Lazy 系の薄いラッパーを単一モジュールに収める (android/ADR-0002)。
// Maven 座標は `jp.kamusoft:kscollectionview` (cross/ADR-0003)。group / version は
// ルート build.gradle.kts が subprojects 一括で設定する。

plugins {
    // Kotlin のコンパイルは Android Gradle Plugin の組み込み Kotlin が担うため、
    // Kotlin Android プラグインは適用しない。
    alias(libs.plugins.android.library)
    // Compose Compiler プラグイン (Kotlin 2.0+ で必須)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "jp.kamusoft.kscollectionview"
    // コンパイル対象の SDK。版の宣言元は本体のバージョンカタログ 1 箇所。
    compileSdk = libs.versions.compile.sdk.get().toInt()

    defaultConfig {
        minSdk = 29
        // 実機で走らせる計測用テスト (instrumented test) の実行係。
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

    // Kotlin ソースルートは Android Library 既定の `src/main/java` ではなく
    // `src/main/kotlin` / `src/test/kotlin` とする (android/ADR-0002)。
    sourceSets {
        named("main") {
            kotlin.directories += "src/main/kotlin"
        }
        named("test") {
            kotlin.directories += "src/test/kotlin"
        }
        named("androidTest") {
            kotlin.directories += "src/androidTest/kotlin"
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
}

kotlin {
    // 公開面は visibility と型を明示した宣言だけで構成する (android/ADR-0002)。
    explicitApi()
    jvmToolchain(17)
}

dependencies {
    // ---- 公開 API に型が現れる依存 (利用者の compile classpath へ届くよう api で公開する) ----

    // Compose BOM。api 側に置き、versionless な Compose 依存の版を発行メタデータでも解決させる。
    api(platform(libs.compose.bom))

    // Compose Runtime。公開 DSL が `@Composable` ラムダを受け取る。
    api(libs.compose.runtime)

    // Compose UI。`listSeparatorColor` / `touchFeedbackColor` が Color を、
    // 公開 Composable が Modifier を受け取る。
    api(libs.compose.ui)

    // Compose Foundation Layout。`contentPadding` が PaddingValues を受け取る。
    api(libs.compose.foundation.layout)

    // Coil (Compose 連携)。公開 API に Coil の型は出さないが、利用者が AsyncImage を直接使って
    // 同じローダーのキャッシュを共有する経路を前提にしているため、compile classpath へ届ける
    // (core/ADR-0012)。
    api(libs.coil.compose)

    // ---- 実装内部でのみ使う依存 ----

    // Compose Foundation。LazyVerticalGrid / GridCells / combinedClickable を使う。
    implementation(libs.compose.foundation)

    // Compose Animation Core。行の高さ変化の補間 (`Animatable`) に使う。
    implementation(libs.compose.animation.core)

    // Compose Animation。次のページの読み込み中の表示の出入りのフェード (`AnimatedVisibility`) に使う。
    // Compose Foundation が推移で持ち込んでいる版と同じもの (BOM が決める) を明示依存にする。
    implementation(libs.compose.animation)

    // Material 3。タップフィードバックの既定を標準 ripple にするために使う。
    implementation(libs.compose.material3)

    // androidx App Startup。アプリケーションのコンテキストを起動時に捕捉する Initializer で使う。
    // 公開面には現れないので implementation で置く。
    implementation(libs.startup.runtime)

    // Coil のネットワーク取得 (OkHttp)。ServiceLoader で自動登録されるため、利用者が
    // fetcher を選ぶ必要はない。公開面には現れないので implementation で置く。
    implementation(libs.coil.network.okhttp)

    // ---- テスト専用依存 ----

    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.androidx.test.ext.junit)

    // Compose UI Test (Robolectric バックエンドで createComposeRule を動かす)
    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test.junit4)

    // テスト実行時の Activity (ComponentActivity) の AndroidManifest を供給する。
    // テスト専用の configuration に置き、発行物へ混入させない。
    testImplementation(libs.compose.ui.test.manifest)

    // ---- 実機で走らせるテスト専用依存 ----
    //
    // 端末のデコードが選ぶ画素の構成は JVM 上のテスト環境では再現しないため、その分岐は
    // 実機で走るテストでしか検証層に載らない。
    androidTestImplementation(libs.junit)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
}
