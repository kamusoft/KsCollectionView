# レビュー結果: drag-reorder (005 回目)

**日付**: 2026-09-30
**判定**: APPROVED

## サマリー

review-004 の Minor 2 件・Suggestion 1 件と、second-opinion-code-004 の Minor (上端の安全領域が UIKit の帯より短い配置で両方が送る) はすべて直っている。iOS 26 より前のプロファイルに 0.75 秒の送り始めの待ちと深い側の曲がり方 (1.6 乗・830pt/秒・基準の長さ 65pt) が入り、1 回に進める時間の上限は 0.1 秒に広がり、UIKit の帯に入る所では自前で送らなくなった。iOS 18.6 のプローブで、送り始めの待ち 0.768 秒と、深さに対する速さが式どおりであること (深さ 45.3pt の式の値 123pt/秒は証跡の 121 と合う) を再現した ([L-001])。

残りは、重なる配置 (バーの無い全画面など) の iOS 18 で、自前の帯と UIKit の帯の境目を指がまたぐと送りが約 0.75 秒止まる点 (Minor) と、iOS 18 の実行で空振りになるテストがある点 (Suggestion)。どちらも基準機の目視 (6.3) を止める理由にはならない。

## 照合した規約

- ソースコメント規約 (always)。`scripts/comment-policy-lint.py --advisory` を `KsReorderTopAutoScroll.swift`・`KsReorderTopAutoScrollTests.swift` にかけて禁止 0・要確認 0。`KsCollectionViewController.swift` の上端の送りを回す箇所 (`:1664`〜`:1712`) のコメントも本文で照合し、作業文書への参照・履歴記述は無い
- テスト実行規約 (テストの実行・結果の報告)。コンテキストパッケージの指示で `KsReorderTopAutoScrollTests` と `KsReorderEngineTests` に絞って実行し、件数を確かめた。絞り込みなしの全件実行 (iOS ライブラリ 519 件など) は実装側の結果で、このレビューでは流していない
- 実行時挙動の検証規約 (不具合修正の完了判定)。review-004 で送り始めの待ちの違いを見つけたプローブ (同じ Sample の複製・同じ合成タッチの運び方) で、修正後の iOS 18.6 の送り始めを確かめた

ロードしたスキル: ksn-review、swift-ui-impl-skill (swift-language・performance の観点。対象は UIKit の CADisplayLink と計算の構造体で、SwiftUI の View の変更は無い)

lessons/code-review.md の重点観点:

- [L-001] 直前のサイクルで直した計算の値を、`evidence/ios-r4-autoscroll-speed.log` の「review-004 の後の測り直し (r5)」の自前の値と突き合わせた。iOS 18.6 で帯 (深さ 45pt) に止めると、帯に入った提案 (ドラッグの始まりから 0.201 秒) の 0.768 秒後に送り始めた (証跡 0.715・0.730 秒、UIKit 標準 0.765 秒)。止めている間の速さは、合成タッチの指の位置が約 0.4 秒に 1pt ずつ深い側へずれたため 45pt ちょうどの値は取れなかったが、深さごとの 1 フレームの送りは式どおり (47.3pt で実測 100・式 103、49.3pt で 81・85)。式の 45.3pt の値 123pt/秒が証跡の 121 と合うので、再現したと判定した。記録は `evidence/review-005-ios18-top-autoscroll-probe.log`
- [L-002] 期待値 (iOS 18 の UIKit 標準の上端と同じく、帯に入ってから約 0.75 秒は動かず、その後は深さで決まる一定の速さで、時間では加速しない) を先に書き出し、プローブで毎フレームの contentOffset を見た。待ちの間は 1pt も動かず、送り始めから一定の 1 フレーム 1.6〜1.7pt で進み (約 60fps)、34〜47ms に延びたフレームの前後も送りの合計は間隔の分だけ伸びていた (頭打ちなし)。指が深い側へずれるにつれて速さが下がり、帯の端 (50pt) を越えると止まった。録画のコマ抜きは行っていない (今回の修正は速さと時機の数値で、見た目の経路は review-004 で録画済み)

## 実行時の確認の記録

- テスト (絞り込みあり)
  - iOS 26.5 (`ksn-drag-reorder-review`): `-only-testing:KsCollectionViewTests/KsReorderTopAutoScrollTests -only-testing:KsCollectionViewTests/KsReorderEngineTests` で Executed 61 tests, 0 failures (`KsReorderEngineTests` 48・`KsReorderTopAutoScrollTests` 13)
  - iOS 18.6 (`ksn-drag-reorder-ios18`): 同じ絞り込みで Executed 61 tests, 0 failures (内訳も同じ)
- iOS 18.6 のプローブ: review-004 のスクラッチの複製 (Sample「並べ替え」、本体は作業ツリーを参照) を今の作業ツリーでビルドし直し (`KsReorderTopAutoScroll.swift` のコンパイルを確かめた)、帯の深さ 45pt に 4 秒止める UI テスト 1 件を走らせた。リポジトリのファイルは変えていない。使ったのは `ksn-drag-reorder-review` と `ksn-drag-reorder-ios18` だけで、終わった後に両方が停止していることを確かめた
- evidence/ に置いたのは記録の要約 1 件 (画像なし)。パス・端末の識別子を含まず、`scripts/identity-lint.py`・`scripts/local-path-lint.py` とも検出 0 件

## 前回の指摘の解消状況

| 出典 | 指摘 | 状況 | 確かめたこと |
|---|---|---|---|
| review-004 🟡 Minor 1 | iOS 18 以前の上端の送りの形 (送り始めの待ちが無い・帯の深い側が遅い) | **解消** | iOS 26 より前のプロファイルが `startDelay: 0.75`・`curveLength: 65`・`exponent: 1.6`・`maximumSpeed: 830` になり (`ios/Sources/KsCollectionView/KsReorderTopAutoScroll.swift:37`〜`:42`)、帯を出る・一覧の外へ出る・UIKit の帯へ入るとき待ちを数え直す (`:83`〜`:90`)。単体テストで深さ 1・25・45pt の速さが実測の 5% 以内 (`ios/Tests/KsCollectionViewTests/KsReorderTopAutoScrollTests.swift:72`〜`:78`。前回の ±60pt/秒から絞られ、45pt の差を通さない)、待ちと数え直し (`:112`〜`:133`)。プローブで待ち 0.768 秒と式どおりの速さを再現 (上の [L-001]) |
| review-004 🟡 Minor 2 (優先度低) | 1 回に進める時間の上限 1/30 秒で、30fps を下回ると上端だけ遅くなる | **解消** | `maximumStep` が 0.1 秒になった (`KsReorderTopAutoScroll.swift:32`〜`:34`)。単体テストで間隔 1/60・1/30・45ms・1/15 秒のどれでも 1 秒あたりの送りが式の値と一致し (`KsReorderTopAutoScrollTests.swift:178`〜`:191`)、1 秒飛んだフレームは 0.1 秒分で切られる (`:193`〜`:198`)。プローブでも延びたフレームの前後で送りの合計が間隔の分だけ伸びていた |
| review-004 🔵 Suggestion | 較正の証跡に UIKit 標準を測ったときの一覧と指の運び方を残す | **解消** | `evidence/ios-r4-autoscroll-speed.log` の冒頭に「測った条件」(ハーネスの一覧の構成・UIKit 標準と自前での置き方の違い・4 歩で約 400pt/秒で運び止めている間は 1 秒ごとに 1pt 左右にずらす運び方・記録の方法・review-004 のプローブとの違い) が書き足された |
| second-opinion-code-004 🟡 Minor | 上端の安全領域が UIKit の帯より短い配置で、UIKit と自前の両方が送る | **解消** | 指が UIKit の帯 (`adjustedContentInset.top` から帯の幅) に入る所では自前で送らない (`KsReorderTopAutoScroll.swift:85`、呼び出し側は `ios/Sources/KsCollectionView/KsCollectionViewController.swift:1703` で `adjustedContentInset.top` を渡す)。UIKit の帯が内側の余白の下から始まることは、review-002 の頃の証跡 `evidence/ios-r2-autoscroll-inset.log` (余白 116pt で指 146pt に UIKit が送る) と合う。単体テスト (`KsReorderTopAutoScrollTests.swift:154`〜`:164`) と、証跡の直した後の実測 (重なる所で UIKit だけの値 179・161pt/秒) がある。この置き方の境目の見え方は下の Minor |

## 指摘事項

### 🟡 Minor 重なる配置の iOS 18 で、自前の帯と UIKit の帯の境目を指がまたぐと、送りが約 0.75 秒止まる

**該当箇所**: `ios/Sources/KsCollectionView/KsReorderTopAutoScroll.swift:83`〜`:90`、`deviation.md` の上端の自動スクロールの項目

**問題点**:
- 上端の安全領域が UIKit の帯より短い配置では、指を上へ運ぶと、自前の帯の下側 (UIKit の帯より下) から UIKit の帯へ入る。そこで自前の送りは止まり、iOS 18 の UIKit は帯に入ってから約 0.75 秒待つため、送りがいったん止まってから再開する。実装者の証跡にも、iOS 18.6・枠を 30pt 下げた配置で、自前が送っていた位置 (枠の上端から 65pt) から重なる所 (40pt) へ動かすと「入ってから 0.77 秒」後に UIKit が送り始めた記録がある (`evidence/ios-r4-autoscroll-speed.log` の r5 の最後の行)
- 逆向き (UIKit の帯から自前の帯へ下げる) でも、UIKit の帯の中では `dwell` を 0 に戻すので、自前の帯に入った時点から 0.75 秒待ち直す。UIKit だけの一覧なら同じ帯の中の移動で待ち直さないので、ここは UIKit の形とも違う
- この配置は「バーの無い全画面の一覧」で起きる。iOS 18 の帯は 50pt なので、安全領域の上が 48pt の iPhone 11 (基準機) でも境目は画面の上端から 50pt にでき、上端へ運ぶ指はほぼ必ずここを通る。deviation.md の上端の項目はこの配置の見え方として「UIKit の帯のすぐ下で速さが上がる見え方が残る」だけを書いていて、止まることには触れていない。6.3 の目視は Sample (バーあり、安全領域が帯より長い) で行うため、ここは目視でも見えない
- 深刻さは、重なる配置・iOS 26 より前・指が境目をまたぐ、の 3 つがそろったときに限られ、最終的にはどちらかが送るので運べなくなることはない

**推奨修正**:
- 逆向き (UIKit の帯 → 自前の帯) の待ち直しは、UIKit の帯の中にいる間も `dwell` を数え続ける (自前の帯と UIKit の帯を合わせて 1 つの帯として待ちを数える) ことで無くせる。単体テストに「UIKit の帯に 1 秒いた後に自前の帯へ下げると、すぐ送る」を足す
- 上向き (自前の帯 → UIKit の帯) の止まりは UIKit 側の待ちなのでライブラリから消しにくい。deviation.md の上端の項目の「この置き方では」の文に「iOS 26 より前は、指が UIKit の帯へ入ると UIKit の待ちの約 0.75 秒だけ送りが止まる」を足し、蒸留で ios/ADR-0011 に書き残す

### 🔵 Suggestion iOS 18 の実行では、上端の送りの「送らない」テストのいくつかが待ちの間に終わり、何も確かめていない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsReorderEngineTests.swift:251`〜`:273`・`:308`〜`:329`・`:332`〜`:350`・`:384`〜`:402`

**問題点**: 「帯の外では送らない」「一覧の外で離すとすぐ止まる」「置いた後は送らない」「安全領域の上が 0 なら送らない」の 4 件は、指を置いた直後から 10 フレーム (約 0.17 秒) 進めて contentOffset が変わらないことを見ている。iOS 18 のプロファイルでは送り始めまで 45 フレーム待つので、iOS 18.6 の実行では、止める処理が壊れていてもこの 4 件は通る (たとえば `test上端の帯を通って一覧の外で離すとすぐ止まる` は、指を帯に置いてすぐ終わりの通知を送るので、待ちの前に 10 フレームで終わる)。`test上端の帯から一覧の外へ出ると止まり帯へ戻ると再開する` は先に待ちを越えて送らせてから外へ出すので、両 OS で意味がある。iOS 26.5 の実行では 4 件とも意味のある確認になっているため、今の実装の欠陥を見逃している証拠は無い

**推奨修正**: 4 件とも、指を帯に置いた後に `advancePastStartDelay` で送り始めを確かめてから止める操作 (外で離す・置く) をするか、「送らない」の確認を待ち + 数フレーム分進めてから行う形にする。そうすると両 OS で同じ意味になる

## 確認した観点

- 仕様充足: Requirement「端での自動スクロール」の上端 (iOS) は deviation.md の上端の項目 (合意済みの差分) のとおり。今回の変更 (iOS 26 より前の待ち・曲がり方・UIKit の帯との重なりの扱い) は deviation.md の同じ項目に書き足されていて、コードの `profile` と `nextOffset` の条件に一致する
- 足場: proposal / design / specs は HEAD から変わっていない。tasks.md の差分はチェックの変更だけ
- 計算の境界: 深さ 0 (最大の速さ)・帯の端 (深さ = 帯の幅で nil)・安全領域 0・指の位置が無い・先頭 (行き過ぎず先頭で止まる、先頭では nil)・経過時間が負や 0・飛んだフレーム。待ちの比較にわずかな幅 (`1e-9`) を持たせて、1/60 の足し合わせで待ちの終わりのフレームを取りこぼさない
- 呼び出し側: 表示のリンクの最初のフレームは時刻の基準にするだけで進めない。取りやめたドラッグ・指の位置を捨てた後は送らない。回し始めるたびに計算の構造体を作り直すので、前のドラッグの待ちを持ち越さない。止めるときに構造体と指の位置を捨てる
- UIKit の帯の位置の取り方: `contentInsetAdjustmentBehavior = .never` (`KsCollectionViewController.swift:504`) のため `adjustedContentInset.top` は通常 0 で、取り直しの間だけ安全領域の分の余白が足される (`:2143`〜`:2149`)。そのときは UIKit の帯が余白の下 (バーの下) に来るので、自前で送らないのは筋が通る
- テスト: 単体テストは OS ごとの値・深さに対する実測との一致・単調性・時間で加速しない・待ちと数え直し・重なり・先頭・低いフレームレート・飛んだフレームを持つ。結合テストは送り始めの待ちを越えてから送ったことを確かめる形に直っている (`advancePastStartDelay`、`KsReorderEngineTests.swift:211`〜`:218`)。空振りは上の Suggestion
- 設計品質: 計算を表示から切り離した値の構造体に置き、OS の分岐は `profile` の 1 か所。オーバーエンジニアリングは無い。性能は 1 フレームに `pow` 1 回と比較だけ
- 並行性: `KsReorderTopAutoScroll` は値型で、メインの表示のリンクからだけ触る

## アクションプラン

1. 🟡 重なる配置の iOS 18 の境目の止まりについて、逆向きの待ち直しを直す (UIKit の帯の中でも待ちを数える) か、deviation.md に上向きの止まりとあわせて書き足す
2. 🔵 iOS 18 で空振りになる「送らない」テストを、待ちを越えてから確かめる形にする
3. 残っている tasks 6.2〜6.4 (体感ゲート・オーナーの目視・置いた直後の塊の件数の変化の見た目) へ進む
