---
type: concept
title: コレクションの項目モデルと差分更新
description: KsCollectionView が受け取るプレーンな配列・安定 ID・テンプレートキー・グループの値の契約と、配列を差し替えたときに何が再描画・アニメーションされるか、親の状態をテンプレートで読む条件 (iOS / Android 共通)
tags: [core-model, diffable, template, groups]
timestamp: 2026-09-29
---

# コレクションの項目モデルと差分更新

この文書を読むと、`KsCollectionView` に渡すデータが何を満たす必要があり、項目をどうグループに分けるか、配列を差し替えたときにライブラリが何を再描画・アニメーションし、何を利用者の責務として残しているかが分かる。レイアウトの語彙は [collection-layout](../styling/collection-layout.md)、タップとスクロール制御は [collection-interaction](collection-interaction.md) を参照。契約は両プラットフォーム共通で、その実現方法は [iOS コレクションエンジン](../../ios/architecture/collection-engine.md) と [Android Compose ラッパー](../../android/architecture/compose-wrapper.md) にある。

## 目的

利用者のモデル型をそのまま並べて表示させる。専用のコレクション型・ラッパー型・ライブラリ独自 protocol / interface への準拠は要求しない (core/ADR-0003)。KMP (Kotlin Multiplatform) で共有しているモデルのように利用者が改造できない型でも、ID の取り出し方を指定するだけで表示できることが狙い。

## 公開 API

```swift
KsCollectionView(items) { item in Row(item) }                       // Identifiable な要素、単一テンプレート
KsCollectionView(sharedItems, id: \.itemId) { item in Row(item) }   // 改造できない型は id: で ID を指定
KsCollectionView(items, template: \.kind) {                          // 値キーでテンプレートを切り替える
    KsTemplate(.message) { item in MessageRow(item) }
    KsTemplate(.ad) { item in AdCard(item) }
}
KsCollectionView(items) { item in Row(item, isExpanded: expandedIDs.contains(item.id)) }
    .observedValue(expandedIDs)                                      // テンプレートの中で読む親の状態を観測する値として渡す (iOS のみ)
KsCollectionView(products) { product in ProductRow(product) }       // category が同じ項目が続く範囲を 1 つのグループにする
    .groups(by: \.category) { category, productsInGroup in
        Text("\(category) (\(productsInGroup.count))")                // 見出し。固定を外すなら groups(by:pinnedHeaders: false)
    }
```

```kotlin
KsCollectionView(items = items, key = { it.id }) {                  // 単一テンプレート
    template { item -> Row(item) }
}
KsCollectionView(items = items, key = { it.id }, template = { it.kind }) {
    template(Kind.Message) { item -> MessageRow(item) }
    template(Kind.Ad) { item -> AdCard(item) }
}
KsCollectionView(
    items = products, key = { it.id },
    groups = KsGroups(by = { it.category }) { category, productsInGroup ->   // 見出しを省くと見出しなしのグループ
        Text("$category (${productsInGroup.size})")
    },
) { template { product -> ProductRow(product) } }
```

| 語彙 | Swift | Kotlin |
|---|---|---|
| 安定 ID | `Identifiable` 準拠、または `id:` キーパス | `key: (Item) -> Any` ラムダ (必須) |
| テンプレートキー | `template:` キーパス | `template: (Item) -> Any` ラムダ |
| キーごとのテンプレート登録 | `KsTemplate(キー) { item in … }` を宣言ブロックに並べる | `template(キー) { item -> … }` をスコープ内で呼ぶ |
| 単一テンプレート | 末尾クロージャ | `template { item -> … }` |
| テンプレートの中で読む親の状態 | `.observedValue(_:)` modifier (`Hashable` な値を 1 つ) | 無し (Compose が自動で購読する) |
| グループの値と見出し | `.groups(by:pinnedHeaders:header:)` modifier (`Hashable` な値へのキーパス) | `groups = KsGroups(by, pinnedHeaders, header)` (ラムダ。値の型は型引数) |

語彙と構造は 1 対 1 に対応し、記法だけが各プラットフォームの流儀に従う (core/ADR-0002)。Kotlin の `template(key)` はスコープ関数で対応する公開型を持たないため、Swift の `KsTemplate` に当たる型名は Android には無い。観測する値だけは iOS にしか無い語彙で、Android には対応物を設けない (ios/ADR-0008)。`KsGroups` は Kotlin だけの公開型で Swift の modifier に当たる (グループの値と見出しを 1 つの値に入れ、見出しを省いてもグループの値の型を推論できるようにするため。core/ADR-0015)。見出し・固定・間隔の見え方は [collection-layout](../styling/collection-layout.md) にある。

## 責務境界

| 責務 | 持つ側 | 具体 |
|---|---|---|
| 配列の内容と順序 | 利用者 | 並べ替え・フィルタはデータ層で行い、新しい配列を渡す。ソート専用 API は無い |
| 安定 ID の宣言 | 利用者 | 上表の語彙で宣言する。Android の `key` の戻り値は状態保存 (Bundle) に載る型に限る (「してはいけないこと」) |
| テンプレートの選択 | 利用者 | 単一テンプレート、または種別キーとキーごとの登録 |
| グループの値の宣言と、同じグループの項目を続けて並べること | 利用者 | 配列は平らなまま渡す。項目型にグループ用の準拠や見出し用の要素の混入は要らない。グループの順・グループ内の順もデータ層で決める |
| 挿入・削除・移動の差分計算とアニメーション | ライブラリ | 新配列全体を渡すだけでよい。iOS は差分データソース (`UICollectionViewDiffableDataSource`) へのスナップショット適用 (ios/ADR-0004)、Android は Compose Lazy 系の `key` と `animateItem` (android/ADR-0006) |
| グループの構成・見出しの出入りと内容の更新 | ライブラリ | 新配列からグループを組み直し、見出しの移動・出現・消滅と内容の更新を差分として反映する |
| 内容変化したセルの再構成 | ライブラリ | 同じ ID で内容が違う要素を検出して該当セルだけ再構成する |
| セル再利用と可視範囲外のセルの生存 | ライブラリ | 生成されるセルは可視範囲 + 再利用 (先読み) 分に留まる (契約: スクロール中の任意時点で、その時点の可視セル数の 4 倍未満) |
| 画面外に出たセルの UI 状態 | 利用者 | 画面外へ出た項目の内部 state (iOS `@State`、Android `remember`) は失われる。残したい状態はモデルに持たせる |

## 保証すること

- **安定 ID が identity である**。同じ ID の要素は内容が変わってもセルインスタンスを維持したまま再構成される (理由は下記)。
- **テンプレートキーが変わった要素はセルを置き換える**。同じ ID でもキー値が `.message` から `.ad` に変われば、再構成ではなく置換になる。
- **同一キーの要素間でのみセルが再利用される**。キーは再利用種別 (iOS `CellRegistration`、Android `contentType`) に写像され、キーをまたいで再利用プールが混ざらない。
- **配列が同値でも、親の状態の変化を可視セルへ反映する** (ios/ADR-0006・ios/ADR-0008)。親の状態 (選択中 ID・展開中 ID の集合など) をテンプレートの中で読む書き方が成立する。iOS での条件は下記「親の状態をテンプレートで読む条件」。
- **不正入力は release で落とさず・消さず・黙らず** (core/ADR-0011)。種類ごとの挙動は下表。
- 10,000 件規模でもメモリが件数に比例して増えない。計測手順と基準は [iOS](../../../handbook/ios/performance-verification.md) / [Android](../../../handbook/android/performance-verification.md) の性能検証規約。

### 不正入力の扱い (core/ADR-0011)

「debug」は利用者が動かしているアプリのビルド種別を指す (ライブラリの配布形態ではない)。

| 不正入力 | debug | release |
|---|---|---|
| 未登録テンプレートキーの要素 | assertion | 最小高 (1pt / 1dp) の空セルを該当位置に置き、警告ログ。件数は配列と一致する |
| 配列内の重複 ID | assertion | 後勝ち (後の要素を採用) で表示を継続し、警告ログ |
| 同じキーへの二重登録 | assertion | 後勝ちで登録を継続し、警告ログ |
| `key` が Bundle に載らない型を返す (Android のみ) | assertion | ライブラリは警告ログを出して継続するが、`key` を包まないため Compose 自身が初回表示時に例外を投げうる。利用契約で防ぐ |
| 同じグループの値が配列の離れた位置に再び現れる | assertion | 項目を並べ替えず消さず、配列の順のまま別々のグループとして表示し、警告ログ |
| グループの値が Bundle に載らない型 (Android のみ) | assertion | `key` と同じ扱い。見出しの識別 (状態保存に載せる lazy のキー) に使うため、使える型も `key` と同じ |

グループの値は「続いた範囲」を 1 つのグループにする。Kotlin の `groupBy` や Swift の `Dictionary(grouping:)` のように離れた同じ値を集めはしないため、離れた同じ値は利用者の並べ忘れとみなして不正入力にする (core/ADR-0015)。

### 親の状態をテンプレートで読む条件

iOS では、テンプレートの中で読む親の状態を `observedValue(_:)` に観測する値として渡す (ios/ADR-0008)。テンプレートのクロージャは body 評価の外で実行されるため、その中でしか読まれない状態は SwiftUI の依存グラフに載らず、渡さないと状態が変わっても更新がライブラリへ届かない。複数の状態は `Hashable` な 1 つの値 (構造体など) にまとめて渡す。Android は Compose が合成の中でテンプレートを実行して親の State を自動で購読するため、対応する指定は無い。

iOS で何が再構成されるかは、観測する値の有無と更新の種類で決まる。

| iOS の書き方 | 配列が同値の更新 | 配列が変わる更新 |
|---|---|---|
| 観測する値を渡している | 値が変わったときだけ可視セルのテンプレートを呼び直す。値以外の変化 (クロージャの差し替え・クロージャの中で読む別の状態) は届かない | 差分で拾われた項目に加え、内容が同値のまま残る可視セルもテンプレートを呼び直す (取り残しなし) |
| 渡していない | 親 View の更新が届くたびに可視セルのテンプレートを呼び直す (ios/ADR-0006)。状態が body でも読まれていることが、更新が届く条件 | 差分で拾われた項目だけ。同じ更新で親の状態も変わっていると、内容不変の既存セルは古い状態のまま残る |

参考 (推奨ではない): 状態を項目の配列に持たせる書き方は両プラットフォームで対称に成立する。参照型モデルをセルの中で観測する書き方は中身の変化がアニメーションする利点がある。どちらも上の契約と排他ではない。

### グループをまたぐ差分更新 (core/ADR-0015、android/ADR-0006)

グループの identity はグループの値である。配列を差し替えると、ライブラリは項目の安定 ID とグループの値を identity として差分を反映し、両プラットフォームとも項目と見出しの移動・挿入・削除を新しい位置へ飛ばさずにアニメーションで見せる。

| 変化 | 見え方 |
|---|---|
| 項目のグループの値が変わった (データ層で並べ直した配列を渡す) | 新しいグループへの移動。同じ ID の項目のままで、移動の前後とも可視範囲にあればセルは作り直されない |
| グループの並び順が変わった | 見出しがそのグループの項目と一緒に移動する |
| グループの項目が 0 件になった / 新しいグループの値が現れた | 見出しごと消える / 見出しごと現れる。項目が 0 件のグループは存在しない |
| グループの項目の数や内容だけが変わった | 見出しは作り直されずに内容が更新される |
| グループの値の取り出し方 (Swift のキーパス / Kotlin のラムダ) を表示中に切り替えた | 配列が同じでも、新しいグループの値の並びが前回と違えば組み直して差分として反映する (カテゴリ別 ⇄ ブランド別のような表示の切り替え) |

グリッドで列をまたぐ移動は、両プラットフォームとも OS 標準の見え方 (元の位置から移動先へまっすぐ動く) のままにしている。並べ替えの DSL は持たない (core/ADR-0003)。

### 端を表示中の端への挿入 (core/ADR-0018)

コンテンツの先頭 (ルートのヘッダーがあればその上端) を表示中に配列の先頭へ項目を入れると、表示範囲は先頭に留まり、挿入した項目が表示範囲の中にアニメーションで現れる。末尾 (ルートのフッターがあればその下端) を表示中の末尾への挿入も同じく末尾に留まる。list / グリッド、グループの有無を問わない。

端を見ている利用者にとって、端への挿入が表示範囲の外にひっそり足されるのは不具合に見えるためである。端を表示していない状態での挿入の見え方は契約に含めず、各プラットフォームの既定の位置の保ち方 (iOS はコンテンツの位置、Android は見えている先頭の項目) のままになる。

ページングを付けた一覧だけは、末尾側の規則を差し替えの直前のページングの状態で置き換える。末尾に留めるのは直前の状態が終端のときだけで、直前が取り直し中なら位置によらず先頭を表示する (core/ADR-0021。規則の全体は [collection-paging](collection-paging.md))。

### なぜ ID を identity にするか

要素全体を identity にすると、内容変更と「削除 + 挿入」の区別がつかず、変わっていない要素まで作り直される。ID を identity にすることで、同じ ID の要素は内容が変わっても同じセルのまま再構成され、差分アニメーションが挿入・削除・移動だけに限られる (出典: kasane/changes/archive/2026-09-04-ios-engine-foundation/design.md Decision 2)。

## してはいけないこと

- ID とテンプレートキーの取り出し方 (Swift `id:` / `template:`、Kotlin `key` / `template`) と登録集合を表示中に差し替えない (ios/ADR-0006)。宣言箇所ごとに静的に決める。Android で偶然反映されても契約にはしない。グループの値の取り出し方だけは切り替えてよい (上記)。
- 同じグループの値を持つ項目を配列の中で離して並べない。グループごとにまとめ直した配列を渡す (上記「不正入力の扱い」)。
- 見出しにしたい要素を項目として配列に混ぜない。見出しは `groups` の宣言で出す (混ぜると項目のモデルが汚れ、固定もできない)。
- Android の `key` に、`Parcelable` / `Serializable` を実装していない `data class` / `value class` など Bundle に載らない型を返さない。使える型は文字列・数値・enum・`Serializable`・`Parcelable`。違反時の挙動は上表「不正入力の扱い」の最終行。
- iOS で、テンプレートの中で読む親の状態を `observedValue(_:)` に渡さずに更新を期待しない。そのクロージャは body 評価の外で実行され依存グラフに載らない (ios/ADR-0008)。渡すときは、テンプレートの中で読む状態をすべて 1 つの値にまとめる (渡した値以外の変化は同値配列の更新で届かない)。Android は Compose の自動観測で問題にならない。
- セル内の `@State` / `remember` に「画面外に出ても残したい状態」を置かない。再利用・破棄で初期値に戻る (ios/ADR-0002。Android は可視範囲と先読み分を超えて送ると Composition が破棄される)。

## 用語

- **安定 ID**: 要素を同一とみなす鍵。`Hashable` (Kotlin では `equals` / `hashCode`) で、同一配列内で一意。
- **テンプレートキー**: `template` が返す `Hashable` な値。どのテンプレートで描くかを選び、再利用種別にもなる。
- **再構成 (reconfigure)**: セルインスタンスを維持したまま内容を差し替えること。Android では項目の Composition を保ったまま新しい値で再コンポジションされることを指す。**置換 (reload)** はセルごと入れ替えること。
- **Sample**: リポジトリ同梱 (`samples/`) の動作確認・プラットフォーム間パリティ検証用アプリ。両プラットフォームに同じデモ画面を持つ。
- **再利用種別**: 同じ種別の要素間でだけセルを使い回す単位。iOS は `CellRegistration`、Android は `contentType`。
- **グループ / グループの値**: 配列の順に同じグループの値が続く範囲 / 項目がどのグループかを表す値 (キーパス・ラムダで項目から取り出す)。グループはグループの値で識別する。
- **観測する値**: iOS で `observedValue(_:)` に渡す `Hashable` な値。テンプレートの中で読む親の状態を表し、その変化が可視セルのテンプレート呼び直しの契機になる。

## 関連

- [collection-layout](../styling/collection-layout.md) — `layout` 値・スペーシング・区切り線・ヘッダー/フッター・グループの見出しと固定
- [collection-interaction](collection-interaction.md) — タップ・長押し・スクロール制御
- [collection-paging](collection-paging.md) — ページングを付けた一覧での差し替え時の表示範囲の置き方 (端への挿入の例外)
- [iOS コレクションエンジン](../../ios/architecture/collection-engine.md) — この契約を UICollectionView でどう実現しているか
- [Android Compose ラッパー](../../android/architecture/compose-wrapper.md) — この契約を Compose Lazy 系でどう実現しているか
- core/ADR-0003 (プレーンな配列 + 安定 ID)、core/ADR-0004 (値キーテンプレート)、core/ADR-0011 (不正入力の release 挙動)、core/ADR-0015 (グループの値によるグループの宣言)、core/ADR-0018 (端を表示中の端への挿入。ページングを付けた一覧は core/ADR-0021 が一部改訂)
- ios/ADR-0002、ios/ADR-0004、ios/ADR-0006、ios/ADR-0008 (観測する値)、android/ADR-0001、android/ADR-0006 (差分の移動・挿入・削除のアニメーション)
