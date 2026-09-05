# レビュー結果: android-wrapper-foundation (003 回目)

**日付**: 2026-09-05
**判定**: APPROVED

**レビュー範囲**: review-002 の指摘 (Major 1・Minor 1〜4) と second-opinion-code-002 の「突き合わせ結果」で採用・確定とした項目の修正確認、および修正による回帰の有無。対象は `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/` の本体 9 ファイルと `src/test/kotlin/` の 3 テストクラス + テスト支援 1 ファイル。tasks.md グループ 7 (Sample)・8 (性能計測)・9 (文書)・6.5 は未着手のため対象外。

## サマリー

前回の必須 2 件・推奨 3 件と、相方レビューで採用・確定とした 5 件がすべて解消している。修正で追加・差し替えられたテストは**変異注入で 1 件ずつ実測し、いずれも意図した契約が壊れたときだけ落ちること**を確認した (下記「実行した検証」)。特に前回「空振り」と指摘した `detachedControllerIsNoOp` は、detach を無効化した変異で確かに落ちる形になっている。件数比例の保持構造も解消され、正常系では利用者の配列そのものを保持することを実測で確かめた。

新規の Critical / Major / Minor はなし。Suggestion 5 件 (うち 2 件は前回からの持ち越し)。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| [handbook/cross/comment-policy.md](../../handbook/cross/comment-policy.md) | always (全ソースコード) |
| [handbook/cross/test-execution.md](../../handbook/cross/test-execution.md) | テストを実行し件数を報告する |

適用外と判定: public-identifiers.md (本サイクルでビルド定義・namespace・配布座標に変更なし)、sample-parity.md (`samples/` は範囲外 — グループ 7 未着手)、runtime-behavior-verification.md (実行時不具合の調査・修正完了判定ではない)、local-development-setup.md (guide、環境構築作業ではない)。`kasane/handbook/android/` `core/` は文書なし。

参照した決定・概念: core/ADR-0007 (スクロール制御の順序保証)・0010 (区切り線の既定外観、proposed)・0011 (不正入力の release 挙動、proposed)、android/ADR-0001・0002 (proposed)。デルタスペック 3 本と design.md Decision 1〜5、deviation.md。
lessons: `kasane/lessons/code-review.md` は未作成 (昇格済みルールなし。`lessons/inbox/` に未昇格の観測が 7 件)。

## 実行した検証

- ビルドとテスト: `:kscollectionview:assemble` + `:kscollectionview:testDebugUnitTest --rerun-tasks` → **BUILD SUCCESSFUL**、コンパイル警告 0 件 (debug / release AAR とも生成)
- テスト件数 (`kscollectionview/build/test-results/testDebugUnitTest/TEST-*.xml` の集計): **54 tests / 0 failures / 0 errors / 0 skipped** (Core 14 / Layout 23 / Interaction 17)。絞り込みなしの全件実行 + `--rerun-tasks` で「差分なし 0 件」ではないことを確認
- lint 3 種: comment-policy 0 件 (検査対象 92 ファイル) / local-path 0 件 / identity 0 件
- **変異注入によるテストの実効性確認** (リポジトリを触らない複製をセッションの作業ディレクトリに作り、実装側だけを 1 か所ずつ壊して全件実行):

| 注入した変異 (実装側) | 落ちたテスト | 結果 |
|---|---|---|
| `drawWithContent { drawContent(); … }` → `drawBehind` | `listSeparatorsAreDrawnOverOpaqueItemBackground` | 検出 (1 件のみ) |
| `index = leadingItemCount + itemIndex` → `index = itemIndex` | `scrollToItemAccountsForHeaderIndex` | 検出 |
| `innerStart` / `innerEnd` から `beforeContentPadding` / `afterContentPadding` を外す | `scrollPositionsUseViewportInsideContentPadding` | 検出 |
| `KsScrollController.detach` を no-op 化 | `detachedControllerIsNoOp` | 検出 |
| `WarnOnce` の本文を空にする (警告ログを出さない) | `duplicateIdKeepsLaterItemWhenNotDebug` / `duplicateTemplateRegistrationKeepsLastWhenNotDebug` / `unregisteredKeyShowsEmptyItemWhenNotDebug` / `sameWarningIsReportedOnlyOnce` | 検出 |
| 存在しない ID の `KsDiagnostics.warn` を外す | `scrollToMissingIdDoesNothing` | 検出 |
| 警告を `KsCollectionView` 本体で毎コンポジション直接ログする形へ戻す | `sameWarningIsReportedOnlyOnce` (実測 4 件 / 期待 1 件) | 検出 |
| `gridState` を layout ごとに作り直す (アンカー喪失) | `switchingLayoutKeepsDataAndAnchorItemVisible` | 検出 |
| `combinedClickable(indication = tapIndication)` → `indication = null` | `itemButtonPressDoesNotStartItemFeedback` | 検出 (差し替え口が実際に配線されていることの裏取り) |

- 保持構造の実測: 複製に一時テストを足し、10,000 件 (テンプレートキー 2 種) の正常系で `resolveItems(...).items` が**利用者が渡した配列そのもの (同一インスタンス)** であること、`templateKeys.size == 2` (種類数のみ)、`diagnostics` が空であることを確認
- 実装コードの改変は複製内だけで行い、リポジトリ側は未変更 (`android/` の作業ツリーに手を入れていない)

## 前回指摘の追跡

### review-002 (ホスト側)

| 指摘 | 状態 | 根拠 |
|---|---|---|
| 🟠 Major 不透明背景のテンプレートで区切り線が見えない | **解消** | `KsListSeparator.kt:38-49` が `drawWithContent { drawContent(); … }` に。`KsCollectionViewLayoutTest.kt:380` が白背景のテンプレートで 3 本すべての色をアサートし、`drawBehind` へ戻す変異で落ちる。design Decision 5 との差分は deviation.md に記録済み (合意済み差分として扱う) |
| 🟡 Minor 1 実装済み機能を「未実装」と述べる TODO | **解消** | `android/kscollectionview/src/` に `TODO` / `FIXME` / 「未実装」の出現 0 件。当該箇所 (`KsCollectionView.kt:232-233`) は現在の挙動を現在形で述べるコメントに置き換わっている |
| 🟡 Minor 2 ヘッダー index 補正と contentPadding 基準が未検証 | **解消** | `scrollToItemAccountsForHeaderIndex` (`KsCollectionViewInteractionTest.kt:242`) と `scrollPositionsUseViewportInsideContentPadding` (`:255`) を追加。後者は Start / Center / End の 3 位置を内側表示範囲で計算した期待値と突き合わせており、余白を外す変異で落ちる |
| 🟡 Minor 3 「接続解除後は no-op」が構造上必ず成立する | **解消** | `KsCollectionViewInteractionTest.kt:411-442` が、接続中に `item-10` へ届くことを先に確かめてから detach し、その位置が動かないことを見る形に変わった。`processedCommandCount` への依存が消え、detach 無効化の変異で落ちる |
| 🟡 Minor 4 警告ログ (ADR-0011 の「黙らず」) が未アサート | **解消** | 重複 ID・二重登録・未登録キーの release 系 3 経路に `ShadowLog` の warn アサーションを追加 (`KsCollectionViewCoreTest.kt:106,276,334`)、存在しない ID への `scrollTo` は debug 系で追加 (`KsCollectionViewInteractionTest.kt:237`)。spec は後者を「debug ビルドでは警告ログを出す」としており、実装 (`KsScrollCommandReceiver.kt:108`) とテストの debug 指定が spec と整合している |
| 🔵 ripple 描画・アニメーション中断の検証層が未定 | **部分解消** | ripple 側は `KsTapFeedback.indicationOverride` により押下 (`PressInteraction`) の有無まで検証層に載った。色が ripple へ届くことと「後の命令が先行アニメーションを中断する」ことは依然未検証で、tasks 6.5 (未着手) に残る |
| 🔵 再コンポジションのたびに配列全体を 3 回走査する | **解消** | `KsItemsPlan` は ID リストを持たず、走査に使う集合は `resolveItems` 内で捨てる。毎コンポジションで走るのは `plan.templateKeys.filterNot { … }` (種類数) だけ。`rememberUpdatedState(displayedItems)` は正常系で同一インスタンスが渡るため比較が O(1) に落ちる |
| 🔵 「データ反映後に実行」の根拠がコメントにない | **部分対応** | `KsCollectionView.kt:147-148` は効果 (差し替え後の配列で解決される) を述べるが、フレームクロックの awaiter 登録順に依存している理由は依然書かれていない (下記 Suggestion 4) |
| 🔵 `processedCommandCount` が snapshot state でも volatile でもない | **未対応** | `KsScrollCommandReceiver.kt:33` は素の `Int` のまま (下記 Suggestion 5) |

### second-opinion-code-002 の突き合わせ結果

| 項目 | 状態 | 根拠 |
|---|---|---|
| 子要素がタッチを処理しても親 ripple が開始され得る (採用・Minor 降格、テストで確定) | **解消** | `itemButtonPressDoesNotStartItemFeedback` (`KsCollectionViewInteractionTest.kt:193`) が、記録用 `Indication` を差し込んで子ボタン押下中・離した後の両方で親へ `PressInteraction` が流れないことを確認し、続けて項目背景の押下では流れることを見る (正の対照付き)。実装修正は不要と確定 |
| ライブラリ保持メモリが項目数に比例する (採用・Major) | **解消** | 正常系で `plan.items === items` を実測。重複がある縮退時だけ補正配列を作る (`KsItemsPlan.kt:70-72`)。スクロール先 ID は命令処理時に最新配列を検索する形 (`KsCollectionView.kt:156`) |
| 完了扱いの Scenario テストに実質未検証の条件が残る (確定・4 項目) | **解消** | 非先頭アンカー (`switchingLayoutKeepsDataAndAnchorItemVisible`)・release の警告ログ・子要素押下時の親 Press 不発・contentPadding + ヘッダーの 4 項目すべてが追加され、変異注入で個別に検出されることを確認 |
| Composition 中にログ副作用を実行している (採用・Minor) | **解消** | 検査結果を純粋な値 (`diagnostics`) にまとめ、release の警告は `KsDiagnostics.WarnOnce` の `LaunchedEffect(messages)` で出す形。`sameWarningIsReportedOnlyOnce` が「本体で毎回ログ」へ戻す変異を検出する |
| 任意の `Number` を保存可能と誤判定する (降格・対応不要) | **変更なし** | `KsItemsPlan.kt:93` は `is Number -> true` のまま。突き合わせ結果の結論どおりで妥当 |
| 実装済み機能を「未実装」とする TODO (確定) | **解消** | 上記 Minor 1 と同一 |

## 指摘事項

### [🔵 Suggestion] 内部の差し替え口 `KsTapFeedback.indicationOverride` は妥当。ただしプロセス全体の可変状態より CompositionLocal のほうが安全

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:42-45,190`

**判断**: **この差し替え口自体は妥当** — 採用してよい。理由は 3 点。(1) 「項目内の操作要素がタッチを処理した場合、アイテムのフィードバックは発火しない (SHALL NOT)」は Robolectric では ripple の塗りを観測できないため、他の手段では検証層に載らなかった。実際この口を配線から外す変異でテストが落ちることを確認しており、口が担保に効いている。(2) `internal` で公開 API に現れず、既存の `KsDiagnostics.debugOverride` と同じ作法に揃っている。(3) 本番の実行コストは毎コンポジションの null 判定 1 回だけ。

**残る弱み**: プロセス全体で 1 つの可変フィールドをコンポジション中に読んでいるため、(a) snapshot state ではなく、composition 開始後に差し替えても反映されない、(b) Robolectric は全テストクラスを同一 JVM で回すため、リセットを書き忘れたテストが他クラスへ漏れる。現在リセットは `KsCollectionViewInteractionTest.tearDown()` の 1 か所だけで、設定側もそのクラスだけなので今は問題ない。

**推奨修正 (任意)**: `internal val LocalKsTapIndication = staticCompositionLocalOf<Indication?> { null }` にして、テストは `CompositionLocalProvider` で包む。差し替えがコンポジションに閉じるため漏れが起きず、Compose 側の `LocalIndication` と同じ作法になる。今回の判定を左右する問題ではないので、次に触るときで構わない。

### [🔵 Suggestion] 同じファイルの中で `List` の修飾が不統一

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsItemsPlan.kt:18,36,78,79`

**問題点**: `KsItemsPlan` の宣言では `val items: List<Item>` と書き、`resolveItems` / `deduplicate` の引数と戻り値だけ `kotlin.collections.List<Item>` と完全修飾している。同一ファイル・同一パッケージで衝突する `List` は無く (クラス宣言側が修飾なしで通っていることが証拠)、読み手には「ここだけ何かを避けている」ように見える。

**推奨修正**: `kotlin.collections.` を外して `List<Item>` に揃える。

### [🔵 Suggestion] debug 停止の検査が 2 か所で二重に走る

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsItemsPlan.kt:68` と `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:122`

**問題点**: `resolveItems` が自分の `diagnostics` で `assertValid` を呼び、呼び出し元も `plan.diagnostics` を含めた一覧で再び `assertValid` を呼ぶ。`resolveItems` を直接呼ぶ単体テスト (`duplicateIdStopsInDebug` / `unsavableKeyStopsInDebug`) のために内側の呼び出しが要るのは分かるが、`resolveItems` の KDoc は「release の警告ログは呼び出し元が出す」としか書いておらず、debug 停止がどちらの責務なのかが読み取れない。挙動上の実害はない (どちらも同じ条件で停止する)。

**推奨修正**: `resolveItems` の KDoc に「debug 停止はこの関数でも行う (単体で呼ばれる経路のため)。呼び出し元はテンプレート側の検査と併せてもう一度まとめて停止させる」ことを明記するか、内側の呼び出しをやめてテスト側が `plan.diagnostics` を検査する形にする。

### [🔵 Suggestion] 1 フレーム待ちが成立する理由が依然コメントにない (前回からの持ち越し)

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:147-149`

**問題点**: `withFrameNanos { }` で 1 フレーム待つ設計は「同じフレームの中で Recomposer の frame callback が先に走り、`rememberUpdatedState` 経由の最新の配列が読める」ことに依存している。コメントは結果 (差し替え後の配列で解決される) だけを述べており、その順序が成り立つ理由は書かれていない。順序保証は core/ADR-0007 の中核なので根拠を残しておきたい。

**推奨修正**: 実装側コメントに「Recomposer が同じフレームクロックへ先に登録された awaiter として先に走るため、この時点の `latestItems` は差し替え後の配列である」ことを明記する。あるいは `snapshotFlow` で配列の反映そのものを待って順序への依存を外す。

### [🔵 Suggestion] `processedCommandCount` が snapshot state でも volatile でもない (前回からの持ち越し)

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsScrollCommandReceiver.kt:33`

**問題点**: 隣の `enqueuedCount` は `mutableIntStateOf` なのに `processedCommandCount` は素の `Int` で、メインスレッドから書かれた値をテストスレッドが読む。Robolectric は単一スレッドなので現状は問題ないが、同じ待ち方を androidTest (instrumentation スレッドから読む) へ移すと可視性の保証がなく間欠的に待ち足りなくなりうる。

**推奨修正**: `enqueuedCount` と同じく `mutableIntStateOf` にする。

## アクションプラン

必須の修正はない。以下は次に該当箇所へ触れるときで構わない。

1. (任意) `KsTapFeedback` を CompositionLocal 化して差し替えをコンポジションに閉じる
2. (任意) `KsItemsPlan.kt` の `List` 修飾を統一し、`resolveItems` の debug 停止の責務を KDoc に明記する
3. (任意) 1 フレーム待ちの根拠コメント、`processedCommandCount` の snapshot state 化
4. (グループ 6.5 で) ripple の色到達とアニメーション中断の検証層を対応表に明示する

## 確認して問題がなかった観点

- 足場アーティファクト (proposal / design / specs / brief) は未変更。`tasks.md` の差分はチェックボックスの反映のみ (本文の書き換えは 1 行もない)。tasks 4.4 は `drawBehind` と書かれたままだが、これは凍結された足場であり、実装との差分は deviation.md 側に記録されている — 正しい扱い
- deviation.md の記録は design Decision 5 との差分 1 件のみで、spec の Requirement (位置・本数・色・opt-out) の不変を明記している。合意済み差分として扱い、違反としては数えていない。`[付随修正]` の同梱はなく、範囲外の変更も見当たらない
- 実装済みチェックに虚偽なし。グループ 6 の各項目に対応するテストが実在し、変異注入で契約を守っていることまで確認した。6.5 と 7〜9 は未チェックのまま
- 区切り線の描画順: 項目 content の前面に出る (白背景のテンプレートで実測)。ripple も `combinedClickable` が modifier 連鎖の内側にあるため区切り線の下に入り、iOS (`KsHostingCell` の前面配置) と同じ見え方になる
- 未登録キー・重複 ID・二重登録の release 縮退がすべて維持されている: 未登録キーは最小高の空項目で件数が保たれ、重複 ID は後に現れた要素の位置で後勝ち (`KsItemsPlan.kt:76-88`)、二重登録は `LinkedHashMap.put` の後勝ち。debug 側の停止も 4 経路すべてテスト済み
- 安定 ID と再利用種別の解決が `items(...)` の中に移っても挙動が変わっていない: `key` は表示する要素の分だけその場で解決され、`contentType` はテンプレートキーをそのまま渡す。テンプレートキーの変化で描画が切り替わること (`templateKeyChangeRedrawsWithNewTemplate`)、同一 ID・同一キーで `remember` が保たれること (`contentUpdateKeepsRememberedStateOfItem`) はいずれも緑
- 警告の 1 回化は `LaunchedEffect(messages)` によるもので、`messages` は毎コンポジション新しい `List` だが内容が同じ限りキーとして等価になるため再起動しない。破棄されたコンポジションからログだけが残ることもない
- スクロール命令の順序保証は維持: 消費側 `LaunchedEffect(receiver)` はコンポジションの生存期間に 1 本だけで、配列やヘッダーの有無の変化で作り直されない。中断された命令も `finally` で処理済みに数えられ、待機側が取り残されない
- ID 解決が事前計算から「命令処理時に最新配列を線形探索」へ変わったことで、命令 1 件あたり利用者の `key` ラムダが件数分呼ばれる。命令はユーザー操作の頻度でしか発行されないため許容範囲で、保持構造を O(1) にする対価として妥当
- テストが「収束を待つアサーション」の形を保っている: `awaitCommands` は実時間 deadline・実行機会の譲り・超過時の実測値付き失敗の 3 条件を満たす。新規テストの `mainClock.advanceTimeBy` / `advanceTimeByFrame` は仮想クロックの前進であり、CPU 競合で結果が変わる固定時間待機ではない
- コメント規約: 新規・改訂コメントに作業文書のパス・レビュー通番・仮称・デルタスペック構文キーワードの混入なし。ADR 参照は `internal` 宣言のコメントにのみ現れ `<domain>/ADR-NNNN` 形式。公開 doc コメントに内部用語なし。履歴記述 (「〜から変更」等) もなし
- 公開 API の形は前回から不変 (`KsCollectionView` の引数一式・`KsLayout` / `KsColumns` / `KsScrollController` / `KsScrollPosition`)。今回の修正はすべて `internal` 以下と描画順に閉じており、`dsl-samples.md` の Kotlin 側との一致は維持されている
- ファイル名 `KsResolvedItems.kt` → `KsItemsPlan.kt` の改名は内部型の改名で、公開 API・配布座標・namespace に影響しない。旧名の残骸なし
