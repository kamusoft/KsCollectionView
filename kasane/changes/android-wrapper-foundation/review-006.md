# レビュー結果: android-wrapper-foundation (006 回目)

**日付**: 2026-09-05
**判定**: CHANGES_REQUESTED

## サマリー

オーナー実機指摘 2 件のうち、**スクロールの「行き過ぎて戻る」は完全に解消している** — 参考機・基準機の両方で、下方向・上方向・末尾指定のすべてについて、描画されたフレームを自前に抽出して逆行 0 を確認し、修正前の実装へ戻した変異ビルドでは同じ手順で 835 px の行き過ぎと 10 フレームの逆行が再現した。行の高さ変化も、**展開**については両経路 × list / grid でアニメーションが成立している。

一方、**折りたたみの途中フレームでは区切り線と行の中身が離れ、最大 254 px の背景色の帯が約 240 ms 出る**。証跡 `evidence/row-height-animation.md` は折りたたみも「中間フレーム 23 / 22」で合格としているが、その観測点 (行高と次行の上端) ではこの現象は写らない。オーナーが目標に挙げた RecyclerView の既定アニメータでは行の背景が枠と一緒に縮むため、この帯は出ない。加えて、design Decision 4 が定めたスクロールの 2 段階補正を 1 回の命令へ作り替えた乖離が `deviation.md` に記録されていない (design の Risks 節が「許容できなければ deviation に記録」と事前に指示している当の項目である)。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| handbook/cross/comment-policy.md | always |
| handbook/cross/test-execution.md | テスト実行・結果報告 |
| handbook/cross/runtime-behavior-verification.md | 実行時挙動 (スクロール・アニメーション) の不具合修正の完了判定 — 本サイクルの中心 |
| handbook/cross/sample-parity.md | `samples/` を触る作業 (計測用画面の対等化) |
| handbook/ios/performance-verification.md | 大量件数を扱う変更の完了判定 (Android 計測が揃える fixture・手順の正) |
| decisions core/ADR-0007 (命令の順序保証) / ios/ADR-0007 (content の配置規則) | 実装が根拠に挙げている accepted ADR |
| lessons/inbox/observe-motion-not-only-end-state-for-scroll-and-resize.md | 本サイクルの評価軸 (動きの過程を自分で観測する) |
| lessons/inbox/capture-transient-layout-glitch-with-offset-logs.md | 同上 (静止画の非発現を根拠にしない) |
| kotlin-impl-skill / jetpack-compose-impl-skill | Kotlin 言語層・Compose の副作用と修飾子の順序 |

`android/ADR-0001` / `android/ADR-0002` は `proposed` のため、これを根拠にした指摘は出していない。

## 実行した検証

### ビルドとテスト (JDK 17)

| 対象 | 結果 |
|---|---|
| `android/` `:kscollectionview:testDebugUnitTest --rerun-tasks` | **60 tests / 0 failures** (Core 14 + Interaction 20 + Layout 26。XML のクラス別内訳で確認) |
| `samples/android/` `:app:testDebugUnitTest --rerun-tasks` | **12 tests / 0 failures** (SampleDemoScreenTest 8 + SampleScreenParityTest 4) |
| `scripts/local-path-lint.py` / `identity-lint.py` / `comment-policy-lint.py` | 0 件 (comment-policy は検査対象 141 ファイル) |
| `scripts/doc-structure-lint.py` | 2 件。いずれも roadmaps の既存分で、本 change が触った文書に指摘なし |

### 動きの過程の自前観測 (観測手段)

証跡は本体へ一時的に足した毎フレームのログで判定している。レビューでは**実装に触れない別経路**で採った。画面録画 (`screenrecord`、60 Hz) の各フレームを macOS の Vision で文字認識し、可視行の「Item N」と画面上の y からスクロール量を復元する方法と、右端の帯の輝度から区切り線の y を拾う方法の 2 つである。リストは行が等間隔なので相互相関では位置が定まらず、行番号そのものを読む必要があった。

観測されるのは**実際に描画されたフレーム**であり、利用者が見るものと同じである。debug ビルドのため描画フレーム数は証跡のログの本数より少ない。

### スクロール命令 (修正後)

参考機 Pixel 6a (60 Hz、アニメーション倍率 1.0)。値は描画された相異なるスクロール位置 (px)。

| 手順 | 位置の系列 | 逆行フレーム | 最終位置を超えた量 |
|---|---|---:|---:|
| 先頭 → 「Item 50」(Center・下方向) | 0 → 845 → 5453 → 8228 → 8230 | **0** | **0 px** |
| 末尾 → 「Item 50」(Center・上方向) | 0 → -844 → -4752 → -8413 | **0** | **0 px** |
| 先頭 → 「末尾」(End) | 0 → 845 → 3713 → 6426 → 11201 → 16196 → 16638 → 16642 | **0** | **0 px** |

基準機 Pixel 4a でも同じ手順で 0 → 795 → 5670 → 8656、逆行 **0**。

**到達位置の妥当性**: Pixel 6a の行送り 185 px・表示範囲の内側 1844 px から、Item 50 を中央に置いたときの理論値は 8235 px。下方向の到達は 8230 px、上方向は末尾 16642 px からの -8413 = 8229 px で、**両方向が同じ位置に収束**している (差は文字認識の枠精度の範囲)。Pixel 4a の理論値 8663 px に対し実測 8656 px。残差の許容 (4dp) の内側に収まっており、「中央に来る」は成立している。

### 変異検査 (実装を複製して差し替え、測定後に完全復元。復元は SHA-1 で照合済み)

**変異 A — `performScroll` を修正前の 2 段階 (先頭合わせ → 残差を `animateScrollBy`) に戻す**

| 手順 | 位置の系列 (抜粋) | 逆行フレーム | 行き過ぎ |
|---|---|---:|---:|
| 下方向 Center | 0 → 845 → 5453 → 9006 → **9067** → 8959 → 8762 → 8584 → 8372 → 8282 → … → 8232 | **10** | **835 px** |
| 上方向 Center | 0 → -844 → -4751 → -7571 → … → -8413 | 0 | 0 px |

オーナーが見た「行き過ぎてから戻る」が、レビュー側の観測手段でも再現した。上方向で症状が出ないことも、オーナーの「先頭・末尾は問題なし」と整合する。この変異で `animatedCenterScrollNeverReversesDirection` / `animatedEndScrollNeverReversesDirection` / `animatedCenterScrollNeverReversesWithMixedItemHeights` の **3 件だけ**が FAILED になり、他の 57 件は通る。

**変異 B — 項目ラッパーの `animateContentSize()` を除去する**

`rowHeightChangeFromParentStateAnimates` / `rowHeightChangeFromTemplateStateAnimates` / `rowHeightChangeAnimatesInGrid` の **3 件だけ**が FAILED。

両変異とも「実装を外すと落ちる」が成立しており、6 件のテストは空振りしていない。

### 行の高さ変化 (修正後、Pixel 6a)

行 1 の下端の区切り線の y を毎フレーム拾った。以降の区切り線もすべて同じ量だけ同時に動いており、押し出される行の追従は成立している。

| 経路 / レイアウト / 向き | 中間フレーム数 | 所要 |
|---|---:|---|
| 親 state / list / 展開 | 21 (1030 → 1287 px) | 約 270 ms |
| テンプレート内 state / list / 展開 | 21 | 約 270 ms |
| 親 state / list / 折りたたみ | 20 | 約 240 ms (ただし下記 Major 1) |
| テンプレート内 state / list / 折りたたみ | 20 | 同上 |
| grid (2 列) / 展開・折りたたみ | 中間フレームあり | 同上 |

### `animateContentSize` の既定化による副作用 (レビュー依頼 (d))

| 観点 | 結果 |
|---|---|
| 「大量件数」の初期表示 | 画面遷移が終わった最初のフレームから行が正しい高さで載る。0 → 自然高のアニメーションは出ない |
| 「大量件数」のフリック (上下 3 回) | 文字認識できた 41 フレーム分の隣接行の間隔は 127〜136 px (短行) と 292〜302 px (長文行) の 2 群だけで、中間の高さは **1 件も出ない**。再利用時に前の項目の高さから animate する副作用は無い |
| layout 切替 (1 行展開したまま list → grid) | 切替後の最初のフレームで確定。中間フレーム無し |
| 空配列・ヘッダー / フッター | `headerAndFooterAreShownForEmptyItems` を含む既存 26 件が通る。ヘッダー / フッター側の `animateContentSize` は下記 Minor 2 |
| テンプレートキー変更 (Message → Ad) | Android Sample の「テンプレート切り替え」画面はキーで高さが変わらないため、実機では観測できない。`templateKeyChangeRedrawsWithNewTemplate` が描画差し替えを担保 |

### 再計測の再現 (レビュー依頼 (f))

基準機 Pixel 4a で `:benchmark:connectedBenchmarkAndroidTest` をライブラリ側・比較対象側それぞれ独立に実行した (2 列グリッド、3 試行)。

| 指標 | 自前計測 ライブラリ | 自前計測 比較対象 | 自前の相対 | 証跡の相対 |
|---|---:|---:|---:|---:|
| `frameDurationCpuMs` P90 | 7.26 ms | 7.32 ms | **-0.8%** | +2.4% |
| `frameDurationCpuMs` P99 | 9.12 ms | 9.23 ms | **-1.2%** | +6.8% |
| `frameOverrunMs` P90 | -6.80 ms | -6.76 ms | — | — |
| `frameOverrunMs` P99 | **-5.10 ms** | -5.24 ms | — | -5.74 / -6.20 ms |

**結論は再現した** — 相対は 10% 以内、絶対上限 (`frameOverrunMs` P99 ≤ 0.0 ms) を満たす。個々の百分率は証跡と一致しないが、証跡自身が「差が 1 ms に満たない領域では試行別 P90 / P99 が ±14% 揺れる」と述べている範囲の内側であり、矛盾ではない。`animateContentSize` を比較対象にも付けて対等化した効果 (`deviation.md` 7 件目) は、自前計測でも同じ向きに出ている。

## 指摘事項

### [🟠 Major] 行を折りたたむ途中で、区切り線と行の枠が中身から離れ、背景色の帯が約 240 ms 出る

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:268` / `evidence/row-height-animation.md`

**問題点**: `animateContentSize()` は**子を新しい自然高で測ったうえで、外へ報告するサイズだけを animate し、子は上端に置いてクリップする**。折りたたみでは子 (テンプレートの content) が先に縮み終わっているため、`animateContentSize` より外側にある `ksListSeparator` と `combinedClickable` が使う「動いている途中の高さ」との間に、**行の中身が何も描かない帯**ができる。そこにはコレクションの背景がそのまま見える。

Pixel 6a の実測 (親 state / list / 1 行目をタップして折りたたみ、区切り線の y を毎フレーム観測):

| 経過 | 行 1 の中身の下端 | 行 1 の区切り線 | 帯の高さ |
|---|---:|---:|---:|
| タップ直後 | 1032 px (固定) | 1286 px | 254 px |
| +70 ms | 1032 px | 1188 px | 156 px |
| +150 ms | 1032 px | 1082 px | 50 px |
| +240 ms | 1032 px | 1041 px | 収束 |

帯の画素は `(244, 244, 247)` (Sample のページ背景) で、行の白 `(255, 255, 255)` と明確に区別できる。**展開時は帯が出ない** (同じ区間の画素はすべて `(255, 255, 255)`) — 子が先に伸びてクリップされるためで、症状は折りたたみに固有である。grid (2 列) でも同じ形で、行の全幅に空白帯が出る。テンプレート内 state 経路でも同じ。

`evidence/row-height-animation.md` は折りたたみを「中間フレーム 23 / 22」で合格としているが、その観測点は行高と次行の上端であり、**行の内側で中身と枠が離れることは原理的に写らない**。これは lessons/inbox の 2 件 (動きの過程を観測する / 一過性の見た目の不具合は数値の A/B で判定する) が指す型そのもので、観測点を 1 つ増やせば拾えた。

オーナーが目標として挙げた RecyclerView の既定アニメータ (`DefaultItemAnimator`) は、行のビュー自体の bounds を animate するため行の背景が枠と一緒に縮み、この帯は出ない。deviation 6 件目の目的 (「RecyclerView の既定アニメータ相当」「iOS に揃える」) を、折りたたみ方向については満たしていない。

**推奨修正**: 次のいずれかを選び、選んだ結果を `deviation.md` と `evidence/row-height-animation.md` に残す。**どれを採るかは見た目の設計判断のためオーナーの確定が要る**。

- (a) 動いている途中の高さを content 側にも渡し、縮む間は content をその高さでクリップする (中身が枠と一緒に縮むため RecyclerView と同じ見え方になる)。ios/ADR-0007 の「content を行高に引き伸ばさない」は伸びる方向の規則なので、縮む間のクリップとは両立する
- (b) 折りたたみ方向だけアニメーションしない (展開のみ animate する)。帯は出なくなるが、オーナー指示の「押される他の項目の移動」が片方向だけになる
- (c) 現状を許容する。その場合は「折りたたみ中に区切り線が中身から離れる」ことを `deviation.md` に**症状として明記**し、`evidence/row-height-animation.md` の折りたたみ欄に観測点と実測 (帯の最大高・色) を足す。証跡が現在「合格」としか読めない状態のまま蒸留へ進めない

### [🟠 Major] design Decision 4 が定めたスクロール補正の方式を作り替えた乖離が `deviation.md` に無い

**該当箇所**: `design.md` Decision 4 および Risks 節 / `deviation.md` / `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsScrollCommandReceiver.kt:156-181`

**問題点**: design Decision 4 は採用案として「`.center` / `.end` は対象を可視化してから `layoutInfo` の項目サイズで `scrollBy` 補正する **2 段階**」と明記している。Risks 節はさらに「`.center` / `.end` の 2 段階補正は…アニメーション中に位置がわずかに跳ぶ可能性 → Sample「スクロール制御」で目視確認し、**許容できなければ deviation に記録**」と、この乖離が起きた場合の扱いを事前に指示している。

実装はこの 2 段階をやめ、項目高の推定から求めたオフセットを 1 回の `animateScrollToItem(index, scrollOffset)` に渡す方式へ作り替えている (到着後の補正は進行方向と同じ向き・許容差超過のときだけ)。**方式そのものの差し替えであり、design が想定した「わずかに跳ぶ」の許容判断ではない。** それにもかかわらず `deviation.md` の 7 件のいずれもこの変更に触れておらず、**オーナーが報告した 2 件の不具合のうちスクロール側だけが、change の記録上どこにも残っていない** (行の高さ側は 6 件目にある)。

design.md は凍結された足場で、蒸留のときに ADR / concepts の素材として読まれる。今の状態では「2 段階補正を採った」という現存しない設計が残り、`evidence/scroll-center-motion.md` を併読しない限り気づけない。

あわせて、design の Open Questions にある「`.center` / `.end` の補正の許容差 (アニメーション後の残差の許容 px は実装時に evidence で決める)」も未回収である。`KsScrollAlignmentTolerance = 4.dp` (`KsScrollCommandReceiver.kt:70`) の根拠は証跡のどこにも無い。

**推奨修正**: `deviation.md` に 8 件目として、(1) オーナー実機指摘の症状、(2) design Decision 4 の 2 段階を 1 回の命令へ作り替えたこと、(3) 理由 (2 段階では中央指定の下方向で必ず行き過ぎと戻りが出る。`evidence/scroll-center-motion.md` の A/B)、(4) 残差の許容を 4dp としたことと、逆向きの残差を詰めない判断を書く。design.md 側は凍結のため触らない。

### [🟡 Minor] `isForwardScroll` の「対象が先頭可視項目と同じとき」の分岐が、意味の違う 2 つの値を比較している

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsScrollCommandReceiver.kt:223-228`

**問題点**: 比較している `scrollOffset` は `initialScrollOffset` の戻り値で、定義上つねに 0 以下である (`-leading.coerceAtLeast(0)`)。一方 `firstVisibleItemScrollOffset` は Compose の契約でつねに 0 以上である。したがって `scrollOffset > firstVisibleItemScrollOffset` は**どんな入力でも false** に評価される。

現状は結果として正しく動く — この分岐に入るのは対象が先頭可視項目のときで、Center / End はいずれも後方 (先頭側) へ動かす必要があり、Start は `performScroll` が先に return するためである。しかし KDoc は「これから行うスクロールが前方かどうか」を求めると書いており、コードはそれを計算していない。`initialScrollOffset` が将来 0 より大きい値を返す形になったとき (例: 対象が表示範囲より大きい場合の扱いを変えたとき)、進行方向が黙って逆に判定され、到着後の補正が「行き過ぎて戻る」向きに掛かる。今回直した不具合が戻る経路である。

**推奨修正**: 同じ基準へそろえてから比べる。たとえば「現在の先頭可視項目の位置」と「要求する位置」をどちらもコンテンツ先頭からのスクロール量で表す (`firstVisibleItemIndex` が同じなら `-scrollOffset` と `firstVisibleItemScrollOffset` の比較にする) か、比較が退化していることを前提として明示し「対象が先頭可視項目なら後方へ動く」と直接書く。

### [🟡 Minor] ヘッダー / フッターへ足した `animateContentSize` が検証層にも証跡にも載っていない

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:227` / `:288` / `evidence/row-height-animation.md`

**問題点**: 項目と同じ修飾をヘッダーとフッターにも足しているが、これを外しても落ちるテストは無く (変異 B で落ちたのは項目側の 3 件だけ)、`evidence/row-height-animation.md` の表も項目の 5 通りだけで、ヘッダー / フッターの高さ変化は 1 行も無い。`verification-matrix.md` の「行の高さ変化のアニメーション」欄も同様である。

Sample の「ルートヘッダー/フッター」画面はヘッダーの高さが変わらないため、実機でも観測できない。つまりこの 2 行は**どの層でも検証されていない新規の既定挙動**であり、Major 1 の帯の症状もヘッダー / フッターで同じように起こりうる (ヘッダーの content が縮む形の利用)。

**推奨修正**: `rowHeightChangeFromParentStateAnimates` と同じ形でヘッダーの高さ変化を 1 件足す。テストを足さない判断なら、`verification-matrix.md` の当該欄に「ヘッダー / フッターは未検証」と明示する (同ファイルは「どの層でも押さえられていない条件は最後の『未検証の一覧』に集める」と自ら定めている)。

### [🔵 Suggestion] 混在行高での Center 指定を実機で確かめられる画面が無くなっている

**該当箇所**: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/LargeDataDemoScreen.kt` / `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/ScrollControlDemoScreen.kt`

**問題点**: 項目高の推定 (`estimateItemHeight`) が外れたときに逆向きの補正が入らないことは、今回の修正の要である。しかし「スクロール制御」画面の行はすべて等高で、混在行高を持つ「大量件数」画面は `scrollController` を持たない (review-005 の Minor 2 に沿って外した結果)。**混在行高の Center 指定は Robolectric の 1 件 (`animatedCenterScrollNeverReversesWithMixedItemHeights`) だけが根拠**で、実機の裏取りが取れない。

そのテストが変異で落ちることは確認したので実害はないが、handbook/cross/runtime-behavior-verification の「実環境での再現と解消確認」を、この条件についてだけは踏めない状態になっている。

**推奨修正**: 「スクロール制御」画面のデータに数行だけ長文を混ぜる (`DemoData.scrollItems` の生成規則を「大量件数」と同じ 7 件ごとの長文にする) と、既存の 3 ボタンのまま混在行高が実機で踏める。あるいは `verification-matrix.md` の当該欄に「混在行高は検証層のみ (実機の入口なし)」と明示する。

### [🔵 Suggestion] `evidence/scroll-center-motion.md` の「動きのフレーム数」がビルド構成に依存する値である

**該当箇所**: `evidence/scroll-center-motion.md`「結果 (A/B)」の表

**問題点**: 表は修正前 28 / 修正後 11 を「動きのフレーム数」として並べているが、これは本体へ足したログの出力回数であり、**実際に描画されたフレーム数とは一致しない**。レビュー側が同じ操作を録画して数えたところ、修正後に描画された相異なる位置は基準機で 4 点、参考機で 5 点だった (debug ビルドのため 1 フレームに 100〜300 ms かかる区間がある)。

判定に使っているのは「符号反転フレーム数」と「最大逆行量」であり、そちらは描画フレームでも同じ結論 (0 / 0) になるため、証跡の主張は揺らがない。ただし「11 フレームで着地する」と読めるため、後から性能の目安として引かれると誤る。

**推奨修正**: 表の見出しを「ログに現れた位置の更新回数」に変え、「debug ビルドの計測であり描画フレーム数ではない」と 1 行添える。

## アクションプラン

1. **(必須)** 折りたたみ中の帯について、修正 / 片方向のみ / 許容 のどれを採るかをオーナーに確定してもらい、結果をコードまたは `deviation.md` + `evidence/row-height-animation.md` に反映する (Major 1)
2. **(必須)** スクロール補正の方式変更を `deviation.md` に 8 件目として記録し、残差の許容 4dp の根拠を証跡に残す (Major 2)
3. (推奨) `isForwardScroll` の比較を同じ基準へそろえる (Minor 1)
4. (推奨) ヘッダーの高さ変化のテストを 1 件足すか、`verification-matrix.md` に未検証と明示する (Minor 2)
5. (任意) 混在行高の実機入口、`scroll-center-motion.md` のフレーム数の但し書き (Suggestion 2 件)

1 と 2 は蒸留前に必要である。1 は挙動そのもの、2 は design.md と実装の食い違いが ADR の素材として読まれるためで、どちらもアーカイブ後は追跡できなくなる。

## 確認した観点 (指摘に至らなかったもの)

- **足場アーティファクトの不改変**: `specs/` 4 ファイル・`design.md`・`proposal.md` は本サイクルで更新されていない。更新は `deviation.md` / `evidence/` / `tasks.md` / `ui/brief.md` に限られている
- **`deviation.md` 6・7 件目**: 行の高さ変化をライブラリ既定にする判断と、比較対象へ同じ既定機能を付けて対等化する判断は、いずれもオーナー判断として理由・影響範囲つきで記録されており、合意済み差分として扱った。7 件目に対応する実装 (`samples/android/app/src/measurement/.../MeasurementDestinations.kt` の 2 か所) は、ライブラリ側と同じ位置 (項目の content を包む箱) に同じ修飾を置いており、条件の対等化として妥当
- **依存の追加**: `androidx.compose.animation:animation` はカタログに版なしで宣言され BOM から解決される。`animateContentSize` は公開 API の型に現れないため `implementation` で正しい
- **修飾子の順序**: `animateContentSize()` が `ksListSeparator` / `combinedClickable` より内側にあり、区切り線とタップ領域が動いている途中の高さを使うという KDoc の主張はコード上成立している (Major 1 は「その高さに content が追いつかない」という別の問題)
- **命令キューへの影響**: `performScroll` の作り替えは `LaunchedEffect` 1 本・FIFO・最新配列での解決・先行命令の中断 (`running?.cancelAndJoin()` 相当の構造) に触れていない。順序保証 (core/ADR-0007) 系の 8 テストは変異 A でも通る
- **`tolerancePx` の受け渡し**: `LocalDensity` 経由で dp → px 変換され、Composable の外 (suspend 関数) には Dp を持ち込んでいない
- **テストの手抜き**: 6 件の新規テストはいずれも `mainClock.autoAdvance = false` でフレームを 1 つずつ進め、失敗メッセージに実測値の系列を載せている。固定時間の待機・言い訳コメントによる実質スキップは無い
- **成果物のパスと識別子**: 新規 2 証跡・本レビューともローカル絶対パス・端末の個体識別子を含まない (lint 2 種 0 件、本文も目視)
- **前回 (review-005) の Minor 3 件**: `ui/brief.md` の「deviation.md へ記録済み」の書き方、`KsLargeDataGrid` の未使用 `scrollController`、計測モジュールのマニフェストのコメント — いずれも解消を確認した
- **iOS との比較**: iOS Sample の同画面で折りたたみの途中フレームを採ろうとしたが、Simulator の録画が中間フレームを 1 枚も出さず、単発のスクリーンショットでも捕まえられなかったため、**クロスプラットフォームの比較は行えていない**。Major 1 は Android 側の観測と RecyclerView の既定挙動を根拠にしている
