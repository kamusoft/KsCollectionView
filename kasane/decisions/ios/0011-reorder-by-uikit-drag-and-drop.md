---
id: 0011
title: iOS の並べ替えは UIKit 標準のドラッグ & ドロップの delegate で作り、差分データソースの並べ替えハンドラには頼らない
status: proposed
date: 2026-09-29
---

## Context

iOS のエンジンは UICollectionView + 差分データソース + 自前の compositional レイアウトで、利用者のグループの中を内部の塊 (差分データソースのセクション) に分け (ios/ADR-0003・ios/ADR-0009・ios/ADR-0010)、固定の見出しは標準の固定ではなくレイアウトが位置を上書きして作っている。並べ替えの契約は core/ADR-0026〜0033 で決めた: 仮の並びはライブラリが持って置いたときに 1 回知らせ、受け入れなければ戻し、行き先は項目で表し、置けるかの判定を持ち、スイッチが有効の間は長押しで持ち上げ、読み上げの移動操作を出し、ドラッグ中に届いた配列は保留する。

UIKit の手段は 3 つある。ドラッグ & ドロップの delegate (`.move` + `insertAtDestinationIndexPath`) は、ドラッグ中の隙間をプレースホルダが持ち、端での自動スクロールと VoiceOver のドラッグ操作が標準で付き (後者は経験則)、セクションをまたぐ移動もでき、ドラッグ中に置けないことを返す口がある。差分データソースの並べ替えハンドラ (`reorderingHandlers`) は、自前の compositional レイアウトでは呼ばれないという報告と Apple への不具合報告 (FB9753149) があり、2021 年時点で未解決。対話的な移動 (`beginInteractiveMovementForItem`) には自動スクロールが無く、持ち上げの見た目も自前になる。iPhone ではコレクションビューのドラッグが既定で無効である。iOS 27 の SwiftUI に標準の並べ替えが入ったが、最低 iOS 16 では使えず、UICollectionView ベースのエンジンからも使えないとみられる。

前提: ドラッグ & ドロップの delegate は、自前の compositional レイアウトと内部の塊 (複数セクション) で動く。自前の見出しの固定との干渉は未確認。

## Decision

iOS の並べ替えは、UIKit 標準のドラッグ & ドロップの delegate (drag delegate と drop delegate) で作る。差分データソースの並べ替えハンドラは使わない。ドロップ位置 (内部の塊と、その中の番号) はエンジンが項目の行き先 (core/ADR-0028) に読み替え、スイッチ (core/ADR-0031) に合わせてドラッグと長押しの認識器を切り替える。

## Alternatives Considered

- **差分データソースの並べ替えハンドラを使う**: 却下。書く量はいちばん少ないが、自前の compositional レイアウトでは呼ばれないという報告があり、頼れない。
- **対話的な移動を自前の長押しで駆動する**: 却下。長押しを自分で持つので調停しやすいが、端での自動スクロールと持ち上げの見た目を自前で作る必要があり、VoiceOver の標準のドラッグ操作も付かない。
- **iOS 27 の SwiftUI 標準の並べ替えを使う**: 却下。最低 iOS 16 では使えず、UICollectionView ベースのエンジンからも使えないとみられる。

## Consequences

- 正: 端での自動スクロール・持ち上げの見た目・VoiceOver のドラッグ操作が標準で付く。
- 正: 内部の塊をまたぐ移動を標準の仕組みで扱える。
- 正: ドラッグ中の置けない場所を標準の口で返せる。
- 負: 自前の見出しの固定 (位置の上書き) とドラッグ中の隙間の計算が干渉しないかを、実機で確かめる必要がある。
- 負: ドロップ位置を項目の行き先に読み替える層がエンジンに要る。
- 負: iPhone ではドラッグを明示的に有効にする手当てが要る。

## Revisit When

- 前提 (Context) が崩れたとき。最低対応 OS を iOS 27 以上に上げて SwiftUI 標準の並べ替えを使える見込みが立ったときは、置き換えを検討する

出典: kasane/roadmaps/v1-foundation/phases/phase-6-drag-reorder/history.md (2026-09-29: iOS の実装方式) / kasane/roadmaps/v1-foundation/phases/phase-6-drag-reorder/artifacts/platform-reorder-research-2026-09-29.md
関連: core/ADR-0026〜core/ADR-0033 (並べ替えの契約) / ios/ADR-0003・ios/ADR-0009・ios/ADR-0010 (自前のレイアウトと内部の塊)
