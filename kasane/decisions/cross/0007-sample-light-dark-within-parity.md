---
id: 0007
title: Sample のライト / ダーク対応は、両プラットフォーム同値の 2 組の配色と同じ切り替えで行い、パリティの範囲内とする
status: accepted
date: 2026-09-26
---

## Context

iOS / Android の Sample は、Sample 共通の配色定義 (`SampleTheme`) の固定の明るい色で描かれ、端末の表示モードに追随しない。一方、OS の部品 (ナビゲーションバーの題名・ステータスバー・segmented の Picker 等) とライブラリの一部の既定色 (スクロールインジケータ等) は表示モードに従う。このため端末をダークにすると、明るい背景の上に白い文字やインジケータが描かれて読めなくなり、Sample が検証装置として使えなくなる。オーナー判断で、Sample の中でライト / ダークを切り替えられるようにする。

Sample は両プラットフォームで同じ文言・同じ画面構成・同じ RGBA で描く検証装置である (cross/ADR-0004)。その規約本文 (`kasane/handbook/cross/sample-parity.md`) は、色を OS の semantic color にせず同じ RGBA を `SampleTheme` に置くことと、「dark mode 追随のようなプラットフォームらしさより一致を優先する」ことを定めている。後者は文面の上ではダーク対応と衝突する。兄弟リポジトリ KsSettingsView の Sample は同じ規約のまま 2 組の配色による切り替えを入れ、規約の文面は改めずに残している。

前提: Sample の色はすべて `SampleTheme` の定数を経由して描かれ、両プラットフォームの Sample が同じ切り替えを持てること。

## Decision

- Sample の配色定義 (`SampleTheme`) にライトとダークの 2 組の RGBA を持たせ、両プラットフォームで同じ値にする。Sample に色を足すときは 2 組を足す
- どちらの組で描くかは、Sample の中に置く切り替えで決める。切り替えは両プラットフォームで同じ文言・同じ選択肢にする
- この形のダーク対応はパリティの範囲内として扱い、sample-parity の規約の「dark mode 追随より一致を優先する」の一文を、この形を許す文面に改める。OS の semantic color に任せる追随は引き続き禁止する

## Alternatives Considered

- **規約の文面を改めず、変更の記録で規約の趣旨に反しないと説明する** (KsSettingsView の進め方): 却下。規約の文面と Sample の実物が食い違ったまま残り、以後のレビューや棚卸しでそのたびに規約違反として拾われる。
- **OS の semantic color に任せて表示モードに追随させる**: 却下。実値がプラットフォーム間でずれ、同じ RGBA での比較が成り立たない (sample-parity の規約の既存の理由)。

## Consequences

- 正: 端末がダークでも Sample が崩れず、検証装置として使い続けられる。
- 正: ライトとダークのそれぞれで、同じ RGBA の上に置いたライブラリの既定の色を両プラットフォームで比べられる。
- 正: 規約の文面と Sample の実物が一致し、ダーク対応が規約違反として拾われない。
- 負: Sample に色を足すたびに、ライトとダークの 2 組を決めて両プラットフォームに足す手間が増える。
- 負: `SampleTheme` を経由しない色 (直書きや OS の色) が残ると、ダークでだけ崩れる。ライトだけの目視ではその崩れに気づけない。

## Revisit When

前提 (Context) が崩れたとき。

出典: kasane/changes/archive/2026-09-26-sample-dark-mode-toggle/exploration.md (課題 / 動機・決定事項・検討した選択肢) / kasane/changes/archive/2026-09-26-sample-dark-mode-toggle/proposal.md (What Changes) / kasane/handbook/cross/sample-parity.md (保証すること) / ../KsSettingsView/kasane/changes/archive/2026-09-05-add-sample-dark-mode-toggle/proposal.md (What Changes)
関連: cross/ADR-0004 (Sample をパリティ検証装置と位置づける決定。この ADR はその規約本文の一文を改める)
