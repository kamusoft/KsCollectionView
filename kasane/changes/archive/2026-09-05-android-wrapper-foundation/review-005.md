# レビュー結果: android-wrapper-foundation (005 回目)

**日付**: 2026-09-05
**判定**: APPROVED

## サマリー

前回 (`review-004.md` の Major 1・Minor 3、および `second-opinion-code-004.md`「突き合わせ結果」で採用・確定した 6 件) の必須指摘はすべて解消しており、いずれも成果物の記述だけでなくレビュアー自身のプローブ (画素検査への変異注入、基準実機での再計測、エミュレータでの回転・戻る操作) で成立を確認した。Compose BOM を 1.11 系へ・compileSdk を 36 へ下げる合意済み差分も、単一宣言元・AAR メタデータ・推移依存のすべてで意図どおり反映されている。残る指摘は成果物の記述の正確さと dead code の 3 件 (Minor) と 3 件 (Suggestion) で、いずれも挙動・仕様適合には影響しない。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| handbook/cross/comment-policy.md | always |
| handbook/cross/sample-parity.md | `samples/` を触る作業 |
| handbook/cross/test-execution.md | テスト実行・結果報告 |
| handbook/cross/runtime-behavior-verification.md | 実行時挙動 (回転・スクロール・再利用) の完了判定 |
| handbook/cross/public-identifiers.md | ビルド定義・配布座標を触る作業 |
| handbook/cross/local-development-setup.md | 環境要件・版の定義元を触る作業 |
| handbook/ios/performance-verification.md | 大量件数を扱う変更の完了判定 (Android 計測が揃える fixture・手順の正) |
| decisions cross/0002・0003・0004 (accepted) / android/0001・0002 (proposed) | ビルドルート・配布座標・パリティ・レンダリング方式・ビルド構成 |
| kotlin-impl-skill / jetpack-compose-impl-skill | Kotlin 言語層・Compose 状態管理と副作用 |

`android/ADR-0001` / `android/ADR-0002` は `proposed` のため、これを根拠にした指摘は出していない。

## 実行した検証

**ビルドとテスト** (JDK 17)

| 対象 | 結果 |
|---|---|
| `android/` `:kscollectionview:testDebugUnitTest --rerun-tasks` | **54 tests / 0 failures** (`KsCollectionViewCoreTest` 14 + `KsCollectionViewInteractionTest` 17 + `KsCollectionViewLayoutTest` 23。XML のクラス別内訳で確認) |
| `android/` `:kscollectionview:assemble` | BUILD SUCCESSFUL (debug / release AAR) |
| `samples/android/` `:app:testDebugUnitTest --rerun-tasks` | **12 tests / 0 failures** (`SampleDemoScreenTest` 8 + `SampleScreenParityTest` 4) |
| `samples/android/` `:app:assembleDebug` / `assembleRelease` / `assembleBenchmark` / `:benchmark:assembleBenchmark` | BUILD SUCCESSFUL |
| `scripts/local-path-lint.py` / `identity-lint.py` / `comment-policy-lint.py` | 0 件 (comment-policy は検査対象 141 ファイル。`--selftest` 全件 OK) |
| `scripts/doc-structure-lint.py` | 30 件はすべて roadmaps / concepts / 配布物の既存分。本 change が触った文書に指摘なし |

**Compose BOM 1.11 系 / compileSdk 36 の反映** (`deviation.md` 3 件目)

- `android/gradle/libs.versions.toml` に `compile-sdk = "36"` の単一宣言元があり、本体・Sample・計測の 3 モジュールが `libs.versions.compile.sdk` から引いている。`compileSdkMinor` のべた書きは残っていない
- 本体 AAR の `META-INF/com/android/build/gradle/aar-metadata.properties` は debug / release とも `minCompileSdk=36`
- 推移依存の解決版は Compose 1.11.4 / material3 1.4.0 / navigation-compose 2.9.8。各 AAR の `minCompileSdk` を実測したところ最大 35 (`material3-android` 35、`foundation-android` 35、`ui-android` 35、`navigation-compose-android` 35) で、**37 を要求する artifact は解決グラフに 1 つも無い**。キャッシュに残る `navigation-compose 2.10.0` は `minCompileSdk=37` で、2.9 系に留めた判断の根拠が実測として裏づけられた
- `handbook/cross/local-development-setup.md` の環境要件 (Platform android-36 / Build-Tools 36.0.0) と版の定義元の表は、上記の実装と一致している

**画素読み取りヘルパの実効性** (前回の懸念点 (b))

`KsCollectionViewLayoutTest` の `readPixels()` が `captureToImage()` と同じ座標・色を観測しているかを、実装へ一時的な変異を入れて確かめた。`Modifier.ksListSeparator` の先頭行の上端の線だけを描かないよう変異させると、`listSeparatorsAreDrawnByDefault` / `listSeparatorsAreDrawnOverOpaqueItemBackground` / `listSeparatorColorChangesOnlyTheColor` の 3 件が FAILED になった。変異を戻すと 54 件すべてが再び成功する。画素比較 6 テストは実描画の値を見ており、空振りしていない (`@GraphicsMode(NATIVE)` も効いている)。

**基準実機での再計測** (lessons: 計測値を含む証跡はレビュアーが自前プローブで再現を試みる)

`:benchmark:connectedBenchmarkAndroidTest` を基準機で独立に実行した。

| 土俵 | 指標 | 自前計測 (ライブラリ / 比較対象 / 相対) | 証跡の値 (相対) |
|---|---|---|---|
| 2 列 grid | `frameDurationCpuMs` P90 | 6.60 / 6.72 ms / -1.7% | +1.1% |
| 2 列 grid | `frameDurationCpuMs` P99 | 7.99 / 8.01 ms / -0.2% | -8.6% |
| 2 列 grid | `frameOverrunMs` P99 | -6.18 ms (絶対上限 0.0 ms 以下を満たす) | -5.52 ms |
| 1 列 list | `frameDurationCpuMs` P90 / P99 | -2.1% / -9.8% | -3.1% / -3.9% |

メモリも独立に再実行した。10,000 件は `steady:4` (暖機) / `steady:3` (本計測)、1,000 件は 2 実行とも `steady:3`。**すべての往復で `visited` が件数と一致** (10,000 / 1,000) しており、走査の到達確認が実際に効いている。`memoryRssAnonLastKb` は 1,000 件 50,756 KB → 10,000 件 57,992 KB (+14.3%) で、証跡の +11.8% と同じ結論 (件数比 10 倍に比例しない) を再現した。1,000 件側の往復 1→2 の大きな減少 (-8.2%) も証跡と同じ形で現れる。

**実機 (エミュレータ) 操作** (lessons: 静止画で完了せず操作して確かめる)

- 「グリッド (固定列)」を起動経路指定で開き、list を選んでから縦 → 横 → 逆横 → 縦の 4 方向を回した後も、Item 1 / Item 2 が全方向で縦に並ぶ (= list 選択が保持されている)
- 同じ状態で戻る操作を 1 回行うとルートメニューへ戻る。回転 0 回 / 1 回 / 2 回 / 3 回 / 4 回のいずれでも同じ (back stack の積み増しは再現しない)。2 回目の戻るでアプリを抜ける
- 検証画面で行を展開してから 4 方向を回しても「展開中: 1 行」と本文が残り、`rememberSaveable` の保存例外 (`cannot be saved`) もログに出ない
- 「リスト」画面で区切り線「なし」を選んで 3 回転させた後も選択と描画が保たれる (静止画で確認)

**検証画面の Scenario 成立**

`HeightChangeRowCount = 60`。`SampleDemoScreenTest.検証画面のテンプレート内の状態は画面外への往復で初期値へ戻る` が、テンプレート内 state 経路で行 3 を展開 → index 59 へ送って `assertDoesNotExist` → index 0 へ戻して本文が消えていることを検証している。実機証跡も展開 / 画面外 / 復帰の 3 枚が揃っており、spec の WHEN / THEN を実際に踏んでいる。

**touchFeedbackColor の追跡整合**

`deviation.md` 4 件目 (本体の意味論の非対称、統一は後続 change) ⇔ `evidence/sample-parity-comparison.md`「不一致」節 (1 件ありと明記し deviation へ送る) ⇔ `ui/brief.md`「プラットフォーム制約による差分」の 3 者が同じ内容で整合している。前回の「証跡が『不一致なし』と述べている」矛盾は解消。

## 前回指摘の追跡表

| 前回の指摘 (出典) | 重要度 | 状態 | 確認方法 |
|---|---|---|---|
| `touchFeedbackColor` の差が deviation.md に無く、証跡は「不一致なし」 (review-004 Major / so-code-004 確定) | 🟠 Major | **解消** | deviation.md 4 件目・evidence「不一致」節・brief の 3 者を突き合わせ |
| 回転で選択状態が初期値へ戻る (review-004 Minor) | 🟡 Minor | **解消** | 4 画面が `rememberSaveable` 化。実機 4 方向回転で保持を確認。`StateRestorationTester` の 1 件をテストに追加 |
| 起動経路指定が回転のたびに back stack へ積み増す (review-004 Minor) | 🟡 Minor | **解消** | `startRouteConsumed` を `rememberSaveable` で 1 回消費。実機で回転 0〜4 回すべて戻る 1 回でメニューへ |
| モックの副文字色を採らなかった事実が未記録 (review-004 Minor) | 🟡 Minor | **解消** | brief「プラットフォーム制約による差分」に iOS に合わせた判断として明記 (下記 Minor 1 の書き方の問題は残る) |
| メモリ定常判定が減少も通し、全項目通過の自己確認が無い (review-004 Suggestion / so-code-004 採用) | 🔵→🟡 | **解消** | `isSteady` の符号の読みをコードと証跡に明記。`visited` 集合と往復ごとの件数照合を追加し、`missedItems` で失敗させる |
| `compileSdk` が 3 か所にべた書き (review-004 Suggestion) | 🔵 Suggestion | **解消** | カタログの `compile-sdk` を 3 モジュールが参照 |
| 計測専用 helper が main にあり release APK に載る (review-004 Suggestion) | 🔵 Suggestion | **未対応** | `KsLargeDataGrid` / `KsLargeDataList` は main のまま (下記 Minor 2) |
| 計測モジュールのマニフェストのコメントが宣言内容と食い違う (review-004 Suggestion) | 🔵 Suggestion | **未対応** | 下記 Minor 3 |
| 単体テスト worker JVM の競合 (review-004 Suggestion) | 🔵 Suggestion | 対応不要 | 今回の 3 度の実行ではいずれも再現せず |
| メモリ比較の 1,000 件側も 10,000 件分の入力データを保持 (so-code-004 Major) | 🟠 Major | **解消** | `DemoData.largeItems(count)` が件数分だけ生成。作り置きの `val largeItems` は無く、10,000 件の常駐も無い |
| メモリ走査が到達完了を観測せず `notSteady` も成功扱い (so-code-004 → Minor) | 🟡 Minor | **解消** | `awaitArrival` が実時間 deadline + `delay(4)` の譲り + 超過時の実測値つき失敗。`notSteady` / `unreached` / `missedItems` を計測側が `assertTrue` で落とす |
| フレーム計測開始前に目的画面の安定を確認していない (so-code-004 → Minor) | 🟡 Minor | **解消** | 経路ごとの semantics を `awaitMeasurementScreen` が deadline つきで待ち、超過で失敗させる |
| テンプレート内状態の破棄 Scenario が 5 行では再現できない (so-code-004 Major) | 🟠 Major | **解消** | 60 行化 + 往復テスト + 実機証跡 3 枚 |
| 再利用確認 (8.3) が Layout Inspector 未実施のまま完了扱い (so-code-004 → Minor) | 🟡 Minor | **解消** | 同時生存数 (現在値・最大値・破棄) を測るカウンタで代替し、deviation.md 5 件目に記録。証跡に最大 32 / 破棄 378 を記載 |

必須 4 件 + 採用 5 件 + 確定 1 件 = **10 件すべて解消**。未対応は前回 Suggestion 2 件のみ。

## 指摘事項

### [🟡 Minor] `ui/brief.md` の見出しが「deviation.md へ記録済み」と述べる 4 項目のうち、実際に記録があるのは 1 件だけ

**該当箇所**: `ui/brief.md`「プラットフォーム制約による差分 (deviation.md へ記録済み)」節と「照合結果」節の末尾 / `deviation.md`

**問題点**: 節の見出しは「(deviation.md へ記録済み)」、直前の照合結果は「プラットフォーム制約による差分は下記のとおりで、**いずれも** deviation.md への記録で確定した」と書いている。しかし `deviation.md` の 5 件に含まれるのは「タップのフィードバック色」だけで、残る 3 件 (通知テンプレートの印 / 長い画面タイトル / ルートメニューの検証区分の副文字色) は記録されていない。

3 件はいずれも sample-parity の「許容される差異」(描画差・OS 標準 chrome) と、モックと iOS のどちらに合わせるかの照合判断であり、そもそも deviation.md へ記録すべき乖離ではない。つまり不足しているのは記録ではなく、記述の正確さである。とはいえ「記録済み」と書かれた追跡先が空という状態は、前回 Major と同じ「追跡があると読めるが無い」型であり、この brief は蒸留までアーカイブに残る。

**推奨修正**: 見出しを「プラットフォーム制約による差分」に戻し、`touchFeedbackColor` の項目だけに「(deviation.md に記録)」を付ける。照合結果の「いずれも deviation.md への記録で確定した」は「タップのフィードバック色のみ deviation.md へ記録し、他は sample-parity の許容差異として扱った」に書き替える。

### [🟡 Minor] `KsLargeDataGrid` の `scrollController` 引数が誰からも渡されなくなり、KDoc だけが用途を語っている

**該当箇所**: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/LargeDataDemoScreen.kt:39-51`

**問題点**: メモリ計測が `MemoryRoundTripScreen` 側で自前の `KsCollectionView` を持つ形になった結果、`KsLargeDataGrid` の `scrollController` に値を渡す呼び出し元が 1 つも無くなった (`grep` で確認: 参照は宣言と `KsCollectionView` への転送のみ)。KDoc は「外からスクロールさせるためのコントローラ」と現役の機能として説明しており、ファイル単体を読む人を誤らせる。

前回 Suggestion (計測専用 helper を `src/measurement` へ移す) が未対応なため、`KsLargeDataList` ともども release APK に残っている点も変わっていない。`KsLargeDataList` はデモ画面からは使われず計測用の経路だけが呼ぶ。

**推奨修正**: `scrollController` 引数と対応する KDoc を削除する。あわせて `KsLargeDataList` を `src/measurement` へ移し、`main` には「大量件数」画面が使う `LargeDataLayout` と `KsLargeDataGrid` だけを残す (前回 Suggestion と同じ方向)。

### [🟡 Minor] 計測モジュールのマニフェストのコメントが、宣言している内容を説明していない (前回から未対応)

**該当箇所**: `samples/android/benchmark/src/main/AndroidManifest.xml:3-6`

**問題点**: コメントは「計測対象アプリのプロセスを観測するために必要な問い合わせ許可」だが、宣言されているのは `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion=29`) で、古い API 版で計測結果を書き出すための宣言である。comment-policy は `always` の規約で「そのファイルだけを読んでいる人にとって意味が通る」ことを最低条件に置いており、これは読んだ人を誤らせる型。機械検査は禁止参照だけを見るため拾わない (検出 0 件は適合の証明にならない)。前回 Suggestion として挙げたが手が入っていない。

**推奨修正**: 「API 29 以前で計測結果ファイルを書き出すために要る」と現在の事実に書き直す。

### [🔵 Suggestion] テンプレート計数の公開関数 3 つがどこからも呼ばれていない

**該当箇所**: `samples/android/app/src/counterEnabled/kotlin/jp/kamusoft/kscollectionview/samples/android/TemplateInvocationCounter.kt:70-88` (`snapshot` / `lifetimeSnapshot` / `reset`) と `counterDisabled/` の同名関数

**問題点**: 証跡 (`evidence/template-reuse-measurement.md`) の数値は `Log.i` の出力を読んで採っており、`snapshot()` / `lifetimeSnapshot()` / `reset()` を呼ぶ経路は無い。両ソースセットで同じ形を保つ必要があるため空実装側も対で残っており、使われない面が 2 倍で増えている。また `reset()` が呼ばれた後に `onDispose` が走ると `alive.getValue(screen)` が `NoSuchElementException` になる (現状は呼ばれないので顕在化しない)。

**推奨修正**: 3 つを削除してログ出力だけを残すか、`reset()` を残すなら `onDispose` 側を `alive[screen]?.decrementAndGet()` にして欠落に耐えるようにする。

### [🔵 Suggestion] 走査の刻みを「可視範囲の半分」と説明しているが、実際は可視範囲の 7 割強

**該当箇所**: `samples/android/app/src/measurement/kotlin/jp/kamusoft/kscollectionview/samples/android/MemoryRoundTripScreen.kt:26` / `evidence/performance-measurement.md`「手順 / メモリ」の 2

**問題点**: `ScanStepItems = 16` に対し、同じ土俵の可視項目数は 22 (`evidence/template-reuse-measurement.md` の「初期表示 Item 1〜22」)。刻みは可視範囲の約 73% であり、コードの KDoc と証跡が言う「可視範囲の半分」ではない。iOS 規約 (`handbook/ios/performance-verification.md` 手順 2) は「可視範囲の高さの半分ずつ」を求めており、Android 側は同じ言葉でより粗い刻みを説明していることになる。

実害は無い — 往復ごとの `visited` 件数照合が入ったため、刻みが粗すぎて間の項目が作られなければ `missedItems` で失敗する (今回の再計測でも全往復 `visited` = 件数で通過している)。ただし説明と実装がずれたままだと、画面構成が変わったときに「半分だから安全」という誤った前提で読まれる。

**推奨修正**: 数値を実態に合わせて「可視範囲を超えない刻み (22 項目の可視範囲に対して 16 項目)」と書くか、刻みを 11 に下げて説明どおりにする。安全性の根拠が刻みの大きさではなく `visited` の件数照合にあることも 1 行添えると読み違えが起きない。

### [🔵 Suggestion] 回転をまたぐ状態保持のテストが 1 画面にしかない

**該当箇所**: `samples/android/app/src/test/kotlin/jp/kamusoft/kscollectionview/samples/android/SampleDemoScreenTest.kt:120-135`

**問題点**: `StateRestorationTester` を使うテストは「グリッド (固定列)」の 1 件だけで、`rememberSaveable` 化した他の 3 画面 (リストの区切り線 3 択と最後のイベント、スペーシングと余白の 2 つの滑り操作、検証画面の経路 / レイアウト / 展開行) は検証層に載っていない。特に検証画面の `expandedIds: List<Int>` は既定の saver が Bundle へ保存できるかどうかがコレクションの実体型に依存するため、壊しても自動テストでは気づけない (今回はレビュアーが実機の 4 方向回転で成立を確認した)。

**推奨修正**: 検証画面の展開状態について `StateRestorationTester` の 1 件を足す (行を展開 → 復元 → 「展開中: 1 行」が残る)。実行時間は既存の 1 件と同程度で済む。

## アクションプラン

1. (推奨) `ui/brief.md` の「deviation.md へ記録済み」の書き方を実態に合わせる (Minor 1) — 蒸留前に直しておくと、アーカイブに事実と違う追跡先の記述が残らない
2. (推奨) `KsLargeDataGrid` の使われない `scrollController` を落とし、`KsLargeDataList` を `src/measurement` へ移す (Minor 2 / 前回 Suggestion)
3. (推奨) 計測モジュールのマニフェストのコメントを事実に直す (Minor 3 / 前回 Suggestion)
4. (任意) 計数の未使用関数の整理、走査の刻みの説明の修正、回転をまたぐテストの追加 (Suggestion 3 件)

いずれも挙動・仕様適合には影響しないため、本 change の完了を妨げない。

## 確認した観点 (指摘に至らなかったもの)

- **tasks.md の完了状態**: 9 グループ全 34 項目がチェック済み。未実装の虚偽チェックは無い。8.3 (Layout Inspector) は deviation.md 5 件目で正式に代替へ置き換えられており、代替手段の結果が証跡に載っている
- **足場アーティファクトの不改変**: `specs/` 4 ファイル・`design.md`・`proposal.md` はいずれも今回の修正サイクルで更新されていない (更新されたのは tasks.md / deviation.md / ui/brief.md / evidence/ のみ)
- **deviation.md の 5 件**: 区切り線の描画順・性能指標の読み替え・Compose BOM と compileSdk の引き下げ・`touchFeedbackColor` の非対称・カウンタによる代替。いずれも理由と spec への影響範囲が書かれており、合意済み差分として扱った
- **spec Scenario の充足**: 「メモリが件数に比例しない」(件数ごとの生成 + 定常判定 + 件数比の説明)、「可変行高混在 10,000 件のスクロール」(相対 10% 以内 + 絶対上限)、「計測の再実行」(自前で再現)、「テンプレート内の状態による展開」(60 行 + テスト + 実機証跡)、「全画面の対応表による照合」(不一致 1 件と deviation 追跡) をそれぞれ実装・テスト・証跡で辿れた
- **`rememberSaveable` の型**: 4 画面が保持するのは enum・String・Float・`List<Int>` で、いずれも既定の saver で Bundle へ入る。実機の 4 方向回転で保存例外が出ないことを logcat で確認した
- **収束を待つアサーション**: `awaitArrival` は実時間 deadline・`delay(4)` による実行機会の譲り・超過時の実測値つき失敗の 3 条件を満たす。`awaitMeasurementScreen` も deadline + 失敗。反復回数で区切る形は残っていない
- **計測用コードの release 除外**: `measurement` / `noMeasurement`、`counterEnabled` / `counterDisabled` の差し替えは維持されており、release 構成のビルドも成功する
- **公開識別子**: application ID・namespace・Maven 座標・計測モジュールの `.benchmark` は cross/ADR-0003 の写像表どおりで、今回の版変更でも動いていない
- **コメント規約**: 今回触れたファイルの外部参照は `<domain>/ADR-NNNN` 形式のみ。作業文書のパス・変更識別子・レビュー通番の裸参照は無い (Minor 3 の型は機械検査の範囲外のため本文から判定した)
- **成果物のパスと識別子**: ローカル絶対パス・端末の個体識別子は evidence / brief / deviation のいずれにも無い (lint 2 種 0 件、本文も目視)
- **本サイクルの diff 範囲外**: `ios/` と `samples/ios/` は今回の修正で 1 ファイルも変更されていないため、iOS のテストは再実行していない (前サイクルまでの結果が有効)
