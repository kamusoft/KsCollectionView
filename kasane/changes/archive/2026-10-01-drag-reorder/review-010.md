# レビュー結果: drag-reorder (010 回目)

**日付**: 2026-10-01
**判定**: APPROVED

## サマリー
範囲は、6.3 のオーナーの指摘 (Android で見出しをまたぐと、持ち上げた項目の下に見出しの帯と同じ色の板が影つきで出る) の修正に絞った。影を、指の下へずらす層 (`ksReorderLift`、間隔を含む項目全体) から外し、間隔の修飾 (`ksItemSpacing`) より内側の新しい層 (`ksReorderLiftShadow`) に付け直した形は原因に対して正しい。新しいエミュレータで、リスト・横にずらした運び・グリッドのそれぞれで見出しをまたいで上下に運ぶ過程を連続したコマで見て、板が 1 コマも出ないことを確かめた。証跡の数え方と画素の値も再現した。ずらし方・重なり順・グリッドの行間・区切り線・高さの補間・持ち上げていないときの描画に新しい問題は見つからず、Critical / Major / Minor はない。

## 照合した規約
- cross/comment-policy.md (always。追加されたコメントの自己完結性。`scripts/comment-policy-lint.py` は禁止 0 件)
- cross/test-execution.md (テストの実行と件数の報告)
- cross/runtime-behavior-verification.md (不具合修正の完了の判定。エミュレータで A/B の後側を再現)
- android/performance-verification.md (項目の描画の経路に触れるため。持ち上げていない項目の層の有無をコードで照合。今回の修正で計測は求めない — 下の観点を参照)

ロードしたスキル: ksn-review, kotlin-impl-skill, jetpack-compose-impl-skill (パッケージの指定による。本文は ksn-review の観点と、Compose の修飾の順序・グラフィックスレイヤー・状態の読み取りの位置の観点で使った)。lessons: code-review.md の [L-001]・[L-002]、inbox の observe-drag-feel-while-autoscrolling.md・confirm-emulator-ownership-before-operating.md

## 確認した観点

### 変わったコード
- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsReorderLift.kt:52-73` — 外側の層 (`KsReorderLiftNode`) は `placeWithLayer(offset, zIndex = 2f)` だけで影を付けない。ずらす量の求め方 (配置の中で自分の座標と指の位置を読む) は変わっていない
- `KsReorderLift.kt:108-126` — 新しい `KsReorderLiftShadowNode` は、`controller.liftedKey != key` の間は `place(0, 0)` で層を作らない。持ち上げている間だけ `placeWithLayer(0, 0) { shadowElevation = 8dp × liftAmount }`。`liftAmount` はレイヤーのブロックの中で読むため、戻りの途中の濃さの変化は層の描き直しだけで済む (配置や再コンポジションを起こさない)
- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:751-808` — 修飾の順は `ksReorderLift` (外側) → `ksAppearance` → `fillMaxWidth` → (グリッドの行末の項目だけ) `width(cellWidth)` → `ksItemSpacing` → **`ksReorderLiftShadow`** → `ksListSeparator` → 読み上げの操作 → `combinedClickable` → `ksAnimatedHeight`。影の層の大きさは content・区切り線・タップ領域の範囲になり、間隔を含まない
- 影が付く条件 (`liftedKey == key`) は外側の層がずらす条件と同じ (`KsReorderController.kt:71-76` の `liftedKey` と `:301-322` の `liftOffset` / `liftAmount` が、ドラッグ中とドラッグ後の戻りの間で同じ場合分けをしている)。戻りの終わりでは影が 0 まで薄くなってから層が外れる

### 判定を頼まれた点
| 点 | 結果 |
|---|---|
| オーナーの指摘の解消 | 解消。リストで見出しをまたぐ上下の運び 76 コマ・横にずらした運び 50 コマで板の行 0 (下の「実行時の確認」)。グループ 1 の最後の位置 (次のグループの見出しの直前) に来たコマを含む |
| 影の範囲 | content の範囲だけ。グループの最後の位置で、content の下端から下は影がなだらかに薄くなってページの色に戻る (間隔の中に影の輪郭の縁が無い)。上の行間・見出しの下の間隔にも輪郭が伸びない (グリッドで確認) |
| 重なり順 | 固定中の見出し (`zIndex(1f)`) より手前 (`zIndex = 2f`) のまま。グリッドで項目を固定中の「グループ 1」の帯の上まで運び、項目が帯の手前に描かれることを確認した (`evidence/review-010-android-grid-lift-over-pinned-header.png`)。影を内側の子の層に移したことで、外側の層の zIndex の効き方は変わらない |
| ずらし方 | 変わっていない。外側の層が間隔を含む項目全体を指の下へずらし、内側の影の層は `(0, 0)` に置くだけ。横にずらした運びでも影は content に沿って動く |
| グリッドの行間 | 行間は項目の上の間隔 (`topSpacing`) として `ksItemSpacing` の中にあり、影の輪郭に入らない。グリッドの行末で行の残りを占める項目 (`fillsLastLine`) は、影の層が `width(cellWidth)` の内側にあるため、影はセルの幅に沿う (外側の層は span の全幅) |
| 区切り線 | `ksListSeparator` は影の層の内側で、層の範囲の上端・下端に描く。持ち上げた項目の区切り線は項目と一緒に動き、置いた後の画面は運ぶ前と画素で一致した (スクロールインジケータの列を除く) |
| 高さの補間 (android/ADR-0004・ADR-0006) | `ksAnimatedHeight` は影の層より内側のため、補間の途中の高さが影の層の大きさになる。持ち上げた項目の配置のアニメーションを外す扱い (`ksAnimateItem` の `lifted`) は変わっていない |
| 持ち上げていないときの描画 | 2 つの節とも、持ち上げていない項目は `place(0, 0)` で層を作らない。`reorder` が null の一覧には修飾自体を付けない。持ち上げたとき・置いたときに見える項目の配置がやり直されるのは今までと同じ (`liftedKey` の読み取りが 1 項目あたり 2 か所になっただけ)。性能の計測を求めるほどの差はない |

### 汎用観点
- 仕様充足: 影の見た目はデルタスペックの Scenario には無く、design Decision 4 の「持ち上げ (指に付いて動かし、ほかの項目と固定の見出しより手前に描く)」の範囲の修正。スペックからの逸脱なし。tasks.md の 6.3 は未チェックのまま (オーナーの目視の見直しを待つ状態として正しい)
- 足場の書き換え: この修正に伴う proposal / design / specs の変更は見当たらない
- テスト: 指定のテストはすべて成功 (下)。この現象の自動テストは無い — 証跡に「Robolectric の影の描き方では直す前の失敗を再現できず、A/B で区別できないテストは残していない」とあり、エミュレータの A/B で確かめている。判断として妥当 (下の Suggestion 1 に、描き方に頼らない回帰の押さえ方を書いた)
- コメント: 2 つの KDoc と呼び出し側の 1 行のコメントは、なぜ影を間隔の内側に付けるか (透明な間隔に影が透けて板に見える) を単独で説明できている。外部文書の ID に頼る説明は無い
- 汎用の品質: 要素の `equals` / `hashCode` はキーとコントローラで比べる形で外側の節と同じ。状態の読み取りの位置 (キーは配置、濃さはレイヤーのブロック) は再コンポジションを起こさない形。リソースの漏れや不要な処理は見当たらない
- 入力検証・認証認可・機密情報: 該当なし

### テスト
`android/` で `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` を次のクラスに絞って実行し (BUILD SUCCESSFUL)、`build/test-results/testDebugUnitTest/*.xml` の件数で確かめた:

| クラス | 件数 | 失敗 / エラー / スキップ |
|---|---|---|
| KsReorderDragTest | 29 | 0 / 0 / 0 |
| KsReorderHoldTest | 15 | 0 / 0 / 0 |
| KsReorderPlannerTest | 10 | 0 / 0 / 0 |
| KsCollectionViewLayoutTest (間隔・グリッド) | 32 | 0 / 0 / 0 |
| KsCollectionViewGroupingTest (見出し・固定・グループ間の間隔) | 47 | 0 / 0 / 0 |
| KsCollectionViewCoreTest (区切り線) | 14 | 0 / 0 / 0 |
| KsCollectionViewInteractionTest (タップ領域・区切り線) | 22 | 0 / 0 / 0 |
| 合計 | 169 | 0 |

全件 (実装側の報告 474 件) は流していない (パッケージの範囲の指定による)。

### 実行時の確認 ([L-002]・[L-001])
- 環境: このレビュー用に作ったエミュレータ `ksn_drag_reorder_review10_pixel4a` (Pixel 4a の定義 / API 36 google_apis arm64、1080×2340、RAM 4096MB、port 5620)。起動前に `adb devices` で 5554 と実機 2 台だけが使われていることを確かめ、操作はすべて `adb -s emulator-5620 emu avd name` がこの名前を返すことを確かめるラッパーから送った。終わった後に停止した (AVD は残してある)
- 対象: Sample の benchmark 版 (`:app:assembleBenchmark` は up-to-date。APK の dex に `ksReorderLiftShadow` が入っていることを確かめてから入れた)。開始ルート `demo/Reorder`、並べ替え・グループが有効、パネルは畳んだ
- 期待値 (先に書いたもの): 持ち上げた項目の影は項目の面 (content) の縁から落ちるだけで、項目の下の間隔にページの色の板や影の縁が出ない。見出しをまたいでも、固定中の見出しの上に重なっても、影の形は項目の面の形のまま。置いた後に影や層が残らない (Android の Material の持ち上げと同じく、面そのものに影が付く見え方)
- 操作: `input motionevent` で長押し (1.2 秒) からのドラッグを合成し、12px 刻みで動かすたびに `screencap` を撮った

| # | 手順 | 結果 | 静止画 |
|---|---|---|---|
| 1 | リスト: 「グループ 2」の見出しのすぐ下の Item 101 を、300px 上 (グループ 1 の最後を越えて Item 99 の辺り) → 450px 下 → 150px 上と、見出しを 2 回ずつまたいで運ぶ (76 コマ) | 証跡と同じ数え方 (中央 x=540 がページの色 (242,242,247) で、右端が影の暗さ 214 以下の行) で、板の行は 76 コマすべて 0。Item 101 がグループ 1 の最後 (見出し「グループ 2」が 99 件) にいるコマ (f012 など) を含む | `evidence/review-010-android-list-across-header-sweep.png` (左から時間順の 8 コマ) |
| 2 | #1 の f012 (グループ 1 の最後にいるコマ) で、content の下端 (y≈1432) から下の画素を中央と右端で読む | 中央は +6px で 200、+38px で 234、+62px でページの色 (242) へと単調に明るくなる。右端も同じ。証跡の #2 (直した後: +6px の 199 から +40px の 233 へ単調) を再現した | (数値のみ) |
| 3 | リスト: Item 101 を 60px 左へずらしながら (オーナーの静止画と同じく横にずれた状態)、156px 上 → 300px 下 → 144px 上と運ぶ (50 コマ) | 板の行は 50 コマすべて 0。グループ 1 の最後にいるコマで、項目の右端の下にも間隔の分の影の縁は無く、影は面の縁に沿う | `evidence/review-010-android-list-across-header-offset-sweep.png` |
| 4 | グリッド (2 列): 見出しの下の Item 101 を 204px 上 → 360px 下 → 156px 上と、見出しをまたいで運ぶ (60 コマ) | グループ 1 の最後の行 (Item 101 だけの行) にいるコマ (f012) で、面の下端 (y≈1090) から下の影は +54px でページの色に戻り、グループ間の間隔の中に板は無い。面の上 (行間) にも輪郭の縁は無い | `evidence/review-010-android-grid-across-header-sweep.png` |
| 5 | グリッド: 項目を固定中の「グループ 1」の帯の上まで運ぶ (上端の自動スクロールが動く) | 持ち上げた項目は固定中の見出しより手前に描かれる。影の形は面の形のまま | `evidence/review-010-android-grid-lift-over-pinned-header.png` |
| 6 | #1・#4 の指を離して 1.5 秒後の画面を、運ぶ前の画面と比べる | 画素で一致 (リストはスクロールインジケータの列だけ差がある)。影や層は残らない | (比較のみ) |

- #5 のコマでは、自動スクロールで流れている間、ほかの項目が配置のアニメーションの途中で重なって見える。今回の修正の範囲外 (影と層の付け方に関係しない) で、観測として残す
- 直す前の APK は作っていない (A/B の前側は証跡の観測と、オーナーの静止画の見え方を正とした)。直した後の側は、証跡の数え方と画素の値を現行コードで再現した

## 指摘事項

### 🔵 Suggestion 1: 影の層が間隔の内側にあることを、描き方に頼らない形でテストに押さえる
**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:765-770`
**問題点**: 今回の不具合は修飾の順 (影の層と `ksItemSpacing` の前後) で決まる。証跡のとおり Robolectric の影の画素では直す前と後を区別できないが、順が将来の並べ替えで戻っても気づけるテストが無い。
**推奨修正**: 画素ではなく構造で押さえる案がある。たとえば、グループ間の間隔を大きくした一覧でグループの最後の項目を持ち上げ、項目の `LayoutInfo.getModifierInfo()` から `ksReorderLiftShadow` の節の座標 (`ModifierInfo.coordinates`) を取り、その高さが content の高さに等しく間隔を含まないこと、`extra` に層があることを確かめる。入れるかどうかは実装側の判断でよい (オーナーの目視の見直しが先)。

### 🔵 Suggestion 2: 影の輪郭が content の矩形であることを、テンプレートの利用者向けに書いておく
**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsReorderLift.kt:75-82` (内部の KDoc) / 公開の `KsReorder` の KDoc
**問題点**: 影の輪郭は content の範囲の矩形になった。テンプレートの根が背景を塗らない (透明な余白や角丸のカードを中に置く) 場合、Android の影は透明な範囲を透けて見えるため、今回の板と同じ種類の見え方が content の中で出る。Sample は根で背景を塗っているので出ない。今回の修正で新しく入った問題ではない (直す前も同じ)。
**推奨修正**: android/ADR-0004 の利用契約 (テンプレートの根で背景を塗る) と同じ形で、並べ替えの KDoc か利用者向けガイドに「持ち上げたときの影は項目の面の矩形に付く。根で背景を塗る」と一言添えることを、蒸留時の反映の候補にする。

## アクションプラン
1. (必須なし) オーナーの目視 (tasks 6.3 の見直し) で、基準機 (Pixel 4a / Android 13) の見え方を確かめる
2. (任意) Suggestion 1 の構造のテストを足すか決める
3. (任意・蒸留時) Suggestion 2 の一言を KDoc かガイドに入れるか決める
