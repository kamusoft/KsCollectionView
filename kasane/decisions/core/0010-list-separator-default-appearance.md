---
id: 0010
title: list の区切り線の既定外観 — 先頭行の上端・行間・最終行の下端に全幅 1pt の固定色で描く
status: accepted
date: 2026-09-02
amended-by: 0016
---

## Context

レイアウト指定の決定 (core/ADR-0006) で、list レイアウトの区切り線は「既定で表示、明示オプションで非表示、両プラットフォームともライブラリの自前描画」と決まっていたが、線をどこに・どの太さと色で描くかは決まっていなかった。iOS エンジン基盤の実装では当初「行の間だけ、左端にインセットを持つ 1 物理ピクセルの hairline、色はシステムの semantic color」で実装し、オーナーが Simulator と実機で確認した結果、次の 3 点が確定した。

- hairline は Retina 上でも薄すぎて判別しづらい
- 行の間だけでは、リストの上下の境界が示されない
- 色をシステムの semantic color にすると、Sample の確定トークンと Android 実装との色比較が同じ実値で成立しない

## Decision

list レイアウトの区切り線の既定外観を次のとおりとする。

- 位置: 先頭行の上端、各行の間、最終行の下端。リスト全体の上下境界を同じ線で明示する
- 幅: セルの左右いっぱい (インセットなし)
- 太さ: 1pt (物理ピクセルではなく論理ポイント)
- 色: 既定はライブラリ内部の固定値 `#D9D9DE` (Sample の確定トークンと同じ実値)。利用者は独立した語彙 `listSeparatorColor` (Swift: `.listSeparatorColor(_:)` modifier / Kotlin: `listSeparatorColor =` 引数) で変更できる。表示の有無 (`listSeparators`) とは別語彙にし、両プラットフォームで 2 語彙が 1 対 1 に対応する (core/ADR-0002)。`listSeparators` の引数に色を足す形は Kotlin 側で引数が 2 つに割れて対応が崩れるため、表示と色をまとめた値型は既存の Bool 形を壊すため、いずれも採らない (2026-09-04 改訂。Android 実装で両プラットフォームの描画を突き合わせてから accepted にする)
- opt-out: `listSeparators(false)` で全て非表示。グリッドでは描かない (core/ADR-0006)
- 描画順: 線は content の前面に描く。不透明な背景を持つテンプレートでも線が隠れない (Android 実装の突き合わせで判明した未記載事項、2026-09-05 追記)

Android 実装は同じ位置・太さ・色・描画順で描き、Sample のプラットフォーム間比較を同じ実値で成立させる (cross/ADR-0004)。両プラットフォームの実装を突き合わせて一致を確認した (2026-09-05)。

## Alternatives Considered

- **1 物理ピクセル相当の hairline**: 却下。Retina 上でも薄すぎて視認しづらいとオーナーが Simulator で判定した。
- **行の間だけに描く (外周に線を出さない)**: 却下。リストの上下境界が示されず、ヘッダー/フッターや周囲の余白との境目が曖昧になる。
- **左端にインセットを持たせる (翻案元 KsSettingsViewUI の 16pt ルール)**: 却下。全幅で描く外観をオーナーが実機確認で確定したため、インセット規則は不要になった。
- **色をシステムの semantic color にする**: 却下。Sample と後続の Android 実装の色比較を同じ実値で成立させるため、既定は固定値にした。
- **色を変える公開 API を設けない**: 当初はそうしたが 2026-09-04 に改訂。利用者がアプリの配色に合わせられないため `listSeparatorColor` を追加した。
- **線を content の背面に描く**: 却下。Android の初版はこの形だったが、不透明な背景を持つテンプレートでは線が 1 本も見えず、iOS (前面) と食い違った。

## Consequences

- 正: 両プラットフォームで同じ位置・太さ・色になり、Sample の視覚比較がそのまま成立する。
- 正: 公開 API は表示の有無 (`listSeparators`) と色 (`listSeparatorColor`) の 2 語彙で、両プラットフォームで 1 対 1 に対応する。
- 負: 色の既定値は固定値のため、アプリのテーマに追随させたい利用者は自分で色を指定する必要がある。
- 負: 「全セルの下端に線」の規則は、セクション対応でセクション境界に前セクションの下線と次セクションの上線が重なる。セクション境界の規則はセクション/グループ化機能の設計で決める。
- 負: 線はセルの底辺に描かれるため、`rowSpacing > 0` では行間の中央ではなく各行の直下に出る。

## Revisit When

- セクション/グループ化機能でセクション境界の区切り線規則を決めるとき (「全セルの下端に線」との重なりの解消)
- 前提 (Context) が崩れたとき

出典: kasane/roadmaps/v1-foundation/phases/phase-3-android-wrapper-foundation/history.md (2026-09-04: 論点 5 セルの装飾と入力) / kasane/changes/archive/2026-09-04-ios-engine-foundation/deviation.md (list の区切り線 4 件、2026-09-02) / kasane/changes/archive/2026-09-04-ios-engine-foundation/design.md (Decision 3) / kasane/changes/archive/2026-09-05-android-wrapper-foundation/deviation.md (区切り線の描画順、2026-09-05) / kasane/changes/archive/2026-09-05-android-wrapper-foundation/evidence/adr-alignment.md / core/ADR-0006 / ios/ADR-0003
