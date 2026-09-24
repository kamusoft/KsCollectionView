# Verify 002: prefetch-display-size

- 対象: コミット 3e4a918 (HEAD) に対する作業ツリーの未コミット差分 (`git diff HEAD` と未追跡ファイル)。ios/Sources・ios/Tests、android/kscollectionview/src (test・androidTest 含む)、samples/ios、samples/android
- 前回からの差分の主題: verify-001 (VALID、実機確認待ち 3 件) の後に実機検証で見つかった Scenario「メモリ到達点の後の表示」の違反の修正 (deviation.md 12 行目、design Decision 2 の実現時点) と、実機の再計測 (tasks 6.6 / 8.2 / 8.3 / 8.5) の証跡 (`evidence/`)
- 突き合わせ元: `specs/image-loading/spec.md` (ADDED 3・MODIFIED 10 の計 13 Requirement / 61 Scenario)、`tasks.md`、`deviation.md`、`design.md`、`proposal.md`、`evidence/` 11 本、`verify-001.md`
- 検証日: 2026-09-23
- 検証者の立場: 一致検証のみ (品質評価は review の領分)。同時進行の review-008.md は読んでいない

## 判定: VALID

全 61 Scenario が「✅ 一致」(56) または「⚠️ deviation 記録済み」(5) で、❌ (未記録の欠落・乖離) は 0 件。虚偽のチェックと足場の逆流は無い。再実行したテストは、本 change の範囲では全件成功した。Sample UI テストに 1 件の失敗があるが、本 change の差分が触れていないテストと対象コードのもので、Scenario には対応しない (下の「テスト実行」)。

**前回「実機確認待ち」だった 3 Scenario は、今回の証跡ですべて閉じた。** 詳細は下の「前回の実機確認待ちの扱い」。

**8.1 待ちの Scenario は無い。** tasks 8.1 (iOS 走行 5 = 「メモリまで (列幅)」の採り直し待ち、未チェック) は滑らかさの体感ゲートで、tasks の完了条件にあたる。spec の Scenario ではない。「列幅の先読みに切り替える」の THEN (読み込み中を経由しない表示) は tasks 8.2 の数えた証跡で閉じており、8.1 には依存しない。ただし、ksn-distill の前に 8.1 の完了を確認する必要がある。

凡例: ✅ 一致 / ⚠️ deviation 記録済み / ❌ 欠落・乖離

## テスト実行 (検証者が再実行)

| 対象 | コマンド | 結果 |
|---|---|---|
| iOS パッケージ | `ios/` で `xcodebuild test -scheme KsCollectionView` (iPhone 17 / iOS 26.5 Simulator、DerivedData はスクラッチ) | **271 tests / 0 failures** (verify-001 から +3: 画面に出る時点の引き当ての契約テスト) |
| Android ライブラリ | `android/` で `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` | **219 tests / 0 failures / 0 skip** (13 クラス。verify-001 から +6: `KsImageTest` の +4 (44 → 48)、新規の `KsImageShownFrameTest` 2) |
| Android Sample | `samples/android/` で `./gradlew :app:testDebugUnitTest --rerun-tasks` | **44 tests / 0 failures / 0 skip** (8 クラス。+7: 新規の `ImageLoadingSlotShownTest` 7) |
| iOS Sample (UI テスト、通常スキーム) | `samples/ios/` で `xcodebuild test -scheme KsCollectionViewSamples` (iPhone 17 Pro Max / iOS 26.5 Simulator) | **11 tests / 1 failure** (新規の `ImageLoadingSlotShownClippingUITests` 2・ImageLoadingSlot 2・InteractiveControl 3 は成功。LargeDataCount 4 のうち `test件数に数値でない値を指定すると起動しない` が失敗) |
| Android 実機 `KsImageDeviceDecodeTest` | 実機を使わない制約のため再実行していない | ホスト報告: Pixel 4a で 4 / 0 / skip 0 |

**Sample UI テストの失敗について:** 失敗の中身は `XCTExpectFailure` の不一致 (「受け取れない件数では起動が止まる」を期待したが、失敗が記録されなかった)。つまり、起動の停止を XCTest が期待した形で記録しなかった。次の 3 点から、本 change の結果ではないと判断した。

- 本 change の差分は、このテスト (`samples/ios/KsCollectionViewSamplesUITests/LargeDataCountUITests.swift`) にも、検査対象の件数の処理 (`samples/ios/KsCollectionViewSamples/LargeDataCount.swift`、`KsCollectionViewSamplesApp.swift`) にも触れていない (`git diff HEAD --stat` で確認)
- ホストは 2 件の失敗を報告し、同じ失敗が HEAD でも出ることを確認済み。今回の再実行では 1 件だけが失敗した (`件数に0を指定すると起動しない` は今回は成功)。環境によって結果が変わる形である
- 対応する Scenario が無い

HEAD での再現は、git 操作禁止の制約のため検証者自身では行っていない (ホストの報告による)。

## 対応表

実装・テストのパスは、iOS は `ios/Sources/KsCollectionView/`・`ios/Tests/KsCollectionViewTests/`、Android は `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/`・`android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/` (androidTest は `.../src/androidTest/kotlin/jp/kamusoft/kscollectionview/`) の下を指す。verify-001 の対応表で挙げたテストは、すべて現存して成功することを確かめた (名前で照合し、上の再実行で通過)。以下では、前回から判定または根拠が変わった行を太字で示す。

### ADDED: プリフェッチの表示幅

実装: verify-001 と同じ (`KsResource` / `KsWidth` / `KsPrefetchDeclaration` / `KsPrefetchRequest` / `KsImagePrefetcher` / `KsCollectionViewController` + `KsLayoutMetrics` / `KsPrefetchMetrics`。And: `KsResource.kt` / `KsWidth.kt` / `KsPrefetchDeclaration.kt` / `KsCoilImageLoading.kt` / `KsImagePrefetchWindow.kt` / `KsCollectionView.kt`)。今回の修正はこの経路に触れていない。

| Scenario | テスト・証跡 | 状態 |
|---|---|---|
| 列幅で縮小して載せる | verify-001 のテスト (iOS `test幅つきの先読みは幅の正方形を覆う大きさで載り元寸は載らない` ほか、And `widthDeclarationCoversTheSquare`・`columnWidthPrefetchIsMatchedByTheDisplay`・実機 `widthPrefetchStoresTheDeclaredWidth`)。実機の証跡: `evidence/memory-steady-ios.md` (列幅は 255 × 255 のみで元寸 0)・`evidence/memory-steady-android.md` (330 × 330 のみで元寸 0) | ✅ 一致 |
| 固定値で縮小して載せる | 同上 (`test固定値の要素は表示倍率込みのピクセルで始まる` / `fixedWidthIsScaledByDensity`) | ✅ 一致 |
| 元寸が小さければ拡大しない | `test元寸が宣言した幅より小さければ拡大せずに載る` / `smallerOriginalIsNotUpscaled` | ✅ 一致 |
| 幅あり・幅なしの混在 | `test幅あり幅なしを混ぜた宣言ではそれぞれの大きさで載る` / `mixedDeclarationsStoreTheirOwnSizes` | ✅ 一致 |
| 向きが変わると新しい列幅で先読みする | `test列幅が変わっただけでは進行中の取得を取り消さず出し直しもしない` / `orientationChangeUsesTheNewColumnWidthForNewPrefetches` | ✅ 一致 |
| 到達点 disk では幅を使わない | `test到達点diskでは幅を宣言しても元データの保存までで止まる` / `diskDestinationIgnoresWidth` | ✅ 一致 |
| 無効な固定値は幅なし扱い | `test無効な固定値は警告して幅なしとして扱う` / `invalidFixedWidthsAreReportedAndTreatedAsOriginal`・`reportingCanStopTheUpdate` | ✅ 一致 |
| 列幅が解けない間は始めない | `test列幅が解けない間は列幅の先読みを始めない` / `columnWidthDeclarationsWaitUntilTheWidthResolves` | ✅ 一致 |

補足: 16384 px の上限は deviation.md 11 行目で合意済み (verify-001 と同じ)。

### ADDED: KsImage のメモリ項目の引き当て

実装: verify-001 の構成 (`KsImageMatching` / `KsImageRequestFactory` / `KsImageMemoryIndex` / `KsImageRetainedMatch`) に、**画面に出る時点の引き当て** を加えた。iOS は `KsImage.swift:130-176` (組み立ての時点で外れたら `KsImageDeferredLoad` に渡す) と `KsImageDeferredLoad.swift` (画面に出るまでは読み込み中の表示だけを置いて要求を出さない。`onAppear` で照会し直し、当たればローダーの表示を組み立てない)。And は `KsImage.kt:183-247` (`lookup` は照会だけ。画面に出ておらず、先読みが未完了 (`prefetchPending`) なら `KsUnshownImageContent` で待ち、画面に置かれた最初の描画で照会し直す) と `KsImageRequestFactory.kt:116-118` (`prefetchPending` = その識別子の先読みの鍵が索引にあり、メモリに無い)。deviation.md 12 行目の記録どおり。

| Scenario | テスト・証跡 | 状態 |
|---|---|---|
| 先読みの縮小済み項目を使う | verify-001 のテスト (`test先読みの縮小済み項目で表示し読み込み中も表示の要求も経由しない` / `prefetchedDownscaledItemIsUsed`・`loadingSlotIsNeverComposedWhenThePrefetchedImageIsInMemory`)。**加えて、先に組み立てたセルに対する画面に出る時点の引き当て**: iOS `KsImageCacheContractTests` `test前もって組み立てた後に先読みが完了すれば画面に出る時点で引き当てて読み込み中を経由しない` (`:698`。実物のコレクションビューのセルを `willDisplay` で組み立てた後に項目を出現させる)、And `KsImageTest` `precomposedDisplayMatchesTheItemThatArrivedBeforeItWasShown` (`:794`)、`KsImageShownFrameTest` `loadingSlotIsNotDrawnWhenTheShownLookupMatches` (画面に出る最初の描画で読み込み中を描かない) | ✅ 一致 |
| **原寸の項目を実機でも使う** | iOS 単体: `test原寸の項目も許容範囲の内側なら枠にそのまま使う`、`test画素の置き場に関わらず実物の寸法だけで判定する`。**iOS 実機: `evidence/device-image-match-ios.md` の「修正後」(iPhone 11 基準機、Release、到達点「メモリまで」(幅なし)。先読みの完了後に画面に出た 138 件のすべてが元寸 400 × 400 の項目で表示された。枠は約 255 px で拡大率 0.64 (許容範囲の内側)。表示の要求 0・画面に描かれた読み込み中 0)**。同じ結果が `evidence/loader-counts-ios.md` (ゆっくり送り 138 件、速い送り 160 件) にもある。And: `originalItemWithinTheUpperBoundIsUsed`、実機 `graphicsBackedOriginalIsMatchedWithoutLoading` (ホスト報告 Pass)、`evidence/loader-counts-android.md` (元寸のハードウェアビットマップ 400 × 400 を 330 px の枠に引き当て、表示要求 0) | ✅ 一致 (**前回 ⏳ → 閉じた**。tasks 6.6 はチェック済み) |
| 小さすぎる項目は使わない | `test小さすぎる項目は使わず枠の実サイズで縮小する要求を出す` / `tooSmallItemIsNotUsed`・実機 `itemOutsideTheRangeFallsBackToDownscaledDecode` | ⚠️ deviation 記録済み (Android の表示鍵の形: deviation.md 7 行目。Scenario の挙動は一致) |
| 大きすぎる項目は使わない | `test大きすぎる項目は使わない` / `tooLargeItemIsNotUsed`・`tooLargePrefetchedItemIsNotReturnedByTheDisplayRequestForFit` | ⚠️ deviation 記録済み (同上) |
| 縦長の枠に fill するときは高さで判定する | `test縦長の枠にfillするときは高さで判定する` / `fillIntoATallFrameIsJudgedByHeight` | ✅ 一致 |
| 消した項目は引き当てない | `test消した項目は引き当てない` / `removedItemIsNotMatched`・`KsImageMemoryIndexTest` の 3 本 | ✅ 一致 |

補足 (Scenario 外の本文条項): 画面に出る時点で引き当てた後に枠が変わる場合も、本文の「枠の実サイズが確定したとき … 引き当て」に従う。iOS `test画面に出る時点で引き当てた後に枠が変わっても範囲内なら再デコードしない` (`:774`) / `test画面に出る時点で引き当てた後に枠が範囲外へ広がると新しい枠で縮小デコードする` (`:751`)、And は `remember(prepared)` で状態を捨てる実装 (`KsImage.kt:202`)。索引の刈り込みをやめた合意 (deviation.md 10 行目) は verify-001 と同じ。

### ADDED: 画像の任意キー

実装・テストは verify-001 から変更なし (`KsImageIdentity` ほか)。今回の修正は識別子の求め方に触れていない。And の `prefetchPending` も識別子で索引を引く (`KsImageRequestFactory.kt:116`)。

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

実装・テストは verify-001 から変更なし。

| Scenario | テスト | 状態 |
|---|---|---|
| もうすぐ表示されるアイテムの画像を取得する | `test先読み対象の項目がURLへ解決されて到達点付きで開始される` / `scrollingForwardAdvancesWindow` | ✅ 一致 |
| 宣言が無ければ何も起きない | `test宣言が無ければ受け口へ何も伝わらない` / `noDeclarationStartsNothing` | ✅ 一致 |
| 複数 URL の宣言 | `test1項目に複数のURLを宣言すると両方の取得が始まる` / `multipleUrlsPerItemAreAllStarted` | ✅ 一致 |
| 幅なしの要素は元寸を載せる | `test幅あり幅なしを混ぜた宣言ではそれぞれの大きさで載る` / `declarationWithoutWidthKeepsTheOriginalSize`。実機: `evidence/memory-steady-*.md` (幅なしの走行で元寸 400 × 400 が載る) | ✅ 一致 |

### MODIFIED: プリフェッチの取り消し

実装・テストは verify-001 から変更なし。

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

実装: `KsNukeImageLoading.swift` / `KsCoilImageLoading.kt` (verify-001 と同じ)。表示側の画面に出る時点の引き当ては、上の「KsImage のメモリ項目の引き当て」の実装欄を参照。

| Scenario | テスト・証跡 | 状態 |
|---|---|---|
| ディスク到達点の後の表示 | `testディスク到達点の後の表示ではネットワークが走らない` / `diskDestinationStoresDataWithoutDecodingOrRefetching`。実機の対照: `evidence/loader-counts-*.md` の「ディスクまで」(表示の要求はディスクから取得し、ネットワークに行かない) | ✅ 一致 |
| **メモリ到達点の後の表示** | 単体・契約: verify-001 のテスト (`testメモリ到達点の後の表示では再デコードしない` / `memoryDestinationIsDisplayedWithoutSecondDecode`) に加えて、**先に組み立てたセルが画面に出る時点で引き当てるテスト**: iOS `test前もって組み立てた後に先読みが完了すれば画面に出る時点で引き当てて読み込み中を経由しない` (読み込み中の表示は画面に出る前の組み立ての分しか組み立てない。デコードは 2 回 = 先読みの 1 回と、合図に使う別の未取得の 1 枚の分で、対象の画像のデコードのやり直しは無い。対象の URL への通信は 1 回)。And は `precomposedDisplayMatchesTheItemThatArrivedBeforeItWasShown`・`precomposedDisplayRequestsOnlyWhenShownWithoutAnItem`、`KsImageShownFrameTest` 2 本 (当たれば最初の描画で読み込み中を描かない、外れれば最初の描画で読み込み中を描く)。**実機 (修正後のビルド)**: iOS `evidence/loader-counts-ios.md` (iPhone 11。ゆっくり送りでは、画面に出た時点で先読みが完了していた 138 件 (幅なし) / 138 件 (列幅)、速い送り 500 ms では 160 件 / 165 件のすべてで、表示の要求 0 (= 取得・デコード 0)・画面に描かれた読み込み中 0。修正前の形は 0 件)、`evidence/device-image-match-ios.md` の「修正後」(修正前 136 件の違反 → 0 件)。And `evidence/loader-counts-android.md` の「修正後」(Pixel 4a。ゆっくり送り 51 件 / 51 件、フリング 4 条件 × 2 走行のすべてで、表示要求・取得・デコード・`loading-shown` が 0。修正前のフリングで出ていた 6〜20 件の違反 → 0 件)。対照の到達点 disk では数え方が空振りしていないことも確かめている | ✅ 一致 (**前回 ⏳ → 閉じた**。前回の後に見つかった違反は、deviation.md 12 行目の合意どおりに修正されており、修正後の実機計測で違反は 0 件だった。tasks 8.2 はチェック済み) |
| 到達点が伝わる | `test到達点memoryの宣言はmemoryとして受け口へ届く` / `destinationIsPassedThroughToLoader` | ✅ 一致 |

「メモリ到達点の後の表示」の GIVEN の読み方: 証跡は「画面に出た時点で先読みが完了していた」項目を対象にし、画面に出た時点で先読みが未完了だった項目 (iOS の最初の送りの 9 件、速い送りの 132〜137 件、Android の二重取得の残り) は GIVEN の外として分けている。deviation.md 12 行目の合意 (まだ引き当てていない `KsImage` は画面に出る時点でもう一度試す) は、この読み方を前提にしている。

### MODIFIED: 共有キャッシュ

実装・テストは verify-001 から変更なし。

| Scenario | テスト | 状態 |
|---|---|---|
| ローダー付属ビューとキャッシュを共有する | `testローダーを直接使う素の要求と同じキャッシュ項目を共有する` / `requestsMadeDirectlyOnTheSharedLoaderReuseThePrefetchedData` | ✅ 一致 |
| key 付きの項目は付属ビューと共有しない | `testキー付きの先読みはローダー付属のビューの要求と共有しない` / `keyedItemsAreNotSharedWithDirectLoaderRequests` | ✅ 一致 |
| iOS のディスクキャッシュ有効化 | `KsImagePipelineTests` 4 本 | ✅ 一致 |

### MODIFIED: KsImage の画像ソース

| Scenario | テスト | 状態 |
|---|---|---|
| 3 種のソースを表示する | `KsImageDisplayTests` 3 本・`test3種のソースがそれぞれの経路へ振り分けられる` / `threeSourceKindsAreDisplayed` | ✅ 一致 |
| 便宜形 | `test便宜形はリモートのソースと同じ宣言になる` / `urlConvenienceFormBehavesLikeRemoteSource`・`convenienceFormPassesTheKey` | ✅ 一致 |

### MODIFIED: KsImage の縮小デコード

実装: 縮小指定は verify-001 と同じ (`KsImageRequestFactory`)。表示の要求を出す時点は、今回の修正で次のように変わった。iOS は、組み立ての時点で外れたら画面に出る時点で `LazyImage` を組み立てる (`KsImageDeferredLoad.swift`)。deviation.md によると、`LazyImage` はもともと画面に出る時点で要求を始めるため、iOS の要求の開始時点は変わらない。And は、先読みが未完了のときに限り、要求を画面に出る時点まで遅らせる (`KsImage.kt:228`)。

| Scenario | テスト | 状態 |
|---|---|---|
| 枠より大きい画像 | `test枠より大きい画像は当てはめ方に応じた寸法へ縮小される` / `displayRequestDecodesToTheFrameSize`・実機 `displayDoesNotKeepTheOriginalInMemory` | ✅ 一致 |
| **サイズ確定前は取得しない** | `testサイズが確定するまで要求を発行しない` / `noRequestIsBuiltBeforeTheFrameSizeIsSettled` (サイズ確定前は要求しない)。サイズ確定後の開始時点: 先読みが未完了でない通常の場合は、サイズ確定後の組み立てで要求する (`precomposedDisplayWithoutPrefetchRequestsBeforeItIsShown`、`precomposedDisplayWithCompletedButUnusablePrefetchRequestsBeforeItIsShown`)。Android で先読みが未完了の場合は、画面に出る時点で要求する (`precomposedDisplayRequestsOnlyWhenShownWithoutAnItem`) | ⚠️ deviation 記録済み (**今回の変更**。THEN の「サイズが確定した時点で発行される」は、Android でその識別子の先読みが未完了のときに限り、「画面に出る時点で発行される」になる。deviation.md 12 行目の「利用者から見える差」として記録済み。前半の「サイズ確定前は発行しない」は一致) |
| 枠が変わっても範囲内なら再デコードしない | `test枠が変わっても範囲内なら同じ項目を使い続ける` / `resizingWithinTheRangeKeepsTheSameItem`。画面に出る時点で引き当てた場合: `test画面に出る時点で引き当てた後に枠が変わっても範囲内なら再デコードしない` | ✅ 一致 |

### MODIFIED: KsImage の読み込み取り消しとメモリ保持

| Scenario | テスト・証跡 | 状態 |
|---|---|---|
| **画面外へ出た読み込みの取り消し** | 単体テスト層に観測点が無い (verify-001 と同じ)。**実機観測**: `evidence/loader-counts-ios.md` (待ちなしの送りで、表示の要求 297 件のうち 245 件 / 255 件が、セルが画面から外れた時点で取り消された)、`evidence/disk-wait-ios.md` (連続送り 1 回の表示の要求 228〜240 件のうち 210〜222 件が取り消された)、`evidence/disk-wait-android.md` (フリング中に表示要求 1,080〜1,311 件のうち 948〜1,235 件が取り消された) | ✅ 一致 (verify-001 の「実機観測でのみ成立」の注記は、今回の証跡で観測できた) |
| 戻ってきたときの再表示 | `test一度表示した画像は表示を作り直しても読み込み中を経由しない` / `loadingSlotIsNeverComposedWhenTheDisplayIsRebuilt`。実機: `evidence/device-image-match-ios.md` の戻し (156 件、表示の要求 0・描かれた読み込み中 0) | ✅ 一致 |
| 追い出された項目は再デコードする | `test追い出された項目はディスクの元データから再デコードする` / `evictedItemIsRedecodedFromDisk` | ✅ 一致 |

### MODIFIED: KsImage の表示状態

実装: iOS は `KsImage.swift:130-176` (成功 = 組み立て時または画面に出る時点で引き当てた画像、または `state.image`。失敗 = `state.error`。それ以外 (画面に出る前の待ちを含む) は読み込み中)。And は `KsImage.kt:205-247`。

| Scenario | テスト | 状態 |
|---|---|---|
| 読み込み中から成功へ | `testリモートのソースは画像が表示される`・`test表示中のKsImageは全消去で取得をやり直す` / `itemsLoadedByTheLoaderDirectlyGoThroughLoading`。画面に出る時点で外れた場合に読み込み中を描くこと: `KsImageShownFrameTest` `loadingSlotIsDrawnInTheFirstFrameWhenTheShownLookupMisses` | ✅ 一致 |
| 失敗時の表示 | `KsImageAccessibilityTests` の 2 本 / `failureSlotIsShownWhenLoadingFails` | ✅ 一致 |
| 失敗後の再試行 | `test失敗した表示はビューが作り直されると再び取得を試みる` / `failedImageIsRetriedWhenTheViewIsRecreated` | ✅ 一致 |
| スロットの差し替え | `test読み込み中と失敗の表示は片方だけでも差し替えられる` / `imageSlotsCanBeSubstitutedIndependently` | ✅ 一致 |

### MODIFIED: キャッシュのクリア

実装: verify-001 と同じ。画面に出る時点の引き当ての状態は、世代 (`reloadToken`) を含む条件ごとに捨てられる。iOS は `.id(condition)` と `.id(reloadToken)`、And は `key(source, reloadToken)`。したがって、消去の後に古い引き当てが残る経路は無い。

| Scenario | テスト | 状態 |
|---|---|---|
| 全消去の後の表示 | `test全消去の後の表示はメモリに当たらず取り直しになる`・`test引き当てた画像を保持していても全消去では取得をやり直す` / `clearingAllAlsoInvalidatesTheDecodedMemoryImage` | ✅ 一致 |
| メモリのみ消去 | `testメモリのみ消去してもディスクの元データから再デコードできる` / `clearingMemoryKeepsDiskDataForRedecoding`。実機: `evidence/device-image-match-ios.md` (メモリのみの消去の後も、表示し続けたセル 9 件・再び現れたセル 6 件とも読み込み中へ戻らない) | ✅ 一致 |
| ソース単位の削除 | `testソース単位の削除では対象のソースだけが消える` / `removeDeletesOnlyTheTargetSource`・`removeMakesTheDisplayedImageReload` | ✅ 一致 |
| key 付きの画像は同じ key で消える | `testキー付きの画像は同じキーのソースで消えキーなしでは消えない` / `keyedImagesAreRemovedBySameKey` | ✅ 一致 |
| key なしのソースでは key 付きの画像は消えない | 同上の前半 / `keyedImagesAreRemovedBySameKey` の前半 | ✅ 一致 |
| 削除後は別サイズでも旧項目に当たらない (iOS) | `test削除後はどの表示サイズの要求も削除前の項目に当たらない` | ✅ 一致 |

### MODIFIED: Sample のデモ画面「画像グリッド」

実装: verify-001 と同じ (`ImagePrefetchChoice` / `ImageGridFixture` / `ImageGridDemoView` / `ImageGridDemoScreen` / `SampleMenuPicker.kt`)。今回、`ImageGridCell` に計測の足場のための差し込み (iOS は組み立ての時刻の記録、Android は読み込み中の表示の引数化) が加わった。どちらも計数を要求した実行でだけ働き、デモ画面の挙動は変わらない。

| Scenario | テスト・証跡 | 状態 |
|---|---|---|
| 切り替えの反映 | `SampleDemoScreenTest`・`ImageGridMeasurementFixtureTest` (Android)。iOS は `ImageLoadingSlotUITests` | ⚠️ deviation 記録済み (メニュー形式: deviation.md 4 行目) |
| **列幅の先読みに切り替える** | 選択 → 宣言の写像: `ImageGridMeasurementFixtureTest` (「メモリまで (列幅)」は列幅の要素を memory で宣言)、`SampleDemoScreenTest` `画像グリッド画面は起動時の指定の選択で始まる`、iOS `ImagePrefetchChoice.swift` (`memoryColumn` → `.column`)。**実機 (修正後)**: 「以後のスクロールで列幅の先読みが開始される」は、iOS `evidence/device-image-match-ios.md` / `evidence/loader-counts-ios.md` (列幅の先読み 162 件が開始・成功し、載った項目は 255 × 255 で元寸は無し) と、And `evidence/loader-counts-android.md` (330 × 330) で確認。「先読み済みのアイテムは読み込み中を経由せず表示される」は、同じ証跡の列幅の走行で、iOS 138 件 (ゆっくり)・165 件 (500 ms)、And 51 件 (ゆっくり)・フリング 2 条件 × 2 走行で、画面に描かれた読み込み中 0・表示の要求 0 | ✅ 一致 (**前回 ⏳ → 閉じた**。下の注記を参照) |
| 全消去 | `ImageGridDemoView.swift` (`KsImageCache.clear(.all)`) + `test表示中のKsImageは全消去で取得をやり直す` / `ImageGridDemoScreen.kt` + `clearingAllAlsoInvalidatesTheDecodedMemoryImage` | ✅ 一致 |

「列幅の先読みに切り替える」の注記: 実機の証跡は、画面上の「なし → メモリまで (列幅)」の切り替えを操作したものではない。起動時に「メモリまで (列幅)」を指定し (iOS `--prefetch memory-column`、Android の観測用画面の到達点の経路)、デモ画面と同じ宣言元 `ImageGridFixture` を使った。起動時の指定は、deviation.md 5・6 行目の付随修正で足されたものである。切り替えた後に効くのは「以後のスクロール」で新しく対象になったアイテムの宣言で、spec の Requirement「プリフェッチの取り消し」には「差し替えた場合は以後の新しい取得にだけ反映される」とある。選択 → 宣言の写像は Android のテストで固定されている。iOS の写像は `ImagePrefetchChoice.swift` の 1 か所で、自動テストは無い (verify-001 と同じ)。これらから、THEN の 2 点は証跡で閉じていると判断した。画面上の切り替え操作そのものの実機観測が要るかは、呼び出し元の判断に委ねる。

## 前回の実機確認待ちの扱い

| verify-001 の ⏳ | 今回の判定 | 閉じた根拠 | 8.1 への依存 |
|---|---|---|---|
| 原寸の項目を実機でも使う (iOS 分) | ✅ 閉じた | `evidence/device-image-match-ios.md` の「修正後」(iPhone 11、元寸 400 × 400 で 138 件、読み込み中 0・表示の要求 0)。tasks 6.6 はチェック済み | なし |
| メモリ到達点の後の表示 | ✅ 閉じた | 修正後の実機のローダー通知の数え上げ (`evidence/loader-counts-ios.md`、`evidence/loader-counts-android.md` の「修正後」)。修正前の違反 (iOS 136 件、Android フリング時 6〜20 件) → 0 件。tasks 8.2 はチェック済み | なし |
| 列幅の先読みに切り替える | ✅ 閉じた (注記あり) | 上の注記のとおり。列幅の走行の実機の数え上げで、読み込み中 0・表示の要求 0 | なし (8.1 の iOS 走行 5 の採り直しは滑らかさの体感ゲートで、この Scenario の THEN ではない) |
| (付随) 「元寸の画像はメモリに載せない」の実機でのメモリ減少 | 確認済み | `evidence/memory-steady-ios.md` (60 件で −54%、600 件で −59%、元寸 0)、`evidence/memory-steady-android.md` (60 件で −25%、元寸 0)。tasks 8.3 はチェック済み | なし |
| (付随) 許容範囲 0.5 / 4 の実機の見た目 | 確認済み | `evidence/manual-imageGrid-{ios,android}-after.md` の 8.4 の節 (オーナーの目視で「特に無し」、定数は不変)。tasks 8.4 はチェック済み | なし |

## 追加検査

- [x] **tasks.md**: 未チェックは 8.1 だけで、ほかの 36 件はチェック済み。対応表と突き合わせ、虚偽チェックが無いことを確かめた。今回チェックされた 6.6・8.2・8.3・8.4・8.5 には、それぞれ `evidence/` の証跡がある。記録として残しておく点:
  - 8.5 の「必要なら簡易起票する」: `evidence/disk-wait-{android,ios}.md` に「簡易起票の材料」の節はあるが、`kasane/changes/` に新しい簡易起票は無い。条件付きの文言なので虚偽とはしない。材料の 3 番目 (Android の先読みの完了後の引き当て直し) は、今回の修正で解消されている。起票するかは呼び出し元の判断
  - 8.3: Android の 10,000 件の往復のうち、幅なしの 1 回目は 10 往復で定常にならなかった (notSteady)。2 回目は steady:7。証跡にはそのとおり記録されている。Scenario には対応しない
  - 8.1 (未チェック): 完了時計測の証跡 `evidence/manual-imageGrid-{android,ios}-after.md` は、どちらも冒頭で、計測したコードを「verify-001 が VALID の時点の作業ツリー」(= 今回の修正の前) と記している。採り直しを iOS 走行 5 だけにするか、修正後のコードで取り直す範囲を広げるかは、呼び出し元とオーナーの判断に委ねる (spec の Scenario の判定には影響しない)
- [x] **逆流検査**: `git diff HEAD -- kasane/` の変更は `tasks.md` だけで、差分は 36 行のチェックボックス (`[ ]` → `[x]`) だけ (word-diff で確認。本文の変更なし)。proposal.md / design.md / specs/ は HEAD (3e4a918 = 提案の改訂コミット、実装前) から変更なし。deviation.md は未追跡の新規ファイル (合意の記録)
- [x] **未記録乖離**: なし。今回の修正は deviation.md 12 行目に記録済みで、実装はその記録と一致した。iOS は画面に出る時点で照会し直し、外れたときだけローダーの表示を組み立てる。Android は、その識別子の先読みの鍵が索引にありメモリに無いときに限って待つ (`KsImageRequestFactory.kt:116-118`)。記録にある「利用者から見える差」のうち、上の「サイズ確定前は取得しない」に当たる分は ⚠️ として扱った
- [x] **付随修正**: 前回以降に増えた Sample の変更は、画面に出る時点の読み込み中の計数 (`ImageLoadingSlotShown*`、`ImageLoadingLedger.swift`、`ImageLoadingSlotShownTest.kt`、`ImageLoadingSlotShownClippingUITests.swift`)、実機の引き当ての観測 (`ImagePrefetchMatchProbe*.swift`、`ImageObserveScreen.kt`)、索引の覗き窓 (`ImageMemoryIndexReport.swift`、`MemoryIndexProbe.kt`)、`ImageGridCell` の差し込み (上記) である。いずれも tasks 6.6 / 8.2 / 8.3 の計測の足場の範囲で、計数を要求した実行と計測用のソースセット・起動経路でだけ働く。spec の挙動は変えない。ただし、証跡の一部 (`evidence/disk-wait-ios.md` の連続送りの段、`evidence/memory-steady-ios.md` の読み込み待ちの往復) は、Sample のスクラッチ上の複製にだけ足した足場で採られており、リポジトリの Sample からは再現できない (各証跡に明記されている)
- [x] **UI 変更**: 本 change は `ui/` を持たない。Sample の選択の見せ方は deviation.md 4 行目で合意済み
- [x] **テスト成功**: 上の「テスト実行」のとおり。本 change の範囲のテスト (iOS パッケージ 271、Android ライブラリ 219、Android Sample 44、Sample UI テストのうち本 change が足したもの・触れたもの) はすべて成功した。失敗した 1 件 (`LargeDataCountUITests`) は、本 change の差分が触れていないテストと対象コードのもので、実行ごとに結果が変わる

## まとめ

| 区分 | 件数 |
|---|---|
| ✅ 一致 | 56 |
| ⚠️ deviation 記録済み | 5 (小さすぎる項目は使わない / 大きすぎる項目は使わない / 削除の世代は別の key と衝突しない / サイズ確定前は取得しない (今回の変更) / 切り替えの反映)。このほか、16384 px の上限・索引の刈り込み・画面に出る時点の引き当て (deviation.md 12 行目) の合意が、各表の補足と実装欄に該当する |
| ⏳ 実機確認待ち | 0 (前回の 3 件はすべて閉じた) |
| ❌ 欠落・乖離 | 0 |
| 合計 | 61 Scenario (13 Requirement) |

ksn-distill の前に残るもの: tasks 8.1 (iOS 走行 5 の採り直し。完了時計測を修正後のコードで取り直す範囲は呼び出し元の判断)。Scenario の判定に残りは無い。
