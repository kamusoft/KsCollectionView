# Proposal: image-loading

## Why

画像グリッドは本ライブラリの最頻ユースケースで、プリフェッチは性能価値の中核 (core/ADR-0008)。「もうすぐ表示されるアイテム」を知っているのはライブラリだけで、その情報は外に出せない。iOS 本体には `UICollectionViewDataSourcePrefetching` からアイテム単位の prefetch / cancel を流す内部配線が既にあるが中身は空で、Android には対応物が無い。セル API の形を縛るため、機能フェーズ (セクション・ページング・D&D) の前に画像ロードを成立させる (phase-8 の実行順)。

phase-8 の議論 (agenda 決定事項 10 件) で、ローダーの依存の持ち方と選定 (core/ADR-0012 proposed)、プリフェッチの到達点、Android の先読み機構、`KsImage` の機能範囲とソース型、キャッシュ方針とクリアの口、検証方法が確定した。本提案はそれを実装可能な契約に落とす。

## What Changes

- **ローダー依存の追加**: iOS は Nuke 13 系 (`Nuke` + `NukeUI`) を SwiftPM 依存に、Android は Coil 3 (`coil-compose` + ネットワーク fetcher) を Gradle 依存に追加する。本体が直接依存し、ローダーの共有インスタンスをそのまま共有キャッシュとする (core/ADR-0012)
- **プリフェッチ宣言** `prefetchResources` (Swift modifier / Kotlin 名前付き引数。core/ADR-0008 の外形): アイテム → リモート URL 配列のクロージャ。任意引数 `destination` で到達点を選ぶ (既定 `.disk` = 元データをディスクまで、`.memory` = デコード済みをメモリまで)
- **iOS の接続**: 既存の内部配線 (`KsPrefetching` / `KsAnyPrefetcher`) を Nuke の `ImagePrefetcher` に繋ぎ、アイテム単位の開始 / 取り消しを URL 単位で流す。Nuke のディスクキャッシュを共有パイプラインで有効化する
- **Android の先読み窓**: 可視範囲の観測からライブラリが先読み窓を作り、窓に入ったアイテムの URL を Coil に `enqueue`、外れたら取り消す。iOS と同じ契約
- **`KsImage`** (両プラットフォーム同名の専用画像コンポーネント): 画像ソース型 `KsImageSource` (リモート / ファイル / リソース) を受け、`KsImage(url)` の便宜形も持つ。縮小の既定は自身のレイアウトサイズ、表示の当てはめ方 (`contentMode`: `KsImageContentMode` の `fit` / `fill`) と読み込み中・失敗時の表示スロットを持つ。画面外に出たら読み込みを取り消す
- **`KsImageCache`** (両プラットフォーム同名): `clear(.memory / .disk / .all)` とソース単位の `remove(source)`。消去後は表示中の該当 `KsImage` が再取得する。iOS のアセットは no-op。iOS のソース単位削除は世代付きの識別子で旧項目に当たらなくする (消したソースに限りローダー付属ビューとの共有が切れる)
- **Sample デモ画面「画像グリッド」**: 両プラットフォームに sample-parity 準拠で追加 (大量件数の画像グリッド。プリフェッチ ON/OFF と到達点の切替、`KsImageCache.clear` の操作)。デモ画像は公開のプレースホルダー画像サービス
- **検証**: 配線の自動テスト (検査用の受け口で、アイテム単位の開始 / 取り消し・共有 URL の参照数・到達点の伝播を確かめる) と、取得層をスタブした実ローダーによるキャッシュ契約の統合テスト、Sample での実機計測 (Android は handbook の全系統を既存 fixture で回帰計測、両プラットフォームで画像グリッド fixture の開始 / 取消件数・メモリ定常化) を evidence/ に残す

影響する能力: image-loading (新設: プリフェッチ・`KsImage`・`KsImageCache`) / samples (検証装置)

## Non-Goals

- 別ローダーとの連携口・ローダー抽象 (`ImageProvider`) — core/ADR-0012 で却下 (共有インスタンスで同ローダーの付属ビューには自動で効く)
- プリフェッチ宣言の優先度・サイズヒント — agenda 決定 (Coil に優先度が無く対称にできない。サイズヒントは鍵不一致の原因)
- `KsImage` の縮小サイズ手動指定・フェードイン等の演出・ローダー個別設定の露出 — agenda 決定 (必要なら利用者がローダー付属のビューを直接使う)
- ソース種別ごとのキャッシュ方針の設定 — agenda 決定 (表示時の保持はローダー既定に乗せ、調整点はプリフェッチの到達点のみ)
- Android の先読み窓幅の利用者設定 — v1 はライブラリ既定のみ (design.md Decision 4)。実機計測で必要と分かったら別 change
- CI での性能の継続計測 — agenda 決定 (実機計測 1 回のみ)
- 動画・アニメーション画像 (GIF / APNG) の再生 — 別能力。静止画のみ

## Impact

- 公開 API 追加 (両プラットフォーム): `prefetchResources` (+ `destination`)、`KsImage`、`KsImageSource`、`KsImageContentMode`、`KsImageCache`、`KsPrefetchDestination`。破壊的変更なし
- 依存の追加: 利用者アプリに iOS は Nuke / NukeUI、Android は Coil 3 + OkHttp が推移する (core/ADR-0012 の負の帰結、受容済み)。画像を使わない利用者にも付いてくる
- リスク: Coil 3.6 系は Compose 1.12 を推移させ利用者に compileSdk 37 を要求する (本体の compileSdk 36 方針と衝突。lessons: check-consumer-compile-sdk-before-adopting-latest-dependency)。design.md Decision 2 で 3.5.0 に固定する
- リスク: iOS の内部配線は `configuration.prefetcher` が `nil` 固定で、公開 API から埋める経路が無い。本 change で経路を通す
- リスク: Android は先読み窓の実装がスクロール中の再コンポジション経路に乗るため、android/performance-verification の相対基準 (素の `LazyVerticalGrid` に対する劣化 10% 以内) を再計測する

## 級: L

両プラットフォーム同時の新能力 + 外部依存の追加 + 公開 API 5 件の新設 + Sample UI。core/ADR-0012 の帰結を design.md の Decision に落とす必要がある

domain: cross   # core の契約 (プリフェッチ・KsImage) + iOS / Android 双方の実装。実装時のスキル解決は ios + android を結合
roadmap: v1-foundation/phase-8-image-loading
