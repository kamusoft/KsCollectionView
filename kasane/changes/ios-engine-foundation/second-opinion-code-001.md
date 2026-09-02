# セカンドオピニオン: ios-engine-foundation (code-001)
**相方**: claude / **label**: so-code-ios-engine-foundation / **日付**: 2026-09-02 / **対象**: 現在の HEAD に対する ios/・samples/ios/・change 成果物一式
---
レビューを完了しました。ビルド/テスト結果はホスト提供の客観値（Debug 25/25、Release 26/26、Sample Debug build 成功）を前提とし、静的レビューとして規約照合・仕様照合・コード精査を行いました。

---

# 独立コードレビュー結果: ios-engine-foundation

**日付**: 2026-09-02
**判定**: **CHANGES_REQUESTED**

## サマリー

エンジンの骨格（diffable + `UIHostingConfiguration` + 自前 compositional layout）と DSL の形は ADR / design の決定に忠実で、翻案移植の設計判断も妥当です。一方で、**公開契約に関わる最低対応 OS が合意なしに iOS 16 → iOS 26 へ引き上げられている**ことが最も重大で、加えて区切り線・ヘッダー/フッター・長押し後のタップ・タップフィードバックに実行時の実害がある欠陥が残っています。さらに、複数のテストがアサーションを持たないまま `evidence/verification-matrix.md` に「Scenario の検証根拠」として計上されており、テストの green が仕様充足の証拠になっていません。性能 Requirement（tasks 8.1〜8.3）は未実施のため、この change は現状アーカイブ可能な状態にありません。

## 照合した規約

- `handbook/cross/comment-policy.md` (always) — lint 0 件、公開 doc コメントも内部用語なし。適合
- `handbook/cross/public-identifiers.md` (`ios/Package.swift` を触るため) — package / product / bundle ID は適合
- `handbook/cross/sample-parity.md` (`samples/**` を触るため)
- `handbook/cross/test-execution.md` (テスト実行・報告)
- `handbook/cross/runtime-behavior-verification.md` (実行時挙動の完了判定)
- `handbook/cross/local-development-setup.md` (Sample scaffold の成立)
- `lessons/inbox/verify-interactive-collection-layout-transitions.md`（昇格前だが重点観点として参照）
- `decisions/core/ADR-0001`、`roadmaps/v1-foundation/roadmap.md` の前提/制約
- 標準 lint 3 本（comment-policy / local-path / identity）実行 — いずれも検出 0 件

---

## 指摘事項

### 🔴 Critical 1. 最低対応 OS が合意なく iOS 16 → iOS 26 へ引き上げられている

**該当箇所**: `ios/Package.swift:8`、`samples/ios/KsCollectionViewSamples.xcodeproj/project.pbxproj:120,131,147,169`

**問題点**: `roadmaps/v1-foundation/roadmap.md:24` は「最低対応 OS: **iOS 16+** (`UIHostingConfiguration` 依存)」を前提/制約として確定しており、`handbook/cross/local-development-setup.md:25` も「決定済みの下限」表に iOS 16 を掲げ、`decisions/core/ADR-0001` の採用根拠も「`UIHostingConfiguration` (iOS 16+)」に立っています。`phases/phase-6-drag-reorder/agenda.md:7` に至っては「最低 OS 16 のため当面使えない」と将来判断の前提にしています。実装は `.iOS(.v26)` / `IPHONEOS_DEPLOYMENT_TARGET = 26.0` で、iOS 16〜25 の全利用者を締め出します。proposal / design / deviation.md のいずれにも根拠がなく、`deviation.md` の「iOS 26 のセル登録準備」は開発環境の話であって対応下限の引き上げ根拠にはなりません。実装コードにも iOS 26 を要する API は見当たりません（`UIHostingConfiguration`・`repeatingSubitem:count:`・`ContinuousClock` はいずれも iOS 16）。`public-identifiers.md`「してはいけないこと」の「ADR の規範値と実装値を食い違わせたまま進めない」に真正面から抵触し、かつ proposal 自身が「公開 API はこの change で初めて世に出るため以後の変更コストが高い」と書いた対象そのものです。

**推奨修正**: `.iOS(.v16)` へ戻し、iOS 16 での実ビルドを通す。引き上げが必要と判断するなら実装で決めず、ロードマップの前提改訂 + ADR 起票（`ios` ドメイン）を経てから反映する。判断が必要なため、この 1 点は **NEEDS_DISCUSSION** 相当として扱ってください。

---

### 🟠 Major 2. 重複 ID が release ビルドでクラッシュする

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:207-210`

**問題点**: `Dictionary(uniqueKeysWithValues:)` はキー重複時に **debug / release を問わず** trap します。デルタスペックは「重複 ID は不正入力であり、debug ビルドでは assertion で検知する」としており、release の即時クラッシュは要求されていません。同スペックが未登録キーについて「release ビルドではクラッシュせず」と定めているライブラリ方針とも非対称です。しかも `KsSnapshotPlanner.swift:12` の `assert` が先に落ちるのは debug のみで、release では `Fatal error: Dictionary(uniqueKeysWithValues:): Duplicate values for key` という原因の読めないメッセージで落ちます。

**失敗シナリオ**: サーバ由来のデータで同一 ID が 2 件混入 → release アプリが起動直後に強制終了。

**推奨修正**: `Dictionary(items.map { ... }, uniquingKeysWith: { _, new in new })` 等の非 trap 構築に変え、重複検知は planner の `assert`（debug）に一本化する。release は先勝ち/後勝ちを決めて警告ログを出す。

---

### 🟠 Major 3. 区切り線が index 変化に追随せず、二重表示・欠落が起きる

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:168-181`（`configure(cell:at:)`）、`:59-67`

**問題点**: 上端の区切り線は `indexPath.item == 0` で判定され、この判定は **セルの dequeue / reconfigure 時にしか走りません**。`update(configuration:)` が `reconfiguringAllItems` を立てるのは `layoutKindChanged` のときだけなので、レイアウト不変のままデータだけが変わると、位置がずれた既存セルの区切り線が更新されません。`deviation.md` で「先頭行の上にも区切り線」「最終行の Bottom にも全幅の区切り線」がオーナー確定値になっている以上、先頭行の表現崩れは合意済み仕様への違反です。

**失敗シナリオ**: 先頭に 1 件挿入 → 新セル（index 0）に上線が付き、下へずれた旧先頭セルも上線を保持したままで、2 本目の線が行の途中に残る。逆に先頭 1 件を削除すると、新しい先頭行に上線が付かない。`lessons/inbox` に記録されている「操作後にだけ現れる不具合」と同型です。

**推奨修正**: 差分適用後に先頭・末尾に関わる可視セルを再構成する（`apply` の completion で `updateVisibleCellSeparators()` を呼ぶ）か、上線を「セル単位の状態」ではなくセクション先頭のレイアウト装飾として持たせる。あわせて「先頭に挿入しても線が 1 本」の回帰テストを追加する。

---

### 🟠 Major 4. ルートヘッダー / フッターがデータ更新後に再構成されない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:116-141`、`:36-68`

**問題点**: supplementary の登録ハンドラは dequeue 時にしか呼ばれず、`update(configuration:)` にも `apply(...)` にも supplementary を再構成する経路がありません。ヘッダー/フッターのクロージャが外部状態を参照している場合、表示が更新時点で固まります。本 change で更新した `kasane/roadmaps/.../dsl-samples.md` の Swift 例がまさに `.footer { Text("全 \(fruits.count) 件") }` であり、**公式サンプルとして提示している書き方が動かない**状態です。

**失敗シナリオ**: `fruits` が 6 件 → 8 件に増えても、フッターは「全 6 件」のまま（画面外へスクロールして戻すまで直らない）。

**推奨修正**: `apply` の中でヘッダー/フッター宣言の有無・内容更新を検知して該当 supplementary を再構成する（`collectionView.supplementaryView(forElementKind:at:)` へ再 configure、または section の再適用）。修正できないなら、`dsl-samples.md` の動的フッター例を静的な文言に差し替えたうえで制約を明記する。

---

### 🟠 Major 5. 長押しした項目への「次のタップ」が握り潰され、Set が無制限に増える

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:349`、`:431-441`

**問題点**: `handleLongPress` は `.began` の時点で ID を `longPressConsumedIDs` に入れますが、この Set から削除されるのは `didSelectItemAt` が呼ばれたときだけです。`UILongPressGestureRecognizer` が認識すると collection view 側のタッチ追跡は通常キャンセルされ、`didSelectItemAt` は呼ばれません。その結果 ID は残り続け、**同じ項目を次にタップしたときに `onItemTap` が発火しません**（そこで初めて Set から抜ける）。項目数が多い画面で長押しを繰り返せば Set は単調増加します。

**失敗シナリオ**: リストで「Apple」を長押し（`onItemLongTap` 発火）→ 続けて「Apple」をタップ → ハイライトは出るが `onItemTap` が発火しない。2 回目のタップで初めて発火する。

**推奨修正**: 長押しとタップの排他は「長押しが成立したタッチ」に限定してスコープする（`recognizer.state == .ended/.cancelled` で該当 ID を除去する、または直近 1 件のみを短時間だけ保持する）。あわせて「長押し → タップ」の回帰テストを追加する。

---

### 🟠 Major 6. `touchFeedback(color:)` のハイライトがセル内容の背後に描かれ、見えない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:420-425`、`samples/ios/KsCollectionViewSamples/DemoListRow.swift:20`、`DemoGridCell.swift:17`

**問題点**: ハイライトは `cell.backgroundConfiguration` に色を置く実装ですが、`UIHostingConfiguration` のコンテンツは背景の**上**に描かれます。Sample のセルは `.background(SampleTheme.cell)`（不透明な白）を敷いているため、`ListDemoView.swift:27` で指定した `touchFeedback(color:)` は視認できません。デルタスペックは「タップ時はセル選択・ハイライト機構によるフィードバックが表示され (SHALL)」「`touchFeedback(color:)` で色を指定できる (SHALL)」と定めており、**セルが背景色を持つという最も一般的な使い方でこの SHALL が成立しません**。しかも Sample はパリティ検証装置なので、Android 側と比較すべき挙動をそもそも観測できません。

**失敗シナリオ**: `DemoListRow` を使う「リスト」画面で行をタップしても、色の変化が一切見えない。

**推奨修正**: ハイライトを `backgroundConfiguration` ではなくセル内容の**上**へ載せる（オーバーレイビュー、または `UIHostingConfiguration` の外側に配置した半透明レイヤ）。もしくは背景方式を維持するなら、Sample 側でセル背景をライブラリに委ねる形へ改め、仕様側の制約として明記する。

---

### 🟠 Major 7. スクロール命令の順序保証（core/ADR-0007）が無検証で、成立が疑わしい

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:444-457`

**問題点**: `receive` は `isApplyingSnapshot` が false のとき `Task { await Task.yield() }` で flush を予約します。SwiftUI から「配列追加 → `scrollToEnd()`」を同一処理内で呼んだ場合、`scrollToEnd()` の時点ではまだ `updateUIViewController` が走っておらず `isApplyingSnapshot` は false です。SwiftUI のビュー更新コミットと main actor task の実行順は保証されないため、flush が先に走ると `.end` は `dataSource.snapshot().itemIdentifiers.last`（**追加前の末尾**）を掴んで終わります。デルタスペックの Scenario「データ反映後のスクロール実行 — 追加された新要素まで確実にスクロールする (反映前の末尾で止まらない)」を満たさないおそれがあります。

さらに、この経路は**テストが 1 件もありません**。`KsScrollControllerTests` は attach/detach しか見ておらず、`KsCollectionEngineTests` は全ケースで `scrollController: nil` です。Sample の `ScrollControlDemoView` にもデータ更新と併用するデモがなく、手動でも検証できません。

**推奨修正**: 「未反映の配列変更が保留中か」を明示的に持つ（例: SwiftUI 更新の到達を待つのではなく、命令を必ず 1 回の `apply` サイクルの後段へ載せる）設計に変える。あわせて、追加 + `scrollToEnd` を同一同期ブロックで実行して最終 indexPath が新要素になることを検証する統合テストを追加し、Sample にも「末尾に追加してスクロール」操作を置いて実機確認可能にする。

---

### 🟠 Major 8. セル内インタラクティブ要素との競合回避が `UIControl` 限定で、SwiftUI Button に効かない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:405-414`、`:431-441`

**問題点**: `gestureRecognizer(_:shouldReceive:)` は `touch.view` の親を辿って `UIControl` を探しますが、`UIHostingConfiguration` 内の SwiftUI `Button` / `Toggle` は `UIControl` ではありません。よって長押し経路のガードは効きません。さらにタップ経路（`didSelectItemAt`）にはガードが一切なく、セル選択の抑止は OS 任せです。デルタスペックは「セル内のインタラクティブ要素 (ボタン・トグル等) がタッチを処理した場合、アイテムのタップコールバックとフィードバックは発火しない (SHALL NOT)」を明示要求しており、Scenario「セル内ボタンとの競合」も定義されています。実装上の担保がなく、Sample にもボタン入りセルのデモがないため（9 画面のいずれもボタンを持たない）、**この Scenario は unit / Simulator / 実機のどの層でも検証されていません**。`evidence/verification-matrix.md` は「実機手動: Button…を操作確認」と書いていますが、対応するデモ画面が存在しません。

**推奨修正**: セル内にボタンを含むデモ（例: 「リスト」画面のセルへボタンを 1 つ追加）を用意して実挙動を確認し、必要なら `shouldReceive` の判定を「hitTest 結果が SwiftUI のインタラクティブ領域か」で判断する方式へ変える。検証できるまで verification-matrix の当該行を「未検証」に直す。

---

### 🟠 Major 9. アサーションを持たないテストが、Scenario の検証根拠として計上されている

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsPublicAPITests.swift:23-70`（3 件すべて）、`KsTemplateRegistryTests.swift:29-36`、`KsScrollControllerTests.swift:14-20`

**問題点**: `KsPublicAPITests` の 3 件は `_ = view.body` で終わり、期待値の検証が 1 つもありません（実質コンパイル確認）。`testReleaseでは未登録キーを空セルへ解決する` も `_ = registry.content(...)` のみで、「空セルが返る」「警告ログが出る」「件数が一致する」のいずれも確認していません。それにもかかわらず `evidence/verification-matrix.md` は `KsPublicAPITests.test非Identifiable型をidキーパスで組み立てられる` を「非準拠型の `id:`」Scenario の Simulator 統合検証として計上しています。当該 Scenario の THEN は「全件が描画され、差分更新も `itemId` を identity として動作する」であり、組み立てが通ることは何の証拠にもなりません。ksn-review の「テスト内の手抜き（言い訳コメントでの実質スキップ）」に該当します。

**推奨修正**: `KsPublicAPITests` は `KsCollectionViewController` まで通して件数・identity・テンプレート解決結果を検証する。release fallback テストは返却ビューが fallback であることを判定できる形（fallback 用の内部フラグ等）で検証する。検証できない行は verification-matrix から外す。

---

### 🟠 Major 10. `KsLayoutMetrics.itemWidth` は本番未使用で、spacing / adaptive の検証が実レイアウトを検証していない

**該当箇所**: `ios/Sources/KsCollectionView/KsLayoutMetrics.swift:22-30`、`ios/Tests/KsCollectionViewTests/KsLayoutMetricsTests.swift:24,34,65`

**問題点**: `itemWidth` を呼ぶプロダクションコードは存在しません（`makeLayout` は `fractionalWidth` と `interItemSpacing` に委ねている）。つまり `test余白と列間を除いた幅を均等配分する` と `testAdaptiveは最小幅を下回らない最大列数を返す` の幅検証部分は、**実際の描画に一切影響しない関数の算術を検証している**だけです。verification-matrix は「spacing / contentPadding」「adaptive の余剰幅配分」の unit 検証として `KsLayoutMetricsTests` を挙げていますが、根拠になっていません。同様に `KsTemplateRegistry.contains` (`KsTemplateRegistry.swift:33`) もテスト専用です。

**推奨修正**: `itemWidth` を `makeLayout` の実計算に使う（`fractionalWidth` をやめて絶対幅を与える）か、関数を削除して幅の検証を `layoutAttributesForItem` ベースの統合テスト（`KsCollectionEngineTests` の `visibleCellWidths` と同型）へ移す。

---

### 🟠 Major 11. tasks.md に、実装/テストが伴わないチェックがある

**該当箇所**: `kasane/changes/ios-engine-foundation/tasks.md:20`（2.6）、`:47`（6.3）

**問題点**:
- 2.6 は「最小契約 (indexPath → アイテム変換・cancel 通知) の unit test を含める」と書かれ `[x]` ですが、`KsPrefetcherTests` は型消去クラス `KsAnyPrefetcher` の委譲しか見ておらず、**indexPath → アイテム変換**（`KsCollectionViewController.swift:389-403`）を通るテストはありません。`KsCollectionEngineTests` は全ケース `prefetcher: nil` です。
- 6.3 は「タップ・スクロール命令キュー・未接続 no-op」と書かれ `[x]` ですが、指摘 7 の通り命令キュー（`receive` / `flushPendingCommands` / `isApplyingSnapshot`）のテストは存在しません。

**推奨修正**: 該当テストを追加してからチェックする。追加しないなら tasks の記述を実態へ合わせ、未達分を残タスクとして明示する。

---

### 🟠 Major 12. handbook の「実装時に追記する」トリガーが発火しているのに未追随

**該当箇所**: `kasane/handbook/cross/runtime-behavior-verification.md`「目視確認の観測点」節、`test-execution.md`「翻案元での実測知見」節、`local-development-setup.md`「Sample を開く / 実行する」「デモ画面一覧はどこを見るか」節

**問題点**: 3 文書がいずれも「**iOS エンジン基盤の実装時**に確定/追記する」と明記しています。特に runtime-behavior-verification は「iOS エンジン基盤 / Android ラッパー基盤の実装時が**最初の追記機会**になる」と名指ししており、本 change がその機会です。Sample scaffold も SwiftPM 構成も scheme も成立したのに、handbook は 1 文字も更新されておらず、tasks.md にも該当タスクがありません（design Decision 6 が distill 送りにしたのは performance-verification 規約のみで、この 3 件は対象外です）。

**推奨修正**: 本 change で追記するか、ksn-distill での実施を tasks / deviation に明記して追跡可能にする。少なくとも「デモ画面一覧の定義元は `samples/ios/KsCollectionViewSamples/SampleScreen.swift`」と、実測した `xcodebuild test` の scheme・destination・実行件数の確認方法は、確定した情報なので今書けます。

---

### 🟡 Minor 13. `Template` のキー重複が debug / release ともに無情報でクラッシュする

**該当箇所**: `ios/Sources/KsCollectionView/KsTemplateRegistry.swift:10-13`

**問題点**: `Dictionary(uniqueKeysWithValues:)` のため、`Template(.message)` を 2 つ書くと trap します。利用者の記述ミスに対する挙動として、メッセージが Swift 標準の内部エラーになり原因が分かりません。

**推奨修正**: `assert` で「キー \(key) のテンプレートが重複しています」を出したうえで、後勝ち（または先勝ち）で構築する。

---

### 🟡 Minor 14. `contentInsetAdjustmentBehavior = .never` により safe area が無視される

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:87`

**問題点**: スクロールインジケータを `contentPadding` に寄せない狙いは理解できますが、`.never` は safe area 由来の自動インセットも殺します。画面いっぱいにコンテンツが載る画面（`AdaptiveGridDemoView` / `LargeDataDemoView`）では、最終行がホームインジケータの下に潜り、そこから上へスクロールできません。デルタスペックが要求しているのは「インジケータが `contentPadding` に寄らないこと」だけで、safe area の無効化までは求めていません。

**推奨修正**: `.always`（または既定）に戻し、`contentPadding` は現行どおり `section.contentInsets` で表現する（インジケータは元々 `contentInsets` の影響を受けません）。長いコンテンツの画面で下端の到達性を目視確認する。

---

### 🟡 Minor 15. 性能ハーネスがどのターゲットにも属さず、参照が change アーカイブで切れる

**該当箇所**: `ios/PerformanceHarness/KsPerformanceHarnessView.swift`、`ios/PerformanceHarness/README.md:5`

**問題点**: `Package.swift` のどのターゲットにも含まれず、Sample の Xcode プロジェクトにも入っていないため、このファイルはコンパイル検証されません（受け入れ計測の土俵が、いつ壊れたか分からない状態で放置されます）。また README が `kasane/changes/ios-engine-foundation/evidence/...` を参照しており、change がアーカイブされると解決できなくなります。comment-policy が「作業文書のパスを参照しない」と定める理由がそのまま当てはまります。

**推奨修正**: Sample の Xcode プロジェクトへ「検証」区分の画面として取り込む（sample-parity の「プラットフォーム固有の技術検証画面」例外に該当）か、最低限ビルド対象へ入れる。README の参照は計測条件の要約を自己完結で書くか、恒久的な置き場（handbook）を指す形にする。

---

### 🟡 Minor 16. `SampleTheme.separator` が未使用で、区切り線の色がモックのトークンと無関係

**該当箇所**: `samples/ios/KsCollectionViewSamples/SampleTheme.swift:9`、`ios/Sources/KsCollectionView/KsHostingCell.swift:34`

**問題点**: `ui/brief.md` は separator `#D9D9DE` を確定トークンとして掲げていますが、実際の線はライブラリ内の `UIColor.separator`（システム semantic color）で描かれ、`SampleTheme.separator` は誰も参照していません。`sample-parity.md` の「色はプラットフォーム固有の semantic color を使わない」（プラットフォーム間で実値がずれるため）に照らすと、phase-3 の Android と並べたときに色差が出て、それが「本体の仕様差」か「Sample の差」か判別できなくなります。

**推奨修正**: 未使用トークンを削除して brief の確定値から外すか、区切り線色をライブラリの公開/内部トークンとして固定値化する。sample-parity の「本体既定値のプラットフォーム差」として `deviation.md` に追跡を残すのが最小対応です。

---

### 🟡 Minor 17. 「グリッド (固定列)」画面のセグメント文言だけ英語小文字

**該当箇所**: `samples/ios/KsCollectionViewSamples/FixedGridLayoutChoice.swift:2-3`、`FixedGridDemoView.swift:14`

**問題点**: Picker には `rawValue`（`list` / `grid`）がそのまま表示されます。ルートメニューは「リスト」「グリッド (固定列)」、他画面の操作列も「区切り線」「スペーシング」「余白」と日本語で統一されており、ここだけ表記が割れています。`sample-parity.md` は「表示文言の完全一致」「表記ゆれも不一致として扱う」と定め、Android がこの文言に一字一句追随する必要があります。

**推奨修正**: 「リスト」「グリッド」等の日本語表示名を持たせる（`rawValue` は識別子用に残し、表示は別プロパティに分ける）。

---

### 🟡 Minor 18. `KsAnyPrefetcher` が prefetcher を強参照し、命名も protocol と食い違う

**該当箇所**: `ios/Sources/KsCollectionView/KsAnyPrefetcher.swift:7-8`、`KsPrefetching.swift:5-6`

**問題点**: `prefetcher.prefetch` という未適用メソッド参照はインスタンスを**強参照**します。phase-8 で画像ローダを接続する際、ローダが画面や VC を保持していると容易に循環参照になります。また protocol 側は `cancelPrefetching`、消去側は `cancel` と名前が割れており、接続口の契約として読みにくくなっています。

**推奨修正**: `[weak prefetcher]` を挟んだクロージャで包む。メソッド名は `cancelPrefetching` に揃える。

---

### 🟡 Minor 19. 性能 Requirement が未検証のまま（アーカイブ不可）

**該当箇所**: `kasane/changes/ios-engine-foundation/tasks.md:63-66`、`evidence/performance-early-measurement.md`

**問題点**: 8.1〜8.3 が未チェックで、`performance-early-measurement.md` の計測結果は全行「未計測 / 保留」です。デルタスペック `collection-core` の Requirement「大量件数での仮想化・再利用」（hitch time ratio 5ms/s 未満、メモリ定常化）は本 change のスコープ内であり、design の Risks も「基準未達なら ios/ADR-0002 の再訪」と書いています。実機不在という状況の記録自体は誠実で適切ですが、**この Requirement が未充足の状態でアーカイブへ進めない**ことは明確にしておく必要があります。

**推奨修正**: 基準機（iPhone 11）での計測を実施するか、機材が確保できないなら「計測を後続 change へ切り出す」ことをオーナー判断として `deviation.md` に記録し、Requirement の扱いを確定させる。

---

### 🔵 Suggestion 20. `fractionalWidth(1 / columnCount)` は count ベース group では無視される

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:267-280`

`NSCollectionLayoutGroup.horizontal(layoutSize:repeatingSubitem:count:)` はサブアイテムのサイズ指定を使わず、`interItemSpacing` を差し引いた領域を均等分割します。`1 / columnCount` は読み手に「ここで幅を決めている」と誤解させるだけなので、`.fractionalWidth(1)` にして「幅は count ベース group が決める」旨のコメントを添えるのが正確です。

### 🔵 Suggestion 21. `rowSpacing` だけ modifier があり `columnSpacing` にない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionLayout.swift:33-35`

`.list.rowSpacing(4)` は書けるのに `.columnSpacing(_)` は無く、grid では初期化子引数でしか指定できません。公開 API の対称性として揃えるか、`rowSpacing(_)` を削って初期化子に一本化する方が説明コストが下がります（Android 側の DSL 対称性にも波及します）。

### 🔵 Suggestion 22. Sample のテンプレート宣言が dsl-samples の書き味と乖離している

**該当箇所**: `samples/ios/KsCollectionViewSamples/TemplateSwitchDemoView.swift:7,14`

`Template<TemplateDemoItem, TemplateDemoKind>(.message)` と全ジェネリクスを明記していますが、`dsl-samples.md` の推奨形は `Template(FeedItem.Kind.message) { (item: FeedItem) in ... }` で、`KsPublicAPITests` でもその形が通っています。Sample は「DSL の書き味の実証装置」なので、ドキュメントと同じ書き方に揃えてください。

### 🔵 Suggestion 23. テスト専用の公開面が本番型に残っている

**該当箇所**: `ios/Sources/KsCollectionView/KsHostingCell.swift:7-29`、`KsTemplateRegistry.swift:33`

`isTopSeparatorVisible` / `topSeparatorFrame` / `separatorZPosition` / `contentViewZPosition` / `contains` はテストからのみ使われます。`internal` なので実害は小さいものの、意図（テスト用の観測点）が読めるようコメントを添えるか、テスト側のヘルパへ寄せると本番型の責務が締まります。

### 🔵 Suggestion 24. `apply` の再入で `isApplyingSnapshot` が早期に false になる

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:240-245`

SwiftUI の連続更新で `apply` が重なると、先行 apply の completion が後続 apply の適用中に `isApplyingSnapshot = false` を書き、保留命令が適用途中に flush されます。カウンタ方式（`applyingCount`）か世代番号での判定にすると堅くなります。

## 突き合わせ結果 (2026-09-02)

ホスト側独立レビュー `review-001.md` とコード・仕様を再照合した。集計は双方一致 3 件、相方のみで採用 11 件、降格 10 件、未解決 0 件。

### 確定 — 双方一致

- #1 最低対応 OS: **Major**。iOS 16 は既存の決定値であり、iOS 26 指定は未記録の不整合。Critical / NEEDS_DISCUSSION は過大で、iOS 16 へ戻すのが既定解
- #5 長押し後の次タップ抑止: **Major**。消費 ID が選択通知でしか除去されず、別タッチへ持ち越される
- #19 性能 Requirement 未計測: **Major**。change の中核受け入れ条件であり、実機計測またはオーナーによる仕様再確定が必要

### 採用 — 相方のみ・根拠強

- #3 区切り線の index 追随: **Major**。先頭挿入・削除時に既存セルの Top / Bottom 状態を再構成する保証がない
- #4 supplementary 更新: **Major**。表示中の header / footer をデータ更新後に再構成する経路がない
- #6 touch feedback: **Major**。Sample の不透明なセル背景に `backgroundConfiguration` が隠れ、色指定を観測できない
- #7 スクロール命令順序: **Major**。`Task.yield()` は SwiftUI 更新コミット後を保証せず、統合テストもない
- #8 子 control 競合: **Major (未検証として採用)**。SwiftUI Button の内部実装断定は退けるが、必須 Scenario を検証するデモ・証拠がない
- #9 テスト証拠の過大計上: **Major**。compile / no-crash テストを描画・identity・fallback 全体の根拠として扱っている
- #10 未使用 `itemWidth` のテスト: **Minor**。本番レイアウトの spacing / adaptive を証明していない
- #11 tasks の虚偽チェック: **Major**。2.6 の indexPath → item と 6.3 の command queue に対応テストがない
- #12 handbook 追記漏れ: **Major**。iOS 基盤実装時という明示トリガーに未追随
- #15 性能ハーネス未所属: **Minor**。コンパイル保証がなく、README の active change 参照は archive 後に切れる
- #16 separator token 不一致: **Minor**。brief の確定 RGBA を Sample が参照せず、ライブラリは semantic color を使用している

### 降格 — 根拠弱・仕様外・好み

- #2 重複 ID release trap: 対応不要〜Suggestion。不正入力の release 縮退契約はない
- #13 Template キー重複診断: Suggestion。診断改善であり契約外
- #14 safe area: Suggestion 以下。親 SwiftUI 配置を含めた実害が未実証
- #17 セグメントの英語表記: 対応不要。日本語統一規約はなく、承認済み UI
- #18 prefetcher の strong 参照・命名: 対応不要〜Suggestion。所有契約と循環参照の具体的根拠がない
- #20 count-based group の fractionalWidth: Suggestion。可読性上の好み
- #21 columnSpacing modifier: 対応不要〜Suggestion。初期化子で契約を満たす
- #22 Sample の明示ジェネリクス: 対応不要〜Suggestion。同じ公開 DSL で機能差なし
- #23 internal テスト観測点: 対応不要。妥当な test seam
- #24 apply 再入 boolean: Suggestion として #7 に統合。単独の再現根拠は不足

### 未解決

なし。

---

## アクションプラン（優先度順）

1. **Critical 1** — 最低対応 OS を iOS 16 に戻す。引き上げるならオーナー判断 + ロードマップ改訂 + ADR 起票を先に行う（**判断が必要**）
2. **Major 2 / 3 / 5** — release クラッシュ、区切り線の追随漏れ、長押し後タップの握り潰し。いずれも回帰テスト付きで修正
3. **Major 6 / 8** — タップフィードバックの可視性とセル内ボタン競合。デルタスペックの SHALL / SHALL NOT に対し現状は実装上の担保も検証手段もない。Sample にボタン入りセルを追加して実挙動から決める
4. **Major 4 / 7** — ヘッダー/フッターの更新と、スクロール命令の順序保証。7 は統合テストの追加を必須とする
5. **Major 9 / 10 / 11** — 空アサーションのテストを実効化し、`itemWidth` を実レイアウトへ接続（または削除して統合テストへ移す）、tasks.md のチェックを実態に合わせる。あわせて `evidence/verification-matrix.md` の計上根拠を洗い直す
6. **Major 12** — handbook 3 文書の追記トリガーに追随、または追跡先を明記
7. **Minor 19** — 性能 Requirement の扱い（計測実施か後続切り出しか）を確定。**これが決まるまでアーカイブに進めない**
8. **Minor 13〜18 / Suggestion 20〜24** — 上記の対応と同じ回で拾えるものから順に
