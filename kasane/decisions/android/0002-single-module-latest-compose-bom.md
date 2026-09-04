---
id: 0002
title: Android は単一モジュール + explicitApi strict で組み、Compose BOM は最新安定版に追随する
status: proposed
date: 2026-09-04
---

## Context

Android の配布は `jp.kamusoft:kscollectionview` の 1 artifact と決まっている (cross/ADR-0003)。参照元の KsSettingsView は本体と interop 用 bridge の 2 モジュール構成だが、本ライブラリには bridge に相当する需要がない。描画の統一 (android/ADR-0001) は Compose Foundation 1.8 以上を前提とし、キャッシュ窓 (`LazyLayoutCacheWindow`) は 1.9 以上、material3 の `PullToRefreshBox` は 1.4 系で stable になる。ライブラリが依存する Compose の版は利用者アプリの Compose を引き上げるため、版方針は利用者への影響を持つ。主目的は自社 KMP アプリの量産で OSS 公開は副次 (cross/ADR-0001)。

## Decision

- モジュールは `android/kscollectionview` の 1 つ。パッケージは `jp.kamusoft.kscollectionview`、ソースルートは `src/main/kotlin`
- minSdk 29 / compileSdk は実装時点の最新 / JDK 17 (`jvmToolchain(17)`)
- 版は `gradle/libs.versions.toml` を単一定義元とし、Sample が composite build で共有する。AGP・Kotlin・Compose BOM は**実装時点の最新安定版**に載せ、以後も最新安定に追随する。Navigation Compose は BOM 外のため個別に指定する
- `kotlin { explicitApi() }` (strict) で公開面を明示宣言する。binary-compatibility-validator は入れない
- maven-publish の設定は配布のフェーズで行う (基盤では composite build による Sample 参照が成立すれば足りる)

## Alternatives Considered

- **必要最低版 (Foundation 1.8 系) に固定して古い Compose のアプリからも使えるようにする**: 却下。キャッシュ窓や stable な Pull to Refresh を使えず、古い版のバグ回避を背負う。主目的の自社アプリは最新追随が前提で、互換を広げる価値が低い
- **KsSettingsView と同じ 2 モジュール構成**: 却下。interop 用 bridge に当たる需要がない (cross/ADR-0003 の 1 artifact と整合)

## Consequences

- 正: 版管理が「catalog を上げるだけ」で済み、KsSettingsView と同じ運用になる
- 正: 公開面が explicitApi で意図的に宣言され、内部型の漏れをコンパイル時に防げる
- 負: ライブラリを入れると利用者アプリの Compose が最新安定版へ引き上がる。古い Compose に留まるアプリは対象外になる
- 負: 最新追随のため、Compose の破壊的変更への追随作業が定期的に発生する

出典: kasane/roadmaps/v1-foundation/phases/phase-3-android-wrapper-foundation/history.md (2026-09-04: ビルド構成) / cross/ADR-0003 / android/ADR-0001
