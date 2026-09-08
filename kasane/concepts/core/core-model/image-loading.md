---
type: concept
title: 画像の先読みと KsImage
description: prefetchResources による画像の先読み (到達点・取り消し・共有キャッシュ)、専用画像コンポーネント KsImage の表示契約、KsImageCache によるキャッシュ操作の契約と限界 (iOS / Android 共通)
tags: [core-model, image, prefetch, cache]
timestamp: 2026-09-08
---

# 画像の先読みと KsImage

この文書を読むと、コレクションが「もうすぐ表示される項目」の画像を先読みする仕組みを利用者がどう宣言し、先読みした画像がどこまで届き、`KsImage` がそれをどう表示し、キャッシュをどう消せるかが分かる。あわせて、両プラットフォームで揃わない箇所とその理由が分かる。項目モデルの契約は [collection-items](collection-items.md) を先に読むと分かりやすい。実現方法は [iOS コレクションエンジン](../../ios/architecture/collection-engine.md) と [Android Compose ラッパー](../../android/architecture/compose-wrapper.md) にある。ADR は `kasane/decisions/<domain>/` にあり、本文では `core/ADR-0012` の形で指す。

## 目的

画像グリッドはこのライブラリの最頻ユースケースで、「もうすぐ表示される項目」を知っているのはライブラリだけである。その情報を外に出す代わりに、項目 → 画像 URL の対応をクロージャで宣言させ (core/ADR-0008)、同じローダー・同じキャッシュを見る `KsImage` を対で提供する。ローダーはライブラリのパッケージ本体 (iOS の `KsCollectionView` product / Android の `kscollectionview` モジュール) が直接依存する Nuke (iOS) と Coil 3 (Android) で、ローダーの共有インスタンスをそのまま共有キャッシュにする (core/ADR-0012)。利用者は本体を入れるだけで先読みと表示が繋がる。

## 公開 API

```swift
KsCollectionView(photos) { photo in
    KsImage(.remote(photo.thumbnailURL)).aspectRatio(1, contentMode: .fill)
}
.prefetchResources(destination: .disk) { photo in [photo.thumbnailURL] }   // destination は省略可 (既定 .disk)

KsImage(.remote(url), contentMode: .fit) { ProgressView() } failure: { Text("表示できません") }
KsImage(url)                                                                // .remote(url) の便宜形
KsImageCache.clear(.all)                                                    // .memory / .all
KsImageCache.remove(.remote(url))
KsImagePipeline.enableSharedDiskCache()                                     // iOS のみ。アプリ起動時に一度
```

```kotlin
KsCollectionView(
    items = photos, key = { it.id },
    prefetchResources = { photo -> listOf(photo.thumbnailUrl) },
    prefetchDestination = KsPrefetchDestination.Disk,                       // 省略可 (既定 Disk)
) {
    template { photo -> KsImage(KsImageSource.Remote(photo.thumbnailUrl), modifier = Modifier.fillMaxWidth().aspectRatio(1f)) }
}

KsImage(KsImageSource.Remote(url), contentMode = KsImageContentMode.Fit, loading = { CircularProgressIndicator() }, failure = { Text("表示できません") })
KsImage(url)                                                                // KsImageSource.Remote(url) の便宜形 (url は String)
KsImageCache.clear(KsImageCacheScope.All)
KsImageCache.remove(KsImageSource.Remote(url))
```

| 語彙 | Swift | Kotlin |
|---|---|---|
| 先読みの宣言 | `.prefetchResources(destination:_:)` modifier | `prefetchResources` / `prefetchDestination` 引数 |
| 到達点 | `KsPrefetchDestination` の `.disk` / `.memory` | `KsPrefetchDestination.Disk` / `Memory` |
| 画像ソース | `KsImageSource` の `.remote(URL)` / `.file(URL)` / `.asset(String)` | `KsImageSource.Remote(String)` / `File(java.io.File)` / `Resource(@DrawableRes Int)` |
| 当てはめ方 | `KsImageContentMode` の `.fit` / `.fill` (既定 `.fill`) | `KsImageContentMode.Fit` / `Fill` (既定 `Fill`) |
| 読み込み中・失敗の表示 | `loading:` / `failure:` の `@ViewBuilder` スロット | `loading` / `failure` の Composable スロット |
| 画像の説明 (アクセシビリティ) | `.accessibilityLabel(_:)` modifier | `contentDescription` 引数 |
| キャッシュの消去範囲 | `KsImageCacheScope` の `.memory` / `.all` | `KsImageCacheScope.Memory` / `All` |
| ディスクキャッシュの有効化 | `KsImagePipeline.enableSharedDiskCache()` | 無し (Coil は既定で有効) |

Kotlin には modifier に当たる構文が無いため、到達点はフラットな名前付き引数 `prefetchDestination` になる (`destination` だけでは何の到達点か読めないので接頭辞を付ける。core/ADR-0002 の記法差)。Swift で末尾クロージャを 1 つだけラベルなしで書く形 (`KsImage(source) { … }`) は、読み込み中と失敗のどちらにも当たりうるため書けず、上の例のように `failure:` のラベルを付けて 2 つ並べるか、片方だけをラベル付きで書く。

## 責務境界

| 責務 | 持つ側 | 具体 |
|---|---|---|
| 項目 → リモート URL の対応 | 利用者 | 先読みの宣言で返す。返すのはリモート URL だけで、ファイル・リソースのソースは先読みの対象外。モデルにライブラリの型を持ち込まない |
| 宣言する URL の寸法 | 利用者 | サムネイル一覧には、その用途の寸法で配信される URL を宣言する (下記) |
| `KsImage` の表示枠の大きさ | 利用者 | `.frame` / `.aspectRatio` (Swift)、`Modifier.size` / `aspectRatio` (Kotlin) で与える (下記) |
| iOS のディスクキャッシュの有効化 | 利用者 | アプリ起動時に `enableSharedDiskCache()` を一度呼ぶ (「共有キャッシュ」の節) |
| 先読みの対象の決定と開始・取り消し | ライブラリ | iOS はシステムの先読み通知、Android は自前の先読み窓 (進行方向の一定件数を対象にする窓。用語の節) |
| 到達点の対応付けと縮小デコード | ライブラリ | 到達点をローダーの取得方針に対応付け、`KsImage` は枠の実サイズへ縮小してデコードする |
| キャッシュの保持と追い出し | ローダー | メモリ・ディスクとも Nuke / Coil の既定 (LRU) に乗せる。ライブラリ独自のキャッシュ領域は持たない |

先読みは縮小を掛けず元寸のまま取得する。原寸画像の URL をグリッドに宣言すると、到達点 `memory` では画面と無関係な量のメモリを使い、到達点 `disk` でも通信量とディスク使用量が原寸のままになる。`KsImage` は枠が決まるまで取得を始めないため、枠の大きさを与えないと iOS は親から与えられた領域いっぱいに広がり、Android は高さ 0 で見えない。

## 保証すること

### 先読みは項目単位で始まり、離れたら取り消される

先読みの対象は「可視範囲の外側で、進行方向に並ぶ項目」で、可視範囲内の項目は含めない (表示側の `KsImage` が読む)。対象の決め方はプラットフォームで異なるが契約は同じ。

| | iOS | Android |
|---|---|---|
| 対象と取り消しのタイミング | `UICollectionViewDataSourcePrefetching` の判定に従う | 可視範囲の観測から、進行方向へ可視件数と同数の項目を窓にする。静止時は直前の進行方向を保ち、初期表示は末尾方向 |
| 配列の差し替えで消えた項目 | snapshot 適用時にライブラリが取り消す (システムからは通知が来ない) | 窓の作り直しで取り消す |
| コレクションの破棄 | controller の解放で全停止 | コンポジション離脱で全停止 |

取り消しは進行中の取得にだけ作用し、完了してキャッシュに入ったものは消さない。ライブラリは台帳を二層で持つ — 項目の安定 ID ごとに解決した URL の集合と、URL ごとにそれを必要としている項目の数 (参照数)。同じ URL を複数の項目が返す場合、その URL の取得は参照数が 0 になるまで、つまり必要としている項目が 1 つでも残る限り止めない。宣言が無いコレクションでは先読みも可視範囲の観測も起きず、空配列を返した項目は何も取得しない。先読みのクロージャと到達点は表示中に差し替えない前提の宣言で、差し替えは次の先読み通知・配列更新から新しい要求に反映される。

### 到達点は「どこまで持ってくるか」を決める

| 到達点 | 意味 | iOS (Nuke `ImagePrefetcher`) | Android (Coil `ImageRequest`) |
|---|---|---|---|
| `disk` (既定) | 元データをディスクキャッシュに保存するまで。デコードしない | `destination: .diskCache` | `memoryCachePolicy(DISABLED)` + デコード省略 |
| `memory` | ディスクに保存した上で、元寸をデコードしてメモリキャッシュにも載せる | `destination: .memoryCache` | サイズ指定なしの `enqueue` (元寸でデコード) |

どちらでも、先読みした画像は同じ URL の `KsImage` に再ダウンロードなしで使われる。到達点 `memory` が載せる元寸の鍵と、表示側の縮小指定付きの鍵は一致しないため、`KsImage` はメモリにある元寸をその場で枠の大きさへ縮小して初回描画に使い、以後は表示サイズ付きの鍵で当たる。

Android の実機ではこの引き当てが通常成立しない。先読みが載せた元寸の画素は GPU 側のメモリ (Android のハードウェアビットマップ) に置かれ、CPU から読み出せないため、初回表示が読み込み中を一瞬経由してローダーの縮小デコードを待つ。エミュレータ・JVM 上のテストではソフトウェアビットマップになり、その場で縮小して即座に描く。この非対称は暫定で、先読みの時点で表示サイズを知る方式への見直し (変更 `kasane/changes/prefetch-display-size`) で解消する。ハードウェアビットマップを使わない指定で挙動を揃える回避策は採らない (描画のたびに画素の転送費用が乗る)。

### 先読みと表示は同じ共有キャッシュを見る

先読みと `KsImage` は iOS が `ImagePipeline.shared`、Android が `SingletonImageLoader` を使う。同じローダーの付属ビュー (`LazyImage` / `AsyncImage`) を利用者が直接使っても同じキャッシュを見るので、先読みが効く。Android は `coil-compose` が Gradle の `api` 構成で推移的に公開されるため、利用者は Coil を自分で依存に足さずに `AsyncImage` を使える。

iOS の共有パイプラインは既定でディスクキャッシュを持たない。`KsImagePipeline.enableSharedDiskCache()` を呼ぶと、`dataCache` が未設定のときだけ現在の構成を引き継いでディスクキャッシュを足した構成に差し替える (アプリが先に構成していれば何もしない)。呼ばない限り、到達点 `disk` でも元データはディスクに残らず、アプリを再起動すると再ダウンロードになる。呼び出しには 2 つの帰結がある。

| 帰結 | 利用者がすること |
|---|---|
| 共有パイプラインの `ImagePipeline.Delegate` が既定に戻る | 要求の加工 (認証ヘッダ等) を delegate で行うアプリは呼ばず、`dataCache` を設定した `ImagePipeline` を自分で `ImagePipeline.shared` に置く |
| 表示を始めた後に呼んでも、既に生きているコレクションの先読みには反映されない | アプリ起動時 (`@main` の `init` 等) に一度だけ呼ぶ |

delegate が戻るのは、Nuke 13 が共有パイプラインの delegate を外から読む API を公開していないため。既存のコレクションに反映されないのは、先読みの経路がコレクション生成時の共有パイプラインを捕捉するためで、`KsImage` の表示側は要求のたびに現在の共有パイプラインを使うので、遅れて呼ぶと同じ画面で先読みと表示が別のパイプラインを使う状態になりうる。

### KsImage は枠の実サイズに縮小し、3 状態を持つ

`KsImage` は読み込み中・成功・失敗の 3 状態を持ち、読み込み中と失敗の表示はスロットで差し替えられる (未指定なら無地の既定表示)。表示のために元寸の画像をメモリに保持せず、枠の実サイズに縮小してデコードする。縮小の目標は当てはめ方で決まり、`fit` は枠に収まる最大寸法、`fill` は枠を覆う最小寸法 (はみ出しは表示されない)。枠のサイズが変わったら新しいサイズで再デコードする。

| ソース | 描画経路 | 読み込み中の状態 |
|---|---|---|
| リモート / ファイル | ローダー (iOS `LazyImage`、Android は `rememberAsyncImagePainter` で状態を観測し Composable スロットを自前で切り替える) | メモリキャッシュに無ければ経由する。あれば経由せず成功になる |
| アセット (iOS) / リソース (Android) | ローダーを通さない同期描画 (SwiftUI `Image` / Compose `painterResource`) | 経由せず、成功か失敗になる。Android で描画リソースとして読めない ID は debug ビルドでは assertion で停止、release は警告ログと失敗表示 (core/ADR-0011) |

画面外に出て破棄された `KsImage` の未完了の読み込みは取り消され、完了した画像はローダーのメモリキャッシュに残る。同じソース・同じサイズで再び表示されたときは再デコードなしに表示され、追い出されていればディスクの元データまたはローカルソースから再デコードする。失敗した `KsImage` は、ビューが作り直されたとき (セルの再利用・画面への再入場) と、`KsImageCache` の `clear(.all)` / `remove` でそのビューに関わる世代が進んだときに再試行し、同じビューが表示され続けている間は自動で再試行しない。

### キャッシュ操作は戻った時点で完了している

`clear(scope)` と `remove(source)` は共有インスタンスのキャッシュを消すので、同じローダーを使う他画面の画像も対象になる。呼び出しから戻った時点で削除は完了しており、以後の同じソースの要求はキャッシュに当たらない。ライブラリは消す前に、先読み層が出した進行中の取得を止める (止めないと、消した後に完了した取得が書き戻す)。

| 操作 | 消えるもの | 表示中の `KsImage` | 世代 |
|---|---|---|---|
| `clear(.memory)` | メモリ上のデコード済み画像 | 置き換えない。次に表示されるときにディスクから再デコード | 進まない |
| `clear(.all)` | メモリとディスクの両方 | 読み込み中の表示に戻って再取得する | 全体の世代が進む |
| `remove(source)` | そのソースのメモリキャッシュ上の項目 (あらゆる表示サイズ) とディスクの元データ | そのソースの表示だけが読み込み中に戻る | そのソースの世代が進む (iOS では要求の識別子にも混ざる) |

消去範囲に「ディスクだけ」は無い。ディスクの元データを消しつつそこから作られたメモリ項目を残す動きはローダーの構造上作れず、同じ動きをする選択肢を 2 つ公開すると誤解を招くため 2 択にしている。

## してはいけないこと

- 先読みの宣言に原寸画像の URL を返さない。グリッドには表示用途の寸法で配信される URL を宣言する (責務境界)。
- iOS で `enableSharedDiskCache()` を表示開始後に呼ばない。起動時に一度だけ呼ぶ (「共有キャッシュ」の節)。
- iOS で `KsImage` と `LazyImage` を同じ URL で混在させるアプリでは、個別削除に `remove` を使わない (理由は下記)。`clear` を使うか、削除後の再表示を両方の経路で確認する。
- Android でファイル・リソースのソースを確実に消したいときに `remove` に頼らない。`remove(File)` は Coil の鍵の作り方に依存する best-effort で、`remove(Resource)` はローダーを通らないため何もしない (iOS のアセットと対称)。`clear` を使う。
- Android で `androidx.startup.InitializationProvider` をマニフェストから取り除いた構成でキャッシュ操作を期待しない (理由は下記)。

iOS で `remove` したソースは、以後 `KsImage` と先読みの要求が「URL + 世代」の識別子を持つようになり、`LazyImage` が素の URL で引く項目とは別になる。直接使いの側には LRU で追い出されるまで古い画像が出うる。`clear` は識別子を変えないので共有に影響せず、一度も `remove` していないソースも共有される。

Android のライブラリは `InitializationProvider` に相乗りしてアプリケーションのコンテキストを捕捉している (android/ADR-0005)。無い環境では `clear` / `remove` は警告ログだけで何もせず、表示は動くため消えないキャッシュが残る。

## 性能

Sample「画像グリッド」(10,000 件・3 列・正方形 `KsImage`、公開のプレースホルダー画像サービス) を固定 fixture として両プラットフォームの基準機で計測した。メモリの定常化は両プラットフォームとも合格。スクロールの絶対基準 (iOS の hitch time ratio、Android の frameOverrun P99) は両プラットフォームとも基準値を超過して不合格だが、iOS では画像ロードの実装が hitch の原因ではないこと、画像を使わない対照の Sample「大量件数」画面が同じ手順で桁違いに超過することが判明したため、性能の合否は規約 (窓・閾値・fixture の件数) の見直し (変更 `kasane/changes/performance-criteria-review`) を待つ状態にある。手順と基準は [iOS](../../../handbook/ios/performance-verification.md) / [Android](../../../handbook/android/performance-verification.md) の性能検証規約。

## 用語

- **先読み (プリフェッチ)**: もうすぐ表示される項目の画像を、表示の要求より前に到達点まで取得すること。宣言は `prefetchResources`。
- **到達点**: 先読みがどこまで画像を持ってくるか。`disk` (元データをディスクまで) と `memory` (デコード済みをメモリまで)。
- **先読み窓**: Android で先読みの対象になる項目の集合。可視範囲の外側・進行方向・可視件数と同数。
- **共有キャッシュ**: ローダーの共有インスタンス (`ImagePipeline.shared` / `SingletonImageLoader`) が持つメモリ・ディスクのキャッシュ。ライブラリ独自の領域ではない。
- **鍵**: ローダーがキャッシュを引くときの識別子。ディスクは URL、メモリは URL に表示サイズ・当てはめ方 (表示側) や世代 (iOS の `remove` 後) が混ざる。
- **世代**: キャッシュを消したことを表示中の `KsImage` へ伝える番号。`clear(.all)` は全体の世代、`remove` はソースごとの世代を進める。iOS ではソースの世代を要求の識別子にも混ぜ、削除前の項目に二度と当たらないようにする。
- **ソース**: `KsImageSource` の値。リモート URL・端末内のファイル・バンドル済みリソース (iOS はアセット名、Android はリソース ID) の 3 種。

## 関連

- [collection-items](collection-items.md) — 項目モデルと安定 ID (先読みの台帳は安定 ID で項目を追う)
- [iOS コレクションエンジン](../../ios/architecture/collection-engine.md) — Nuke への接続、表示要求の鍵、世代付き識別子の実現
- [Android Compose ラッパー](../../android/architecture/compose-wrapper.md) — 先読み窓、表示要求の鍵、アプリケーションコンテキストの捕捉
- core/ADR-0008 (DSL 外形)、core/ADR-0012 (ローダーの直接依存と共有キャッシュ・iOS のディスクキャッシュの明示的な有効化)、core/ADR-0002 (記法差)、core/ADR-0011 (不正入力)、android/ADR-0005 (アプリケーションコンテキストの捕捉)
- [dsl-samples](../../../roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md) のシナリオ 5 — 利用形の全体
