---
id: 0008
title: Android のビルドは JDK 17 以上のどれでも動かせるようにし、出力するバイトコードだけを Java 17 向けに固定する
status: accepted
date: 2026-10-03
amends: 0002
---

## Context

android/ADR-0002 は、Android のビルド構成の 1 項目として「JDK 17 (`jvmToolchain(17)`)」を決めている。`jvmToolchain(17)` はビルドを動かす JDK そのものを 17 に固定するため、JDK 21 だけを入れた開発機では、本体も Sample も構成の段階で失敗し、ビルド・テスト・端末への導入のどれも実行できない (JDK 17 の取得元は設定していない)。android/ADR-0002 には、JDK を 17 に固定する理由と、検討した代替案の記録が無い。

配布するライブラリが利用者に求める Java の版は、出力するバイトコードの対象で決まり、ビルドを動かした JDK の版では決まらない。

前提: ビルドに使う Gradle・AGP・Kotlin が、JDK 17 より新しい JDK の上で Java 17 向けの出力を作れる。

## Decision

Android のビルド (本体・Sample・計測モジュール) は、ビルドを動かす JDK を 1 つの版に固定せず、JDK 17 以上のどれでも動かせるようにする。出力するバイトコードは Java 17 向けに固定する。

android/ADR-0002 の決定のうち「JDK 17 (`jvmToolchain(17)`)」を本決定で置き換える。他の決定は維持する。

含むもの: ビルドを動かす JDK の範囲と、出力の対象の版。含まないもの: 利用者に求める Java の版を上げること (出力の対象は Java 17 のまま変えない)。

## Alternatives Considered

- **JDK の固定を 21 に変える**: 却下。JDK 17 だけの環境でビルドできなくなる
- **出力も Java 21 向けに上げる**: 却下。配布するライブラリが利用者に求める Java の版が上がる
- **android/ADR-0002 に従って JDK 17 の固定を残し、開発機に JDK 17 を入れる**: 却下 (オーナー判断、2026-10-03)。固定の理由が記録されておらず、配布物の出力が変わらないため、開発機ごとに特定の版の JDK を求める利得が無い

## Consequences

- 正: JDK 17 より新しい JDK だけを入れた開発機でも、ビルド・テスト・端末への導入ができる
- 正: 配布するライブラリが利用者に求める Java の版は変わらない
- 負: コンパイル時に見える JDK の API が、ビルドを動かす JDK の版で変わる。JDK 17 に無い API を使ったコードは、新しい JDK でだけビルドが通り、JDK 17 では通らない
- 負: ビルドを動かす JDK が開発機ごとに違ってよくなるため、すべての版での確認はされない

## Revisit When

- JDK 17 に無い API の混入でビルドが環境によって通ったり落ちたりしたとき
- 出力の対象を Java 17 より上げたくなったとき
- 前提 (Context) が崩れたとき

出典: kasane/changes/archive/2026-10-03-android-build-jdk-range/exploration.md (検討した選択肢・決定事項) / kasane/changes/archive/2026-10-03-android-build-jdk-range/review-001.md (android/ADR-0002 との食い違いの指摘と、コンパイル時に見える JDK の API の指摘)
