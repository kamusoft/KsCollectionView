# レビュー結果: android-wrapper-foundation (008 回目)

**日付**: 2026-09-05
**判定**: APPROVED

## サマリー

review-007 の Major (「はみ出しを切り取る」が一度も働かない) は解消している。切り取りの可否を「補間しているかどうか」1 つの状態へ統一した実装は、**実機の実描画で A/B が成立した** — 制約を無視する content を持つテンプレートで補間の各フレームを採ると、現行実装では content が行の下端でぴたりと止まり (行の外 **0 px**)、切り取りを外した対照ビルドでは同じ手順で行の下端より下へ **150 px** はみ出す。証跡 2 か所の「復元した」「採用は未決」も採用済みの実態へ書き直されており、公開 KDoc の利用契約と自前修飾の後始末 (進行中 Job の cancel・intrinsics の上書き) も入っている。

新規の Critical / Major は無い。残るのは、相対 10% の比較基準が「ラッパーの上乗せ」より緩い側にあることの明示 (蒸留時に規約へ持ち込む話) と、自前修飾の細かな取りこぼし 2 点である。いずれも蒸留を妨げない。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| handbook/cross/comment-policy.md | always (公開 doc コメントの追加があるため節ごとに照合) |
| handbook/cross/test-execution.md | テスト実行・結果報告 |
| handbook/cross/runtime-behavior-verification.md | 実行時挙動 (アニメーション) の修正の完了判定 |
| handbook/cross/sample-parity.md | プローブで `samples/` を一時変更したため (復元済み) |
| handbook/ios/performance-verification.md | 大量件数の完了判定 (Android 計測が揃える手順の正) |
| decisions ios/ADR-0007 (content の配置規則) | 自前修飾が配置の責務を持つため |
| lessons/inbox/reviewer-reproduces-evidence-numbers-by-probe.md | 直前サイクルで直した箇所の証跡を自前プローブで再実行する義務 |
| lessons/inbox/observe-motion-not-only-end-state-for-scroll-and-resize.md / capture-transient-layout-glitch-with-offset-logs.md | 動きの過程を実描画で観測する評価軸 |
| kotlin-impl-skill / jetpack-compose-impl-skill | Kotlin 言語層・Compose の修飾子ノード (`LayoutModifierNode` / `DrawModifierNode` / intrinsics) と測定契約 |

`android/ADR-0001` / `android/ADR-0002` は `proposed` のため、これを根拠にした指摘は出していない。`kasane/lessons/` に昇格済みルールのファイルは無く、inbox の観測を評価軸として使った。

## 前回 (review-007) 指摘の追跡

| review-007 の指摘 | 状態 | 根拠 |
|---|---|---|
| 🟠 Major 「はみ出しを切り取る」が成立しない比較で一度も働かない | **解消** | `clipsContent = isInterpolating` に統一。実機 A/B で行の外へのはみ出しが 0 px / 対照ビルドは 150 px (下記「切り取りのプローブ」)。回帰テスト `rowHeightAnimationClipsContentIgnoringHeightConstraint` は変異検査で単独失敗する |
| 🟡 Minor 1 証跡 2 か所が採用済みの Sample 修正を「復元した」「採用は未決」と書いたまま | **解消** | `evidence/row-height-animation.md`「残る条件」は「Sample へ恒久的に入れて解消した」へ書き直され、`evidence/verification-matrix.md`「未検証の一覧」から当該行が消えて、利用契約が「行の高さ変化のアニメーション」欄へ移っている |
| 🟡 Minor 2 相対 10% の比較対象がライブラリより重い実装を持ち続けている | **部分対応** | 素の比較対象での測り直しは行われていない。ただし `evidence/performance-measurement.md` は、両側を `animateContentSize` にそろえた計測 (P90 +2.4% / P99 +6.8%) と、両側からアニメーションを外した対照計測 (P90 +2.3% / P99 +6.0%) の 2 つで「ラッパーの上乗せ」を別途押さえており、相対基準が何を測るものかも明記している。下記 Minor に残す |
| 🔵 Suggestion 1 行の高さ変化の既定挙動と利用契約が公開 KDoc に無い | **解消** | `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:60-63` に 3 文で追記。dsl-samples の記述と実装の挙動に一致し、内部用語も無い (下記「判定した論点」) |
| 🔵 Suggestion 2 Android 固有の検証画面の観測点が handbook の表に無い | **未対応** | `kasane/handbook/cross/runtime-behavior-verification.md` の「目視確認の観測点」表は 09-03 のまま。長命層への追記であり蒸留の経路で行うのが自然 |
| 🔵 Suggestion 3 自前修飾の取りこぼし 2 点 (再利用時の Job・intrinsics) | **解消** | `onReset` / `onDetach` が `reset()` を呼び、`reset()` が `animationJob.cancel()` を行う。intrinsics 4 種を上書きし、いずれも `updateAnimation` を経由しない |
| (review-006 から持ち越し) 🔵 混在行高の Center を実機で踏める画面が無い | **未対応** | `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/DemoData.kt:24-25` の `scrollItems` は等高のまま |

## 実行した検証

### ビルドとテスト (JDK 17)

| 対象 | 結果 |
|---|---|
| `android/` `:kscollectionview:testDebugUnitTest --rerun-tasks` | **66 tests / 0 failures / 0 skipped** (Core 14 + Interaction 22 + Layout 30。XML のクラス別内訳で確認。前サイクル 64 から Layout が +2) |
| `samples/android/` `:app:testDebugUnitTest --rerun-tasks` | **12 tests / 0 failures** (SampleDemoScreenTest 8 + SampleScreenParityTest 4) |
| `scripts/local-path-lint.py` / `identity-lint.py` / `comment-policy-lint.py` | 0 件 (comment-policy は検査対象 142 ファイル)。プローブ復元後にも再実行して同じ |

### 切り取りのプローブ (レビュー依頼 (a)。参考機で実描画の A/B)

review-007 が使ったプローブを、実装に触れない形で組み直して再実行した。

- テンプレートの本文を、行 1 だけ `Modifier.requiredHeight` (渡した高さの制約に従わない content) の赤い箱、行 2 以降は背景を塗らない透明な箱に差し替えた Sample を用意する。行 1 を折りたたみ 100dp / 展開 300dp とする
- 端末の `animator_duration_scale` を 10 にして補間を引き伸ばし、行 1 をタップした直後から静止画を 12 枚連続で取得する
- 各フレームで、行の左右中央より右 (文字に掛からない列) を上から読み、**赤の連続範囲**と、区切り線 (行の下端。`ksListSeparator` は自前修飾より外側にあるため切り取られない) の位置を数える

| ビルド | 赤の範囲の系列 (px) | 行の下端より下に出た content |
|---|---|---:|
| 現行 | 267 → 369 → 490 → 586 → 661 → 707 → 738 → 757 → 767 → 774 → 778 → 780 | **0 px** (全 12 フレーム。赤の末端の直後に区切り線があり、その下はページ背景) |
| 対照 (`clipsContent` を常に false にした変異) | 526 → 575 → 635 → 683 → 723 → 747 → 763 → 772 → 777 → 780 → 782 → 783 | **150 px** (中間フレームで、区切り線を跨いで赤が次の行の領域へ続く) |

現行では赤の範囲が行の高さと一致したまま 100dp 相当 (267 px) から 300dp 相当 (780 px) へ育つ。対照では最初のフレームからすでに 526 px あり、行の下端を示す区切り線の下に赤が 150 px 続いていた。**切り取りは実際に働いている**。

変異は複製から完全復元し、SHA-1 で照合済み。

### 行の高さ変化の回帰 (レビュー依頼 (e)。参考機、`animator_duration_scale` = 10)

Sample「検証: 行の高さ変化 (Android 固有)」の親 state / list で、展開と折りたたみを別々に採った。行 1 の上端の直下からその行の区切り線までを読み、ページ背景色 (242, 242, 247) の画素数と連続区間の最大長を数える (行の中身は白。タップのフィードバックで白が (241〜245) まで沈む区間があるため、青成分まで見て区別した)。

| 操作 | 採った実描画フレーム | 行の高さの推移 | 帯 |
|---|---:|---|---|
| 展開 | 12 | 123 → 376 px (中間 10 枚) | 全フレーム **0 px** |
| 折りたたみ | 12 | 373 → 123 px (中間 10 枚) | 全フレーム **0 px** |

review-006 が測った修正前の帯 (最大 261 px) はどのフレームにも出ない。展開の中間フレームも維持されている。

### スクロール命令の回帰 (レビュー依頼 (e))

`KsScrollCommandReceiver.kt` は本サイクルで変更されていない (更新時刻が review-007 の作成より前) ため、確認のためのスポットチェックにとどめた。等高 100 件の「スクロール制御」画面で、画面の階層を連続で読み、先頭可視項目の ID とその位置からコンテンツ先頭からのスクロール量を復元した。

| 手順 | 復元した位置 (px) | 逆行 / 行き過ぎ |
|---|---|---|
| 先頭 → 「Item 50」(Center・下方向) | 7,778 → 8,228 (以降 8,228 で静止) | 無し |
| 末尾 → 「Item 50」(Center・上方向) | 8,859 → 8,228 (以降 8,228 で静止) | 無し |

**両方向が同じ 8,228 px へ収束**する。階層の読み取りは 1 サンプルあたり 1 秒前後かかるため中間の採取点は各 1 点しか取れておらず、逆行の非発現の根拠としては review-007 の連続静止画の系列 (各 11 点) のほうが強い。本サイクルではその経路のコードが変わっていないことと合わせて回帰なしと判定した。

### 通常時の経路 (レビュー依頼 (b))

**性能の再計測は行っていない。** 本サイクルの差分が、補間していない通常時の描画・測定を変えていないことをコードで確認したうえでの判断である。

- `measure`: `isInterpolating` が false のとき content の測定は 1 回のまま (`naturalPlaceable` をそのまま使う)。追加されたのは `Int` の比較 1 つだけ
- `draw`: `clipsContent` が false のとき `drawContent()` の分岐を通る。前サイクルも `clipsContent` は常に false だったため、通常時に実行される命令列は変わっていない
- intrinsics の上書きは Lazy 系が問い合わせない経路であり、フリックでは通らない
- `onReset` の後始末は項目の再利用のたびに `Job?.cancel()` を 1 回呼ぶだけで、進行中の補間が無ければ null チェックで終わる

実機の裏取りとして Sample「大量件数」を `animator_duration_scale` = 10 のままフリックし、各フリック直後の静止画で行の送りを数えた。現れたのは確定値のみで、補間の途中の高さは 1 件も出ない。

### 変異検査 (実装を複製して差し替え、測定後に完全復元。復元は SHA-1 で照合済み)

| 変異 | FAILED になったテスト |
|---|---|
| A: `clipsContent` を常に false にする | `rowHeightAnimationClipsContentIgnoringHeightConstraint` の **1 件だけ** |
| B: `onReset()` の中身を空にする | **0 件** (下記「確認した観点」) |

A は新規テストが空振りしていないことを示す。B は落ちるテストが無く、実装者が `evidence/row-height-animation.md` に明記している「検証層では再利用時の後始末だけを外しても失敗しない」と一致した。

## 指摘事項

### [🟡 Minor] 相対 10% の合格基準は今もラッパーの上乗せより緩い側にあり、その但し書きが規約へ引き継がれない

**該当箇所**: `evidence/performance-measurement.md`「相対基準の比較対象の条件」 / `deviation.md` 7 件目とその補足

**問題点**: 比較対象には `animateContentSize` が付いたままで、これは `clipToBounds` (項目ごとの描画レイヤ) を常時持つ。ライブラリ側は補間中だけ描画時に切り取る形になったため、**アニメーションが走っていないフリックの計測では、比較対象だけがレイヤのコストを負う**。合格基準「劣化 10% 以内」はこの条件では緩く、ラッパーの上乗せを検出しない。

証跡自身はこの構図を隠しておらず、相対基準が測るものを「標準の Compose で同じ機能を組んだ場合に対するラッパーの上乗せ」と明記し、ラッパーそのものの薄さは別の 2 つの対等な計測 (両側 `animateContentSize` で P90 +2.4% / P99 +6.8%、両側アニメーションなしで P90 +2.3% / P99 +6.0%) で押さえている。したがって主張の裏付けとしては足りている。残る問題は**置き場**である — この但し書きは change の証跡にしか無く、証跡はアーカイブされる。deviation 2 件目は「蒸留時に handbook/android/performance-verification.md へ規約化する」と述べており、その規約に相対基準の読み方が入らないと、後続の変更が 10% を素直な合格基準と読む。

**推奨修正**: 蒸留で `handbook/android/performance-verification.md` を起こすときに、相対基準の条件 (比較対象に同じ既定機能を付ける) と、それが測るものの但し書き (ラッパーそのものの薄さは対等条件の計測で別に押さえる) を 1 節として持ち込む。本サイクルでのコード変更は要らない。

### [🔵 Suggestion] 補間中かどうかの判定が、制約で丸める前の高さと比べている

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsAnimatedHeight.kt:112-113`

**問題点**: 補間の目標は `constraints.constrainHeight(naturalPlaceable.height)` (制約で丸めた値) なのに、補間中かどうかの判定は丸める前の `naturalPlaceable.height` と比べている。

```kotlin
val currentHeight = updateAnimation(constraints.constrainHeight(naturalPlaceable.height))
val isInterpolating = currentHeight != naturalPlaceable.height
```

高さの制約が実際に効く箱にこの修飾を付けると、補間が収まったあとも `currentHeight`(= 丸めた目標) と `naturalPlaceable.height` が食い違い続けるため、`isInterpolating` が **恒久的に true** になる。そうなると content の測り直しと描画の切り取りが常時走り、「通常時は 1 回の測定で済む」という設計上の前提が静かに崩れる。

現在の使い方 (`LazyVerticalGrid` の項目・ヘッダー・フッター) では主軸の `maxHeight` が無制約なので丸めは起きず、実害は無い。修飾は `internal` なので影響も 1 ファイルに閉じている。

**推奨修正**: 判定を目標そのものと比べる (`currentHeight != targetHeight`) 形にする。1 行で、意味も「まだ目標に届いていない」と素直に読める。

### [🔵 Suggestion] 切り取りは幅にも掛かるが、doc は高さだけを述べている / 再利用時の後始末は静的レビューでしか担保されていない

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsAnimatedHeight.kt:47-48` / `:138-146` / `:100-102`

**問題点**: どちらも現状の使い方では実害が観測されないが、修飾を再利用するときに効いてくる。

- `clipRect(right = size.width, bottom = size.height)` は左右にも掛かる。`Modifier.requiredWidth` のように幅の制約に従わない content は、補間中だけ横方向にも切り取られ、補間が終わった瞬間に元の幅で現れる (見え方が跳ぶ)。doc コメント (:47-48) は「描画を箱の高さで切り取る」としか書いていないため、この振る舞いは読み取れない
- `onReset()` の後始末 (進行中の補間の打ち切り) は、検証層のどのテストでも落ちない (上記 変異 B)。`reusedItemDoesNotInheritPreviousRowHeight` は再利用の往復での見え方を押さえるものであり、後始末そのものは押さえていない。証跡はその旨を明記しており隠していないが、担保はレビューの目だけに載っている

**推奨修正**: 前者は doc を「箱の範囲で切り取る」に直すか、切り取りを縦方向だけに限る。後者は、`ReusableContentHost` などで再利用そのものを起こす形の単体テストを 1 件足せば、この修飾を他所で使うときの回帰網になる。どちらも本 change の完了条件ではない。

## アクションプラン

1. (蒸留時) `handbook/android/performance-verification.md` に相対基準の条件と但し書きを持ち込む (Minor)
2. (蒸留時) `handbook/cross/runtime-behavior-verification.md` の観測点表へ Android 固有の検証画面の行を足す (review-007 Suggestion 2 の持ち越し)
3. (任意) 補間判定を目標と比べる形へ、切り取りの doc と範囲、再利用の後始末のテスト (Suggestion 2 件)
4. (任意) 混在行高の Center を実機で踏める画面 (review-006 からの持ち越し)

1〜4 のいずれもコードの誤りではなく、本 change のアーカイブを妨げない。

## 判定した論点

**公開 KDoc の追記は、dsl-samples の記述・実装の挙動・comment-policy のいずれとも整合している。**

追記された 3 文は「行の高さが変わるとアニメーションする」「補間の間はテンプレートのいちばん外側の要素に行の高さが制約として渡る」「外側が制約を受け取らずに内側だけで背景を塗ると折りたたみの途中で背景の隙間が見える」「外側で背景を塗るか `propagateMinConstraints = true` を付ける」である。

- **実装との一致**: 項目・ヘッダー・フッターの箱はいずれも `propagateMinConstraints = true` の `Box` に `ksAnimatedHeight` を付けた形であり、補間中は `minHeight = maxHeight = 補間中の高さ` でテンプレートの根を測り直す。「行の高さが制約として渡る」は正確
- **dsl-samples との一致**: `kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md`「Android 行の高さ変化のアニメーション」と、条件 (根が制約を使わない透明な箱) も対処 (根で背景を塗る / `propagateMinConstraints`) も同じことを述べている
- **comment-policy との一致**: 公開 doc コメントの節を照合した。ADR ID・change 名・デルタスペック構文キーワード・作業文書のパス・履歴記述はいずれも含まれず、利用者が知っている語 (`Box` / `propagateMinConstraints`) だけで閉じている。事後判定 (公開 doc だけを読んで意味が通るか) も満たす

なお、切り取り (制約に従わない content が行の外へ描かれないこと) は公開 KDoc に書かれていないが、これは利用者が契約として守るべきことではなくライブラリ側の保証なので、公開 doc に無くても契約の説明としては欠けていない。

## 確認した観点 (指摘に至らなかったもの)

- **足場アーティファクトの不改変**: `specs/` 4 ファイル・`design.md`・`proposal.md` は 09-04 のまま。本サイクルで更新されたのは実装 2 ファイル・テスト 1 ファイル・証跡 3 ファイルに限られる
- **deviation との整合**: 7 件目の補足が述べる「両者は機能として同等 (高さの補間 + はみ出しのクリップ)」は、切り取りが働くようになった本サイクルではじめて事実になった。8 件の乖離はいずれも合意済み差分として扱い、違反として指摘していない
- **`onReset` / `onDetach` の後始末**: `reset()` は進行中の Job を打ち切り、`Animatable` の参照・目標・切り取りの状態をすべて捨てる。再利用でも切り離しでも次の測定が初回として走るため、前の項目の高さから補間が始まる経路は無い。`onDetach` での `cancel()` はノードのスコープが切れることと二重だが害は無い。`updateAnimation` が目標を変えるときに先行 Job を `cancel()` してから `animateTo` を起こす順序も、`Animatable` 側の排他と二重だが誤りではない
- **intrinsics の上書き**: 4 種すべてを上書きして `updateAnimation` を経由しない形にしてあり、「問い合わせだけで補間が始まる / `Animatable` が生成される」経路は塞がっている。高さ 2 種は補間中だけ現在値を返し、それ以外は content へ委譲する。補間の開始命令を出してから `Animatable.isRunning` が真になるまでの数ミリ秒だけ、問い合わせが content の固有値を返す窓があるが、Lazy 系は固有サイズを問い合わせないため現状の経路には現れない
- **修飾子の順序**: `ksListSeparator` と `combinedClickable` は `ksAnimatedHeight` より外側にあり、切り取りの対象にならない。プローブで、はみ出す content を持つ行でも区切り線が行の下端に描かれることを実描画で確認した
- **水平配置 (ios/ADR-0007)**: 配置は `horizontalAlignment.align` のままで、補間中も content は上端に置かれる。`narrowContentIsCenteredAndWideContentFillsFromStart` が通る
- **新規テストの手抜き**: 2 件ともクロックの自動進行を止めてフレームを 1 つずつ進め、失敗メッセージに実測値の系列を載せている。切り取りのテストは「中間フレームが 3 枚以上採れていること」を先に assert しており、補間が起きずに空振りで合格する経路を塞いでいる。再利用のテストは変異 B で落ちないが、証跡がその限界を明記しており、テスト自体は再利用往復の見え方という別の回帰網として成立している
- **`tasks.md`**: 37 項目すべてチェック済みで未チェック 0。本サイクルでは更新されていない
- **Sample の対等性**: 本サイクルで `samples/` の恒久的な変更は無い (プローブ用の一時変更は SHA-1 で照合して復元済み)。`sample-parity.md` が定める 9 デモ画面には触れていない
- **成果物のパスと識別子**: 更新された証跡・本レビューともローカル絶対パス・端末の個体識別子を含まない (lint 2 種 0 件、本文も目視)
- **端末設定の復旧**: 観測で変更した `animator_duration_scale` は参考機・基準機とも 1.0 へ戻し、値を読み直して確認した
