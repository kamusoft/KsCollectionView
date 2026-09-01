---
id: 0003
title: コレクションの状態モデル — プレーンな配列 + 安定 ID 必須、差分更新はライブラリの責務
status: accepted
date: 2026-09-01
---

## Context

iOS エンジンは diffable data source を使い (core/ADR-0001)、アイテムの安定な識別子を内部要求する。Compose 側も `key` が安定しないと差分アニメ・状態保持・並べ替えが壊れる。両プラットフォームとも内部が安定 ID を要求することは確定しており、それを利用者にどう見せるかが論点だった。

## Decision

- 利用者は**プレーンなデータ配列**を渡す。専用のコレクション型・スナップショット型は要求しない
- **安定 ID を必須**とする。宣言方法は各流儀に従う (core/ADR-0002): Swift は `Identifiable` 準拠**または `id:` キーパス指定の二本立て** (`ForEach` と同型)、Kotlin は `key` ラムダ。キーパス指定は KMP 共有モデル (Kotlin/Native export のクラスは Swift protocol に準拠できない) の無改造利用を支える
- **差分計算と移動/挿入/削除アニメの適用はライブラリの責務**。利用者はデータを差し替えるだけ
- 内容変更の検知: iOS はアイテムの同値比較 (`Equatable` / NSObject `isEqual`) による再構成 (reconfigure)、Android は再コンポーズで自動。KMP 共有モデルは Kotlin/Native の equals → `isEqual` 写像により data class なら構造比較が自動成立する (data class でない場合は参照比較 — ドキュメント注意書き)

## Alternatives Considered

- **スナップショット / 差分命令を利用者に明示的に組ませる**: 却下。UIKit diffable の概念が Compose 側に存在せず対称性が破綻する。宣言的 UI の書き味にも反する
- **安定 ID を要求しない位置ベース**: 却下。差分アニメ・セル再利用・D&D 並べ替え (phase-6) が成立しない

## Consequences

- 正: SwiftUI `ForEach` / Compose `key` と同型の、利用者が既に知っている契約になる
- 正: iOS diffable / Compose key の内部要求と直結し、変換層が薄い
- 負: 安定 ID は利用者のデータ型に課す要求であり、後から課し直すことはできない片方向の契約になる
- 負: iOS は `Equatable` 準拠も事実上要求する (内容変更検知のため)。Swift の値型では通常自動合成されるが、契約として明示が必要

出典: kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/history.md (2026-09-01: コレクションの状態モデル) / kasane/roadmaps/v1-foundation/phases/phase-2-ios-engine-foundation/history.md (2026-09-01: テンプレートマッピング (a)) / core/ADR-0001 / core/ADR-0002
