# レビュー結果: image-loading (003 回目)

**日付**: 2026-09-07
**判定**: CHANGES_REQUESTED

## サマリー

2 周目の指摘 (ホスト Major 2 / Minor 1 / Suggestion 2、相方 Major 3 / Minor 1) は**全件が解消**していた。
特に「同じ継ぎ目をプラットフォームごとに逆向きへ倒した」2 件は、両プラットフォームを「元寸を同期で
引き当て、その場で縮小して初回描画に使う」形に揃えることで解消し、Android には Scenario
「枠より大きい画像」の実測テストが、iOS には読み込み中スロットの構成回数を数えるテストが入っている。
ビルド・全テスト・lint はすべて緑 (件数は下記)。

一方で、**その修正で作られた「表示の鍵」の仕組みが、iOS では最も普通の経路 (先読み無しで一度表示し、
セル再利用で表示し直す) に届いていない**。`prepare` は「縮小指定付きの鍵」と「元寸の鍵」しか見ないが、
実際に発行する要求は 3 つ目の鍵 (デコード時縮小) を持つため、その要求の結果は次の表示で引き当てられない。
**実測で確認した** — iOS は再表示で読み込み中スロットが 1 回構成され、Android は 0 回だった。
Scenario「戻ってきたときの再表示」に対する違反であり、また今周も同じ「片方の契約だけを見た修正が
別の契約を落とす」型になっている。

あわせて、**iOS の表示経路の Scenario 検査が、本番がもう呼ばない関数 (`makeRequest`) に対して
行われている**ことを検出した。上の穴が今周も検出されなかった直接の理由であり、Android が今周
同じ問題を付随修正で直した (deviation 記録済み) のと非対称のまま残っている。

この 2 件を Major として CHANGES_REQUESTED とする。

## 実行したビルドとテスト

| 対象 | コマンド | 結果 |
|---|---|---|
| iOS 本体 | `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,id=<iPhone 17 Pro>' -configuration Debug` | **Executed 144 tests, with 0 failures** (前周 139 → +5) |
| iOS Sample | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples` | **Executed 3 tests, with 0 failures** (計測ドライバは含まれず分離が効いている) |
| Android 本体 | `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` | **122 tests / 0 failures / 0 skipped** (9 クラス。前周 116 → +6。内訳: `KsAppContextTest` 3 / `KsCollectionViewCoreTest` 14 / `KsCollectionViewInteractionTest` 22 / `KsCollectionViewLayoutTest` 30 / `KsCollectionViewPrefetchTest` 7 / `KsCollectionViewPublicApiTest` 5 / `KsImageCacheContractTest` 12 / `KsImagePrefetchWindowTest` 14 / `KsImageTest` 15) |
| Android Sample | `./gradlew :app:testDebugUnitTest --rerun-tasks` | **18 tests / 0 failures / 0 skipped** (3 クラス: `ImageGridMeasurementFixtureTest` 5 / `SampleDemoScreenTest` 9 / `SampleScreenParityTest` 4) |
| lint | `local-path-lint.py` / `identity-lint.py` / `comment-policy-lint.py` | 禁止 0 件 / 0 件 / 0 件 (comment-policy は検査対象 194 ファイル) |

件数は XML レポート (`build/test-results/testDebugUnitTest/TEST-*.xml` の `tests` / `failures` /
`errors` 属性) のクラス単位の集計まで取った。

### 依頼された間欠失敗の観測 (`KsImageTest.removeMakesTheDisplayedImageReload`)

**Android 本体の全件実行を計 9 回 (初回 1 + 連続 8) 行い、9 回とも 122 tests / 0 failures。
当該テストの失敗は 1 度も再現しなかった。** ただし**このテストは原理的に落ちうる書き方になっている** —
機序と根拠は下記 [🟡 Minor] に書いた。再現しないことをもって解消と判断しないこと。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| [ソースコメント規約](../../handbook/cross/comment-policy.md) | always |
| [Sample のプラットフォーム間一致](../../handbook/cross/sample-parity.md) | `samples/` にデモ画面「画像グリッド」と計測用の画面を追加・変更 |
| [テスト実行規約](../../handbook/cross/test-execution.md) | テストの実行と結果の報告・間欠失敗の観測 |
| [実行時挙動の検証規約](../../handbook/cross/runtime-behavior-verification.md) | 実行時挙動の証跡と、同文書自身への観測点の追記 |
| [公開識別子と配布座標](../../handbook/cross/public-identifiers.md) | `Package.swift` / `libs.versions.toml` / AndroidManifest を変更 |
| [ローカル開発環境と Sample の実行](../../handbook/cross/local-development-setup.md) | 本体・Sample のビルドとテスト実行 (guide) |
| [iOS 性能検証の手順と合格基準](../../handbook/ios/performance-verification.md) | 大量件数 (10,000 件) を扱う変更の完了判定 |
| [Android 性能検証の手順と合格基準](../../handbook/android/performance-verification.md) | 同上・ラッパーのスクロール経路に触れる |

用途キー `code-review` (android) で解決した **kotlin-impl-skill** をロードして適用した
(null 安全・sealed / data class・structured concurrency・コード衛生)。新規 Kotlin ソースに
`GlobalScope` / `runBlocking` / `!!` / `Thread.sleep` / `CancellationException` の握り潰しは無い。
公開 API は Explicit API mode 下で KDoc を持つ。

参照した決定: core/ADR-0002・0011 (accepted)、core/ADR-0012 (proposed — 判定根拠にはしていない)。
`kasane/lessons/code-review.md` は未作成のため重点観点・除外観点なし
(`kasane/lessons/inbox/` の 5 件は昇格前なので判定には使っていない)。

## 前周の指摘の解消状況

| 前周の指摘 | 状況 | 確認した根拠 |
|---|---|---|
| ホスト Major 1 (iOS) 到達点 memory の先読み後も初回表示が読み込み中を経由 | **解消** | `ios/Sources/KsCollectionView/KsImageRequestFactory.swift:75-106` の `prepare` が元寸をその場で縮小して `cachedImage` に載せ、`KsImage.swift:112-137` がローダーの状態が決まるまでそれを描く。`KsImageCacheContractTests.test読み込み中のスロットはメモリにある画像では一度も構成されない` がスロットの構成回数 0 を検査 |
| ホスト Major 2 (Android) 到達点 memory の先読み後に元寸をそのまま表示 | **解消** | `KsImageRequestFactory.kt:59-125` が `Precision.EXACT` に戻したうえで元寸をその場で縮小し、表示サイズ付きの鍵へ載せ直す。`KsImageTest.imagesLargerThanTheFrameAreDownscaledBeforeBeingDisplayed` が fit=100×50 / fill=200×100 の実寸法まで検査 |
| ホスト Minor 3 / 相方 Major 1 消去のフェンスの適用範囲 | **解消** | `clear(.memory)` も `fenceAll()` を通すようになった (`KsImageCache.swift:26-35` / `KsImageCache.kt:32-42`)。両プラットフォームに「メモリのみの消去でも消去より前に始まった先読みはメモリへ戻らない」テストがある。**表示層が対象外である理由と受容範囲は deviation.md に明記された** (Coil 3.5.0 に公開の取り消し口が無い / 代替 3 案の確認 / 片側だけ入れると非対称を新造する / オーナー未確認である旨) |
| ホスト Suggestion 1 iOS の計測入口の土俵一致 | **解消** | `samples/ios/KsCollectionViewSamples/ImageGridFixture.swift` にコレクションの組み立てごと 1 本化し、デモ画面と `PerformanceVerificationView` の両方がそこから取る。担保の非対称 (Android は静的テスト / iOS は型で書けない) は deviation 記録済み |
| ホスト Suggestion 2 iOS 証跡の状態表 | **解消** | `evidence/image-grid-measurement-ios.md` の状態表が「合格の判定に未達」に統一され、本文の自己申告と一致 |
| 相方 Major 2 安定 ID 据え置きの URL 変更が反映されない | **解消** | iOS `KsImagePrefetcher.swift:105-120` の `reconcile` と Android `KsImagePrefetchWindow.kt:57-84` の再解決。テストは iOS 4 件 (`test同じIDのまま画像が差し替わると…` / `test画像の差し替えでも他の項目と共有中のURLは取り消さない` / `test配列の差し替えで同じIDの画像が変わると先読みを取り直す` ほか)、Android 2 件 (`changingTheUrlOfAnItemWithTheSameIdRestartsThePrefetch` / `changingTheUrlKeepsAUrlThatAnotherItemStillNeeds`)。クロージャ呼び出し回数が増える帰結は deviation 記録済み |
| 相方 Major 3 Android の画像メモリ計測に 1,000 件の入口が無い | **解消** | `ImageGridBenchmark.kt:48-66` に到達点 × 件数の 4 系統。`evidence/image-grid-measurement-android.md` に 4 行の表と件数比の判定欄を追加。閾値が規約に無い点も deviation に記録して実測後のオーナー判断へ回している |
| 相方 Minor 4 テストコメントの作業タスク番号依存 | **解消** | `ImageGridMeasurementFixtureTest.kt:17-23` がファイル単体で意味の閉じる説明に置き換わっている |

**降格に値する前周の指摘は今周も 0 件。**

## 指摘事項

### [🟠 Major] iOS: 一度表示した画像を表示し直すと読み込み中を経由する (先読みの有無に関わらず)

**該当箇所**: `ios/Sources/KsCollectionView/KsImageRequestFactory.swift:75-106` (`prepare`) /
`ios/Sources/KsCollectionView/KsImage.swift:112-137`

**問題点**: デルタスペック Requirement「KsImage の読み込み取り消しとメモリ保持」の Scenario
「戻ってきたときの再表示」は「一度表示して画面外に出た `KsImage` → スクロールで戻る → **読み込み中の
表示を経由せず即座に画像が表示される**」を要求する。Requirement「KsImage の表示状態」も
「メモリキャッシュにあれば読み込み中を経由せず成功になる (SHALL)」と定める。

`prepare` が同期で引き当てるのは 2 つの鍵だけである — 縮小指定付き (`resizedRequest`) と
元寸 (`originalRequest`)。ところがメモリに何も無いときに**実際に発行する要求は 3 つ目の鍵**
(`thumbnailRequest`、`ImageRequest.thumbnail` を持つ) であり、その結果はその 3 つ目の鍵の下に入る。
`prepare` はその鍵を見ないため、**先読み無しで一度表示した画像は、次に同じ `KsImage` を組み立て直した
ときに引き当てられず `cachedImage` が nil になり、読み込み中のスロットが構成される**。
セル再利用と画面への再入場という、この機能でもっとも頻繁に起きる経路がこれに当たる。

**実測で確認した** (レビュー用の一時テストを本体テストターゲットに置いて実行し、確認後に削除):

| 観測 | iOS | Android |
|---|---:|---:|
| 一度表示 → 表示を作り直したときの読み込み中スロットの構成回数 | **1** | **0** |
| そのときの取得回数の増加 | 0 | 0 |

- iOS 側の追加観測: 再表示時点で `pipeline.cache[発行する要求]` は**存在する** (メモリには画像がある)
  のに `prepare` の `cachedImage` は nil だった。つまり「メモリに無い」のではなく「見ている鍵が違う」
- Android が 0 回なのは、`KsImageRequestFactory.kt:71-83` が表示要求に自前の `displayKey` を与えて
  いて、**その表示要求自身の結果が同じ鍵に入り、次の `prepare` がそれを引き当てる**ため

計数の基準 (読み込み中スロットの構成回数) は、実装側が今周追加した
`KsImageCacheContractTests.test読み込み中のスロットはメモリにある画像では一度も構成されない` と
`KsImageTest.loadingSlotIsNeverComposedWhenTheImageIsAlreadyInMemory` が採っているものと同一であり、
「一瞬なので見えない」で片付けられる差ではない (この基準を採ったこと自体が、実装側も
LazyImage が最初の組み立てでは必ず未確定であることを前提にしている証拠になる)。

deviation.md の「到達点メモリの先読みと表示の継ぎ目 (両プラットフォーム)」は今回の設計を
「以後は縮小指定付きの鍵で当たる」と書いているが、**iOS では先読みを使わない経路でそうなっていない**。
記録と実装が食い違っており、この帰結はどの deviation にも記録が無い。

副次的に、iOS では同じソース・同じ枠・同じ当てはめ方に対して「デコード時縮小の項目」と
「デコード後縮小の項目」の 2 つがメモリに並びうる。deviation の「縮小済み画像を共有ローダーの
メモリへ書く」は「表示サイズ × 当てはめ方」の数だけ増えるとしているが、この 2 重化は勘定に入っていない。

**推奨修正**: `prepare` の同期引き当てに `thumbnailRequest` の鍵も加える (実測どおりメモリには
在るので、これだけで再表示は読み込み中を経由しなくなる)。または Android と同様に**表示要求へ
安定した表示用の鍵を与え、発行する要求と引き当てる鍵を一致させる**。後者のほうが「鍵が 3 種類ある」
という状態自体を無くせるため、同じ型の見落としを断てる。
あわせて、**「先読み無しで一度表示 → 表示を作り直す → 読み込み中スロットの構成回数 0」を数える
テストを iOS に追加する** (現在の 2 件はどちらも先読みでメモリへ載せた前提から始まっており、
この経路を 1 件も踏んでいない)。Android にも対のテストが無いので、同時に入れると非対称を作らない。

### [🟠 Major] iOS: 表示経路の Scenario 検査が、本番がもう呼ばない関数に対して行われている

**該当箇所**: `ios/Sources/KsCollectionView/KsImageRequestFactory.swift:48-67`
(`makeRequest`) / `ios/Tests/KsCollectionViewTests/KsImageTests.swift` (10 箇所) /
`ios/Tests/KsCollectionViewTests/KsImageCacheContractTests.swift` (3 箇所)

**問題点**: `KsImageRequestFactory.makeRequest` を呼ぶ本番コードは 1 箇所も無い
(`ios/Sources/KsCollectionView/` 全体を検索して確認。表示経路は `prepare` と `route` だけを使い、
`KsNukeImageLoading.makeRequest(url:)` は別物)。にもかかわらず、次の Scenario の検査はすべて
`makeRequest` に対して書かれている:

- 「枠より大きい画像」/「サイズ確定前は取得しない」(`KsImageTests`)
- 「削除後は別サイズでも旧項目に当たらない (iOS)」(`KsImageTests`)
- 「メモリ到達点の後の表示」/「ソース単位の削除」/「全消去の後の表示」(`KsImageCacheContractTests`)

`makeRequest` と `prepare` は**別の判断をする** — `makeRequest` は縮小をローダーに委ねて要求を返すだけ
だが、`prepare` はその場で縮小を実行し共有メモリキャッシュへ書き込む。したがって `makeRequest` が
緑であることは、表示が spec を満たすことの根拠にならない。上の Major 1 が今周も検出されなかったのは、
まさにこの検査の穴による。

これは相方レビュー 1 周目の Major 群 (「テストが実経路を通っていない」) と同型で、**Android は今周
同じ問題を付随修正で直している** (deviation:「`KsImageCacheContractTest` (Android): 表示の検査を
本番の組み立て経由に変更し手書きの複製を廃止した」)。iOS 側は逆に、本番が `prepare` へ移った時点で
テストだけが `makeRequest` に取り残された。`kasane/lessons/inbox/check-tests-exercise-production-path-before-accepting-green.md`
が捉えているパターンそのものでもある。

**推奨修正**: 上記のテストを `prepare` (本番が呼ぶ入口) 経由へ移し、`makeRequest` を削除する。
`prepare` に寄せると副作用 (キャッシュ書き込み) が検査に混じるので、要求の形だけを見たい検査は
`prepare` の戻り値の `request` を見る形にすれば足りる。削除せず残す判断をするなら、
**残す理由と「本番は通らない」ことを doc コメントに明記する** (現状の doc は表示経路の説明として
書かれており、読者は本番の挙動と誤解する)。

### [🟡 Minor] Android: `removeMakesTheDisplayedImageReload` の待機が「取得が始まった」で戻るため、原理的に落ちうる

**該当箇所**:
`android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsImageTest.kt:436-459`
(および数え上げ地点 `:72-73`)

**問題点**: [テスト実行規約](../../handbook/cross/test-execution.md)「収束を待つアサーション」は
「待ちたい**完了条件そのもの**を観測する」ことを求める。このテストの 1 段目は

```
awaitCondition("1 回目の取得が走らない") { fetchCount >= 1 }
```

だが、`fetchCount` は `ScriptedFetcher.fetch()` の**冒頭**で増える (`:69-70` の `onFetch()`)。
つまりこの待機は「取得が始まった」で戻り、1 回目の表示要求はまだ飛行中でありうる。

その状態で `KsImageCache.remove` が走ると、次の順序が成立する:

1. `remove` がメモリを走査して消す (まだ何も入っていない) → ディスク削除 → 世代を進める
2. 飛行中だった 1 回目の要求が完了し、`displayKey` へ書き込む
3. 世代が進んだことで `KsImage` が組み立て直され、`prepare` が同じ `displayKey` を引く
   — **Android の表示要求の鍵には世代が入らない** ので、2 で書き戻された項目に当たる
4. メモリに当たったので取得が走らず、2 段目の `awaitCondition` が 10 秒で失敗する

3 の「表示要求の鍵に世代が入らない」ことと、表示層がフェンスの対象外であることは deviation に
記録済みの受容範囲なので**製品側の違反ではない**。問題は、テストがその受容範囲と矛盾する前提
(「remove の後は必ず取得が走る」) で書かれていることである。報告されている間欠失敗の説明として
整合する (**当方の 9 回の全件実行では再現しなかった** — 実行機が空いていると 1 回目の取得は
`awaitCondition` が戻る前に終わってしまうため、混雑時にだけ表面化する形になっている)。

**推奨修正**: 1 段目の待機を**完了条件**にする — 「取得が始まった」ではなく「1 回目の画像が表示された」
(`onAllNodesWithContentDescription("reload")` が出る) か「`displayKey` にメモリ項目が入った」を
観測してから `remove` を呼ぶ。あわせて `awaitCondition` の失敗メッセージに、現在の
`fetch=` に加えてそのとき見ていた条件の実測値を載せると、次に落ちたときに
「実装が壊れた」と「待機が足りない」を切り分けられる。

### [🟡 Minor] 縮小を表示の組み立て中に同期で行う設計になったが、その費用がどこにも記録されていない

**該当箇所**: `ios/Sources/KsCollectionView/KsImageRequestFactory.swift:93-99` /
`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImageRequestFactory.kt:95-100`
(`downscale` → `image.toBitmap(...)`)

**問題点**: 今周の修正で、到達点 `memory` の先読みが載せた元寸から**表示の組み立て中に同期で**
縮小画像を作るようになった (iOS は SwiftUI の body 評価、Android は composition の `remember` 内)。
どちらもメインスレッドで、フリング中に新しく組み立てられるセルごとに 1 回走る。

`handbook/android/performance-verification.md` と `handbook/ios/performance-verification.md` は
この change の完了判定に frameOverrun P99 / hitch time ratio を要求しており、tasks 7.1 / 7.5 は
これから実施される。**この経路が新たに増えたメインスレッド上の同期処理であることは、計測前に
既知のリスクとして記録しておくべき情報**だが、deviation.md にも証跡にも記載が無い。
deviation は同じ性格の未計測リスク (Android の `BoxWithConstraints` による subcomposition 1 段増、
「表示枠より小さい画像がメモリにあると数フレーム拡大表示」) は記録しているので、記録の粒度として
不揃いでもある。

未計測そのものは指摘しない (合意済みの進行状態)。指摘は**証跡・deviation の書き方**に対するもの。

**推奨修正**: deviation.md に「到達点 `memory` を選んだとき、表示の組み立て中にメインスレッドで
縮小が 1 回走る (セルごと)。10,000 件グリッドでの実測は tasks 7.1 / 7.5 で行う」を足す。
`evidence/image-grid-measurement-*.md` の「到達点メモリ」の行を読むときに、この経路の費用を
見に行くものだと分かる状態にしておくと、計測結果の解釈が後から再現できる。

### [🔵 Suggestion] iOS の `prepare` が SwiftUI の body 評価の中で共有キャッシュへ書き込む

**該当箇所**: `ios/Sources/KsCollectionView/KsImage.swift:113-118` →
`ios/Sources/KsCollectionView/KsImageRequestFactory.swift:97` (`cache[resized] = ...`)

**問題点**: `prepare` は `KsImage.loaderContent(size:)` から、つまり**ビューの body 評価の中**で
呼ばれ、その中で共有メモリキャッシュへ書き込む。SwiftUI の body は純粋であることが期待され、
再評価の回数と順序は保証されない。書き込み自体は冪等なので現時点で壊れ方は見えないが、
Android が `remember(source, context, width, height, contentMode)` で 1 回に固定しているのに対し、
iOS は枠サイズ・`displayScale`・世代が変わるたびに再実行される (毎フレームではない) という
非対称がある。

**推奨修正**: 必須ではない。入れるなら、縮小と書き込みを body の外 (`task` / `onChange` あるいは
`@State` に置いた値の初期化) へ出し、body では読むだけにする。現状のまま残す判断でも、
`prepare` の doc コメントに「body から呼ばれ、副作用としてキャッシュへ書く」ことを明記しておくと、
後から `prepare` を触る人が再評価の回数を意識できる。

## 所見 (指摘ではない)

- **`KsImagePrefetchWindow.update` の再解決**は、可視 + 窓のアイテムだけを毎回解決し直す形で、
  `ledgerStaysBoundedWhileScanning` が台帳の上限も見ている。窓から可視へ移ったアイテムを
  取り消さない扱い (表示側へ引き継ぐ) も Scenario「進行方向へ移動すると窓が進む」の但し書きに沿う。
  iOS の `reconcile` も「両方に残る URL は参照数を動かさない」まで含めて対称に書けている
- **フェンスの受容がオーナー未確認**である旨が deviation に明記されている
  (「この受容はオーナー未確認 — 完了報告で提示する」)。記録済みなので違反としては扱っていないが、
  **完了報告での提示が実際に行われたかは蒸留の前に確認が要る**
- **`sample-parity`**: 「画像グリッド」の画面タイトル・3 択の文言 (「なし」「ディスクまで」「メモリまで」)・
  説明行「プリフェッチ · 10,000 件 · 3 列」・「キャッシュを消去」が両プラットフォームで一致している。
  `runtime-behavior-verification.md` の観測点表への追記も、技術検証画面の例外枠の書き方に沿っている
- **付随修正の同梱条件**: deviation の `[付随修正]` 8 件は、いずれも本務で触るファイル内・局所・
  公開 API 不変で ksn-core の同梱条件に収まっている。今周追加された 3 件 (iOS テストの間欠失敗解消 /
  iOS テストの窓の後始末 / Android テストを本番の組み立て経由へ) もテストで担保されている
- **core/ADR-0011 との整合**: Android の未初期化時の no-op + 警告は「落とさず・消さず・黙らず」に
  沿い、debug assertion を掛けられない理由も deviation に記録されている。iOS の
  `KsImagePipeline` の無言 no-op 解消 (debug assertion / release 警告) も同様
- **core/ADR-0012 は依然 proposed**。実装は明示 API (`enableSharedDiskCache()`) で、ADR 本文の
  「初回利用時に自動で差し替える」と Consequences は蒸留で accepted 化するときに書き直しが要る
  (1・2 周目と同じ所見)
- **未実施の実機計測 (tasks 7.1 / 7.2 / 7.5)** は合意済みの進行状態。証跡は「何が測れて何が測れて
  いないか」を分けて書けており、Android は 4 系統の件数比まで枠が用意された。未計測そのものは
  指摘にしていない
- **良かった点**: 前周の指摘 9 件すべてに、指摘の「検証の穴」まで含めた修正が入っている。特に
  Android の `imagesLargerThanTheFrameAreDownscaledBeforeBeingDisplayed` は縮小結果のピクセル寸法を
  fit / fill 別に実測しており、以前「緩和のおかげで緑になっていた」テストの裏返しになっている

## アクションプラン

1. **[Major]** iOS の `prepare` が引き当てる鍵と、実際に発行する要求の鍵を一致させる
   (`thumbnailRequest` の鍵も見る / 表示用の安定鍵を持つ)。あわせて
   **「先読み無しで一度表示 → 作り直す → 読み込み中スロット 0 回」**のテストを iOS と Android の
   両方に入れる (現在どちらにも無い)。実装で満たせない場合はオーナー判断として提示し、
   結論を deviation.md と `evidence/user-notes-source.md` に残す
2. **[Major]** iOS の表示経路の Scenario 検査を `prepare` 経由へ移し、`makeRequest` を削除する
   (Android が今周行った付随修正と対)。残すなら「本番は通らない」ことを doc に明記する
3. **[Minor]** `KsImageTest.removeMakesTheDisplayedImageReload` の 1 段目の待機を、
   「取得が始まった」から「1 回目の表示が確定した」へ変える。間欠失敗の再現が取れていないので、
   直した後も全件実行を複数回回して観測結果を残す
4. **[Minor]** 到達点 `memory` で表示の組み立て中にメインスレッド縮小が走ることを deviation に記録し、
   tasks 7.1 / 7.5 の証跡がその費用を見に行けるようにする
5. **[Suggestion]** iOS の `prepare` の副作用 (body 評価中のキャッシュ書き込み) を body の外へ出すか、
   doc に明記する
6. 上記と独立に、蒸留では **core/ADR-0012 の Decision と Consequences を実装 (明示 API) に合わせて
   確定し、消去範囲の 2 択と `clear(.all)` の実挙動、および表示層がキャッシュ消去のフェンスの
   対象外である限界を concepts に明記する**
