---
id: 0002
title: Android は単一モジュール + explicitApi strict で組み、Compose BOM は利用者に未普及の SDK Platform を強いない範囲で最新安定版に追随する
status: accepted
date: 2026-09-04
---

## Context

Android の配布は `jp.kamusoft:kscollectionview` の 1 artifact と決まっている (cross/ADR-0003)。参照元の KsSettingsView は本体と interop 用 bridge の 2 モジュール構成だが、本ライブラリには bridge に相当する需要がない。描画の統一 (android/ADR-0001) は Compose Foundation 1.8 以上を前提とし、キャッシュ窓 (`LazyLayoutCacheWindow`) は 1.9 以上、material3 の `PullToRefreshBox` は 1.4 系で stable になる。ライブラリが依存する Compose の版は利用者アプリの Compose を引き上げるため、版方針は利用者への影響を持つ。主目的は自社 KMP アプリの量産で OSS 公開は副次 (cross/ADR-0001)。

実装で判明した制約: Compose の AAR メタデータは利用者アプリに最低 compileSdk (`minCompileSdk`) を要求する。実装時点の最新安定 BOM 2026.08.00 (Compose 1.12.0) は compileSdk 37 (Platform 37.2、直近リリースの minor 版) を要求し、ライブラリを入れるだけで利用者に未普及の SDK Platform のインストールを強いる状態になった (実装・Sample・計測はすべて通り、レビュー 5 回も指摘しなかった。オーナー指摘で判明)。

前提: 利用者アプリは Compose を使い、SDK Platform は広く配布済みの安定版に載っている。

## Decision

- モジュールは `android/kscollectionview` の 1 つ。パッケージは `jp.kamusoft.kscollectionview`、ソースルートは `src/main/kotlin`
- minSdk 29 / compileSdk は広く配布済みの最新の SDK Platform (minor 版は指定しない。実装時点は 36) / JDK 17 (`jvmToolchain(17)`)
- 版は `gradle/libs.versions.toml` を単一定義元とし、Sample が composite build で共有する。AGP・Kotlin・Compose BOM は**最新安定版**に追随する。ただし Compose BOM は、その版の AAR が利用者に要求する compileSdk が広く配布済みの SDK Platform を超えるときは採らず、条件を満たす直近の安定版に留める (「最新安定」は「利用者に未普及の SDK Platform を強いない範囲での最新安定」と読む。実装時点は Compose 1.11 系の最新安定 BOM。キャッシュ窓 (1.9 以上) と material3 1.4 の要件は満たす)。Navigation Compose は BOM 外のため個別に指定する
- `kotlin { explicitApi() }` (strict) で公開面を明示宣言する。binary-compatibility-validator は入れない
- maven-publish の設定は配布のフェーズで行う (基盤では composite build による Sample 参照が成立すれば足りる)

## Alternatives Considered

- **必要最低版 (Foundation 1.8 系) に固定して古い Compose のアプリからも使えるようにする**: 却下。キャッシュ窓や stable な Pull to Refresh を使えず、古い版のバグ回避を背負う。主目的の自社アプリは最新追随が前提で、互換を広げる価値が低い
- **KsSettingsView と同じ 2 モジュール構成**: 却下。interop 用 bridge に当たる需要がない (cross/ADR-0003 の 1 artifact と整合)
- **最新安定版を無条件に採る (Compose 1.12.0 + compileSdk 37.2)**: 却下 (2026-09-05)。本決定が受容した負の帰結は「利用者アプリの Compose 版の引き上げ」までであり、SDK Platform のインストールを強いることは想定外

## Consequences

- 正: 版管理が「catalog を上げるだけ」で済み、KsSettingsView と同じ運用になる
- 正: 公開面が explicitApi で意図的に宣言され、内部型の漏れをコンパイル時に防げる
- 負: ライブラリを入れると利用者アプリの Compose が最新安定版へ引き上がる。古い Compose に留まるアプリは対象外になる
- 負: 最新追随のため、Compose の破壊的変更への追随作業が定期的に発生する
- 負: 最新安定版が未普及の SDK Platform を要求する期間は、その版を採れない (1 版分の遅れが出る)
- 負: 最新安定を素直に採ると通ってしまう。ビルド定義のレビューで生成物 (AAR) の `minCompileSdk` を読む必要がある (lessons inbox に捕捉済み)

## Revisit When

- 採りたい Compose 版が要求する SDK Platform が広く配布済みになったとき (実装時点の例: Platform 37 の普及で Compose 1.12 系へ上げる)
- 前提 (Context) が崩れたとき

出典: kasane/roadmaps/v1-foundation/phases/phase-3-android-wrapper-foundation/history.md (2026-09-04: ビルド構成) / kasane/changes/archive/2026-09-05-android-wrapper-foundation/deviation.md (Compose BOM と compileSdk の引き下げ、2026-09-05) / cross/ADR-0003 / android/ADR-0001
