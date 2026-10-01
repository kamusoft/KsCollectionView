# Tasks: drag-reorder

## 0. 先に確かめること

- [x] 0.1 両プラットフォームで、固定の見出しを持つ一覧に最小のドラッグを組み、見出しの下を項目が通るときの重なり順 (持ち上げた項目が手前) と、iOS の自前の見出しの固定 (レイアウトの位置の上書き) と UIKit のドラッグ中の隙間の計算が干渉しないかを確かめる。干渉するなら止めて諮る (→ design の Risks / Open Questions)
- [x] 0.2 iOS: UIKit のドラッグ & ドロップが、10,000 件・内部の塊 (セクション) をまたぐ移動・`contentInsetAdjustmentBehavior = .never` の全画面の一覧で、標準どおりに持ち上げ・隙間・自動スクロールするかを確かめる。自動スクロールがバーの裏の範囲で反応するかも見る (→ design Decision 3 / Risks)

## 1. 公開 API

- [x] 1.1 iOS: `KsReorderMove` / `KsReorderDestination` / `KsReorderAccessibilityActions` と `.reorder(isEnabled:canMove:canDrop:accessibilityActions:onMove:)` を `KsCollectionView+Reorder.swift` と internal の設定型 (`KsCollectionConfiguration` に載せる) で足す。DocC に契約 (置いたときに 1 回・受け入れの真偽値・行き先・グループの値・長押しの知らせを呼ばない・ドラッグ中の配列の保留) と SwiftUI の `onMove` との違いを書く (→ design Decision 1 / Requirement: 並べ替えのスイッチ・置いたときの知らせ)
- [x] 1.2 Android: `KsReorder` / `KsReorderMove` / `KsReorderDestination` (`Before` / `End`) / `KsReorderAccessibilityActions` と、`KsCollectionView` の `reorder` 引数 (`onRefresh` の後ろ) を足す。KDoc に 1.1 と同じ契約を書く (→ 同上)
- [x] 1.3 公開 API のテスト (iOS `KsPublicAPITests`、Android `KsCollectionViewPublicApiTest`) に新しい型と引数の形を足す (→ Requirement: 並べ替えのスイッチ)

## 2. 行き先の求め方 (両プラットフォーム共通の規則)

- [x] 2.1 両プラットフォームに UI から切り離した行き先の計算を置く: 仮の並び (配列の位置・グループの区切り・動かした項目) から知らせ (`before(後ろの項目)` / `end` + グループの値) を求める。元の位置なら知らせない判定、読み上げの 1 つ前 / 1 つ後ろの行き先 (グループの境目を越える) も同じ部品で求める (→ design Decision 2・6 / Requirement: 置いたときの知らせ・グループをまたぐ移動・読み上げの移動操作)
- [x] 2.2 2.1 の単体テスト (両プラットフォーム): Scenario「置いたときに 1 回だけ知らせる」の行き先「D の前」「最後に置いたら末尾」「元の位置に置いたら知らせない」「別のグループの途中へ置く」「見出しの上と下」「見出しの無いグループでも境目で分かれる」「操作で 1 つ後ろへ動かす」「グループの境目を越える操作」 (→ 同上)

## 3. iOS のドラッグ & ドロップ

- [x] 3.1 `KsCollectionViewController` に drag delegate / drop delegate を付ける。スイッチが有効なら `dragInteractionEnabled = true` にして長押しの認識器を無効にし、無効なら元に戻す (`update` のたびに更新)。有効の間は `onItemLongTap` をハンドラに数えず、`onItemTap` が無い項目は強調しない (→ design Decision 3 / Requirement: 並べ替えのスイッチ、collection-interaction のアイテムタップ / ロングタップ)
- [x] 3.2 持ち上げ: `itemsForBeginning` で `canMove` が偽なら持ち上げない。ドラッグの項目にアプリの中だけの目印を持たせ、アプリの外への持ち出しを止める。セッションに持ち上げた一覧の目印を付け、ほかの一覧からのセッションは受けない (→ Requirement: 動かせるかと置けるかの判定・並べ替えは一覧の中だけ)
- [x] 3.3 ドラッグ中: UIKit の行き先 (塊のセクションと番号) を 2.1 の知らせに読み替える補助を `KsGroupChunkTable` 側に足し、`canDrop` が偽なら禁止、真なら `.move` + `insertAtDestinationIndexPath` を返す (→ Requirement: 動かせるかと置けるかの判定・グループをまたぐ移動)
- [x] 3.4 置いたとき: `onMove` を呼び、受け入れたら差分データソースの今の snapshot の中で項目だけを動かして当て (グループの値からは組み直さない)、配列の並びと塊の表の全体 (各塊の件数・セクションの範囲・グループの項目の範囲) を仮の所属で組み直し、見出しの中身もこの表から組み、項目が無くなったグループのセクションと見出しを取り除いて、`coordinator.drop` で置く。受け入れなければ置かずに終える。元の位置・置けない場所では `onMove` を呼ばない (→ design Decision 3 / Requirement: 受け入れと元に戻す)
- [x] 3.5 ドラッグ中の配列の保留・ページングの判定の停止・スクロール命令の溜め置き (Decision 5)、受け入れた後は置いた時点と同じ配列の `update` では当てずに待つこと、ドラッグ中にスイッチ・layout・グループの宣言が変わったときの取りやめ (Decision 7) を `update` と `apply` の手前に組み込む。ドラッグの終わりに控えた配列を当てるとき、端の留め方 (core/ADR-0018・0021) の直前の状態を正しく控える (→ Requirement: ドラッグ中に届いた配列・ドラッグ中のページングとスクロール命令・並べ替えのスイッチ)
- [x] 3.6 読み上げ: 読み上げの焦点が当たる要素 (セルの中の SwiftUI の要素になりうる — design の Risks) で出るように、「前へ移動 / 後ろへ移動」のカスタム操作を付ける (スイッチ有効・文言あり・動かせる・行き先が `canDrop` で真のときだけ)。実行したら `onMove` を通し、受け入れたら項目を動かして焦点を動かした項目に残す (→ design Decision 6 / Requirement: 読み上げの移動操作)
- [x] 3.7 結合テスト (SwiftPM、delegate と読み上げの操作を直接呼ぶ): 並べ替えのスイッチ・置いたときの知らせ・並べ替えは一覧の中だけ・受け入れと元に戻す・グループをまたぐ移動・動かせるかと置けるかの判定・読み上げの移動操作・ドラッグ中に届いた配列・ドラッグ中のページングとスクロール命令の各 Scenario と、collection-interaction の「並べ替えが有効な間の長押し」「並べ替えが有効な間のタップ」「スイッチを無効に戻すと長押しが戻る」 (→ 同上)

## 4. Android の自前のドラッグ

- [x] 4.1 ラッパーに並べ替えの状態 (internal: ドラッグ中の項目・仮の並び・指の位置・置けない場所の上か・控えた配列・受け入れ待ち) を置き、スイッチが有効なら項目の `combinedClickable` の `onLongClick` を外し、`canMove` が真の項目に長押しからのドラッグの検出を付ける。有効の間は `onItemLongTap` をタップのハンドラに数えない (→ design Decision 4 / Requirement: 並べ替えのスイッチ、collection-interaction のアイテムタップ / ロングタップ)
- [x] 4.2 仮の並び: `KsGroupPlan` にドラッグ中の項目の所属の上書きを渡せるようにし、空になった元のグループの見出しを残す。ドラッグ中の項目の中心がほかの項目の範囲に入ったら 2.1 で知らせを求め、`canDrop` が真なら仮の並びの中で動かす (→ Requirement: グループをまたぐ移動・動かせるかと置けるかの判定)
- [x] 4.3 持ち上げと自動スクロール: ドラッグ中の項目を指に付けて (graphicsLayer) ほかの項目と固定の見出しより手前に描き、その項目だけ配置のアニメーションを外す。端の近くで距離に応じた速さでスクロールを続け、スクロール分を補正する (速さと範囲は内部の定数)。仮の並びで先頭の可視項目が入れ替わったら見え方を合わせ直す (→ design Decision 4 / Requirement: 端での自動スクロール)
- [x] 4.4 置いたとき: 置けない場所の上・元の位置なら元に戻して知らせない。それ以外は `onMove` を呼び、受け入れたら項目が無くなったグループを見出しごと取り除いて仮の並びのまま配列を待ち (置いた時点と同じ配列の再コンポジションでは捨てない)、受け入れなければ元の位置へ戻してから控えた最新の配列を当てる (→ Requirement: 置いたときの知らせ・受け入れと元に戻す)
- [x] 4.5 ドラッグ中の配列の保留・ページングの判定の停止 (`snapshotFlow` の判定を止める)・スクロール命令の溜め置きと、スイッチ・layout・グループの宣言が変わったときの取りやめを組み込む。`KsPositionKeeper` の端の留め方と控えた配列の当て方の組み合わせを確かめる (→ design Decision 5・7 / Requirement: ドラッグ中に届いた配列・ドラッグ中のページングとスクロール命令)
- [x] 4.6 読み上げ: 読み上げの焦点が当たる要素で出るように、項目の semantics の `customActions` に「前へ移動 / 後ろへ移動」を付ける (3.6 と同じ条件)。実行したら `onMove` を通す (→ Requirement: 読み上げの移動操作)
- [x] 4.7 結合テスト (Robolectric + compose ui-test、長押しからのドラッグを合成): 3.7 と同じ Scenario の組と「画面の外の位置へ運ぶ」(端での自動スクロール)。加えて、ドラッグ中の項目が見えている範囲の外に出ても持ち上げが切れないこと (design の Risks) (→ 同上)

## 5. Sample「並べ替え」

- [x] 5.1 「ページング」の画面専用のパネルの部品 (面・畳むボタン・丸いボタン・寸法・帯) を Sample の共通部品に切り出し、「ページング」の見た目を変えずに置き換える (両プラットフォーム) (→ design Decision 8)
- [x] 5.2 両プラットフォームのメニューに「並べ替え」を「ページング」の次に足し、画面の振り分けと起動引数での直接起動 (iOS `--screen 並べ替え`、Android の開始ルート) を足す。一覧を画面の下端まで広げる置き方は「ページング」と同じ (Android の `SampleNavHost` の下端のバーの裏まで広げる指定を含む) (→ Requirement: デモ画面「並べ替え」)
- [x] 5.3 データと VM: 10,000 件・100 件ずつのグループ・10 の倍数は動かせない。知らせを受けたらグループの値を行き先に書き換えて入れ、受け入れる。グループがオフの間は行き先の隣の項目のグループの値に合わせる。「置いても受け入れない」なら受け入れず帯を出す (iOS `@Observable @MainActor final class`、Android は Compose の状態を持つ class) (→ Requirement: デモ画面「並べ替え」・並べ替えの実演の操作)
- [x] 5.4 画面: 承認 mock (案 B) どおりに、操作のパネル (セグメント・2×2 のトグルのボタン・説明の一行、畳める)、帯 (「長押し: Item N」「並べ替えを受け入れませんでした」)、「(移動不可)」の表示、読み上げの文言「前へ移動」「後ろへ移動」。パネルは一覧の配置の入力を変えない (→ Requirement: 並べ替えの実演の操作、handbook/cross/sample-debug-controls)
- [x] 5.5 Android の Sample の単体テスト: メニューの一致 (`SampleScreenParityTest`)、データの並び・グループ・動かせない項目、VM の並べ替え (グループあり / なし・受け入れない・グループをまたがせない)、画面の長押しの帯 (→ samples の各 Scenario)
- [x] 5.6 iOS の UI テスト (実際のドラッグの操作): Scenario「項目を並べ替える」「別のグループへ動かす」「動かせない項目」「スイッチを切ると長押しの知らせになる」「スイッチがオンの間は長押しの知らせが出ない」「受け入れないと元に戻る」「グループをまたがせない」「グリッドとグループなしでも並べ替えられる」 (→ 同上)

## 6. 見た目と性能の検証

- [x] 6.1 承認 mock との視覚照合 (ksn-ui) を両プラットフォームで行い、verification/ に残す (6 つの状態。② ドラッグ中は持ち上げ・隙間の見え方が各 OS の標準に従っていることを見る) (→ ui/brief.md)
- [x] 6.2 「並べ替え」画面でスイッチをオンにした状態の、両プラットフォームの基準機の体感ゲート (handbook/cross/scroll-performance-gate.md、iOS / Android の performance-verification) を 1 回行い、evidence/ に残す (→ design Decision 9)
- [x] 6.3 基準機でのオーナーの目視: 持ち上げ・端での自動スクロールで長い距離を運ぶ・受け入れないときの戻り・グループをまたぐ移動・固定の見出しとの重なり・グループの最後の 1 件を持ち出したときの見出し・「前へ / 後ろへ移動」の読み上げ (iOS は標準のドラッグの操作と並ぶ見え方)。Android の持ち上げの見た目を iOS と並べて確かめる (→ design Decision 9 / Risks、ui/brief.md)
- [x] 6.4 iOS: 置いた直後の snapshot から確定の配列へ移るとき (内部の塊の件数が変わる差し替え) に見た目が変わらないことを、6.3 の中で目視で確かめる (→ design の Risks)
