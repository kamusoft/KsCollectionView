---
type: concept
title: コレクションの項目モデルと差分更新
description: KsCollectionView が受け取るプレーンな配列・安定 ID・テンプレートキーの契約と、配列を差し替えたときに何が再描画されるか
tags: [core-model, diffable, template]
timestamp: 2026-09-03
---

# コレクションの項目モデルと差分更新

この文書を読むと、`KsCollectionView` に渡すデータが何を満たす必要があり、配列を差し替えたときにライブラリが何を再描画し、何を利用者の責務として残しているかが分かる。レイアウトの語彙は [collection-layout](../styling/collection-layout.md)、タップとスクロール制御は [collection-interaction](collection-interaction.md) を参照。iOS 実装が先行しており (2026-09-03 時点)、Android は同じ契約に追随する (cross/ADR-0004)。

## 目的

利用者のモデル型をそのまま並べて表示させる。専用のコレクション型・ラッパー型・ライブラリ独自 protocol への準拠は要求しない (core/ADR-0003)。KMP 共有モデルのように利用者が改造できない型でも、`id:` キーパスの指定だけで表示できることが狙い。

## 責務境界

| 責務 | 持つ側 | 具体 |
|---|---|---|
| 配列の内容と順序 | 利用者 | 並べ替え・フィルタはデータ層で行い、新しい配列を渡す。ソート専用 API は無い |
| 安定 ID の宣言 | 利用者 | `Identifiable` 準拠、または `KsCollectionView(items, id: \.itemId)` |
| テンプレートの選択 | 利用者 | 単一クロージャ、または `template: \.kind` + `Template(Kind.message) { (item: Item) in … }` の登録 |
| 挿入・削除・移動の差分計算とアニメーション | ライブラリ | 新配列全体を渡すだけで差分が計算される。iOS の実現は `UICollectionViewDiffableDataSource` への snapshot 適用 (ios/ADR-0004)、Android は Compose Lazy 系の `key` に委ねる |
| 内容変化したセルの再構成 | ライブラリ | 同じ ID で内容が違う要素を検出して該当セルだけ再構成する |
| セル再利用と可視範囲外のセルの生存 | ライブラリ | 生成されるセルは可視範囲 + 再利用プール分に留まる (契約: 同時に生存するセルは可視セル数の 4 倍未満) |
| 画面外に出たセルの UI 状態 | 利用者 | 再利用で SwiftUI の内部 state は失われる (ios/ADR-0002)。残したい状態はモデルに持たせる |

## 保証すること

- **安定 ID が identity である**。同じ ID の要素は内容が変わってもセルインスタンスを維持したまま再構成される。ID を identity に使わず要素全体を identity にすると、内容変更と削除+挿入の区別がつかず、変わっていない要素まで作り直される (ios-engine-foundation design Decision 2)。
- **テンプレートキーが変わった要素はセルを置き換える**。同じ ID でも `template:` のキー値が `.message` から `.ad` に変わったら、再構成ではなく置換になる。キーは再利用種別に写像され、同一キーの要素間でのみセルが再利用されるため、キーをまたいで再利用プールが混ざらない。
- **配列が同値でも親 View の更新が届けば可視セルを再構成する** (ios/ADR-0006)。親の状態 (選択中 ID など) をテンプレートの中で読む書き方が成立する。差分計算と snapshot 適用は同値配列では省略される。
- **未登録キーの要素は release では空セル + 警告ログになる** (debug では assertion)。要素を黙って非表示にはしない。件数は配列と一致する。
- **重複 ID は不正入力**。debug では assertion、release では後勝ちで表示を継続し警告ログを出す (ios-engine-foundation deviation.md)。
- 10,000 件規模でもメモリが件数に比例して増えない。計測手順と基準は [handbook/ios/performance-verification.md](../../../handbook/ios/performance-verification.md)。

## してはいけないこと

- `id:` / `template:` のキーパスと `Template` の登録集合を表示中に差し替えない (ios/ADR-0006)。同値配列の更新ではこれらの変更は反映されない。宣言箇所ごとに静的に決める。
- テンプレートの中でしか読まれない親の `@State` に依存して更新を期待しない。そのクロージャは SwiftUI の body 評価の外で実行されるため依存グラフに載らず、その状態だけが変わっても親 View は再評価されない (2026-09-03 観測)。回避策は同じ状態を body 側でも読むこと。根本的な解き方は変更 template-parent-state-observation (`kasane/changes/` 配下の探索メモ) で検討中。
- セル内の `@State` に「画面外に出ても残したい状態」を置かない。再利用で初期値に戻る (ios/ADR-0002)。

## 用語

- **安定 ID**: 要素を同一とみなす鍵。`Hashable` で、同一配列内で一意。
- **テンプレートキー**: `template:` キーパスが返す `Hashable` な値。どの `Template` で描くかを選び、再利用種別にもなる。
- **再構成 (reconfigure)**: セルインスタンスを維持したまま内容を差し替えること。**置換 (reload)** はセルごと入れ替えること。

## 関連

- [collection-layout](../styling/collection-layout.md) — `layout` 値・スペーシング・区切り線・ヘッダー/フッター
- [collection-interaction](collection-interaction.md) — タップ・長押し・スクロール制御
- [iOS コレクションエンジン](../../ios/architecture/collection-engine.md) — この契約を UICollectionView でどう実現しているか
- core/ADR-0003 (プレーンな配列 + 安定 ID)、core/ADR-0004 (値キーテンプレート)、core/ADR-0011 (不正入力の release 挙動)、ios/ADR-0002、ios/ADR-0004、ios/ADR-0006
