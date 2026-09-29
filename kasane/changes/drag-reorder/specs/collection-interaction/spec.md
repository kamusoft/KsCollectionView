# collection-interaction — デルタスペック

両プラットフォーム共通。既存の「アイテムタップ / ロングタップ」(ios-engine-foundation・android-wrapper-foundation で追加) に、並べ替えのスイッチが有効な間の長押しの扱いを足す。

## MODIFIED Requirements

### Requirement: アイテムタップ / ロングタップ
`onItemTap` / `onItemLongTap` で、タップされた要素が型付きで渡るコールバックを宣言できる (SHALL)。タップ時はプラットフォーム標準のタッチのフィードバックが表示され (SHALL)、`touchFeedback(color:)` / `touchFeedbackColor` で色を指定できる (SHALL)。ハンドラ未宣言の要素はタップしてもフィードバックを出さない (SHALL NOT)。セル内のインタラクティブ要素 (ボタン・トグル等) がタッチを処理した場合、アイテムのタップコールバックとフィードバックは発火しない (SHALL NOT)。タップ追跡中にスクロールが始まった場合、タップはキャンセルされコールバックは発火しない (SHALL)。`onItemTap` と `onItemLongTap` は排他で、長押しが成立したタッチでは `onItemTap` を発火しない (SHALL NOT)。並べ替えのスイッチが有効な間は、長押しは並べ替えの操作になり、`onItemLongTap` は動かせない項目も含めて発火しない (SHALL NOT)。`onItemTap` は並べ替えのスイッチによらず発火する (SHALL)。並べ替えのスイッチが有効な間は `onItemLongTap` をハンドラに数えず、`onItemTap` を宣言していない要素はタップしてもフィードバックを出さない (SHALL NOT)。

#### Scenario: セル内ボタンとの競合
- **GIVEN** テンプレート内にボタンを含むセルと `onItemTap` の宣言
- **WHEN** セル内のボタンをタップする
- **THEN** ボタンのアクションだけが実行され、`onItemTap` は発火しない (セル背景の余白をタップした場合は `onItemTap` が発火する)

#### Scenario: タップで型付き要素が渡る
- **GIVEN** `onItemTap` を宣言したリスト
- **WHEN** 要素をタップする
- **THEN** タップ中はフィードバックが表示され、離した時点でその要素がコールバックに渡る

#### Scenario: ロングタップ
- **GIVEN** `onItemLongTap` を宣言したリスト (並べ替えのスイッチは無効)
- **WHEN** 要素を長押しする
- **THEN** 長押し閾値の経過時点でその要素がコールバックに渡る (通常タップのコールバックは発火しない)

#### Scenario: 並べ替えが有効な間の長押し
- **GIVEN** `onItemLongTap` と並べ替えを宣言し、スイッチを有効にしたリスト (「動かせるか」が偽の項目を含む)
- **WHEN** 動かせる項目を長押しする / 動かせない項目を長押しする
- **THEN** 動かせる項目ではドラッグが始まり、どちらの項目でも `onItemLongTap` は発火しない

#### Scenario: 並べ替えが有効な間のタップ
- **GIVEN** `onItemTap` と並べ替えを宣言し、スイッチを有効にしたリスト
- **WHEN** 要素をタップする
- **THEN** その要素が `onItemTap` に渡る

#### Scenario: 長押しの知らせだけを宣言した一覧のタップ
- **GIVEN** `onItemLongTap` だけを宣言し (`onItemTap` なし)、並べ替えのスイッチを有効にしたリスト
- **WHEN** 要素をタップする
- **THEN** フィードバックは出ず、どのコールバックも発火しない

#### Scenario: スイッチを無効に戻すと長押しが戻る
- **GIVEN** 並べ替えのスイッチを有効にしていたリスト
- **WHEN** スイッチを無効にしてから要素を長押しする
- **THEN** その要素が `onItemLongTap` に渡る
