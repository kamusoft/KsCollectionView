# Exploration: test-suite-speedup-and-pruning

## 課題 / 動機

テストの実行に時間がかかりすぎて、実用に耐えない (オーナーの指摘、2026-10-03)。テストの高速化と、無駄なテストの整理を行いたい。

`sample-group-header-spacing-color` (S 級、Sample の色 1 つの変更) の独立レビューで起きたこと:

- レビュアーが iOS Sample の UI テストを全件回し始め、28 分を超えても終わらなかった。44 件のうち 39 件まで進んだ時点で、オーナーの指示で切り上げた (残りは `ReorderDemoUITests` の 5 件)
- 変更に関係する UI テスト (見出しの帯の色や画素の色を見るテスト) は 1 件も無かった

過去にも同じ種類の痛みが記録されている:

- `drag-reorder` の 4 周目のレビューに約 2 時間 24 分かかった (`kasane/lessons/inbox/scope-test-reruns-per-review-cycle.md`)

この探索で分かっている規模 (2026-10-03 時点):

| 系統 | 件数 | 所要 |
|---|---|---|
| iOS 本体 (`ios/`) | 530 | 未計測 |
| iOS Sample の UI テスト (`samples/ios/KsCollectionViewSamplesUITests/`) | 44 | 39 件で 28 分超 |
| Android 本体 (`android/`) | 474 | 未計測 (ビルドとあわせて約 30 秒の実行例あり) |
| Android Sample (`samples/android/`) | 163 | 未計測 |

オーナーの依頼で簡易起票した。

### 探索での計測 (2026-10-03)

| 系統 | 件数 | 所要 | 出どころ |
|---|---|---|---|
| iOS 本体 | 530 | テスト区間 約 179 秒 (ビルドは別) | 実測 (同日の結果ファイル、iPhone 17 / iOS 27.0) |
| iOS Sample の UI テスト | 44 | 約 28〜30 分 | 推定 (記録の積み上げ。全件の結果ファイルは残っていない) |
| Android 本体 | 474 | 17 秒 (全タスクのやり直し込み) | 実測 (失敗 0) |
| Android Sample | 163 | 12 秒 (同上) | 実測 (失敗 0) |

- 時間の約 9 割は iOS Sample の UI テスト。Android は 2 系統あわせて 30 秒で、削る対象にならない
- iOS Sample の UI テストは全件が毎回アプリを起動する (1 件あたり最低 6〜7.5 秒)。並列実行の設定は無い
- 重いもの: 10,000 件を末尾までスワイプし続けるテスト (上限 900 秒)、項目を 100 件ぶんドラッグで運ぶ準備をする 2 件 (合計 約 340 秒)、グループの操作を繰り返す 2 件 (合計 約 56 秒)
- 44 件のうち、ライブラリ本体のテストに同じ振る舞いの検証がある候補が約 20 件 (ページング 8・並べ替え 8・グループ 3・長押しとタップ 1)、UI テストでなくても確かめられる候補が約 13 件 (メニューの並び・起動引数の解釈・設定の保存など)。テスト名とコードの対応からの見立てで、アサーション単位の突き合わせは未実施
- iOS 本体は直列で動いていて、時間を使うのは画面に載せて実レイアウトを収束させる群 (上位 10 クラスで約 149 秒)
- この作業場所には Android のビルドルートの `local.properties` が無く、計測は SDK の場所を環境変数で渡して行った

### 44 件の仕分け (2026-10-04、ソースの読解による。実行なし)

略記: UI = `samples/ios/KsCollectionViewSamplesUITests`、L = `ios/Tests/KsCollectionViewTests`、S = `samples/ios/KsCollectionViewSamples`。行番号は UI テストのファイル内の位置。

- 本体のテストに本物のタッチを通すものは無い。並べ替えは delegate 相当の関数を直接呼び (L/KsReorderTestSupport.swift:177-198)、ページングは位置の代入 (L/KsPagingTestSupport.swift:184)、引っ張りは開始の関数の直呼び (L/KsPullToRefreshTests.swift:519-527)、タップと長押しも直呼び
- 区分の件数 (確定): 残す 10 / 消す 8 / 移す 25 / C1 へ合流 1
- 残す 10 件の所要の見当 (推定): 約 2.8 分

| # | クラス / テスト (行) | 区分 | 根拠 |
|---|---|---|---|
| A1 | Appearance / 保存が無ければシステム (:29) | 移す | `SampleAppearance.initial` |
| A2 | Appearance / ダークを選んで起動し直し (:39) | 残す | 実タップ + 保存 + 再起動 |
| A3 | Appearance / 見出しと 3 項目の並び (:59) | 移す | 並びは View に埋まる (S/RootMenuView.swift:13-28)。切り出しが要る |
| G1 | Grouping / メニューの並び (:9) | 移す | `SampleScreen.allCases` |
| G2 | Grouping / 開いて反転 (:32) | 残す | グループの 1 件 |
| G3 | Grouping / 別のグループへ移す (:52) | 移す | `GroupingDemoEdits.movingItem` + L/KsGroupingEngineTests.swift:789 |
| G4 | Grouping / 差分更新の操作 (:76) | 移す | `DiffUpdateModel` + L/KsGroupingEngineTests.swift:679,699 |
| G5 | Grouping / 繰り返しても不正にならない (:121) | 移す | `DiffUpdateModel` の不変条件 |
| G6 | Grouping / 崩してからグループあり (:150) | 移す | `DiffUpdateModel.setGrouped` |
| IG | ImageGridCount / 件数の指定で末尾に届く (:10) | 移す | `ImageGridCount.resolve(arguments:)` |
| C1 | SlotShownClipping / 切り取られた範囲 (:11) | 残す | Sample だけの型。実描画の周期が要る |
| C2 | SlotShownClipping / 周期が止まり再開 (:36) | C1 へ合流 | 本体に対応なし。C1 と同じ画面・同じ操作の続き |
| S1 | Slot / sized が出る (:11) | 消す | S2 の前段が同じアサーション (UI/ImageLoadingSlotUITests.swift:34-38) |
| S2 | Slot / 印を叩くと数え直される (:29) | 残す | 実レイアウト + 実タップ。計測ドライバの前提 |
| I1 | Interactive / セル内のボタンの実タップ (:5) | 残す | L/KsCollectionEngineTests.swift:424 は直呼び |
| I2 | Interactive / 長押し宣言時はタップを発火しない (:24) | 残す | L/KsCollectionEngineTests.swift:399 は直呼び |
| I3 | Interactive / 未宣言時は保持でもタップ (:37) | 消す | L/KsCollectionEngineTests.swift:2459 |
| L1 | LargeData / 件数の指定で開く (:9) | 移す | `LargeDataCount.resolve` |
| L2 | LargeData / 数え直すと前の分が入らない (:37) | 残す | 実スワイプ。本体に同じ検証は見つからず |
| L3 | LargeData / 0 で起動しない (:118) | 移す | `resolve` が不正を返すこと。起動を止める配線は覆えない |
| L4 | LargeData / 数値でない値 (:123) | 移す | 同上 |
| P1 | Paging / メニューの位置 (:36) | 移す | `SampleScreen.allCases` |
| P2 | Paging / 遅延を縮めて直接開く (:62) | 移す | `PagingDelay.resolve`。画面の指定の解釈は切り出しが要る (S/SampleLaunchView.swift:35-38) |
| P3 | Paging / 最初の読み込み中の表示 (:74) | 消す | L/KsPagingDisplayTests.swift:71,195,373 |
| P4 | Paging / スクロールで続きを読み込む (:91) | 残す | L/KsPagingTriggerTests.swift:26 は位置の代入 |
| P5 | Paging / 最後まで読むと終端 (:103) | 移す | `PagingDemoSource.fetch` の最終ページ + L/KsPagingDisplayTests.swift:28,153 |
| P6 | Paging / 次のページの失敗と再試行 (:122) | 移す | `PagingDemoModel` + L/KsPagingDisplayTests.swift:321 |
| P7 | Paging / 最初の読み込みの失敗 (:145) | 移す | `PagingDemoModel.refresh` + L/KsPagingDisplayTests.swift:344 |
| P8 | Paging / 0 件で空の表示 (:162) | 移す | `PagingDemoModel.setEmpty` + L/KsPagingDisplayTests.swift:28 |
| P9 | Paging / 途中から再読み込みで先頭 (:176) | 消す | L/KsPagingPositionTests.swift:104,199 |
| P10 | Paging / 古いページが混ざらない (:193) | 移す | `PagingDemoModel` の世代の検査 |
| P11 | Paging / 項目があるときの取り直しの失敗 (:220) | 残す | 実際の引っ張りと帯の位置。本体に指で引っ張る確認は無い |
| P12 | Paging / 畳んで広げる (:260) | 消す | オーナー判断で不要。代わりは足さない |
| P13 | Paging / 末尾の表示が操作に隠れない (:282) | 消す | オーナー判断で不要。代わりは足さない |
| R1 | Reorder / メニューの位置 (:31) | 移す | `SampleScreen.allCases` |
| R2 | Reorder / 直接開くと初期の並び (:57) | 移す | `ReorderDemoModel` の初期値 |
| R3 | Reorder / 項目を並べ替える (:75) | 残す | L/KsReorderEngineTests.swift:430 はドライバ経由 |
| R4 | Reorder / 別のグループへ動かす (:92) | 移す | `ReorderDemoModel.applying` + L/KsReorderEngineTests.swift:692 |
| R5 | Reorder / 動かせない項目 (:108) | 消す | L/KsReorderEngineTests.swift:875 |
| R6 | Reorder / スイッチを切ると長押しの知らせ (:124) | 移す | モデルの知らせ + L/KsReorderEngineTests.swift:29,1322 |
| R7 | Reorder / オンの間は知らせが出ない (:140) | 消す | L/KsReorderEngineTests.swift:1279 |
| R8 | Reorder / 受け入れないと元に戻る (:154) | 移す | `ReorderDemoModel.move` + L/KsReorderEngineTests.swift:615 |
| R9 | Reorder / グループをまたがせない (:172) | 移す | `ReorderDemoModel.canDrop` + L/KsReorderEngineTests.swift:890,922 |
| R10 | Reorder / グリッドとグループなし (:198) | 移す | `applying` (グループなし) + L/KsReorderEngineTests.swift:126 |

移す先を作るときの注意 (調査で分かったこと):

- Sample の型は全て internal。ユニットテストから呼ぶにはテスト用の参照の設定が要る見込み (既定値は未確認)
- 切り出しが要るもの: 画面の指定と確認用の引数の解釈 (S/SampleLaunchView.swift:5-38)、メニューの行の並び (S/RootMenuView.swift:13-28)、外観の保存の消去 (S/SampleAppearance.swift:53-56)
- `PagingDemoModel.refresh()` は一覧からの知らせを待ち続ける (S/PagingDemoModel.swift:58,99-102)。帯の 3 秒は実時間の待ちで差し替え口が無い (S/PagingDemoModel.swift:114、S/ReorderDemoModel.swift:73)
- 件数の解釈の結果は起動時に固定される。件数ごとの項目の生成を確かめるには、件数を引数に取る関数が要る
- 計測スキーム (`KsCollectionViewSamplesPerformance`) の除外はクラス名の指定。ImageGridCount のクラスが消えると除外の項目が宙に浮く。新設するユニットテストのターゲットは計測スキームに入れない。計測ドライバは S2 が確かめる印のタップを前提にしている

## 検討した選択肢 (却下案と理由を含む)

### 「10 分」の数え方

- 採用: 4 系統を順に流した、ビルド込みの待ち時間の合計 (待たされるのはコマンド開始から結果までで、体感と合う)
- 却下: テストが走っている時間だけで数える (実際の待ち時間が 10 分を超えうる)
- 却下: 系統ごとに 10 分以内 (全部流すと最大 40 分の余地が残る)

### UI テストでなくても確かめられる約 13 件の扱い

- 採用: 画面を起動しないテストに書き直して残す (確認は残り、ビルド込みで 20〜30 秒の見込み。未計測)
- 却下: そのまま消す (iOS の Sample のメニューの並び・起動引数・設定の保存が崩れてもテストで気づけない)
- 却下: メニューの並びの確認だけを残す UI テスト 1 件に寄せ、ほかは消す (起動引数の解釈と設定の保存を確かめなくなる)

### iOS Sample の UI テストを約 4 分に収める方向

配分の見当: iOS 本体 約 4 分 (ビルド込みの見込み)・Android 30 秒・残り約 5 分に iOS Sample の UI テストをビルド込みで収める。

- 採用: 重複を消して、実際の操作でしか確かめられないものだけ残す (44 → 12 件前後、2〜3 分の見込み)。機能ごとに実際の指の操作を通すテストを 1 件ずつ残す (本体のテストが本物のタッチの経路を通っているとは限らないため)
- 却下: 件数を保って速くする (データを縮める起動引数・並列実行)。8〜12 分の見込みで 10 分に入らない可能性が高く、Sample にテスト専用の引数が増える
- 却下: 二段構え (普段は軽いものだけ、重いものは別枠)。テスト実行規約の「完了判定は全件」の改訂が要り、別枠は流されなくなって腐りやすく、全部流すと 10 分を超える

## 決定事項

- iOS Sample の UI テストは、ライブラリ本体のテストと重なるもの・UI テストでなくても確かめられるものを消し、実際の操作でしか確かめられないものだけ残す (オーナー採用、2026-10-03)。消す前に、対応する本体のテストとアサーション単位で突き合わせる
- UI テストでなくても確かめられる約 13 件 (メニューの並び・起動引数の解釈・設定の保存と復元など) は、消さずに、画面を起動しないテストへ書き直して残す。iOS の Sample にその置き場 (ユニットテストのターゲット) を新設する (オーナー採用、2026-10-03。理由は「検討した選択肢」)
- P12 (操作パネルを畳んで広げる) と P13 (末尾の表示が操作パネルに隠れない) は消す。代わりの確認は足さない (オーナー判断、2026-10-04:「どう考えてもいらない」)
- C2 (計測用の見張りの停止と再開) は、残す C1 の末尾に確認をつなげて 1 件にする (オーナー採用、2026-10-04。同じ画面・同じ操作の続きで、起動は増えない)
- P11 (実際に引っ張って更新し、失敗の帯を確かめる) は UI テストに残す (オーナー採用、2026-10-04。指で引っ張る経路を通す確認がほかに無い)
- 仕分けの確定: UI テストに残す 10 件 (A2・G2・C1 (C2 を合流)・S2・I1・I2・L2・P4・P11・R3、約 2.8 分の見込み)、消す 8 件 (S1・I3・P3・P9・P12・P13・R5・R7)、起動しないテストへ移す 25 件、C1 へ合流 1 件 (C2)
- 完了の条件: 4 系統 (新設する iOS Sample のユニットテストを含む) を順に流して、ビルド込みの合計が 10 分以内であることを実測で確かめる。超えたら同じ変更の中で iOS 本体のテスト (約 3 分、直列) を速くする
- 完了判定に絞り込みなしの全件実行を使う決まり (テスト実行規約) は変えない
- Android の 2 系統は対象にしない (合わせて 30 秒)
- 蒸留時に反映: `kasane/handbook/cross/test-execution.md` — 合計 10 分の上限と、Sample の UI テストに置くものの線引き

- 目標: テスト 4 系統 (iOS 本体・iOS Sample の UI テスト・Android 本体・Android Sample) を順に流したときの、コマンド開始から結果が出るまでの待ち時間の合計を、ビルド込みで最大 10 分以内に抑える (オーナー指定、2026-10-03。ビルドは差分ビルドの状態で数える)

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

- 作成済み: cross/ADR-0008 (proposed) — テスト全系統の合計を 10 分以内に保ち、Sample の UI テストは実際の操作でしか確かめられないものに絞る

## 未決の論点

- 計測スキームが Appearance・Grouping・Paging・Reorder・Slot・Clipping を除外しておらず、絞り込みなしで流すと一緒に走る。計測の手順が対象を絞っているかは未確認
- iOS 本体のテストを速くする手段 (合計が 10 分を超えた場合だけ要る。並列実行の成立は未確認)
- レビュー・検証のたびに全系統を流し直す運用 (教訓 `scope-test-reruns-per-review-cycle`) は、この変更の対象外

## UI 素材 (ui/references/ の一覧と注釈)

## 変更級の推奨: S / M / L (理由)

S (オーナー確定、2026-10-04)

- 触る範囲: iOS Sample の UI テスト、iOS Sample に新設するユニットテストのターゲット、抜けが見つかった場合の iOS 本体のテストへの追加。製品のコードはテストから呼べるように切り出す程度
- 公開 API の変更なし・可逆 (テストの削除と追加)・画面の見た目の変更なし
- 消す根拠は本メモの仕分け表が持つ。決定記録は cross/ADR-0008、テスト実行規約への追記は蒸留時に反映
