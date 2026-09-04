# collection-layout (iOS) — デルタスペック

## ADDED Requirements

### Requirement: layout 値による表示形態
`layout` 値 1 つでリスト / 固定列グリッド / adaptive グリッド / 向き別列数を宣言できる (SHALL)。core/ADR-0006 の語彙 (`.list` / `.grid(columns: .fixed(n))` / `.grid(columns: .adaptive(minItemWidth:))` / `.fixed(portrait:landscape:)`) に従う (SHALL)。0 以下の列数・0 以下の `minItemWidth`・負のスペーシングは不正入力であり、debug ビルドでは assertion で検知する (SHALL)。列の利用可能幅は「コンポーネント幅 − contentPadding 左右 − 列間 (columnSpacing × (列数 − 1))」から求める (SHALL)。

#### Scenario: 固定列グリッド
- **GIVEN** `.grid(columns: .fixed(3))` の宣言
- **WHEN** 表示する
- **THEN** 要素は 3 列で配置される

#### Scenario: adaptive グリッド
- **GIVEN** `.grid(columns: .adaptive(minItemWidth: 120))` の宣言
- **WHEN** コンテナ幅が変わる
- **THEN** 最小アイテム幅を下回らない範囲で最大の列数が自動決定される。列間は指定した `columnSpacing` のまま固定され、余剰幅はアイテム幅へ均等配分される

#### Scenario: 向き別列数 (コンテナ縦横比基準)
- **GIVEN** `.grid(columns: .fixed(portrait: 2, landscape: 4))` の宣言
- **WHEN** コンテナの縦横比が変わる (端末の回転、Split View 等でのリサイズ)
- **THEN** コンテナの高さ > 幅なら 2 列、幅 ≥ 高さなら 4 列で表示される (判定は端末の物理向きではなくコンテナの縦横比 — core/ADR-0006)

### Requirement: レイアウトの動的切り替え
表示中に `layout` 値を差し替えたとき、データの状態を保ったまま表示形態が切り替わる (SHALL)。スクロール位置は「切り替え直前に表示範囲の先頭にあった要素」をアンカーとして維持する (SHALL) — 切り替え後もアンカー要素が表示範囲内に現れる。アンカー要素が同時に削除された場合は、その近傍の位置を維持する (SHALL)。切り替え時に画面全体の再構築や表示の乱れを起こしてはならない (SHALL NOT)。

#### Scenario: list とグリッドの切り替え
- **GIVEN** リスト表示中の画面 (先頭可視要素 X)
- **WHEN** `layout` を `.grid(columns: .fixed(2))` に差し替える
- **THEN** 同じデータが 2 列グリッドで表示され、X は表示範囲内にある

### Requirement: スペーシング
行間 (`rowSpacing`) と列間 (`columnSpacing`) を layout 値のパラメータで宣言できる (SHALL)。既定値は 0 (SHALL)。`columnSpacing` は固定列・adaptive の全グリッドで有効とする (SHALL)。

#### Scenario: グリッドの行間・列間
- **GIVEN** `.grid(columns: .fixed(2), rowSpacing: 8, columnSpacing: 8)` の宣言
- **WHEN** 表示する
- **THEN** 行の間と列の間にそれぞれ指定の間隔が空く。既定 (未指定) では間隔なしで詰めて表示される

### Requirement: contentPadding
コンポーネントレベルの `contentPadding` で、コンポーネント本体とスクロールするコンテンツの間の内側余白を 4 辺個別に宣言できる (SHALL)。既定値は 0 (SHALL)。スクロールインジケータの位置は `contentPadding` の影響を受けず、コンポーネント本体の端に表示される (SHALL)。

#### Scenario: 内側余白とスクロールインジケータ
- **GIVEN** `contentPadding` に左右余白を指定したリスト
- **WHEN** スクロールする
- **THEN** コンテンツは余白の内側に配置され、スクロールインジケータは余白に寄らずコンポーネントの右端に表示される

### Requirement: list の区切り線
list レイアウトでは、行の間に区切り線を既定で表示する (SHALL)。明示オプションで非表示にできる (SHALL)。グリッドレイアウトでは区切り線を表示しない (SHALL NOT)。

#### Scenario: 既定表示と opt-out
- **GIVEN** 区切り線オプション未指定のリスト
- **WHEN** 表示する
- **THEN** 各行の間に区切り線が表示される。非表示オプションを指定した場合は表示されない

#### Scenario: グリッドでは出ない
- **GIVEN** `.grid(columns: .fixed(2))` の宣言
- **WHEN** 表示する
- **THEN** 区切り線は表示されない

### Requirement: ルートヘッダー / フッター
`header:` / `footer:` クロージャで、コンテンツ全体の先頭・末尾に任意のビューを配置できる (SHALL)。ヘッダー / フッターはコンテンツと一緒にスクロールする (SHALL)。宣言しない場合は何も表示されない (SHALL)。

#### Scenario: ヘッダーのスクロール追従
- **GIVEN** `header:` を宣言したリスト
- **WHEN** 下方向へスクロールする
- **THEN** ヘッダーはコンテンツと一緒に画面外へスクロールする

### Requirement: セル自己サイズ
セルの高さはテンプレートのコンテンツに応じて自動決定される (SHALL)。利用者に高さの手動指定・事前計算を要求してはならない (SHALL NOT)。

#### Scenario: 可変行高
- **GIVEN** 行ごとにテキスト量が異なるリスト
- **WHEN** 表示する
- **THEN** 各行はコンテンツに必要な高さで表示され、切れ・余分な空白が生じない
