---
id: 0004
title: テンプレート宣言 — データ型ごとの明示登録 DSL、型を再利用種別として自動導出
status: proposed
date: 2026-09-01
---

## Context

異種セル (複数のデータ型が混在する配列を型ごとに違う見た目で描く) は roadmap のゴールであり、「再利用と両立する宣言形式」が要求されている。両プラットフォームの再利用機構はセルの種別申告を必要とする — iOS は種別ごとの `CellRegistration` で再利用プールが分かれ、Compose は `contentType` 一致のアイテム間でしかコンポジションを再利用しない。

## Decision

データ型ごとにテンプレートを明示登録する DSL とする:

```swift
KsCollectionView(items) {
    Template(for: Message.self) { msg in MessageRow(msg) }
    Template(for: AdBanner.self) { ad in AdCard(ad) }
}
```

```kotlin
KsCollectionView(items) {
    template<Message> { msg -> MessageRow(msg) }
    template<AdBanner> { ad -> AdCard(ad) }
}
```

- 登録はデータ型 → View の対応表であり、画面の宣言側に置く。データ型自身は UI を知らない
- 型がそのまま再利用種別になり、iOS の型別 `CellRegistration` / Compose の `contentType` はライブラリが自動導出する
- テンプレートのクロージャは該当型にキャスト済みで型安全

## Alternatives Considered

- **単一コンテンツビルダー内で利用者が switch / when 分岐** (SwiftUI `ForEach` 流): 却下。ライブラリから全アイテムが同一種別に見え、異種セルで再利用プールが混ざり性能が劣化する。種別を別途申告させると宣言が二重になる
- **データ型自身にテンプレート提供の protocol / interface を実装させる**: 却下。データ層のモデルが UI に依存する設計を利用者に強制する

## Consequences

- 正: 再利用種別の申告が宣言から機械的に得られ、「異種セル × 再利用」のゴールが構造的に成立する
- 正: 宣言構造が両言語で1対1対応する (core/ADR-0002)
- 負: 単一型のリストでも登録1つの宣言を要する (`ForEach` より一段厚い)
- 負: 実行時に未登録の型がアイテムに現れうる。その扱い (クラッシュ / 空セル / debug 警告) を仕様で定める必要がある

出典: kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/history.md (2026-09-01: テンプレート種別の宣言方法) / core/ADR-0002 / core/ADR-0003
