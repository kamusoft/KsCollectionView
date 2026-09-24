# レビュー結果: android-scrollbar-parity (003 回目)

**日付**: 2026-09-24
**判定**: APPROVED

## サマリー

review-002 の Minor (余白の補正を確かめる結合テストが 1 列・header なしのリストだけ) への対応として、3 列のグリッドに全幅の header を置いた構成の逆戻りテストが 1 件足された。既存の逆戻りテストの本体は、共有の補助関数へそのまま切り出されている。製品コードは review-002 の時点から内容が変わっていない。変異を入れて確かめると、新しいテストは「行ではなく項目の数で距離を数える」形の崩れを、リストのテストが見逃す中で単独で捕まえた。Minor は解消した。本体の単体テストは 249 件で、失敗 0 だった。

## 照合した規約

- ソースコメント規約 (always)。`comment-policy-lint` の検出は 0 件 (`--advisory` でも対象ファイルの検出なし)。新しいコメントは現在形で、ファイル内だけで意味が通る
- テスト実行規約 (テスト実行・結果の報告)。`--rerun-tasks` で全件を実行し、クラス別の件数を集計した (下記)。Sample のテストは回していない。今回の差分は本体のテストファイル 1 つだけで、Sample が依存する製品コードに変更が無いためである (review-002 で 44 件・失敗 0)
- Android 性能検証の手順: 今回はスクロール経路の製品コードに触れていないため、対象外
- lessons/code-review.md の重点観点 L-001: 計測値を含む証跡は今回の差分に無いため対象外

## 確認した観点 (問題なし)

### 製品コードが変わっていないこと

作業ツリーの `KsScrollIndicator.kt` と `KsCollectionView.kt` を、review-002 の探針で使った複製と比べた。内容はバイト単位で一致する。`KsScrollIndicator.kt` の更新時刻は review-002 の出力より後だが、内容は同じである。同時刻のバックアップが残っているので、変異の確認などで書き換えてから元に戻した跡と見られる。

### テストの差分

review-002 時点のテストファイルとの差は次の 3 点だけである。

- `indicatorDoesNotMoveBackwardWithContentPadding` の本体を、補助関数 `assertBarNeverMovesBackwardWhileDragging` へ切り出した
- 新しいテスト `indicatorDoesNotMoveBackwardInGridWithHeaderAndContentPadding` を足した
- `setScrollableContent` に `layout` と `headerHeight` の引数を足した

切り出した本体は、1 行も変わらずに移っている。刻み幅 20dp・閾値越えの 5 刻み・40 刻みの記録・逆戻りの判定・前進の判定・`autoAdvance = false` の位置はいずれも元と同じである。したがって、既存テストの検査は弱まっていない。追加した引数はどちらも既定値が元の構成 (`KsLayout.List`・header なし) なので、他のテストの構成も変わらない。

### 新しいテストが空振りしていないこと

作業ツリーの複製に変異を入れ、`KsScrollIndicatorTest` (18 件) を走らせた。リポジトリは変更していない。

| 変異 | 失敗したテスト | 読み |
|---|---|---|
| なし (基準) | なし | 複製でも全件成功 |
| 補正をやめて公式の値を返す | 余白の 3 件 (リストの 2 件 + グリッドの 1 件) | 新しいテストも補正の有無を捕まえる |
| 距離を「行の差」ではなく「項目の番号の差」で数える (`行の間の距離 × 番号の差 / 行の差`) | **グリッドの 1 件だけ** | Minor の懸念そのもの。リストでは番号の差 = 行の差なので、リストのテストは通り続ける。新しいテストが単独で捕まえる |
| 行の比較を番号の比較 (`anchor.index <= firstOnScreen.index`) に置き換える | なし | 等価な変異。LazyGrid の `firstVisibleItemIndex` は行の先頭の項目を指し、`visibleItemsInfo` の先頭も行の先頭なので、2 つが同じ行なら同じ項目になる。review-002 が例に挙げた「番号で比べる」崩れは、実害のない書き換えだった |
| 距離を「行の差 × 基準の項目の高さ」に置き換える | なし | 違いが出るのは header (60) が先頭に見えている区間だけで、そこでも位置は前へ跳ぶだけで逆戻りしない。「逆戻りしない」という基準では区別できず、また区別すべき退行でもない |

探針で位置を確かめた。先頭の記録の時点で、グリッドのスクロール量は約 84dp である。このとき header は画面の上端に 6px だけ残り、上側の余白の境目にかかっているのは項目の行 1 だった。つまり「header が余白の領域に残る区間」は、最初の記録 1 回だけで押さえられている (下の Suggestion)。記録の列は 19 → 30 → 33 → … → 176 と単調に進む。header が画面から抜けるところの +11 は、公式の平均の高さに由来する前向きの跳びで、決定事項の目視の範囲内である。

### テストの書き方

- 待機は `mainClock` を手で進めるだけで、実時間の待機を含まない。テスト実行規約の「収束を待つアサーション」の対象外である
- 失敗時のメッセージには刻みの番号と記録の列全体が載るため、壊れたときに位置を追える
- `header` の引数は `(@Composable () -> Unit)?` で、`headerHeight?.let { height -> { Box(...) } }` は header の高さ 60 どおりに配置された (探針で項目の行 1 の位置から確かめた)

### テストの実行結果 (本体・`--rerun-tasks`)

| クラス | 件数 | 失敗 |
|---|---|---|
| KsAppContextTest | 3 | 0 |
| KsCollectionViewCoreTest | 14 | 0 |
| KsCollectionViewInteractionTest | 22 | 0 |
| KsCollectionViewLayoutTest | 30 | 0 |
| KsCollectionViewPrefetchTest | 9 | 0 |
| KsCollectionViewPublicApiTest | 8 | 0 |
| KsImageCacheContractTest | 27 | 0 |
| KsImageMemoryIndexTest | 11 | 0 |
| KsImagePrefetchWindowTest | 41 | 0 |
| KsImageShownFrameTest | 4 | 0 |
| KsImageTest | 52 | 0 |
| KsPrefetchDecodeSizeTest | 4 | 0 |
| KsPrefetchMetricsTest | 6 | 0 |
| KsScrollIndicatorTest | 18 | 0 |
| 合計 | 249 | 0 |

review-002 の 248 件から、追加した 1 件だけ増えた。

## 指摘事項

### 🔵 Suggestion header が余白の領域に残る区間が、最初の記録 1 回だけで押さえられている

**該当箇所**: `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsScrollIndicatorTest.kt:289-306`、`:313-320`

**問題点**: テストの説明は「header と項目の行が上側の余白の領域に残る区間を含めて確かめる」としている。header が画面に見えながら、余白の境目には項目の行 1 がかかる区間は、スクロール量でいうと 60〜90dp である。しかし記録はタッチの閾値を越えた後から始まり、最初の記録の時点で約 84dp、2 回目で約 104dp に進んでいる。そのため、この区間の記録は 1 回だけで、区間の中での比較は無い。この区間の値は、区間を抜けた後の値と 1 回だけ比べられている。

今の変異 (補正なし・番号の差で数える) は後ろの行で捕まるため、Minor の解消には影響しない。ただし、タッチの閾値や刻みが変わって最初の記録が 90dp を越えると、この区間は何の警告もなく記録から外れる。

**推奨修正** (任意・優先度は低い): 次のいずれかにすると、区間の中で複数回比べられるようになり、説明どおりの守備範囲を安定して保てる。

- 上側の余白を header の高さより大きくする (例: 上 80dp。区間は 60〜140dp になる)
- 最初の記録の時点で header が画面に残っていることを確かめるアサーションを 1 行足す

## アクションプラン

1. (Suggestion・任意) グリッドの逆戻りテストで、header が余白の領域に残る区間を複数の記録で押さえる。余白を広げるか、最初の記録で header が見えていることを確かめる
2. (前回からの持ち越し・コード外) review-002 の Suggestion のとおり、基準機確認でオーナーへ deviation を報告するときに、グリッド + header / footer では末尾の約 1 行手前でバーが下端に着くことを添える
