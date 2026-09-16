# 一致検証: performance-criteria-review (002 回目)

**日付**: 2026-09-16
**判定**: VALID (未記録の乖離・虚偽チェック・逆流・テスト失敗はいずれも無し)

## 前提と検証範囲

- 検証対象: 作業ツリーの未コミット変更すべて (`git diff HEAD` と未追跡ファイル) と、コミット `3567ba1` で入った実装。`kasane/lessons/` は対象外
- 突き合わせの正: 改訂版 (2026-09-16) の `specs/{collection-core,collection-layout,samples}/spec.md`。`deviation.md` に記録済みの乖離・読み替え・取り下げ・付随修正は**合意済み差分**として扱い、読み替え後の Scenario を検証対象にした
- verify-001 (最頻値化まで) で VALID だった分も、その後の改訂と塊分割による影響を含めて**全件を再照合**した
- `tasks.md` グループ 9 (本実装後の再計測) と 5 (仕上げ) は未着手。基準実機でのオーナー操作を要する Scenario は「実装と足場は揃っており、実行はオーナーの計測待ち」として ⏳ で区別した (INVALID の根拠にしていない)。ただし**足場が揃っているかは検証した**
- 試作段階の証跡 `evidence/manual-largeData-ios-2026-09-16-prototype.md` は tasks 6.3 (段階 1) の結果として参照しただけで、9 系の証跡としては数えていない
- 使用 Simulator: `iPad Air 13-inch (M4) / iOS 26.4.1` (倍率 2) と `iPhone Air / iOS 26.1` (倍率 3) でライブラリ、`iPhone 17 Pro / iOS 26.5` で Sample 通常スキーム、`iPhone 17 / iOS 26.4.1` で Sample 計測スキーム。レビュー 5 周が直前に使った機体 (iPhone 17 Pro Max 26.0.1 / iPad mini 26.5 / iPhone 16e 26.0.1) とも verify-001 の機体 (iPad Air 11-inch (M3) 26.0.1 / iPhone 17e 26.4.1) とも重ならない
- 参照した lessons (inbox): `do-not-run-review-and-verify-on-same-simulator` (機体を分けた)、`check-tests-exercise-production-path-before-accepting-green` (契約の中核はテストが本番経路を通っているかを確かめた。下の「本番経路の確認」節)、`no-untested-production-fixture` (届かない検査を未判定へ逃がしていないかを見た)

## 対応表

凡例: ✅ 一致 / ⚠️ deviation 記録済み / ⏳ 実装・足場は揃い、実行はオーナーの実機計測待ち / ❌ 欠落・乖離

### collection-layout (ADDED)

#### Requirement: 推定高さと一致するセルの自己サイズ (iOS)

| 条項 / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 推定高さ = 直近一定件数の実測 (ピクセル格子に量子化) の最頻値 | `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:51-75` | `ios/Tests/KsCollectionViewTests/KsEstimatedHeightTests.swift:20`, `:29` | ✅ |
| **返す値は量子化後ではなく格子に入った直近の実測値そのもの** | `KsEstimatedHeight.swift:60`, `:74` | `KsEstimatedHeightTests.swift:65` | ⚠️ deviation 記録済み (design Decision 1 との差。丸めの半画素差が解き直しを起こさないまま全行に積み上がるため) |
| 同数なら新しい値 / 繰り返しが無いうちは平均 / 未計測は既定値 (SHALL) | `KsEstimatedHeight.swift:52`, `:62-73` | `KsEstimatedHeightTests.swift:6`, `:39`, `:47`, `:56`, `:94` | ✅ |
| 幅が変わったときは前の実測を捨てる (SHALL) | `KsEstimatedHeight.swift:96` | `KsEstimatedHeightTests.swift:162`, `:172`, `:220` | ✅ |
| **画面の倍率が変わったときは前の実測を捨てる (SHALL)** (改訂で追加、tasks 8.1) | `KsEstimatedHeight.swift:95-100` (正規化した倍率を保持して比較)、`:42` | `KsEstimatedHeightTests.swift:186`, `:200`, `:208`, `:119` | ✅ |
| 推定と同じ高さに測られたセルの自己サイズは再解決を起こさない (SHALL NOT) | 実測値をそのまま返す設計 (`KsEstimatedHeight.swift:74`) + `KsHostingCell.swift:89` | `ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:29`, `:60`, `:105` | ✅ |
| 複数列では行の高さの実測に基づき合計を見積もる (SHALL) | — (実装なし) | — | ⚠️ deviation 記録済み (**オーナー判断 A で本 change から取り下げ**。Decision 15 の前提が A/B で崩れたため。混在 2 列の挙動は本 change 前と同一。spec 本文からの除去は蒸留時) |
| Debug 構成で「自己サイズを返したセル数」「不一致回数」を数えられる (SHALL) | `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:18-72`、`KsCollectionViewController.swift:396-402` | `KsEstimatedHeightTests.swift:106`、`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:1589` | ✅ |
| Scenario: 多数派のセルは再解決を起こさない | 上記一式 | `KsCollectionEngineTests.swift:1552` (高さ 2 種 6:1 の 2,000 件を実スクロールし不一致率 ≤ 0.20)。塊分割後に 2 機種で再実行済み (tasks 7.6) | ✅ |
| Scenario: 複数列で行内に高いセルが 1 つある | レイアウト既存挙動 | `KsCollectionEngineTests.swift:1637` (2 列・片側だけ高い配列で行高が高い方に揃う) | ✅ |
| Scenario: 微小な測定差は同じ高さとして数える | `KsEstimatedHeight.swift:101`, `:115` | `KsEstimatedHeightTests.swift:65`, `:79`, `:89` | ✅ |
| **Scenario: 倍率が変わると前の実測を捨てる** (新規) | `KsEstimatedHeight.swift:95-100` | `KsEstimatedHeightTests.swift:186` (倍率 3 で繰り返した後に倍率 2 の実測が届くと、新しい倍率の実測から決まる) / `:200` (同じ倍率では捨てない対照) | ✅ |
| Scenario: 合計高さの見積もりを損ねない | `KsEstimatedHeight.swift:51` | `KsCollectionEngineTests.swift:1676` (一様 1 列 2,000 件。初回誤差 ≤ 5%、0.1% 超の contentSize 変化 ≤ 3 回)。塊分割後に 2 機種で再実行済み (tasks 7.6) | ⚠️ deviation 記録済み (GIVEN を一様配列 1 列へ読み替え / 変化回数を「合計高さの 0.1% 超」に校正。読み替えは改訂で spec 本文へ畳み込み済み) |
| Scenario: 混在 2 列でも合計高さの見積もりを損ねない | — (実装なし) | — | ⚠️ deviation 記録済み (**オーナー判断 A で取り下げ**。基準は緩めず、混在 2 列は 9 系の実機計測で判定する) |

#### Requirement: 配列の内部分割 (iOS) — 新規

| 条項 / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 1 つの配列を内部で固定件数の塊に分けて配置する (SHALL) | `ios/Sources/KsCollectionView/KsSectionID.swift:6` (塊の順番による識別子)、`KsCollectionViewController.swift:575-592` (塊ごとの section へ載せる snapshot)、`ios/Sources/KsCollectionView/KsSectionChunking.swift:8` (基準 500 件) | `KsCollectionEngineTests.swift:762` (2,000 件が 2 つ以上の塊に分かれ、全件を通し番号で一意に数え切れる) | ✅ |
| 塊の件数は list=1 / 固定列数=その列数 / 向き別列数=宣言列数すべて (lcm) / adaptive=解決した列数 の倍数 (SHALL) | `KsSectionChunking.swift:25-56` | `ios/Tests/KsCollectionViewTests/KsSectionChunkingTests.swift:6`, `:12`, `:22`, `:59`, `:75`；実 snapshot では `KsCollectionEngineTests.swift:820` (list 500×4 / 3 列 501,501,501,497 / 向き別 2:3 で 504,504,504,488) | ✅ |
| 向き別列数の lcm があふれる・上限 (2,000) を超えるときは現在解決している列数の倍数へ縮退 | `KsSectionChunking.swift:16`, `:37-44`, `:66-71` | `KsSectionChunkingTests.swift:38` (61 と 67)、`:49` (`Int.max` でのあふれ) | ⚠️ deviation 記録済み (spec 本文は例外なしの記述。縮退規則は design Decision 10 / ios/ADR-0009 のとおり。spec 追随は蒸留時) |
| 塊の境界に列数に満たない行を作ってはならない (SHALL NOT) | 件数を列数の倍数へ切り上げる `KsSectionChunking.swift:52-56` | `KsCollectionEngineTests.swift:844` (境界前後の実レイアウト属性で行の埋まりと行頭を確認) | ✅ |
| adaptive の列数変化・layout 値の変更で、塊の件数が割り切れなくなったときだけ組み直す (SHALL) | `KsCollectionViewController.swift:493-494` (`chunkSizeChanged`)、`:651-661` (`scheduleChunkRebuildIfNeeded`)、`:664-675` (`rebuildChunksIfNeeded`)、`:677-684` (`currentChunkSize`)、`:214` (`viewDidLayoutSubviews` からも同じ判定) | `KsCollectionEngineTests.swift:879` (未解決からの確定でも組み直す)、`:1127` (adaptive 3 列 → 1 列で組み直す)、`:1156` (2 列 → 4 列は割り切れるので `chunkRebuildCount` が動かない)、`:1181` / `:1198` (layout 値の変更) | ✅ |
| 組み直しで表示範囲の先頭にあった項目を先頭に保つ (SHALL) | `KsCollectionViewController.swift:617` (アニメーション抑止)、`:621-622` / `:632-644` (適用後の実行機会まで遅らせる復元と世代番号)、`:769-787` (幾何ベースの `leadingVisibleID`)、`:791-806` / `:808-813` (控えと破棄) | `KsCollectionEngineTests.swift:1127`, `:1181`, `:1198` (いずれも送って静止させた後の実測アンカーで照合) | ⚠️ deviation 記録済み (THEN「先頭に留まる」→ テストの判定は「**同じ行**に留まる」へ読み替え。緩和そのものは Simulator では弁別できず、効き目の裏取りは 9 系の実機目視) |
| 配列が同じでも塊の件数が合わなくなれば組み直す (SHALL) | `KsCollectionViewController.swift:505` (同値配列の早期 return より前に `chunkSizeChanged` を判定) | `KsCollectionEngineTests.swift:899` (塊を組み直す同値配列の更新でも可視セルを作り直す) | ✅ |
| 塊の境界は行間・区切り線・内側余白・ヘッダー / フッターに現れない (SHALL NOT) | `KsCollectionViewController.swift:693-694` (塊の位置)、`:730-737` (余白 top/bottom と境界の行間)、`:741-745` (ヘッダー / フッターは先頭・末尾の塊だけ)、`:421` (上端の区切り線は `section == 0 && item == 0`) | `KsCollectionEngineTests.swift:948` (境界の行間 = 他の行間、余白は全体の上下だけ)、`:989` (ヘッダー / フッター各 1)、`:1045` (境界で上端の区切り線が出ない) | ✅ |
| 塊の分け方は公開 API と利用者の宣言に現れない (SHALL NOT) | `KsSectionID` / `KsSectionChunking` は internal。外へ出るのは `ios/Sources/KsCollectionView/KsItemOffsetLookup.swift:14-37` の `@_spi(KsMeasurement)` 1 本だけで、読めるのは「通し番号」のみ (塊の件数・順番は internal) | `ios/Tests/KsCollectionViewTests/KsPublicAPITests.swift` (公開 API の組み立て。塊に関する型は現れない) | ⚠️ deviation 記録済み (`@_spi` で Release にも載せる理由。表面は 1 本に限定) |
| 追加・削除・並べ替えで所属が変わる項目は差分更新の対象。境界で位置が飛ばず、所属が変わらない可視セルは作り直されない | `KsCollectionViewController.swift:575-592` (塊をまたぐ snapshot)、`:852-881` (控えた位置の復元)、`:907-919` (アンカーが消えたときの近傍解決) | `KsCollectionEngineTests.swift:1315` (先頭への挿入)、`:1372` (先頭の削除)、`:1426` (塊をまたぐ並べ替え)。いずれも `assertVisibleCellsSurviveWhereChunkUnchanged` (`:2419`) で所属不変セルの同一性を確かめ、「所属が変わる可視セルが 0 件なら前提崩れとして失敗」させている | ⚠️ deviation 記録済み (実測では位置の動きは 0.0 pt で、THEN の「挿入した行の分だけ動き」は観測されない。テストは「1 行以内の動きに収まり、それ以外に飛ばない」で固定。所属が変わった可視セルは作り直されずに移動したことも記録済み) |
| ID によるスクロール命令と末尾への命令は塊に依らず解決される (SHALL) | `KsCollectionViewController.swift:950-980` (`dataSource.indexPath(for:)` と `appliedIdentifiers.last` で解決) | `KsCollectionEngineTests.swift:1470` (対象が末尾の塊にあることを確かめたうえで両命令を実行) | ✅ |
| 項目が空でもヘッダー / フッターは表示される (SHALL) | `KsSectionChunking.swift:59-63` (空でも塊を 1 つ作る)、`KsCollectionViewController.swift:741-745` | `KsCollectionEngineTests.swift:989` (末尾で空配列にして両方の可視を確認) | ✅ |
| レイアウトの再解決の費用は塊の件数で上限が決まり、件数に比例してはならない (SHALL NOT) | 塊分割一式 | — (実機の time profile が必要) | ⏳ (tasks 9.1。段階 1 の証跡は `evidence/manual-largeData-ios-2026-09-16-prototype.md`) |
| Scenario: 塊の境界に不完全な行が無い | `KsSectionChunking.swift:52` | `KsCollectionEngineTests.swift:844` | ✅ |
| Scenario: 向き別列数で列数が変わっても不完全な行が無い | `KsSectionChunking.swift:37-44` (lcm)、`KsCollectionViewController.swift:182-197` (回転直前に控える)、`:816-844` (列数が変わったときだけ戻す) | `KsCollectionEngineTests.swift:1083` (回転で `chunkRebuildCount` が動かず、最終塊以外が 2 でも 3 でも割り切れ、先頭の項目が同じ行に留まる。戻す向きも確認) | ⚠️ deviation 記録済み (THEN 後半の読み替え。`viewWillTransition` が SwiftUI representable 経由で届くことはテストでは担保せず、9 系の実回転の目視で確かめる) |
| Scenario: adaptive で列数が変わると塊を組み直して位置を保つ | `KsCollectionViewController.swift:207-215`, `:651`, `:664`, `:617-644` | `KsCollectionEngineTests.swift:1127` | ⚠️ deviation 記録済み (同上の読み替え + 緩和を弁別しない旨。境界に 1 フレーム不完全な行が出うる件も記録済みで、9 系の目視に送られている) |
| Scenario: 塊の境界で行間と区切り線が変わらない | `KsCollectionViewController.swift:730-737`, `:421` | `KsCollectionEngineTests.swift:948`, `:1045` | ✅ |
| Scenario: 内側余白は配列全体の上下にだけ付く | `KsCollectionViewController.swift:733`, `:735` | `KsCollectionEngineTests.swift:948` | ✅ |
| Scenario: ヘッダーとフッターは 1 つずつ | `KsCollectionViewController.swift:741-745` | `KsCollectionEngineTests.swift:989` | ✅ |
| Scenario: 先頭への挿入で塊の所属が変わっても位置が飛ばない | `KsCollectionViewController.swift:852-881` | `KsCollectionEngineTests.swift:1315` | ⚠️ deviation 記録済み (位置の動きの観測) |
| Scenario: 先頭の削除で塊の所属が変わっても位置が飛ばない | 同上 | `KsCollectionEngineTests.swift:1372` | ⚠️ deviation 記録済み (同上) |
| Scenario: 塊をまたぐ並べ替え | `KsCollectionViewController.swift:575-592` | `KsCollectionEngineTests.swift:1426` | ✅ |
| Scenario: スクロール命令は塊をまたいで解決する | `KsCollectionViewController.swift:950-980` | `KsCollectionEngineTests.swift:1470` | ✅ |
| Scenario: 件数に比例しない | 件数指定 `samples/ios/KsCollectionViewSamples/LargeDataCount.swift`、計数の帯 `LargeDataMeasurementBar.swift`、初回区間での占有率の採り方 `kasane/handbook/ios/performance-verification.md:51-60`、実機の起動引数の渡し方 `:同 手順 2` | — | ⏳ (tasks 9.1。試作段階の同じ判定規則での計測は `evidence/manual-largeData-ios-2026-09-16-prototype.md` に済み) |

### collection-core (MODIFIED)

#### Requirement: 大量件数での仮想化・再利用 (iOS)

| 条項 / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 生成されるセルは可視範囲 + 再利用プール分に留まる (SHALL) | `KsCollectionViewController.swift:82-85` (`liveCellCount`)、`:326-341` (弱参照での記録と畳み込み) | `KsCollectionEngineTests.swift:1507` (2,000 件を全件走査) | ✅ |
| 推定高さの実測は項目単位ではなく上限つきの固定長で保持する (SHALL) | `KsEstimatedHeight.swift:32` (`sampleCapacity = 32`)、`:102-104` | `KsEstimatedHeightTests.swift:135` | ✅ |
| 判定は 3 状態、未判定のままで完了と報告しない (SHALL NOT) | `kasane/handbook/cross/scroll-performance-gate.md` の 3 状態と再試行の節 | — (規約) | ✅ |
| 判定規則は cross、計測器と手順は ios の規約に従う (SHALL) | `kasane/handbook/cross/scroll-performance-gate.md` / `kasane/handbook/ios/performance-verification.md` (fixture・基準機・接続手順・取り出す数値・メモリの手順がいずれも実在) | — (規約) | ✅ |
| Scenario: 可変行高混在 10,000 件の手動フリック | fixture = Sample「大量件数」既定 10,000 件、手順 `handbook/ios/performance-verification.md` の「スクロール性能の手順」、操作列 `handbook/cross/scroll-performance-gate.md` | — | ⏳ (tasks 9.1) |
| Scenario: 迷いは未判定になる | 再試行規則 (非接続の対照 1 回 → なお迷えば未判定) `handbook/cross/scroll-performance-gate.md` | — | ⏳ (tasks 9.1。規則は実在) |
| Scenario: 往復後もメモリが定常化する | `samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:98` (上限 10)、`:102` (許容 2%)、`:110-122` (`runUntilSteady` と `KS` 接頭の記録)、`:129-175` (往復ごとの `phys_footprint` / 通過件数 / 成立判定)、`:241-248` (通過を `KsItemOffsetLookup` の通し番号で数える)、`:305-311` (定常判定) | `samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift:153` (往復ごとに 10000 / 10000 を確認し定常で止まる) | ⏳ (証跡の採取は tasks 9.3。駆動と自動判定は実装済み・テスト緑) |
| Scenario: 配列の置換で不要な保持が解放される | `KsCollectionViewController.swift:326-341` (生存セルだけを弱参照で数える)、`:484-646` (置換の差分適用) | `KsCollectionEngineTests.swift:1771` (2,000 件往復 → 置換 → 同時生存 < 可視 × 4)。塊分割後に 2 機種で再実行済み (tasks 7.6) | ✅ |
| Scenario: コレクションの破棄で全て解放される | 同上 (所有関係) | `KsCollectionEngineTests.swift:1811` (弱参照プローブが nil) | ✅ |

#### Requirement: 大量件数での仮想化・再利用 (Android)

本 change で `android/kscollectionview` (ライブラリ本体) には一切の変更が無い (`git show --stat 3567ba1 -- android/` と作業ツリーの差分で確認)。verify-001 の対応表をそのまま引き継ぎ、実機実行の状態だけを更新した。

| 条項 / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 絶対値の合格線は置かない (SHALL NOT) | `samples/android/benchmark/scripts/verify-fling-results.py` (定数は下限フレーム数と劣化率のみ)、`kasane/handbook/android/performance-verification.md` | `samples/android/benchmark/scripts/test_verify_fling_results.py` (26 件) | ✅ |
| 基準実機の代替はオーナー承認 + 証跡に明記 (SHALL) | `handbook/android/performance-verification.md` | — (規約) | ✅ |
| Scenario: 比較対象に対する薄さ | `samples/android/benchmark/.../LargeDataScrollBenchmark.kt`、比較対象の `animateContentSize` | `test_verify_fling_results.py` | ✅ (tasks 4.4 実施済み。`evidence/relative-fling-android-2026-09-15.md` = 合格、劣化はすべて 10% 以内) |
| Scenario: 可変行高混在 10,000 件の手動フリック (Android) | 手順 `handbook/android/performance-verification.md`、操作列 `handbook/cross/scroll-performance-gate.md` | — | ⏳ (下の「未対応」節を参照。現在の証跡 `evidence/manual-largeData-android-2026-09-08.md` は体感 合格だが**固定の操作列の制定前**の記録であり、Scenario の WHEN を満たしていない) |
| Scenario: 往復後もメモリが定常化する (Android) | `MemoryRoundTripScreen.kt` (連続 2 往復 2% 以内、通過件数の照合) | `LargeDataMemoryBenchmark.kt` | ✅ (tasks 4.6 実施済み。`evidence/relative-fling-android-2026-09-15.md` に 3 本の通過を記録) |
| Scenario: 配列の置換と画面離脱で保持が解放される (Android) | `MemoryRoundTripScreen.kt`、`MeasurementLifetime.kt` (プロセスに属する計数)、`MeasurementResultScreen.kt` (進捗の印)、`SampleNavHost.kt` | `LargeDataMemoryBenchmark.kt` の `assertReleased`、ホスト側 `MeasurementLifetimeTest.kt` / `MeasurementRoundTripCountingTest.kt` | ✅ (tasks 4.6 実施済み。置換後 ≤ 可視 × 4、離脱後 0 を確認) |

### samples

#### Requirement: 性能計測の自動実行 (MODIFIED)

本 change の改訂 (2026-09-16) でこの Requirement 本文は変わっていない。verify-001 の判定を再確認し、Android 側の実機実行が済んだ分を更新した。

| 条項 / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 計測モジュールを同じビルドルートに持つ / fixture は iOS と同じ / 比較対象に既定機能を付ける (SHALL) | `samples/android/benchmark/`、`MeasurementDestinations.kt`、`handbook/android/performance-verification.md` | — | ✅ |
| 事後検証: 最新 1 実行のみ・テスト名で対応付け・環境一致・フレーム数 90 未満は未判定・劣化 10% 以内 (SHALL) | `verify-fling-results.py` | `test_verify_fling_results.py` (26 件 0 failures、自分で再実行) | ✅ |
| 不合格・未判定・入力不正はいずれも非 0 終了 (SHALL) | `verify-fling-results.py` | 同上 | ✅ |
| 絶対値の合格線は判定しない / 件数を変えた比較の試行は持たない (SHALL NOT) | 定数は下限フレーム数と劣化率のみ。`SmallItemCount` は源泉に残らない | 同上 | ✅ |
| Scenario: 計測の再実行 | `LargeDataScrollBenchmark.kt` (3 秒 × 3 試行)、`LargeDataMemoryBenchmark.kt` (全項目通過の往復) | — | ✅ (tasks 4.4 / 4.6 実施済み) |
| Scenario: 事後検証 | `verify-fling-results.py` | `test_verify_fling_results.py` | ✅ |
| Scenario: 描画が少ない試行は未判定 | `verify-fling-results.py` | 同上 | ✅ |
| Scenario: 入力不正は判定しない | `verify-fling-results.py` | 同上 | ✅ |

#### Requirement: 計測専用の件数指定 (iOS) (ADDED)

| 条項 / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 起動引数で件数を指定できる / 指定が無ければ 10,000 (SHALL) | `samples/ios/KsCollectionViewSamples/LargeDataCount.swift`、`DemoData.swift` | `samples/ios/KsCollectionViewSamplesUITests/LargeDataCountUITests.swift:9` | ✅ |
| 不正値 (0・負数・非数値・値の欠落・複数指定) は既定へ戻さず起動を失敗させる (SHALL) | `LargeDataCount.swift`、`KsCollectionViewSamplesApp.swift` | `LargeDataCountUITests.swift:118`, `:123` (`XCTExpectFailure` + 起動状態の確認) | ✅ |
| 件数を表示し、Debug 構成ではさらに計数と「数え直し / 読み直し」の操作を持つ (SHALL) | `LargeDataDemoView.swift`、`LargeDataMeasurementBar.swift`、`samples/ios/KsCollectionViewSamples.xcodeproj/project.pbxproj:217` (Debug 構成に `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG`。tasks 8.2) | `LargeDataCountUITests.swift:9` (`#if DEBUG` 側で帯の存在)、`:37` | ✅ |
| 計数は操作したときだけ読み直され、スクロール中に自動更新されない (SHALL NOT) | 帯の「読む」操作でだけ計数を読み直す | `LargeDataCountUITests.swift:37` | ✅ |
| Scenario: 件数を指定して開く | `LargeDataDemoView.swift`、`LargeDataMeasurementBar.swift` | `LargeDataCountUITests.swift:9` (件数 2000 の表示 + 生成規則の一致) | ✅ |
| Scenario: 不正な件数 | 同上 | `LargeDataCountUITests.swift:118`, `:123` | ✅ |
| **Scenario: Debug 構成では計数を読める** (新規) | `KsLayoutDiagnostics.swift:36` (`reset`)、`LargeDataMeasurementBar.swift` の「数え直す / 読む」、`project.pbxproj:217` | `LargeDataCountUITests.swift:37` (送る → 読む → 数え直す → 短く送る → 読む で、後の値が前の値より小さいことを確かめ、数え直し前の分が混ざらないことを固定) | ✅ |

#### Requirement: iOS の計測ドライバの構成 (ADDED)

| 条項 / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 自動フリックによるスクロール性能の駆動は持たない (SHALL NOT) | `PerformanceDriverUITests.swift` に自動フリックは無く、`ScrollWindowSignpost` / `--signpost-scroll-window` は源泉に残らない。計測スキームの除外設定も整合 (`KsCollectionViewSamples.xcscheme` は `PerformanceDriverUITests` を除外、`KsCollectionViewSamplesPerformance.xcscheme` は他 2 クラスを除外) | 通常スキーム 9 件に計測ドライバが含まれないことを実行で確認 | ✅ |
| 「メモリの自動往復**だけ**を持つ (SHALL)」 | `PerformanceDriverUITests.swift:153`, `:163` に加え `:24` の画像グリッド観測駆動が残る | — | ⚠️ deviation 記録済み (退役対象は自動フリック 2 本と signpost。観測駆動は image-loading の証跡取得用。spec 文言は蒸留時に追随。`handbook/ios/performance-verification.md` は既に「2 つだけ」の表現へ改めてある) |
| 連続 2 往復の増分がいずれも 1 往復後の値の 2% 以内になるまで重ねる (上限 10) (SHALL) | `PerformanceVerificationView.swift:98`, `:102`, `:305-311` (基準は `footprints.first` = 1 往復後の値) | `PerformanceDriverUITests.swift:153` | ✅ |
| 往復ごとの `phys_footprint`・通過件数・最終判定を記録に出す (SHALL) | `PerformanceVerificationView.swift:155-158`, `:115-121` (`KS_PERF_*`) | `PerformanceDriverUITests.swift:198-204` | ✅ |
| 定常化しなければ未判定として失敗し、成功として終わってはならない (SHALL NOT) | `PerformanceVerificationView.swift:54-59` (自動実行モードは `exit(EXIT_FAILURE)`)、`:173` (判定)、`PerformanceDriverUITests.swift:210-214` | `PerformanceDriverUITests.swift:163` (上限 1 往復で定常に届かない状態を作り、失敗が記録されることを `XCTExpectFailure` で固定) | ⚠️ deviation 記録済み ([付随修正] `--verify-performance-auto` の終了コードを `EXIT_FAILURE` へ。8.3 の一部として実施) |
| Scenario: メモリの自動往復 | `PerformanceVerificationView.swift:110-175`, `:241-248` | `PerformanceDriverUITests.swift:153` | ✅ (駆動と判定。証跡の採取は tasks 9.3) |
| **Scenario: 定常化しなければ未判定** (新規) | `PerformanceVerificationView.swift:54-59`, `:173` | `PerformanceDriverUITests.swift:163` | ✅ |

#### Requirement: 保持対象の解放の自動確認 (Android) (ADDED)

| 条項 / Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 計測用の入口が置換 → 離脱の後に同時生存を読める自動走査を持つ (SHALL) | `MemoryRoundTripScreen.kt`、`MeasurementDestinations.kt` | `MeasurementRoundTripCountingTest.kt` | ✅ |
| カウンタはプロセスに属し、離脱後の値は結果画面の進捗の印から読める (SHALL) | `MeasurementLifetime.kt`、`MeasurementResultScreen.kt` | `MeasurementLifetimeTest.kt` (3 件) | ⚠️ deviation 記録済み (既存の `TemplateInvocationCounter` を共用せず `measurement` ソースセットに新設した理由) |
| Scenario: 置換と離脱の走査 | 同上 + `SampleNavHost.kt` | `LargeDataMemoryBenchmark.kt` の `assertReleased` | ✅ (tasks 4.6 実施済み) |

## 追加検査

### tasks.md の虚偽チェック

| グループ | 記載 | 対応表との整合 |
|---|---|---|
| 1 (規約と証跡の雛形) 1.1〜1.5 | すべて `[x]` | ✅ 一致 (verify-001 で確認済み。改訂後も規約 3 本と 4 本の証跡は実在) |
| 2 (iOS 推定高さと計測の足場) 2.1〜2.7 | すべて `[x]` | ✅ 一致 |
| 3 (Android 計測モジュール) 3.1〜3.6 | すべて `[x]` | ✅ 一致 |
| 4 (再計測と判定。最頻値化) 4.1〜4.6 | すべて `[x]` | ✅ 一致。4.1 は**不合格**の結果ごと証跡 (`evidence/manual-largeData-ios-2026-09-15.md`) と deviation に記録され、4.2 で Decision 3 の分岐 (提案改訂 + ios/ADR-0009 起票 + 再レビュー) に入っている。緑に見せる改竄は無い |
| 6 (内部セクション分割 — 試作) 6.1〜6.3 | すべて `[x]` | ✅ 一致。6.3 の証跡 `evidence/manual-largeData-ios-2026-09-16-prototype.md` は判定規則 (初回区間・到達件数・区間長差) を満たす形で残り、**到達件数が取得不能である旨を推定で埋めずに明示**している |
| 7 (内部セクション分割 — 本実装) 7.1〜7.7 | すべて `[x]` | ✅ 一致。7.6 の「2 機種以上」は自分でも倍率の異なる 2 機種で再現した (下のテスト節) |
| 7.8 | `[ ]` + **取り下げ (オーナー判断 A)** | ✅ 一致。実装もテストも入っておらず、取り下げの理由と A/B の結果が deviation に残る。**基準を緩めて通した形跡は無い** |
| 8 (計測の足場の追随) 8.1〜8.4 | すべて `[x]` | ✅ 一致 |
| 9 (再計測と判定。本実装後) 9.1〜9.3 | すべて `[ ]` | ✅ 一致 (未着手。`evidence/` に最終ビルドでの計測は無い) |
| 5 (仕上げ) 5.1〜5.2 | すべて `[ ]` | ✅ 一致 |

**未実装なのにチェック済みの項目は無い。**

### 逆流検査

`proposal.md` / `design.md` / `specs/**` は改訂コミット `3567ba1` (tasks 4.2 = Decision 3 に従う合意済みの改訂) 以降、**作業ツリーで一度も変更されていない**。グループ 6〜9 の実装期間中に足場を書き換えた形跡は無い。

### 付随修正の記録

`deviation.md` の `[付随修正]` 5 件 (`ImageGridBenchmark.kt` の KDoc / `handbook/android/performance-verification.md` のメモリ手順 / `MeasurementLifetime` の新設理由 / `--verify-performance-auto` の終了コード / `leadingVisibleID` の幾何ベース化) は、いずれも diff の該当箇所と一致する。

作業ツリーの差分のうち、Scenario にも `[付随修正]` にも直接は結び付かない変更は 1 件だけである。

- `kasane/handbook/cross/test-execution.md` の「計測ドライバ」の節: 「アサーションを持たない計測ドライバ」「合否ではなく Instruments 側の記録で判定する」という記述を、「観測のための駆動 / 判定を持つドライバ」の 2 種類に書き分ける形へ改めた。これは tasks 8.3 で計測ドライバが判定を持つようになった (Scenario「定常化しなければ未判定」) ことの規約側の追随であり、**改めなければ規約が実装と矛盾したまま残る**。したがって未記録の乖離ではなく Scenario に帰属する変更として扱ったが、tasks 8.4 が挙げる文書は `handbook/ios/performance-verification.md` だけであり、この文書名が tasks にも deviation にも現れないのは**記録の漏れ**である (下の「申し送り」を参照)

`kasane/lessons/inbox/` の差分は ksn-lesson の管轄で、本検証の対象外とした。

### 未記録の乖離

**無し。** 対応表に ❌ は 1 件も無い。

### テスト実行 (自分で再実行)

`handbook/cross/test-execution.md` に従い、絞り込みなしの全件実行で件数まで確認した。

| 対象 | コマンド / 機体 | 結果 |
|---|---|---|
| iOS ライブラリ (倍率 2) | `xcodebuild test -scheme KsCollectionView` / iPad Air 13-inch (M4) · iOS 26.4.1 | **Executed 200 tests, with 0 failures** (`** TEST SUCCEEDED **`) |
| iOS ライブラリ (倍率 3) | 同上 / iPhone Air · iOS 26.1 | **Executed 200 tests, with 0 failures** (`** TEST SUCCEEDED **`) |
| iOS Sample (通常スキーム) | `xcodebuild test -scheme KsCollectionViewSamples` / iPhone 17 Pro · iOS 26.5 | **Executed 9 tests, with 0 failures**。内訳は `LargeDataCountUITests` 4 / `InteractiveControlUITests` 3 / `ImageLoadingSlotUITests` 2 で、**`PerformanceDriverUITests` は含まれない** (分離が効いている) |
| iOS Sample (計測スキーム) | `xcodebuild test -scheme KsCollectionViewSamplesPerformance` / iPhone 17 · iOS 26.4.1 | **Executed 5 tests, with 0 failures**。内訳は `PerformanceDriverUITests` 3 / `ImageLoadingSlotUITests` 2。うち**判定を持つドライバは 2 件** (`test大量件数を全件通過で定常化するまで往復してメモリを記録する` と `test上限までに定常化しなければ未判定として失敗する`)、観測のための駆動が 1 件 (`test画像グリッドで基準点を切り送って戻す`) |
| Android 事後検証スクリプト | `python3 -m unittest discover -s samples/android/benchmark/scripts` | **Ran 26 tests — OK** |
| Android ライブラリ | `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` (XML 集計) | **130 tests / 0 failures** |

tasks 7.6 が要求する「画面サイズまたは倍率の異なる 2 機種以上」は、上の iPad Air 13-inch (M4) / iOS 26.4.1 (倍率 2) と iPhone Air / iOS 26.1 (倍率 3) で満たしている。

計測スキームの走行では、判定つきドライバの中身も spec どおりに動いた (証跡ではなく、駆動が成立していることの確認)。

- `test大量件数を全件通過で定常化するまで往復してメモリを記録する`: 3 往復で判定「定常」。往復ごとに通過 10000 / 10000 と `phys_footprint` が `KS_PERF_ROUND=` の行として出た
- `test上限までに定常化しなければ未判定として失敗する`: 1 往復で判定「未判定」となり、ドライバが失敗として記録された (`XCTExpectFailure` が拾って緑)。**未判定が成功として通らない**ことが実行で裏付けられている

### 本番経路の確認 (lessons: テストが本番と同じ経路を通しているか)

塊分割で新しく入った契約について、テストが簡略化した経路で緑になっていないかを確かめた。

- **塊の構造**: `KsSectionChunkingTests` は算出規則だけを固定するが、`KsCollectionEngineTests.swift:820` が**実 snapshot の section ごとの件数**を layout 別に照合しており、算出から snapshot までが繋がっている。さらに `:844` / `:948` は件数ではなく**実レイアウト属性の座標**で境界の行の埋まり・行間・余白を見ているため、「割り算は合っているが表示は崩れている」状態を通さない
- **塊をまたぐ検証であることの担保**: 塊を扱うテストはいずれも `numberOfSections > 1` を前提として明示的に固定しており (`:762`, `:948`, `:989`, `:1045`)、1 つの塊に収まってしまって検証が空振りする状態を失敗にしている
- **可視セルの存続**: `assertVisibleCellsSurviveWhereChunkUnchanged` (`:2419`) は「所属が変わらない可視セルが 1 件も無い」ときと「所属が変わる可視セルが 1 件も無い」ときの両方を失敗にする。送り先が境界から外れて**検査しない緑**になる抜けが塞がれている
- **アンカー**: `leadingVisibleID` を「可視一覧の最小 indexPath」から「表示範囲と矩形が重なる項目のうち先頭」へ直した経緯が deviation に残り、直す前は adaptive のテストが空振りしていたことも記録されている。テスト側も定数の決め打ちをやめ、**送って静止させた後に実測した先頭の項目**をアンカーに採っている
- **通過件数の数え方**: Sample の往復記録は `indexPath.item` ではなく本体の `KsItemOffsetLookup` を通した通し番号で数える (`PerformanceVerificationView.swift:241-248`)。塊をまたいで一意に数えられることは `KsCollectionEngineTests.swift:762` が本体の入口そのもので固定している。ドライバ側も往復ごとに 10000 / 10000 を確認しており、一度全件に届いた後の不完全な往復を見逃さない
- **未判定を緑にしない**: `PerformanceDriverUITests.swift:163` は上限 1 往復で「定常に届かない状態」を実際に作り、ドライバが失敗することを確かめている。判定を持つドライバの失敗化が、宣言だけでなく実行で裏付けられている
- **7.8 の取り下げ**: 取り下げの根拠は A/B の実測 (2 機種、倍率 2 と 3) で、基準値 (±5% / 3 回) を動かした形跡は無い。混在 2 列の判定は 9 系の実機計測へ送られており、届かない検査を未判定へ逃がす形にはなっていない

## 未対応 (合意済み・INVALID の根拠ではない)

- **tasks 9.1〜9.3 (本実装後の再計測と判定)**: 基準実機 (iPhone 11) でのオーナー操作が必要。足場 (件数指定の起動引数、Debug の計数帯、Release の計測スキーム、定常判定つきのメモリドライバ、実機の起動引数の順序と件数確認を含む規約) はすべて揃っており、実行待ち
- **tasks 5.1 (ADR の見直し) / 5.2 (lint と `log-sanitize.py`)**: 未着手
- **spec 本文の追随 (蒸留時)**: deviation 記録済みで、いずれも本検証では合意済み差分として扱った
  - 「iOS の計測ドライバはメモリの自動往復**だけ**」→ 画像読み込みの観測駆動を含む文言へ
  - 「推定高さは量子化した値」→ 「数えるときだけ量子化する」へ
  - 向き別列数の lcm の**縮退規則**の追記
  - 「表示範囲の先頭にあった項目が先頭に留まる」→ 「**同じ行**に留まる」へ
  - Scenario「混在 2 列でも合計高さの見積もりを損ねない」と Requirement の「複数列では行の高さの実測に基づき見積もる」の**除去** (取り下げ済み)
  - 「挿入した行の高さと行間の分だけ動き」→ 実測の観測 (0.0 pt) に合わせた表現へ

## 申し送り (判定には影響しないが、蒸留までに片付けたい)

1. **Android「可変行高混在 10,000 件の手動フリック」を採る担当タスクが無い。** Requirement (Android) の (2) と同名 Scenario は「基準実機で**固定の操作列**に従って手動フリックしたとき引っかかりを感じない」を求めるが、現在の証跡 `evidence/manual-largeData-android-2026-09-08.md` は自身の「操作条件」で**固定の操作列の制定前**の記録であり、以後の記録とは比較不能と明記している (体感の判定そのものは合格)。tasks 4.5 が扱うのは画像グリッドで、大量件数の採り直しはどのタスクにも無い。本 change で Android ライブラリ本体は一切変更していないため実害は小さいと見るが、**(a) 9 系に Android の大量件数の手動フリックを足す、(b) 「ライブラリ本体を変更していないため 2026-09-08 の証跡で足りる」と deviation に合意として記録する、のいずれかを選ばないと、Scenario の WHEN を満たさないまま完了になる。** 見立てとしては (b) が実態に合う
2. **`kasane/handbook/cross/test-execution.md` の改訂が tasks にも deviation にも記録されていない。** 内容は tasks 8.3 の当然の追随で、書き換えなければ規約が実装と矛盾する (乖離ではない)。8.4 の対象文書にこの 1 本を書き足すか、`[付随修正]` として 1 行残すのが素直

## 判定

**VALID。** デルタスペック 3 本の全 Requirement / Scenario について、改訂 (2026-09-16) と塊分割の影響を含めて実装とテストの対応が付いた。❌ (未記録の欠落・乖離) は 0 件、tasks.md の虚偽チェックは 0 件、足場の逆流は無し、自分で再実行したテストはすべて成功した (ライブラリ 200 件 × 2 機種、Sample 通常 9 件、Sample 計測 5 件、事後検証 26 件、Android ライブラリ 130 件)。オーナーの実機計測を要する Scenario は「足場は揃い実行待ち」であり、仕様と実装の不一致ではない。取り下げた 2 件 (7.8 関連) は基準を緩めずオーナー判断として記録されており、届かない検査を未判定へ逃がす形にはなっていない。
