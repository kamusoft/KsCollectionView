---
id: 0011
title: iOS の並べ替えは UIKit 標準の並べ替えの仕組みで作り、隙間・持ち上げ・置く動きは UIKit に任せる
status: accepted
date: 2026-10-01
---

## Context

iOS のエンジンは UICollectionView + 差分データソース + 自前の compositional レイアウトで、利用者のグループの中を内部の塊 (差分データソースのセクション) に分け (ios/ADR-0003・ios/ADR-0009・ios/ADR-0010)、固定の見出しは標準の固定ではなくレイアウトが位置を上書きして作っている。並べ替えの契約は core/ADR-0026〜0034 で決めた: 仮の並びはライブラリが持って置いたときに 1 回知らせ、受け入れなければ戻し、行き先は項目で表し、置けるかの判定を持ち、並べ替えのスイッチが有効の間は長押しで持ち上げ、読み上げの移動操作を出し、ドラッグ中に届いた配列は保留する。

UIKit で並べ替えを作る手段は 3 つある。差分データソースの並べ替えハンドラ (`reorderingHandlers`) を持たせると、一覧が並べ替えのできる置き先になり、UIKit が自分で並びを動かして確定する。ドラッグ & ドロップの delegate だけを付け、置く処理 (`performDropWith`) でエンジンが置く形は、置く前に受け入れを確かめられる。対話的な移動 (`beginInteractiveMovementForItem`) は、長押しを自分で駆動する。

実装と基準機の目視で確かめたこと (iOS 18.6・26.5):

- 隙間が動く速さの設定 (`reorderingCadence`) は、並べ替えのできる置き先の上でだけ効く。置く処理でエンジンが置く形では効かず、端での自動スクロール中に 1 行ごとに隙間が動き、置いた後は持ち上げた絵が約 0.9 秒止まってから収まる
- 並べ替えハンドラは、自前の compositional レイアウトと内部の塊でも呼ばれる (呼ばれないという 2021 年の報告は再現しなかった)
- ドラッグ中の隙間の位置は UIKit が決め、差し替える公開の口 (delegate の `targetIndexPathForMove…`、レイアウトの `targetIndexPath(forInteractivelyMovingItem:)`) はドラッグ & ドロップの間は呼ばれない
- 一覧を画面の上端のバーの裏まで広げた置き方 (core/ADR-0017) では、UIKit の上端の自動スクロールが反応する帯がバーの裏に入り、指を置けない
- 対話的な移動は、持ち上げの見た目 (影・拡大) が付かない

iOS 27 の SwiftUI に標準の並べ替えが入ったが、最低 iOS 16 では使えず、UICollectionView ベースのエンジンからも使えないとみられる。

前提: 差分データソースの並べ替えハンドラが、自前の compositional レイアウトと内部の塊 (複数セクション) で呼ばれる (iOS 18.6・26.5 で確認。iOS 16・17 は未確認)。

## Decision

iOS の並べ替えは、差分データソースの並べ替えハンドラで一覧を並べ替えのできる置き先にし、UIKit 標準の並べ替えとして作る。隙間の位置・持ち上げの見た目・置く動き・下端の自動スクロールは UIKit に任せ、隙間が動く速さは遅い設定 (指を止めてから動く) にする。ドラッグ & ドロップの delegate は、持ち上げてよい項目・置けない場所・ほかの一覧やアプリの外との受け渡しの制限に使う。エンジンは、UIKit が見せた隙間を項目の行き先 (core/ADR-0028) に読み替え、UIKit が並びを確定した後に利用者へ知らせ、受け入れなければ元の並びへ戻す。

この決定に含むもの: 全画面に広げた一覧では、上端の自動スクロールだけをエンジンが足す (UIKit の帯がバーの裏に入るため)。

この決定に含まないもの: 境目 (見出し・グループの間) での置き先を指の位置で決めること。隙間の位置は UIKit の動きに従う。

## Alternatives Considered

- **ドラッグ & ドロップの delegate だけで作り、置く処理でエンジンが置く**: 却下。受け入れを確かめてから置けるが、隙間が動く速さの設定が効かず、自動スクロールしながらのドラッグで隙間が動き続け、置いた後の収まりも遅い。基準機の目視で受け入れられなかった。
- **対話的な移動を自前の長押しで駆動する**: 却下。隙間の位置を差し替えられるが、持ち上げの見た目が付かず、端での自動スクロールも自前になる。
- **ドラッグ中の隙間をエンジンが自前で作る**: 却下。境目の置き先を指の位置で決められるが、UIKit 標準の隙間の動きを失い、指の位置から行き先を求める処理と仮の並びの組み直しをエンジンが持つことになる。
- **全画面の一覧で、安全領域の分を contentInset に持たせて UIKit の帯をバーの下へ移す**: 却下。上端も UIKit 標準の自動スクロールになるが、固定の見出しの位置の計算・Pull to Refresh・全画面の一覧の公開の振る舞い (core/ADR-0017・core/ADR-0025) に及ぶ。
- **iOS 27 の SwiftUI 標準の並べ替えを使う**: 却下。最低 iOS 16 では使えず、UICollectionView ベースのエンジンからも使えないとみられる。

## Consequences

- 正: 隙間の動き・持ち上げの見た目・置く動き・下端の自動スクロールが、UIKit 標準の並べ替えと同じ手触りになる。
- 正: 内部の塊をまたぐ移動を標準の仕組みで扱え、ドラッグ中の置けない場所を標準の口で返せる。
- 負: 置き先の規則が UIKit の動きに従うため、指の位置で決める Android とそろわない。
- 負: UIKit が並びを確定した後で利用者に受け入れを聞くため、受け入れないときは、いったん置いた位置に収まってから元の位置へ戻る。
- 負: 隙間の決め方と確定する位置は UIKit の公開の契約に無く、OS の版で変わりうる。置けるかの判定のために、隙間の位置をエンジンが追う層が要る。
- 負: 上端の自動スクロールだけが自前になり、反応する帯と速さを UIKit に合わせ続ける必要がある。

## Revisit When

- 前提 (Context) が崩れたとき。最低対応 OS を iOS 27 以上に上げて SwiftUI 標準の並べ替えを使える見込みが立ったときは、置き換えを検討する

出典: kasane/changes/archive/2026-10-01-drag-reorder/deviation.md (iOS の組み替えの項・上端の自動スクロールの項・境目の項) / kasane/changes/archive/2026-10-01-drag-reorder/evidence/ios-6.3-fix-investigation.md / kasane/changes/archive/2026-10-01-drag-reorder/evidence/ios-6.3-rework.md / kasane/changes/archive/2026-10-01-drag-reorder/evidence/ios-precheck-uikit-drag-and-drop.md / kasane/changes/archive/2026-10-01-drag-reorder/design.md (Decision 3) / kasane/roadmaps/v1-foundation/phases/phase-6-drag-reorder/history.md (2026-09-29: iOS の実装方式) / kasane/roadmaps/v1-foundation/phases/phase-6-drag-reorder/artifacts/platform-reorder-research-2026-09-29.md
関連: core/ADR-0026〜core/ADR-0034 (並べ替えの契約) / ios/ADR-0003・ios/ADR-0009・ios/ADR-0010 (自前のレイアウトと内部の塊) / core/ADR-0017 (全画面に広げた一覧。上端の自動スクロールをエンジンが足す理由)
