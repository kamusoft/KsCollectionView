# 大量件数 (Android) の手動フリック計測 — 2026-09-08

探索中 (論点 6) に、cross/ADR-0006 (proposed) の手順を Android に初めて適用した計測。iOS の対 (`manual-largeData-ios-2026-09-08.md`)。

## 環境

| 項目 | 値 |
|---|---|
| 機種 | Pixel 4a (基準機) |
| 構成 | benchmark ビルド種別 (release と同じ最適化 + profileable)。削除してから入れ直し |
| fixture | Sample「大量件数」(10,000 件・2 列・固定高と 7 件ごとの長文の混在)。Intent の追加情報 `ks_start_route=demo/LargeData` で直接開く |
| 駆動 | オーナーの手動フリック (自動化なし)。記録 60 秒 |
| 記録 | `dumpsys gfxinfo <package> reset` → 操作 → `dumpsys gfxinfo <package> framestats`。同時に `perfetto -t 60s sched freq gfx view` で trace を取得 (退避のみ、解析は不要だった) |
| 熱状態 | 制限なし (thermalservice に override なし) |

1 回目の記録窓は合図が届く前に終わり、フレームが 75 しか数えられなかったため破棄し、2 回目を本記録とした。

## オーナーの体感 (合否の主語)

- iPhone と違ってとてもスムーズで引っかかりなし。ムラもない (初回と再訪の差も感じない)
- 別問題として、スクロールバーが表示されないことに気づいた (性能とは無関係。別途起票)

## 数値 (証跡。合否ではない)

| 指標 | 値 |
|---|---|
| 描画フレーム数 (60 秒) | 3,941 (60 Hz でほぼ毎 vsync) |
| janky frames | 2 (0.05%) |
| フレーム時間 P50 / P90 / P95 / P99 | 10 / 13 / 15 / 17 ms |
| 期限超過 (Frame deadline missed) | 2 |
| ヒストグラムの山 | 7〜12 ms に集中、最大 30 ms が 1 件 |
| Slow UI thread / Slow issue draw | 1 / 1 |

## 判定

- 文字だけの「大量件数」は Android の土台としては滑らか。iOS で主因だった estimated 高さの solver に相当する費用は Android (LazyVerticalGrid) には無い
- image-loading で見えた Android 側の重さ (画像 1 枚ごとの subcomposition、到達点 memory の同期縮小) は画像グリッドの fixture でしか出ない。本 change の Android 側の再計測は画像グリッドを対象にする

## 限界

- 手動操作なので操作量は記録間で揃わない。数値は合否ではなく説明と傾向の材料 (cross/ADR-0006)
- gfxinfo の集計は HWUI の描画フレームで、Compose の composition 費用は「フレーム時間」に含まれる形でしか見えない
