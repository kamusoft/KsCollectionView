---
id: 0006
title: 配列の差し替えによる項目と見出しの移動・挿入・削除を、Android でも `animateItem` でアニメーションさせる
status: proposed
date: 2026-09-24
amends: 0004
---

## Context

core/ADR-0003 は、差分計算とアニメーションの適用をライブラリの責務と決めた。iOS は diffable data source が移動・挿入・削除をアニメーションで見せる。Android の Compose Lazy 系で項目の移動・挿入・削除を動かして見せる手段は `Modifier.animateItem()` だけだが、android/ADR-0004 は行の高さ変化の補間 (`ksAnimatedHeight`) を決めたとき「`animateItem` は重ねない」とした。そのため今の Android は、配列を差し替えると項目が新しい位置へ一瞬で飛ぶ。

ADR-0004 が `animateItem` を退けた理由は、高さ変化の補間に重ねても押し出される行の動きは良くならず、性能の上乗せ (2 列グリッドのフレーム CPU 時間 P90 +19.4%、`animateContentSize` との組み合わせで計測) だけが残ったことだった。項目の移動・挿入・削除を見せる目的では検討していない。

セクション / グループ化機能 (change `sections-grouping`) で、グループをまたぐ項目の移動とグループの並べ替えを見せる必要が出た。後続の D&D 並べ替え機能でも、ドラッグ中に項目がどいて動く見え方に同じ手段が要る。

前提: `ksAnimatedHeight` と `animateItem` を同じ項目に付けたときの性能と見え方は、決定の時点で測っていない。

## Decision

android/ADR-0004 の決定のうち「`animateItem` は重ねない」を本決定で置き換える。高さ変化の補間 (`ksAnimatedHeight`) とその利用契約は維持する。

配列の差し替えによる項目とセクションの見出しの移動・挿入・削除を、Android でも `animateItem` でアニメーションさせる。付ける位置 (既存の modifier との順序)、出入りの見せ方 (フェードの有無)、高さ変化の補間と重なったときの扱いは、使い捨ての試作をオーナーが目視して決める。性能は、handbook/android/performance-verification に従って比較対象にも `animateItem` を付けて相対基準を測り、`animateItem` 自体の費用は「なし / あり」の比較を証跡に残して体感のゲート (cross/ADR-0006) で判断する。

## Alternatives Considered

- **ADR-0004 に従い、Android の移動のアニメーションを D&D 並べ替え機能まで先送りする**: 却下。D&D 並べ替え機能の実装時期は決まっておらず、同じ判断をいずれ解く必要がある。先送りしても解くコストは変わらず、その間 Android だけ項目が飛ぶ見え方が残る。

## Consequences

- 正: 配列の差し替えの見え方が iOS と揃い、差分のアニメーションをライブラリの責務とする core/ADR-0003 を Android でも満たす。
- 正: D&D 並べ替え機能は、項目がアニメーションで動く前提から始められる。
- 負: 全項目に `animateItem` が付き、スクロール中の性能に上乗せが出うる。既定機能として比較対象にも付けるため相対基準には現れず、体感で不合格なら付け方を見直す必要がある。
- 負: 高さ変化の補間と配置のアニメーションが同じ項目で同時に動く場面が生まれ、見え方と性能の両方で組み合わせを保守する。

## Revisit When

- 体感のゲートで、`animateItem` を原因とする不合格が出たとき
- Compose が項目の配置のアニメーションを別の手段で提供したとき

出典: kasane/changes/sections-grouping/ (提案作成時の自己レビューで android/ADR-0004 との衝突を検出し、オーナーが改訂を選択。2026-09-24) / kasane/roadmaps/v1-foundation/phases/phase-4-sections-grouping/history.md (2026-09-24: Android の差分の移動アニメーション)
関連: core/ADR-0003 (差分とアニメーションはライブラリの責務) / android/ADR-0001 (LazyVerticalGrid への統一)
