# レビュー結果: prefetch-display-size (002 回目)

**日付**: 2026-09-23
**判定**: APPROVED

## サマリー

前回の採用分 (共有中のキーで署名 URL を差し替えても取得が更新されない) とオーナー決定 A (Android の表示の縮小要求の鍵にだけ当てはめ方を付ける)、Suggestion 2 件 (iOS の警告を 1 回にする・Android 便宜形の `key` の位置) は、いずれも両プラットフォームで直っており、回帰テストも付いている。修正で入った新しい問題は、共有中の取得単位に別の URL のアイテムが加わるたびに取得をやり直す動きの 1 件だけである。spec には反しておらず、影響も狭いので Suggestion とした。ビルドとテストはレビュアーの手元で全件成功した。

## 照合した規約

- ソースコメント規約 (always): 前回以降に変わったコメントを節ごとに照合した。Sample の doc コメントにあった ADR 参照の整理 (付随修正) は、許容参照の形式 (`<domain>/ADR-NNNN`) を非 doc の行コメントに移すか、自己完結した文に書き直すかのどちらかで、規約に沿っている。lint は禁止 0 件、要確認 2 件。1 件は `KsPrefetchDeclaration.kt:33` で、internal なデータクラスの companion にある関数の doc (可視性を推定する仕組みの誤検知)。もう 1 件は `KsImageTest.kt:510` で、テストのコメントである。どちらも公開 doc コメントではない
- Sample のプラットフォーム間一致 (`samples/**` を触る): 選択肢の文言・順序・起動時の指定の綴り (`none` / `disk` / `memory` / `memory-column`) が両プラットフォームで一致している
- テスト実行規約 (テスト実行・結果の報告): 件数を集計して確認した。Android はクラス単位の XML を集計し、期待する 12 クラス (本体) と 7 クラス (Sample) がすべて出ていることを見た。iOS は `Executed N tests` で数えた
- 実行時挙動の検証規約 (実行環境で実体が変わる資源 = ハードウェアビットマップ): Android の分岐はホスト側の実機テスト `KsImageDeviceDecodeTest` (Pixel 4a、4 件成功・skip 0) が踏んでいる。iOS 実機 (tasks 6.6) は未実施で、合意どおり指摘しない

## 確認したこと

- **ビルド・テスト (レビュアーが自分で実行)**
  - iOS パッケージ (Simulator iPhone 17e / iOS 26.5、起動中の他の機種と重ならない。DerivedData はスクラッチ): **255 tests / 0 failures**
  - iOS Sample (scheme `KsCollectionViewSamples`、Simulator iPhone Air / iOS 26.5): **9 tests / 0 failures** (計測ドライバは含まない)
  - Android ライブラリ (`--rerun-tasks`): **199 件 / 失敗 0** (12 クラス)
  - Android Sample (`--rerun-tasks`): **37 件 / 失敗 0** (7 クラス)
  - comment-policy-lint: 禁止 0 / 要確認 2 (上記)
- **前回の指摘の解消**
  - 共有中のキーで署名 URL を差し替えたとき (相方 Major、採用): iOS `KsImagePrefetcher.acquire` と Android `KsImagePrefetchWindow.acquire` は、単位が共有中で参照数が 0 にならなくても、開始時の URL と違う URL で確保されたら古い要求を止めて新しい URL で始め直す。次の 3 つの場合を追って確かめた。(a) 片方だけ変わる: 古い URL を止めて新しい URL を始める。後からもう片方も同じ URL に変わっても、何もしない (b) 両方が同時に変わる: 出し直しは 1 回 (c) 同じ通知の中で出した要求を置き換える (iOS): まだローダーに渡していない要求は取り消さず、開始の一覧から外す。取り消しは開始より先に伝わるので、この順序で正しい。テストは iOS `test同じキーを共有するアイテムの…` の 3 本と、Android `changingTheSignedUrlOfOneSharingItemRestartsTheSharedRequest` / `changingTheSignedUrlsOfAllSharingItemsRestartsOnce`。最後の 1 件が外れたときに、新しい URL の要求で取り消すことまで確かめている
  - オーナー決定 A (deviation 記録済み): `KsImageIdentity.displayKey` が表示の要求の鍵に `ks#scale` を足す。先読みの鍵 (`sizedKey`) は `coil#size` だけのままである。鍵の本体は識別子のままなので、`KsImageCache.remove` (本体の完全一致で消す) は表示の項目も消す。前回挙げた 2 つの条件はどちらも回帰テストが Coil の実行で確かめている。横長の先読み項目 + `fit` は `tooLargePrefetchedItemIsNotReturnedByTheDisplayRequestForFit`、`fit` で載った小さい項目 + `fill` は `smallerItemLoadedForFitIsNotReturnedByTheDisplayRequestForFill` で、いずれも `DataSource.MEMORY_CACHE` で返らず、取り直すこと。Sample の要求の分類 (`ImageRequestKind.of`) は精度 (`INEXACT` / `EXACT`) で見分けるので、鍵の付随情報が増えても誤らない
  - iOS の警告の繰り返し (Suggestion): `KsInvalidInput.report` が同じ文面を 1 回だけ記録する (上限 256 件。Android の `reportOnce` と同じ形)。空文字のキーと無効な固定値のそれぞれにテストがある。debug の assertion は毎回止まり、規約どおり
  - Android 便宜形 `KsImage(url, …)` の `key` の位置 (Suggestion): `contentMode` の後ろに移った。`KsCollectionViewPublicApiTest.urlOverloadKeepsPositionalArgumentsOfTheSourceOverload` が、位置引数の 3 番目の文字列が説明に結び付くことと、末尾のラムダが失敗の表示になることを固定している
- **足場**: proposal / design / specs は未変更。tasks は差分がチェックの付与だけである (2.3 の文面「`ks#scale` を外す」は、deviation の Decision 3 の記録で上書きされた合意済みの差分)
- **deviation の付随修正**: Sample の ADR 参照の整理は、同梱条件の「3 ファイル以内」を超える (約 12 ファイル)。ただしオーナー指示の同梱と記録されており (確認の経路で同梱が選ばれた)、変更はコメントだけで、担保は lint (禁止 0) である。`ImageGridDemoView.swift` の文のつながりの修正もコメントだけである。どちらも範囲に収まっている
- **lessons L-001**: 証跡の数値は本実装前の対照 (before) で、直前のサイクルで修正したコードを測った値ではない。前回と同じく、再現プローブは適用外と判断した

## 指摘事項

### 🔵 Suggestion 共有中の取得単位に別の URL のアイテムが加わるたびに取得をやり直す

**該当箇所**: `ios/Sources/KsCollectionView/KsImagePrefetcher.swift:197-209`、`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImagePrefetchWindow.kt:255-276`

**問題点**: 出し直しの条件は「単位が開始時に使った URL と、いま確保する宣言の URL が違う」である。これは「アイテム自身の URL が変わった」場合 (Requirement「画像の任意キー」が求める出し直し) だけでなく、「別の署名付き URL を持つ別のアイテムが、同じ `key` の単位に新しく加わった」場合にも当てはまる。たとえば同じ人のアバター (`key` = ユーザー ID) がページごとに別の署名付き URL で返るタイムラインでは、そのユーザーの行が先読みの窓に入るたびに、進行中の取得が取り消されて別の URL で始め直される。取得の完了より行の入れ替わりが速い間は、先読みが完了しない。Android は同じ更新の中でも「開始 → 取り消し → 開始」になる (iOS は同じ通知の中なら 1 本にまとめる)。
一度完了すれば出し直しはキャッシュに当たり、表示は `KsImage` 自身の要求で出るので、壊れはしない。spec の文面 (URL が変わった要素は出し直す) にも反していない。影響は「同じ `key` に有効な URL が同時に複数ある」場合の、初回の先読みの効き目に限られる。
**推奨修正 (選択肢)**:
- 出し直しを「そのアイテムが同じ単位を手放した直後に、違う URL で確保し直した」場合に絞る (`reconcile` の中で、同じアイテムが手放した単位の集合を持つ)。この形でも、相方が挙げた「共有中の片方・両方の署名が変わる」場合は出し直しになる
- あるいは今の動きを既知の性質として受け入れ、蒸留時に concepts の「任意キー」の注意 (同じ `key` の URL が同時に複数あると先読みを取り直すことがある) に 1 行残す
- 急ぎではない。完了時の計測 (tasks 8.x) の前に直す必要もない

### 観察 (本 change の範囲外)

- iOS Sample の UI テストは、Xcode が接続中の実機 (パスコードでロック中) の通知サービスに触れた旨のログを出した。Simulator 上の実行には影響しない

## アクションプラン

1. (任意) 共有中の取得単位の出し直しを、アイテム自身の URL が変わった場合に絞るか、既知の性質として concepts に残すかを決める
2. 残りは合意どおり tasks 6.6 (iPhone 実機) と 8.x (完了時の計測) へ進む
