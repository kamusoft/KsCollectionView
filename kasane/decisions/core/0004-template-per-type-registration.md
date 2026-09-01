---
id: 0004
title: テンプレート宣言 — 値キーによる切り替えを基本形とする明示登録 DSL
status: accepted
date: 2026-09-01
---

## Context

異種セル (1 つのリストに複数種類の見た目が混在する) は roadmap のゴールであり、「再利用と両立する宣言形式」が要求されている。両プラットフォームの再利用機構はセルの種別申告を必要とする — iOS は種別ごとの `CellRegistration` で再利用プールが分かれ、Compose は `contentType` 一致のアイテム間でしかコンポジションを再利用しない。

当初はデータ型ごとの明示登録 (混在配列 `[any Identifiable]` を渡し、Swift の型でテンプレートを引く) を採用したが、オーナーレビューで棄却された: (1) 実際の開発では配列は単一の型で持ち、種別はモデルのプロパティ (enum 等) で表現する、(2) 型消去の吸収にライブラリ独自 protocol への準拠をモデルに強制するとデータが UI に引っ張られる、(3) KMP 共有モデル (Kotlin/Native export) は Swift の protocol に準拠できず使えない。

## Decision

**値キーによるテンプレート切り替えを基本形**とする。モデルが持つ種別プロパティをキーセレクタで宣言し、キー値ごとにテンプレートを登録する:

```swift
KsCollectionView(items, template: \.kind) {
    Template(.message) { item in MessageRow(item) }
    Template(.ad)      { item in AdCard(item) }
}
```

```kotlin
KsCollectionView(items, template = { it.kind }) {
    template(Kind.Message) { MessageRow(it) }
    template(Kind.Ad)      { AdCard(it) }
}
```

- 配列は単一型のプレーンな配列。モデルへのライブラリ独自 protocol の強制はしない
- キーは `Hashable` なら何でもよい (enum / String / Int 等)。キー値がそのまま再利用種別になり、iOS のキー別 `CellRegistration` / Compose の `contentType` はライブラリが自動導出する
- キーの集合は有限個 (セルの見た目の種類数) に収まっているのが正しい使い方。毎要素ユニークな値をキーにすると再利用が無効化する — 仕様では縛らずドキュメントで注意書きする
- 切り替え不要の単一テンプレートはクロージャ 1 つの軽量形: `KsCollectionView(items) { item in MessageRow(item) }`
- 型ベース切り替え (混在配列を Swift / Kotlin の型で分ける形) は副次変種として残してよい

## Alternatives Considered

- **データ型ごとの明示登録を基本形にする (当初案)**: 却下。異種混在の配列 (`[any ...]`) を持たせる開発は実態と合わず、Swift では存在型の ID 型消去・型間 ID 衝突・同値比較の吸収層が必要になる。吸収のためのライブラリ protocol 強制はモデルの純粋性を壊し、KMP 共有モデルでは準拠自体が不可能
- **単一コンテンツビルダー内で利用者が switch / when 分岐** (SwiftUI `ForEach` 流): 却下。ライブラリから全アイテムが同一種別に見え、異種セルで再利用プールが混ざり性能が劣化する。種別を別途申告させると宣言が二重になる
- **データ型自身にテンプレート提供の protocol / interface を実装させる**: 却下。データ層のモデルが UI に依存する設計を利用者に強制する

## Consequences

- 正: モデルが純粋なデータのまま使える (ライブラリ独自の準拠要求なし)。KMP 共有モデルもそのまま渡せる
- 正: 再利用種別の申告が宣言から機械的に得られ、「異種セル × 再利用」のゴールが構造的に成立する
- 正: 宣言構造が両言語で 1 対 1 対応し (core/ADR-0002)、Compose の `contentType` の流儀とも一致する
- 負: キーの有限性を静的に強制できない (誤用で再利用が無効化する余地。ドキュメントで担保)
- 負: 実行時に未登録のキー値がアイテムに現れうる。扱いは「debug ビルドは assertion で即停止、release ビルドは最小高の空セル + 警告ログで落とさない」とする (該当アイテムの非表示は、静かに消えて気づけず件数整合も崩すため不採用)

出典: kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/history.md (2026-09-01: テンプレート種別の宣言方法) / kasane/roadmaps/v1-foundation/phases/phase-2-ios-engine-foundation/history.md (2026-09-01: テンプレートマッピング (a)) / core/ADR-0002 / core/ADR-0003
