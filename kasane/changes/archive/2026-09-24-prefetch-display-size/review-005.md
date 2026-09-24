# レビュー結果: prefetch-display-size (005 回目)

**日付**: 2026-09-23
**判定**: APPROVED

## サマリー

修正サイクル 4 で直した 3 件は、いずれも両プラットフォームで直っていて、回帰テストもある。3 件は、索引の刈り込みをやめたこと、共有取得の始め直しで URL の変更をアイテム × 識別子で記録するようにしたこと、Android の KDoc の位置である。review-004 の Minor 2 件と second-opinion-code-004 の NEEDS_DISCUSSION (オーナー決定 A) は解消した。修正で新たに入った不具合は見つからなかった。始め直しの判定を識別子の全単位に広げたことで、判定の対象になる単位が少し増えた。その結果は規則の範囲に収まり害も無いので、観察として残す。ビルドとテストは、レビュアーの手元でも全件成功した。

## 照合した規約

- ソースコメント規約 (always): サイクル 4 で変わったコメントを節ごとに照合した。対象は、両プラットフォームの索引の冒頭説明と `cachedEntries`、台帳の冒頭説明、`URLChange` / `UrlChange`、`recordURLChanges` / `recordUrlChanges`、`settle`、`releaseStale`、新しいテストの doc である。いずれも外部文書の ID に頼らず、それだけで読める。時間軸の記述 (「刈り込みをやめた」等) も仕様構文キーワードも無い。lint は禁止 0 件である。要確認の 1 件 (`KsImageTest.kt:533`) は前回の `:511` と同じもので、行がずれただけである。テストの doc であり、公開 doc コメントではない
- テスト実行規約 (テスト実行・結果の報告): 件数を集計して確認した。Android はクラス単位の XML を集計し、期待するクラスがすべて出ていることを見た (本体 12 クラス、Sample 7 クラス)。iOS は `Executed N tests` で数えた
- Sample のプラットフォーム間一致 (`samples/**`): サイクル 4 では `samples/` に差分が無い (更新時刻で確認)。前回までの照合結果のまま
- 実行時挙動の検証規約: サイクル 4 は Android の表示経路 (`KsImage.kt`・`KsImageRequestFactory.kt`) に触れていない。触れたのは索引の問い合わせで、実機で実体が変わる資源 (ハードウェアビットマップ) の分岐とは無関係である。ホスト側の実機テスト `KsImageDeviceDecodeTest` (Pixel 4a、サイクル 4 の後に 4 件成功・skip 0) を採った。iOS 実機 (tasks 6.6) は未実施で、合意どおり指摘しない

## 確認したこと

- **ビルド・テスト (レビュアーが自分で実行)**
  - iOS パッケージ (Simulator iPhone Air / iOS 26.5。起動中の他の機種と重ならない。DerivedData はスクラッチ): **268 tests / 0 failures**
  - Android ライブラリ (`--rerun-tasks`): **213 件 / 失敗 0 / skip 0** (12 クラス。`KsImagePrefetchWindowTest` 41 件、`KsImageTest` 44 件、`KsImageMemoryIndexTest` 9 件を含む)
  - Android Sample (`--rerun-tasks`): **37 件 / 失敗 0** (7 クラス)
  - iOS Sample の UI テストは再実行していない。サイクル 4 は `samples/` にも公開 API にも触れていないため、ホスト側の結果 (9 tests / 0 failures) を採った
  - comment-policy-lint: 禁止 0
- **修正 1: 索引の刈り込みをやめた (second-opinion-code-004、オーナー決定 A)**
  - 両プラットフォームの `cachedEntries` は、キャッシュに無い鍵を候補から外すだけになり、索引からは消さない (`ios/Sources/KsCollectionView/KsImageMemoryIndex.swift:77-86`、`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImageMemoryIndex.kt:57-63`)。索引から消す経路は `remove(effectiveID:)` / `remove(identifier)`・`removeAll`・上限の LRU だけである。刈り込みの呼び出しも、それを前提にしたコメントも残っていない (grep で確認)
  - 回帰テストは両プラットフォームにある。索引の単体テストは、照会しただけでは鍵が残ることを固定する (Android `keysNotInTheCacheStayIndexedUntilTheItemArrives`、iOS は下の結合テストの途中で確かめる)。表示の結合テストは、未完了の先読みの鍵を登録して照会し、候補にならず索引に残ること、同じ鍵に項目が載った後の照会で引き当てることを固定する (iOS `test先読みの完了前に照会しても完了後の次の照会で引き当てる`、Android `prefetchCompletedAfterAnEarlierQueryIsMatchedNextTime`)。Android の契約テスト (`KsImageCacheContractTest.kt:291-299`) も、追い出された鍵が照会の後も残る形に書き換わっている
  - 代償は、死んだ鍵への問い合わせが残ることである。1 識別子あたりの鍵は、先読みの幅と表示の枠の大きさの数だけで、上限つき LRU の範囲に収まる。design の Risks の見積もり (URL あたり数件) の内側である。`KsImageRequestFactory` の「完了前の鍵は問い合わせで空になるだけで候補にならない」という説明も、新しい挙動と矛盾しない
  - spec との整合: Requirement「KsImage のメモリ項目の引き当て」は、上限を超えて外れた項目を把握の対象外とするだけで、照会による除外は定めていない。今回の形のほうが、Requirement「プリフェッチの到達点」の「把握から外れていなければデコードのやり直しも読み込み中の経由もなし」に素直に合う。design Decision 3 内の 2 つの記述の食い違いと tasks 6.4 の文言は、deviation.md (索引の刈り込み) に記録済みで、合意済み差分として扱った
- **修正 2: URL の変更をアイテム × 識別子で記録する (review-004 Minor 2)**
  - 両プラットフォームとも、`reconcile` の中で、手放した宣言と新しい宣言をアイテム 1 件ぶん識別子ごとに比べる。直前の URL と新しい URL がそろった識別子だけを変更として記録する (`recordURLChanges` / `recordUrlChanges`)。Android は可視範囲のアイテムの `releaseStale` でも同じ記録を使う。`settle` は、変更のあった識別子の全単位 (幅違いを含む) を判定する。規則自体 (進行中の URL が「変更したアイテムの直前の URL」か「どの持ち主も宣言していない URL」なら始め直す、始め直す URL の優先順位) は前回と同じである
  - review-004 で再現した形 (列幅が変わった後に、取得を始めたアイテムの署名だけが変わる) は、両プラットフォームで古い幅の取得を残るアイテムの URL で始め直す。テストは iOS `test列幅が変わった後に取得を始めたアイテムの署名が変わると古い幅の共有中の取得も出し直す`、Android `theStarterChangingItsSignedUrlAfterAWidthChangeRestartsTheOldWidthRequest`。対になる否定形 (取得を始めていないアイテムの署名が変わるだけなら始め直さない) と、Android の可視範囲へ移った後の形 (`theStarterInTheViewport…`) もある
  - 前回の表の形 (共有中の片方だけ・両方同時・別アイテムの参加・始めていないアイテムの変更・始めたアイテムの離脱・離脱後の変更・同じ通知内の食い違い) は、既存のテストがすべて緑のまま通っている
  - 列幅が変わっただけでは、宣言が変わらないので `reconcile` が早く戻り、変更は記録されない。Requirement「プリフェッチの取り消し」の「列幅が変わっただけでは…出し直しもしない」は保たれる
  - 記録の寿命: iOS は `Batch` に閉じる。Android の `urlChanges` は `update` の錠の中だけで読み書きし、`settle` と `disposeAll` で空にする。前回確かめた性質は変わっていない。`settle` の中で単位の表を書き換えるが、走査はどちらも複製した一覧 (`filter` の結果) の上で行うので安全である
- **修正 3: Android の KDoc の位置 (review-004 Minor 1)**: `UrlChange` の KDoc (`KsImagePrefetchWindow.kt:53-58`) と `UnitState` の KDoc (`:64-71`) が、それぞれの宣言の直前に付いている。KDoc が続く形は解消した
- **足場**: proposal / design / specs / tasks はサイクル 4 で変更なし (更新時刻がすべて review-004 より前)。decisions にも差分は無い
- **deviation**: サイクル 4 で 2 件増えた (索引の刈り込み、16384 px の上限)。前者は second-opinion-code-004 のオーナー決定、後者は review-004 の Suggestion への対応で、どちらも理由と影響の範囲が書かれている
- **lessons L-001**: 証跡の数値は本実装前の対照 (before) で、直前のサイクルで修正したコードを測った値ではない。再現プローブは適用外と判断した

## 指摘事項

なし (Critical / Major / Minor / Suggestion いずれも 0 件)。

### 観察 (指摘ではない)

- **始め直しの判定を識別子の全単位に広げたことで、URL を変えたアイテムが持っていない幅の単位も判定の対象になった。** 例: 同じ `key` で、列幅の単位 U1 と固定 40 の単位 U2 がある。U2 は C (`sig=a`) が始めて D (`sig=b`) と共有している。U1 側のアイテム A が `sig=a` → `sig=a2` に変わると、U2 の進行中の URL `sig=a` は「変更したアイテムの直前の URL」に当たる。そのため U2 は D の `sig=b` で始め直す (C はまだ `sig=a` を宣言している)。同様に、持ち主のいない URL で走る単位 (始めたアイテムが外れた後の単位) も、別の幅の単位での URL 変更をきっかけに始め直す。コードの読解による確認で、プローブは走らせていない
  - 同じ URL は同じ署名で同じ期限と考えれば、「変更したアイテムの直前の URL は失効し得る」という規則の趣旨に合う。始め直した要求は取得済みなら `key` でキャッシュに当たるので、費用は取り消しと要求 1 回ずつにとどまる。spec の Scenario にも反しない。蒸留で concepts の「任意キー」の節を書くとき、始め直しのきっかけは「その画像のどの幅の単位でも」だと添えておくと、読む人が挙動を追いやすい
- review-004 の観察 (iOS で、枠の大きさが一時的に 0 になる組み立てのとき、保持画像を捨てる) は、サイクル 4 で該当コードに触れていないので前回のまま。tasks 6.6 (iPhone 実機) の機会に、自己サイズ調整の画面で消去の後の見え方を併せて見ておくとよい

## アクションプラン

1. 指摘なし。合意どおり tasks 6.6 (iPhone 実機) と 8.x (完了時の計測) へ進む
2. (蒸留時・任意) 上の観察の、始め直しのきっかけが識別子単位であることを concepts の「任意キー」の注意に 1 行添える
