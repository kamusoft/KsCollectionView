# レビュー結果: sample-group-header-spacing-color (001 回目)

**日付**: 2026-10-03
**判定**: APPROVED

## サマリー

diff は合意スコープ (`exploration.md` の決定事項) の 4 項目 (帯の背景を専用の色にする・配色の 2 組に同じ名前の色を足して `SampleTheme` から参照する・`SamplePaletteParityTest` の iOS の値の表に足す・帯の doc コメントを書き換える) をすべて満たし、スコープ外の変更は無い。色の値・名前・宣言の位置は両プラットフォームで一致している。Critical / Major は無く、優先度の低い Minor 1 件と Suggestion 1 件だけである。

iOS Sample の UI テストは全件を実行していない (下の「ビルドとテスト」)。判定は diff の照合と、Android のユニットテスト・iOS のビルド・UI テストのソースの検索で出した。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` (always)
- `kasane/handbook/cross/sample-parity.md` (`samples/` を触る)
- `kasane/handbook/cross/sample-debug-controls.md` (`samples/` を触る。操作・一覧の配置の入力には触れていないため該当する節なし)
- `kasane/handbook/cross/test-execution.md` (テストを実行し結果を報告する)
- 決定: cross/ADR-0004・cross/ADR-0007 (どちらも accepted)
- lessons: `kasane/lessons/code-review.md` の [L-001] (証跡の数値を自前で再現する) を適用。[L-002] (動きの過程) は、動きを変える変更ではないため適用外

ロードしたスキル: ksn-review、kotlin-impl-skill (Android の code-review)。iOS の code-review 用途のスキルは定義なし

## ビルドとテスト

| 対象 | 結果 |
|---|---|
| Android Sample のユニットテスト (`samples/android/` で `:app:testDebugUnitTest --rerun-tasks`、JDK 21) | 163 tests / 0 failures / 0 errors / 0 skipped (21 クラス。`SamplePaletteParityTest` は 5 tests / 0 failures)。同じ作業ツリーにある別 change `android-build-jdk-range` のビルド定義の変更を含む状態で実行 |
| iOS Sample のビルド (通常スキーム `KsCollectionViewSamples`、iOS 27.0 の専用 Simulator) | 成功 (app と UI テストのバンドルがビルドされ、テストが始まった) |
| iOS Sample の UI テスト (通常スキーム) | **未実行 (途中で切り上げ。オーナー指示)**。切り上げまでに終わっていたのは 44 件のうち 39 件で、39 passed / 0 failures (`AppearanceUITests` 3・`GroupingDemoUITests` 6・`ImageGridCountUITests` 1・`ImageLoadingSlotShownClippingUITests` 2・`ImageLoadingSlotUITests` 2・`InteractiveControlUITests` 3・`LargeDataCountUITests` 4・`PagingDemoUITests` 13・`ReorderDemoUITests` 10 件のうち 5)。`ReorderDemoUITests` の残り 5 件は走っていない。全件実行ではないため、完了判定の根拠には数えない |
| iOS Sample の UI テストのソースの検索 | `samples/ios/KsCollectionViewSamplesUITests/` を `pixel` `cgImage` `screenshot` `UIColor` `Color(` `groupHeader` `SampleTheme` `SamplePalette` `background` `rgb` `見出しの帯` で検索し、一致は 0 件。「帯」の一致は計数の帯・「更新できませんでした」の帯の文言と位置を見るもので、見出しの帯の色や画素の色を見るテストは無い。この変更が UI テストの合否を変える経路は、ソースの上では見つからない |
| コメント規約の lint (`python3 scripts/comment-policy-lint.py --summary`) | 禁止 0 件 (検査対象 473 ファイル)。`--advisory` でも `samples/` の要確認は 0 件 |

実物の見た目 (ライト / ダークでの見分け・固定中の見え方) はレビューでは見ていない。`summary.md` に記録されたオーナーの実物確認 (iPhone 11・iOS 27.0 の Simulator と Pixel 4a 相当・API 36 のエミュレータ) を前提にしている。

レビューのために作った専用の Simulator (`ksn-review-header-color-001`) は削除済み。Android のエミュレータは作っていない。

## 確認した観点

**仕様充足 (合意スコープ)**
- 帯の背景が両プラットフォームで `SampleTheme.groupHeader` になっている (`samples/ios/KsCollectionViewSamples/GroupHeaderBand.swift:22`、`samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/GroupHeaderBand.kt:33`)。帯を描く場所は `GroupHeaderBand` だけで、利用箇所 (グループ化・差分更新・並べ替え・Android の計測用の画面) はすべてこの部品を通る
- 配色のライト / ダークの 2 組に `groupHeader` があり、名前・値 (ライト #E3E3EA、ダーク #223050)・宣言の位置 (`separator` の次、`onAccent` の前) が両プラットフォームで同じ。iOS の `rgb(227, 227, 234)` `rgb(34, 48, 80)` は 16 進の値と一致する
- `SamplePaletteParityTest` の iOS の値の表にライト / ダークとも足されている。名前つきの一覧 (`namedArgb`) にも足されており、足し忘れると表との突き合わせが落ちる形になっている
- doc コメントが変更後の見え方に書き換えられている (両プラットフォームで同じ文)
- 変えないもの (グループの間隔 16・帯の高さ 40・グリッドの間隔 1・画面の背景と行の色・ライブラリ本体) に diff が無い。`GroupHeaderMetrics` と画面の背景の指定は触られていない
- 無断の逸脱なし。`deviation.md` は無く、記録の要る乖離も見当たらない
- 長命層 (handbook / concepts / decisions) の書き換えは diff に無い。「帯は画面の背景と同じ色」と書いた長命層の記述も無いため、蒸留送りの漏れもない

**テスト**
- 色の一致のテストが足した色を含めて通っている
- ダークの読みやすさの組に「文字 / 見出しの帯」「補助の文字 / 見出しの帯」が足されている。`summary.md` の「補助の文字とのコントラスト比 約 4.6」を自前で計算し直し、4.62 で再現した ([L-001])。主な文字は 10.93

**設計品質**
- cross/ADR-0007 (色を足すときは 2 組とも足し、両プラットフォームで同じ値にする) と `sample-parity.md` (色は `SampleTheme` に置き、OS の semantic color に任せない) に適合
- コメントは単独で読める。作業文書への参照・履歴の記述は無い (`cross/ADR-0007` の参照は既存の行で、許容される形)
- オーバーエンジニアリングなし。既存の色と同じ並びに 1 つ足しただけで、新しい抽象は無い
- Kotlin: `data class` の引数はすべて名前つきで渡されており、引数の追加で位置がずれる呼び出しは無い (`SamplePalette(` の呼び出しは `Light` と `Dark` の 2 つだけ)。`SampleTheme.groupHeader` は既存の色と同じ `@Composable @ReadOnlyComposable` の形で KDoc つき
- 入力検証・機密情報・並行性・リソースに関わる変更は無い

参考: 帯と周りの面のコントラスト比 (自前の計算)

| 組 | 帯 / 画面の背景 | 帯 / 行 | 主な文字 / 帯 | 補助の文字 / 帯 |
|---|---|---|---|---|
| ライト | 1.15 | 1.28 | 14.67 | 3.88 |
| ダーク | 1.42 | 1.22 | 10.93 | 4.62 |

## 指摘事項

### [🟡 Minor] ライトの帯の上の補助の文字 (件数) のコントラスト比が 3.88 で、変更前 (4.44) より下がっている (優先度: 低)

**該当箇所**: `samples/ios/KsCollectionViewSamples/SamplePalette.swift:35`、`samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/SamplePalette.kt:43`

**問題点**: ライトの補助の文字 (#6E7076) と帯 (#E3E3EA) のコントラスト比は 3.88 で、WCAG 2.x の AA (4.5) に届かない。変更前は帯が画面の背景 (#F2F2F7) だったので 4.44 だった (こちらも 4.5 未満)。件数は小さい文字 (iOS は `.footnote`、Android は `bodySmall`) で描かれる。`SamplePaletteParityTest` の読みやすさの検査はダークの組だけが対象 (`samples/android/app/src/test/kotlin/jp/kamusoft/kscollectionview/samples/android/SamplePaletteParityTest.kt:65`) なので、ライトの値はテストでは守られていない。`summary.md` はダークの値 (約 4.6) だけを書いていて、ライトの値には触れていない。

合意スコープの条件は「帯の上の主な文字と補助の文字が読める」で、数値の下限は決めておらず、オーナーが実物で見て確定している。したがって合意スコープへの違反ではない。

**推奨修正**: 修正は求めない。オーナーへ数値を伝えて受け入れを確かめる程度でよい。帯の値を変えるのは**見た目が変わる指摘**になり、しかも帯を画面の背景まで明るくしても 4.44 が上限なので、帯の色だけでは 4.5 に届かない (届かせるには補助の文字の色を変える必要があり、この change のスコープの外)。

### [🔵 Suggestion] `summary.md` のテスト結果に実行件数が無い

**該当箇所**: `summary.md:29`

**問題点**: 「Android Sample のビルドとユニットテスト成功」とだけ書かれ、実行件数が無い。`kasane/handbook/cross/test-execution.md` の「実行件数の確認までが検証」は、結果を報告するときに件数 (`N tests / M failures`) を併記するよう定めている。

**推奨修正**: 蒸留・コミットのときの記録には件数を添える (このレビューでの実測は 163 tests / 0 failures)。iOS Sample の UI テストを全件実行していないことも、そのまま残す。

## アクションプラン

1. 対応が必須の項目は無い。このまま次の段へ進めてよい
2. ライトの件数のコントラスト比 (3.88) をオーナーへ伝え、受け入れを確かめる (値を変えるなら見た目が変わるため、オーナーの実物確認をやり直す)
3. 蒸留・コミットの記録にテストの実行件数を添える。iOS Sample の UI テストは全件実行していない旨を残す (走った 39 件は成功、`ReorderDemoUITests` の 5 件は未実行)
