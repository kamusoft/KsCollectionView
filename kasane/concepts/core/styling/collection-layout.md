---
type: concept
title: コレクションのレイアウト語彙
description: layout 値 (list / grid・列数・向き別列数) とスペーシング・contentPadding・区切り線・ルートヘッダー/フッター・グループの見出しと固定と間隔・セルの高さの自動決定と content 配置・行の高さ変化・スクロールインジケータの契約 (iOS / Android 共通)
tags: [styling, layout, grid, groups]
timestamp: 2026-09-26
---

# コレクションのレイアウト語彙

この文書を読むと、リストとグリッドの表示形態を何で宣言し、切り替えたときに何が保たれ、行間・余白・区切り線・ヘッダー/フッター・グループの見出し・スクロールインジケータが既定でどう見え、セルの中身がどこに置かれるかが分かる。項目モデルとグループの宣言 (どの項目がどのグループか) は [collection-items](../core-model/collection-items.md) を先に読むと分かりやすい。語彙は両プラットフォームで 1 対 1 に対応する (core/ADR-0006)。

## 目的

リストとグリッドを別コンポーネントにせず、単一の `KsCollectionView` に `layout` 値 1 つで表示形態を宣言させる (core/ADR-0006)。データを保ったまま実行中に切り替えられることが狙い。

## 公開 API

```swift
KsCollectionView(items, layout: .list(rowSpacing: 8)) { … }
KsCollectionView(items, layout: .grid(columns: .fixed(portrait: 2, landscape: 4), rowSpacing: 8, columnSpacing: 8,
                                      groupSpacing: 24, headerItemSpacing: 8),
                 contentPadding: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)) { … }
    .groups(by: \.category) { category, itemsInGroup in Text(category) }
    .header { Text("見出し") }
    .footer { Text("末尾") }
    .listSeparators(false)
    .listSeparatorColor(.blue)
```

```kotlin
KsCollectionView(items = items, key = { it.id }, layout = KsLayout.List(rowSpacing = 8.dp)) { … }
KsCollectionView(
    items = items, key = { it.id },
    layout = KsLayout.Grid(
        KsColumns.Fixed(portrait = 2, landscape = 4), rowSpacing = 8.dp, columnSpacing = 8.dp,
        groupSpacing = 24.dp, headerItemSpacing = 8.dp,
    ),
    contentPadding = PaddingValues(horizontal = 16.dp),
    groups = KsGroups(by = { it.category }) { category, itemsInGroup -> Text(category) },
    header = { Text("見出し") }, footer = { Text("末尾") },
    listSeparators = false, listSeparatorColor = Color.Blue,
) { … }
```

| 意味 | Swift | Kotlin |
|---|---|---|
| 1 列。行間は既定 0 | `.list` / `.list(rowSpacing:)` | `KsLayout.List` / `KsLayout.List(rowSpacing)` |
| 多列。行間・列間は既定 0 | `.grid(columns:rowSpacing:columnSpacing:)` | `KsLayout.Grid(columns, rowSpacing, columnSpacing)` |
| 固定列数 | `.fixed(n)` | `KsColumns.Fixed(n)` |
| コンテナの縦横比で列数を切り替える | `.fixed(portrait:landscape:)` | `KsColumns.Fixed(portrait, landscape)` |
| 最小アイテム幅を下回らない最大の列数 | `.adaptive(minItemWidth:)` | `KsColumns.Adaptive(minItemWidth)` |
| グループとグループの間の間隔 / 見出しとそのグループの先頭行の間の間隔 (いずれも既定 0) | `.list` / `.grid` の `groupSpacing:` / `headerItemSpacing:` | `KsLayout.List` / `Grid` の `groupSpacing` / `headerItemSpacing` |
| グループの見出しと固定の有無 (固定は既定 true) | `.groups(by:pinnedHeaders:header:)` | `groups = KsGroups(by, pinnedHeaders, header)` |
| 本体とコンテンツの間の内側余白 (4 辺個別、既定 0) | `contentPadding:` | `contentPadding =` |
| 区切り線の表示 (既定 true) / 色 (既定は固定値) | `.listSeparators(_:)` / `.listSeparatorColor(_:)` | `listSeparators =` / `listSeparatorColor =` |

向き別列数は端末の物理向きではなく、コンポーネント自身の高さ > 幅なら portrait 側を使う (分割画面・タブレット・折りたたみで両プラットフォームの列数が揃う)。adaptive の余剰幅はアイテム幅へ均等配分し、列間は指定値のまま。列の利用可能幅は「コンポーネント幅 − contentPadding 左右 − columnSpacing × (列数 − 1)」。

## 保証すること

### 表示形態と切り替え

- **切り替えでデータと位置が保たれる**。表示中に `layout` を差し替えても画面全体の再構築や表示の乱れは起こさない。iOS は切り替え直前に表示範囲の先頭にあった要素をアンカーとして表示範囲内に残す (ios/ADR-0003)。Android は同じ Composable・同じスクロール状態のまま列数だけを変える (android/ADR-0001)。
- **ルートヘッダー/フッターはコンテンツと一緒にスクロールする**。固定されない。宣言しなければ何も表示されない。配列が空でも表示される。グリッドでは全幅を占める。余白の位置は下記「行間と余白の置き場所」。
- 0 以下の列数・0 以下の `minItemWidth`・負のスペーシング (行間・列間・グループ間・見出しの下) は不正入力。debug では assertion、release では警告ログを出して表示を継続する (負の間隔は 0、Android の列数は 1 以上へ丸める。core/ADR-0011 の方針)。

### 行間と余白の置き場所

行間 (`rowSpacing`) は行と行の間にだけ入り、ルートのヘッダー / フッターとグループの見出しの前後には入らない。見出しの前後の空きは、それぞれ専用の間隔で決まる。

| 場所 | 入るもの |
|---|---|
| `contentPadding` の上端 / 下端 | ルートのヘッダーの上 / フッターの下 (ヘッダー / フッターもコンテンツの一部。core/ADR-0006)。無ければ最初の行の上 / 最後の行の下 |
| ルートのヘッダーと最初の見出し (または先頭行) の間、最終行とフッターの間 | 何も入らない |
| 前のグループの最終行と次のグループの見出しの間 | `groupSpacing`。コンテンツ全体の先頭と末尾には入らない |
| グループの見出しとそのグループの先頭行の間 | `headerItemSpacing` |
| 同じグループの行と行の間 | `rowSpacing` |

`groupSpacing` と `headerItemSpacing` は固定中の見出しと一緒に上端へ貼り付かず、行と一緒に流れる。見出しの View に余白を持たせると、その空白ごと固定されて貼り付く。行間を見出しの前後に入れない規則は、ルートのヘッダーにもグループの見出しにも同じに効く (core/ADR-0015)。

### グループの見出し (core/ADR-0015)

グループ (配列の順に同じグループの値が続く範囲。宣言は [collection-items](../core-model/collection-items.md)) の見出しは、任意の View / Composable で宣言する。

- 見出しのクロージャには、そのグループのグループの値とグループ内の項目が渡る。配列を差し替えると、表示中の見出しは作り直されずに新しい値と項目で内容が更新される (件数だけが変わった場合も)。
- 見出しの高さは中身から自動で決まる。高さの指定は持たない。グリッドでは全幅を占め、グループの先頭の項目は次の行の行頭に置かれる。
- 見出しはグループの先頭行の前に 1 つだけ置かれる。グループのフッターは持たない。見出しを宣言しないグループは区切りに見出しを出さず、間隔と区切り線の単位としてだけ働く。
- 列数に満たない行は各グループの最終行にだけ現れる。見出しを宣言しないグリッドでも、次のグループは行頭から始まる。
- 見出しの中で親の状態を読むときの再描画の条件は項目のテンプレートと同じ (iOS は観測する値、Android は Compose の自動の観測)。

### 見出しの固定

見出しは既定で、そのグループが表示範囲にある間、表示範囲の上端に固定される。次のグループの見出しが上端に達すると固定中の見出しは押し上げられて入れ替わり、押し上げの間も薄れない。`pinnedHeaders` を false にすると固定を外し、見出しはコンテンツと一緒に流れる。ルートのヘッダー / フッターは固定しない。

固定に伴って位置の扱いが 2 つ変わる。表示領域の縦横が変わって列数が変わったときは、表示範囲の先頭にあった項目を固定中の見出しのすぐ下に保つ (見出しの裏に隠さない)。`KsScrollController` の先頭合わせも同じく見出しのすぐ下に置く ([collection-interaction](../core-model/collection-interaction.md))。

iOS で 1 つのグループが内部の塊に割れても、見出しはグループ全体で 1 つとして固定され、塊の境目に隙間・行へのかぶり・動き・欠けは出ない (ios/ADR-0010。実現方法は [iOS コレクションエンジン](../../ios/architecture/collection-engine.md))。Android は Compose の固定見出し (`stickyHeader`) で同じ見え方になる。

### 全画面に広げたときの安全領域 (core/ADR-0017)

一覧を画面全体に広げて置いたとき (iOS の `.ignoresSafeArea()`、Android の edge-to-edge) にライブラリが安全領域に合わせるのは、固定中のグループの見出しを上端の安全領域の境目 (ステータスバー・ナビゲーションバーのすぐ下) より上へ行かせないことだけである。行はバーの裏を流れる。

コンテンツの先頭と末尾には安全領域の分の内側余白を足さない。ルートのヘッダーは安全領域に被ってよく、バーの分の空きは利用者がルートのヘッダーの大きさ (または `contentPadding`) で作る (末尾のフッター・最後の行も同じ)。安全領域に重ならない普通の置き方では、見え方は何も変わらない。左右の安全領域 (横向き) は特別に扱わない。

### セルの高さと content の配置 (ios/ADR-0007、両プラットフォーム共通)

- **セルの高さはコンテンツから自動決定される**。利用者に高さの指定や事前計算を要求しない。
- **content は行の上端に固定され、水平は中央に置かれる**。自然幅が項目幅より小さい content は水平中央に置かれ、項目幅いっぱいに広がる content はそのまま項目幅を占める (規則は 1 つ)。
- **静定時は content へ行の高さを与えない** (SwiftUI では提案しない、Compose では制約として渡さない)。grid で背の低いセルは行高いっぱいに広がらず、余りは背景として見える。Android の高さ補間中だけが例外 (「してはいけないこと」)。両プラットフォームで見え方が一致することを Sample「大量件数」で確認済み。
- **行の高さが変わるときはアニメーションする**。展開する項目自身の高さ変化と、それに押される他の項目の移動が中間フレームを通る。iOS は UICollectionView の標準挙動、Android はライブラリ既定の高さ補間 (android/ADR-0004)。

### list の区切り線 (core/ADR-0010)

| 項目 | 契約 |
|---|---|
| 位置 | 先頭行の上端・各行の間・最終行の下端。リスト全体の上下境界を同じ線で示す。グループがあるときはグループごとに引く (下記) |
| 幅と太さ | セルの左右いっぱい (インセットなし)、1pt / 1dp |
| 色 | 既定はライブラリ内部の固定値 `#D9D9DE`。`listSeparatorColor` で変更できる |
| 描画順 | content の前面。不透明な背景を持つテンプレートでも隠れない |
| 既定と opt-out | 既定で表示。`listSeparators(false)` で全て消す。グリッドには描かない |

グループを持つ list では、各グループの先頭行の上端・行の間・最終行の下端に線を引き、見出しは前のグループの最終行の下線と自分のグループの先頭行の上線の間に置かれる (core/ADR-0016)。見出しを宣言しない場合は、2 つめ以降のグループの先頭行の上線を出さない。出すと、グループの境目に前のグループの下線と合わせて 2 本の線が並ぶためである。線は余白 (行間・グループ間・見出しの下の間隔) を除いたセルの範囲に対して引く。

### スクロールインジケータ

| 項目 | 契約 |
|---|---|
| 表示 | 縦のインジケータを既定で表示する。スクロール中だけ現れ、止まって約 1 秒後に消える。つまんで動かすことはできない |
| 設定 | 表示 / 非表示の設定は持たない。iOS で SwiftUI の `.scrollIndicators(.hidden)` を付けても内側には届かない |
| 位置 | `contentPadding` の影響を受けない。コンポーネント本体の末尾側の端に置き、余白を含む全高を走る |
| 色 | 表示モードに従う (ライトは黒 35%、ダークは白 50%) |
| 長さと位置の精度 | 見積もりであり、行の高さがばらつくと長さが揺れる。末尾で下端に届くのは行の高さが揃っている場合 |

iOS は `UICollectionView` の既定のインジケータをそのまま使う。Android の Compose Lazy 系には標準の描画が無いため、ライブラリが iOS の既定に合わせて描く (太さ・端からの距離・最短の長さ・色・消えるまでの時間は iOS の実物から測った値)。プラットフォーム固有の差は次のとおり。

| 項目 | iOS | Android |
|---|---|---|
| 表示モードの判定元 | trait (`overrideUserInterfaceStyle` / `preferredColorScheme` で上書きできる) | 端末の表示モード (`isSystemInDarkTheme()`)。Compose の中だけでテーマをライトに固定したアプリでは、端末がダークだとバーが白になる |
| 長さの見積もり方 | 測り終えた行の実測と、未測定の行の見積もり (直近の実測の最頻値) の合計。進むほど落ち着く | 見えている行の平均の高さ × ライブラリが数えた全体の行数。ルートのヘッダー / フッターとグループの見出しを 1 行、各グループの項目を列数で切り上げた行数として数える |

どちらも `KsScrollController` の命令によるスクロールではインジケータを出さない。表示モードを固定せずに背景だけを明るい固定色で描くと、ダークモードでは両プラットフォームともバーが見えにくい。

## してはいけないこと

- grid のセルで `.frame(maxHeight: .infinity)` / `Spacer()` / `fillMaxHeight()` によって「行全体の高さに背景を敷く」ことを期待しない。行の高さはその行に並ぶセルのうち最も高いもので決まるが、各セルの content は自然高のまま上端に置かれる。行全体を塗りたい場合は content 側で高さを揃える。
- `rowSpacing > 0` の list で区切り線が行間の中央に出ることを期待しない。線はセルの底辺に描かれる。
- グループの見出しの View に上下の余白を持たせて間隔の代わりにしない。固定中の見出しと一緒に空白が上端へ貼り付く。間隔は `groupSpacing` / `headerItemSpacing` で指定する。
- 全画面に広げた一覧で、ルートのヘッダーや先頭行がバーの下へ自動でずれることを期待しない。安全領域に合わせるのは固定中の見出しだけで、バーの分の空きは利用者が作る。
- テンプレートの中で `Divider` / `HorizontalDivider` を描いて区切り線の代用にしない。ライブラリの区切り線と二重になる。
- Android で、テンプレートの根を「制約を子へ渡さない透明な箱」にしない。行の高さ変化の補間中に限り根に行の高さが制約として渡るため、根で背景を塗るか `Box(propagateMinConstraints = true)` にしないと折りたたみの途中に隙間が見える (android/ADR-0004)。

## 用語

- **layout 値**: `KsCollectionLayout` (Swift) / `KsLayout` (Kotlin) の値。表示形態・列数・スペーシングをまとめて持つ。
- **アンカー要素**: レイアウト切り替え直前に表示範囲の先頭にあった要素。切り替え後の位置決めの基準 (iOS)。
- **ルートヘッダー/フッター**: コンテンツ全体の先頭・末尾に 1 つずつ置く View。グループの見出しとは別物で、固定されない。
- **グループの見出し**: グループの先頭行の前に 1 つ置く View。既定で上端に固定される。
- **安全領域**: 画面上端のステータスバー・ナビゲーションバー・切り欠きが占める範囲。iOS の safe area、Android の `WindowInsets.systemBars` と `displayCutout` の和 (祖先が消費済みの分を除く)。
- **高さを与える / 提案する**: 親が子に高さを伝えて測らせること。SwiftUI では proposed size、Compose では constraints。本文書では両方を「与える」で表す。
- **Sample**: リポジトリ同梱 (`samples/`) の動作確認・パリティ検証用アプリ ([collection-items](../core-model/collection-items.md) の用語)。
- **content 配置**: セルの中身をセル領域のどこに置くかの規則 (上端固定・水平中央)。

## 関連

- [collection-items](../core-model/collection-items.md) — 差分更新とテンプレート、グループの宣言
- [iOS コレクションエンジン](../../ios/architecture/collection-engine.md) — 自前 compositional レイアウト・区切り線サブビュー・自己サイズと推定高さ
- [Android Compose ラッパー](../../android/architecture/compose-wrapper.md) — `LazyVerticalGrid` 統一・`BoxWithConstraints` による向き判定・項目単位の区切り線描画・高さ補間
- core/ADR-0006 (layout 値の語彙)、core/ADR-0010 (区切り線の既定外観)、core/ADR-0015 (グループの宣言と見出し)、core/ADR-0016 (グループごとの区切り線)、core/ADR-0017 (固定中の見出しを安全領域の境目で止める)
- ios/ADR-0010 (塊と見出しの固定)、ios/ADR-0003 (自前レイアウトの統一)、ios/ADR-0007 (セル content の配置)、android/ADR-0001、android/ADR-0004
