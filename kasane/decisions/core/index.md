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
| [0008](0008-prefetch-resources-and-ksimage.md) | 画像プリフェッチの DSL 外形 — `prefetchResources` + `KsImage` の対 | accepted | アイテム → リソースをクロージャ宣言し、同一キャッシュを見る専用画像コンポーネントを対で提供。詳細は phase-8。一部改訂: 0013 (宣言の要素を URL から `KsResource` へ)。 |
| [0009](0009-legacy-vocabulary-inventory.md) | 旧 AiForms.CollectionView 公開契約の棚卸し | accepted | ScrollController・向き別列数・タップ系等を継承、IsInfinite・HCollectionView・手動サイズ指定等を廃止。v1 は縦のみ。 |
| [0010](0010-list-separator-default-appearance.md) | list の区切り線の既定外観 — 先頭行の上端・行間・最終行の下端に全幅 1pt の固定色で描く | accepted | hairline・行間のみ・インセット・semantic color・背面描画を却下。両プラットフォーム同じ実値、線は content の前面。色は `listSeparatorColor` で変更可。Android 実装と突き合わせて accepted (2026-09-05)。 |
| [0011](0011-invalid-input-release-behavior.md) | 不正入力 (重複 ID・未登録テンプレートキー) は debug では assertion、release では表示を継続して警告ログを出す | accepted | 落とさず・消さず・黙らず。重複 ID と重複登録は後勝ち。Android のみ 4 つ目 (Bundle に載らない `key`)。debug の主語は利用者アプリのビルド種別。Android 実装と突き合わせて accepted (2026-09-05)。 |
| [0012](0012-image-loader-direct-dependency.md) | 画像ローダー — 本体が iOS は Nuke・Android は Coil 3 に直接依存し `KsImage` とプリフェッチ接続を内蔵 | accepted | 別 product 同梱・ローダー抽象 + アダプタ・Kingfisher・iOS のディスクキャッシュ自動有効化を却下。ローダーの共有インスタンスをそのまま共有キャッシュとし、iOS のディスクキャッシュは `KsImagePipeline.enableSharedDiskCache()` の明示呼び出し。関連: 0013・0014 (縮小済みの項目・キー付きの項目はローダー付属ビューと共有しない例外)。後続 3 change の決着を待って accepted (2026-09-24)。 |
| [0013](0013-prefetch-display-size-hint.md) | 先読みの表示幅の宣言 — 要素 `KsResource` に URL ごとの概算の幅 (列幅 / 固定値) を持たせ、表示は実物の寸法を許容範囲で引き当てる | accepted | `prefetchResources` の要素を `KsResource` (幅省略 = 原寸) にし `[URL]` は廃止 (配布前)。`KsImage` は拡大率 `s` で許容範囲 (必要寸法の 0.5〜4 倍、内部定数) のメモリ項目を引き当て、範囲内なら要求を出さない。幅は正方形を覆う大きさに縮小。CPU の同期縮小を廃止。学習 (A-2)・バケット化・別名の入口・オーバーロード・ハードウェア支援オフ・許容範囲の公開を却下。amends 0008。実装後の視点で書き直して accepted (2026-09-24)。 |
| [0014](0014-image-cache-key-override.md) | 画像の任意キー — 先読みの要素 `KsResource` と `KsImage` の画像ソースの両方に同じ任意キーを持たせ、キーがあれば URL の代わりに鍵の基準にする | accepted | 署名付き URL など URL が変わる画像のため。引数名は `key`、省略は従来どおり URL。指定時は取得以外 (メモリ・ディスク・世代・索引・先読みの取得単位・消去) をすべてキー基準にし、キーの識別子は URL と別の名前空間。リモートだけ・空文字は不正入力・URL だけ変われば先読みを出し直す。`KsResource` だけに持たせる案・URL → キー変換の登録・先読み宣言から対応を覚える案 (D / D') を却下。実装後の視点で書き直して accepted (2026-09-24)。 |
| [0015](0015-section-by-group-value.md) | セクションの宣言 — 平らな配列のまま、項目の「どのグループか」を表す値を指してグループにする | proposed | 同じ値が続く項目を 1 セクションにし、セクションはグループの値で識別。ヘッダーは任意の View で値とセクション内の項目を受け取り、高さは自動。グループの配列を渡す形・両方の入口を却下。帰結: 空のグループは出せない。 |
| [0016](0016-list-separator-per-section.md) | セクションを持つ list の区切り線は、セクションごとに先頭行の上端・行の間・最終行の下端に引く | proposed | amends 0010 (線の位置だけを置き換え)。見出しは前セクションの下線と自セクションの上線の間。見出し未宣言なら 2 つめ以降の上線を出さない。塊の境目には出さない。見出しの下に引かない案を却下。 |

採番規則は [../index.md](../index.md) を参照。
