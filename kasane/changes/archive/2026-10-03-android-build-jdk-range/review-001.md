# レビュー結果: android-build-jdk-range (001 回目)

**日付**: 2026-10-03
**判定**: NEEDS_DISCUSSION

## サマリー

実装 (3 ファイルの `jvmToolchain(17)` を `compilerOptions.jvmTarget = JVM_17` に置き換え) は合意スコープのとおりで、JDK 21 でのビルド・ユニットテストはすべて通り、出力されるクラスはすべて Java 17 向け (クラスファイルの major 61) のままだった。実装への Critical / Major の指摘は無い。

ただし、accepted の android/ADR-0002 の Decision が「JDK 17 (`jvmToolchain(17)`)」と手段まで書いており、この change はその記述と食い違う。exploration.md は「ADR 候補: なし」としていて、この ADR の扱い (改訂するか・蒸留時に追随させるか) がどこにも記録されていない。実装では解決できないため NEEDS_DISCUSSION とする。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` (always)
- `kasane/handbook/cross/test-execution.md` (テストを実行するとき)
- `kasane/handbook/cross/local-development-setup.md` (本体のビルド)
- `kasane/handbook/cross/public-identifiers.md` (ビルド定義を触るとき。配布座標・識別子に変更が無いことだけ確認)
- `kasane/decisions/android/0002-single-module-latest-compose-bom.md` (accepted)
- `kasane/lessons/code-review.md` (L-001・L-002 とも計測値・動きの過程を扱わない change のため該当なし)

ロードしたスキル: ksn-review、kotlin-impl-skill

## 確認した観点

実行した確認 (すべて JDK 21.0.12、`JAVA_HOME=$(/usr/libexec/java_home)`):

| 確認 | 結果 |
|---|---|
| `android/` で `:kscollectionview:assemble`、`compileDebugKotlin` / `compileReleaseKotlin` / `testDebugUnitTest` を `--rerun` で再実行 | 成功。テストは 28 クラス 474 件、失敗 0・スキップ 0 (結果 XML の集計。更新時刻が今回の実行であることを確認) |
| `samples/android/` で `:app:assembleDebug`、`compileDebugKotlin` / `testDebugUnitTest` を `--rerun` で再実行 | 成功。テストは 21 クラス 163 件、失敗 0・スキップ 0 |
| `samples/android/` で `:benchmark:compileBenchmarkKotlin` を `--rerun` で実行 (事前に `--dry-run` で install・connected 系のタスクが含まれないことを確認。パッケージの列挙には無いコンパイルだけのタスク) | 成功 |
| 出力クラスの版 | `kscollectionview-release.aar` / `kscollectionview-debug.aar` の `classes.jar` は 196 クラスすべて major 61 (Java 17)。`:app` 309 クラス、`:benchmark` 10 クラスも major 61 |
| Kotlin コンパイラに渡る引数 (`-Pkotlin.internal.compiler.arguments.log.level=warning`) | `-jvm-target 17`、`-jdk-home` はビルドを動かす JDK 21、`-Xexplicit-api=strict` は維持 |
| `scripts/comment-policy-lint.py` | 対象 3 ファイルに検出なし |

install・connected 系のタスクは実行していない。JDK 17 での実行は環境に無いため行っていない。

チェックリスト:

- 仕様充足 (合意スコープ): 3 か所とも `jvmToolchain(17)` が `compilerOptions { jvmTarget.set(JVM_17) }` に置き換わり、`compileOptions` の `sourceCompatibility` / `targetCompatibility` (17) は 3 ファイルとも無変更。対象外の箇所に `jvmToolchain` / `jvmTarget` の指定は残っていない。完了の目安のうち「導入」はレビューでは実行していない
- 足場の書き換え: exploration.md は未追跡の新規ファイルで、実装による書き換えの有無は diff からは判定できない (内容に実装の後追いと読める記述は無い)。deviation.md は無い
- 配布物の出力: 上の表のとおり Java 17 向けのまま。利用者に見える Java の版の属性は `compileOptions.targetCompatibility` から決まり、こちらは無変更
- Java 側との整合: Kotlin の `jvmTarget` 17 と Java の `targetCompatibility` 17 が一致し、Kotlin Gradle Plugin の Java / Kotlin の対象の食い違いの検査に掛からない (JDK 21 でビルドが通ることで確認)。3 モジュールとも Java のソースは無い (`compile*JavaWithJavac` は NO-SOURCE)
- JDK 17 での成立 (机上): `compilerOptions.jvmTarget` は JDK の版に依存しない指定で、JDK 17 で動かした場合は「JDK 17 で動き、出力は 17 向け」となり、変更前に toolchain が解決していた構成と実質同じになる。成立しない要素は見当たらない。実機での確認は未実施 (exploration.md の未決の論点のとおり)
- テスト: ビルド定義だけの変更で、対応するテストの追加は不要。既存テストは全件成功
- 設計品質: 既存 ADR との整合は指摘 1。オーバーエンジニアリングなし (AGP の組み込み Kotlin は `targetCompatibility` から `jvmTarget` を既定で導くため明示は冗長とも言えるが、合意スコープが明示を決めており、意図が読める利点があるので指摘しない)
- コメント: 3 か所とも単独で意味が通り、禁止参照・履歴記述なし。「17 以上であればよい」は 21 でだけ実証済み
- kotlin-impl-skill の観点: Gradle Kotlin DSL として `compilerOptions` の Property への `set` は現行の書き方。完全修飾名の直書きは 1 か所ずつで、import にするかは好みの範囲のため指摘しない
- セキュリティ・性能・リソース: 該当なし

## 指摘事項

### [🟠 Major (spec 側)] accepted の android/ADR-0002 が `jvmToolchain(17)` を決定として書いており、扱いが記録されていない

**該当箇所**: `kasane/decisions/android/0002-single-module-latest-compose-bom.md:19`、`exploration.md` (「ADR 候補」と「決定事項」)、`android/kscollectionview/build.gradle.kts:67-70`
**問題点**: ADR-0002 の Decision は「JDK 17 (`jvmToolchain(17)`)」と手段を名指ししている。この change はその手段を外すので、蒸留後は accepted の ADR とコードが食い違う。exploration.md は「ADR 候補: なし」とし、「蒸留時に反映」の 2 行は handbook だけを挙げていて、ADR-0002 への言及が無い。実装は合意スコープに従っており、実装側では直せない。
**推奨修正** (選択肢。判断はオーナー / 記録の主体):
- 案 1 (推奨): ADR-0002 の該当箇所を「出力は Java 17 向け、ビルドを動かす JDK は 17 以上」に改める扱いを決めて記録する。記録の形は、ADR-0002 を amend する proposed の ADR を起票するか、表記の追随で足りると判断するなら `deviation.md` に「蒸留時に反映: decisions・android/ADR-0002 — …」の行を足す (どちらにするかは ADR の運用の判断)
- 案 2: ADR-0002 の決定を維持し、`jvmToolchain(17)` を残したまま JDK 17 の取得手段 (toolchain の取得元の設定、または JDK 17 の導入) で課題を解く。exploration.md の採用案を覆すことになる

### [🟡 Minor (spec 側)] 蒸留の申し送りが `local-development-setup.md` の「版の定義元」の表を拾っていない

**該当箇所**: `kasane/handbook/cross/local-development-setup.md:60`
**問題点**: 同文書は「Android の minSdk・JDK・namespace」の定義元を `android/kscollectionview/build.gradle.kts` としている。変更後、このファイルが宣言するのは出力の対象 (Java 17) だけで、ビルドに要る JDK の下限はコメントにしか無い (実際の下限は AGP の要求で決まる)。申し送りの行は 33・37 行目に当たる内容だけを挙げている。
**推奨修正**: 上の指摘の記録と合わせ、蒸留の申し送りにこの表の行 (JDK の「定義元」の書き方) を含める。優先度は低い。

### [🔵 Suggestion] JDK の API の見え方がビルドする環境の JDK で変わる

**該当箇所**: `android/kscollectionview/build.gradle.kts:68-70` (他 2 ファイルも同じ)
**問題点**: Kotlin コンパイラには `-jdk-home` としてビルドを動かす JDK (今回は 21) が渡り、`-no-jdk` も `-Xjdk-release` も付かない。JDK 21 にあって JDK 17 に無い API を使ったコードは JDK 21 の環境でだけコンパイルが通り、JDK 17 の環境で落ちる、という環境差が理屈の上では生じる。出力のバイトコードの版には影響せず、Android の API (android.jar) の範囲で書いている限り起きない。変更前も「JDK 17 にあって android.jar に無い API」が通る点は同じ性質だった。
**推奨修正**: 今は対応不要。JDK 17 の環境 (CI 等) を持った時点で差が出たら、`-Xjdk-release=17` を足すかを検討する。

## アクションプラン

1. android/ADR-0002 の「JDK 17 (`jvmToolchain(17)`)」の扱いを決めて記録する (案 1 なら実装の変更は不要)
2. 蒸留の申し送りに `local-development-setup.md` の「版の定義元」の表を含める
3. JDK 17 の環境が手に入った時点で、同じ 4 タスクを 1 回通して「17 以上」の下端を実証する (exploration.md の未決の論点)
