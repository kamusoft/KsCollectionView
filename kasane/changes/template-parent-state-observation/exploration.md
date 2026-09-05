# Exploration: template-parent-state-observation

## 課題 / 動機

ios-engine-foundation のライブ調整 (2026-09-03、高さ変化の検証画面 `samples/ios/KsCollectionViewSamples/HeightChangeVerificationView.swift`) で発見。

テンプレートのクロージャは `body` 評価の外 (UIKit 側のセル生成時) で実行されるため、そのクロージャの中でだけ読まれる親 View の `@State` (例: 展開中 ID の集合、選択中 ID) は SwiftUI の依存グラフに載らない。state が変化しても親 View の body は再評価されず、Representable の更新 (`updateUIViewController` → `KsCollectionViewController.update(configuration:)`) が届かないため、ライブラリの可視セル再構成 (ios-engine-foundation deviation.md「差分更新: 同値配列でも親の更新が来たら可視セルを再構成する (案 B)」) は一度も走らない。

ワーカーの A/B (ログ実測): `body` 内で同じ state を 1 行読むだけで正常に更新される。読まなければタップ後に何も起きず、溜まった状態はレイアウト切替や別タップなど無関係なタイミングでまとめて反映される (grid では 1 タップで追従する非対称あり、内訳未計測)。証跡: `archive/2026-09-04-ios-engine-foundation/evidence/height-change-before-*.png`、経緯: `archive/2026-09-04-ios-engine-foundation/session.md`。

案 B の目的 (SwiftUI の親状態を捕捉するテンプレートを成立させ、Android と挙動を揃える) は「親の更新が来る」前提に依存しており、その前提が成り立たない使い方が普通にあり得る。

## 検討した選択肢 (却下案と理由を含む)

探索 2026-09-05 (オーナーとの対話)。詳細と却下理由は ios/ADR-0008 の Alternatives Considered。

- A: 利用者契約のみ (親の状態は body でも読む) — 却下: API 上の手がかりが無く静かな失敗が起きやすい
- B: 観測する値を DSL で明示的に渡す modifier (仮称 `.observing(_:)`) — **採用**
- C: 状態を項目 (配列) または参照型モデルに持たせる書き方だけを支える (API 不変) — 単独では却下。参照型モデルをセルの中で観測する書き方 (C-2) は中身のアニメーションが成立する。C-1 (状態を項目に持たせる) と共に、ドキュメントには推奨ではなく参考として併記する (オーナー 2026-09-05)
- KsSettingsView CustomCell と同じくクロージャが (項目, content 値) を受け取る形 — 却下: 公開面の変更が大きい。効果は B と同じ
- B の未指定時に「観測値が変わったときだけ再構成」へ狭める — 却下: 静かな失敗の範囲が広がる (ADR-0006 の挙動を残す)

## 決定事項

- 案 B を採用する (オーナー 2026-09-05)。未指定時の挙動は ADR-0006 のまま残す (推奨に対する明示的な異論なし)
- 中身のアニメーションの改善余地 (SwiftUI のトランザクションを可視セル再構成に引き渡す) は、この change のスコープ内で探る (オーナー 2026-09-05)。成立しなくても B の採用は変えない
- C-1 / C-2 は推奨パターンではなく参考として利用者向けドキュメントに併記する (オーナー 2026-09-05)
- Android には対応 API を設けない。Compose のテンプレートは合成の中で実行され親の State を自動購読するため同じ問題は起きない (android/kscollectionview/.../KsCollectionView.kt の item 内 `itemContent(item)` で確認)

## ADR 候補 (作成済み: ios/ADR-0008 proposed / 未起票: —)

- accepted 昇格時に ios/ADR-0006 の Consequences (前提の成立条件を本 change に委ねる記述) を改訂する

## 未決の論点

探索済み (2026-09-05)。残る論点:

- modifier の正式名称 (仮称 `.observing(_:)`) と、複数の状態をまとめて渡す推奨形 (構造体 / タプル)
- SwiftUI のトランザクション (`context.transaction`) を可視セル再構成に引き渡すと中身がアニメーションするか (未検証。スコープ内の spike として提案の tasks に含める。判定はオーナー目視か offset ログの A/B で行い、静止画の非発現を根拠にしない)
- list と grid で追従が非対称だった内訳 (未計測。B の実装で消えるかを確認)

簡易起票時の疑問点 (経緯として保持):

- 参考先: KsSettingsView のカスタムセル (`../KsSettingsView/ios/Sources/KsSettingsViewUI/CustomCell*.swift`、SwiftUI DSL 側の対応物) が親 state の変化をどう捕捉しているか (オーナー示唆)
- 選択肢の見当: (1) 利用者契約として ADR 化 (親 state はテンプレート内だけでなく body 側でも読む) (2) 変更検知用の値を DSL で明示的に受け取る公開 API (3) KsSettingsView 方式の翻案
- list と grid で追従が非対称だった理由 (未計測)
- 案 B (deviation) の記述をどう改訂するか
- 検証画面は body で state を読む回避策を適用済み (回避策を外せば再現する) — `HeightChangeVerificationView` の「展開中: N 行」表示が依存を張っており、これを消すと遷移直後のタップで開閉が効かない状態に戻る
- アニメーションの非対称 (オーナー観察 2026-09-03, grid): テンプレート内 state は中身 (背景含む) と行高が一緒にアニメーションするが、親 state は行高だけ動き中身は瞬時に切り替わる。行 1 の展開はアニメーションあり・行 2 はなし。親 state の更新が SwiftUI のトランザクションとして届かず hosting configuration の差し替えで反映されるためと見られる。解き方によって中身のアニメーションが成立するかが変わるため、選択肢の評価軸に含める

- 根本解決後の確認手順 (オーナー指示 2026-09-03): Sample の回避策 (`HeightChangeVerificationView.swift` の「展開中: N 行」表示で body から `expandedIDs.count` を読んでいる箇所) を削除し、遷移直後の 1 タップ目から親 state 経路の開閉が効くこと、および中身のアニメーションがテンプレート内 state 経路と揃うことを Simulator で再確認する

## UI 素材

## 変更級の推奨: M (理由: 公開 API の追加 1 件、ADR-0008 起票済み、concepts (collection-items / collection-engine) とサンプルの追随、検証画面の回避策撤去と Simulator での再確認、アニメーション改善の spike が必要。触る能力は iOS の差分更新 1 つで可逆)
