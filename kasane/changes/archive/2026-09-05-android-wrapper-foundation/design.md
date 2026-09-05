# Design: android-wrapper-foundation

## Context

Android の描画は Compose Lazy 系の薄いラッパーである (core/ADR-0001)。公開 DSL の外形は core/ADR-0002〜0009 と dsl-samples の Kotlin 側で確定済み、Android 側の骨格は phase-3 の議論で android/ADR-0001 (`LazyVerticalGrid` 統一) と android/ADR-0002 (単一モジュール・最新安定 BOM) として決定済み。本 design は、それらを実装可能な粒度に落とした判断を記録する。iOS 実装 (ios-engine-foundation) が挙動の正として先行しており、concepts/core の契約 (collection-items / collection-layout / collection-interaction) に Android が追随する。

## Goals / Non-Goals

Goals / Non-Goals は proposal.md のとおり。本 design は「どう作るか」の判断だけを扱う。

## Decisions

### Decision 1: 変換層は「スコープで宣言を集めて 1 つの Composable が Lazy DSL に流す」2 段構成にする

**採用案:** 利用者の content ラムダ (`KsCollectionViewScope<Item>.() -> Unit`) を毎コンポジションで評価し、`template(key) { }` の登録をキー → `@Composable (Item) -> Unit` の対応表に集める。単一テンプレート形 (`template<Item> { }`) は内部センチネルキーへの登録として同じ表に載る。`KsCollectionView` 本体はこの表と引数を `LazyVerticalGrid` に流す 1 つの Composable で、Store 層や差分計算層は持たない (差分は Compose の `key` に委ねる — concepts/core/core-model/collection-items.md)。

```kotlin
@DslMarker public annotation class KsCollectionDsl

@KsCollectionDsl
public class KsCollectionViewScope<Item> internal constructor() {
    public fun template(key: Any, content: @Composable (Item) -> Unit)
    public fun template(content: @Composable (Item) -> Unit)   // 単一テンプレート形
}
```

**理由:** KsSettingsView の DSL 表層 (スコープ + `@DslMarker`、登録を中間表に貯める) と同じ作法で、変換先だけが Lazy DSL になる (scout 調査)。content ラムダを毎回評価するのは、テンプレートが親の state を捕捉する書き方 (ios/ADR-0006 と同じ体験) を成立させるため — 評価コストは登録数 (数個) に比例するだけ。`key` / `template` セレクタと登録集合の表示中の差し替えは、iOS と同じく契約上サポートしない (concepts/core/core-model/collection-items.md「してはいけないこと」)。Android で偶然反映されても契約にはしない。同じキーへの二重登録は core/ADR-0011 どおり debug assertion / release 後勝ち + 警告ログ。`@DslMarker` は同一マーカーを持つ暗黙 receiver 同士の混線を防ぐだけで、content ラムダ (`(Item) -> Unit`、receiver なし) の中から外側スコープの `template` を呼ぶことは Kotlin の言語規則上禁止できない — これは契約にしない (呼んだ場合の登録は次のコンポジションの評価で拾われるか無視されるかを保証しない)。
**代替案:**
- **A: content ラムダを `remember` して初回だけ評価する** — 親 state を捕捉したテンプレートが更新されず、iOS (ios/ADR-0006) と挙動が食い違うため却下
- **B: KsSettingsView と同じく Store + 差分計算を持つ** — 差分は Compose Lazy の `key` が担うため二重になる。android/ADR-0001 の「薄いラッパー」に反するため却下

### Decision 2: 向き判定は `BoxWithConstraints` で行い、列数を決めてから `GridCells` を作る

**採用案:** `KsCollectionView` の最外殻を `BoxWithConstraints` にし、`maxHeight > maxWidth` を portrait と判定して `KsColumns.Fixed(portrait, landscape)` の列数を解決する。解決後の列数から `GridCells.Fixed(n)` を、`KsColumns.Adaptive(minItemWidth)` は `GridCells.Adaptive(minItemWidth)` を、list は `GridCells.Fixed(1)` を作って同一の `LazyVerticalGrid` に渡す。`rowSpacing` / `columnSpacing` は `verticalArrangement` / `horizontalArrangement` の `spacedBy`、`contentPadding` はそのまま。
**理由:** iOS (`KsLayoutMetrics`) と同じ「コンテナ自身の縦横比」の規則で、分割画面・タブレット・折りたたみでも両プラットフォームの列数が一致する (agenda 論点 3)。
**代替案:**
- **A: `LocalConfiguration.current.orientation` (端末の向き)** — 分割画面等でコンテナの縦横比と食い違い、iOS とずれるため却下
- **B: 独自 `GridCells` 実装で `calculateCrossAxisCellSizes` 内で判定する** — 利用可能サイズは幅しか渡らず高さが取れないため却下

### Decision 3: `key` は利用契約 (Bundle 保存可能な型) で担保し、重複 ID はライブラリの前処理で後勝ちにする

**採用案:** `key: (Item) -> Any` の戻り値は Bundle に保存できる型 (String / 数値 / enum / `Serializable` / `Parcelable`) であることを利用契約とし、ライブラリでは包まない。`items()` に渡す前に配列を走査して (1) 重複 ID を後勝ちで除去し警告ログ、(2) 未登録テンプレートキーを検出 — いずれも debug では assertion、release では継続 (core/ADR-0011)。未登録キーの要素は最小高の空セル + 警告ログ (件数は配列と一致)。`contentType` にはテンプレートキーをそのまま渡す。
**理由:** Compose の Lazy 系は保存できない key を初回表示時に例外で落とし、重複 key も例外にするため、ADR-0011 の「落とさず・消さず・黙らず」をライブラリ側で成立させる必要がある。包む案は衝突・復元不整合を抱える (agenda 論点 2、scout 調査)。
**代替案:**
- **A: `key` を `String` / `Long` に型で絞る** — Swift (`Identifiable` / `id:`) より狭く非対称のため却下
- **B: ライブラリが `Parcelable` ラッパーで包む** — `hashCode` 衝突・`toString` の identity 依存・KMP での expect/actual が要るため却下

### Decision 4: スクロール命令はキューに積み、`LaunchedEffect` でコンポジション後に最新の配列で解決する

**採用案:** `KsScrollController` は plain class。内部の receiver (Composable 内で `remember` される状態オブジェクト) に `DisposableEffect(controller)` で attach / detach する。命令は receiver のキュー (snapshot state) へ積む。消費側は **Composition の生存期間に 1 本だけ**立てる `LaunchedEffect(receiver)` の coroutine で、`snapshotFlow` でキューの変化を待ち、命令を FIFO で 1 つずつ取り出して、その時点の最新の配列 (`rememberUpdatedState` 経由) で ID → index (ヘッダー分の +1 込み) を解決し `LazyGridState.scrollToItem` / `animateScrollToItem` を呼ぶ。配列更新で effect を再起動しない (キー付き `LaunchedEffect(items, …)` は配列更新のたびに実行中のアニメーションをキャンセルし命令が消えうるため)。コンポジション後に消費されるため「配列更新と同じ処理で出た命令が更新後の配列で解決される」は保たれる。後の命令は `LazyGridState` の相互排他により先行アニメーションを中断して優先する (最終位置は最後の命令)。`.center` / `.end` は対象を可視化してから `layoutInfo` の項目サイズで `scrollBy` 補正する 2 段階で、補正量はスクロール可能範囲で clamp される (先頭・末尾付近や表示範囲より大きい項目は端で止まるか先頭合わせ)。位置の基準は `contentPadding` 内側の表示範囲。存在しない ID・削除済みの対象は no-op (debug で警告) で後続へ進む。公開 API はメインスレッドから呼ぶ契約 (debug で assertion)。
**理由:** 配列更新と命令が同じ再コンポジションで届くため「データ反映後に実行」(core/ADR-0007) が構造的に成立し、iOS の「apply completion で flush」と同じ意味になる (agenda 論点 4)。
**代替案:**
- **A: 受信した瞬間に `animateScrollToItem` を起動する** — まだ再コンポジションされていない古い配列で ID を引き、追加した末尾へ届かないため却下

### Decision 5: 区切り線は項目の `drawBehind` で描き、色は `listSeparatorColor` で変える

**採用案:** list (1 列) のときだけ、各項目の Composable を包む Modifier の `drawBehind` で「先頭項目は上端に 1 本、全項目の下端に 1 本」を左右全幅・1dp で描く (core/ADR-0010 の位置・太さ)。既定色は iOS と同じ固定値 `#D9D9DE`、`listSeparatorColor: Color? = null` で変更できる。`listSeparators = false` で全て描かない。grid では描かない。
**理由:** 項目単位の描画は `LazyVerticalGrid` の再利用と両立し、`rowSpacing > 0` のときも iOS と同じ「セルの底辺」に線が出る (concepts/core/styling/collection-layout.md の帰結と一致)。
**代替案:**
- **A: 行間に区切り線用の item を挿入する** — 項目数が倍になり `key` / `contentType` / スクロール index の解決が複雑化するため却下
- **B: material3 `HorizontalDivider` をテンプレートの外に足す** — 独立した Composable が増えて再利用単位が割れるため却下

### Decision 6: タップは `combinedClickable`、フィードバックは material3 の ripple、content は `Box(TopCenter)` で包む

**採用案:** `onItemTap` / `onItemLongTap` のいずれかが宣言された場合だけ、項目のルートを `combinedClickable(onClick, onLongClick)` で包む。indication は `touchFeedbackColor` 未指定なら material3 の標準 ripple、指定時は `ripple(color = …)`。項目 content は `Box(modifier = fillMaxWidth(), contentAlignment = Alignment.TopCenter)` で包み、content が幅いっぱいに広がらないときは中央、広がるときは先頭から敷く (ios/ADR-0007 の横規則)。縦は `LazyVerticalGrid` が項目を行高に引き伸ばさないため自然高で上端固定になる (同 ADR の縦規則)。ライブラリは `androidx.compose.material3` に依存する。
**理由:** タップと長押しの排他、セル内の操作要素が先にタッチを消費する点は Compose のポインタ処理でそのまま成立し、concepts の契約 (collection-interaction.md) と一致する。ripple を material3 から取ることで、利用者アプリのテーマに関わらず既定のフィードバックが標準 ripple になる (agenda 論点 5)。
**代替案:**
- **A: foundation の `LocalIndication.current` だけを使い material3 に依存しない** — `MaterialTheme` を置かないアプリでは既定 indication がデバッグ用の塗りになり「既定は標準 ripple」の契約が崩れるため却下。material3 は Pull to Refresh (phase-5) でも必要になる
- **B: content を包まず素の item scope に置く** — Compose は項目幅を固定するため狭い content が左寄せになり、iOS (中央) とずれるため却下

### Decision 7: Sample は KsSettingsView 同型の composite build + enum 駆動の画面骨格にする

**採用案:** `samples/android/settings.gradle.kts` で `includeBuild("../../android")` + 明示の `dependencySubstitution` (`jp.kamusoft:kscollectionview` → `project(":kscollectionview")`)、`versionCatalogs` で本体の `libs.versions.toml` を共有。`app` の依存は利用者と同じ `implementation("jp.kamusoft:kscollectionview:…")` 1 行。`enum class SampleScreen(val title: String)` が 9 デモのタイトル (iOS `SampleScreen.swift` と一字一句同じ) の単一定義元、`VerificationScreen` が「検証: 行の高さ変化 (Android 固有)」を持つ。遷移は Navigation Compose、共通ラッパーは `Scaffold` + `TopAppBar`。`object SampleTheme` は iOS `SampleTheme.swift` と同じ RGBA と寸法定数。
**理由:** 配布座標 (cross/ADR-0003) の実地確認を兼ね、local-development-setup の Android 節を翻案で埋められる (agenda「Sample scaffold」)。
**代替案:**
- **A: `project(":kscollectionview")` 直依存 + state による画面切替の最小構成** — 配布座標の検証と手引きの流用を失うため却下

### Decision 8: 性能検証は Macrobenchmark モジュールで固定手順を自動実行する

**採用案:** `samples/android/benchmark` (Macrobenchmark) を置き、Sample の「大量件数」画面 (iOS と同じ fixture: 10,000 件・2 列グリッド・固定高と 7 件ごとの長文の混在・整数 ID の決定的生成) を対象に計測する。合格線は 2 段: (1) **比較対象との相対**: 同じ fixture を素の `LazyVerticalGrid` で描いた計測用画面 (Sample に debug 限定で同梱) に対し、`FrameTimingMetric` の `frameOverrunMs` P90 / P99 の劣化が 10% 以内 — ラッパーが薄いこと (android/ADR-0001) の直接の検証で、候補実装だけを測る循環を避ける。(2) **絶対上限**: P99 の `frameOverrunMs` を初回計測で校正して固定 (以後の回帰検出用)。手順: `CompilationMode.Partial`、warmup 1 回、実座標フリック 3 秒 × 3 試行 (`StartupMode` は使わない)。メモリは `MemoryUsageMetric(Mode.Last, subMetrics = [memoryRssPss / memoryHeapSize])` を往復終了時点で取り、iOS と同じ定常判定 (連続 2 往復の増分が 2% 以内、上限 10 往復)。件数比例の検証は 1,000 件と 10,000 件の定常値の比較で行う。基準機 Pixel 4a (参考 Pixel 6a)、代替はオーナー承認 + 証跡に「基準機の保証にならない」を明記。合格線の校正値は evidence/ に記録し、規約化 (handbook/android/performance-verification.md) は蒸留時に行う。再利用の確認は Sample の debug 構成のテンプレート呼び出しカウンタ + Layout Inspector。
**理由:** iOS の「計測専用 launch 経路 + 固定手順」と同じ再現性を公式の枠組みで得られ、将来 CI にも載る (agenda 論点 7)。
**代替案:**
- **A: Perfetto / `dumpsys gfxinfo` の手動計測** — 人の操作に依存し再現性が落ちるため却下

### Decision 9: iOS 追随は builder の `buildExpression` + 型改名 + modifier 追加で行い、最初のタスクグループに置く

**採用案:** `KsTemplateBuilder` に `buildExpression(_ e: KsTemplate<Item, Key>) -> KsTemplate<Item, Key>` を追加して各宣言に文脈型を与え、推論形 `KsTemplate(.message) { item in … }` を成立させる (再現コードで確認済み — agenda「値キーテンプレートの推論形」)。`Template` を `KsTemplate` に改名する。`listSeparatorColor(_ color: Color)` modifier を追加し、内部固定値を既定として上書きできるようにする。iOS Sample と dsl-samples を追随させる。これらを tasks の最初のグループに置き、Android 着手前に完了させる。
**理由:** Android の DSL を書く前に対称 DSL の外形を確定させるため (オーナー判断)。
**代替案:**
- **A: 明示形を正式化し ADR-0004 / dsl-samples を改訂する** — Kotlin と非対称のため却下 (agenda)
- **B: 別 change に切り出す** — 小さく独立した作業で Android 実装と衝突しないため同梱 (オーナー判断)

## Risks / Trade-offs

- 1 列 `LazyVerticalGrid` の性能が `LazyColumn` と乖離する可能性 → Decision 8 の計測をエンジン中核の直後 (Sample 完成前) に行い早期検知。乖離時は android/ADR-0001 を見直す
- `key` の契約違反は実行時 (初回表示) にしか分からない → debug assertion で早期化。ドキュメント (蒸留時に concepts/android) に明記
- `.center` / `.end` の 2 段階補正は項目の可視化を待つため、アニメーション中に位置がわずかに跳ぶ可能性 → Sample「スクロール制御」で目視確認し、許容できなければ deviation に記録
- material3 依存は利用者への推移依存を増やす → android/ADR-0002 の「最新安定に追随」と同じ受容範囲

## Migration Plan

新規実装のため移行はない。iOS の `Template` → `KsTemplate` は未配布のため利用者影響なし。

## Open Questions

- Macrobenchmark の絶対上限の実値 (Pixel 4a の初回計測で校正。相対 10% は事前に固定)
- `.center` / `.end` の補正の許容差 (clamp 規則は確定。アニメーション後の残差の許容 px は実装時に evidence で決める)

## ADR 候補

- Decision 6 の「ライブラリが material3 に依存する」: 利用者への推移依存 (境界を越える) — 蒸留時に android ドメインで起票を検討
- 骨格判断 (`LazyVerticalGrid` 統一・単一モジュール・最新 BOM) は android/ADR-0001・0002 として起票済み。他は局所的な実装判断のためコード + テストに任せる
