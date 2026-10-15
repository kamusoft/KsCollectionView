# 画像ロード統合

画像の遅延ロード・キャンセル・キャッシュ・プリフェッチをリスト/グリッドの性能要件として成立させる。実行順は基盤 (phase-2/3) の直後・機能フェーズの前 (セル API の形を縛るため後付け不可)。

## 論点


### phase-1 からの申し送り (2026-09-01)

- DSL 外形は core/ADR-0008 で確定: `prefetchResources` クロージャ (アイテム → リソース列挙、データ型への準拠要求なし) + 同一ローダ・キャッシュを見る専用 `KsImage` の対。利用形は [dsl-samples.md](../phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md) シナリオ5
- `KsImage` は「提供するか」から「外形確定済み」に進んだ — 本フェーズの論点は機能範囲 (ダウンサンプリング既定値等) とローダー選定・依存の持ち方

## 決定事項

### ローダー依存の持ち方 — 本体が直接依存する (2026-09-05)

画像ローダーは本体 (`KsCollectionView` product / `kscollectionview` モジュール) が直接依存し、`KsImage` とプリフェッチ接続を本体に内蔵する。別 product での同梱・ローダー抽象 + アダプタは却下。ローダーの共有インスタンスをそのまま共有キャッシュとするため、`KsImage` を使わずローダー付属のビューを直接使う利用者にもプリフェッチが効く (論点「キャッシュ連携口」の前提)。core/ADR-0012 (proposed)。

### ローダーの選定 — iOS は Nuke、Android は Coil 3 (2026-09-05)

iOS は Nuke (13 系、`Nuke` + `NukeUI`)、Android は Coil 3 (`coil-compose` 系) に依存する。決め手は Nuke の `ImagePrefetcher` が URL 単位で開始・停止でき、本体の内部配線 (アイテム単位の prefetch / cancel) にそのまま繋がること、Swift Concurrency 移行済みで Swift 6 環境と相性がよいこと。Kingfisher はプリフェッチのキャンセルがインスタンス単位のみで却下。Android は Glide の Compose 統合が beta のため Coil 一択。core/ADR-0012 に統合。

### プリフェッチの宣言と到達点 — URL 配列のまま、既定はディスク (元データ) まで、メモリまで載せる指定も可 (2026-09-05)

宣言は ADR-0008 の外形どおり URL 配列のみ (複数 URL は配列で表現、優先度・サイズヒントは持たせない — Coil に優先度がなく対称にできない)。到達点は宣言の任意引数で選ぶ: **既定はディスク (元データ) まで**で、デコードと縮小は表示時に `KsImage` が行う。**メモリまで (元寸をデコードして載せる) も指定可** (Swift `.prefetchResources(destination: .memory) { }` / Kotlin `prefetchDestination = KsPrefetchDestination.Memory`。Nuke は宛先指定、Coil はメモリ方針の切替で実現)。ディスク鍵は両ローダーとも URL なので表示時の要求サイズに関係なく確実にヒットし、既定では元寸画像がメモリに載らない。元寸をメモリまでを既定にする案 (スクロール中は最軽量だがメモリ圧) と、サイズヒント付き宣言で縮小鍵まで合わせる案 (利用者に `KsImage` とのサイズ一致責任を負わせ、Android は列幅の自前計算が要る) は却下。iOS は Nuke のディスクキャッシュが既定で無効なので有効化が実装の前提 (TODO)。

### Android のプリフェッチ機構 — 自前の先読み窓でアイテム単位に取得・取り消し (2026-09-05)

可視範囲 (`LazyGridState.layoutInfo`) の観測からライブラリ自身が先読み窓を作り、窓に入ったアイテムの URL を Coil に `enqueue`、窓から外れたら `Disposable` で取り消す。iOS の内部配線 (アイテム単位の prefetch / cancel) と同じ契約になり、到達点 (ディスク / メモリ) の指定にも従える。安定 API のみ使用。Compose Foundation の先読み窓 (`LazyLayoutCacheWindow`) は BOM 2026.06.01 (foundation 1.11.4) では experimental で、かつセルを先に合成する機構のため到達点を制御できず却下。プリフェッチなし (ADR-0008 改訂が必要) も却下。窓幅の既定値は提案で決める。

### `KsImage` の機能範囲 — 薄い包みに縮小既定と表示スロットだけ持たせる (2026-09-05)

縮小の既定は**自身のレイアウトサイズ** (`KsImage` が置かれた枠。iOS はライブラリが枠を測って縮小処理を付け、Android は Coil の既定挙動に乗る)。引数は表示の当てはめ方 (`contentMode` / `contentScale`) と、読み込み中・失敗時の表示を差し替えるスロット (未指定なら無地の既定表示)。画面外に出たら読み込みを取り消す (両ローダーの既定挙動)。持たないもの: 縮小サイズの手動指定・フェードイン等の演出・ローダー個別設定の露出 (必要なら利用者がローダー付属のビューを直接使う。ADR-0012 の共有インスタンスでキャッシュは共有される)。最小 (スロットなし) とローダー付属ビューの薄い別名 (iOS の縮小が利用者任せ、語彙が揃わない) は却下。

### 画像ソースの種類 — ソース型を導入し、リモート / ファイル / リソースを 1 つの値で表す (2026-09-05)

`KsImage` は画像ソース型を受ける: Swift `KsImageSource` の `.remote(URL)` / `.file(URL)` / `.asset(名前)`、Kotlin `KsImageSource.Remote(String)` / `File(File)` / `Resource(@DrawableRes Int)`。`KsImage(url)` は便宜的な初期化子として残す。モデルにはライブラリの型を持ち込まず、テンプレート内でモデルの値をソースへ変換する (KMP 共有モデルの純粋性)。`prefetchResources` の返り値は ADR-0008 どおりリモート URL の配列のまま (ローカルソースはプリフェッチの対象外)。種類ごとの初期化子 (切り替えをテンプレートで分岐) と URL のみ (リソース画像は標準 `Image` で描く) は却下。iOS のアセットは Nuke の守備範囲外なので SwiftUI `Image` で直接描く経路になる。

### キャッシュ方針 — 表示時の保持は全種別ともローダー既定、ライブラリの調整点はプリフェッチの到達点のみ (2026-09-05)

`KsImage` が表示のために読み込んだ画像 (レイアウトサイズに縮小したもの) は、ソース種別に関わらず Nuke / Coil の既定どおりメモリキャッシュに保持される (画面外から戻ったときは再デコードなし、LRU で追い出されたらディスクの元データまたはローカルソースからデコードし直す)。ファイル・リソースは元がローカルにあるためディスクキャッシュは関与しない。ライブラリが持つ調整点は**プリフェッチの到達点 (既定ディスク / 指定でメモリ) だけ**で、ソース種別ごとの設定も `KsImage` の個別引数も導入しない。「表示後もメモリに残さない」案はスクロールで戻るたびに再デコードが走るため却下。

### iOS のプリフェッチ接続と、先行決定で決着した 2 項目 (2026-09-05)

**iOS の接続**: `UICollectionViewDataSourcePrefetching` のアイテム単位の prefetch / cancel を、そのまま Nuke `ImagePrefetcher` の URL 単位の開始 / 停止に流す。宛先はプリフェッチ宣言の指定 (既定ディスク)、優先度は Nuke のプリフェッチ既定 (低) のままで利用者に露出しない。Android の先読み窓と同じ契約 (「もうすぐ表示されるアイテムの URL を宛先まで取得し、離れたら取り消す」) として concepts に両プラットフォーム共通で書く。

**標準 API の限界**: SwiftUI `AsyncImage` にキャッシュ制御・縮小・重複統合がなく、Compose に標準ローダーがないことは調査で裏付け済み。ADR-0012 で Nuke / Coil に依存すると決めたため、自前実装しない方針ごと決着。

**`KsImage` を使わない画像部品とのキャッシュ連携口**: ADR-0012 の「ローダーの共有インスタンスをそのまま共有キャッシュ」により、同じローダーの付属ビューを直接使えば連携口なしでプリフェッチが効く。**別ローダーとの連携口は設けない**。

### キャッシュのクリアの口 — 同名の入口で範囲付き全消去とソース単位の削除 (2026-09-05)

両プラットフォーム同名の `KsImageCache` を提供する: `clear(.memory / .disk / .all)` の全消去と、`remove(source)` (`KsImageSource` を受け、リモート URL・ファイル・リソースのいずれも削除可) のソース単位の削除。ローダーのキャッシュ操作の薄い包みで、消えるのは ADR-0012 の共有インスタンスのキャッシュ (同じローダーを使う他画面の画像も消える — 共有の性質上不可避)。iOS のアセットは Nuke を通らず SwiftUI `Image` で描くため削除は no-op (中身が変わらないので実害なし)。全消去のみの入口と、入口を設けずローダー直叩きを案内する案は却下。

### 検証方法 — 配線は自動テスト、性能は Sample の実機計測を 1 回記録 (2026-09-05)

自動テスト: プリフェッチ宣言を付けたとき、もうすぐ表示されるアイテムの URL で取得が開始され、離れたら取り消されること (アイテム単位・宛先の指定が渡ること) を、ローダーを差し替えた検査用の受け口で確かめる (iOS はプリフェッチ配線、Android は先読み窓の差分計算)。実機計測: Sample に大量件数 (例: 1 万件) の画像グリッドのデモ画面を両プラットフォームに置き (sample-parity 準拠)、オーナーの実機でフリング中の開始 / 取消件数 (ローダーのログ) とメモリ推移 (Instruments / Android Studio Profiler) を 1 回計測して history に残す。数値目標・CI での継続計測は持たない。デモ画像は公開のプレースホルダー画像サービスの URL を使う。

## 実装結果 (2026-09-08 反映)

change `image-loading` (L 級) で両プラットフォームに `prefetchResources` (+ 到達点)・`KsImage`・`KsImageSource`・`KsImageContentMode`・`KsImageCache`・`KsPrefetchDestination` を新設した。iOS は Nuke 13.2 系、Android は Coil 3.5.0 (3.6 系は Compose 1.12 の推移で利用者に compileSdk 37 を強いるため固定) に本体が直接依存する。Android はキャッシュ操作の引数を iOS と揃えるため androidx.startup でアプリケーションコンテキストを捕捉する (android/ADR-0005)。契約の全体は concepts `core/core-model/image-loading.md`、実装の実際は `kasane/changes/archive/2026-09-24-image-loading/deviation.md`。

決定事項から変わった点:

| 決定事項 | 実装の実際 | 理由 |
|---|---|---|
| iOS のディスクキャッシュ有効化 (初回利用時に自動で差し替える設計) | 利用者が起動時に `KsImagePipeline.enableSharedDiskCache()` を明示的に呼ぶ | Nuke 13 は共有パイプラインの delegate を外から読めず、自動差し替えは delegate で要求を加工するアプリを黙って壊す |
| キャッシュのクリアの口 (`.memory` / `.disk` / `.all` の 3 択) | `.memory` / `.all` の 2 択 | ディスクの元データを消すとそこから作られたメモリ項目も落とす実挙動になり、`.disk` と `.all` が同じ動きになった |
| 画像ソースの種類 (Android のリソースも Coil 経由) | リソースは `painterResource` で同期描画 | 「リソースは読み込み中を経由しない」の契約を Coil 経由では満たせない |
| 到達点メモリ (元寸をメモリに載せ、表示時に縮小) | Android の実機では初回表示が読み込み中を一瞬経由する (暫定) | 元寸がハードウェアビットマップで画素を読めず、その場の縮小が成立しない。ハードウェア支援を切る回避策はオーナー方針で不採用 |
| 検証方法 (実機計測 1 回) | handbook の全系統を既存 fixture で回帰計測 + 画像グリッド fixture で絶対基準とメモリ | handbook の rule が上位 |

検証: 自動テスト (iOS 154 件 / Android 130 件 + 実機テスト 3 件)、verify-002 VALID、独立レビュー 13 周と相方レビュー 13 周。実機計測は、メモリ定常化が両プラットフォームとも合格、スクロールの絶対基準が両プラットフォームとも不合格 (iOS は画像ロードの実装が hitch の原因ではなく、対照「大量件数」が同じ手順で桁違いに超過。Android は cold の取得が原因ではない)。到達点メモリの実機クラッシュ (レビューと verify を素通りした欠陥) を修正し、実機で走るテストを本体に新設した。

オーナー受容済みの保留 4 件 (2026-09-08 の蒸留で受容): キャッシュ消去のフェンスは先読み層の進行中取得のみ対象 (表示側は対象外) / iOS 7.4 の判定対象は「戻った可視範囲 1〜12」に絞った読み方 / アクセシビリティテストの SPI (dlsym) 利用 / 7.3 Android (ローダー付属ビューとの共有) の実機再確認は未実施。

### 申し送り

| 項目 | 受け皿 |
|---|---|
| 到達点 `memory` の方式見直し (先読みの時点で表示サイズを知る) | 独立変更 `kasane/changes/prefetch-display-size` (簡易起票済み) |
| 性能規約の見直し (窓・閾値・帰属・fixture の件数)、「大量件数」の超過、計測の足場の負荷 | 独立変更 `kasane/changes/performance-criteria-review` (簡易起票済み。Android benchmark の frameCount 下限未判定を材料に追記) |
| iOS の区切り線更新の無駄 (毎レイアウトで全可視セルの背景色を代入) | 独立変更 `kasane/changes/ios-separator-update-guard` (簡易起票済み) |
| 利用者ドキュメント (サムネイル URL の宣言、`enableSharedDiskCache()` の運用と delegate、iOS `remove` の共有喪失、Android の startup 前提) | phase-7 の agenda に追記 (原料は concepts `core/core-model/image-loading.md`) |
| 実機でしか走らないテスト (`android/kscollectionview/src/androidTest/`) の CI の受け皿、iOS Sample にユニットテストターゲットが無いこと | phase-7 の agenda「検証 CI の構成」に追記 |
| core/ADR-0012 の確定 | 後続 3 change の決着後、2026-09-24 の再蒸留でオーナー確認を経て accepted。image-loading を `kasane/changes/archive/2026-09-24-image-loading/` へ archive |
| Android `KsImageSource.File` の `Uri` (content://) 対応 | 見送り。需要が出たら追加する (design の Open Question) |
| 7.3 Android の実機再確認 | 見送り (受容済み。spec の「再ダウンロードなし」はディスクでも満たす) |

## 実装結果 (2026-09-24 反映、prefetch-display-size)

change `prefetch-display-size` (L 級) で、先読みの要素を `KsResource` (URL + 任意の幅 `KsWidth` + 任意キー `key`) に変え、`KsImage` がメモリのキャッシュ項目を許容範囲で引き当てる形にした (core/ADR-0013・core/ADR-0014)。前節の表の「到達点メモリ」の Android の暫定は解消した。契約の全体は concepts `core/core-model/image-loading.md`、実装の実際は `kasane/changes/archive/2026-09-24-prefetch-display-size/deviation.md`。

決定事項から変わった点:

| 決定事項 | 実装の実際 | 理由 |
|---|---|---|
| プリフェッチの宣言と到達点 (URL 配列のまま。サイズヒント付き宣言は却下) | 要素を `KsResource` にし、任意の幅と任意キーを持たせた。URL だけの配列は廃止 (配布前) | 元寸の鍵と表示の鍵が一致せず、Android 実機で到達点メモリが成立しなかった。サイズヒント却下の理由 (利用者のサイズ一致責任・列幅の自前計算) は、許容範囲の引き当てと列幅の自動解決で成り立たなくなった (core/ADR-0013)。キーは署名付き URL のためのオーナー追加要望 (core/ADR-0014) |
| `KsImage` の機能範囲 (縮小の既定は自身のレイアウトサイズ、縮小サイズの手動指定は持たない) | メモリに許容範囲内のキャッシュ項目があればそれを優先し、自身のレイアウトサイズは無いときの縮小の目標として維持。手動指定を持たない点も維持 (許容範囲は公開しない) | core/ADR-0013 |

実装で design から変わった点は deviation.md に 9 件ある。利用者から見える差が大きいのは、先読みが取得中のときだけ `KsImage` の表示要求の開始を画面に出る時点まで遅らせ、その時点で引き当てをやり直すことである (コレクションが画面外のセルを先に組み立てる時点では先読みが未完了で外れ、spec「メモリ到達点の後の表示」が実機で破れていたため)。ほかに、Android の表示要求の鍵に当てはめ方を残したこと、索引を照会時に刈り込まないこと、先読みの幅を 16384 px で頭打ちにすることがある。

検証: 自動テスト (iOS パッケージ 276 件・Android ライブラリ 231 件・両 Sample)、verify-003 VALID、独立レビュー 10 周と相方レビュー 10 周。実機計測では、体感はなし以外の 3 設定とも両基準機で合格、先読みの完了後に画面に出たセルは両プラットフォームとも表示要求・取得・デコード・読み込み中が 0 件、メモリは往復で定常化した。止めてから画像が揃うまでの待ちの主因は取得の同時数で、先読みの方式とは別の要因だった。

### 申し送り (prefetch-display-size)

| 項目 | 受け皿 |
|---|---|
| 画像の表示待ちの主因 (取得の同時数・先読みと表示要求の優先度・Android の二重取得) | 独立変更 `kasane/changes/image-fetch-concurrency-priority` (簡易起票済み) |
| 利用者ドキュメント (先読みの幅・任意キーの運用) | phase-7 の agenda「phase-8 からの申し送り (2026-09-24、prefetch-display-size)」に追記 |
| Android `KsImageTest.urlConvenienceFormBehavesLikeRemoteSource` の揺れ (取得の回数を待たずに読む書き方。verify-003) | 独立変更 `kasane/changes/image-fetch-concurrency-priority` (exploration.md の未決の論点に追記。2026-09-24 に本フェーズの TODO から移管) |
| 表示要求を画面に出る時点まで遅らせた `KsImage` が、画面外に出たときに要求を取り消すことを数えたテストが無い (verify-003) | 独立変更 `kasane/changes/image-fetch-concurrency-priority` (exploration.md の未決の論点に追記。2026-09-24 に本フェーズの TODO から移管) |
| 性能改善後のビルドでの体感ゲートの取り直し (手動の最終走行は改善前のビルドで、改善は自動駆動の A/B で確認。verify-003) | 見送り。改善は遅らせる対象を絞って再合成を減らす向きで、A/B で Android の「メモリまで」の janky・P99 が比較用ビルドより良く、iOS の「ディスクまで」の悪化も消えたことを確かめている。体感を悪くする向きの変更ではない |
| iOS の性能検証手順のメモリ判定 (`phys_footprint`) が、展開済みの画像の記憶域を数えていない可能性 (`evidence/memory-steady-ios.md`) | 見送り。本 change の「元寸を載せない」はキャッシュの大きさと項目の寸法で示せた。画像キャッシュのメモリ量を合否に使う変更が出たときに手順を見直す |

## TODO

core/ADR-0012 の確定と image-loading の archive は、簡易起票済みの 3 change (`prefetch-display-size` / `performance-criteria-review` / `ios-separator-update-guard`) で到達点・性能基準まわりの内容が動きうるためオーナー判断で保留している (2026-09-08)。実装フェーズで解ききれず別 change に逃がした部分があり、そこが落ち着くまで決定を固めない。それらの決着後に image-loading と併せて再蒸留し、確定と archive を行う。

決着 (2026-09-24): `performance-criteria-review` は 2026-09-17、`prefetch-display-size` と `ios-separator-update-guard` は 2026-09-24 に archive した。いずれも core/ADR-0012 の決定を動かさなかった (core/ADR-0013・0014 は ADR-0012 を前提にした例外で、footer の関連行で繋いだ)。同日に再蒸留し、core/ADR-0012 を accepted にして image-loading を archive した。残っていたテストの TODO 2 件を独立変更 `image-fetch-concurrency-priority` へ移し、本フェーズを completed にした。

- [x] 論点の解消 (2026-09-05)
- [x] core/ADR-0012 (proposed) のオーナー確認 → accepted へ昇格 (2026-09-24)
- [x] Sample のデモ画像に使う公開プレースホルダー画像サービスの選定 (identity lint の許可設定を含む) (2026-09-06: Lorem Picsum)
- [x] iOS: Nuke の共有パイプラインでディスクキャッシュ (DataCache) を有効化する設計 (既定無効。共有インスタンスをそのまま使う ADR-0012 との両立方法) (2026-09-07: 明示 API `enableSharedDiskCache()`。実装結果を参照)
- [x] 利用者ドキュメント: グリッドにはサムネイル用途の URL を申告する運用を書く (2026-09-08: 原料を concepts へ蒸留、実制作は phase-7 へ申し送り)
- [x] ksn-propose で変更提案を起こす (2026-09-05: image-loading)
- [x] Android `KsImageTest.urlConvenienceFormBehavesLikeRemoteSource` を、取得の回数を待ってから読む形に直す (負荷が高いと揺れる。prefetch-display-size の verify-003 の申し送り) (2026-09-24: 独立変更 image-fetch-concurrency-priority へ移管)
- [x] 表示要求を画面に出る時点まで遅らせた `KsImage` が、画面外に出たときに要求を取り消すことを両プラットフォームの単体テストで固定する (prefetch-display-size の verify-003 の申し送り) (2026-09-24: 独立変更 image-fetch-concurrency-priority へ移管)
