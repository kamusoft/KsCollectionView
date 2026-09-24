# Verify 001: prefetch-display-size

- 対象: コミット 3e4a918 (HEAD) に対する作業ツリーの未コミット差分 (`git diff HEAD` と未追跡ファイル)。ios/Sources・ios/Tests、android/kscollectionview/src (test・androidTest 含む)、samples/ios、samples/android
- 突き合わせ元: `specs/image-loading/spec.md` (ADDED 3・MODIFIED 10 の計 13 Requirement / 61 Scenario)、`tasks.md`、`deviation.md`、`design.md`、`proposal.md`
- 検証日: 2026-09-23
- 検証者の立場: 一致検証のみ (品質評価は review の領分)。同時進行の review-005.md は読んでいない

## 判定: VALID (実機確認の残りつき)

自動テストで検査できる範囲では、全 61 Scenario が「✅ 一致」または「⚠️ deviation 記録済み」で、❌ (未記録の欠落・乖離) は 0 件。虚偽のチェック・足場の逆流・テスト失敗は無い。

ただし tasks 6.6 と 8.1〜8.5 は未実施 (未チェックで、虚偽ではない)。実機でしか成立しない確認に依存する 3 Scenario は「⏳ 実機確認待ち」として分けた (下の「実機確認待ちの Scenario」。同じ 8.x で閉じる Requirement 本文・design の確認事項 2 件も併記)。自動テストで担保できている範囲は各行に書いた。**ksn-distill の前に、6.6 / 8.x の完了と証跡 (`evidence/manual-imageGrid-{android,ios}-after.md` ほか) の追加を確認する必要がある。** これらの実機の結果が spec と食い違った場合は、その時点で INVALID に戻る。

凡例: ✅ 一致 / ⚠️ deviation 記録済み / ⏳ 実機確認待ち (自動テストの範囲は一致) / ❌ 欠落・乖離

## テスト実行 (検証者が再実行)

| 対象 | コマンド | 結果 |
|---|---|---|
| iOS パッケージ | `ios/` で `xcodebuild test -scheme KsCollectionView` (iPhone Air / iOS 26.5 Simulator、DerivedData はスクラッチ) | **268 tests / 0 failures** |
| iOS Sample (UI テスト、通常スキーム) | `samples/ios/` で `xcodebuild test -scheme KsCollectionViewSamples` (iPhone 17 Pro Max / iOS 26.5 Simulator) | **9 tests / 0 failures** (ImageLoadingSlot 2・InteractiveControl 3・LargeDataCount 4。計測ドライバは含まれない) |
| Android ライブラリ | `android/` で `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` | **213 tests / 0 failures / 0 skip** (12 クラス: PrefetchWindow 41・KsImage 44・CacheContract 23・MemoryIndex 9・CollectionViewPrefetch 9・PrefetchDecodeSize 4・PrefetchMetrics 6・PublicApi 8・Core 14・Layout 30・Interaction 22・AppContext 3) |
| Android Sample | `samples/android/` で `./gradlew :app:testDebugUnitTest --rerun-tasks` | **37 tests / 0 failures / 0 skip** (7 クラス) |
| Android 実機 `KsImageDeviceDecodeTest` | 検証者は実機を使わない制約のため再実行していない | ホスト報告: Pixel 4a / Android 13 で 4 / 0 / skip 0 |

## 対応表

実装・テストのパスは、iOS は `ios/Sources/KsCollectionView/`・`ios/Tests/KsCollectionViewTests/`、Android は `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/`・`android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/` (androidTest は `.../src/androidTest/kotlin/jp/kamusoft/kscollectionview/`) の下を指す。

### ADDED: プリフェッチの表示幅

実装: `KsResource.swift` / `KsWidth.swift` / `KsPrefetchDeclaration.swift:18-30` (無効な固定値) / `KsPrefetchRequest.swift:21-33` (幅の正方形を覆う `aspectFill` 縮小) / `KsImagePrefetcher.swift:220-236` (単位への解決、disk では幅を落とす) / `KsCollectionViewController.swift:261-277` + `KsLayoutMetrics.swift:24-45` (列幅) / `KsPrefetchMetrics.swift:16-22` (px 化と上限)。And: `KsResource.kt` / `KsWidth.kt` / `KsPrefetchDeclaration.kt:35-59,76-135` / `KsCoilImageLoading.kt:53-70` (`size(w,w)` + `Scale.FILL` + `Precision.INEXACT`) / `KsImagePrefetchWindow.kt:290-305` / `KsCollectionView.kt:230-256`

| Scenario | テスト | 状態 |
|---|---|---|
| 列幅で縮小して載せる | iOS: `KsImagePrefetchTests` `test列幅の要素はその時点の列幅のピクセルで始まる`、`KsImageCacheContractTests` `test幅つきの先読みは幅の正方形を覆う大きさで載り元寸は載らない` (200x100 → 80x40、元寸の鍵は nil)<br>And: `KsImagePrefetchWindowTest` `columnWidthIsResolvedToPixelsForMemory`、`KsPrefetchDecodeSizeTest` `widthDeclarationCoversTheSquare`、`KsImageCacheContractTest` `columnWidthPrefetchIsMatchedByTheDisplay` (元寸の鍵に載らない)、実機 `KsImageDeviceDecodeTest` `widthPrefetchStoresTheDeclaredWidth` | ✅ 一致 |
| 固定値で縮小して載せる | iOS: `test固定値の要素は表示倍率込みのピクセルで始まる` + 上の縮小経路 (幅の px が同じ要求を通る)<br>And: `fixedWidthIsScaledByDensity`、`widthDeclarationCoversTheSquare` | ✅ 一致 |
| 元寸が小さければ拡大しない | iOS: `test元寸が宣言した幅より小さければ拡大せずに載る` (8x8 を 100 で宣言 → 8x8)<br>And: `KsPrefetchDecodeSizeTest` `smallerOriginalIsNotUpscaled` | ✅ 一致 |
| 幅あり・幅なしの混在 | iOS: `test幅あり幅なしを混ぜた宣言はそれぞれの大きさで始まる`、`test幅あり幅なしを混ぜた宣言ではそれぞれの大きさで載る` (列幅 50x50・幅なし 200x200)<br>And: `mixedDeclarationsProduceTheirOwnRequests`、`mixedDeclarationsStoreTheirOwnSizes` | ✅ 一致 |
| 向きが変わると新しい列幅で先読みする | iOS: `test列幅が変わっただけでは進行中の取得を取り消さず出し直しもしない` (後から対象になった項目が 300px で始まる、取り消し 0)、`testコレクションの先読み通知は表示領域から解いた列幅で始まる`<br>And: `KsCollectionViewPrefetchTest` `orientationChangeUsesTheNewColumnWidthForNewPrefetches`、`rotationAloneDoesNotTouchRequestsInFlight`。縦向きの項目が消されないのは、回転でキャッシュ・索引を消す経路が無いこと (消去は `KsImageCache` のみ) による | ✅ 一致 |
| 到達点 disk では幅を使わない | iOS: `test到達点diskでは幅を使わない`、`test到達点diskでは幅を宣言しても元データの保存までで止まる` (デコード 0・メモリ無し・索引無し)<br>And: `diskDestinationIgnoresWidth`、`KsImageCacheContractTest` `diskDestinationStoresDataWithoutDecodingOrRefetching` | ✅ 一致 |
| 無効な固定値は幅なし扱い | iOS: `test無効な固定値は警告して幅なしとして扱う` (0・負・NaN・無限大、release 経路)、`test無効な固定値の警告は通知が重なっても同じ文面につき1回だけ記録する`。debug の停止は `KsInvalidInput.swift:20-24` の `assertionFailure` (テストでは停止を下ろして release 経路だけを検査)<br>And: `invalidFixedWidthsAreReportedAndTreatedAsOriginal`、`reportingCanStopTheUpdate` (debug 停止) | ✅ 一致 |
| 列幅が解けない間は始めない | iOS: `test列幅が解けない間は列幅の先読みを始めない` (-10・0 では固定値だけ始まり、正になった後の項目から列幅も始まる)、`KsLayoutMetricsTests` 系 + `test列幅は表示領域から内側余白と列の間隔を引いて列数で割る`<br>And: `columnWidthDeclarationsWaitUntilTheWidthResolves`、`KsPrefetchMetricsTest` `unresolvableWidthIsZero` | ✅ 一致 |

補足: 固定値の px を 16384 で頭打ちにする実装 (`KsPrefetchMetrics.swift:8,20`、`KsPrefetchDeclaration.kt:82-93`、テスト `test大きすぎる固定値は停止せず幅のピクセルの上限で始まる` / `hugeFixedWidthsAreCappedAtTheMaximumPixels` ほか) は deviation.md 11 行目に記録済み (⚠️ 合意済み。上の Scenario の判定には影響しない)。

### ADDED: KsImage のメモリ項目の引き当て

実装: `KsImageMatching.swift` (下限 0.5・上限 4、`fill`=max / `fit`=min、最も近い候補) / `KsImageRequestFactory.swift:46-76` / `KsImageMemoryIndex.swift` / `KsImage.swift:120-170` (引き当て成功時は `LazyImage` を作らない) / `KsImageRetainedMatch.swift` / `KsImageCache.swift:31,72`。And: `KsImageMatching.kt` / `KsImageRequestFactory.kt:44-89` / `KsImageMemoryIndex.kt` (1 つの錠) / `KsImage.kt:163-207` (成功時は `rememberAsyncImagePainter` を作らない) / `KsImageCache.kt:49,100`

| Scenario | テスト | 状態 |
|---|---|---|
| 先読みの縮小済み項目を使う | iOS: `KsImageTests` `test先読みの縮小済み項目を枠にそのまま使い要求を出さない`、`KsImageCacheContractTests` `test先読みの縮小済み項目で表示し読み込み中も表示の要求も経由しない` (読み込み中スロット 0 回・再ダウンロード無し・表示要求の鍵が索引に無い)<br>And: `prefetchedDownscaledItemIsUsed`、`columnWidthPrefetchIsMatchedByTheDisplay` (ネットワーク 1・デコード 1)、`loadingSlotIsNeverComposedWhenThePrefetchedImageIsInMemory` | ✅ 一致 |
| 原寸の項目を実機でも使う | iOS: `test原寸の項目も許容範囲の内側なら枠にそのまま使う`、`test画素の置き場に関わらず実物の寸法だけで判定する` (CGImage を持たない画像でも寸法だけで判定)<br>And: `originalItemWithinTheUpperBoundIsUsed`、実機 `graphicsBackedOriginalIsMatchedWithoutLoading` (ホスト報告 Pass) | ⏳ 実機確認待ち (6.6)。Android は実機テストで確認済み。iOS は単体テストで「画素を読まない判定」までを担保、iPhone 実機での原寸引き当ての確認が 6.6 で残る |
| 小さすぎる項目は使わない | iOS: `test小さすぎる項目は使わず枠の実サイズで縮小する要求を出す` (要求の縮小指定が枠 200x200、索引に登録)<br>And: `tooSmallItemIsNotUsed`、`smallerItemLoadedForFitIsNotReturnedByTheDisplayRequestForFill`、実機 `itemOutsideTheRangeFallsBackToDownscaledDecode` | ⚠️ deviation 記録済み (Android の表示鍵の形: deviation.md 7 行目。Scenario の挙動は一致) |
| 大きすぎる項目は使わない | iOS: `test大きすぎる項目は使わない`<br>And: `tooLargeItemIsNotUsed`、`tooLargePrefetchedItemIsNotReturnedByTheDisplayRequestForFit` | ⚠️ deviation 記録済み (Android の表示鍵の形: deviation.md 7 行目。Scenario の挙動は一致) |
| 縦長の枠に fill するときは高さで判定する | iOS: `test縦長の枠にfillするときは高さで判定する` (fill は不使用、fit なら使用)<br>And: `fillIntoATallFrameIsJudgedByHeight` | ✅ 一致 |
| 消した項目は引き当てない | iOS: `test消した項目は引き当てない`、`testメモリ全体を消した後は引き当てない`、`test削除はその識別子の鍵だけを索引から外す`<br>And: `removedItemIsNotMatched`、`clearedItemIsNotMatched`、`KsImageMemoryIndexTest` `removeInvalidatesCacheAndIndexOnReturn` / `clearInvalidatesCacheAndIndexOnReturn` / `concurrentRegistrationNeverPointsToRemovedItems` | ✅ 一致 |

補足 (Scenario 外の本文条項): 複数候補から最も近いものを選ぶ (`test範囲内の候補が複数あれば必要な寸法に最も近い項目を使う` / `closestItemIsChosenAmongCandidates`)、把握外の項目は対象外 (`itemsLoadedOutsideTheLibraryAreNotMatched` / `itemsLoadedByTheLoaderDirectlyGoThroughLoading`)、索引の上限 (`test索引は上限を超えると最も長く使われていない鍵から外す` / `capacityEvictsTheLeastRecentlyUsedKey`) も一致。索引の刈り込みをやめた点は deviation.md 10 行目で合意済みで、実装 (`KsImageMemoryIndex.swift:75-86`、`KsImageMemoryIndex.kt:57-64`) とテスト (`test先読みの完了前に照会しても完了後の次の照会で引き当てる` / `keysNotInTheCacheStayIndexedUntilTheItemArrives` / `evictedItemIsRedecodedFromDisk` の索引残存の検査) はその合意どおり。tasks 6.4 の「キャッシュに無い候補の破棄」は、この合意により「その回の候補にしない」の意味で完了扱いになっている。

### ADDED: 画像の任意キー

実装: `KsImageIdentity.swift` (key なし = URL、key あり = `"ks-key " + key`、世代付き = `"ks-gen N " + 識別子`) / `KsImageSource.swift:14` / `KsResource.swift` / `KsPrefetchDeclaration.swift` (識別子・URL・幅の種類で判定) / `KsImagePrefetcher.swift:165-318` (URL 変更の記録と出し直し) / `KsImageCache.swift:53-88`。And: `KsImageIdentity.kt` (key あり = `"ks-key " + key`、世代は鍵に入れない) / `KsImageSource.kt:22-25` / `KsPrefetchDeclaration.kt` / `KsCoilImageLoading.kt:46` (key ありはディスクの鍵も識別子) / `KsImageRequestFactory.kt:68` / `KsImagePrefetchWindow.kt:221-386` / `KsImageCache.kt:64-102`

| Scenario | テスト | 状態 |
|---|---|---|
| 署名が変わっても先読みの項目を使う | iOS: `test署名が変わっても同じキーなら先読みの項目で表示する` (署名違い URL へのアクセス 0)<br>And: `keyedMemoryPrefetchIsMatchedAcrossSignatures` (ネットワーク 1・デコード 1) | ✅ 一致 |
| 起動をまたいでもディスクの項目を使う | iOS: `test起動をまたいでも同じキーならディスクの元データから表示する` (パイプラインを作り直す)<br>And: `keyedDiskItemIsUsedAfterARestart` (メモリと索引を空にする) | ✅ 一致 |
| key なしは URL で識別する | iOS: `testキーなしは別のURLを別の画像として取得する`、`testキーなしの表示の要求は世代が進むまで識別子を付けない`<br>And: `keylessImagesAreIdentifiedByUrl`、`keylessRequestsKeepTheUrlBasedKeys` | ✅ 一致 |
| key と URL は衝突しない | iOS: `testキーとURLが同じ文字列でも衝突しない`、`KsImageTests` `testキーの識別子はURLの識別子と衝突しない`<br>And: `keyEqualToAnotherUrlDoesNotCollide` | ✅ 一致 |
| 削除の世代は別の key と衝突しない | iOS: `test削除の世代は別のキーと衝突しない` (`"p1#1"`)、`test削除の世代は別のキーや別のURLと衝突しない`<br>And: `removedKeyDoesNotCollideWithASuffixedKey` (Android は世代を鍵に入れないため構造上衝突しない) | ⚠️ deviation 記録済み (識別子の文字列の形: deviation.md 3 行目。Scenario の挙動は一致) |
| 署名だけが変わった配列の差し替えでは新しい URL で出し直す | iOS: `testキーが同じでURLだけが変わった配列の差し替えでは古いURLを止めて新しいURLで出し直す` ほか共有・同時変更・幅変更との組み合わせ 8 本 (`KsImagePrefetchTests.swift:685-895`)<br>And: `changingOnlyTheSignedUrlRestartsWithTheNewUrl` ほか組み合わせ 11 本 (`KsImagePrefetchWindowTest.kt:599-880`) | ✅ 一致 |
| 取得済みの画像は署名が変わっても取り直さない | iOS: `test取得済みの画像は署名が変わっても取り直さない` (新 URL へのアクセス 0)<br>And: `reissuedKeyedPrefetchHitsTheCache` (新 URL で出し直され成功、ネットワーク 1) | ✅ 一致 |
| 空文字の key は key なし扱い | iOS: `KsImagePrefetchTests` `test空文字のキーは警告してURLで見分ける`、`KsImageTests` `test空文字のキーは警告してURLで見分ける` / `…同じ文面につき1回だけ記録する`。debug 停止は `KsInvalidInput.swift:20-24`<br>And: `keysArePassedAndEmptyKeysAreReported`、`emptyKeyIsWarnedAndTreatedAsKeyless`、`emptyKeyStopsInDebug` | ✅ 一致 |

### MODIFIED: プリフェッチ宣言

実装: `KsCollectionView.swift:241-249` (`prefetchResources(destination:_:)`、戻り値は `[KsResource]` のみ) / `KsCollectionConfiguration.swift:23` / `KsCollectionViewController.swift:229-258`。And: `KsCollectionView.kt:107,230-256`。URL だけの配列を受ける API は両プラットフォームとも残っていない (`[URL]` / `List<String>` のシグネチャを grep で確認)

| Scenario | テスト | 状態 |
|---|---|---|
| もうすぐ表示されるアイテムの画像を取得する | iOS: `test先読み対象の項目がURLへ解決されて到達点付きで開始される`、`testシステムの先読み通知で取得が始まり取り消し通知で止まる`<br>And: `initialWindowPrefetchesVisibleCountAhead`、`scrollingForwardAdvancesWindow` | ✅ 一致 |
| 宣言が無ければ何も起きない | iOS: `test宣言が無ければ受け口へ何も伝わらない`<br>And: `noDeclarationStartsNothing` | ✅ 一致 |
| 複数 URL の宣言 | iOS: `test1項目に複数のURLを宣言すると両方の取得が始まる`<br>And: `multipleUrlsPerItemAreAllStarted` | ✅ 一致 |
| 幅なしの要素は元寸を載せる | iOS: `test幅なしの要素は縮小の指定なしで始まる`、`test幅あり幅なしを混ぜた宣言ではそれぞれの大きさで載る` (幅なし 200x200)、`KsPublicAPITests` `test先読みの要素は幅とキーを省略すると元寸でURLで見分ける`<br>And: `declarationWithoutWidthKeepsTheOriginalSize`、`resourceHasOptionalWidthAndKey` | ✅ 一致 |

### MODIFIED: プリフェッチの取り消し

実装: `KsImagePrefetcher.swift` (アイテム → 宣言、単位 → 参照数 + 開始時の要求。`KsPrefetchUnit.swift`) / `KsImagePrefetchFence.swift`。And: `KsImagePrefetchWindow.kt` (同じ 2 層、`update` の release 判定は宣言で行う) / `KsImagePrefetchWindow.kt:434-435` (`DisposableEffect` で全取り消し)

| Scenario | テスト | 状態 |
|---|---|---|
| スクロール方向の反転で取り消される | iOS: `testシステムの先読み通知で取得が始まり取り消し通知で止まる` (方向は UICollectionView の prefetch / cancel 通知が決める)<br>And: `reversingDirectionCancelsOldWindowAndStartsNewOne`、`reversingDirectionCancelsAndRestarts` | ✅ 一致 |
| 配列の差し替えで消えたアイテム | iOS: `test配列の差し替えで消えた項目の取得は取り消される`<br>And: `replacingItemsCancelsRequestsForRemovedItems`、`replacingItemsCancelsRemovedItem` | ✅ 一致 |
| 共有 URL は最後のアイテムが外れるまで取り消さない | iOS: `test共有URLは最後の項目が外れるまで取り消さない`<br>And: `sharedUrlIsCancelledOnlyAfterLastItemLeaves` | ✅ 一致 |
| 幅が違えば別の取得 (memory) | iOS: `test到達点memoryでは同じURLでも幅が違えば別の取得として数える`<br>And: `differentWidthsAreIndependentForMemory` | ✅ 一致 |
| disk では幅違いも 1 つの取得 | iOS: `test到達点diskでは幅違いも1つの取得にまとめる`<br>And: `differentWidthsShareOneRequestForDisk` | ✅ 一致 |
| 向きが変わっただけでは触らない | iOS: `test列幅が変わっただけでは進行中の取得を取り消さず出し直しもしない`<br>And: `rotationAloneDoesNotTouchRequestsInFlight` | ✅ 一致 |
| 向きが変わった後の取り消し | iOS: `test列幅が変わった後の取り消しは始めたときの要求で行う`<br>And: `cancellationAfterRotationTargetsTheRequestStartedBefore` | ✅ 一致 |
| 画面から消えたら全て取り消す | iOS: `test画面から消えたときに未完了の取得をすべて取り消す`<br>And: `leavingCompositionDisposesAll` | ✅ 一致 |

補足: `fence` が識別子で全幅を止めること (`testソース単位の削除はキーの識別子で全幅の取得を止める` / `fenceStopsEveryWidthOfTheIdentifier`) と、key なしの削除が key 付きの取得を止めないこと (`testキーなしのソースの削除ではキーを付けた取得は止まらない`) も一致。

### MODIFIED: プリフェッチの到達点

実装: `KsNukeImageLoading.swift:19-54` (disk = `.diskCache`、memory = `.memoryCache` + 索引登録) / `KsPrefetchRequest.swift`。And: `KsCoilImageLoading.kt:40-74` (disk = メモリ無効 + `BlackholeDecoder`、memory = 索引登録)

| Scenario | テスト | 状態 |
|---|---|---|
| ディスク到達点の後の表示 | iOS: `testディスク到達点の後の表示ではネットワークが走らない`<br>And: `diskDestinationStoresDataWithoutDecodingOrRefetching` | ✅ 一致 |
| メモリ到達点の後の表示 | iOS: `testメモリ到達点の後の表示では再デコードしない`、`test表示はメモリ到達点の先読み結果を再デコードせずに使う`、`test読み込み中のスロットはメモリにある画像では一度も構成されない`<br>And: `memoryDestinationIsDisplayedWithoutSecondDecode` (ネットワーク 1・デコード 1・表示要求 0)、実機 `graphicsBackedOriginalIsMatchedWithoutLoading` | ⏳ 実機確認待ち (8.2)。単体・契約テストでネットワーク・デコード・要求の回数まで担保済み。実機のローダー通知で数える証跡が 8.2 で残る |
| 到達点が伝わる | iOS: `test到達点memoryの宣言はmemoryとして受け口へ届く`、`testプリフェッチ宣言の到達点を省略するとdiskになる`<br>And: `destinationIsPassedThroughToLoader`、`destinationReachesLoader` | ✅ 一致 |

### MODIFIED: 共有キャッシュ

実装: iOS は `ImagePipeline.shared` を使う (`KsCollectionViewController.swift:244`、`KsImageRequestFactory.swift:51`、`KsImageCache.swift:25,61`)、`KsImagePipeline.swift:37-` (ディスクキャッシュ未設定時のみ差し替え)。And: `SingletonImageLoader` (`KsCoilImageLoading.kt:72`、`KsImageRequestFactory.kt:50`、`KsImageCache.kt:126`)。key なし・幅なしは鍵を既定 (URL) のまま (`KsImageIdentity.swift:50-56`、`KsCoilImageLoading.kt:66-68`)

| Scenario | テスト | 状態 |
|---|---|---|
| ローダー付属ビューとキャッシュを共有する | iOS: `testローダーを直接使う素の要求と同じキャッシュ項目を共有する`<br>And: `requestsMadeDirectlyOnTheSharedLoaderReuseThePrefetchedData` | ✅ 一致 |
| key 付きの項目は付属ビューと共有しない | iOS: `testキー付きの先読みはローダー付属のビューの要求と共有しない` (両方の項目が残る)<br>And: `keyedItemsAreNotSharedWithDirectLoaderRequests` | ✅ 一致 |
| iOS のディスクキャッシュ有効化 | iOS: `KsImagePipelineTests` 4 本 (未設定なら差し替え・設定済みなら不変 ほか) | ✅ 一致 (本 change では差分なし、既存テストが通過) |

### MODIFIED: KsImage の画像ソース

実装: `KsImageSource.swift:14` (`remote(URL, key: String? = nil)`) / `KsImage.swift:65-72,214-257` (便宜形 `KsImage(url, key:)`)。And: `KsImageSource.kt:22-25` / `KsImage.kt:130-147`

| Scenario | テスト | 状態 |
|---|---|---|
| 3 種のソースを表示する | iOS: `KsImageDisplayTests` 3 本、`test3種のソースがそれぞれの経路へ振り分けられる`、`test画像ソースは3種を表せる`<br>And: `threeSourceKindsAreDisplayed`、`imageSourceCoversThreeKinds` | ✅ 一致 |
| 便宜形 | iOS: `test便宜形はリモートのソースと同じ宣言になる` (key 付きの全 init を含む)<br>And: `urlConvenienceFormBehavesLikeRemoteSource`、`convenienceFormPassesTheKey`、`remoteSourceHasOptionalKey` | ✅ 一致 |

### MODIFIED: KsImage の縮小デコード

実装: `KsImageRequestFactory.swift:86-100` (`ThumbnailOptions` の縮小指定) / `KsImage.swift:129-166` (枠が変わると組み立て直して引き当てからやり直す)。And: `KsImageRequestFactory.kt:56-69` (`size` + `Scale` + `Precision.EXACT`) / `KsImage.kt:171-178` (`remember(width, height, …)` で引き当てをやり直す)。旧 CPU 縮小 (`ImageProcessors.Resize` / `downscale` / `KsDownscaleResult` / `isPixelReadable`) は両ソースから消えている (grep で確認)

| Scenario | テスト | 状態 |
|---|---|---|
| 枠より大きい画像 | iOS: `test枠より大きい画像は当てはめ方に応じた寸法へ縮小される`、`test表示枠と当てはめ方から決まる縮小指定が付く`<br>And: `displayRequestDecodesToTheFrameSize`、実機 `displayDoesNotKeepTheOriginalInMemory` | ✅ 一致 |
| サイズ確定前は取得しない | iOS: `testサイズが確定するまで要求を発行しない`<br>And: `noRequestIsBuiltBeforeTheFrameSizeIsSettled` | ✅ 一致 |
| 枠が変わっても範囲内なら再デコードしない | iOS: `test枠が変わっても範囲内なら同じ項目を使い続ける`<br>And: `resizingWithinTheRangeKeepsTheSameItem` | ✅ 一致 |

### MODIFIED: KsImage の読み込み取り消しとメモリ保持

実装: 未完了の読み込みの取り消しはローダー付属の部品に委ねる (`KsImage.swift:150` の `LazyImage`、`KsImage.kt:219` の `rememberAsyncImagePainter`。引き当て成功時は要求自体を出さない)。再表示は引き当て (`KsImageRequestFactory`) と `KsImageRetainedMatch.swift`

| Scenario | テスト | 状態 |
|---|---|---|
| 画面外へ出た読み込みの取り消し | 単体テスト層に観測点が無い (image-loading の verify-002 と同じ扱い)。取り消しを担う部品は本 change でも `LazyImage` / `rememberAsyncImagePainter` のままで、経路の構造は不変 | ✅ 一致 (**検査は実機観測でのみ成立**。本 change での実機観測は 8.x の計測で副次的に得られる) |
| 戻ってきたときの再表示 | iOS: `test一度表示した画像は表示を作り直しても読み込み中を経由しない`<br>And: `loadingSlotIsNeverComposedWhenTheDisplayIsRebuilt` | ✅ 一致 |
| 追い出された項目は再デコードする | iOS: `test追い出された項目はディスクの元データから再デコードする` (再ダウンロード無し・デコード 2)<br>And: `evictedItemIsRedecodedFromDisk` | ✅ 一致 |

### MODIFIED: KsImage の表示状態

実装: `KsImage.swift:143-166` (成功 = 引き当て済み画像 or `state.image`、失敗 = `state.error`、それ以外は読み込み中) / `:107-117` (アセットは同期)。And: `KsImage.kt:180-236` / `KsResourceImageContent`

| Scenario | テスト | 状態 |
|---|---|---|
| 読み込み中から成功へ | iOS: `KsImageDisplayTests` `testリモートのソースは画像が表示される`、`test表示中のKsImageは全消去で取得をやり直す`<br>And: `slotsAreSubstituted`、`itemsLoadedByTheLoaderDirectlyGoThroughLoading` | ✅ 一致 |
| 失敗時の表示 | iOS: `KsImageAccessibilityTests` `test説明を付けた画像は失敗の状態でもその説明を読み上げる` / `test失敗の既定表示は読み上げる名前を作らない`<br>And: `failureSlotIsShownWhenLoadingFails`、`defaultDisplayIsUsedWithoutSlots` | ✅ 一致 |
| 失敗後の再試行 | iOS: `test失敗した表示はビューが作り直されると再び取得を試みる`<br>And: `failedImageIsRetriedWhenTheViewIsRecreated` | ✅ 一致 |
| スロットの差し替え | iOS: `test読み込み中と失敗の表示は片方だけでも差し替えられる`、`test読み込み中のスロットはメモリにある画像では一度も構成されない`<br>And: `slotsAreSubstituted`、`imageSlotsCanBeSubstitutedIndependently` | ✅ 一致 |

### MODIFIED: キャッシュのクリア

実装: `KsImageCache.swift:24-88` (clear: 先読み停止 → ローダー消去 → 索引全消去、remove: 識別子で停止・消去・索引削除・世代前進) / `KsImageInvalidation.swift` / `KsImage.swift:190-196` (reloadToken)。And: `KsImageCache.kt:35-102` (remote はメモリ鍵の本体の完全一致 + ディスク `remove(識別子)`) / `KsImageInvalidation.kt` / `KsImage.kt:163-166`

| Scenario | テスト | 状態 |
|---|---|---|
| 全消去の後の表示 | iOS: `test全消去の後の表示はメモリに当たらず取り直しになる`、`test表示中のKsImageは全消去で取得をやり直す`、`test引き当てた画像を保持していても全消去では取得をやり直す`<br>And: `clearingAllAlsoInvalidatesTheDecodedMemoryImage`、`clearMapsToLoaderCachesAndAdvancesGenerationExceptForMemory` | ✅ 一致 |
| メモリのみ消去 | iOS: `testメモリのみ消去してもディスクの元データから再デコードできる`、`test引き当てて表示中の画像はメモリのみ消去の後に親が組み立て直されても置き換わらない` ほか 2 本<br>And: `clearingMemoryKeepsDiskDataForRedecoding`、`matchedImageIsKeptAcrossRecompositionAfterClearingMemory`、`switchingBackAfterClearingMemoryDoesNotReuseThePreviouslyMatchedImage` | ✅ 一致 |
| ソース単位の削除 | iOS: `testソース単位の削除では対象のソースだけが消える`、`testソース単位の削除は対象のソースの識別子だけを変える`、`test引き当てた画像を保持していてもソース単位の削除では取得をやり直す`<br>And: `removeDeletesOnlyTheTargetSource`、`removeMakesTheDisplayedImageReload`、`removeAffectsOnlyTheTargetSource`、`removeKeepsAnotherSourceWhoseKeySharesThePrefix` | ✅ 一致 |
| key 付きの画像は同じ key で消える | iOS: `testキー付きの画像は同じキーのソースで消えキーなしでは消えない` (メモリ・ディスクとも消え、引き当てられない)。表示中の読み込み直しは reloadToken が識別子の世代で変わる経路 (`testソース単位の削除は対象のソースの識別子だけを変える`)<br>And: `keyedImagesAreRemovedBySameKey` (メモリ・ディスクが消え、識別子の世代が 1 に進む = 表示が作り直される) | ✅ 一致 |
| key なしのソースでは key 付きの画像は消えない | iOS: 同上の前半、`testキーなしのソースの削除ではキーを付けた取得は止まらない`<br>And: `keyedImagesAreRemovedBySameKey` の前半、`keyEqualToAnotherUrlDoesNotCollide` | ✅ 一致 |
| 削除後は別サイズでも旧項目に当たらない (iOS) | iOS: `test削除後はどの表示サイズの要求も削除前の項目に当たらない` | ✅ 一致 |

### MODIFIED: Sample のデモ画面「画像グリッド」

実装: `samples/ios/KsCollectionViewSamples/ImagePrefetchChoice.swift` (4 択 なし / ディスクまで / メモリまで / メモリまで (列幅)、`memoryColumn` は `.column`) / `ImageGridFixture.swift:49` (`KsResource(…, width:)`) / `ImageGridDemoView.swift` (メニュー形式・全消去 `:51`)。And: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/ImagePrefetchChoice.kt:24-33` / `ImageGridFixture.kt:45-48` / `ImageGridDemoScreen.kt` (全消去 `:84`) / `SampleMenuPicker.kt`

| Scenario | テスト | 状態 |
|---|---|---|
| 切り替えの反映 | And: `SampleDemoScreenTest` `画像グリッド画面のプリフェッチの初期選択はディスクまでである` (選び直せること)、`ImageGridMeasurementFixtureTest` (選択 → 宣言の写像)。iOS は Sample UI テスト `ImageLoadingSlotUITests` が画像グリッドを起動引数つきで開いて動かす (選択の切り替え自体の自動テストは無い)。ローダーのログでの確認は手動 | ⚠️ deviation 記録済み (選択の見せ方をメニュー形式に: deviation.md 4 行目。文言・順序は spec どおりで、Android のテストが 4 択の文言を固定) |
| 列幅の先読みに切り替える | And: `ImageGridMeasurementFixtureTest` (「メモリまで (列幅)」は列幅の要素を memory で宣言、4 択の文言と順序)、`SampleDemoScreenTest` `画像グリッド画面は起動時の指定の選択で始まる`。iOS は `ImagePrefetchChoice.swift` の写像 (自動テストなし)。「先読み済みは読み込み中を経由せず表示」はライブラリ側の「先読みの縮小済み項目を使う」のテストで担保 | ⏳ 実機確認待ち (6.6 / 8.1)。Sample 上で列幅の先読みから読み込み中を経由しないことの確認は実機の手動操作で残る |
| 全消去 | iOS: `ImageGridDemoView.swift:51` (`KsImageCache.clear(.all)`) + ライブラリの `test表示中のKsImageは全消去で取得をやり直す`<br>And: `ImageGridDemoScreen.kt:84` + `clearingAllAlsoInvalidatesTheDecodedMemoryImage` | ✅ 一致 (Sample 上の実操作は既存の検証から変更なし) |

## 実機確認待ちの Scenario (⏳)

| Scenario | 残る確認 | 自動テストで担保済みの範囲 |
|---|---|---|
| 原寸の項目を実機でも使う (iOS 分) | tasks 6.6: iPhone 実機で到達点 memory の原寸引き当てを踏む | iOS 単体: 原寸 800x600 の引き当て、画素を持たない画像でも寸法だけで判定。Android は実機テスト (Pixel 4a) で確認済み |
| メモリ到達点の後の表示 (実機の取得・デコード回数) | tasks 8.2: 実機のローダー通知で先読み後の初回表示に取得・デコードが走らないことを数える | 契約テストでネットワーク 1・デコード 1・表示要求 0 を両プラットフォームで固定 |
| 列幅の先読みに切り替える (Sample) | tasks 6.6 / 8.1: Sample「メモリまで (列幅)」で先読み済みが読み込み中を経由しないこと | Sample の選択 → 宣言の写像 (Android テスト)、ライブラリの引き当て・読み込み中スロット 0 回の契約テスト |
| (付随) プリフェッチの表示幅「元寸の画像はメモリに載せない」の実機でのメモリ減少 | tasks 8.3 | 契約テストで元寸の鍵に載らないことを固定 (`test幅つきの先読みは…元寸は載らない` / `columnWidthPrefetchIsMatchedByTheDisplay`) |
| (付随) 許容範囲 0.5 / 4 の実機の見た目 | tasks 8.4 (値を変えたら定数と証跡に理由) | 定数は各 1 か所 (`KsImageMatching.swift:12,15`、`KsImageMatching.kt:18,21`) |

表の後ろ 2 行は Scenario ではなく Requirement 本文と design の確認事項だが、完了条件として同じ 8.x で閉じるため並べた。

## 追加検査

- [x] **tasks.md**: 1.1〜7.1 (6.6 を除く) はチェック済みで、すべて対応表の実装・テストが存在する (虚偽チェックなし)。6.6・8.1〜8.5 は未チェックのまま (上の ⏳ に対応。虚偽ではない)。6.4 の「キャッシュに無い候補の破棄」は deviation.md 10 行目の合意 (刈り込みをやめる) で意味が変わった上でのチェック
- [x] **逆流検査**: `git diff HEAD -- kasane/` の変更は `tasks.md` のみで、差分はチェックボックスの行だけ (31 行の `[ ]` → `[x]` 相当、本文の変更なし)。proposal.md / design.md / specs/ は HEAD (3e4a918 = 提案の改訂コミット、実装前) から変更なし
- [x] **未記録乖離**: なし。deviation.md の 5 件の合意 (識別子の形・メニュー形式・Android の表示鍵の当てはめ方・索引の刈り込みをやめる・16384 px の上限) と 4 件の付随修正は、いずれも diff 上の該当箇所と一致した
- [x] **付随修正**: diff の Sample 変更のうち Scenario に直接対応しないものは次のとおりで、いずれも記録済みまたは tasks の範囲
  - `[付随修正]` として記録済み: Android の `ks_prefetch` (`SampleRoutes.kt` / `MainActivity.kt` / `SampleNavHost.kt`)、iOS の `--prefetch memory-column` (`ImagePrefetchChoice.swift`)、doc コメントの ADR 参照の整理 (`DemoData.kt` / `LargeDataDemoScreen.kt` / `SampleScreen.kt` / `SampleTheme.kt` ほか)、`ImageGridDemoView.swift` の doc コメントの文のつながり
  - tasks 7.1 / 8.2 の範囲 (計測の足場の追随): 読み込みの分類に「幅つきの先読み」を足す変更 (`ImageLoadingObserver.kt` / `ImageRequestKindTest.kt` / `ImageLoadingObservation.swift`)、選択の名前を到達点から「形」へ広げた追随 (`MeasurementDestinations.kt` / `MemoryRoundTripScreen.kt` / `MeasurementTarget.kt` / `LargeDataScrollBenchmark.kt` / `PerformanceFixture.swift` / `PerformanceVerificationView.swift` / `SampleLaunchView.swift` / `ImageBehaviorVerificationView.swift` / `ImageGridMetrics.*`)。いずれも公開 API の破壊的変更 (`[KsResource]`) と 4 択化への追随で、spec の挙動を変えない
- [x] **UI 変更**: 本 change は `ui/` を持たない。Sample の選択の見せ方の変更は deviation.md 4 行目で合意済み
- [x] **テスト成功**: 上の「テスト実行」のとおり、再実行した 4 系統はすべて失敗 0。実機テストはホスト報告の値

## まとめ

| 区分 | 件数 |
|---|---|
| ✅ 一致 | 54 |
| ⚠️ deviation 記録済み | 4 (小さすぎる項目は使わない / 大きすぎる項目は使わない / 削除の世代は別の key と衝突しない / 切り替えの反映)。このほか 16384 px の上限と索引の刈り込みの合意が各表の補足に該当 |
| ⏳ 実機確認待ち | 3 (原寸の項目を実機でも使う / メモリ到達点の後の表示 / 列幅の先読みに切り替える) |
| ❌ 欠落・乖離 | 0 |
| 合計 | 61 Scenario (13 Requirement) |
