# Android ラッパー基盤

Compose Lazy 系 (`LazyColumn` / `LazyVerticalGrid`) の薄いラッパー。リスト・グリッドの表示まで。phase-2 と並行可。

## 論点

(出尽くした — 2026-09-04 に 8 論点すべてを決定事項へ昇格済み。DSL の外形は core/ADR-0002〜0009 と [dsl-samples.md](../phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md) で確定済み)

proposed のまま持ち越した core/ADR-0010・core/ADR-0011・ios/ADR-0007 は、Android 実装と突き合わせてから accepted にする (オーナー判断 2026-09-04。突き合わせ方は決定事項「テンプレート解決と項目識別」「セルの装飾と入力」に記載)。

## 決定事項

### 値キーテンプレートの推論形 — builder の `buildExpression` で成立させ、iOS 修正を本フェーズの change に同梱 (2026-09-04)

core/ADR-0004 と dsl-samples の推論形 `Template(.message) { item in ... }` をそのまま正とする。コンパイル失敗の原因は result builder が各宣言を独立した文として型付けし `Item` / `Key` が決まらないことで、ビルダー (`KsTemplateBuilder`) に `buildExpression` を足して各宣言へ文脈型を与えると推論が通る (Swift 6.3.2・iOS 16 simulator ターゲットで、本体と同構造の再現コードにて確認。同じ再現コードで `buildExpression` なしは deviation.md と同じ内部エラー)。公開 API の外形と決定文書は変えない。iOS 側の修正 (builder・iOS Sample・dsl-samples の明示形を推論形へ戻す) は本フェーズの change に同梱し、tasks の最初のグループとして Android 着手前に済ませる。

### `Template` は `KsTemplate` に改名する (2026-09-04)

公開型はほかがすべて `Ks` 接頭辞であり、`Template` は利用者側の同名型と衝突しやすいため `KsTemplate` に改名する。Kotlin 側はテンプレート登録がスコープ関数 `template(key) { }` で対応する公開型を持たないため改名対象はなく、型 `KsTemplate` ⇔ 関数 `template` の対応は core/ADR-0002 の流儀差の範囲。改名は推論形対応と同じ tasks グループで行い、dsl-samples と iOS Sample を追随させる。core/ADR-0004 は accepted で不変のため例示は触らず、経緯は history に残す。

### Sample scaffold — KsSettingsView の Android Sample と同型 (2026-09-04)

`samples/android/` は `../KsSettingsView/samples/android/` の翻案とする。本体参照は composite build (`settings.gradle.kts` の `includeBuild("../../android")`) に**明示の** `dependencySubstitution` (`jp.kamusoft:kscollectionview` → `project(":kscollectionview")`) を組み合わせ、Sample の依存記述は利用者と同じ `implementation("jp.kamusoft:kscollectionview:…")` 1 行にする (自動置換は失敗時に公開版へ静かにフォールバックし本体修正が映らなくなるため明示にする)。版は本体の `gradle/libs.versions.toml` を `versionCatalogs` で共有する (composite build は plugin 版を継承しない)。

画面骨格は `enum class SampleScreen(val title: String)` を画面一覧・タイトルの単一定義元とし、iOS の 9 デモタイトルを一字一句で持って `when` で各デモ Composable にディスパッチする。Android 固有の検証画面は `VerificationScreen` として別 enum・メニュー上も別区分 (iOS と同型)。遷移は Navigation Compose、ルートメニューは `Scaffold` + `TopAppBar` + リスト、各デモは戻るボタン付き `TopAppBar` の共通ラッパーで包む。`object SampleTheme` は iOS `SampleTheme.swift` と同じ RGBA (accent / background / cell / text / secondaryText / separator / swatches 9 色) と寸法定数を持つ。成立後に local-development-setup の Android 節と `SampleScreen` の定義元パスを追記する。

### ラッパー構成 — 変換先を `LazyVerticalGrid` に統一、list は 1 列グリッド (2026-09-04)

DSL → Lazy DSL の変換先は `LazyVerticalGrid` のみとし、layout 値が list のときは `GridCells.Fixed(1)` で描く ([android/ADR-0001](../../../../decisions/android/0001-unified-lazy-grid-rendering.md)、proposed)。スクロール状態は `LazyGridState` 1 種で `KsScrollController` の attach 先も 1 経路。list ⇔ grid 切替で Composable が入れ替わらないためスクロール位置が保たれ、phase-1 申し送りの「レイアウト切替時のスクロール位置維持」はこれで解消。

変換層の骨格: `@DslMarker` 付きの `KsCollectionViewScope<Item>` が `template(key) { }` を集めてキー → Composable の対応表を作り (content ラムダは毎回評価)、`LazyVerticalGrid(columns, state, contentPadding)` の中に header (全幅 span) / `items(items, key, contentType = テンプレートキー)` / footer (全幅 span) を並べる。1 列グリッドの性能が `LazyColumn` と同等かは Sample「大量件数」画面で実測する。

### ビルド構成 — 単一モジュール + explicitApi strict、Compose BOM は最新安定に追随 (2026-09-04、論点 1)

`android/kscollectionview` の 1 モジュール (パッケージ `jp.kamusoft.kscollectionview`、`src/main/kotlin`)、minSdk 29 / compileSdk 最新 / JDK 17。版は `gradle/libs.versions.toml` を単一定義元にして Sample と共有し、AGP・Kotlin・Compose BOM は実装時点の最新安定版 (2026-09 時点 BOM 2026.08.00 = foundation 1.12.0 / material3 1.4.0)。Navigation Compose は BOM 外で個別指定。`explicitApi()` strict、binary-compatibility-validator なし。maven-publish は配布フェーズへ ([android/ADR-0002](../../../../decisions/android/0002-single-module-latest-compose-bom.md)、proposed)。

### テンプレート解決と項目識別 — `key` は `Any` のまま Bundle 保存可能な型を契約に (2026-09-04、論点 2)

`key: (Item) -> Any` の宣言は dsl-samples のまま維持し、ID の型は Bundle に保存できる型 (String / 数値 / enum / `Serializable` / `Parcelable`) であることを利用契約として明記する。Compose の Lazy 系は保存できない key を初回表示時に例外で落とすため、契約違反は debug のライブラリ側 assertion と Compose の例外で気づく形にする。`String` 等への型の絞り込みは Swift (`Identifiable` / `id:`) より狭くなるため、ライブラリが `Parcelable` 等で包む案は衝突・復元不整合と KMP での expect/actual を抱えるため却下。

| 項目 | 内容 |
|---|---|
| `contentType` | テンプレートキーをそのまま渡す。単一テンプレート形は固定の内部センチネル |
| 未登録テンプレートキー | debug は assertion、release は最小高の空セル + 警告ログ (core/ADR-0011)。空セルの高さ・ログ文言は iOS に揃える |
| 重複 ID | Compose 自身が重複 key で例外を投げるため、ライブラリが `items()` に渡す前に後勝ちで重複を除いて警告ログを出す (release)。debug は assertion。これで core/ADR-0011 の「後勝ちで継続」が Android でも成立する |

### layout 値の変換 — 向きはコンテナ自身の縦横比で判定し、列数を決めてから `GridCells` を作る (2026-09-04、論点 3)

向き別列数 (`KsColumns.Fixed(portrait, landscape)`) の判定は iOS (`KsLayoutMetrics`) と同じ「コンテナの `height > width` なら portrait」の規則とし、`BoxWithConstraints` で得たサイズから列数を決めて `LazyVerticalGrid` に渡す。端末の向き (`LocalConfiguration.orientation`) は分割画面・タブレット・折りたたみで iOS とずれるため却下。`GridCells` が変わっても同じ Composable・state のためスクロール位置は保たれる (android/ADR-0001)。

| DSL | Lazy DSL |
|---|---|
| `KsLayout.List(rowSpacing)` | `GridCells.Fixed(1)` + `verticalArrangement = spacedBy(rowSpacing)` |
| `KsColumns.Fixed(n)` / `Fixed(portrait, landscape)` | `GridCells.Fixed(n)` (向き判定後の値) |
| `KsColumns.Adaptive(minItemWidth)` | `GridCells.Adaptive(minItemWidth)` (余りを列に均等配分 — core/ADR-0006 と一致) |
| `rowSpacing` / `columnSpacing` / `contentPadding` | `verticalArrangement` / `horizontalArrangement` の `spacedBy` / `contentPadding` そのまま |

不正値 (列数 0 以下・負の spacing) は iOS 同様 debug で assertion。

### スクロール制御 — 命令をキューに積み、コンポジション後に最新の配列で解決する (2026-09-04、論点 4)

`KsScrollController` は plain class (`rememberKsScrollController()` は View 所有用の糖衣) で、iOS と同じく receiver への参照 1 本を持ち、未接続・切断後は no-op、複数接続は最後勝ち (debug で警告)。`KsCollectionView` 内の `DisposableEffect(controller)` で attach / detach する。命令は receiver (Composable 内部の状態オブジェクト) の snapshot state のキューに積み、`LaunchedEffect(items, キュー)` がコンポジション後にそのとき描画されている配列で ID → index (ヘッダー分の +1 込み) を解決して `LazyGridState.scrollToItem` / `animateScrollToItem` を呼ぶ。配列更新と同じ処理で呼ばれた命令が同じ再コンポジションで届くため「データ反映後に実行」(core/ADR-0007) が構造的に成立する。対象 ID が無ければ no-op (debug で警告)。`.center` / `.end` は Compose の `scrollToItem` が先頭揃えのみのため 2 段階 (可視化 → `layoutInfo` の項目サイズで `scrollBy` 補正)。公開 API はメインスレッドから呼ぶ契約 (debug で assertion)。命令を受けた瞬間に実行する案は、古い配列で ID を引くため却下。

### セルの装飾と入力 — 区切り線の色は `listSeparatorColor`、タップは `combinedClickable`、content は `Box(TopCenter)` で包む (2026-09-04、論点 5)

| 項目 | 内容 |
|---|---|
| 区切り線の色 | 独立した語彙 `listSeparatorColor` (Swift `.listSeparatorColor(_:)` / Kotlin `listSeparatorColor =`) を追加。既定 `#D9D9DE`、`listSeparators` (表示の有無) とは別語彙で 2 語彙が 1 対 1。core/ADR-0010 の本文に反映済み (proposed のまま、Android で突き合わせ後 accepted)。iOS 側は現状 `listSeparators(Bool)` のみで色は内部固定値のため、iOS の追加も本フェーズの iOS 追随グループに同梱する |
| 区切り線の描画 | ADR-0010 どおり (先頭行上端・行間・最終行下端、全幅、1dp、list のみ、既定表示) を項目の `drawBehind` で描く |
| タップ / 長押し / フィードバック | ハンドラが宣言された項目だけを `combinedClickable` (`onClick` / `onLongClick`) で包む。排他とセル内操作要素の優先は Compose のポインタ処理で成立。フィードバックは標準 ripple、`touchFeedbackColor` 指定時は material3 の `ripple(color)` |
| content 配置 | セル content を `Box(contentAlignment = TopCenter)` で包み、ios/ADR-0007 の「縦: 自然高で上端固定・行高を提案しない、横: 自然幅が狭ければ中央・幅いっぱいなら先頭から」を再現する。`LazyVerticalGrid` は項目を行高に引き伸ばさないため縦は自然に一致。これで ios/ADR-0007 は両プラットフォーム共通の規則として accepted にできる見込み |

### Pull to Refresh — 外形だけ確認して phase-5 に申し送り、本フェーズでは実装しない (2026-09-04、論点 6)

iOS に対応物が無い (phase-2 の範囲外) ため、Android だけ先行実装すると sample-parity の片側先行の追跡が残る。両プラットフォームを同時に扱う phase-5 で実装する。流儀の答え: `onRefresh: (suspend () -> Unit)?` を引数で受け、Swift の `.refreshable { await }` と同じ「非同期処理が終わるまでインジケータを出す」意味論にする。ライブラリが `LazyVerticalGrid` を material3 の `PullToRefreshBox` (1.4 系で stable) で内包し、`isRefreshing` は「`onRefresh` 実行中」または `KsPagingState.Refreshing`。`onRefresh` 未指定なら `PullToRefreshBox` を挟まない。利用者が自分で包む形は DSL の外になり非対称なので採らない。[phase-5 agenda](../phase-5-paging-state-machine/agenda.md) に申し送り済み。

### 再利用・性能の検証と既定 — iOS 規約の対を Macrobenchmark で自動計測、cache window は Compose 既定 (2026-09-04、論点 7)

| 項目 | 内容 |
|---|---|
| 土俵 | Sample「大量件数」画面。iOS と同じ fixture (10,000 件・2 列グリッド・固定高と 7 件ごとの長文の混在・整数 ID の決定的生成) |
| スクロール性能 | `benchmark` モジュール (Jetpack Macrobenchmark) が Release 相当の Sample を起動し、実座標フリック 3 秒 × 3 試行。`FrameTimingMetric` の `frameOverrunMs` / `frameDurationCpuMs` の P50 / P90 / P99 を記録。合格線は基準機 Pixel 4a (参考 Pixel 6a) の初回計測で校正して規約に固定 (見当: P90 が overrun なし、P99 が 1 フレーム未満) |
| メモリ | 同じ走査を往復し `MemoryUsageMetric` (PSS) で iOS と同じ判定 (連続 2 往復の増分が 2% 以内で定常、上限 10 往復) |
| 再利用の確認 | Sample の debug 構成にテンプレート呼び出し回数のカウンタを置き、Layout Inspector の再コンポーズ回数と合わせて目視確認。定常状態でカウンタが可視セル数程度で頭打ちなら再利用成立 |
| `LazyLayoutCacheWindow` | v1 は `LazyVerticalGrid` の既定に従い、公開 API にも内部既定にもしない。計測で hitch が出たら設定を検討 |
| 規約化 | `handbook/android/performance-verification.md` を iOS 規約 (handbook/ios/performance-verification.md) の対として起こす |

手動計測 (Perfetto / `dumpsys gfxinfo`) は準備は軽いが再現性が人の操作に依存するため却下。

### 行の高さ変化の検証画面 — Android 固有の技術検証画面として置く (2026-09-04、論点 8)

「検証: 行の高さ変化 (Android 固有)」を `VerificationScreen` に置く (iOS の「検証: 行の高さ変化 (iOS 固有)」と同じ区分。sample-parity の固有検証画面の例外枠に収まり、9 デモの集合は動かさない)。構成は iOS と同じ「展開経路 2 種 (親 state / テンプレート内 state) × list / grid 切替」で行タップで展開/折りたたみ。確かめること: 高さ変化時の `animateItem` / `animateContentSize`、`Box(TopCenter)` による content 配置、テンプレート内 state が再コンポーズをまたいで保持されるか (ios/ADR-0002 との差)。親 state 経路は [template-parent-state-observation](../../../../changes/template-parent-state-observation/exploration.md) との対称性を見る場を兼ねる。共通デモへの昇格 (iOS 側の改修と 10 デモ化が要る) は必要になったら改めて決める。

## TODO

- [x] 論点の解消 (2026-09-04 全 8 論点を決定事項へ昇格)
- [x] 提案化時: iOS の推論形対応 (`KsTemplateBuilder` の `buildExpression`)、`Template` → `KsTemplate` 改名、`listSeparatorColor` の iOS 側追加 (現状は内部固定値のみで未実装)、iOS Sample・dsl-samples の追随を tasks の最初のグループに載せる
- [x] [dsl-samples.md](../phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md) への `KsTemplate` 改名と `listSeparatorColor` の反映 → change の tasks 1.5 に移管 (2026-09-04)
- [x] ksn-propose で変更提案を起こす (android-wrapper-foundation、2026-09-04。dsl-samples の追随と iOS 追随は change の tasks グループ 1 へ)
