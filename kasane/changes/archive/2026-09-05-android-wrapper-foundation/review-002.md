# レビュー結果: android-wrapper-foundation (002 回目)

**日付**: 2026-09-05
**判定**: CHANGES_REQUESTED

**レビュー範囲**: tasks.md グループ 2〜6 (Android 本体、`android/` 全体) と、review-001 Minor 1 (iOS の下端区切り線の色テスト) の修正確認。グループ 7 (Sample)・8 (性能計測)・9 (文書) と tasks 6.5 は未着手のため対象外。

## サマリー

Android ラッパー本体は公開 DSL の形・core/ADR-0011 の 3 経路・スクロール命令の順序保証のいずれも成立しており、テストは 49 件すべて緑で「収束を待つアサーション」の形も守られている。ただし list の区切り線が項目 content の**背面**に描かれるため、不透明な背景を持つテンプレート (Sample の `SampleTheme.cell` = #FFFFFF がまさにこれ) では区切り線が 1 本も見えない。既存テストが透明な content でしか描画を見ていないためこの穴が素通りしている。

review-001 Minor 1 は解消済み。指摘は Major 1 件・Minor 4 件・Suggestion 4 件。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| [handbook/cross/comment-policy.md](../../handbook/cross/comment-policy.md) | always (全ソースコード) |
| [handbook/cross/test-execution.md](../../handbook/cross/test-execution.md) | テストを実行し件数を報告する |
| [handbook/cross/public-identifiers.md](../../handbook/cross/public-identifiers.md) | `**/build.gradle.kts` / `**/settings.gradle.kts` を触る (Android ビルド定義の新設) |

適用外と判定: handbook/cross/sample-parity.md (`samples/` は本レビュー範囲に無い — グループ 7 未着手)、handbook/cross/runtime-behavior-verification.md (実行時不具合の調査・修正完了判定ではない)、handbook/cross/local-development-setup.md (guide、環境構築作業ではない)。`kasane/handbook/android/` `core/` は文書なし。

参照した決定・概念: core/ADR-0004 (テンプレート宣言)・0006 (単一コンポーネント + layout 値)・0007 (スクロール制御)・0010 (区切り線の既定外観、proposed)・0011 (不正入力の release 挙動、proposed)、android/ADR-0001 (LazyVerticalGrid 統一、proposed)・0002 (単一モジュール + explicitApi strict、proposed)、cross/ADR-0002 (ビルドルート)・0003 (公開識別子)、`kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md` の Kotlin 側と公開語彙一覧。
lessons: `kasane/lessons/code-review.md` は未作成 (昇格済みルールなし)。

## 実行した検証

- `android/` `:kscollectionview:assemble` + `:kscollectionview:testDebugUnitTest --rerun-tasks`: **BUILD SUCCESSFUL**、警告 0 件 (debug / release AAR とも生成)
- テスト件数 (`android/kscollectionview/build/test-results/testDebugUnitTest/TEST-*.xml` の集計): **49 tests / 0 failures / 0 errors / 0 skipped** (Core 13 / Layout 22 / Interaction 14)
- lint: comment-policy 0 件 (検査対象 92 ファイル) / local-path 0 件 / identity 0 件
- 区切り線の z 順の実測: リポジトリを触らない複製 (セッションの作業ディレクトリ) で、白背景の項目テンプレートを使った描画を画素で確認。**上端 (y=0) / 行間 (y=49) / 下端 (y=99) すべてが白のまま**で区切り線が現れない。同じ複製で `drawBehind` を `drawWithContent { drawContent(); … }` に替えると 3 本とも既定色 (#D9D9DE) で現れることを確認
- `explicitApi()` が strict で効いていることの実測: 同じ複製の main ソースへ visibility なしの宣言を足すと `Visibility must be specified in explicit API mode.` / `Return type must be specified in explicit API mode.` が **error** (warning ではない) で出ることを確認
- iOS 側 review-001 Minor 1 の修正確認 (下記)

## 指摘事項

### [🟠 Major] 不透明な背景を持つテンプレートでは区切り線が 1 本も見えない (iOS と描画順が逆)

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsListSeparator.kt:36` (`drawBehind`)、適用箇所 `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:214`

**問題点**: 区切り線を `drawBehind` で描いているため、項目 content が自分の背景を塗ると上端・行間・下端のすべてが隠れる。実測で確認済み (「実行した検証」参照)。iOS は区切り線を contentView の**前面**に出しており (`ios/Sources/KsCollectionView/KsHostingCell.swift:108-109` の `bringSubviewToFront`)、両プラットフォームで描画順が逆になっている。

`specs/collection-layout/spec.md` の Requirement「list の区切り線 (Android)」Scenario「既定表示と opt-out」の THEN (「先頭行の上端・各行の間・最終行の下端に区切り線が表示される」) と、同 Requirement の「既定の色・太さ・位置は iOS 実装と同じ実値とする」を、背景を持つテンプレートで満たさない。セルに背景色を置くのはリスト UI の一般形であり、`ui/brief.md` が一致対象に挙げる SampleTheme のセル背景は `#FFFFFF` なので、グループ 7 で iOS と Android が直接食い違う。

既存の区切り線テスト (`android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsCollectionViewLayoutTest.kt:550-563`) は背景を持たない `Text` だけを置いているため、この穴を検出できていない。

**推奨修正**: `ksListSeparator` を `drawWithContent { drawContent(); <線を描く> }` にして content の前面に描く (複製で実測し、3 本とも既定色で現れることを確認済み)。あわせて区切り線テストの下ごしらえに不透明な背景 (`Modifier.background(...)`) を持つテンプレートの系を 1 つ足し、content の背景で隠れないことをアサートする。

design.md Decision 5 は手段として `drawBehind` と書いているため、実装を変える場合はその差分を `deviation.md` に記録すること (足場は凍結、逆流修正はしない)。

### [🟡 Minor] 実装済みの機能を「未実装」と述べる TODO コメントが残っている

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:237`

```kotlin
// TODO: onItemTap / onItemLongTap / touchFeedbackColor の接続は未実装。
```

**問題点**: この 3 つは同じ関数の直前 (`:221-232`) で `combinedClickable` + `ripple` として実装済みで、tasks.md 5.1 も `[x]` になっており、対応するテストも通っている。コメントだけが古い状態を述べている。comment-policy の「現在の仕様を現在形で書く」に反し、このファイルだけを読む人 (人間・エージェント双方) を確実に誤らせる。機械検査 (comment-policy-lint) は禁止参照だけを見るためこの型を拾わない。

**推奨修正**: この行を削除する。

### [🟡 Minor] ヘッダーがあるときのスクロール index 補正と contentPadding 基準が 1 件も検証されていない

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsScrollCommandReceiver.kt:117` (`leadingItemCount + itemIndex`)、`:154-166` (`alignmentDelta` の `beforeContentPadding` / `afterContentPadding`)

**問題点**: `specs/collection-interaction/spec.md` の Requirement「スクロール制御 (Android)」は「位置の基準は `contentPadding` の内側の表示範囲とし、ヘッダー / フッターは要素の index に数えない (SHALL)」を明記しているが、`KsCollectionViewInteractionTest.kt` のスクロール系テストは `header` も `footer` も `contentPadding` も一度も宣言していない (`ScrollTestCollection` `:418-443`)。したがって index の +1 補正と内側表示範囲の計算はどちらも未実行のまま緑になっている。ヘッダー付きで `scrollTo(id)` が 1 項目分ずれても、今のテストは気づかない。

**推奨修正**: `header` と `contentPadding` を宣言したケースで `scrollTo(id, position = Center)` を呼び、対象が `contentPadding` 内側の中央に来ることをアサートするテストを 1 件足す。

### [🟡 Minor] 「接続解除後は no-op」のアサーションが構造上必ず成立する (空振り)

**該当箇所**: `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsCollectionViewInteractionTest.kt:342`、`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsScrollController.kt:33`

**問題点**: `KsScrollController.processedCommandCount` は `receiver?.processedCommandCount ?: 0` で、detach 後は receiver が null なので**常に 0 を返す**。`detachedControllerIsNoOp` の `assertEquals(0, controller.processedCommandCount)` は、仮に命令が処理されていたとしても 0 になるため、「処理されなかったこと」を区別できない。Scenario「接続解除後の no-op」で実質担保できているのは「クラッシュしない」ことだけになっている。

未接続版 (`:320`) は同じ性質の値を見ているが、`topOf("item-0")` の不変も併せて見ているため空振りではない。

**推奨修正**: detach 前に受け口側の件数を控えて比較する、あるいはコレクションを消さずに `scrollController` だけを外して (接続解除後も表示は残る形にして) スクロール位置が動かないことをアサートする。

### [🟡 Minor] core/ADR-0011 の「黙らず」(警告ログ) が 1 件もアサートされていない

**該当箇所**: `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsCollectionViewCoreTest.kt:77,248,292`、`android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsCollectionViewInteractionTest.kt:194`

**問題点**: 重複 ID・二重登録・未登録キー・存在しない ID への `scrollTo` の 4 経路は、いずれも spec の THEN に「警告ログが出力される」が入っている。実装は `KsDiagnostics.warn` / `invalidInput` で `Log.w` を呼んでいるが、テストは表示結果と assertion の有無だけを見ており、ログが出ることは 1 件も検証していない。core/ADR-0011 は「落とさず・消さず・黙らず」の 3 点セットで、3 点目だけが検証層から漏れている。Robolectric なら `ShadowLog.getLogs()` で観測できるため、検証できない類ではない。

**推奨修正**: release 側 (`debugOverride = false`) の各テストに `ShadowLog` で該当タグの warn が出ていることのアサーションを 1 行ずつ足す。

### [🔵 Suggestion] ripple 描画・アニメーション中断の検証層が未定のまま残っている

**該当箇所**: `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsCollectionViewInteractionTest.kt:83-104`

**問題点**: `touchFeedbackColor` を渡すテストは受け口 (`OnClick` / `OnLongClick` semantics) の有無までしか見ておらず、指定した色が実際に ripple へ届くことはどのテストでも確かめていない。コメントは「Robolectric では描画されない」と述べるが、このクラスは `@GraphicsMode(NATIVE)` を付けており、同じ設定の Layout テストは画素比較に成功している。同様に「後の命令が先行アニメーションを中断する」も、最終位置しか見ていないため中断そのものは未検証。deviation.md も無いため、この 2 点をどの層 (実機手動) で担保する想定なのかが成果物のどこにも書かれていない。

**推奨修正**: tasks 6.5 (Requirement ⇔ 検証層の対応表) で ripple の色とアニメーション中断を「実機手動」として明示的に置く。あわせて、押下状態を作った画素比較が NATIVE モードで成立するかを一度試し、成立するならテストへ落とす。

### [🔵 Suggestion] 再コンポジションのたびに配列全体を 3 回走査する

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:108-112,130`

**問題点**: 未登録キーの走査 (`:108-112`) と `resolvedItems.map { it.id }` の生成 (`:130`) は `remember` の外にあり、`KsCollectionView` が再コンポーズされるたびに走る。さらに `rememberUpdatedState` への代入は既定の構造的等価ポリシーで比較するため、同じ内容の List でも要素数分の比較が走る。配列が変わっていなくても、spec が要求する「テンプレートの中で親の状態を読む」書き方 (親 state の変更で `KsCollectionView` ごと再コンポーズされる) をすると、10,000 件で毎回 3 パス + 1 万要素の `ArrayList` 生成になる。Requirement「大量件数での仮想化・再利用 (Android)」の相対劣化 10% を測る前に潰しておく価値がある。

**推奨修正**: `remember(resolvedItems)` の中で「ID のリスト」と「登場するテンプレートキーの集合」を作り、毎コンポジションでは小さいキー集合と `templates` の突き合わせだけにする。

### [🔵 Suggestion] 「データ反映後に実行」がフレームクロックの awaiter 登録順に暗黙依存している

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:136-143`

**問題点**: `withFrameNanos { }` で 1 フレーム待つ設計は、「同じフレームの中で Recomposer の frame callback が先に走り、`rememberUpdatedState` で更新された最新の配列が読める」ことに依存している。`scrollToEndReachesItemAddedInTheSameFrame` が緑なので現状は成立しているが、その順序が成り立つ理由はコード上のどこにも書かれておらず、Compose 側の実装詳細に寄りかかった保証になっている。core/ADR-0007 の順序保証はこの変更の中核の一つなので、根拠を残しておきたい。

**推奨修正**: 実装側コメントに「Recomposer が同じフレームクロックへ先に登録された awaiter として先に走るため、この時点の `latestItemIds` は差し替え後の配列である」ことを明記する。あるいは、`withFrameNanos` ではなく「配列が反映されたこと自体」(`snapshotFlow` で `latestItemIds` の到達を待つ) を待って順序への依存を外す。

### [🔵 Suggestion] `processedCommandCount` が snapshot state でも volatile でもない

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsScrollCommandReceiver.kt:33`

**問題点**: 隣の `enqueuedCount` は `mutableIntStateOf` なのに対し、`processedCommandCount` は素の `Int` で、メインスレッドから書かれた値をテストスレッドが読む形になっている。Robolectric は単一スレッドで動くため現状は問題ないが、同じ待ち方を androidTest (instrumentation スレッドから読む) へ移すと、可視性の保証がないぶん間欠的に待ち足りなくなりうる。

**推奨修正**: `enqueuedCount` と同じく `mutableIntStateOf` にする。

## review-001 の指摘の追跡

- **Minor 1 (区切り線の色のテストが下端を検証していない)**: **解消済み**。`ios/Sources/KsCollectionView/KsHostingCell.swift:57-63` で `topSeparatorColor` / `bottomSeparatorColor` の 2 つの窓に分かれ、`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:185-190` が first / middle / last の**上端・下端の両方**を指定色でアサートしている。既定色へ戻したときの検証 (`:202-205`) と既定表示時の検証 (`:148-149`) も上下両方を見ている
- **Minor 2 (concepts / ADR への乖離の申し送り)**: 未解消のまま。蒸留 (ksn-distill) 側の担当として据え置き
- **Suggestion (「リスト」画面の初期選択を「既定」に揃える)**: グループ 7 が未着手のため未着手。申し送り継続
- **Suggestion (dsl-samples の出典 ADR 列)**: 未対応。`dsl-samples.md:403` の出典列は `0006, 0010` になっており**対応済み**
- **Suggestion (`UIColor` の同値比較)**: 対応不要と結論済みのまま変更なし

## アクションプラン

1. **(必須)** 区切り線を content の前面に描く (`drawWithContent`) + 不透明背景のテンプレートでの描画テストを追加。design Decision 5 との差分を deviation.md に記録 (Major)
2. **(必須)** `KsCollectionView.kt:237` の古い TODO コメントを削除 (Minor)
3. **(推奨)** ヘッダー + `contentPadding` を含むスクロール解決のテストを 1 件追加 (Minor)
4. **(推奨)** 接続解除後 no-op のアサーションを実効のある形へ差し替え (Minor)
5. **(推奨)** 警告ログ (`ShadowLog`) のアサーションを ADR-0011 の 3 経路 + `scrollTo` の存在しない ID に追加 (Minor)
6. **(グループ 6.5 で)** ripple の色とアニメーション中断の検証層を対応表に明記 (Suggestion)
7. **(グループ 8 の前に)** 毎コンポジションの O(n) 走査を `remember` へ畳む (Suggestion)

## 確認して問題がなかった観点

- 足場アーティファクト (proposal / design / specs / brief) は未変更。`tasks.md` の差分はチェックボックスの反映のみで本文の書き換えはない
- 実装済みチェックに虚偽なし (2.1〜6.4 すべて対応する成果物とテストを確認)。6.5 と 7〜9 は未チェックのまま
- 公開 API の形が dsl-samples.md の Kotlin 側と一致: `KsCollectionView(items, key, modifier, template, layout, contentPadding, header, footer, onItemTap, onItemLongTap, touchFeedbackColor, listSeparators, listSeparatorColor, scrollController) { template(key) { } / template { } }`、`KsLayout.List` (括弧なし = companion) と `KsLayout.List(rowSpacing =)` の両形、`KsLayout.Grid(columns =, rowSpacing =, columnSpacing =)`、`KsColumns.Fixed(n)` / `Fixed(portrait =, landscape =)` / `Adaptive(minItemWidth =)`、`KsScrollController` / `rememberKsScrollController()` / `scrollTo(id, position, animated)` (`KsScrollPosition.Start/Center/End`) / `scrollToStart` / `scrollToEnd`。公開語彙一覧の 0002・0004・0006・0007・0009・0010 の行と Kotlin 側が全項目一致する (未実装の `paging` / `prefetchResources` / `KsImage` は Non-Goals どおり不在)
- core/ADR-0011 の 3 経路がすべて `KsDiagnostics.invalidInput` の 1 か所に集約され、debug は `IllegalStateException`、release は `Log.w` + 継続で成立している。重複 ID は後に現れた要素の位置で後勝ち (`KsResolvedItems.kt:43-48`)、未登録キーは最小高の空項目で件数が保たれ、二重登録は `LinkedHashMap.put` の後勝ち。debug / release の両分岐がテストで押さえられている
- スクロール命令の順序保証: 消費側 `LaunchedEffect(receiver)` はコンポジションの生存期間に 1 本だけで、配列やヘッダーの有無の変化で作り直されない (`rememberUpdatedState` 経由で最新値を読む形)。したがって配列更新でキュー内の命令が失われない — spec の「配列の更新はキュー内の命令を消失させてはならない」に適合。`enqueuedCount` を残件数ではなく単調増加の延べ件数にしているため「積む → 消費し切る → また積む」でも変化が観測される。中断された命令も `finally` で処理済みに数えられ、待機側が取り残されない
- 1 フレーム待ちの副作用: 命令はデータ更新の有無に関わらず必ず 1 フレーム遅れて実行される。`scrollToStart` のような即時性の要る操作でも 1 フレームの遅延が入るが、spec に即時性の要求はなく、順序保証と引き換えとして妥当
- テストが「収束を待つアサーション」の形になっている: `awaitCommands` (`KsCollectionViewInteractionTest.kt:363-373`) は実時間 deadline で区切り、ループ内で `waitForIdle()` + `advanceTimeByFrame()` により待機対象へ実行機会を譲り、超過時は実測値を添えて `fail` する — handbook/cross/test-execution.md の 3 条件をすべて満たす。固定時間待機は 1 件もない
- テスト件数の確認まで実施 (49 tests / 0 failures)。`--rerun-tasks` を付けており「差分なしで 0 件 BUILD SUCCESSFUL」ではないことを確認済み。Robolectric の描画限界への対処として、実描画を要するクラス (Layout / Interaction) に `@GraphicsMode(NATIVE)` が付いている
- `explicitApi()` が strict で効いていることを実測で確認 (warning ではなく error)。公開宣言はすべて visibility と戻り値型を明示し、KDoc を持つ
- 公開識別子: namespace `jp.kamusoft.kscollectionview`、`group = "jp.kamusoft"`、`rootProject.name` / モジュール名 `kscollectionview` (ハイフンなし 1 トークン)、version の宣言元は `gradle/libs.versions.toml` の 1 箇所でルートが `subprojects` 一括で設定 — public-identifiers の写像表と「保証すること」の全項目に適合。artifact は 1 点で層分割していない
- 公開 doc コメントに内部用語 (ADR ID・change 名・デルタスペック構文キーワード) の混入なし。ADR 参照は `internal` 宣言のコメントとビルド定義のコメントにのみ現れ、いずれも `<domain>/ADR-NNNN` 形式 (comment-policy の許容参照)
- 依存の公開範囲: 公開 API に型が現れる Compose BOM / runtime / ui / foundation-layout を `api`、内部だけで使う foundation / material3 を `implementation` に分けている。`compose-ui-test-manifest` は `testImplementation` に置かれ発行物へ混入しない
- 向き判定はコンテナ自身の `maxHeight > maxWidth` で行い (`KsCollectionView.kt:185`)、`LocalConfiguration` の端末向きは参照していない。同値 (正方形) は landscape 側 — spec の「幅 ≥ 高さなら landscape」と一致
- release 側の防御: 0 以下の列数は `coerceAtLeast(1)`、0 以下の `minItemWidth` は `coerceAtLeast(1.dp)`、負のスペーシングは `coerceAtLeast(0.dp)` で、debug で停止・release で継続の形が layout 値にも通っている
- layout 差し替え時に `LazyGridState` が `remember` されたまま維持され、データとアンカー項目が保たれる (テスト済み)
- 「スクロールインジケータの位置は `contentPadding` の影響を受けない」は、Compose の `LazyVerticalGrid` が標準のスクロールインジケータを持たないため該当なし
- `deviation.md` は不在。無断の仕様逸脱・同梱条件を超える付随修正の混入は見当たらない (`android/` 以外の変更はグループ 1 の iOS 追随分のみ)
- lint 3 種 (comment-policy / local-path / identity) いずれも 0 件
