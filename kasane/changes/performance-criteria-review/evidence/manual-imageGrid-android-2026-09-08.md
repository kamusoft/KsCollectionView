# 画像グリッド (Android) の手動フリック計測 — 2026-09-08

探索中 (論点 6) の追加計測。文字だけの「大量件数」(`manual-largeData-android-2026-09-08.md`) との対照。iOS の対は `manual-imageGrid-ios-2026-09-08.md`。

## 環境

| 項目 | 値 |
|---|---|
| 機種 | Pixel 4a (基準機) |
| 構成 | benchmark ビルド種別。削除してから入れ直し、起動時に画像キャッシュを空にする指定 (`ks_reset_image_cache=true`)。cold |
| fixture | Sample「画像グリッド」(10,000 件・3 列・正方形セル、リモート画像)。`ks_start_route=demo/ImageGrid` で直接開く |
| 駆動 | オーナーの手動フリック (自動化なし)。記録 60 秒 (gfxinfo の集計窓は reset から取得まで約 69 秒) |
| 記録 | `dumpsys gfxinfo <package> reset` → 合図 → 操作 → `dumpsys gfxinfo <package> framestats`。同時に `perfetto -t 60s sched freq gfx view` (退避のみ) |
| 熱状態 | thermalservice に override なし (熱制限の有無そのものは未確認) |

## オーナーの体感 (合否の主語。数値を見る前に聞き取り)

- スクロールはスムーズ。初回 / 再訪 / 連続 / ムラのいずれも問題なし
- ただし画像のレスポンスは iOS と比べて数テンポ遅れる。スクロールを止めて少し待つと画像が揃う感じで、そこは体感があまりよくない (滑らかさではなく表示待ちの軸)

## 数値 (証跡。合否ではない。gfxinfo のフレーム時間 = 描画 1 フレームの所要時間の分布)

| 指標 | 値 |
|---|---|
| 描画フレーム数 (約 69 秒) | 2,996 |
| janky frames | 64 (2.14%)。legacy 95 (3.17%) |
| フレーム時間 P50 / P90 / P95 / P99 | 14 / 20 / 21 / 34 ms |
| 期限超過 (Frame deadline missed) | 64 |
| Missed Vsync / Slow UI thread / Slow issue draw | 15 / 37 / 34 |
| ヒストグラム | 12 ms (526) と **20 ms (735)** の 2 つの山。26 ms 以上が約 90 件、最長 200 ms が 2 件 |

## 判定

- 文字だけの「大量件数」(P99 17 ms、janky 0.05%) より明らかに重い。20 ms の山は 60 Hz の期限 (16.7 ms) を越えており、画像セルが新しく可視になるフレームが定常的に 1 フレーム落ちしている形
- image-loading の Macrobenchmark で見えた「画像 1 枚ごとの subcomposition (`BoxWithConstraints`) の費用」および到達点の方式 (`prefetch-display-size` の動機) と整合する。Android 側の再計測と対策の対象は画像グリッドで確定
- **体感との突き合わせ**: スクロールの滑らかさは体感で合格 (cross/ADR-0006 のゲート)。数値 (20 ms の山、janky 2%) は文字グリッドより悪いが、オーナーは引っかかりとして感じていない。「数値の一致と主観の一致は別に書く」の実例
- **画像の表示待ち** (止めてから画像が揃うまでのテンポ) は体感で不良。これは滑らかさとは別の軸で、本 change の対象外。`prefetch-display-size` の動機 (到達点 memory が効かず、表示時に取得・デコードが走る) と一致するので、同 change の exploration に観測として引き継ぐ

## 限界

- 手動操作なので操作量は記録間で揃わない (cross/ADR-0006)。記録は 1 回
- リモート画像の到着タイミングとネットワーク状態は記録していない
- gfxinfo のフレーム時間は Macrobenchmark の `frameOverrunMs` (期限からの超過) とは別の指標で、そのまま比較しない
