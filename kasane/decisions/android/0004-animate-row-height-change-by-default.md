---
id: 0004
title: 行の高さ変化を既定でアニメーションさせ、補間中は content を行の高さで測り直して切り取る
status: accepted
date: 2026-09-05
amended-by: 0006
---

## Context

デルタスペックは「項目の高さはコンテンツに応じて自動決定される」ことだけを定めていた。Android 固有の検証画面「検証: 行の高さ変化」をオーナーが実機で操作したところ、行の展開・折りたたみで高さが 1 フレームで飛び、押し出される他の行も飛んでいた。参照実装の RecyclerView (KsSettingsView) は既定のアニメータで行高の変化がアニメーションされ、iOS 側 (UICollectionView) も行の高さ変化がアニメーションされることをオーナーが確認済みだった。Android だけがアニメーションしない状態は両プラットフォームの見え方を揃える方針 (cross/ADR-0004) に反する。

補間の方法には Compose 標準の `animateContentSize` があるが、これは子を新しい自然高で測ってから外へ報告するサイズだけを補間する。縮む向きでは content の下端が最初のフレームで折りたたみ後の位置へ飛び、区切り線が降りてくるまでの間にページ背景の帯が見える (実機の連続静止画で帯 261 px → 0 px の A/B)。項目の配置アニメーション (`animateItem`) を重ねると 2 列グリッドのフレーム CPU 時間 P90 が +19.4% になる。

前提: 大量件数のスクロール性能の合格基準 (handbook/android/performance-verification.md) を満たすこと。

## Decision

行の高さが変わるときはライブラリの既定の挙動としてアニメーションさせる (展開する項目自身の高さ変化と、それに押される他の項目の移動)。実現は自前の高さ補間 modifier (`ksAnimatedHeight`) で行い、次を守る。

- 補間している間は content もその時点の行の高さで測り直す。content の背景・枠が箱の高さと同じ量で伸び縮みし、区切り線・タップ領域との間に何も描かれない帯ができない
- 補間している間は描画を行の高さで切り取る (渡した制約に従わない content が行の外へ描かれないため)。補間していない通常時は切り取らない。切り取りは描画時に行い、合成レイヤは作らない
- 最初の測定では補間しない (高さ 0 から伸びる動きを出さない)。項目が再利用されたとき直前の項目の高さを持ち越さない
- `animateItem` は重ねない
- 利用契約: テンプレートの根の Composable には行の高さが制約として渡る。根が制約を使わない透明な箱で本体を包むと折りたたみの途中に隙間が見えるため、根で背景を塗るか `Box` に `propagateMinConstraints = true` を付ける。KDoc と dsl-samples に明記する

## Alternatives Considered

- **アニメーションさせない (スペックどおり高さの自動決定のみ)**: 却下。RecyclerView の既定と iOS の挙動に対して Android だけが飛ぶ動きになる (オーナー実機確認)
- **Compose 標準の `animateContentSize` を項目の箱に付ける**: 却下。縮む向きで content が先に縮み、行の枠との間にページ背景の帯が約 240 ms 出る。この版の `animateContentSize` にクリップを外す引数は無く、常時の合成レイヤが大量件数の上乗せにもなる
- **`animateContentSize` + `animateItem`**: 却下。押し出される行の移動は高さの補間だけで段階を踏み、`animateItem` は性能の上乗せ (2 列 P90 +19.4%) だけが残る

## Consequences

- 正: 行の高さ変化の見え方が iOS・RecyclerView と揃う。中間フレームは 23 本 (Pixel 4a)、帯は全フレーム 0 px
- 正: 補間は描画時の切り取りだけで済むため、`animateContentSize` 採用時より大量件数のフレーム CPU 時間が良い側に動いた (差は 1 ms 未満)
- 負: 既定機能のコストが常にラッパーに乗る。性能の相対基準はこの機能を比較対象にも付けて測る必要がある (handbook/android/performance-verification.md)
- 負: 利用契約が 1 つ増える (テンプレートの根に高さの制約を渡す)。違反しても落ちないが、折りたたみの途中に隙間が見える
- 負: 補間中に限り content はその時点の行の高さで測り直される。「content は行の高さに引き伸ばされない」(ios/ADR-0007 の配置規則) は静定時の契約として不変

## Revisit When

- 前提 (Context) が崩れたとき
- Compose の `animateContentSize` が補間中の子の測り直しとクリップの無効化を提供したとき (自前 modifier を標準へ置き換えられる)

出典: kasane/changes/archive/2026-09-05-android-wrapper-foundation/deviation.md (行の高さ変化のアニメーション 6 件目・比較対象の条件 7 件目とその補足、2026-09-05) / kasane/changes/archive/2026-09-05-android-wrapper-foundation/evidence/row-height-animation.md / kasane/changes/archive/2026-09-05-android-wrapper-foundation/evidence/performance-measurement.md (経緯: アニメーション導入直後の再計測) / ios/ADR-0007 / cross/ADR-0004
