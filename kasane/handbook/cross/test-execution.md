---
kind: rule
applies-when:
  always: false
  tasks: [テスト実行, テスト結果の報告]
title: テスト実行規約
description: テストを「実際に全件走らせた」と言える条件 — 実行件数の確認、収束を待つアサーション、確認済みの iOS 実行手順
timestamp: 2026-09-02
---

# テスト実行規約

この文書は、各プラットフォームのテストを「実際に全件走らせる」ための規律と、**実行や検証が黙って空振りする範囲**の扱いを定める。読むと、何をもって検証したと言えるか、どんな書き方が「待ったつもり」になるかが分かる。

本文書の現行規範は、プラットフォーム非依存の 2 節と、実構成で確認済みの iOS 実行手順である。Android の節はまだ翻案元での知見に留まる。

## 実行件数の確認までが検証

テストが 1 件も実行されなくてもコマンド自体は成功で終わるため、終了コードだけでは検証したことにならない。**実行件数を確認するところまでが検証**であり、テスト結果を報告するときはプラットフォームを問わず実行件数 (`N tests / M failures`) を併記する。

- 件数の得方はビルドシステムごとに異なる。コンソールに出ないビルドシステムでは、結果ファイル (XML / HTML レポート) の集計まで行って初めて件数を得たことになる
- 「テスト全 pass」とだけ報告しない。件数を言えない状態は、空振りしていないことを確認していない状態と同じである
- 絞り込み実行 (特定ターゲット・特定クラスのみ) は反復中の手段であり、**完了判定には絞り込みなしの全件実行を使う**

## 収束を待つアサーション

非同期に反映される状態を検証するテストは、待ちたい**完了条件そのもの**を観測する条件ベース待機で書く。固定時間の待機を繰り返して「静止した」ことにしない。通常時は無駄に待ち、実行機が混んでいるときは待ち足りずに落ちる。

待機は次の 3 つをすべて満たす形で書く。いずれを欠いても「待ったつもり」になる。

- 上限は**実時間の deadline** で区切る。反復回数で区切ると、対象がバックグラウンドにある間にループが燃え尽きる
- ループ内で待機対象へ実行機会を譲る (`Thread.sleep(1)` 等)。CPU が飽和した状況では、OS へのヒントに留まる譲り方 (`Thread.yield()` 等) は譲れる保証がない
- deadline 超過時は黙って戻らず、その時点の実測値をメッセージに載せて失敗させる

黙って戻る待機は収束前の状態を検証したことにされ、「実装が壊れた」と「待機が足りない」も区別できなくなる。この誤りは CPU が競合したときだけ落ちるため、手元では常に緑で、並列実行や CI の混雑時に間欠的に落ちる flaky として表面化する。**手元で通ることは、この形で書けている根拠にならない。**

リスト・グリッドの検証はこの誤りに特に当たりやすい。行の生成・再利用、差分適用、レイアウトの反映はいずれも呼び出した時点では完了せず、フレームまたはバックグラウンドスレッドをまたいで確定するためである。

## プラットフォーム別の実行手順

実測していない手順を確定した手順として書かない。iOS は本プロジェクトで確認済み、Android は未検証である。

### iOS: Simulator で SwiftPM 全件を実行する

- Swift Package のテストのうち `#if canImport(UIKit)` でガードされたものは、macOS 上の `swift test` では**コンパイル対象から外れ、失敗ではなく最初から存在しないものとして扱われる**
- UIKit のセル・レイアウト・Renderer に関わる検証はガードされた側に集まるため、`swift test` だけで完了と判断すると変更の中核が 1 件も検証されないまま「全 pass」と報告されうる
- `ios/` で `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=<利用可能な機種名>,OS=<利用可能な版>' -configuration Debug` を実行する
- Release は `ENABLE_TESTABILITY=YES` を付ける。付けないと `@testable import KsCollectionView` を解決できず、テストバンドルのコンパイル前に失敗する
- 実行件数は `xcodebuild` 出力末尾の `Executed N tests, with M failures` で確認できる。Simulator の機種名は `xcrun simctl list devices available` で得る

### iOS: Sample の UI テストと計測ドライバを分けて実行する

Sample (`samples/ios/`) の UI テストターゲットには、アサーションを持たない計測ドライバ (Instruments の接続窓を開くための固定待機を含む) が同居する。計測ドライバを通常の検証に混ぜると、実行時間が伸びるうえ「収束を待つアサーション」を欠いたテストが緑の一部として数えられる。

- 通常の検証は `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples` で実行する。このスキームは計測ドライバを除外する
- 計測ドライバは `-scheme KsCollectionViewSamplesPerformance` でのみ実行する。実行そのものが計測手順の一部であり、合否ではなく Instruments 側の記録で判定する
- どちらのスキームも実行件数を報告する。通常スキームの件数に計測ドライバが含まれていないことが、分離が効いている確認になる

### Android: 差分なし再実行と Robolectric の描画限界 (未検証)

- Gradle は up-to-date なテストタスクをスキップするため、**差分なしの再実行は「テスト 0 件で BUILD SUCCESSFUL」になり得る**。全件を回し直して件数を確認するときは `--rerun-tasks` を付ける
- 実行件数はコンソールに出ない。`build/test-results/<タスク名>/TEST-*.xml` の `tests` / `failures` 属性の合計、または `build/reports/tests/<タスク名>/index.html` で確認する
- ディレクトリ名は variant 名ではなく**タスク名**であり、読み替えを誤ると集計対象が 0 件になる
- Robolectric の既定 (legacy graphics モード) では一部の描画処理が実行されず、描画結果を見るアサーションが空振りする。実描画を要する検証にはクラスへ `@GraphicsMode(GraphicsMode.Mode.NATIVE)` が必要になる

Robolectric の NATIVE モードは実 Skia を動かすため起動コストと CI の環境依存が増える。採否は Android ラッパー基盤の実装時に、必要な検証と費用を突き合わせて決める。

## 関連

- [実行時挙動の検証規約](runtime-behavior-verification.md) — テストの green が実機の動作を保証しない範囲と、その完了判定
- [ローカル開発環境と Sample の実行](local-development-setup.md) — ビルド・実行の環境設定 (テスト実行は本文書が正)
- [cross/ADR-0002](../../decisions/cross/0002-monorepo-platform-build-roots.md) — `ios/` `android/` が独立したビルドルートである理由

出典: ../KsSettingsView/kasane/handbook/cross/test-execution.md (実行件数の確認・収束を待つアサーション・プラットフォーム別の落とし穴)
