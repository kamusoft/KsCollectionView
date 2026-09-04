# collection-layout (Android + 区切り線の色) — デルタスペック

## ADDED Requirements

### Requirement: layout 値による表示形態 (Android)
`layout` 値 1 つでリスト / 固定列グリッド / adaptive グリッド / 向き別列数を宣言できる (SHALL)。core/ADR-0006 の Kotlin 語彙 (`KsLayout.List(rowSpacing)` / `KsLayout.Grid(columns = KsColumns.Fixed(n) | KsColumns.Fixed(portrait, landscape) | KsColumns.Adaptive(minItemWidth), rowSpacing, columnSpacing)`) に従う (SHALL)。0 以下の列数・0 以下の `minItemWidth`・負のスペーシングは不正入力であり、debug ビルドでは assertion で検知する (SHALL)。向き別列数の判定はコンポーネント自身のコンテナの縦横比 (高さ > 幅なら portrait 側) で行い、端末の物理向きで判定してはならない (SHALL NOT)。

#### Scenario: 固定列グリッド
- **GIVEN** `KsLayout.Grid(columns = KsColumns.Fixed(3))` の宣言
- **WHEN** 表示する
- **THEN** 要素は 3 列で配置される

#### Scenario: adaptive グリッド
- **GIVEN** `KsLayout.Grid(columns = KsColumns.Adaptive(minItemWidth = 120.dp))` の宣言
- **WHEN** コンテナ幅が変わる
- **THEN** 最小アイテム幅を下回らない範囲で最大の列数が自動決定される。列間は指定した `columnSpacing` のまま固定され、余剰幅はアイテム幅へ均等配分される

#### Scenario: 向き別列数 (コンテナ縦横比基準)
- **GIVEN** `KsLayout.Grid(columns = KsColumns.Fixed(portrait = 2, landscape = 4))` の宣言
- **WHEN** コンテナの縦横比が変わる (端末の回転、分割画面でのリサイズ)
- **THEN** コンテナの高さ > 幅なら 2 列、幅 ≥ 高さなら 4 列で表示される

### Requirement: レイアウトの動的切り替え (Android)
表示中に `layout` 値を差し替えたとき、データの状態を保ったまま表示形態が切り替わる (SHALL)。切り替え直前に表示範囲の先頭にあった要素は切り替え後も表示範囲内にある (SHALL)。切り替え時に画面全体の再構築や表示の乱れを起こしてはならない (SHALL NOT)。

#### Scenario: list とグリッドの切り替え
- **GIVEN** リスト表示中の画面 (先頭可視要素 X)
- **WHEN** `layout` を `KsLayout.Grid(columns = KsColumns.Fixed(2))` に差し替える
- **THEN** 同じデータが 2 列グリッドで表示され、X は表示範囲内にある

### Requirement: スペーシング (Android)
行間 (`rowSpacing`) と列間 (`columnSpacing`) を layout 値のパラメータで宣言できる (SHALL)。既定値は 0 (SHALL)。`columnSpacing` は固定列・adaptive の全グリッドで有効とする (SHALL)。

#### Scenario: グリッドの行間・列間
- **GIVEN** `KsLayout.Grid(columns = KsColumns.Fixed(2), rowSpacing = 8.dp, columnSpacing = 8.dp)` の宣言
- **WHEN** 表示する
- **THEN** 行の間と列の間にそれぞれ指定の間隔が空く。既定 (未指定) では間隔なしで詰めて表示される

### Requirement: contentPadding (Android)
コンポーネントレベルの `contentPadding` (`PaddingValues`) で、コンポーネント本体とスクロールするコンテンツの間の内側余白を 4 辺個別に宣言できる (SHALL)。既定値は 0 (SHALL)。スクロールインジケータの位置は `contentPadding` の影響を受けない (SHALL)。

#### Scenario: 内側余白
- **GIVEN** `contentPadding` に左右余白を指定したリスト
- **WHEN** スクロールする
- **THEN** コンテンツは余白の内側に配置され、先頭・末尾まで余白の分だけ内側からスクロールする

### Requirement: list の区切り線 (Android)
list レイアウトでは、先頭行の上端・各行の間・最終行の下端に区切り線を既定で表示する (SHALL)。`listSeparators = false` で全て非表示にできる (SHALL)。グリッドレイアウトでは区切り線を表示しない (SHALL NOT)。既定の色・太さ・位置は iOS 実装と同じ実値とする (SHALL)。

#### Scenario: 既定表示と opt-out
- **GIVEN** 区切り線オプション未指定のリスト
- **WHEN** 表示する
- **THEN** 先頭行の上端・各行の間・最終行の下端に区切り線が表示される。`listSeparators = false` を指定した場合はいずれも表示されない

#### Scenario: グリッドでは出ない
- **GIVEN** `KsLayout.Grid(columns = KsColumns.Fixed(2))` の宣言
- **WHEN** 表示する
- **THEN** 区切り線は表示されない

### Requirement: 区切り線の色 (両プラットフォーム)
区切り線の色は、表示の有無 (`listSeparators`) とは独立した語彙 `listSeparatorColor` (Swift: `.listSeparatorColor(_:)` modifier / Kotlin: `listSeparatorColor =` 引数) で指定できる (SHALL)。未指定時はライブラリ既定の色を使う (SHALL)。`listSeparators` が非表示のとき `listSeparatorColor` は何も描かせない (SHALL)。

#### Scenario: 色の指定
- **GIVEN** `listSeparatorColor` に色を指定したリスト
- **WHEN** 表示する
- **THEN** 区切り線が指定した色で描かれ、位置・本数は既定と同じ

#### Scenario: 非表示との組み合わせ
- **GIVEN** `listSeparators = false` と `listSeparatorColor` の両方を指定したリスト
- **WHEN** 表示する
- **THEN** 区切り線は表示されない

### Requirement: ルートヘッダー / フッター (Android)
`header` / `footer` の Composable ラムダで、コンテンツ全体の先頭・末尾に任意の内容を配置できる (SHALL)。ヘッダー / フッターはコンテンツと一緒にスクロールし、グリッドでは全幅を占める (SHALL)。宣言しない場合は何も表示されない (SHALL)。配列が空でも表示される (SHALL)。

#### Scenario: ヘッダーのスクロール追従
- **GIVEN** `header` を宣言したリスト
- **WHEN** 下方向へスクロールする
- **THEN** ヘッダーはコンテンツと一緒に画面外へスクロールする

#### Scenario: 空配列でのヘッダー / フッター
- **GIVEN** `header` と `footer` を宣言し、配列が空のリスト
- **WHEN** 表示する
- **THEN** ヘッダーとフッターが表示され、項目は 0 件

#### Scenario: グリッドでの全幅ヘッダー
- **GIVEN** `header` を宣言した 3 列グリッド
- **WHEN** 表示する
- **THEN** ヘッダーは 3 列分の幅を占め、要素はその下から 3 列で並ぶ

### Requirement: セル自己サイズと content の配置 (Android)
項目の高さはテンプレートのコンテンツに応じて自動決定される (SHALL)。利用者に高さの手動指定・事前計算を要求してはならない (SHALL NOT)。項目の content は自然高のまま項目の上端に置かれ、行の高さに引き伸ばされない (SHALL)。content の自然幅が項目幅より小さいときは水平中央に置き、幅いっぱいに広がる content は先頭から敷く (SHALL) — iOS (ios/ADR-0007) と同じ配置規則。

#### Scenario: 可変行高
- **GIVEN** 行ごとにテキスト量が異なるリスト
- **WHEN** 表示する
- **THEN** 各行はコンテンツに必要な高さで表示され、切れ・余分な空白が生じない

#### Scenario: 狭い content の水平配置
- **GIVEN** 短いテキストだけを置いたテンプレートの 2 列グリッド
- **WHEN** 表示する
- **THEN** テキストは各項目の水平中央に置かれ、幅いっぱいの content (`fillMaxWidth`) は項目の先頭から敷かれる
