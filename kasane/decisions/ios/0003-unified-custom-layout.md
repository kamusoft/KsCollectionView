---
id: 0003
title: 全レイアウトを自前 compositional セクションで統一する (システム list 不使用)
status: accepted
date: 2026-09-01
---

## Context

layout 値 1 つで list / 固定列 / adaptive / 向き別列数を宣言する外形は core/ADR-0006 で決定済み。iOS 内部の実現として、リスト表示をシステム list (`UICollectionLayoutListConfiguration` / `.list(using:)`) に乗せるか、グリッドと同じ自前セクションで統一するかを決める必要があった。先行実装 KsSettingsViewUI は「レイアウトの差し替えは描画乱れを招くため、クロージャの実行時参照 + `invalidateLayout()` で切り替える」方式を実証している (ios/ADR-0001 で流用決定)。

## Decision

全レイアウトを自前の compositional セクションで実装し、リストは「1 列グリッド」として扱う。システム list は使わない。layout 値の切り替え (list⇄グリッド) と向きによる列数変化は、単一の sectionProvider が現在の layout 値を実行時参照し `invalidateLayout()` で再評価する形で扱う。

区切り線は list レイアウト専用のオプションとして**ライブラリが自前描画**で標準提供する (グリッドでは出さない)。Android 側も divider をライブラリが描き、同じ宣言・同じ既定で対称にする。既定値 (表示/非表示) と DSL 外形は core/ADR-0006 側で定める。

## Alternatives Considered

- **リストだけシステム list (`.list(using:)`)、グリッドは自前**: 却下。list⇄グリッド切り替えでレイアウトとセル基底クラス (`UICollectionViewListCell` / 素の Cell) の二系統を跨ぐことになり、先行実装が回避した「レイアウト差し替え時の描画乱れ」の再来リスクがある。システム list が運ぶスワイプアクション・アクセサリは v1 の非ゴールで、区切り線だけなら自前描画で足りる。iOS のリストだけシステムの見た目の既定 (セパレータ・インセット) が混入し、Compose 側 (`LazyColumn` は標準セパレータなし) と既定が食い違う

## Consequences

- 正: layout 値の全バリエーションが単一 sectionProvider で完結し、切り替え時の描画乱れリスクがない
- 正: 見た目の既定が両プラットフォームで一致する (「テンプレートが全て + list 専用の区切り線オプション」)
- 負: 将来スワイプアクション等のシステム list 機能を提供したくなった場合は自前実装になる (ただし Compose 側にもシステム提供はなく、対称提供するならどのみち自前)
- 負: 区切り線の描画・インセット処理をライブラリが両プラットフォームで自前保守する

出典: kasane/roadmaps/v1-foundation/phases/phase-2-ios-engine-foundation/history.md (2026-09-01: レイアウト) / core/ADR-0006 / ios/ADR-0001
