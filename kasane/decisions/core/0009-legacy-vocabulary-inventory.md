---
id: 0009
title: 旧 AiForms.CollectionView 公開契約の棚卸し — 引き継ぐ語彙と捨てる語彙
status: proposed
date: 2026-09-01
---

## Context

旧 AiForms.CollectionView (Xamarin.Forms 版) の README-ja.md にある全公開語彙を、phase-1 の8決定 (core/ADR-0002〜0008) と突き合わせて棚卸しした。

## Decision

**引き継ぐ (新 DSL の形に変換して継承)**:

- `ScrollController`: `KsScrollController` として継承 (同設計の実績が旧に実在)。端への命令名は向き中立の `scrollToStart` / `scrollToEnd` を継承する — 将来水平レイアウトを追加しても公開 API が壊れないため
- `LoadMoreCommand` + `SetLoadMoreCompletion` + `LoadMoreMargin`: ページング契約 (core/ADR-0005) に置換。completion コールバックの役割は `endReached` 状態が吸収。発火しきい値 (`LoadMoreMargin` 相当) は phase-5 で検討
- `PortraitColumns` / `LandscapeColumns` → `.fixed(portrait:landscape:)`、`AutoSpacingGrid` + `ColumnWidth` → `.adaptive(minItemWidth:)` (core/ADR-0006)
- Pull to Refresh 系 → 各流儀 + `refreshing` 状態 (core/ADR-0005)
- `ItemTapCommand` / `ItemLongTapCommand` / `TouchFeedbackColor`: `onItemTap { }` / `onItemLongTap { }` (型付きアイテムが渡る) + フィードバック色指定として継承 (既定はプラットフォーム標準の ripple / ハイライト)。iOS は UICollectionView のセル選択・ハイライト機構の正道で提供する — セル内 `onTapGesture` では得られない価値
- グループ化一式 (`IsGroupingEnabled` / `GroupHeaderTemplate` / `GroupHeaderHeight` / `IsGroupHeaderSticky`): phase-4 の議論素材として申し送り

**捨てる**:

- `IsInfinite` (水平無限循環): roadmap 非ゴール
- `HCollectionView` (水平リスト): v1 は縦のみ。素の Compose `LazyRow` は性能込みで書け、SwiftUI `LazyHStack` は再利用プールを持たないが実務の水平は少数カルーセルが大半で足りる。水平×大量件数の需要が出たら roadmap 改訂で追加する
- `CachingStrategy`: 再利用戦略は内部責務化し公開しない
- `ContentCell`: `UIHostingConfiguration` で不要
- `ColumnHeight` / `AdditionalHeight` / `ComputedWidth` / `ComputedHeight`: 旧 XF の手動サイズ計算の名残。セル自己サイズ計測で不要 (phase-2 の要件として申し送り)
- `GroupFirstSpacing` / `GroupLastSpacing` / `BothSidesMargin` / `SpacingType`: contentPadding / spacing の各流儀へ簡素化 (詳細は phase-4)

## Alternatives Considered

- **端への命令名を `scrollToTop` / `scrollToBottom` にする**: 却下。縦専用としては直感的だが、水平追加時に嘘の名前になり改名は破壊的変更
- **タップ系を捨てる (セル内で各流儀のタップ処理を書かせる)**: 却下 (オーナー判断で格上げ)。iOS ではセルハイライトの正道が利用者に書けず、両プラットフォーム同語彙の価値もある
- **v1 に水平リストを含める**: 見送り。roadmap ゴール外のスコープ拡大であり、必要時に roadmap 改訂で追加できる

## Consequences

- 正: 旧利用者 (自社) の概念移行が対応表1枚で説明でき、実績ある語彙 (`ScrollController` / 向き別列数) が新 DSL に生き残る
- 正: 旧のコールバック地獄 (`SetLoadMoreCompletion`) や手動サイズ指定 (`ColumnHeight` 系) が構造的に消える
- 負: 水平×大量件数のユースケースは v1 では両プラットフォームとも提供手段がない (iOS は素の `LazyHStack` の再利用なしで妥協)

出典: kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/history.md (2026-09-01: 旧 AiForms.CollectionView 公開契約の棚卸し) / ../AiForms.CollectionView/README-ja.md / core/ADR-0005 / core/ADR-0006 / core/ADR-0007
