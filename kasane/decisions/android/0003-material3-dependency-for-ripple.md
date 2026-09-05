---
id: 0003
title: ライブラリは material3 に依存し、タップのフィードバックは標準 ripple を既定にする
status: accepted
date: 2026-09-04
---

## Context

コレクションの操作契約 (concepts/core/core-model/collection-interaction.md) は「ハンドラを宣言した項目だけがフィードバックを出し、既定のフィードバックはプラットフォーム標準の塗り」と定める。Compose では項目のタップに `combinedClickable` を使い、フィードバック (indication) を何にするかを決める必要がある。Compose Foundation だけで書くと indication は `LocalIndication.current` になり、`MaterialTheme` を置かないアプリではデバッグ用の塗りが既定になる。

Android のラッパーは薄く保つ (android/ADR-0001)。ライブラリの依存は利用者アプリの推移依存になり、Compose の版方針 (android/ADR-0002) と同じく利用者への影響を持つ。ページング状態機械のフェーズで実装する Pull to Refresh は material3 の `PullToRefreshBox` を使う方針が固まっている。

前提: 利用者アプリは Jetpack Compose を使う (material3 を使っているかは問わない)。

## Decision

ライブラリは `androidx.compose.material3` に依存する。`onItemTap` / `onItemLongTap` のいずれかが宣言された項目だけを `combinedClickable` で包み、indication は `touchFeedbackColor` 未指定なら material3 の標準 ripple、指定時は `ripple(color = 指定色)` とする。

## Alternatives Considered

- **Foundation の `LocalIndication.current` だけを使い material3 に依存しない**: 却下。`MaterialTheme` を置かないアプリでは既定 indication がデバッグ用の塗りになり、「既定は標準 ripple」の契約が崩れる。material3 は Pull to Refresh でも必要になる

## Consequences

- 正: 利用者アプリのテーマの有無に関わらず、既定のフィードバックが標準 ripple になる
- 正: Pull to Refresh (`PullToRefreshBox`) の依存を先に持てる
- 負: 利用者アプリへの推移依存が増える (android/ADR-0002 の「最新安定に追随」と同じ受容範囲)
- 負 (実装結果): material3 の `ripple` は渡した色に自前で不透明度を掛けるため、`touchFeedbackColor` の意味論が iOS (渡した色をそのまま塗る) と非対称になった。Sample「リスト」は描画結果を揃える値を渡して回避しているが、利用者が同じ値を書いたときの見え方は揃わない。統一は後続の変更で扱う (kasane/changes/archive/2026-09-05-android-wrapper-foundation/deviation.md 4 件目)

## Revisit When

- 前提 (Context) が崩れたとき
- `touchFeedbackColor` の意味論を両プラットフォームで統一する決定を下すとき (ripple の色の扱いが本決定の帰結にある)

出典: kasane/changes/archive/2026-09-05-android-wrapper-foundation/design.md (Decision 6・ADR 候補) / kasane/roadmaps/v1-foundation/phases/phase-3-android-wrapper-foundation/history.md (2026-09-04: 論点 5 セルの装飾と入力) / kasane/changes/archive/2026-09-05-android-wrapper-foundation/deviation.md (`touchFeedbackColor` の非対称、2026-09-05) / android/ADR-0001 / android/ADR-0002
