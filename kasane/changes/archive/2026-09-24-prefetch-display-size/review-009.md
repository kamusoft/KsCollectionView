# レビュー結果: prefetch-display-size (009 回目)

**日付**: 2026-09-24
**判定**: CHANGES_REQUESTED

## サマリー

review-008 の後に入った性能の改善は、Android では spec を保っている。Android の改善は 2 点ある。1 つは、画面に出た時点の引き当て・要求の開始・描画を部品 (`KsDeferredNode`) の中で行うこと。もう 1 つは、要求を遅らせる対象を取得中の先読みに絞ること (`hasFetchInFlight`)。iOS の改善で、画面に出る時点の包み (`KsImageDeferredLoad`) を通すのは、先読みが取得中の可能性があるときだけになった。ただしこの iOS の改善には新しい不具合が 1 件ある。どの経路で表示するかを `KsImage` の組み立てのたびに選び直すため、包みの中で表示の要求によって読み込んだ画像が、メモリのみの消去の後の組み立て直しで `LazyImage` に切り替わる。そのとき表示中の画像は読み込み中へ戻り、ディスクから再デコードされる。レビュアーのプローブで再現したので Major とする。ビルドとテストは両プラットフォームとも全件成功した。画像グリッドの実際の経路の観測も、現行コードで review-008 と同じ値を再現した。計測の足場は、release・ライブラリの公開面・Sample の見た目のどれにも影響していない。

## 照合した規約

- ソースコメント規約 (always): review-008 の後に変わったコメントを節ごとに照合した。対象は Android の `KsImage.kt` (`KsDeferredImageContent` / `KsDeferredNode`)・`KsImageMemoryIndex.kt`・`KsCoilImageLoading.kt`・`KsImageRequestFactory.kt`、iOS の `KsImage.swift`・`KsImageDeferredLoad.swift`・`KsImageMemoryIndex.swift`・`KsImageRequestFactory.swift`・`KsNukeImageLoading.swift`、samples/ios の取り込んだ足場 (`ImageGridCount`・`ImageLoadingObservation`・`PerformanceVerificationView`・`ImageMemoryIndexReport`) である。外部文書の ID に頼らず、現在形で書かれている。comment-policy-lint は禁止 0 件 (258 ファイル)
- テスト実行規約 (テスト実行・結果の報告): 下記の件数を自分で集計した。iOS は `Executed N tests`、Android はクラス単位の XML の合計
- 実行時挙動の検証規約 (不具合の調査・修正の完了判定): 指摘 1 はプローブで再現を確かめた。画像グリッドの実際の経路は、Simulator の観測で再現した (lessons L-001)
- Sample のプラットフォーム間一致 (`samples/**`): 取り込んだ足場はどれも起動引数 (`--image-count` / `--memory-loaded` / `--data-loading-limit` / `--verify-image-prefetch-match-auto` 等) でしか働かない。デモ画面の文言・構成・件数の既定 (10,000) は変わっていない。`ImageGridCell` に足した `noteCellBuilt` は、観測していない実行では旗を見て戻るだけである
- スクロール性能の体感ゲート / iOS・Android 性能検証の手順 (性能の証跡を書くとき): `manual-imageGrid-{ios,android}-after.md` の再確認の節、`loader-counts-android.md` の「性能改善後」、`device-image-match-ios.md` の「改善後のビルドでの確認」、`memory-steady-*.md` と `disk-wait-*.md` の注記を読んだ

## 確認したこと

- **ビルド・テスト (レビュアーが自分で実行。DerivedData はスクラッチ、Simulator は iPhone 16e / iOS 26.1。起動中の他の機種と重ならない)**
  - iOS パッケージ: **275 tests / 0 failures**
  - iOS Sample の通常スキーム (UI テスト): **12 tests / 0 failures** (`ImageGridCountUITests` と `ImageLoadingSlotShownClippingUITests` を含む)
  - iOS Sample の Release ビルド (Simulator 向け): **BUILD SUCCEEDED**。Debug 専用の `ImageMemoryIndexReport` (`@testable import`) は `#if DEBUG` の中にあり、Release は本体を通常の import だけで組める
  - Android ライブラリ (`--rerun-tasks`): **231 件 / 失敗 0 / skip 0** (13 クラス)
  - Android Sample (`--rerun-tasks`): **44 件 / 失敗 0** (8 クラス)
  - comment-policy-lint 禁止 0。identity-lint / local-path-lint は違反なし (終了コード 0)
- **画像グリッドの実際の経路 (lessons L-001。計測対象の iOS の表示経路が直前のサイクルで変わったため)**: 現行コードの iOS Sample (Debug) を入れ直して、`--verify-image-prefetch-match-auto --observe-image-loading --count-image-loading-slots --probe-steps 8` で走らせた

  | 形 | 現れた | 引き当てた | 間に合わない | builtBefore | violation | **matchedShown** | 送りの shown / 表示の要求 | 戻し・メモリのみの消去の後 | 項目の寸法 |
  |---|---:|---:|---:|---:|---:|---:|---:|---|---|
  | `memory` | 60 | 51 | 9 | 0 | 0 | **0** | 9 / 9 | 表示の要求 0・shown 0 | 元寸 400 × 400 (51) |
  | `memory-column` | 60 | 51 | 9 | 0 | 0 | **0** | 9 / 9 | 表示の要求 0・shown 0 | 358 × 358 (51)、元寸無し 51 |

  review-008 の走行と同じ値で、実機の証跡の「改善後のビルドでの確認」とも同じ形である。ただし、この観測の「メモリのみの消去の後も表示し続けたセル」の段では、`KsImage` の組み立て直しが起きない。そのため指摘 1 の経路は通らない
- **Android の改善 (`KsDeferredNode`・`hasFetchInFlight`) と spec の照合**
  - メモリ到達点の後の表示: 組み立ての時点で先読みが取得中なら、要求を出さずに部品を置く。部品は最初に置かれた時点 (配置) で引き当てをやり直し、当たればその項目を描く。測るだけの先行合成では配置が走らないので、画面に出る前には何もしない。実機の証跡 (`loader-counts-android.md` の「性能改善後」) の値 (先読み完了のセルで表示要求・取得・デコード・`loading-shown` 0) とも整合する
  - 表示状態: 既定の読み込み中は部品が同じ色で直接描く。利用者の読み込み中の表示は中身として組み立てておき、画像を描けるようになると描かなくなる。その後の再合成で外れる。失敗は状態を立てて失敗の表示へ切り替える。`KsImageShownFrameTest` の 4 本と `KsImageTest` の `shownLookup*` 3 本が、最初のフレームの描き分けと再合成の有無を押さえている
  - 画面外へ出た読み込みの取り消し: 部品の要求は部品のコルーチンの範囲で動く。この範囲は部品が外れると取り消されるので、要求も一緒に取り消される (`onDetach` / `onReset` は、次に置かれたときの引き当てのやり直しに備えて状態を戻すだけである)。この経路の取り消しを直接確かめる単体テストは無い。ただし、取り消しは Compose の部品の寿命の規約そのものなので、指摘にはしない
  - メモリのみの消去: `prepared` は `remember` のキー (ソース・枠・当てはめ方) が変わらない限り作り直されない。そのため、消去の後に再合成されても同じ部品と描いている画像が残る。枠の変化は `key(prepared)` で部品ごと作り直して引き当てからやり直すので、Scenario「枠が変わっても範囲内なら再デコードしない」と範囲外の選び直しも保たれる
  - 取得中の数え方: 取得の終わりを Coil の listener (成功・失敗・取り消し) と取り消しの取っ手の両方で外す。取得ごとの目印なので、同じ鍵を取り消して始め直しても、古い取得の終わりが新しい取得の目印を消さない (`fetchInFlightIsCountedPerFetch`)。`clear` は目印ごと消し、`remove` の後の古い目印は無視される (`fetchInFlightOfARemovedKeyIsIgnored`)
- **iOS の改善と spec の照合**: 包みの中では読み込み状態 (`FetchImage`) を最初から持ち、中身の種類を入れ替えない。画面から出ると要求を取り消し、戻ると照会し直す。先読みの取り消しは `cancelPrefetch` で「取得中の可能性」から外れ、ディスクまでの先読みは数えない (`testディスクまでの先読みと取り消した先読みでは表示の要求を待たない`)。枠の変化は `.id(condition)` で包みごと作り直す。問題は、包みを選んだ理由 (`mayBeLoadingPrefetch`) が組み立てのたびに変わりうることである (指摘 1)
- **計測の足場の影響範囲**: iOS の取り込んだ足場は Sample の中に閉じていて、本体の `ios/Sources` に `@_spi` や public の追加は無い (公開面の差分は `KsImage(url, key:)` など spec どおりのものだけ)。`--data-loading-limit` は Sample の共有パイプラインの構成を作り直すだけで、本体の既定には触れない。Android の足場は計測用ソースセットにあり、release には入らない
- **review-008 の Minor の対応**: iOS の足場はリポジトリへ取り込まれ、証跡に再現の手順と「数値はスクラッチ版で採り、リポジトリ版は出力の形だけを Simulator で確かめた」ことが書かれている。Android の `memory-steady` / `disk-wait` の冒頭には、採ったビルド・解消した副因・変わった値の注記がある。`disk-wait-android.md` の待ちの数値は「最終ビルドで採り直す予定 (別の作業)」で、それまでは修正前の値として読むよう明記されている。tasks 8.5 の目的は主因の切り分けで、その主因 (取得経路の同時数の上限) はこの改善が触っていない経路にある。したがってこのまま受け入れる
- **足場**: proposal / design / specs は変わっていない。tasks はすべてチェック済み。deviation.md の末尾の記録は、Android の「取得中の条件へ絞った」ことと iOS の「取得中の可能性があるときだけ包む」ことを反映している

## 指摘事項

### 🟠 Major iOS: 画面に出る時点まで待つ経路で読み込んだ画像が、メモリのみの消去の後に組み立て直されると読み込み中に戻り、ディスクから再デコードされる
**該当箇所**: `ios/Sources/KsCollectionView/KsImage.swift:145-175` (経路の選択)、`ios/Sources/KsCollectionView/KsImageMemoryIndex.swift:150-156` (`removeAll` が取得中の可能性の記録も消す)、`ios/Sources/KsCollectionView/KsImageDeferredLoad.swift:31-44`
**問題点**: `loaderContent` は組み立てのたびに `prepare` を呼び直し、次の 3 つの経路を選び直す。
- 引き当てた画像 (`retainedMatch`)
- `prepared.mayBeLoadingPrefetch` のときの `KsImageDeferredLoad`
- それ以外の `LazyImage`

`KsImageDeferredLoad` が画面に出る時点の照会に外れて、自分の `FetchImage` で表示の要求を出して画像を表示したとする。この画像は `retainedMatch` に入らない。この状態で `KsImageCache.clear(.memory)` を呼ぶと、ローダーのメモリと索引が消え、取得中の可能性の記録 (`pendingPrefetchKeys`) も `removeAll` で消える。その後に親の状態の変化や別のソースの `remove` で `KsImage` が組み立て直されると、次のように進む。
1. 引き当ては外れ、`mayBeLoadingPrefetch` は false になり、`retainedMatch` も空である
2. そのため経路が `KsImageDeferredLoad` から `LazyImage` に切り替わる。構造上の別のビューなので、表示していた画像の状態は捨てられる
3. 新しい `LazyImage` が読み込み中を出し、ディスクから再デコードする

これは Requirement「キャッシュのクリア」の SHALL「`clear(.memory)` は表示中の画像を置き換えず」と、Scenario「メモリのみ消去」に反する。同じ型の不具合は、引き当てた経路について second-opinion-code-002 で Major として採用済みで、`KsImageRetainedMatch` で直されている。今回の改善で経路の選択が組み立てのたびに変わるものになったため、同じ不具合が包みの経路で戻った。
- 再現 (レビュアーのプローブ): 作業ツリーの ios パッケージをスクラッチへ複製し、既存の `KsImageCacheContractTests` の道具 (`KsRebuildingParent` / `rebuildParent` / `KsStubURLProtocol.gate`) で次の順に操作した
  1. メモリまでの先読みを取得中に止めておく
  2. `KsImage` を表示する (包みの経路に入る)
  3. 応答を返して、表示の要求の画像が表示されるまで待つ
  4. `clear(.memory)` を呼ぶ
  5. 親を組み立て直す
- 結果: デコード回数が **2 → 3** (ディスクからの再デコード)、読み込み中のスロットの組み立てが +2 だった。対照として、先読みなし (`LazyImage` の経路) で同じ操作をすると、デコード回数は **1 → 1** で読み直しは無かった (スロットの組み立て +1 は両方に出る雑音)
- 実機の証跡 (`device-image-match-ios.md` の「メモリのみの消去の後も表示し続けたセル 9 件」) は組み立て直しを起こしていないので、この経路を通らない。Android は `prepared` を `remember` で持ち、組み立て直しで経路を選び直さないので起きない
- 副次の形: 包みの中で読み込んだ後、先読みが取り消されて (`cancelPrefetch`) 取得中の可能性が消えることがある。その後に表示の項目と先読みの項目がローダーの LRU で追い出されてから組み立て直されると、同じく `LazyImage` へ切り替わる
**推奨修正**: 同じ引き当ての条件 (`condition`) の間は、表示している画像が経路の選び直しで失われないようにする。例を 2 つ挙げる。
- 案 1: `KsImageDeferredLoad` が読み込んだ画像も `KsImageRetainedMatch` に持たせる。こうすると、組み立て直しで引き当てが外れても同じ画像を描ける。全消去・ソース単位の削除では `reloadToken` が変わって捨てられるので、再取得の契約は保たれる
- 案 2: ある条件でいったん包みを選んだら、その条件の間は包みを選び続ける

回帰テストとして、既存の `test引き当てて表示中の画像はメモリのみ消去の後に親が組み立て直されても置き換わらない` / `…別のソースの削除があっても置き換わらない` と同じ形のものを、包みの経路で表示の要求によって読み込んだ場合について足す。

## 観察 (指摘ではない)

- Android の体感ゲートの手動の最終走行は、性能の改善の前のビルドで採られている。改善後は自動フリングの A/B で、比較用ビルドより良い値になっている (`manual-imageGrid-android-after.md` の「性能改善後の再確認」)。証跡の「限界」に「体感ゲートの手動計測はやり直していない」と明記されている。iOS の改善後の自動の確認も、オーナー決定で 1 回で打ち切られ、その理由が書かれている。どちらもオーナー判断の範囲なので指摘しない
- iOS の `pendingPrefetchKeys` は、失敗した先読みの鍵を索引から外れるまで持ち続ける (コメントに明記)。その間の同じ画像の表示は包みの経路を通る。挙動は `LazyImage` と同じく画面に出る時点で要求を出すので、見た目は変わらない。ただし指摘 1 の包みの経路に入る画像の範囲を広げる

## アクションプラン

1. (Major) iOS: 包みの経路で読み込んだ画像が、同じ条件の組み立て直しで失われないようにする (案 1 または案 2)。メモリのみの消去 + 親の組み立て直し / 別のソースの削除の回帰テストを、包みの経路について足す
2. 修正後に iOS パッケージのテストと、画像グリッドの観測 (`--verify-image-prefetch-match-auto`) の Simulator 1 走行で、`matchedShown` 0 と「戻し・メモリのみの消去の後 0」が変わらないことを確かめる
