# android ADR 一覧

| ID | タイトル | status | 概要 |
|---:|---|---|---|
| [0001](0001-unified-lazy-grid-rendering.md) | Android の描画は LazyVerticalGrid に統一し、list は 1 列グリッドとして扱う | accepted | `LazyColumn` 不使用。`LazyGridState` 1 種でスクロール制御を 1 経路にし、list ⇔ grid 切替で位置を保つ。iOS (ios/ADR-0003) と同型。1 列グリッドの性能は `LazyColumn` と同等 (実測)。 |
| [0002](0002-single-module-latest-compose-bom.md) | Android は単一モジュール + explicitApi strict で組み、Compose BOM は利用者に未普及の SDK Platform を強いない範囲で最新安定版に追随する | accepted | 1 モジュール・minSdk 29・compileSdk 36・JDK 17・catalog 単一定義元。最低版固定と 2 モジュール構成を却下。Compose 1.12 は compileSdk 37 を強いるため 1.11 系 (2026-09-05 改訂)。 |
| [0003](0003-material3-dependency-for-ripple.md) | ライブラリは material3 に依存し、タップのフィードバックは標準 ripple を既定にする | accepted | Foundation の `LocalIndication` だけでは `MaterialTheme` 無しのアプリで既定がデバッグ塗りになる。帰結: `touchFeedbackColor` の意味論が iOS と非対称 (統一は後続)。 |
| [0004](0004-animate-row-height-change-by-default.md) | 行の高さ変化を既定でアニメーションさせ、補間中は content を行の高さで測り直して切り取る | accepted | 自前 modifier `ksAnimatedHeight`。`animateContentSize` (縮む向きで帯) と `animateItem` 併用 (P90 +19%) を却下。利用契約: テンプレートの根に高さの制約を渡す。 一部改訂: 0006 (「animateItem は重ねない」を置き換え)。 |
| [0005](0005-app-context-via-androidx-startup.md) | 公開 API は `Context` を引数に取らず androidx.startup の Initializer でアプリケーションコンテキストを捕捉する | accepted | core/ADR-0002 の引数 1 対 1 を守るため `KsAppContext` を起動時に埋める。既存の `InitializationProvider` に相乗りし ContentProvider は増えない。未初期化時は警告 no-op (debug assertion は掛けない)。image-loading の実装と突き合わせて accepted (2026-09-08)。 |
| [0006](0006-animate-item-placement-on-diff.md) | 配列の差し替えによる項目と見出しの移動・挿入・削除を、Android でも `animateItem` でアニメーションさせる | accepted | amends 0004 (「`animateItem` は重ねない」だけを置き換え)。項目・見出し (固定中を含む)・ルートのヘッダー / フッターに、修飾のいちばん外側でフェードありで付ける。高さの補間中は配置を止める。末尾への挿入は同じフレームで位置を要求せず次のフレームから送る。費用は体感のゲートで判断。D&D まで先送りする案を却下。 |
| [0007](0007-reorder-self-implemented.md) | Android の並べ替えは Compose の上に自前で作り、OSS には依存も取り込みもしない | accepted | 公式 API は無い。`sh.calvin.reorderable` への依存 (置けない場所を作れない・#93・依存が増える・保守が止まり気味) を却下、ソースの取り込み (約 1,500 行) をオーナー判断で却下。自動スクロール・位置飛び・持ち上げを一から解く。 |

採番規則は [../index.md](../index.md) を参照。
