---
type: concept
title: iOS コレクションエンジン
description: KsCollectionView の iOS 実装 — UICollectionView + diffable data source + UIHostingConfiguration による項目モデル・レイアウト・操作契約の実現方法と、その中で守っている仕組み
tags: [ios, engine, uicollectionview, hosting]
timestamp: 2026-09-05
---

# iOS コレクションエンジン

この文書を読むと、[項目モデル](../../core/core-model/collection-items.md)・[レイアウト語彙](../../core/styling/collection-layout.md)・[操作](../../core/core-model/collection-interaction.md) の契約を iOS 側がどの部品で実現し、どこに実測で確かめた罠対策が入っているかが分かる。エンジンは KsSettingsViewUI からの翻案移植 (ios/ADR-0001) で、公開されるのは DSL の入口だけ、エンジン型はすべて `internal` (ios/ADR-0005)。

## 全体像

```
KsCollectionView (SwiftUI, 値型 + modifier で KsCollectionConfiguration を積む)
  └ KsCollectionRepresentable (UIViewControllerRepresentable)
      └ KsCollectionViewController
           ├ UICollectionViewDiffableDataSource<KsSectionID, AnyHashable>   … identity は安定 ID のみ。section は常時 1 つ (将来のセクション対応に備えた型)
           ├ KsSnapshotPlanner        … 旧新の突き合わせで reconfigure / reload を振り分ける
           ├ KsTemplateRegistry       … テンプレートキー → CellRegistration (遅延登録、snapshot 適用前に全キー準備)
           ├ UICollectionViewCompositionalLayout (sectionProvider が configuration を実行時参照)
           └ KsHostingCell            … UIHostingConfiguration { KsRowContentPlacement { content } }
```

Store 層と独自 diff 計算は持たない薄い 2 層構成 (ios/ADR-0004)。差分計算は diffable に任せ、内容変更の検知だけを旧新突き合わせで行う。

## 責務境界

| 部品 | 責務 |
|---|---|
| `KsSnapshotPlanner` | 旧新の配列から「識別子だけの snapshot」と、再構成 (同 ID・内容変化・キー不変) / 置換 (同 ID・キー変化) の対象を計算する。重複 ID は debug assertion、release は後勝ち |
| `KsTemplateRegistry` / `KsTemplate` | 値キーごとの `CellRegistration` を保持する。登録は snapshot 適用前に使用キー全てを準備する「登録準備の前倒し」(iOS 26 で初回セル取得中に登録を生成すると実行時例外になるため) |
| `KsCollectionViewController` | snapshot 適用、同値配列時の可視セル再構成 (ios/ADR-0006。観測する値が宣言されていればその変化時だけ、ios/ADR-0008)、レイアウト生成、区切り線とタッチ feedback の表示切替、スクロール命令のキューと apply completion での flush、`applyingSnapshotCount` による再入防止 |
| `KsHostingCell` | `UIHostingConfiguration` の適用、再利用時のホスティング破棄 (state 非保持、ios/ADR-0002)、上下の区切り線ビューとタッチ feedback ビュー、hitTest による「セル内の操作要素か」の判定、自己サイズ結果の通知 |
| `KsRowContentPlacement` | セル content を包む `Layout`。行の高さの遅れによる中央配置はみ出しを防ぐ (後述) |
| `KsEstimatedHeight` | 自己サイズの実測から推定高さを決める値型 (後述) |
| `KsScrollController` | 命令を受け取り VC へ転送する。未接続は no-op、最後の接続だけ有効 |

## 保証すること (実測で確かめた罠対策)

### content は行の上端に固定し、水平は中央 (ios/ADR-0007)

`UIHostingConfiguration` はホスト View が行の高さを提案して content を測り、content の方が高いとその高さで組み直して行の中央に置く。行の高さが content の変化に 1 レイアウトパス遅れる間、content が上下へ均等にはみ出す (実測: 行 44pt / content 142pt で −48.7pt 上へ)。`KsRowContentPlacement` は提案された高さをそのまま自分の高さとして返し、content を自然高のまま上端へ置くことでこれを消す。翻案元 `CustomCellRowPlacement` から核心だけを移植し、固定行高の概念は持ち込んでいない。帰結として content に行の高さを提案しないため、grid で背の低いセルは行高いっぱいに広がらない (Android も同じ規則で一致 — [collection-layout](../../core/styling/collection-layout.md))。

### 推定高さは実測平均 (`KsEstimatedHeight`)

compositional layout の `.estimated` は item 定義単位で index path ごとに変えられないため、コレクション全体で 1 つの値を使う。未計測なら 44pt、以後は直近 32 件の実測の平均。中央値ではなく平均なのは、推定値がコンテンツ全体の高さの見積もりに使われ、合計を言い当てる推定量が平均のため。実測は「測ったときの行の幅」と対で持ち、違う幅の実測が来た時点で前の幅の分を捨てる (幅が変わった瞬間に捨てると、その直後の再レイアウトが既定値を読んでしまう)。効果: 初回表示のコンテンツ高さの誤差 −27% → 0%、末尾へのスクロール中の contentSize 変化 25 回 → 1 回。

### 区切り線はセルのサブビュー

システム list の `separatorConfiguration` は使えない (システム list を使わないため)。`KsHostingCell` が上下 1pt の線ビューを content の前面に持ち、既定を非可視に倒して list かつ表示 ON のときだけ先頭行の上線と全セルの下線を可視化する。色は `listSeparatorColor` 未指定なら固定値 (core/ADR-0010)。`NSCollectionLayoutDecorationItem` を使わないのは、将来のセクション装飾と座を取り合うため。

### 観測する値の変化だけがテンプレートを呼び直す (ios/ADR-0008)

`observedValue(_:)` の値は `KsCollectionConfiguration` に `AnyHashable?` で保持し、`update(configuration:)` が前回値と比べる。宣言があるときの再構成は次の 2 段に分かれる。

| 更新の種類 | 宣言あり | 宣言なし |
|---|---|---|
| 配列が同値 | 値が変わったときだけテンプレートのクロージャを呼び直す。値が同じでも位置依存の表示 (先頭行の区切り線) とタッチ feedback の色の追随は止めない | 届くたびにクロージャを呼び直す (ios/ADR-0006) |
| 配列が変わる | 差分で拾われた項目に加え、値が変わっていれば新 snapshot に生き残る可視セルも `reconfigureItems` の対象に加える (全識別子を 1 パス走査。画面外セルは表示時に最新構成で作られるため対象外) | 差分で拾われた項目だけ |

位置依存の表示とタッチ feedback を止めないのは、止めると宣言した利用者だけ `touchFeedback(color:)` の変更が表示中のセルへ届かなくなるため。生き残る可視セルを対象に加えないと、配列の追加と状態変化が同じ更新で届いたときに既存セルが古い観測値のまま取り残される。

### 可視セル再構成にトランザクションを渡しても中身はアニメーションしない

親の state 変更で Representable に届く `context.transaction` は `animation=nil` で、`withTransaction` で再構成へ引き渡しても載せるものが無い。タップを `withAnimation` で包んで `DefaultAnimation` を届けても、中身 (SwiftUI 側の描画) はアニメーションしなかった (Simulator でのフレームログ A/B とオーナー目視、2026-09-05)。行の高さの変化自体は UICollectionView の自己サイズ変更として約 0.35 秒かけて動き、transaction の有無に依存しない。`UIHostingConfiguration` の content view は内部の描画レイヤーを外から観測できないため、中身のアニメーションの判定は目視で行う。中身をアニメーションさせるには別の解き方が要る。

### レイアウト切替・入力・命令

- **レイアウトオブジェクトは差し替えない**。list ⇄ grid・列数・スペーシング・向き変更のいずれも、sectionProvider が `configuration.layout` を実行時参照し `invalidateLayout()` で反映する。`setCollectionViewLayout` を使うと全セルがバウンドして描画が乱れる (翻案元の実績。ios/ADR-0003)。
- **セル内の操作要素はタップを奪わない**。`KsHostingCell` の hitTest で操作要素 (UIControl 系) に当たったタッチはセル選択に流さず、feedback も出さない。長押し認識器はハンドラ未宣言時は無効。
- **スクロール命令は apply completion で flush**。データ差し替えと同時に来た命令は未完了の最後の apply が終わってから実行する。

## してはいけないこと

- `KsRowContentPlacement` に「content へ行の高さを提案する」変更を入れない。自己サイズが自己参照になる。
- 推定値の更新を契機に `invalidateLayout()` を呼ばない。推定値は次に走る invalidate で読まれれば足り、追加の invalidate は再計算の連鎖になる。
- 同値配列の更新経路で `id:` / `template:` / 登録集合の変更を反映しようとしない。表示中は不変の利用者契約 (ios/ADR-0006)。
- テンプレートのクロージャの中で UI state を持たせる設計に寄せない。再利用でホスティングを作り直す (ios/ADR-0002)。
- 観測する値が同じ同値配列の更新で、位置依存の表示とタッチ feedback 色の追随まで止めない (上記)。
- 可視セル再構成に `withTransaction` を渡して中身をアニメーションさせようとしない。効果が無いことは確認済み (上記)。

## 性能

Sample「大量件数」(10,000 件、固定高 + 可変行高混在、2 列 grid) で、iPhone 15 実機の hitch time ratio (1 秒のスクロールあたりコマ落ちで失われた時間。小さいほど滑らかで、合格基準は 5 ms/s 未満) は 0.0 ms/s (3 試行)、Simulator のメモリは全項目走査の往復 4〜5 回で定常化。同時生存セルは可視セル数の 3 倍程度 ([項目モデル](../../core/core-model/collection-items.md) の責務境界にある契約は 4 倍未満)。手順と基準は [handbook/ios/performance-verification.md](../../../handbook/ios/performance-verification.md)。基準機 iPhone 11 での計測は未実施。

## 用語

- **識別子だけの snapshot**: diffable の item identifier に安定 ID (`AnyHashable`) のみを載せ、内容を含めない構成。内容変化は snapshot の差分ではなく再構成で扱う。
- **登録準備の前倒し**: snapshot 適用前に使用する全テンプレートキーの `CellRegistration` を生成すること。画面外の未登録キーもこの時点で検知される。

## 関連

- [項目モデルと差分更新](../../core/core-model/collection-items.md)、[レイアウト語彙](../../core/styling/collection-layout.md)、[操作とスクロール制御](../../core/core-model/collection-interaction.md)
- ios/ADR-0001〜0008 (0007: セル content の配置、0008: 観測する値)、core/ADR-0010 (区切り線の既定外観)、handbook/cross/runtime-behavior-verification.md (Simulator での観測点表に「検証: 行の高さ変化」を含む)
- 翻案元: `../KsSettingsView/ios/Sources/KsSettingsViewUI/` (`FullSnapshotContentTargets` / `KsCellRegistry` / `CustomCellRowPlacement` / `SectionBoxLayout`)
