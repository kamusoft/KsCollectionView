# Tasks: paging-indicator-color

適用する規約: handbook/cross/comment-policy・handbook/cross/test-execution・handbook/cross/sample-parity・handbook/cross/sample-debug-controls。見た目の正は `ui/mock/indicator-color-a-secondary-text.html` (`ui/mock/approved.png`。照合するのは色だけ — `ui/brief.md`)、挙動の正は `specs/collection-paging/spec.md` と `specs/samples/spec.md`。方向の理由は core/ADR-0035 (proposed)。

## 1. iOS のライブラリ

- [x] 1.1 一覧の設定 (`KsCollectionConfiguration`) に読み込み中の表示の色を足し、公開の modifier `.loadingIndicatorColor(_ color: Color)` を `listSeparatorColor(_:)` と同じ形で足す。doc コメントに、効く範囲 (差し替えていない次のページの読み込み中・最初の読み込み中と、Pull to Refresh のインジケータ)・ページングを付けない一覧でも Pull to Refresh に効くこと・差し替えた表示には効かないこと・指定しないときは標準の色のままであることを書く (→ Requirement: 読み込み中の表示の色 / 色を指定しないときの読み込み中の表示)
- [x] 1.2 中身が同じになっている既定の表示の型 2 つ (`KsPagingDefaultIndicator`・`KsPagingDefaultProgress`) を 1 つにまとめ、指定した色を受け取って描く。色の指定が無いときは色を付けず、親に付けた tint に従う今の見え方のままにする。利用者が差し替えた表示には色を渡さない (→ Scenario: 次のページの読み込み中に効く / 最初の読み込み中に効く / 差し替えた表示には効かない / 表示中に色を変える / 表示中に指定を外す / 指定しない一覧は標準の色のまま)
- [x] 1.3 Pull to Refresh の部品 (`KsRefreshControl`) に指定した色を渡す。一覧の更新のたびに行う付け外し (`syncPullRefreshControl`) の中で合わせ、指定を外したら標準の色に戻す。ページングを付けない一覧でも効かせる。並べ替えのドラッグ中に届いた色の変化は、ほかの設定と同じくドラッグが終わってから当てる今の経路 (ドラッグ中に届いた構成を控える仕組み) に乗せ、色だけを先に当てる経路は足さない (→ Scenario: Pull to Refresh のインジケータに効く / ページングを付けない一覧でも効く / 表示中に色を変える / 表示中に指定を外す / 並べ替えのドラッグ中に色を変える (iOS))
- [x] 1.4 既存の doc コメントのうち標準の読み込み中の表示を説明している箇所 (`paging(_:threshold:onLoadMore:)`・`pagingAppendingIndicator(_:)`・`pagingLoadingPlaceholder(_:)`) に、色を `loadingIndicatorColor(_:)` で指定できることを書き足す (→ Requirement: 読み込み中の表示の色)
- [x] 1.5 テスト (ライブラリのテストに足す。既存のテストが使っている読み込み中の部品の探し方で、部品の色を読む):
  - 色を指定した一覧で、次のページの読み込み中と最初の読み込み中の部品が指定した色になる (→ Scenario: 次のページの読み込み中に効く / 最初の読み込み中に効く)
  - 色を指定した一覧で、Pull to Refresh の部品が指定した色になる。ページングを付けた一覧と付けない一覧の両方 (→ Scenario: Pull to Refresh のインジケータに効く / ページングを付けない一覧でも効く)
  - 2 つの読み込み中を差し替えた一覧では、差し替えた表示が利用者の色のまま出る (→ Scenario: 差し替えた表示には効かない)
  - 3 つの表示のそれぞれについて、表示を出したまま指定を別の色に変えると、出ている部品が新しい色になる。Pull to Refresh は、取り直しの処理を待たせてインジケータを出したまま変える (→ Scenario: 表示中に色を変える)
  - 3 つの表示のそれぞれについて、表示を出したまま指定を外すと、出ている部品が色を指定しない一覧と同じ色になる (→ Scenario: 表示中に指定を外す)
  - 次のページの読み込み中を出したまま並べ替えのドラッグを始め、ドラッグの途中で指定を別の色に変えると、ドラッグの間は前の色のままで、ドラッグが終わると新しい色になる (→ Scenario: 並べ替えのドラッグ中に色を変える (iOS))
  - 色を指定しない一覧では、読み込み中の部品 2 つが親に付けた tint に従い (tint を変えると追随する)、Pull to Refresh の部品が作ったばかりの標準の部品と同じ色である (→ Scenario: 指定しない一覧は標準の色のまま)

## 2. Android のライブラリ

- [x] 2.1 `KsCollectionView` に引数 `loadingIndicatorColor: Color? = null` を `listSeparatorColor` と同じ形で足す。置く位置は `reorder` の次 (末尾の `content` の前) とし、既存の引数の順番は変えない (引数を位置で渡している既存の呼び出しを壊さないため)。KDoc に、効く範囲・ページングを付けない一覧でも Pull to Refresh に効くこと・差し替えた表示には効かないこと・省略すると標準の色のままであること・Pull to Refresh では矢印に効き下地はテーマの色のままで、テーマと合わない色を指定すると矢印が見えにくくなりうることを書く (→ Requirement: 読み込み中の表示の色 / 色を指定しないときの読み込み中の表示)
- [x] 2.2 既定の読み込み中の表示 2 つ (`KsPagingDefaultProgress`・`KsPagingAppendingIndicatorDefault`) に指定した色を渡す。指定が無いときは material3 の既定 (テーマの primary) のままにする。利用者が差し替えた表示には色を渡さない (→ Scenario: 次のページの読み込み中に効く / 最初の読み込み中に効く / 差し替えた表示には効かない / 表示中に色を変える / 表示中に指定を外す / 指定しない一覧は標準の色のまま)
- [x] 2.3 Pull to Refresh のインジケータ (`PullToRefreshDefaults.Indicator`) の矢印の色に指定した色を渡す。下地の色は渡さず material3 の既定のままにする。指定が無いときは矢印も既定のままにする。ページングを付けない一覧でも効かせる (→ Scenario: Pull to Refresh のインジケータに効く / ページングを付けない一覧でも効く / Android の下地は変わらない / 表示中に色を変える / 表示中に指定を外す)
- [x] 2.4 `KsPaging` の KDoc のうち標準の読み込み中の表示を説明している箇所 (クラスの説明・`appendingIndicator`・`loadingPlaceholder`) に、色を `KsCollectionView` の `loadingIndicatorColor` で指定できることを書き足す (→ Requirement: 読み込み中の表示の色)
- [x] 2.5 テスト (ライブラリのテストに足す。描いた結果の色を見るテストには `@GraphicsMode(GraphicsMode.Mode.NATIVE)` を付ける — handbook/cross/test-execution):
  - 色を指定した一覧で、次のページの読み込み中と最初の読み込み中が指定した色で描かれる (→ Scenario: 次のページの読み込み中に効く / 最初の読み込み中に効く)
  - 色を指定した一覧で、Pull to Refresh のインジケータの矢印が指定した色で描かれ、下地は色を指定しない一覧と同じ色で描かれる。ページングを付けた一覧と付けない一覧の両方 (→ Scenario: Pull to Refresh のインジケータに効く / ページングを付けない一覧でも効く / Android の下地は変わらない)
  - 2 つの読み込み中を差し替えた一覧では、差し替えた表示が利用者の色のまま出る (→ Scenario: 差し替えた表示には効かない)
  - 3 つの表示のそれぞれについて、表示を出したまま指定を別の色に変えると、新しい色で描かれる。Pull to Refresh は、取り直しの処理を待たせてインジケータを出したまま変える (→ Scenario: 表示中に色を変える)
  - 3 つの表示のそれぞれについて、表示を出したまま指定を外すと、色を指定しない一覧と同じ色で描かれる (→ Scenario: 表示中に指定を外す)
  - 色を指定しない一覧では、ページングの 2 つがテーマの primary で、Pull to Refresh が material3 の既定の色で描かれる (→ Scenario: 指定しない一覧は標準の色のまま)

## 3. Sample

- [x] 3.1 iOS のデモ画面「ページング」(`PagingDemoView.swift`) の一覧に、`loadingIndicatorColor` で `SampleTheme` のテキスト副 (`secondaryText`) を指定する。操作のパネル・失敗 / 終端 / 空の表示・一覧に渡す配置の入力は変えない (→ Requirement: デモ画面「ページング」の読み込み中の表示の色)
- [x] 3.2 Android のデモ画面「ページング」(`PagingDemoScreen.kt`) の一覧に、3.1 と同じ名前のトークン (`SampleTheme.secondaryText`) を `loadingIndicatorColor` で指定する。ほかは変えない。色の値が両プラットフォームで同じことは、既存の配色の突き合わせのテスト (`SamplePaletteParityTest`) が確かめているため、テストは足さない (→ Requirement: デモ画面「ページング」の読み込み中の表示の色 / Scenario: 両プラットフォームで同じ色)

## 4. 確認

- [x] 4.1 mock との視覚照合 (ksn-ui の手順): 両プラットフォームの「ページング」で、① 最初の読み込み中・② 次のページの読み込み中・③ Pull to Refresh のインジケータを、ライト / ダークのそれぞれで出して承認 mock と色を照合する。あわせて、失敗・終端・空の表示と操作のパネルが変更前と同じ見え方であることを見る。最終周の画像を `ui/verification/` に保存し、`ui/brief.md` に照合記録を書く。撮影は作業専用に新しく作ったシミュレータ / エミュレータで行い、終わったら削除する (→ Scenario: 3 つの表示が同じ色でそろう / 外観の切り替えに追随する / ほかの表示は変わらない)
- [x] 4.2 両プラットフォームのライブラリと Sample のテストを 4 系統とも絞り込みなしで流し、系統ごとの実行件数と、4 系統を順に流した壁時計の合計を報告する (合計 10 分以内 — handbook/cross/test-execution) (→ 全 Requirement)
