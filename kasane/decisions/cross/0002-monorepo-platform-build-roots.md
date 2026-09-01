---
id: 0002
title: モノレポとプラットフォーム別ビルドルート
status: accepted
date: 2026-09-01
---

## Context

KsCollectionView は SwiftUI 版と Jetpack Compose 版の2実装を持ち、両者で同じ書き味の公開 DSL を提供することそのものが製品価値である (cross/ADR-0001)。一方で内部の描画エンジンは非対称であり (core/ADR-0001)、Xcode / SwiftPM と Gradle / AGP ではビルドツールチェインも IDE のワーキングセットも異なる。

公開 DSL に手を入れる変更はほぼ必ず両プラットフォームに及ぶため、対称性の崩れを1つの変更単位の中で検出できる構成が要る。同時に、各プラットフォームの開発者が相手側のツールチェインを意識せずビルド・テストできる必要がある。

KMP / CMP 対応は本ライブラリの非ゴールであり、両プラットフォームのビルドを1つのツールで束ねる動機は現時点で存在しない。

## Decision

単一リポジトリ配下に iOS 実装・Android 実装・Sample・ドキュメントを配置し、公開 DSL の変更、バージョニング、CHANGELOG、変更管理を一元化する。

ビルドについては `ios/` と `android/` をそれぞれ独立したビルドルートとして扱い、リポジトリルートには共通ビルドファイル (統合 `build.gradle.kts`・ルートの `Package.swift` など) を置かない。各プラットフォームは、それぞれの標準ビルド入口を IDE から直接開く。

## Alternatives Considered

- **iOS と Android を別リポジトリに分割する**: 却下。公開 DSL の対称性が製品価値の中核であり、DSL に触る変更は常に両リポジトリの同期 PR になる。対称性の検証も PR をまたぐため、単一メンテナーで始める本プロジェクトには運用コストが釣り合わない。
- **リポジトリルートに両プラットフォームを束ねる統合ビルドファイルを置く**: 却下。KMP / CMP 対応が非ゴールである以上、統合ビルドが解く問題が存在しない。ルートの共通ビルドファイルは Xcode / Android Studio のプロジェクト認識をかえって阻害する。
- 参考 (翻案元での検討): 翻案元は iOS / Android / MAUI の3ディレクトリを対象に同じ決定を行い、将来の KMP 導入時の再検討余地を残していた。本プロジェクトは MAUI 非対応 (cross/ADR-0001)・KMP 非ゴールのため、対象を2面に絞って適用する。

## Consequences

- 正: 公開 DSL の変更を同一 PR で完結でき、両プラットフォームの対称性をその場で確認できる。
- 正: バージョニング・CHANGELOG・Sample の参照経路を一元化できる。
- 正: 各プラットフォームの開発者は対象ディレクトリを IDE で開くだけで独立して作業できる。
- 負: リポジトリルートから両プラットフォームを一括ビルドする共通入口を持たないため、ビルド・テストの手順がプラットフォームごとに分かれる。
- 負: 対称性の検証は人および CI の責務として別途設計する必要がある (ビルドシステムは何も強制しない)。

出典: ../KsSettingsView/kasane/decisions/cross/0001-monorepo-platform-build-roots.md (Context / Decision / Alternatives) / kasane/changes/kasane-initial-assets/exploration.md (ADR 候補 1) / kasane/roadmaps/v1-foundation/roadmap.md (前提 / 制約: リポジトリ構成)
