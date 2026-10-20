# 対称 DSL 仕様の設計

SwiftUI / Compose の両言語でサンプルコードを書きながら、公開 API の形を確定する (全フェーズの土台)。

## 論点

(すべて決定事項へ昇格済み)

## 決定事項

- **対称性の粒度**: コンポーネント名・パラメータ名・宣言構造は両プラットフォームで1対1対応させる。modifier 記法・状態保持 (`@State` / `remember` 等)・非同期処理は各プラットフォームの流儀に従う。揃えるのは「何を・どんな名前で・どんな順で宣言するか」という頭の中のモデルであり、記法まで独自 DSL 化しない (2026-09-01、core/ADR-0002)
- **コレクションの状態モデル**: 利用者はプレーンなデータ配列を渡し、安定 ID を必須とする (Swift: `Identifiable` 準拠 / Kotlin: `key` ラムダ)。差分計算と移動/挿入/削除アニメの適用はライブラリの責務。内容変更の検知は iOS はアイテムの同値比較 (`Equatable`) で再構成、Android は再コンポーズで自動 (2026-09-01、core/ADR-0003)
- **テンプレート種別の宣言方法**: データ型ごとにテンプレートを明示登録する DSL (`Template(for: Message.self) { ... }` / `template<Message> { ... }`)。データ型 → View の対応表を画面宣言側に置き、型を再利用種別として iOS の型別 `CellRegistration` / Compose の `contentType` をライブラリが自動導出する。クロージャはキャスト済みで型安全 (2026-09-01、core/ADR-0004)

### ページング契約の外形 (2026-09-01、core/ADR-0005)

5状態の公開 enum (`KsPagingState`: idle / refreshing / appending / failed / endReached) を利用者の VM が所有し、DSL には「現在の状態」と「次ページ要求コールバック」を渡す。ライブラリの責務は末尾近傍でのコールバック発火 (多重発火の抑止込み)・状態に応じた標準フッター描画 (appending → ローディング / failed → リトライ / endReached → 終端。カスタムテンプレートで差し替え可)・Pull to Refresh と refreshing の接続。渡し方は流儀に従う: Swift は modifier (`.paging(state) { }`)、Kotlin は名前付き引数 (`paging = KsPaging(state, onLoadMore)`)。状態遷移ロジックは利用者 (KMP 共有 VM) 側に置ける。実装は phase-5。

### レイアウト指定の DSL (2026-09-01、core/ADR-0006)

リストとグリッドは単一コンポーネントとし、`layout` 値1つで宣言する: `.list` / `.grid(columns: .fixed(3))` / `.grid(columns: .adaptive(minItemWidth: 120))` / 向き別列数 `.grid(columns: .fixed(portrait: 2, landscape: 4))` (Kotlin は `KsLayout.List` / `KsLayout.Grid(KsColumns.Fixed(3))` 等の対応語彙)。向き別列数は値として一級サポートし、利用者に画面サイズ監視を書かせない。データ・テンプレート・ページングの宣言を変えずにレイアウトだけ差し替えられる。セクションごとの layout 付与への拡張は phase-4 で詰める。

### ソートの表現 (2026-09-01)

DSL に専用 API は持たない。ソートはデータ層の仕事 — 利用者が VM で配列を並べ替えて差し替えれば、状態モデル (core/ADR-0003) の自動差分で移動アニメ付きソートが成立する。ソート記述子を DSL に持つと表示順と配列順の真実が二重化し、D&D (phase-6) と衝突するため採らない。サンプルに「ソート切替」レシピを載せて書き方を示す。必要が実証されたら追加的に拡張できる。

### スクロール制御 (2026-09-01、core/ADR-0007)

命令ハンドル `KsScrollController` を両プラットフォーム同名で提供する (Flutter の controller 方式と同型。Compose 側も `state` ではなくこの名前 — スクロール専用窓口であることを名前が示す)。ID ベースの命令語彙 (`scrollTo(id:position:animated:)` / `scrollToStart` / `scrollToEnd` — 向き中立の旧実績語彙を継承) を1対1で揃える。コントローラは UI ライフサイクル非依存の plain オブジェクトで、所有位置は自由: View 所有 (`@State` / `rememberKsScrollController()`)・VM 所有 (直接命令)・イベント方式のいずれも成立する。契約: 未接続時の命令は no-op、命令は保留中のデータ反映後に実行 (順序保証はライブラリ責務)。ドキュメントの標準レシピは View 所有とし、VM 所有 (新着で末尾へ等) もサンプルに載せる。

### 画像プリフェッチの DSL 外形 (2026-09-01、core/ADR-0008)

アイテム → 必要リソースの対応をクロージャで宣言させ (Swift `.prefetchResources { item in [URL] }` / Kotlin `prefetchResources =` 引数)、プリフェッチと同一ローダ・キャッシュを見る専用画像コンポーネント `KsImage` を対で提供する。データ型にはプロトコル等の要求を課さない (対応表は宣言側 — ADR-0004 と同じ思想)。ライブラリは「表示予測 × 対応表」でプリフェッチを完結し、`KsImage` とのキャッシュ一体性で二重ダウンロードを防ぐ。ローダ選定・キャッシュ設計等の詳細は phase-8-image-loading。

### 旧 AiForms.CollectionView 公開契約の棚卸し (2026-09-01、core/ADR-0009)

README-ja.md の全公開語彙を新 DSL に対応付けた。

**引き継ぐ (変換して継承)**:
- `ScrollController` → `KsScrollController` (ADR-0007 と同設計が旧に実在。命令名は向き中立の `scrollToStart` / `scrollToEnd` を継承)
- `LoadMoreCommand` + `SetLoadMoreCompletion` + `LoadMoreMargin` → ページング契約 (ADR-0005)。completion コールバックの役割は `endReached` 状態が吸収。`LoadMoreMargin` は phase-5 で paging 設定に
- `PortraitColumns` / `LandscapeColumns` → `.fixed(portrait:landscape:)`、`AutoSpacingGrid` + `ColumnWidth` → `.adaptive(minItemWidth:)` (ADR-0006)
- `IsPullToRefreshEnabled` / `RefreshCommand` / `IsRefreshing` → 各流儀 + `refreshing` 状態 (ADR-0005)
- `ItemTapCommand` / `ItemLongTapCommand` / `TouchFeedbackColor` → `onItemTap { }` / `onItemLongTap { }` (型付きアイテムが渡る) + フィードバック色指定 (既定はプラットフォーム標準の ripple / ハイライト)。iOS は UICollectionView のセル選択・ハイライトの正道で提供 — 利用者が自力で書けない価値
- グループ化一式 (`IsGroupingEnabled` / `GroupHeaderTemplate` / `GroupHeaderHeight` / `IsGroupHeaderSticky`) → phase-4 の議論素材に申し送り (sticky は旧 iOS のみ → 両対応が論点)

**捨てる**: `IsInfinite` (非ゴール)、`HCollectionView` (v1 は縦のみ。少数カルーセルは素の `LazyRow` / `LazyHStack` で足り、水平×大量件数が必要になったら roadmap 改訂で追加 — 命令名が向き中立なので API は壊れない)、`CachingStrategy` (内部責務化)、`ContentCell` (`UIHostingConfiguration` で不要)、`ColumnHeight` / `AdditionalHeight` / `ComputedWidth` / `ComputedHeight` (セル自己サイズ計測で不要に — phase-2 要件として申し送り)、`GroupFirstSpacing` / `GroupLastSpacing` / `BothSidesMargin` / `SpacingType` (contentPadding / spacing の流儀へ簡素化 — 詳細 phase-4)

## 調査結果 (2026-09-01 完了)

9論点すべてを決定事項に昇格し、公開 DSL の骨格を確定した。成果物:

- **決定事項** (本ファイル上記) と **core/ADR-0002〜0009** (proposed で起票済み)
- **[artifacts/dsl-samples.md](artifacts/dsl-samples.md)**: 全決定を反映した6シナリオの両言語対比サンプル。公開語彙一覧 (Swift / Kotlin / 出典 ADR) と実装フェーズへの申し送り一覧を含む — 後続フェーズはこれを API 形状の仕様候補として参照する
- 後続への影響は各フェーズ agenda に「phase-1 からの申し送り」として追記済み

## TODO

- [x] 論点の解消 (9論点すべて決定事項へ昇格、core/ADR-0002〜0009 を proposed で起票)
- [x] 両言語のサンプルコード (利用側視点) を artifacts/ に書いて API 形状を固める → [artifacts/dsl-samples.md](artifacts/dsl-samples.md)
- [x] 調査結果のまとめ → 決定事項 (本ファイル) + core/ADR-0002〜0009 + [artifacts/dsl-samples.md](artifacts/dsl-samples.md) の公開語彙一覧・申し送り一覧が成果物
- [x] ksn-roadmap で research 完了をマーク (2026-09-01)
