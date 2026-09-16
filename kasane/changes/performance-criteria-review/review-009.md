# レビュー結果: performance-criteria-review (009 回目)

**日付**: 2026-09-16
**判定**: CHANGES_REQUESTED

## サマリー

グループ 7 (7.1〜7.7、7.8 は取り下げ) とグループ 8 (8.1〜8.4) を、グループ 6 の試作の上に積んだ形で評価した。塊の境界を見た目に出さない 4 点 (行間・内側余白・ヘッダー / フッター・上端の区切り線) はいずれも実経路の snapshot とレイアウト属性で固定されており、design Decision 11 の内容がそのままテストに写っている。組み直しの契機は review-008 の申し送りどおり「塊の件数の変化 (未解決からの確定を含む)」で定義され、`viewDidLayoutSubviews` からも apply 完了からも同じ判定を通る。挿入 / 削除 / 並べ替えの可視セル存続、ID と末尾へのスクロール命令、空配列のヘッダー / フッターも塊をまたぐ形で固定されている。7.8 の取り下げと A/B の結果は deviation に、教訓は lessons inbox に残っており、基準を緩めて通す形にはなっていない。計測の足場 (8 系) も、往復ごとの記録・未判定の失敗化・Debug の計数帯・実機の起動引数の順序まで spec と handbook の双方に届いている。

一方で 2 件を差し戻す。1 件目は **`update(configuration:)` 由来で塊の件数が変わる経路 (list ⇄ grid、列数の指定の変更) に、組み直し用の緩和 (アニメーションの抑止・復元の遅延) が一切掛からず、テストも無い**こと。ios/ADR-0009 と design Decision 12 はこの経路を明示的に組み直しの対象に挙げており、しかも「即時復元では表示範囲がずれる」ことは実装者自身が deviation に実測として書いている。2 件目は**間欠失敗しているエンジンテスト**で、これは緑を前提にした完了報告 (9 系への進行) の土台を崩す。

テストはレビュアー側でも独立に実行した (ホストの 2 機種とは別の機種・OS を選び、lessons `do-not-run-review-and-verify-on-same-simulator` に従って verify 用の機種とも重ねていない)。

| 実行 | 環境 | 結果 |
|---|---|---|
| 全件 (絞り込みなし、Debug) | iPhone 17 Pro Max Simulator / iOS 26.4.1 | **198 tests / 0 failures** |
| 全件 × 6 回 (絞り込みなし、Debug) | iPhone 16e Simulator / iOS 26.1 | 198 tests / 0 failures (6 回とも) |
| `KsCollectionEngineTests` × 5 回 (CPU 6 本を飽和させた状態) | iPhone 17 Pro Simulator / iOS 26.1 | 62 tests / 0 failures (5 回とも) |
| `KsCollectionEngineTests` (3 機種同時起動) | iPad Pro 11-inch (M5) Simulator / iOS 26.1、iPhone Air Simulator / iOS 26.1 | 62 tests / 0 failures |

**合計 13 走行で、報告されている間欠失敗は再現しなかった** (同時起動のうち iPhone 17 Pro Max / 26.1 の 1 走行だけは Simulator の準備段階のエラーで走らず、テストの失敗ではない)。この「負荷と並列を掛けても出ない」ことは、後述の見立て (件数に比例する退行ではなく、過渡のピークを標本化していること) と整合する。

lint は comment-policy (禁止 0 件 / 要確認 14 件はすべて本 diff 外の既存分)・local-path・identity とも違反 0。doc-structure lint に本 diff の文書 (`kasane/handbook/ios/performance-verification.md`) の指摘は無い。

## 照合した規約

| 文書 | 適用のきっかけ | 判定 |
|---|---|---|
| cross/comment-policy.md | **常時** (全ソースコード) | 適用。新規・改訂コメントに作業文書パス・通番・仮称・履歴記述・デルタスペック構文キーワードの混入なし。`KsSectionID` / `KsSectionChunking` / `KsItemOffsetLookup` の内部説明は非公開側のコメントに置かれ、`KsItemOffsetLookup` の公開 doc コメントは契約だけになった (review-008 Minor (c) の解消)。機械検査の要確認 14 件はすべて既存分 |
| cross/test-execution.md | テストを実行するとき・テスト結果を報告するとき | **一部不適合**。絞り込みなしの全件実行と件数の併記は満たしている。ただし「収束を待つアサーション」に反する形が 2 か所ある (Major 2・Minor 3)。計測スキームと通常スキームの分離は維持され、計測スキームは `SkippedTests` で `LargeDataCountUITests` / `InteractiveControlUITests` を外している |
| cross/scroll-performance-gate.md | 性能の完了を判定するとき・手動フリック計測を行うとき・性能の証跡を書くとき | **一部不適合**。6.3 の証跡は 6 節の構成・体感を数値の前に聞き取る順序・参考スケールの扱い・比較不能の明示・限界の列挙まで規約どおりだが、「体感と数値が食い違ったときは計測器を接続せずに同じ操作列を 1 回行って対照とする」を踏んでいない (Minor 4) |
| ios/performance-verification.md | iOS エンジンの描画・再利用・レイアウト経路に触れるとき・大量件数を扱う変更の完了を判定するとき | 適用。8.4 で実機の起動引数の位置と合図前の画面確認が手順に入り、計測ドライバの構成の記述も spec と揃った。6.3 の走行は追記後の手順どおり (`--` の後ろ、件数表示の目視確認、接続成立の確認後に合図) に行われている |
| cross/sample-parity.md | `samples/` を触るとき | 適用。`samples/ios` の変更は通過記録の数え方・計測帯の読み取り・ビルド設定・UI テストに限られ、デモ画面・文言・デモデータ・DSL 引数は不変。Android に追随の要る差分は生じていない |
| cross/public-identifiers.md | 公開識別子・配布座標を決めるとき | 適用。新設の型名は `Ks` 接頭辞の PascalCase。SwiftPM の package / product 構成は不変。`@_spi(KsMeasurement)` の表面は `KsItemOffsetLookup.itemOffset(of:in:)` 1 本に絞られた |
| cross/runtime-behavior-verification.md | 実行時挙動の不具合を調査するとき・不具合修正の完了を判定するとき | 適用。塊の境界の見た目はレイアウト属性のテストで固定されたが、**遷移の一瞬にだけ現れる形** (Minor 2) は静止したテストでは捕まらない範囲として残る |
| cross/local-development-setup.md | 環境構築・Sample の起動 | 該当なし |

昇格済みルール (`kasane/lessons/<scope>.md`) は未生成のため `kasane/lessons/inbox/` を参照した。`check-tests-exercise-production-path-before-accepting-green` を新規テストの実効性の確認に (Minor 1 はこれに該当)、`review-inclusive-requirement-on-all-paths` を「塊の件数が変わる経路」の洗い出しに (Major 1 はこれに該当)、`tests-created-in-change-are-in-scope-for-fixes` を間欠失敗の扱いに (Major 2)、`reviewer-reproduces-evidence-numbers-by-probe` を独立実行と再現試行に、`report-device-and-os-with-layout-numeric-tests` を実行環境の併記に、`capture-transient-layout-glitch-with-offset-logs` と `verify-interactive-collection-layout-transitions` を Minor 2 の観測方法に適用した。

## review-008 の申し送り 3 件の処理状況

| # | 申し送り | 状態 | 根拠 |
|---|---|---|---|
| 🟡 Minor | `KsItemOffsetLookup` の SPI 表面を絞る (b)・`deviation.md` へ記録する (a)・公開 doc コメントを契約だけにする (c) | **解消 (3 点とも)** | (b) `ios/Sources/KsCollectionView/KsItemOffsetLookup.swift:20-24` の `@_spi` は `itemOffset(of:in:)` 1 本だけになり、`indexPath(forItemOffset:)` (`:42`) と `totalItemCount(in:)` (`:59`) は internal へ。`ios/Tests/KsCollectionViewTests/KsItemOffsetSupport.swift:4` が `@_spi(KsMeasurement) @testable import` で受けている。(a) `deviation.md` に「`@_spi(KsMeasurement)` で Release にも載せる。表面は Sample が使う 1 本に限定し、残りは internal」を記録済み。(c) 公開 doc コメント (`:10-13`) は「先頭を 0 とする通し番号で数えるための入口」「範囲外は nil」だけになり、内部構造の説明は非公開側 (`:4-8`) へ移った |
| 🔵 Suggestion 1 | 塊だけが変わる再適用を `animatingDifferences: false` で行う | **一部解消** | `KsCollectionViewController.swift:573` が `itemsAreEqual && chunkSizeChanged` のときだけアニメーションを落とす。`rebuildChunksIfNeeded` (`:611`) も `animatingDifferences: false` で呼ぶ。ただし **`update(configuration:)` 由来で塊の件数が変わる経路は条件から外れている** (Major 1) |
| 🔵 Suggestion 2 | 組み直しの契機を「`currentChunkSize()` の値の変化 (未解決からの確定を含む)」で定義する | **解消** | `scheduleChunkRebuildIfNeeded` (`:598-599`) が `currentChunkSize() != appliedChunkSize` だけを見て、`viewDidLayoutSubviews` (`:173`) と apply 完了 (`:593`) の両方から呼ばれる。`KsCollectionEngineTests.swift:845` が「更新を 1 度も届けずに、列数の確定だけで 500 → 501 へ組み直る」ことを固定しており、review-008 が懸念した「adaptive で表示して一度も更新が届かない画面が永続的に不完全な行を持つ」形は塞がれた。review-007 Suggestion 2 (解決列数の記録がレイアウト解決の副作用であること) は `:660` のまま**未解消 (意図的)** で、7.3 の設計判断として受け入れられている |

## 指摘事項

### [🟠 Major] `update(configuration:)` 由来で塊の件数が変わる経路に、組み直しの緩和が掛からずテストも無い

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:458`・`:573`・`:611-621`、`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:675-740` (既存のアンカーテストはすべて 300 件 = 1 塊)

**問題点**:
塊の件数が変わる更新には 2 つの入口がある。

1. レイアウトが解けて列数が変わった経路 → `rebuildChunksIfNeeded` (`:611`)。ここでは `animatingDifferences: false` を渡し、`restoresAnchorAfterApply = true` (`:618`) で復元を apply 後の実行機会まで遅らせる。
2. 利用者が layout 値を差し替えた経路 → `update(configuration:)` → `apply(animatingDifferences: true, reconfiguringAllItems: layoutKindChanged)`。

2 の側には緩和が **1 つも掛からない**。`KsCollectionLayout.Kind` は `.grid(KsGridColumns)` が列数を associated value に持つため、`.list` ⇄ `.grid(columns:)` だけでなく `.fixed(2)` → `.fixed(3)` のような列数の指定の変更でも `layoutKindChanged` が真になり、`reconfiguringAllItems: true` が渡る。すると `:458` の `itemsAreEqual` は必ず偽になり、

- `:573` の `animates = animatingDifferences && !(itemsAreEqual && chunkSizeChanged)` は真に落ちる → 塊の件数が 500 → 501 に変わると、先頭の 1 塊を除くほぼ全項目がセクションをまたいで移る差分が**アニメーション付きで**適用される (10,000 件なら 1 万件規模)。塊分割の前は同じ操作が「1 セクション内の reconfigure」で済んでいたので、これは本 diff が持ち込んだ退行である
- 復元は `:590` の即時経路を通る。ところが `deviation.md` は「塊の組み直しは…アンカーの復元は apply 後の実行機会まで遅らせる (即時復元では表示範囲がずれることを iPad で実測)」と書いている。**同じ「ほぼ全項目がセクションをまたぐ再適用」でありながら、片方だけ実測済みの不具合形のまま残っている**

ios/ADR-0009 は「組み直すのは列数の変化**または layout 値の変更**で現在の塊の件数が新しい列数で割り切れなくなったときだけ」と明記し、design Decision 12 も「layout 値の変更 (list ⇄ grid、列数の指定の変更) で塊の件数が変わるときも、`update(configuration:)` の既存のアンカー捕捉に乗せて同じ経路で組み直す」と書いている。実装は「同じ経路」に乗せたが、その経路に後から足した緩和を分岐の片側にしか適用していない。

テストも無い。既存のアンカー保持テスト (`:675`「レイアウト切替と同時の先頭側への大量挿入でもアンカーを保つ」、`:695`、`:717`) と行間変更のテストはいずれも 300 件で、1 塊に収まるため塊の件数の変化を一度も通らない。新規テストの側も、塊の件数が変わる更新を通すのは `:865`「塊を組み直す同値配列の更新でも可視セルを作り直す」だけで、これは同値配列 (`itemsAreEqual == true`) の側であり、この分岐は検査されていない。

**推奨修正**:
- `:573` の抑止条件を `itemsAreEqual && chunkSizeChanged` から `chunkSizeChanged` へ広げる (塊の件数の変化そのものは「動かして見せる変化」ではない。項目の増減が同時に起きる場合にアニメーションが要るかは、増減分だけの差分に対して別途判断する)
- 復元の遅延 (`restoresAnchorAfterApply`) も `chunkSizeChanged` を契機に立てる。`rebuildChunksIfNeeded` だけが立てる形をやめる
- 500 件を超える配列で `.list` → `.grid(columns: .fixed(3))` (塊 500 → 501) と `.fixed(2)` → `.fixed(3)` を行い、表示範囲の先頭の項目が保たれることをエンジンテストで固定する。`testadaptiveで列数が変わると塊を組み直して先頭の項目を保つ` (`:1081`) と同じ形で書ける

### [🟠 Major] `test2000件を全件走査しても同時生存セルを可視範囲と再利用プールに留める` が間欠失敗し、上限の導き方が塊分割後の実測で裏付けられていない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:1336-1359` (とくに `:1337` のコメントと `:1342` の上限、`:1346-1349` の標本化)

**問題点**:
ホストの報告では全件実行 1 回で実測の最大 167 件が上限 156 件 (可視 39 × 4) を超えて失敗し、再実行では成功している。レビュアー側でも 13 走行 (負荷 6 本の飽和、3 機種同時起動を含む) を試したが再現しなかった。

このテストが不安定な形になっている理由は 2 つある。

1. **収束を待たずに過渡のピークを標本化している。** `advanceRoundTrip` の `onStep` は 1 段階送るたびにその瞬間の `controller.liveCellCount` を読み、全段階の最大値を上限と比べる (`:1346-1349`)。セルが再利用プールへ戻り、余剰が破棄されるのはレイアウトパスと解放の機会をまたいでからなので、読んだ値は「落ち着いた同時生存数」ではなく「送りの途中の生存数」である。すぐ隣の `test配列の置換で同時生存セルが可視範囲の規模に戻る` (`:1613`) は `waitUntil(...) { $0 < liveCellLimit }` で収束を待ってからアサートしており、同じ計数に対して 2 つの流儀が同居している。cross/test-execution.md「収束を待つアサーション」は、この差がまさに「並列実行や CI の混雑時に間欠的に落ちる flaky として表面化する」と書いている
2. **上限の裏付けが塊分割前のままである。** `:1337` のコメントは「可視 39 件に対して同時生存の実測最大が 115 件 (可視の約 3 倍)」を根拠に 4 倍を置いている。7 系で 2,000 件の list は 1 セクションから 4 セクション (塊 500 件) に変わり、セクションごとに内側余白と行間の切り替えが入った。**上限の根拠になった実測値が、塊分割後に採り直されていない。** 実際の観測 (167 = 可視の約 4.28 倍) はコメントの 115 から大きく離れており、コメントが現状を説明していない

**見立て** (間欠失敗の原因): 「塊分割によって同時生存数が系統的に増えた」退行ではなく、**もともと余裕の乏しかった上限 (115 → 156、余裕 36%) に対して、塊分割で送りの途中の過渡のピークが押し上げられ、標本化の瞬間しだいで上限を越えるようになった**もの、と読む。根拠は次のとおり。

- 系統的な退行なら件数に比例して失敗が安定するはずだが、13 走行・3 機種・CPU 飽和・並列のいずれでも 1 度も出ていない。失敗は特定の送り段階の一瞬にしか現れていない
- 塊分割は再利用識別子を増やさないので、再利用プールそのものの規模は変えない。一方で、可視範囲が塊の境界をまたぐ段階では 2 つのセクションが同時に配置を解かれ、その解き直しの途中では新しいセルが作られてから古いセルがプールへ戻るため、境界をまたぐ段階だけ過渡のピークが高くなる。刻みは可視範囲の半分なので、2,000 件・塊 500 件では往復で境界を 6 回またぐ
- 上限は「件数に比例しないこと」を守るための値であり、破綻時は 2,000 件規模になる。4.28 倍と 4 倍の差は、この守りたい性質とは無関係の水準にある

**推奨修正** (数値を先に動かさないこと):
- まず `onStep` の標本化を収束後に揃える。段階ごとに `layoutIfNeeded` と実行機会の譲りを挟んでから読み、`:1613` と同じ流儀にする。これで直れば上限は触らない
- それでも越えるなら、**塊分割後の実測の分布を採り直してから**上限を導き直し、`:1337` のコメントの 115 を現在の値に書き換える (複数走行・2 機種以上の最大値を根拠にする)。根拠の数値を残さないまま 4 倍を 5 倍にするのは、基準を結果に合わせて動かすことになる
- 境界をまたぐ段階でピークが立つ見立てを確かめるなら、段階ごとの生存数と、その段階で可視範囲が塊の境界をまたいだかを 1 回だけログに出して分布を見るのが最短 (lessons `reviewer-reproduces-evidence-numbers-by-probe` の形)

このテストは本 change が作ったものではないが、7 系がその前提 (セクション構造) を変えており、6.2 で補助関数 (`isVisible` / `advanceUntilVisible`) にも手が入っている。lessons `tests-created-in-change-are-in-scope-for-fixes` の趣旨どおり本 change の責務として扱う。

### [🟡 Minor] 倍率のテストが倍率の変化を 1 度も通らない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsEstimatedHeightTests.swift:200-206`

**問題点**:
`test倍率が変わっても新しい倍率の実測が入るまでは前の推定値を使う` は、倍率 2 で 120 を 2 回記録して `value == 120` を確かめているだけで、**倍率を変える操作が本文に無い**。名前とコメントが主張している「遅延破棄」(倍率が変わっても、新しい倍率の実測が届くまでは前の推定値を返す) は、この本文では一度も発火しない。`KsEstimatedHeight` は `record(height:width:scale:)` でしか倍率の変化を知らないため、この書き方では直前のテスト (最頻値が 120 になること) と同じことしか検査していない。実装から遅延破棄を取り除いても緑のまま通る。

**推奨修正**:
幅の側の同名テスト (`test幅が変わっても新しい幅の実測が入るまでは前の推定値を使う` 相当) と同じ形にし、「倍率 2 で標本を貯める → 倍率 3 の実測を渡す**直前**に `value` を読む」ことで前の推定値が返ることを確かめる。倍率の変化を通す道が `record` しか無いのであれば、このテストは検査対象を持たないので削除し、`test倍率が変わると前の倍率の実測値を捨てる` (`:189`) に一本化する。

### [🟡 Minor] adaptive の組み直しが 1 実行機会ぶん遅れ、その間だけ塊の境界に不完全な行が出る

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:598-607`・`:170-173`

**問題点**:
`scheduleChunkRebuildIfNeeded` は `DispatchQueue.main.async` で組み直しを次の実行機会へ送る。したがって adaptive (および最小公倍数が縮退した向き別列数) で列数が変わったとき、**新しい列数で解かれたレイアウトが、古い塊の件数のまま少なくとも 1 フレーム描画される**。例えば塊 501 件のまま 2 列で解かれると、各塊の末尾が 1 件だけの行になり、塊の境界に列数に満たない行が現れる。spec の Requirement「配列の内部分割 (iOS)」は「塊の境界に列数に満たない行を作ってはならない (SHALL NOT)」と書いており、契約の字面はこの 1 フレームを許していない。

レイアウトの途中で snapshot を適用しないための遅延自体は妥当で、設計 (Decision 12) もこの形を選んでいる。問題は**この一瞬が見えるかどうかが未確認**なことで、いまのテストは組み直し後の状態だけを見ているため、静止したアサーションでは原理的に捕まらない。

**推奨修正**:
- 9 系の実機計測の機会に、iPad の Split View 幅変更または回転 (adaptive の画面) をオーナーに 1 度操作してもらい、境界の行が一瞬崩れて見えるかを目視で確かめる。静止画やテストの緑を「出ていない」の根拠にしない
- 見えるなら、列数の確定を `viewDidLayoutSubviews` の後ではなく「解決した列数が変わったレイアウトパスの完了直後」に寄せる、あるいは組み直しが決まるまで新しい列数での描画を 1 パス止める、のいずれかを検討する
- 見えないなら、その観測を deviation に「1 実行機会の遅延は目視で現れない」として残し、spec 本文の SHALL NOT との関係を蒸留時に書き分ける

### [🟡 Minor] Debug の計数帯の UI テストが、操作の反映を待たずに表示を読んでいる

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/LargeDataCountUITests.swift:53-54`・`:57-62`・`:67-68`

**問題点**:
`read.tap()` / `reset.tap()` の直後に `tally.label` を同期的に読んでいる。`tap()` はイベントの配送までしか保証せず、SwiftUI の再描画とアクセシビリティ情報の更新はその後に起きるため、読んだ label が操作前の値である可能性が残る。とくに `:58-62` は「数え直した直後に 0 に戻っていること」を、待ちを挟まずに 1 回読んで判定している。同じターゲットには `UITestSupport.swift:5` の `waitForLabel(_:timeout:)` があり、他のテスト (`PerformanceDriverUITests`) はこれを使っている。cross/test-execution.md「収束を待つアサーション」に照らすと、この形は「手元で通ることが、この形で書けている根拠にならない」側に当たる。

**推奨修正**:
`reset.tap()` の後は `XCTAssertTrue(tally.waitForLabel("自己サイズ: 0 / 不一致: 0 (0.000)", timeout: ...))` のように条件ベースで待つ。`read.tap()` の後は「label が tap 前の値から変わること」または「`自己サイズ: ` の数値が 0 より大きくなること」を deadline 付きで待ってから値を取り出す。

### [🟡 Minor] 6.3 の証跡で体感と数値が食い違っているのに、規約が要求する非接続の対照を行っていない

**該当箇所**: `evidence/manual-largeData-ios-2026-09-16-prototype.md` の「数値との突き合わせ」と「限界」、および「判定 (design Decision 13 の段階 1)」の表

**問題点**:
cross/scroll-performance-gate.md の「判定の 3 状態と再試行」は、**「オーナーが体感に迷った、または体感と数値が食い違ったときは、計測器を接続せずに同じ操作列を 1 回行って対照とする」**と定めている。証跡は自ら「体感と数値が食い違う点を 2 つそのまま残す」と書き (10,000 件が体感合格なのに High の hitch 56 件・特定区間に 495 ms/s が集中)、限界にも「再試行 (計測器なしの対照) は行っていない」と明記したうえで、総合判定を合格としている。規約が発火する条件を満たしながら、その手順を踏まずに合格側へ進んでいる。

もう 1 点、未判定条件 a (2,000 件が初回区間で末尾に達したか) を「**数値の回収後**のオーナーへの確認」で外している。手順としては「到達範囲を証跡に残す」(証跡に残す項目) が先にあり、記憶での事後確認はその代わりにはならない。証跡自身も「アプリ側に可視範囲の先頭項目を出す印を足すか、記録後に画面の到達位置をオーナーに確認して控える必要がある」と書いている。

段階 1 の主判定 (初回区間の solver 占有率 0.90 倍) は数値として頑健で、照合シンボルを変えても結論が動かないことまで確かめてある。したがって**段階 2 へ進んだ判断そのものを覆すべきとは考えない**。ただし同じ形のまま 9.1 (完了判定) へ行くと、完了判定が規約の再試行条件を踏まないまま下りることになる。

**推奨修正**:
- 9.1 では、体感と数値が食い違ったらその場で非接続の対照を 1 回行う。行わない場合は「なぜ食い違いに当たらないか」(例: 食い違いは数値どうしの並びの逆転であって体感と数値の食い違いではない) を証跡に書いて、規約の条件に照らして判断したことを残す
- 到達範囲は記録中に確定できる形にする。アプリ側に可視範囲の先頭項目を出す印を足すのが最も確実で、9.1 の未判定条件を毎回オーナーの記憶に頼らずに外せる
- 6.3 の証跡には、対照を行わなかったことを「限界」ではなく判定の節に移し、規約の再試行条件との関係を 1 行で書き足す

## 指摘ではない所見

### [🔵 Suggestion] 塊の所属が変わる可視セルの存在をテストが固定していない

`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:2233-2278` の `assertVisibleCellsSurviveWhereChunkUnchanged` は「所属が変わらない可視セルを 1 つも確かめられていない」場合には失敗するが (`:2271`)、**所属が変わった可視セルが 0 件でも通る**。Scenario「先頭への挿入で塊の所属が変わっても位置が飛ばない」が前提にしているのは「境界の項目が可視範囲に入っていること」なので、送り先 (`boundary - 4`) が将来ずれたときに前提ごと空振りする。`movedCount > 0` を 1 行足せば前提が固定できる (deviation の観測では挿入・削除とも 1 件)。

### [🔵 Suggestion] 塊の境界の幾何を frame で 1 度固定しておく

Scenario「塊の境界に不完全な行が無い」の THEN は「境界の直前の行は 2 列とも埋まり、境界の直後の項目は行頭に置かれる」と幾何で書かれているが、テスト (`:820` の `assertChunkStructure`、`:1049` の回転) は塊の件数が列数で割り切れることだけを見ている。割り切れることは、UIKit が各セクションの先頭項目を必ず行頭に置く前提の下で十分条件になる — その前提こそが塊分割の成立条件なので、2 列のグリッドで境界の前後 3 項目の `minX` を 1 度だけ確かめておくと、前提ごと守れる。`columnCount(in:)` (`:2773`) が既に `minX` から列を読んでいるので道具は揃っている。

### [🔵 Suggestion] `chunkRebuildCount` だけが Debug 構成の外にある

`ios/Sources/KsCollectionView/KsCollectionViewController.swift:61` の `chunkRebuildCount` は観測専用の計数だが、同じ目的の `liveCellCount` / `cellProviderCallCount` (`:66-73`) が `#if DEBUG` に閉じているのに対し Release にも載る。`processedCommandCount` という前例はあるので違反ではないが、「計測のための仕組みは Release に載せない」という本 change 自身の方針 (design Decision 1) との関係が読めない。`#if DEBUG` へ寄せるか、寄せない理由をコメントに 1 行置くとよい。

### その他 (確認した観点、指摘なし)

- **spec の Scenario とテストの対応**: 「塊の境界で行間と区切り線が変わらない」(`:914`・`:1011`)、「内側余白は配列全体の上下にだけ付く」(`:914`)、「ヘッダーとフッターは 1 つずつ」(`:955`、空配列まで含む)、「向き別列数で列数が変わっても不完全な行が無い」(`:1049`)、「adaptive で列数が変わると塊を組み直して位置を保つ」(`:1081`)、「先頭への挿入 / 削除」(`:1135`・`:1192`)、「塊をまたぐ並べ替え」(`:1246`)、「スクロール命令は塊をまたいで解決する」(`:1288`)、「倍率が変わると前の実測を捨てる」(`KsEstimatedHeightTests.swift:189`)、「Debug 構成では計数を読める」(`LargeDataCountUITests.swift:37`)、「メモリの自動往復」「定常化しなければ未判定」(`PerformanceDriverUITests.swift:148`・`:158`) がそれぞれ対応している。テストはいずれも controller の実経路 (`showInWindow` → 実 snapshot → レイアウト属性) を通っており、合成した値を突き合わせるだけの形は無い
- **tasks.md の完了印**: 7.1〜7.7・8.1〜8.4 の印はいずれも実体を伴う。7.8 は未チェックのまま取り下げの注記が付き、deviation に理由と A/B の実測 (iPad @2x で group の推定が無効、iPhone @3x で分母が 1.6 倍振れる) が残っている。基準を緩めて通した形跡は無く、`test行高が一様な配列で初回表示の合計高さの見積もりを損ねない` (`:1490`) の基準値 (±5% / 0.1% 超 3 回) も据え置かれている
- **足場アーティファクトの書き換え**: `specs/` と `design.md` に本サイクルの変更は無く、読み替えはすべて `deviation.md` 側に積まれている
- **公開 API への漏れ**: `KsSectionID` / `KsSectionChunking` / `chunkRebuildCount` はいずれも internal。塊の件数・塊の順番は `@_spi` にも出ていない
- **付随修正の同梱**: `--verify-performance-auto` の終了コードを `EXIT_FAILURE` にした変更は、Requirement「iOS の計測ドライバの構成」の「成功として終わってはならない」に直接該当し、8.3 の範囲に収まっている。deviation に記録済み
- **混在 2 列の合計高さ**: 7.8 の取り下げにより自動テストでの担保は無くなり、判定は 9 系の実機計測 (体感と solver 占有率) に移った。オーナー判断として合意済みなので指摘にはしないが、**9 系が未了のまま性能面の完了を報告しないこと**が前提になる (cross/scroll-performance-gate.md の「未判定のままでは完了と報告しない」)
- **`KsItemOffsetLookup.itemOffset(of:in:)` の計算量**: 先行セクションの件数を毎回積む O(セクション数)。10,000 件でも 20 回なので 9.3 の走査に影響する大きさではない (review-008 の所見のまま)

## アクションプラン

1. **Major 1**: アニメーションの抑止と復元の遅延の契機を `chunkSizeChanged` へ広げ、500 件超の配列で `.list` → `.grid(columns: .fixed(3))` / `.fixed(2)` → `.fixed(3)` の位置維持をエンジンテストで固定する
2. **Major 2**: 同時生存セルのテストの標本化を収束後に揃える。それでも越えるなら、塊分割後の実測の分布を 2 機種以上で採り直してから上限とコメントの根拠値を導き直す (先に数値を動かさない)
3. **Minor 1・3**: 倍率の遅延破棄のテストを実効のある形にする (または削除して 1 本に寄せる)。計数帯の UI テストの読み取りを `waitForLabel` に載せる
4. **Minor 4**: 9.1 で非接続の対照の要否をその場で判断し、判断の結果を証跡に残す。到達範囲を記録中に確定できる印をアプリ側に足すかを決める。6.3 の証跡には対照を行わなかったことと規約の条件との関係を判定の節に書き足す
5. **Minor 2**: 9 系の実機計測のついでに、adaptive の幅変更 / 回転の一瞬を目視で確かめ、結果を deviation に残す
6. **Suggestion 3 件**: 所属が変わる可視セルの件数の固定、境界の `minX` の固定、`chunkRebuildCount` の可視性 — いずれも 9 系と並行で足せる
