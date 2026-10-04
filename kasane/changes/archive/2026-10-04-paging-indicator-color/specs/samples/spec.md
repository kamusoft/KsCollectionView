# Delta Spec: samples (paging-indicator-color)

## ADDED Requirements

### Requirement: デモ画面「ページング」の読み込み中の表示の色
両プラットフォームのデモ画面「ページング」は、読み込み中の表示の色の設定に Sample 共通の配色の同じ色を指定し、次のページの読み込み中・最初の読み込み中・Pull to Refresh のインジケータを同じ色で出す (SHALL)。指定する色は両プラットフォームで同じ値で、Sample の外観 (ライト / ダーク) の切り替えに追随する (SHALL)。操作のパネルと、失敗・終端・空の表示は変えない (SHALL)。

**Side Effects**: なし

#### Scenario: 3 つの表示が同じ色でそろう
- **GIVEN** 「ページング」を開いている
- **WHEN** 最初の読み込み中・次のページの読み込み中・Pull to Refresh のインジケータをそれぞれ出す
- **THEN** 3 つとも Sample が指定した同じ色で描かれる (Android の Pull to Refresh は矢印がその色になる)

#### Scenario: 両プラットフォームで同じ色
- **GIVEN** 同じ外観を選んだ iOS と Android の「ページング」
- **WHEN** 読み込み中の表示を出す
- **THEN** Sample が指定している色の値は、両プラットフォームで同じである

#### Scenario: 外観の切り替えに追随する
- **GIVEN** 「ページング」で読み込み中の表示を出せる状態
- **WHEN** ルートメニューの「外観」でライトとダークを切り替える
- **THEN** 読み込み中の表示の色が、選んだ外観の配色の色になる

#### Scenario: ほかの表示は変わらない
- **GIVEN** 「ページング」を開いている
- **WHEN** 失敗・終端・空の表示と、操作のパネルをそれぞれ出す
- **THEN** この変更の前と同じ見え方で出る
