# レビュー結果: android-wrapper-foundation (004 回目)

**日付**: 2026-09-05
**判定**: CHANGES_REQUESTED

## サマリー

Android Sample は 9 デモ画面 + 固有検証画面の文言・件数・初期値・DSL パラメータ・`SampleTheme` の RGBA が iOS Sample とよく一致しており (5 画面をソースで直接突き合わせて確認)、composite build の明示置換・application ID・計測用コードの release 除外はいずれも実測で成立していた。性能計測の証跡も基準機で自前に再実行して桁と傾向が再現した。一方で、`touchFeedbackColor` に両プラットフォームで異なる値を渡している点が sample-parity の言う「本体側の統一課題」として deviation.md に記録されておらず、証跡は逆に「不一致なし」と述べている。あわせて、lessons inbox の回転検証を実機で行ったところ、Sample 側に回転で選択状態が失われる・back stack が積み増される 2 件の不具合を検出した (静止画では出ない型)。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| handbook/cross/comment-policy.md | always |
| handbook/cross/sample-parity.md | `samples/` を触る作業 |
| handbook/cross/test-execution.md | テスト実行・結果報告 |
| handbook/cross/public-identifiers.md | ビルド定義・配布座標を触る作業 |
| handbook/ios/performance-verification.md | 大量件数を扱う変更の完了判定 (Android 計測が揃える fixture・手順の正) |
| decisions cross/0003 (accepted) / cross/0004 (accepted) / android/0001 (proposed) / android/0002 (proposed) | 配布座標・パリティ・レンダリング方式・ビルド構成 |
| lessons/inbox/verify-interactive-collection-layout-transitions.md | 動的レイアウト・操作設定に触れたレビュー |
| lessons/inbox/reviewer-reproduces-evidence-numbers-by-probe.md | 計測値を含む証跡のレビュー |

`android/ADR-0001` / `android/ADR-0002` はまだ `proposed` のため、これを根拠にした指摘は出していない (蒸留で accepted に昇格する前提のコード参照も、本体側と同じ扱いとして許容した)。

## 実行した検証

**ビルドとテスト** (`samples/android`、JDK 17):

| 対象 | 結果 |
|---|---|
| `:app:assembleDebug` / `:app:assembleRelease` | BUILD SUCCESSFUL |
| `:app:assembleBenchmark` / `:benchmark:assembleBenchmark` | BUILD SUCCESSFUL |
| `:app:testDebugUnitTest --rerun-tasks` | 10 tests / 0 failures (`SampleDemoScreenTest` 6 + `SampleScreenParityTest` 4)。単独実行 6 連続で BUILD SUCCESSFUL |
| `scripts/local-path-lint.py` / `identity-lint.py` / `comment-policy-lint.py` | 0 件 (comment-policy は検査対象 141 ファイル) |
| `scripts/doc-structure-lint.py` | 指摘はすべて roadmaps 配下の既存分。本 change の範囲外 |

**自前プローブ** (lessons: 証跡の数値はレビュアーが再現を試みる):

- 基準機で `LargeDataScrollBenchmark#ksCollectionView` と `#baselineLazyVerticalGrid` を独立に実行。ライブラリ `frameDurationCpuMs` P90 6.8 ms / P99 8.9 ms、比較対象 P90 7.0 ms / P99 20.5 ms → 相対 P90 −3.7% / P99 −56.7% で合格線内。`frameOverrunMs` P99 は −3.8 ms で提案されている絶対上限 (0.0 ms 以下) を満たす。証跡記載の値 (P90 6.60〜6.96 / P99 8.56〜8.89) と桁も範囲も一致した
- 証跡が「試行 1 に散発する外れ値は比較対象側にも出る」と述べている現象を、今回は**比較対象側**で再現 (P99 20.5 ms)。証跡の説明は裏づけられた
- メモリ往復の走査が全項目を通過しているかを、debug 構成のテンプレート呼び出しカウンタで独立に計数。1,000 件 1 往復で 1,972 回、10,000 件 3 往復で 59,876 回 (いずれも件数 × 2 × 往復数にほぼ一致) → 走査は間の項目を飛ばしていない
- release / debug / benchmark の各 APK に含まれる識別子を数え、release に `BaselineLargeDataGrid` / `MemoryRoundTripScreen` / 計数の実装がいずれも 0 件であることを確認

**実機 (エミュレータ) 操作** (lessons: 静止画で完了せず操作して確かめる): 区切り線 3 択の切り替え、滑り操作の連続ドラッグ (両端まで往復)、layout 切替後の上下スクロール、縦 → 横 → 逆横 → 縦の回転。うち回転で 2 件の不具合を検出 (下記 Minor)。

## 指摘事項

### [🟠 Major] `touchFeedbackColor` に両プラットフォームで違う値を渡しているが、deviation.md に追跡がなく証跡は「不一致なし」と述べている

**該当箇所**: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/ListDemoScreen.kt:59` / `samples/ios/KsCollectionViewSamples/ListDemoView.swift:38` / `evidence/sample-parity-comparison.md`「不一致」節 / `deviation.md`

**問題点**: iOS は `.touchFeedback(color: SampleTheme.accent.opacity(0.15))`、Android は `touchFeedbackColor = SampleTheme.accent` と、同じデモ画面が同じ公開 API へ**違う値**を渡している。原因は本体の意味論の非対称で、iOS (`ios/Sources/KsCollectionView/KsHostingCell.swift:132-134`) は渡された色をそのまま塗り面の背景色にする (不透明度は呼び出し側の責任) のに対し、Android (`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:188`) は `ripple(color = …)` へ渡すため不透明度をライブラリ側が掛ける。結果の見え方は揃うが、**利用者が同じ値を書くと結果が揃わない**。

sample-parity は「DSL に渡すパラメータ (…色等) を一致させる」を保証対象に置き、「本体公開 API のプラットフォーム差で一致が不可能な箇所を黙認しない。一致できない理由を deviation.md に記録し、本体側の統一課題として扱う」と定めている。また specs/samples の Scenario「全画面の対応表による照合」は THEN に「不一致があれば deviation.md に記録された追跡がある」を置いている。現状の追跡先は `ui/brief.md` の「プラットフォーム制約による差分 (オーナー確認待ち)」だけで、`deviation.md` には無い。さらに `evidence/sample-parity-comparison.md` の「不一致」節は「なし。本体既定値のプラットフォーム差に由来する差も、今回の照合では観測されなかった」と書いており、brief 側の未決事項と食い違っている (許容差異表の「タップ中の表現」は *値を指定しない場合* の描き分けを述べたもので、値を指定している今回の状態を説明していない)。

対称 DSL を製品価値とするライブラリで、同じ引数名・同じ意味の色に対して呼び出し側の書き方が変わる点は、Sample の書き分けではなく本体の契約の問題として残す必要がある。

**推奨修正**: `deviation.md` に「`touchFeedbackColor` の不透明度の扱いがプラットフォーム間で非対称 (iOS = 呼び出し側が指定、Android = ripple が付与)。Sample は同じ見え方になる値を各々渡している」を本体側の統一課題として記録し、`evidence/sample-parity-comparison.md` の「不一致」節をその追跡へ差し替える (「なし」の断定をやめる)。統一の方向 (Android も渡された不透明度を尊重する / iOS も一定の不透明度を掛ける / 契約として明文化して doc コメントに書く) の決定自体は本 change のスコープ外でよく、後続 change か ADR へ送る。

### [🟡 Minor] 回転すると各デモ画面の選択状態が初期値へ戻る (`remember` が構成変更をまたがない)

**該当箇所**: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/FixedGridDemoScreen.kt:26` / `ListDemoScreen.kt:28-29` / `SpacingPaddingDemoScreen.kt:30-31` / `HeightChangeVerificationScreen.kt:35-37`

**問題点**: 実機 (エミュレータ) で確認。「グリッド (固定列)」で list を選んでから縦 → 横 → 縦と回すと、選択が grid (初期値) に戻る。「リスト」の区切り線 3 択、「スペーシングと余白」の 2 つの滑り操作、検証画面の経路 / レイアウト / 展開行も同様に失われる。いずれも `remember` を使っており、Activity 再生成で composition ごと破棄されるため。iOS の `@State` は回転で失われないので、同じ操作をしたときの Sample の振る舞いがプラットフォーム間で食い違う。

Sample は「同じ宣言内容が OS 標準 chrome の中でどう描かれるか」を人が見て確かめる装置であり、回転は「向きで列数変更」以外の画面でも検証手順に含まれる (lessons/inbox の回転確認)。回転のたびに設定が戻ると、layout 切替 → 回転 → 表示確認という手順そのものが成立しない。

**推奨修正**: デモ画面と検証画面の選択状態を `rememberSaveable` にする (`Set<Int>` の展開状態は `rememberSaveable` + saver、または `List<Int>` で保持)。あわせて「回転しても選択が保たれる」ことを `SampleDemoScreenTest` に 1 件足せると、静止画では出ないこの型を検証層に載せられる。

### [🟡 Minor] 起動時の経路指定で開いた画面が、回転のたびに back stack へ積み増される

**該当箇所**: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/SampleNavHost.kt:71-76` / `MainActivity.kt:17`

**問題点**: 実機 (エミュレータ) で確認。追加情報 `ks_start_route` を付けて起動した後、回転しないで戻ると 1 回でルートメニューへ戻る。1 度でも回転すると、戻る操作をしても同じデモ画面が表示されたままになる (2 回転させると 3 回押しても抜けられずアプリごと終了した)。

`MainActivity` は `configChanges` を宣言していないため回転で再生成され、`intent` には追加情報が残ったままなので `LaunchedEffect(startRoute)` が再び発火して同じ経路へ `navigate` する。`navController` の back stack は `rememberSaveable` で復元されているため、同じ宛先が重複して積まれる。

この経路は目視照合と計測の入口 (`evidence/sample-parity-comparison.md`「照合の手順 (再現方法)」が案内している手順) なので、照合作業中に回転を挟むと戻る導線が壊れる。

**推奨修正**: 起動時の経路指定を 1 回だけ消費する (例: `rememberSaveable { mutableStateOf(false) }` で消費済みを覚える、または `navigate` 後に `intent.removeExtra(SampleRoutes.StartRouteExtra)` する)。

### [🟡 Minor] 承認モックが検証画面の行に与えている副文字色が実装されておらず、brief の照合結果は「一致」と記録している

**該当箇所**: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/RootMenuScreen.kt:44-58` / `ui/mock/variant-android.html:46` / `ui/brief.md`「照合結果」

**問題点**: 承認モックはルートメニューの「検証: 行の高さ変化 (Android 固有)」行だけ `color:var(--text2)` (= `SampleTheme.secondaryText` #6E7076) で描き、デモ画面の行と視覚的に区別している。実装の `MenuRow` は全行を `SampleTheme.text` で描くため、この区別が無い (`ui/verification/root-menu.png` でも確認できる)。brief の照合結果は「構造・トークン・意図の 3 点で一致を確認」と書いており、トークンの差が拾われていない。

sample-parity の「ルートメニュー上でデモ画面と明確に区別する」は文言 (「検証:」) で満たされているため規約違反ではない。また iOS 側は両区分を同じ配色で描いており、モックに合わせると iOS と食い違う。つまりこれは「モックに合わせる」か「iOS に合わせる」かの選択であって、どちらでもよい代わりに**選んだ事実が記録されていない**のが問題。

**推奨修正**: 検証画面の行を `SampleTheme.secondaryText` にしてモックへ合わせるか、iOS に合わせる判断を採って brief の照合結果に「モックの副文字色は iOS 実装に合わせて採らなかった」と 1 行残す (後者ならオーナー確認が要る)。

### [🔵 Suggestion] メモリの定常判定が「減少」も 2% 以内として通し、全項目通過の自己確認を持たない

**該当箇所**: `samples/android/app/src/measurement/kotlin/jp/kamusoft/kscollectionview/samples/android/MemoryRoundTripScreen.kt:117-123` (`isSteady`) / `evidence/performance-measurement.md`「計測結果: メモリ」の 1,000 件・本計測の行

**問題点**: `isSteady` は `first <= SteadyRatio && second <= SteadyRatio` と符号付きで比べるため、往復間で **−6.49%** 変動しても「定常」と判定される。証跡の 1,000 件・本計測の行 (101,474 → 94,891 → 95,482 KB、増分 −6.49% / +0.62%) はこの経路で「3 往復で定常」と記録されている。「増え続けないこと」を見る意図なら妥当だが、6% 揺れている系列を定常と呼ぶのは、この行だけ他の 3 行 (増分が両方とも +2% 未満) と判定の意味が違う。

あわせて iOS 規約の手順 3 は「各段階の可視セルの項目番号を集合に記録し、往復ごとに全項目を通過したことを件数で確かめる」を求めているが、Android 側は `awaitScrollStep()` が固定 2 フレームを見送るだけで、通過件数の自己確認を持たない。今回レビュアーがカウンタで数えた限りでは走査は全項目を通過していた (上記「自前プローブ」) が、遅い実機や負荷の高い状況で命令が追い越されて間の項目が作られなくなると、**メモリが増えない = 合格**という向きに誤るため、証跡だけからは空振りを見分けられない。

**推奨修正**: (1) `isSteady` を絶対値で比べるか、証跡側で「減少は定常とみなす」と明記する。(2) 走査中に可視項目番号を集合へ足し、往復終了時に件数を進捗の印 (`status`) かログへ出す。計測側は `steady:N` を読むついでにその件数を見られる。

### [🔵 Suggestion] `compileSdk` / `compileSdkMinor` が 3 か所にべた書きで、本体の版変更に追随しない

**該当箇所**: `samples/android/app/build.gradle.kts:18-19` / `samples/android/benchmark/build.gradle.kts:14-15` (本体は `android/kscollectionview/build.gradle.kts:17-18`)

**問題点**: specs/samples の Requirement「Android Sample の器」は「版の宣言元は本体の version catalog 1 箇所とし、Sample はそれを共有する」を求めており、依存ライブラリの版はそのとおり実装されている。一方 `compileSdk` / `compileSdkMinor` はカタログに無く 3 モジュールへ独立にべた書きされている。`deviation.md` の 3 件目 (本体の `compileSdk` を 36 へ、Compose BOM を 1.11 系へ下げる) が入ると、Sample 側の 37.2 だけが取り残され、ライブラリを入れるだけで未普及の SDK Platform を要求するという当の問題が Sample のビルドでは残る。

**推奨修正**: `compile-sdk` / `compile-sdk-minor` を本体カタログの `[versions]` に置き、3 モジュールから同じ値を引く。

**あわせて**: 本レビューのビルド・テスト・計測はすべて `deviation.md` 3 件目の反映**前** (Compose BOM 2026.08.00 / compileSdk 37.2) の構成で行った。版を下げた後は Sample の再ビルドと計測のやり直しが要る。

### [🔵 Suggestion] 計測構成でしか使わない helper が main にあり、release APK に載る

**該当箇所**: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/LargeDataDemoScreen.kt:28-31・59-73`

**問題点**: `KsLargeDataList` と `KsLargeDataGrid` の `scrollController` 引数は `src/measurement` からしか参照されないが、宣言は `main` にあるため release APK に含まれる (release APK の識別子を数えて確認: `KsLargeDataList` 6 件)。「計測用のコードは配布する構成に入れない」という構成分けの意図に対し、ここだけ穴が空いている。

**推奨修正**: `KsLargeDataList` と `scrollController` 付きの入口を `src/measurement` へ移し、`main` には「大量件数」画面が使う形だけを残す。

### [🔵 Suggestion] 計測モジュールのマニフェストのコメントが、宣言している内容を説明していない

**該当箇所**: `samples/android/benchmark/src/main/AndroidManifest.xml:3-6`

**問題点**: コメントは「計測対象アプリのプロセスを観測するために必要な問い合わせ許可」と書いているが、宣言されているのは `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion=29`) で、これは古い API 版で計測結果を書き出すための宣言。comment-policy の「そのファイルだけを読んでいる人にとって意味が通る」に対し、読んだ人を誤らせる。機械検査は禁止参照だけを見るためこの型を拾わない。

**推奨修正**: 「API 29 以前で計測結果ファイルを書き出すために要る」と現在の事実に書き直す。

### [🔵 Suggestion] 単体テストの worker JVM が、他の Gradle 実行と重なると落ちることがある

**該当箇所**: `samples/android/app/build.gradle.kts:58-66` / `samples/android/gradle.properties:7`

**問題点**: `:app:assembleDebug :app:assembleRelease :app:testDebugUnitTest --rerun-tasks` をまとめて実行した回と、その直後の 2 回 (いずれも別プロセスの Gradle と重なっていた。ログに `Detected multiple Kotlin daemon sessions` が出ていた) で、10 件すべて成功して結果 XML も出ているのに `:app:testDebugUnitTest` が `java.io.EOFException` / `Could not execute test class` で失敗した。単独実行では 6 連続で成功したため、実装の欠陥ではなくメモリ競合と見ている (`maxHeapSize = "2g"` × `org.gradle.parallel=true`)。

**推奨修正**: 必須ではない。CI に載せる段で `maxHeapSize` を実測に合わせて下げるか、`--max-workers` を絞る方針を決めておくと、同種の失敗を実装の失敗と読み違えずに済む。

## アクションプラン

1. **(必須)** `touchFeedbackColor` の意味論の非対称を `deviation.md` へ本体側の統一課題として記録し、`evidence/sample-parity-comparison.md` の「不一致: なし」をその追跡へ差し替える (Major)
2. **(必須)** 回転で選択状態が失われる件を `rememberSaveable` で直し、回転をまたぐ 1 件をテストに足す (Minor)
3. **(必須)** 起動時の経路指定を 1 回だけ消費するようにし、回転後も戻る導線が 1 回でメニューへ戻ることを確認する (Minor)
4. **(必須)** ルートメニューの検証画面行の配色について、モックに合わせるか iOS に合わせるかを決めて、後者なら brief の照合結果に残す (Minor)
5. (推奨) メモリ定常判定の符号の扱いを揃え、走査の通過件数を証跡から読めるようにする (Suggestion)
6. (推奨) `compileSdk` をカタログへ寄せる。版を下げた後に Sample の再ビルドと計測をやり直す (Suggestion)
7. (推奨) 計測専用 helper を `src/measurement` へ移す / 計測モジュールのマニフェストのコメントを直す (Suggestion)

## 確認した観点 (指摘に至らなかったもの)

- **画面の集合と文言**: `SampleScreen` / `VerificationScreen` の 9 + 1 件が iOS の同名 enum と順序・文言まで一致。メニューと画面タイトルは同じ宣言元から引いており、二重管理がない
- **デモ画面の構成**: 「リスト」「グリッド (固定列)」「グリッド (adaptive)」「向きで列数変更」「テンプレート切り替え」「ルートヘッダー/フッター」「スクロール制御」「スペーシングと余白」「大量件数」の 9 画面と検証画面を iOS のソースと直接突き合わせ、件数 (6 / 9 / 18 / 18 / 30 / 6 / 100 / 18 / 10,000)・初期値 (区切り線=既定、layout=grid、spacing=4 / padding=8、経路=親 state)・選択肢の文言・DSL パラメータ (fixed 3 / adaptive 120 / portrait 2・landscape 4 / rowSpacing・columnSpacing / contentPadding / `scrollTo(50, Center)`) が一致することを確認
- **`SampleTheme`**: accent・背景・セル・テキスト主副・区切り線・9 色の swatches・寸法定数 6 件すべてが iOS の RGBA と一致 (`SampleTheme.swift` の分数表記を 8bit に直して照合)
- **composite build の明示置換**: `settings.gradle.kts` の `dependencySubstitution` で `jp.kamusoft:kscollectionview` → `project(":kscollectionview")`。本体を含む `:android:kscollectionview:*` タスクが Sample のビルドで実行されており、公開版へのフォールバックは起きていない
- **公開識別子**: application ID `jp.kamusoft.kscollectionview.samples.android`、Sample の namespace 同値、計測モジュールは `.benchmark` 付き。cross/ADR-0003 の写像表どおり
- **計測用コードの release 除外**: source set の差し替え (`measurement` / `noMeasurement`、`counterEnabled` / `counterDisabled`) が効いており、release APK に比較対象画面・自動往復画面・計数の実装がいずれも入っていない (APK の識別子を数えて確認)
- **計測の再現性**: 基準機で benchmark が動き、証跡と同じ桁の値が出る。3 試行の集計に対して判定する deviation の扱いも、外れ値が比較対象側にも出る様子を含めて再現した
- **ローカル絶対パス / 個体識別子**: `local.properties`・`build/`・`.gradle/`・`.kotlin/` は `.gitignore` に載っており追跡対象に入らない。lint 3 種も 0 件
- **コメント**: 外部参照は `<domain>/ADR-NNNN` 形式のみ (4 種 10 件)。作業文書のパス・変更識別子・Decision 番号の裸参照はない
