// KsCollectionView Android の利用者役 — :app モジュール
//
// 一覧を 1 つ表示するだけの最小のアプリ。本ライブラリへの依存は、利用者が書くのと同じ
// Maven の座標の 1 行だけで、どこから取るかは settings.gradle.kts が決める。
//
// リリースは、利用者のアプリと同じくコード縮小 (R8) を有効にして組み立てる。規則は Android の
// 既定の最適化の規則だけで、本ライブラリのための規則をここに書かない。ここに規則を足して
// 通すと、配布物の側に規則が足りないことが隠れる。

plugins {
    // Kotlin のコンパイルは Android Gradle Plugin の組み込み Kotlin が担うため、
    // Kotlin Android プラグインは適用しない (本体・Sample と同じ形)。
    alias(libs.plugins.android.application)
    // Compose Compiler プラグイン (Kotlin 2.0+ で必須)
    alias(libs.plugins.kotlin.compose)
}

// 取る版。渡されなければ、本体のバージョンカタログの版 (本体を版の指定なしで発行したときの版) を使う。
val ksCollectionViewVersion: String =
    providers.gradleProperty("ksCollectionViewVersion").orNull?.takeIf { it.isNotBlank() }
        ?: libs.versions.kscollectionview.get()

android {
    namespace = "jp.kamusoft.kscollectionview.verification.android"
    compileSdk = libs.versions.compile.sdk.get().toInt()

    defaultConfig {
        // 公開識別子の規約 (cross/ADR-0003) による、利用者役の application ID。
        applicationId = "jp.kamusoft.kscollectionview.verification.android"
        minSdk = 29
        targetSdk = libs.versions.compile.sdk.get().toInt()
        versionCode = 1
        versionName = "0.1.0"
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
            isMinifyEnabled = true
            // Android の既定の最適化の規則だけを使う。規則のファイルをほかに足さない。
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            // デバッグ用の鍵で署名を付ける。組み立てた APK を、手元で端末に入れて起動できるように
            // するためで、配るためのものではない。
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    sourceSets {
        named("main") {
            kotlin.directories += "src/main/kotlin"
        }
    }
}

kotlin {
    // 出力するバイトコードは Java 17 向けに固定する (本体・Sample と同じ)。
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    // 利用者が書くのと同じ 1 行。
    implementation("jp.kamusoft:kscollectionview:$ksCollectionViewVersion")

    // 行の文字を描く BasicText を持つ。版は、本ライブラリが届ける Compose の BOM が決める。
    // Compose の runtime・ui・foundation-layout は、本ライブラリの依存として届くものを使う。
    implementation(libs.compose.foundation)

    // setContent を持つ ComponentActivity。本体のバージョンカタログに無いので、版をここに書く。
    implementation("androidx.activity:activity-compose:1.11.0")
}
