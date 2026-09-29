# 両プラットフォームの並べ替えの実装手段 (調査 2026-09-29)

ksn-scout による読み取り専用の調査の要約。論点 1・2・3・5・6 の材料。「確認済み」はコードか一次資料で確かめたこと、「推測」「経験則」は未検証。

## iOS

### 現行エンジンで競合しうる箇所 (確認済み)

| 箇所 | 現状 | 並べ替えとの関係 |
|---|---|---|
| 長押し (`onItemLongTap`) | collectionView 自体に `UILongPressGestureRecognizer` を 1 つ。`cancelsTouchesInView = true`、ハンドラが無いときは無効 (`ios/Sources/KsCollectionView/KsCollectionViewController.swift:452-459`、`:1896-1922`) | drag の持ち上げも長押し (約 0.5 秒) なので同時に成立しうる。優先順の調停が要る (推測: 長押しが先に成立すると drag のタッチが取り消される) |
| タップとフィードバック | 選択・強調の delegate (`KsCollectionViewController.swift:2027-2069`)、操作部品の判定は `KsHostingCell.swift:148-195` | — |
| 内部の塊 | `KsSectionID` (グループの値・何回目か・塊の番号)、`KsGroupChunkTable.make`。配列を丸ごと受け取る `apply` が毎回全体を組み直す (`KsCollectionViewController.swift:770-932`) | 別の塊・別のグループへ動かしても、配列を渡し直せば塊の境目は組み直される。部分的に動かす経路は無い |
| グループの値 | `KsGrouping.value: (Item) -> AnyHashable` で項目から導く (`KsGrouping.swift:4-14`) | 別のグループへの移動は、利用者がモデルの値を書き換えない限り表せない |
| 固定の見出し | 標準の pinToVisibleBounds ではなく `KsCompositionalLayout` が属性を上書き (`KsCompositionalLayout.swift:3-48`、`:98-136`) | ドラッグ中のプレースホルダの属性問い合わせと干渉しないかは実機で要確認 (推測) |

### UIKit / SwiftUI の事実

- diffable の `reorderingHandlers` は drag / drop の delegate を付けないと動かない (確認済み: https://developer.apple.com/forums/thread/661495)
- 自前の compositional レイアウト (list でないもの) では canReorder / didReorder が呼ばれない報告と FB9753149 がある。2021 年時点で未解決、その後は不明 (確認済み: https://developer.apple.com/forums/thread/693913)
- drag / drop の delegate (`.move` + `.insertAtDestinationIndexPath`) なら仮の並びは UIKit のプレースホルダが持ち、`performDropWith` で 1 回だけ知らせられる。セクション (塊) をまたぐ移動も可能 (経験則)
- 端での自動スクロールは drag / drop の経路なら標準で付く。`beginInteractiveMovementForItem` の経路には無く自前になる (経験則)
- iPhone では `dragInteractionEnabled` の既定が false (UIKit の既知の仕様)
- VoiceOver: drag を付けるとローターに「ドラッグ」「ここにドロップ」が出る。調整は `accessibilityDragSourceDescriptors` / `accessibilityDropPointDescriptors`、代替は「上へ / 下へ移動」の `UIAccessibilityCustomAction` (経験則)
### iOS 27 の SwiftUI の並べ替え (確認済み)

iOS 27 (WWDC26) の SwiftUI に `.reorderable()` (ForEach に付ける) と `.reorderContainer(for:)` (親に付ける) が入った。List 以外の LazyVGrid などでも使える。閉包はドロップの後に 1 回、`ReorderDifference` (動かした ID 群と、行き先 = `.before(id)` / `.end` とコレクションの ID) で呼ばれ、コレクションの ID を使えばセクションをまたいで動かせる。空のコレクションには入れられない。

iOS 26 には無く、UIKit との橋渡しの記述も見つからないため、UICollectionView ベースの自前エンジンからは使えないとみられる (推測)。最低 iOS 16 の本ライブラリでは対象外。出典: https://nilcoalescing.com/blog/NewSwiftUIAPIsForReorderingAndDragAndDropOniOS27/ 、https://alexanderlogan.co.uk/blog/wwdc26/01-reordering

## Android

### 現行ラッパー (確認済み)

| 箇所 | 現状 |
|---|---|
| 長押し・タップ | 項目ごとに `Modifier.combinedClickable(onLongClick, onClick)`、ハンドラがあるときだけ (`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:627-640`) |
| 固定の見出し | LazyVerticalGrid の `stickyHeader(key, contentType)` + `ksPinnedHeaderSafeArea` (同 `:550-567`) |
| 項目 | グループごとに `items(count, key, span, contentType)`、key は安定 ID (同 `:585-589`) |
| `animateItem` | `ksAnimateItem`。高さの補間中は配置のアニメーションを null (同 `:916-917`) |
| 依存の版 | compose-bom 2026.06.01 = 1.11.4、compileSdk 36 (`android/gradle/libs.versions.toml:11`、`:27`、`:39`) |

### `sh.calvin.reorderable` (確認済み。本ライブラリとの結合は未確認)

- 最新 3.1.0 (Maven Central 最終更新 2026-04-20)、Apache-2.0、保守継続中 (2.4 → 3.1)
- Android の成果物の依存は Compose runtime / animation / foundation 1.7.0 と kotlin-stdlib 1.9.0 だけ。下限が低く BOM 1.11 系に吸収される見込み (1.11 とのバイナリ互換は未検証)
- LazyVerticalGrid / 横向きグリッド / Staggered に対応。3.0.0 でグリッドのスクロール時の移動の既定が `ScrollMoveMode.SWAP`
- 動きの模型: ドラッグ中に `onMove` が何度も呼ばれ、返る前にリストを更新する前提 (更新が遅れるとちらつく)。インデックスは Lazy 全体の位置で見出しの分ずれる。key 必須。`onDragStarted` / `onDragStopped` あり
- 端での自動スクロールあり (`scrollThresholdPadding`)。先頭の可視項目のドラッグは 2.4.0 で修正済み
- TalkBack は自動では付かず、`customActions` で上下左右への移動を自前で出す例が README にある
- stickyHeader との相性の issue は見つからず (未確認)。「高さの補間中は配置のアニメーションを null」と組み合わせると押し出される項目が動かない可能性 (推測)
- 出典: https://github.com/Calvin-LL/Reorderable 、https://repo1.maven.org/maven2/sh/calvin/reorderable/reorderable-android/

### 公式 API と自前実装

- compose-foundation のリリースノート (1.13.0-alpha03 まで) に Lazy 系の並べ替え API は無い。要望 https://issuetracker.google.com/issues/181282427 の現状は未確認
自前実装の難所 (経験則・一部推測):

| 難所 | 回避策 |
|---|---|
| 先頭の可視項目を動かすとスクロール位置が飛ぶ (LazyGridState が先頭の key に追従する) | 移動の直後に `requestScrollToItem` / `scrollToItem` で元の位置に戻す (Reorderable も同趣旨) |
| 端での自動スクロール | 端からの距離で速度を決め `scrollBy` を毎フレームのループで回し、スクロール分だけドラッグ中の項目の位置を補正する |
| ドラッグ中の項目の持ち上げ | `zIndex` + `graphicsLayer { translationY }`、その項目だけ animateItem の配置を外す。固定の見出しより手前に描けるかは要確認 |
| グループの境目をまたぐ移動 | ドラッグ中に見出しの出入りが起きる (推測) |

## 「置いたときに 1 回だけ知らせる」形の成立

| 手段 | 成立 |
|---|---|
| iOS drag / drop の delegate | 素直に成立 (`performDropWith` で 1 回)。塊をまたぐ見え方と見出し固定との干渉は実機で要確認 |
| iOS `reorderingHandlers` | 自前のレイアウトで動かない報告があり、頼らない方が安全 |
| iOS `beginInteractiveMovementForItem` | 成立するが自動スクロールは自前 |
| Android `sh.calvin.reorderable` | ラッパー内部に仮のリストを持ち、`onMove` でそれを書き換え `onDragStopped` で 1 回知らせる包み方で成立。見出しの分のインデックスの読み替えが要る |
| Android 自前実装 | 最初から仮のリストを持つ設計で自然に成立するが、上の難所を全部背負う |

両プラットフォーム共通 (推測): グループをまたぐ移動は、グループの値が項目から導かれる以上、利用者がモデルを書き換えるまで確定しない (論点 2)。

## 確認できなかったこと

- 固定の見出しと drag の実機での組み合わせ (両プラットフォーム)
- `sh.calvin.reorderable` と Compose 1.11 のバイナリ互換、stickyHeader との実際の相性
- VoiceOver の標準の操作の詳細
- 要望 181282427 の現状
