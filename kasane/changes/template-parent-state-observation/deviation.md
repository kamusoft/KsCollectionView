# Deviation: template-parent-state-observation

## modifier の名称 (tasks 1.1)

- 確定名: `observedValue(_:)` (仮称 `.observing(_:)` から変更) (2026-09-05)
- 理由: 既存の利用者向け modifier (`header` / `footer` / `touchFeedback(color:)` / `listSeparators(_:)` / `listSeparatorColor(_:)` / `scrollController(_:)`) は、イベントハンドラ (`onItemTap` / `onItemLongTap`) を除きすべて「設定する対象」を表す名詞句で統一されている。Swift API Design Guidelines も非破壊のメソッドは名詞句を推奨しており、動名詞の `observing` は既存の並びから外れる
- 加えて `observedValue` はデルタスペックの語彙「観測する値」と 1 対 1 で対応し、doc コメント・利用者向け説明と用語がずれない
- シグネチャ: `public func observedValue<Value: Hashable>(_ value: Value) -> KsCollectionView<Item>` (内部では `AnyHashable?` として保持)

## 可視セル再構成の分割 (spec の解釈)

- spec (collection-core / 親の状態の観測) は「観測する値が前回と同じで配列も同値の更新では、可視セルを再構成しない」と書いているが、実装ではこの経路を **テンプレートのクロージャの呼び直し (中身の作り直し)** と **位置依存の表示・タッチ時の背景色の追随** に分け、前者だけを止めた (2026-09-05)
- 理由: 後者まで止めると、観測する値を宣言している利用者に限り `touchFeedback(color:)` の色変更が表示中のセルへ届かなくなる (既存テスト `testtouchFeedback色の変更を可視セルへ反映する` が守っている挙動が、観測する値の宣言時だけ失われる) 回帰になる。Scenario「観測する値が同じなら可視セルを再構成しない」の要点はカッコ書きの「テンプレートのクロージャは再実行されない」であり、この分割はその要点を満たす

## アニメーションの spike (tasks 2.1 / 2.2): A・B・C とも効果なしにつき取り込まない

`updateUIViewController` の `context.transaction` を `withTransaction` で可視セル再構成へ引き渡す試作を行い、検証画面「行の高さ変化」の親 state 経路で A/B を取った。判定は静止画ではなく、行のセルと content view の presentation layer の高さをフレームごとに記録したログの A/B で行った。

結論は構成ごとに射程が異なる (2026-09-05):

- **構成 A / B は効果なしが確定**。親の state 変更で届く transaction は `animation=nil` であり、引き渡せるアニメーションがそもそも載っていない。この否定は frame ログに依存しない論理的な帰結
- **構成 C も効果なし (オーナー目視で確定、2026-09-05)**。`animation=DefaultAnimation` は実際に届いており機構としては引き渡せているが、中身 (SwiftUI 側の描画) がアニメーションするかは frame ログの射程外だった (下記のとおり content view の内部レイヤーを外から観測できない)。そのため構成 C を再適用した Sample を Simulator (iPhone 17 Pro / iOS 26.5) で起動し、オーナーが親 state 経路とテンプレート内 state 経路を同じ行のタップで見比べた結果、親 state 経路では中身のアニメーションに何の効果も観測されなかった。目視後に再適用分は撤去し、レビュー・verify 済みの状態へ戻した

**いずれの構成も試作は取り込まない**。A / B は効果を持ちえず、C はオーナー目視で効果が無かったため。中身のアニメーションの改善は、トランザクションの引き渡しでは解けない (別の解き方が要る) ことが本 change の結論。

試した構成 (いずれも Simulator iPhone 17 Pro / iOS 26.5、`--verify-height-change` で起動し行 1 をタップ):

| 構成 | 引き渡し | Sample のタップ | 届いた transaction |
|---|---|---|---|
| A | なし (現行) | そのまま | `animation=nil` |
| B | `withTransaction(context.transaction)` | そのまま | `animation=nil` |
| C | `withTransaction(context.transaction)` | `withAnimation` で包む | `animation=DefaultAnimation` |

観測結果:

- 親の state 変更で届く更新の transaction は `animation=nil` だった (A・B とも)。引き渡せるアニメーションがそもそも載っていないため、B は A に対して効果を持ちえない
- presentation layer の高さの推移は A・B・C で同一だった (サンプリング位相の差を除き一致)。いずれも行の高さが約 45pt → 141.7pt へ 0.35 秒程度かけて変化しており、この動きは UICollectionView の自己サイズ変更によるもので、transaction の有無に依存しない
- 中身 (SwiftUI 側の描画) が同時にアニメーションしているかは、この計測では判定できなかった。`UIHostingConfiguration` の content view は subview を持たず (`subviews=0`)、内部の描画レイヤーを外から観測できないため (構成 C の判定は上記のとおりオーナー目視で行った)
- 実測ログ (抜粋、構成 B): `t=0.013 cellPresent=45.2` → `t=0.097 cellPresent=99.0` → `t=0.298 cellPresent=140.1` → `t=0.448 cellPresent=141.7`。構成 A も同じ曲線 (`t=0.021 cellPresent=48.6` → `t=0.105 cellPresent=104.1` → …)

実測ログの全文は `evidence/transaction-spike.md` (構成 A / B / C)。spike のコード (Representable の `withTransaction`、controller の `CADisplayLink` によるフレームログ) はすべて撤去済み。modifier の実装は proposal のとおり、この結果に依存しない。

## list / grid の実操作確認 (tasks 3.2)

Simulator iPhone 17 Pro / iOS 26.5 で、親 state 経路の list / grid をそれぞれ実タッチで確認した (2026-09-05)。
遷移直後の 1 タップ目で展開し、次のタップで折りたたむことを両方で観測し、追従の差は無かった (別起票の材料なし)。
手順・観測結果・静止画の一覧は `evidence/height-change-tap-verification.md`。

## iOS 性能検証の扱い (handbook/ios/performance-verification.md)

本 diff は iOS エンジンの描画・再利用経路 (可視セルの再構成と snapshot 適用の分岐) に触れるため、
同規約の適用範囲に当たる。ただし加えた分岐は、観測する値が変わらない同値配列の更新でテンプレートの
呼び直しを**省く**方向のみで、フレームあたりの新規コストを足していない (配列が変わる更新で加えた
再構成対象も、対象は可視セルに限られる)。ただし観測する値が変わった配列変更の更新に限り、生き残った
可視セルを再構成対象へ加えるために新 snapshot の全識別子を 1 パス走査する処理が増えている (差分計算と
同じ O(n)、可視セルの判定は集合参照。review-002 Suggestion 2)。このため 2 系統 (hitch time ratio /
メモリ定常化) の計測は本 change では行わず、実機 + Instruments の計測を掛けるかはオーナー判断に委ねた。オーナー判断: 本 change では計測を見送る (2026-09-05)。

## 蒸留への申し送り

- tasks 4.1 / 4.2 (concepts の collection-items / collection-engine の更新) は ksn-implement の規律 (長命層の書き換え禁止) により実装フェーズでは行わず、ksn-distill Step 4 で行う (2026-09-05)
- Android の検証画面 (samples/android の HeightChangeVerificationScreen) に残る「展開中: N 行」表示は、Compose では回避策ではなく単なる表示のため撤去しない (オーナー判断 2026-09-05、review-001 Suggestion 4)
- ios/ADR-0006 の Consequences 改訂時に 1 行残す: 観測する値を宣言した場合は配列変更と同時の更新でも既存の可視セルが取り残されないが、宣言なしの経路は同じ状況で内容不変の既存セルを再構成しない (spec の合意範囲内。review-002 Suggestion 1)
