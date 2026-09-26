# Design: sections-grouping

## Context

phase-4 の議論で、グループの宣言 (core/ADR-0015)、list の区切り線 (core/ADR-0016)、iOS の塊とグループの重ね方と見出しの固定の方式 (ios/ADR-0010) が proposed で決まった。本 design はそれを両プラットフォームの実装の方式に落とす。

現状の前提 (コードの調査による):

- iOS は `KsCollectionViewController` が 1 つの配列を塊 (`KsSectionID(chunkIndex:)`) に区切って snapshot を組み、sectionProvider (`makeLayout`) が塊の位置で内側余白・ルートのヘッダー / フッター・区切り線の上線を切り替えている。ヘッダーは boundary supplementary item で、固定 (`pinToVisibleBounds`) は使っていない。区切り線の上線は `indexPath.section == 0 && item == 0` の項目にだけ出る
- iOS の見出しは、その塊の上端の内側余白 (`contentInsets.top`) より外側 (上) に置かれる (試作 1 周目の計測)。このため今は `contentPadding.top` がルートのヘッダーと先頭行の間に入っている
- Android は `LazyVerticalGrid` に「ルートのヘッダー (key なし・全幅) → 項目 → フッター」を並べ、行間を `Arrangement.spacedBy` で全項目に一律に入れている。ルートのヘッダーと先頭行の間にも行間が入り、`contentPadding.top` はヘッダーの上に入る。スクロール命令と画像の先読み窓は「先頭の全幅項目は 0 か 1 個 + 平らな項目」の前提で lazy の index と項目の位置を写像している
- Android の依存 (Compose Foundation 1.11.4) の `LazyGridScope` は `stickyHeader(key, contentType, content)` を実験扱いでなく持つ (android/ADR-0001)。ライブラリ内で `animateItem` は使っておらず (android/ADR-0004 が禁じていた)、配列の差し替えで項目は新しい位置へ飛ぶ
- Android のスクロールインジケータは公式の `scrollIndicatorState` の全体の長さをそのまま使い、位置だけを補正している (`ksAlignedScrollOffset`)
- Sample は `SampleScreen` を両プラットフォームで同じ順・同じ文言で列挙し (10 画面)、Android のテストが画面数 10 を決め打ちしている

## Goals / Non-Goals

**Goals**: proposal の What Changes をすべて、両プラットフォームで同じ宣言・同じ見え方で実装する。Sample「グループ化」で体感と試作時の未確認 4 点を確かめる。

**Non-Goals**: proposal の Non-Goals のとおり。

## Decisions

### Decision 1: 公開 API の形 — グループは 1 つの宣言にまとめる

**採用案:** グループの値・見出し・固定の有無を 1 つの宣言にまとめる。Swift は modifier、Kotlin は引数 1 つに値を渡す (記法は各流儀、語彙は 1 対 1。core/ADR-0002)。間隔は layout 値の引数に足す (core/ADR-0006)。

以下の例の項目型は `Product` (`id` と、グループの値に使う `category: String` を持つ) とする。

**基本形** — `category` が同じ項目が続く範囲を 1 つのグループにし、見出しに「カテゴリ名 (件数)」を出す。見出しは既定で上端に固定される。

```swift
KsCollectionView(products) { product in ProductRow(product) }
    .groups(by: \.category) { category, productsInGroup in
        Text("\(category) (\(productsInGroup.count))")
    }
```

```kotlin
KsCollectionView(
    items = products,
    key = { it.id },
    groups = KsGroups(by = { it.category }) { category, productsInGroup ->
        Text("$category (${productsInGroup.size})")
    },
) { template { product -> ProductRow(product) } }
```

**見出しの固定を外す** — 基本形に `pinnedHeaders: false` を足すだけ。

```swift
KsCollectionView(products) { product in ProductRow(product) }
    .groups(by: \.category, pinnedHeaders: false) { category, _ in
        Text(category)
    }
```

```kotlin
KsCollectionView(
    items = products,
    key = { it.id },
    groups = KsGroups(by = { it.category }, pinnedHeaders = false) { category, _ ->
        Text(category)
    },
) { template { product -> ProductRow(product) } }
```

**見出しなし** — グループに分けるだけ (グループ間の間隔や区切り線の単位として使う)。

```swift
KsCollectionView(products) { product in ProductRow(product) }
    .groups(by: \.category)
```

```kotlin
KsCollectionView(
    items = products,
    key = { it.id },
    groups = KsGroups(by = { it.category }),
) { template { product -> ProductRow(product) } }
```

**間隔** — グループの間隔と見出しの下の間隔は、行間と同じく layout 値の引数で指定する (いずれも既定 0)。

```swift
KsCollectionView(
    products,
    layout: .grid(columns: .fixed(portrait: 2, landscape: 4),
                  rowSpacing: 8, groupSpacing: 24, headerItemSpacing: 8)
) { product in ProductCell(product) }
    .groups(by: \.category) { category, _ in Text(category) }
```

```kotlin
KsCollectionView(
    items = products,
    key = { it.id },
    layout = KsLayout.Grid(
        KsColumns.Fixed(portrait = 2, landscape = 4),
        rowSpacing = 8.dp, groupSpacing = 24.dp, headerItemSpacing = 8.dp,
    ),
    groups = KsGroups(by = { it.category }) { category, _ -> Text(category) },
) { template { product -> ProductCell(product) } }
```

グループの値の型は Swift が `Hashable`、Kotlin が型引数で、見出しのクロージャは型を保ったまま値を受け取る。`KsGroups` は Kotlin だけの公開型で、Swift の modifier に当たる (Kotlin の `template(key)` に Swift の `KsTemplate` が当たるのと同じ非対称)。

**理由:** Swift の初期化子は今 4 つ (ID の指定 × テンプレートの切り替え) あり、グループの値を初期化子の引数にすると組み合わせが 8 つに増える。modifier ならどの初期化子とも組み合わさる。Kotlin は、グループの値と見出しを別々の省略可能な引数にすると、見出しを省いたときにグループの値の型を推論できず、型を `Any` に落とすことになる。値と見出しを 1 つの型に入れれば、型引数を保ったまま全体を省略できる。固定の有無は見出しに属する設定なので同じ宣言に置く。

**代替案:**
- **A: Swift の初期化子に `section:` 引数を足す (議論時の仮称の形)** — 初期化子が 8 つになり、今後の引数追加でさらに倍になる
- **B: Kotlin で `section = { … }` と `sectionHeader = { value, items -> }` を別々の引数にする** — 見出しを省いた呼び出しで型が決まらず、見出しの値が `Any` になる
- **C: 固定の有無を独立した modifier / 引数 (`sectionHeadersPinned`) にする (議論時の仮称)** — グループの宣言と離れた場所に置けてしまい、グループなしで指定されたときの意味が無い
- **D: 公開の語彙を section にする (`.sections(by:)` / `KsSections` / `sectionSpacing`。提案の初版)** — 利用者の言葉 (「グループ化」「グループの値」) と旧 AiForms の語彙 (`IsGroupingEnabled` / `GroupHeaderTemplate` / `IsGroupHeaderSticky`) からずれ、iOS エンジンの内部で既に使っている「セクション」(内部の塊 = compositional layout のセクション) と同じ言葉になって取り違えやすい (オーナー判断で group に変更)。なお `groupBy` という名前は、Kotlin の `groupBy` / Swift の `Dictionary(grouping:)` のように離れた同じ値も集めると誤解させるため避け、`.groups(by:)` とする。続いた範囲だけがグループになることは利用者向けドキュメントに明記し、debug の assertion でも気づける
- **E: 見出しの下の間隔を `groupHeaderSpacing` / `groupHeaderToItemsSpacing` / `spacingBelowGroupHeader` / `groupHeaderBottomSpacing` と名付ける** — `groupHeaderSpacing` は見出しの上か下か、何と何の間かが読めない。残りは長い、語順がほかの間隔と違う、「下端」がどちらの下端か曖昧、のいずれか。layout 値で間隔を持つ見出しはグループの見出しだけ (ルートの見出しは前後に行間を入れず設定を持たない) なので `group` を外し、`rowSpacing` / `columnSpacing` と同じ作りで「見出しと項目の間」と読める `headerItemSpacing` にする (オーナー判断)

### Decision 2: Android のグループの値と見出しのキー

**採用案:** グループの見出しの lazy のキーは、ライブラリ内部の `Parcelable` 型 (グループの値と、release で同じ値が離れて現れたときの何回目か) にする。グループの値は項目の `key` と同じく状態保存 (Bundle) に載せられる型でなければならない (利用契約)。載らない値は不正入力として、項目の `key` と同じ扱い (core/ADR-0011 の Android 固有の 4 つめ) にする。

**理由:** 見出しにキーが無いと、グループの並べ替えや別グループへの移動で見出しが項目と一緒に動かない (差分更新の要件)。項目のキーと同じ名前空間に置くと、項目のキーとグループの値が偶然一致したときに衝突するので、内部の型で包んで分ける。lazy のキーは保存可能でなければならないため、包む中身 (グループの値) にも同じ制約が要る。

**代替案:**
- **A: 見出しのキーをグループの先頭の項目のキーから作る** — 先頭の項目が入れ替わるたびに見出しが作り直され、見出しの移動アニメーションが成り立たない
- **B: 見出しのキーを `toString()` した文字列にする** — 異なる値が同じ文字列になると衝突し、重複キーで落ちる

### Decision 3: iOS の snapshot — グループ × 塊

**採用案:** ios/ADR-0010 のとおり、配列を先頭から走査して同じグループの値が続く範囲をグループにし、各グループを先頭から塊の件数ごとに区切る。内部セクションの識別子を `KsSectionID(group: AnyHashable, occurrence: Int, chunkInGroup: Int)` に広げ (`occurrence` は離れて現れた同じ値の何回目か。正しい入力では常に 0)、塊ごとに「グループの中の位置・グループ内の塊の数・項目数・見出しの有無」を持つ表を snapshot と同時に作って sectionProvider と見出しの書き換えが読む。グループの値を指定しない場合は配列全体を 1 つのグループ (グループの値なし) として同じ経路に乗せる。離れて現れた同じ値の検知は走査と同時に行い、debug は assertion、release は警告ログ (core/ADR-0011)。

**理由:** 塊の件数の決め方・組み直しの条件・世代番号つきのアンカーは既存の仕組みのまま動かしたい。グループの有無で経路を分けると、塊の境界の処理 (余白・区切り線・ヘッダー) が 2 系統になる。

**代替案:**
- **A: グループありとなしで snapshot の組み立てを分ける** — 境界の処理が 2 系統になり、塊の境界を見せない保証を二重に保守する

### Decision 4: iOS の見出しの固定 — 方式 3c

**採用案:** 各グループの先頭の塊に見出しを付け (場所を取る)、塊に割れたグループでは 2 つめ以降の塊にも同じ見出しを場所を取らない形 (`extendsBoundary = false`) で付ける。固定するときは全見出しに `pinToVisibleBounds` を設定し、`UICollectionViewCompositionalLayout` の派生クラスで `layoutAttributesForElements(in:)` と `layoutAttributesForSupplementaryView(ofKind:at:)` が返す見出しの属性を複製して書き換える: y を「グループの見出しの本来の位置と表示範囲の上端の大きい方、ただしグループの最終行の下端から見出しの高さを引いた位置まで」に置き、横位置と幅を先頭の塊の見出しに揃え、表示範囲の上端を含む塊の見出しだけを不透明 (1) にして他は透明 (0) にする。押し出し中も透明度を 1 に保ち、UIKit の薄めを打ち消す。固定を外したときは `pinToVisibleBounds` を付けず、書き換えもしない。ルートのヘッダー / フッターは固定しない。

**理由:** 試作 2 周目で、塊の境目の隙間・かぶり・見出しの動き・帯の欠けがすべて 0、グループの境目の押し出しがオーナーが自然と判定した方式 3 と全フレーム一致した (ios/ADR-0010、[試作の証跡](../../roadmaps/v1-foundation/phases/phase-4-sections-grouping/artifacts/sticky-header-chunk-prototype-2026-09-24.md))。見出しは UIKit の supplementary view のままなので、差分の適用と再利用を UIKit に任せられる。

**代替案:** ios/ADR-0010 の Alternatives (全塊に通常の見出し / 場所を取らない見出し / 別 View の重ね描き / UIKit の薄めに任せる 3b) を参照。

### Decision 5: 間隔の置き方 — 行間は行の間だけ、2 つの間隔は固定見出しに貼り付かない場所に置く

**採用案:**

| 間隔 | iOS | Android |
|---|---|---|
| 行間 | `interGroupSpacing` と、グループの 2 つめ以降の塊の上端の内側余白 (既存) | 各項目の上側の余白 (グループの先頭行以外)。`Arrangement.spacedBy` の縦方向は 0 にする |
| 見出しの下の間隔 | グループの先頭の塊の上端の内側余白 (見出しより内側に入る) | グループの先頭行の項目の上側の余白 |
| グループ間の間隔 | 最後のグループ以外の、末尾の塊の下端の内側余白 | 最後のグループ以外の、最終行の項目の下側の余白 |

区切り線・タッチの反応範囲・高さの補間は、余白を除いた content の範囲に対して描く / 測る。

**理由:** 見出しの内側 (見出しの View の余白) に置くと固定中の見出しと一緒に空白が貼り付く (core/ADR-0015 で却下した形)。Android の固定見出しは lazy の項目なので、見出しの前後の余白を見出しの項目に入れると同じく貼り付く。項目の側に置けば行と一緒に流れる。`spacedBy` は全項目に一律の値しか入れられず、見出しの前後だけ行間を外せない。

**代替案:**
- **A: Android で `spacedBy` を残し、見出しの前後だけ負の余白で打ち消す** — 固定見出しの位置と押し上げの計算が負の余白で狂い、区切り線とタッチの範囲も合わせにくい
- **B: 間隔を空の全幅項目 (スペーサー) として並べる** — スペーサーが lazy の項目になり、スクロール命令・先読み窓・インジケータの行数の写像に混ざる。iOS には対応物が無く非対称になる

### Decision 6: ルートのヘッダー / フッターの余白を両プラットフォームで揃える

**採用案:** ルートのヘッダー / フッターの前後にも行間を入れない (グループの見出しと同じ規則)。`contentPadding` はルートのヘッダーの上とフッターの下に入れる (core/ADR-0006 の「本体とスクロールするコンテンツの間の内側余白」。ヘッダーもコンテンツ)。iOS はルートのヘッダー / フッターをレイアウト全体の boundary supplementary item (`UICollectionViewCompositionalLayoutConfiguration.boundarySupplementaryItems`) に移し、`contentPadding` をその外側に置く。Android は Decision 5 の並べ方で行間がヘッダーの前後に入らなくなる。

**理由:** 今は iOS が「ヘッダーの下に `contentPadding.top`、行間なし」、Android が「ヘッダーの上に `contentPadding.top`、ヘッダーの下に行間」で揃っていない (調査)。グループの見出しで「行間は見出しの前後に入らない」と決めたので、ルートのヘッダーも同じ規則にする。`contentPadding` の位置は core/ADR-0006 の意味論で決まっている。

**代替案:**
- **A: ルートのヘッダーは今のまま (両プラットフォームで違うまま) にする** — sample-parity の見え方が一致せず、グループの見出しとルートのヘッダーで規則が違う
- **B: iOS のルートのヘッダーは先頭の塊に付けたまま、内側余白の順序だけ入れ替える** — compositional layout では見出しは内側余白の外側に置かれ、グループ単位では余白を見出しの上に置けない

### Decision 7: 区切り線の上線の判定

**採用案:** 上線を出す項目を「グループの先頭の塊の先頭の項目」にする。見出しを宣言しない場合は最初のグループだけに出す (core/ADR-0016)。iOS は塊の表から、Android は項目ごとの「グループの先頭か」の表から判定する。

**理由:** 今の判定 (配列全体の先頭の項目だけ) をグループの単位に広げるだけで済む。

**代替案:** なし (core/ADR-0016 の決定をそのまま写す)

### Decision 8: Android の並べ方と固定見出し

**採用案:** `LazyVerticalGrid` に「ルートのヘッダー → (各グループの見出し → 項目) → フッター」を並べる。見出しは固定するとき `stickyHeader(key = 見出しのキー, contentType = 見出し専用)`、固定しないとき `item(span = 全幅, key = 見出しのキー)` で置く。項目の位置と lazy の index の対応は、グループの構成から前もって作った表 (項目の位置 → lazy の index、lazy の index → 項目の位置または見出し) で写像し、スクロール命令と先読み窓はこの表を使う。ID によるスクロール命令で見出しが固定されている場合は、固定見出しの高さの分だけずらして項目を見出しの下に置く。

**理由:** 固定見出しは Compose 標準の仕組みで、押し上げの挙動も標準のまま iOS の 3c と同じ見え方 (薄れずに押し上げられる) になる。今の写像は「先頭の全幅項目 + 平らな項目」の前提なので、見出しが挟まると壊れる。

**代替案:**
- **A: 固定見出しを `LazyVerticalGrid` の外に重ねて自前で描く** — Compose に標準の固定見出しがあるのに、押し上げ・再利用・差分を自前で持つことになる

### Decision 9: 回転での位置の復元 — 固定見出しの下へ

**採用案:** iOS は控えた項目を復元するとき、その項目のグループの見出しが固定される場合は、見出しの高さの分だけ下にずらして表示範囲の先頭に置く。表示範囲の先頭の項目の選び方 (`leadingVisibleID`) も、固定中の見出しに覆われた範囲を表示範囲から除いて選ぶ。Android は lazy の状態がキーで位置を保つので、ずらしは ID によるスクロール命令と同じ処理 (Decision 8) を使う。

**理由:** 表示範囲の先頭に戻すと、固定中の見出しの裏に項目が隠れる (agenda の決定)。

**代替案:** なし (agenda の決定を写す)

### Decision 10: Android のスクロールインジケータの全体の行数

**採用案:** グループの構成と列数から全体の行数を数える (ルートのヘッダー / フッター・各見出しを 1 行、各グループの項目は切り上げの行数)。全体の長さは「公式の値が前提にした行数」との比で補う: `補った全体の長さ = 公式の全体の長さ × 数えた行数 ÷ 公式が数えた行数` (公式が数えた行数は、全幅項目を 1 ÷ 列数 行とした `ceil(lazy の項目数 ÷ 列数)`)。位置は、先頭の可視項目の行番号を同じ数え方で数え直して求め、既存の位置の補正 (上側の余白に前の行が見える間の食い違い) はその上に重ねる。数え直しの表は Decision 8 の表と同時に作り、描画フェーズでだけ読む。

**理由:** 公式の値は全幅の項目を 1 ÷ 列数 行と数え、見出しの数に比例して短くなる (agenda の決定)。行数はグループの構成から正確に分かり、残る誤差は行の高さのばらつきだけになる。

**代替案:**
- **A: 公式の値のまま受け入れる** — agenda で却下 (「グループ化」画面で 6〜7% 手前で下端に着く)

### Decision 11: Sample「グループ化」

**採用案:** 両プラットフォームの `SampleScreen` の末尾に「グループ化」を足す。データは ID から決まる決定的な生成 (「大量件数」と同じ流儀) で、10,000 件を 1,200 件前後のグループ 3 つと 5〜30 件のグループ多数に分ける (大きいグループは先頭寄り・中ほど・末尾寄りに散らす)。layout は縦 2 / 横 4 列、見出しは固定、グループ名と件数を表示する。操作は「グループの並び順を反転」と「見えている項目を 1 つ別のグループへ移す」の 2 つ。性能の自動計測の対象 (iOS の計測ドライバ、Android の Macrobenchmark と比較対象) に「グループ化」を加える。Android の比較対象の画面には、相対計測の前にスクロールインジケータを付ける (handbook/android/performance-verification の「比較対象と、それが測るもの」)。画面数の決め打ちのテストを更新する。

**理由:** agenda の決定 (大小混在の 1 画面・向き別列数・操作ボタン 2 つ)。大きいグループを散らすのは、先頭・中ほど・末尾のどこでも塊の境目と固定見出しの入れ替わりを通るため。

**代替案:** agenda の決定事項「グループ化の性能を確かめる画面」「差分アニメーションを確かめる場所」を参照。

### Decision 14: Sample「差分更新」

**採用案:** 両プラットフォームの `SampleScreen` の「グループ化」の次に「差分更新」を足す。20 件の配列 (ID から決まる決定的な内容。件数は動きを目で追える少なさにする)、list / 2 列グリッドの切り替えと、グループの有無 (5 件ずつ 4 グループ、見出し固定) の切り替え。操作の対象の位置 (先頭 / 中ほど / 末尾) を切り替え、位置ごとに 挿入 (新しい ID の項目) / 削除 / 更新 (内容を同じ ID で変える) / 移動 (別の位置へ。グループありなら別のグループへ) を行う。位置によらない操作として 反転 / シャッフル (固定の種から進む擬似乱数で、両プラットフォームで同じ順) / 元に戻す。先頭・中ほど・末尾の挿入と削除を揃えるのは、Android の試作をオーナーが目視したとき「末尾・中間の挿入と削除も無いと網羅できない」と判定したため。操作ごとに配列をデータ側で組み替えて渡す。グループありのときは、どの操作の後も同じグループが続くようにデータ側でグループ単位に並べ直す (反転はグループの順とグループ内の順の両方を逆に、シャッフルはグループの順とグループ内の順をそれぞれ混ぜる。離れた同じグループの値は不正入力のため)。

**理由:** 今の Sample には配列を差し替える操作がどの画面にも無く、差分のアニメーション (Android の `animateItem` を含む) を確かめる場所が無かった (オーナー指示)。「グループ化」の操作は 10,000 件と iOS の塊をまたぐ動きのためのもので、件数が多く動きを目で追いにくい。少ない件数の画面を別に持つ。

**代替案:**
- **A: 「グループ化」画面の操作を増やして兼ねる** — 10,000 件では動く範囲が画面に収まらず、挿入・削除の動きを目で追えない

### Decision 15: iOS の見出しの内容の更新

**採用案:** 配列の適用 (差分の有無によらない) の完了時と、観測する値 (`observedValue`) が変わったときに、表示中の見出し (塊の見出しを含む) を集めて、新しい配列でのグループの値とグループ内の項目で内容を設定し直す。見出しの view は作り直さず、`UIHostingConfiguration` を設定し直す。同じグループの塊の見出しはすべて同じ内容で設定する。

**理由:** diffable の差分は項目の identity と再構成だけを扱い、supplementary view の内容はグループの識別子が変わらない限り更新されない。項目の数だけが変わる場合 (件数を出す見出し) や、見出しが親の状態を読む場合に古い内容が残る。可視セルを同値配列の更新でも再構成する既存の方針 (ios/ADR-0006、観測する値は ios/ADR-0008) を見出しにも広げる。

**代替案:**
- **A: 項目の数が変わったグループだけ識別子を変えて作り直させる** — 見出しの作り直しで固定中の見出しが一瞬消え、差分の移動アニメーションも崩れる

### Decision 16: 端を表示中の端への挿入 (両プラットフォーム)

**採用案:** 配列を差し替える直前に、表示範囲がコンテンツの先頭にあるか (上端がコンテンツの上端と一致) と、末尾にあるか (下端がコンテンツの下端と一致。どちらも 1pt / 1px 未満の差は一致とみなす) を控える。差し替えで先頭に項目が入り、直前に先頭にいた場合は、表示範囲を先頭に留める。差し替えで末尾に項目が入り、直前に末尾にいた場合は、表示範囲を末尾に留める。どちらでもない差し替えは各プラットフォームの既定の位置の保ち方のまま。留め方は、挿入のアニメーションと同時に表示範囲が端に追従する形にし、挿入 → 反映後に改めてスクロール、の 2 段の動きにしない。

| | iOS | Android |
|---|---|---|
| 先頭 | 既定 (コンテンツの位置を保つ) で先頭に留まる。先頭に留まることを確かめるだけ | `LazyGridState.requestScrollToItem(0)` を差し替えと同じフレームで要求する (既定は見えている先頭の項目の位置を保ち、新しい項目が上に外れる) |
| 末尾 | 差分の適用と同じアニメーションの中で、コンテンツの高さの変化分だけ `contentOffset` を下げて末尾に留める (既定は位置を保ち、新しい項目が下に外れる) | 差し替え後の最後の lazy の index へ、表示範囲の下端に合わせてスクロールを要求する (既定は見えている先頭の項目の位置を保ち、新しい項目が下に外れる) |

具体的な留め方 (アニメーションとの重ね方) は、実装時に両プラットフォームでオーナーの目視で「アニメーションが見える」ことを確かめて決める。

**理由:** 端を見ている利用者にとって、端への挿入が見えないのは不具合に見える。Android の試作で、いちばん上での先頭への挿入が上に外れて見えないことをオーナーが NG と判定し、同じことが末尾 (いちばん下での末尾への挿入が下に外れる) では両プラットフォームで起きていた (試作の観察)。オーナーの判断で、両プラットフォーム・list / グリッドの両方で、端を見ているときの端への挿入はアニメーションが見えることを必須とし、画面外での挿入は見えないので考慮しないとした。

**代替案:**
- **A: Android の先頭だけを直す (提案の初版)** — 末尾への挿入は両プラットフォームで下に外れて見えないまま残る
- **B: 表示範囲の位置の保ち方を、両プラットフォームで常に同じ方式 (コンテンツの位置、または見えている先頭の項目) に揃える** — 画面外での挿入まで振る舞いを変えることになるが、画面外の挿入は見えないので揃える利得が無い (オーナー判断)

### Decision 12: 検証

**採用案:** Scenario ごとの自動テスト (iOS はエンジンのテストで属性と位置、Android は Robolectric のレイアウトテスト) に加え、次を evidence/ に残す。

| 項目 | 方法 |
|---|---|
| 基準機の体感 (両プラットフォーム) | handbook/cross/scroll-performance-gate の固定の操作列、「グループ化」画面。記録はオーナーの合図を待って始める |
| 塊の境目の見出しの見え方 (iOS) | 試作と同じフレームごとの位置の記録 (ゆっくり / 速く) を本実装で取り直す |
| 追加・削除のアニメーション中の見出しの位置 (iOS) | 「グループ化」画面の 2 つの操作で、アニメーション中のフレームの位置を記録する |
| VoiceOver での見出し (iOS) | 塊に割れたグループで、読み上げで見える見出しが 1 つであること (透明の見出しを読み上げ対象から外す) |
| 塊が多いときの書き換えの費用 (iOS) | 体感の計測と同じ走行の time profile で、書き換えの主スレッド占有率を記録する |
| UIKit の薄め方の版差 (iOS) | 対応 OS の最古 (iOS 16) の Simulator で、押し出し中の透明度の変化が透明度で起きていることを確かめる |
| Android の相対計測 | 比較対象にスクロールインジケータと `animateItem` を付けてから、「グループ化」で相対基準を測る。`animateItem` の「なし / あり」の比較を別に証跡として取る |
| 固定見出しと `animateItem` (Android) | 「差分更新」画面 (グループあり) の並べ替えで、固定中の見出しを含めて移動アニメーションすることを確かめる |

**理由:** 試作時に未確認だった 4 点 (ios/ADR-0010 の負の帰結) と、一瞬の見え方は静止画でなく位置の記録かオーナーの目視で判定する規律 (handbook/cross/runtime-behavior-verification)。

**代替案:** なし

### Decision 13: Android の移動・挿入・削除のアニメーション

**採用案:** 項目とグループの見出しに `Modifier.animateItem()` を付け、配列の差し替えによる移動・挿入・削除をアニメーションで見せる (android/ADR-0006、amends android/ADR-0004)。付ける位置 (`ksAnimatedHeight` など既存の modifier との順序)、出入りのフェードの有無、高さ変化の補間と同時に動くときの扱いは、使い捨ての試作 (Android エミュレータで `animateItem` なし / ありを切り替える画面) のオーナー目視で決めてから実装する。固定中の見出し (`stickyHeader`) にも付けて動くことを確かめる。グリッドで列をまたぐ移動は、両プラットフォームとも標準の見え方 (元の位置から移動先へまっすぐ動く) のままにし、自前の配置アニメーションに差し替えない (試作で iOS も同じ動きと確認し、オーナーが標準のままを選択)。性能は handbook/android/performance-verification に従い、既定機能になった `animateItem` を比較対象 (素の Lazy グリッド) にも付けて相対基準を測り、既存 fixture の回帰も測る。`animateItem` 自体の費用は相対基準に現れないため、ライブラリの「なし / あり」の比較を証跡として別に取り、体感のゲート (cross/ADR-0006) で合否を決める。

**理由:** 差分とアニメーションはライブラリの責務 (core/ADR-0003) で、iOS は diffable が見せている。Compose で配置の変化を見せる手段は `animateItem` だけ。ADR-0004 の禁止は高さ補間に重ねたときの性能の上乗せが理由で、移動を見せる目的では検討していなかった。D&D 並べ替え機能の時期は決まっておらず、いずれ解く必要がある (オーナー判断)。

**代替案:**
- **A: ADR-0004 に従い、Android の移動のアニメーションを D&D 並べ替え機能まで先送りする** — 先送りしても解くコストは変わらず、その間 Android だけ項目が飛ぶ (android/ADR-0006 で却下)
- **B: グリッドで列をまたぐ移動を、両プラットフォームで薄れて入れ替わる形に差し替える** — 両プラットフォームで配置のアニメーションを自前で持つことになり、差分の適用・再利用・高さの補間との組み合わせを保守する。両 OS の標準は斜めにまっすぐ動く形で、利用者に見慣れた動き

## Risks / Trade-offs

- iOS でグループの数がグループの数になる費用 (ios/ADR-0010 の負の帰結) は、体感で不合格なら Revisit When に従って別の変更で再検討する。本 change の中で方式を変えない
- 3c は UIKit の薄め方に依存する。iOS 16 で透明度以外の薄め方だった場合は、その版だけ UIKit の既定 (3b 相当) に落ちることを deviation で扱う
- ルートのヘッダーの余白の変更 (Decision 6) は既存の見た目を変える (iOS は `contentPadding.top` の位置、Android はヘッダーの下の行間)。配布前のため互換の手当てはしない
- Android の `animateItem` (Decision 13) はスクロール中の性能に上乗せが出うる。比較対象にも付けるため相対基準には現れず、「なし / あり」の比較と体感のゲートで判断する。体感で不合格なら付け方 (フェードを外す等) を試作に戻って見直し、それでも不合格ならオーナーに相談する
- Android の行間を項目の余白に移す (Decision 5) ことで、既存の区切り線・タッチ・高さの補間の範囲の計算を content の範囲に合わせ直す必要がある。既存のテスト (行間・区切り線・ヘッダー) の期待値の見直しを伴う

## Migration Plan

配布前のため移行の手当ては不要。既存の利用コードはグループを宣言しなければ今の見た目のまま (ルートのヘッダーの余白の変更 (Decision 6) を除く)。

## Open Questions

なし (提案作成時の未決「先頭以外を表示中の、表示範囲より前への挿入・削除での位置の保ち方の違い」は、画面外の挿入は見えないので考慮不要とオーナーが判断して決着。Decision 16)

## ADR 候補

- Decision 1 (公開 API の形): 覆すコストが高い公開 API の形で、両プラットフォームにまたがる。core/ADR-0015 の「引数名は仮称」を確定させる形で ADR-0015 に反映する
- Decision 2 (Android のグループの値の制約): 利用契約を足し、core/ADR-0011 の Android 固有の不正入力の対象を広げる。core/ADR-0015 の Consequences に反映するか、android の ADR にするかを蒸留時に判断する
- Decision 4 (iOS の見出しの固定): ios/ADR-0010 に反映済み
- Decision 13 (Android の `animateItem`): android/ADR-0006 (proposed、amends 0004) に反映済み
- Decision 6 (ルートのヘッダーの余白): core/ADR-0006 の `contentPadding` の意味論の適用で新しい決定ではないが、行間を見出しの前後に入れない規則は core/ADR-0015 に含めて記録する
