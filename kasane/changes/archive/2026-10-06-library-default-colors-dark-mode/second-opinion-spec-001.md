# セカンドオピニオン: library-default-colors-dark-mode (spec-001)
**相方**: codex / **label**: so-spec-library-default-colors-dark-mode-001 / **日付**: 2026-10-06 / **対象**: 提案一式 (kasane/changes/library-default-colors-dark-mode/ の proposal.md (「自己レビューの記録」の節を除く)・specs/ の 4 つ・tasks.md・ui/brief.md・ui/mock/default-colors-a-ios-standard.html・evidence/proposal-probes.md、kasane/decisions/core/ の 0036・0037 のドラフト)
---
実装前に修正を推奨します。Major 2 件、Minor 2 件です。

1. **Major — Android の外観判定元が、仕様の説明と一致しない**
   
   該当箇所: `kasane/changes/library-default-colors-dark-mode/specs/collection-layout/spec.md:8`、`kasane/changes/library-default-colors-dark-mode/specs/image-loading/spec.md:8`
   
   **問題点:** 「端末の表示モード」と `isSystemInDarkTheme()` を同義にしていますが、既存 Sample は Activity の Configuration を上書きし、その上書きが `isSystemInDarkTheme()` に反映される構成です（`samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/SampleAppearanceStore.kt:13`）。端末がライトでも Sample がダークなら、実装はダークを選びます。「アプリ内だけの切り替えには追随しない」という説明も、Material の配色だけを切り替える場合と Configuration を上書きする場合を区別できていません。
   
   **推奨修正:** 判定元を「Compose に届く Configuration の夜間モード。通常は端末設定に追随し、Activity 等による上書きを含む」と明記し、proposal・ADR-0036・doc コメントのタスクもそろえてください。端末ライト／Configuration ダークの Scenario を追加すると、Sample と契約の整合も確認できます。

2. **Major — 性能検証を対象外にする判断が handbook と衝突する**
   
   該当箇所: `kasane/changes/library-default-colors-dark-mode/proposal.md:57`
   
   **問題点:** 色の選び方だけの変更を理由に性能検証を除外していますが、`kasane/handbook/android/performance-verification.md:136` は区切り線の経路に触れる変更を対象とし、対象外は公開 API の形だけの変更と Sample の文言・配色変更です。今回はライブラリの区切り線と画像の描画処理を変更するため、この除外条件に入りません。
   
   **推奨修正:** 少なくとも Android の規約に沿った性能確認を tasks に追加してください。検証を省略するなら、現行規約との例外扱いを実装開始前に明示して合意する必要があります。

3. **Minor — iOS の動的な指定色を保持する契約が曖昧**
   
   該当箇所: `kasane/changes/library-default-colors-dark-mode/specs/collection-layout/spec.md:37`、`kasane/decisions/core/0036-library-default-colors-light-dark-pairs.md:26`
   
   **問題点:** 「指定した色は表示モードで変わらない」「今までどおり単色」という記述は、利用者が渡した動的な色まで固定する契約にも読めます。既存 Sample は動的な `SampleTheme.accent` を `.listSeparatorColor(_:)` に渡しています（`samples/ios/KsCollectionViewSamples/ListDemoView.swift:42`）。意図する「ライブラリが別の色に差し替えない」と、色自身の外観への追随を区別する必要があります。
   
   **推奨修正:** 現 Scenario を「固定色を指定した場合」と限定し、利用者指定の動的な色は、その色自身の解決結果を保持する Scenario とテストを追加してください。

4. **Minor — 画像取得をやり直さないことを、予定のテストでは判定できない**
   
   該当箇所: `kasane/changes/library-default-colors-dark-mode/tasks.md:30`、`kasane/changes/library-default-colors-dark-mode/tasks.md:44`
   
   **問題点:** 実装タスクは「取得の状態を作り直さない」と要求していますが、テストは色と表示状態の維持だけを確認します。切り替えで要求を取り消して再取得しても、前後とも読み込み中なら合格できます。既存の遅延描画経路は取得 Job と描画状態を同じ Node に持つため、テーマ更新による作り直しを検出する必要があります。
   
   **推奨修正:** 外観だけの変更では取得要求を再発行・取消ししない契約を spec に明記してください。通常経路と先読み待ち経路で、取得を保留したまま外観を切り替え、要求数・取消し数が増えず、同じ要求の完了結果が表示されるテストを追加してください。

「自己レビューの記録」は読まず、ビルド・テストの実行とファイル変更も行っていません。

## 突き合わせ結果

突き合わせの相手は、提案の自己レビュー (2 周。`proposal.md` の「自己レビューの記録」)。自己レビューはこの 4 件のどれも拾っていなかった。指摘の根拠の箇所は、すべて開いて確かめた (2026-10-06)。

| 指摘 | 相方の重要度 | 採否 | 根拠と反映 |
|---|---|---|---|
| 1. Android の外観判定元が、仕様の説明と一致しない | Major | 採用 | 根拠強。`samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/SampleAppearanceStore.kt:13` のとおり、Sample は画面の構成の上書きで外観を切り替え、使う判定はそれに追随する。「端末の表示モード」という言い方では、Sample の切り替えと契約が食い違って読める。提案・collection-layout と image-loading のスペック・core/ADR-0036・tasks の言い方を「画面の構成の夜間モード」に正し、上書きした場合と Material の配色だけの場合の Scenario を足した |
| 2. 性能検証を対象外にする判断が handbook と衝突する | Major | 採用 (オーナー判断で例外) | 根拠強。`kasane/handbook/android/performance-verification.md:136` の対象に区切り線の経路が明記されている。規約の例外は提案側で決められないのでオーナーに諮り、今回は行わないと決まった (2026-10-06)。理由と歯止めを `proposal.md` の Impact と `tasks.md` の冒頭に書いた |
| 3. iOS の動的な指定色を保持する契約が曖昧 | Minor | 採用 (推奨修正の一部は採らない) | 根拠強 (Sample が外観で値の変わる色を渡している)。言い方を「指定した色にライブラリは手を加えない」に直し、Scenario を固定の色に限定した。推奨修正のうち「動的な色の解決結果を保持する Scenario とテストを追加」は採らない: 提案の段階の実測で、iOS 17.5 では OS の変換の時点でライトの値に固定されると分かり (`evidence/proposal-probes.md` の 4)、今の挙動として約束できないため。iOS 17 以前の扱いは Non-Goals に書いた |
| 4. 画像取得をやり直さないことを、予定のテストでは判定できない | Minor | 採用 | 根拠強 (tasks の要求にスペックの約束とテストが対応していなかった)。約束と Scenario を足し、要求と取り消しの数を数えるテストを両プラットフォームに足した |

- 確定 (双方一致): 0 件 / 採用: 4 件 / 降格: 0 件 / 未解決: 0 件
- 採用した 4 件はすべて提案に反映済み。反映の後、スペックの全 Requirement・Scenario が tasks に対応していること、スペックに色の生値が無いこと、ADR の構造 lint とパスの lint が通ることを確かめた
