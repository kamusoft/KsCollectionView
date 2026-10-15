# 証跡: Android の公開の設定 (tasks 3.1〜3.5)

実施日: 2026-10-09。環境: macOS 27.0、JDK 21.0.12 (Microsoft の OpenJDK)、Gradle 9.7.0 (wrapper)、AGP 9.4.0、Kotlin 2.4.10 (AGP の組み込み)、`com.vanniktech.maven.publish` 0.37.0、Android SDK Platform 36・Build-Tools 36.0.0。

生ログの全文は手元保管で、ここには要約行だけを書く。コマンドは `android/` で流した (Sample のテストだけ `samples/android/`)。

- Android SDK の場所は、どの実行でも `ANDROID_HOME=<Android SDK の場所>` を前置きして渡した。この前置きは、下のコマンドの表記では省いている
- 発行先は、リポジトリの外の作業用のディレクトリにした。手元への発行のタスクに、Maven の手元のリポジトリの場所を上書きするシステムプロパティを `-D` で渡すと、発行先がそのディレクトリに変わる。下のコマンドでは、この指定を `<発行先の指定>` と書く
- システムプロパティの名前は、`maven.repo` の後ろに `.local` を続けたものである。続けて書くと、識別の lint (`scripts/identity-lint.py`) がホスト名と判定して書き込みを止めるので、この文書では分けて書いている
- 認証の情報 (`mavenCentralUsername`・`mavenCentralPassword`) は、どの実行でも渡していない。環境変数と利用者の Gradle の設定にも、認証の情報と署名の鍵の名前を持つ行が無いことを、行の数 (0) で確かめてから始めた
- Maven Central への送信は 1 回も行っていない (下の 3.2 のとおり、どのタスクも動き出す前に止まった)

## 3.1 足した設定

| ファイル | 足したもの |
|---|---|
| `android/gradle/libs.versions.toml` | プラグインの版 `maven-publish = "0.37.0"` と、プラグインの別名 `maven-publish` |
| `android/kscollectionview/build.gradle.kts` | プラグインの適用、`mavenPublishing` (release の 1 種類・sources jar・空の javadoc jar・送信先・署名・POM)、署名を必須にする条件、開発中の版の歯止め |

ルートの `android/build.gradle.kts` (`group` と `version` の決め方) と、`dependencies` の宣言は変えていない (足したのは Compose UI の依存の上のコメント 2 行だけ)。これは最初の実装の時点の記録である。その後の修正サイクルで、`androidx.annotation` の宣言を 1 つ足した (下の「修正サイクル 1」)。

プラグインが足した発行のタスク (`./gradlew :kscollectionview:tasks --all` から):

```
dropMavenCentralDeployment
enableAutomaticMavenCentralPublishing
generateMetadataFileForMavenPublication
generatePomFileForMavenPublication
prepareMavenCentralPublishing
publish
publishAllPublicationsToMavenCentralRepository
publishAndReleaseToMavenCentral
publishMavenPublicationToMavenCentralRepository
publishMavenPublicationToMavenLocal
publishToMavenCentral
publishToMavenLocal
signMavenPublication
```

## 3.2 開発中の版を Maven Central へ送らない

版は既定の `0.1.0-SNAPSHOT` のまま、認証の情報を渡さずに、送信に至る 3 つのタスクを実際に実行した (空実行ではない)。

| コマンド | 結果 | 動いたタスク |
|---|---|---|
| `./gradlew :kscollectionview:publishToMavenCentral` | `BUILD FAILED` (1 秒未満) | 0 |
| `./gradlew :kscollectionview:publishAndReleaseToMavenCentral` | `BUILD FAILED` (1 秒未満) | 0 |
| `./gradlew :kscollectionview:publish` | `BUILD FAILED` (1 秒未満) | 0 |

「動いたタスク 0」は、出力に `> Task` の行が 1 つも無いことで確かめた。ビルドは、実行するタスクの集合が決まった時点で止まっている。

`publishToMavenCentral` の出力 (空行を除く。ほかの 2 つは、対象のタスクの一覧だけが違う):

```
* What went wrong:
Failed to notify task execution graph listener.
> Credentials required for this build could not be resolved.
   > The following Gradle properties are missing for 'mavenCentral' credentials:
       - mavenCentralUsername
       - mavenCentralPassword
> 開発中の版 (0.1.0-SNAPSHOT) は Maven Central へ送れない。リリースの版を -Pversion=<版> で渡す。手元で発行物を確かめるときは publishToMavenLocal を使う。 (対象のタスク: :kscollectionview:prepareMavenCentralPublishing, :kscollectionview:publishMavenPublicationToMavenCentralRepository, :kscollectionview:publishAllPublicationsToMavenCentralRepository, :kscollectionview:publishToMavenCentral)
```

読み方:

- 認証の情報が無いと、Gradle 自身も、同じ時点で認証の情報の不足を報告する。2 つの理由は並んで出る
- この Gradle の報告があるので、歯止めを「対象のタスクの実行の最初で失敗させる」だけにすると、認証の情報の無い環境ではタスクの実行まで進まず、開発中の版は送れないという理由が出力に出ない (最初にその形で試して確かめた)。そこで、実行するタスクの集合が決まった時点でも判定する形にした。タスクの実行の最初の判定は、備えとして残してある

歯止めが 2 つとも効いていることと、開発中でない版では止めないことの確認:

| 確かめたこと | やり方 | 結果 |
|---|---|---|
| タスクの実行の最初の判定が、単独でも止める | リポジトリの外に `android/` の写しを作り、写しの側でだけ 1 つ目の判定を外して、`./gradlew --offline :kscollectionview:prepareMavenCentralPublishing` を流した (このタスクは認証の情報を要らない)。写しは確認の後に消した | `> Task :kscollectionview:prepareMavenCentralPublishing FAILED` で、同じ理由の文が出た |
| 開発中でない版では、歯止めが掛からない | `./gradlew -m -Pversion=9.9.9 :kscollectionview:publishToMavenCentral` (空実行。タスクは動かさない) | `BUILD SUCCESSFUL`。歯止めの文は出ない |
| 開発中の版でも、手元には発行できる | 下の 3.4 の 1 つ目 (版は `0.1.0-SNAPSHOT`) | 成功 |

確かめていないこと: 開発中でない版と本物の認証の情報を渡したときの、実際の送信 (本変更では行わない)。

## 3.3 公開 API に現れる外部の型と、依存の範囲の突き合わせ

### 洗い出し方

発行した AAR (下の 3.4 の 1 つ目) と、本体のソースの両方から洗った。片方だけでは漏れるためである。

| 見たもの | やり方 | この見方で拾えないもの |
|---|---|---|
| ソース (`android/kscollectionview/src/main/kotlin`) | `public`・`protected` の付いた宣言 (74 個。囲む型がすべて公開のもの) の文面から型の名前を取り、そのファイルの import で完全な名前に直す。前の行の注釈も含める | 型の推論で決まる戻り値の型 (公開の宣言は型を明示する設定なので、該当は無い) |
| バイトコード (AAR の `classes.jar`) | 公開の型 32 個と、公開のトップレベルの関数を持つ 3 つのクラスを `javap` で読み、公開・protected のメンバーの宣言と総称の署名から型の名前を取る。名前にモジュール名の付いたメンバー (internal) は除く | 値クラス (`Dp`・`Color`)。バイトコードでは基本の型に置き換わる |

ソースの側の 74 個は、同じ条件の `grep` の行の数と一致した。バイトコードの側は、公開の型 32 個のクラスファイルがすべて見つかった。

### 洗い出した外部の型

本ライブラリ自身の型 (`jp.kamusoft.kscollectionview.*`) を除く。

| 型 | 現れる場所 (代表) | 型を持つ成果物 |
|---|---|---|
| `androidx.compose.runtime.Composable` (注釈) | `KsCollectionView`・`KsImage`・`KsPaging` などの 15 個の宣言 | `androidx.compose.runtime:runtime` |
| `androidx.compose.runtime.Composer` | 上の `@Composable` の宣言をコンパイルした結果の引数 (ソースには現れない) | `androidx.compose.runtime:runtime` |
| `androidx.compose.ui.Modifier` | `KsCollectionView`・`KsImage` (2 つ) の引数 | `androidx.compose.ui:ui` |
| `androidx.compose.ui.graphics.Color` | `KsCollectionView` の引数 | `androidx.compose.ui:ui-graphics` |
| `androidx.compose.ui.unit.Dp` | `KsLayout.List`・`KsLayout.Grid`・`KsColumns.Adaptive`・`KsWidth.Fixed` などの 7 個の宣言 | `androidx.compose.ui:ui-unit` |
| `androidx.compose.foundation.layout.PaddingValues` | `KsCollectionView` の引数 | `androidx.compose.foundation:foundation-layout` |
| `androidx.annotation.DrawableRes` (注釈) | `KsImageSource.Resource` の引数 | `androidx.annotation:annotation` |
| `java.io.File` | `KsImageSource.File` | JDK (依存の宣言は要らない) |
| `kotlin.*` (関数の型・`Unit`・`Continuation`・列挙の一覧など) | 多数 | `org.jetbrains.kotlin:kotlin-stdlib` |

Android SDK の型 (`android.*`) は、公開の宣言に現れなかった。Coil の型 (`coil3.*`) も現れなかった。

### POM との突き合わせ

この小節と次の「判定」は、修正サイクル 1 で `androidx.annotation` の宣言を足した後の状態に直してある。直す前の値と、足したときに確かめたことは、下の「修正サイクル 1」に書いた。洗い出した外部の型の表 (上) は変わらない。

発行した POM (`0.1.0-SNAPSHOT`) の依存:

| 範囲 | 依存 |
|---|---|
| 依存の管理 (import) | `androidx.compose:compose-bom:2026.06.01` |
| compile | `androidx.compose.runtime:runtime`・`androidx.compose.ui:ui`・`androidx.compose.foundation:foundation-layout`・`io.coil-kt.coil3:coil-compose:3.5.0`・`androidx.annotation:annotation:1.9.1`・`org.jetbrains.kotlin:kotlin-stdlib:2.4.10` |
| runtime | `androidx.compose.foundation:foundation`・`androidx.compose.animation:animation-core`・`androidx.compose.animation:animation`・`androidx.compose.material3:material3`・`androidx.startup:startup-runtime:1.1.1`・`io.coil-kt.coil3:coil-network-okhttp:3.5.0` |

Gradle のメタデータ (`.module`) の API の側の依存も、POM の compile と同じ 6 つに BOM を足したものだった。`kotlin-stdlib` は、ビルドファイルに宣言が無く、Kotlin のビルドの仕組みが compile の範囲に足している。

型を持つ成果物ごとの結果:

| 型を持つ成果物 | POM での扱い | 利用側の compile のクラスパス |
|---|---|---|
| `androidx.compose.runtime:runtime` | compile に直接ある | ある (1.11.4) |
| `androidx.compose.ui:ui` | compile に直接ある | ある (1.11.4) |
| `androidx.compose.foundation:foundation-layout` | compile に直接ある | ある (1.11.4) |
| `org.jetbrains.kotlin:kotlin-stdlib` | compile に直接ある | ある (2.4.10) |
| `androidx.compose.ui:ui-graphics` | 直接は無い。compile にある `ui` が、自分の API の依存として届ける (`ui` から 2 段) | ある (1.11.4) |
| `androidx.compose.ui:ui-unit` | 直接は無い。同じく `ui` が届ける (2 段) | ある (1.11.4) |
| `androidx.annotation:annotation` | compile に直接ある (版 1.9.1)。`ui` と `foundation-layout` からも届く | ある (1.9.1) |

「利用側の compile のクラスパス」の列は、最初の実装の時点で測った値である (`androidx.annotation` の行の版は、修正サイクル 1 で利用者役の compile のクラスパスから読み直し、同じ 1.9.1 だった)。測り方: リポジトリの外に使い捨ての Android のライブラリのプロジェクトを作って確かめた。`jp.kamusoft` の取得元を作業用の発行先だけに固定し、`jp.kamusoft:kscollectionview:0.1.0-SNAPSHOT` の 1 行だけに依存させ、リリースの compile のクラスパスに載る jar (36 個) の中から、上の型のクラスファイルを引いた。上の表の外部の型は、すべて compile のクラスパスの jar の中に見つかった。runtime のクラスパスにだけあって compile のクラスパスに無い型は、無かった。

「`ui` から 2 段」は、利用側の compile の依存の木から数えた (`ui` → `ui-android` → `ui-graphics` など。1 段目は、Kotlin Multiplatform の入口から Android 向けの実体への切り替え)。

### 判定

- 公開 API の宣言に現れる外部の型は、すべて利用者の compile の範囲に届いている。届かない型は無い
- `@DrawableRes` を持つ `androidx.annotation:annotation` は、POM の compile の範囲に、版 1.9.1 で直接ある (修正サイクル 1 で足した)
- `Color` を持つ `ui-graphics` と `Dp` を持つ `ui-unit` は、POM に名前では現れず、compile にある `ui` を通って届く。この 2 つは直接は宣言しない。spec の文面 (型を持つ依存を compile の範囲で宣言する) との差で、合意済みの乖離として `deviation.md` に記録がある (兄弟ライブラリ KsSettingsView と宣言の形を揃える)
- Coil の Compose 連携 (`coil-compose`) は compile にあり、Compose の BOM は依存の管理に入っている
- runtime の 6 つの依存が持つ型は、公開の宣言に現れない
- compile の範囲の依存は、公開の設定を足す前のビルドファイルの `api` の宣言 (BOM・runtime・ui・foundation-layout・coil-compose) に、`androidx.annotation` を足したものである。runtime の範囲へ動いたものは無い

## 3.4 手元のディレクトリへの発行

3 つの形と、追加の 1 つを流した。発行先は形ごとに別のディレクトリにした。

| 形 | コマンド | 結果 | 署名のタスク |
|---|---|---|---|
| 鍵なし (版は既定) | `./gradlew <発行先の指定> :kscollectionview:publishToMavenLocal` | `BUILD SUCCESSFUL` | `signMavenPublication SKIPPED` |
| 版を外から渡す (鍵なし) | 上に `-Pversion=0.0.1-check` を足す | `BUILD SUCCESSFUL` | `signMavenPublication SKIPPED` |
| 使い捨ての鍵を渡す (版は `-Pversion=0.0.2-signed`) | 鍵を環境変数 `ORG_GRADLE_PROJECT_signingInMemoryKey` で渡す | `BUILD SUCCESSFUL` | `signMavenPublication` が実行された |
| (追加) 使い捨ての鍵を渡す (版は既定の `0.1.0-SNAPSHOT`) | 同上 (`-Pversion` なし) | `BUILD SUCCESSFUL` | `signMavenPublication` が実行された |

### 発行物の一覧

座標の場所 `<発行先>/jp/kamusoft/kscollectionview/<版>/` にできたファイル:

| 形 | 版のディレクトリ | ファイル |
|---|---|---|
| 鍵なし | `0.1.0-SNAPSHOT` | `.aar`・`-sources.jar`・`-javadoc.jar`・`.pom`・`.module` の 5 点と、`maven-metadata-local.xml`。`.asc` は無い |
| 版を外から渡す | `0.0.1-check` | `.aar`・`-sources.jar`・`-javadoc.jar`・`.pom`・`.module` の 5 点。`.asc` は無い |
| 使い捨ての鍵 | `0.0.2-signed` | 上の 5 点と、5 点それぞれの `.asc` (計 10) |
| (追加) 使い捨ての鍵・既定の版 | `0.1.0-SNAPSHOT` | 上の 5 点と、5 点それぞれの `.asc`、`maven-metadata-local.xml` |

ファイルの名前は、どれも `kscollectionview-<版>` で始まる。`<発行先>/jp/kamusoft/kscollectionview/` の直下には、ほかに `maven-metadata-local.xml` ができる。

中身:

| 発行物 | 確かめたこと |
|---|---|
| AAR (約 449 KB) | 中は `AndroidManifest.xml`・`classes.jar`・`R.txt` (空)・`META-INF/com/android/build/gradle/aar-metadata.properties` の 4 つ。コード縮小の規則のファイル (`proguard.txt`) は無い。鍵なし・版を外から渡す・使い捨ての鍵の 3 つの形の AAR は、SHA-256 が同じだった (版と鍵で中身が変わらない) |
| sources jar (約 132 KB) | 52 のエントリ |
| javadoc jar (261 バイト) | `META-INF/MANIFEST.MF` だけ (中身は空) |
| Gradle のメタデータ | variant は 3 つ (API・実行時・ソース)。release の 1 種類だけである |

### POM の項目

鍵なしの形の POM から:

| 項目 | 値 |
|---|---|
| 座標 | `jp.kamusoft` / `kscollectionview` / `0.1.0-SNAPSHOT`、packaging は `aar` |
| 名前 | `KsCollectionView` |
| 説明 | `A list and grid library for Jetpack Compose on Android, offering paging, pull to refresh, grouping, and drag-and-drop reordering.` |
| URL | `https://github.com/kamusoft/KsCollectionView` |
| 開始年 | `2026` |
| ライセンス | `MIT License` / `https://opensource.org/licenses/MIT` / `repo` |
| 開発者 | id `kamusoft`・名前 `kamusoft`・`https://github.com/kamusoft` |
| リポジトリの場所 | 画面で開く URL は `https://github.com/kamusoft/KsCollectionView`。読み取りの接続は `scm:git:https://github.com/kamusoft/KsCollectionView.git`。開発者の接続は、同じリポジトリを `scm:git:ssh://` で指す GitHub の SSH の URL |

版を外から渡した形の POM は、版が `0.0.1-check` になっていた。依存は 3.3 の表のとおり。

説明の文は、ルートの `README.md` の最初の段落を Android 向けに縮めたものである。

### 使い捨ての鍵の扱い

- 鍵は、リポジトリの外の一時のディレクトリを GnuPG の鍵束の場所 (`GNUPGHOME`) にして作った。利用者の既定の鍵束は使っていない (既定の鍵束に、作った鍵の名前が無いことを確かめた)
- 鍵は、署名だけができる RSA 2048 ビット・パスフレーズなし・有効期間 1 日のものである
- 鍵は環境変数で Gradle に渡した。コマンドの引数にも、記録にも、鍵の中身は出していない (手元の記録に、秘密鍵の見出しの行が無いことを確かめた)
- 署名は、同じ鍵束の公開鍵で 5 つとも検証できた (`gpg --verify`)
- 確認の後に、鍵束のディレクトリごと `trash` で消した。鍵束のための常駐のプロセスも止めた
- 鍵束の場所について: GnuPG は鍵束の場所の下にソケットを作り、パスが長いと鍵を作れない (最初に長いパスで試して失敗した。その回は鍵ができていない)。短いパスの一時のディレクトリに作り直した

### 既定の手元の Maven リポジトリ

どの実行の後も、既定の手元の Maven リポジトリ (`~/.m2/repository`) の `jp/kamusoft/` の下に `kscollectionview` は増えていなかった (実行の前後で、一覧が同じ)。

## 3.5 Android のテスト

公開の設定を足した状態で、絞り込みなしで流した。件数は、結果の XML (`build/test-results/testDebugUnitTest/TEST-*.xml`) の集計である。

| 系統 | コマンド (作業ディレクトリ) | クラス | 実行 | 失敗 | エラー | スキップ | 所要 (差分ビルド込み) |
|---|---|---:|---:|---:|---:|---:|---|
| Android 本体 | `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` (`android/`) | 31 | 512 | 0 | 0 | 0 | 25 秒 |
| Android Sample | `./gradlew :app:testDebugUnitTest --rerun-tasks` (`samples/android/`) | 21 | 163 | 0 | 0 | 0 | 15 秒 |

- 件数とクラスの数は、公開の設定を足す前の記録 (`kasane/handbook/cross/verification-ci.md` の「件数の読み方」: 本体 512・31 クラス、Sample 163・21 クラス) と同じである
- Sample は、本体のビルドを取り込んでいる (ソースで参照する) ので、本体に足したプラグインの設定は Sample のビルドでも評価される。Sample のビルドも通った

## 標準の lint とスクリプトのテスト

| コマンド | 結果 |
|---|---|
| `python3 scripts/local-path-lint.py` | 終了コード 0 |
| `python3 scripts/identity-lint.py` | 終了コード 0 |
| `python3 scripts/comment-policy-lint.py` | 禁止 0 件 (検査対象 494 ファイル) |
| `python3 scripts/ci/run-tests.py` | 実行 139 件 / 失敗 0 件 / スキップ 0 件 |
| `python3 scripts/ci/check-workflows.py` | 違反は無い |

テスト・手元への発行 (鍵なし・既定の版)・開発中の版の歯止めは、ビルドファイルの最後の編集 (コメントの追記) の後に流し直した。上の 3.5 の件数と所要は、その流し直しの値である (1 回目は本体 22 秒・Sample 21 秒で、件数は同じ)。

## 修正サイクル 1 (review-001.md の指摘 1): `androidx.annotation` を直接宣言した

実施日: 2026-10-09。環境と、コマンドの前置き・発行先の指定の書き方は、冒頭と同じである。認証の情報と署名の鍵は渡していない。Maven Central への送信は行っていない。

### 変えたこと

オーナーの決定 (`deviation.md`) に従い、兄弟ライブラリ KsSettingsView (`../KsSettingsView/android/kssettingsview/build.gradle.kts`) と同じ形にした。

| ファイル | 変えたこと |
|---|---|
| `android/gradle/libs.versions.toml` | 版 `androidx-annotation = "1.9.1"` と、ライブラリの別名 `androidx-annotation` (`androidx.annotation:annotation`) を足した。版を書くのは、ここの 1 箇所だけである |
| `android/kscollectionview/build.gradle.kts` | 「公開 API に型が現れる依存」の節に `api(libs.androidx.annotation)` を足した。Compose UI の依存の上のコメントを、`Color`・`Dp` だけを `ui` に任せる文に直した |

`ui-graphics` と `ui-unit` は足していない。

### 発行した POM (宣言を足した後)

`./gradlew <発行先の指定> :kscollectionview:publishToMavenLocal` (鍵なし・版は既定) は `BUILD SUCCESSFUL`、`signMavenPublication SKIPPED`。座標の場所のファイルは、3.4 の「鍵なし」と同じ 5 点と `maven-metadata-local.xml` だった。

POM に増えた行 (ほかの `<dependency>` は増減なし):

```
<dependency>
  <groupId>androidx.annotation</groupId>
  <artifactId>annotation</artifactId>
  <version>1.9.1</version>
  <scope>compile</scope>
</dependency>
```

POM の依存を、範囲ごとに読み直した結果:

| 範囲 | 依存 | 足す前との差 |
|---|---|---|
| 依存の管理 (import) | `androidx.compose:compose-bom:2026.06.01` | 無い |
| compile | `androidx.compose.runtime:runtime`・`androidx.compose.ui:ui`・`androidx.compose.foundation:foundation-layout`・`io.coil-kt.coil3:coil-compose:3.5.0`・`androidx.annotation:annotation:1.9.1`・`org.jetbrains.kotlin:kotlin-stdlib:2.4.10` | `androidx.annotation:annotation:1.9.1` が増えた。ほかの 5 つは同じ |
| runtime | `androidx.compose.foundation:foundation`・`androidx.compose.animation:animation-core`・`androidx.compose.animation:animation`・`androidx.compose.material3:material3`・`androidx.startup:startup-runtime:1.1.1`・`io.coil-kt.coil3:coil-network-okhttp:3.5.0` | 無い |

- Gradle のメタデータ (`.module`) の API の側の依存は、BOM と上の compile の 6 つで、`androidx.annotation:annotation` の求める版は 1.9.1 だった。実行時の側は、runtime の 6 つに API の側を足したものである
- 足す前の値は、最初の実装の記録 (compile は 5 つで、`androidx.annotation` は無い) と、下の「足す前の形との比較」で作り直した POM (`androidx.annotation` の出現は 0 行) の 2 つで確かめた

### 足す前の形との比較

足す前の形は、リポジトリの外に `android/` の写し (ビルドの出力と `local.properties` を除く) を作り、写しの側でだけ、足した別名と `api` の 1 行を外して、別の作業用の発行先へ発行して作った。作業ツリーは戻していない。写しと発行先は、確認の後に消した。

| 比べたもの | 結果 |
|---|---|
| AAR の SHA-256 | 足す前と後で同じ (本体の中身は変わらない) |
| 利用者役 (`verification/android`) の `:app:dependencies --configuration releaseCompileClasspath` | 差は 1 行だけ。本ライブラリの直下に `androidx.annotation:annotation:1.9.1 (*)` が増えた。ほかの行と、解決された版は同じ |
| 同じく `--configuration releaseRuntimeClasspath` | 差は 1 行だけ。本ライブラリの直下に `androidx.annotation:annotation:1.9.1 -> 1.10.0 (*)` が増えた。ほかの行と、解決された版は同じ |

利用側に届く `androidx.annotation:annotation` の版:

| クラスパス | 足す前 | 足した後 |
|---|---|---|
| 利用者役の compile (`releaseCompileClasspath`) | 1.9.1 | 1.9.1 |
| 利用者役の実行時 (`releaseRuntimeClasspath`) | 1.10.0 | 1.10.0 |

- compile の側は、求められている版の最大が 1.9.1 (Compose UI の先にある lifecycle・savedstate など) で、本ライブラリの宣言 (1.9.1) はそれを上げも下げもしない
- 実行時の側の 1.10.0 は、本ライブラリが runtime の範囲で届けている Coil の OkHttp 連携の先 (`coil-core-android:3.5.0`) が求めている版である。足す前から 1.10.0 に解決されていて、本ライブラリの宣言 (1.9.1) はこの結果を変えない
- `ui-graphics`・`ui-unit` は、利用者役の compile のクラスパスに 1.11.4 で届いている (足す前と同じ)
- 3.3 の表の「利用側の compile のクラスパス」は、本ライブラリだけに依存する使い捨てのライブラリのプロジェクトで測った値である。今回は、その使い捨てのプロジェクトは作り直さず、利用者役 (本ライブラリのほかに `foundation` と `activity-compose` に依存する) で読んだ

### 利用者役の確認

`python3 scripts/ci/verify-consumer-android.py --mode local` は終了コード 0。本体の発行・利用者役のリリースの組み立て (コード縮小あり)・実行時の依存の確認が、どれも成功した (組み立ては `BUILD SUCCESSFUL in 17s`)。

### テストと lint

絞り込みなしで流した。件数は結果の XML の集計である。

| 系統 | コマンド (作業ディレクトリ) | クラス | 実行 | 失敗 | エラー | スキップ | 所要 (差分ビルド込み) |
|---|---|---:|---:|---:|---:|---:|---|
| Android 本体 | `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` (`android/`) | 31 | 512 | 0 | 0 | 0 | 21 秒 |
| Android Sample | `./gradlew :app:testDebugUnitTest --rerun-tasks` (`samples/android/`) | 21 | 163 | 0 | 0 | 0 | 16 秒 |

| コマンド | 結果 |
|---|---|
| `python3 scripts/ci/run-tests.py` | 実行 261 件 / 失敗 0 件 / スキップ 0 件 |
| `python3 scripts/ci/check-workflows.py` | 違反は無い (workflow 5 本) |
| `python3 scripts/local-path-lint.py` | 終了コード 0 |
| `python3 scripts/identity-lint.py` | 終了コード 0 |
| `python3 scripts/comment-policy-lint.py` | 禁止 0 件 (検査対象 502 ファイル) |

どの実行の後も、既定の手元の Maven リポジトリ (`~/.m2/repository`) の `jp/kamusoft/` の下の一覧は、実行の前と同じだった。

### この修正サイクルで確かめていないこと

- iOS の 2 系統のテスト (変えたのは Android のビルドの定義だけである)
- 鍵を渡す形と、版を外から渡す形の発行のやり直し (変えたのは依存の宣言だけで、3.4 の記録のままである)
- 開発中の版の歯止め (3.2) の流し直し
- 利用者役の起動 (コード縮小の後)。AAR の中身が変わらないことは、上の SHA-256 で確かめた

## 確かめていないこと

- iOS の 2 系統のテストは、この担当範囲 (Android の公開の設定) では流していない
- 実際の Maven Central への送信と、Maven Central の側の検査 (署名・POM の項目・javadoc jar の有無) を通ること
- 本番で使う署名の鍵 (パスフレーズつき・鍵の ID を指定する形) を渡したときの発行。確かめたのは、パスフレーズなしの鍵を `signingInMemoryKey` だけで渡す形である
- 発行物を利用者役がビルドして使えること (コード縮小を含む。tasks のグループ 5 が確かめる)
- 検証 CI のランナーの上で、足したプラグインを取得できること (手元では取得できた)
- Gradle の configuration cache を有効にしたときの、歯止めの動き (このビルドは有効にしていない)
