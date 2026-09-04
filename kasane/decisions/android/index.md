# android ADR 一覧

| ID | タイトル | status | 概要 |
|---:|---|---|---|
| [0001](0001-unified-lazy-grid-rendering.md) | Android の描画は LazyVerticalGrid に統一し、list は 1 列グリッドとして扱う | proposed | `LazyColumn` 不使用。`LazyGridState` 1 種でスクロール制御を 1 経路にし、list ⇔ grid 切替で位置を保つ。iOS (ios/ADR-0003) と同型。 |
| [0002](0002-single-module-latest-compose-bom.md) | Android は単一モジュール + explicitApi strict で組み、Compose BOM は最新安定版に追随する | proposed | 1 モジュール・minSdk 29・JDK 17・catalog 単一定義元。最低版固定と 2 モジュール構成を却下。 |

採番規則は [../index.md](../index.md) を参照。
