---
id: 0008
title: 画像プリフェッチの DSL 外形 — prefetchResources クロージャ + 専用 KsImage の対
status: accepted
date: 2026-09-01
amended-by: 0013
---

## Context

画像グリッドは本ライブラリの最頻ユースケースで、プリフェッチは性能価値の中核。仕組み上「もうすぐ表示されるアイテム」はライブラリが知り (iOS `UICollectionViewDataSourcePrefetching` / Compose のキャッシュウィンドウ)、「そのアイテムが必要とする画像」は利用者しか知らない。さらにプリフェッチが効くのは、セル内で描画する画像コンポーネントが同じローダ・キャッシュを見ている場合だけで、分断すると二重ダウンロードになる。詳細設計は phase-8-image-loading の責務で、本 ADR は DSL 外形のみを定める。

## Decision

- アイテム → 必要リソースの対応を**クロージャで宣言**させる: Swift は modifier `.prefetchResources { item in [URL] }`、Kotlin は名前付き引数 `prefetchResources = { item -> listOf(url) }` (記法差は core/ADR-0002)。なお旧 AiForms.CollectionView は画像機能を持たず FFImageLoading の利用を README で推奨していた — 本決定はその外部依存推奨を `KsImage` として内蔵化するもの
- プリフェッチと**同一ローダ・キャッシュを見る専用画像コンポーネント `KsImage`** を対で提供する。「プリフェッチ宣言と `KsImage` はセットで効く」という契約を DSL の見た目が示す
- データ型にはプロトコル / interface 準拠を課さない。対応表は宣言側に置く (core/ADR-0004 と同じ思想)

## Alternatives Considered

- **データ型にリソース列挙のプロトコル / interface を実装させる**: 却下。データ層がライブラリの型に準拠する結合が生まれる (ADR-0004 でデータ型へのテンプレート実装を却下したのと同根)
- **画像を守備範囲外とする (プリフェッチ API を持たない)**: 却下。「もうすぐ表示」のタイミング情報はライブラリの外に出せず、利用者が Nuke / Coil を自力接続しても片手落ち。プリフェッチ⇔描画のキャッシュ分断で二重ダウンロードになる

## Consequences

- 正: 表示予測 (ライブラリ) × リソース対応表 (利用者) の分担が1クロージャで接続され、データ層は非結合のまま
- 正: phase-8 はこの外形の内側 (ローダ選定・キャッシュ設計・`KsImage` の機能範囲) を自由に設計できる
- 負: `KsImage` を使わない既存の画像コンポーネントとはプリフェッチキャッシュが共有されない。その場合の扱い (連携口を設けるか) は phase-8 で判断する

出典: kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/history.md (2026-09-01: 画像プリフェッチのリソース宣言と専用画像コンポーネント) / core/ADR-0002 / core/ADR-0004
