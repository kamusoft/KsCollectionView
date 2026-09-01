# iOS エンジン基盤

UICollectionView + diffable data source + `UIHostingConfiguration` によるエンジンと、SwiftUI DSL ラッパー。リスト・グリッドの表示まで。

DSL の外形は core/ADR-0002〜0009 と [dsl-samples.md](../phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md) で確定済み (phase-1)。本フェーズは iOS 側の実現方法を詰める。

## 参考資料 (議論の材料)

- 先行実装 (流用元候補): KsSettingsViewUI (`../KsSettingsView/ios/Sources/KsSettingsViewUI/` — diffable + Compositional Layout + セルホスティング)
- 先行実装 (方式の参考): 旧 AiForms.CollectionView (`../AiForms.CollectionView/CollectionView.iOS/` — `ContentCellContainer` 等)
- 性能計測規約の参考: `../KsSettingsView/kasane/handbook/maui/performance-verification.md` (kasane-initial-assets の申し送り)

## 論点

(出尽くした — 全論点を決定事項へ昇格済み)

## 決定事項

### エンジン構成 — KsSettingsViewUI の設計パターンを翻案移植 (2026-09-01)

パッケージ依存や共通基盤の切り出しは行わず、実証済みの設計パターンをコピーして汎用化する ([ios/ADR-0001](../../../../decisions/ios/0001-engine-pattern-transplant.md))。流用する骨格:

- 識別子だけを snapshot に載せる diffable 構成 (identity と内容を分離し、内容更新は `reconfigureItems`)
- データ型 → セル型の遅延登録つき解決機構 (`KsCellRegistry` / `KsCellRenderer` の翻案)
- `UIHostingConfiguration` を `contentConfiguration` に差すセルホスティング一式 (自己サイズ補正・中央配置はみ出し対策込み)
- SwiftUI ラッパーの「宣言ツリー → diff 計算 → Store 経由で流す」構成
- レイアウトは差し替えず「クロージャの実行時参照 + `invalidateLayout()`」で切り替える方式

グリッド (多列・adaptive) の経路は KsSettingsViewUI に存在しないため新規実装。`UICollectionViewDataSourcePrefetching` の口は基盤段階から開けておく (画像プリフェッチ接続は画像ロード統合フェーズが使う)。

### セルホスティング — 再利用で SwiftUI state は保持されない仕様 (2026-09-01)

`UIHostingConfiguration` の適用・自己サイズ計測・はみ出し対策は翻案移植 (ios/ADR-0001) の実証済みパターンを踏襲し、タップ/ロングタップ/フィードバック色 (core/ADR-0009) はセル選択・ハイライト機構の正道で提案時に具体化する。セル再利用時はホスティングを作り直し、セル内の SwiftUI 内部 state は保持されない仕様とする ([ios/ADR-0002](../../../../decisions/ios/0002-no-state-across-cell-reuse.md))。残したい状態はデータモデル側に持たせる (core/ADR-0003 と一貫)。**利用者向けドキュメントへの明記が必要**。

### テンプレート切り替え — 値キー基本形 + ID 宣言の二本立て (2026-09-01)

phase-1 の「データ型ごとの登録 (混在配列)」案をオーナーレビューで棄却し、core/ADR-0004・0003 を改訂:

1. テンプレート切り替えは**値キー** (`Hashable` なら何でも、有限個推奨) を基本形とする: `KsCollectionView(items, template: \.kind) { Template(.message) { ... } }`。型ベース切り替え (混在配列) は副次変種として残す
2. 配列は単一型 `[Item]`。ライブラリ独自 protocol のモデルへの強制はしない (純粋なデータのまま)
3. 安定 ID は **`Identifiable` 準拠または `id:` キーパス指定の二本立て** (`ForEach` と同型)。KMP 共有モデル (Kotlin/Native export) は後者または app 側 1 行 extension で無改造利用できる
4. 内容変更検知は `Equatable` / NSObject `isEqual` (KMP data class は構造比較が自動成立)。Android 側は key ラムダ + `contentType` + 再コンポーズでそのまま成立
5. 未登録キーのアイテムが実行時に現れた場合: **debug ビルドは assertion で即停止、release ビルドは最小高の空セル + 警告ログで落とさない** (ADR-0004 残課題の解消。空セルの見た目・ログ文言は提案時に具体化)

### レイアウト — 自前 compositional セクションで統一、区切り線は list 専用のライブラリ描画 (2026-09-01)

- 全レイアウト (list / fixed / adaptive / 向き別列数) を自前の compositional セクションで実装し、リストは「1 列グリッド」として扱う ([ios/ADR-0003](../../../../decisions/ios/0003-unified-custom-layout.md))。システム list (`.list(using:)`) は使わない
- layout 値の切り替え・向きによる列数変化は「クロージャの実行時参照 + `invalidateLayout()`」方式 (ios/ADR-0001) の単一 sectionProvider で扱う
- 区切り線は **list レイアウト専用のオプションとしてライブラリが自前描画**で標準提供する (グリッドでは出さない)。**既定は表示** (opt-out)。Android 側も divider をライブラリが描いて同じ宣言・同じ既定で対称にする (core/ADR-0006 に反映済み)
- 区切り線の流用範囲: KsSettingsView の実装はシステム list 専用機構 (`UIListSeparatorConfiguration` + `itemSeparatorHandler`) のため**描画機構は流用不可・自前実装**。位置判定 (先頭/末尾/中間)・インセット規則・Theme 色解決のロジックは翻案流用できる

### SwiftUI ラッパー — 薄い Coordinator 直結 + ルートヘッダー/フッター (2026-09-01)

- Store 層と独自 diff 計算は持ち込まず、`UIViewControllerRepresentable` → Coordinator (VC 保持) → 配列から snapshot 構築・apply の**薄い 2 層構成**とする ([ios/ADR-0004](../../../../decisions/ios/0004-thin-representable-wrapper.md))。挿入・削除・移動の差分計算は diffable data source に任せ、内容変更の検知 (reconfigure 対象選定) は先行実装の突き合わせ方式 (`FullSnapshotContentTargets` の翻案) を使う
- スクロール命令 (core/ADR-0007) は Coordinator のキューに積み、`apply` の completion で flush して「データ反映後実行」を保証する
- **ルートヘッダー/フッターを本フェーズのスコープに追加**: リスト全体の上下にスクロールと一緒に流れる入れ物を `header:` / `footer:` クロージャで提供。iOS はレイアウト全体の boundary supplementary + `UIHostingConfiguration` 系ホスト、Android は Lazy 系の先頭・末尾 item。sticky セクションヘッダー (phase-4) とは別物。dsl-samples.md への語彙追加が必要

### Sample scaffold — デモ画面構成 9 画面 (2026-09-01)

器 (Local Swift Package 参照、`SampleScreen` / `SampleTheme` / ルートメニュー) は roadmap と [sample-parity](../../../../handbook/cross/sample-parity.md) の規約通り。デモ画面は決定事項と 1 対 1 対応の 9 画面とし、タイトル (= メニュー文言) は phase-3 の Android が一字一句追随する:

| 画面タイトル | 検証対象 |
|---|---|
| リスト | 基本 list・区切り線の既定表示と非表示切替・タップ/ロングタップのフィードバック (ADR-0009) |
| グリッド (固定列) | `.fixed(n)` + list⇄grid 切替トグル (状態保持の確認) |
| グリッド (adaptive) | `.adaptive(minItemWidth:)` |
| 向きで列数変更 | 向き別列数 (自社実績機能) |
| テンプレート切り替え | 値キーによる異種セル + 再利用 |
| ルートヘッダー/フッター | `header:` / `footer:` |
| スクロール制御 | `KsScrollController` の ID 指定移動・順序保証 |
| スペーシングと余白 | 行間・列間・contentPadding の動的変更 (論点 8 の DSL を受ける) |
| 大量件数 | 10,000 件グリッド (固定高 + 可変行高の混在) での仮想化・再利用 (性能検証の土俵を兼ねる) |

### スペーシングと余白 — layout 値パラメータ + contentPadding の 2 段構成 (2026-09-01)

phase-1 の抜け (棚卸し ADR-0009 から `RowSpacing` / `ColumnSpacing` が漏れ、余白系は phase-4 先送りだった) を本フェーズで解消。core/ADR-0006・0009 に反映済み:

- 行間・列間は **layout 値のパラメータ**: `.list(rowSpacing:)` / `.grid(columns:, rowSpacing:, columnSpacing:)`。旧の「UniformGrid 等のみ有効」の制約は撤廃し、adaptive 含む全グリッドで有効
- 画面端からの余白は **コンポーネントレベルの `contentPadding`** (4 辺)。意味論は「コンポーネント本体とスクロールするコンテンツの間の内側余白」であり、外側マージンではない。**スクロールバーは padding に左右されず本体の端に留まる** (iOS `contentInset` 系 / Compose `contentPadding` の標準挙動。外側の余白は利用者が通常の padding modifier で付ける)
- `SpacingType` (Between/Center) は廃止: adaptive は「列間は指定値で固定、余りを均等配分」のみ。既定値はいずれも 0
- グループ単位の余白 (`GroupFirstSpacing` / `GroupLastSpacing`) はセクション単位余白として phase-4 のまま
- list の区切り線 (既定表示) と `rowSpacing` 併用時の線の描画位置は提案時の詳細に回す

### 性能検証方法 — 実機 + Animation Hitches、可変行高混在の 10,000 件 (2026-09-01)

- 土俵: Sample「大量件数」画面 = 10,000 件グリッド。セルはテキスト + 色ブロックのみ (画像は phase-8 の担当)。**固定高と可変行高のセルを混在**させ (テキスト長ランダム化)、自己サイズ計測込みのスクロール性能を測る
- 計測: 実機 + Instruments の Animation Hitches。高速スクロール中の hitch time ratio **5ms/s 未満** (Apple 推奨の「良好」域) を合格ラインとする。メモリフットプリントが件数に比例しないこと (仮想化成立) を Memory Graph で確認
- 基準機: **iOS = iPhone 11** (iPhone 15 は参考計測)。**Android = Pixel 4a** (Pixel 6a は参考) — phase-3 への申し送り
- シミュレータは目安のみ。合否判定は実機で行う
- 計測手順・合格基準は `handbook/ios/` に performance-verification 規約として残す (KsSettingsView の同種規約 `../KsSettingsView/kasane/handbook/maui/performance-verification.md` の翻案。Android 側が対の規約を作れる形にする)

## TODO

- [x] 論点の解消 (2026-09-01 全 8 論点を決定事項へ昇格)
- [ ] [dsl-samples.md](../phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md) を改訂後の宣言形式 (値キー切り替え・`id:` 指定・区切り線オプション・ルートヘッダー/フッター・rowSpacing / columnSpacing / contentPadding) に追随させる
- [ ] ksn-propose で変更提案を起こす
