# レビュー結果: ios-engine-foundation (006 回目)

**日付**: 2026-09-02
**判定**: APPROVED

## サマリー

修正サイクル 6 で確定した 11 件 (Major 4 / Minor 6 / 昇格 Suggestion 1) はすべてコード上で解消しており、いずれにも回帰テストまたは成果物の更新が伴っている。ビルドとテストは Debug 39 件 / Release 41 件 / Sample UI 3 件がすべて成功し、標準 lint 4 本も違反 0 件だった。修正による後退は確認できなかった。残る指摘は `evidence/verification-matrix.md` がサイクル 6 の追加検証を反映していない Minor 1 件と、前回から Suggestion のまま持ち越した項目のみである。

重要度別件数: **Critical 0 / Major 0 / Minor 1 / Suggestion 5**

## 実行結果

Simulator は `xcrun simctl list devices available` で存在を確認した機種・OS を使用した。

| 対象 | コマンド | 結果 |
|---|---|---|
| 本体 Debug | `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug` | Executed 39 tests, 0 failures |
| 本体 Release | 同上 + `-configuration Release ENABLE_TESTABILITY=YES` | Executed 41 tests, 0 failures |
| Sample UI (通常) | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` | Executed 3 tests, 0 failures |
| local-path lint | `python3 scripts/local-path-lint.py` | 違反 0 |
| identity lint | `python3 scripts/identity-lint.py` | 違反 0 |
| comment-policy lint | `python3 scripts/comment-policy-lint.py --advisory` | 検査対象 60 ファイル / 禁止 0 / 要確認 0 |
| doc-structure lint | `python3 scripts/doc-structure-lint.py` | exit 0 (警告のみ。指摘箇所は本 change が触っていない handbook / roadmap の既存ファイル) |

Release が Debug より 2 件多いのは `#if !DEBUG` で切られた `testReleaseでは重複IDを後勝ちで解決して表示を継続する` と `testReleaseでは未登録キーを空セルへ解決する` によるもので、両ビルド構成を回して初めて全 Scenario が走る構成になっている。

Sample の通常スキームの 3 件は `InteractiveControlUITests` のみで、`PerformanceDriverUITests` は 1 件も含まれていない。スキームの `SkippedTests` (`KsCollectionViewSamples.xcscheme:41-45` / `KsCollectionViewSamplesPerformance.xcscheme:41-45`) が相互に相手のクラスを除外しており、計測ドライバの分離は実際に効いている。

## 照合した規約

`kasane/handbook/cross/index.md` から、`always` と担当範囲 (ios/ 本体・samples/ios/・テスト実行・evidence) に当たる文書を本文までロードした。

| 文書 | 適用のきっかけ | 判定 |
|---|---|---|
| ソースコメント規約 | 常時 | 適用。lint 0 件に加え、本文基準でも作業文書パス・変更識別子・ローカル通番・履歴記述の混入なしを確認 |
| テスト実行規約 | テストを実行するとき | 適用。件数併記・Simulator 全件・Release の `ENABLE_TESTABILITY=YES`・スキーム分離をすべて実行手順として使用 |
| Sample のプラットフォーム間一致 | `samples/` を触るとき | 適用。文言集約・semantic color 不使用・検証画面のメニュー非掲載を確認 |
| 公開識別子と配布座標 | `ios/Package.swift`・pbxproj を触るとき | 適用。package / product / bundle ID が規約表と一致 |
| 実行時挙動の検証規約 | 実行時挙動の完了判定 | 適用。観測点表の追記と Sample 画面の対応を確認 |
| ローカル開発環境と Sample の実行 | 環境構築・Sample 実行 (guide) | 適用。記載された iOS 手順が実構成と一致することをコマンド実行で確認 |

`kasane/lessons/` に昇格済みルールは無いため (inbox のみ)、追加の重点観点・抑制対象は無い。参照した決定は core/ADR-0003・0004・0006・0007、ios/ADR-0001〜0004、cross/ADR-0002〜0004。concepts は未作成 (index のみ)。

## 前回指摘の追跡

`second-opinion-code-005.md` の「再突き合わせ」「オーナー判断」で確定した修正リストを追跡する。

| # | 出典 | 重要度 | 状態 | 確認結果 |
|---|---|---|---|---|
| 1 | code-005 Major-1 既定 touchFeedback が不透明 | Major | **解消** | `ios/Sources/KsCollectionView/KsCollectionViewController.swift:205` で既定が半透明の `.systemFill` になり、`test既定のtouchFeedbackは半透明でセル内容を隠さない` が解決済み色の alpha < 1 を固定している |
| 2 | code-005 Major-2 長押し認識器の常時有効化 | Major (再昇格) | **解消** | 認識器は生成時 (`:114`) と更新時 (`:59`) の双方で `onItemLongTap != nil` に連動。`testロングタップ未宣言のときは長押し認識器を無効にする` と、Sample UI テスト `test長押し未宣言時は長押し相当の保持でも通常タップを発火する` / `test長押し宣言時は同一タッチの通常タップを発火しない` が実タッチ経路で排他の両側を検証している |
| 3 | code-005 Major-3 位置変更時の全件 reconfigure | Major | **解消** | `KsCollectionViewController.swift:299-305` で reconfigure 対象は `plan.reconfigure` (と layout 種別変更時のみ全件) に限定。`positionsChanged` は適用要否の判定にのみ残る。`test挿入時に内容不変の要素のセルプロバイダを再実行しない` がセルプロバイダ呼び出し回数で固定 |
| 4 | code-001 #21 / code-005 Suggestion-3 スペーシングの DSL 語彙 | Major (再昇格・案 A) | **解消** | `KsCollectionLayout.swift:17-35` が `.list` / `.list(rowSpacing:)` / `.grid(columns:rowSpacing:columnSpacing:)` の引数形に統一され、`rowSpacing(_:)` modifier は撤去された。core/ADR-0006 の語彙と一致。dsl-samples.md の Swift / Kotlin 例と語彙表も同じ形へ追随済み |
| 5 | code-005 Minor-1 header / footer の再生成 | Minor | **解消** | `KsHostingSupplementaryView.swift:25-44` が同型 configuration ではホスティングビューを維持。`test内容不変のheader更新でホスティングビューを維持する` がインスタンス同一性で固定 |
| 6 | code-005 Major-4 不変更新時の O(n) 再構築 | Minor | **解消** | `apply` 冒頭 (`:247-253`) で `items == appliedItems` の早期脱出。`execute` は `appliedIdentifiers` を参照し `snapshot()` コピーを行わない。`test同一配列の再適用ではID解決もセル構成も行わない` と `test同一配列の再適用でも保留中のスクロール命令を実行する` が、早期脱出でスクロール命令が落ちないことまで固定 |
| 7 | code-005 Minor-5 verification matrix の機種不一致 | Minor | **解消** | `evidence/verification-matrix.md` の性能行が「iPhone 15 (代替機、deviation 記録済み)」になり、deviation.md と evidence の記述と一致 |
| 8 | code-001 #2 / code-005 Minor-2 重複 ID の release trap | Minor | **解消** | `KsCollectionViewController.swift:265-279` と `KsSnapshotPlanner.swift:15-16,39-51` が後勝ちで畳んで警告ログを出す。`testReleaseでは重複IDを後勝ちで解決して表示を継続する` が Release 構成で順序まで検証。契約の明確化は deviation.md 最終行に記録済み |
| 9 | code-001 #22 Sample のテンプレート宣言 | Minor | **解消** | `samples/ios/KsCollectionViewSamples/TemplateSwitchDemoView.swift:7,14` が `Template(TemplateDemoKind.message) { (item: TemplateDemoItem) in ... }` となり、dsl-samples.md の宣言形と一致 |
| 10 | code-005 Minor-4 PerformanceHarness | Minor | **解消** | `ios/PerformanceHarness/` は削除され、`ios/Package.swift` にも該当ターゲットは無い。fixture の二系統と iPhone 11 前提の README も同時に消えた |
| 11 | code-005 Suggestion-5 UI テストの固定 sleep | 昇格 | **解消** | 計測ドライバを `KsCollectionViewSamplesPerformance` スキームへ分離し、通常スキームから除外。handbook `cross/test-execution.md` に分離運用の節が追記され、実行でも分離を確認した |
| — | code-005 Suggestion-1 空データ時 `scrollToStart` | Suggestion | **未対応** | 修正リスト外。`KsCollectionViewController.swift:456` の `guard !appliedIdentifiers.isEmpty` は現状のまま (下記 Suggestion-3) |
| — | code-005 Suggestion-4 `Template` の無接頭辞 | Suggestion | **未対応 (オーナー提示待ち)** | phase-1 の確定語彙のため本 change の欠陥ではない。公開前の命名判断としてオーナーへ提示する扱いのまま |

`second-opinion-code-001.md` で降格が維持された指摘 (#13 テンプレートキー重複診断 / #14 safe area / #17 セグメント文言 / #18 prefetcher 強参照 / #20 fractionalWidth / #23 test seam / #24 apply 再入) は、いずれも再判定の根拠が変わっていないため再評価対象としない。

## 指摘事項

### 🟡 Minor: `evidence/verification-matrix.md` がサイクル 6 の追加検証を反映していない

**該当箇所**: `evidence/verification-matrix.md` (「tap / long tap / 子 control 競合」行、「セル再利用時の状態非保持」行、「動的切り替えの anchor」行)

**問題点**: この表は tasks 6.5 が定めた Requirement ⇔ 検証層の対応表であり、未実施の verify (ksn-verify) が指標として読む成果物である。しかし次の 2 点で実態とずれている。

- サイクル 6 で追加された長押しの排他検証 (`InteractiveControlUITests.test長押し宣言時は同一タッチの通常タップを発火しない` / `test長押し未宣言時は長押し相当の保持でも通常タップを発火する`、`KsCollectionEngineTests.testロングタップ未宣言のときは長押し認識器を無効にする`) が 1 つも載っていない。spec collection-interaction の「長押しが成立したタッチでは `onItemTap` を発火しない」は、前サイクルまで「同一タッチのテストが無い」と指摘されていた箇所であり、実装は解消したのに対応表からは解消したことが読めない
- 「実機手動」列に `iPhone 17 Simulator (iOS 26.5) で --verify-interactive-control を起動し` という Simulator での実施記録が入っている。列見出しと実施環境が食い違っており、Minor-5 で直したばかりの「計画値と実施内容の食い違い」と同型のずれが別の行に残っている

加えて「セル再利用時の状態非保持」行の unit 欄 (`prepareForReuse` で configuration 破棄) と「動的切り替えの anchor」行の unit 欄 (anchor 復元処理) は、テスト名ではなく実装の説明が書かれており、検証層の対応表として読むと根拠が特定できない。

**推奨修正**: 追加された 3 件のテストを対応する行へ記載し、Simulator での実施は「Simulator 統合」列へ移すか、列見出しを実施環境が分かる表現に合わせる。テスト名ではなく実装を書いている欄は、対応するテストがあればテスト名へ、無ければ「自動検証なし (実機手動で確認)」と明示する。

### 🔵 Suggestion-1: snapshot 世代判定が制御フローに寄与していない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:319-323`

**問題点**: `if generation == snapshotGeneration || applyingSnapshotCount == 0 { guard applyingSnapshotCount == 0 else { return } ... }` は、外側条件の第 2 項と内側 guard が同じ条件のため、全体として `if applyingSnapshotCount == 0 { ... }` と等価である。`generation` / `snapshotGeneration` は結果に影響せず、読み手に「世代でも制御している」と誤解させる。`second-opinion-code-005.md` で Suggestion へ降格された指摘の再掲であり、挙動不良は成立しない。

**推奨修正**: 世代番号が不要なら `snapshotGeneration` ごと削除して条件を `applyingSnapshotCount == 0` に単純化する。将来の再入制御のために残すなら、その意図をコメントで自己完結させる。

### 🔵 Suggestion-2: 既定 feedback の「内容を隠さない」判定がピクセル比較では成立していない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:480`

**問題点**: `XCTAssertLessThan(UInt8(highlightedPixels[0] & 0xFF), 255)` は合成後アルファを見ているが、`UIHostingConfiguration` の内容は `layer.render(in:)` で描画されないため、セル内容 (不透明な白背景) の有無にかかわらず 255 未満になる。この行はテスト名が主張する「内容を隠さない」を直接には示していない。同テスト末尾の `XCTAssertLessThan(alpha ?? 1, 1)` は既定色が不透明へ戻れば確実に落ちるため、Major-1 の回帰ガード自体は成立している。

**推奨修正**: ピクセル判定を残すなら UIKit のビューを重ねた土俵にするか、この 1 行を削って解決済み色のアルファ判定へ寄せる (テスト名と検証内容を一致させる)。

### 🔵 Suggestion-3: 空データ時の `scrollToStart` が no-op になる

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:456`

**問題点**: `guard !appliedIdentifiers.isEmpty else { return }` により、items が空でも大きな header があってスクロール可能な状態で `scrollToStart` が落ちる。spec collection-interaction の「未接続・接続解除後は no-op」とは別の経路であり、空データは未接続ではない。前サイクルから Suggestion のまま持ち越されている。

**推奨修正**: `.start` は items の有無に依らずコンテンツ先頭へのオフセット設定を行う (対象要素の解決を必要としないため)。

### 🔵 Suggestion-4: tasks 5.3 の「3 形」が proposal の Non-Goals と食い違う

**該当箇所**: `tasks.md:29`

**問題点**: `Template` result builder のタスクが「値キー / 型 / 単一クロージャの 3 形」と書かれてチェック済みだが、型ベースのテンプレート切り替えは proposal.md の Non-Goals で v1 実装から除外されており、実装も値キーと単一クロージャの 2 形しかない。実装は proposal に従っており正しい。足場側の記述が古いだけなので、本レビューでは書き換えを指示しない (足場は実装中凍結)。

**推奨修正**: 蒸留 (ksn-distill) の際に、この不一致を実装乖離メモとして扱うか、記録不要な足場の言い回しとして落とすかを判断する。

### 🔵 Suggestion-5: 項目が不変で外部 state だけが変わる更新ではセルが再構成されない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:247-253`

**問題点**: テンプレートのクロージャが items 以外の外部状態を捕捉している場合 (例: 画面側の表示モードでセルの色を変える)、items が `Equatable` 同値のままだと `apply` が早期脱出し、可視セルの内容が更新されない。spec collection-core の「内容変化の判定は `Equatable` 準拠による同値比較」に忠実な挙動であり違反ではない。またサイクル 6 以前も `hasSnapshotChanges` の guard で同じ結果になっていたため後退でもない。ただし利用者にとっては説明がないと踏みやすい。

**推奨修正**: dsl-samples.md の「iOS セル再利用の注意」と同じ場所に、「セルの表示に影響する値はすべて要素モデルに載せる」という趣旨の注記を足すことを検討する (公開ドキュメント整備は phase-7 のため、本 change での対応は必須としない)。

## 確認した観点 (指摘に至らなかったもの)

- **足場の凍結**: `proposal.md` / `design.md` / `specs/*/spec.md` は HEAD から未変更。`tasks.md` の差分はチェックボックスの `[ ]` → `[x]` のみで本文の書き換えは無い。2.4 の採番欠番は HEAD 時点から存在する
- **deviation.md**: 記録済みの 10 件はいずれも合意済み差分として扱った。`[付随修正]` は「iOS 26 のセル登録準備」1 件のみで、同一能力内・局所・テスト担保 (`test初回表示前にセル登録を準備して再利用セルを生成する`) の同梱条件に収まっている。区切り線の固定 RGBA・1pt 化・最終行 Bottom、iPhone の対応 3 方向、Slider の連続値、重複 ID の release 方針、性能基準機の代替はすべて記録済み
- **spec 適合の再確認**: 値キー解決 / 未登録キーの debug assertion と release フォールバック / `id:` キーパス / adaptive の列数式と余剰幅の均等配分 / `contentPadding` と `section.contentInsets` によるインジケータ不動 / 向き別列数の `environment.container.effectiveContentSize` 参照 (物理向き非依存、core/ADR-0006 適合) / 未接続・存在しない ID・複数接続の各 no-op と警告ログ — いずれも実装とテストで成立
- **M3 修正の副作用**: 位置依存の表示 (先頭行の Top 区切り線) は apply completion と `viewDidLayoutSubviews` の `updateVisibleCellSeparators()` で揃う。`test挿入削除並べ替え後に区切り線の位置を再構成する` が挿入・削除・並べ替えの 3 経路で位置を固定しており、reconfigure を外したことによる表示の取り残しは起きていない
- **M4 修正の副作用**: 早期脱出は `reconfiguringAllItems` (layout 種別変更) を除外条件に持つため、`FixedGridDemoView` のような「items 不変で list ⇔ grid を切り替える」経路ではセルが正しく作り直される。保留中スクロール命令の flush も早期脱出路で維持されており、専用テストがある
- **語彙の対称性**: dsl-samples.md の Swift / Kotlin 例と語彙表が同じ引数形に揃っており、Android (phase-3) が追随できる形になっている。Kotlin 側の `KsLayout.List(rowSpacing = 4.dp)` / `KsLayout.Grid(columns =, rowSpacing =, columnSpacing =)` も core/ADR-0006 と一致
- **公開識別子**: package / product `KsCollectionView`、Sample bundle ID `jp.kamusoft.kscollectionview.samples.ios`、UI テスト `....samples.ios.uitests`。最低対応 OS は `Package.swift` / pbxproj とも iOS 16 で、roadmap の前提と一致
- **Sample パリティ**: デモ 9 画面が `SampleScreen` に集約され、メニュー文言と画面タイトルは同一の `rawValue` を共有 (二重管理なし)。色はすべて `SampleTheme` の固定 RGBA で semantic color 不使用。検証専用 3 画面は launch 引数でのみ到達しメニューに出ないため、デモ画面の集合に混入していない。Android への追随は phase-3 として proposal / roadmap で追跡されている
- **証跡の衛生**: `evidence/` と `ui/verification/` は静止画と Markdown のみ。identity lint と local-path lint がともに 0 件で、生 trace・端末個体名・開発者識別子・ローカル絶対パスは保存されていない。pbxproj に `DEVELOPMENT_TEAM` は存在しない
- **ビルド生成物**: `ios/.build` `ios/DerivedData` `samples/ios/DerivedData` `xcuserdata` はいずれも `.gitignore` で除外済み (`git check-ignore` で確認)
- **テストの待機規約**: `waitUntil` は実時間 deadline・待機対象への実行機会の譲り (`Task.sleep`)・超過時の実測値付き失敗の 3 点を満たしており、handbook の「収束を待つアサーション」に適合している

## アクションプラン

1. **Minor** `evidence/verification-matrix.md` を、サイクル 6 で追加した長押し関連 3 件のテストと、Simulator 実施の記録位置に合わせて更新する (verify を走らせる前が望ましい)
2. **Suggestion-1〜3** は次サイクルまたは後続フェーズで判断してよい。Suggestion-1 (世代判定) と Suggestion-3 (空データ時 `scrollToStart`) はいずれも数行の整理で閉じる
3. **Suggestion-4** は蒸留時の判断項目として ksn-distill へ送る
4. **Suggestion-5** の利用者向け注記は phase-7 のドキュメント整備で扱ってよい
5. 本 change は L 級のため、アーカイブ前に verify (ksn-verify) が未実施である点はレビューの範囲外の残作業として引き継ぐ。`Template` の無接頭辞命名 (code-005 Suggestion-4) も、公開前のオーナー判断として未提示のまま残っている
