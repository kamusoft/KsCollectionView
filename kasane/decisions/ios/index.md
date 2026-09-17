# ios ADR 一覧

| ID | タイトル | status | 概要 |
|---:|---|---|---|
| [0001](0001-engine-pattern-transplant.md) | iOS エンジンは KsSettingsViewUI の設計パターンを翻案移植する | accepted | パッケージ依存せずコピーして汎用化。diffable の identity/内容分離・型解決機構・`UIHostingConfiguration` ホスティング等を流用し、グリッド経路は新規実装。 |
| [0002](0002-no-state-across-cell-reuse.md) | セル再利用で SwiftUI の内部 state を保持しない | accepted | 再利用ごとにホスティングを作り直す。残したい状態はデータモデル側に持たせる (core/ADR-0003 の帰結)。利用者向けドキュメントに明記。 |
| [0003](0003-unified-custom-layout.md) | 全レイアウトを自前 compositional セクションで統一する | accepted | システム list は不使用、リストは 1 列グリッド扱い。単一 sectionProvider + 実行時参照で layout 値を切り替え。区切り線は list 専用オプションを自前描画。 |
| [0004](0004-thin-representable-wrapper.md) | SwiftUI ラッパーは Store 層を持たない薄い Coordinator 直結にする | accepted | 差分計算は diffable に任せ、内容変更検知のみ突き合わせ方式を翻案。スクロール命令は apply completion で flush。 |
| [0005](0005-single-swiftpm-product.md) | SwiftPM の product は KsCollectionView 単一とし、エンジンは同一モジュールの internal に置く | accepted | 公開面は DSL の入口に限定。Core/UI 分割・別 package は却下 (モデル層が無い・共有先が無い)。 |
| [0006](0006-reconfigure-visible-cells-on-equal-array-update.md) | 同値配列の更新でも可視セルを再構成し、ID・テンプレートキーの宣言と登録集合は表示中不変とする | accepted | 親の状態を捕捉するテンプレートを成立させる。前提「親の更新が届く」はテンプレート内でしか読まれない `@State` では成り立たず、観測する値を渡した場合の再構成条件は 0008 が置き換えた。一部改訂: 0008 |
| [0007](0007-cell-content-placement.md) | セル content は行の上端に固定・水平は中央に置き、content へ行の高さを提案しない | accepted | UIHostingConfiguration の中央配置はみ出し対策 (KsRowContentPlacement)。帰結: grid で背の低いセルは行高いっぱいに広がらない。Android も同じ規則で一致を確認して accepted (2026-09-05)。配置規則は両プラットフォーム共通の契約 (concepts/core/styling/collection-layout.md)。 |
| [0008](0008-observed-parent-state-modifier.md) | テンプレートの中で読む親の状態は、観測する値として DSL に明示的に渡す (iOS 固有の modifier) | accepted | `observedValue(_:)` (amends 0006)。引数式が body で評価されるため依存が張られ、値が変わったときだけ可視セルを再構成する。未指定時は 0006 のまま。Android は Compose の自動観測で不要。トランザクション引き渡しによる中身のアニメーションは効果なしと確認。 |
| [0009](0009-internal-section-chunking.md) | 配列を内部で固定件数の塊 (内部セクション) に分けて配置し、レイアウトの再解決の費用を配列の件数から切り離す | accepted | 塊の件数は 500 を列数候補の最小公倍数の倍数に切り上げ。境界は見た目に出さず、利用者の語彙に現れない。セクション / グループ化機能の論理セクションは 2 段 (論理 × 塊) を前提にする。前提 (解き直しの費用はセクション単位) は基準機の件数比 1.04 倍で確認。 |

採番規則は [../index.md](../index.md) を参照。
