# セカンドオピニオン: image-loading (code-005)
**相方**: codex / **label**: so-code-image-loading-005 / **日付**: 2026-09-08 / **対象**: 群 1 (commit 8336212 内の Android 到達点メモリのクラッシュ修正) + 群 2 (未コミットの計測足場: samples/ios の ImageLoadingSlotCounter / ImageGridCell、samples/android の ImageLoadingSlotCounter・ImageGridCell・ImageLoadingSlotCounterTest・benchmark 2 本)
---
# レビュー結果: image-loading（5 周目）

**日付**: 2026-09-08  
**対象**: 指定された群 1・群 2 のみ  
**指摘件数**: Critical 0 / Major 1 / Minor 1 / Suggestion 0

## サマリー

群 1 のクラッシュ修正は、`allowHardware(false)` と `Unreadable` フォールバックの二重防御になっており、指定範囲に新たな問題は見つかりませんでした。

群 2 では、Android の計数機構専用テストが全 build variant 共通の source set に置かれているため、release/benchmark の unit test variant がコンパイルできない問題があります。提示された `assembleRelease` / `assembleBenchmark` は unit test ソースをコンパイルしないため、この問題を検出しません。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`（always）
- `kasane/handbook/cross/sample-parity.md`
- `kasane/handbook/cross/runtime-behavior-verification.md`
- `kasane/handbook/android/performance-verification.md`
- `kasane/handbook/ios/performance-verification.md`
- `core/ADR-0008`、`android/ADR-0002`、`cross/ADR-0004`
- Kotlin / Jetpack Compose / SwiftUI の実装・レビュー観点
- `deviation.md` 記録済みの差分は合意済みとして除外

## 指摘事項

### 🟠 Major: debug 専用テストが全 variant 共通の source set にある

**該当箇所**: `samples/android/app/src/test/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotCounterTest.kt:38`、`samples/android/app/src/test/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotCounterTest.kt:58`、`samples/android/app/build.gradle.kts:80`

**問題点**: `src/test` はすべての build type の unit test に共有されますが、このテストは debug の `counterEnabled` 実装だけを前提にしています。特に 58 行目の `record` は `counterDisabled` 実装に存在しないため、`testReleaseUnitTest` などは unresolved reference でコンパイルできません。仮に空実装へ `record` を追加しても、38 行目の「計数される」テストは release/benchmark variant で失敗します。

**推奨修正**: テスト全体を debug 専用 source set（例: `src/testDebug/kotlin/...`）へ移し、必要なら Gradle の source set を明示設定してください。その後、debug だけでなく release/benchmark の unit test compile task も確認してください。

### 🟡 Minor: Compose テストが手動ポーリングで `Thread.sleep` を使用している

**該当箇所**: `samples/android/app/src/test/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotCounterTest.kt:85`

**問題点**: `waitForIdle()` と 1 ms の `Thread.sleep` を最大 5 秒繰り返しており、Compose テストの同期機構と実時間待機を重ねています。実行時間とスケジューリングに依存し、Kotlin テスト規律の `Thread.sleep` 禁止にも抵触します。

**推奨修正**: `composeTestRule.waitUntil(timeoutMillis = TallyTimeoutMillis) { ImageLoadingSlotCounter.tally(itemId).sized > 0 }` のような条件待機へ置き換え、タイムアウト時には現在値を添えて失敗させてください。

## アクションプラン

1. `ImageLoadingSlotCounterTest` を debug 専用 test source set へ移す。
2. 手動 sleep ループを Compose の条件待機へ置き換える。
3. debug/release/benchmark の unit test variant がすべてコンパイル可能なことを確認する。
4. その後、予定されている tasks 7.4 / 7.5 の再計測へ進む。

**判定: CHANGES_REQUESTED**



## 突き合わせ結果 (ホスト側 review-005.md との照合、2026-09-08)

| 相方の指摘 | ホスト側 | 採否 | 根拠 |
|---|---|---|---|
| Major: debug 専用テスト (`ImageLoadingSlotCounterTest`) が全 variant 共通の `src/test` にあり、release / benchmark の unit test がコンパイルできない | 指摘なし | **降格 (Suggestion)** | 事実確認: この Sample の Gradle には unit test の variant が debug にしか生成されない (`:app:tasks --all` に `testDebugUnitTest` / `compileDebugUnitTestKotlin` のみ。`assembleRelease` が unit test をコンパイルしないという前提は正しいが、release 側の unit test タスク自体が存在しない)。したがって挙げられた失敗は現状では起きない。ただし「共有 source set に debug 専用前提のテストがある」構図は事実なので、`src/testDebug` へ移す整理は修正サイクルに同梱する (安価で構造が正直になるため) |
| Minor: Compose テストが `Thread.sleep` の手動ポーリング | 指摘なし | **採用 (Minor)** | 該当箇所特定済み。kotlin-impl-skill のテスト規律 (`Thread.sleep` 禁止) に抵触。`waitUntil` への置換で解消できる |

ホスト側のみの指摘 (Major: iOS アクセシビリティテストが Simulator 26.1 以降で空振り / Minor 2 件 / Suggestion 3 件) は review-005.md のとおり確定。相方は静的レビュー (テスト実行なし) のため Major を検出できる立場になかった。

集計: 確定 0 / 採用 1 / 降格 1 / 未解決 0。
