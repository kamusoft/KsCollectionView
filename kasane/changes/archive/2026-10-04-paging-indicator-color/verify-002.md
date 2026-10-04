# 検証結果: paging-indicator-color (002 回目)

**日付**: 2026-10-04
**判定**: VALID (❌ 0 件。⚠️ deviation 記録済み 4 行)

001 回目の ❌ (iOS・ライトの Pull to Refresh のコントラスト比 約 2.1 が未記録) は、`deviation.md` の 3 行目と `ui/brief.md` の「合意済み妥協」3 件目に記録が入り、合意済みの差分になった。001 回目の後にコードは変わっていない (実装とテストのファイルの更新時刻は、いちばん新しいもので 16:53。001 回目の出力は 17:12)。この回は、全 Scenario の対応をコードとテストから読み直した。

## 対応表

テストの略記: iOS = `ios/Tests/KsCollectionViewTests/KsLoadingIndicatorColorTests.swift`、Android = `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsLoadingIndicatorColorTest.kt`。

### collection-paging — Requirement: 読み込み中の表示の色

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 設定を 1 つ持つ (Requirement 本文) | `ios/Sources/KsCollectionView/KsCollectionView.swift:310` / `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:193` | `ios/Tests/KsCollectionViewTests/KsPublicAPITests.swift` (test読み込み中の表示の色を指定すると構成に入り指定しなければ無い) / `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsCollectionViewPublicApiTest.kt` (collectionAcceptsLoadingIndicatorColor) | ✅ 一致 |
| Scenario: 次のページの読み込み中に効く | `ios/Sources/KsCollectionView/KsPagingDisplays.swift:22`・`ios/Sources/KsCollectionView/KsPagingDefaultProgress.swift`・`ios/Sources/KsCollectionView/KsCollectionViewController.swift:2130` / `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsPaging.kt:104`・`KsCollectionView.kt:883` | iOS:37 (項目 40 件・追加読み込み中で、部品の色が指定した色) / Android:70 (指定した色の画素があり、テーマの primary の画素は 0) | ✅ 一致 |
| Scenario: 最初の読み込み中に効く | `KsPagingDisplays.swift:28` / `KsPaging.kt:108`・`KsCollectionView.kt:862` | iOS:37 (0 件の追加読み込み中と取り直し中の両方) / Android:80 (同) | ✅ 一致 |
| Scenario: Pull to Refresh のインジケータに効く | `KsCollectionViewController.swift:2232`・`ios/Sources/KsCollectionView/KsRefreshControl.swift:25` / `KsCollectionView.kt:918` | iOS:46 (ページングありの周。部品に渡る色が、指定した色を成分ごとの平方根で補正した値)・iOS:241 (補正した色を 2 乗すると指定した色に戻る) / Android:95 | iOS: ⚠️ deviation 記録済み (色みは指定どおり、濃さは標準と同じ) / Android: ✅ 一致 |
| Scenario: ページングを付けない一覧でも効く | 同上 (色を合わせる行 `:2232` は、取り直しの処理の有無の判定より前で、ページングの有無を見ない) / `KsCollectionView.kt:918` (ページングの有無を見ない) | iOS:46 (ページングなしの周) / Android:107 | iOS: ⚠️ deviation 記録済み / Android: ✅ 一致 |
| Scenario: 差し替えた表示には効かない | `KsPagingDisplays.swift:22`・`:28` (差し替えた中身には色を渡さずそのまま返す) / `KsPaging.kt:104`・`:108` (同) | iOS:66 (色を付けた差し替えはその色、色を付けない差し替えは色を指定しない一覧と同じ色。3 つの状態で) / Android:124 (差し替えた 2 つとも、指定した色の画素が 0) | ✅ 一致 |
| Scenario: 表示中に色を変える | iOS: 更新のたびに表示の中身と部品の色を入れ直す (`KsCollectionViewController.swift:2134`・`:2232`) / Android: 引数の再コンポーズ (`KsCollectionView.kt:883`・`:862`・`:918`) | iOS:101 (読み込み中の 2 つ)・iOS:113 (Pull to Refresh。インジケータは出たまま) / Android:145・157・169 | 読み込み中の 2 つ: ✅ 一致 / iOS の Pull to Refresh: ⚠️ deviation 記録済み / Android の Pull to Refresh: ✅ 一致 |
| Scenario: 並べ替えのドラッグ中に色を変える (iOS) | `KsCollectionViewController.swift:237` (ドラッグ中に届いた構成を控える既存の経路。色だけを先に当てる経路は無い) | iOS:176 (ドラッグの間は前の色、終わると新しい色) | ✅ 一致 |
| Scenario: Android の下地は変わらない | `KsCollectionView.kt:918` (矢印の色だけ渡し、下地の色は渡さない) | Android:95・107・169・209 (色を指定した一覧の下地がテーマの色)・Android:238 (色を指定しない一覧の下地も同じテーマの色) | ✅ 一致 |
| 読み込み中の表示の色 — Side Effects (なし) | 構成の値の保持 (`ios/Sources/KsCollectionView/KsCollectionConfiguration.swift:38`) と描画だけ。永続化・送信・通知は無い | — | ✅ 一致 |

### collection-paging — Requirement: 色を指定しないときの読み込み中の表示

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| Scenario: 指定しない一覧は標準の色のまま | `KsPagingDefaultProgress.swift` (色が無ければ tint を付けない)・`KsRefreshControl.swift:28` (nil なら `tintColor` も nil) / `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsPagingDisplay.kt` (null なら material3 の既定の色)・`KsCollectionView.kt:918` (null なら material3 の既定の色) | iOS:202 (読み込み中の 2 つが親の tint に従い、変えると追随)・iOS:221 (作ったばかりの標準の部品と同じ色。ページングの有無の両方) / Android:225 (テーマの primary)・Android:238 (矢印と下地が material3 の既定) | ✅ 一致 |
| Scenario: 表示中に指定を外す | 同上 | iOS:131 (読み込み中の 2 つが、色を指定しない一覧と同じ色になる)・iOS:156 (Pull to Refresh の部品の色が nil になり、標準の部品と同じ色) / Android:185・197・209 | ✅ 一致 |
| 色を指定しないときの読み込み中の表示 — Side Effects (なし) | 同上 | — | ✅ 一致 |

### samples — Requirement: デモ画面「ページング」の読み込み中の表示の色

proposal は Sample に自動テストを足さず、mock との視覚照合で確かめると決めている。テストの列は証跡を書く。

| Requirement / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| Scenario: 3 つの表示が同じ色でそろう | `samples/ios/KsCollectionViewSamples/PagingDemoView.swift:102` / `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/PagingDemoScreen.kt:153` | `ui/verification/` の `*-first-loading-*`・`*-appending-*`・`*-pull-to-refresh-*` (12 枚) と `ui/brief.md` の照合結果 | Android: ✅ 一致 / iOS: ⚠️ deviation 記録済み (Pull to Refresh は色みが同じで薄い。`deviation.md` の 1〜3 行目、brief の合意済み妥協 3 件) |
| Scenario: 両プラットフォームで同じ色 | 両方とも `SampleTheme.secondaryText` (`samples/ios/KsCollectionViewSamples/SampleTheme.swift:13` / `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/SampleTheme.kt:41`) | 既存の `samples/android/app/src/test/kotlin/jp/kamusoft/kscollectionview/samples/android/SamplePaletteParityTest.kt` (期待値: ライト `#6E7076`、ダーク `#8E9AB3`) | ✅ 一致 |
| Scenario: 外観の切り替えに追随する | iOS は表示モードで解決される色 (Pull to Refresh は外観ごとに解決してから補正 — `KsRefreshControl.swift:42`)、Android は選んだ外観の配色を読む色 | `ui/verification/` のライト / ダークの組。ライブラリ側は iOS:263・iOS:294 (表示モードを切り替えると Pull to Refresh の部品の色が追随) | ✅ 一致 |
| Scenario: ほかの表示は変わらない | Sample の diff は色の指定の 1 行ずつだけ。ライブラリは色を既定の読み込み中の表示と Pull to Refresh にしか渡さない | `ui/verification/` の `*-failed-footer-*`・`*-failed-placeholder-*`・`*-empty-*` と brief の照合結果 (iOS・ライトは変更前との比較なし、終端の表示は未撮影) | ✅ 一致 (証跡は一部だけ。失敗・終端・空の表示と操作のパネルを描くコードは diff に無い) |
| デモ画面「ページング」の読み込み中の表示の色 — Side Effects (なし) | 表示だけ | — | ✅ 一致 |

## 追加検査

- tasks.md: 1.1〜4.2 の全タスクがチェック済みで、対応表の実装・テスト・証跡と一致する (虚偽チェックなし)。4.1 は brief の照合結果に最終承認 (2026-10-04) と 24 枚の記録があり、4.2 は 001 回目の全件実行の結果と一致する
- 逆流検査: proposal・specs の更新時刻 (14:56〜15:09) は、実装で最初に変わったファイル (15:13) より前で、書き換えた形跡は無い。足場は未コミットのため `git log` / `git diff` では確かめられず、更新時刻で確かめた。実装の後に変わったのは `tasks.md` (チェック)・`deviation.md`・`ui/brief.md` (合意済み妥協・照合結果) で、どれも実装期間に書く欄である
- 未記録乖離: なし。001 回目の ❌ は `deviation.md` の 3 行目に記録済み
- deviation.md の乖離 4 行と実装の突き合わせ:
  - 1 行目 (iOS の Pull to Refresh は色みが指定どおり・濃さは標準と同じ): `KsRefreshControl.swift:42` の補正と iOS:46・113・241 が記録どおり
  - 2・3 行目 (iOS・ダーク 約 2.9、iOS・ライト 約 2.1): brief の合意済み妥協と照合結果の表が同じ値で書いている
  - 4 行目 (Android で、中身のブロックまで括弧の中に位置で並べる呼び出しだけがコンパイルできなくなる): `KsCollectionView.kt:193` は `reorder` の次・`content` の前に足していて、互換用の別の入口は無く、記録どおり
- Side Effects (逆向きの検査): 2 能力・3 Requirement とも、実装が起こす状態変更は構成の値の保持と描画だけで、「なし」に収まる
- 付随修正: `deviation.md` に `[付随修正]` の行は無い。Scenario に対応しない diff は、iOS の既定の表示の型の統合 (`ios/Sources/KsCollectionView/KsPagingDefaultIndicator.swift` の削除。参照の残りは無い) と既存の doc コメント・KDoc の書き足しで、どちらも tasks 1.2・1.4・2.4 にある。Scenario に無いテスト (iOS:241・263・282・294) は、1 行目の乖離の補正の計算を確かめるもの
- 「蒸留時に反映」の 2 行 (concepts・core/ADR-0035) は実装範囲外で、検証の対象にしていない
- UI 変更: brief に承認モックの記録あり (案 A、2026-10-04 オーナー承認)。合意済み妥協は 3 件 (iOS の Pull to Refresh の濃さ、iOS・ダーク 約 2.9、iOS・ライト 約 2.1) で、`deviation.md` の 1〜3 行目と対応する。照合結果に最終承認の記録あり
- テスト: この回は実行していない (呼び出し元の指定。001 回目の全件実行の後、コードの変更なし)。001 回目の結果は 4 系統とも絞り込みなしで全件成功
  - iOS ライブラリ 545 件 / 失敗 0
  - iOS Sample 48 件 / 失敗 0
  - Android ライブラリ 488 件 / 失敗 0
  - Android Sample 163 件 / 失敗 0
  - iPhone 17・iOS 27.0 のシミュレータ

## 判定

VALID。デルタスペックの全 Requirement / Scenario (Side Effects の行を含む) が「一致」か「deviation 記録済み」で、未記録の乖離・虚偽チェック・逆流は無い。テストは 001 回目の全件成功の結果を引き継いだ (この回の再実行なし)。
