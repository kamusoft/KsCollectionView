# Verify 001: sections-grouping

- 検証日: 2026-09-25
- 対象: HEAD `883ee76` 以降の作業ツリーの未コミットの変更 (ライブラリ iOS / Android、Sample iOS / Android、benchmark)
- 基準: `specs/collection-core/spec.md` (6 Requirement / 12 Scenario)、`specs/collection-layout/spec.md` (ADDED 7・MODIFIED 2・REMOVED 1 Requirement / 32 Scenario)、`specs/samples/spec.md` (4 Requirement / 9 Scenario)。合計 53 Scenario
- 合意済みの差分: `deviation.md` (付随修正 5 件・合意済み乖離 10 件)、`ui/brief.md` の「合意済み妥協」3 件
- 作業ドメイン: cross (core の契約 + ios + android)
- 前提: tasks 5.1〜5.7 (evidence/ に残す動作証跡) はまだ実施していない。体感・目視・計測でしか確かめられない Scenario は「未検証 (5.x)」として区別し、それだけを理由に INVALID にはしない

## 判定

**INVALID (❌ 1 件)**

- ❌ samples の Requirement「デモ画面「差分更新」」: iOS Sample で、グループなしのまま並びを混ぜてからグループありに切り替えると、debug ビルドで不正入力の assertion が発火してアプリが停止する。この Requirement は「グループの有無を切り替えられる」「グループありのときは、どの操作の後も同じグループの項目が続けて並ぶよう、データ側で並べ直す」を SHALL としている。Simulator で再現を確認した (詳細は「❌ の詳細」)。関連する Scenario は「グループありの操作で不正入力にならない」。
  - Scenario の WHEN をそのまま読むと (グループありの表示のまま全操作) 満たしており、UI テストも通る。
  - 破れているのは、切り替えでグループありに入る経路。
  - 見立て: 実装を直すべき (Android と同じく、切り替えと同じ更新の中で並べ直す)。
- それ以外の 52 Scenario は「✅ 一致」「⚠️ deviation 記録済み」「未検証 (5.x)」のいずれか。テストの守備範囲の小さな穴は「所見」節に分けた (いずれも実装の構造で成り立っていることを確認済みで、判定には含めない)
- 虚偽チェックなし。足場の逆流なし (working tree での proposal / design / specs の変更なし。tasks.md の差分はチェックの付け替えだけ)
- テストは全系統で全件成功 (「テストの実行」節)

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

## 対応表: collection-core

### Requirement: グループの値によるグループ化 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 続いた同じ値が 1 つのグループになる | iOS: `KsCollectionView.swift:164,186` (`groups(by:)`)、`KsGroupChunkTable.swift:32,105`<br>And: `KsGroupPlan.kt:327-404`、`KsCollectionView.kt:398-519` | iOS: CT:6、GE:54 (見出しに値と項目が渡る)<br>And: P:38、G:88 | ✅ 一致 |
| 指定しなければ今までどおり | iOS: `KsGroupChunkTable.swift:32` (値なしの 1 グループ)<br>And: `KsGroupPlan.kt:336-348` | iOS: GE:78、CT:26、PA:251<br>And: G:101、P:81 | ✅ 一致 |
| 項目のモデルを変えずにグループ化する | iOS: `KsCollectionView.swift:164` (キーパス)<br>And: `KsGroups.kt:47-51` (ラムダ) | iOS: PA:200 (準拠のない `Product` の `\.category`)<br>And: A:69、G は素の data class を使う | ✅ 一致 |

表示中にグループの値の取り出し方を切り替えたときの扱いは ⚠️ deviation 記録済み (review-001 の裁定)。テストは iOS GE:820 / GE:859、And G:247 / G:290。

### Requirement: グループの値の型 (Android) (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 項目のキーと同じ値のグループ | `KsGroupPlan.kt:18-46` (見出しのキーは内部の `Parcelable` 型)、`KsCollectionView.kt:408-411` | G:116 (debug で停止しない・見出しと項目の両方が出る)、P:153 (キーが別物で Parcel の往復) | ✅ 一致 |

- 利用契約は `KsGroups.kt:14-16` の KDoc に明記されている (文字列・数値・enum・`Serializable`・`Parcelable`)。`KsCollectionView.kt:100-101` の `@param groups` からもそこを案内している
- 載らない型の検知は、項目の key と共通の `isSavableKey` を使う (`KsGroupPlan.kt:369-371,386-391`)。テストは P:139 と G:158 (debug)

### Requirement: 同じグループの値が離れて現れる入力 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| release ビルドでの離れた同じ値 | iOS: `KsCollectionViewController.swift:896` (`reportReappearingGroupValues`)、`KsInvalidInput.swift:23` (debug で assertion)<br>And: `KsGroupPlan.kt:355-384`、`KsCollectionView.kt:197,203-204` | iOS: GE:973 (release で 3 グループ・並びは不変・警告)、CT:69 (何回目かで区別)<br>And: G:142 (release で 3 グループ・全項目・WARN ログ)、G:129 (debug で停止)、P:122 | ✅ 一致 |

iOS の debug 側の停止は、テストではなく本検証の Simulator 操作で実際に発火したことを確かめた。クラッシュの呼び出し経路は `KsInvalidInput.report` ← `reportReappearingGroupValues` ← `apply` (❌ の詳細を参照)。

### Requirement: グループをまたぐ差分更新 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 項目が別のグループへ移る | iOS: `KsCollectionViewController.swift:806,820` (`animatingDifferences`)<br>And: `KsCollectionView.kt:581,604-605` (`animateItem`) | iOS: GE:731 (新しいグループへ移り、セルを作り直さない)<br>And: G:572 (移動先の位置と両グループの件数) | ✅ 一致 (所見 1)。アニメーションの見え方は未検証 (5.2 / 5.6) |
| グループの並び順を反転する | iOS: 同上<br>And: `KsCollectionView.kt:406-433` | iOS: GE:759<br>And: G:589、G:853 (見出しが途中の位置を通る)、G:619 (見出しを作り直さない) | ✅ 一致 |
| 最後の項目が消えたグループ | iOS: `KsGroupChunkTable.swift:105`<br>And: `KsGroupPlan.kt:360-377` | iOS: GE:799<br>And: G:606、G:868 | ✅ 一致 |

`animateItem` を高さの補間の間は止めること、ルートのヘッダー / フッターにも付けること、試作で決めた付け方は ⚠️ deviation 記録済み。

### Requirement: 端を表示中の端への挿入 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| いちばん上での先頭への挿入 | iOS: `KsCollectionViewController.swift:852` (`edgeToKeep`)、`KsContentEdge.swift:2`<br>And: `KsPositionKeeper.kt:86-91` | iOS: EI:41 (list / グリッド × グループの有無 × フッターの有無の 6 形)<br>And: G:736 (list)、G:742 (グリッド)、G:833 (グループの端)、G:880 (list の途中の位置) | ✅ 位置は一致。アニメーションの見え方は未検証 (5.7) |
| いちばん下での末尾への挿入 | iOS: `KsCompositionalLayout.swift:49` (`finalizeCollectionViewUpdates`)<br>And: `KsPositionKeeper.kt:92-99,137-153`、`KsAppearingItems.kt:58-127` | iOS: EI:69 (6 形、差分の適用の中で末尾に留まる)<br>And: G:748、G:754、G:903、G:909、G:916 | ⚠️ deviation 記録済み (iOS は `finalizeCollectionViewUpdates` で実装。Android は次のフレームからばねで追う)。見え方は未検証 (5.7) |
| ルートのフッターがあるときの末尾への挿入 | iOS: 同上<br>And: `KsPositionKeeper.kt:196-200` | iOS: EI:69 (フッターの形でフッターの下端と「項目がフッターの前」を確認)<br>And: G:805 | ✅ 位置は一致。見え方は未検証 (5.7) |

端を表示していないときの挿入は契約外。iOS は EI:111 で表示範囲を動かさないことを押さえている。

### Requirement: グループを持つ大量件数での仮想化と滑らかさ (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| グループの多い大量件数 | iOS: 塊による仮想化 (`KsGroupChunkTable.swift`)<br>And: `KsCollectionView.kt:376-519` | 自動テストなし (体感の Scenario)。グループなしの仮想化は既存の CE:1507 と C:56 | 未検証 (5.5 / 5.6) (所見 4) |

---

## 対応表: collection-layout

### Requirement: グループの見出し (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 見出しにグループの値と項目が渡る | iOS: `KsCollectionViewController.swift:585` (`configureGroupHeader`)<br>And: `KsCollectionView.kt:406-420` | iOS: GE:54、PA:200<br>And: G:88、A:69 | ✅ 一致 |
| グリッドでは全幅 | iOS: `KsCollectionViewController.swift:1102` (`makeGroupHeaderItem`)<br>And: `KsCollectionView.kt:410,423-425` | iOS: GE:107<br>And: G:179、G:191 | ✅ 一致 |
| ルートのヘッダーとの共存 | iOS: `KsCollectionViewController.swift:963` (レイアウト全体の boundary item)<br>And: `KsCollectionView.kt:388-396,521-531` | iOS: GE:137<br>And: G:206、P:54 | ✅ 一致 |

### Requirement: 見出しの内容の更新 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 項目数が変わると見出しの件数が変わる | iOS: `KsCollectionViewController.swift:617` (`updateVisibleGroupHeaders`)<br>And: `KsCollectionView.kt:183,406-407` | iOS: GE:621 (作り直さずに更新)、GE:641、GE:672<br>And: G:216 (作り直さない)、G:366、G:331 | ✅ 一致 |
| 観測する値で見出しが変わる (iOS) | iOS: `KsCollectionViewController.swift:208` | iOS: GE:700 | ✅ 一致 |

### Requirement: 見出しの固定 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 既定で固定される | iOS: `KsCompositionalLayout.swift:23,93`<br>And: `KsGroups.kt:49`、`KsCollectionView.kt:409-421` (`stickyHeader`) | iOS: GE:375、PA:200 (`pinsHeaders` が既定で true)<br>And: G:395 | ✅ 一致 |
| 次の見出しに押し上げられる | 同上 | iOS: GE:403 (押し上げ・重ならない・alpha 1)<br>And: G:406 (画素で薄れないことを確認)、S:76 | ✅ 一致。iOS 16 での透明度の打ち消しは未検証 (5.4) |
| 固定を外す | iOS: `KsCompositionalLayout.swift:23` (書き換えない)<br>And: `KsCollectionView.kt:422-433` | iOS: GE:387、GE:474、PA:229<br>And: G:427 | ✅ 一致 |
| 内部の塊に割れたグループの見出し (iOS) | iOS: `KsCompositionalLayout.swift:93` (方式 3c)、`KsCollectionViewController.swift:1142,1160` | iOS: GE:324、GE:440 (塊の 2 つの境目を 2pt 刻みと 45pt 刻みで往復し、見出しが 1 つだけ同じ位置と幅で固定されること・他の見出しが透明で読み上げ対象外であることを毎回確認) | ✅ レイアウト上は一致。実機のフレームごとの記録は 5.1、VoiceOver は 5.3、iOS 16 は 5.4 で未検証 |

全画面に広げたときの安全領域の扱い (固定中の見出しを境目で止める) と、iOS の中身が押し下げられる件の付随修正は ⚠️ deviation 記録済み。テストは iOS SA:55〜253 の 8 件、And S。

### Requirement: グループまわりの間隔 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 間隔の既定 | iOS: `KsCollectionLayout.swift:20,26,37-38`<br>And: `KsLayout.kt:28-29,72-73`、`KsGroupPlan.kt:292-308` | iOS: GE:201、PA:259<br>And: G:439、A:33 | ✅ 一致 |
| 2 つの間隔を指定する | iOS: `KsCollectionViewController.swift:954`、`KsGroupHeaderPinning.swift:9`<br>And: `KsGroupPlan.kt:292-308`、`KsCollectionView.kt:476-479` | iOS: GE:225、GE:258、EI (グループありの形)<br>And: G:452、G:472、G:485 (固定中の見出しに貼り付かない)、P:171 | ✅ 一致 |

負の値は不正入力。テストは iOS GE:945 と PA:281、And G:499 / G:512 / G:522。`rowSpacing` / `columnSpacing` の release での扱いを揃えた件は付随修正として記録済み。

### Requirement: グループを持つ list の区切り線 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 見出しの上下に線がある | iOS: `KsCollectionViewController.swift:523,536` (`showsTopSeparator`)<br>And: `KsCollectionView.kt:480-486` | iOS: GE:282<br>And: G:540 (画素) | ✅ 一致 |
| 見出しが無いと線は重ならない | 同上 | iOS: GE:302<br>And: G:556 (画素) | ✅ 一致 |

### Requirement: 回転と列数の変化での位置 (グループ) (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 固定中の見出しの下に戻る | iOS: `KsCollectionViewController.swift:1199,1226,1301` (覆われた範囲を除いたアンカー)<br>And: `KsPositionKeeper.kt:67-69,162-186` | iOS: GE:503 (縦 2 列から横 4 列)、SA:224<br>And: G:696、S:131 | ✅ 一致 |

### Requirement: スクロールインジケータの全体の長さ (Android) (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 小さいグループが多いグリッド | `KsScrollIndicator.kt:172-209`、`KsGroupPlan.kt:194-205` | I:316 (途中で下端に着かず、末尾で届く)、P:98 | ⚠️ deviation 記録済み (前後の余白を比の外に出す式) |

iOS は標準のインジケータのままで、変更はない。

### Requirement: ルートヘッダー / フッター (MODIFIED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| ヘッダーのスクロール追従 | iOS: `KsCollectionViewController.swift:963` (固定しない boundary item)<br>And: `KsCollectionView.kt:388-396` | iOS: CE:1867<br>And: L:457 | ✅ 一致 |
| 内側余白と行間の位置 | iOS: `KsCollectionViewController.swift:963-989` (余白をヘッダーの上とフッターの下に置く)<br>And: `KsCollectionView.kt:382-385,476-479` | iOS: GE:165 (上下の余白と前後に行間が無いこと)<br>And: L:483、L:510 | ✅ 一致 (所見 2) |
| 空配列でのヘッダー / フッター | iOS: 同上<br>And: `KsGroupPlan.kt:336-348` | iOS: CE:989<br>And: L:534 | ✅ 一致 |
| グリッドでの全幅ヘッダー | iOS: `KsCollectionViewController.swift:1087-1099` (`fractionalWidth(1)`。列の外で、レイアウト全体に付く)<br>And: `KsCollectionView.kt:389-391` (`GridItemSpan(maxLineSpan)`) | iOS: 直接のテストなし<br>And: L:555 | ✅ 一致 (所見 3) |

### Requirement: 配列の内部分割 (iOS) (MODIFIED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 塊の境界に不完全な行が無い | `KsGroupChunkTable.swift:32,105` | CE:844、CE:820、`KsSectionChunkingTests` | ✅ 一致 |
| 塊はグループをまたがない | `KsGroupChunkTable.swift:105` | CT:47、GE:107 (2 列で奇数件のグループの後、次の先頭は行頭) | ✅ 一致 |
| 向き別列数で列数が変わっても不完全な行が無い | 同上 | CE:1083、GE:503 (グループあり) | ✅ 一致 |
| adaptive で列数が変わると塊を組み直して位置を保つ | `KsCollectionViewController.swift:1226` | CE:1127、CE:879、CE:1156 | ✅ 一致 |
| 塊の境界で行間と区切り線が変わらない | `KsCollectionViewController.swift:536` | CE:1045、CE:948 | ✅ 一致 |
| 内側余白は配列全体の上下にだけ付く | `KsCollectionViewController.swift:963-989` | CE:948 | ✅ 一致 |
| ルートのヘッダーとフッターは 1 つずつ | 同上 | CE:989 | ✅ 一致 |
| 先頭への挿入で塊の所属が変わっても位置が飛ばない | `KsCollectionViewController.swift:1325` (`survivingAnchor`) | CE:1315 | ✅ 一致 |
| 先頭の削除で塊の所属が変わっても位置が飛ばない | 同上 | CE:1372 | ✅ 一致 |
| グループをまたぐ挿入で後ろのグループの塊が組み直る | `KsGroupChunkTable.swift:105` | GE:891、CT:85 (前のグループへの挿入で後ろの識別子が変わらない) | ✅ 一致 |
| 塊をまたぐ並べ替え | — | CE:1426 | ✅ 一致 |
| スクロール命令は塊とグループをまたいで解決する | iOS: `KsCollectionViewController.swift:1368,1408`<br>And (tasks 3.6): `KsScrollCommandReceiver.kt:116-160`、`KsCollectionView.kt:246-285,649-667` | iOS: CE:1470 (末尾の塊)、GE:552 (グループあり・見出しの下)、GE:599<br>And: G:678、G:649、G:666、S:117 | ✅ 一致 |
| 件数に比例しない | 塊の件数で上限が決まる構造 (変更なし) | 計測の Scenario | 未検証 (5.5 の time profile) |

### Requirement: ルートヘッダー / フッター (Android) (REMOVED)

共通の「ルートヘッダー / フッター」に統合された。Android 専用の分岐や、それを前提にしたテストの残骸はない。共通の Scenario は上の MODIFIED 表で L のテストに対応づけた。**✅ 一致**

---

## 対応表: samples

### Requirement: デモ画面「グループ化」 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 両プラットフォームで同じ構成 | iS: `SampleScreen.swift:11-13`、`GroupingDemoData.swift:15-68`、`GroupingFixture.swift:11-28`、`GroupHeaderBand.swift:16,27-29`<br>AS: `SampleScreen.kt:20-22`、`GroupingDemoData.kt:19-69`、`GroupingFixture.kt:19-37`、`GroupHeaderBand.kt:60-61` | iS-UT: `GroupingDemoUITests.swift:9` (メニューの順)、`:25` (「グループ 1」「1,200 件」、反転後の「グループ 378」「Item 9978」)<br>AS-T: `SampleScreenParityTest.kt:16-66`、`GroupingDemoDataTest.kt:22-55` (378 グループ、大きいグループは 1・182・347 番、小さいグループは 5〜30 件)、`SampleDemoScreenTest.kt:184` | ✅ 一致 (所見 5) |
| 起動引数で開ける | iS: `SampleLaunchView.swift:35-38,67-72` (`--screen グループ化`)<br>AS: `SampleNavHost.kt:93-106` (`ks_start_route=demo/Grouping`) | iS-UT: `GroupingDemoUITests.swift:25`<br>AS-T: `SampleScreenParityTest.kt:89` (経路の文字列) | ✅ 一致 (所見 6) |

`DemoData` の「大量件数」の項目の作り方を共有する件は付随修正として記録済み。

### Requirement: 差分アニメーションを確かめる操作 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| グループの並び順を反転する | iS: `GroupingDemoView.swift:25-27`、`GroupingDemoEdits.swift:8-10`<br>AS: `GroupingDemoScreen.kt:51-55,87-90`、`GroupingDemoEdits.kt:12-13` | iS-UT: `GroupingDemoUITests.swift:25`<br>AS-T: `GroupingDemoEditsTest.kt:22`、`SampleDemoScreenTest.kt:195` | ✅ 並びは一致。見出しと項目が一緒に動く見え方は未検証 (5.2) |
| 項目を別のグループへ移す | iS: `GroupingDemoView.swift:45-49`、`VisibleItemProbe.swift:18-28`、`GroupingDemoEdits.swift:23-46`<br>AS: `GroupingDemoScreen.kt:97-112`、`VisibleItemProbe.kt:29-32`、`GroupingDemoEdits.kt:27-52` | iS-UT: `GroupingDemoUITests.swift:45`<br>AS-T: `GroupingDemoEditsTest.kt:31-80`、`SampleDemoScreenTest.kt:211` | ✅ 一致 (所見 7) |

操作はどちらも新しい配列を代入するだけで、ライブラリに並べ替えを命じていない。計測用の画面には「表示中の項目」を探る仕組みを付けていない (iS `PerformanceVerificationView.swift:103`、AS-M `MeasurementDestinations.kt:190-196`)。

### Requirement: デモ画面「差分更新」 (ADDED) — ❌

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 各操作がアニメーションで反映される | iS: `DiffUpdateDemoView.swift:88-98`<br>AS: `DiffUpdateDemoScreen.kt:111-121` | 自動テストなし (見え方の Scenario) | 未検証 (5.2 / 5.7。所見 8) |
| グループありの操作で不正入力にならない | iS: `DiffUpdateModel.swift:47-118`、`DiffUpdateDemoView.swift:45-50`<br>AS: `DiffUpdateModel.kt:39-116`、`DiffUpdateDemoScreen.kt:76-81` | iS-UT: `GroupingDemoUITests.swift:114` (グループありのまま全操作を 2 周、debug)<br>AS-T: `DiffUpdateModelTest.kt:138` (全位置・全操作を 4 周し、毎回グループが続いて並ぶ)、`:153` (グループありへの切り替えで並べ直す) | ❌ iOS: グループなしからグループありへの切り替えで assertion が発火 (❌ の詳細)。Android は一致 |
| 更新は作り直さずに反映される | iS: `DiffUpdateModel.swift:59-62`、`DiffUpdateItem.swift:12-14`<br>AS: `DiffUpdateModel.kt:54-59`、`DiffUpdateItem.kt:16-17` | iS-UT: `GroupingDemoUITests.swift:69` (「Item 21 ★」)<br>AS-T: `DiffUpdateModelTest.kt:53`、`SampleDemoScreenTest.kt:222` | ✅ 一致。作り直さないことはライブラリ側のテスト (iOS GE:641、And G:366、C:134) で担保 |
| 両プラットフォームで同じ結果 | iS: `DiffUpdateModel.swift`、`SampleRandom.swift:19-42`<br>AS: `DiffUpdateModel.kt`、`SampleRandom.kt:28-59` | AS-T: `DiffUpdateModelTest.kt:87,94,113`、`SampleRandomTest.kt:16,40` (固定値)<br>iOS 側で実行して確かめるテストはない | ✅ 一致 (所見 9) |

「更新」の印の文言 (「Item n ★」) は ui/brief.md の合意済み妥協どおり。

### Requirement: 性能計測の対象への追加 (ADDED)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 計測の自動実行 | iS: `PerformanceFixture.swift:12-45` (`--performance-fixture グループ化`)、`PerformanceVerificationView.swift:101-103`<br>benchmark: `GroupingScrollBenchmark.kt:31-39`、`MeasurementTarget.kt`、`scripts/verify-fling-results.py:64-73`<br>比較対象: AS-M `MeasurementDestinations.kt:521,535,559,564,588-671`、`BaselineScrollIndicator.kt` | iS-UT: `PerformanceDriverUITests.swift:165` (Performance スキームで実行。通常スキームからは外れる)<br>`samples/android/benchmark/scripts/test_verify_fling_results.py:498-516` | ✅ 駆動は一致。計測の値は未検証 (5.5 / 5.6) |

---

## ❌ の詳細

### iOS Sample「差分更新」: グループなしで並べ替えた後、グループありに切り替えると debug で停止する

- **再現手順** (本検証で Simulator の iPhone 17 Pro と Debug ビルドを使って実施):
  1. `--screen 差分更新` で開く
  2. 「グループ」をオフにする
  3. 「シャッフル」を押す (グループの値が混ざった並びになる)
  4. 「グループ」をオンにする → アプリが停止する
- **停止の経路** (Simulator のクラッシュレポート): `EXC_BREAKPOINT`。`assertionFailure` ← `KsInvalidInput.report(_:)` ← `KsCollectionViewController.reportReappearingGroupValues(_:)` ← `apply(items:…)` ← `update(configuration:)` ← `KsCollectionRepresentable.updateUIViewController`
- **原因**:
  - `iS/DiffUpdateDemoView.swift:45-50` は、グループありへの並べ直し (`model.regroup()`) を `.onChange(of: grouped)` の中で行っている
  - そのため、切り替えの描画でまず「グループあり + 並べ直す前の配列」がライブラリへ渡り、離れた同じグループの値の不正入力になる
  - Android (`AS/DiffUpdateDemoScreen.kt:76-81`) は、切り替えと同じ変更の中で並べ直してから `grouped` を立てるので起きない (コメントにもその意図がある)
- **触れている契約**: samples の Requirement「デモ画面「差分更新」」の次の SHALL
  - 「グループの有無を切り替えられる」
  - 「グループありのとき、どの操作の後も同じグループの項目が続いて並ぶよう、データ側でグループ単位に並べ直す (離れた同じグループの値は不正入力のため)」
  - Scenario「グループありの操作で不正入力にならない」の趣旨 (debug で assertion が一度も起きない) も、グループありの状態に切り替えで入る経路では破れている
- **テストの穴**: `iS-UT/GroupingDemoUITests.swift:114` は、グループありのまま操作を繰り返すだけで、「グループなしで並べ替えてから切り替える」経路を通らない。iOS Sample にはモデルのユニットテストもない
- **deviation.md**: 記録なし
- **見立て: 実装を直すべき**。例えば、切り替えの Binding の set の中で並べ直してから `grouped` を立てるなど、Android と同じく 1 回の更新で済ませる。同時に、UI テストに「グループなしでシャッフル → グループあり」の経路を足すのがよい。deviation で合意するのは適さない (debug の Sample が止まるため)

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
  - 1.1〜4.7 はすべて完了。実装とテストの存在を対応表で確かめ、虚偽のチェックはなかった
    - 3.8 (試作の目視で決めた点) は deviation.md に決定の記録がある
    - 4.7 は `ui/verification/` に 6 枚ある
  - 5.1〜5.7 は未完了で、前提どおり
  - HEAD との差分はチェックの付け替えだけ (本文の変更なし)
- [x] **逆流検査**
  - working tree では proposal.md / design.md / specs/ に差分がない
  - HEAD の `883ee76` は、design Decision 16 と collection-core のスペックを広げている
    - これはオーナーの指示による提案の改訂で、コミットメッセージとフェーズの history.md に経緯がある。実装の都合の書き換えではないため、逆流としない
    - ただし実装期間中の改訂であることは記しておく (deviation.md の 2026-09-24 の記録と同じ日)
- [x] **未記録乖離**
  - ❌ の 1 件 (iOS Sample の切り替え) だけ
  - 表示中にグループの値の取り出し方を切り替えたときの扱いと、安全領域の扱いは deviation.md に記録済み
- [x] **付随修正**
  - deviation.md の `[付随修正]` 5 件は、diff の該当箇所とテストの存在を確かめた
    - iOS の補助ビューの安全領域: SA
    - `rowSpacing` / `columnSpacing` の release での扱い: GE:945、PA:281
    - `KsInvalidInput` の category: `KsInvalidInputTests.swift:20`
    - iOS / Android の `DemoData.largeItem`
    - `build.gradle.kts` のコメント
  - Scenario に対応しない diff は、いずれも付随修正か deviation に記録がある
    - `KsImagePrefetchWindow.kt` / `KsPrefetchDeclaration.kt` / `KsScrollCommandReceiver.kt` の index の写像は tasks 3.6 の範囲
    - `KsAnimatedHeight.kt` は tasks 3.4 / 3.9 の範囲
  - `kasane/lessons/inbox/` への追加は change の外の教訓の記録で、検証の対象外
- [x] **UI**
  - `ui/brief.md` に承認モックの記録がある (案 B、`mock/approved.png`、2026-09-24 のオーナー承認と再承認)
  - 照合結果 (両プラットフォーム、2026-09-25 最終承認) と合意済み妥協 3 件もある
  - `ui/verification/` に最終周の画像 6 枚がある

## テストの実行

本検証で実行した結果。iOS は Simulator の iPhone 17 Pro、Android はエミュレータ `emulator-5554` を指定した。

| 系統 | 結果 |
|---|---|
| iOS ライブラリ Debug (`xcodebuild test -scheme KsCollectionView`) | 340 件 / 失敗 0 |
| iOS ライブラリ Release (`-configuration Release ENABLE_TESTABILITY=YES`) | 331 件 / 失敗 0 |
| iOS Sample (`-scheme KsCollectionViewSamples`、UI テスト。`PerformanceDriverUITests` はスキームで除外) | 17 件 / 失敗 0 |
| Android ライブラリ (`:kscollectionview:testDebugUnitTest`) | 320 件 / 失敗 0 (※) |
| Android Sample (`:app:testDebugUnitTest`) | 83 件 / 失敗 0 (※) |
| benchmark の判定スクリプト (`python3 -m unittest test_verify_fling_results`) | 29 件 / OK |

※ Gradle が UP-TO-DATE と判定した (入力のソースが直前の実行から変わっていない)。そのため、現在のソースに対する直前の実行の結果 XML を集計した。

iOS Sample の UI テストの実行中に残ったクラッシュレポート 2 件は、`LargeDataCount.failIfInvalid()` によるもの (件数の不正な起動引数で起動しないことを確かめるテストの意図どおりの停止) で、失敗ではない。

---

## 所見 (判定に含めない、テストの守備範囲の小さな穴)

1. **Android「項目が別のグループへ移る」**: G:572 は、移動先の位置と両グループの件数を見ている。移動の前後で X のコンポジションが保たれること (作り直されないこと) は直接見ていない。
   - 項目は安定したキーで並べていて、Lazy の仕組みで保たれる構造である
   - 見出しでは同じことを G:619 で確かめている
   - 項目についても同じ形のテストを足すと、iOS GE:731 と揃う
2. **Android「内側余白と行間の位置」**: L:483 は、フッターの下の余白を確かめていない (3 件で画面に収まる条件)。実装は Lazy の `contentPadding` の下端で、構造上フッターの下に入る。
3. **iOS「グリッドでの全幅ヘッダー」**: iOS には直接のテストがない。
   - ルートのヘッダーは、塊ではなくレイアウト全体の boundary item になった (幅 `fractionalWidth(1)`)。そのため列数に関係なく全幅になる
   - 今回この箇所を作り替えたので、グリッドで幅と「要素がその下から並ぶ」を確かめるテストがあると安心
4. **「グループの多い大量件数」の仮想化**: グループありで、同時に生成されるセル / コンポジションが可視範囲と先読み分に留まることを確かめる自動テストは、どちらのプラットフォームにもない。グループなしでは CE:1507 と C:56 で確かめている。Scenario は体感 (5.5) だが、Requirement の前半 (同時生成の上限) は自動で確かめられる。
5. **「両プラットフォームで同じ構成」の列数**: 縦 2 / 横 4 はどちらも `fixed(portrait: 2, landscape: 4)` で宣言されているが、確かめるテストはない。
6. **Android「起動引数で開ける」**: テストは開始ルートの文字列までで、そのルートで画面を開いて確かめるテストはない。`SampleNavHost` は `SampleScreen.entries` から経路を自動で受け付ける構造。
7. **「項目を別のグループへ移す」の件数の更新**: UI テストでは、両方の見出しの件数の更新を確かめていない。
   - iOS は、見出しの文言が変わったことだけを確かめている
   - Android は、移した元の「1,199 件」だけを確かめている
   - 規則は `GroupingDemoEditsTest.kt` で網羅されている
8. **「各操作がアニメーションで反映される」**: tasks 5.x の割り当てが明示されていない。5.2 は「グループ化」の 2 操作、5.7 は端への挿入だけを指している。「差分更新」の中ほどの挿入・削除・移動、反転、シャッフルの見え方をどこで確かめるかを 5.x の実施時に決めておくとよい。
9. **「両プラットフォームで同じ結果」**: 固定値のテストは Android 側だけで、iOS 側を実行して照合するテストはない。本検証では次の 2 点を確かめた。
   - iOS Sample の初期状態でグループありのシャッフルを 1 回行った結果が、`DiffUpdateModelTest.kt:94` の 1 回目の期待値と一致した (Simulator の目視: 先頭から「グループ B: 8, 6, 9, 7, 10」「グループ D: 19, 17, 18, 20, 16」)
   - 別途の独立な再計算で、Android の固定値が Swift の手順と一致した
   - 続けた操作の結果 (`:113`) は iOS では確かめていない
