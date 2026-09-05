# Exploration: revival-feasibility

## 課題 / 動機

`../KsSettingsView/` の基盤 (Core + Native UI + 宣言的ラッパー + MAUI facade の三面構成、binding 設備、CI、Kasane ハーネス) を活かして、旧 `../AiForms.CollectionView/` (Xamarin.Forms 時代の CollectionView ライブラリ) をリバイバルさせる価値があるかを検討する。

前提となる問い: SwiftUI / Jetpack Compose の普及で宣言的 UI でも仮想スクロール部品が書けるようになった今、「UICollectionView / RecyclerView のボイラープレートを吸収する」という旧ライブラリの価値命題は残っているのか。観点: ローディングインジケータ・無限スクロール・Pull to Refresh・スクロール仮想化・セクション/グループ化・D&D・ソート。

調査は ksn-dual-research (相方 codex + ホスト側 ksn-researcher の並走、2ラウンド) で実施。ラウンド1では相方「再定義すれば Go」/ ホスト側「三面新設 No-Go」と結論が割れ、追ラウンド (双方の主張を検証対象として再調査) で「三面新設は No-Go、ただしベンチ前提」に収束した。

## 調査結果: 各機能の 2026 年時点の実装コスト

| 機能 | SwiftUI | Compose | 素の UICollectionView / RecyclerView |
|---|---|---|---|
| 通常リスト | `List` / `LazyVStack` — 数行 | `LazyColumn` — 数行 | DataSource + Cell + 登録で数十〜百行 |
| グリッド (固定列数) | `LazyVGrid` + `GridItem(.flexible())` — 3行程度 | `LazyVerticalGrid` + `GridCells.Fixed(n)` | FlowLayout / GridLayoutManager 設定 |
| グリッド (列幅→自動列数) | `GridItem(.adaptive(minimum:))` | `GridCells.Adaptive(minSize)` | 自前計算 |
| Pull to Refresh | `.refreshable {}` — 1行 | `PullToRefreshBox` — ほぼ1行 | 状態接続コードが必要 |
| ローディング表示 | `ProgressView` / `.redacted(.placeholder)` | Paging `loadState` で定型。skeleton/shimmer のみ標準になし (自前20〜40行 or OSS) | 全部自前 |
| 無限スクロール | 専用 API なし。定番パターン 60〜120 行 (重複防止・終端判定・再試行は自前) | Paging 3 でほぼ解決済み (3.5.0 で state 設計との相性も改善) | 自由だが全部自前 |
| セクション + sticky ヘッダ | `Section` 自動 sticky / `pinnedViews:` | `stickyHeader` (stable 化済み。グリッド版の有無は未確定) | supplementary view / ConcatAdapter |
| D&D 並べ替え | `List` は `.onMove`。グリッドは iOS 27 の `.reorderable()` 待ち (2026-09-14 リリース予定) | 公式 API なし。`sh.calvin.reorderable` 等 OSS が事実上の標準 | Android の `ItemTouchHelper` は標準完結でここだけ View 系が優位 |
| ソート | 配列並べ替えで自動 move アニメ | 安定 `key` + `animateItem()` | DiffUtil / diffable |
| スクロール制御 | `ScrollViewReader` / `.scrollPosition(id:)` | `LazyListState.animateScrollToItem` | 直呼び |
| 仮想化 | `List` は iOS 16+ で UICollectionView 実装 (本物の再利用)。**`LazyVGrid` は生成遅延のみで再利用プールなし** | 本物の再利用 (プール上限7 = RecyclerView の 5+2 と同設計)。1.9 `LazyLayoutCacheWindow` で jank 最大40%改善、Google は「View と同等」を公式主張 | 基準 |

要約: 「差はパフォーマンスくらい」という当初の印象はほぼ正確。Android は性能差も実質消滅。iOS は `LazyVGrid` (大量件数グリッド) のみ本物の差が残る。素の UICollectionView 側も diffable + `CellRegistration` + `UIHostingConfiguration` でボイラープレートは 2019 年比で半減。

2026 年時点で残る穴は 4 つに絞られた:

1. Compose のリスト内 D&D 公式 API (OSS 2本が現役 — 正解形は薄いモディファイア層と市場が示唆)
2. SwiftUI の大量件数グリッド (LazyVGrid 再利用なし)
3. iOS のセクション別複合レイアウト (Compositional Layout 等価物) — ただし旧 AiForms.CollectionView も未提供 = リバイバルではなく新規開発
4. Android の初回ロード shimmer (SwiftUI は `.redacted` 標準)

## 検討した選択肢 (却下案と理由を含む)

### 案1: KsSettingsView 型三面構成での新設 (相方ラウンド1案) → 追ラウンドで双方 No-Go に収束

「ページング状態機械 + セクション/D&D 共通契約 + MAUI 向け高品質 Native CollectionView」への再定義案。No-Go の根拠 (強い順):

1. **MAUI 標準 CollectionView が機能面では既に揃っている** (検証ラウンドで判明した最重要事実): 継承鎖に `ReorderableItemsView` を含み `CanReorderItems` の D&D・グループ化・`RemainingItemsThreshold`・RefreshView を標準装備。価値命題は性能・安定性の差でしか立たず、そこは CV2 (.NET 10 で iOS 既定、.NET 11 Preview 6 で Windows も) に MS が集中投資中で差が縮む方向
2. **需要信号が弱い**: 旧 CollectionView の NuGet DL は旧 SettingsView の 6.1% (34.2K vs 559.3K)、pre 版のまま 2022-02 停止。現役自社アプリ5本にグリッド利用ゼロ (唯一の実使用は Xamarin.Forms 5 レガシーの pixie 1画面)。`../AiForms.Maui.NativeCollectionView/` (2025 年の MAUI 版試作) もリリース前に停止している
3. **順序の問題**: KsSettingsView / KsDialogs が未リリースのまま3本目の新築になる。KsSettingsView 自身が CollectionView の前提技術2つ — D&D (maui-support phase-7) とテンプレート仮想化 (phase-10) — を pending で抱えている
4. **Android の土台**: Google I/O 2026 で RecyclerView 含む View toolkit が maintenance mode 宣言 (削除予定なし・critical fix 継続なので「使うと壊れる」ではないが、新規資産を積む判断への逆風。約3年間機能追加ゼロ)
5. **工数実績**: KsSettingsView は約4ヶ月・326 commit・約60k LOC。CollectionView は同等以上の見込み

### 案2: MAUI 単独に割り切り `../AiForms.Maui.NativeCollectionView/` を完成 → 未判定 (自信度 55〜60%)

MAUI にだけは品質の穴が実在する (標準 CollectionView の未解決 issue 431件、Sharpnado は 2024 年から更新停止、商用のみ)。ただし:
- 現物は Linear のみでグリッド未実装 (`CollectionViewLayout.cs` / `LinearLayout.cs` は空クラス、iOS LayoutFactory は Linear 分岐のみ)。「完成」は試作をグリッド・D&D・仮想化まで作り込む規模
- KsSettingsView の戦略 ADR (`cross/0017`: MAUI 専用は MAUI 終息で共倒れ) への明示的な例外判断が必要
- MAUI 標準 CV2 と正面比較される立場になるため、性能ベンチで勝てることが前提

### 案3: 独立ライブラリを作らず、残る穴を既存ライブラリの機能として吸収 → 検証ワーカーが最も支持

maui-support の phase-7 (D&D) / phase-10 (テンプレート仮想化) がまさにそれに相当。ライブラリ化の固定費 (3 platform CI・binding・配信・ドキュメント・バージョン整合) を払わない。

### 補足: 技術的な新発見

- 「宣言的セルホスティングは重い」説は数百セル規模では実測で否定済み: KsSettingsView の Pixel 6a 実測で MAUI 埋め込み Release が Janky 4.6% / p90 12ms (Native 比較 6.1% / 28ms より良好)、iOS は CustomCell 200行ストレスで 60fps 張り付き・hitch 0。ただし現設計は行数分の live View が常存する (phase-10 未解決) ため数千件は未実測・不成立の見込み
- 旧コードの最大の再利用価値はページング契約ではなく `ContentCellContainer` (Droid 248行 / iOS 285行) — phase-10 と同じ問題の先行実装
- Compose 1.9 で `LazyLayoutMeasurePolicy` / `LazyLayoutItemProvider` / `LazyLayoutPrefetchState` が stable 化 → 何か作るなら「RecyclerView をラップ」でなく「Compose LazyLayout 上に独自 Lazy」の筋が使える (未検証)
- 旧 `LoadMoreMargin` 方式 (アイテム出現契機の追加ロード) は Compose の prefetch 拡大で LaunchedEffect が可視前に走るため 2026 年では成立しない。移植するなら `layoutInfo` ベースの再設計が前提

## 決定事項

1. **作る意味は「ある」(Go)** — ただし三面リバイバルではなく、SwiftUI / Compose で同じ書き味を提供する2プラットフォームライブラリとして再定義する。**MAUI は非対応** (ユーザー確定)
2. **描画エンジンは非対称構成** — iOS は UICollectionView ベース (セル中身は `UIHostingConfiguration` で SwiftUI)、Android は Compose Lazy 系の薄いラッパー。根拠: SwiftUI の `LazyVGrid` に再利用プールがなく大量件数グリッドが成立しない一方、Compose Lazy は RecyclerView 同等性能で RecyclerView 自体は maintenance mode (ユーザー確定)
3. リサイクル有無の影響は端末性能の向上で緩和されている面もあるが、グリッドの大量件数対応は必須要件とする
4. **主目的は自社アプリの KMP 量産時にリスト・グリッドを同じ書き方にすること。OSS 公開はついで** (ユーザー確定)
5. 調査所見の訂正: 「現役自社アプリにグリッド利用ゼロ」は誤り。Xamarin 時代の自社アプリ (調査対象リポジトリ群の外) で**グループ化 + ポートレイト/ランドスケープ可変グリッド**を実戦投入している → この組み合わせは機能スコープの必須候補

## ADR 候補 (作成済み: cross/ADR-0001, core/ADR-0001 / 未起票: なし)

- [cross/ADR-0001](../../decisions/cross/0001-two-platform-declarative-library-scope.md): 2プラットフォームライブラリとしての新設 (MAUI 非対応) — proposed
- [core/ADR-0001](../../decisions/core/0001-asymmetric-rendering-engines.md): 描画エンジンの非対称構成 — proposed

## 未決の論点

(解決済み: Go/No-Go → Go で確定 / MAUI 関連の論点 2〜5 → MAUI 非対応の決定により消滅)

1. **公開 DSL の対称 API 設計** — SwiftUI / Compose で「同じ書き味」をどの粒度で揃えるか (命名・状態モデル・ページング契約)。ksn-propose / ロードマップの領分
2. **機能スコープの確定** — 初期リリースに含める機能セット (D&D・セクション・ページング状態機械・shimmer 等の優先順位)。自社実績のある「グループ化 + 画面向きで列数が変わる可変グリッド」は必須候補
3. ~~KMP 量産アーキテクチャとの接続形態~~ → 解決済み: 利用側 KMP アプリの **Native UI 層 (SwiftUI / Compose) から使う**ため、ライブラリ側に KMP / CMP の考慮は不要。CMP で iOS UI を描く構想もない (ユーザー確定)
4. **旧コード再利用範囲** — `ContentCellContainer` (iOS 285行) 等、UICollectionView エンジン実装での先行実装参照
5. 細部の未確定事実: `LazyGridScope` の stickyHeader 有無 / iOS 27 `.reorderable()` の厳密な availability (Xcode 上での確認推奨) / SwiftUI Lazy 系の画面外ビュー破棄/保持の実挙動

## UI 素材

(なし)

## 変更級の推奨: ロードマップ領分 (1変更に収まらない)

方向性確定 (Go・2プラットフォーム・非対称エンジン)。ライブラリ全体の新規開発であり、iOS エンジン / Android ラッパー / 対称 DSL 設計 / 機能群 (ページング・セクション・D&D 等) と独立した change が複数必要 → **ksn-roadmap で起案するのが適切**。本 exploration がそのまま起案の材料になる。

→ **起案済み**: [roadmaps/v1-foundation](../../roadmaps/v1-foundation/roadmap.md) (2026-08-31、7フェーズ)。本 change はロードマップへのハンドオフをもって役割を終えた (ADR 2本は accepted 済み)。
