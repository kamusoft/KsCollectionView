# コードレビュー: ios-engine-foundation

## メタデータ

- 日付: 2026-09-02
- 判定: **CHANGES_REQUESTED**

## サマリー

公開 API、差分更新、レイアウト、Sample の主要経路はビルドおよび自動テストを通過している。一方、必須の性能受け入れ判定が未実施であり、決定済みの iOS 16 下限に対して配布設定が iOS 26 になっているほか、ロングタップ後の次の通常タップを誤って抑止する状態管理上の不具合があるため、現状では承認できない。

重要度別件数: **Critical 0 / Major 3 / Minor 0 / Suggestion 0**

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` — 常時適用のソースコメント規約
- `kasane/handbook/cross/sample-parity.md` — `samples/ios/` の構成と表示内容
- `kasane/handbook/cross/test-execution.md` — テストの実行・報告
- `kasane/handbook/cross/runtime-behavior-verification.md` — ジェスチャー、スクロール、再利用などの実行時挙動
- `kasane/handbook/cross/public-identifiers.md` — 公開ライブラリと配布座標
- `kasane/handbook/cross/local-development-setup.md` — iOS 16 下限、ローカルビルド、Sample 実行
- `swift-ui-impl-skill` — Swift 6.2 / SwiftUI / UIKit ブリッジの実装・レビュー規律

## Findings

### 🔴 Major

#### 1. 必須の性能受け入れ条件が未検証

- **場所**: `kasane/changes/ios-engine-foundation/tasks.md:49`
- **問題**: collection-core の必須要件は、iPhone 11 実機で可変行高混在 10,000 件を 3 回計測し、全試行で hitch time ratio 5 ms/s 未満かつメモリが定常化することを要求している。しかし 8.1〜8.3 は未完了で、`kasane/changes/ios-engine-foundation/evidence/performance-early-measurement.md:5` も「未実施」、各結果も「未計測」と明記している。UIKit エンジン採用の中核理由である仮想化・再利用性能について、適合を判断できる証拠がない。
- **推奨修正**: 規定の iPhone 11 実機・Release 構成・固定 fixture で Instruments と Memory Report の計測を 3 回実施し、サニタイズ済みの条件・各試行値・メモリ推移・判定を `evidence/` に保存したうえで tasks 8.1〜8.3 を完了する。

#### 2. 配布対象の下限が決定済みの iOS 16 ではなく iOS 26 になっている

- **場所**: `ios/Package.swift:8`
- **問題**: Package の platform が `.iOS(.v26)` であり、Sample も `samples/ios/KsCollectionViewSamples.xcodeproj/project.pbxproj:120` などで deployment target 26.0 を指定している。これは `kasane/handbook/cross/local-development-setup.md:25` の決定済み下限「iOS 16 以上」に反し、iOS 16〜25 の利用者がパッケージを解決できない。なお、レビュー時に `IPHONEOS_DEPLOYMENT_TARGET=16.0` を上書きしたライブラリビルド自体は成功しており、現時点で確認できた阻害要因は配布設定である。
- **推奨修正**: Package と Sample の deployment target を iOS 16 に揃え、iOS 16 を対象にしたライブラリビルドと、サポート対象ランタイムでの Sample / 主要実行時挙動を再検証する。

#### 3. 成立したロングタップが次の通常タップまで抑止する

- **場所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:349`
- **問題**: ロングタップ成立時に ID を `longPressConsumedIDs` へ追加する一方、削除する経路は `didSelectItemAt` の `longPressConsumedIDs.remove` (`ios/Sources/KsCollectionView/KsCollectionViewController.swift:435`) だけである。`UILongPressGestureRecognizer` は既定で成立したタッチをキャンセルするため、同じタッチの選択通知が来なければ ID が残り、同じアイテムへの次の通常タップが誤って捨てられる。「長押しが成立した同じタッチでは通常タップを発火しない」という排他要件を、次の別タッチにまで持ち越している。
- **推奨修正**: 消費状態を ID 単位で次の選択まで保持せず、同一ジェスチャー／同一タッチの終端で確実に解消する設計へ変更する。少なくとも「同じアイテムをロングタップした後に通常タップする」統合テストを追加し、ロングタップ 1 回と通常タップ 1 回がそれぞれ発火することを確認する。

### 🟡 Minor

なし。

### 🔵 Suggestion

なし。

## 実行したコマンドと結果

個体識別子を成果物へ残さないため、Simulator は名前と OS で表記する。

| コマンド | 結果 |
|---|---|
| `python3 scripts/comment-policy-lint.py` | 成功。対象 54 ファイル、違反 0 件 |
| `python3 scripts/local-path-lint.py` | 成功 |
| `python3 scripts/identity-lint.py` | 成功 |
| `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' -configuration Debug` | 成功。25 tests、0 failures、`TEST SUCCEEDED` |
| `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' -configuration Release` | 失敗。Release では testability が無効で、`@testable import KsCollectionView` を解決できず exit 65 |
| `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' -configuration Release ENABLE_TESTABILITY=YES` | 成功。26 tests、0 failures、`TEST SUCCEEDED` |
| `xcodebuild build -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' -configuration Debug CODE_SIGNING_ALLOWED=NO` (`samples/ios/`) | 成功。`BUILD SUCCEEDED` |
| `xcodebuild build -scheme KsCollectionView -destination 'generic/platform=iOS Simulator' -configuration Debug IPHONEOS_DEPLOYMENT_TARGET=16.0 CODE_SIGNING_ALLOWED=NO` (`ios/`) | 成功。`BUILD SUCCEEDED` |

Release 26/26 は `ENABLE_TESTABILITY=YES` を明示した条件で再現した。通常の Release 構成ではテストバンドルをコンパイルできないため、以後の再検証でも同じ条件を明記する必要がある。

## 推奨アクションプラン

1. ロングタップ消費状態を同一タッチ内に閉じ、回帰テストを追加する。
2. Package と Sample の deployment target を iOS 16 に修正し、下限対象で再検証する。
3. iPhone 11 実機で必須の性能・メモリ計測を完了し、`evidence/` と tasks を更新する。
4. 上記完了後、Debug / Release テスト、Sample build、lint を再実行して再レビューを依頼する。
