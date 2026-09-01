---
id: 0001
title: iOS エンジンは KsSettingsViewUI の設計パターンを翻案移植する
status: accepted
date: 2026-09-01
---

## Context

iOS エンジン基盤 (UICollectionView + diffable data source + `UIHostingConfiguration`、core/ADR-0001) を実装するにあたり、同型のエンジンを持つ先行実装 KsSettingsViewUI (`../KsSettingsView/ios/Sources/KsSettingsViewUI/`) の取り込み方を決める必要があった。調査の結果、先行実装は次のように切り分けられた:

- 汎用に効く骨格: 識別子だけを snapshot に載せる diffable 構成 (identity と内容を分離し、内容更新は `reconfigureItems`)、データ型 → セル型の遅延登録つき解決機構 (`KsCellRegistry` / `KsCellRenderer`)、`UIHostingConfiguration` を `contentConfiguration` に差すセルホスティング一式 (自己サイズ補正・中央配置はみ出し対策込み)、SwiftUI ラッパーの「宣言ツリー → diff 計算 → Store 経由で流す」構成、レイアウトを差し替えず「クロージャの実行時参照 + `invalidateLayout()`」で切り替える方式 (差し替え時の描画乱れ回避の実績)
- 設定画面特化で流用できない部分: セクション箱の装飾レイアウト・Theme 配布契約・罫線ルール、および「セクション必須・セル型有限」前提のデータモデル。レイアウトは `.list` 固定でグリッド (多列・adaptive) の経路が存在しない

旧 AiForms.CollectionView (`../AiForms.CollectionView/CollectionView.iOS/`) は、当時の 3 課題 (レンダラ寿命管理・手動フレーム配り・固定高さ) が `UIHostingConfiguration` 方式で解消済みのため、方式面での持ち帰りはない。

## Decision

KsSettingsViewUI の設計パターンとコードを**翻案移植** (コピーして汎用化) する。パッケージ依存や共通基盤の切り出しは行わず、両ライブラリは独立に保守する。上記「汎用に効く骨格」を出発点とし、グリッド経路 (多列・adaptive) は新規実装する。

## Alternatives Considered

- **共通基盤をパッケージに切り出し KsSettingsView と共有**: 却下。KsSettingsView 側の改修とリリース調整が発生し、変更が相手に波及する lockstep 保守になる。設定画面前提の型が共通層に残り、汎用要件 (任意の型・グリッド) への適合も悪い。将来 2 ライブラリの共通部分が増えた時点で改めて判断する
- **ゼロから新規設計 (先行実装は読み物としてのみ)**: 却下。再利用・自己サイズ・レイアウト差し替え時の描画乱れなど、先行実装が実測で解決済みの罠を再び踏むことになり、コストに見合わない

## Consequences

- 正: 実証済みの対策 (描画乱れ回避・`UIHostingConfiguration` の中央配置はみ出し対策・自己サイズ補正) を初版から継承できる
- 正: 両ライブラリが独立に進化でき、リリース調整が不要
- 負: 同種のコードが 2 リポジトリに併存し、共通部分のバグ修正は手動で相互反映する必要がある
- 負: 翻案時の汎用化 (Theme 依存の除去・データモデルの置き換え) の品質はこのリポジトリ側で新たに検証する必要がある

出典: kasane/roadmaps/v1-foundation/phases/phase-2-ios-engine-foundation/history.md (2026-09-01: エンジン構成)
