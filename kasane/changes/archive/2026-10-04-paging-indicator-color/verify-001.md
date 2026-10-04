# 検証結果: paging-indicator-color (001 回目)

**日付**: 2026-10-04
**判定**: INVALID (❌ 1 件 — デルタスペックの Scenario はすべて一致か記録済みの乖離。❌ は `ui/brief.md` の基準に対する未記録の乖離)

## 対応表

テストの略記: iOS = `ios/Tests/KsCollectionViewTests/KsLoadingIndicatorColorTests.swift`、Android = `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsLoadingIndicatorColorTest.kt`。

### collection-paging — Requirement: 読み込み中の表示の色

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 設定を 1 つ持つ (Requirement 本文) | `ios/Sources/KsCollectionView/KsCollectionView.swift:310` / `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:193` | `ios/Tests/KsCollectionViewTests/KsPublicAPITests.swift` (test読み込み中の表示の色を指定すると構成に入り指定しなければ無い) / `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsCollectionViewPublicApiTest.kt` (collectionAcceptsLoadingIndicatorColor) | ✅ 一致 |
| Scenario: 次のページの読み込み中に効く | `ios/Sources/KsCollectionView/KsPagingDisplays.swift` (`content(for:retry:loadingIndicatorColor:)`)・`ios/Sources/KsCollectionView/KsPagingDefaultProgress.swift` / `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsPaging.kt:104` | iOS:37 / Android:70 | ✅ 一致 |
| Scenario: 最初の読み込み中に効く | 同上 / `KsPaging.kt:108` | iOS:37 (0 件の追加読み込み中と取り直し中の両方) / Android:80 (同) | ✅ 一致 |
| Scenario: Pull to Refresh のインジケータに効く | `ios/Sources/KsCollectionView/KsCollectionViewController.swift:2232`・`ios/Sources/KsCollectionView/KsRefreshControl.swift:25` / `KsCollectionView.kt:918` | iOS:46 (部品に渡る色が、指定した色を補正した値であること) / Android:95 | iOS: ⚠️ deviation 記録済み (色みは指定どおり、濃さは標準と同じ) / Android: ✅ 一致 |
| Scenario: ページングを付けない一覧でも効く | 同上 (色を合わせる箇所は取り直しの処理の有無の判定より前) | iOS:46 (ページングなしの周) / Android:107 | iOS: ⚠️ deviation 記録済み / Android: ✅ 一致 |
| Scenario: 差し替えた表示には効かない | `KsPagingDisplays.swift` (差し替えた表示には色を渡さない) / `KsPaging.kt:104`・`:108` | iOS:66 / Android:124 | ✅ 一致 |
| Scenario: 表示中に色を変える | iOS: 更新のたびに表示の中身と部品の色を入れ直す (`KsCollectionViewController.swift:2134`・`:2232`) / Android: 引数の再コンポーズ | iOS:101 (読み込み中の 2 つ)・iOS:113 (Pull to Refresh) / Android:145・157・169 | 読み込み中の 2 つ: ✅ 一致 / iOS の Pull to Refresh: ⚠️ deviation 記録済み / Android の Pull to Refresh: ✅ 一致 |
| Scenario: 並べ替えのドラッグ中に色を変える (iOS) | `KsCollectionViewController.swift:237` (ドラッグ中は構成を控える既存の経路) | iOS:176 | ✅ 一致 |
| Scenario: Android の下地は変わらない | `KsCollectionView.kt:918` (矢印の色だけ渡し、下地の色は渡さない) | Android:95・107・169・209 (下地がテーマの色)・Android:238 (色を指定しない一覧の下地も同じテーマの色) | ✅ 一致 |
| 読み込み中の表示の色 — Side Effects (なし) | 構成の値の保持と描画だけで、永続化・送信は無い | — | ✅ 一致 |

### collection-paging — Requirement: 色を指定しないときの読み込み中の表示

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| Scenario: 指定しない一覧は標準の色のまま | `KsPagingDefaultProgress.swift` (色が無ければ tint を付けない)・`KsRefreshControl.swift:28` (nil なら `tintColor` も nil) / `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsPagingDisplay.kt` (material3 の既定の色)・`KsCollectionView.kt:918` | iOS:202 (親の tint に従い、変えると追随)・iOS:221 (作ったばかりの標準の部品と同じ色) / Android:225 (テーマの primary)・Android:238 (material3 の既定) | ✅ 一致 |
| Scenario: 表示中に指定を外す | 同上 | iOS:131 (読み込み中の 2 つ)・iOS:156 (Pull to Refresh) / Android:185・197・209 | ✅ 一致 |
| 色を指定しないときの読み込み中の表示 — Side Effects (なし) | 同上 | — | ✅ 一致 |

### samples — Requirement: デモ画面「ページング」の読み込み中の表示の色

proposal は Sample に自動テストを足さず、mock との視覚照合で確かめると決めている。テストの列は証跡を書く。

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| Scenario: 3 つの表示が同じ色でそろう | `samples/ios/KsCollectionViewSamples/PagingDemoView.swift:102` / `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/PagingDemoScreen.kt:153` | `ui/verification/` の `*-first-loading-*`・`*-appending-*`・`*-pull-to-refresh-*` (12 枚)。iOS の Pull to Refresh はこの検証で撮り直して再現 (ダーク `#565F73`、ライト `#A8A9AF`) | Android: ✅ 一致 / iOS: ⚠️ deviation 記録済み (Pull to Refresh は色みが同じで薄い) |
| Scenario: 両プラットフォームで同じ色 | 両方とも `SampleTheme.secondaryText` | 既存の `SamplePaletteParityTest` (Android Sample の 163 件に含まれ、成功) | ✅ 一致 |
| Scenario: 外観の切り替えに追随する | iOS は表示モードで解決される色、Android は選んだ外観の配色 | `ui/verification/` のライト / ダークの組。iOS はこの検証で、起動したまま表示モードを切り替えて Pull to Refresh の色が変わることを確認 | ✅ 一致 |
| Scenario: ほかの表示は変わらない | Sample の diff は色の指定の 1 行だけ。ライブラリは色を既定の読み込み中の表示にしか渡さない | `ui/verification/` の `*-failed-footer-*`・`*-failed-placeholder-*`・`*-empty-*` (brief の照合結果。iOS・ライトは変更前との比較なし、終端の表示は未撮影) | ✅ 一致 (証跡は一部だけ。失敗・終端・空の表示と操作のパネルを描くコードは diff に無い) |
| デモ画面「ページング」の読み込み中の表示の色 — Side Effects (なし) | 表示だけ | — | ✅ 一致 |

## 追加検査

- tasks.md: 1.1〜3.2 はチェック済みで、対応表の実装と一致する (虚偽チェックなし)。4.1 (視覚照合) はオーナーの最終承認待ち、4.2 (4 系統の全件テスト) はこの検証で実行済みで、どちらも未チェック
- 逆流検査: proposal・specs の更新時刻は実装のファイルより前で、書き換えた形跡は無い。足場は未コミットのため `git log` では確かめられない
- 未記録乖離 (Scenario): なし
- Side Effects (逆向きの検査): 2 能力とも、実装が起こす状態変更は構成の値の保持と描画だけで、「なし」に収まる
- 付随修正: `deviation.md` に `[付随修正]` の行は無い。Scenario に対応しない diff は、iOS の既定の表示の型の統合 (`KsPagingDefaultIndicator.swift` の削除) と既存の doc コメントの書き足しで、どちらも proposal の What Changes と tasks 1.2・1.4・2.4 にある
- UI 変更: brief に承認モックの記録あり (案 A、2026-10-04)。合意済み妥協は iOS の Pull to Refresh の濃さと iOS・ダークのコントラスト比 約 2.9 の 2 件
  - ❌ **iOS・ライトの Pull to Refresh のコントラスト比 約 2.1 が、brief の「視認性の基準」(3 以上) に届かず、`deviation.md` にも合意済み妥協にも記録が無い** (brief の照合結果が「未合意」と書いている。この検証の撮影でも `#A8A9AF` / 下地 `#F2F2F7` を再現)
  - 見立て: deviation として合意すべき。原因はダークと同じ標準の部品の濃さの上限で、記録済みの乖離を採る限り実装では直せない
- テスト: 4 系統を絞り込みなしで実行し、全件成功
  - iOS ライブラリ 545 件 / 失敗 0 (159 秒)
  - iOS Sample 48 件 (ユニットテスト 37・UI テスト 11) / 失敗 0 (174 秒)
  - Android ライブラリ 488 件 / 失敗 0 (19 秒)
  - Android Sample 163 件 / 失敗 0 (13 秒)
  - 4 系統を順に流した壁時計の合計 365 秒 (6 分 5 秒)。iOS は専用のシミュレータ (iPhone 17・iOS 27.0) で、終わってから削除した

## 判定

INVALID。デルタスペックの Requirement / Scenario は、すべて「一致」か「deviation 記録済み」で、虚偽チェック・逆流・テストの失敗は無い。❌ は brief の基準に対する未記録の乖離 1 件だけで、オーナーが合意して `deviation.md` と brief に記録すれば VALID になる。
