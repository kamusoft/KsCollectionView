# 利用者向け注記の原料 (image-loading)

蒸留で concepts へ移すための原料。読むと、この変更で利用者が知らないと困る運用と限界が
一覧できる。各項目は「何が起きるか」「なぜそうなっているか」「利用者は何をすればよいか」の
3 点を持つ。

出典は本 change の `deviation.md`・`design.md` の Decision と、実装したコードである。
1〜3 は deviation.md に既に記録されている材料の要約で、4〜6 が tasks 8.1 で足した項目、
8〜10 はレビュー 4 周目までの実装変更で新たに利用者から見えるようになった挙動である。

## 1. iOS: ディスクキャッシュは明示的に呼んだときだけ有効になる

`KsImagePipeline.enableSharedDiskCache()` を呼ぶまで、Nuke の共有パイプライン
(`ImagePipeline.shared`) はディスクキャッシュを持たない (Nuke 13 の既定)。呼ばない限り、
プリフェッチの到達点 `disk` は元データをディスクに残さず、アプリを再起動すると再ダウンロードに
なる。

差し替えの条件は「共有パイプラインの `configuration.dataCache` が `nil` のときだけ」で、
アプリが先にディスクキャッシュを構成していれば何もしない (アプリの構成を尊重する)。

利用者がすること: アプリの起動時に一度だけ呼ぶ (`@main` の `init` 等)。

## 2. iOS: 差し替えで割り込み処理 (`delegate`) は既定に戻る

`enableSharedDiskCache()` は現在の `configuration` を引き継ぐが、共有パイプラインに設定された
`ImagePipeline.Delegate` は引き継げず、既定に戻る。Nuke 13.2.0 が共有パイプラインの
`delegate` を外から読む手段を公開していない (宣言が internal) ためである。

リクエスト直前に認証ヘッダを付けるなど、delegate で要求を加工しているアプリは、この呼び出しで
その加工が失われ、画像が読めなくなる。

利用者がすること: delegate を使っているアプリは `enableSharedDiskCache()` を呼ばず、
`dataCache` を設定した `ImagePipeline` を自分で組み立てて `ImagePipeline.shared` に置く。

## 3. iOS: 表示を始めた後に呼んでも既存のコレクションには反映されない

プリフェッチの経路はコレクション生成の時点で共有パイプラインを捕捉する
(`KsCollectionViewController` が `ImagePipeline.shared` を読んでローダーを作る)。表示を始めた
後に `enableSharedDiskCache()` を呼んでも、既に生きているコレクションのプリフェッチは
差し替え前のパイプライン (ディスクキャッシュ無し) を使い続ける。

一方 `KsImage` の表示側 (`LazyImage`) は要求のたびに現在の共有パイプラインを使うため、
同じ画面の中でプリフェッチと表示が別のパイプラインを使う状態になりうる。

利用者がすること: 起動時に一度だけ呼ぶ (項目 1 と同じ運用)。

## 4. グリッドにはサムネイル用途の URL を申告する

`prefetchResources` で申告した URL は、縮小処理を付けずに**元寸のまま**取得される
(design Decision 3)。到達点が `memory` のときは、その元寸の画像がデコードされてメモリ
キャッシュに載る。表示側の `KsImage` は表示枠の実サイズに縮小してデコードするが (Decision 5)、
プリフェッチ側にはその縮小が掛からない。

そのため、1 辺数千ピクセルの原寸画像の URL を 3 列のグリッドに申告すると、到達点 `memory` では
画面に見えている大きさと無関係な量のメモリを使う。到達点 `disk` (既定) ではデコードしないので
メモリには載らないが、通信量とディスク使用量は原寸のままである。

利用者がすること: グリッドやサムネイル一覧では、その用途の寸法で配信される URL
(サーバ側のサムネイル URL・サイズ指定付きの URL) を `prefetchResources` に申告する。

## 5. iOS: `remove` したソースはローダー付属ビューとキャッシュを共有しなくなる

`KsImageCache.remove(source)` はそのソースの世代番号を進め、以後の `KsImage` とプリフェッチの
要求は「URL + 世代」を識別子として発行する (design Decision 7)。Nuke のメモリ鍵は縮小
オプションを含み、どのサイズで要求したかを後から列挙できないため、世代を切り替えることで
「あらゆる縮小サイズの古い項目に二度と当たらない」を成立させている。

その帰結として、利用者が同じ URL を Nuke の `LazyImage` で直接使っている場合、`remove` の後は
`KsImage` 側と識別子が異なるためキャッシュが共有されなくなる。直接使いの側には、LRU で
追い出されるまで古い画像が出続けうる。

`clear(scope)` は識別子を変えないため、この影響はない。一度も `remove` していないソース
(世代 0) も素の URL のままなので共有される。

利用者がすること: `KsImage` と `LazyImage` を同じ URL で混在させるアプリでは、個別削除に
`remove` ではなく `clear` を使うか、削除後の再表示を両方の経路で確認する。

## 6. Android: `remove` はリモート以外のソースでは best-effort

`KsImageCache.remove(source)` は Coil のキャッシュ鍵を URL から導く。`KsImageSource.Remote` は
鍵が URL そのものなので確実に消えるが、`KsImageSource.File` はメモリ鍵を完全一致と、Coil が
file URI に付ける接尾辞の前置一致で拾っており、Coil の鍵の作り方が変わると取りこぼしうる。
この経路は自動テストで担保していない (spec の Scenario がリモートのソースだけを要求している)。

`KsImageSource.Resource` の `remove` は no-op である。リソースはローダー (Coil) を通さず
同期的に描く (アプリの `Context` から drawable を起こしてそのまま描く) ため、消すキャッシュ
項目が無い。iOS のアセットが no-op であるのと対称になっている。

利用者がすること: ファイル・リソースのソースを確実に消したい場合は `clear(scope)` を使う。

## 7. Android には共有キャッシュを有効化する API が無い

Coil 3 は既定でメモリキャッシュとディスクキャッシュの両方が有効なため、iOS の
`KsImagePipeline.enableSharedDiskCache()` に当たる API は Android に用意していない
(deviation.md)。両プラットフォームで公開面が 1 対 1 にならない箇所として、concepts に
理由つきで残す。

## 8. Android: 読めないリソース ID は debug ビルドで停止する

`KsImage(KsImageSource.Resource(id))` に描画リソースとして読めない ID (存在しない ID・
drawable ではない ID・読み取りに失敗する XML) を渡すと、**組み込み先アプリが debug ビルドの
ときは例外で停止する** (`IllegalStateException`)。release ビルドでは停止せず、警告ログを残して
失敗の表示に切り替える。判定に使うのは組み込み先アプリの debuggable フラグで、
core/ADR-0011 の「不正入力は debug で止め、release では縮退する」に従う。

`KsImage` は本 change で新設した API なので、既存の利用者コードが新たに落ちるようになることは
ない。読めない ID を渡している利用者コードが debug で止まる、というだけである。

利用者がすること: debug で止まったら、渡している ID が drawable として解決できるかを確かめる
(ログのメッセージに ID が出る)。

## 9. アクセシビリティの記法はプラットフォームで異なる

画像の説明の与え方は両プラットフォームで形が違う。Android は `KsImage` の
`contentDescription` 引数、iOS は SwiftUI の `.accessibilityLabel(_:)` modifier である
(core/ADR-0002 が「各プラットフォームの流儀に残すもの」として modifier 記法を名指ししている)。
できることは同じで、説明は読み込み中・失敗・成功のどの状態でも読み上げに残る。読み上げの性格
(画像であること) も両プラットフォームとも状態によらず保たれる (Android は `Role.Image`、
iOS は既定の表示に付けた画像の trait)。ただし iOS で読み込み中・失敗のスロットを利用者が
差し替えた場合は、その中身の性格が優先される。

説明を付けない場合の既定は非対称である。Android は読み上げの対象にならない (飾りの画像として
扱う)。iOS は**名前を持たない要素が 1 つ残る** — これは SwiftUI の `Image` が元からそうなる
ためで、`KsImage` はその形を 3 状態でそろえている。

利用者がすること: iOS で装飾目的の画像を読み上げから完全に外したいときは
`.accessibilityHidden(true)` を付ける (Android の `contentDescription = null` に相当する)。

## 10. Android: キャッシュ操作は起動時の初期化が動いていることが前提

`KsImageCache.clear` / `remove` は、ライブラリの起動時の初期化 (androidx.startup の
`InitializationProvider`) が動いていることを前提にする。初期化を無効にしている構成では、
どちらも**警告を記録するだけで何もしない** (共有ローダーを安全に特定する手段が無いため)。
画像の表示そのものは初期化が無効でも動くので、**消えないキャッシュが残る**状態になる。

落とさずに戻るのは、初期化を外す構成が androidx.startup の正規の運用であり、そこで例外を
投げると利用者に回避手段が無くなるためである (core/ADR-0011 の「落とさず・黙らず」)。

利用者がすること: キャッシュ操作が効かないときは、AndroidManifest.xml から
`androidx.startup.InitializationProvider` を取り除いていないかを確認する (警告ログにも同じ
案内が出る)。
