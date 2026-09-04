# samples (Android Sample と iOS 追随) — デルタスペック

## ADDED Requirements

### Requirement: Android Sample の器
`samples/android/` は独立した Gradle ビルドルートであり、本体 `android/` を composite build で参照する (SHALL)。Sample アプリの依存宣言は利用者と同じ配布座標 (`jp.kamusoft:kscollectionview`) 1 行で書き、その実体はソース参照へ置換される (SHALL)。置換が効かない場合に公開版へ黙ってフォールバックしてはならない (SHALL NOT)。版の宣言元は本体の version catalog 1 箇所とし、Sample はそれを共有する (SHALL)。Sample の application ID は `jp.kamusoft.kscollectionview.samples.android` とする (SHALL)。

#### Scenario: 本体の修正が Sample に映る
- **GIVEN** 本体 `android/` のソースを変更した状態
- **WHEN** Sample をビルドして起動する
- **THEN** 変更後の本体で Sample が動作する (公開版の artifact は参照されない)

### Requirement: デモ画面の集合と文言の一致
Android Sample は iOS Sample と同じ 9 つのデモ画面を持ち、ルートメニューの項目と画面タイトルは iOS の `SampleScreen` の文言と一字一句一致する (SHALL)。画面一覧とタイトルは 1 箇所 (`SampleScreen`) で定義し、メニューと画面タイトルを別々に持ってはならない (SHALL NOT)。各デモ画面の構成 (件数・初期値・選択肢の文言・DSL に渡すパラメータ) と `SampleTheme` の色 (RGBA) は iOS と同じ値とする (SHALL)。OS 標準のナビゲーション chrome・フォントの差は許容する (handbook/cross/sample-parity.md)。

#### Scenario: ルートメニューの一致
- **GIVEN** Android Sample を起動する
- **WHEN** ルートメニューを表示する
- **THEN** 「リスト」「グリッド (固定列)」「グリッド (adaptive)」「向きで列数変更」「テンプレート切り替え」「ルートヘッダー/フッター」「スクロール制御」「スペーシングと余白」「大量件数」の 9 項目がこの順で並び、各遷移先の画面タイトルはメニュー文言と同一である

#### Scenario: デモ画面の構成一致
- **GIVEN** iOS Sample の「グリッド (固定列)」画面
- **WHEN** Android Sample の同名画面と並べて比較する
- **THEN** 列数・件数・操作列 (list⇄grid 切替) ・デモデータの文言・色が一致する

#### Scenario: 全画面の対応表による照合
- **GIVEN** 9 デモ画面それぞれのタイトル・初期データ・操作・DSL パラメータ・表示結果を iOS と Android で並べた対応表
- **WHEN** 各画面を iOS Simulator と Android Emulator で並べて目視照合する
- **THEN** 対応表の全項目が一致し、不一致があれば deviation.md に記録された追跡がある

#### Scenario: 「リスト」画面の区切り線 3 択
- **GIVEN** 「リスト」画面 (両プラットフォーム)
- **WHEN** 区切り線の操作を「なし」「既定」「アクセント」の順に切り替える
- **THEN** 区切り線が非表示 → ライブラリ既定の色 → SampleTheme の accent 色の順に即時に切り替わり、位置・本数は既定と同じ

### Requirement: Android 固有の検証画面
「検証: 行の高さ変化 (Android 固有)」を、デモ画面とは別区分 (`VerificationScreen`) としてルートメニューに置く (SHALL)。構成は iOS の同種画面と同じく、展開経路 2 種 (親の状態 / テンプレート内の状態) と list / grid の切替を持ち、行のタップで展開・折りたたみができる (SHALL)。この画面はデモ画面の集合に数えず、iOS への移植義務を負わない (SHALL)。

#### Scenario: 親の状態による展開
- **GIVEN** 検証画面で展開経路「親の状態」を選択
- **WHEN** 行をタップする
- **THEN** その行が展開 (再タップで折りたたみ) され、他の行の位置がそれに合わせて動く

#### Scenario: テンプレート内の状態による展開
- **GIVEN** 検証画面で展開経路「テンプレート内の状態」(テンプレート内の `remember` で展開状態を持つ) を選択し、行を展開する
- **WHEN** その行を、可視範囲と先読み分を確実に超える距離まで画面外へスクロールして戻す
- **THEN** 展開状態は初期値に戻っている (Compose の Lazy 系は可視範囲外の項目の Composition を破棄する。iOS の ios/ADR-0002 と同じ「残したい状態はモデル側へ」の契約)

### Requirement: 性能計測の自動実行
Sample と同じビルドルートに計測モジュール (Macrobenchmark) を持ち、「大量件数」画面に対するスクロール性能とメモリの計測を、人の操作なしに固定手順で実行できる (SHALL)。fixture (件数・列数・可変行高の混在規則・決定的生成) は iOS 規約と同じとする (SHALL)。

#### Scenario: 計測の再実行
- **GIVEN** 基準実機を接続した状態
- **WHEN** 計測モジュールを実行する
- **THEN** 同じ操作 (実座標フリック 3 秒 × 3 試行、全項目を通過する往復) が再現され、指標が結果として得られる

### Requirement: iOS Sample と dsl-samples の追随
iOS Sample は `KsTemplate` の推論形に追随し、「リスト」画面の区切り線の操作を Android と同じ 3 択 (なし / 既定 / アクセント) にする (SHALL)。dsl-samples.md は `KsTemplate` への改名と `listSeparatorColor` の語彙 (両言語) を反映し、公開語彙一覧を更新する (SHALL)。

#### Scenario: iOS Sample の追随
- **GIVEN** 追随後の iOS Sample
- **WHEN** 「テンプレート切り替え」画面のソースを見る
- **THEN** `KsTemplate(.message) { item in … }` の推論形で書かれ、ビルドと表示が成立する
