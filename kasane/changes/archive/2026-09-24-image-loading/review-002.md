# レビュー結果: image-loading (002 回目)

**日付**: 2026-09-07
**判定**: CHANGES_REQUESTED

## サマリー

1 周目の指摘 (ホスト 7 件・相方 10 件、突き合わせ後の修正対象 Major 6 / Minor 7 / Suggestion 1) は、
**確認できた範囲ですべて解消していた**。特に相方の Major 1〜6 は、いずれも「テストが実経路を通っていない」
という指摘の中身まで含めて直っており、再現テスト (縮小指定付きの実要求で数える / 応答を保留できるスタブで
消去と完了の順序を作る / 読み込み中スロットの構成回数を数える / 土俵の一致を実際に描いて確かめる) が
追加されている。両プラットフォームのビルド・全テスト・lint も緑 (件数は下記)。

一方で、**相方 Major 1 (iOS の再デコード) と Major 4 (Android の読み込み中) の修正が、同じ継ぎ目
「到達点 `memory` の先読み → `KsImage` の表示」をプラットフォームごとに別の向きへ倒しており、
それぞれ反対側の契約を落としている**。Android は元寸のまま表示して縮小デコードの契約を落とし、iOS は
読み込み中を経由して表示状態の契約を落とす。どちらも deviation.md に記録が無く、どちらもテストが無い
(そして Android の既存テストは、落ちた側を検査しない形で緑になっている)。この 2 件を Major として
CHANGES_REQUESTED とする。

## 実行したビルドとテスト

| 対象 | コマンド | 結果 |
|---|---|---|
| iOS 本体 | `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,id=<iPhone 17 Pro>' -configuration Debug` | **Executed 139 tests, with 0 failures** (前周 129 → +10) |
| iOS Sample | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples` | **Executed 3 tests, with 0 failures** (計測ドライバは含まれず分離が効いている) |
| Android 本体 | `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` | **116 tests / 0 failures / 0 skipped** (9 クラス。前周 108 → +8。内訳: `KsAppContextTest` 3 / `KsCollectionViewCoreTest` 14 / `KsCollectionViewInteractionTest` 22 / `KsCollectionViewLayoutTest` 30 / `KsCollectionViewPrefetchTest` 7 / `KsCollectionViewPublicApiTest` 5 / `KsImageCacheContractTest` 10 / `KsImagePrefetchWindowTest` 12 / `KsImageTest` 13) |
| Android Sample | `./gradlew :app:testDebugUnitTest --rerun-tasks` | **18 tests / 0 failures / 0 skipped** (3 クラス: `ImageGridMeasurementFixtureTest` 5 / `SampleDemoScreenTest` 9 / `SampleScreenParityTest` 4) |
| lint | `local-path-lint.py` / `identity-lint.py` / `comment-policy-lint.py` | 禁止 0 件 / 0 件 / 0 件 (comment-policy は検査対象 192 ファイル。前周の要確認 13 件も 0 件になっている) |

件数は XML レポート (`build/test-results/testDebugUnitTest/TEST-*.xml` の `tests` / `failures` 属性) の
クラス単位の集計まで取った。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| [ソースコメント規約](../../handbook/cross/comment-policy.md) | always |
| [Sample のプラットフォーム間一致](../../handbook/cross/sample-parity.md) | `samples/` にデモ画面「画像グリッド」と計測用の画面を追加 |
| [テスト実行規約](../../handbook/cross/test-execution.md) | テストの実行と結果の報告 |
| [実行時挙動の検証規約](../../handbook/cross/runtime-behavior-verification.md) | 実行時挙動 (取り消し・再表示・消去後の再取得) の証跡と、同文書自身への観測点の追記 |
| [公開識別子と配布座標](../../handbook/cross/public-identifiers.md) | `Package.swift` / `libs.versions.toml` / AndroidManifest を変更 |
| [iOS 性能検証の手順と合格基準](../../handbook/ios/performance-verification.md) | 大量件数 (10,000 件) を扱う変更の完了判定 |
| [Android 性能検証の手順と合格基準](../../handbook/android/performance-verification.md) | 同上・ラッパーのスクロール経路に触れる |

参照した決定: core/ADR-0002・0004・0008・0011・0012 (proposed)、android/ADR-0002、cross/ADR-0003・0004。
`kasane/lessons/code-review.md` は未作成のため重点観点・除外観点なし
(`kasane/lessons/inbox/` の 3 件は昇格前なので判定には使っていない)。

## 前周の指摘の解消状況

| 前周の指摘 | 状況 | 確認した根拠 |
|---|---|---|
| ホスト Minor 1 観測点表への追随漏れ | **解消** | `kasane/handbook/cross/runtime-behavior-verification.md` の表に「画像グリッド」と「検証: 画像の挙動」が追加され、末尾の注記も「3 行」に更新。timestamp も 2026-09-07 |
| ホスト Minor 2 Android の未初期化時の例外 | **解消** | `KsAppContext.currentOrNull` (nullable) + `KsImageCache.sharedLoader` の警告 + no-op。`KsAppContextTest.cacheOperationsAreNoOpWhenTheInitializerDidNotRun` が初期化前の状態を作って検査。debug assertion を掛けられない理由も deviation に記録 |
| ホスト Minor 3 / 相方 Major 2 `clear(.disk)` | **解消** | 消去範囲を `.memory` / `.all` の 2 択にし (deviation でオーナー判断を記録)、`.all` はメモリとディスクの両方を落とす。`clearingAllAlsoInvalidatesTheDecodedMemoryImage` / `test表示中のKsImageは全消去で取得をやり直す` で表示レベルまで検査 |
| ホスト Minor 4 表示枠の大きさの責務 | **解消** | `KsImage.swift:25-33` / `KsImage.kt:49-58` に「表示枠の大きさは利用者が与える」と壊れ方の例を明記 |
| ホスト Suggestion 5 iOS `remove` の doc 文言 | **解消** | `KsImageCache.swift:39-42`「以後はどの表示サイズで要求しても…当たらなくなります (残った項目は使われないまま順次追い出されます)」 |
| ホスト Suggestion 6 / 相方 Minor 9 無言の no-op | **解消** | `KsImagePipeline.swift:43-50` で debug は assertion、release は警告ログ。テストで踏めない理由は deviation に記録 |
| ホスト Suggestion 7 / 相方 Minor 7 前置一致の誤削除 | **解消** | `KsImageCache.kt:62-67` でリモートは完全一致、ファイルだけ前置一致。`removeKeepsAnotherSourceWhoseKeySharesThePrefix` が衝突を検査 |
| 相方 Major 1 iOS の再デコード | **解消** (ただし下記 Major 2 を生んだ) | `KsImageRequestFactory.swift:64-80` が元寸のメモリ項目の有無で縮小手段を選び分ける。`test表示の要求はメモリ到達点の先読み結果を再デコードせずに使う` が `makeRequest` の実要求で数える |
| 相方 Major 3 消去中の進行中要求 | **解消** (範囲差は下記 Minor 3) | 両プラットフォームに `KsImagePrefetchRegistry` / `fence` を追加。iOS は応答を保留できる `URLProtocol` スタブ、Android は保留できる受け口で「消去 → 復帰 → 旧要求完了」を再現 |
| 相方 Major 4 Android の読み込み中 | **Android は解消・iOS は未対応** (下記 Major 1) | `KsImage.kt:139-151` がメモリ項目を同期で引く。`loadingSlotIsNeverComposedWhenTheImageIsAlreadyInMemory` がスロットの構成回数 0 を検査 |
| 相方 Major 5 スロットの非対称 | **解消** | `KsImage.swift:168-218` に loading のみ / failure のみの initializer。`KsPublicAPITests.test読み込み中と失敗の表示は片方だけでも差し替えられる` と `KsCollectionViewPublicApiTest.imageSlotsCanBeSubstitutedIndependently` が 4 組を検査。末尾クロージャの糖衣が非対称な点は deviation に記録済み |
| 相方 Major 6 Android の計測 fixture | **解消** (iOS 側は下記 Suggestion 1) | `ImageGridFixture` を宣言元にしてデモ画面と計測画面が同じ要素・配置・外周余白・宣言を取り、`ImageGridMeasurementFixtureTest` が両方を実際に描いて文言一致を検査。3 試行は cold に統一 (`ks_reset_image_cache`) し、帰結を証跡に明記 |
| 相方 Minor 8 ディスクキャッシュ設定の導線 | **解消** | `prefetchResources` の doc・`KsPrefetchDestination.disk` の doc・dsl-samples の 3 入口から `enableSharedDiskCache()` の完全な例へ導いている |
| 相方 Minor 10 証跡と配布構成の食い違い | **解消** | `evidence/image-behavior-observation.md:16-19` が iOS (release にも入るが起動引数で不活性) と Android (計測ソースセット限定) を書き分け |

## 指摘事項

### [🟠 Major] iOS: 到達点 `memory` の先読みの後でも、`KsImage` の初回表示が読み込み中を経由する

**該当箇所**: `ios/Sources/KsCollectionView/KsImage.swift:112-137` /
`ios/Sources/KsCollectionView/KsImageRequestFactory.swift:52-80`

**問題点**: デルタスペック Requirement「KsImage の表示状態」は「リモート・ファイルのソースは、
**メモリキャッシュに無い場合に**読み込み中の状態を経由する (メモリキャッシュにあれば読み込み中を経由せず
成功になる) (SHALL)」と定める。相方 Major 4 はこの文を根拠に Android の一瞬の読み込み中を契約違反と判定し、
突き合わせでも採用され、Android は同期のメモリ参照を足して直った。**同じ状況が iOS では直っていない。**

先読み (`KsNukeImageLoading.makeRequest`) は縮小指定の無い素の要求でメモリへ載せる。表示側は
`KsImageRequestFactory.makeRequest` が縮小処理付き (`ImageProcessors.Resize`) または縮小デコード付き
(`ThumbnailOptions`) の要求を作るため、**どちらの経路でもメモリ鍵が先読みの項目と一致しない**。
`LazyImage` の内部 (`FetchImage.load`) は「要求そのものの鍵での同期メモリ参照」だけを行い、外れると
`isLoading = true` にして非同期経路へ入る (Nuke 13.2.0 `Sources/NukeUI/FetchImage.swift`)。したがって
到達点 `memory` の先読みが完了していても、そのセルの初回表示は読み込み中のスロットを経由する。

これは本 change の `evidence/image-behavior-observation.md` の 7.3 の観測とも整合する — そこで
「要求そのものが起きない」と観測できたのは**素の要求で組んだローダー付属ビュー**であり、`KsImage` では
ない。到達点 `memory` を `disk` より上位の選択肢として公開している以上、「読み込み中を挟まない」は
その選択肢の主な価値であり、そこが片方のプラットフォームでだけ効かないのは core/ADR-0002 (accepted) の
「片方で書いた宣言をもう片方へ機械的に書き写せる」に対する実質的な穴でもある。

**検査の穴**: iOS には Android の `loadingSlotIsNeverComposedWhenTheImageIsAlreadyInMemory` に当たる
テストが無い。`KsImageCacheContractTests` / `KsImageTests` は要求の形とデコード回数だけを見ており、
読み込み中の状態を経由したかは 1 件も検査していない。

**推奨修正**: 表示の組み立て時に、先読みが載せた素の鍵のメモリ項目を同期で参照して初回描画に使う
(Android の `memoryCachedPainter` と同じ形) か、先読みと表示の鍵を一致させる。前者を採るなら
「読み込み中スロットが 1 度も構成されないこと」を数えるテストを iOS にも追加すること。
実装で解決せずオーナー判断で受容するなら、**Android と観測が異なる帰結として deviation.md に記録し、
`evidence/user-notes-source.md` にも利用者向け注記として残す**こと (現状はどちらにも記載が無い)。

### [🟠 Major] Android: 到達点 `memory` の先読みの後、`KsImage` が元寸の画像をそのまま表示・保持する

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImage.kt:129-136`
(`.precision(Precision.INEXACT)`) / `.../KsCoilImageLoading.kt:28-40` (先読みは寸法を付けない要求)

**問題点**: デルタスペック Requirement「KsImage の縮小デコード」は「`KsImage` は表示枠の実サイズに
合わせて縮小した画像をデコードする (SHALL)」、Scenario「枠より大きい画像」は「表示に使われるデコード済み
画像のピクセルサイズは、`fit` では枠のサイズ (表示倍率込み) を、`fill` では枠を覆う最小寸法を超えない」と
定める。design.md Decision 5 も Android について「制約からサイズを解決し縮小デコードする」を前提にしている。

実装は相方 Major 4 の修正にあわせて表示要求へ `Precision.INEXACT` を明示的に付けた。Coil 3.5.0 の
`MemoryCacheService.isCacheValueValidForSize` は、**縮小されていないキャッシュ項目 (`isSampled == false`) は
`precision == INEXACT` のとき要求サイズと無関係に有効と判定して返す** (`coil-core` の同メソッドを逆アセンブルして
確認: 鍵に `coil#size` が入るのは変換を持つ要求だけで、本実装の先読み・表示はどちらも変換を持たないため
鍵は取得元の文字列そのもの → 寸法判定は `isSampled` と `precision` の分岐に落ちる)。
先読み (到達点 `memory`) は寸法指定の無い要求なので元寸・未縮小でメモリに載る。
結果として、**先読み済みのセルは元寸の画像をそのまま描き、その bitmap を表示中ずっと保持する**。

Requirement の SHALL NOT には「プリフェッチの到達点 `memory` による元寸の**保持**は本要件の対象外」という
除外があるが、除外されているのは保持であって「表示に使うデコード済み画像の寸法」ではない。到達点 `memory` は
グリッドで勧めている選択肢であり、1 辺数千ピクセルの URL を申告した利用者は、画面上の見た目と無関係な量の
bitmap を全可視セルぶん抱えることになる (`evidence/user-notes-source.md` の 4 は「先読みが元寸を載せる」までは
書いているが、「表示もその元寸をそのまま使う」ことは書いていない)。

同じ継ぎ目を iOS は逆向きに解いている — deviation.md の「縮小手段の選び分け (iOS)」は、
`ThumbnailOptions` と `ImageProcessors.Resize` を使い分けて**再デコードを避けつつ縮小した画像を作る**と
明記している。Android にはこの選び分けに当たるものが無く、非対称も deviation に記録されていない
(記録があるのは「表示枠より小さい画像がメモリにあると数フレーム拡大表示になる」という別の帰結だけ)。

**検査の穴**: Android には Scenario「枠より大きい画像」に対応するテストが 1 件も無い。
`KsImageCacheContractTest.memoryDestinationAvoidsSecondDecode` (`:199-214`) は「再デコードしない」ことだけを
見ており、しかもそれが緑になるのは**まさにこの緩和のおかげ**である。加えて同テストの `displayRequest`
(`:167-172`) は `KsImage` の要求を手で書き写した複製で、本番の組み立て (`KsImage.kt:129-136` にインライン)
を通っていない — iOS が `KsImageRequestFactory` を切り出して実経路を検査しているのと非対称。

**推奨修正**: 表示要求の寸法契約を戻す (`Precision.EXACT` にする / 元寸のメモリ項目からは縮小して描く経路を
別に持つ等) か、iOS と同様に「元寸がメモリにあるときだけ別手段」の選び分けを入れる。あわせて
Scenario「枠より大きい画像」を Android でも検査するテスト (デコード結果のピクセル寸法が枠を超えないこと) を
追加し、表示要求の組み立てを `KsImage` から切り出してテストが本番経路を通れるようにすること。
再デコード回避と縮小の両立が Coil の API で成立しないと判断するなら、**どちらを優先するかはオーナー判断として
提示し、結論を deviation.md と利用者向け注記に残す** (iOS 側は同じ衝突を deviation で処理している)。

### [🟡 Minor] キャッシュ消去のフェンスが先読みだけを対象にしており、その範囲差が記録されていない

**該当箇所**: `ios/Sources/KsCollectionView/KsImageCache.swift:30-33,50-52` /
`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImageCache.kt:35-36,54-56`
(名簿は `KsImagePrefetchFence.swift` / `KsImagePrefetchFence.kt`)

**問題点**: `KsImagePrefetchRegistry` に登録されるのは先読み層 (`KsImagePrefetcher` /
`KsImagePrefetchWindow`) だけで、**表示中の `KsImage` が出した進行中の要求は消去時に止まらない**。
表示側の取り消しは世代が進んで表示が組み直されたときに起きるので、`clear` / `remove` が戻った後になる。
その間に完了した表示要求は、消去したのと同じ鍵へ書き戻せる。

deviation.md の「キャッシュ消去時のフェンスの限界」は「`clear` / `remove` は進行中の取得を止めてから消すが、
止められるのは取り消しが届く前に完了しきっていない取得まで」と書いており、**表示要求はそもそもフェンスの
対象外である**ことが読み取れない。デルタスペック Requirement「キャッシュのクリア」の「呼び出しから戻った
時点でキャッシュの削除が完了しており、以後の同じソースの要求はキャッシュに当たらない (SHALL)」に対する
残穴としては、記録されている穴より一段広い。

**推奨修正**: 実装で塞ぐなら表示側の要求も名簿に載せる。窓が狭く受容するなら、deviation.md の該当項目に
「表示中の要求はフェンスの対象外で、消去から表示が組み直されるまでの間に完了した要求は書き戻し得る」を
足して、記録と実装をそろえること。

### [🔵 Suggestion] iOS の計測入口が Sample と同じ宣言元を共有しておらず、土俵一致の歯止めが無い

**該当箇所**: `samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift` の
`imageGridCollection(destination:)` と `samples/ios/KsCollectionViewSamples/ImageGridDemoView.swift` の
`collection`

**問題点**: 相方 Major 6 で Android は `ImageGridFixture` に宣言を 1 本化し、`ImageGridMeasurementFixtureTest`
が「土俵が食い違ってもどちらの画面も正常に動くため、コンパイラでは守れない」として実際に描いて一致を
確かめる形になった。iOS の計測用の土俵は同じ定数 (`ImageGridMetrics` / `DemoData.imageGridItems`) を
参照しているものの、配置・外周余白・先読み宣言の**組み立て自体はデモ画面と別々に書かれている**。現時点で
値は一致しているが、Android で「守れない」と判断した種類の乖離に対する歯止めが iOS には無い。

**推奨修正**: iOS にも `ImageGridFixture` 相当 (レイアウト・contentPadding・先読み宣言・セル) を 1 本化した
宣言元を置き、デモ画面と計測画面の両方から取る。tasks 7.1 の実施前に入れておくと、計測値の前提が
証跡の「Sample と同じデータ・同じ配置」という記述と実際に一致していることを言える。

### [🔵 Suggestion] iOS のメモリ計測の「状態」表と本文の食い違い

**該当箇所**: `evidence/image-grid-measurement-ios.md` の「状態」表 (メモリ = 実施済み・合格) と
同ファイル本文末尾 (「同じ手順の 2 回目の実行は行っていない … この点は未達である」)

**問題点**: iOS 性能検証の規約は「同じ手順を独立に 2 回実行し、実行間のばらつきも記録する」を求めており、
本文はそれが未達であることを正しく自己申告している。一方、冒頭の状態表は「実施済み・定常化を確認」とだけ
書いているため、表だけを読むとメモリ系統が規約を満たして完了したように読める。tasks 7.1 が未チェックの
まま残っているので実害は小さいが、証跡は表から読まれる。

**推奨修正**: 状態表のメモリ行を「一部実施 (1 回のみ。規約の独立 2 回は未達)」にそろえる。

## 所見 (指摘ではない)

- **公開型の削減 (`KsImageCacheScope` の 2 択化)** は deviation にオーナー判断として記録済みで、
  参照箇所 (本体・テスト・Sample・計測) に取り残しは無い。ただしデルタスペック Requirement
  「キャッシュのクリア」は 3 択のまま (足場は凍結なので正しい) なので、**蒸留で concepts へ落とすときに
  2 択が確定形であることと、`clear(.all)` がメモリも落とすことを明記する必要がある**。
- **core/ADR-0012 は依然 proposed**。実装は deviation の合意どおり明示 API (`enableSharedDiskCache()`) に
  なっており、ADR 本文の「初回利用時に自動で差し替える」と Consequences (「入れるだけで効く」) は
  蒸留で accepted 化するときに書き直しが要る (前周と同じ所見)。
- **付随修正の同梱条件**: deviation の `[付随修正]` 5 件 (`libs.versions.toml` のコメント削除 /
  Android テストの `AtomicInteger` 化 / `MemoryRoundTripScreen` の引数化 / `KsAppContextTest` の順序依存解消 /
  iOS `KsImageCacheContractTests` の待機の作り直し) は、いずれも本務で触るファイル内・局所・公開 API 不変で
  ksn-core の同梱条件に収まっている。`MemoryRoundTripScreen` の引数化は前周「テストが足りない」と指摘されたが、
  `ImageGridMeasurementFixtureTest` の 2 件目がその画面を実際に描いて担保するようになった。
- **未実施の実機計測 (tasks 7.1 / 7.2 / 7.5)** は合意済みの進行状態。証跡は「何が測れて何が測れていないか」を
  分けて書けており、Android は cold 試行の取り決めと帰結 (回線状態を含むので日をまたいだ比較ができない) まで
  明記している。未計測そのものは指摘にしていない。
- **良かった点**: 相方の 6 件がいずれも「検証の穴」ごと直っている (縮小指定付きの実要求で数える /
  応答を保留できるスタブで消去と完了の順序を作る / スロットの構成回数を数える / 土俵を実際に描いて
  文言で照合する)。`sample-parity` の追加分 (画面タイトル「画像グリッド」・3 択の文言・説明行
  「プリフェッチ · 10,000 件 · 3 列」・「キャッシュを消去」) は両プラットフォームで一致しており、
  `SampleScreenParityTest` も更新されている。`runtime-behavior-verification.md` への観測点追記は、
  技術検証画面の扱い (メニューに出さない・デモ画面の集合に数えない) まで既存の書き方に沿っている。

## アクションプラン

1. **[Major]** 到達点 `memory` の先読みと `KsImage` の表示の継ぎ目を、**両プラットフォームで同じ契約に
   そろえる**。iOS は読み込み中を経由しないこと、Android は表示に使う画像を枠の大きさへ縮小すること。
   どちらも spec の Requirement なので、実装で満たせない側があるならオーナー判断として提示し、
   結論を deviation.md と `evidence/user-notes-source.md` に残す (現状はどちらにも記録が無い)
2. **[Major に付随]** 1 の検査を両プラットフォームに入れる。iOS は「読み込み中スロットが 1 度も構成されない」
   (Android の既存テストと対) 、Android は「デコード結果のピクセル寸法が枠を超えない」(iOS の既存テストと対)。
   あわせて Android の表示要求の組み立てを `KsImage` から切り出し、テストが本番経路を通るようにする
3. **[Minor]** キャッシュ消去のフェンスが表示中の要求を対象にしていないことを、実装で塞ぐか
   deviation.md の「フェンスの限界」に追記して記録と実装をそろえる
4. **[Suggestion]** iOS の画像グリッドの土俵を 1 本化する (Android の `ImageGridFixture` と対)。
   tasks 7.1 の計測前が望ましい
5. **[Suggestion]** `evidence/image-grid-measurement-ios.md` の状態表を本文の自己申告に合わせる
6. 上記と独立に、蒸留では **core/ADR-0012 の Decision と Consequences を実装 (明示 API) に合わせて確定し、
   消去範囲の 2 択と `clear(.all)` の実挙動を concepts に明記する**
