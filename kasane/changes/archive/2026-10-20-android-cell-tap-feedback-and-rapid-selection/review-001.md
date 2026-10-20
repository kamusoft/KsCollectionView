# レビュー結果: android-cell-tap-feedback-and-rapid-selection (001 回目)

**日付**: 2026-10-20
**判定**: APPROVED

## サマリー
exploration.md の決定事項 (論点 1 の A・論点 3・「完全に透明」の範囲・`Color.Unspecified` の扱い) は、`KsCollectionView.kt` の indication の決め方の変更と KDoc の追記で過不足なく満たされている。追加したテスト 3 件は、修正を外すと落ちる形で書かれており、境界 (不透明度 1/255) と `Color.Unspecified` も押さえている。Android 本体の全件 (516 件) が成功した。コードの指摘は無い。完了の報告の前に、実環境で直ったことを確かめる手順が残っている (Minor 1 件)。

## 照合した規約
- cross/comment-policy.md (always) — 公開 KDoc と実装側コメントの追記
- cross/test-execution.md — テストの追加と実行 (実行件数の確認・`--rerun-tasks`・タスク名の結果ディレクトリ)
- cross/runtime-behavior-verification.md — 押下の帯が見える不具合の修正の完了判定 (描画の症状はユニットテストで再現できないので、この規約に当たる)
- android/performance-verification.md は当たらないと判断した (項目の描画・再利用・スクロールの経路を変えていない。押下の反応を付けるかどうかの分岐だけ)
- 関連 ADR: core/ADR-0037 (accepted)・core/ADR-0038 (proposed、この変更の決定)・android/ADR-0003 (accepted)
- lessons: kasane/lessons/code-review.md (L-001・L-002 はどちらも当たらない。計測値の証跡は無く、動きの過程が見える機能でもない)

ロードしたスキル: ksn-review / kotlin-impl-skill / jetpack-compose-impl-skill

## 確認した観点

**仕様充足**
- 合意スコープの充足: 不透明度がちょうど 0 の色のときだけ indication を `null` にし、タップと長押しの知らせはそのまま届く (`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:469-476`・`:836-840`)。ほとんど透明な色と `Color.Unspecified` は今までどおり波紋に渡る。iOS のコードは変わっていない。事象 2 についてライブラリへの変更は無い (決定どおり)
- 足場の書き換え: レビュー対象の 2 ファイルは kasane/ の成果物に触れていない
- 無断の仕様逸脱: なし。deviation.md は無い。`Color.Unspecified` の扱いは「実装時に追記」として決定事項に書かれている
- 蒸留時に反映する項目 (concepts・ADR の印) は範囲外として扱った

**テスト**
- 全件の実行: `android/` で `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` を実行。31 クラス / 516 tests / 0 failures / 0 errors / 0 skipped。`KsCollectionViewInteractionTest` は 25 件で、追加した 3 件 (`fullyTransparentFeedbackColorShowsNoFeedbackButDeliversTaps`・`nearlyTransparentFeedbackColorStillShowsFeedback`・`unspecifiedFeedbackColorStillShowsFeedback`) は結果の XML で確認した
- テストが意味を持つか: 差し替え口 (`KsTapFeedback.indicationOverride`) は反応を出す側の分岐でだけ使われる。このため、完全に透明な色の判定が壊れて反応を出す側へ流れると、記録用の表現に押下が残って `fullyTransparent...` が落ちる。逆に、ほとんど透明な色や `Color.Unspecified` が反応を出さない側へ誤って流れると、残りの 2 件が落ちる。差し替え口の KDoc (`KsCollectionView.kt:104-109`) にもこの使われ方が書かれている
- 境界: 不透明度 1/255 (`Color(0x01FF0000)`) を「ほとんど透明」の側として確かめている。押下は 300ms で、長押しの判定時間より短いため、タップとして届く (既存のテストと同じ組み立て)
- 手抜き: なし。言い訳のコメントで実質スキップしているテストも無い

**設計品質**
- ADR との照合: accepted の core/ADR-0037 の「Android は渡した色を標準の波紋に渡す」から、完全に透明な色だけを外している。この例外は proposed の core/ADR-0038 (amends 0037) と合意スコープで決まっており、判定の根拠にしない (蒸留で accepted と印を付ける予定)。android/ADR-0003 の「ハンドラを宣言した項目だけを `combinedClickable` で包む」は変わらない
- オーバーエンジニアリング: なし。分岐 1 つと KDoc の追記だけで、公開 API は変わらない
- コメント: 実装側のコメント (`KsCollectionView.kt:465-468`) は、透明な色を波紋に渡すと灰色の帯になる理由と `Color.Unspecified` の扱いを、そのファイルだけで読める形で書いている。ADR の参照は `core/ADR-0038` の形。公開 KDoc (`KsCollectionView.kt:144-150`) に内部用語は無く、iOS と並べた結果とコールバックが届くことを利用者向けに書いている。`scripts/comment-policy-lint.py --advisory` を 2 ファイルに流して、禁止 0 件・要確認 0 件
- 汎用の品質: `touchFeedbackColor` は `Color?` で、null・`Color.Unspecified`・不透明度 0 の 3 つを分けて扱っている。使われない `defaultIndication` の `remember` は残るが、波紋の factory を作るだけで描画の仕事は無く、性能の問題にならない。並行・リソースの観点で当たるものは無い
- Kotlin・Compose の観点: `isSpecified` の import 1 件の追加だけで、`!!`・可変な状態の追加は無い。`combinedClickable(interactionSource = null, indication = null)` は、押下の反応を付けずにクリックの semantics を保つ正しい組み合わせ (`KsCollectionViewInteractionTest` の既存のテストで、クリックと長押しの受け口が付くことを確かめている)

## 指摘事項

### 🟡 Minor 実環境で直ったことを確かめた証跡が change に無い
**該当箇所**: `kasane/changes/android-cell-tap-feedback-and-rapid-selection/` (evidence/ が無い)
**問題点**: 事象 1 (押した直後に灰色の帯が一瞬見える) は描画の症状で、Robolectric では波紋が描かれないため、ユニットテストでは症状そのものを再現できない。追加したテストは「項目に反応の表現が付かない」ことまでを確かめている。cross/runtime-behavior-verification.md は、こうした不具合の修正について、修正前に実環境で症状を再現し、修正後に同じ手順で消えたことを確かめ、証跡を change に残すまで完了と報告しない、と定めている。exploration.md には、波紋が不透明度を捨てる性質を実測した記録 (core/ADR-0037 の出典) はあるが、`Color.Transparent` で帯が出ることと、修正後に出ないことを、同じ手順で確かめた記録は無い。修正の仕組み (indication を付けなければ反応は描かれない) は Compose の API の約束で決まっているので、直っていない見込みは低い。それでもこの規約の完了の条件は満たしていない。
**推奨修正**: コードの直しは要らない。完了を報告する前に、エミュレータか実機で、`touchFeedbackColor = Color.Transparent` を渡した一覧のセルを押す。修正の前の版で灰色の帯が出て、修正の後の版で出ないことを確かめ、静止画を `evidence/` に残す (A/B)。タップと長押しが届くことも同じ手順で確かめる。

### 🔵 Suggestion 反応を出さないとき、キーボード操作のフォーカスの表示も消えることを KDoc に書く
**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:147-150`
**問題点**: indication を `null` にすると、押下の波紋だけでなく、material3 の波紋が出しているフォーカス・ホバーの表示 (キーボードや D-pad で項目を選んだときの塗り) も消える。決定事項は「押したときの反応を出さない」と書いており、フォーカスの表示が消えることには触れていない。スマートフォンで使う一覧では影響は小さい。また、反応を消すのは利用者が自分で選ぶことなので、挙動を直す必要は無い。
**推奨修正**: 公開 KDoc の「押したときの反応を出さない」の後に、キーボードで選んだときの表示も出ない旨を 1 文足す。挙動は変えない。蒸留で concepts の操作契約に書くときも同じ範囲で書く。

## アクションプラン
1. (Minor) 完了を報告する前に、実環境で修正の前後を比べ (A/B)、証跡を `evidence/` に残す。cross/runtime-behavior-verification.md の完了の条件
2. (Suggestion・任意) 公開 KDoc に、フォーカス・ホバーの表示も消えることを書き足す
