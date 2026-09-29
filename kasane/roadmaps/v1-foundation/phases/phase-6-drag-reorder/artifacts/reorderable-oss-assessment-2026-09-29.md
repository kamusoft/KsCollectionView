# `sh.calvin.reorderable` の依存・取り込みの見積もり (調査 2026-09-29)

ksn-scout による読み取り専用の調査の要約 (v3.1.0、HEAD 66de575、2026-04-20 時点のソースを読んだもの)。論点 6 (Android の実装方式) の材料。「確認済み」はソース・Maven の記述で確かめたこと、「推測」はビルド・動作を試していないもの。

## 規模と構成 (確認済み)

本体は commonMain だけの KMP ライブラリで、Kotlin は 9 ファイル・計 2,544 行。

| ファイル | 行数 | 役割 |
|---|---:|---|
| ReorderableLazyCollection.kt | 839 | `ReorderableLazyCollectionState`: ドラッグの状態・移動先の判定・onMove の呼び出し・自動スクロールの連携 |
| ReorderableList.kt | 472 | Lazy でない Column / Row 用 (不要) |
| ReorderableLazyList.kt | 329 | LazyColumn / LazyRow 用 (不要) |
| ReorderableLazyGrid.kt | 232 | `ReorderableLazyGridState` (LazyGridState を写す薄い層)、`ReorderableItem` (zIndex と graphicsLayer で持ち上げ) |
| ReorderableLazyStaggeredGrid.kt | 232 | Staggered 用 (不要) |
| Scroller.kt | 219 | 端での自動スクロール (端からの距離で 1〜10 倍、animateScrollBy の繰り返し) |
| draggable.kt | 96 | `draggableHandle` / `longPressDraggableHandle` |
| util.kt | 87 | 補助 |
| DragGestureDetector.kt | 38 | ジェスチャ |

LazyVerticalGrid 向けに要る部分 (Collection + Grid + Scroller + util + draggable + DragGestureDetector) は 1,511 行 (ライセンス表示とコメント込み)。

## 依存と API (確認済み)

| 項目 | 内容 |
|---|---|
| 実験的 API・内部 API | `@OptIn`・`@ExperimentalFoundationApi` は 0 件。使うのは LazyGridState の layoutInfo・visibleItemsInfo・animateScrollBy・requestScrollToItem (foundation 1.7 からの公開 API) と `Modifier.animateItem()` だけ。Compose 1.11 で壊れそうな箇所はコードからは見当たらない (ビルドは未確認) |
| `Modifier.composed` | 2 か所で使う。Modifier.Node への移行を求める issue #116 がある |
| 再配置の時機への依存 | 移動の直後は位置の予測値で表示をつなぎ、次の layoutInfo の更新を snapshotFlow で待つ (ReorderableLazyCollection.kt:307-310、645-655)。LazyGrid の再配置の時機が変わると影響を受けやすい (推測) |
| Android の成果物の依存 | `org.jetbrains.compose.runtime` / `animation` / `foundation` 1.7.0 と kotlin-stdlib 1.9.0。minSdk 21、compileSdk 34 |
| 利用者に加わる依存 | JetBrains の foundation 1.7.0 は Android で `androidx.compose.foundation:foundation:1.7.1` に依存し、BOM 1.11 系なら上の版に解決される。副作用として org.jetbrains.compose.* の成果物 (ui-text・collection-internal 等) が利用者の依存に加わる |

## 動きの模型と本ライブラリの要件との当たり

| 要件 | 依存 (A) で | 取り込み (C) で |
|---|---|---|
| 仮の並びを自分で持ち、指を離したときに 1 回知らせる (core/ADR-0026) | onMove で自分の仮の配列を書き換え、onDragStopped で知らせれば改変なしで満たせる見込み | 同左 |
| 見出しをまたぐ (core/ADR-0029) | 見出しを `ReorderableItem(enabled = false)` で包み、index を読み替える (onMove の index は Lazy 全体の位置。issue #92 の作者回答)。包まない項目が混ざると挙動が乱れる報告あり (#87) | 同左。読み替えを本体に組み込める |
| 置けない場所で並びを変えない (core/ADR-0030) | 満たしにくい。onMove で並びを変えないと、最大 1,000ms ロックを持ったまま待ち、その間ドラッグ中の項目が指からずれて固まる (ReorderableLazyCollection.kt:619-658、:484。推測)。事前判定の要望 #97・#91 は未解決。回避策はドラッグ中に置けない項目を enabled = false に切り替えること | 移動先の判定 (findTargetItem、:593-611) に「置けるか」を 1 つ足せば、置けない場所を最初から候補にせず、待ちもずれも起きない見込み (小さな改変) |
| 自動スクロール | 付いている (SWAP / INSERT、既定 SWAP) | 同左 |

既知の弱点 (確認済みの issue):

| issue | 内容 | 本ライブラリへの当たり |
|---|---|---|
| #103 | ドラッグ中の項目がスクロールで composition から外れるとつかみが切れて元に戻る (作者も昔からの問題と認める) | 自動スクロールで長く運ぶと起きうる |
| #93 | span の異なる Grid でつかみが切れる | グループの見出しは全幅の項目なので、グリッドでの見出しまたぎに当たりうる (推測) |
| #107 | ドラッグ中に並びを差し替えると検出が壊れる | ドラッグ中は配列を保留する (core/ADR-0033) ので避けられる |
| #117 | 素早く離すと一部の項目の移動アニメが出ない | — |

stickyHeader を名指しした issue は無く、固定表示中の見出しとドラッグ中の項目 (zIndex 1) の重なり順は未確認。

## 保守 (確認済み)

- コミット 185 件のうち 176 件が作者 (Calvin Liang)。ほかの貢献者 8 人は 1〜2 件ずつ
- 年ごとのコミット: 2023 年 40 / 2024 年 120 / 2025 年 23 / 2026 年 2 (4/20 の macOS 対応 PR と版上げだけ)
- リリース: v3.0.0 (2025-08)、v3.1.0 (2026-04)。未解決の issue 19 件、開いている PR 9 件。作者の返答は続くが実装は止まり気味

## 取り込むときの手当て (Apache-2.0)

- 配布元は LICENSE だけで NOTICE ファイルは無い。各ソースの冒頭に「Copyright 2023 Calvin Liang」と Apache の表示がある
- 必要なこと: ライセンス本文の同梱、各ファイル冒頭の著作権表示を残す、改変したファイルに変更した旨を明記する (§4(b))。NOTICE の引き継ぎ義務は無い。パッケージ名は変えてよい
- KsCollectionView のリポジトリルートには現在 NOTICE も LICENSE も無い
- 取り込む元のコメントは英語で、プロジェクトのソースコメント規約 (日本語、handbook/cross/comment-policy.md) との扱いを別に決める必要がある (推測)

## 確認できなかったこと

- Compose 1.11 でのビルドと動作、並びを変えなかったときの実際の見た目 (ずれて固まるか)
- stickyHeader と組み合わせたときの描画順
