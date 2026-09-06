---
id: 0012
title: 画像ローダー — 本体が iOS は Nuke・Android は Coil 3 に直接依存し KsImage とプリフェッチ接続を内蔵する
status: proposed
date: 2026-09-05
---

## Context

core/ADR-0008 は `prefetchResources` クロージャと専用画像コンポーネント `KsImage` の対を DSL 外形として確定し、ローダー選定・キャッシュ設計・依存の持ち方は phase-8 に委ねた。iOS 本体には `UICollectionViewDataSourcePrefetching` からアイテム単位の prefetch / cancel を内部プロトコルへ流す配線が既にあるが、中身は空で埋める公開 API がない。Android 側に対応物はない。

隣接リポジトリに画像ローダーを実依存として採用した前例はなく、旧 AiForms.CollectionView は本体無依存のまま README で FFImageLoading を推奨していた (ADR-0008 はこれを `KsImage` として内蔵化する決定)。

前提: 主目的が自社 KMP アプリの量産で、利用者にローダー統合の手順を課す価値が薄い (cross/ADR-0001)。両プラットフォームに MIT / Apache-2.0 で活発に保守される標準的なローダー (iOS: Nuke 等、Android: Coil) が存在する。

## Decision

- 画像ローダーは本体 (iOS の `KsCollectionView` product / Android の `kscollectionview` モジュール) が**直接依存**する。`KsImage` とプリフェッチ接続は本体に内蔵し、利用者は本体を導入するだけで両方が効く
- ローダーの**共有インスタンスをそのまま共有キャッシュ**とする。ライブラリ独自のキャッシュ層や抽象を挟まない。これにより `KsImage` を使わずローダー付属のビューを直接使う利用者にもプリフェッチが効く
- iOS の共有パイプライン (`ImagePipeline.shared`) は既定でディスクキャッシュを持たないため、ライブラリの初回利用時にディスクキャッシュが未設定ならディスクキャッシュを有効にした構成で差し替える。アプリが先に構成していれば変更しない (利用者に構成手順を課さず、かつアプリの構成を上書きしない)
- ローダーは **iOS: Nuke (13 系、`Nuke` + `NukeUI`)、Android: Coil 3 (`coil-compose` 系)** とする。Android は Compose の事実上の標準で対抗 (Glide の Compose 統合) が beta のため一択。iOS は Nuke の `ImagePrefetcher` が URL 単位で開始・停止でき、本体の内部配線 (アイテム単位の prefetch / cancel) にそのまま繋がること、13 系でパイプライン全体が Swift Concurrency に移行済みで Swift 6 環境と相性がよいこと、重複統合と優先度指定を持つことが決め手

## Alternatives Considered

- **本体は無依存とし、統合部品を同一パッケージの別 product / 別モジュールで同梱する** (Nuke・Coil 自身が採る分割の型): 却下。画像を使わない利用者を軽く保てるが、画像を使う利用者は 2 つ import する手間が増え、product 分割・保守のコストが乗る。主目的 (自社量産) ではその軽さより導入の簡単さを優先する
- **ローダー抽象 (`ImageProvider`) + アダプタ提供**: 却下。利用者がローダーを選べるが、抽象の設計と維持が最も重く、他の画像部品とのキャッシュ連携口も別途設計が要る
- **iOS のローダーを Kingfisher にする**: 却下。プリフェッチのキャンセルがプリフェッチャーのインスタンス単位 (`stop()`) しかなく、フリング中のアイテム単位キャンセルを表現できない。Swift 6 strict concurrency は README で対応を表明しているが Package.swift の宣言 (tools 5.1・言語モード指定なし) と乖離があり未検証。SwiftUI ビューが本体統合で product が 1 つで済む利点はあるが決め手にならない

## Consequences

- 正: 利用者は本体を入れるだけで `KsImage` とプリフェッチが効く。追加設定なし
- 正: ADR-0008 の負の帰結「`KsImage` を使わない画像部品とはキャッシュが共有されない」が、同じローダーの共有インスタンスを使う限り解消される
- 正: 実装・保守コストが最小 (抽象も product 分割もない)
- 負: 画像を使わない利用者にもローダーが依存として付いてくる
- 負: ローダーの差し替えは破壊的変更になる (利用者コードがローダー付属のビューや設定に触れている場合)

## Revisit When

- Nuke / Coil が非推奨になった、または最低対応 OS (iOS 16 / minSdk 29) を切り上げて追随できなくなったとき (Nuke 次期 14 系は iOS 16 / Swift 6.2 要求の予定)
- OSS 公開が主目的に変わり、画像を使わない利用者の依存の重さが問題になったとき

出典: kasane/roadmaps/v1-foundation/phases/phase-8-image-loading/history.md (2026-09-05: ローダー依存の持ち方 / ローダーの選定) / kasane/changes/image-loading/design.md (Decision 1) / core/ADR-0008 / cross/ADR-0001
