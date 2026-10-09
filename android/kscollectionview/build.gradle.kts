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
    // Maven への発行 (発行物の構成・署名・Maven Central への送信)
    alias(libs.plugins.maven.publish)
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
    // 出力するバイトコードは Java 17 向けに固定する。ビルドを動かす JDK は 17 以上であればよい (android/ADR-0008)。
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

mavenPublishing {
    // 発行するのは release の 1 種類。sources jar を付ける。javadoc jar は Maven Central が
    // 求めるので置くが、中身は空にする (IDE は sources jar からコメントを表示できる)。
    configure(
        com.vanniktech.maven.publish.AndroidSingleVariantLibrary(
            javadocJar = com.vanniktech.maven.publish.JavadocJar.Empty(),
            sourcesJar = com.vanniktech.maven.publish.SourcesJar.Sources(),
            variant = "release",
        ),
    )

    // 送信先は Maven Central (Sonatype Central Portal)。認証の情報は Gradle のプロパティ
    // `mavenCentralUsername` / `mavenCentralPassword` で受け取る。
    publishToMavenCentral()

    // 発行物のそれぞれに署名を付ける。鍵は Gradle のプロパティ `signingInMemoryKey`
    // (必要なら `signingInMemoryKeyId` / `signingInMemoryKeyPassword`) で受け取る。
    // 鍵が無いときの扱いは下の signing の設定が決める。
    signAllPublications()

    pom {
        name.set("KsCollectionView")
        description.set(
            "A list and grid library for Jetpack Compose on Android, offering paging, " +
                "pull to refresh, grouping, and drag-and-drop reordering.",
        )
        inceptionYear.set("2026")
        url.set("https://github.com/kamusoft/KsCollectionView")

        licenses {
            license {
                name.set("MIT License")
                url.set("https://opensource.org/licenses/MIT")
                distribution.set("repo")
            }
        }

        developers {
            developer {
                id.set("kamusoft")
                name.set("kamusoft")
                url.set("https://github.com/kamusoft")
            }
        }

        scm {
            url.set("https://github.com/kamusoft/KsCollectionView")
            connection.set("scm:git:https://github.com/kamusoft/KsCollectionView.git")
            developerConnection.set("scm:git:ssh://git@github.com/kamusoft/KsCollectionView.git")
        }
    }
}

// 署名の鍵のプロパティが無いときは、署名を必須にしない。手元のディレクトリへの発行は、
// 鍵を持たない環境でも、開発中でない版でも行えるようにするためである。鍵なしで Maven Central へ
// 送ろうとした場合は、Maven Central の側が署名の無い発行物を受け付けない。
// (signing プラグインは発行のプラグインが適用するので、適用を待ってから拡張を設定する)
plugins.withId("signing") {
    extensions.configure<org.gradle.plugins.signing.SigningExtension> {
        setRequired(providers.gradleProperty("signingInMemoryKey").isPresent)
    }
}

// 開発中の版 (`-SNAPSHOT` で終わる版) を Maven Central へ送らない。
//
// 発行のプラグインは、版が `-SNAPSHOT` で終わるとき、送信先を Maven Central の snapshot の
// リポジトリへ向ける。認証の情報がある環境で送信のタスクを実行すると、開発中の版がそのまま
// 公開されるので、開発中の版のあいだは、送信のタスクを含むビルドを失敗させる。
// 手元への発行 (`publishToMavenLocal` など) は止めない。
//
// 対象はタスクの名前で決める。名前に `MavenCentral` を含むタスクをすべて対象にするのは、
// プラグインが送信のタスクを増やしたり名前を変えたりしたときに、列挙から漏れて素通りするのを
// 防ぐためである。`dropMavenCentralDeployment` だけは除く。誤って作った deployment を
// 取り下げる後始末のタスクで、送信の経路ではない。
//
// 止める場所は 2 つある。
// - 実行するタスクの集合が決まった時点: どのタスクも動き出す前に、理由を出力に出して止める。
//   認証の情報が無い環境では Gradle が認証の情報の不足も報告するが、その場合も理由は並んで出る。
// - 対象のタスクの実行の最初: 上の判定を通らずにタスクが動き出した場合の備え。
val publishingVersion = version.toString()

if (publishingVersion.endsWith("-SNAPSHOT")) {
    val sendingProject = project
    val refusal =
        "開発中の版 ($publishingVersion) は Maven Central へ送れない。" +
            "リリースの版を -Pversion=<版> で渡す。" +
            "手元で発行物を確かめるときは publishToMavenLocal を使う。"

    fun sendsToMavenCentral(taskName: String): Boolean =
        taskName.contains("MavenCentral") && taskName != "dropMavenCentralDeployment"

    gradle.taskGraph.whenReady {
        val blocked = allTasks.filter { it.project == sendingProject && sendsToMavenCentral(it.name) }
        if (blocked.isNotEmpty()) {
            throw GradleException("$refusal (対象のタスク: ${blocked.joinToString { it.path }})")
        }
    }

    tasks.configureEach {
        if (sendsToMavenCentral(name)) {
            doFirst { throw GradleException(refusal) }
        }
    }
}

dependencies {
    // ---- 公開 API に型が現れる依存 (利用者の compile classpath へ届くよう api で公開する) ----

    // Compose BOM。api 側に置き、versionless な Compose 依存の版を発行メタデータでも解決させる。
    api(platform(libs.compose.bom))

    // Compose Runtime。公開 DSL が `@Composable` ラムダを受け取る。
    api(libs.compose.runtime)

    // Compose UI。`listSeparatorColor` / `touchFeedbackColor` が Color を、
    // 公開 Composable が Modifier を受け取る。
    // Color (ui-graphics)・Dp (ui-unit) は別の成果物が持つが、ui が自分の利用者の
    // compile classpath へ届けるので、ここでは個別に宣言しない。
    api(libs.compose.ui)

    // Compose Foundation Layout。`contentPadding` が PaddingValues を受け取る。
    api(libs.compose.foundation.layout)

    // Coil (Compose 連携)。公開 API に Coil の型は出さないが、利用者が AsyncImage を直接使って
    // 同じローダーのキャッシュを共有する経路を前提にしているため、compile classpath へ届ける
    // (core/ADR-0012)。
    api(libs.coil.compose)

    // androidx.annotation。`KsImageSource.Resource` の引数に `@DrawableRes` が付く。
    api(libs.androidx.annotation)

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
