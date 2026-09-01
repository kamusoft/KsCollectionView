# collection-core (iOS) — デルタスペック

## ADDED Requirements

### Requirement: プレーンな配列と安定 ID による表示
`KsCollectionView` は、利用者が渡したプレーンな配列の全要素を宣言されたテンプレートで表示する (SHALL)。安定 ID の宣言は `Identifiable` 準拠、または `id:` キーパス指定のいずれでもよい (SHALL)。専用のコレクション型・ラッパー型・ライブラリ独自 protocol への準拠を要求してはならない (SHALL NOT)。安定 ID は `Hashable` であり、同一配列内で一意でなければならない (SHALL)。重複 ID は不正入力であり、debug ビルドでは assertion で検知する (SHALL)。

#### Scenario: Identifiable 準拠の配列を表示する
- **GIVEN** `Identifiable` に準拠した要素 100 件の配列
- **WHEN** `KsCollectionView(items)` に渡す
- **THEN** データソースの件数は 100 件になり、スクロールで全要素に到達・表示できる (画面内に生成されるセルは可視範囲 + 再利用分に留まる)

#### Scenario: 非準拠型を id: キーパスで表示する
- **GIVEN** `Identifiable` に準拠しない型 (KMP 共有モデル相当) の配列
- **WHEN** `KsCollectionView(items, id: \.itemId)` に渡す
- **THEN** 全件が描画され、差分更新も `itemId` を identity として動作する

### Requirement: 差分更新
利用者が配列を差し替えたとき、ライブラリは差分を計算し、挿入・削除・移動をアニメーション付きで適用する (SHALL)。内容変化の判定は `Equatable` 準拠 (NSObject 継承型は `isEqual`) による同値比較で行う (SHALL)。identity が同じで内容だけが変わり、テンプレートキーが不変の要素は、セルインスタンスを維持したまま内容を再構成する (SHALL)。identity が同じでもテンプレートキーが変わった要素は、セルを置換して新しいテンプレートで再描画する (SHALL) — 再利用プールをキー間で混ぜてはならない (SHALL NOT)。

#### Scenario: 挿入・削除・移動のアニメーション適用
- **GIVEN** 表示中の配列
- **WHEN** 要素の追加・削除・並べ替えを行った新しい配列を渡す
- **THEN** 変化した要素だけが挿入・削除・移動としてアニメーション適用され、無関係な要素は再描画されない

#### Scenario: 内容変更の再構成
- **GIVEN** 表示中の配列の要素 X
- **WHEN** X と同じ ID・同じテンプレートキーで内容の異なる要素を含む配列を渡す
- **THEN** X のセルはインスタンスを維持したまま新しい内容で再描画される

#### Scenario: テンプレートキー変更でのセル置換
- **GIVEN** 表示中の要素 X (キー .message)
- **WHEN** X と同じ ID でキーが .ad に変わった配列を渡す
- **THEN** X の位置のセルは .ad のテンプレートのセルに置き換わる

### Requirement: 値キーによるテンプレート切り替え
テンプレートは値キー (`Hashable` な任意の値) で切り替えられる (SHALL)。`template:` キーセレクタを宣言した場合、各要素はキー値に対応する登録テンプレートで描画される (SHALL)。キー値は再利用種別に写像され、同一キーの要素間でのみセルが再利用される (SHALL)。キーセレクタを省略した場合は単一テンプレートのクロージャで全要素を描画する (SHALL)。

#### Scenario: キー値ごとのテンプレート適用
- **GIVEN** `kind` プロパティが 2 種の値を持つ配列と、各値への `Template` 登録
- **WHEN** `KsCollectionView(items, template: \.kind)` で表示する
- **THEN** 各要素は自分の `kind` に対応するテンプレートで描画される

#### Scenario: 単一テンプレートの軽量形
- **GIVEN** 単一種別の配列
- **WHEN** `KsCollectionView(items) { item in ... }` で表示する
- **THEN** テンプレート登録なしで全件が描画される

### Requirement: 未登録キーの挙動
テンプレート未登録のキー値 (または型) を持つ要素が現れたとき、debug ビルドでは assertion で即停止する (SHALL)。release ビルドではクラッシュせず、該当要素の位置に最小高の空セルを表示し、警告ログを出力する (SHALL)。該当要素を非表示にしてはならない (SHALL NOT)。

#### Scenario: release ビルドでの未登録キー
- **GIVEN** 登録キーが `{message, ad}` で、`kind == .system` の要素を含む配列 (release ビルド)
- **WHEN** 表示する
- **THEN** アプリはクラッシュせず、該当位置に空セルが表示され、警告ログが出力される。件数は配列と一致する

### Requirement: セル再利用時の状態非保持
セルが画面外に出て再利用されるとき、セル内の SwiftUI 内部 state は保持されない (SHALL)。この挙動は利用者向けドキュメントに明記する (SHALL)。

#### Scenario: スクロール往復での状態初期化
- **GIVEN** セル内テンプレートが `@State` で展開状態を持つリスト
- **WHEN** 該当セルを、再利用が確実に発生する距離 (可視範囲の数倍以上) まで画面外へスクロールして戻す
- **THEN** 展開状態は初期値に戻っている (残したい状態はデータモデル側に持たせる)

### Requirement: 大量件数での仮想化・再利用
10,000 件規模の配列でも、生成されるセルは可視範囲 + 再利用プール分に留まり (SHALL)、メモリ使用量が件数に比例して増加してはならない (SHALL NOT)。固定高と可変行高が混在する 10,000 件のグリッドで、基準実機 (iPhone 11) の連続フリックスクロールにおいて hitch time ratio 5ms/s 未満を満たす (SHALL)。

#### Scenario: 可変行高混在 10,000 件のスクロール
- **GIVEN** 固定高と可変行高のセルが混在する 10,000 件のグリッド (Sample「大量件数」画面。デモデータは固定シード生成で再現可能にする)
- **WHEN** iPhone 11 実機で 3 秒間の連続フリックスクロールを 3 回行い Instruments (Animation Hitches) で計測する
- **THEN** hitch time ratio は **3 回すべて** 5ms/s 未満である。また、リスト全体の 1 往復スクロール後のメモリ使用量を基準に、さらに 1 往復してもメモリが増え続けない (再利用プール分で定常化する)
