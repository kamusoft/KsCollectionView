# 手元の完了判定 (tasks 8) — 1 回目

実行した日: 2026-10-15 / 対象: tasks 1〜7 を実装した作業ツリー (HEAD c764358 からの未 commit の変更) / 環境: Xcode 27.0、作業専用に作った Simulator (iPhone 17・iOS 27.0。流した後に削除)

## 8.1 スクリプトのテスト

| コマンド | 実行 | 失敗 | スキップ |
|---|---|---|---|
| `python3 scripts/ci/run-tests.py` | 702 | 0 | 4 (Gradle を実際に流すテスト。`KS_GRADLE_TESTS=1` のときだけ流れる) |
| `KS_GRADLE_TESTS=1 python3 scripts/ci/run-tests.py` (tasks 2 の担当が実行) | 706 | 0 | 0 |

## 8.2 4 系統 (順に流した。ビルド込みの壁時計)

| 系統 | コマンド | 実行 | 失敗 | 所要 |
|---|---|---|---|---|
| iOS 本体 | `ios/` で `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,id=<作業用>' -configuration Debug -collect-test-diagnostics never` | 567 | 0 | 167 秒 |
| iOS Sample | `samples/ios/` で `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,id=<作業用>' -collect-test-diagnostics never` | 48 (ユニット 37・UI 11) | 0 | 178 秒 |
| Android 本体 | `android/` で `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` (件数は `build/test-results/testDebugUnitTest/TEST-*.xml` の集計) | 512 (スキップ 0) | 0 | 23 秒 |
| Android Sample | `samples/android/` で `./gradlew :app:testDebugUnitTest --rerun-tasks` (同じく XML の集計) | 163 (スキップ 0) | 0 | 14 秒 |
| 合計 | | | | 382 秒 (10 分の上限の内) |
