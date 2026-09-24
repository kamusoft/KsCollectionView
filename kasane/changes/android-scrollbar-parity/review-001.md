# レビュー結果: android-scrollbar-parity (001 回目)

**日付**: 2026-09-24
**判定**: CHANGES_REQUESTED

## サマリー

構成は決定事項に沿っている。自前描画・外部依存なし・公開 API 不変・常に有効・描画フェーズでだけ状態を読む・タッチを受け取らない、のいずれも満たす。iOS の実物と比べた見た目の数値 (太さ・端からの距離・最短の長さ・ライト/ダークの色) と、プログラムによるスクロールでは出さない挙動も、iOS Simulator の探針で一致を確かめた。一方で `contentPadding` を指定すると、リストを末尾まで送ってもバーが下端に届かない。公式の `scrollIndicatorState` の `scrollOffset` と `contentSize` で余白の扱いが食い違っているためで、KDoc の「全高 (contentPadding を含む) を走る」という主張とも合わない。Sample の実画面 (余白デモ・画像グリッド) で目に見えるため Major とする。テストは全件成功 (本体 245 件 / Sample 44 件、失敗 0)。

## 照合した規約

- ソースコメント規約 (always)
- テスト実行規約 (テスト実行・結果の報告)
- Android 性能検証の手順 (スクロール経路に触れる変更。基準機での確認は完了条件側の作業で、このレビューの範囲外)
- concepts: android/architecture/compose-wrapper (してはいけないこと・保証すること)
- decisions: android/ADR-0001〜0005、cross/ADR-0004・0006 (衝突なし)
- lessons/code-review.md の重点観点 L-001 (計測値を含む証跡は無いため対象外。代わりに、以下の主張は自前の探針で確かめた)

## 確認した観点 (問題なし)

- **決定事項との一致**: 表示/非表示の設定なし・公開 API の変更なし (`internal` のみ追加)・外部依存の追加なし・`LazyGridState.scrollIndicatorState` の値から位置と長さを求めている。
- **再コンポーズを起こさない**: `visibility.value` と `scrollIndicatorState` は `drawWithContent` の中でだけ読んでいる。`isDragged` も `snapshotFlow` の中でだけ読んでいる。非表示 (alpha 0) のときは `scrollIndicatorState` を読む前に抜けるため、非表示の間はスクロールしても描き直しが起きない。`scrollingDoesNotRecomposeCollectionOrCells` はテンプレート宣言ブロックの評価回数で本体の再コンポーズを数えている。この宣言ブロックは毎コンポジションで評価される (`KsCollectionViewScope<Item>().apply(content)`) ため、数え方は空振りしない。
- **タッチ**: 描画だけの modifier で、入力を受け取る経路が無い。つまめない (iOS 既定と同じ)。
- **ライフサイクルとコルーチン**: `LaunchedEffect(gridState, isDragged)` の中で `collectLatest` を回しており、待機とフェードは新しい状態が来れば取り消される。`transformLatest` は前の処理を取り消して終わるのを待ってから次を始めるため、`isUserScroll` を同時に書き換えることはない。`CancellationException` の握りつぶしもない。
- **慣性スクロール**: 探針 (後述) で、スワイプ後の慣性スクロールの間は表示が保たれ、止まってから約 1 秒でフェードすることを確かめた。
- **既存機能との干渉**: 区切り線・タッチ feedback・`ksAnimatedHeight` は項目の modifier で、インジケータはグリッドの外側の modifier なので互いに触れない。スクロール命令は `isUserScroll` が立たないため表示しない。
- **iOS の実物との一致** (iOS 26 Simulator で `UIScrollView` の `_UIScrollViewScrollIndicator` を探針で読んだ):
  - 幅 300 × 高さ 600、contentSize 3000 のとき、バーは x=294・y=3・幅 3・高さ 118.67、角丸 1.5 → 太さ 3 / 端からの距離 3 / 長さ (600−6)×600/3000 と一致
  - contentSize 1,000,000 で長さ 36 → 最短の長さ 36 と一致
  - 色はライトで黒 35%、ダークで白 50% → 一致
  - `setContentOffset(_:animated: true)` の最中も後もインジケータの alpha は 0 → 「スクロール命令では出さない」という実装とコメントの主張は正しい
  - `UICollectionViewController` を表示しても点滅は起きない → Android で初回表示時に出さないのと一致
  - 消えるまでの時間 (1 秒待ってから 250ms でフェード) は `flashScrollIndicators()` の経路でしか観測できず、ドラッグ後の経路と同じとは言えないため確かめられていない。完了条件のオーナー目視で確かめる範囲とする (指摘にはしない)
- **コメント規約**: `comment-policy-lint` の検出は 0 件。新しいコメントは現在形で、ファイル内だけで意味が通る。公開 doc コメントの追加はない。

## 指摘事項

### 🟠 Major contentPadding があると、末尾まで送ってもバーが下端に届かない

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsScrollIndicator.kt:135` (位置の割合の計算)、`:28-30` (KDoc の主張)、`android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsScrollIndicatorTest.kt:242-255`

**問題点**: 公式の `scrollIndicatorState` は、`contentSize` には前後の余白を含める一方で、`scrollOffset` は余白を除いた座標で数えている。そのため、末尾に達したときの `scrollOffset` が `contentSize - viewportSize` に届かない。探針 (作業ツリーの複製上で実行。リポジトリは変更していない) の実測は次のとおり。

- 素の `LazyVerticalGrid` (1 列・高さ 100 の項目 30 件・縦の `contentPadding` 50・高さ 600): 末尾 (`canScrollForward=false`) で `scrollOffset=2400`、`contentSize=3100`、`viewportSize=600`。割合は 2400 / 2500 = 0.96 で頭打ちになる。途中でも実際のスクロール量 1000 に対して `scrollOffset=900` で、位置が遅れる
- `KsCollectionView` で `contentPadding = PaddingValues(vertical = 50.dp)` を指定して末尾で描いた画素: バーの下端は y=577 で、期待する 596 (高さ − 距離 3 − 1) より 19px 手前。余白 0 では 596 に届く

iOS では末尾まで送ればバーは下端に届くため、パリティの穴が残る。Sample の実画面 (`SpacingPaddingDemoScreen`・`ImageGridDemoScreen`) が `contentPadding` を使っているので、目に見える。`KsScrollIndicatorDefaults` の KDoc は「全高 (contentPadding を含む) を走る」と言っているが、実際の走り方は違う。また `boundsSpanWholeContainerIncludingPadding` は名前に反して余白を一切扱わない純関数のテストで、結合テストもすべて余白 0 で書かれている。そのため、この食い違いを捕まえるテストが無い。

**推奨修正**:
- `scrollOffset` と `contentSize` が同じ座標系になるよう揃えてから割合を求める。たとえば `layoutInfo.beforeContentPadding + afterContentPadding` を `contentSize` から引く、または `scrollOffset` 側に足す。どちらが公式の式に合うかは実装側で確かめる。末尾で割合が 1 に届き、先頭で 0 になることを満たせばよい
- 結合テストを 1 件足す: 0 でない `contentPadding` で末尾まで送り、バーの下端が「高さ − 端からの距離」に届くことを画素で確かめる (先頭側も同様)
- 決定事項の「位置と長さは `scrollIndicatorState` の値をそのまま使う」は、独自の推定 (論点 3 の c) を作らないという趣旨と読める。同じ値どうしの座標系を揃えるだけの正規化はその範囲内と考える。ただし、オーケストレーターが決定の変更に当たると判断するなら、オーナーに確認してから進めること

### 🟡 Minor 慣性スクロール中の表示の維持と、ドラッグ中の位置がテストで押さえられていない

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsScrollIndicator.kt:79-86`、`android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsScrollIndicatorTest.kt:216-240`

**問題点**:
- `isUserScroll` による「ドラッグから続く慣性スクロールの間は表示を保つ」分岐は、この実装で唯一の自明でない状態遷移である。しかし、既存のテストはすべて `releaseWithoutFling` で慣性を殺しており、この分岐を通らない。探針では正しく動いたが、回帰を捕まえるテストが無い
- `indicatorIsDrawnAtTrailingEdgeWithDefaultMetrics` の doc コメントには「スクロール量に比例した位置に描かれる」とあるが、テストが確かめているのは長さと x 位置だけで、y 位置は見ていない

**推奨修正**:
- スワイプで慣性を起こし、指を離してから 1 秒 (`HIDE_DELAY_MILLIS`) を過ぎても、慣性スクロールが続いている間は濃さが 1 のままであることを確かめるテストを足す。探針では、高さ 100 の項目 300 件を 80ms でスワイプすると、約 2.4 秒の慣性の間は表示が保たれた
- 位置を画素で確かめる行を足すか、doc コメントを実際に確かめている内容に合わせる

### 🔵 Suggestion ダークの判定をアプリ側のテーマと揃える余地

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:226`

**問題点**: `isSystemInDarkTheme()` は構成の `uiMode` を読む。AppCompat の夜間モード指定には追随するが、`MaterialTheme(lightColorScheme())` のように Compose の中でだけ明るいテーマに固定するアプリでは、システムがダークだと白 50% のバーが明るい背景に乗り、見えにくくなる。iOS は画面ごとの `overrideUserInterfaceStyle` に追随するため、厳密な対応先は無い。

**推奨修正**: 今回は対応不要。オーナーの目視でダーク端末の Sample を見る機会があれば、見え方を確かめるだけでよい。

## アクションプラン

1. (Major) `scrollOffset` と `contentSize` の余白の扱いを揃え、0 でない `contentPadding` で末尾・先頭の端に届くことを確かめる結合テストを足す。KDoc の「全高を走る」を実装どおりに保つ
2. (Minor) 慣性スクロールの間は表示を保つテストを足す。位置を確かめる行を足すか、doc コメントを直す
3. (Suggestion) 対応不要。基準機での目視確認で、ダークの見え方と消えるまでの時間 (iOS の実物との比較) も見るとよい
