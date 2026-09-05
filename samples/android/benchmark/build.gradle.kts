// KsCollectionView Android Sample — :benchmark モジュール
//
// Macrobenchmark で :app の「大量件数」の土俵を計測する。人の操作を挟まずに固定手順を
// 再実行できることが目的で、配布物には含まれない。

plugins {
    // Android Gradle Plugin に同梱される計測モジュール用のプラグイン。版はルートの
    // build.gradle.kts が classpath に載せたものを使う。
    id("com.android.test")
}

android {
    namespace = "jp.kamusoft.kscollectionview.samples.android.benchmark"
    // コンパイル対象の SDK。版の宣言元は本体のバージョンカタログ 1 箇所。
    compileSdk = libs.versions.compile.sdk.get().toInt()

    defaultConfig {
        // Macrobenchmark は計測対象の別プロセスを観測するため、24 以上が要る。
        minSdk = 29
        targetSdk = libs.versions.compile.sdk.get().toInt()
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        // 計測は release と同じ最適化のビルドに対して行う。計測アプリ側は実機で走らせる
        // ためだけのもので、debug 鍵で署名する。
        create("benchmark") {
            isDebuggable = true
            signingConfig = signingConfigs.getByName("debug")
            matchingFallbacks += "release"
        }
    }

    sourceSets {
        named("main") {
            kotlin.directories += "src/main/kotlin"
        }
    }

    targetProjectPath = ":app"
    experimentalProperties["android.experimental.self-instrumenting"] = true
}

kotlin {
    jvmToolchain(17)
}

// 計測は benchmark 構成だけで行う。debug / release の変種は作らない。
androidComponents {
    beforeVariants {
        it.enable = it.buildType == "benchmark"
    }
}

dependencies {
    implementation(libs.junit)
    implementation(libs.androidx.test.ext.junit)
    implementation(sampleLibs.androidx.test.runner)
    implementation(sampleLibs.uiautomator)
    implementation(sampleLibs.benchmark.macro.junit4)
}
