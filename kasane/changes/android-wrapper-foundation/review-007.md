# レビュー結果: android-wrapper-foundation (007 回目)

**日付**: 2026-09-05
**判定**: CHANGES_REQUESTED

## サマリー

review-006 の Major 2 件・Minor 2 件はいずれも解消している。**折りたたみ中の帯は消えた** — 親 state / テンプレート内 state × list / grid の 4 通りすべてで、補間を 10 倍に引き伸ばして採った実描画の連続静止画の全フレームで帯 0 px を確認した (修正前は 261 px)。展開のアニメーションも中間フレーム 10 枚で維持され、スクロールの逆行は下方向・上方向とも 0 フレームで、両方向が同じ位置 (8,238 px) へ収束する。

一方、新しい修飾 `ksAnimatedHeight` が KDoc と証跡で主張している「はみ出す分は描画時に切り取る」は**一度も働かない**。`clipsContent` の判定は成立し得ない比較になっており、補間中に行の高さを超えた content は切り取られずに行の外へ描かれる (プローブで実証)。前実装の `animateContentSize` は `clipToBounds` を内包していたため、この点は今サイクルで入った後退でもある。加えて、証跡 2 か所 (`evidence/row-height-animation.md` の「残る条件」と `evidence/verification-matrix.md` の「未検証の一覧」最終行) が、すでに採用済みの Sample 修正を「復元した」「採用は未決」と書いたままである。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| handbook/cross/comment-policy.md | always |
| handbook/cross/test-execution.md | テスト実行・結果報告 |
| handbook/cross/runtime-behavior-verification.md | 実行時挙動 (アニメーション・スクロール) の不具合修正の完了判定 — 本サイクルの中心 |
| handbook/cross/sample-parity.md | `samples/` を触る作業 (検証画面のセル構造の変更) |
| handbook/ios/performance-verification.md | 大量件数を扱う変更の完了判定 (Android 計測が揃える fixture・手順の正) |
| decisions core/ADR-0007 (命令の順序保証) / ios/ADR-0007 (content の配置規則) | 実装が根拠に挙げている accepted ADR |
| lessons/inbox/observe-motion-not-only-end-state-for-scroll-and-resize.md | 本サイクルの評価軸 (動きの過程を自分で観測する) |
| lessons/inbox/capture-transient-layout-glitch-with-offset-logs.md | 同上 (静止画の非発現を根拠にしない) |
| lessons/inbox/reviewer-reproduces-evidence-numbers-by-probe.md | 証跡の計測値を自前で再実行する義務 (性能の再計測) |
| kotlin-impl-skill / jetpack-compose-impl-skill | Kotlin 言語層・Compose の修飾子ノード (`LayoutModifierNode` / `DrawModifierNode`) と測定契約 |

`android/ADR-0001` / `android/ADR-0002` は `proposed` のため、これを根拠にした指摘は出していない。

## 前回 (review-006) 指摘の追跡

| review-006 の指摘 | 状態 | 根拠 |
|---|---|---|
| 🟠 Major 1 折りたたみ中に帯が出る | **解消** | 実機の実描画で 4 通り × 全フレーム 帯 0 px (下記「行の高さ変化」)。証跡も観測手順と A/B (261 px → 0 px) つきで書き直されている |
| 🟠 Major 2 スクロール補正の方式変更が deviation に無い | **解消** | `deviation.md` 8 件目に、症状・2 段階を 1 回の命令へ集約したこと・理由 (A/B)・残差 4dp とその根拠・逆向きの補正を入れない判断が記録されている。design.md は不改変 |
| 🟡 Minor 1 `isForwardScroll` の比較が意味の違う値どうし | **解消** | 両辺を「表示範囲の先頭からどれだけ下か」へ揃えた式に書き換え、専用テスト 2 件を追加。実装者が「レビュー案の符号は逆になる」として案を採らなかった判断は**妥当** (下記「判定した論点」) |
| 🟡 Minor 2 ヘッダー / フッターの `animateContentSize` が未検証 | **解消** | `headerHeightChangeAnimates` を追加。変異検査でヘッダー側の修飾を外すとこの 1 件だけが落ちる。フッターは `verification-matrix.md` の「未検証の一覧」へ理由つきで明示された |
| 🔵 Suggestion 1 混在行高の Center を実機で踏める画面が無い | **未対応** | `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/DemoData.kt:24-25` の `scrollItems` は等高のまま。代替案の「`verification-matrix.md` に実機の入口なしと明示」も入っていない |
| 🔵 Suggestion 2 `scroll-center-motion.md` のフレーム数の但し書き | **解消** | 表の見出しを「ログに現れた位置の更新回数」に変え、描画フレーム数ではない旨と「性能の目安として引かないこと」を追記済み |

## 実行した検証

### ビルドとテスト (JDK 17)

| 対象 | 結果 |
|---|---|
| `android/` `:kscollectionview:testDebugUnitTest --rerun-tasks` | **64 tests / 0 failures** (Core 14 + Interaction 22 + Layout 28。XML のクラス別内訳で確認) |
| `samples/android/` `:app:testDebugUnitTest --rerun-tasks` | **12 tests / 0 failures** (SampleDemoScreenTest 8 + SampleScreenParityTest 4) |
| `scripts/local-path-lint.py` / `identity-lint.py` / `comment-policy-lint.py` | 0 件 (comment-policy は検査対象 142 ファイル) |
| `scripts/doc-structure-lint.py` | 30 件 / 10 ファイル。検査範囲は concepts / handbook / roadmaps であり、本 change のアーティファクトは範囲外。指摘はいずれも本 change が触っていない既存文書 |

### 観測手段 (実装に触れない別経路)

証跡は本体へ一時的に足したログ、または引き伸ばした補間の連続静止画で判定している。レビューでは次の 2 つを自前で用意した。いずれも**実際に描画されたフレーム**を見る。

- **帯の判定**: 端末の `animator_duration_scale` を 10 にして補間を引き伸ばし、`screencap` を連続で取得 (1 枚あたり 300〜400 ms)。列 1 つ (テキストに掛からない右端) を上から読み、ページ背景色 `(242, 242, 247)` の画素数と、その連続区間の最大長を数える。行の中身は白 `(255, 255, 255)`。採取後に倍率を 1.0 へ戻した (実施済み)
- **スクロール位置の復元**: 同じく連続静止画を採り、macOS の Vision で「Item N」の文字と枠を読み、`(N-1) × 行送り + 先頭位置 - 枠上端` からコンテンツ先頭からのスクロール量を復元する。行が等間隔なので相互相関では位置が定まらず、行番号そのものを読む必要があった

参考機は Pixel 6a (60 Hz)、性能の基準機は Pixel 4a。

### 行の高さ変化 — 帯の有無 (Pixel 6a、`animator_duration_scale` = 10)

list では行間が無いため、リスト領域に現れるページ背景の画素数がそのまま帯の高さになる。grid は行間 (8dp = 21 px) が正しい表示なので、ページ背景の**連続区間の最大長**で見た (行間だけなら 21 px のまま)。

| 経路 / レイアウト / 向き | 採った実描画フレーム | 行の下端の推移 | 帯 |
|---|---:|---|---|
| 親 state / list / 展開 | 12 | 1031 → 1286 px (中間 10 枚) | 全フレーム **0 px** |
| 親 state / list / 折りたたみ | 12 | 1284 → 1030 px (中間 10 枚) | 全フレーム **0 px** |
| テンプレート内 state / list / 展開 | 8 | 1032 → 1275 px (中間 6 枚) | 全フレーム **0 px** |
| テンプレート内 state / list / 折りたたみ | 12 | 1281 → 1030 px (中間 10 枚) | 全フレーム **0 px** |
| 親 state / grid (2 列) / 展開 | 6 | 中間 4 枚 | 背景の最大連続 **21 px** = 行間のみ |
| 親 state / grid (2 列) / 折りたたみ | 10 | 中間 8 枚 | 同上 |
| テンプレート内 state / grid / 展開・折りたたみ | 8 / 12 | 中間あり | 同上 |

review-006 が測った修正前の帯 (最大 261 px、ページ背景色) は**どの経路でも 1 フレームも出ない**。折りたたみの中間フレームを切り出して目視でも確認した (行の白が区切り線の直上まで届いている)。テンプレート内 state 経路は Sample 側の 1 行 (`propagateMinConstraints = true`) で直っており、実機でも解消を確認できた。

### スクロール命令 (Pixel 6a、`animator_duration_scale` = 10)

値は復元したスクロール量 (px)。行送り 185 px。

| 手順 | 位置の系列 | 逆行フレーム | 最終位置を超えた量 |
|---|---|---:|---:|
| 先頭 → 「Item 50」(Center・下方向) | 461 → 2849 → 5120 → 6852 → 7697 → 8025 → 8164 → 8210 → 8227 → 8235 → 8238 | **0** | **0 px** |
| 末尾 → 「Item 50」(Center・上方向) | 16499 → 14067 → 11875 → 9833 → 8929 → 8486 → 8318 → 8269 → 8248 → 8241 → 8238 | **0** | **0 px** |

**両方向が 8,238 px へ収束**しており、`isForwardScroll` の書き換えによる回帰は無い。

### 自前修飾の副作用 (レビュー依頼 (d))

| 観点 | 結果 |
|---|---|
| 初回表示 | 画面を開き直してから 2.8 秒の間に 8 枚採り、いずれも行の送りは確定値。0 → 自然高の補間は出ない |
| 項目の再利用 | Sample「大量件数」でフリック 4 回 × 各 3 枚。現れた行送りは **130 / 294 px の 2 種のみ** (と両者が連続した 424 px)。補間を 10 倍にしたままでも中間の高さは 1 件も出ない |
| layout 切替 (1 行展開したまま) | grid → list、list → grid とも、切替後の最初のフレームで確定。中間フレーム **0** |
| テンプレートキー変更 | `KsCollectionViewCoreTest.templateKeyChangeRedrawsWithNewTemplate` が描画差し替えを担保 (Sample にキーで高さが変わる画面が無いため実機では観測できない) |
| 空配列・ヘッダー / フッター | `headerAndFooterAreShownForEmptyItems` を含む Layout 28 件が通る |
| 水平配置 (ios/ADR-0007) | 配置の責務が `ksAnimatedHeight` へ移ったが、`narrowContentIsCenteredAndWideContentFillsFromStart` が実座標で担保 (変異検査で単独失敗を確認) |

### 変異検査 (実装を複製して差し替え、測定後に完全復元。復元は SHA-1 で照合済み)

| 変異 | FAILED になったテスト |
|---|---|
| A: 項目の箱から `propagateMinConstraints = true` を外す | `rowHeightCollapseKeepsContentBottomAtRowBottom` の **1 件だけ** |
| B: ヘッダーの箱から `ksAnimatedHeight()` を外す | `headerHeightChangeAnimates` の **1 件だけ** |
| C: `isForwardScroll` の比較の符号を反転 | `forwardScrollIsJudgedByRequestedTopWithinSameItem` の **1 件だけ** |
| D: 項目の水平配置を `Alignment.Start` にする | `narrowContentIsCenteredAndWideContentFillsFromStart` の **1 件だけ** |

4 件とも「実装を外すと落ちる / 他は落ちない」が成立しており、対応テストは空振りしていない。

### 性能の再計測 (レビュー依頼 (f)。基準機 Pixel 4a、2 列グリッド、3 試行 × 1 実行)

| 指標 | 自前計測 ライブラリ | 自前計測 比較対象 | 自前の相対 | 証跡の相対 (2 実行) |
|---|---:|---:|---:|---|
| `frameDurationCpuMs` P90 | 6.91 ms | 7.50 ms | **-7.9%** | -9.1% / -4.2% |
| `frameDurationCpuMs` P99 | 8.28 ms | 9.00 ms | **-8.0%** | -23.2% / -5.6% |
| `frameOverrunMs` P90 | -6.8 ms | -6.7 ms | — | — |
| `frameOverrunMs` P99 | **-5.9 ms** | -5.7 ms | — | -5.87 / -6.25 ms |

**結論は再現した** — 相対はどちらの指標でも負 (ライブラリ側が速い) で、絶対上限 (`frameOverrunMs` P99 ≤ 0.0 ms) も満たす。個々の百分率は証跡と一致しないが、証跡自身が述べている揺れの範囲の内側である。ただしこの「速い側」の出どころについては下記 Minor 2 を見ること。

## 指摘事項

### [🟠 Major] `ksAnimatedHeight` の「はみ出しを切り取る」は成立しない比較で、一度も働かない

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsAnimatedHeight.kt:119` (および同 44 / 86-87 / 129-133 の記述) / `evidence/row-height-animation.md`「実装の選択」

**問題点**: 切り取りの可否を決めているのは次の 1 行である。

```kotlin
clipsContent = placeable.height > currentHeight
```

`Placeable.height` は定義上その placeable を測ったときの制約へ丸められた値であり、測定制約の `maxHeight` を超えることがない。この `measure` では

- 補間していないとき (`currentHeight == naturalPlaceable.height`) は `placeable.height == currentHeight`
- 補間中は `minHeight = maxHeight = currentHeight` の固定制約で測り直しているので `placeable.height == currentHeight`

となるため、`clipsContent` は**どんな入力でも false** である。`draw()` の `clipRect` 分岐 (:129-133) は到達しない。

実測でも確かめた。制約を無視する子 (`Modifier.requiredHeight`) を持つテンプレートで展開の補間を 1 フレームずつ進め、行の下端の 10 px 下の画素を読むと、行高 61 / 79 / 98 / 116 / 131 / 144 px のいずれのフレームでも **content の色がそのまま出た** (切り取られていれば背景色になる)。content は行の外側 — 次の行が描かれる領域 — へはみ出して描かれている。

これは前実装からの後退でもある。`androidx.compose.animation` の `animateContentSize` は `this.clipToBounds() then SizeAnimationModifierElement(...)` と定義されており (`AnimationModifier.kt:77`)、はみ出しは実際に切り取られていた。今回その `clipToBounds` を意図的に外した (レイヤを作らないため) こと自体は性能上の判断として理解できるが、**切り取りが働いていることを前提にした記述が KDoc・コメント・証跡の 3 か所に残っている**。この状態で蒸留すると「自前修飾ではみ出しをクリップする」という現存しない仕様が ADR / concepts の素材になる。

なお Sample の「行の高さ変化検証」で症状が出ないのは、テンプレートの根が `Column` であり、`Column` が子を残りの主軸空間で測る (子が押し出されない) ことと `Text` が自前で切り取ることによる。制約を無視する修飾 (`requiredHeight` / `requiredSize`) や独自 Layout を使うテンプレートでは出る。

**推奨修正**: どちらかを選ぶ。

- (a) 判定を実際の状態で行う。補間中の高さが自然高より小さいかどうか (`currentHeight < naturalPlaceable.height`) を切り取りの条件にする。回帰テストは、制約を無視する子を置いて行の外の画素を読む形で 1 件足せる (上記プローブと同じ形)
- (b) 切り取らない設計として確定する。その場合は `clipsContent` / `clipRect` の分岐と `clipRect` の import を落とし、KDoc (:44) とクラスのコメント、`evidence/row-height-animation.md`「実装の選択」の「はみ出す分は描画時に切り取るだけで」を削って、**「補間中に content が行の高さを超えると行の外へ描かれる」ことを既知の限界として `deviation.md` か `verification-matrix.md` に残す**

### [🟡 Minor] 証跡 2 か所が、採用済みの Sample 修正を「復元した」「採用は未決」と書いたまま

**該当箇所**: `evidence/row-height-animation.md`「残る条件: テンプレートの根が高さを使わない場合」 / `evidence/verification-matrix.md`「未検証の一覧」最終行 / `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/HeightChangeVerificationScreen.kt:141-147`

**問題点**: Sample の「テンプレート内 state」経路のセルには `propagateMinConstraints = true` が**恒久的に入っており**、実機でもこの経路の帯は全フレーム 0 px である (上記の観測)。しかし証跡は次のように書いたままである。

- `row-height-animation.md`: 「その内側で背景を塗っている本文との間に帯が残る (同じ手順で 260 → 2 px)」「この確認用の変更は採取後に復元した」
- `verification-matrix.md`: 「テンプレートの根が背景を塗らない場合の折りたたみ」を**未検証**として挙げ、「押さえるとしたら」欄に「Sample …の箱に高さの制約を通す指定を足す (確認済み。採用は未決)」

読み手は「Sample のこの経路には今も帯が出る」「対処は未採用」と受け取る。実際は採用済みで解消しており、蒸留がこの記述を素材にすると誤った限界が概念側へ移る。

**推奨修正**: `row-height-animation.md` の当該節を「Sample 側で採用した」形へ書き直し (帯 0 px の実測はすでに同節にある)、`verification-matrix.md` の「未検証の一覧」からこの行を外して、代わりに「行の高さ変化のアニメーション」欄へ**利用契約 (テンプレートの根へ高さの制約が渡ること) と、根が制約を使わない場合に帯が出ること**を残す。限界そのものは残るので、消すのではなく置き場を移す。

### [🟡 Minor] 相対 10% の比較対象がライブラリより重い実装を持ち続けており、基準が「ラッパーの上乗せ」を検出しなくなっている

**該当箇所**: `samples/android/app/src/measurement/kotlin/jp/kamusoft/kscollectionview/samples/android/MeasurementDestinations.kt:188` / `:211` / `evidence/performance-measurement.md`「相対基準の比較対象の条件」

**問題点**: 比較対象には `animateContentSize` が付いたままである。ライブラリ側はこのサイクルで自前修飾へ移り、`clipToBounds` (項目ごとの描画レイヤ) を持たなくなった。証跡自身が、以前の +10.6 〜 +12.9% の上乗せの出どころを「`animateContentSize` が内側に持つクリップ (項目ごとの描画レイヤ)」と分析している。つまり**比較対象だけがその重い実装を負っている**。

結果として相対は自前計測でも -7.9% / -8.0% (ライブラリが速い) となり、「劣化 10% 以内」という合格基準はラッパーの上乗せを検出できる状態ではなくなっている。`deviation.md` 7 件目の前提 —「既定機能そのもののコストで相対が超過するため、比較対象にも同じ既定機能を付ける」— は、自前修飾になった今も成り立つかどうかが未確認である。証跡は「比較対象の条件は同じ既定機能を持つことであり、実装をそろえる必要はない」と明言しているので合意の範囲だが、前提が変わった以上は測り直す価値がある。

**推奨修正**: 素の比較対象 (アニメーションなし) に対して 2 列を 1 実行だけ測り直す。10% 以内に収まるなら deviation 7 件目の対等化は不要になり、相対基準が本来の意味 (ラッパーの薄さ) を取り戻す。超過するなら、その値を根拠として現行の対等化を維持し、`performance-measurement.md` に「自前修飾でも素の比較対象では超過する」と 1 行残す。

### [🔵 Suggestion] 行の高さ変化の既定挙動と、その利用契約が公開 KDoc に無い

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:48-93` (公開 KDoc) / `kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md`「Android 行の高さ変化のアニメーション」

**問題点**: 「行の高さが変わるとアニメーションする」ことと「補間中はテンプレートの根に高さの制約が渡るので、根が制約を使わないと折りたたみの途中でページ背景が見える」ことは、`dsl-samples.md` にだけ書かれている。`KsCollectionView` の KDoc には行の高さ変化への言及が 1 行も無い。

これはライブラリの既定挙動であり、しかも Sample の「テンプレート内 state」経路 — セルを `clickable` の箱で包むという自然な書き方 — が実際にこれを踏んで 1 行の修正を要した。利用者は IDE の KDoc を読むのであってリポジトリのロードマップ成果物は読まない。なお iOS 側には同じ契約が無く、プラットフォーム間で非対称な利用契約が生まれている点も、蒸留のときに拾えるようにしておきたい。

**推奨修正**: `content` (テンプレートを宣言するブロック) の `@param` か KDoc 本文へ 2 行程度で足す。dsl-samples の記述はそのまま残してよい。

### [🔵 Suggestion] Android 固有の検証画面の観測点が handbook の表に無い

**該当箇所**: `kasane/handbook/cross/runtime-behavior-verification.md`「目視確認の観測点」

**問題点**: 同文書は「観測点の一覧は Sample のデモ画面が生まれる時点でこの節へ追記する。iOS エンジン基盤 / **Android ラッパー基盤の実装時が最初の追記機会**になる」と自ら定めている。表の最終行は「検証: 行の高さ変化 (iOS 固有)」だけで、Android 固有の同名画面の行が無い。

今サイクルの帯はまさに観測点で拾える型の症状であり (review-006 の Major 1 は観測点を 1 つ増やせば拾えた、と書いている)、行を足すなら観測点は「折りたたみの途中で行の中身と区切り線の間にページ背景が出ないこと」になる。

**推奨修正**: 表へ Android 固有行を 1 行足す。iOS 固有行と同じく「デモ画面の集合には数えない」例外枠の扱いにする。

### [🔵 Suggestion] 自前修飾の細かな取りこぼし 2 点

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsAnimatedHeight.kt:89-97` / `:99-124`

**問題点**: どちらも現状の使い方では実害が観測されないが、修飾を再利用するときに効いてくる。

- `onReset()` (項目の再利用) は `height = null` で参照を捨てるだけで、走っている `animateTo` のコルーチンを止めていない。捨てられた `Animatable` に対する補間が収束まで回り続ける (ノードのスコープは detach まで生きている)。高速スクロールで補間中の項目が再利用されると数フレーム分の無駄が乗る
- 固有サイズ (intrinsics) を上書きしていないため、親が固有サイズを問い合わせると `measure` が固有サイズ計測の文脈で走り、`Animatable` の生成やコルーチンの起動がそこで起きる。Lazy 系は問い合わせないが、`Modifier.height(IntrinsicSize.Min)` などで包まれると通る

**推奨修正**: 前者は `reset()` で補間の Job を保持して `cancel()` する。後者は最小限、固有サイズは補間を経由せず content へ委譲する (`measurable.minIntrinsicHeight` 等をそのまま返す) 形にする。

## アクションプラン

1. **(必須)** `clipsContent` の判定を直すか、切り取らない設計として KDoc・コメント・証跡の記述を落として既知の限界として記録する (Major)
2. **(必須)** 証跡 2 か所の「復元した」「採用は未決」を、採用済みの実態に合わせて書き直す (Minor 1)
3. (推奨) 素の比較対象で 2 列を 1 実行だけ測り直し、deviation 7 件目の対等化が今も要るかを確かめる (Minor 2)
4. (推奨) 公開 KDoc への 2 行、handbook の観測点表への 1 行 (Suggestion 2 件)
5. (任意) 自前修飾の取りこぼし 2 点、review-006 から持ち越しの混在行高の実機入口 (Suggestion)

1 と 2 は蒸留前に必要である。どちらも「現存しない挙動 / 解消済みの限界」が ADR・concepts の素材として読まれる経路であり、アーカイブ後は追跡できなくなる。

## 判定した論点

**`isForwardScroll` でレビュー案の符号を採らなかった判断は妥当である。**

review-006 の案 (`-scrollOffset` と `firstVisibleItemScrollOffset` を比べる) は、実装者の言うとおり向きが逆になる。対象の index が先頭可視項目と同じとき、対象の上端のコンテンツ座標を `c` とすると、現在のスクロール量は `c + firstVisibleItemScrollOffset`、要求後のスクロール量は `c + scrollOffset` である (`animateScrollToItem(index, scrollOffset)` は当該 index の `firstVisibleItemScrollOffset` を `scrollOffset` にする)。したがって前方は `scrollOffset > firstVisibleItemScrollOffset` であり、レビュー案はこれを反転させてしまう。

現行の実装 (`requestedTop = -scrollOffset` と `currentTop = -firstVisibleItemScrollOffset` を比べる) はこれと同値で、かつ「どちらも表示範囲の先頭からどれだけ下か」という 1 つの基準に揃っているため、`initialScrollOffset` が将来 0 より大きい値を返す形になっても向きが黙って逆にならない。review-006 が求めた「同じ基準へそろえる」を満たしている。式が現状の入力域では退化する (常に false) 点も変わらないが、それは「対象が先頭可視項目なら Center / End は必ず後方」という現在の設計の帰結であり、欠陥ではない。追加された 2 件のテストは退化しない入力 (`scrollOffset = 300`) も含めて向きの規約を固定しており、変異検査でも単独で落ちる。

## 確認した観点 (指摘に至らなかったもの)

- **足場アーティファクトの不改変**: `specs/` 4 ファイル・`design.md`・`proposal.md` は 09-04 のまま更新されていない。更新は `deviation.md` / `evidence/` に限られている
- **`deviation.md` 8 件目**: design Decision 4 の 2 段階を 1 回の命令へ集約した方式変更、その理由 (A/B)、残差の許容 4dp の根拠 (design の Open Question の回収)、逆向きの補正を入れない判断がすべて書かれている。design の Risks 節の事前指示に沿った記録として妥当。既存 7 件も合意済み差分として扱った
- **命令キューへの影響**: `isForwardScroll` の書き換えは `LaunchedEffect` 1 本・FIFO・最新配列での解決・先行命令の中断に触れていない。順序保証 (core/ADR-0007) 系のテストはすべて通る
- **修飾子の順序**: `ksAnimatedHeight` が `ksListSeparator` / `combinedClickable` より内側にあり、区切り線とタップ領域が補間中の高さを使う。実機でも区切り線が中身の直下に追従している
- **依存の絞り込み**: `androidx.compose.animation:animation` から `animation-core` へ落としている。`Animatable` / `spring` / `Int.VectorConverter` はいずれも `animation-core` にあり、`implementation` で正しい (公開 API の型に現れない)
- **測定中のコルーチン起動**: `measure` の中から `coroutineScope.launch` で補間を始める形は `animateContentSize` の実装と同じ流儀であり、補間値は snapshot state として `measure` で読まれるため再測定が正しく走る
- **`Box` の二重測定**: 補間中だけ content を 2 回測る (自然高 → 補間中の高さ) 分の上乗せは、補間している項目 1 つに閉じる。大量件数のフリックの計測では上乗せは観測されない (上記の再計測)
- **テストの手抜き**: 新規 3 件 (`headerHeightChangeAnimates` / `rowHeightCollapseKeepsContentBottomAtRowBottom` / 進行方向 2 件) は、クロックの自動進行を止めてフレームを 1 つずつ進め、失敗メッセージに実測値の系列を載せている。固定時間の待機・言い訳コメントによる実質スキップは無い
- **`tasks.md`**: 37 項目すべてチェック済みで未チェックは 0。本サイクルでは更新されていない (前サイクルの状態のまま)
- **Sample の対等性**: 変更したのは Android 固有の検証画面のみで、`sample-parity.md` が定める 9 デモ画面の文言・構成には触れていない (固有検証画面は同規約の例外枠)
- **成果物のパスと識別子**: 更新された証跡・本レビューともローカル絶対パス・端末の個体識別子を含まない (lint 2 種 0 件、本文も目視)
- **端末設定の復旧**: 観測で変更した `animator_duration_scale` は参考機・基準機とも 1.0 へ戻し、値を読み直して確認した
