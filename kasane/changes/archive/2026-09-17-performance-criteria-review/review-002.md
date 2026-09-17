# レビュー結果: performance-criteria-review (002 回目)

**日付**: 2026-09-15
**判定**: CHANGES_REQUESTED

## サマリー

前回 (`review-001.md` と `second-opinion-code-001.md` の突き合わせ表) で採用された 16 件は、**15 件が解消、1 件が部分解消**。Major 4 件 (不一致率の取得経路・`MeasurementLifetime.reset()` の順序・保持上限の空テスト・破棄テストの全件往復) と相方の Major 5 件はいずれも指摘の機構に届く形で直っており、修正のために触った箇所が他の契約を壊した形跡も見当たらない。

一方で、**この 2 周目で初めて実行環境を変えたときに、グループ 2 の成果物であるエンジンテスト 1 本が決定的に失敗する**ことが分かった。`test行高が一様な配列で初回表示の合計高さの見積もりを損ねない` は、手元で試した 5 つの Simulator のうち 3 つで落ちる (誤差 8.7〜10.0% / 基準 ±5%、contentSize 変化 124〜188 回 / 基準 3 回)。`tasks.md:22` の 2.4 は `[x]` だが、Scenario「合計高さの見積もりを損ねない」は環境を変えると満たされない。テスト失敗を抱えたまま先へ進めないため CHANGES_REQUESTED とする。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| `kasane/handbook/cross/comment-policy.md` | always |
| `kasane/handbook/cross/test-execution.md` | テストを実行する・テスト結果を報告する |
| `kasane/handbook/cross/runtime-behavior-verification.md` | 実行時挙動の検証・完了判定 |
| `kasane/handbook/cross/sample-parity.md` | `samples/**` を触る |
| `kasane/handbook/cross/scroll-performance-gate.md` (本 change の成果物) | スクロール性能の完了判定・証跡 |
| `kasane/handbook/ios/performance-verification.md` / `kasane/handbook/android/performance-verification.md` (同上) | 各 platform の計測手順 |
| `kasane/decisions/cross/0006-perceived-smoothness-as-performance-gate.md` (proposed) | 参照のみ。proposed のため指摘の根拠にしていない |

`kasane/lessons/` に昇格済み scope ファイルは無い。inbox の code-review 系 4 本 (証跡の自前再現 / テストが本番経路を通っているか / 兄弟契約の確認 / 基準値の fixture 追跡) を観点に加えた。

## 再現した検証

ホスト側とは別の Simulator・別の実行で回した。

| 対象 | コマンド | 結果 |
|---|---|---|
| iOS ライブラリ | `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,id=<iPhone 16e / iOS 26.1>' -configuration Debug` | **Executed 167 tests, with 2 failures** (失敗は 1 本のテスト内の 2 アサーション) |
| iOS Sample (通常スキーム) | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination '<iPhone 16e / iOS 26.1>'` | Executed 8 tests, with 0 failures (`LargeDataCountUITests` 3 件を含む) |
| Android Sample | `./gradlew :app:testDebugUnitTest --rerun-tasks` → XML 集計 | 32 tests / 0 failures (7 クラス。`MeasurementLifetimeTest` 3 件・`MeasurementRoundTripCountingTest` 1 件を含む) |
| 事後検証スクリプト | `python3 -m unittest discover -s samples/android/benchmark/scripts` | 23 tests OK |
| lint | `local-path-lint.py` / `identity-lint.py` / `comment-policy-lint.py --advisory` | 違反 0 / 違反 0 / 禁止 0 件・要確認 14 件 (14 件はすべて本 change の diff 外) |

失敗したテストは、Simulator を変えて 5 通り試した。同じ入力で同じ結果になる (再実行しても同じ値) 決定的な失敗である。

| Simulator / OS | 初回表示の誤差 (基準 ±5%) | contentSize 変化回数 (基準 3 回) | 判定 |
|---|---|---|---|
| iPhone 16e / 26.1 | 9.98% (初回 72,773 / 実測 80,841) | 188 | 失敗 |
| iPhone 17 / 26.1 | 8.69% (初回 72,737 / 実測 79,657) | 124 | 失敗 |
| iPhone 17 Pro / 26.4.1 | 8.69% (同上) | 124 | 失敗 |
| iPhone Air / 26.1 | — | — | 通過 |
| iPhone 17 Pro Max / 26.0.1 | — | — | 通過 |

`ios/` を作業ディレクトリ外へ複製し、失敗するテストの本文に計数の表示を挟んだプローブでも同じ値を確認した (複製側にだけ手を入れており、作業ツリーは変更していない)。プローブが読んだ値は次のとおり。

| 観測点 | iPhone 16e / 26.1 (失敗) | iPhone 17 Pro Max / 26.0.1 (通過) |
|---|---|---|
| 推定高さ (量子化後) | 36.333 | 36.333 |
| 走査後の自己サイズ呼び出し数 | 18,305 | 2,195 |
| 走査後の不一致回数 / 不一致率 | 1,257 / **0.069** | 42 / 0.019 |

## 前回指摘の解消状況

`review-001.md` の指摘と `second-opinion-code-001.md` 末尾の突き合わせ表で採用された全件。

| # | 出所 | 指摘 | 判定 | 該当箇所 |
|---|---|---|---|---|
| 1 | host Major | 不一致率が Debug 構成にしかなく、規約の計測構成 (Release) で読めない | **解消** | `kasane/handbook/ios/performance-verification.md:36` が「2 つの走行」を明記し、`:45` に Debug 走行の手順、`:56` に取得源 (帯) を追加。副次の周期再描画も `samples/ios/KsCollectionViewSamples/LargeDataMeasurementBar.swift:26-34` で「読む」「数え直す」の手動操作に置換され、`TimelineView` は消えた |
| 2 | host Major | `MeasurementLifetime.reset()` が `LaunchedEffect` にあり項目の `DisposableEffect` との順序が保証されない | **解消** (回帰テストは弱い → 新指摘 2) | `samples/android/app/src/measurement/.../MemoryRoundTripScreen.kt:92-95` でコンポジション段階の `remember(items)` へ移動 |
| 3 | host Major | 保持上限のテストが最頻値化で上限を外しても通る | **解消** | `ios/Tests/KsCollectionViewTests/KsEstimatedHeightTests.swift:115-141`。古い値 32 件 + 新しい値 20 件で、上限が効かなければ古い値が最頻になって落ちる形。件数の前提をアサーションで固定してある |
| 4 | host Minor / 相方 Major | 破棄テストが Scenario の GIVEN (全件往復) を再現していない | **解消** | `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:1019` が `advanceRoundTrip` で末尾往復し、走査が成立しなければ破棄の確認へ進まない |
| 5 | host Minor | 置換後の上限が同じ実行の観測値 (peak) で独立していない | **解消** | `MeasurementLifetime.kt:57-108` の `VisibleItemTracker` を新設し、`LargeDataMemoryBenchmark.kt:128-136` が `peak <= visible × 4` と `replaced <= 同上` を別々に判定。`kasane/handbook/android/performance-verification.md` の該当節も独立の上限として書き直された |
| 6 | host Minor | 別々の実行の結果をファイル 2 つ指定で受け取れる | **解消** | `samples/android/benchmark/scripts/verify-fling-results.py:105-109` が 2 指定を入力不正にし、`test_指定を_2_つ渡すと入力不正` が固定 |
| 7 | host Minor | 単体テストが実物の結果 JSON の形を通っていない | **部分解消** → 新指摘 3 | `scripts/testdata/memory-benchmarkData.json` と 2 件のテストが追加されたが、実物はメモリ計測の結果でフリング指標を含まない |
| 8 | host Suggestion | 計数が controller とプロセス全体の 2 系統に重複 | **解消** | `ios/Sources/KsCollectionView/KsCollectionViewController.swift:63` は推定値だけを返し、計数は `KsLayoutDiagnostics` 1 か所 |
| 9 | host Suggestion / 相方 Major | Debug 限定の診断型が公開 API になっている | **解消** | `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:14` の `@_spi(KsMeasurement)`。利用者の補完には出ず、読む側は `@_spi(KsMeasurement) import` を書く |
| 10 | host Suggestion | 起動失敗の UI テストが `crashed` の文言に依存 | **解消** | `samples/ios/KsCollectionViewSamplesUITests/LargeDataCountUITests.swift:50-58` が `failIfInvalid` を含む 4 条件で拾う |
| 11 | host Suggestion | 置換後の待機が完了条件そのものを見ていない | **解消** | `MemoryRoundTripScreen.kt` の `awaitPreviousItemsReleased` が「置換前の識別子が 1 つも載っていないこと」を条件にし、実時間の上限超過では残数つきで失敗を返す |
| 12 | 相方 Major | 不一致率が original attributes ではなく現在の推定値と比較している | **解消** | `ios/Sources/KsCollectionView/KsHostingCell.swift:89` が original も渡し、`KsCollectionViewController.swift:335-345` が渡された高さと比較。`KsCollectionEngineTests.swift:835` が「推定値が動いた後でも渡された高さと比べる」ことを固定 |
| 13 | 相方 Major | スクリプトが試行数 3 を検証しない | **解消** | `verify-fling-results.py:234-252` が試行数と `repeatIterations` を照合。1 / 2 / 4 試行と画像グリッドのテストが追加 |
| 14 | 相方 Major | iOS 規約だけ基準機の無承認代替を許す | **解消** | `kasane/handbook/ios/performance-verification.md:34` が承認必須 + 速い遅いに関わらず非保証の明記を要求 |
| 15 | 相方 Minor | 繰り返し前の平均が格子に載らない | **解消** | `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:62` で平均も量子化。`test繰り返しが無いときの平均も格子に載せて返す` が固定 |
| 16 | 相方 Minor | cross と Android の合格線の文面矛盾 | **解消** | `kasane/handbook/cross/scroll-performance-gate.md:20` が体感ゲートに限定し、Android の相対計測を別系統と明記 |
| 17 | 相方 Minor | スクリプトの使用例が実在しないファイル名 | **解消** | `verify-fling-results.py:11` がリポジトリルートからの実パス |
| 18 | 相方 Minor | Android の証跡に OS 情報が無い | **解消** | `evidence/manual-imageGrid-android-2026-09-08.md:10` / `evidence/manual-largeData-android-2026-09-08.md:10` が「未記録」と比較不能の条件を明記 |

未解消・後退はいずれも無い。

## 指摘事項 (今回新たに入ったもの)

### [🔴 Critical] 合計高さの再検証テストが実行環境を変えると決定的に失敗し、tasks 2.4 の完了印と実態が食い違う

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:925`、`tasks.md:22`、`deviation.md:1`

**問題点**:

`specs/collection-layout/spec.md` の Scenario「合計高さの見積もりを損ねない」は THEN に「初回表示の高さの誤差は実測に対して ±5% 以内、末尾までの変化回数は 3 回以下」を置いている (`deviation.md` の合意で GIVEN は「行の高さが一様な配列 (1 列)」に読み替え、基準値は据え置き)。これを再検証する `test行高が一様な配列で初回表示の合計高さの見積もりを損ねない` は、**手元で試した 5 つの Simulator のうち 3 つで落ちる**。数値は上の「再現した検証」の表のとおりで、誤差は基準の約 2 倍、変化回数は基準の 40〜60 倍である。フレーキーではなく、同じ Simulator では同じ値が再現する。

`tasks.md:22` の 2.4 は `[x]` だが、この Scenario は環境を変えると満たされていない。`deviation.md:1` が記録する実測値「一様配列では最頻値 1.01% / 2 回」も、3 つの環境では再現しない (8.69〜9.98% / 124〜188 回)。基準値も deviation の数値も、実装者の手元の 1 環境でしか成立していない。

プローブで見たとおり、失敗する環境では走査中の自己サイズ呼び出しが 18,305 回・不一致 1,257 回まで膨れており、推定値 (36.333) より高いセルが少なくない割合で現れて contentSize が伸び続けている。つまり「最頻値化で合計高さの見積もりが崩れる」という design の Risks 節の懸念が、環境によっては実際に起きている。

**あわせての所見 (spec / design 側の判断が要る)**: 失敗した環境の走査後の不一致率は **0.069** で、design Decision 2 の主指標 (基準 1: 0.20 以下) は楽に満たしている。つまり**主指標が合格でも基準 3 が大きく外れる**。グループ 4.1 を不一致率中心で判定すると、合計高さの退行を見逃したまま「対策成功」と読めてしまう。基準値そのものの校正が必要という結論になる場合、足場は凍結なのでこのレビューでは spec を直さず、提案の改訂として扱う必要がある。

**推奨修正**:
1. まず失敗する環境で原因を切り分ける (推定値と実測が食い違うセルが何であるか、初回レイアウト時の幅が確定する前の計測が標本に入っていないか)。実装で詰められるなら直して全環境で通す
2. 実装では詰め切れず「基準値が 1 環境でしか成立しない値だった」となるなら、tasks 2.4 のチェックを外したうえで NEEDS_DISCUSSION として提案側へ返す (基準の校正は design Decision 2 の改訂事項であり、レビューでも実装でも決められない)
3. どちらの結論でも、`deviation.md` の「1.01% / 2 回」は採取環境 (機種・OS) を併記した形に直す。環境名の無い数値は次回の比較に使えない

### [🟠 Major] `reset()` の順序を守る回帰テストが、指摘された失敗モードを落とせない

**該当箇所**: `samples/android/app/src/testDebug/kotlin/jp/kamusoft/kscollectionview/samples/android/MeasurementRoundTripCountingTest.kt:41-48`

**問題点**:

前回 Major 2 の推奨修正は「数え直しをコンポジション段階へ移し、**初期可視分が数え落とされないことを 1 本のテストで固定する**」だった。実装側は前者を行ったが、追加されたテストのアサーションは `MeasurementLifetime.alive > 0` と `peakAlive > 0` の 2 つだけである。

数え直しが `LaunchedEffect` に戻った場合でも、reset の後に走査が新しい項目を載せれば `invoked` は増えるため、`alive` も `peakAlive` も 0 より大きくなりうる。テストの docstring は「数え落とすと同時生存が負に振れる」と書いているが、負に振れることを検出する条件 (載っている項目数との一致、または `alive` の下限) はどこにも書かれていない。つまりこのテストは、それが守るはずの順序を固定していない。

`MeasurementLifetimeTest` はカウンタ単体しか触らないので、順序を見ているテストは実質ゼロのままである。

**推奨修正**: 「画面に載っている項目の数」と `alive` が一致することをアサーションにする (例: 画面の項目に付けた semantics の数、または走査が公開する載った項目の集合の大きさと突き合わせる)。少なくとも `alive` が初期可視分の下限を下回ったら落ちる形にし、数え落としが起きたときに落ちる向きで壊れることを確かめる。

### [🟡 Minor] 実物の結果 JSON の回帰テストが、フリング判定が読む指標の容器を一度も通っていない

**該当箇所**: `samples/android/benchmark/scripts/testdata/memory-benchmarkData.json`、`samples/android/benchmark/scripts/test_verify_fling_results.py:313-326`

**問題点**:

追加された実物の結果 JSON は**メモリ計測**の実行結果で、`metrics` に入っているのは `memoryGpuLastKb` 等の 4 件、`sampledMetrics` は空である。したがって新しい 2 件のテストが実物で確かめているのは「`context` の 4 項目が読めること」と「フリングの対象が無ければ入力不正になること」だけで、**`frameCount` と `frameDurationCpuMs` がどちらの容器のどこに入るか**は手書き fixture の仮定のままである。前回 Minor 7 の主眼はここだった。

そのうえで、この 1 本の実物から既に形の食い違いが 1 つ見えている。実物の `sampledMetrics` は **`[]` (配列)** で、手書き fixture の `sampledMetrics` は**辞書**である。`verify-fling-results.py:189-193` の `metric_of` は辞書だけを見るため、実物のフリング結果でも `sampledMetrics` が配列で出るなら `frameDurationCpuMs` に到達できない。黙って緑にはならず入力不正 (終了コード 3) で止まるので実害は「初回の実行で必ず止まる」だが、判定の要を担うスクリプトが実物で一度も動いていないことの具体例ではある。

**推奨修正**: グループ 4.4 で最初にフリング計測を回したときの結果 JSON を `scripts/log-sanitize.py` に通して `evidence/` か `scripts/testdata/` に 1 本残し、それを読む回帰テストを 1 件足す (前回の推奨と同じ)。あわせて `metric_of` が配列形式の `sampledMetrics` も読めるようにしておくと、初回の空振りを 1 往復減らせる。

### [🔵 Suggestion] 失敗したテストが 1 つの Simulator でしか回されていない構造そのものへの手当て

**該当箇所**: `kasane/handbook/cross/test-execution.md` (既存規約) と本 change の iOS テスト群

Critical 1 は「同じコードが Simulator によって通ったり落ちたりする」形で現れた。`test-execution.md` は実行件数の確認と収束待ちの書き方を定めているが、**どの機種・OS で回したかを結果と一緒に報告する**ことは求めていない。レイアウトの数値に対するアサーションを持つテストが増えた以上、報告に機種と OS を併記する (そして完了判定では 2 機種以上で回す) 規律があると、この種の食い違いが 1 周目で見つかる。規約の改訂は本 change のスコープ外なので、`ksn-lesson` への捕捉か別 change としての起票が適切と考える。

## アクションプラン

1. **Critical 1** — 失敗する環境での原因切り分け。実装で詰められるなら直して全環境で通し、詰め切れないなら tasks 2.4 のチェックを外して基準値の校正を提案側へ返す。`deviation.md` の数値には採取環境を併記する。グループ 4 に入る前提条件
2. **Major 2** — `MeasurementRoundTripCountingTest` を、数え落としが起きたら落ちる形 (載っている項目数との一致、または下限) に書き直す
3. **Minor 3** — グループ 4.4 の実機フリング結果を 1 本残して回帰テストを足す。`metric_of` の配列対応は今のうちに入れてもよい
4. **Suggestion 4** — テスト実行の報告に機種 / OS を併記する規律を lessons へ捕捉するか、別 change として起票する
