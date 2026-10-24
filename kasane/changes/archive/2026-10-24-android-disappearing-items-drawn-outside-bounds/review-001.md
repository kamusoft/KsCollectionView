# レビュー結果: android-disappearing-items-drawn-outside-bounds (001 回目)

**日付**: 2026-10-24
**判定**: APPROVED

## サマリー

合意したスコープ (exploration.md の決定事項の A 案) のとおり、`LazyVerticalGrid` の modifier に `clipScrollableContainer(Orientation.Vertical)` を 1 つ足しただけの直しで、一覧の根・iOS・公開 API には触れていない。新しいテスト 2 件は修正前のコードで落ち、修正後に通ることをレビュー側で再現した (落ちたときの画素の数も証跡と一致)。Critical / Major / Minor の指摘は無く、任意の Suggestion が 1 件だけある。

## 照合した規約

- ソースコメント規約 (always) — 本体とテストに足したコメントを照合。`scripts/comment-policy-lint.py` も 2 ファイルとも禁止 0 件
- テスト実行規約 (テストの実行・追加) — 「実行件数の確認までが検証」「全系統の合計は 10 分以内」「収束を待つアサーション」「Android: 差分なし再実行と Robolectric の描画限界」の各節
- 実行時挙動の検証規約 (不具合修正の完了の判定) — 修正前に落ち修正後に通るテストと、作業用のエミュレータでの修正前後の見比べがそろっていることを照合
- Android 性能検証の手順 (Android ラッパーの描画の経路に触れる) — 決定事項で「性能のゲートはやり直さない」と合意済み (追加は一覧全体に 1 枚の切り取りの層で、項目ごとの費用は増えない)。合意どおりで、違反として扱わない
- 証跡の規約 (ksn-core references/evidence.md) — evidence/ のテキストに `scripts/identity-lint.py`・`scripts/local-path-lint.py` を掛けて 0 件。静止画 2 枚は Sample のデモ画面だけで、個人の値は写っていない

ロードしたスキル: kotlin-impl-skill (パッケージの指定。config の android の code-review と同じ)

lessons: kasane/lessons/code-review.md の L-001 (証跡の計測値を自前で再現する)・L-002 (動きの過程を見る) を重点観点として当てた。

## 確認した観点

**仕様充足**
- 決定事項の A 案: 切り取りはグリッドの modifier の中で、消えていく項目を描く仕組みより外側に付いている。Compose foundation 1.11.4 の `LazyGrid.kt` (ソース jar) で、利用者の modifier → `lazyLayoutSemantics` → `beyondBoundsModifier` → `state.itemAnimator.modifier` → `scrollableArea` の順であることを確かめ、付けた位置で消えていく項目が切り取りの内側に入ることを確認した
- 一覧の根 (`BoxWithConstraints`、`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:599`) に切り取りは無い。根に重ねる表示 (引っ張って更新・ページングの表示) の見え方は変わらない
- 切り取りより内側に並ぶ `ksScrollIndicator` は `drawWithContent` で枠の中に描くため影響を受けない。並べ替えのジェスチャ (`pointerInput`) は描画の切り取りと無関係
- 見えている項目は元から Compose 自身の同じ形の切り取りの内側にあるため、変わるのは消えていく項目の描かれ方だけ。並べ替えで持ち上げた項目の影 (`KsReorderLift.kt` の `placeWithLayer`) も項目の中で描かれ、見え方は変わらない
- iOS のコード・公開 API・KDoc の利用契約は変わっていない (diff は `KsCollectionView.kt` の import 1 行と modifier 1 行とコメント 3 行)
- tasks.md は S 級のため無い。足場 (exploration.md) は書き換えられていない (作業ツリーで未追跡の新規ファイルのみ。中身は決定事項どおり)
- deviation.md は蒸留送りの行 1 件だけで、記録の無い仕様の逸脱は無い。付随修正は無い

**テスト**
- 本体 `android/` で `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks`: 32 クラス / 518 件 / 失敗 0 / エラー 0 / スキップ 0 (`KsDisappearingItemsClipTest` 2 件を含む。このクラスは 0.35 秒)。壁時計 27 秒
- Sample `samples/android/` で `./gradlew :app:testDebugUnitTest --rerun-tasks`: 21 クラス / 163 件 / 失敗 0 / エラー 0 / スキップ 0。壁時計 21 秒
- 修正前に落ちることの再現 (L-001): HEAD (94a31b1) を一時の worktree に出し、新しいテストだけを写して流した。2 件とも `KsDisappearingItemsClipTest.kt:164` (上下の部品の画素のアサーション) で失敗し、フレームごとの違う画素の数は上が `[0, 10500 が 22 フレーム, 0 が 7 フレーム]`、下が `[0, 4500 が 22 フレーム, 0 が 7 フレーム]` で、証跡 `evidence/diff-update-replace-ab.txt` の記載と一致した。一時の worktree は確かめた後に片付けた
- 空振りの防止: フェードの途中のフレームを観測できたこと (一覧の中に新しい項目の色でない画素があるフレームが 3 以上) を先に確かめており、消える項目が描かれないまま上下の判定が通ることを防いでいる
- 時間の扱い: 固定時間の待機は無く、`mainClock.autoAdvance = false` と `advanceTimeByFrame()` でフレームを 1 枚ずつ進めている。「収束を待つアサーション」の誤りに当たらない
- 上と下の両方を確かめている (決定事項の「下端側も同じ形で確かめる」)。下の部品に `zIndex(-1f)` を付けて一覧より先に描かせ、はみ出しが画素に出るようにしている理由がコメントにある
- システムプロパティ `robolectric.pixelCopyRenderMode` は `@Before` で設定し `@After` で元に戻しており、他のテストクラスへ漏れない
- 決定事項はテストの土台を `captureToImage` と書いているが、実際は `PixelCopy` とハードウェア描画で読んでいる。`captureToImage` では層で描かれる消えていく項目が出ず修正前でも通ってしまうためで、その知見は deviation.md の蒸留送りの行に記録済み。決定事項の目的 (修正前に落ち、上の部品の画素が差し替え前と同じことを確かめる) は満たしており、手段の差として問題にしない
- 動きの過程 (L-002): 単体テストが差し替え後の 30 フレームを 1 枚ずつ読んでおり、エミュレータでもアニメーションを 10 倍に延ばしてフェードの途中を撮っている (`evidence/diff-update-replace-fading-before.png` では古い「Item 3」が上のバーに重なり、`evidence/diff-update-replace-fading-after.png` では一覧の外に何も出ない)。この直しはスクロールの動きを変えないため、スクロールの録画までは求めない

**設計品質**
- accepted ADR との照合: android/ADR-0006 (差し替えを `animateItem` で見せる) の挙動はそのままで、その副作用だけを消している。android/ADR-0004 の「切り取りは描画時に行い、合成レイヤは作らない」は行の高さの補間の話で、一覧全体に 1 枚の切り取りには当たらない。android/ADR-0001 (list も 1 列グリッド) により、list の表示も同じ経路で直る (エミュレータの見比べは list で行っている)
- オーバーエンジニアリング: 無い (modifier 1 つ)
- コメント: 本体のコメント (`KsCollectionView.kt:684-686`) は理由 (消えていく項目が Compose 自身の切り取りの外で描かれる) と、横の見え方を変えない理由をそのファイルだけで説明できている。作業文書への参照は無い
- 入力検証・認証認可・機密情報: 該当なし
- Kotlin の品質 (kotlin-impl-skill): テストは `internal class`、補助関数は `private`、定数は `companion object` に集めており既存のテストの書き方と揃っている。`!!` や `runBlocking` は無い。`@OptIn(InternalComposeUiApi::class)` はテストの中だけで、本体の公開 API に漏れない

## 指摘事項

### [🔵 Suggestion] 左右の見え方が変わらないことはテストで押さえていない

**該当箇所**: `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsDisappearingItemsClipTest.kt:96`
**問題点**: 決定事項が B 案 (四辺を切る `clipToBounds`) を却下した理由は「左右の端の影が新しく切れる」ことで、本体のコメントにも「左右の見え方は変わらない」とある。今のテストは上下のはみ出しが消えたことだけを見ているため、将来この切り取りを `clipToBounds` などに置き換えても、左右の影が切れたことにテストは気づかない。今回の合意スコープは上下のはみ出しを消すことで、テストの追加はスコープに含まれていないため、任意の提案とする。
**推奨修正**: 必要なら、一覧の左右に余白を取り、端の列の項目に影 (または横へはみ出す装飾) を付けて、一覧の枠の外の左右に画素が出ることを確かめるテストを 1 件足す。足さない場合は、蒸留時に concepts へ書く段落 (決定事項の「蒸留時に反映」) で横を広げている理由を残せば足りる。

## アクションプラン

1. (任意) 上の Suggestion を、この change で足すか、見送るかを決める。見送っても APPROVED のまま
