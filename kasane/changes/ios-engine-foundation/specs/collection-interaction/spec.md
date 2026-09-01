# collection-interaction (iOS) — デルタスペック

## ADDED Requirements

### Requirement: アイテムタップ / ロングタップ
`onItemTap` / `onItemLongTap` で、タップされた要素が型付きで渡るコールバックを宣言できる (SHALL)。タップ時はセル選択・ハイライト機構によるフィードバックが表示され (SHALL)、既定はプラットフォーム標準のハイライト、`touchFeedback(color:)` で色を指定できる (SHALL)。ハンドラ未宣言の要素はタップしてもフィードバックを出さない (SHALL NOT)。セル内のインタラクティブ要素 (ボタン・トグル等) がタッチを処理した場合、アイテムのタップコールバックとフィードバックは発火しない (SHALL NOT)。タップ追跡中にスクロールが始まった場合、タップはキャンセルされコールバックは発火しない (SHALL)。`onItemTap` と `onItemLongTap` は排他で、長押しが成立したタッチでは `onItemTap` を発火しない (SHALL NOT)。

#### Scenario: セル内ボタンとの競合
- **GIVEN** テンプレート内にボタンを含むセルと `onItemTap` の宣言
- **WHEN** セル内のボタンをタップする
- **THEN** ボタンのアクションだけが実行され、`onItemTap` は発火しない (セル背景の余白をタップした場合は `onItemTap` が発火する)

#### Scenario: タップで型付き要素が渡る
- **GIVEN** `onItemTap` を宣言したリスト
- **WHEN** 要素をタップする
- **THEN** タップ中はセルにハイライトが表示され、離した時点でその要素がコールバックに渡る

#### Scenario: ロングタップ
- **GIVEN** `onItemLongTap` を宣言したリスト
- **WHEN** 要素を長押しする
- **THEN** 長押し閾値の経過時点でその要素がコールバックに渡る (通常タップのコールバックは発火しない)

### Requirement: スクロール制御
`KsScrollController` を接続すると、ID 指定 (`scrollTo(id:position:animated:)`、position は start / center / end) と端への命令 (`scrollToStart` / `scrollToEnd`) でスクロールできる (SHALL)。公開 API は MainActor 上で提供する (SHALL)。未接続・接続解除後のコントローラへの命令は no-op とする (SHALL)。存在しない ID への命令は no-op とし、debug ビルドでは警告ログを出す (SHALL)。1 つのコントローラを複数の `KsCollectionView` に接続した場合は最後の接続だけが有効で、debug ビルドでは警告ログを出す (SHALL)。データ差し替えと同時に発行された命令は、発行時点で未完了の最後の差分反映の完了後に実行される (SHALL) — core/ADR-0007 の順序保証。命令実行前に対象要素が削除された場合、その命令は no-op となる (SHALL)。

#### Scenario: 存在しない ID への命令
- **GIVEN** 接続済みコントローラ
- **WHEN** 配列に存在しない ID で `scrollTo(id:)` を呼ぶ
- **THEN** スクロールは起きず、クラッシュしない (debug では警告ログが出る)

#### Scenario: ID 指定スクロール
- **GIVEN** 表示範囲外の要素 X を含むリスト
- **WHEN** `scrollTo(id: X.id, position: .center)` を呼ぶ
- **THEN** X が表示範囲の中央に来るようスクロールする

#### Scenario: データ反映後のスクロール実行
- **GIVEN** 表示中のリストと接続済みコントローラ
- **WHEN** 配列末尾への要素追加と `scrollToEnd(animated:)` を同一処理内で連続実行する
- **THEN** 追加された新要素まで確実にスクロールする (反映前の末尾で止まらない)

#### Scenario: 未接続 no-op
- **GIVEN** どの `KsCollectionView` にも接続していない `KsScrollController`
- **WHEN** `scrollToStart()` を呼ぶ
- **THEN** 何も起きず、クラッシュ・警告もない
