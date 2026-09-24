# Verify 001: image-loading

- 検証日: 2026-09-07
- 対象: 作業ツリーの未コミット変更全体 (`git status --short` / `git diff` / untracked 新規ファイル)
- 基準: `specs/image-loading/spec.md` (13 Requirement / 32 Scenario)
- 合意済みの差分: `deviation.md` (50 件)
- 作業ドメイン: cross (ios + android)

## 判定

**VALID**

全 32 Scenario が「✅ 一致」または「⚠️ deviation 記録済み」。虚偽チェックなし、逆流なし、
テストは 4 系統すべて全件成功。未記録の欠落・乖離は検出されなかった。

---

## 参照の短縮名

| 短縮名 | パス |
|---|---|
| iOS 本体 | `ios/Sources/KsCollectionView/` |
| iOS テスト | `ios/Tests/KsCollectionViewTests/` |
| And 本体 | `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/` |
| And テスト | `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/` |
| And Sample テスト | `samples/android/app/src/test/kotlin/jp/kamusoft/kscollectionview/samples/android/` |
| 証跡 | `kasane/changes/image-loading/evidence/` |

---

## 対応表

### Requirement: プリフェッチ宣言 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| もうすぐ表示されるアイテムの画像を取得する | iOS: `KsCollectionView.swift:231` (`prefetchResources(destination:_:)`) → `KsCollectionViewController.swift:748` → `KsImagePrefetcher.swift:32`<br>And: `KsCollectionView.kt:105-106,145` → `KsImagePrefetchWindow.kt:51` | iOS: `KsImagePrefetchTests.swift` `test先読み対象の項目がURLへ解決されて到達点付きで開始される` / `testシステムの先読み通知で取得が始まり取り消し通知で止まる` (本番 controller の `prefetchItemsAt` を叩く)<br>And: `KsCollectionViewPrefetchTest.kt` `initialWindowPrefetchesVisibleCountAhead` (本番 `KsCollectionView` を compose) | ✅ 一致 |
| 宣言が無ければ何も起きない | iOS: `KsCollectionViewController.swift:160-166` (`syncImagePrefetching` が nil で解決層を作らない)<br>And: `KsCollectionView.kt:143` (`if (prefetchResources != null)` で Effect 自体を組み立てない) | iOS: `KsImagePrefetchTests.swift` `test宣言が無ければ受け口へ何も伝わらない`<br>And: `KsCollectionViewPrefetchTest.kt` `noDeclarationStartsNothing` | ✅ 一致 |
| 複数 URL の宣言 | iOS: `KsImagePrefetcher.swift:104` (`reconcile` が URL 集合を扱う)<br>And: `KsImagePrefetchWindow.kt:144` (`start` が urls を反復) | iOS: `KsImagePrefetchTests.swift` `test1項目に複数のURLを宣言すると両方の取得が始まる`<br>And: `KsImagePrefetchWindowTest.kt` `multipleUrlsPerItemAreAllStarted` | ✅ 一致 |

補足 (SHALL NOT / 付帯条項の検査):
- 「データ型に protocol / interface 準拠を要求しない」: 公開面は `(Item) -> [URL]` / `((Item) -> List<String>)?` の素のクロージャ。`KsPublicAPITests.swift` `testプリフェッチ宣言を到達点付きで組み立てられる` / `KsCollectionViewPublicApiTest.kt` `composesWithPrefetchDeclaration` で確認 — ✅
- 「空配列を返したアイテムは何も取得しない」: iOS `test空の配列を返した項目では何も取得しない` / And `itemsWithoutResourcesStartNothing` — ✅
- 「`destination` の既定は `disk`」: iOS `testプリフェッチ宣言の到達点を省略するとdiskになる` / And `KsCollectionView.kt:106` の既定値 + `prefetchDestinationHasDiskAndMemory` — ✅

### Requirement: プリフェッチの取り消し (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| スクロール方向の反転で取り消される | iOS: `KsCollectionViewController.swift:756` (`cancelPrefetchingForItemsAt`) → `KsImagePrefetcher.swift:41`<br>And: `KsImagePrefetchWindow.kt:121` (`resolveWindow` の進行方向判定) + `:156` (`release`) | iOS: システム通知に委譲 (下の「先読み範囲 (iOS)」で検査)。受け口側は `testシステムの先読み通知で取得が始まり取り消し通知で止まる`<br>And: `KsCollectionViewPrefetchTest.kt` `reversingDirectionCancelsAndRestarts` / `KsImagePrefetchWindowTest.kt` `reversingDirectionCancelsOldWindowAndStartsNewOne` | ✅ 一致 |
| 配列の差し替えで消えたアイテム | iOS: `KsCollectionViewController.swift:131-134` → `KsImagePrefetcher.swift:47` (`retain`)<br>And: `KsImagePrefetchWindow.kt:63-79` (`retained` に無い ID を release) | iOS: `KsImagePrefetchTests.swift` `test配列の差し替えで消えた項目の取得は取り消される`<br>And: `KsCollectionViewPrefetchTest.kt` `replacingItemsCancelsRemovedItem` / `KsImagePrefetchWindowTest.kt` `replacingItemsCancelsRequestsForRemovedItems` | ✅ 一致 |
| 共有 URL は最後のアイテムが外れるまで取り消さない | iOS: `KsImagePrefetcher.swift:122-142` (参照数 acquire / release)<br>And: `KsImagePrefetchWindow.kt:33` (`Request.referenceCount`) | iOS: `test共有URLは最後の項目が外れるまで取り消さない`<br>And: `KsImagePrefetchWindowTest.kt` `sharedUrlIsCancelledOnlyAfterLastItemLeaves` | ✅ 一致 |
| 画面から消えたら全て取り消す | iOS: `KsCollectionViewController.swift:154-158` (`disconnect` → `cancelAll`)<br>And: `KsImagePrefetchWindow.kt:194` (`DisposableEffect` の `onDispose` → `disposeAll`) | iOS: `test画面から消えたときに未完了の取得をすべて取り消す`<br>And: `KsCollectionViewPrefetchTest.kt` `leavingCompositionDisposesAll` | ✅ 一致 |

補足:
- 「取り消しは進行中の取得にのみ作用し、完了してキャッシュに入ったものは消さない」: iOS は `ImagePrefetcher.stopPrefetching`、And は `Disposable.dispose` へ写像。`KsImageCacheContractTest.kt` `diskDestinationStoresDataWithoutDecodingOrRefetching` 等が「取り消し後もキャッシュから表示できる」側を検査 — ✅
- 「クロージャと `destination` は差し替えても以後の新しい取得にだけ反映」: iOS `KsCollectionViewController.swift:172-175`、And `KsImagePrefetchWindow.kt:185-187` (`rememberUpdatedState`)。台帳の再解決により「次の通知・配列更新の時点で旧 URL を止めて新 URL へ切り替わる」挙動になった点は `deviation.md`「先読み宣言のクロージャの呼び出し回数」で記録済み — ⚠️ deviation 記録済み

### Requirement: プリフェッチの到達点 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| ディスク到達点の後の表示 | iOS: `KsNukeImageLoading.swift:52` (`.diskCache`)<br>And: `KsCoilImageLoading.kt:28-38` (`memoryCachePolicy(DISABLED)` + `BlackholeDecoder`) | iOS: `KsImageCacheContractTests.swift` `testディスク到達点の後の表示ではネットワークが走らない` (URLProtocol スタブ + デコード計数、表示は本番 `KsImageRequestFactory.prepare` の要求)<br>And: `KsImageCacheContractTest.kt` `diskDestinationStoresDataWithoutDecodingOrRefetching` (`display()` が本番 `KsImageRequestFactory.prepare` を通す) | ✅ 一致 |
| メモリ到達点の後の表示 | iOS: `KsNukeImageLoading.swift:53` (`.memoryCache`) + `KsImageRequestFactory.swift:73-80` (元寸から同期縮小)<br>And: `KsCoilImageLoading.kt:39` + `KsImageRequestFactory.kt:96-106` | iOS: `testメモリ到達点の後の表示では再デコードしない` / `test表示の要求はメモリ到達点の先読み結果を再デコードせずに使う`<br>And: `memoryDestinationAvoidsSecondDecode` | ✅ 一致 |
| 到達点が伝わる | iOS: `KsImagePrefetcher.swift:147-154` (`apply` → `loading.prefetch(urls:destination:)`)<br>And: `KsImagePrefetchWindow.kt:144-155` | iOS: `test到達点memoryの宣言はmemoryとして受け口へ届く`<br>And: `KsCollectionViewPrefetchTest.kt` `destinationReachesLoader` / `KsImagePrefetchWindowTest.kt` `destinationIsPassedThroughToLoader` | ✅ 一致 |

補足:
- 「ライブラリ独自のキャッシュ領域を持たない」: iOS は `ImagePipeline.shared`、And は `SingletonImageLoader.get(context)`。`KsImageCacheContractTest.kt` `requestsMadeDirectlyOnTheSharedLoaderReuseThePrefetchedData` が `assertSame` で共有インスタンスであることを検査 — ✅
- 縮小済み画像を共有ローダーのメモリへ書き足す設計 (項目数が「表示サイズ × 当てはめ方」ぶん増える) は `deviation.md`「縮小済み画像を共有ローダーのメモリへ書く」で記録済み — ⚠️ deviation 記録済み

### Requirement: プリフェッチの先読み範囲 (Android) (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 可視件数と同数を先読みする | `KsImagePrefetchWindow.kt:121-141` (`resolveWindow`) | `KsCollectionViewPrefetchTest.kt` `initialWindowPrefetchesVisibleCountAhead` (可視 6 件 → 直後の 6 件。本番 `KsCollectionView` 経由)<br>`KsImagePrefetchWindowTest.kt` `initialWindowFollowsForwardWithVisibleCount` / `windowStopsAtTheEndOfItems` | ✅ 一致 |
| 進行方向へ移動すると窓が進む | `KsImagePrefetchWindow.kt:63-79` (可視範囲のアイテムは台帳に残し取り消さない) | `KsCollectionViewPrefetchTest.kt` `scrollingForwardAdvancesWindow`<br>`KsImagePrefetchWindowTest.kt` `forwardScrollAdvancesWindowWithoutCancellingItemsEnteringViewport` | ✅ 一致 |

補足: 「静止時は直前の進行方向を保つ」「初期表示は末尾方向」は `stationaryViewportKeepsPreviousDirection` / `initialWindowFollowsForwardWithVisibleCount` で検査 — ✅

### Requirement: プリフェッチの先読み範囲 (iOS) (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| システムの先読み通知に従う | `KsCollectionViewController.swift:191` (`prefetchDataSource = self`) / `:748` / `:756` | `KsImagePrefetchTests.swift` `testシステムの先読み通知で取得が始まり取り消し通知で止まる` (本番 `KsCollectionViewController` を `loadViewIfNeeded` して `UICollectionViewDataSourcePrefetching` のメソッドを直接呼ぶ) | ✅ 一致 |

### Requirement: 共有キャッシュ (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| ローダー付属ビューとキャッシュを共有する | iOS: `KsNukeImageLoading.swift:30-35` (識別子を付けない素の要求)<br>And: `KsCoilImageLoading.kt:39` (寸法なしの素の要求) | iOS: `KsImageCacheContractTests.swift` `testローダーを直接使う素の要求と同じキャッシュ項目を共有する`<br>And: `KsImageCacheContractTest.kt` `requestsMadeDirectlyOnTheSharedLoaderReuseThePrefetchedData`<br>実機/エミュレータ: `証跡/image-behavior-observation.md` 7.3 (tasks 7.3 完了) | ✅ 一致 |
| iOS のディスクキャッシュ有効化 | `KsImagePipeline.swift:37` (`enableSharedDiskCache()` — **利用者が明示的に呼ぶ公開 API**) | `KsImagePipelineTests.swift` 4 件 (未設定なら差し替え / 設定済みなら不変 / 独自 DataLoader の引き継ぎ / 二度呼んでも保つ) — いずれも本番 API を呼ぶ | ⚠️ deviation 記録済み |

deviation の内容: spec は「ライブラリの初回利用時に自動で差し替える」だが、Nuke 13.2.0 が共有パイプラインの `delegate` を外から読めないため、**明示 API を 1 つ設けて呼ばれたときだけ差し替える**形に変更 (オーナー判断)。既知の副作用 2 件 (delegate が既定に戻る / 表示開始後に呼んでも既存コレクションに反映されない) も deviation と公開 doc に記載済み。`enableSharedDiskCache()` のディスクキャッシュ作成失敗経路がテスト未到達である点も deviation に記録済み。

### Requirement: KsImage の画像ソース (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 3 種のソースを表示する | iOS: `KsImageSource.swift` + `KsImage.swift:88-107` (asset は `UIImage(named:)`、remote/file は `LazyImage`)<br>And: `KsImageSource.kt` + `KsImage.kt:80-95` (Resource は `drawablePainter`、他は loader) | iOS: `KsImageDisplayTests.swift` `testリモートのソースは画像が表示される` / `testファイルのソースは画像が表示される` (実表示・中心色一致)、`testバンドル済みリソースのソースはローダーを通らずに表示が決まる`<br>And: `KsImageTest.kt` `threeSourceKindsAreDisplayed` (実 compose・3 種すべて成功表示) | ⚠️ deviation 記録済み (iOS のアセットのみ) |
| 便宜形 | iOS: `KsImage.swift:57-64` ほか `KsImage(url)` 系 init<br>And: `KsImage.kt:117` (`KsImage(url: String, ...)`) | iOS: `KsImageTests.swift` `test便宜形はリモートのソースと同じ宣言になる` + `KsPublicAPITests.swift` `test読み込み中と失敗の表示は片方だけでも差し替えられる`<br>And: `KsImageTest.kt` `urlConvenienceFormBehavesLikeRemoteSource` | ✅ 一致 |

deviation の内容: **iOS のアセットのソースの「成功表示」は end-to-end で検査できていない** (SwiftPM のテストプロセスでは `Bundle.main` が Xcode のディレクトリを指すため本番の解決経路が引けない)。代わりに「解決できない名前 → 失敗表示」「ローダーを通らない」を実表示で検査。Android は実リソースで通っており、この 1 点だけ非対称 — `deviation.md` に記録済み。

補足: Android の `KsImageSource.Resource` を Coil ではなく `painterResource` 相当 (`context.getDrawable` → painter) の同期経路にした点、および読めないリソース ID を debug で停止させる扱いも `deviation.md` に記録済み。図形 (shape) 形式の直接テストが無い点も記録済み — ⚠️ deviation 記録済み

### Requirement: KsImage の表示状態 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 読み込み中から成功へ | iOS: `KsImage.swift:112-146` (`prepare` が nil / cachedImage が nil のとき `loadingContent`)<br>And: `KsImage.kt:176-227` (`AsyncImagePainter.State` と `cachedHolder`) | iOS: `KsImageDisplayTests.swift` `testリモートのソースは画像が表示される` (空キャッシュから成功表示まで)。逆側 (メモリにあれば読み込み中を経由しない) は `KsImageCacheContractTests.swift` `test読み込み中のスロットはメモリにある画像では一度も構成されない`<br>And: `KsImageTest.kt` `slotsAreSubstituted` (Hang 挙動で読み込み中が出る) / `loadingSlotIsNeverComposedWhenTheImageIsAlreadyInMemory`<br>実機: `証跡/image-behavior-loading-failure-{ios,android}.png` | ✅ 一致 |
| 失敗時の表示 | iOS: `KsImage.swift:127-128` (`state.error != nil` → `failureContent`) / `:104` (asset 解決失敗)<br>And: `KsImage.kt:210-211` (`State.Error`) / `:243-246` (リソース解決失敗) | iOS: `KsImageDisplayTests.swift` `testバンドル済みリソース…` (失敗スロットの色を実描画で確認) / `KsImageAccessibilityTests.swift` `test説明を付けた画像は失敗の状態でもその説明を読み上げる` (既定の失敗表示を実表示で確認)<br>And: `KsImageTest.kt` `failureSlotIsShownWhenLoadingFails` / `defaultDisplayIsUsedWithoutSlots` / `resourcesThatCannotBeDrawnFallBackToTheFailureSlot`<br>実機: `証跡/image-behavior-loading-failure-{ios,android}.png` | ✅ 一致 |
| 失敗後の再試行 | iOS: `KsImage.swift:140` (`.id(reloadToken)` とビュー再生成)<br>And: `KsImage.kt:146` (`key(source, reloadToken)`) | iOS: `KsImageTests.swift` `test失敗した表示はビューが作り直されると再び取得を試みる` (失敗パイプラインで実表示・要求 2 回)<br>And: `KsImageTest.kt` `failedImageIsRetriedWhenTheViewIsRecreated` | ✅ 一致 |
| スロットの差し替え | iOS: `KsImage.swift:148-162` + 各 init overload<br>And: `KsImage.kt:74-75` (`loading` / `failure` 引数) | iOS: `KsPublicAPITests.swift` `test読み込み中と失敗の表示は片方だけでも差し替えられる` (4 組 × 便宜形) + `KsImageDisplayTests.swift` (失敗スロットの実描画)<br>And: `KsImageTest.kt` `slotsAreSubstituted` / `defaultDisplayIsUsedWithoutSlots` / `KsCollectionViewPublicApiTest.kt` `imageSlotsCanBeSubstitutedIndependently` | ✅ 一致 |

補足 (Requirement 本文の付帯条項):
- 「メモリキャッシュにあれば読み込み中を経由せず成功になる」と「枠のサイズが確定するまでは読み込み中の表示を出す」の 2 文が衝突する局面 (サイズ未確定かつメモリに画像あり) で**後者を優先**した点は `deviation.md`「spec 内の 2 文の衝突」で記録済み — ⚠️ deviation 記録済み
- 「リソースは読み込み中を経由せず成功か失敗になる」: iOS は `UIImage(named:)`、And は `drawablePainter` の同期経路。Android で design (Coil 経由) から外れた点は `deviation.md` に記録済み — ⚠️ deviation 記録済み
- 「同じビューが表示され続けている間は自動で再試行しない」: `reloadToken` / `key(...)` が変わらない限り再構成されないことで担保。`loadingSlotIsNeverComposedWhenTheDisplayIsRebuilt` の「作り直した表示で取得をやり直さない」アサートが裏側から支える — ✅
- Android の「メモリ上の小さい画像を数フレームだけ拡大表示する」帰結は `deviation.md` に記録済み (実機での見え方は未確認) — ⚠️ deviation 記録済み

### Requirement: KsImage の当てはめ方 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| fit と fill | iOS: `KsImage.swift:80-85` (`clipped()`) + `KsImageRequestFactory.swift:139-150` (`thumbnailContentMode`)<br>And: `KsImage.kt:79` (`clipToBounds`) + `KsImageRequestFactory.kt:128-131` (`toCoilScale`) | iOS: `KsImageTests.swift` `test表示枠と当てはめ方から決まる縮小指定が付く` / `test枠より大きい画像は当てはめ方に応じた寸法へ縮小される` / `test当てはめ方の既定はfillになる`<br>And: `KsImageTest.kt` `contentModeMapsToContentScale` / `imagesLargerThanTheFrameAreDownscaledBeforeBeingDisplayed` / `KsCollectionViewPublicApiTest.kt` (既定値) | ✅ 一致 |

補足: 既定が `fill` であること、`fill` のはみ出しが表示されないこと (`clipped()` / `clipToBounds()`) を実装側で確認。視覚面は `ui/verification/image-grid-normal-{ios,android}.png` と `ui/brief.md` の照合記録が補う。

### Requirement: KsImage の縮小デコード (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 枠より大きい画像 | iOS: `KsImageRequestFactory.swift:114-127` (`displayRequest` の `ThumbnailOptions`) / `:73-80` (元寸からの同期縮小)<br>And: `KsImageRequestFactory.kt:59-108` (`size` + `Precision.EXACT` + `downscale`) | iOS: `KsImageTests.swift` `test枠より大きい画像は当てはめ方に応じた寸法へ縮小される` / `test元寸から縮小する経路でも当てはめ方に応じた寸法になる` / `test表示に使う要求の鍵は元寸の有無で変わらない`<br>And: `KsImageTest.kt` `imagesLargerThanTheFrameAreDownscaledBeforeBeingDisplayed` | ⚠️ deviation 記録済み |
| サイズ確定前は取得しない | iOS: `KsImageRequestFactory.swift:95-105` (`makeContext` が 0 で nil) → `KsImage.swift:142` (`loadingContent`)<br>And: `KsImageRequestFactory.kt:67` (`width <= 0 \|\| height <= 0` で null) → `KsImage.kt:157-159` | iOS: `KsImageTests.swift` `testサイズが確定するまで要求を発行しない`<br>And: `KsImageTest.kt` `noRequestIsBuiltBeforeTheFrameSizeIsSettled` | ✅ 一致 |

deviation の内容 (いずれも記録済み):
- iOS の `fit` の縮小指定を `maxPixelSize` から `ThumbnailOptions` の `.aspectFit` / `.aspectFill` に変更
- 縮小手段の選び分け (元寸がメモリにあるか) と、レビュー 3 周目での**表示要求 1 本化**
- Android の表示要求のキャッシュ鍵にローダー内部の付随情報名 `coil#size` を使い、当てはめ方の区別に自前の `ks#scale` を併用
- Android の枠の読み取りを `rememberConstraintsSizeResolver()` から `BoxWithConstraints` に変更 (subcomposition が 1 段増える。10,000 件での実測は未実施)
- 到達点メモリの先読みと表示の継ぎ目を「元寸を同期で引き当て、その場で縮小して初回描画に使う」形に両プラットフォームで揃えた件、およびその同期縮小の費用

### Requirement: KsImage の読み込み取り消しとメモリ保持 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 画面外へ出た読み込みの取り消し | iOS: `KsImage.swift:118` (`LazyImage` が消滅時に取り消す)<br>And: `KsImage.kt:178` (`rememberAsyncImagePainter` が composition 離脱時に取り消す) | 実機/エミュレータ: `証跡/image-behavior-observation.md` 7.4「取り消し」表 (iOS 表示要求 取消 53 件 / Android 表示要求 取消 3 件。Android は回線を絞って取り消しが起きる状況を作ってから観測) | ✅ 一致 (**検査は実機観測でのみ成立**) |
| 戻ってきたときの再表示 | iOS: `KsImageRequestFactory.swift:49-83` (表示要求の鍵を 1 本にし、自分が書いた項目を次の表示が引き当てる)<br>And: `KsImageRequestFactory.kt:70-80` (`displayKey`) | iOS: `KsImageCacheContractTests.swift` `test一度表示した画像は表示を作り直しても読み込み中を経由しない` (読み込み中スロットの**構成回数 0** を直接数える)<br>And: `KsImageTest.kt` `loadingSlotIsNeverComposedWhenTheDisplayIsRebuilt` (同上)<br>実機: **未確認** (`証跡/image-behavior-observation.md` が理由と再測手順つきで明記、tasks 7.4 未チェック) | ✅ 一致 (テスト層)<br>実機確認は合意済みの未実施 |

補足:
- 「メモリキャッシュから追い出された画像はディスク／ローカルから再デコードされる」は `testメモリのみ消去してもディスクの元データから再デコードできる` / `clearingMemoryKeepsDiskDataForRedecoding` が担保 — ✅
- 「画面外へ出た読み込みの取り消し」は**ローダー内部の取り消し挙動**であり、単体テスト層で本番経路を通して観測する手段が無いため、実機観測 (tasks 7.4 の前半) が唯一の検査になっている。この前半は証跡で完了しており、未実施なのは後半 (戻りの再表示) のみ。

### Requirement: キャッシュのクリア (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 全消去の後の表示 | iOS: `KsImageCache.swift:24-42` (`clear(.all)` → `removeAll(.all)` + `invalidateAll`)<br>And: `KsImageCache.kt:35-53` | iOS: `KsImageCacheContractTests.swift` `test全消去の後の表示はメモリに当たらず取り直しになる` / `test表示中のKsImageは全消去で取得をやり直す` (実表示を窓に載せて取り直しを観測)<br>And: `KsImageCacheContractTest.kt` `clearingAllAlsoInvalidatesTheDecodedMemoryImage` / `KsImageTest.kt` `clearMapsToLoaderCachesAndAdvancesGenerationExceptForMemory` / `removeMakesTheDisplayedImageReload`<br>実機: `証跡/image-behavior-observation.md`「キャッシュを消去」の後の再取得 | ✅ 一致 |
| メモリのみ消去 | iOS: `KsImageCache.swift:36-37`<br>And: `KsImageCache.kt:46` | iOS: `testメモリのみ消去してもディスクの元データから再デコードできる`<br>And: `clearingMemoryKeepsDiskDataForRedecoding` | ✅ 一致 |
| ソース単位の削除 | iOS: `KsImageCache.swift:47-73` (世代を進める)<br>And: `KsImageCache.kt:57-92` (鍵一致でメモリ走査 + `diskCache.remove`) | iOS: `testソース単位の削除では対象のソースだけが消える` / `KsImageTests.swift` `testソース単位の削除は対象のソースの識別子だけを変える`<br>And: `removeDeletesOnlyTheTargetSource` / `removeKeepsAnotherSourceWhoseKeySharesThePrefix` / `KsImageTest.kt` `removeAffectsOnlyTheTargetSource` | ✅ 一致 |
| 削除後は別サイズでも旧項目に当たらない (iOS) | `KsImageIdentity.swift` + `KsImageRequestFactory.swift:100` (`imageID` を要求に付与) | `KsImageTests.swift` `test削除後はどの表示サイズの要求も削除前の項目に当たらない` (複数サイズで検査) | ✅ 一致 |

deviation (いずれも記録済み) — ⚠️:
- **消去範囲の選択肢を 3 択 (`memory` / `disk` / `all`) から 2 択 (`memory` / `all`) に変更** (オーナー判断)。`.disk` と `.all` の実挙動が同一になったため。対応する Scenario は存在しないため、対応表の欠落にはならない
- `clear(.disk)` がメモリ項目も落とす実挙動 (上記の前提)
- キャッシュ消去時のフェンスの限界 (取り消しとキャッシュ書き込みが同時に起きた場合の書き戻しは防げない / 消去後は次に可視範囲が動くまで先読みは再開しない)
- **フェンスの適用範囲を先読み層の進行中取得のみに限定** (表示中の `KsImage` の取得は対象外)。Coil 3.5.0 に公開の取り消し口が無いため両プラットフォームで揃えた。deviation に「**この受容はオーナー未確認**」と明記されている
- Android のキャッシュ操作が未初期化時に警告ログ + no-op になる件 (「呼び出しから戻った時点で削除が完了している」の例外。公開 doc にも記載)
- Android の `remove` のキャッシュ鍵の導出が、リモート以外は best-effort である件
- `KsAppContext.reset()` をテスト専用に追加した件

追加検査 (Requirement 本文の SHALL NOT):
- 「`clear` は共有に影響しない」: `clear(.all)` は `KsImageInvalidation.globalGeneration` (表示側の再構成トリガ) だけを進め、要求に載る `imageID` は変えない。`KsImageIdentity.imageID` は `remove` でのみ世代が進む (`KsImageTests.swift` `test全消去は世代を進めメモリのみ消去は進めない` + `testソース単位の削除は対象のソースの識別子だけを変える`) — ✅
- 「iOS のアセットに対する `remove` は何もしない」: `KsImageCache.swift:48` の guard。`testアセットの削除は何もしない` — ✅

### Requirement: Sample のデモ画面「画像グリッド」 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 切り替えの反映 | iOS: `samples/ios/KsCollectionViewSamples/ImageGridDemoView.swift` + `ImageGridFixture.swift` + `ImagePrefetchChoice.swift`<br>And: `samples/android/.../ImageGridDemoScreen.kt` + `ImageGridFixture.kt` + `ImagePrefetchChoice.kt` | And: `And Sample テスト/SampleDemoScreenTest.kt` `画像グリッド画面のプリフェッチの初期選択はディスクまでである` (3 択の選び直し) + `ImageGridMeasurementFixtureTest.kt` `プリフェッチの宣言は到達点を選ばないときだけ無い` (「なし」→ 宣言なし / 「ディスクまで」→ 宣言あり)<br>本体側: 「宣言あり → 先読み開始」「宣言なし → 何も起きない」は上の 2 Requirement で検査済み<br>ローダーのログ: `証跡/image-behavior-observation.md` 7.4 (Sample「画像グリッド」・到達点ディスクで先読み 42 件開始) | ✅ 一致 |
| 全消去 | iOS: `ImageGridDemoView.swift` の `KsImageCache.clear(.all)`<br>And: `ImageGridDemoScreen.kt` の `KsImageCache.clear(KsImageCacheScope.All)` | 実機/エミュレータ: `証跡/image-behavior-observation.md`「キャッシュを消去」の後の再取得 (iOS 15 件がネットワークから再取得 / Android は可視セルが読み込み中の既定表示に戻る静止画 `image-grid-after-cache-clear-android.png`) | ✅ 一致 |

補足:
- sample-parity: `SampleScreenParityTest.kt` が「画像グリッド」の追加とデモ画面 10 件を検査。文言・件数・列数・初期選択は両 Sample のソースで一致を確認 (「プリフェッチ · 10,000 件 · 3 列」「なし / ディスクまで / メモリまで」「キャッシュを消去」、初期値「ディスクまで」、10,000 件・3 列)
- URL の決定性: `DemoData.imageUrl(id)` / `DemoData.imageURL(for:)` がともに `https://picsum.photos/seed/ks-<id>/400/400`。選定記録は `証跡/placeholder-image-service.md`
- 「切り替えの反映」の THEN にある「ローダーのログで確認できる」は、デモ画面での**「なし」→「ディスクまで」の切り替え前後の対比**としては証跡に残っていない (証跡は到達点ディスクの状態での先読み件数を記録)。挙動そのものはテスト 2 層 (Sample の宣言有無 + 本体の宣言あり/なし) で担保されているため一致とした
- 計測入口の土俵一致の担保が非対称 (Android は静的テスト、iOS は組み立て関数の 1 本化) である点は `deviation.md` に記録済み — ⚠️

---

## 追加検査

### tasks.md の完了状態と虚偽チェック

| 項目 | 結果 |
|---|---|
| チェック済みタスクの裏付け | 8.1 まで全 [x] タスクについて実装・証跡を確認。**虚偽チェックなし** |
| 未チェックタスク | 7.1 / 7.2 / 7.4 / 7.5 (実機計測)。証跡ファイル (`image-grid-measurement-ios.md` / `performance-regression-android.md` / `image-grid-measurement-android.md` / `image-behavior-observation.md`) にも「未実施」「合格の判定に未達」「未確認」と一致して書かれている。**tasks の状態と証跡の記述が食い違っていない** |

個別確認:
- 1.3 → `証跡/dependency-requirements.md` あり
- 1.4 → `証跡/placeholder-image-service.md` あり (identity lint はホスト追加不要と判断し、実行して 0 件を確認した旨を記録)
- 6.3 → `ui/verification/` に両プラットフォームの最終周スクリーンショット、`ui/brief.md` に照合記録 (2 周) あり
- 6.4 → `kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md` を更新済み
- 7.3 → `証跡/image-behavior-observation.md` 7.3 節あり
- 8.1 → `証跡/user-notes-source.md` あり

### 逆流検査 (足場アーティファクトの書き換え)

- `proposal.md` / `design.md` / `specs/image-loading/spec.md` はいずれも `git diff` で差分なし。最終更新は提案化コミット `f7a2aed`。**逆流なし**
- `tasks.md` (進捗チェック) と `ui/brief.md` (照合結果の追記) の変更は、実装フェーズで書き足すことが規約上想定されている箇所であり、契約 (spec) の書き換えではない

### 未記録乖離の洗い出し

対応表に ❌ はなく、**未記録乖離は検出されなかった**。

diff にあって Scenario に対応しない変更のうち、`deviation.md` の `[付随修正]` にも tasks にも載っていないものは
`kasane/handbook/cross/runtime-behavior-verification.md` の観測点表への追記 1 件のみ。これは
**レビュー指摘由来** (`review-001.md` Minor 1 → `review-002.md` で解消確認) であり、来歴が変更フロー内で
追跡できるため未記録乖離としない。

その他の Scenario 非対応の変更はすべて来歴が追える:
- 計測・観測の足場 (`ImageGridMetrics` / `ImageLoadingObserver` / `ImageBehaviorVerificationScreen` / `PerformanceFixture` / `ImageGridBenchmark` / `MeasurementDestinations` / `MeasurementTarget` / `PerformanceDriverUITests` ほか) → tasks 7.x の入口
- `MemoryRoundTripScreen.kt` の引数化 → `deviation.md` に `[付随修正]` として記録済み
- `KsAppContext` / `KsAppContextInitializer` / 本体 `AndroidManifest.xml` / `startup-runtime` 依存 → `deviation.md`「Android の `KsImageCache` のシグネチャと本体の依存」に記録済み
- テストの間欠失敗の解消・後始末の追加 (iOS `KsImageCacheContractTests` / `KsImageTests`、Android `KsAppContextTest` / `KsImageCacheContractTest`) → いずれも `[付随修正]` として記録済み
- `libs.versions.toml` のコメント修正 → `[付随修正]` として記録済み

### UI 変更の検査

- `ui/brief.md` に承認モックの記録あり (`mock/variant-b-bottom-bar.html` を採用、`mock/approved.png`、2026-09-05 オーナー承認)
- 合意済み妥協が「合意済み差分 (プラットフォーム制約)」節に 3 件記載 (戻る導線 / 下部バーと画面下端の間 / 2 行目の高さ)
- 「未撮影の状態」節に、読み込み中・失敗の既定表示が Sample 画面上では撮影できていない旨と、その担保 (ライブラリのテスト) が明記されている
- **`ui/brief.md` に「オーナーの最終承認は未取得」と明記**されている (実装側の照合まで)。これは verify の対象ではなく、完了報告での提示事項

### テスト実行 (絞り込みなしの全件実行)

`handbook/cross/test-execution.md` の手順で実行し、件数を確認した。

| 系統 | コマンド | 結果 |
|---|---|---|
| iOS 本体 | `ios/` で `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,id=<iPhone 17 Pro / iOS 26.0.1>' -configuration Debug` | **Executed 154 tests, with 0 failures** / `** TEST SUCCEEDED **` |
| iOS Sample | `samples/ios/` で `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination <同上>` | **Executed 3 tests, with 0 failures** (計測ドライバは分離されており件数に含まれない) |
| Android 本体 | `android/` で `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` (JDK 17) | **129 tests / 0 failures / 0 errors** (9 クラス: `KsAppContextTest` 3 / `KsCollectionViewCoreTest` 14 / `KsCollectionViewInteractionTest` 22 / `KsCollectionViewLayoutTest` 30 / `KsCollectionViewPrefetchTest` 7 / `KsCollectionViewPublicApiTest` 5 / `KsImageCacheContractTest` 12 / `KsImagePrefetchWindowTest` 14 / `KsImageTest` 22) |
| Android Sample | `samples/android/` で `./gradlew :app:testDebugUnitTest --rerun-tasks` (JDK 17) | **21 tests / 0 failures / 0 errors** (4 クラス: `ImageGridMeasurementFixtureTest` 5 / `ImageRequestKindTest` 3 / `SampleDemoScreenTest` 9 / `SampleScreenParityTest` 4) |

コンテキストパッケージの申告 (iOS 154 / iOS Sample 3 / Android 129 / Android Sample 21) と一致。

### 「テストが本番の経路を通しているか」の確認

コンテキストパッケージの指摘を受け、主要 Scenario のテストが本番の組み立てを通しているかを個別に確認した。

| 観点 | 確認結果 |
|---|---|
| iOS の先読み | `KsImagePrefetchTests` の「コレクションとの接続」節は本番 `KsCollectionViewController` を `loadViewIfNeeded()` して `UICollectionViewDataSourcePrefetching` のメソッドを直接呼ぶ。受け口だけをテストする節と分かれている — ✅ |
| Android の先読み | `KsCollectionViewPrefetchTest` は本番 `KsCollectionView` を compose し、受け口だけを `LocalKsImageLoading` で差し替える。窓の算術単体は `KsImagePrefetchWindowTest` に分離 — ✅ |
| iOS のキャッシュ契約 | `displayRequest` / `displayedImageExists` はいずれも本番 `KsImageRequestFactory.prepare` を通す。表示レベルの検査は実 `UIWindow` に `KsImage` を載せる — ✅ |
| Android のキャッシュ契約 | `display()` が本番 `KsImageRequestFactory.prepare` を通す (`deviation.md` に「表示の検査を本番の組み立て経由に変更し手書きの複製を廃止した」と記録あり)。共有ローダーを直接使うテストは素の要求を使う — ✅ |
| Android の起動時初期化 | `installKsAppContext` は本番 `KsAppContextInitializer` を `AppInitializer` 経由で動かす (Robolectric が ContentProvider を作らないための明示起動) — ✅ |
| **例外 1** | `And Sample テスト/ImageRequestKindTest.kt` は、本体の要求組み立てが internal で Sample から呼べないため**要求の形を手で組んでいる**。本番経路を通らないため本体側の形が変わると緑のまま実態を映さなくなる。テストの doc にその旨が明記されており、`deviation.md`「観測ログの分類のテストがプラットフォーム間で非対称」に記録済み — ⚠️ deviation 記録済み。なおこれは**観測ログの分類**のテストであり、spec の Scenario に対応するテストではない |
| **例外 2** | iOS のアセットのソースの成功表示が end-to-end で検査できていない (`deviation.md` 記録済み) — ⚠️ |

### 実機計測でしか成立しない検査

コンテキストパッケージの指示に従い、「Scenario に対応する検査が実機計測 (または実機観測) でしか成立しないもの」を明記する。

| Scenario | 状況 |
|---|---|
| 画面外へ出た読み込みの取り消し | ローダー内部の取り消し挙動であり、単体テスト層に本番経路の観測点が無い。**実機/エミュレータ観測でのみ成立** — `証跡/image-behavior-observation.md` 7.4 で観測済み (完了) |
| 戻ってきたときの再表示 | 単体テスト 2 本 (iOS / Android) が読み込み中スロットの構成回数 0 を直接数えており、**テスト層では成立している**。実機観測は tasks 7.4 の未実施分 (合意済み) |
| 全消去 (Sample) | 「表示中の画像が読み込み中を経由して再取得される」ことの Sample 画面上の確認は実機観測でのみ成立 — 証跡で観測済み (完了) |
| ローダー付属ビューとキャッシュを共有する | テスト層でも成立 (両プラットフォーム)。実機観測も tasks 7.3 で完了 |

なお、tasks 7.1 / 7.2 / 7.4 / 7.5 の**性能計測**は spec のどの Scenario にも対応しない (spec は性能値を契約していない)。したがって未計測は本判定の INVALID 事由に**しない**。

---

## 呼び出し元への申し送り (判定に影響しない観察)

verify の判定には影響しないが、蒸留・完了報告で扱うべき事項として記録する。

1. `deviation.md`「キャッシュ消去のフェンスの適用範囲」に **「この受容はオーナー未確認 — 完了報告で提示する」** と書かれている。完了報告で提示されているか確認が要る
2. `ui/brief.md` の照合結果に **「オーナーの最終承認は未取得」** と書かれている
3. `deviation.md`「Android のメモリ計測の合格線」に、`handbook/android/performance-verification.md` に閾値が無く実測後にオーナー判断が要る可能性がある旨が記録されている
4. `kasane/lessons/inbox/` に本 change 由来の観測が 5 件 (`check-sibling-contracts-when-fixing-a-review-finding` / `check-tests-exercise-production-path-before-accepting-green` / `do-not-stash-to-compare-before-and-after` / `verify-external-api-visibility-before-writing-it-into-design` / `wait-for-idle-in-robolectric-compose-tests`) 積まれている。蒸留時の昇格判定の対象
