# 大量件数 (Android) の手動フリック計測 — 2026-09-08

探索中 (論点 6) に、cross/ADR-0006 (proposed) の手順を Android に初めて適用した計測。iOS の対 (`manual-largeData-ios-2026-09-08.md`)。

## 環境

| 項目 | 値 |
|---|---|
| 機種 | Pixel 4a (基準機) |
| OS / API level | **未記録** (この計測では端末の OS 版を記録していない)。比較不能の条件に加える |
| 構成 | benchmark ビルド種別 (release と同じ最適化 + profileable)。削除してから入れ直し |
| fixture | Sample「大量件数」(10,000 件・2 列・固定高と 7 件ごとの長文の混在)。Intent の追加情報 `ks_start_route=demo/LargeData` で直接開く |
| 駆動 | オーナーの手動フリック (自動化なし) |
| 記録 | `dumpsys gfxinfo <package> reset` → 操作 → `dumpsys gfxinfo <package> framestats`。同時に `perfetto -t 60s sched freq gfx view` で trace を取得 (退避のみ、解析は不要だった)。記録窓は reset から取得までの実長で約 66 秒 (60 Hz × 60 秒 = 3,600 を上回る 3,941 フレームから逆算。時刻差の直接記録は無い) |
| 熱状態 | thermalservice に override なし (熱制限の有無そのものは未確認) |

1 回目の記録窓は合図が届く前に終わり、フレームが 75 しか数えられなかったため破棄し、2 回目を本記録とした。

## 操作条件

| 項目 | 値 |
|---|---|
| 操作列 | **固定の操作列の制定前**の記録。初回の下向きフリック → 再訪 → 連続フリックを自由な順で反復した (段階ごとの所要は未記録) |
| 開始位置 / 到達範囲 | 先頭から開始。到達した件数は未記録 |
| 文字サイズ / キャッシュ状態 | 端末の既定 (値は未記録) / 削除してから入れ直した直後 |

操作列が固定される前の記録であるため、固定の操作列で採る以後の記録とは**比較不能**。

## オーナーの体感 (合否の主語。数値を見る前に聞き取り)

- iPhone と違ってとてもスムーズで引っかかりなし。ムラもない (初回と再訪の差も感じない)
- 別問題として、スクロールバーが表示されないことに気づいた (性能とは無関係。別途起票)

## 数値 (証跡。合否ではない。取得源は `dumpsys gfxinfo` = HWUI の描画フレーム)

| 指標 (取得源・単位) | 値 |
|---|---|
| 描画フレーム数 (gfxinfo、約 66 秒の窓) | 3,941 (60 Hz でほぼ毎 vsync) |
| janky frames (gfxinfo) | 2 (0.05%) |
| フレーム時間 = 描画 1 フレームの所要時間 P50 / P90 / P95 / P99 (gfxinfo、ms) | 10 / 13 / 15 / 17 |
| 期限超過 (Frame deadline missed) | 2 |
| ヒストグラムの山 | 7〜12 ms に集中、最大 30 ms が 1 件 |
| Slow UI thread / Slow issue draw | 1 / 1 |

## 判定

- **体感の合否: 合格**。数値 (janky 0.05%、P99 17 ms) とも一致する
- **前回との比較可否**: 操作列が固定前で、gfxinfo のフレーム時間は Macrobenchmark の指標と取得源が違うため、過去の自動計測とは比較不能
- 文字だけの「大量件数」は Android の土台としては滑らか。iOS で主因だった estimated 高さの solver に相当する費用は Android (LazyVerticalGrid) には無い
- image-loading で見えた Android 側の重さ (画像 1 枚ごとの subcomposition、到達点 memory の同期縮小) は画像グリッドの fixture でしか出ない。本 change の Android 側の再計測は画像グリッドを対象にする

## 限界

- 端末の OS / API level を記録していないため、OS 版が変わった後の記録とは比較不能
- 手動操作なので操作量は記録間で揃わない。数値は合否ではなく説明と傾向の材料 (cross/ADR-0006)
- gfxinfo の集計は HWUI の描画フレームで、Compose の composition 費用は「フレーム時間」に含まれる形でしか見えない
