# Verify 003: prefetch-display-size

- 対象: コミット 3e4a918 (HEAD) に対する作業ツリーの未コミット差分 (`git diff HEAD` と未追跡ファイル)。ios/Sources・ios/Tests、android/kscollectionview/src (test・androidTest 含む)、samples/ios、samples/android
- 前回からの差分の主題: verify-002 (VALID) の後の 3 点
  1. 性能の改善。両プラットフォームの `KsImage` で、画面に出る時点の処理を軽くし、要求の開始を遅らせる条件を絞った。deviation.md 末尾の行は更新済み
     - iOS: `KsImageDeferredLoad` で包むのは、同じ画像のメモリまでの先読みが取得中の可能性があるときだけにした。包みの中身も入れ替えない形にした
     - Android: 遅らせる条件を「索引に鍵がある」から「先読みが取得中」に絞った。画面に出た時点の引き当てと要求は、部品 `KsDeferredNode` の中で組み立て直しなしに行う
  2. samples/ios への計測の足場の取り込み (`ImageGridCount` ほか)
  3. 証跡の追記。8.1 の最終ビルドでの 6 走行と性能改善後の再確認、8.2 の性能改善後の数え上げ
- 突き合わせ元: `specs/image-loading/spec.md` (ADDED 3・MODIFIED 10 の計 13 Requirement / 61 Scenario)、`tasks.md`、`deviation.md`、`design.md`、`proposal.md`、`evidence/` 11 本、`verify-002.md`
- 前回からの差分の特定: 作業ツリーに verify-002 時点のスナップショットが無い。そのため、verify-002.md より更新時刻が新しいファイルを差分の範囲とした (下の「前回からの差分の範囲」)
- 検証日: 2026-09-24
- 検証者の立場: 一致検証のみ (品質評価は review の領分)。同時進行の review-009.md は読んでいない

## 判定: VALID

全 61 Scenario が「✅ 一致」(56) か「⚠️ deviation 記録済み」(5) のどちらかで、❌ (未記録の欠落・乖離) は 0 件。虚偽のチェックと足場の逆流は無い。tasks は 37 件すべてがチェック済みで、8.1〜8.5 には `evidence/` の裏付けがある。

性能の改善で Scenario の対応は崩れていない。遅らせる条件の絞り込みは、Scenario「サイズ確定前は取得しない」の ⚠️ (deviation.md 末尾の行の「利用者から見える差」) の範囲を狭める向きの変更である。この行の記述は実装と一致する。「メモリ到達点の後の表示」は、改善後のビルドの実機の数え上げでも違反 0 件のままだった。

テストは、最終の実行ですべて成功した。ただし、Android ライブラリの 1 回目の全件実行で 1 件の失敗があった (`KsImageTest.urlConvenienceFormBehavesLikeRemoteSource`)。単独での再実行 3 回と全件の再実行 1 回ではすべて成功している。このテストは HEAD から変わっておらず、待たずに読む箇所のある書き方をしている (下の「テスト実行」)。Scenario の不一致ではないため判定は変えないが、呼び出し元への申し送りとする。

凡例: ✅ 一致 / ⚠️ deviation 記録済み / ❌ 欠落・乖離

## テスト実行 (検証者が再実行)

| 対象 | コマンド | 結果 |
|---|---|---|
| iOS パッケージ | `ios/` で `xcodebuild test -scheme KsCollectionView` (iPhone 17 / iOS 26.5 Simulator、DerivedData はスクラッチ) | **275 tests / 0 failures**。verify-002 から +4 で、新しい 4 本はすべて成功した: `test取得中のメモリまでの先読みがあるときだけ表示の要求を画面に出る時点まで待つ`・`testディスクまでの先読みと取り消した先読みでは表示の要求を待たない`・`test先読みが取得中のまま画面に出た表示は表示の要求を出して画像を表示する`・`test先読みの鍵は取り消しか項目を見るまで取得中の可能性として数える` |
| Android ライブラリ | `android/` で `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` | 1 回目: **231 tests / 1 failure** (iOS のビルドと同時に実行)。`KsImageTest` だけの単独再実行 3 回: 3 回とも 0 failures。2 回目の全件実行 (iOS Sample のビルドと同時に実行): **231 tests / 0 failures / 0 skip** (13 クラス) |
| Android Sample | `samples/android/` で `./gradlew :app:testDebugUnitTest --rerun-tasks` | **44 tests / 0 failures / 0 skip** (8 クラス) |
| iOS Sample (UI テスト、通常スキーム) | `samples/ios/` で `xcodebuild test -scheme KsCollectionViewSamples` (iPhone 17 Pro Max / iOS 26.5 Simulator) | **12 tests / 0 failures**。新規の `ImageGridCountUITests` 1 本を含む。verify-002 で 1 件失敗した `LargeDataCountUITests` は、今回は 4 本とも成功した |
| Android 実機 `KsImageDeviceDecodeTest` | 実機を使わない制約のため再実行していない | ホスト報告: 4 / 0 / skip 0 |

Android ライブラリの増分 (219 → 231、+12) の内訳:

- `KsImageTest` +4 (48 → 52): `precomposedDisplayWithEndedPrefetchRequestsBeforeItIsShown`、`shownLookupMatchDoesNotRecompose`、`shownLookupMissLoadsWithoutRecomposition`、`shownLookupMissShowsTheFailureSlotWhenLoadingFails`
- `KsImageShownFrameTest` +2 (2 → 4): 既定の読み込み中の表示を描く / 描かない
- `KsImageMemoryIndexTest` +2: `fetchInFlightIsCountedPerFetch`、`fetchInFlightOfARemovedKeyIsIgnored`
- `KsImageCacheContractTest` +4: `memoryPrefetchIsInFlightOnlyUntilItCompletes`、`cancelledMemoryPrefetchLeavesInFlightImmediately`、`failedMemoryPrefetchLeavesInFlight`、`diskPrefetchIsNotCountedAsInFlight`

**Android の 1 件の失敗について:** 失敗したのは `KsImageTest.urlConvenienceFormBehavesLikeRemoteSource` の `assertTrue("取得が走っていません", fetchCount >= 1)` (`KsImageTest.kt:712`)。このテストは、読み上げの説明 (contentDescription) が付いた節点が現れるのを待ってから、取得の回数を**待たずに**読んでいる。ところが説明は `KsImage` の根に最初の組み立てから付いているので、この待ちは取得の開始を待つことにならない。取得はローダーの非同期の処理で走るため、負荷が高いと読む時点に間に合わない形になっている。

テスト本体は HEAD (`git show HEAD:…/KsImageTest.kt` の 432〜448 行) と同じで、本 change では変わっていない。このテストが通る経路 (先読みなし → `KsRequestedImageContent` → `rememberAsyncImagePainter`) も、今回の性能改善の分岐 (`prefetchPending` が false の側) で変わっていない。Scenario「便宜形」の THEN (リモートのソースと同じ挙動) は、同じクラスの `convenienceFormPassesTheKey` と iOS の `test便宜形はリモートのソースと同じ宣言になる` でも固定されている。これらの理由から、実装の不一致ではなくテストの待ち方の問題と見立てる。直すなら、テスト側で `awaitCondition { fetchCount >= 1 }` のように待つのが自然である (実装の修正は要らない)。直すかどうかは呼び出し元の判断に委ねる。

## 前回からの差分の範囲

verify-002.md (2026-09-23 23:12) より新しいファイルは次のとおり (更新時刻で特定)。

- iOS 本体: `KsImage.swift`、`KsImageDeferredLoad.swift`、`KsImageRequestFactory.swift`、`KsImageMemoryIndex.swift`、`KsNukeImageLoading.swift`
- iOS テスト: `KsImageTests.swift`、`KsImageCacheContractTests.swift`
- Android 本体: `KsImage.kt`、`KsImageRequestFactory.kt`、`KsImageIdentity.kt`、`KsImageMemoryIndex.kt`、`KsCoilImageLoading.kt`
- Android テスト: `KsImageTest.kt`、`KsImageShownFrameTest.kt`、`KsImageMemoryIndexTest.kt`、`KsImageCacheContractTest.kt`
- samples/ios: `ImageGridCount.swift` (新規)、`DemoData.swift`、`KsCollectionViewSamplesApp.swift`、`ImageLoadingObservation.swift`、`ImagePrefetchMatchProbe.swift`、`PerformanceVerificationView.swift`、`KsCollectionViewSamplesUITests/ImageGridCountUITests.swift` (新規)、性能スキーム (`ImageGridCountUITests` を性能スキームで飛ばす指定)
- kasane: `tasks.md`、`deviation.md`、`evidence/` のうち 7 本 (`manual-imageGrid-{android,ios}-after.md`、`loader-counts-android.md`、`disk-wait-{android,ios}.md`、`device-image-match-ios.md`、`memory-steady-{android,ios}.md`)。ほかに `kasane/lessons/inbox/` に 1 本が増えている (本 change の検証対象外)

## 対応表

実装・テストのパスは次の下を指す。

- iOS: `ios/Sources/KsCollectionView/`・`ios/Tests/KsCollectionViewTests/`
- Android: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/`・`android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/`

verify-002 の対応表で挙げたテストは、すべて現存して上の再実行で成功した (名前で照合)。以下では、前回から判定または根拠が変わった行を太字で示す。

### 今回の実装の要点 (表示の経路)

**iOS** (`KsImage.swift:121-190`、`KsImageDeferredLoad.swift`、`KsImageMemoryIndex.swift:82-117`、`KsNukeImageLoading.swift:19-38`)

- 組み立ての時点で引き当てに成功したら、その項目で表示する
- 外れた場合は、同じ識別子に取得中の可能性がある到達点 memory の先読みがあるか (`mayBeLoadingPrefetch`) で分ける
  - あれば `KsImageDeferredLoad` で包む。画面に出る時点 (`onAppear`) でもう一度照会し、当たればその項目で表示する。外れたら、同じ読み込み状態 (`FetchImage`) に要求を渡す。画面から出たら要求を取り消す (`onDisappear` → `fetch.cancel()`)
  - 無ければ、組み立ての時点で `LazyImage` を直接置く (要求の開始は画面に出る時点)
- 「取得中の可能性」の登録と解除
  - 登録: 到達点 memory の先読みを出した時点
  - 解除: 照会でキャッシュに項目を見たとき、先読みの層から取り消されたとき、`clear` / `remove` のとき

**Android** (`KsImage.kt:173-426`、`KsImageRequestFactory.kt:74-119`、`KsImageMemoryIndex.kt:42-101`、`KsCoilImageLoading.kt:44-89`)

- 組み立ての時点の `lookup` は照会だけを行い、索引には登録しない
- 当たれば、その項目を `Image` で描く
- 外れた場合は、同じ識別子の索引の鍵に**取得中の先読み**があり、かつその項目がメモリに無いか (`prefetchPending` = `hasFetchInFlight`) で分ける
  - そうであれば `KsDeferredImageContent` を置く。部品 `KsDeferredNode` が最初に配置された時点で引き当てをやり直し、外れたらその場で要求を出して結果を描く
  - そうでなければ、組み立ての時点で要求を出す (`KsRequestedImageContent`)
- 取得中の数え方: `beginFetch` で数え始め、ローダーの成功・失敗・取り消しの通知と、取り消しの取っ手で外す

両プラットフォームとも、この構成は deviation.md 末尾の行の記述と一致する。

### ADDED: プリフェッチの表示幅

実装・テストは verify-002 から変更なし。

| Scenario | テスト・証跡 | 状態 |
|---|---|---|
| 列幅で縮小して載せる | verify-002 と同じ (iOS `test幅つきの先読みは幅の正方形を覆う大きさで載り元寸は載らない` ほか、And `widthDeclarationCoversTheSquare`・`columnWidthPrefetchIsMatchedByTheDisplay`・実機 `widthPrefetchStoresTheDeclaredWidth`。`evidence/memory-steady-{ios,android}.md`)。**改善後のビルドの iOS 実機でも、列幅の 138 件は 255 × 255 の項目で、元寸は無かった** (`evidence/device-image-match-ios.md` の末尾の節) | ✅ 一致 |
| 固定値で縮小して載せる | `test固定値の要素は表示倍率込みのピクセルで始まる` / `fixedWidthIsScaledByDensity` | ✅ 一致 |
| 元寸が小さければ拡大しない | `test元寸が宣言した幅より小さければ拡大せずに載る` / `smallerOriginalIsNotUpscaled` | ✅ 一致 |
| 幅あり・幅なしの混在 | `test幅あり幅なしを混ぜた宣言ではそれぞれの大きさで載る` / `mixedDeclarationsStoreTheirOwnSizes` | ✅ 一致 |
| 向きが変わると新しい列幅で先読みする | `test列幅が変わっただけでは進行中の取得を取り消さず出し直しもしない` / `orientationChangeUsesTheNewColumnWidthForNewPrefetches` | ✅ 一致 |
| 到達点 disk では幅を使わない | `test到達点diskでは幅を宣言しても元データの保存までで止まる` / `diskDestinationIgnoresWidth` | ✅ 一致 |
| 無効な固定値は幅なし扱い | `test無効な固定値は警告して幅なしとして扱う` / `invalidFixedWidthsAreReportedAndTreatedAsOriginal`・`reportingCanStopTheUpdate` | ✅ 一致 |
| 列幅が解けない間は始めない | `test列幅が解けない間は列幅の先読みを始めない` / `columnWidthDeclarationsWaitUntilTheWidthResolves` | ✅ 一致 |

補足: 16384 px の上限は deviation.md 11 行目で合意済み (前回と同じ)。

### ADDED: KsImage のメモリ項目の引き当て

実装: 引き当ての規則 (`KsImageMatching`・許容範囲 0.5 / 4) は変更なし。変わったのは、引き当てを試す時点と、要求を出す時点の分岐だけ (上の「今回の実装の要点」)。

| Scenario | テスト・証跡 | 状態 |
|---|---|---|
| **先読みの縮小済み項目を使う** | verify-002 のテスト (`test先読みの縮小済み項目で表示し読み込み中も表示の要求も経由しない` / `prefetchedDownscaledItemIsUsed`・`loadingSlotIsNeverComposedWhenThePrefetchedImageIsInMemory`、前もって組み立てたセルの `test前もって組み立てた後に先読みが完了すれば画面に出る時点で引き当てて読み込み中を経由しない` / `precomposedDisplayMatchesTheItemThatArrivedBeforeItWasShown`) は引き続き成功。**加えて、改善後の経路を固定するテストが増えた**: iOS `test取得中のメモリまでの先読みがあるときだけ表示の要求を画面に出る時点まで待つ`、And `shownLookupMatchDoesNotRecompose` (画面に出た時点で当たると、要求 0・組み立て直し 0)、`KsImageShownFrameTest` `defaultLoadingIsNotDrawnWhenTheShownLookupMatches` / `loadingSlotIsNotDrawnWhenTheShownLookupMatches` (最初の描画で読み込み中を描かない) | ✅ 一致 |
| 原寸の項目を実機でも使う | 単体は前回と同じ (iOS `test原寸の項目も許容範囲の内側なら枠にそのまま使う` ほか、And `originalItemWithinTheUpperBoundIsUsed`、実機 `graphicsBackedOriginalIsMatchedWithoutLoading` はホスト報告で Pass)。**iOS 実機は改善後のビルドでも同じ結果**: 幅なしで引き当て 138 件、`matchedShown` 0・`violation` 0 (`evidence/device-image-match-ios.md` の「改善後のビルドでの確認」) | ✅ 一致 |
| 小さすぎる項目は使わない | `test小さすぎる項目は使わず枠の実サイズで縮小する要求を出す` / `tooSmallItemIsNotUsed`・実機 `itemOutsideTheRangeFallsBackToDownscaledDecode` | ⚠️ deviation 記録済み (Android の表示鍵の形: deviation.md 7 行目。Scenario の挙動は一致) |
| 大きすぎる項目は使わない | `test大きすぎる項目は使わない` / `tooLargeItemIsNotUsed`・`tooLargePrefetchedItemIsNotReturnedByTheDisplayRequestForFit` | ⚠️ deviation 記録済み (同上) |
| 縦長の枠に fill するときは高さで判定する | `test縦長の枠にfillするときは高さで判定する` / `fillIntoATallFrameIsJudgedByHeight` | ✅ 一致 |
| 消した項目は引き当てない | `test消した項目は引き当てない` / `removedItemIsNotMatched`・`KsImageMemoryIndexTest` の `clearInvalidatesCacheAndIndexOnReturn` / `removeInvalidatesCacheAndIndexOnReturn` / `concurrentRegistrationNeverPointsToRemovedItems`。**取得中の数えも消去に従う**: And `fetchInFlightOfARemovedKeyIsIgnored` (`remove` の後は取得中を数えない)。iOS は `remove(_:)` と `removeAll()` が `pendingPrefetchKeys` も外す (`KsImageMemoryIndex.swift:150-153,185`) | ✅ 一致 |

補足 (Scenario 外の本文条項):

- 画面に出る時点で引き当てた後に枠が変わる場合: iOS の `test画面に出る時点で引き当てた後に枠が…` の 2 本は成功した。And は `key(prepared)` (`KsImage.kt:231`) で、枠が変わると部品ごと作り直す
- 索引の刈り込みをやめた合意 (deviation.md 10 行目) は変わらない。取得中の数え (`fetchesInFlight` / `pendingPrefetchKeys`) は索引の鍵とは別に持ち、索引から鍵を外す条件 (`clear` / `remove` / LRU) は変わっていない

### ADDED: 画像の任意キー

実装・テストは verify-002 から変更なし。`KsImageIdentity.kt` の更新時刻は新しいが、識別子の形 (`"ks-key " + key`) と鍵の組み立て (`displayKey` に当てはめ方を載せる、`sizedKey` は `coil#size` のみ) は、deviation.md 3・7 行目の記録どおり。取得中の判定も識別子で索引を引く (`hasFetchInFlight(identifier, …)`、iOS `mayBeLoadingPrefetch(forEffectiveID:…)`)。

| Scenario | テスト | 状態 |
|---|---|---|
| 署名が変わっても先読みの項目を使う | `test署名が変わっても同じキーなら先読みの項目で表示する` / `keyedMemoryPrefetchIsMatchedAcrossSignatures` | ✅ 一致 |
| 起動をまたいでもディスクの項目を使う | `test起動をまたいでも同じキーならディスクの元データから表示する` / `keyedDiskItemIsUsedAfterARestart` | ✅ 一致 |
| key なしは URL で識別する | `testキーなしは別のURLを別の画像として取得する` / `keylessImagesAreIdentifiedByUrl` | ✅ 一致 |
| key と URL は衝突しない | `testキーとURLが同じ文字列でも衝突しない` / `keyEqualToAnotherUrlDoesNotCollide` | ✅ 一致 |
| 削除の世代は別の key と衝突しない | `test削除の世代は別のキーと衝突しない` / `removedKeyDoesNotCollideWithASuffixedKey` | ⚠️ deviation 記録済み (識別子の文字列の形: deviation.md 3 行目。Scenario の挙動は一致) |
| 署名だけが変わった配列の差し替えでは新しい URL で出し直す | `testキーが同じでURLだけが変わった配列の差し替えでは古いURLを止めて新しいURLで出し直す` ほか / `changingOnlyTheSignedUrlRestartsWithTheNewUrl` ほか | ✅ 一致 |
| 取得済みの画像は署名が変わっても取り直さない | `test取得済みの画像は署名が変わっても取り直さない` / `reissuedKeyedPrefetchHitsTheCache` | ✅ 一致 |
| 空文字の key は key なし扱い | `test空文字のキーは警告してURLで見分ける` (2 クラス) / `emptyKeyIsWarnedAndTreatedAsKeyless`・`emptyKeyStopsInDebug` | ✅ 一致 |

### MODIFIED: プリフェッチ宣言

実装・テストは verify-002 から変更なし。

| Scenario | テスト | 状態 |
|---|---|---|
| もうすぐ表示されるアイテムの画像を取得する | `test先読み対象の項目がURLへ解決されて到達点付きで開始される` / `scrollingForwardAdvancesWindow` | ✅ 一致 |
| 宣言が無ければ何も起きない | `test宣言が無ければ受け口へ何も伝わらない` / `noDeclarationStartsNothing` | ✅ 一致 |
| 複数 URL の宣言 | `test1項目に複数のURLを宣言すると両方の取得が始まる` / `multipleUrlsPerItemAreAllStarted` | ✅ 一致 |
| 幅なしの要素は元寸を載せる | `test幅あり幅なしを混ぜた宣言ではそれぞれの大きさで載る` / `declarationWithoutWidthKeepsTheOriginalSize`。実機: `evidence/memory-steady-*.md` | ✅ 一致 |

### MODIFIED: プリフェッチの取り消し

台帳 (`KsImagePrefetcher` / `KsImagePrefetchWindow`) は verify-002 から変更なし。受け口の側では、取り消しの通知で取得中の数えを外す処理が加わった (iOS `KsNukeImageLoading.cancel` → `index.cancelPrefetch`、And は取り消しの取っ手で `endFetch()`)。取り消しそのものの挙動は変わらない。

| Scenario | テスト | 状態 |
|---|---|---|
| スクロール方向の反転で取り消される | `testシステムの先読み通知で取得が始まり取り消し通知で止まる` / `reversingDirectionCancelsOldWindowAndStartsNewOne` | ✅ 一致 |
| 配列の差し替えで消えたアイテム | `test配列の差し替えで消えた項目の取得は取り消される` / `replacingItemsCancelsRequestsForRemovedItems` | ✅ 一致 |
| 共有 URL は最後のアイテムが外れるまで取り消さない | `test共有URLは最後の項目が外れるまで取り消さない` / `sharedUrlIsCancelledOnlyAfterLastItemLeaves` | ✅ 一致 |
| 幅が違えば別の取得 (memory) | `test到達点memoryでは同じURLでも幅が違えば別の取得として数える` / `differentWidthsAreIndependentForMemory` | ✅ 一致 |
| disk では幅違いも 1 つの取得 | `test到達点diskでは幅違いも1つの取得にまとめる` / `differentWidthsShareOneRequestForDisk` | ✅ 一致 |
| 向きが変わっただけでは触らない | `test列幅が変わっただけでは進行中の取得を取り消さず出し直しもしない` / `rotationAloneDoesNotTouchRequestsInFlight` | ✅ 一致 |
| 向きが変わった後の取り消し | `test列幅が変わった後の取り消しは始めたときの要求で行う` / `cancellationAfterRotationTargetsTheRequestStartedBefore` | ✅ 一致 |
| 画面から消えたら全て取り消す | `test画面から消えたときに未完了の取得をすべて取り消す` / `leavingCompositionDisposesAll` | ✅ 一致 |

### MODIFIED: プリフェッチの到達点

| Scenario | テスト・証跡 | 状態 |
|---|---|---|
| ディスク到達点の後の表示 | `testディスク到達点の後の表示ではネットワークが走らない` / `diskDestinationStoresDataWithoutDecodingOrRefetching`。**到達点 disk の先読みは取得中として数えないので、遅らせる経路に入らない**: iOS `testディスクまでの先読みと取り消した先読みでは表示の要求を待たない`、And `diskPrefetchIsNotCountedAsInFlight`、実機は `evidence/disk-wait-android.md` の「性能改善後」(ディスクまでで遅らせた表示要求 0%) | ✅ 一致 |
| **メモリ到達点の後の表示** | 単体・契約: verify-002 のテスト群 (iOS `testメモリ到達点の後の表示では再デコードしない`・`test前もって組み立てた後に先読みが完了すれば画面に出る時点で引き当てて読み込み中を経由しない`、And `memoryDestinationIsDisplayedWithoutSecondDecode`・`precomposedDisplayMatchesTheItemThatArrivedBeforeItWasShown`・`KsImageShownFrameTest`) は成功。**改善後の条件の絞り込みで GIVEN の場合が外れないこと**も固定されている。取得中の先読みは待つ: iOS `test取得中のメモリまでの先読みがあるときだけ…`、And `memoryPrefetchIsInFlightOnlyUntilItCompletes`・`shownLookupMatchDoesNotRecompose`。**実機 (改善後のビルド)**: iOS は `evidence/device-image-match-ios.md` の「改善後のビルドでの確認」(幅なし・列幅とも、現れた 147 件のうち引き当て 138 件で違反 0。表示の要求は、先読みが間に合わなかった 9 件だけ)。Android は `evidence/loader-counts-android.md` の「性能改善後」(フリングで、同時取得数 5・64 × メモリまで・列幅の各 2 走行。画面に出た時点で先読みが完了していたセルのすべてで、表示要求・取得・デコード・`loading-shown` が 0。対照の比較用ビルドでは各 6 件の違反が出ており、数え方は空振りしていない) | ✅ 一致 (改善後のビルドでも違反 0 件。tasks 8.2 の裏付けが改善後のコードに更新された) |
| 到達点が伝わる | `test到達点memoryの宣言はmemoryとして受け口へ届く` / `destinationIsPassedThroughToLoader` | ✅ 一致 |

「メモリ到達点の後の表示」の GIVEN の読み方は、verify-002 と同じとする。画面に出た時点で先読みが未完了だった項目は GIVEN の外にある (例: iOS の 9 件、Android の二重取得 30〜35%)。証跡もこの読み方で分けている。

今回の絞り込みで、先読みが完了済み・失敗・取り消し済み・追い出し済みの画像は、組み立ての時点で要求を出すようになった。このうち完了済みで項目がメモリにある画像は、組み立ての時点の引き当てで当たる。項目がメモリに無い画像は、そもそも GIVEN を満たさない。したがって、絞り込みは GIVEN の場合を外さない。

### MODIFIED: 共有キャッシュ

実装・テストは verify-002 から変更なし。

| Scenario | テスト | 状態 |
|---|---|---|
| ローダー付属ビューとキャッシュを共有する | `testローダーを直接使う素の要求と同じキャッシュ項目を共有する` / `requestsMadeDirectlyOnTheSharedLoaderReuseThePrefetchedData` | ✅ 一致 |
| key 付きの項目は付属ビューと共有しない | `testキー付きの先読みはローダー付属のビューの要求と共有しない` / `keyedItemsAreNotSharedWithDirectLoaderRequests` | ✅ 一致 |
| iOS のディスクキャッシュ有効化 | `KsImagePipelineTests` 4 本 | ✅ 一致 |

### MODIFIED: KsImage の画像ソース

| Scenario | テスト | 状態 |
|---|---|---|
| 3 種のソースを表示する | `KsImageDisplayTests` 3 本・`test3種のソースがそれぞれの経路へ振り分けられる` / `threeSourceKindsAreDisplayed` | ✅ 一致 |
| **便宜形** | `test便宜形はリモートのソースと同じ宣言になる` / `urlConvenienceFormBehavesLikeRemoteSource`・`convenienceFormPassesTheKey` | ✅ 一致 (注記: `urlConvenienceFormBehavesLikeRemoteSource` が 5 回の実行のうち 1 回失敗した。テストの待ち方の問題と見立てる。上の「テスト実行」を参照) |

### MODIFIED: KsImage の縮小デコード

実装: 縮小指定 (`KsImageRequestFactory` の表示の要求) は verify-002 と同じ。要求を出す時点は、上の「今回の実装の要点」のとおりに変わった。

| Scenario | テスト | 状態 |
|---|---|---|
| 枠より大きい画像 | `test枠より大きい画像は当てはめ方に応じた寸法へ縮小される` / `displayRequestDecodesToTheFrameSize`・実機 `displayDoesNotKeepTheOriginalInMemory` | ✅ 一致 |
| **サイズ確定前は取得しない** | 前半の「サイズ確定前は発行しない」: `testサイズが確定するまで要求を発行しない` / `noRequestIsBuiltBeforeTheFrameSizeIsSettled` (`lookup` は幅・高さが 0 以下なら null で、読み込み中の表示だけを置く。`KsImage.kt:208`)。後半の「サイズが確定した時点で発行される」: 遅らせない場合は、サイズ確定後の組み立ての時点で要求を出す (`precomposedDisplayWithoutPrefetchRequestsBeforeItIsShown`、`precomposedDisplayWithCompletedButUnusablePrefetchRequestsBeforeItIsShown`、**`precomposedDisplayWithEndedPrefetchRequestsBeforeItIsShown` (今回追加。取得が終わった先読みでは遅らせない)**)。遅らせる場合 (And で、その識別子の先読みが取得中のとき) は、画面に出る時点で要求を出す (`precomposedDisplayRequestsOnlyWhenShownWithoutAnItem`、`shownLookupMissLoadsWithoutRecomposition`) | ⚠️ deviation 記録済み (deviation.md 末尾の行の「利用者から見える差」。**今回、遅らせる条件が「索引に先読みの鍵がある」から「先読みが取得中」へ狭まった**。記録の文言「完了・失敗・取り消し済みは遅らせない。性能改善サイクルで索引の条件から取得中の条件へ絞った」は実装と一致する。iOS は、要求の開始が画面に出る時点であることが、包むかどうかによらず変わらない) |
| 枠が変わっても範囲内なら再デコードしない | `test枠が変わっても範囲内なら同じ項目を使い続ける` / `resizingWithinTheRangeKeepsTheSameItem`。画面に出る時点で引き当てた場合: `test画面に出る時点で引き当てた後に枠が変わっても範囲内なら再デコードしない` | ✅ 一致 |

### MODIFIED: KsImage の読み込み取り消しとメモリ保持

| Scenario | テスト・証跡 | 状態 |
|---|---|---|
| **画面外へ出た読み込みの取り消し** | 単体テスト層に観測点が無い点は前回と同じ。実機の観測も前回と同じ (`evidence/loader-counts-ios.md`、`evidence/disk-wait-ios.md`、`evidence/disk-wait-android.md` の初回の節。いずれも表示の要求の大半が、セルが画面から外れた時点で取り消された)。**今回変わった遅延の経路の取り消しは、実装で次のとおり確かめた**: iOS `KsImageDeferredLoad` は `onDisappear` で `fetch.cancel()` (`KsImageDeferredLoad.swift:60-62`)。And `KsDeferredNode` は要求を部品の `coroutineScope` で始める (`KsImage.kt:386`)。このスコープは部品が外れると取り消され、再利用のとき (`onReset`) には明示的に取り消す (`KsImage.kt:419-425`) | ✅ 一致 (注記: 遅延の経路の取り消しは、実装の読みによる確認に留まる。改善後のビルドで取り消しの件数を数えた証跡は無い。「性能改善後」の証跡は、取り消しを数えていない) |
| **戻ってきたときの再表示** | `test一度表示した画像は表示を作り直しても読み込み中を経由しない` / `loadingSlotIsNeverComposedWhenTheDisplayIsRebuilt`。実機: `evidence/device-image-match-ios.md` の戻し。**改善後のビルドでも、戻しの後の表示の要求・読み込み中はともに 0** (同じ証跡の末尾の節) | ✅ 一致 |
| 追い出された項目は再デコードする | `test追い出された項目はディスクの元データから再デコードする` / `evictedItemIsRedecodedFromDisk` | ✅ 一致 |

### MODIFIED: KsImage の表示状態

実装の区分は次のとおり。

- iOS
  - 成功: 組み立て時か画面に出る時点で引き当てた画像、または `fetch.image` / `state.image`
  - 失敗: `fetch.result` の `.failure` / `state.error`
  - 読み込み中: それ以外
- And (遅延の経路)
  - 成功: 部品が描く画像
  - 失敗: `failed` による失敗の表示
  - 読み込み中: 部品が描く既定の表示か、利用者の読み込み中の表示

| Scenario | テスト | 状態 |
|---|---|---|
| **読み込み中から成功へ** | 前回のテスト (`testリモートのソースは画像が表示される`・`test表示中のKsImageは全消去で取得をやり直す` / `itemsLoadedByTheLoaderDirectlyGoThroughLoading`・`KsImageShownFrameTest` `loadingSlotIsDrawnInTheFirstFrameWhenTheShownLookupMisses`)。**遅延の経路の分**: iOS `test先読みが取得中のまま画面に出た表示は表示の要求を出して画像を表示する`、And `shownLookupMissLoadsWithoutRecomposition` と `KsImageShownFrameTest` `defaultLoadingIsDrawnInTheFirstFrameWhenTheShownLookupMisses` (外れたら最初の描画で既定の読み込み中を描き、取得後に画像になる) | ✅ 一致 |
| **失敗時の表示** | `KsImageAccessibilityTests` の 2 本 / `failureSlotIsShownWhenLoadingFails`。**遅延の経路**: And `shownLookupMissShowsTheFailureSlotWhenLoadingFails` (失敗のスロットに切り替わり、読み込み中は残らない)。iOS は `fetch.result` の `.failure` で失敗の表示を置く (`KsImageDeferredLoad.swift:41-42`。この経路の失敗に専用の自動テストは無い) | ✅ 一致 |
| 失敗後の再試行 | `test失敗した表示はビューが作り直されると再び取得を試みる` / `failedImageIsRetriedWhenTheViewIsRecreated`。遅延の経路では、同じ表示が続く間は再試行しない (`shownLookupMissShowsTheFailureSlotWhenLoadingFails` の「自動で再試行しました」の検査で取得 1 回) | ✅ 一致 |
| **スロットの差し替え** | `test読み込み中と失敗の表示は片方だけでも差し替えられる` / `imageSlotsCanBeSubstitutedIndependently`。**遅延の経路**: And `KsImageShownFrameTest` `loadingSlotIsDrawnInTheFirstFrameWhenTheShownLookupMisses` (利用者の読み込み中の表示) と `shownLookupMissShowsTheFailureSlotWhenLoadingFails` (利用者の失敗の表示) | ✅ 一致 |

### MODIFIED: キャッシュのクリア

実装: verify-002 と同じ。画面に出る時点の引き当ての状態は、世代 (`reloadToken`) を含む条件ごとに捨てられる (iOS `.id(condition)`・`.id(reloadToken)` (`KsImage.swift:181,184`)、And `key(source, reloadToken)` (`KsImage.kt:192`))。今回加わった取得中の数えは、`clear` で全部 (`removeAll`) が、`remove` でその識別子の分が外れる (上の「消した項目は引き当てない」)。

| Scenario | テスト | 状態 |
|---|---|---|
| 全消去の後の表示 | `test全消去の後の表示はメモリに当たらず取り直しになる`・`test引き当てた画像を保持していても全消去では取得をやり直す` / `clearingAllAlsoInvalidatesTheDecodedMemoryImage` | ✅ 一致 |
| メモリのみ消去 | `testメモリのみ消去してもディスクの元データから再デコードできる` / `clearingMemoryKeepsDiskDataForRedecoding`。実機: `evidence/device-image-match-ios.md` (改善後のビルドでも、メモリのみの消去の後に表示の要求・読み込み中が 0) | ✅ 一致 |
| ソース単位の削除 | `testソース単位の削除では対象のソースだけが消える` / `removeDeletesOnlyTheTargetSource`・`removeMakesTheDisplayedImageReload` | ✅ 一致 |
| key 付きの画像は同じ key で消える | `testキー付きの画像は同じキーのソースで消えキーなしでは消えない` / `keyedImagesAreRemovedBySameKey` | ✅ 一致 |
| key なしのソースでは key 付きの画像は消えない | 同上の前半 / `keyedImagesAreRemovedBySameKey` の前半 | ✅ 一致 |
| 削除後は別サイズでも旧項目に当たらない (iOS) | `test削除後はどの表示サイズの要求も削除前の項目に当たらない` | ✅ 一致 |

### MODIFIED: Sample のデモ画面「画像グリッド」

実装: verify-002 と同じ (`ImagePrefetchChoice` / `ImageGridFixture` / `ImageGridDemoView` / `ImageGridDemoScreen` / `SampleMenuPicker.kt`)。今回の samples/ios の変更は、計測の足場の取り込みである。

- `ImageGridCount` (起動引数 `--image-count`。無指定なら 10,000 件で従来どおり。受け取れない値では起動を止める)
- `DemoData.imageGridItemCount` がこの値を読む形への変更
- 観測・計測用の起動経路への追加

デモ画面の選択肢・宣言・全消去の挙動は変わらない。

| Scenario | テスト・証跡 | 状態 |
|---|---|---|
| 切り替えの反映 | `SampleDemoScreenTest`・`ImageGridMeasurementFixtureTest` (Android)。iOS は `ImageLoadingSlotUITests` | ⚠️ deviation 記録済み (メニュー形式: deviation.md 4 行目) |
| 列幅の先読みに切り替える | 選択 → 宣言の写像: 前回と同じ (`ImageGridMeasurementFixtureTest`、`SampleDemoScreenTest`、iOS `ImagePrefetchChoice.swift`)。実機: 前回の証跡に加えて、**改善後のビルドでも同じ結果**。iOS は `evidence/device-image-match-ios.md` の末尾の節 (列幅で引き当て 138 件、255 × 255、元寸無し、違反 0)。Android は `evidence/loader-counts-android.md` の「性能改善後」(列幅 × 同時取得数 5・64 の各 2 走行で、表示要求 0・`loading-shown` 0) | ✅ 一致 (前回の注記 (起動時の指定で「メモリまで (列幅)」を選んだ観測であり、画面上の切り替え操作そのものではない) はそのまま残る) |
| 全消去 | `ImageGridDemoView.swift` (`KsImageCache.clear(.all)`) + `test表示中のKsImageは全消去で取得をやり直す` / `ImageGridDemoScreen.kt` + `clearingAllAlsoInvalidatesTheDecodedMemoryImage` | ✅ 一致 |

## 追加検査

- [x] **tasks.md**: 37 件すべてがチェック済み (前回未チェックだった 8.1 が今回チェックされた)。対応表と突き合わせ、虚偽のチェックは無いことを確かめた。8.1〜8.5 の裏付けは次のとおり。
  - **8.1**: `evidence/manual-imageGrid-{android,ios}-after.md` の「最終ビルドでの採り直し — 2026-09-24」に、両基準機の 3 到達点 (「メモリまで」「メモリまで (列幅)」「ディスクまで」) の 6 走行がそろっている。どちらも Pixel 4a / iPhone 11 で、固定の操作列による手動フリックである。各走行に次の記録がある。
    - オーナーの体感 (滑らかさ): 6 走行とも合格
    - 画像の出方
    - 数値
    - before・前回との比較の可否と差
    - 悪化した数値の扱い

    タスク文の要件 (1.1 と同じ操作列、3 到達点 × 両基準機、体感の合否と表示待ち、before との比較可否と差) を満たす。**記録として残す点**: この 6 走行のビルドは、証跡の記述どおり「review-008 / verify-002 の時点」のもので、今回の性能改善より前である。改善後のビルドの確認は、次のとおり自動駆動の A/B だけである。
    - Android: 「メモリまで」「ディスクまで」× 3 ビルド × 5 反復。改善後は「メモリまで」の janky 中央値 3.19% で、比較用 3.63%・改善前 4.89% より良い
    - iOS: 「ディスクまで」の改善後は 1 回だけ。依頼の回数に届いておらず、熱状態 Fair・待機 60 秒で条件がそろっていない。証跡の「限界」にオーナー決定で打ち切ったと明記されている

    どちらの証跡も、体感の手動計測をやり直していないことを明記している。証跡は、改善の向き (改善前のビルドの体感合格より悪くならない方向) を数値で示している。タスク文は最終のコードでの採り直しを要件にしていないため、虚偽とはしない。改善後のコードで体感ゲートを取り直すかは、呼び出し元とオーナーの判断に委ねる
  - **8.2**: `evidence/loader-counts-android.md` の「性能改善後」と `evidence/device-image-match-ios.md` の「改善後のビルドでの確認」で、改善後のコードでも違反 0 件 (上の「メモリ到達点の後の表示」)
  - **8.3**: `evidence/memory-steady-{ios,android}.md`。iOS の読み込み待ちの往復の数値は、Sample の複製 (スクラッチ) に足した足場で採られている。今回その足場がリポジトリへ取り込まれ、リポジトリ版では Simulator で出力の形だけを確かめたことが明記されている (実機の数値は採り直していない)。改善はメモリに載せる項目・索引の上限を変えていない (取得中の数えは索引とは別の集合に持つ)。このため、8.3 の結論には影響しないと判断した
  - **8.4**: 両証跡の「8.4 … (最終ビルド)」の節 (定数 0.5 / 4 は不変。オーナーの見た目の指摘は無い)。改善は引き当ての規則を変えていない
  - **8.5**: `evidence/disk-wait-{android,ios}.md`。Android には「性能改善後」の節が加わった (遅らせた表示要求の割合 65〜70% → 38〜41%、待ちの差は縮まらない、主因は同一ホストの同時取得数 5 のまま)。「簡易起票の材料」の節は前回と同じで、`kasane/changes/` に新しい簡易起票は無い。タスク文は「必要なら簡易起票する」という条件付きなので、虚偽とはしない (前回と同じ)
- [x] **逆流検査**: `git diff HEAD --stat -- kasane/changes/prefetch-display-size/{proposal.md,design.md,exploration.md,specs}` は空。`tasks.md` の差分は、`git diff --word-diff=porcelain` で見て `-[ ]` / `+[x]` の 37 対だけで、本文の変更は無い。deviation.md は未追跡の新規ファイル (合意の記録) で、今回は末尾の行の「利用者から見える差」の括弧内が更新された
- [x] **未記録乖離**: なし。今回の性能改善で変わったのは次の 2 点で、どちらも deviation.md 末尾の行の現在の記述と一致する。
  - iOS: 包むのを取得中の可能性があるときだけにし、中身の差し替えをやめた
  - Android: 遅らせる条件を取得中に絞り、画面に出る時点の処理を部品の中で終え、再合成をしない

  Scenario に対して新しく生じた差は無い。「サイズ確定前は取得しない」の ⚠️ の範囲は狭まった
- [x] **付随修正**: samples/ios に取り込まれた計測の足場 (`ImageGridCount.swift`、`ImageGridCountUITests.swift`、`DemoData.swift` / `KsCollectionViewSamplesApp.swift` の接続、`ImageLoadingObservation.swift`、`ImagePrefetchMatchProbe.swift`、`PerformanceVerificationView.swift`、性能スキームの除外指定) は、tasks 8.3 / 8.5 の計測手順の再現のためのもので、前回「スクラッチにだけある」と記録した足場にあたる。`evidence/memory-steady-ios.md:33-41` と `evidence/disk-wait-ios.md:112-119` に、取り込みと、リポジトリ版で出力の形を確かめたことが記録されている。無指定の起動は従来の 10,000 件で、デモ画面の Scenario の挙動は変えない。前回と同じく計測の足場として扱い、`[付随修正]` の記録が無いことを乖離とはしない。記録するべきかどうかは呼び出し元の判断に委ねる
- [x] **UI 変更**: 本 change は `ui/` を持たない。Sample の選択の見せ方は deviation.md 4 行目で合意済み
- [x] **テスト成功**: 上の「テスト実行」のとおり、最終の実行ではすべて成功した (iOS パッケージ 275、iOS Sample 12、Android ライブラリ 231、Android Sample 44)。Android ライブラリの 1 回目の全件実行で `urlConvenienceFormBehavesLikeRemoteSource` が 1 回失敗した。テストの待ち方による揺れと見立て、申し送る

## まとめ

| 区分 | 件数 |
|---|---|
| ✅ 一致 | 56 |
| ⚠️ deviation 記録済み | 5 (小さすぎる項目は使わない / 大きすぎる項目は使わない / 削除の世代は別の key と衝突しない / サイズ確定前は取得しない (今回、範囲が狭まった) / 切り替えの反映)。このほか、16384 px の上限・索引の刈り込み・画面に出る時点の引き当て (deviation.md 末尾の行) の合意が、各表の補足と実装欄に該当する |
| ❌ 欠落・乖離 | 0 |
| 合計 | 61 Scenario (13 Requirement) |

呼び出し元への申し送り (判定には影響しない):

1. `KsImageTest.urlConvenienceFormBehavesLikeRemoteSource` は、負荷が高いと失敗しうる書き方になっている。取得の回数を待たずに読んでいるためで、テスト本体は HEAD から変わっていない。直すならテスト側で待つ形にする
2. tasks 8.1 の手動の 6 走行は、性能改善より前のビルドで採られている。改善後の確認は自動駆動の A/B だけで、iOS は「ディスクまで」1 回に留まる。改善後のコードで体感ゲートを取り直すかは、オーナーの判断に委ねる
3. 「画面外へ出た読み込みの取り消し」は、遅延の経路 (両プラットフォームとも今回の改善で形が変わった) について、実装の読みによる確認に留まる。改善後のビルドで取り消しを数えた証跡は無い
