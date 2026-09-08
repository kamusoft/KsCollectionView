# Verify 002: image-loading

- 検証日: 2026-09-08
- 対象: 実装コミット `8336212` + その後の未コミット変更 (`git status --short` 51 件 / `git diff` / untracked 新規ファイル)
- 基準: `specs/image-loading/spec.md` (13 Requirement / 32 Scenario)
- 合意済みの差分: `deviation.md` (97 件。verify-001 時点の 50 件から 47 件増)
- 前回: `verify-001.md` (2026-09-07、VALID)。本便はその後に変わった範囲 (Android の縮小結果 3 値化・到達点メモリの指定撤去・実機テスト・計数機構・実機計測の完了) を含めて全 Scenario を引き直した
- 作業ドメイン: cross (ios + android)

## 判定

**INVALID (❌ 1 件 — 契約の欠落ではなく、記録漏れ 1 件のみ)**

- 32 Scenario はすべて「✅ 一致」または「⚠️ deviation 記録済み」で、**契約の欠落・未記録の乖離は 0 件**
- 虚偽チェックなし。逆流なし。テストは 5 系統すべて全件成功 (154 / 5 / 130 / 28 / 4)
- ❌ は**追加検査の「未記録の付随変更」1 件**: `kasane/handbook/cross/local-development-setup.md` への追記 (iOS 実機のペアリング手順) が `deviation.md` の `[付随修正]` にも tasks にも無く、change のどのアーティファクト (review / evidence / deviation) からも来歴を辿れない。**見立て: 実装の修正は不要。`deviation.md` に `[付随修正]` を 1 行足せば解消する** (詳細は「未記録乖離の洗い出し」節)

---

## 参照の短縮名

| 短縮名 | パス |
|---|---|
| iOS 本体 | `ios/Sources/KsCollectionView/` |
| iOS テスト | `ios/Tests/KsCollectionViewTests/` |
| And 本体 | `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/` |
| And テスト | `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/` |
| And 実機テスト | `android/kscollectionview/src/androidTest/kotlin/jp/kamusoft/kscollectionview/` |
| And Sample テスト | `samples/android/app/src/test/kotlin/.../samples/android/` |
| 証跡 | `kasane/changes/image-loading/evidence/` |

---

## 対応表

### Requirement: プリフェッチ宣言 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| もうすぐ表示されるアイテムの画像を取得する | iOS: `KsCollectionView.swift:231` (`prefetchResources(destination:_:)`) → `KsCollectionViewController.swift:163,748` → `KsImagePrefetcher.swift:32`<br>And: `KsCollectionView.kt:105-106,144-151` → `KsImagePrefetchWindow.kt:51,144` | iOS: `KsImagePrefetchTests.swift` `test先読み対象の項目がURLへ解決されて到達点付きで開始される` / `testシステムの先読み通知で取得が始まり取り消し通知で止まる` (本番 controller の `prefetchItemsAt` を叩く)<br>And: `KsCollectionViewPrefetchTest.kt` `initialWindowPrefetchesVisibleCountAhead` (本番 `KsCollectionView` を compose) | ✅ 一致 |
| 宣言が無ければ何も起きない | iOS: `KsCollectionViewController.swift:163-168` (nil で解決層を作らず既存も破棄)<br>And: `KsCollectionView.kt:144` (`if (prefetchResources != null)` で Effect 自体を組み立てない) | iOS: `test宣言が無ければ受け口へ何も伝わらない`<br>And: `noDeclarationStartsNothing` | ✅ 一致 |
| 複数 URL の宣言 | iOS: `KsImagePrefetcher.swift:105-119` (`reconcile`)<br>And: `KsImagePrefetchWindow.kt:144-155` (`start` が urls を反復) | iOS: `test1項目に複数のURLを宣言すると両方の取得が始まる`<br>And: `KsImagePrefetchWindowTest.kt` `multipleUrlsPerItemAreAllStarted` | ✅ 一致 |

補足 (SHALL NOT / 付帯条項):
- 「protocol / interface 準拠を要求しない」: 公開面は `(Item) -> [URL]` / `((Item) -> List<String>)?` の素のクロージャ。`KsPublicAPITests.swift` / `KsCollectionViewPublicApiTest.kt` `composesWithPrefetchDeclaration` — ✅
- 「空配列を返したアイテムは何も取得しない」: iOS `test空の配列を返した項目では何も取得しない` / And `itemsWithoutResourcesStartNothing` — ✅
- 「`destination` の既定は `disk`」: `KsCollectionView.kt:106` の既定値 + `prefetchDestinationHasDiskAndMemory`、iOS は modifier の既定引数 — ✅

### Requirement: プリフェッチの取り消し (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| スクロール方向の反転で取り消される | iOS: `KsCollectionViewController.swift:756` → `KsImagePrefetcher.swift:41`<br>And: `KsImagePrefetchWindow.kt:121-141` (進行方向判定) + `:156-165` (`release`) | iOS: `testシステムの先読み通知で取得が始まり取り消し通知で止まる` (システム通知に委譲)<br>And: `reversingDirectionCancelsAndRestarts` / `reversingDirectionCancelsOldWindowAndStartsNewOne` | ✅ 一致 |
| 配列の差し替えで消えたアイテム | iOS: `KsCollectionViewController.swift:134` → `KsImagePrefetcher.swift:47`<br>And: `KsImagePrefetchWindow.kt:58-86` | iOS: `test配列の差し替えで消えた項目の取得は取り消される`<br>And: `replacingItemsCancelsRemovedItem` / `replacingItemsCancelsRequestsForRemovedItems` | ✅ 一致 |
| 共有 URL は最後のアイテムが外れるまで取り消さない | iOS: `KsImagePrefetcher.swift:123-142` (参照数 acquire / release)<br>And: `KsImagePrefetchWindow.kt:32,149-165` (`Request.referenceCount`) | iOS: `test共有URLは最後の項目が外れるまで取り消さない`<br>And: `sharedUrlIsCancelledOnlyAfterLastItemLeaves` / `duplicatedUrlsWithinOneItemCountAsOne` | ✅ 一致 |
| 画面から消えたら全て取り消す | iOS: `KsCollectionViewController.swift:155-158` (`disconnect` → `cancelAll`)<br>And: `KsImagePrefetchWindow.kt:87,195` (`onDispose` → `disposeAll`) | iOS: `test画面から消えたときに未完了の取得をすべて取り消す`<br>And: `leavingCompositionDisposesAll` | ✅ 一致 |

補足:
- 「取り消しは進行中の取得にのみ作用し、完了してキャッシュに入ったものは消さない」: iOS は `ImagePrefetcher.stopPrefetching`、And は `Disposable.dispose` へ写像。`diskDestinationStoresDataWithoutDecodingOrRefetching` 等が「取り消し後もキャッシュから表示できる」側を検査 — ✅
- 「クロージャと `destination` の差し替えは以後の新しい取得にだけ反映」: iOS `KsCollectionViewController.swift:171-175`、And `KsImagePrefetchWindow.kt` の `rememberUpdatedState`。台帳再解決で「次の通知・配列更新の時点で旧 URL を止めて新 URL へ切り替わる」挙動になった点は deviation「先読み宣言のクロージャの呼び出し回数」で記録済み。テストは iOS `test同じIDのまま画像が差し替わると古いURLを止めて新しいURLを取りに行く` / And `changingTheUrlOfAnItemWithTheSameIdRestartsThePrefetch` — ⚠️ deviation 記録済み

### Requirement: プリフェッチの到達点 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| ディスク到達点の後の表示 | iOS: `KsNukeImageLoading.swift:37-52` (`.diskCache`)<br>And: `KsCoilImageLoading.kt:38-49` (`memoryCachePolicy(DISABLED)` + `BlackholeDecoder`) | iOS: `KsImageCacheContractTests.swift` `testディスク到達点の後の表示ではネットワークが走らない` (URLProtocol スタブ + デコード計数、表示は本番 `prepare` 経由)<br>And: `KsImageCacheContractTest.kt` `diskDestinationStoresDataWithoutDecodingOrRefetching` (`display()` が本番 `KsImageRequestFactory.prepare` を通す) | ✅ 一致 |
| メモリ到達点の後の表示 | iOS: `KsNukeImageLoading.swift:53` (`.memoryCache`) + `KsImageRequestFactory.swift:69-74` (元寸から同期縮小)<br>And: `KsCoilImageLoading.kt:46-48` (既定のまま) + `KsImageRequestFactory.kt:102-118` (3 値の縮小結果) | iOS: `testメモリ到達点の後の表示では再デコードしない` / `test表示の要求はメモリ到達点の先読み結果を再デコードせずに使う`<br>And: `memoryDestinationAvoidsSecondDecodeWhenPrefetchedPixelsAreReadable` (**画素を読み出せる条件下でのみ**) + 実機 `KsImageDeviceDecodeTest.displayAfterMemoryPrefetchDecodesOnceInLoader` (実機はデコード 1 回を待つ) | ⚠️ deviation 記録済み (Android 実機) |
| 到達点が伝わる | iOS: `KsImagePrefetcher.swift:144-152` (`apply` → `prefetch(urls:destination:)`)<br>And: `KsImagePrefetchWindow.kt:144-155` | iOS: `test到達点memoryの宣言はmemoryとして受け口へ届く`<br>And: `destinationReachesLoader` / `destinationIsPassedThroughToLoader` | ✅ 一致 |

deviation の内容 (「メモリ到達点の後の表示」の Android 実機):
- **オーナー判断 C** (deviation 2026-09-08「先読みの `allowHardware(false)` を外す」) により、Android の到達点 `memory` は元寸をハードウェア支援のままメモリへ載せる。実機では画素を読み出せないため表示側は初回描画に使わず (`KsDownscaleResult.Unreadable` → `KsImageRequestFactory.kt:117`)、**「デコードのやり直しもなしに表示される」が実機で一時的に破れる** (ディスクから表示サイズで再デコードする)。ソフトウェアビットマップの環境 (エミュレータ・JVM) では両立する。解消は別 change `prefetch-display-size`。deviation の 2026-09-08 の 2 項 (オーナー判断 C とレビュー 9 周目の補足) に明記済み
- 「ライブラリ独自のキャッシュ領域を持たない」: iOS は `ImagePipeline.shared`、And は `SingletonImageLoader.get(context)`。`requestsMadeDirectlyOnTheSharedLoaderReuseThePrefetchedData` が `assertSame` で共有インスタンスを検査 — ✅
- 縮小済み画像を共有ローダーのメモリへ書き足す設計 (項目数が「表示サイズ × 当てはめ方」ぶん増える) は deviation 記録済み — ⚠️

### Requirement: プリフェッチの先読み範囲 (Android) (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 可視件数と同数を先読みする | `KsImagePrefetchWindow.kt:121-141` (`resolveWindow`) | `KsCollectionViewPrefetchTest.kt` `initialWindowPrefetchesVisibleCountAhead` (可視 6 件 → 直後の 6 件。本番 `KsCollectionView` 経由)<br>`KsImagePrefetchWindowTest.kt` `initialWindowFollowsForwardWithVisibleCount` / `windowStopsAtTheEndOfItems` | ✅ 一致 |
| 進行方向へ移動すると窓が進む | `KsImagePrefetchWindow.kt:58-86` (可視範囲のアイテムは台帳に残し取り消さない) | `scrollingForwardAdvancesWindow` / `forwardScrollAdvancesWindowWithoutCancellingItemsEnteringViewport` | ✅ 一致 |

補足: 「静止時は直前の進行方向を保つ」「初期表示は末尾方向」は `stationaryViewportKeepsPreviousDirection` / `initialWindowFollowsForwardWithVisibleCount`、台帳が可視+窓に有界であることは `ledgerStaysBoundedWhileScanning` — ✅

### Requirement: プリフェッチの先読み範囲 (iOS) (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| システムの先読み通知に従う | `KsCollectionViewController.swift:191` (`prefetchDataSource = self`) / `:748` / `:756` | `KsImagePrefetchTests.swift` `testシステムの先読み通知で取得が始まり取り消し通知で止まる` (本番 controller を `loadViewIfNeeded` して `UICollectionViewDataSourcePrefetching` を直接呼ぶ) | ✅ 一致 |

### Requirement: 共有キャッシュ (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| ローダー付属ビューとキャッシュを共有する | iOS: `KsNukeImageLoading.swift:31-35` (識別子を付けない素の要求)<br>And: `KsCoilImageLoading.kt:38-49` (寸法なしの素の要求) | iOS: `testローダーを直接使う素の要求と同じキャッシュ項目を共有する`<br>And: `requestsMadeDirectlyOnTheSharedLoaderReuseThePrefetchedData`<br>実機/エミュレータ: `証跡/image-behavior-observation.md` 7.3 (iOS: 先読み済み 12 件は要求が 0 件 / And: 12 件がメモリキャッシュから) | ✅ 一致 |
| iOS のディスクキャッシュ有効化 | `KsImagePipeline.swift:37` (`enableSharedDiskCache()` — **利用者が明示的に呼ぶ公開 API**) | `KsImagePipelineTests.swift` 4 件 (未設定なら差し替え / 設定済みなら不変 / 独自 DataLoader の引き継ぎ / 二度呼んでも保つ) | ⚠️ deviation 記録済み |

deviation の内容: spec は「初回利用時に自動で差し替える」だが、Nuke 13.2.0 が共有パイプラインの `delegate` を外から読めないため、**明示 API を 1 つ設けて呼ばれたときだけ差し替える**形に変更 (オーナー判断)。副作用 2 件と、ディスクキャッシュ作成失敗経路がテスト未到達である点も deviation に記録済み。

### Requirement: KsImage の画像ソース (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 3 種のソースを表示する | iOS: `KsImageSource.swift` + `KsImage.swift:102` (asset は `UIImage(named:)`)、`:123` (remote/file は `LazyImage`)<br>And: `KsImageSource.kt` + `KsImage.kt:241` (Resource は `drawablePainter`)、`:153-` (他は loader) | iOS: `KsImageDisplayTests.swift` `testリモートのソースは画像が表示される` / `testファイルのソースは画像が表示される` (実表示・中心色一致)、`testバンドル済みリソースのソースはローダーを通らずに表示が決まる`<br>And: `KsImageTest.kt` `threeSourceKindsAreDisplayed` / `xmlDrawablesThatAreNotVectorsAreDisplayed` | ⚠️ deviation 記録済み (iOS のアセットのみ) |
| 便宜形 | iOS: `KsImage.swift:225` (`KsImage(_ url:)` ほか init overload)<br>And: `KsImage.kt:117` | iOS: `KsImageTests.swift` `test便宜形はリモートのソースと同じ宣言になる`<br>And: `urlConvenienceFormBehavesLikeRemoteSource` | ✅ 一致 |

deviation の内容: **iOS のアセットの「成功表示」は end-to-end で検査できていない** (SwiftPM のテストプロセスでは `Bundle.main` が Xcode のディレクトリを指す)。代わりに「解決できない名前 → 失敗表示」「ローダーを通らない」を実表示で検査。Android の Resource を `painterResource` 相当の同期経路にした点・読めないリソース ID を debug で停止させる点・図形形式の直接テストが無い点も記録済み。

### Requirement: KsImage の表示状態 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 読み込み中から成功へ | iOS: `KsImage.swift:123-145` (`prepare` が nil / `cachedImage` が nil のとき `loadingContent`)<br>And: `KsImage.kt:185-227` (`cachedHolder` と `AsyncImagePainter.State`) | iOS: `KsImageDisplayTests.swift` `testリモートのソースは画像が表示される` (空キャッシュから成功表示まで)。逆側は `test読み込み中のスロットはメモリにある画像では一度も構成されない`<br>And: `slotsAreSubstituted` / `loadingSlotIsNeverComposedWhenTheImageIsAlreadyInMemory`<br>実機: `証跡/image-behavior-loading-failure-{ios,android}.png` | ⚠️ deviation 記録済み (Android 実機・到達点 memory のみ) |
| 失敗時の表示 | iOS: `KsImage.swift:129` (`state.error != nil`) / `:107` (asset 解決失敗)<br>And: `KsImage.kt:213` (`State.Error`) / `:243-` (リソース解決失敗) | iOS: `KsImageDisplayTests.swift` `testバンドル済みリソース…` / `KsImageAccessibilityTests.swift` `test説明を付けた画像は失敗の状態でもその説明を読み上げる`<br>And: `failureSlotIsShownWhenLoadingFails` / `defaultDisplayIsUsedWithoutSlots` / `resourcesThatCannotBeDrawnFallBackToTheFailureSlot` | ✅ 一致 |
| 失敗後の再試行 | iOS: `KsImage.swift:142` (`.id(reloadToken)`)<br>And: `KsImage.kt:149` (`key(source, reloadToken)`) | iOS: `test失敗した表示はビューが作り直されると再び取得を試みる` (失敗パイプラインで実表示・要求 2 回)<br>And: `failedImageIsRetriedWhenTheViewIsRecreated` | ✅ 一致 |
| スロットの差し替え | iOS: `KsImage.swift:150-166` + 各 init overload (`:180`〜`:225`)<br>And: `KsImage.kt:69-80` (`loading` / `failure` 引数) | iOS: `KsPublicAPITests.swift` `test読み込み中と失敗の表示は片方だけでも差し替えられる` + `KsImageDisplayTests.swift` (失敗スロットの実描画)<br>And: `slotsAreSubstituted` / `defaultDisplayIsUsedWithoutSlots` / `imageSlotsCanBeSubstitutedIndependently` | ✅ 一致 |

deviation の内容 (「読み込み中から成功へ」の Android 実機):
- **オーナー判断 C の帰結**として、Android 実機で到達点 `memory` の先読みが載せた元寸は画素を読み出せず、`KsImageRequestFactory.kt:117` が初回描画に使わないため、Requirement 本文の「**メモリキャッシュにあれば読み込み中を経由せず成功になる**」が一時的に破れる (`KsCoilImageLoading.kt` / `KsImage.kt:185-190` / `KsImageRequestFactory.kt:41-46` の doc に明記)。deviation の 2026-09-08 の 2 項に記録済み。解消は `prefetch-display-size`
- ただし本 Scenario の判定に直結する「戻ってきたとき」の局面は実機で合格している (下記「戻ってきたときの再表示」)

その他の付帯条項:
- 「サイズ未確定かつメモリに画像あり」の 2 文衝突で後者を優先した点 — ⚠️ deviation 記録済み
- 「リソースは読み込み中を経由せず成功か失敗になる」: iOS `UIImage(named:)`、And `drawablePainter` の同期経路 — ✅ (design からの逸脱は deviation 記録済み)
- 「同じビューが表示され続けている間は自動で再試行しない」: `reloadToken` / `key(...)` が変わらない限り再構成されない。`loadingSlotIsNeverComposedWhenTheDisplayIsRebuilt` が裏側から支える — ✅

### Requirement: KsImage の当てはめ方 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| fit と fill | iOS: `KsImage.swift:84` (`clipped()`) + `KsImageRequestFactory.swift:146-151` (`thumbnailContentMode`)<br>And: `KsImage.kt:80` (`clipToBounds`) + `KsImageRequestFactory.kt:176-179` (`toCoilScale`) | iOS: `test表示枠と当てはめ方から決まる縮小指定が付く` / `test枠より大きい画像は当てはめ方に応じた寸法へ縮小される` / `test当てはめ方の既定はfillになる`<br>And: `contentModeMapsToContentScale` / `imagesLargerThanTheFrameAreDownscaledBeforeBeingDisplayed` / `KsCollectionViewPublicApiTest.kt` (既定値) | ✅ 一致 |

補足: 既定が `fill`、はみ出しが表示されないこと (`clipped()` / `clipToBounds()`) を実装で確認。視覚面は `ui/verification/image-grid-normal-{ios,android}.png` と `ui/brief.md` の照合記録が補う (**2026-09-07 にオーナー最終承認済み**)。

### Requirement: KsImage の縮小デコード (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 枠より大きい画像 | iOS: `KsImageRequestFactory.swift:115-127` (`displayRequest` の `ThumbnailOptions`) / `:69-74` (元寸からの同期縮小) / `:130-141` (`downscaleProcessor`)<br>And: `KsImageRequestFactory.kt:85-93` (`size` + `Precision.EXACT`) / `:125-149` (`downscale`) / `:172` (`isPixelReadable`) | iOS: `test枠より大きい画像は当てはめ方に応じた寸法へ縮小される` / `test元寸から縮小する経路でも当てはめ方に応じた寸法になる` / `test表示に使う要求の鍵は元寸の有無で変わらない`<br>And: `imagesLargerThanTheFrameAreDownscaledBeforeBeingDisplayed`<br>**実機**: `KsImageDeviceDecodeTest.preparedRequestDecodesInsideFrameAfterMemoryPrefetch` / `preparedImageSkipsUnreadableOriginal` (読み出せない元寸を初回描画に使わず、枠を超えないことを実機で固定) | ⚠️ deviation 記録済み |
| サイズ確定前は取得しない | iOS: `KsImageRequestFactory.swift:96` (`makeContext` が 0 で nil) → `KsImage.swift:145`<br>And: `KsImageRequestFactory.kt:77` (`width <= 0 \|\| height <= 0` で null) → `KsImage.kt:153-` | iOS: `testサイズが確定するまで要求を発行しない`<br>And: `noRequestIsBuiltBeforeTheFrameSizeIsSettled` | ✅ 一致 |

deviation の内容 (いずれも記録済み):
- iOS の `fit` の縮小指定を `maxPixelSize` から `ThumbnailOptions` の `.aspectFit` / `.aspectFill` へ
- 縮小手段の選び分け (元寸がメモリにあるか) と、レビュー 3 周目での**表示要求 1 本化**
- Android の表示要求のキャッシュ鍵に `coil#size` を使い、当てはめ方の区別に自前の `ks#scale` を併用
- Android の枠の読み取りを `BoxWithConstraints` に変更 (subcomposition が 1 段増える)
- 到達点メモリの継ぎ目を「元寸を同期で引き当て、その場で縮小」に揃えた件、その同期縮小の費用、および**クラッシュ修正で 3 値化 (`Done` / `NotNeeded` / `Unreadable`) した件**
- **「`KsImage` の表示のために元寸をメモリに保持しない (SHALL NOT)」は保たれている**: `Unreadable` の分岐は元寸を描画に使わずローダーの縮小デコードを待つ形で、元寸は先読みが載せたもの (本要件の対象外と spec が明記)

### Requirement: KsImage の読み込み取り消しとメモリ保持 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 画面外へ出た読み込みの取り消し | iOS: `KsImage.swift:123` (`LazyImage` が消滅時に取り消す)<br>And: `KsImage.kt:178-` (`rememberAsyncImagePainter` が composition 離脱時に取り消す) | 実機/エミュレータ: `証跡/image-behavior-observation.md` 7.4「取り消し」表 (iOS 表示要求 取消 53 件 / Android 表示要求 取消 3 件。Android は回線を絞って取り消しが起きる状況を作ってから観測) | ✅ 一致 (**検査は実機観測でのみ成立**) |
| 戻ってきたときの再表示 | iOS: `KsImageRequestFactory.swift:49-79` (表示鍵 1 本)<br>And: `KsImageRequestFactory.kt:81-99` (`displayKey`) | iOS: `test一度表示した画像は表示を作り直しても読み込み中を経由しない` (読み込み中スロットの構成回数 0 を直接数える)<br>And: `loadingSlotIsNeverComposedWhenTheDisplayIsRebuilt`<br>**実機 (tasks 7.4 完了)**: `証跡/image-behavior-observation.md` — 基準点からの差分 `Δsized == 0` を両プラットフォーム・両到達点で観測し**合格**。陽性対照 (同区間で初出要素が `Δsized >= 1`) も揃っている | ✅ 一致 (テスト層 + 実機観測) |

補足:
- 「メモリキャッシュから追い出された画像はディスク／ローカルから再デコードされる」: `testメモリのみ消去してもディスクの元データから再デコードできる` / `clearingMemoryKeepsDiskDataForRedecoding` — ✅
- verify-001 で「実機未確認」だった後半 (戻りの再表示) は本便で**実機観測が完了**している (Android は Pixel 4a、iOS は iPhone 11)
- iOS の判定範囲を「戻った可視範囲 1〜12」に絞った読み方 (ID 13〜15 を除外) は deviation に「**オーナー未確認**」として記録済み — ⚠️

### Requirement: キャッシュのクリア (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 全消去の後の表示 | iOS: `KsImageCache.swift:24-45` (`clear(.all)` → `removeAll` + `invalidateAll`)<br>And: `KsImageCache.kt:35-55` | iOS: `test全消去の後の表示はメモリに当たらず取り直しになる` / `test表示中のKsImageは全消去で取得をやり直す` (実表示を窓に載せて取り直しを観測)<br>And: `clearingAllAlsoInvalidatesTheDecodedMemoryImage` / `clearMapsToLoaderCachesAndAdvancesGenerationExceptForMemory` / `removeMakesTheDisplayedImageReload`<br>実機: `証跡/image-behavior-observation.md`「キャッシュを消去」の後の再取得 | ✅ 一致 |
| メモリのみ消去 | iOS: `KsImageCache.swift:30-31`<br>And: `KsImageCache.kt:41` | iOS: `testメモリのみ消去してもディスクの元データから再デコードできる`<br>And: `clearingMemoryKeepsDiskDataForRedecoding` | ✅ 一致 |
| ソース単位の削除 | iOS: `KsImageCache.swift:47-` (世代を進める)<br>And: `KsImageCache.kt:57-` (鍵一致でメモリ走査 + `diskCache.remove`) | iOS: `testソース単位の削除では対象のソースだけが消える` / `testソース単位の削除は対象のソースの識別子だけを変える`<br>And: `removeDeletesOnlyTheTargetSource` / `removeKeepsAnotherSourceWhoseKeySharesThePrefix` / `removeAffectsOnlyTheTargetSource` | ✅ 一致 |
| 削除後は別サイズでも旧項目に当たらない (iOS) | `KsImageIdentity.swift` + `KsImageRequestFactory.swift:100,125` (`imageID` を要求に付与) | `test削除後はどの表示サイズの要求も削除前の項目に当たらない` (複数サイズ) | ✅ 一致 |

deviation (いずれも記録済み) — ⚠️:
- **消去範囲を 3 択 → 2 択 (`memory` / `all`) に変更** (オーナー判断)。実装で確認: `KsImageCacheScope` は iOS `KsImageCache.swift:5-11` / And `KsImageCache.kt:7-13` とも 2 値。**対応する Scenario が spec に無いため対応表の欠落にはならない**
- `clear(.disk)` がメモリ項目も落とす実挙動 (上記の前提)
- キャッシュ消去時のフェンスの限界 (取り消しとキャッシュ書き込みの同時発生 / 消去後は次に可視範囲が動くまで先読み再開しない)
- **フェンスの適用範囲を先読み層の進行中取得のみに限定**。deviation に「**この受容はオーナー未確認**」と明記
- Android のキャッシュ操作が未初期化時に警告ログ + no-op になる件 / `remove` の鍵導出がリモート以外 best-effort である件 / `KsAppContext.reset()` をテスト専用に追加した件

追加検査 (Requirement 本文の SHALL / SHALL NOT):
- 「`clear` は共有に影響しない」: `clear(.all)` は無効化の世代だけを進め、要求に載る `imageID` は変えない (`test全消去は世代を進めメモリのみ消去は進めない`) — ✅
- 「iOS のアセットに対する `remove` は何もしない」: `KsImageCache.swift:48` の guard + `testアセットの削除は何もしない`。Android の Resource も対称に no-op (`removeDoesNothingForBundledResources`) — ✅
- 「呼び出しから戻った時点で削除が完了」: 先読みのフェンス (`KsImagePrefetchFence`) を両プラットフォームに持ち、`clearFencesEveryPrefetchInFlight` / `prefetchesStartedBeforeAClearDoNotRepopulateTheCache` / iOS `test消去より前に始まった先読みは完了してもキャッシュへ戻らない` が検査 — ✅ (限界は deviation 記録済み)

### Requirement: Sample のデモ画面「画像グリッド」 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 切り替えの反映 | iOS: `samples/ios/KsCollectionViewSamples/ImageGridDemoView.swift` + `ImageGridFixture.swift` + `ImagePrefetchChoice.swift`<br>And: `samples/android/.../ImageGridDemoScreen.kt` + `ImageGridFixture.kt` + `ImagePrefetchChoice.kt` | And: `SampleDemoScreenTest.kt` `画像グリッド画面のプリフェッチの初期選択はディスクまでである` (3 択の選び直し) + `ImageGridMeasurementFixtureTest.kt` `プリフェッチの宣言は到達点を選ばないときだけ無い`<br>本体側: 「宣言あり → 先読み開始」「宣言なし → 何も起きない」は上の 2 Requirement で検査済み<br>ローダーのログ: `証跡/image-grid-measurement-android.md`「先読みの開始・取消件数」(到達点ディスク・メモリ)、`証跡/image-behavior-observation.md` 7.4 | ✅ 一致 |
| 全消去 | iOS: `ImageGridDemoView.swift` の `KsImageCache.clear(.all)`<br>And: `ImageGridDemoScreen.kt` の `KsImageCache.clear(KsImageCacheScope.All)` | 実機/エミュレータ: `証跡/image-behavior-observation.md`「キャッシュを消去」の後の再取得 (iOS 15 件がネットワークから再取得 / Android は可視セルが読み込み中の既定表示に戻る静止画) | ✅ 一致 |

補足:
- sample-parity: `SampleScreenParityTest.kt` の 4 件 (`デモ画面のタイトルと順序が iOS と一致する` / `デモ画面は 10 ある` / `検証画面はデモ画面と別区分の 1 画面である` ほか)。初期選択「ディスクまで」は `ImagePrefetchChoice.initialSelection` (iOS) / `ImagePrefetchChoice` の既定 (And) で一致
- 計数機構の追加後も**デモ画面の見た目は不変**: 印 (`ImageLoadingSlotMark`) と読み込み中スロットの差し込みは、両プラットフォームとも実行時 opt-in (iOS 起動引数 `--count-image-loading-slots` / Android intent extra `ks_count_image_loading_slots`) でのみ現れる。`counterDisabled` 構成の `rememberLoadingSlot` は常に null を返し本体既定に委ねる (実装確認済み)。deviation 記録済み — ⚠️
- 「切り替えの反映」の THEN にある「ローダーのログで確認できる」は、デモ画面での**「なし」→「ディスクまで」の切り替え前後の対比**としては証跡に残っていない (証跡は到達点ごとの独立実行での先読み件数)。挙動そのものはテスト 2 層で担保されているため一致とした (verify-001 と同じ扱い)
- 計測入口の土俵一致の担保が非対称 (Android は静的テスト、iOS は組み立て関数の 1 本化) — ⚠️ deviation 記録済み

---

## 追加検査

### tasks.md の完了状態と虚偽チェック

| 項目 | 結果 |
|---|---|
| 全 26 タスクが `[x]` | verify-001 で未チェックだった 7.1 / 7.4 / 7.5 が本便で `[x]` に。いずれも証跡が実在し、実施内容と一致 |
| 虚偽チェック | **なし** |

個別確認 (verify-001 以降にチェックが付いた 3 件):

| タスク | 証跡 | 判定 |
|---|---|---|
| 7.1 (iOS 計測) | `evidence/image-grid-measurement-ios.md` — 「メモリは合格、スクロール性能は不合格 (0.00 / 3.94 / 5.54 ms/s)」「計測としては完了、性能の合否としては不合格」と明記。先読み開始/取消件数も記録 | タスクの文言は「計測し証跡に残す」であり、**計測は完了している**。合否は不合格のまま deviation に記録され、扱いはオーナー判断待ち。虚偽ではない |
| 7.4 (取り消し / 戻り) | `evidence/image-behavior-observation.md` — 取り消しは両プラットフォームで観測、戻りは `Δsized == 0` を両プラットフォーム・両到達点で観測して**合格**。陽性対照あり | 一致 |
| 7.5 (Android 画像グリッド計測) | `evidence/image-grid-measurement-android.md` — スクロール絶対基準は両到達点とも**不合格** (ディスク 6.4/6.2 ms、メモリ 4.6/4.4 ms、いずれも再現)、メモリ定常化と件数比は合格。到達点メモリはオーナー判断 C 反映後の値で取り直し済み | 7.1 と同じ理由で虚偽ではない |

### 逆流検査 (足場アーティファクトの書き換え)

- `proposal.md` / `design.md` / `specs/image-loading/spec.md` は最終更新が提案化コミット `f7a2aed` のままで、実装コミット `8336212` にも作業ツリーにも差分なし。**逆流なし**
- `tasks.md` (進捗チェック) / `deviation.md` / `evidence/` / `ui/brief.md` の追記は実装フェーズで想定された書き足しであり、契約の書き換えではない

### 未記録乖離の洗い出し

対応表に ❌ はない (契約の欠落・未記録の仕様乖離は 0 件)。

一方、**Scenario に対応しない変更のうち、`[付随修正]` にも tasks にも記録が無く、change のアーティファクトから来歴を辿れないものが 1 件**ある。

| # | 変更 | 内容 | 見立て |
|---|---|---|---|
| ❌ 1 | `kasane/handbook/cross/local-development-setup.md` (コミット `8336212`) | iOS 実機での実行・計測時の機体指名 (`-destination 'platform=iOS,id=<UDID>'`) と、`xcrun devicectl manage pair` によるペアリング再確立の手順を 16 行追記し `timestamp` を 2026-09-07 に更新 | **deviation として合意すべき** (実装の修正は不要)。内容は tasks 7.1 の実機計測で実際に踏んだ手順であり、記述自体に誤りは見当たらない。長命層 (handbook) への追記が change の記録から辿れない状態なので、`deviation.md` に `[付随修正]` を 1 行足すのが解消手段。**契約・実装・テストへの影響はない** |

来歴が辿れるため未記録乖離としなかったもの:

- `kasane/handbook/cross/runtime-behavior-verification.md` の観測点表への追記 → `review-001.md` Minor 1 由来 (verify-001 で確認済み)
- `kasane/changes/sample-comment-policy-cleanup/exploration.md` → `review-001.md` から参照され、exploration 本文に「`image-loading` の実装フェーズで発見し、オーナー判断で別 change として積んだ」と記載
- `kasane/changes/prefetch-display-size/` → deviation 2026-09-08「到達点 `memory` の性能不合格」に簡易起票として記録済み
- `kasane/changes/ios-separator-update-guard/` → deviation 2026-09-08「iOS 7.1 の不合格の切り分け」に簡易起票として記録済み
- `kasane/lessons/inbox/` の追加 (`exercise-device-only-branches-on-real-hardware` ほか) → ksn-lesson の捕捉であり、deviation に「教訓を捕捉済み」と記載
- `kasane/roadmaps/.../dsl-samples.md` → tasks 6.4
- 計測・観測・計数の足場一式 (`ImageGridMetrics` / `ImageLoadingObserver` / `ImageBehaviorVerificationScreen` / `ImageLoadingSlotCounter` (counterEnabled / counterDisabled) / `ImageLoadingSlotMark` / `ScrollWindowSignpost` / `ImageGridBenchmark` / `MeasurementDestinations` / `PerformanceDriverUITests` / `ImageLoadingSlotUITests` / `ImageLoadingSlotCounterTest`) → tasks 7.x の入口。deviation の計数機構・基準点機構・opt-in の各項に記録済み
- `KsAppContext` / `startup-runtime` 依存 / `MemoryRoundTripScreen.kt` の引数化 / `libs.versions.toml` のコメント / `androidx.test:runner` の追加 / テストの間欠失敗解消 → すべて deviation 記録済み
- `KsImageAccessibilityTests.swift` の SPI スイッチ追加 → deviation 2026-09-08 の 2 項に記録済み (「テストコードに SPI を持ち込む判断はオーナー未確認」も明記)

### UI 変更の検査

- `ui/brief.md` に承認モックの記録あり (`mock/variant-b-bottom-bar.html` を採用、`mock/approved.png`、2026-09-05 オーナー承認)
- 合意済み妥協 3 件 (戻る導線 / 下部バーと画面下端の間 / 2 行目の高さ) を記載
- **2026-09-07 にオーナーが最終承認**した旨が `ui/brief.md:49` と deviation に記載 (verify-001 時点の「最終承認は未取得」は解消)

### テスト実行 (絞り込みなしの全件実行)

`handbook/cross/test-execution.md` の手順で実行し、件数を確認した。iOS は lessons `do-not-run-review-and-verify-on-same-simulator` に従い、**これまで使われていない個体を新規作成**して使用 (`ksn-verify-002` / iPhone 16 Pro / iOS 26.1、検証後に削除)。

| 系統 | コマンド | 結果 |
|---|---|---|
| iOS 本体 | `ios/` で `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,id=<ksn-verify-002>' -configuration Debug` | **Executed 154 tests, with 0 failures** / `** TEST SUCCEEDED **` (17 スイート全 passed。`KsImageAccessibilityTests` 6 件も含めて緑) |
| iOS Sample | `samples/ios/` で `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination <同上>` | **Executed 5 tests, with 0 failures** (`ImageLoadingSlotUITests` 2 / `InteractiveControlUITests` 3。計測ドライバは分離されており含まれない) |
| Android 本体 unit | `android/` で `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` (JDK 17) | **130 tests / 0 failures / 0 errors / 0 skipped** (9 クラス: `KsAppContextTest` 3 / `KsCollectionViewCoreTest` 14 / `KsCollectionViewInteractionTest` 22 / `KsCollectionViewLayoutTest` 30 / `KsCollectionViewPrefetchTest` 7 / `KsCollectionViewPublicApiTest` 5 / `KsImageCacheContractTest` 13 / `KsImagePrefetchWindowTest` 14 / `KsImageTest` 22) |
| Android Sample unit | `samples/android/` で `./gradlew :app:testDebugUnitTest --rerun-tasks` (JDK 17) | **28 tests / 0 failures / 0 errors / 0 skipped** (5 クラス: `ImageGridMeasurementFixtureTest` 5 / `ImageLoadingSlotCounterTest` 7 / `ImageRequestKindTest` 3 / `SampleDemoScreenTest` 9 / `SampleScreenParityTest` 4) |
| Android 実機テスト | `./gradlew :kscollectionview:assembleDebugAndroidTest` → `adb -s <Pixel 6a> install -r -t …` → `adb -s <Pixel 6a> shell am instrument -w jp.kamusoft.kscollectionview.test/androidx.test.runner.AndroidJUnitRunner` | **OK (4 tests)** — `KsImageDeviceDecodeTest` 4 件。基準機 (Pixel 4a) とは別の実機で実行し、実機分岐が Pixel 6a でも通ることを確認 |

コンテキストパッケージの申告 (iOS 154 / iOS Sample 5 / Android 本体 130 / Sample 28 / 実機 4) とすべて一致。

### 「テストが本番の経路を通しているか」の確認

lessons `check-tests-exercise-production-path-before-accepting-green` に従い、中核 Scenario のテストが本番の組み立てを通しているかをテストコードで確かめた。

| 観点 | 確認結果 |
|---|---|
| iOS の先読み | `KsImagePrefetchTests` の「コレクションとの接続」節は本番 `KsCollectionViewController` を `loadViewIfNeeded()` して `UICollectionViewDataSourcePrefetching` を直接呼ぶ — ✅ |
| Android の先読み | `KsCollectionViewPrefetchTest` は本番 `KsCollectionView` を compose し、受け口だけを `LocalKsImageLoading` で差し替える。窓の算術は `KsImagePrefetchWindowTest` に分離 — ✅ |
| iOS のキャッシュ契約 | `displayRequest` / 表示レベルの検査はいずれも本番 `KsImageRequestFactory.prepare` と実 `UIWindow` を通す — ✅ |
| Android のキャッシュ契約 | `display()` が本番 `KsImageRequestFactory.prepare` を通す。共有ローダーを直接使うテストは素の要求 — ✅ |
| **実機分岐 (新規)** | `KsImageDeviceDecodeTest` は本番 `KsCoilImageLoading` と `KsImageRequestFactory.prepare` をそのまま呼ぶ。`displayAfterMemoryPrefetchDecodesOnceInLoader` は共有インスタンスを観測付きに差し替えるが要求経路は本番のまま — ✅。lessons `exercise-device-only-branches-on-real-hardware` が求める「実機で踏む経路を 1 本用意する」を満たしている |
| **実機分岐の限界** | 同テストは `Assume` で「画素がグラフィックス側に置かれる」ことを前提にしており、条件を満たさない実行機では skip に落ちる (テスト自身の doc に明記)。Pixel 6a では 4 件とも実行され `OK (4 tests)` — ⚠️ 実行機依存であることは deviation と同テストの doc に記録済み |
| **例外 1** | `And Sample テスト/ImageRequestKindTest.kt` は本体の要求組み立てが internal のため要求の形を手で組む。本番経路を通らない — ⚠️ deviation 記録済み。**spec の Scenario には対応しないテスト** (観測ログの分類) |
| **例外 2** | iOS のアセットのソースの成功表示が end-to-end で検査できていない — ⚠️ deviation 記録済み |
| **例外 3** | Android の `memoryDestinationAvoidsSecondDecodeWhenPrefetchedPixelsAreReadable` は「画素を読み出せる」条件下でしか成立しない。テスト名と doc がその限定を明示しており、実機側は `KsImageDeviceDecodeTest` が別契約 (落ちない・枠を超えない・デコード 1 回) で押さえる — ⚠️ deviation 記録済み (オーナー判断 C) |

### 実機計測・実機観測でしか成立しない検査

| Scenario | 状況 |
|---|---|
| 画面外へ出た読み込みの取り消し | ローダー内部の取り消し挙動で単体テスト層に観測点が無い。**実機/エミュレータ観測でのみ成立** — 証跡 7.4 で観測済み (完了) |
| 戻ってきたときの再表示 | 単体テスト 2 本 (構成回数 0) に加え、**実機観測 (`Δsized == 0`) が本便で完了** — 両プラットフォーム・両到達点で合格 |
| メモリ到達点の後の表示 (Android 実機) | 実機では SHALL が一時的に破れる。`KsImageDeviceDecodeTest` が「落ちない・枠を超えない・デコード 1 回」の側を実機で固定 — ⚠️ deviation 記録済み |
| 全消去 (Sample) / ローダー付属ビューとの共有 | 証跡で観測済み (完了) |

なお tasks 7.1 / 7.2 / 7.4 / 7.5 の**性能値**は spec のどの Scenario にも対応しない (spec は性能を契約していない)。したがって 7.1 / 7.5 のスクロール絶対基準の不合格は本判定の INVALID 事由に**しない**。

---

## 呼び出し元への申し送り (判定に影響しない観察)

1. **iOS 7.1 / Android 7.5 のスクロール絶対基準が不合格のまま** (iOS 0.00 / 3.94 / 5.54 ms/s、Android ディスク 6.4/6.2 ms・メモリ 4.6/4.4 ms、いずれも再現)。deviation にオーナー判断待ちとして記録されており、証跡には「iOS は対照『大量件数』が 108〜136 ms/s と桁違いに悪く、エンジンの土台側の問題が先にある」旨も記載。完了報告での提示が要る
2. deviation「キャッシュ消去のフェンスの適用範囲」に **「この受容はオーナー未確認 — 完了報告で提示する」** が残っている (verify-001 から未解消)
3. deviation に**オーナー未確認**と明記された項目が他に 2 件: 「`KsImageAccessibilityTests` の SPI 利用」「iOS 7.4 の判定対象を可視 1〜12 に絞った読み方」
4. deviation「未確認: 7.3 Android の実機確認」— ローダー付属ビューとのキャッシュ共有はエミュレータで取った値のみ。実機確認を蒸留前に行うかはオーナー判断
5. `kasane/lessons/inbox/` に本 change 由来の観測が多数積まれている (`exercise-device-only-branches-on-real-hardware` は severity: critical)。蒸留時の昇格判定の対象
6. Android のメモリ計測の合格線が `handbook/android/performance-verification.md` に無く、実装側の解釈で判定している (deviation 記録済み)
