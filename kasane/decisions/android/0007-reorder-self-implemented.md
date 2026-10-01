---
id: 0007
title: Android の並べ替えは Compose の上に自前で作り、OSS には依存も取り込みもしない
status: accepted
date: 2026-09-29
---

## Context

Android のラッパーは LazyVerticalGrid の薄いラッパーで (android/ADR-0001)、単一モジュールで組み (android/ADR-0002)、項目と見出しに `animateItem` を付けている (android/ADR-0006)。Compose Foundation には Lazy 系の公式の並べ替え API が無い。並べ替えの契約は core/ADR-0026〜0033 で決めた: 仮の並びはライブラリが持って置いたときに 1 回知らせ、見出しをまたいで別のグループへ動かせ、置けない場所には入らず、ドラッグ中に届いた配列は保留する。

候補の OSS `sh.calvin.reorderable` (v3.1.0、Apache-2.0) は LazyVerticalGrid に対応し、端での自動スクロール・先頭の項目を動かしたときの位置飛び・持ち上げの見た目を解いている。一方で、置けない場所で並びを変えないとドラッグ中の項目が指からずれて固まる作りで、事前に判定する口が無い (推測を含む)。span の異なるグリッドでつかみが切れる不具合 (#93) やつかみ切れ (#103) が未解決で、依存にすると `org.jetbrains.compose.*` の成果物が利用者の依存に加わる。保守はほぼ作者 1 人で、2026 年のコミットは 2 件である。グリッドに要る部分を取り込むと約 1,500 行になる。

前提: Compose の公開 API (LazyGridState の配置の情報・スクロール・`animateItem`) だけで並べ替えを組める。

## Decision

Android の並べ替えは、Compose の公開 API の上に自前で作る。`sh.calvin.reorderable` には依存せず、ソースの取り込みもしない。

## Alternatives Considered

- **`sh.calvin.reorderable` に依存する**: 却下。書く量はいちばん少ないが、置けない場所に入らない契約 (core/ADR-0030) をきれいに作れず、グリッドの見出しまたぎで不具合 (#93) に当たりうる。直すには作者を待つしかなく、その実装も止まり気味で、利用者の依存に `org.jetbrains.compose.*` が加わる。
- **グリッド向けのソース (約 1,500 行) を取り込み、手を入れて自分で持つ**: 却下 (オーナー判断。却下の理由は出典に記載が無い)。推奨側の理由は、置けるかの判定を小さな改変で足せる、難所は解いてあるものを使える、不具合を自分で直せる、ios/ADR-0001 の前例がある、だった。

## Consequences

- 正: 並べ替えの契約 (仮の並び・見出しまたぎ・置けない場所・ドラッグ中の保留) を最初から作り込める。
- 正: 利用者の依存は増えず、第三者のライセンスの表示や、取り込んだ英語のコメントの扱いも要らない。
- 負: 端での自動スクロール、先頭の項目を動かしたときの位置飛び、ドラッグ中の項目の持ち上げ、移動直後の表示のつなぎを一から解く必要がある。
- 負: 自分で持つコードの量が、取り込む場合より大きくなる見込み。

## Revisit When

- 前提 (Context) が崩れたとき。Compose Foundation に Lazy 系の公式の並べ替え API が入ったときは、置き換えを検討する

出典: kasane/roadmaps/v1-foundation/phases/phase-6-drag-reorder/history.md (2026-09-29: Android の実装方式) / kasane/roadmaps/v1-foundation/phases/phase-6-drag-reorder/artifacts/reorderable-oss-assessment-2026-09-29.md / kasane/roadmaps/v1-foundation/phases/phase-6-drag-reorder/artifacts/platform-reorder-research-2026-09-29.md
関連: core/ADR-0026〜core/ADR-0033 (並べ替えの契約) / android/ADR-0001 (LazyVerticalGrid に統一) / android/ADR-0006 (`animateItem`) / core/ADR-0012 (画像ローダーへの直接依存の前例)
