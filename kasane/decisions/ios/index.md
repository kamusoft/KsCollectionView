# ios ADR 一覧

| ID | タイトル | status | 概要 |
|---:|---|---|---|
| [0001](0001-engine-pattern-transplant.md) | iOS エンジンは KsSettingsViewUI の設計パターンを翻案移植する | accepted | パッケージ依存せずコピーして汎用化。diffable の identity/内容分離・型解決機構・`UIHostingConfiguration` ホスティング等を流用し、グリッド経路は新規実装。 |
| [0002](0002-no-state-across-cell-reuse.md) | セル再利用で SwiftUI の内部 state を保持しない | accepted | 再利用ごとにホスティングを作り直す。残したい状態はデータモデル側に持たせる (core/ADR-0003 の帰結)。利用者向けドキュメントに明記。 |
| [0003](0003-unified-custom-layout.md) | 全レイアウトを自前 compositional セクションで統一する | accepted | システム list は不使用、リストは 1 列グリッド扱い。単一 sectionProvider + 実行時参照で layout 値を切り替え。区切り線は list 専用オプションを自前描画。 |
| [0004](0004-thin-representable-wrapper.md) | SwiftUI ラッパーは Store 層を持たない薄い Coordinator 直結にする | accepted | 差分計算は diffable に任せ、内容変更検知のみ突き合わせ方式を翻案。スクロール命令は apply completion で flush。 |

採番規則は [../index.md](../index.md) を参照。
