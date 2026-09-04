# collection-interaction (Android) — デルタスペック

## ADDED Requirements

### Requirement: アイテムタップ / ロングタップ (Android)
`onItemTap` / `onItemLongTap` で、タップされた要素が型付きで渡るコールバックを宣言できる (SHALL)。タップ時はフィードバックが表示され (SHALL)、既定はプラットフォーム標準の ripple、`touchFeedbackColor` で色を指定できる (SHALL)。ハンドラ未宣言の要素はタップしてもフィードバックを出さない (SHALL NOT)。項目内のインタラクティブ要素 (ボタン・トグル等) がタッチを処理した場合、アイテムのタップコールバックとフィードバックは発火しない (SHALL NOT)。タップ追跡中にスクロールが始まった場合、タップはキャンセルされコールバックは発火しない (SHALL)。`onItemTap` と `onItemLongTap` は排他で、長押しが成立したタッチでは `onItemTap` を発火しない (SHALL NOT)。

#### Scenario: 項目内ボタンとの競合
- **GIVEN** テンプレート内にボタンを含む項目と `onItemTap` の宣言
- **WHEN** 項目内のボタンをタップする
- **THEN** ボタンのアクションだけが実行され、`onItemTap` は発火しない (項目背景の余白をタップした場合は `onItemTap` が発火する)

#### Scenario: タップで型付き要素が渡る
- **GIVEN** `onItemTap` を宣言したリスト
- **WHEN** 要素をタップする
- **THEN** タップ中は項目にフィードバックが表示され、離した時点でその要素がコールバックに渡る

#### Scenario: ロングタップ
- **GIVEN** `onItemLongTap` を宣言したリスト
- **WHEN** 要素を長押しする
- **THEN** 長押し閾値の経過時点でその要素がコールバックに渡る (通常タップのコールバックは発火しない)

#### Scenario: ハンドラ未宣言ではフィードバックなし
- **GIVEN** `onItemTap` も `onItemLongTap` も宣言しないリスト
- **WHEN** 要素をタッチする
- **THEN** フィードバックは表示されない

### Requirement: スクロール制御 (Android)
`KsScrollController` (plain class。View 所有用に `rememberKsScrollController()` も提供) を `scrollController` 引数で接続すると、ID 指定 (`scrollTo(id, position, animated)`、position は Start / Center / End) と端への命令 (`scrollToStart` / `scrollToEnd`) でスクロールできる (SHALL)。公開 API はメインスレッドから呼ぶ (SHALL)。未接続・接続解除後のコントローラへの命令は no-op とする (SHALL)。存在しない ID への命令は no-op とし、debug ビルドでは警告ログを出す (SHALL)。1 つのコントローラを複数の `KsCollectionView` に接続した場合は最後の接続だけが有効で、debug ビルドでは警告ログを出す (SHALL)。配列の差し替えと同じ処理内で発行された命令は、差し替え後の配列が表示に反映されてから実行される (SHALL) — core/ADR-0007 の順序保証。命令は発行順 (FIFO) に処理し、後の命令は先行する命令のアニメーションを中断して優先する (SHALL) — 最終的なスクロール位置は最後の命令で決まる。配列の更新はキュー内の命令を消失させてはならない (SHALL NOT)。命令実行前に対象要素が削除された場合、その命令は no-op となり後続の命令は継続する (SHALL)。要求位置 (Start / Center / End) に到達できない場合 (先頭・末尾付近の要素、表示範囲より大きい要素) は、スクロール可能範囲の端で止まるか、要素の先頭を表示範囲の先頭に合わせる (SHALL)。位置の基準は `contentPadding` の内側の表示範囲とし、ヘッダー / フッターは要素の index に数えない (SHALL)。

#### Scenario: 存在しない ID への命令
- **GIVEN** 接続済みコントローラ
- **WHEN** 配列に存在しない ID で `scrollTo(id)` を呼ぶ
- **THEN** スクロールは起きず、クラッシュしない (debug では警告ログが出る)

#### Scenario: ID 指定スクロール
- **GIVEN** 表示範囲外の要素 X を含むリスト
- **WHEN** `scrollTo(id = X.id, position = KsScrollPosition.Center)` を呼ぶ
- **THEN** X が表示範囲の中央に来るようスクロールする

#### Scenario: データ反映後のスクロール実行
- **GIVEN** 表示中のリストと接続済みコントローラ
- **WHEN** 配列末尾への要素追加と `scrollToEnd(animated = true)` を同一処理内で連続実行する
- **THEN** 追加された新要素まで確実にスクロールする (反映前の末尾で止まらない)

#### Scenario: 連続する命令
- **GIVEN** 接続済みコントローラ
- **WHEN** `scrollTo(id = A.id)` と `scrollTo(id = B.id)` を連続して呼ぶ
- **THEN** 最終的に B が表示範囲内にあり、A へのアニメーションは完了を待たず中断される

#### Scenario: 待機中に対象が削除された命令
- **GIVEN** 接続済みコントローラと表示中の配列
- **WHEN** 要素 X を除いた配列への差し替えと `scrollTo(id = X.id)`、続けて `scrollToEnd()` を同一処理内で呼ぶ
- **THEN** X への命令は何もせず、`scrollToEnd()` は実行されて末尾に到達する

#### Scenario: 到達できない位置の要求
- **GIVEN** 末尾から 2 番目の要素 X を含むリスト
- **WHEN** `scrollTo(id = X.id, position = KsScrollPosition.Center)` を呼ぶ
- **THEN** スクロール可能範囲の末尾で止まり、X は表示範囲内にある (中央に置けないことでクラッシュ・無限スクロールにならない)

#### Scenario: 複数接続は最後勝ち
- **GIVEN** 1 つのコントローラを 2 つの `KsCollectionView` (A、B の順) に接続した画面
- **WHEN** `scrollToEnd()` を呼ぶ
- **THEN** B だけがスクロールし、A は動かない (debug では警告ログが出る)

#### Scenario: 未接続 no-op
- **GIVEN** どの `KsCollectionView` にも接続していない `KsScrollController`
- **WHEN** `scrollToStart()` を呼ぶ
- **THEN** 何も起きず、クラッシュ・警告もない

#### Scenario: 接続解除後の no-op
- **GIVEN** `KsCollectionView` がコンポジションから外れた後のコントローラ
- **WHEN** `scrollToEnd()` を呼ぶ
- **THEN** 何も起きず、クラッシュしない
