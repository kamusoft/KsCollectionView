---
id: 0001
title: KsCollectionView を SwiftUI / Compose の2プラットフォームライブラリとして新設する (MAUI 非対応)
status: accepted
date: 2026-08-31
---

## Context

旧 `../AiForms.CollectionView/` (Xamarin.Forms 時代の CollectionView ライブラリ) のリバイバルを検討した。並走調査 (相方 codex + ホスト側調査ワーカー、2ラウンド) の結果:

- 旧ライブラリの価値の大半 (リスト・グリッド・Pull to Refresh・ローディング・スクロール制御) は SwiftUI / Compose の標準 API に吸収済み
- MAUI 標準 CollectionView は機能面では要求をほぼ網羅 (`ReorderableItemsView` の D&D 含む)。残る差は品質・性能のみで、CV2 に Microsoft が集中投資中
- 旧 CollectionView の NuGet 実績は旧 SettingsView の約 6% (34.2K vs 559.3K DL)。なお調査時の「現役自社アプリにグリッド利用ゼロ」という所見は誤りで、Xamarin 時代の自社アプリ (調査対象リポジトリ群の外) で**グループ化 + ポートレイト/ランドスケープ可変グリッド**を実戦投入している
- 一方、SwiftUI と Compose では残る穴の場所が非対称 (Compose: リスト内 D&D の公式 API・shimmer / SwiftUI: グリッドのセル再利用・無限スクロールの状態機械) で、両プラットフォームで同じ機能セットを同じ書き方で使える手段は存在しない

本ライブラリの主目的は**自社アプリを KMP で量産する際に、リスト・グリッドをプラットフォーム間でできるだけ同じ書き方にすること**であり、OSS 公開は副次的な位置づけとする。

## Decision

KsCollectionView を **SwiftUI / Jetpack Compose の2プラットフォームライブラリ**として新設する。価値命題は「ネイティブ API のボイラープレート吸収」(旧ライブラリの命題) ではなく、**「リスト・グリッドの定型機能 (ローディング・無限スクロール・Pull to Refresh・仮想化・セクション/グループ化・D&D・ソート) を SwiftUI / Compose で同じ書き味で提供すること」** とする。MAUI facade は持たない。

## Alternatives Considered

- **KsSettingsView 型の三面構成 (Native engine + 宣言的ラッパー + MAUI facade) での新設**: 却下。MAUI 標準 CollectionView が機能面で既に充足しており価値命題が性能差でしか立たない / 需要実績が弱い / KsSettingsView・KsDialogs 未リリースのまま3本目の新築になる / RecyclerView が maintenance mode / 工数が KsSettingsView 実績 (約4ヶ月・約60k LOC) と同等以上。並走調査の追ラウンドで両調査者が No-Go に収束した
- **MAUI 単独に割り切り `../AiForms.Maui.NativeCollectionView/` を完成させる**: 却下。ユーザー判断として MAUI は今後サポートしない。現物も Linear のみでグリッド未実装であり「完成」の工数が大きい
- **独立ライブラリを作らず、残る穴を既存ライブラリ (KsSettingsView 等) の機能として吸収する**: 却下。「SwiftUI / Compose で同じ書き方」という対称 API 自体を製品価値とするため、独立した2プラットフォームライブラリの形を取る

## Consequences

- 正: MAUI interop (Bridge・Handler・binding) の実装・保守コストを負わない
- 正: SwiftUI / Compose という両陣営の投資先に乗るため、土台の陳腐化リスクが低い
- 正: 「プラットフォーム間の書き方の差の吸収」という、標準 API・既存 OSS のどちらも提供していない価値命題を持てる
- 負: 旧ライブラリのユーザー基盤 (NuGet の Xamarin / MAUI ユーザー) には届かない。実質的に新規ブランドの新製品になる
- 負: 外部 (OSS) 需要は未実証。ただし主目的が自社の KMP 量産であるため、成立性は外部需要に依存しない
- 負: KsSettingsView / KsDialogs が未リリースのまま並行開発になる (リソース配分の競合)

出典: kasane/changes/revival-feasibility/exploration.md (検討した選択肢・未決の論点)
