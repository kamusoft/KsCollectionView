# ios ADR 一覧

| ID | タイトル | status | 概要 |
|---:|---|---|---|
| [0001](0001-engine-pattern-transplant.md) | iOS エンジンは KsSettingsViewUI の設計パターンを翻案移植する | accepted | パッケージ依存せずコピーして汎用化。diffable の identity/内容分離・型解決機構・`UIHostingConfiguration` ホスティング等を流用し、グリッド経路は新規実装。 |
| [0002](0002-no-state-across-cell-reuse.md) | セル再利用で SwiftUI の内部 state を保持しない | accepted | 再利用ごとにホスティングを作り直す。残したい状態はデータモデル側に持たせる (core/ADR-0003 の帰結)。利用者向けドキュメントに明記。 |
| [0003](0003-unified-custom-layout.md) | 全レイアウトを自前 compositional グループで統一する | accepted | システム list は不使用、リストは 1 列グリッド扱い。単一 sectionProvider + 実行時参照で layout 値を切り替え。区切り線は list 専用オプションを自前描画。 |
| [0004](0004-thin-representable-wrapper.md) | SwiftUI ラッパーは Store 層を持たない薄い Coordinator 直結にする | accepted | 差分計算は diffable に任せ、内容変更検知のみ突き合わせ方式を翻案。スクロール命令は apply completion で flush。 |
| [0005](0005-single-swiftpm-product.md) | SwiftPM の product は KsCollectionView 単一とし、エンジンは同一モジュールの internal に置く | accepted | 公開面は DSL の入口に限定。Core/UI 分割・別 package は却下 (モデル層が無い・共有先が無い)。 |
| [0006](0006-reconfigure-visible-cells-on-equal-array-update.md) | 同値配列の更新でも可視セルを再構成し、ID・テンプレートキーの宣言と登録集合は表示中不変とする | accepted | 親の状態を捕捉するテンプレートを成立させる。前提「親の更新が届く」はテンプレート内でしか読まれない `@State` では成り立たず、観測する値を渡した場合の再構成条件は 0008 が置き換えた。一部改訂: 0008 |
| [0007](0007-cell-content-placement.md) | セル content は行の上端に固定・水平は中央に置き、content へ行の高さを提案しない | accepted | UIHostingConfiguration の中央配置はみ出し対策 (KsRowContentPlacement)。帰結: grid で背の低いセルは行高いっぱいに広がらない。Android も同じ規則で一致を確認して accepted (2026-09-05)。配置規則は両プラットフォーム共通の契約 (concepts/core/styling/collection-layout.md)。 |
| [0008](0008-observed-parent-state-modifier.md) | テンプレートの中で読む親の状態は、観測する値として DSL に明示的に渡す (iOS 固有の modifier) | accepted | `observedValue(_:)` (amends 0006)。引数式が body で評価されるため依存が張られ、値が変わったときだけ可視セルを再構成する。未指定時は 0006 のまま。Android は Compose の自動観測で不要。トランザクション引き渡しによる中身のアニメーションは効果なしと確認。 |
| [0009](0009-internal-section-chunking.md) | 配列を内部で固定件数の塊 (内部セクション) に分けて配置し、レイアウトの再解決の費用を配列の件数から切り離す | accepted | 塊の件数は 500 を列数候補の最小公倍数の倍数に切り上げ。境界は見た目に出さず、利用者の語彙に現れない。グループ化機能のグループは 2 段 (論理 × 塊) を前提にする。前提 (解き直しの費用はグループ単位) は基準機の件数比 1.04 倍で確認。 一部改訂: 0010 (塊の区切り方と識別)。 |
| [0010](0010-chunk-per-logical-section.md) | 内部の塊は利用者のグループごとに区切り、「グループの値 + グループ内の塊の順番」で識別し、塊に割れたグループの見出しは位置の書き換えで 1 つとして固定する | accepted | amends 0009 (塊の区切り方と識別だけを置き換え)。塊はグループをまたがず最後の塊は端数でよい。塊に割れたグループは全塊の見出しの位置を書き換えて 1 つとして固定し (下端は最後の行の下端)、押し出し中も不透明に保ち、透明な見出しは読み上げから外す。UIKit の薄めは版で違う (26.5 はあり・18.6 はなし・16 は未確認)。重ね描き・場所を取らない見出し等を試作で却下。 |
| [0011](0011-reorder-by-uikit-drag-and-drop.md) | iOS の並べ替えは UIKit 標準の並べ替えの仕組みで作り、隙間・持ち上げ・置く動きは UIKit に任せる | accepted | 差分データソースの並べ替えハンドラで一覧を並べ替えのできる置き先にし、隙間が動く速さは遅い設定。delegate は持ち上げてよい項目・置けない場所・受け渡しの制限に使う。UIKit が見せた隙間を項目の行き先に読み替え、確定した後に受け入れを聞く。全画面の一覧の上端の自動スクロールだけエンジンが足す。delegate だけで置く形・対話的な移動・自前の隙間・contentInset に安全領域を持たせる形・iOS 27 の SwiftUI 標準を却下。iOS 16・17 は未確認。 |

採番規則は [../index.md](../index.md) を参照。
