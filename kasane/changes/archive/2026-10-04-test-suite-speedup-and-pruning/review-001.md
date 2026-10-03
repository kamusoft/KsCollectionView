# レビュー結果: test-suite-speedup-and-pruning (001 回目)

**日付**: 2026-10-04
**判定**: APPROVED

## サマリー

仕分け表どおりに UI テストが 44 件から 11 件 (P3 の残置を含む) になり、移した 25 件は新設のユニットテスト 37 件が、画面が実際に呼んでいる型と関数 (`PagingDemoModel`・`ReorderDemoModel`・`DiffUpdateModel`・`GroupingDemoEdits`・各起動引数の `resolve`) を通して確かめている。通常スキームは 48 件・失敗 0、計測スキームのテスト用ビルドも通った。Critical / Major は無く、指摘は優先度の低い Minor 2 件と Suggestion 1 件。

## 実行結果

| 対象 | 結果 |
|---|---|
| 通常スキーム `KsCollectionViewSamples` (全件・1 回) | 48 tests / 0 failures (ユニットテスト 37 + UI テスト 11)。壁時計 208 秒 (ビルドと、新しく作ったシミュレータの初回起動を含む)。テスト区間はユニットテスト 0.4 秒 + UI テスト 158.8 秒 |
| 計測スキーム `KsCollectionViewSamplesPerformance` の `build-for-testing` | TEST BUILD SUCCEEDED (29 秒)。テストは実行していない |
| 通常スキームに計測ドライバが入っていないこと | 実行ログに `PerformanceDriverUITests` のテストケースは 0 件 |

- 使ったシミュレータ: このレビュー専用に作った iPhone 17 / iOS 27.0 (終了後に削除済み)
- iOS 本体・Android の 2 系統は流していない (依頼の範囲外)。渡された実測 (iOS 本体 144 秒・Android 本体 20 秒・Android Sample 13 秒) に今回の 208 秒を足すと 385 秒で、目標の 600 秒に収まる
- UI テストで長いものは A2 23.5 秒・L2 33.1 秒・P11 21.5 秒・R3 15.4 秒。残置中の P3 は 7.7 秒

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` (always) — `scripts/comment-policy-lint.py` で禁止 0 件。要確認 7 件は `samples/ios` の外
- `kasane/handbook/cross/sample-parity.md` (`samples/` を触る) — メニューの並び・文言・デモデータの値に変更なし
- `kasane/handbook/cross/sample-debug-controls.md` (`samples/` を触る) — 画面の操作の追加・変更なし
- `kasane/handbook/cross/test-execution.md` (テストを実行・報告する) — 実行件数の併記、通常スキームと計測スキームの分離、収束を待つアサーションの 3 条件
- `kasane/lessons/code-review.md` — L-001 (計測値は iOS Sample の分を自分で測り直した)、L-002 (動きの過程が見える機能の変更は無く対象外)

ロードしたスキル: ksn-review、swift-ui-impl-skill

## 確認した観点

**仕様充足**

- 仕分け表との一致: 残す 10 件 + P3 の残置 = UI テスト 11 件。消す S1・I3・P9・P12・P13・R5・R7 は削除済み。C2 は C1 に合流。移す 25 件はすべてユニットテストに対応がある
- 足場 (`exploration.md`) の書き換えは実装 diff の外で、今回の対象外
- deviation.md に無い逸脱は見つからなかった

**【消す】の根拠の突き合わせ (本体テストの読解)**

| # | 根拠の本体テスト | 判断 |
|---|---|---|
| S1 | 残した S2 の前段 (`samples/ios/KsCollectionViewSamplesUITests/ImageLoadingSlotUITests.swift:20-24`) が同じ正規表現で `sized` を待つ | 覆っている |
| I3 | `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:2459` — 長押しの認識器が無効であることと、選択の直呼びでタップが届くこと | 仕組みは覆っている。指で長く押して離す経路は通らない (実タッチは I1・I2 に残る) |
| P9 | `ios/Tests/KsCollectionViewTests/KsPagingPositionTests.swift:104` ほか — 取り直し中から差し替えで先頭になること (描画を挟む / 挟まないの両方、10,000 件、グリッド) | 覆っている。Sample の「取り直し中を一覧に届けてから取得する」配線は、残した P11 が実際の引っ張りで通る |
| R5 | `ios/Tests/KsCollectionViewTests/KsReorderEngineTests.swift:875` — 動かせない項目は持ち上がらない | 覆っている |
| R7 | `ios/Tests/KsCollectionViewTests/KsReorderEngineTests.swift:1279` — 並べ替えが有効な間は長押しの認識器が無効で知らせが呼ばれず、持ち上げはできる | 覆っている。置いた後の並びは残した R3 が見る |

**【移す】25 件が本番と同じ経路を通るか**

- メニューの並び (A3・G1・P1・R1): `RootMenuView` が `RootMenuRow.all` を上から描く形になり、テストは同じ配列を見る
- 起動引数 (IG・L1・L3・L4・P2・画面の指定): アプリが使う `resolve(arguments:)`・`value(for:)`・`SampleScreen.requested(arguments:)`・`DemoData.makeLargeItems(count:)` / `makeImageGridItems(count:)` をそのまま呼ぶ。アプリ側の値はこれらの関数の結果から作られている
- 外観 (A1): `SampleAppearance.resetIfRequested(arguments:defaults:)` を専用の保存先で確かめ、アプリの保存先に触れない
- ページング (P5〜P8・P10): 画面が呼ぶ `loadNextPage()`・`reload()`・`setEmpty(_:)`・`refresh()` を通す。`PagingListStub` は画面の `onChange` が行う `listDidReceiveRefreshing()` の呼び出しだけを代わりに行う
- 並べ替え (R2・R4・R6・R8〜R10): 画面が呼ぶ `move(_:)`・`canDrop(_:)`・`didLongPress(_:)` と `applying(_:to:)` を通す
- グループ化・差分更新 (G3〜G6): 画面のボタンが呼ぶ `GroupingDemoEdits.movingItem(at:in:)` と `DiffUpdateModel` の各操作を通す
- テストのためだけの別経路は、`ReorderDemoModel` の帯の時間の引数 1 つ。既定値は `SamplePanelMetrics.bannerDuration` (3 秒) のままで、画面は引数なしで作る

**残した UI テストと C2 の合流**

- A2・G2・S2・I1・I2・L2・P4・P11・R3 は本文のアサーションが変更前と同じ
- C1 に合流した C2 のアサーション (周期が止まる・足すと数えて再び止まる) は 2 つとも残っている

**Sample アプリ側の切り出し**

- メニュー: 行の種類ごとの View と修飾子は変更前と同じ。並びは見出し・外観 3 項目・隙間・デモ画面・技術検証画面の順のまま
- 画面の指定: 最初の `--screen` のすぐ後ろの値だけを読み、名前が一致しなければルートメニュー、という解釈は変更前と同じ
- 外観の保存の消去: 既定の引数が変更前の呼び方 (起動引数・標準の保存先) と同じ
- 帯の 3 秒: 上記のとおり既定値のまま。`PagingDemoModel` は未変更

**スキームとプロジェクト定義**

- 通常スキームは `PerformanceDriverUITests` を除外したままで、ユニットテストのターゲットが加わっただけ
- 計測スキームのテスト対象は UI テストのターゲットだけ (生成された実行定義でも確認)。除外は `InteractiveControlUITests`・`LargeDataCountUITests` の 2 つで、消えた `ImageGridCountUITests` の項目は残っていない
- `ENABLE_TESTABILITY = YES` はプロジェクトの Debug 構成だけにあり、Release には無い
- プロジェクト定義に開発者の識別子の混入なし (`scripts/identity-lint.py` で指摘なし)

**テストの品質**

- `SampleTestSupport.waitUntil` は実時間の期限・待つ間の譲り・期限超過時に値を添えて失敗、の 3 つを満たす
- 言い訳コメントでの実質スキップは無い。L3・L4 が「起動を止める配線」を覆えない点は仕分け表に記載済み

## 指摘事項

### [🟡 Minor] 画面の表示文言を確かめるテストが無くなった (優先度: 低)

**該当箇所**: `samples/ios/KsCollectionViewSamplesTests/PagingDemoModelTests.swift:36`、`samples/ios/KsCollectionViewSamplesTests/ReorderDemoModelTests.swift:13`

**問題点**: 変更前の UI テストは、画面に出る文言そのものを見ていた (「読み込めませんでした」「再試行」「これ以上ありません」「項目がありません」「Item 10 (移動不可)」「全 10,000 件・10 の倍数は移動不可」「件数: 2000」)。移した先のユニットテストはモデルの状態と配列を見るため、これらの文言が変わってもテストは落ちない。残っているのは P11 が見る 3 つと、R6・R8 の帯の文言だけ。文言は `kasane/handbook/cross/sample-parity.md` が両プラットフォームで一字一句の一致を求める対象である。

**推奨修正**: `RootMenuRowTests` がメニューの文言を値で固定しているのと同じ形で、`PagingDemoText` と `ReorderDemoText` の値を確かめるアサーションを既存のテストに足す。受け入れて足さない判断もありうる (cross/ADR-0008 の負の結果「Sample の画面の配線の崩れは UI テストで見つからない」の範囲)。

### [🟡 Minor] メニューの項目を押して画面を開く経路を通すテストが無くなった (優先度: 低)

**該当箇所**: `samples/ios/KsCollectionViewSamplesTests/RootMenuRowTests.swift:60-72`

**問題点**: 変更前の P1・R1 は、メニューの項目を実際に押して、開いた画面のタイトルまで見ていた。移した先は並びだけを見る。残した UI テストはすべて起動引数で画面を直接開くため、メニューから画面へ進む配線を通すテストが 1 件も無い。仕分け表の P1・R1 の根拠 (`SampleScreen.allCases`) は並びだけを指しており、押して開く部分の扱いは書かれていない。

**推奨修正**: オーナー判断。次のどちらか。

- 受け入れる (cross/ADR-0008 の負の結果の範囲とみなす)
- 残した UI テストのどれか 1 件を、起動引数ではなくメニューから開く形に変える (起動は増えない。メニューを送る数秒が加わる)

### [🔵 Suggestion] 古いページが混ざらないテストは、実行機が混むと別の理由で落ちうる

**該当箇所**: `samples/ios/KsCollectionViewSamplesTests/PagingDemoModelTests.swift:96-109`

**問題点**: 先に始めた読み込み (遅延 100 ミリ秒) が、取り直しを始める前に戻ってしまうと、項目が 100 件になった状態で検査に入り、「先に始めた読み込みのページが混ざっています」で落ちる。実際には混ざっておらず、取り直しが間に合わなかっただけである。黙って通ることはなく、今回の実行では 0.3 秒で通っている。

**推奨修正**: 取り直し中になった時点で、先に始めた読み込みがまだ追加読み込み中から戻っていない (項目が 50 件のまま) ことを先に確かめ、戻っていたら「取り直しが間に合わなかった」と分かる文言で失敗させる。または遅延を長くする。

## P3 の残置についての所見 (判定には数えない)

残す側の材料:

- 本体のテストのコメント (`ios/Tests/KsCollectionViewTests/KsPagingDisplayTests.swift:367-370`) は、読み込み中の表示が読み上げの要素として出ることを「アプリの UI テストで確かめる」と書いている。本体のテスト本文が見ているのは、標準の部品で描かれて動いていることと、名前を与えていないことまで
- P3 を消すと、読み込み中の表示を読み上げの要素として見るテストは全系統で 0 件になる (同じ要素を見ていた P10 の UI テストはユニットテストに移った)。上のコメントは指す先が無くなり、`ios/` 側の書き換えが要る
- 実測は 7.7 秒。残しても iOS Sample は 208 秒、4 系統の合計は 385 秒

消す側の材料:

- 仕分け表とオーナー採用の決定は「消す」。残すなら UI テストは 11 件になり、決定事項の件数 (10 件) と食い違う

レビュアーの見立ては「残す」。消す根拠にした本体テストが、消す対象のアサーションを覆っていないため。

## アクションプラン

1. P3 を残すか消すかをオーナーが決める (残すなら deviation.md の記述のまま)
2. メニューから画面を開く経路のテストを持つかをオーナーが決める (Minor 2 件目)
3. 表示文言のアサーションを足すかを決める (Minor 1 件目)
4. 余力があれば、古いページが混ざらないテストの失敗の文言を分ける (Suggestion)
