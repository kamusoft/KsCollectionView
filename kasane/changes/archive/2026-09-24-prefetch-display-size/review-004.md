# レビュー結果: prefetch-display-size (004 回目)

**日付**: 2026-09-23
**判定**: APPROVED

## サマリー

修正サイクル 3 で直した 3 件は、いずれも両プラットフォームで直っており、回帰テストもある。3 件は、共有中の取得を始め直す条件、iOS の保持画像をソースの切り替えで捨てること、大きい固定幅を 16384 px で頭打ちにすることである。review-003 の Major (取得を始めたアイテムが外れた後・可視範囲へ移った後に古い URL の取得が続く) は、新しい条件で解消している。修正で新たに入った問題は 1 件である。Android の `UnitState` の doc コメントが、別のクラスの doc の前に取り残されている。このほか、始め直しの条件に 1 つだけ穴がある。取得を始めた後に列幅が変わっていると、始めたアイテムが URL を変えても共有中の古い幅の取得は古い URL のまま続く。成立する条件が狭く、表示は壊れないので、どちらも優先度の低い Minor とした。ビルドとテストはレビュアーの手元で全件成功した。

## 照合した規約

- ソースコメント規約 (always): サイクル 3 で増えた・変わったコメントを節ごとに照合した。照合したのは、両プラットフォームの台帳の冒頭と `settle` / `acquire` / `release` / `releaseStale` の説明、`KsImageRetainedMatch.swift` の冒頭と `discard()`、`KsImage.swift` の捨てる箇所、両プラットフォームの幅の上限の説明、新しいテストの doc である。外部文書の ID に頼らず、それだけで読める。禁止参照・禁止記述類型 (時間軸の記述・仕様構文キーワード) にも当たらない。lint は禁止 0 件である。要確認の 2 件 (`KsPrefetchDeclaration.kt:33`、`KsImageTest.kt:511`) は前回と同じもので、どちらも internal の宣言とテストであり、公開 doc コメントではない。doc コメントの置き場所の誤りが 1 件ある (指摘 1)
- Sample のプラットフォーム間一致 (`samples/**` を触る): サイクル 3 では `samples/` に差分が無い (更新時刻で確認)。前回までの照合結果のまま
- テスト実行規約 (テスト実行・結果の報告): 件数を集計して確認した。Android はクラス単位の XML を集計し、期待するクラス (本体 12 クラス、Sample 7 クラス) がすべて出ていることを見た。iOS は `Executed N tests` で数えた
- 実行時挙動の検証規約: サイクル 2・3 はどちらも Android の表示経路の本体コード (`KsImage.kt`) に触れていない。そのため、ホスト側の実機テスト `KsImageDeviceDecodeTest` (Pixel 4a、4 件成功・skip 0) の結果はそのまま有効と判断した。iOS 実機 (tasks 6.6) は未実施で、合意どおり指摘しない

## 確認したこと

- **ビルド・テスト (レビュアーが自分で実行)**
  - iOS パッケージ (Simulator iPhone 17e / iOS 26.5。起動中の他の機種と重ならない。DerivedData はスクラッチ): **266 tests / 0 failures**
  - Android ライブラリ (`--rerun-tasks`): **209 件 / 失敗 0 / skip 0** (12 クラス。`KsImagePrefetchWindowTest` 38 件、`KsImageTest` 43 件を含む)
  - Android Sample (`--rerun-tasks`): **37 件 / 失敗 0** (7 クラス)
  - iOS Sample の UI テストは再実行していない。サイクル 3 は `samples/` にも公開 API にも触れていないため、ホスト側の結果 (9 tests / 0 failures) を採った
  - comment-policy-lint: 禁止 0
- **修正 1: 共有中の取得を始め直す条件 (review-003 の Major)**
  - 実装は、依頼された規則と一致している。1 回の処理 (iOS は通知 1 回、Android は `update` 1 回) の中で、同じアイテムが単位を手放して違う URL で確保し直したら、それを URL の変更として記録する (`batch.changes` / `urlChanges`)。処理の終わりの `settle` で、進行中の URL が「変更したアイテムの直前の URL」か「どの持ち主も宣言していない URL (`declaredURLs` に無い)」なら始め直す。Android では、可視範囲のアイテムが宣言を変えた場合も `releaseStale` で変更として記録する。加わる・外れるだけの処理では記録が無いので始め直さない
  - spec との整合: Requirement「画像の任意キー」の「URL が変わった要素は、進行中の取得を取り消して新しい URL で出し直す (SHALL)」について、共有中の単位は「まだ必要としているアイテムが残る限り取り消さない」(Requirement「プリフェッチの取り消し」) と両立させる必要がある。今の規則は、両立させた上で、失効し得る URL の取得を残さない解釈になっている。Scenario「署名だけが変わった配列の差し替えでは新しい URL で出し直す」は、単独 (0 → 新規) と共有中 (始め直し) の両方で満たしている
  - これまでに挙がった形を、コードとテストで 1 つずつ確かめた。

    | 形 | 結果 | テスト (iOS / Android) |
    |---|---|---|
    | 共有中の片方だけ署名が変わる | 始めたアイテムが変わったら始め直す。もう片方が後から同じ URL に変わっても触らない | `test同じキーを共有するアイテムの片方だけ…` / `changingTheSignedUrlOfOneSharingItem…` |
    | 両方が同時に変わる | 1 回だけ始め直す | `test…両方の署名が同時に変わっても…` / `changingTheSignedUrlsOfAllSharingItemsRestartsOnce` |
    | 別のアイテムが違う署名で加わる | 始め直さない | `test別のアイテムが同じキーを違う署名で共有しても…` / `anotherItemJoining…` |
    | 始めていないアイテムの署名だけが変わる | 始め直さない | `test進行中の取得のURLを持つアイテムが変わらなければ…` / `anotherItemChangingItsSignedUrl…` |
    | 始めたアイテムが外れるだけ | 始め直さない | `test取得を始めたアイテムが外れた後に…` の途中 / `theStarterLeavingAlone…` |
    | 始めたアイテムが外れた後に残りが変わる | 最初に変わった処理で始め直す | `test取得を始めたアイテムが外れた後に…` / `remainingItemsChanging…` |
    | Android: 始めたアイテムが可視範囲へ移った後に全員が変わる | 窓の中の新しい URL で始め直す | `allSignedUrlsChangingAfterTheStarterMovedIntoTheViewport…` |
    | iOS: 同じ通知の中で署名が食い違う | 始める要求は 1 つで、取り消しは出さない | `test同じ通知の中で共有する取得の署名が食い違っても…` / `mismatchedSignedUrlsInOneUpdate…` |

  - 上の表に無い形は、プローブで確かめた。スクラッチに複製したパッケージに台帳を直接呼ぶテストを足しており、本体は触っていない。
    - 3 件が共有し、始めたアイテムが外れた後に、残りの 1 件ずつが別々の処理で変わる形: 1 件目の処理で始め直し、2 件目では触らない (`started=[a, b2] cancelled=[a]`)
    - 到達点 `disk` で 1 アイテムが幅違いの 2 宣言 (同じ単位) を持ち、署名が変わる形: 参照数が崩れず、最後に新しい URL の要求で取り消す
    - 回転を挟む形: 下の指摘 2
  - iOS で、同じ通知の中で始めた要求を置き換える場合: `restart` は、開始の一覧から外すだけで取り消しには入れない。単位が 0 になって作り直された後に始め直す場合も、取り消し (元の要求) → 開始 (新しい要求) の順でローダーへ伝わり、正しい
  - Android の `urlChanges` はインスタンスのフィールドだが、読み書きは `update` の錠の中だけで、`settle` と `disposeAll` で空にする。宣言は台帳に触る前に求めるので、debug の停止 (報告の例外) で処理が途中で止まっても、変更の記録が次の処理へ残ることはない
- **修正 2: iOS の保持画像はソースを切り替えたら捨てる (相方 code-003、採用)**
  - `KsImage.content` はアセットへ切り替わったときに、`loaderContent` は枠の大きさが決まらない間に、それぞれ `retainedMatch.discard()` を呼ぶ。別のリモート URL へ切り替えた場合は、`resolve` の条件 (`reloadToken` が変わる) で捨てる。ローダーを通る経路で `resolve` も `discard` も通らない分岐は無い
  - 回帰テストは 2 本ある (アセットを挟む形、別の URL を挟む形)。どちらも、戻したときに読み込み中を経由してディスクから再デコードし、再ダウンロードしないことを固定している。Android は引き当ての結果を `remember(source, …)` で持つので、ソースが変われば作り直される。対になる `switchingBackAfterClearingMemoryDoesNotReuseThePreviouslyMatchedImage` がある
- **修正 3: 大きい固定幅の丸め (相方 code-003、採用)**
  - iOS の `KsPrefetchMetrics.pixels` は、`Int` へ直す前に上限と比べる。無限大・NaN は比較が偽になり、どちらも上限に落ちるので、停止しない。Android の `roundToInt` は飽和するので、その後の `coerceIn` で同じ上限になる。列幅にも同じ上限が掛かる。両プラットフォームとも `.fixed(1e19)` 相当と上限の境界 (上限の 1 px 手前 / 上限ちょうど / 上限を超える値。Android は列幅の丸めも) のテストがある
- **足場**: proposal / design / specs は未変更。tasks は HEAD との差分がチェックの付与だけである (チェック欄を伏せた比較で差分なし)。decisions にも差分は無い
- **deviation**: サイクル 3 で増えた記録は無い。既存の記録は前回までの確認のまま
- **lessons L-001**: 証跡の数値は本実装前の対照 (before) で、直前のサイクルで修正したコードを測った値ではない。再現プローブは適用外と判断した。代わりに、修正 1 の挙動をプローブで確かめた (上記と指摘 2)

## 指摘事項

### 🟡 Minor (低優先) Android の `UnitState` の doc コメントが `UrlChange` の doc の前に取り残されている

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImagePrefetchWindow.kt:51-77`

**問題点**: 51〜58 行の KDoc は `UnitState` の説明である (「取得単位 1 件分の要求」、`@property declaredUrls` / `latest`)。サイクル 3 で `UrlChange` のクラスとその KDoc (59〜65 行) がこの KDoc と `UnitState` (71 行) の間に入った。その結果、KDoc が 2 つ続き、前の方はどの宣言にも付かない。`UnitState` には doc が無い状態になり、IDE でも `UnitState` の説明が出ない。ktlint の標準ルール (`no-consecutive-comments`) も、KDoc が続く形を違反とする。挙動には影響しない。
**推奨修正**: 51〜58 行の KDoc を `UnitState` の直前 (70 行の後) へ移す。

```kotlin
// before
/** 取得単位 1 件分の要求。… @property latest … */
/** 1 回の [update] の中で、…URL を変えたことの記録。 … */
private class UrlChange(…)
private class UnitState(…)

// after
/** 1 回の [update] の中で、…URL を変えたことの記録。 … */
private class UrlChange(…)
/** 取得単位 1 件分の要求。… @property latest … */
private class UnitState(…)
```

### 🟡 Minor (低優先) 取得を始めた後に列幅が変わっていると、始めたアイテムが URL を変えても共有中の古い幅の取得が古い URL のまま続く

**該当箇所**: `ios/Sources/KsCollectionView/KsImagePrefetcher.swift:172-176,185-195`、`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImagePrefetchWindow.kt:233-256,277-283`

**問題点**: URL の変更は「手放した単位」と「いま確保する単位」が同じときだけ記録される。iOS は `releasedURLs[unit]` を新しく解いた単位で引き、Android の `reconcile` も同じである。`releaseStale` は `unitFor(新しい宣言) == assignment.unit` で比べる。到達点 `memory` の列幅の要素では、取得を始めた後に列幅が変わると (回転・列数・余白の変更)、同じアイテムの新しい宣言は新しい幅の単位へ解ける。そのため、古い幅の単位には URL の変更が記録されない。次の形をプローブで再現した。スクラッチに複製したパッケージに台帳を直接呼ぶテストを足しており、本体は触っていない。

- 同じ `key`・列幅の A (`sig=a`) と B (`sig=b`) が、A の URL で始まった単位を共有する。列幅が変わる (台帳は触らない。spec どおり)。その後、A の署名だけが `a2` に変わる
- iOS: `started=[sig=a@200, sig=a2@300] cancelled=[]`。Android: `started=[sig=a@300, sig=a2@500] disposed=[] active=[sig=a@300, sig=a2@500]`
- 古い幅の単位は B が持ち続けるので残る (正しい)。しかし、その取得の URL は、URL を変えた A の直前の URL (`sig=a`) のままで、いまどの持ち主も宣言していない。列幅が変わらなければ、同じ操作で B の URL (`sig=b`) で始め直す (プローブの対照: `started=[a@200, a2@200] cancelled=[a@200]`)。回転を挟むかどうかで、採用した規則の結果が変わっている

採用した規則は「その単位を確保しているアイテムのうち URL を変えたアイテムがいて、進行中の URL がその直前の URL なら始め直す」である。A は処理の始めの時点でこの単位を確保していて、URL を変えている。この形は規則の対象に入ると読むのが自然である。影響は、失効した `sig=a` の取得が失敗し、B の古い幅の先読みが効かなくなることに限られる。新しい枠に対して許容範囲の内側なら、引き当てに使われ得る項目である。表示は `KsImage` 自身の要求で出るので壊れない。成立には 4 つが重なる必要がある: 到達点 `memory` + 列幅、同じ `key` を違う署名で共有、始めた後の列幅の変化、始めたアイテムを含む一部だけの署名の更新。配列全体の署名が一斉に変わる普通の形では、B も古い単位を手放すので取り消される。優先度は低い。

**推奨修正 (選択肢)**:
- URL の変更を単位ではなく識別子で記録する。同じアイテムの 1 回の処理の中で、識別子 X の宣言を URL `u` で手放し、同じ識別子を別の URL `u'` で確保し直したら (単位の幅は問わない)、手放した側の単位に「直前の URL `u`」として記録する。Android の `releaseStale` も、`unitFor` の一致ではなく識別子の一致で見る。上の形を両プラットフォームの台帳テストに足す
- あるいは既知の性質として受け入れ、deviation か蒸留時の concepts の「任意キー」の注意に 1 行残す (「列幅が変わった後の署名の更新では、古い幅の共有中の取得が古い URL のまま残ることがある。表示は壊れない」)
- 急ぎではない。完了時の計測 (tasks 8.x) の前に直す必要もない

### 🔵 Suggestion 幅の上限 (16384 px) を deviation に 1 行残す

**該当箇所**: `ios/Sources/KsCollectionView/KsPrefetchMetrics.swift:5-8,18-22`、`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsPrefetchDeclaration.kt:82-93`

**問題点**: spec「プリフェッチの表示幅」は、有限かつ正の固定値を有効とし、その幅の正方形を覆う大きさで載せると定めている。上限による丸めがあると、元寸が 16384 px を超える画像を 16384 px 以上の幅で宣言した場合だけ、載る項目が宣言より小さくなる。停止を避ける丸めとして妥当で、現実の入力ではまず起きない。ただし spec の文面にない挙動である。コメントの「ここで頭打ちにしても結果は変わらない」も、この場合には厳密には当たらない (表示に使えない大きさ、という前段の理由は成り立つ)。
**推奨修正**: deviation.md に「幅は 16384 px で頭打ちにする (描画の最大辺。有効な値でも整数へ直す前に丸める)」を 1 行残し、蒸留で concepts に反映できるようにする。コードの変更は要らない。

### 観察 (指摘ではない)

- iOS の `loaderContent` は、枠の大きさが決まらない間に保持画像を捨てる。表示中の `KsImage` がレイアウトの途中で一時的に大きさ 0 で組み立てられる場合を考える。この場合、メモリのみの消去の後に読み込み中の表示へ戻り得る (サイクル 3 より前は、大きさ 0 の組み立てでは保持画像に触れなかった)。画像グリッドのような固定の大きさのセルでは起きない。自己サイズ調整のセルで一時的な大きさ 0 の組み立てが起きるかは確かめていない。tasks 6.6 (iPhone 実機) で自己サイズ調整の画面を触る機会があれば、消去の後の見え方を併せて見ておくとよい

## アクションプラン

1. (任意・低優先) Android の `UnitState` の KDoc を `UnitState` の直前へ移す
2. (任意・低優先) 列幅が変わった後の署名の更新で、古い幅の共有中の取得を始め直すか決める。識別子での記録に直すか、既知の性質として deviation / concepts に残すかのどちらか
3. (任意) 幅の上限 16384 px を deviation に 1 行残す
4. 残りは合意どおり tasks 6.6 (iPhone 実機) と 8.x (完了時の計測) へ進む
