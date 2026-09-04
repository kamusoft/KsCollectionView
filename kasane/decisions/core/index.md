# core ADR 一覧

| ID | タイトル | status | 概要 |
|---:|---|---|---|
| [0001](0001-asymmetric-rendering-engines.md) | 描画エンジンの非対称構成 | accepted | iOS は UICollectionView ベースのエンジン + `UIHostingConfiguration` セル、Android は Compose Lazy 系の薄いラッパー。対称性は公開 DSL の層で担保する。 |
| [0002](0002-symmetry-granularity.md) | 対称性の粒度 — 語彙・構造は1対1対応、記法は各プラットフォームの流儀 | accepted | コンポーネント名・パラメータ名・宣言構造を両プラットフォームで揃え、modifier 記法・状態保持・非同期処理は各流儀に残す。 |
| [0003](0003-collection-state-model.md) | コレクションの状態モデル — プレーンな配列 + 安定 ID 必須 | accepted | 利用者はプレーンな配列を渡し安定 ID を宣言 (`Identifiable` or `id:` 指定 / `key`)。差分計算・アニメ適用はライブラリの責務。 |
| [0004](0004-template-per-type-registration.md) | テンプレート宣言 — 値キーによる切り替えを基本形とする明示登録 DSL | accepted | モデルの種別プロパティ (Hashable な値キー) でテンプレートを切り替え、キー値を再利用種別として `CellRegistration` / `contentType` を自動導出。型ベースは副次変種。 |
| [0005](0005-paging-contract-shape.md) | ページング契約の外形 — 利用者所有の5状態 enum + コールバック | accepted | `KsPagingState` を VM が所有し DSL に状態とコールバックを渡す。ライブラリはトリガー発火と標準フッターを担う。 |
| [0006](0006-single-component-layout-value.md) | レイアウト指定 — 単一コンポーネント + layout 値 | accepted | list / fixed / adaptive / 向き別列数を layout 値1つで宣言。向き可変を一級サポート。 |
| [0007](0007-scroll-controller.md) | スクロール制御 — plain な `KsScrollController` を同名提供 | accepted | ID ベース命令の plain ハンドル。所有位置自由 (View / VM / イベント)、未接続 no-op + データ反映後実行の順序保証。 |
| [0008](0008-prefetch-resources-and-ksimage.md) | 画像プリフェッチの DSL 外形 — `prefetchResources` + `KsImage` の対 | accepted | アイテム → リソースをクロージャ宣言し、同一キャッシュを見る専用画像コンポーネントを対で提供。詳細は phase-8。 |
| [0009](0009-legacy-vocabulary-inventory.md) | 旧 AiForms.CollectionView 公開契約の棚卸し | accepted | ScrollController・向き別列数・タップ系等を継承、IsInfinite・HCollectionView・手動サイズ指定等を廃止。v1 は縦のみ。 |
| [0010](0010-list-separator-default-appearance.md) | list の区切り線の既定外観 — 先頭行の上端・行間・最終行の下端に全幅 1pt の固定色で描く | proposed | hairline・行間のみ・インセット・semantic color を却下。両プラットフォーム同じ実値。色は DSL で設定可能にする方向で Android 実装時に確定 — それまで proposed (オーナー判断 2026-09-04)。 |
| [0011](0011-invalid-input-release-behavior.md) | 不正入力 (重複 ID・未登録テンプレートキー) は debug では assertion、release では表示を継続して警告ログを出す | proposed | 落とさず・消さず・黙らず。重複 ID と重複登録は後勝ち。Android 実装完了まで proposed (オーナー判断 2026-09-04)。 |

採番規則は [../index.md](../index.md) を参照。
