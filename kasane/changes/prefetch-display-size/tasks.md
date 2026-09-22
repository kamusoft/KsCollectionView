# Tasks: prefetch-display-size

規約: cross の体感ゲート (`kasane/handbook/cross/scroll-performance-gate.md`) と platform 別の性能検証手順 (`kasane/handbook/{ios,android}/performance-verification.md`)。実機だけで実体が変わる資源 (ハードウェアビットマップ) の分岐は、実機で踏むまで未検証 (`kasane/handbook/cross/runtime-behavior-verification.md`)。

## 1. 現状の対照 (本実装の前)

- [ ] 1.1 Sample「画像グリッド」を到達点「メモリまで」にして、基準機 Pixel 4a と iPhone 11 で固定の操作列の手動フリックを行い、体感ゲート規約の 6 節 + 「画像の出方」を `evidence/manual-imageGrid-{android,ios}-before.md` に残す。到達点と OS 版を必ず記録する (→ design Decision 8 (1))
- [ ] 1.2 同じ操作列で「ディスクまで」も 1 回記録し、表示待ちの差を対照に残す (→ proposal Non-Goals「到達点 disk の初回表示」の切り分け材料)

## 2. 引き当て (KsImage)

- [ ] 2.1 iOS: `KsImageRequestFactory.prepare` を、索引の候補をローダーのキャッシュで検証し、当てはめ方で必要な拡大率を求めて許容範囲 (定数 1 か所: 下限 0.5 / 上限 4) で選ぶ形に置き換える。`ImageProcessors.Resize` による同期縮小と表示鍵への書き戻しを削除する (→ Requirement: KsImage のメモリ項目の引き当て / KsImage の縮小デコード)
- [ ] 2.2 iOS: `KsImage` は引き当てに成功したら `LazyImage` を作らず、その項目を成功状態として描く。失敗したら従来の縮小要求 (`ThumbnailOptions`) を `LazyImage` に出し、その鍵を索引へ登録する (→ Scenario: 先読みの縮小済み項目を使う / 読み込み中から成功へ)
- [ ] 2.3 Android: `KsImageRequestFactory.prepare` を同じ規則に置き換え、`downscale` / `KsDownscaleResult` / `isPixelReadable` を削除する。表示鍵は `coil#size` のみ (`ks#scale` を外す) (→ Requirement: KsImage のメモリ項目の引き当て / 原寸の項目を実機でも使う)
- [ ] 2.4 Android: `KsPreparedImageContent` は引き当てに成功したら `rememberAsyncImagePainter` を作らず、その項目を `Image` で描く。失敗したら従来の要求を出し、その鍵を索引へ登録する (→ Scenario: 先読みの縮小済み項目を使う)
- [ ] 2.5 両: 枠のサイズが変わったときの引き当てのやり直し (範囲内なら同じ項目を使い続ける) (→ Scenario: 枠が変わっても範囲内なら再デコードしない)

## 3. 寸法索引

- [ ] 3.1 iOS: `KsImageMemoryIndex` (URL の識別子 → [要求]、上限つき LRU) を追加し、`KsImageCache.clear` で全消去・`remove` でその識別子を消す (→ design Decision 3、Scenario: 消した項目は引き当てない)
- [ ] 3.2 Android: 同じ索引 (`MemoryCache.Key` を保持、1 つの錠で直列化) を追加し、`KsImageCache` の `clear` / `remove` と接続する。`clear` / `remove` の復帰時点でキャッシュと索引の両方が無効であること、登録と消去が競合しても旧項目を指さないことをテストで固定する (→ 同上、design Decision 3)
- [ ] 3.3 両: 到達点 `memory` の先読み要求と `KsImage` の縮小要求を出した時点で鍵を索引へ登録する経路を実装し、未完了の鍵が引き当ての候補にならない (キャッシュへの問い合わせで空になる) ことを単体テストで固定する (→ Scenario: 列幅で縮小して載せる / 読み込み中から成功へ)

## 4. 先読みの幅の宣言 (KsResource / KsWidth)

- [ ] 4.1 両: 公開型 `KsResource` (url + 任意の幅) と `KsWidth` (列幅 / 固定値) を追加し、`prefetchResources` の戻り値を `[KsResource]` / `List<KsResource>` に変える (`[URL]` / `List<String>` は廃止)。固定値の無効値 (0・負数・NaN・無限大・`Dp.Unspecified`) は不正入力として幅なし扱いにし、テストで固定する (→ Requirement: プリフェッチ宣言 / プリフェッチの表示幅、Scenario: 無効な固定値は幅なし扱い / 幅あり・幅なしの混在)
- [ ] 4.2 iOS: `KsNukeImageLoading` に幅つきの要求 (`ThumbnailOptions(size: (w, w), .pixels, .aspectFill)`) を出す経路を足す。到達点 `disk` では幅を付けない。元寸が小さいときに拡大されないことを単体テストで固定する (→ Scenario: 列幅で縮小して載せる / 到達点 disk では幅を使わない / 元寸が小さければ拡大しない)
- [ ] 4.3 Android: `KsCoilImageLoading` に幅つきの要求 (`size(w, w)` + `Scale.FILL` + `Precision.INEXACT` + `coil#size` 鍵) を出す経路を足す。元寸が小さいときに拡大されないことを単体テストで固定する (→ Scenario: 元寸が小さければ拡大しない)
- [ ] 4.4 iOS: 列幅の解決 (`KsLayoutMetrics` + bounds + contentPadding + 列間隔) を `KsCollectionViewController` の prefetch 通知で行い、px に正規化して台帳へ渡す (→ Scenario: 向きが変わると新しい列幅で先読みする)
- [ ] 4.5 Android: `KsPrefetchWindowEffect` に `layout` / `contentPadding` / コンテナ幅を渡し、`update` のたびに列幅を解く (`Adaptive` は `LazyVerticalGrid` の規則を再現) (→ 同上)
- [ ] 4.6 両: 列幅が 0 以下に解ける間は列幅の先読みを開始しないことをテストで固定する (→ Scenario: 列幅が解けない間は始めない)

## 5. 先読み台帳の要求単位化

- [ ] 5.1 iOS: `KsImagePrefetcher` を「アイテム → 宣言集合 (URL + 幅の種類)」「取得単位 (`disk` は URL、`memory` は URL + 幅 px) → 参照数 + 開始時の `ImageRequest`」の 2 層に変え、取り消しは開始時の要求で行う。`fence(url:)` は全幅を止める (→ Requirement: プリフェッチの取り消し、Scenario: 幅が違えば別の取得 (memory) / disk では幅違いも 1 つの取得 / 向きが変わった後の取り消し)
- [ ] 5.2 Android: `KsImagePrefetchWindow` を同じ 2 層に変え、`Request` に開始時のハンドルと幅 px を持たせる。`update` の release 判定は宣言で行い、列幅の px が変わっただけでは release しない (→ 同上、Scenario: 向きが変わっただけでは触らない)
- [ ] 5.3 両: 既存の台帳テスト (`KsImagePrefetchTests` / `KsImagePrefetchWindowTest`) を 2 層に更新し、`memory` の幅違いの独立性・`disk` の幅違いの統合・開始時の要求での取り消し・回転で既存要求の開始/取消回数が変わらないことを追加する (→ Scenario: 共有 URL は最後のアイテムが外れるまで取り消さない / 幅が違えば別の取得 (memory) / disk では幅違いも 1 つの取得 / 向きが変わっただけでは触らない)

## 6. テスト (単体・契約)

- [ ] 6.1 iOS `KsImageTests` / `KsImageCacheContractTests`: 引き当ての Scenario 6 本 (縮小済み / 原寸 / 小さすぎ / 大きすぎ / 縦長 fill / 消した項目) と、範囲内のとき要求を出さないことを追加。「元寸から縮小する経路」「表示鍵は元寸の有無で変わらない」の旧テストは新契約に置き換える (→ Requirement: KsImage のメモリ項目の引き当て)
- [ ] 6.2 Android `KsImageTest` / `KsImageCacheContractTest`: 同じ 6 本 + 要求を出さないこと。`memoryDestinationAvoidsSecondDecodeWhenPrefetchedPixelsAreReadable` 等の「画素を読める」前提のテストを置き換える (→ 同上)
- [ ] 6.3 両: `KsResource` の宣言 (幅あり / 幅なし / 混在)・到達点の写像・幅なしが元寸のまま載ることのテスト。既存の宣言テストを `KsResource` の形に書き換える (→ Requirement: プリフェッチの表示幅 / プリフェッチ宣言)
- [ ] 6.4 両: 索引の単体テスト (登録・LRU 上限・`clear` / `remove` との同期・キャッシュに無い候補の破棄) と、追い出された項目が再デコードに落ちること (→ design Decision 3、Scenario: 追い出された項目は再デコードする)
- [ ] 6.5 Android `KsImageDeviceDecodeTest` (androidTest、実機): 4 本を新契約に書き換える — 原寸のハードウェアビットマップが引き当てられ読み込み中を経由しない / 幅ありの先読みは宣言幅の項目を載せる / 範囲外は縮小デコードに落ちる / 表示後に元寸がメモリに無い (→ Scenario: 原寸の項目を実機でも使う、handbook runtime-behavior-verification)
- [ ] 6.6 iOS: iPhone 実機で到達点 `memory` の原寸引き当てと列幅の先読みを踏む確認を 1 本 (UI テストまたは Sample 操作の証跡) 残す (→ design Open Questions)

## 7. Sample

- [ ] 7.1 両: 「画像グリッド」の宣言を `KsResource` の形に書き換え、到達点の選択肢に「メモリまで (列幅)」を同一文言・同一順序で追加して列幅の `KsResource` を宣言する (sample-parity) (→ Requirement: Sample のデモ画面「画像グリッド」、Scenario: 列幅の先読みに切り替える)

## 8. 完了時の計測と証跡

- [ ] 8.1 1.1 と同じ操作列で「メモリまで」(幅なし)「メモリまで (列幅)」「ディスクまで」を両基準機で手動フリックし、体感の合否 (滑らかさ) と表示待ち (画像の出方) を `evidence/manual-imageGrid-{android,ios}-after.md` に残す。before との比較可否と差を書く (→ design Decision 8 (3))
- [ ] 8.2 両: 先読み後の初回表示で取得・デコードが走らないことをローダーの通知 (iOS 割り込み処理 / Android `EventListener`) で数え、証跡に残す (→ Scenario: メモリ到達点の後の表示)
- [ ] 8.3 両: 到達点 `memory` (幅なし / 列幅) のメモリ定常化を各 platform の性能検証手順で測り (iOS は画像グリッド全件往復後の定常化と保持対象の解放確認)、列幅では元寸を載せない分の減少と、索引込みで定常化すること・画面離脱後に索引がコレクションやセルを保持しないこと・索引の充足 (キャッシュにある項目が索引に残っている率) を証跡に残す (→ Requirement: プリフェッチの表示幅「元寸の画像はメモリに載せない」、design Decision 3 / Risks)
- [ ] 8.4 両: 許容範囲の初期値 (0.5 / 4) を実機の見た目で確認し、変えた場合は定数と証跡に理由を残す (→ design Decision 1)
- [ ] 8.5 到達点 `disk` の表示待ちで残る分 (subcomposition・cold 取得) を切り分けた所見を証跡に残し、必要なら簡易起票する (→ proposal Non-Goals)
