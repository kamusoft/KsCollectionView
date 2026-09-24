# レビュー結果: prefetch-display-size (007 回目)

**日付**: 2026-09-23
**判定**: APPROVED

## サマリー

修正サイクル 6 は、review-006 / second-opinion-code-006 で確定した 4 件をすべて直している。iOS の Major は、画面に出る時点の状態に引き当ての条件を識別子として付けて直した。回帰テストは修正を外すと落ちる (レビュアーが確かめた)。Android の空白フレームは、利用者のスロットを中身として組み立て、ノードが描き分ける形で直した。要求開始の遅れは、先読みの鍵がキャッシュに無い識別子だけに絞った。iOS の計測の足場は「組み立てた」と「画面に出た」を分けた。レビュアーの Simulator 観測で `matchedShown=0`、`shown 9 = displayStarts 9` を再現し、数え落としも誤計上も無い。計測の足場は release に入らず、本体に計測用の公開面も増えていない。Sample の見た目と文言も変わっていない。新しく入った問題は見つからなかった。deviation の記述の精度について Suggestion を 1 件出す。

## 照合した規約

- ソースコメント規約 (always): サイクル 6 で変わったコメントを節ごとに照合した。対象は `KsImageDeferredLoad` の冒頭説明 (条件ごとの状態)、`KsImageRetainedMatch.Condition`、`KsImage.swift` の `.id(condition)` の説明、`KsImage.kt` の分岐の説明 / `KsUnshownImageContent` / `KsShownNode`、`KsPreparedImageRequest.prefetchPending`、`KsImageMemoryIndex.uncachedKeys`、`KsImageIdentity.isDisplayKey` である。Sample 側は `ImageLoadingSlotCounter` (iOS / Android 両方の「組み立てと、画面に出た読み込み中」)、`ImageLoadingSlotMark`、`ImageLoadingSlotShownProbe*` / `ImageLoadingSlotShownMonitor`、`ImageObserveScreen`、`MemoryIndexProbe`、`ImageGridCell` の新しい引数を見た。いずれも外部文書の ID に頼らず、それだけで読める。公開 doc コメント (`ImageGridCell` の `loading`) に内部用語は無い。lint (全体) は禁止 0 件。advisory は既存のテストコード 1 行 (`KsImageTest.kt:536`、今回の差分の外) だけ
- テスト実行規約 (テスト実行・結果の報告): 件数を集計して確認した。iOS は `Executed N tests`、Android はクラス単位の XML の合計である
- 実行時挙動の検証規約 (不具合修正の完了判定): iOS の Major は、レビュアーが修正を外した複製で回帰テストが落ちることを確かめた (下記)。両プラットフォームの実機での解消確認は tasks 6.6 / 8.2 の再計測に残る (未実施であること自体は指摘しない)
- Sample のプラットフォーム間一致 (`samples/**`): 観測用の画面 (Android `measurement/image-observe`、iOS `--verify-image-prefetch-match-auto`) は技術検証の経路で、デモ画面の集合に入らない (例外枠)。デモ画面の文言・構成・見た目に差分は無い (下記)
- スクロール性能の体感ゲート / iOS・Android 性能検証の手順: 表示経路 (セルの中の `KsImage`) に触れている。合否は tasks 8.1 の再計測に委ねる。今回の修正は、Android の遅延を絞ったので主スレッドの費用を減らす向きに働く

## 確認したこと

- **ビルド・テスト (レビュアーが自分で実行)**
  - iOS パッケージ (Simulator iPhone Air / iOS 26.0。起動中の他の機種と重ならない。DerivedData はスクラッチ): **271 tests / 0 failures**
  - Android ライブラリ (`--rerun-tasks`): **219 件 / 失敗 0 / skip 0** (13 クラス。新しい `KsImageShownFrameTest` 2 件を含む)
  - Android Sample (`--rerun-tasks`): **44 件 / 失敗 0** (8 クラス。testDebug の `ImageLoadingSlotShownTest` 7 件を含む)
  - iOS Sample は Debug でビルドが通ることを確かめた (下の観測に使用)。UI テスト (9 / 0) と `:app:assembleBenchmark` / `:app:compileReleaseKotlin` はホストの結果を採った
  - comment-policy-lint: 禁止 0
- **review-006 の指摘の修正**
  - **(Major) iOS: 画面に出る時点で引き当てた表示の選び直し**: `KsImageDeferredLoad` に `.id(condition)` を付けた (`ios/Sources/KsCollectionView/KsImage.swift:173-177`)。condition は世代・枠の大きさ・表示倍率・当てはめ方である。条件が変わると状態 (`.matched`) ごと捨て、差し込み直しの `onAppear` から照会し直す。組み立ての時点で引き当てた経路は、`retainedMatch.resolve` が条件を比べるので従来どおり。回帰テストは 2 本ある。範囲外は、64 px の項目で 20pt → 80pt に広げると縮小デコードが出ることを確かめる。範囲内は、20pt → 24pt でデコード・読み込み中・枠の大きさの項目がどれも増えないことを確かめる。**レビュアーはスクラッチの複製で `.id(condition)` を外して走らせ、範囲外のテストが「広げた枠での縮小デコードが収束しない (実測 2)」で落ちることを確かめた**。テストは修正の効き目を捉えている。範囲内のテストは、組み立ての時点で引き当てる経路で成立する (この経路を修正前から守る固定)
  - **(Major) Android: 利用者の読み込み中スロットの最初のフレーム**: `KsUnshownImageContent` は、スロット (未指定なら既定の表示) を中身として組み立てるようになった。`KsShownNode.draw()` は、画面に出る時点で引き当てた painter があれば中身を描かずに画像を描き、無ければ `drawContent()` で中身を描く。`KsImageShownFrameTest` は、フレームを 1 つずつ進めて View を直接描き、画面に出た最初の描画の中心の画素を読む。外れたときはスロットの色、当たったときは画像の色になり、その後もスロットは 1 度も描かれない (`slotDraws == 0`)。`KsImageTest` の回帰テストは「画面に出た後に組み立てが増えない」の形に改めてある (review-006 の推奨どおり)
  - **(Minor) Android: 要求開始の遅れ**: 画面に出るまで待つのは `prepared.prefetchPending` のときだけになった (`KsImage.kt:228`)。これは、同じ識別子の先読みの鍵 (表示の鍵以外) が索引にあり、その項目がメモリに無い場合である (`KsImageRequestFactory.kt:116-117`)。ディスクまでの先読みは索引に登録しない (`KsCoilImageLoading.kt:48-51`) ので、「ディスクまで」と「なし」では従来どおり先行合成の時点で要求を出す。テストは 2 本ある。先読みなし、および完了済みだが枠に合わない先読みで、画面に出る前に要求が出ることを確かめる
  - **(Minor) iOS 計測の足場の shown 分離**: `CountedImageLoadingPlaceholder` の背面に、見た目を持たない `ImageLoadingSlotShownProbe` (UIView) を置いた。`ImageLoadingSlotShownMonitor` が画面の更新の周期ごとに、窓の中で見える位置にあるかを見て `shown` を 1 回だけ数える。判定規則は `Δshown == 0` に改められた (iOS / Android の計数の説明、`ImagePrefetchMatchProbe` の `matchedShown`)。Android も同じ `shown` を持つ。こちらは `boundsInWindow` と描画の実行を見る `onLoadingSlotShown` で、`onReset` で数え直す
  - **(Suggestion) サイクル 5 の決定の記録**: deviation.md の最終項目に、design Decision 2 の実現時点の追補として残された (下の Suggestion は、その記述の精度)
- **iOS の計測の足場の再現 (lessons L-001 に従って自前で再実行)**: iOS Sample (Debug) を iPhone Air Simulator (iOS 26.0) に入れた。`--verify-image-prefetch-match-auto --observe-image-loading --count-image-loading-slots --probe-steps 8` で走らせた結果:

  | 形 | 現れた | 引き当てた | 間に合わない | 組み立てが完了より前で要求 | 違反 | matchedSized | **matchedShown** | 送りの shown / 表示の要求 |
  |---|---:|---:|---:|---:|---:|---:|---:|---:|
  | `memory` | 60 | 51 | 9 | 0 | 0 | 49 | **0** | **9 / 9** |
  | `memory-column` | 60 | 51 | 9 | 0 | 0 | 48 | **0** | **9 / 9** |

  戻し、およびメモリのみの消去の後 (表示し続けたセル 9 / 再び現れたセル 6) は、どちらも shown 0・表示の要求 0 だった。引き当てた項目の寸法は、幅なしが元寸 400 × 400 (51 件)、列幅が 388 × 388 (51 件) である。ホストの参考値と同じ結果になった。`matchedSized` (組み立て) は 49 / 48 あるが、`matchedShown` は 0 である。一方、先読みが間に合わなかった 9 件は、表示の要求の数と同じ 9 件が shown に数えられている。つまり、新しい計数は画面に出なかった読み込み中を除き、画面に出た読み込み中を数え落としていない
- **Android の画面に出た印 (`KsShownNode`) の再利用への耐性 (プローブ)**: review-006 の観察で、`hasBeenPlaced` / `painter` を `onReset()` で戻していないことを挙げた。スクラッチの複製で次のテストを足して確かめた (リポジトリには入れていない)。遅延列に `KsImage` を 300 件並べ、全件を先読み未完了の状態にし、取得は完了させない。小刻みの送り 120 回、方向を変える往復 60 回、戻し 80 回を行った。その後、見えているアイテムがすべて表示の要求を出している (表示の鍵が索引に載っている) ことを見た。止まったまま要求を出さないアイテムは 0 件だった (送りの後 `visible=44..52`、往復・戻しの後 `visible=20..28`)。一度置かれたノードが別のアイテムや同じアイテムの再表示に使い回されて `onShown` を呼ばない、という経路は現れなかった
- **計測の足場が release・本体の公開面に入っていないか**
  - Android: `src/measurement` と `src/counterEnabled` は debug (と benchmark の measurement / counterDisabled) にだけ入る。release は `noMeasurement` + `counterDisabled` である (`samples/android/app/build.gradle.kts:90-101`)。`onLoadingSlotShown`・`MemoryIndexProbe`・`ImageObserveScreen` は measurement の中だけから参照される。main の `ImageGridCell` に足した引数 `loading` は、既定が従来と同じ `ImageLoadingSlotCounter.rememberLoadingSlot(item.id)` である。counterDisabled の実装は null を返すので、デモ画面の見た目は変わらない。`ImageLoadingSlotMark` の差分は KDoc だけ
  - `MemoryIndexProbe` は本体の internal な `KsImageMemoryIndex` を実行時に名前で読み、読めなければ `unreadable` を出す。本体に計測用の公開面を足していない。本体の差分の公開宣言は `KsResource` / `KsWidth` / `KsImageSource.Remote(key)` / `KsImage(url, key:)` だけで、いずれも spec の Requirement どおりである。新しい `@_spi` も無い
  - iOS: Sample の計測コードは、従来どおり起動引数で動く方式である (既存の `ImageLoadingSlotCounter` / `ImageLoadingObservation` と同じ扱い)。`ImageMemoryIndexReport` だけが `#if DEBUG` + `@testable import` である。`ImageGridCell` の `noteCellBuilt` は、観測していない実行では最初の分岐で戻る。`ImageLoadingSlotShownProbe` は計数を要求した実行の読み込み中にだけ置かれ、透明で触れても反応せず、読み上げの対象にもならない
- **足場**: proposal / design / specs は review-006 より前の更新時刻で、変更は無い。tasks.md は 6.6 / 8.1〜8.3 / 8.5 が未チェックのままで、虚偽のチェックは無い
- **既存の Scenario への影響 (差分から読んだもの)**
  - 枠が変わったとき: iOS は、組み立ての時点・画面に出る時点のどちらで引き当てた表示も、条件の変化で引き当てからやり直す。Android は、`prepared` / `shownMatch` を枠の大きさで作り直す (従来どおり)
  - 世代による作り直し: iOS は、外側の `.id(reloadToken)` に加えて condition にも世代が入る (重複だが無害)。Android の `clear` / `remove` は索引から鍵を外すので、作り直した表示は `prefetchPending == false` となり、すぐに要求を出す
  - サイズ確定前は取得しない / アセット・リソース: 分岐は変わっていない

## 指摘事項

### 🔵 Suggestion deviation の「先読みが未完了のときに限り遅らせる」を、実装の条件どおりに書く
**該当箇所**: `deviation.md` 最終項目 (「Android は先読みが未完了のときに限り遅らせる」)、`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImageRequestFactory.kt:24-30`、`:116-117`
**問題点**: 実装が遅らせる条件は「同じ識別子の先読みの鍵が索引にあり、その項目がメモリに無い」ことである。索引は、完了した先読みの項目がメモリから追い出された後も、失敗・取り消しの後も鍵を残す (`clear` / `remove` と上限でしか外さない)。そのため、メモリまでの先読みで長くスクロールし、追い出された画像へ戻った場合も、要求は画面に出る時点まで遅れる。`KsPreparedImageRequest.prefetchPending` の KDoc はこれを明記しているが、deviation の一文は「未完了のときに限り」と読め、蒸留で concepts へ運ぶときに条件が狭く伝わる。挙動としては、review-006 の Minor 3 が懸念した遅れのうち、追い出し後の再表示の分が残る。tasks 8.1 の再計測 (ディスクまで・メモリまでの比較) の読み方に関わる。
**推奨修正**: deviation の該当箇所を、実装の条件 (未完了に加え、追い出し・失敗・取り消しの後も索引に鍵が残る間は遅らせる) で書き直す。tasks 8.1 でメモリまでの「送って戻す」を測るときは、この条件を読みの前提に入れる。実装の変更は求めない。

## 観察 (指摘ではない)

- **iOS の shown の見え方の判定は窓の範囲で見る**: `ImageLoadingSlotShownProbeView.isOnScreen` は、祖先の隠れ・透明と窓の範囲との重なりを見る。祖先 (コレクションビュー) の切り抜きは見ない。Android の `boundsInWindow` は祖先で切り抜く。UICollectionView は、表示範囲に掛かったセルだけを階層に置くので、実害のある過大計上の経路は見つからなかった。仮に起きても「画面に出た」を多めに数える向き (違反を見逃さない側) である
- **Android `KsShownElement` の更新**: `onShown` は組み立てのたびに作られるラムダなので、要素が等しくならず、再構成のたびに `update` → `invalidateDraw()` が走る。この表示は画面に出る前の短い間しか組み立てられないので、費用は無視できる

## アクションプラン

1. (Suggestion) deviation.md の最終項目の「先読みが未完了のときに限り」を、実装の条件 (追い出し・失敗・取り消しの後に索引に残った鍵も含む) に合わせて書き直し、tasks 8.1 の読みの前提に入れる
2. tasks 6.6 / 8.1〜8.3 / 8.5 の実機の再計測へ進む。iOS の「読み込み中を経由しない」の判定は `Δshown` (`matchedShown`) で読む
