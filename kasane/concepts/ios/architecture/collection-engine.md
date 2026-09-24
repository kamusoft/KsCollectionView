---
type: concept
title: iOS コレクションエンジン
description: KsCollectionView の iOS 実装 — UICollectionView + diffable data source + UIHostingConfiguration による項目モデル・レイアウト・操作契約の実現方法と、その中で守っている仕組み
tags: [ios, engine, uicollectionview, hosting]
timestamp: 2026-09-24
---

# iOS コレクションエンジン

この文書を読むと、[項目モデル](../../core/core-model/collection-items.md)・[レイアウト語彙](../../core/styling/collection-layout.md)・[操作](../../core/core-model/collection-interaction.md) の契約を iOS 側がどの部品で実現し、どこに実測で確かめた罠対策が入っているかが分かる。エンジンは KsSettingsViewUI からの翻案移植 (ios/ADR-0001) で、公開されるのは DSL の入口だけ、エンジン型はすべて `internal` (ios/ADR-0005)。

## 全体像

```
KsCollectionView (SwiftUI, 値型 + modifier で KsCollectionConfiguration を積む)
  └ KsCollectionRepresentable (UIViewControllerRepresentable)
      └ KsCollectionViewController
           ├ UICollectionViewDiffableDataSource<KsSectionID, KsItemIdentifier>
           │     … item の identity は安定 ID のみ。section は配列を固定件数に区切った内部の塊 (ios/ADR-0009)
           ├ KsSnapshotPlanner        … 旧新の突き合わせで reconfigure / reload を振り分ける (塊を知らない)
           ├ KsSectionChunking        … 塊の件数と塊の数を決める
           ├ KsTemplateRegistry       … テンプレートキー → CellRegistration (遅延登録、snapshot 適用前に全キー準備)
           ├ UICollectionViewCompositionalLayout (sectionProvider が configuration と塊の位置を実行時参照)
           ├ KsEstimatedHeight        … 自己サイズの実測から推定高さを決める
           ├ KsImagePrefetcher        … prefetchResources の宣言 (KsResource) を取得単位へ解く台帳 → KsNukeImageLoading (Nuke ImagePrefetcher)
           └ KsHostingCell            … UIHostingConfiguration { KsRowContentPlacement { content } }
KsImage (SwiftUI)  … KsImageRequestFactory が索引 (KsImageMemoryIndex) から引き当て、外れたときだけ
                     NukeUI LazyImage (先読みが取得中なら KsImageDeferredLoad) が共有パイプラインへ要求を出す
```

Store 層と独自 diff 計算は持たない薄い 2 層構成 (ios/ADR-0004)。差分計算は diffable に任せ、内容変更の検知だけを旧新突き合わせで行う。

## 責務境界

| 部品 | 責務 |
|---|---|
| `KsSnapshotPlanner` | 旧新の配列から「識別子だけの snapshot」と、再構成 (同 ID・内容変化・キー不変) / 置換 (同 ID・キー変化) の対象を計算する。返すのは配列全体の識別子の列で、塊への区切りは controller が snapshot を組む直前に行う。重複 ID は debug assertion、release は後勝ち |
| `KsSectionChunking` / `KsSectionID` | 配列を載せる塊の件数と塊の数を決める (後述)。`KsSectionID` は塊の並び順だけを持つ識別子 |
| `KsTemplateRegistry` / `KsTemplate` | 値キーごとの `CellRegistration` を保持する。登録は snapshot 適用前に使用キー全てを準備する「登録準備の前倒し」(iOS 26 で初回セル取得中に登録を生成すると実行時例外になるため) |
| `KsCollectionViewController` | 塊ごとの snapshot の構築と適用、塊の件数が変わったときの組み直し、同値配列時の可視セル再構成 (ios/ADR-0006。観測する値が宣言されていればその変化時だけ、ios/ADR-0008)、レイアウト生成、区切り線とタッチ feedback の表示切替、表示位置の控えと復元、スクロール命令のキューと apply completion での flush、`applyingSnapshotCount` による再入防止 |
| `KsHostingCell` | `UIHostingConfiguration` の適用、再利用時のホスティング破棄 (state 非保持、ios/ADR-0002)、上下の区切り線ビューとタッチ feedback ビュー、hitTest による「セル内の操作要素か」の判定、自己サイズ結果の通知 |
| `KsRowContentPlacement` | セル content を包む `Layout`。行の高さの遅れによる中央配置はみ出しを防ぐ (後述) |
| `KsEstimatedHeight` | 自己サイズの実測から推定高さを決める値型 (後述) |
| `KsScrollController` | 命令を受け取り VC へ転送する。未接続のときは何もしない。複数のコレクションに接続されたときは、最後に接続したコレクションだけへ転送する |
| `KsLayoutDiagnostics` / `KsItemOffsetLookup` | 計測のための入口 (`@_spi(KsMeasurement)` を付けて読み込んだときだけ見える。利用者向け API ではない)。前者は Debug 構成だけに載る「自己サイズを返したセル数と、推定と不一致だった回数」の計数、後者は Release にも載る「画面の indexPath を配列全体の通し番号へ変換する」入口 |
| `KsImagePrefetcher` / `KsNukeImageLoading` | システムの先読み通知 (`KsPrefetching`、アイテム単位) を取得単位へ翻訳し、「アイテム ID → 宣言 (識別子・URL・幅の種類)」「取得単位 → 参照数と開始時の `ImageRequest`」の 2 層の台帳で寿命を管理する。列幅は controller が先読み通知の時点で `KsLayoutMetrics` の列数と bounds・余白・列間隔から解き、px で渡す。ローダー操作は internal な受け口 `KsImageLoading` に集め、本番は到達点ごとの `ImagePrefetcher` へ写像、テストは記録用の fake を注入する |
| `KsImageRequestFactory` / `KsImageIdentity` / `KsImageInvalidation` | `KsImage` の引き当てと表示要求の組み立て (外れたときの枠の実サイズからのデコード時縮小)、識別子 (キーまたは URL) と世代付き識別子の算出、キャッシュ消去の通知 (`ObservableObject`。下限 iOS 16 のため `@Observable` は使わない) |
| `KsImageMemoryIndex` / `KsImageMatching` | 引き当ての候補になる「メモリへ載せるよう要求した鍵」の索引 (主スレッドに閉じた LRU、上限 20,000 件) と、許容範囲の判定 (定数 0.5 / 4 はここに 1 か所) |
| `KsImageRetainedMatch` / `KsImageDeferredLoad` | 引き当てた画像と表示経路の選択を条件ごとに持ち続ける値と、画面に出る時点で引き当てを照会し直してから要求を出す包み (後述) |
| `KsImagePipeline` | `enableSharedDiskCache()` の実装。`dataCache` が未設定なら `configuration` を引き継いで差し替える (core/ADR-0012) |

## 保証すること (実測で確かめた罠対策)

### content は行の上端に固定し、水平は中央 (ios/ADR-0007)

`UIHostingConfiguration` はホスト View が行の高さを提案して content を測り、content の方が高いとその高さで組み直して行の中央に置く。行の高さが content の変化に 1 レイアウトパス遅れる間、content が上下へ均等にはみ出す (実測: 行 44pt / content 142pt で −48.7pt 上へ)。`KsRowContentPlacement` は提案された高さをそのまま自分の高さとして返し、content を自然高のまま上端へ置くことでこれを消す。翻案元 `CustomCellRowPlacement` から核心だけを移植し、固定行高の概念は持ち込んでいない。帰結として content に行の高さを提案しないため、grid で背の低いセルは行高いっぱいに広がらない (Android も同じ規則で一致 — [collection-layout](../../core/styling/collection-layout.md))。

### 推定高さは実測の最頻値 (`KsEstimatedHeight`)

compositional layout の `.estimated` は item 定義単位で index path ごとに変えられないため、コレクション全体で 1 つの推定高さを使う。UIKit は、セルが自己サイズで返した高さがそのセルに渡していた推定高さと違うと、そのセクションの配置を計算し直す (以下「解き直し」。`_UICollectionLayoutSectionEstimatedSolver`)。行の高さが数種類に集中する画面では、推定高さをいちばん多い高さに合わせれば、多数派のセルは解き直しを起こさない。

そこで推定高さは、直近 32 件の実測のうち最も多く現れた値にする。同数なら新しい方、どの値も繰り返していないうちは平均、未計測なら既定値 44pt を使う。標本の単位は行ではなくセルで、解き直しの判定がセルごとの比較で行われるためである。Sample の「大量件数」画面 (高さ 2 種類のセルが 6 : 1 で混在する 2 列グリッド) では、推定と違う高さに測られたセルの割合 (不一致率) は 0.02〜0.04 に収まる。推定高さが実測の平均だった頃は、平均がどちらの高さとも一致せず全セルが解き直しを起こし、基準機で解き直しが主スレッドの処理時間の 55% を占めていた。

解き直しが起きる境界は、画面のピクセル格子の半画素にある (倍率 3 で約 0.167pt、倍率 2 で 0.25pt)。境界より小さい差は解き直しを起こさない代わりに、渡した推定高さのまま行が積まれ、差が行数ぶん合計高さに積み上がる (差 0.1pt・60 行で 6.0pt)。そのため実測は格子に丸めて数えるが、返すのは最も多く現れた格子に入った実測のうち最新の値そのものにしている。丸めた値を返すと、半画素までの差が全行に積み上がる。

実測は測ったときの行の幅・画面の倍率と対で持つ。幅または倍率が変わったら前の標本を捨てるが、捨てるのは新しい幅・倍率の実測が届いた時点である。変わったと知った時点で捨てると、新しい実測がまだ無いまま、直後の再レイアウトが既定値 44pt を読んでしまう。

推定高さは、まだ解いていない範囲を含むコンテンツ全体の高さ (contentSize) の見積もりにも使われる。

| 配列 | 初回表示の合計高さの誤差 | 備考 |
|---|---|---|
| 行の高さが一様な 1 列 (2,000 件) | 0.09〜0.15% | 末尾へ送る間に合計の 0.1% を超えて変わるのは 1〜2 回 (Simulator 5 機種) |
| 高さの違うセルが混在する 2 列 (「大量件数」と同じ生成規則) | 約 34% (推定を平均にしても約 12%) | 行の高さが列内の最大で決まるため、単一の推定高さでは合計を当てられない。スクロールにつれて contentSize が伸びる |

混在する複数列の見積もりは直せていない。group に item と別の推定高さ (行の高さの平均) を渡しても、倍率 2 の iPad では渡す・渡さないで合計高さが完全に一致し、行の配置に使われなかった。倍率 3 の iPhone では、渡す推定高さを変えると、全行を解き終えた後の合計高さまで最大 1.6 倍違った。

### 配列は内部の塊に分けて載せる (ios/ADR-0009)

最頻値化だけでは、少数派の行が可視になるたびにセクション全体を解き直す費用が残る。解き直しの費用は 1 セクションの件数に比例するため、10,000 件を 1 セクションに載せると、解き直しの主スレッド占有率が 2,000 件のときの 4.1 倍になり、基準機での体感は不合格だった。そこで配列を固定件数の塊に区切り、塊ごとに diffable のセクションへ載せて、1 回の解き直しの上限を塊の件数で抑える。

塊の件数は基準 500 件を、次の列数の倍数へ切り上げた値にする。列数の倍数にするのは、塊の境界に列数に満たない行を作らないためである。

| layout | 塊の件数が倍数になる列数 |
|---|---|
| list | 1 (塊は 500 件) |
| 固定列数 n | n |
| 向き別列数 (portrait, landscape) | 両者の最小公倍数。回転しても塊を組み直さずに済む。最小公倍数の計算があふれるか 2,000 を超える組み合わせは、確定した列数へ縮退して回転で組み直す |
| adaptive | 確定した列数 (まだ解いていなければ 1) |

塊の数は件数を塊の件数で割って切り上げた数で、空配列でも 1 塊を載せる (ヘッダー / フッターを表示するため)。

塊の境界が見た目に出ないよう、sectionProvider (`makeLayout`) が塊の位置で次を切り替える。内側余白の上端は先頭の塊だけ、下端は末尾の塊だけに付け、先頭以外の塊の上端には行間を入れる (compositional layout はセクションの間に行間を入れないため)。ヘッダーは先頭の塊、フッターは末尾の塊にだけ付け、区切り線の上線は先頭の塊の先頭の項目にだけ出す。

塊の件数は snapshot を組むたびに現在の layout と確定した列数から計算し直し、適用済みの件数と違えば同値配列でも組み直す。この比較は、同値配列で早期に抜ける判定より前に行う。列数はレイアウトを解いて初めて分かるので、`viewDidLayoutSubviews` と適用の完了で判定し、組み直しは次の実行機会へ回す (レイアウトの途中で snapshot を適用しない)。組み直しの適用にはアニメーションを付けない。塊の件数が変わると先頭以外のほぼ全項目が隣の塊へ移る差分になり、動かすと位置の復元と重なって表示が乱れるためである。

効果は基準機の手動フリックで確かめた。先頭から未訪問の範囲へ下向きに 10 秒送る区間 (初回区間) で、解き直しの主スレッド占有率は 2,000 件 4.75%・10,000 件 4.94% (1.04 倍) となり、件数に比例しなくなった。

差分更新の挙動も確かめてある。先頭に 1 件挿入すると各塊の末尾の項目が次の塊へ移るが、塊の所属が変わった可視セルも作り直されず、同じセルのまま移動する。このとき表示範囲の先頭の項目の位置は動かない (UIKit が表示中の内容を留めるため、0.0pt)。

### 表示位置の控えと復元

layout 値の変更や塊の組み直しのように行の並びが変わる更新では、適用の前に「表示範囲の先頭にある項目」と表示範囲の上端からのオフセットを控え (`captureAnchor`)、適用とレイアウトの確定の後に同じオフセットへ戻す (`restorePendingAnchor`)。上端へ吸着させず同じオフセットへ戻すのは、値を連続して変えても表示が跳ねないようにするためである。

| 契機 | 控える時点 | 戻す時点 |
|---|---|---|
| layout 値の変更 (list ⇄ grid・列数の指定) | `update(configuration:)` で適用の前 | 適用の完了後。塊の件数も変わるなら次の実行機会 |
| 塊の件数の変化 (adaptive の列数変化・列数の初回確定) | 組み直しの適用の前 | 適用の完了の次の実行機会 |
| 向き別列数の回転 (塊は組み直さない) | `viewWillTransition(to:with:)` | `viewDidLayoutSubviews` で確定した列数が変わっていたら次の実行機会。変わっていなければ控えを捨てる |
| 項目の追加・削除・並べ替え | 控えない | — (位置の動きは塊が無い場合と同じ) |

表示範囲の先頭の項目 (`leadingVisibleID()`) は、可視セル一覧の最小の indexPath ではなく、レイアウト属性の矩形が表示範囲と重なる項目のうち先頭を採る。遠くへ送った直後は送る前のセルが可視一覧に残っており、一覧の先頭を採ると画面外の項目を控えて、復元で先頭へ飛ぶためである。回転の控えを `viewWillTransition` で取るのは、`viewWillLayoutSubviews` まで待つと bounds だけが新しく contentOffset が古い、食い違った組になるためである。列数が変わると同じ項目が行頭に来るとは限らないので、保つのは「控えた項目が、復元後も表示範囲の先頭の行に含まれる」ことまでになる。

復元を適用の直後ではなく次の実行機会まで遅らせるのは、同じ実行の中で戻すと、その後に UIKit 自身が行う位置の調整に上書きされ、表示範囲が 1 画面ぶんずれるためである (iPad で実測)。遅らせた復元には、控えるたびに 1 増える通し番号 (`anchorGeneration`) を持たせ、実行時に番号が変わっていたら取り下げる。番号は控え直したときと、利用者がドラッグを始めたとき (`scrollViewWillBeginDragging` で控えを捨てる) に変わる。番号が無いと、復元を待つ間に別の更新が控え直しても、先に予約した復元が古い控えの位置へ戻してしまう。

### 区切り線はセルのサブビュー

システム list の `separatorConfiguration` は使えない (システム list を使わないため)。`KsHostingCell` が上下 1pt の線ビューを content の前面に持ち、既定を非可視に倒して list かつ表示 ON のときだけ先頭行の上線と全セルの下線を可視化する。先頭行の判定は配列全体の先頭 (先頭の塊の先頭の項目) で行う。色は `listSeparatorColor` 未指定なら固定値 (core/ADR-0010)。`NSCollectionLayoutDecorationItem` を使わないのは、将来のセクション装飾と座を取り合うため。

### 位置依存の表示とタッチ feedback の揃え直し

先頭行の上線の有無、区切り線の色、タッチ feedback の色は、セルの組み立て時に加えて次の契機で現在の構成に揃え直す。

| 契機 | 対象 | 構成 | 届けるもの |
|---|---|---|---|
| 構成の差し替え (`update(configuration:)`) | 可視セル | 区切り線の表示・色・表示形態が変わったとき | 区切り線の変更 |
| 同値配列の更新 (`reconfigureVisibleCells`) | 可視セル | 問わない | タッチ feedback の色の変更 |
| 差分の適用完了 | 可視セル | 問わない | 位置が変わったセルの上線、差分で作り直されない残存セルへのタッチ feedback の色 |
| 表示に入る時点 (`willDisplay`) | 表示に入るセル | 問わない | 画面外で先に組み立てられたセルへの、組み立て後の変更 |
| レイアウト確定 (`viewDidLayoutSubviews`) | 可視セル | list かつ区切り線を表示のときだけ | 差分適用後の上線 |

レイアウト確定はスクロール中に毎フレーム通るため、揃える対象 (区切り線) を持たない構成では走査しない。かつてはここで構成を問わず全可視セルを上書きしており、それが差分の適用完了と表示に入る時点の経路の欠けを覆い隠していた。レイアウト確定を限定するなら、他の契機は構成を問わず残す必要がある。

セルは最後に書いた色を控え、同じオブジェクト (`===`) なら書き込みを省く。値の比較 (`!=`) は動的色で比較そのものの費用がかかり、書き込みは trait の解決とレイヤーの再描画要求を伴うためである。既定のタッチ feedback の色は定数 (`KsHostingCell.defaultTouchFeedbackColor`) に固定し、毎回同じオブジェクトにする。利用者が指定した色は構成の更新のたびに新しいオブジェクトになるが、スクロール中は変わらないのでガードが効く。

### 観測する値の変化だけがテンプレートを呼び直す (ios/ADR-0008)

`observedValue(_:)` の値は `KsCollectionConfiguration` に `AnyHashable?` で保持し、`update(configuration:)` が前回値と比べる。宣言があるときの再構成は次の 2 段に分かれる。

| 更新の種類 | 宣言あり | 宣言なし |
|---|---|---|
| 配列が同値 | 値が変わったときだけテンプレートのクロージャを呼び直す。値が同じでも位置依存の表示 (先頭行の区切り線) とタッチ feedback の色の追随は止めない | 届くたびにクロージャを呼び直す (ios/ADR-0006) |
| 配列が変わる | 差分で拾われた項目に加え、値が変わっていれば新 snapshot に生き残る可視セルも `reconfigureItems` の対象に加える (全識別子を 1 パス走査。画面外セルは表示時に最新構成で作られるため対象外) | 差分で拾われた項目だけ |

位置依存の表示とタッチ feedback を止めないのは、止めると宣言した利用者だけ `touchFeedback(color:)` の変更が表示中のセルへ届かなくなるため。生き残る可視セルを対象に加えないと、配列の追加と状態変化が同じ更新で届いたときに既存セルが古い観測値のまま取り残される。

### 可視セル再構成にトランザクションを渡しても中身はアニメーションしない

親の state 変更で Representable に届く `context.transaction` は `animation=nil` で、`withTransaction` で再構成へ引き渡しても載せるものが無い。タップを `withAnimation` で包んで `DefaultAnimation` を届けても、中身 (SwiftUI 側の描画) はアニメーションしなかった (Simulator でのフレームログ A/B とオーナー目視、2026-09-05)。行の高さの変化自体は UICollectionView の自己サイズ変更として約 0.35 秒かけて動き、transaction の有無に依存しない。`UIHostingConfiguration` の content view は内部の描画レイヤーを外から観測できないため、中身のアニメーションの判定は目視で行う。中身をアニメーションさせるには別の解き方が要る。

### 画像の先読みは controller 生成時の共有パイプラインを捕捉する

`KsCollectionViewController` は生成時に `ImagePipeline.shared` を読んで `KsNukeImageLoading` を作る。`KsImagePipeline.enableSharedDiskCache()` を後から呼んでも既存のコレクションの先読みは差し替え前のパイプラインを使い続けるため、利用者契約は「起動時に一度呼ぶ」になる ([画像の先読みと KsImage](../../core/core-model/image-loading.md))。取り消し通知には到達点が付かないため、`KsNukeImageLoading` は作成済みの全到達点の `ImagePrefetcher` へ停止を伝える。`ImagePrefetcher` は解放時に未完了の取得を止めるので、controller の解放で先読みは全停止する。

### 範囲内のメモリ項目は要求を出さずに描き、外れたときだけ 1 本の鍵で要求する

Nuke には近い大きさの項目を引き当てる手段も鍵の列挙も無く、`ThumbnailOptions` 付きの要求は寸法の違うメモリ項目を再利用せず再デコードする。そのため `KsImageMemoryIndex` が識別子ごとに `ImageRequest` を覚え、`KsImageRequestFactory` が組み立ての時点で候補をパイプラインのメモリキャッシュへ問い合わせて `KsImageMatching` で判定する (契約は [画像の先読みと KsImage](../../core/core-model/image-loading.md)、core/ADR-0013)。外れたときの表示要求は、常にデコード時縮小の指定 (`ThumbnailOptions` の `.aspectFit` / `.aspectFill`) を持つ 1 本の形にする。ローダーは要求そのものの鍵でメモリを引き、結果も同じ鍵へ書くため、経路ごとに鍵を変えると自分で書いた項目に次の表示が当たらない。

UIKit はセルの中身を先読みの開始と同じ頃に組み立てるので、組み立てで一度だけ引き当てると、先読みの完了後に画面に出たセルもディスクから再デコードする (実機で 147 件中 136 件)。そこで、先読みが取得中の可能性 (`mayBeLoadingPrefetch`) があるときだけ `KsImageDeferredLoad` で包み、画面に出る時点 (`onAppear`) で照会し直してから要求を出す。それ以外は組み立て時に `LazyImage` を置く (`LazyImage` も要求の開始は画面に出る時点)。`KsImageRetainedMatch` は、引き当てた画像と包みを選んだことを条件 (識別子と世代・`reloadToken`・枠・表示倍率・当てはめ方) ごとに覚える。`clear(.memory)` は索引と取得中の記録を消すが世代を進めないため、覚えていないと直後の組み立て直しで `LazyImage` に切り替わり、表示中の画像をディスクから再デコードする。

### ソース単位の削除は世代付き識別子で旧項目を避ける

Nuke のメモリ鍵は縮小オプションを含み、ライブラリはどのサイズで要求したかを後から列挙できない。`KsImageIdentity` は識別子を 1 か所で求める。キーなしは URL の文字列、キーありは `"ks-key " + key`、削除後は `"ks-gen N " + 識別子` で、キーと URL・世代付きの形と別のキーが衝突しない (core/ADR-0014)。`KsImageCache.remove(source)` は世代 0 の要求と現在の世代の要求の両方で消し、そのソースの世代を進める。以後の `KsImage` と先読みの要求は `ImageRequest.imageID` に世代付きの識別子を入れて発行する。世代 0 でキーなしのソースは識別子を付けず、NukeUI の `LazyImage` を直接使った表示と同じ項目を指し続ける。キーありのソースは世代 0 でも `imageID` を付け、メモリとディスクの両方の鍵がキーになる。`clear` は識別子を変えず、`KsImageInvalidation` の世代だけを進めて表示中の `KsImage` を組み立て直す。`clear` / `remove` は、生存している先読み層の一覧 (`KsImagePrefetchRegistry`) を通じて進行中の取得を止めてから消す。表示側の進行中の取得は止めない (Android に公開の取り消し口が無く、両プラットフォームで揃えるため)。

### レイアウト切替・入力・命令

- **レイアウトオブジェクトは差し替えない**。list ⇄ grid・列数・スペーシング・向き変更のいずれも、sectionProvider が `configuration.layout` を実行時参照し `invalidateLayout()` で反映する。`setCollectionViewLayout` を使うと全セルがバウンドして描画が乱れる (翻案元の実績。ios/ADR-0003)。
- **セル内の操作要素はタップを奪わない**。`KsHostingCell` の hitTest で操作要素 (UIControl 系) に当たったタッチはセル選択に流さず、feedback も出さない。長押し認識器はハンドラ未宣言時は無効。
- **スクロール命令は apply completion で flush**。データ差し替えと同時に来た命令は未完了の最後の apply が終わってから実行する。ID への命令と末尾への命令は `dataSource.indexPath(for:)` で解決するので、塊をまたいでも同じに動く。

## 分かっている限界

- 高さの違うセルが混在する複数列では、contentSize の見積もりが大きく外れる (上記「推定高さは実測の最頻値」)。
- 塊の件数が変わる適用の最中に配列と layout 値の更新が重なると、遅らせた復元が通し番号の不一致で取り下げられ、新しい控えが使われないまま残る。その更新の後は表示範囲の先頭の項目が保たれない。
- adaptive では、列数が変わってから塊を組み直すまでの間 (次の実行機会まで)、塊の境界に列数に満たない行が 1 フレーム出うる。
- 回転と adaptive の組み直しで位置が保たれることは、Simulator のテストでしか確かめていない。`viewWillTransition` と `scrollViewWillBeginDragging` が SwiftUI の representable 経由で実際に届くことはテストで担保していない。Sample に列数が変わる大量件数の画面が無く、実機でも目視できていない。
- 2 列 grid に自己サイズの行を載せ、静止を待たずに半画面ずつ送り続けると、セルが自己サイズで返す高さが 1 画素ずつ伸び続け、UIKit のレイアウトループ検出で落ちる (Simulator のテストで発見。別の変更 `kasane/changes/ios-self-sizing-layout-loop` で調査中)。

## してはいけないこと

### 自己サイズ・推定高さ・塊

- `KsRowContentPlacement` に「content へ行の高さを提案する」変更を入れない。自己サイズが自己参照になる。
- 推定高さの更新を契機に `invalidateLayout()` を呼ばない。推定高さは次に走る invalidate で読まれれば足り、追加の invalidate は再計算の連鎖になる。
- 推定高さを格子に丸めた値で返さない。半画素未満の差は解き直しを起こさないまま全行に積み上がる。
- 解き直しが起きたかを `shouldInvalidateLayout(forPreferredLayoutAttributes:withOriginalAttributes:)` の戻り値で判定しない。自己サイズ 1 回につき 1 回呼ばれるが、戻り値は解き直しの有無と連動しない。数えるなら `invalidateLayout(with:)` の回数とセルを測った回数を使う。
- 混在する複数列の合計高さを、group に item と別の推定高さを渡して直そうとしない。行の配置に使われない (上記)。
- `indexPath.item` を配列全体の順番として使わない。塊ごとに 0 から始まる。項目は `dataSource.indexPath(for:)` / `itemIdentifier(for:)` で ID から解決し、計測で通し番号が要るときは `KsItemOffsetLookup` を使う。
- 塊の件数が変わる適用にアニメーションを付けない。表示位置の復元を、適用と同じ実行の中で行わない (上記)。

### 更新と再構成

- 同値配列の更新経路で `id:` / `template:` / 登録集合の変更を反映しようとしない。表示中は不変の利用者契約 (ios/ADR-0006)。
- テンプレートのクロージャの中で UI state を持たせる設計に寄せない。再利用でホスティングを作り直す (ios/ADR-0002)。
- 観測する値が同じ同値配列の更新で、位置依存の表示とタッチ feedback 色の追随まで止めない (上記)。
- 可視セル再構成に `withTransaction` を渡して中身をアニメーションさせようとしない。効果が無いことは確認済み (上記)。

## 性能

スクロール性能の合否は、基準機でのオーナーの体感で下し、計測器の数値は証跡として残す (cross/ADR-0006)。判定規則は [スクロール性能の体感ゲート](../../../handbook/cross/scroll-performance-gate.md)、手順は [iOS 性能検証の手順](../../../handbook/ios/performance-verification.md)。

基準機 iPhone 11 (iOS 18.7.8、Release) で内部の塊を実装した後に、決まった順の手動フリック (固定の操作列) で計測した結果 (2026-09-17):

| fixture | 体感 | 数値の要点 |
|---|---|---|
| 大量件数 10,000 件 | 合格 | 初回区間の解き直し 4.94% (2,000 件の 1.04 倍)、不一致率 0.035。主スレッドの費用の主役はセルの生成 (初回区間で約 50%) と hosting の計測・描画 |
| 大量件数 2,000 件 | 合格 | 初回区間の解き直し 4.75%、不一致率 0.023 |
| 画像グリッド | 合格 | 全セルが同じ高さで、解き直しは time profile に一度も現れない |

体感と数値は食い違ったままである。体感は操作のどの段階でも引っかかりなしだが、hitch は残る。10,000 件では重大度 High の hitch が 36 件あり、記録全体で 1 秒あたり 76.8 ms がコマ落ちで失われた。画像グリッドでは、未訪問の範囲へ続けて送る区間に hitch が集中する。数値は合否に入れない規則なので、食い違いは証跡に書いて残している。

件数を変えた比較は、2,000 件の走行が初回区間で末尾に達していないことを成立条件にしている。末尾に達すると未訪問のセルが尽きて解き直しが減り、2 つの件数で仕事量が揃わないためである。Instruments の記録には到達した項目の番号が残らないため、この条件はオーナーへの確認で判定している。

メモリは Simulator で全項目走査の往復を重ねると 3〜6 往復で定常化し (iPhone 17 Simulator / iOS 26.1、10,000 件)、同時生存セルは可視セル数の 3 倍程度に留まる ([項目モデル](../../core/core-model/collection-items.md) の契約は 4 倍未満)。配列を置換すると同時生存は 4 倍未満に戻り、強参照を手放すと controller が解放される (エンジンテスト)。

## 用語

| 用語 | 意味 |
|---|---|
| Sample | リポジトリ同梱 (`samples/ios/`) の動作確認・パリティ検証用アプリ。「大量件数」「画像グリッド」は性能計測の土俵になる画面 |
| 基準機 | 性能の合否を下す実機。iOS は iPhone 11 |
| 識別子だけの snapshot | diffable の item identifier に安定 ID (`KsItemIdentifier` が包む `AnyHashable`) のみを載せ、内容を含めない構成。内容変化は snapshot の差分ではなく再構成で扱う |
| 登録準備の前倒し | snapshot 適用前に使用する全テンプレートキーの `CellRegistration` を生成すること。画面外の未登録キーもこの時点で検知される |
| 解き直し | compositional layout が、推定高さと違う高さに測られたセルを受けてセクションの配置を計算し直すこと。費用はセクションの件数に比例する |
| 不一致率 | 自己サイズを返したセルのうち、渡されていた推定高さと違う高さに測られた割合。解き直しの回数の上界になる |
| 塊 (内部セクション) | 配列を固定件数に区切って載せた diffable のセクション。利用者の宣言にも公開 API にも現れず、将来の論理セクションとは別物 (ios/ADR-0009) |
| 確定した列数 | 直近のレイアウトパスで決まった列数。固定列数以外はレイアウトを解くまで分からない |
| 同値配列 | 前回適用した配列と等しい配列 |
| 次の実行機会 | 今の処理を抜けた後にメインキューで実行される処理 (`DispatchQueue.main.async`)。レイアウトの途中や UIKit 自身の調整の前を避けるために使う |
| 控え | 行の並びが変わる更新の前後で位置を保つために記録する「表示範囲の先頭の項目と、表示範囲の上端からのオフセット」 |
| hitch | 描画が表示の期限に間に合わず、フレームが遅れて出た事象 (Instruments の指標。High は遅れの大きいもの) |
| 到達点 | 先読みが画像をどこまで持ってくるか。`disk` (元データをディスクまで) と `memory` (デコード済みをメモリまで) |
| 受け口 (`KsImageLoading`) | ローダーへの操作を集めた internal な境界。本番は Nuke の adapter、テストは記録用の fake が入る |
| 識別子 / 索引 / 引き当て | 画像の鍵の基準 (キーまたは URL)、引き当ての候補の一覧、許容範囲に入る項目を探して使うこと。意味は [画像の先読みと KsImage](../../core/core-model/image-loading.md) の用語節 |

## 関連

- [項目モデルと差分更新](../../core/core-model/collection-items.md)、[レイアウト語彙](../../core/styling/collection-layout.md)、[操作とスクロール制御](../../core/core-model/collection-interaction.md)
- [画像の先読みと KsImage](../../core/core-model/image-loading.md) — 先読み・到達点・キャッシュ操作の契約 (この文書はその iOS 側の実現)
- ios/ADR-0001〜0009 (0007: セル content の配置、0008: 観測する値、0009: 内部の塊)、core/ADR-0010 (区切り線の既定外観)、core/ADR-0012 (Nuke への直接依存と共有パイプライン)、core/ADR-0013・0014 (許容範囲の引き当て・任意キー)、cross/ADR-0006 (性能の完了判定)
- handbook/cross/runtime-behavior-verification.md (Simulator での観測点表に「検証: 行の高さ変化」を含む)
- 翻案元: `../KsSettingsView/ios/Sources/KsSettingsViewUI/` (`FullSnapshotContentTargets` / `KsCellRegistry` / `CustomCellRowPlacement` / `SectionBoxLayout`)
