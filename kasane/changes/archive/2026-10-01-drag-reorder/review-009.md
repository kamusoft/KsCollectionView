# レビュー結果: drag-reorder (009 回目)

**日付**: 2026-10-01
**判定**: CHANGES_REQUESTED

## サマリー

iOS の並べ替えの組み替えだけを見た。組み替えは、`performDropWith` で置く形から、差分データソースの並べ替えハンドラ (`reorderingHandlers`) を使う reorder-capable な形への変更で、`reorderingCadence = .slow` を使う。spec の collection-reorder・collection-interaction の Requirement は、組み替えた後もコードとテストと Simulator の観測で満たしている。確かめた範囲は、知らせは置いたときに 1 回だけ・元の位置では知らせない・受け入れないと戻る・グループをまたぐ移動・置けない場所・ドラッグ中の配列の保留・長押しとタップ。一方、組み替えの目的の 1 つだった「置いた後の収まりが約 0.3 秒になる」(deviation と evidence/ios-6.3-rework.md の 2 節) は、[L-001] の手順で測り直したが両 OS とも再現しなかった。受け入れた項目は影を付けたまま置いた位置に約 0.92〜0.96 秒残り、そこで一度に消える。これを Major 1 件とした。ほかに Minor 3 件 (状態の後始末・食い違いの窓・テストの無い経路) と Suggestion 2 件がある。

## 照合した規約

- ソースコメント規約 (always): `scripts/comment-policy-lint.py --advisory` を対象の 8 ファイルにかけた。禁止 0 件・要確認 1 件で、要確認は `ios/Sources/KsCollectionView/KsCollectionViewController.swift:2261` のページングのコメント (今回の範囲外の前からある行)。組み替えで足されたコメントは本文で読んだ。単独で読めて、実装と合っている。ただし Suggestion 6 の置き場所のずれが 1 か所ある
- テスト実行規約 (テストの実行・結果の報告): コンテキストパッケージの指示で絞り込んで実行した (件数は「テストと実行時の確認」)
- 実行時挙動の検証規約 (実行時挙動が絡む不具合修正の完了判定): 6.3 の目視の指摘に対する修正なので、「修正後に同じ手順で解消を確かめる」を証跡の数値の再現として当てた (Major 1)
- 証跡の規約 (ksn-core references/evidence.md): 実行時の静止画と、sanitize を通したプローブの抜粋を `evidence/review-009-*` に置いた

ロードしたスキル: ksn-review、swift-ui-impl-skill (iOS。対象は UIKit のため、Concurrency・命名・一貫性の観点だけを当てた)。lessons: kasane/lessons/code-review.md の [L-001]・[L-002] と、inbox の observe-drag-feel-while-autoscrolling.md。

## 確認した観点

- 仕様充足 (collection-reorder の全 Requirement と collection-interaction の「アイテムタップ / ロングタップ」)
  - 置いたときに 1 回だけ知らせる: 受け入れの経路 `reorderDidReorder` (`ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:198`) と、置く処理の経路 `acceptDrop` (`:283`) のどちらも、`onMove` を 1 回だけ呼ぶ。Simulator では、受け入れる・受け入れない・またぐ・素早く離す、のすべてで `onMove` は 1 回だった (evidence/review-009-probe.log)
  - 元の位置では知らせない: `placement != planner.originalPlacement(of:)` で除いている (`:221`・`:296`)。テスト `test元の位置に置くと知らせない` も確かめた
  - 受け入れたら配列が届くまで置いた並びのまま・同じ配列の描き直しでは戻らない: `reorderAwaitedItems` の扱いは組み替えの前と同じ。ドラッグの状態が続いている間に届いた構成は控えに回り、`endReorderDrag` で当たる。Sample は `onMove` の中で配列を同期で書き換えるので、この経路を通る。Simulator では並び 1,3,4,5,2,6 のまま崩れなかった
  - 受け入れないと戻る: `revertReorderedSnapshot` は、ドロップのセッションが終わってから (`afterDropSession`) 動かして戻す。26.5 で「収まる 約 0.3 秒 → 止まる 約 0.63 秒 → 戻る 約 0.3 秒」を観測した。離してから戻り終わるまで約 1.3 秒で、evidence の 3 節の値と deviation の合意の形に一致する (evidence/review-009-reject-26.png)
  - グループをまたぐ移動・グループの値・空のグループ: 下へまたいだとき、見せていた隙間と確定した位置がずれる現象 (shown `[1, 1]`・final `[1, 2]`) を 18.6 で再現した。見せていた位置で「Item 102 の前・グループ 2」と知らせ、並びは 99, 101, 98, 102 に揃った。揃えるときに見た目は崩れず、見出しの件数は endReorderDrag の後に 101 件へ変わった (evidence/review-009-cross-down-18.png)。空になったグループを消す処理は組み替えの前と同じ `applyAcceptedReorder` の中にある
  - 置けない場所には入らない: 26.5 で「グループをまたがせない」をオンにし、Item 98 を Item 102 の上へ運んで 1.5 秒止めた。置けない提案は 89 回返り、置く処理も並べ替えも起きず、並びは変わらなかった
  - ドラッグ中の配列の保留・ページングとスクロール命令: `isReorderDragging` が、置いた結果を当て終えるまで (`isResolving`) 真のまま残る。控えた構成・溜めたスクロール命令・次ページ要求の判定は、その後に行われる。テスト (`test受け入れなければ元の位置に戻してから最新の配列を当てる`、`testドラッグ中の項目が消えた…`、`testドラッグ中は次のページを頼まず…`、`testドラッグ中のスクロール命令は…`) は、ドロップのセッションの終わりを待つ形に合っている
  - 取りやめ: 取りやめた後の提案は `.move` と `.unspecified` の組 (`:143`)。`reorderDidReorder` も取りやめを見て元へ戻す (`:209`)。テスト 5 件が成功した
  - 別の一覧のセッション・アプリの外: `isOwnReorderSession` と `dragSessionIsRestrictedToDraggingApplication` は組み替えの前と同じ
  - 読み上げの操作: `immediate` の経路のまま変わっていない。テストが成功した
  - 長押しを呼ばない / タップは呼ぶ: `installsStandardGestureForInteractiveMovement = false` (`ios/Sources/KsCollectionView/KsCollectionViewController.swift:522`) で標準の長押しを外している。`KsReorderEngineTests` の 4 件と、`KsCollectionEngineTests` の長押し・タップの 3 件が両 OS で成功した
- テストの期待値の書き換え: 対象のテストは未コミットの新規ファイルのため、前の版との diff は取れない。今の期待値を spec と突き合わせた。受け入れない場合の中間状態 (`["B", "C", "A"]`) を確かめているのは、deviation に合意された「いったん置いた位置に収まってから戻る」形そのもので、最後の状態は spec どおり元の並びを求めている。spec を緩めた書き換えは見つからなかった。UI テスト `test別のグループへ動かす` の期待値 `[101, 1, 102]` は、deviation の (3) (slow では指を止めた項目の前に隙間が空く) と合っている
- 状態の後始末 (`isResolving` / `isSessionEnded` / `hasDropSessionEnded` / `workAfterDropSession`): 受け入れる・受け入れない・揃える・取りやめるの各経路で、`finishReorderResolution` → `endReorderDrag` まで閉じることを、コードとプローブで確かめた。当て終える前に構成が変わった場合は控えに回り、当て終えた後に当たる。一覧が消える場合、controller は弱参照で捕まえているため、閉包は何もせずに終わる。漏れの候補は Minor 2・3
- 足場の書き換え・tasks の虚偽チェック: 6.3・6.4 は未チェックのまま。足場は書き換えられていない
- 設計品質・コメント・性能・Concurrency: `@MainActor` の delegate と `DispatchQueue.main.async` の使い分けに問題は見つからなかった。オーバーエンジニアリングも見つからなかった

## テストと実行時の確認

- 単体・結合テスト (リポジトリの作業ツリーのまま。シミュレータは下の 2 台):
  - iOS 18.6: `KsReorderEngineTests` 52 件と `KsCollectionEngineTests` の長押し・タップの 3 件 (`test長押し成立後の別タッチによる通常タップを抑止しない`・`testセル内の操作要素へのタッチではitemTapとfeedbackを発火しない`・`testロングタップ未宣言のときは長押し認識器を無効にする`)。計 55 件、失敗 0 件
  - iOS 26.5: 同じ 55 件、失敗 0 件
  - 補足: パッケージにあった「KsCollectionViewInteraction 系」という名前のテストのクラスは無い。長押し・タップの既存の結合テストは `KsCollectionEngineTests` の中にあるため、それを流した
- 実行時の確認 ([L-002]): スクラッチの複製 (本体に NSLog を足しただけのもの。リポジトリは触っていない) の Sample「並べ替え」を、XCTest の合成タッチで操作した。`simctl io recordVideo` の録画から 60fps のコマを取り出し、前のコマとの差分で動きの区間を求めた。Release でビルドした
  - Simulator: `ksn-drag-reorder-review9-ios18` (iPhone 16 / iOS 18.6)・`ksn-drag-reorder-review9-ios26` (iPhone 17 / iOS 26.5)
  - 見た過程: 受け入れる (両 OS)・受け入れない (26.5)・下へまたぐ (18.6)・置けない場所 (26.5)・下端で 5 秒自動スクロールさせてから離す (18.6)・止めずに素早く離す (26.5)
  - 期待値 (先に書き出したもの): 受け入れたときは、UIKit 標準の並べ替えと同じく、影が約 0.25〜0.35 秒で薄れて収まる (evidence/ios-6.3-fix-drop-uikit-standard-18.png)。受け入れないときは、deviation の合意の形 (収まる → 止まる → 戻る、合計約 1.3 秒)。自動スクロールの間は、隙間は指を止めた位置のまま動かない (evidence/ios-6.3-rework.md の 1 節の UIKit 標準・slow)

## 指摘事項

### [🟠 Major] 受け入れた後の収まりが証跡の値 (約 0.3 秒) で再現しない。影が約 0.93 秒残り、一度に消える
**該当箇所**: `evidence/ios-6.3-rework.md:24`〜`:31` (2 節)、`deviation.md:10` (「置いた後の収まりは約 0.3 秒になる」)、`ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:198`〜`:244`
**問題点**: 2 節と同じ手順で測った (Item 2 を Item 5 の上へ運び、1.2 秒止めて離す。Release)。結果は次のとおり。
- iOS 26.5: 離したコマ (30.200 秒) の後、動きは約 0.4 秒で止まる。ところが、持ち上げたときの影を付けた項目は置いた位置に残り、31.117 秒で一度に消える (離してから約 0.92 秒)。この時点はプローブの `dropSessionDidEnd` (`didReorder` の 1.006 秒後) と一致する (evidence/review-009-accept-shadow-26.png)
- iOS 18.6: 同じく、影は 29.517 秒まで残り、29.55 秒で消える (離してから約 0.95 秒。`didReorder` から `dropSessionDidEnd` まで 0.964 秒) (evidence/review-009-accept-shadow-18.png)

この見え方は、2 節の「直す前」の欄 (「影を付けたまま止まり、約 0.9 秒後に一度に消える」) と同じである。「直した後 0.27〜0.36 秒 (影が薄れて収まる)」は再現しない。UIKit 標準の並べ替え (evidence/ios-6.3-fix-drop-uikit-standard-18.png) では影が約 0.3 秒で薄れており、組み替えた後の本体はそれと違う。原因を絞る試行として、受け入れた並びの snapshot の適用 (`applyReorderSnapshot` の `.nextRunLoop`) を飛ばすビルドも測ったが、同じく約 0.92 秒残った (evidence/review-009-accept-skip-apply-trial-26.png)。したがって、snapshot の当て直しは原因ではない。2 節の測り方 (「動いている区間」をコマの差分で求める) では、止まったまま残る影は差分に出ない。約 0.9 秒後の一度だけの変化を見落とした可能性がある。オーナーの指摘 2 (「置いた後の収まりが遅い (約 0.9 秒)」) は組み替えの理由の 1 つであり、それを支える数値が再現しないまま 6.3 の見直しへ進むことになる。
**推奨修正**: 影が消える時点までを含めて、2 節を測り直す (Sample と、同じアプリの UIKit 標準の並べ替えを、同じ手順で並べて測る)。標準は約 0.3 秒で本体だけが残るなら、残る原因 (標準の画面との差分。例: セルの中身・ドロップの delegate の実装の有無・プレビューの扱い) を A/B で特定して直す。標準も同じく残るなら、2 節と deviation の「約 0.3 秒になる」を実測に合わせて書き直す。そのうえで、組み替えで指摘 2 が解けないことをオーナーに伝える。

### [🟡 Minor] 前のドロップの `dropSessionDidEnd` が、次のドラッグの状態に入りうる
**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:272`〜`:279`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:1685`〜`:1692`、`ios/Sources/KsCollectionView/KsReorderDrag.swift:23`
**問題点**: 受け入れた並べ替え (揃えが要らない場合) では、`finishReorderResolution` → `endReorderDrag` が離してから約 0.07 秒で走り、`reorderDrag` は nil になる。一方、そのドロップのセッションが終わるのは約 0.93 秒後である (プローブの 26-accept・18-accept)。その間に次の項目を持ち上げると、`reorderItemsForBeginning` は `!isReorderDragging` だけを見るため受け付け、新しい `reorderDrag` ができる。そこへ前のセッションの `reorderDropSessionDidEnd` が届くと、どのセッションの終わりかを確かめずに、新しいドラッグの `hasDropSessionEnded = true` を立てる (`reorderDragContext` は一覧に 1 つで、セッションを区別しない)。すると、新しいドラッグを受け入れなかった場合の戻しが次の周回で走り、実装の証跡が避けたかった崩れ (項目が置いた位置に止まったまま、絵が消えた瞬間に元の位置に現れる) が起こりうる。UIKit が前のドロップの間に次の持ち上げを許すかは、Simulator では確かめていない (合成タッチでは約 0.5 秒以内に次の長押しを成立させにくい)。
**推奨修正**: `dropSessionDidEnd` を、そのドラッグのセッションに対応するものだけで扱う。たとえば、ドラッグごとに `localContext` へ別の目印を入れ、`KsReorderDrag` に控えて照合する。または、前のドロップのセッションが終わるまで次の持ち上げを受け付けない。どちらにしても、前のセッションの終わりが後から届く順番のテストを足す。

### [🟡 Minor] 下へまたいで受け入れた後、揃えるまでの約 0.9 秒は、タップが見えている項目と別の項目を渡しうる
**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:234`〜`:243` (`snapshotTiming: .afterDropSession`)、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:2491`〜`:2497` (`didSelectItemAt`)
**問題点**: 確定した位置と見せていた隙間がずれた場合 (下へまたいだとき。18.6 で再現)、差分データソースの並びは、ドロップのセッションが終わるまで UIKit が確定した並びのまま残る (101, 102, 98)。見えているセル (101, 98, 102) とは食い違っている。その間、`reorderDrag` は解決中のまま残るが、タップは止めていない。`didSelectItemAt` は `dataSource.itemIdentifier(for:)` で項目を引くため、見えている Item 98 の行をタップすると `onItemTap` に Item 102 が渡る。`onItemTap` は並べ替えのスイッチによらず呼ぶ契約である (collection-interaction)。窓は約 0.9 秒と短く、条件も狭いが、渡る項目は誤りになる。Sample「並べ替え」には `onItemTap` が無いため、実行時には確かめていない (コードの読みによる)。
**推奨修正**: 揃えるまでの間はタップの知らせを見送る (`isResolving` の間は `didSelectItemAt` で何もしない等)。または、見えている並び (`appliedIdentifiers` と塊の表) から引く。どちらかにして、ずれを作るテスト (`dropWithMismatchedFinalPosition`) の中でタップを渡す確認を足す。

### [🟡 Minor] 止めずに素早く離したときの「置く処理で受け入れる」経路にテストが無い
**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController+Reorder.swift:168`〜`:182`・`:283`〜`:308`、`ios/Tests/KsCollectionViewTests/KsReorderTestSupport.swift:244`〜`:258`
**問題点**: コメントでは、「元の位置以外で置く処理が呼ばれる」場合は備えとして扱われている。ところが 26.5 では、持ち上げて指を止めずに Item 6 の上で離すと、隙間は一度も動かないまま、UIKit は置く処理 (`performDrop dest=[0, 4]`) を呼んだ。本体は `acceptDrop` で `onMove` を 1 回呼び、`applyAcceptedReorder` (immediate) と `coordinator.drop(toItemAt:)` で「Item 6 の前」に置いた。見た目の崩れは無かった (evidence/review-009-quick-release-26.png)。つまりこの経路は、ふだんの操作で通る経路である。一方、テストの偽物の `KsReorderDriver.drop` は、最後の提案が隙間を空ける提案で、置く位置が元の位置と違えば、必ず並べ替え (`reorderDidReorder`) として扱う。この経路 (置く処理で受け入れる・受け入れない・置けない行き先) を通るテストは無い (`droppedIndexPaths` が空でないことを確かめるテストが無い)。
**推奨修正**: 偽物に「隙間が動く前に離す」操作を足す。置く処理の経路で、受け入れたとき (知らせ 1 回・置いた並び・`droppedIndexPaths`)、受け入れないとき (元の位置へ戻す・並び不変)、判定が偽のとき (知らせない) のテストを足す。コメントも「隙間が動く前に離したとき」と実際の条件で書く。

### [🔵 Suggestion] 自動スクロールの間に指を止めずに離すと、項目が画面の外の位置に置かれる。6.3 の見直しの観測点に加える
**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:516`〜`:518` (`reorderingCadence = .slow`)、`owner-visual-checkpoints.md`
**問題点**: 18.6 で、Item 3 を下端から 12pt に運んで 5 秒止め、そのまま離した。自動スクロールの間は隙間が動かない (運ぶ途中で 3 回動いただけ)。このため、項目は送り始めの前の隙間 (Item 19 の前) に置かれ、画面 (Item 82〜97 が見えている) の外へ消えた (evidence/review-009-autoscroll-release-18.png)。知らせは 1 回で、spec の「指を上へ戻すと止まり、スクロールした先で置ける」には反しない。evidence の 1 節の観測から、UIKit 標準 (slow) も同じ振る舞いになる見込みなので、不具合とはしない。ただ、inbox の observe-drag-feel-while-autoscrolling.md のとおり、長く運んだときの手触りとしてオーナーの目に入れておくべき見え方である。
**推奨修正**: 6.3 の見直しの観測点に「自動スクロールの間に指を止めずに離したときの置かれ方 (設定アプリ等の標準の並べ替えと比べる)」を加える。

### [🔵 Suggestion] テストのコメントが別のテストの前に置かれている
**該当箇所**: `ios/Tests/KsCollectionViewTests/KsReorderEngineTests.swift:604`〜`:606`
**問題点**: 「iOS では見出しとグループの間の間隔の上 (提案が nil) では…」の 3 行は `test見出しの上では直前の隙間の位置で知らせる` (`:628`) の説明である。しかし、組み替えで足された `test確定した位置が見せていた隙間とずれても…` (`:609`) の前に残っている。
**推奨修正**: 3 行を `:628` のテストの前へ移す。

## アクションプラン

1. (Major) 受け入れた後の収まりを、影が消えるまで含めて UIKit 標準の画面と並べて測り直す。本体だけが残るなら原因を A/B で特定して直し、標準も同じなら証跡と deviation を実測に合わせてオーナーに伝える
2. (Minor) 前のドロップの `dropSessionDidEnd` を、次のドラッグと区別する (または前のドロップの間の持ち上げを受けない)。順番のテストを足す
3. (Minor) 揃えるまでの窓のタップの扱いを決めて直し、テストを足す
4. (Minor) 置く処理で受け入れる経路のテストと偽物の操作を足し、コメントを実際の条件に直す
5. (Suggestion) 6.3 の見直しの観測点に「自動スクロール中に離したときの置かれ方」を加える。テストのコメントの位置を直す

## 実行時の確認の記録

- 使った Simulator (レビュー専用に作成。確認の後に停止済み。削除は指揮側): `ksn-drag-reorder-review9-ios18` (<uuid>)、`ksn-drag-reorder-review9-ios26` (<uuid>)。UDID は報告に書いた
- 証跡: evidence/review-009-accept-shadow-26.png、evidence/review-009-accept-shadow-18.png、evidence/review-009-accept-skip-apply-trial-26.png、evidence/review-009-reject-26.png、evidence/review-009-cross-down-18.png、evidence/review-009-autoscroll-release-18.png、evidence/review-009-quick-release-26.png、evidence/review-009-probe.log (各コマの上の黄色い帯の数字は録画の中の秒)
- 録画とスクラッチの複製 (NSLog を足した本体と Sample、確認用の UI テスト) は手元のスクラッチに置き、リポジトリには入れていない
