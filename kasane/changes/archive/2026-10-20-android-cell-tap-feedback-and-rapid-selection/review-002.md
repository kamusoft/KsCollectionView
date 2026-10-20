# レビュー結果: android-cell-tap-feedback-and-rapid-selection (002 回目)

**日付**: 2026-10-20
**判定**: APPROVED

## サマリー
review-001 の 2 件はどちらも解消した。Minor (実環境で直ったことの証跡) は、`evidence/` の A/B の静止画 4 枚と `evidence/list-transparent-feedback-ab.txt` で、cross/runtime-behavior-verification.md の 3 条件を満たした。3 条件は、修正前の再現・修正後に同じ手順での解消・change 配下の証跡。証跡に書かれた画素の数値は、保存された画像から自前で数え直して一致した。Suggestion (フォーカスの表示も消えること) は、公開 KDoc に 1 文足して反映された。コードの差分は review-001 から KDoc だけが増えており、新しい指摘は無い。

## 照合した規約
- cross/comment-policy.md (always) — 公開 KDoc に足した 1 文
- cross/runtime-behavior-verification.md — review-001 の Minor への対応 (押下の帯は描画の症状で、ユニットテストで再現できないため、この規約の完了の条件に当たる)。規約の 3 条件と「目視確認の観測点」の節 (リストの画面の観測点「タップ feedback、通常タップと長押しの排他」・修正前後で同じ操作と観測点を使う) を照合した
- cross/test-execution.md — 対象テストクラスの再実行と件数の確認
- ksn-core references/evidence.md・references/ui-artifacts.md — 証跡の置き場・ファイル名・写り込み
- 関連 ADR: core/ADR-0037 (accepted)・core/ADR-0038 (proposed、この変更の決定)。review-001 の照合から変わらない
- lessons: kasane/lessons/code-review.md の L-001 に当たる (証跡に画素の計測値がある)。証跡を撮った後のコードの変更は KDoc だけで、挙動は変わっていない。パッケージの制約でエミュレータは使えないので、エミュレータでの撮り直しはしていない。代わりに、保存された画像から数値を数え直して確かめた (下記)。L-002 は当たらない (押下の反応の有無で、動きの過程が見える機能ではない)

ロードしたスキル: ksn-review / kotlin-impl-skill / jetpack-compose-impl-skill

## 確認した観点

**review-001 の指摘への対応**
- Minor「実環境で直ったことの証跡が無い」: 解消
  - 修正前の再現: `evidence/list-transparent-pressed-before.png` で、Cherry の行の全体が灰色になっている。`touchFeedbackColor = Color.Transparent` を渡した Sample のリストの画面で撮っている (`evidence/list-transparent-feedback-ab.txt` の「Sample の仮の書き換え」)
  - 修正後の解消: `evidence/list-transparent-pressed-after.png` は同じ操作 (`input motionevent DOWN 700 1005` の 0.3 秒後) で、帯が出ていない。修正前と修正後は、同じ版 (develop の 95d3fb9) に、この change の差分を当てたかどうかだけが違う。仮の書き換えは両方のビルドで同じ。A/B の形になっている
  - 撮り損ねの否定: 修正後の画像が「指を上げた後に撮った」ものではないことを、同じ操作で長押しの知らせが届いたことで示している。反応が無いことの証跡として必要な裏付けがある
  - タップと長押しの知らせ: 修正前と修正後の両方で届いたことが、証跡のテキストの表に書かれている。画面の「最後の操作」は静止画には写っていない (押している間に撮ったため、表示は空)。規約は証跡を「スクリーンショット・ログ等」としており、手順と観測した文言をテキストに残す形で足りると判断した。タップと長押しが届くことは、ユニットテスト (`fullyTransparentFeedbackColorShowsNoFeedbackButDeliversTaps`) でも固定されている
  - 観測点: 手順の前に、観測点 (灰色の帯・タップの知らせ・長押しの知らせ) を表の行として決め、修正前後で同じものを見ている。handbook のリストの画面の観測点 (タップ feedback・タップと長押しの排他) と合っている
  - 画素の数値の検算 (L-001): 3 枚の PNG を自前のデコーダで読み、証跡に書かれた数値を数え直した。すべて一致した
    - 画像の大きさ: 1080x2400
    - Cherry の行の右側 (600,925)-(1060,1090) は 75,900 画素。押す前と修正後はすべて (255,255,255)。修正前はすべて白以外で、平均 (230.9,230.9,230.9)
    - 押す前との差の画素数: 修正前 197,638、修正後 0。上端を 100px と 150px の 2 通りで数え、どちらも同じだった
  - 証跡の置き場と写り込み: 置き場は `evidence/` で、静止画だけ (動画は無い)。ファイル名は `<画面>-<状態>` の形 (`list-transparent-pressed-before` / `-after`)。4 枚を開いて確かめた。エミュレータとデモのデータ (果物の名前) だけで、通知・アカウント・端末名などの個人の要素は写っていない。ステータスバーは時刻と電波の表示だけ。`scripts/identity-lint.py` を証跡のテキストに流して、検出は 0 件
- Suggestion「フォーカスの表示も消えることを KDoc に書く」: 反映済み。`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:148` に「キーボードなどで項目を選んだときのフォーカスの表示も出ない。」が足された。挙動は変わっていない。利用者向けの言葉で書かれ、内部の用語や ADR の参照は無い

**仕様充足** (差分全体の再確認)
- 合意スコープ: review-001 の確認から変わらない。不透明度がちょうど 0 の色のときだけ indication を `null` にする (`KsCollectionView.kt:469-476`)。ほとんど透明な色と `Color.Unspecified` は波紋に渡す。タップと長押しの知らせは届く。iOS のコードは変わっていない。事象 2 についてライブラリの変更は無い
- 足場の書き換え・無断の仕様逸脱: なし。deviation.md は無い。蒸留時に反映する項目は範囲外

**テスト**
- `android/` で `./gradlew :kscollectionview:testDebugUnitTest --tests '*KsCollectionViewInteractionTest*' --rerun-tasks` を実行した。結果の XML は `KsCollectionViewInteractionTest` の 25 件、失敗 0・エラー 0・スキップ 0 (追加の 3 件を含む)。review-001 からの変更は KDoc だけなので、全件 (516 件) の再実行はしていない
- テストの意味 (修正を外すと落ちる)・境界 (不透明度 1/255)・`Color.Unspecified`: review-001 の確認から変わらない

**設計品質**
- ADR・規約との照合: review-001 から変わらない。proposed の core/ADR-0038 は判定の根拠にしていない
- コメント: `scripts/comment-policy-lint.py --advisory` を差分の 2 ファイルに流して、禁止 0 件・要確認 0 件。足した 1 文は単独で読める
- オーバーエンジニアリング・汎用の品質・Kotlin と Compose の観点: 新しい差分は KDoc だけで、当たるものは無い

## 指摘事項

なし

## アクションプラン

なし (蒸留へ進めてよい。exploration.md の「蒸留時に反映」の 2 行 (concepts の操作契約・ADR の印) は蒸留で扱う)
