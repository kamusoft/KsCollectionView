---
id: 0005
title: SwiftPM の product は KsCollectionView 単一とし、エンジンは同一モジュールの internal に置く
status: accepted
date: 2026-09-01
---

## Context

iOS エンジン基盤の実装にあたり、SwiftPM パッケージ `KsCollectionView` の product 構成を決める必要があった。公開識別子の決定 (cross/ADR-0003) は「product 名は `KsCollectionView` を接頭辞とする PascalCase。分割粒度はエンジン実装時に決める」としており、その残課題である。

先行実装 KsSettingsView は Core (モデル層) と UI の 2 product に分かれているが、それは Core に独立したモデル層があるためである。本ライブラリのモデルは利用者の型そのもの (プレーンな配列 + 安定 ID、core/ADR-0003) で、Core に置くものがほぼ無い。Android 側は単一 artifact と決まっている (cross/ADR-0003)。

## Decision

package `KsCollectionView` に product を 1 つ (`KsCollectionView`) だけ置き、公開 DSL とエンジンを同一モジュールに収める。エンジン型 (UICollectionView ベースの VC・セル・レイアウト生成・snapshot 計画) は `internal` とし、公開するのは DSL の入口 (`KsCollectionView` / `Template` / `KsCollectionLayout` / `KsGridColumns` / `KsScrollController` / `KsScrollPosition`) に限る。

## Alternatives Considered

- **`KsCollectionViewCore` / `KsCollectionViewUI` の 2 product 分割**: 却下。KsSettingsView は Core にモデル層を持つため分割の意味があったが、本ライブラリのモデルは利用者の型そのもので Core に置くものがほぼ無い。分割は import の説明コストだけ増やす。
- **エンジンを別 package に切る**: 却下。翻案移植 (ios/ADR-0001) の方針でエンジンは本ライブラリ専用であり、共有先が無い。

## Consequences

- 正: 利用者の import は常に 1 行で足り、公開契約 (handbook/cross/public-identifiers.md の接頭辞規則) 内で最小。Android の単一 artifact と対称になる。
- 正: 公開面が DSL の入口に限られるため、エンジン内部 (推定高さ・ホスティング配置・登録機構) の変更が公開 API に波及しない (実装結果: ライブ調整での `KsRowContentPlacement` / `KsEstimatedHeight` 追加は公開 API 不変で完了した)。
- 負: エンジンを他ライブラリや利用者が直接使う経路が無い。将来エンジンだけを再利用したくなった場合は product の追加 (公開面の拡張) が必要になる。

出典: kasane/changes/archive/2026-09-04-ios-engine-foundation/design.md (Decision 1) / kasane/changes/archive/2026-09-04-ios-engine-foundation/proposal.md (What Changes) / cross/ADR-0003 / ios/ADR-0001
現行照合: 2026-09-05 確認。公開型 `Template` は `KsTemplate` に改名済み (android-wrapper-foundation、命名のみで決定は不変)。product 単一・エンジン internal は維持。 判定: 維持
