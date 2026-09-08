---
id: 0012
title: 画像ローダー — 本体が iOS は Nuke・Android は Coil 3 に直接依存し KsImage とプリフェッチ接続を内蔵する
status: proposed
date: 2026-09-07
---

## Context

core/ADR-0008 は `prefetchResources` クロージャと専用画像コンポーネント `KsImage` の対を DSL 外形として確定し、ローダー選定・キャッシュ設計・依存の持ち方は画像ロード統合の変更 (image-loading) に委ねた。iOS 本体には `UICollectionViewDataSourcePrefetching` からアイテム単位の prefetch / cancel を内部プロトコルへ流す配線が既にあるが、中身は空で埋める公開 API がない。Android 側に対応物はない。

隣接リポジトリに画像ローダーを実依存として採用した前例はなく、旧 AiForms.CollectionView は本体無依存のまま README で FFImageLoading を推奨していた (ADR-0008 はこれを `KsImage` として内蔵化する決定)。

前提: 主目的が自社 KMP アプリの量産で、利用者にローダー統合の手順を課す価値が薄い (cross/ADR-0001)。両プラットフォームに MIT / Apache-2.0 で活発に保守される標準的なローダー (iOS: Nuke 等、Android: Coil) が存在する。Nuke 13 の共有パイプライン (`ImagePipeline.shared`) は既定でディスクキャッシュを持たず、共有パイプラインに設定された `ImagePipeline.Delegate` を外から読む手段を公開していない (宣言が internal)。Coil 3 の共有インスタンス (`SingletonImageLoader`) は既定でメモリとディスクの両方のキャッシュを持つ。

## Decision

**直接依存と内蔵。** 画像ローダーは本体 (iOS の `KsCollectionView` product / Android の `kscollectionview` モジュール) が直接依存する。`KsImage` とプリフェッチ接続は本体に内蔵し、利用者は本体を導入するだけで両方が効く。

**共有インスタンスをそのまま共有キャッシュにする。** ライブラリ独自のキャッシュ層や抽象を挟まない。これにより `KsImage` を使わずローダー付属のビューを直接使う利用者にもプリフェッチが効く。Android は `coil-compose` を `api` で公開し、利用者が Coil を自分で依存に足さずに `AsyncImage` を使える (二重の Coil による版の不一致を作らない)。

**iOS のディスクキャッシュは明示的な呼び出しで有効にする。** 利用者が起動時に `KsImagePipeline.enableSharedDiskCache()` を呼んだときだけ、共有パイプラインの `dataCache` が未設定なら現在の `configuration` を引き継いで `dataCache` だけを足した構成で `ImagePipeline.shared` を差し替える。既に設定されていれば何もしない (アプリの構成を上書きしない)。ライブラリの初回利用時に自動で差し替えることはしない。Android は Coil の既定でディスクキャッシュが有効なため対応する API を設けない。

**ローダーは iOS: Nuke (13 系、`Nuke` + `NukeUI`)、Android: Coil 3 (`coil-compose` 系)。** Android は Compose の事実上の標準で対抗 (Glide の Compose 統合) が beta のため一択。iOS は Nuke の `ImagePrefetcher` が URL 単位で開始・停止でき、本体の内部配線 (アイテム単位の prefetch / cancel) にそのまま繋がること、13 系でパイプライン全体が Swift Concurrency に移行済みで Swift 6 環境と相性がよいこと、重複統合と優先度指定を持つことが決め手。

## Alternatives Considered

| 案 | 却下理由 |
|---|---|
| 本体は無依存とし、統合部品を同一パッケージの別 product / 別モジュールで同梱する (Nuke・Coil 自身が採る分割の型) | 画像を使わない利用者を軽く保てるが、画像を使う利用者は 2 つ import する手間が増え、product 分割・保守のコストが乗る。主目的 (自社量産) ではその軽さより導入の簡単さを優先する |
| ローダー抽象 (`ImageProvider`) + アダプタ提供 | 利用者がローダーを選べるが、抽象の設計と維持が最も重く、他の画像部品とのキャッシュ連携口も別途設計が要る |
| iOS のローダーを Kingfisher にする | プリフェッチのキャンセルがプリフェッチャーのインスタンス単位 (`stop()`) しかなく、フリング中のアイテム単位キャンセルを表現できない。Swift 6 strict concurrency は README で対応を表明しているが Package.swift の宣言 (tools 5.1・言語モード指定なし) と乖離があり未検証。SwiftUI ビューが本体統合で product が 1 つで済む利点はあるが決め手にならない |
| iOS のディスクキャッシュをライブラリの初回利用時に自動で有効化する (`dataCache` が未設定なら `configuration` と `delegate` を引き継いで差し替える) | Nuke 13 は共有パイプラインの `delegate` を外から読めず引き継げない。`configuration` だけを引き継ぐ自動差し替えは、要求の直前に認証ヘッダを付けるなど `delegate` で要求を加工しているアプリで画像が読めなくなる壊れ方をし、利用者が原因に気づきにくい |
| iOS はライブラリ専用のパイプラインを持つ | ローダー付属のビュー (`LazyImage`) を直接使う利用者とキャッシュが分断され、本決定が解こうとした二重ダウンロードが再発する |
| iOS は利用者にパイプライン構成を要求する (ドキュメントで案内するだけ) | 「本体を入れるだけで効く」が崩れ、構成忘れが「プリフェッチが効かない」という発見しにくい不具合になる。明示 API は呼び忘れが同じ形で起きうるが、呼ぶべき 1 つの入口があることで案内が単純になる |
| iOS は `ImagePipeline.shared` を常に差し替える | アプリが自分で構成したパイプライン (認証ヘッダ・独自キャッシュ) を上書きする |

## Consequences

- 正: 利用者は本体を入れるだけで `KsImage` とプリフェッチが効く。iOS で元データをディスクに残すには起動時の 1 呼び出しが加わるだけで、それ以外の設定はない
- 正: ADR-0008 の負の帰結「`KsImage` を使わない画像部品とはキャッシュが共有されない」が、同じローダーの共有インスタンスを使う限り解消される
- 正: 実装・保守コストが最小 (抽象も product 分割もない)
- 負: 画像を使わない利用者にもローダーが依存として付いてくる
- 負: ローダーの差し替えは破壊的変更になる (利用者コードがローダー付属のビューや設定に触れている場合)
- 負: iOS で `enableSharedDiskCache()` を呼ぶと共有パイプラインの `delegate` は既定に戻る。`delegate` を使うアプリは呼ばずに、`dataCache` を持つパイプラインを自分で組んで `ImagePipeline.shared` に置く必要がある
- 負: iOS で呼び忘れると、プリフェッチの到達点をディスクまでにしても元データはディスクに残らず、アプリの再起動で再ダウンロードになる

## Revisit When

- Nuke / Coil が非推奨になった、または最低対応 OS (iOS 16 / minSdk 29) を切り上げて追随できなくなったとき (Nuke 次期 14 系は iOS 16 / Swift 6.2 要求の予定)
- OSS 公開が主目的に変わり、画像を使わない利用者の依存の重さが問題になったとき
- Nuke が共有パイプラインの `delegate` を公開で読めるようにしたとき (ディスクキャッシュの自動有効化を再検討できる)

出典: kasane/roadmaps/v1-foundation/phases/phase-8-image-loading/history.md (2026-09-05: ローダー依存の持ち方 / ローダーの選定) / kasane/changes/archive/2026-09-08-image-loading/design.md (Decision 1・2) / kasane/changes/archive/2026-09-08-image-loading/deviation.md (Requirement「共有キャッシュ」の項、2026-09-07) / core/ADR-0008 / cross/ADR-0001
