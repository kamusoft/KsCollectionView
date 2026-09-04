# Exploration: template-parent-state-observation

## 課題 / 動機

ios-engine-foundation のライブ調整 (2026-09-03、高さ変化の検証画面 `samples/ios/KsCollectionViewSamples/HeightChangeVerificationView.swift`) で発見。

テンプレートのクロージャは `body` 評価の外 (UIKit 側のセル生成時) で実行されるため、そのクロージャの中でだけ読まれる親 View の `@State` (例: 展開中 ID の集合、選択中 ID) は SwiftUI の依存グラフに載らない。state が変化しても親 View の body は再評価されず、Representable の更新 (`updateUIViewController` → `KsCollectionViewController.update(configuration:)`) が届かないため、ライブラリの可視セル再構成 (ios-engine-foundation deviation.md「差分更新: 同値配列でも親の更新が来たら可視セルを再構成する (案 B)」) は一度も走らない。

ワーカーの A/B (ログ実測): `body` 内で同じ state を 1 行読むだけで正常に更新される。読まなければタップ後に何も起きず、溜まった状態はレイアウト切替や別タップなど無関係なタイミングでまとめて反映される (grid では 1 タップで追従する非対称あり、内訳未計測)。証跡: `archive/2026-09-04-ios-engine-foundation/evidence/height-change-before-*.png`、経緯: `archive/2026-09-04-ios-engine-foundation/session.md`。

案 B の目的 (SwiftUI の親状態を捕捉するテンプレートを成立させ、Android と挙動を揃える) は「親の更新が来る」前提に依存しており、その前提が成り立たない使い方が普通にあり得る。

## 検討した選択肢 (却下案と理由を含む)

(未探索)

## 決定事項

## ADR 候補 (作成済み: — / 未起票: テンプレートと親 state の観測契約 — 公開 API または利用者契約に関わるため ADR 級)

## 未決の論点

未探索 (簡易起票)。分かっている疑問点:

- 参考先: KsSettingsView のカスタムセル (`../KsSettingsView/ios/Sources/KsSettingsViewUI/CustomCell*.swift`、SwiftUI DSL 側の対応物) が親 state の変化をどう捕捉しているか (オーナー示唆)
- 選択肢の見当: (1) 利用者契約として ADR 化 (親 state はテンプレート内だけでなく body 側でも読む) (2) 変更検知用の値を DSL で明示的に受け取る公開 API (3) KsSettingsView 方式の翻案
- list と grid で追従が非対称だった理由 (未計測)
- 案 B (deviation) の記述をどう改訂するか
- 検証画面は body で state を読む回避策を適用済み (回避策を外せば再現する) — `HeightChangeVerificationView` の「展開中: N 行」表示が依存を張っており、これを消すと遷移直後のタップで開閉が効かない状態に戻る
- アニメーションの非対称 (オーナー観察 2026-09-03, grid): テンプレート内 state は中身 (背景含む) と行高が一緒にアニメーションするが、親 state は行高だけ動き中身は瞬時に切り替わる。行 1 の展開はアニメーションあり・行 2 はなし。親 state の更新が SwiftUI のトランザクションとして届かず hosting configuration の差し替えで反映されるためと見られる。解き方によって中身のアニメーションが成立するかが変わるため、選択肢の評価軸に含める

- 根本解決後の確認手順 (オーナー指示 2026-09-03): Sample の回避策 (`HeightChangeVerificationView.swift` の「展開中: N 行」表示で body から `expandedIDs.count` を読んでいる箇所) を削除し、遷移直後の 1 タップ目から親 state 経路の開閉が効くこと、および中身のアニメーションがテンプレート内 state 経路と揃うことを Simulator で再確認する

## UI 素材

## 変更級の推奨: 未判定 (公開 API / ADR に触れるため S ではない見込み)
