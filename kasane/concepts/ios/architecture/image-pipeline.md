---
type: concept
title: iOS 画像の先読みと KsImage の実現
description: core の画像の契約 (先読み・到達点・KsImage の引き当て・キャッシュ操作) を iOS が Nuke の上でどの部品で実現し、どの罠を避けているか
tags: [ios, image, prefetch, nuke]
timestamp: 2026-09-26
---

# iOS 画像の先読みと KsImage の実現

この文書を読むと、[画像の先読みと KsImage](../../core/core-model/image-loading.md) の契約を iOS 側がどの部品で実現し、Nuke のどの性質を回避するために索引・引き当て・世代付き識別子を持っているかが分かる。利用者から見た契約 (宣言の形・到達点・許容範囲・キャッシュ操作の意味・プラットフォーム差) は core の文書が正で、この文書はその iOS 側の実現だけを扱う。core の文書と、コレクション本体の部品構成を述べた [iOS コレクションエンジン](collection-engine.md) を先に読むと分かりやすい。Android の対応物は [Android 画像の先読みと KsImage の実現](../../android/architecture/image-pipeline.md)。

## 全体像

```
KsCollectionViewController
  └ KsImagePrefetcher … prefetchResources の宣言 (KsResource) を取得単位へ解く台帳
       └ KsNukeImageLoading (受け口 KsImageLoading の本番実装) … 到達点ごとの Nuke ImagePrefetcher
KsImage (SwiftUI)  … KsImageRequestFactory が索引 (KsImageMemoryIndex) から引き当て、外れたときだけ
                     NukeUI LazyImage (先読みが取得中なら KsImageDeferredLoad) が共有パイプラインへ要求を出す
KsImageCache       … clear / remove。KsImagePrefetchRegistry を通じて先読みの取得を止めてから消し、
                     KsImageInvalidation の世代を進める
KsImagePipeline    … enableSharedDiskCache()
```

## 責務境界

| 部品 | 責務 |
|---|---|
| `KsImagePrefetcher` / `KsNukeImageLoading` | システムの先読み通知 (`KsPrefetching`、アイテム単位) を取得単位へ翻訳し、「アイテム ID → 宣言 (識別子・URL・幅の種類)」「取得単位 → 参照数と開始時の `ImageRequest`」の 2 層の台帳で寿命を管理する。列幅は controller が先読み通知の時点で `KsLayoutMetrics` の列数と bounds・余白・列間隔から解き、px で渡す。ローダー操作は internal な受け口 `KsImageLoading` に集め、本番は到達点ごとの `ImagePrefetcher` へ写像、テストは記録用の fake を注入する |
| `KsImageRequestFactory` / `KsImageIdentity` / `KsImageInvalidation` | `KsImage` の引き当てと表示要求の組み立て (外れたときの枠の実サイズからのデコード時縮小)、識別子 (キーまたは URL) と世代付き識別子の算出、キャッシュ消去の通知 (`ObservableObject`。下限 iOS 16 のため `@Observable` は使わない) |
| `KsImageMemoryIndex` / `KsImageMatching` | 引き当ての候補になる「メモリへ載せるよう要求した鍵」の索引 (主スレッドに閉じた LRU、上限 20,000 件) と、許容範囲 (必要な寸法の 0.5〜4 倍) の判定 (定数 0.5 / 4 はここに 1 か所) |
| `KsImageRetainedMatch` / `KsImageDeferredLoad` | 引き当てた画像と表示経路の選択を条件ごとに持ち続ける値と、画面に出る時点で引き当てを照会し直してから要求を出す包み (「範囲内のメモリ項目は要求を出さずに描き…」の節) |
| `KsImageCache` / `KsImagePrefetchRegistry` | 公開のキャッシュ操作 (`clear` / `remove`) の実装と、生存している先読み層 (コレクションごとの `KsImagePrefetcher`) の一覧。消す前に一覧を通じて先読みの進行中の取得を止める (「ソース単位の削除は…」の節) |
| `KsImagePipeline` | `enableSharedDiskCache()` の実装。`dataCache` が未設定なら `configuration` を引き継いで差し替える (core/ADR-0012) |

## 保証すること

### 画像の先読みは controller 生成時の共有パイプラインを捕捉する

`KsCollectionViewController` は生成時に `ImagePipeline.shared` を読んで `KsNukeImageLoading` を作る。`KsImagePipeline.enableSharedDiskCache()` を後から呼んでも既存のコレクションの先読みは差し替え前のパイプラインを使い続けるため、利用者契約は「起動時に一度呼ぶ」になる ([画像の先読みと KsImage](../../core/core-model/image-loading.md))。システムの先読みの取り消し通知 (`KsPrefetching`) には到達点が付かないため、`KsNukeImageLoading` は作成済みの全到達点の `ImagePrefetcher` へ停止を伝える。`ImagePrefetcher` は解放時に未完了の取得を止めるので、controller の解放で先読みは全停止する。

### 範囲内のメモリ項目は要求を出さずに描き、外れたときだけ 1 本の鍵で要求する

Nuke には近い大きさの項目を引き当てる手段も鍵の列挙も無く、`ThumbnailOptions` 付きの要求は寸法の違うメモリ項目を再利用せず再デコードする。そのため `KsImageMemoryIndex` が識別子ごとに `ImageRequest` を覚え、`KsImageRequestFactory` が組み立ての時点で候補をパイプラインのメモリキャッシュへ問い合わせて `KsImageMatching` で判定する (契約は [画像の先読みと KsImage](../../core/core-model/image-loading.md)、core/ADR-0013)。外れたときの表示要求は、常にデコード時縮小の指定 (`ThumbnailOptions` の `.aspectFit` / `.aspectFill`) を持つ 1 本の形にする。ローダーは要求そのものの鍵でメモリを引き、結果も同じ鍵へ書くため、表示要求を出す経路 (組み立て時の `LazyImage` と画面に出る時点の `KsImageDeferredLoad`) ごとに鍵を変えると自分で書いた項目に次の表示が当たらない。

UIKit はセルの中身を先読みの開始と同じ頃に組み立てるので、組み立てで一度だけ引き当てると、先読みの完了後に画面に出たセルもディスクから再デコードする (実機の計測で、画面に出たセル 147 件中 136 件)。そこで、先読みが取得中の可能性 (`mayBeLoadingPrefetch`) があるときだけ `KsImageDeferredLoad` で包み、画面に出る時点 (`onAppear`) で照会し直してから要求を出す。それ以外は組み立て時に `LazyImage` を置く (`LazyImage` も要求の開始は画面に出る時点)。`KsImageRetainedMatch` は、引き当てた画像と包みを選んだことを条件 (識別子と世代・`reloadToken` (世代付き識別子と全体の世代を連ねた値)・枠・表示倍率・当てはめ方) ごとに覚える。`clear(.memory)` は索引と取得中の記録を消すがどちらの世代も進めないため、覚えていないと直後の組み立て直しで `LazyImage` に切り替わり、表示中の画像をディスクから再デコードする。

### ソース単位の削除は世代付き識別子で旧項目を避ける

Nuke のメモリ鍵は縮小オプションを含み、Nuke には鍵を列挙する手段が無いため、どのサイズで要求したかを後から辿れない。`KsImageIdentity` は識別子を 1 か所で求める。キーなしは URL の文字列、キーありは `"ks-key " + key`、削除後は `"ks-gen N " + 識別子` で、キーと URL・世代付きの形と別のキーが衝突しない (core/ADR-0014)。`KsImageCache.remove(source)` は世代 0 の要求と現在の世代の要求の両方で消し、そのソースの世代を進める。以後の `KsImage` と先読みの要求は `ImageRequest.imageID` に世代付きの識別子を入れて発行する。世代 0 でキーなしのソースは `imageID` を付けず、NukeUI の `LazyImage` を直接使った表示と同じ項目を指し続ける。キーありのソースは世代 0 でも `imageID` を付け、メモリとディスクの両方の鍵がキーになる。`clear` は識別子を変えず、`KsImageInvalidation` の全体の世代だけを進めて (`.all` のとき)表示中の `KsImage` を組み立て直す。`clear` / `remove` は、生存している先読み層の一覧 (`KsImagePrefetchRegistry`) を通じて進行中の取得を止めてから消す。表示側の進行中の取得は止めない (Android に公開の取り消し口が無く、両プラットフォームで揃えるため)。

## 用語

| 用語 | 意味 |
|---|---|
| 到達点 | 先読みが画像をどこまで持ってくるか。`disk` (元データをディスクまで) と `memory` (デコード済みをメモリまで) |
| 受け口 (`KsImageLoading`) | ローダーへの操作を集めた internal な境界。本番は Nuke の adapter、テストは記録用の fake が入る |
| 識別子 / 索引 / 引き当て | 画像の鍵の基準 (キーまたは URL)、引き当ての候補の一覧、許容範囲に入る項目を探して使うこと。意味は [画像の先読みと KsImage](../../core/core-model/image-loading.md) の用語節 |
| 世代 | 2 種類ある。全体の世代 (`KsImageInvalidation`。`clear(.all)` で進み、表示中の `KsImage` を組み立て直させる) と、ソースの世代 (`remove` で進み、識別子に `"ks-gen N "` として混ざる) |
| 取得単位 / 幅の種類 / 許容範囲 / 鍵 | 先読みの台帳が参照数を数える単位、宣言の幅の指定の種類、引き当ててよい大きさの範囲、ローダーがキャッシュ項目を引く値。意味は core の用語節 |
| ローダー | 画像の取得・デコード・キャッシュを行う本体。iOS では Nuke の `ImagePipeline` |

## 関連

- [画像の先読みと KsImage](../../core/core-model/image-loading.md) — 先読み・到達点・キャッシュ操作の契約 (この文書はその iOS 側の実現)
- [iOS コレクションエンジン](collection-engine.md) — 先読み通知を出すコレクション本体の部品構成
- [Android 画像の先読みと KsImage の実現](../../android/architecture/image-pipeline.md) — 同じ契約の Android 側の実現
- core/ADR-0012 (Nuke への直接依存と共有パイプライン)、core/ADR-0013・0014 (許容範囲の引き当て・任意キー)
