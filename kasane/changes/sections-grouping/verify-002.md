# Verify 002: sections-grouping

- 検証日: 2026-09-25
- 対象: HEAD `883ee76` 以降の作業ツリーの未コミットの変更。verify-001 から変わったのは次の 3 ファイルだけ (verify-001.md より新しいファイルを ios / android / samples / kasane の全体で探して確かめた)
  - `samples/ios/KsCollectionViewSamples/DiffUpdateModel.swift`
  - `samples/ios/KsCollectionViewSamples/DiffUpdateDemoView.swift`
  - `samples/ios/KsCollectionViewSamplesUITests/GroupingDemoUITests.swift`
- 基準: `specs/collection-core/spec.md` (6 Requirement / 12 Scenario)、`specs/collection-layout/spec.md` (ADDED 7・MODIFIED 2・REMOVED 1 Requirement / 32 Scenario)、`specs/samples/spec.md` (4 Requirement / 9 Scenario)。合計 53 Scenario
- 合意済みの差分: `deviation.md` (付随修正 5 件・合意済み乖離 10 件。verify-001 から変更なし)、`ui/brief.md` の「合意済み妥協」3 件
- 作業ドメイン: cross (core の契約 + ios + android)
- 前提: tasks 5.1〜5.7 (evidence/ に残す動作証跡) はまだ実施していない。体感・目視・計測でしか確かめられない Scenario は「未検証 (5.x)」として区別し、それだけを理由に INVALID にはしない
- 引き継ぎ: 変更の影響を受けない Scenario は verify-001 の対応をそのまま引き継いだ (ライブラリのソースとテスト、Android Sample、benchmark は verify-001 の後に変更がない)。変更の影響を受けるのは samples の Requirement「デモ画面「差分更新」」の 4 Scenario で、これは改めて突き合わせた

## 判定

**VALID**

- verify-001 の ❌ (samples「デモ画面「差分更新」」: iOS Sample でグループなしのまま並びを崩してからグループありに切り替えると debug で停止する) は解消した
  - 実装: 切り替えと並べ直しをモデルの 1 回の変更にまとめた (「❌ の解消の確認」節)
  - Simulator (iPhone 17 Pro、Debug) で、verify-001 の再現手順を含む 4 経路を実際に踏み、停止しないことを確かめた
  - UI テストに「グループなしで崩してからグループありにする」経路が加わり、通る
- 53 Scenario はすべて「✅ 一致」「⚠️ deviation 記録済み」「未検証 (5.x)」のいずれか
- 虚偽チェックなし。足場の逆流なし (proposal / design / specs は verify-001 から変わっていない。tasks.md と deviation.md も変わっていない)
- テストは全系統で全件成功 (「テストの実行」節)
- テストの守備範囲の小さな穴は「所見」節に分けた。今回、所見 10 を加えた (新しい UI テストの 2 周目は並びを崩していない)

---

## 参照の短縮名

| 短縮名 | パス |
|---|---|
| iOS 本体 | `ios/Sources/KsCollectionView/` |
| iOS テスト | `ios/Tests/KsCollectionViewTests/` |
| And 本体 | `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/` |
| And テスト | `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/` |
| iS | `samples/ios/KsCollectionViewSamples/` |
| iS-UT | `samples/ios/KsCollectionViewSamplesUITests/` |
| AS | `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/` |
| AS-T | `samples/android/app/src/test/kotlin/jp/kamusoft/kscollectionview/samples/android/` |
| AS-M | `samples/android/app/src/measurement/kotlin/jp/kamusoft/kscollectionview/samples/android/` |

テストファイル名の略記: **GE** = iOS `KsGroupingEngineTests.swift`、**CT** = iOS `KsGroupChunkTableTests.swift`、**EI** = iOS `KsEdgeInsertionTests.swift`、**CE** = iOS `KsCollectionEngineTests.swift`、**PA** = iOS `KsPublicAPITests.swift`、**SA** = iOS `KsSafeAreaTests.swift`、**G** = And `KsCollectionViewGroupingTest.kt`、**P** = And `KsGroupPlanTest.kt`、**L** = And `KsCollectionViewLayoutTest.kt`、**I** = And `KsScrollIndicatorTest.kt`、**A** = And `KsCollectionViewPublicApiTest.kt`、**C** = And `KsCollectionViewCoreTest.kt`、**S** = And `KsCollectionViewSafeAreaTest.kt`、**F** = And `KsCollectionViewPrefetchTest.kt`。行番号はテスト関数の行。

---

## 対応表: collection-core (verify-001 から引き継ぎ)

### Requirement: グループの値によるグループ化 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 続いた同じ値が 1 つのグループになる | iOS: `KsCollectionView.swift:164,186` (`groups(by:)`)、`KsGroupChunkTable.swift:32,105`<br>And: `KsGroupPlan.kt:327-404`、`KsCollectionView.kt:398-519` | iOS: CT:6、GE:54<br>And: P:38、G:88 | ✅ 一致 |
| 指定しなければ今までどおり | iOS: `KsGroupChunkTable.swift:32`<br>And: `KsGroupPlan.kt:336-348` | iOS: GE:78、CT:26、PA:251<br>And: G:101、P:81 | ✅ 一致 |
| 項目のモデルを変えずにグループ化する | iOS: `KsCollectionView.swift:164` (キーパス)<br>And: `KsGroups.kt:47-51` (ラムダ) | iOS: PA:200<br>And: A:69、G | ✅ 一致 |

表示中にグループの値の取り出し方を切り替えたときの扱いは ⚠️ deviation 記録済み (テストは iOS GE:820 / GE:859、And G:247 / G:290)。

### Requirement: グループの値の型 (Android) (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 項目のキーと同じ値のグループ | `KsGroupPlan.kt:18-46`、`KsCollectionView.kt:408-411` | G:116、P:153 | ✅ 一致 |

### Requirement: 同じグループの値が離れて現れる入力 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| release ビルドでの離れた同じ値 | iOS: `KsCollectionViewController.swift:896`、`KsInvalidInput.swift:23`<br>And: `KsGroupPlan.kt:355-384`、`KsCollectionView.kt:197,203-204` | iOS: GE:973、CT:69<br>And: G:142、G:129 (debug で停止)、P:122 | ✅ 一致 |

### Requirement: グループをまたぐ差分更新 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 項目が別のグループへ移る | iOS: `KsCollectionViewController.swift:806,820`<br>And: `KsCollectionView.kt:581,604-605` | iOS: GE:731<br>And: G:572 | ✅ 一致 (所見 1)。アニメーションの見え方は未検証 (5.2 / 5.6) |
| グループの並び順を反転する | iOS: 同上<br>And: `KsCollectionView.kt:406-433` | iOS: GE:759<br>And: G:589、G:853、G:619 | ✅ 一致 |
| 最後の項目が消えたグループ | iOS: `KsGroupChunkTable.swift:105`<br>And: `KsGroupPlan.kt:360-377` | iOS: GE:799<br>And: G:606、G:868 | ✅ 一致 |

`animateItem` の付け方 (高さの補間の間は止める、ルートのヘッダー / フッターにも付ける、試作で決めた点) は ⚠️ deviation 記録済み。

### Requirement: 端を表示中の端への挿入 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| いちばん上での先頭への挿入 | iOS: `KsCollectionViewController.swift:852`、`KsContentEdge.swift:2`<br>And: `KsPositionKeeper.kt:86-91` | iOS: EI:41<br>And: G:736、G:742、G:833、G:880 | ✅ 位置は一致。アニメーションの見え方は未検証 (5.7) |
| いちばん下での末尾への挿入 | iOS: `KsCompositionalLayout.swift:49`<br>And: `KsPositionKeeper.kt:92-99,137-153`、`KsAppearingItems.kt:58-127` | iOS: EI:69<br>And: G:748、G:754、G:903、G:909、G:916 | ⚠️ deviation 記録済み。見え方は未検証 (5.7) |
| ルートのフッターがあるときの末尾への挿入 | iOS: 同上<br>And: `KsPositionKeeper.kt:196-200` | iOS: EI:69<br>And: G:805 | ✅ 位置は一致。見え方は未検証 (5.7) |

### Requirement: グループを持つ大量件数での仮想化と滑らかさ (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| グループの多い大量件数 | iOS: `KsGroupChunkTable.swift`<br>And: `KsCollectionView.kt:376-519` | 自動テストなし (体感の Scenario) | 未検証 (5.5 / 5.6) (所見 4) |

---

## 対応表: collection-layout (verify-001 から引き継ぎ)

### Requirement: グループの見出し (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 見出しにグループの値と項目が渡る | iOS: `KsCollectionViewController.swift:585`<br>And: `KsCollectionView.kt:406-420` | iOS: GE:54、PA:200<br>And: G:88、A:69 | ✅ 一致 |
| グリッドでは全幅 | iOS: `KsCollectionViewController.swift:1102`<br>And: `KsCollectionView.kt:410,423-425` | iOS: GE:107<br>And: G:179、G:191 | ✅ 一致 |
| ルートのヘッダーとの共存 | iOS: `KsCollectionViewController.swift:963`<br>And: `KsCollectionView.kt:388-396,521-531` | iOS: GE:137<br>And: G:206、P:54 | ✅ 一致 |

### Requirement: 見出しの内容の更新 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 項目数が変わると見出しの件数が変わる | iOS: `KsCollectionViewController.swift:617`<br>And: `KsCollectionView.kt:183,406-407` | iOS: GE:621、GE:641、GE:672<br>And: G:216、G:366、G:331 | ✅ 一致 |
| 観測する値で見出しが変わる (iOS) | iOS: `KsCollectionViewController.swift:208` | iOS: GE:700 | ✅ 一致 |

### Requirement: 見出しの固定 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 既定で固定される | iOS: `KsCompositionalLayout.swift:23,93`<br>And: `KsGroups.kt:49`、`KsCollectionView.kt:409-421` | iOS: GE:375、PA:200<br>And: G:395 | ✅ 一致 |
| 次の見出しに押し上げられる | 同上 | iOS: GE:403<br>And: G:406、S:76 | ✅ 一致。iOS 16 での透明度の打ち消しは未検証 (5.4) |
| 固定を外す | iOS: `KsCompositionalLayout.swift:23`<br>And: `KsCollectionView.kt:422-433` | iOS: GE:387、GE:474、PA:229<br>And: G:427 | ✅ 一致 |
| 内部の塊に割れたグループの見出し (iOS) | iOS: `KsCompositionalLayout.swift:93`、`KsCollectionViewController.swift:1142,1160` | iOS: GE:324、GE:440 | ✅ レイアウト上は一致。実機のフレームごとの記録は 5.1、VoiceOver は 5.3、iOS 16 は 5.4 で未検証 |

安全領域の扱いと、iOS の中身が押し下げられる件の付随修正は ⚠️ deviation 記録済み (テストは iOS SA:55〜253 の 8 件、And S)。

### Requirement: グループまわりの間隔 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 間隔の既定 | iOS: `KsCollectionLayout.swift:20,26,37-38`<br>And: `KsLayout.kt:28-29,72-73`、`KsGroupPlan.kt:292-308` | iOS: GE:201、PA:259<br>And: G:439、A:33 | ✅ 一致 |
| 2 つの間隔を指定する | iOS: `KsCollectionViewController.swift:954`、`KsGroupHeaderPinning.swift:9`<br>And: `KsGroupPlan.kt:292-308`、`KsCollectionView.kt:476-479` | iOS: GE:225、GE:258、EI<br>And: G:452、G:472、G:485、P:171 | ✅ 一致 |

### Requirement: グループを持つ list の区切り線 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 見出しの上下に線がある | iOS: `KsCollectionViewController.swift:523,536`<br>And: `KsCollectionView.kt:480-486` | iOS: GE:282<br>And: G:540 | ✅ 一致 |
| 見出しが無いと線は重ならない | 同上 | iOS: GE:302<br>And: G:556 | ✅ 一致 |

### Requirement: 回転と列数の変化での位置 (グループ) (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 固定中の見出しの下に戻る | iOS: `KsCollectionViewController.swift:1199,1226,1301`<br>And: `KsPositionKeeper.kt:67-69,162-186` | iOS: GE:503、SA:224<br>And: G:696、S:131 | ✅ 一致 |

### Requirement: スクロールインジケータの全体の長さ (Android) (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 小さいグループが多いグリッド | `KsScrollIndicator.kt:172-209`、`KsGroupPlan.kt:194-205` | I:316、P:98 | ⚠️ deviation 記録済み |

### Requirement: ルートヘッダー / フッター (MODIFIED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| ヘッダーのスクロール追従 | iOS: `KsCollectionViewController.swift:963`<br>And: `KsCollectionView.kt:388-396` | iOS: CE:1867<br>And: L:457 | ✅ 一致 |
| 内側余白と行間の位置 | iOS: `KsCollectionViewController.swift:963-989`<br>And: `KsCollectionView.kt:382-385,476-479` | iOS: GE:165<br>And: L:483、L:510 | ✅ 一致 (所見 2) |
| 空配列でのヘッダー / フッター | iOS: 同上<br>And: `KsGroupPlan.kt:336-348` | iOS: CE:989<br>And: L:534 | ✅ 一致 |
| グリッドでの全幅ヘッダー | iOS: `KsCollectionViewController.swift:1087-1099`<br>And: `KsCollectionView.kt:389-391` | iOS: 直接のテストなし<br>And: L:555 | ✅ 一致 (所見 3) |

### Requirement: 配列の内部分割 (iOS) (MODIFIED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 塊の境界に不完全な行が無い | `KsGroupChunkTable.swift:32,105` | CE:844、CE:820、`KsSectionChunkingTests` | ✅ 一致 |
| 塊はグループをまたがない | `KsGroupChunkTable.swift:105` | CT:47、GE:107 | ✅ 一致 |
| 向き別列数で列数が変わっても不完全な行が無い | 同上 | CE:1083、GE:503 | ✅ 一致 |
| adaptive で列数が変わると塊を組み直して位置を保つ | `KsCollectionViewController.swift:1226` | CE:1127、CE:879、CE:1156 | ✅ 一致 |
| 塊の境界で行間と区切り線が変わらない | `KsCollectionViewController.swift:536` | CE:1045、CE:948 | ✅ 一致 |
| 内側余白は配列全体の上下にだけ付く | `KsCollectionViewController.swift:963-989` | CE:948 | ✅ 一致 |
| ルートのヘッダーとフッターは 1 つずつ | 同上 | CE:989 | ✅ 一致 |
| 先頭への挿入で塊の所属が変わっても位置が飛ばない | `KsCollectionViewController.swift:1325` | CE:1315 | ✅ 一致 |
| 先頭の削除で塊の所属が変わっても位置が飛ばない | 同上 | CE:1372 | ✅ 一致 |
| グループをまたぐ挿入で後ろのグループの塊が組み直る | `KsGroupChunkTable.swift:105` | GE:891、CT:85 | ✅ 一致 |
| 塊をまたぐ並べ替え | — | CE:1426 | ✅ 一致 |
| スクロール命令は塊とグループをまたいで解決する | iOS: `KsCollectionViewController.swift:1368,1408`<br>And: `KsScrollCommandReceiver.kt:116-160`、`KsCollectionView.kt:246-285,649-667` | iOS: CE:1470、GE:552、GE:599<br>And: G:678、G:649、G:666、S:117 | ✅ 一致 |
| 件数に比例しない | 塊の件数で上限が決まる構造 | 計測の Scenario | 未検証 (5.5) |

### Requirement: ルートヘッダー / フッター (Android) (REMOVED)

共通の「ルートヘッダー / フッター」に統合された。Android 専用の分岐や、それを前提にしたテストの残骸はない。**✅ 一致**

---

## 対応表: samples

### Requirement: デモ画面「グループ化」 (ADDED) — 引き継ぎ

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 両プラットフォームで同じ構成 | iS: `SampleScreen.swift:11-13`、`GroupingDemoData.swift:15-68`、`GroupingFixture.swift:11-28`、`GroupHeaderBand.swift:16,27-29`<br>AS: `SampleScreen.kt:20-22`、`GroupingDemoData.kt:19-69`、`GroupingFixture.kt:19-37`、`GroupHeaderBand.kt:60-61` | iS-UT: `GroupingDemoUITests.swift:9`、`:25`<br>AS-T: `SampleScreenParityTest.kt:16-66`、`GroupingDemoDataTest.kt:22-55`、`SampleDemoScreenTest.kt:184` | ✅ 一致 (所見 5) |
| 起動引数で開ける | iS: `SampleLaunchView.swift:35-38,67-72`<br>AS: `SampleNavHost.kt:93-106` | iS-UT: `GroupingDemoUITests.swift:25`<br>AS-T: `SampleScreenParityTest.kt:89` | ✅ 一致 (所見 6) |

### Requirement: 差分アニメーションを確かめる操作 (ADDED) — 引き継ぎ

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| グループの並び順を反転する | iS: `GroupingDemoView.swift:25-27`、`GroupingDemoEdits.swift:8-10`<br>AS: `GroupingDemoScreen.kt:51-55,87-90`、`GroupingDemoEdits.kt:12-13` | iS-UT: `GroupingDemoUITests.swift:25`<br>AS-T: `GroupingDemoEditsTest.kt:22`、`SampleDemoScreenTest.kt:195` | ✅ 並びは一致。見え方は未検証 (5.2) |
| 項目を別のグループへ移す | iS: `GroupingDemoView.swift:45-49`、`VisibleItemProbe.swift:18-28`、`GroupingDemoEdits.swift:23-46`<br>AS: `GroupingDemoScreen.kt:97-112`、`VisibleItemProbe.kt:29-32`、`GroupingDemoEdits.kt:27-52` | iS-UT: `GroupingDemoUITests.swift:45`<br>AS-T: `GroupingDemoEditsTest.kt:31-80`、`SampleDemoScreenTest.kt:211` | ✅ 一致 (所見 7) |

### Requirement: デモ画面「差分更新」 (ADDED) — 改めて突き合わせ

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 各操作がアニメーションで反映される | iS: `DiffUpdateDemoView.swift:86-96`<br>AS: `DiffUpdateDemoScreen.kt:111-121` | 自動テストなし (見え方の Scenario) | 未検証 (5.2 / 5.7。所見 8) |
| グループありの操作で不正入力にならない | iS: `DiffUpdateModel.swift:50-103` (各操作)、`:112-117` (`setGrouped`)、`:120-123` (`regroup`)、`DiffUpdateDemoView.swift:37-40` (切り替えの Binding)<br>AS: `DiffUpdateModel.kt:39-116`、`DiffUpdateDemoScreen.kt:76-81` | iS-UT: `GroupingDemoUITests.swift:114` (グループありのまま全位置・全操作を 2 周)、`:143` (グループなしでシャッフルしてからグループありへ。所見 10)<br>AS-T: `DiffUpdateModelTest.kt:138`、`:153`<br>本検証の Simulator 操作 (「❌ の解消の確認」節) | ✅ 一致 |
| 更新は作り直さずに反映される | iS: `DiffUpdateModel.swift:62-65`、`DiffUpdateItem.swift:12-14`<br>AS: `DiffUpdateModel.kt:54-59`、`DiffUpdateItem.kt:16-17` | iS-UT: `GroupingDemoUITests.swift:69`<br>AS-T: `DiffUpdateModelTest.kt:53`、`SampleDemoScreenTest.kt:222` | ✅ 一致。作り直さないことはライブラリ側のテスト (iOS GE:641、And G:366、C:134) で担保 |
| 両プラットフォームで同じ結果 | iS: `DiffUpdateModel.swift`、`SampleRandom.swift:19-42`<br>AS: `DiffUpdateModel.kt`、`SampleRandom.kt:28-59` | AS-T: `DiffUpdateModelTest.kt:87,94,113`、`SampleRandomTest.kt:16,40`<br>iOS 側で実行して確かめるテストはない | ✅ 一致 (所見 9) |

「両プラットフォームで同じ結果」への影響: 今回の変更は、グループの有無をビューの状態からモデルに移し、切り替えを `setGrouped(_:)` にまとめただけ。操作ごとの規則 (挿入・削除・更新・移動・反転・シャッフル・元に戻す) は変わっていない。切り替えの規則も Android と同じで、次の 3 点が一致している。

- グループありにするときだけ、先に並べ直してから有無を切り替える (`DiffUpdateModel.swift:112-117` と `DiffUpdateDemoScreen.kt:76-81`)
- 並べ直しは、グループが初めて現れた順に集め、グループ内の順は保つ (`DiffUpdateModel.swift:120-123` と `DiffUpdateModel.kt:112-113`)
- 元に戻すはグループの有無を変えない (両方のモデルの冒頭の説明、`DiffUpdateModel.swift:105-109`)

「更新」の印の文言 (「Item n ★」) は ui/brief.md の合意済み妥協どおり。

### Requirement: 性能計測の対象への追加 (ADDED) — 引き継ぎ

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 計測の自動実行 | iS: `PerformanceFixture.swift:12-45`、`PerformanceVerificationView.swift:101-103`<br>benchmark: `GroupingScrollBenchmark.kt:31-39`、`MeasurementTarget.kt`、`scripts/verify-fling-results.py:64-73`<br>比較対象: AS-M `MeasurementDestinations.kt:521,535,559,564,588-671`、`BaselineScrollIndicator.kt` | iS-UT: `PerformanceDriverUITests.swift:165` (Performance スキーム)<br>`samples/android/benchmark/scripts/test_verify_fling_results.py:498-516` | ✅ 駆動は一致。計測の値は未検証 (5.5 / 5.6) |

---

## ❌ の解消の確認 (verify-001 の ❌)

### 実装の変化

- `iS/DiffUpdateModel.swift`
  - グループの有無 (`grouped`) をモデルが持つようになった (`:36`)
  - `setGrouped(_:)` (`:112-117`) は、グループありにするときは先に `regroup()` で並べ直し、そのあとで `grouped` を立てる
  - `regroup()` は private になり、外から切り替えと別に呼べない (`:120`)
  - 移動・シャッフルは、モデル自身の `grouped` を見る (`:69`、`:90`)
- `iS/DiffUpdateDemoView.swift`
  - 以前の `.onChange(of: grouped)` による並べ直しはなくなった
  - スイッチは `Binding(get: { model.grouped }, set: { model.setGrouped($0) })` (`:37-40`)。切り替えは `@State` の 1 回の変更で済む
  - 表示は `model.grouped` のときだけ `groups(by:)` を付ける (`:55`)
  - 以上により、並べ直す前の配列がグループありで表示側へ渡る経路はなくなった
- グループありの間の各操作が「同じグループの項目が続いて並ぶ」を保つことは、コードで 1 つずつ確かめた
  - 挿入: その位置の項目の直前に、同じグループで入る
  - 移動: 次のグループの先頭へ入る
  - 反転・グループありのシャッフル: グループ単位のまま組み替える
  - 削除・更新: 並びを崩さない
  - 元に戻す: 初期の配列に戻り、これは続いて並んでいる

### Simulator での確認

本検証で、Simulator の iPhone 17 Pro に Debug ビルドを入れ、`--screen 差分更新` で開いて実施した。次の 4 経路で、グループありへ切り替えた後もアプリの処理 (PID) が同じまま動き続けた。この Simulator の本 Sample の新しいクラッシュレポートは、手順の間に 1 件も出ていない。

| # | 表示 | 手順 | 切り替え後の表示 |
|---|---|---|---|
| 1 | list | グループをオフ → シャッフル → グループをオン (verify-001 の再現手順そのもの) | グループ D・C… の順に、各 5 件が続けて並ぶ |
| 2 | list | グループをオフ → 中ほどで移動 (Item 6 が先頭へ出てグループ B が割れる) → グループをオン | グループ B (6, 8, 10, 9, 7)・D… の順 |
| 3 | グリッド | グループをオフ → シャッフル → グループをオン | グループ A・D・B… の順で、各グループが行頭から並ぶ |
| 4 | グリッド | グループをオフ → 挿入 → シャッフル → グループをオン (間を空けずに続けて操作) | グループ A・D・C… の順 |

### 同じ時間帯の別のクラッシュレポートについて

同じ時間帯に、別の Simulator (iPhone 17 Pro Max、同時に動いていた別のワーカーのもの) で、本 Sample が `reportReappearingGroupValues` の assertion で停止したレポートが 1 件あった (15:34)。これは現在のソースから作ったものではないと判断した。

- そのバイナリには、`.onChange` の修飾子 (`_ValueActionModifier<Bool>`) を持つ「差分更新」画面の型が残っていた。現在の `DiffUpdateDemoView.swift` に `.onChange` はない
- 同じバイナリに `DiffUpdateModel.regroup()` が外から見える形で残っていた
- 本検証でビルドしたバイナリ (現在のソース) には、どちらもない

修正前の形を含むビルド (修正前の挙動を確かめるための途中の状態と見られる) が原因で、判定の対象外とした。

---

## 未検証 (5.x で確認予定)

| Scenario | 確かめる方法 | tasks |
|---|---|---|
| 内部の塊に割れたグループの見出し (iOS): 実機での隙間・かぶり・動き・欠け | フレームごとの位置の記録 (ゆっくり / 速く) | 5.1 |
| 内部の塊に割れたグループの見出し (iOS): 読み上げが 1 つだけ | VoiceOver | 5.3 |
| 次の見出しに押し上げられる (iOS 16 で薄れない) | iOS 16 の Simulator | 5.4 |
| 項目が別のグループへ移る / グループの並び順を反転する (アニメーション中の見出しの位置、iOS) | 「グループ化」の 2 つの操作でフレームの位置を記録 | 5.2 |
| グループの並び順を反転する (samples) の見え方 | 同上 | 5.2 |
| いちばん上での先頭への挿入 / いちばん下での末尾への挿入 / ルートのフッターがあるときの末尾への挿入 (アニメーションが見えること、両プラットフォーム・list / グリッド) | オーナーの目視 | 5.7 |
| 各操作がアニメーションで反映される (samples「差分更新」) | オーナーの目視 (所見 8) | 5.7 ほか |
| グループの多い大量件数 (基準機の体感) | 基準機の手動フリック、iOS は見出しの書き換えの主スレッド占有率も記録 | 5.5 |
| 件数に比例しない (iOS) | time profile の占有率の比較 | 5.5 |
| 計測の自動実行 (結果の値) と、`animateItem` の費用・行間を余白に移した影響 (Android) | 相対計測と既存 fixture の回帰計測 | 5.6 |

---

## 追加検査

- [x] **tasks.md**
  - verify-001 から変更なし。1.1〜4.7 は完了で、虚偽のチェックはない
    - 4.4 (「差分更新」画面) は、今回の修正でグループありへの切り替えも含めて成り立つようになった
  - 5.1〜5.7 は未完了で、前提どおり
- [x] **逆流検査**
  - proposal.md / design.md / specs/ は working tree で HEAD との差分がなく、verify-001 の後にも変更がない
  - HEAD `883ee76` の提案の改訂 (オーナーの指示) の扱いは verify-001 のとおり
- [x] **未記録乖離**: なし。verify-001 の ❌ は実装の修正で解消した (deviation での合意ではない)
- [x] **付随修正**: deviation.md の `[付随修正]` 5 件は verify-001 で確認済みで、変更なし。今回の 3 ファイルの差分は、どれも samples「デモ画面「差分更新」」の Scenario の範囲に収まる
- [x] **UI**
  - `ui/brief.md` の承認モックの記録・照合結果・合意済み妥協は verify-001 から変わっていない
  - 今回の修正は切り替えの内部の処理だけで、画面の構成・文言は変わらない。そのため `ui/verification/` の撮り直しは要らない

## テストの実行

| 系統 | 結果 | 備考 |
|---|---|---|
| iOS Sample (`-scheme KsCollectionViewSamples`、Debug、UI テスト。`PerformanceDriverUITests` はスキームで除外) | 18 件 / 失敗 0 | 本検証で iPhone 17 Pro に対して実行。`GroupingDemoUITests` の 6 件 (新しい `:143` を含む) がすべて成功 |
| iOS ライブラリ Debug (`xcodebuild test -scheme KsCollectionView`) | 340 件 / 失敗 0 | verify-001 の実行結果を引き継いだ。ライブラリのソースとテストは、その後変わっていない |
| iOS ライブラリ Release (`-configuration Release ENABLE_TESTABILITY=YES`) | 331 件 / 失敗 0 | 同上 |
| Android ライブラリ (`:kscollectionview:testDebugUnitTest`) | 320 件 / 失敗 0 | 本検証で実行 (※) |
| Android Sample (`:app:testDebugUnitTest`) | 83 件 / 失敗 0 | 本検証で実行 (※) |
| benchmark の判定スクリプト | 29 件 / OK | verify-001 を引き継いだ (変更なし) |

※ Gradle が UP-TO-DATE と判定した (入力のソースが直前の実行から変わっていない)。そのため、現在のソースに対する直前の実行の結果 XML を集計した。呼び出し元がホスト側で実行した結果 (iOS Sample 18 件、ライブラリ Debug 340 / Release 331、Android 320 / 83、いずれも失敗 0) とも一致する。

iOS Sample の UI テストの実行中に、この Simulator でクラッシュレポートが 2 件残った。どちらも `LargeDataCount.failIfInvalid()` によるもの (件数の不正な起動引数で起動しないことを確かめるテストの意図どおりの停止) で、失敗ではない。

---

## 所見 (判定に含めない、テストの守備範囲の小さな穴)

1〜9 は verify-001 の所見をそのまま引き継ぐ。要点だけを再掲する。

1. **Android「項目が別のグループへ移る」**: G:572 は、移動の前後で項目のコンポジションが保たれることを直接見ていない
2. **Android「内側余白と行間の位置」**: L:483 は、フッターの下の余白を確かめていない
3. **iOS「グリッドでの全幅ヘッダー」**: iOS に直接のテストがない
4. **「グループの多い大量件数」の仮想化**: グループありで同時生成の上限を確かめる自動テストがない (グループなしは CE:1507 と C:56)
5. **「両プラットフォームで同じ構成」の列数**: 縦 2 / 横 4 を確かめるテストがない
6. **Android「起動引数で開ける」**: テストは開始ルートの文字列までで、画面を開いて確かめていない
7. **「項目を別のグループへ移す」の件数の更新**: UI テストで両方の見出しの件数の更新を確かめていない
8. **「各操作がアニメーションで反映される」**: tasks 5.x の割り当てが明示されていない
9. **「両プラットフォームで同じ結果」**: 固定値のテストは Android 側だけ。iOS は verify-001 で初期状態からのシャッフル 1 回だけを目視で照合した

10. **(新規) iOS UI テスト `GroupingDemoUITests.swift:143` の 2 周目は、並びを崩していない**
    - 2 周目の崩す操作は「中ほどで移動 → 先頭で移動」
    - グループなしの移動は、元の位置 i と件数 n から (i + n / 2) % n の位置へ入れる規則 (`DiffUpdateModel.swift:78-82`)
    - 20 件では、中ほど (10) の項目が 0 へ行き、続く先頭 (0) の移動で同じ項目が 10 へ戻る。並びは元どおりになる
    - 本検証の Simulator でも、2 回の移動の後の並びが移動の前と同じだった
    - そのため 2 周目は「続いて並んでいる配列でグループありに戻す」経路になり、修正を確かめていない
    - 1 周目 (シャッフル) は修正前のコードで停止する経路 (verify-001 の再現手順) で、Scenario の確認はこれで足りている。本検証の Simulator 操作では、移動 1 回で崩す経路 (上の表の #2) も確かめた
    - 2 周目を意味のあるものにするなら、例えば「中ほどで移動」を 1 回だけにする
