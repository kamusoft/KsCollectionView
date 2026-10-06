# Delta Spec: collection-interaction (library-default-colors-dark-mode)

両プラットフォーム共通。既存の「アイテムタップ / ロングタップ」(タップ時にフィードバックを出し、色を指定できる) は変えない。指定した色の濃さがプラットフォームごとにどう決まるかを、契約として書き足す (core/ADR-0037)。ライブラリの挙動は変えず、今の挙動を契約にする。色を指定しないときのフィードバック (各プラットフォームの標準) は既存の要件のままで、ここでは扱わない。

## ADDED Requirements

### Requirement: タップしたときの色の濃さの決まり方
`touchFeedback(color:)` / `touchFeedbackColor` に指定した色について、iOS は指定した色を、不透明度を含めてそのままフィードバックの塗りに使う (SHALL)。Android は指定した色をプラットフォーム標準の波紋の色として渡し、濃さは標準の波紋が決める (SHALL)。ライブラリは、両プラットフォームの濃さをそろえるために指定した色を加工しない (SHALL NOT)。

**Side Effects**: なし

#### Scenario: 半透明の色を指定する (iOS)
- **GIVEN** `touchFeedback(color:)` に半透明の色を指定し、`onItemTap` を宣言したリスト
- **WHEN** 項目を押している
- **THEN** フィードバックが、指定した色の不透明度のまま項目の中身の前面に出る

#### Scenario: 不透明度が違う同じ色みを指定する (Android)
- **GIVEN** `onItemTap` を宣言した 2 つのリスト。片方は `touchFeedbackColor` に不透明な色を、もう片方は同じ色みで半透明の色を指定している
- **WHEN** それぞれの項目を押し続ける
- **THEN** どちらも指定した色みの波紋が出て、押している間の濃さは 2 つのリストで同じになる
