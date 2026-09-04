# collection-core (Android + 対称 DSL 追随) — デルタスペック

## ADDED Requirements

### Requirement: プレーンな配列と安定 ID による表示 (Android)
`KsCollectionView` は、利用者が渡したプレーンな `List<Item>` の全要素を宣言されたテンプレートで表示する (SHALL)。安定 ID は `key: (Item) -> Any` ラムダで宣言する (SHALL)。専用のコレクション型・ラッパー型・ライブラリ独自 interface への準拠を要求してはならない (SHALL NOT)。`key` の戻り値は同一配列内で一意であり、Android の状態保存 (Bundle) に載せられる型 (文字列・数値・enum・`Serializable`・`Parcelable`) でなければならない (SHALL) — この制約は利用契約として利用者向けドキュメントに明記する (SHALL)。重複 ID は不正入力であり、debug ビルドでは assertion で検知し、release ビルドでは後勝ちで表示を継続して警告ログを出す (SHALL)。

#### Scenario: key ラムダで配列を表示する
- **GIVEN** `data class` の要素 100 件の `List`
- **WHEN** `KsCollectionView(items = list, key = { it.id }) { template { … } }` で表示する
- **THEN** スクロールで全要素に到達・表示でき、同時にコンポジションされる項目は可視範囲 + 先読み分に留まる

#### Scenario: release ビルドでの重複 ID
- **GIVEN** 同じ ID を持つ要素が 2 件含まれる配列 (release ビルド)
- **WHEN** 表示する
- **THEN** アプリはクラッシュせず、後に現れた要素だけが表示され、警告ログが出力される (debug ビルドでは assertion で停止する)

### Requirement: 差分更新 (Android)
利用者が配列を差し替えたとき、ライブラリは安定 ID を identity として挿入・削除・移動を反映する (SHALL)。identity が同じ要素は、項目に紐づく状態 (`remember` した値) と Composition 上の identity を維持したまま内容が更新される (SHALL)。identity が同じでもテンプレートキーが変わった要素は、新しいテンプレートで再描画する (SHALL)。テンプレートの中で親の状態を読む書き方は、親の再コンポーズによって反映される (SHALL)。可視範囲 (先読み分を含む) の外の要素を Composition に保持し続けてはならない (SHALL NOT)。個々の項目が再コンポーズされる回数は契約に含めない (Compose の skip 可否は要素型の stability に依存するため)。

#### Scenario: 内容変更の反映
- **GIVEN** 表示中の配列の要素 X (項目内に `remember` した状態を持つ)
- **WHEN** X と同じ ID・同じテンプレートキーで内容の異なる要素を含む配列を渡す
- **THEN** X の項目は新しい内容で描画され、`remember` した状態は維持される (項目が作り直されない)

#### Scenario: テンプレートキー変更での再描画
- **GIVEN** 表示中の要素 X (キー Message)
- **WHEN** X と同じ ID でキーが Ad に変わった配列を渡す
- **THEN** X の位置は Ad のテンプレートで描画される

#### Scenario: 親の状態をテンプレートで読む
- **GIVEN** 選択中 ID を親の state に持ち、テンプレートの中で「選択中なら強調」と描くリスト
- **WHEN** 選択中 ID を変更する
- **THEN** 新旧の選択項目の描画が更新される

### Requirement: 値キーによるテンプレート切り替え (Android)
テンプレートは値キーで切り替えられる (SHALL)。`template: (Item) -> Any` キーセレクタを宣言した場合、各要素はスコープ内の `template(key) { }` で登録したテンプレートのうちキー値が一致するもので描画される (SHALL)。キー値はそのまま再利用種別 (`contentType`) に写像され、同一キーの要素間でのみコンポジションが再利用される (SHALL)。キーセレクタを省略した場合は `template { }` の単一テンプレートで全要素を描画する (SHALL)。同じキーへの二重登録は不正入力であり、debug ビルドでは assertion で検知し、release ビルドでは後勝ちで登録を継続して警告ログを出す (SHALL) — core/ADR-0011。

#### Scenario: キー値ごとのテンプレート適用
- **GIVEN** `kind` プロパティが 2 種の値を持つ配列と、各値への `template(kind) { }` 登録
- **WHEN** `KsCollectionView(items, key, template = { it.kind })` で表示する
- **THEN** 各要素は自分の `kind` に対応するテンプレートで描画される

#### Scenario: 単一テンプレートの軽量形
- **GIVEN** 単一種別の配列
- **WHEN** `KsCollectionView(items, key) { template { item -> … } }` で表示する
- **THEN** キー登録なしで全件が描画される

#### Scenario: release ビルドでの二重登録
- **GIVEN** 同じキー Message に 2 つのテンプレートを登録したスコープ (release ビルド)
- **WHEN** 表示する
- **THEN** アプリはクラッシュせず、後に登録したテンプレートで描画され、警告ログが出力される (debug ビルドでは assertion で停止する)

### Requirement: 未登録キーの挙動 (Android)
テンプレート未登録のキー値を持つ要素が現れたとき、debug ビルドでは assertion で即停止する (SHALL)。release ビルドではクラッシュせず、該当要素の位置に最小高の空項目を表示し、警告ログを出力する (SHALL)。該当要素を非表示にしてはならない (SHALL NOT)。

#### Scenario: release ビルドでの未登録キー
- **GIVEN** 登録キーが `{Message, Ad}` で、`kind == System` の要素を含む配列 (release ビルド)
- **WHEN** 表示する
- **THEN** アプリはクラッシュせず、該当位置に空項目が表示され、警告ログが出力される。件数は配列と一致する

### Requirement: 大量件数での仮想化・再利用 (Android)
10,000 件規模の配列でも、同時にコンポジションされる項目は可視範囲 + 先読み分に留まり (SHALL)、ライブラリが保持するメモリが件数に比例して増加してはならない (SHALL NOT)。固定高と可変行高が混在する 10,000 件のグリッドで、基準実機の連続フリックスクロールにおいて、次の 2 条件を満たす (SHALL): (1) 同じ fixture を素の `LazyVerticalGrid` で描いた比較対象に対するフレーム時間指標 (P90 / P99) の劣化が 10% 以内、(2) 初回計測で校正し記録した絶対上限 (P99 のフレーム超過時間) 以内。計測手順は iOS 規約 (handbook/ios/performance-verification.md) と同じ fixture・同じメモリ判定 (連続 2 往復の増分が 2% 以内で定常) を Android の自動計測で行う (SHALL)。基準実機を代替する場合はオーナー承認を要し、代替機の結果は基準機の保証にならない旨を証跡に明記する (SHALL)。

#### Scenario: 可変行高混在 10,000 件のスクロール
- **GIVEN** 固定高と可変行高の項目が混在する 10,000 件のグリッド (Sample「大量件数」画面。デモデータは iOS と同じ決定的生成) と、同じ fixture を素の `LazyVerticalGrid` で描いた比較対象
- **WHEN** 基準実機で自動計測 (実座標フリック 3 秒 × 3 試行、warmup 後) を行う
- **THEN** 3 試行すべてで、フレーム時間指標 (P90 / P99) の比較対象に対する劣化が 10% 以内、かつ P99 が校正済みの絶対上限以内である

#### Scenario: メモリが件数に比例しない
- **GIVEN** 同じ fixture の 1,000 件と 10,000 件のグリッド
- **WHEN** それぞれで全項目を通過する往復を定常化 (連続 2 往復の増分が 2% 以内、上限 10 往復) まで重ね、定常時のメモリ (PSS 合計、往復終了時点) を記録する
- **THEN** 10,000 件の定常値と 1,000 件の定常値の差は、入力配列 (要素データ) 自体の増分を除いて件数比 (10 倍) に比例せず、可視範囲 + 先読み分の項目数で説明できる範囲に留まる

### Requirement: 値キーテンプレートの推論形 (iOS 追随)
iOS の値キーテンプレート宣言は、要素型とキー型を書かない推論形 `KsTemplate(.message) { item in … }` でコンパイルできる (SHALL)。テンプレート型の名前は `KsTemplate` とする (SHALL)。旧名 `Template` は残さない (SHALL NOT)。

#### Scenario: 推論形の宣言がコンパイルできる
- **GIVEN** `kind` プロパティを持つ要素の配列
- **WHEN** `KsCollectionView(items, template: \.kind) { KsTemplate(.message) { item in … }; KsTemplate(.ad) { item in … } }` と書く
- **THEN** 型注釈なしでコンパイルでき、各要素が `kind` に対応するテンプレートで描画される
