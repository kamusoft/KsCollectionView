# 議論履歴

## 2026-09-04: 値キーテンプレートの推論形 (phase-2 からの申し送り)

phase-2 で `Template(.message) { item in ... }` がコンパイルできず明示形 `Template(Kind.message) { (item: Item) in ... }` で暫定確定していた件。原因を実物で確認: result builder が各宣言を独立した文として型付けするため、宣言単体では `Item` / `Key` が決まらない。scratchpad で本体と同構造を再現し、`KsTemplateBuilder` に `buildExpression` を足すと推論形が通ること (Swift 6.3.2、iOS 16 simulator ターゲット)、無しでは deviation.md と同じ内部エラーになることを確認した。

- 案 A: 推論形をそのまま成立させる (builder に `buildExpression` 追加、Sample と dsl-samples を推論形へ戻す)。文書改訂なし
- 案 B: 明示形を正式化して core/ADR-0004 と dsl-samples を改訂 — 却下。item の型注釈が Swift 側にだけ残り Kotlin `template(Kind.Message) { item -> }` と非対称
- 案 C: builder の入口で型を渡す語彙を足す — 却下。Kotlin に対応物がなく API 面が増える

採用: 案 A。Kotlin との構造 1 対 1 を保ち、キーの書き方 (`.message` / `Kind.Message`) だけが流儀差 (core/ADR-0002 の範囲)。iOS 側の修正は独立した小タスクで Android 実装と衝突しないため、本フェーズの change に同梱し tasks の最初のグループに置く (オーナー判断)。ADR は起票しない (ADR-0004 の宣言形を成立させる実装内部の直しで新しい判断を含まない)。

## 2026-09-04: `Template` の `Ks` 接頭辞 (phase-2 からの申し送り)

公開型のうち `Template` だけが無接頭辞で利用者の同名型と衝突しやすい件。

- 案 A: `KsTemplate` に改名 — 採用
- 案 B: `Template` のまま (衝突は利用者が `KsCollectionView.Template` と修飾して回避) — 却下。1 型だけ命名の例外が残る
- 案 C: `KsCollectionView.Template` の入れ子型 — 却下。宣言が毎行長くなる

オーナーの確認: 案 A は Android の型名も統一する意味か → Swift 側だけ。Kotlin はスコープ関数 `template(key) { }` で公開型を持たないため改名対象がない。Android 側で公開識別子になりうるのはスコープの型で、これは「ラッパー構成」の論点で `Ks` 接頭辞に揃える方針。
文書の追随: dsl-samples (命名の仕様候補) と iOS Sample を更新。core/ADR-0004 は accepted で不変のため例示は触らない。ADR は起票しない (局所的で公開前に可逆)。

## 2026-09-04: Sample scaffold (`samples/android/` の器)

scout で `../KsSettingsView/samples/android/` を調査 (composite build + 明示 substitution、catalog 共有、`SampleScreen` enum が単一定義元、Navigation Compose、`SampleTheme` object)。iOS Sample の実物 (`SampleScreen` 9 タイトル、`VerificationScreen` の別区分、`SampleTheme` の RGBA) と突き合わせた。

- 案 A: KsSettingsView 同型 (利用者と同じ依存 1 行で本体ソース参照、Navigation Compose、enum 駆動の画面骨格) — 採用。配布座標 (cross/ADR-0003) の実地確認を兼ね、手引きの翻案が効く
- 案 B: 最小構成 (`project()` 直依存、state での画面切替) — 却下。配布座標の検証と手引きの流用を失う

ADR は起票しない (iOS の器と同じく規約の具体化)。

## 2026-09-04: ラッパー構成 (DSL → Lazy DSL への変換層)

scout で Compose Foundation の現状を公式リファレンスで確認: `LazyGridScope.stickyHeader` は 1.8.0 で stable、`animateItem` は list / grid 同形 (1.7.0)、`LazyListState` と `LazyGridState` の共通親は `ScrollableState` のみで index 指定スクロールの共通経路なし、`LazyLayoutCacheWindow` は双方で利用可。BOM 最新安定版 2026.08.00 (foundation 1.12.0 / material3 1.4.0)、Compose の minSdk 要件は 23。

- 案 A: `LazyVerticalGrid` に統一、list は `GridCells.Fixed(1)` — 採用。iOS (ios/ADR-0003) と同型、切替でスクロール位置が保てる (core/ADR-0006 の負の帰結が消える)、`KsScrollController` の attach が 1 経路
- 案 B: list は `LazyColumn`、grid は `LazyVerticalGrid` — 却下。切替時の位置補正と state 2 種の自前抽象が要る

オーナーの確認: 統一で失う `fillParentMax*` と snap fling 簡易ヘルパーの意味 → 前者は利用者のテンプレートが生の item scope を触らないため露出せず、後者は吸着スクロールが v1 対象外。ADR android/0001 を proposed で起票 (android ドメイン初の ADR、index 作成)。

## 2026-09-04: agenda の整理 (論点統合)

決定 4 件の後も論点が 14 項目 (本体 6 + phase-1 申し送り 5 + ライブ調整 3 + ADR 確定) で分割トリガー (8 個) を超えていた。テーマはすべて Android ラッパー基盤の内側で単独完了できるサブフェーズに割れないため、ksn-split / 昇格ではなく統合を選択 (オーナー承認)。統合後 8 項目: 1 ビルド構成 / 2 テンプレート解決と項目識別 / 3 layout 値の変換 / 4 スクロール制御 / 5 セルの装飾と入力 / 6 Pull to Refresh の接続 / 7 再利用・性能の検証と既定 / 8 行の高さ変化の検証画面。番号は以後のフェーズ議論で固定して使う。

## 2026-09-04: 論点 1 ビルド構成

scout の KsSettingsView 調査 (2 モジュール、AGP 8.13.2 / Kotlin 2.4.10 / BOM 2025.11.01、minSdk 29 / compileSdk 35 / JDK 17、explicitApi strict、BCV なし) と Compose 公式 (最新 BOM 2026.08.00、Compose の minSdk 要件 23) を材料に議論。

- 案 A: 単一モジュールで KsSettingsView を翻案し、Compose BOM は最新安定に追随 — 採用。cross/ADR-0003 の 1 artifact と整合、bridge 相当の需要なし、主目的の自社アプリは最新追随が前提
- 案 B: foundation 1.8 系の最低版に固定 — 却下。キャッシュ窓・stable な PullToRefreshBox を失い、古い版のバグ回避を背負う

ADR android/0002 を proposed で起票。

## 2026-09-04: 論点 2 テンプレート解決と項目識別

scout で Compose Foundation のソースを確認: Lazy 系の `key` は Bundle 保存可能な型でないと `SaveableStateHolderImpl` の require で初回表示時に即例外 (data class / value class は不可)、`contentType` は型制約なしで等価な値の間だけ再利用、重複 key は Compose 自身が例外。

- 案 A: `key: (Item) -> Any` のまま、Bundle 保存可能な型を契約に明記 + debug assertion — 採用。Swift の `Identifiable` / `id:` と見え方が揃い、実際の ID は String / Long が普通
- 案 B: `String` / `Long` に型で絞る — 却下。Kotlin 側だけ狭くなる
- 案 C: ライブラリが `Parcelable` 等で包む — 却下。衝突・復元不整合の落とし穴と KMP での expect/actual

付随: 重複 ID は Compose が落とすため、ADR-0011 の「release は後勝ちで継続」をライブラリの前処理 (後勝ちの重複除去 + 警告ログ) で成立させる。未登録キーと `contentType` は ADR-0004 / 0011 どおり。ADR は起票しない (公開契約の細目として蒸留時に concepts/android へ)。

## 2026-09-04: 論点 3 layout 値の変換

iOS の実物 (`KsLayoutMetrics`: コンテナの `height > width` で portrait 判定) を確認して議論。

- 案 A: コンテナ自身の縦横比で判定 (`BoxWithConstraints`) — 採用。両プラットフォームで「同じ layout 値 → 同じ列数」の条件が揃う
- 案 B: 端末の向き (`LocalConfiguration.orientation`) — 却下。分割画面・タブレット・折りたたみで iOS とずれる

変換表 (List → `GridCells.Fixed(1)`、Adaptive → `GridCells.Adaptive`、spacing → `spacedBy`、contentPadding そのまま) を決定事項に記載。ADR は起票しない (core/ADR-0006 の実装細目)。

## 2026-09-04: 論点 4 スクロール制御

iOS の実物 (`KsScrollController` は receiver 弱参照、`KsCollectionViewController` のキューを snapshot apply 完了後に flush) と concepts/core/core-model/collection-interaction.md の契約を確認。

- 案 A: キュー + `LaunchedEffect` でコンポジション後に最新配列で解決 — 採用。配列更新と命令が同じ再コンポジションで届くため順序保証が構造的に成立
- 案 B: 受信即時に `animateScrollToItem` — 却下。古い配列で ID を引き ADR-0007 を満たせない

`.center` / `.end` は `layoutInfo` による 2 段階補正、スレッド契約はメインのみ。ADR は起票しない (core/ADR-0007 の実現方法)。

## 2026-09-04: 論点 5 セルの装飾と入力

core/ADR-0010 (区切り線)・ios/ADR-0007 (content 配置)・iOS の modifier 実物 (`onItemTap` / `onItemLongTap` / `touchFeedback(color:)` / `listSeparators(Bool)`) を確認。判断が要ったのは区切り線の色 API の形。

- 案 A: 独立した語彙 `listSeparatorColor` を追加 — 採用。既存の Bool 形を壊さず両側 2 語彙が 1 対 1
- 案 B: `listSeparators` に色引数 — 却下。Kotlin 側で引数が 2 つに割れ対応が崩れる
- 案 C: 表示と色をまとめた値型 — 却下。既存の Bool 形を壊す

タップ系は `combinedClickable` + ripple、content 配置は `Box(TopCenter)` で ios/ADR-0007 を再現 (両プラットフォーム共通規則として accepted 化の見込み)。core/ADR-0010 の本文を改訂 (proposed 維持)。dsl-samples への反映を TODO に追加。

## 2026-09-04: 論点 6 Pull to Refresh の接続

iOS 側に refresh / paging の実装が無く (phase-2 範囲外)、phase-5 agenda に「`.refreshable` / `PullToRefreshBox` の対称ラップ」が既に載っていることを確認。

- 案 A: 外形だけ確認して phase-5 に申し送り、本フェーズでは実装しない — 採用。両プラットフォーム同時に実装でき片側先行の追跡が不要
- 案 B: Android だけ先行実装 — 却下。iOS 未実装の間の追跡と Sample の非対称
- 案 C: DSL に載せず利用者が `PullToRefreshBox` で包む — 却下。非対称で ADR-0005 の見直しが要る

外形 (`onRefresh: suspend () -> Unit`、ライブラリが `PullToRefreshBox` を内包) を phase-5 agenda に申し送った。

## 2026-09-04: 論点 7 再利用・性能の検証と既定

iOS 規約 (handbook/ios/performance-verification.md: 固定 fixture・hitch time ratio 3 回すべて 5 ms/s 未満・メモリ往復の 2% 定常化) を対にする形で議論。

- 案 A: Macrobenchmark (`FrameTimingMetric` / `MemoryUsageMetric`) で手順をコードに固定、合格線は Pixel 4a の初回計測で校正 — 採用。iOS の「計測専用 launch 経路」と同じ再現性を公式の枠組みで得られ、将来 CI にも載る
- 案 B: Perfetto / gfxinfo の手動計測 — 却下。再現性が人の操作に依存

付随: 再利用確認は debug カウンタ + Layout Inspector、`LazyLayoutCacheWindow` は v1 では Compose 既定に従う (公開 API にしない)。規約は実装後に handbook/android へ (ADR ではない)。

## 2026-09-04: 論点 8 行の高さ変化の検証画面

iOS の `HeightChangeVerificationView` (展開経路 2 種 × list / grid 切替) を確認。

- 案 A: Android 固有の技術検証画面として同構成で置く — 採用。sample-parity の例外枠に収まり、`animateItem` / content 配置 / テンプレート内 state の保持を確かめる場になる
- 案 B: 共通デモに昇格 — 却下 (今回は)。iOS 側の改修と 10 デモ化が本フェーズに乗る
- 案 C: 置かない — 却下

これで 8 論点すべて決定。残 TODO は dsl-samples の追随と ksn-propose。

## 2026-09-04: 補足 — `listSeparatorColor` は iOS 側も未実装

オーナーの確認。iOS は `listSeparators(Bool)` のみ公開で色は内部固定値 (ios-engine-foundation の deviation)。`listSeparatorColor` は両プラットフォーム新規のため、iOS 側の追加を本フェーズの iOS 追随グループ (推論形対応・`KsTemplate` 改名と同じ組) に同梱する。
