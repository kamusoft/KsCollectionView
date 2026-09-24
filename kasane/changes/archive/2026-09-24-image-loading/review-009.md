# レビュー結果: image-loading (009 回目)

**日付**: 2026-09-08
**判定**: CHANGES_REQUESTED

## サマリー
`allowHardware(false)` の撤去そのものは安全に閉じている — 画素を読む経路は `KsImageRequestFactory.downscale` の 1 箇所だけで、`isPixelReadable()` の門が撤去前と同じ位置に残っており、落ちる経路は復活していない。取り消し・キャッシュ消去の経路は画素に触れないため相互作用も無い。新設の unit テストは本番経路 (`KsCoilImageLoading.enqueue` → singleton loader) を `EventListener` で観測しており、契約の固定として妥当。

一方で、撤去の帰結として破れる spec の SHALL が deviation に記録された 1 件だけではない。到達点 `memory` は実機で**デコードもやり直す**ようになっており、これは Scenario「メモリ到達点の後の表示」の逸脱だが未記録で、それを検査している unit テストは代替実装 (ソフトウェアビットマップ) の上でだけ緑になっている。加えて deviation が自ら約束した「証跡に明記する」が、クラッシュ修正の証跡に対して実施されておらず、その文書は現行実装と逆のことを書いたまま残っている。

## 照合した規約
- `handbook/cross/comment-policy.md` (always) — doc の書き換えが本便の中心のため節ごとに照合
- `handbook/cross/test-execution.md` (テスト実行・結果報告) — 実行件数の確認、収束を待つアサーション
- `handbook/cross/runtime-behavior-verification.md` (不具合修正の完了判定) — 実環境での A/B と証跡
- `handbook/android/index.md` — 性能検証は本便の対象外 (再計測は tasks 7.5 で未了)
- `decisions/core/0008` (accepted) — 到達点の粒度に関する定めは無く、衝突なし。`core/ADR-0012` は `proposed` のため判定根拠にしていない
- lessons/inbox: `exercise-device-only-branches-on-real-hardware` / `check-tests-exercise-production-path-before-accepting-green` / `check-sibling-contracts-when-fixing-a-review-finding` (`lessons/code-review.md` は未作成のため「指摘しないこと」は無し)

## 実行したビルドとテスト
- `android/` `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` → BUILD SUCCESSFUL。`build/test-results/testDebugUnitTest/TEST-*.xml` 集計で **130 tests / 0 failures・0 errors**
- `android/` `./gradlew :kscollectionview:assembleDebugAndroidTest` → BUILD SUCCESSFUL (実機テストのコンパイル確認。実行は基準機を占有中のため行っていない)
- `python3 scripts/comment-policy-lint.py --advisory` → **禁止 0 件** / 要確認 14 件 (いずれも本便の対象ファイル外)

## 指摘事項

### [🟠 Major] 実機で破れる spec の SHALL が deviation に 1 件しか記録されていない (「デコードのやり直しもなし」も破れている)

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCoilImageLoading.kt:47` / `kasane/changes/image-loading/deviation.md:83`

**問題点**:
spec の Requirement「プリフェッチの到達点」/ Scenario「メモリ到達点の後の表示」は

> **THEN** ネットワークアクセスも**デコードのやり直しもなしに**表示される

と定める。撤去後の実機経路は次のとおりで、この SHALL が破れる。

1. 先読みが元寸を `HARDWARE` でメモリへ載せる (鍵 = 取得元の文字列)
2. `KsImageRequestFactory.prepare` が displayKey では引けず、元寸は `isPixelReadable()` で `Unreadable` → `cachedImage = null`
3. 表示は `.memoryCacheKey(displayKey)` を持つ要求をローダーへ出す。displayKey はメモリに無いのでディスクキャッシュから **もう一度デコードする**

再ダウンロードは起きないので「ネットワークアクセスなし」は保たれるが、「デコードのやり直しもなし」は保たれない。deviation:83 が記録しているのは Requirement「KsImage の表示状態」の「メモリキャッシュにあれば読み込み中を経由せず成功になる」だけで、この Scenario の逸脱は**未記録の仕様逸脱**になっている。帰結として実機の到達点 `memory` は、`disk` に対して「元寸のデコード 1 回分と元寸のメモリ占有を余分に払って、得るものが無い」状態であり、記録の有無に関わらず利用者向け注記でも扱いが変わる。

なお、本便で追加された実機テスト `preparedRequestDecodesInsideFrameAfterMemoryPrefetch`
(`android/kscollectionview/src/androidTest/kotlin/jp/kamusoft/kscollectionview/KsImageDeviceDecodeTest.kt:82-104`) は、まさにこの再デコードを `execute` で走らせてその結果を assert している。再デコードが起きること自体は実測済みで、記録だけが無い。

**推奨修正**: deviation に Scenario「メモリ到達点の後の表示」の逸脱 (実機でデコードが 1 回増える) を追記し、`prefetch-display-size` で解消する対象に含める。合わせて、この逸脱が spec の 2 つの Requirement にまたがることを利用者向け注記の原料 (tasks 8.1) にも反映する。

### [🟠 Major] 「再デコードしない」を検査する unit テストが、代替実装の上でだけ緑になっている

**該当箇所**: `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsImageCacheContractTest.kt:214-230`

**問題点**:
`memoryDestinationAvoidsSecondDecode` は末尾で `assertEquals("表示で再デコードしない", 1, decodeCount)` を確かめている。Robolectric の画素は常にソフトウェア側なので `downscale` が `Done` を返し、displayKey がメモリへ書かれ、ローダー要求がメモリに当たって `decodeCount` は 1 のまま — 撤去後も緑になる。しかし実機では上記のとおり 2 になる。

現在このテストは、緑であることが Scenario 充足の根拠に見えるが、実際には**「ソフトウェアビットマップの環境では成立する」しか意味していない**。lessons `exercise-device-only-branches-on-real-hardware` と `check-tests-exercise-production-path-before-accepting-green` がまさにこの型 (実行環境で実体が変わる資源の分岐を、代替実装の緑で完了扱いにする) を禁じている。本便は `allowHardware` の契約を新テストで固定した一方で、同じ継ぎ目に掛かっているこちらの契約を未処理のまま残しており、`check-sibling-contracts-when-fixing-a-review-finding` の「修正が触る箇所に掛かっている他の Scenario を洗い出す」に照らしても不足している。

**推奨修正**: このテストの doc に「この結果はソフトウェアビットマップ環境に限る。実機では元寸が読み出せず、ローダーが 1 回デコードし直す」ことを明記する。可能なら実機側 (`KsImageDeviceDecodeTest`) に対になる検査 — 先読み後の表示要求でデコードが 1 回起きること — を置き、どちらの環境で何が成立するかがテスト側から読めるようにする。

### [🟠 Major] クラッシュ修正の証跡が現行実装と逆のことを書いたまま残っている

**該当箇所**: `kasane/changes/image-loading/evidence/image-grid-memory-prefetch-crash-fix-android.md:40` および `:43-53`

**問題点**:
deviation:83 は「**実機と挙動が分かれる点を証跡・利用者向け注記に明記する**」と自ら約束している。この証跡は撤去後の実装に対して次の 3 点が事実と逆になっており、約束が未実施である。

1. 40 行目「画像は読み込み中を挟まずに出る」— 実機では読み込み中を一瞬経由するようになった。まさに今回のオーナー判断が受け入れた帰結の逆を書いている
2. 回帰テスト表 (48-52 行) の 1 行目「先読みが載せた元寸の画素を読み出せる」は、現在のテスト `memoryPrefetchStoresGraphicsBackedImage` が**逆の契約** (`config == HARDWARE` であること) を要求しているため、指している検証がもう存在しない。2 行目「元寸から作った表示用の画像が枠を超えない」も現在は「初回描画には使わず、ローダーの縮小デコードが枠に収まる」へ改訂されている
3. A/B の根拠も入れ替わっている。現行の A/B は「`isPixelReadable()` を常に true にすると 3 件中 2 件が同じ `IllegalArgumentException` で失敗する」であり、表が書いている「修正前 = `allowHardware(false)` 無し」ではない

証跡は足場と共にアーカイブされ、蒸留で concepts / lessons の原料になる。実装と逆の記述を残すと、後から読む側が「到達点 memory は読み込み中を挟まない」と誤って持ち出す。実装者が対象外としたとのことだが、deviation の約束事項である以上、対象外にする根拠が無い。

**推奨修正**: 40 行目を現行の実機挙動 (読み込み中を一瞬経由してローダーの縮小デコードを待つ) に書き直し、回帰テスト表を現在の 3 件の契約と現行の A/B (分岐の無効化による再現) に差し替える。クラッシュが解消していること自体の記録 (症状・原因・修正前スタックトレース) は歴史として残してよいが、「修正」が何を指すかを現行実装 (`Unreadable` 分岐) に合わせる。

### [🟡 Minor] 実機テスト 2 件が環境条件を assert しており、環境要因で製品の欠陥に見える失敗を出す

**該当箇所**: `android/kscollectionview/src/androidTest/kotlin/jp/kamusoft/kscollectionview/KsImageDeviceDecodeTest.kt:59-73` および `:82-97`

**問題点**:
`memoryPrefetchStoresGraphicsBackedImage` は `assertEquals(Bitmap.Config.HARDWARE, ...)` で、`preparedRequestDecodesInsideFrameAfterMemoryPrefetch` は `assertNull(prepared.cachedImage)` で、いずれも「この実行環境がハードウェアビットマップを返す」ことを**アサーション**にしている。これは製品の契約ではなく実行環境の性質であり、次の場合に製品の欠陥のような失敗メッセージが出る。

- エミュレータや、ソフトウェア構成でデコードする端末で走らせた場合
- 実機であっても、Coil が `LimitedFileDescriptorHardwareBitmapService` (coil-core 3.5.0 に同梱を確認) でハードウェアビットマップを止めている状況。ファイルディスクリプタが逼迫すると発火する仕組みで、**大量件数の画像グリッドで到達点 memory を使う** という本 change が狙う条件はまさにその圧が掛かる状況にあたる

クラス doc も「ソフトウェア側になる環境では、その経路は踏まれない」と書いており、踏まれないことを実装者自身が認めている。踏まれない環境で失敗させるのではなく、前提条件として扱うのが正しい形になる。

**推奨修正**: 環境条件は `org.junit.Assume.assumeTrue` で前提として書き、満たされない環境では skip されるようにする。契約のアサーションは「落ちないこと」「表示に使う画像が枠を超えないこと」に限る。`preparedImageSkipsUnreadableOriginal` は構成を直に作るため決定的で、環境非依存の担保としてこの 1 件が残る形になる (ただし `BitmapFactory.Options.inPreferredConfig` も要求であって保証ではないため、`:116-120` の確認も同じ扱いにするのが一貫する)。

### [🟡 Minor] 実機の挙動が 1 通りに書かれているが、実際は環境で 2 通りに分かれる

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCoilImageLoading.kt:20-27` / `kasane/changes/image-loading/deviation.md:83`

**問題点**:
`KsCoilImageLoading` の doc は「実機ではグラフィックス側に置かれることが**多く**」と正しく幅を持たせているのに対し、deviation:83 と実機テストのアサーションは「実機 = 常にハードウェア = 常に読み込み中を経由」と断定していて、同じ事実の記述が 3 箇所で食い違っている。上記のとおり Coil はファイルディスクリプタの逼迫時にハードウェアビットマップを自分で止めるため、実機でも同期縮小で即時表示になる実行がありうる。

到達点 `memory` の実機挙動が**同じ端末でも実行ごとに変わりうる**ことは、tasks 7.4 / 7.5 の再計測 (読み込み中スロットの計数と frameOverrun) の解釈に直接効く。断定した記述のままだと、計数が 0 になった実行を「spec を満たした」と読んでしまう余地が残る。

**推奨修正**: doc の「多く」に合わせて deviation の記述にも幅を持たせ (ローダーがハードウェアビットマップを止める状況では従来どおり即時表示になる)、7.4 / 7.5 の再計測の証跡には、その実行で元寸がどちらの構成だったかを添えるか、少なくとも構成に依存する旨を書く。

### [🔵 Suggestion] iOS との非対称が deviation に明示されていない

**該当箇所**: `kasane/changes/image-loading/deviation.md:83`

**問題点**:
iOS の `KsImageRequestFactory.prepare` (`ios/Sources/KsCollectionView/KsImageRequestFactory.swift:69-74`) は元寸を無条件に `downscaleProcessor` へ通し、`UIImage` の画素は常に読めるため、iOS 側は「読み込み中を経由しない」も「デコードのやり直しなし」も保ったままになる。つまり本便は**同じ公開 API の同じ選択肢が、プラットフォームによって満たす SHALL の数が違う**状態を作った。

deviation:83 は「エミュレータ・単体テストでは従来どおり」という環境軸の非対称は書いているが、プラットフォーム軸の非対称には触れていない。本 change は lessons `check-sibling-contracts-when-fixing-a-review-finding` の原型 (両プラットフォームを別々に倒して非対称を作った) を生んだ change でもあり、意図した非対称であることを記録に残す価値がある。

**推奨修正**: deviation:83 に「iOS は同じ経路で両 SHALL を満たし続けるため、到達点 `memory` の初回表示挙動はプラットフォーム間で非対称になる (解消は `prefetch-display-size`)」を 1 行足す。

## 確認して問題が無かった観点
- **落ちる経路の復活**: 画素を読む呼び出しは `KsImageRequestFactory.kt:146` の `image.toBitmap(...)` のみで、直前の `isPixelReadable()` (`:142`) が門として残っている。`NotNeeded` 経路が `HARDWARE` の元寸をそのまま描画へ渡しうるが、これは撤去前から displayKey 命中経路 (ローダーのデコード結果は既定でハードウェア) で起きていたことと同じで、新しい危険ではない
- **取り消し・キャッシュ消去との相互作用**: `KsImageCache.clear` / `remove` と `KsImagePrefetchRegistry` の fence は画素構成に触れず、鍵の一致だけで動く。撤去の影響なし
- **新テストの本番経路性**: `memoryDestinationKeepsHardwareBitmapsAllowed` は `KsCoilImageLoading(context).enqueue(...)` から singleton loader へ流れる実要求を `EventListener.onStart` で捕まえており、要求生成経路を迂回していない。待機も deadline + 実測値付き失敗で `test-execution.md` の「収束を待つアサーション」を満たす。`CopyOnWriteArrayList` の選択も取得スレッドからの記録として妥当
- **コメント規約**: 書き換えた doc に作業文書パス・change 識別子・通番・`SHALL` 等の混入は無い。`KsImageRequestFactory` の「現状は暫定的にこの形にしている」は外部文書に依存せず自己完結しており適合。公開 doc (`KsPrefetchDestination`) は内部用語を含まず、今回の帰結を誤って約束してもいない
- **足場アーティファクト**: `specs/image-loading/spec.md` は未変更 (`git status` で確認)。書き換えによる辻褄合わせは行われていない

## アクションプラン
1. deviation に Scenario「メモリ到達点の後の表示」の逸脱 (実機でデコードが 1 回増える) を追記する (Major 1)
2. `evidence/image-grid-memory-prefetch-crash-fix-android.md` を現行実装・現行 A/B・現行テスト契約に合わせて改訂する (Major 3)
3. `memoryDestinationAvoidsSecondDecode` の doc に環境限定である旨を明記し、可能なら実機側に対の検査を置く (Major 2)
4. 実機テストの環境条件を `Assume` へ移す (Minor 1)
5. 実機挙動の記述の幅を doc / deviation / 再計測証跡で揃える (Minor 2)
6. iOS との非対称を deviation に 1 行残す (Suggestion)
