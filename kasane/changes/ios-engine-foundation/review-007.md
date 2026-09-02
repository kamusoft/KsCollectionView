# レビュー結果: ios-engine-foundation (007 回目)

**日付**: 2026-09-02
**判定**: APPROVED

## サマリー

修正サイクル 7 の確定リスト 12 件 (案 B / Major 2 / Minor 3 / Suggestion 3 / 同梱修正 2 群) はすべて解消しており、いずれにも回帰テストか成果物の更新が伴っている。ビルドとテストは Debug 51 件 / Release 53 件 / Sample UI 3 件がすべて成功し、標準 lint 4 本も違反 0 件だった。Simulator での操作確認 (レイアウト切替・区切り線 ON/OFF/ON・連続 Slider ドラッグ・末尾/先頭スクロール) でも表示の乱れは無く、修正による後退は確認できなかった。

重点として指示された 4 点はいずれも成立している。(a) 案 B の可視セル再構成は差分適用経路 (`plan.reconfigure` / `plan.reload`) を一切変えず、同値配列時の早期脱出でのみ働く。ID 解決を伴わないこと・保留中スクロール命令が落ちないことがテストで固定されている。(b) アンカー保持はアンカー自身が消えたときの近傍解決を含めて実装され、3 種のテスト (通常 / 先頭側大量挿入 / アンカー削除) が可視 ID で検証している。(c) `evidence/verification-matrix.md` が引用するテスト名 45 件は実在テスト 58 件の部分集合で、機械照合で不一致 0 件だった。(d) `[付随修正]` 2 件はいずれも同梱条件に収まりテストで担保されている。

残る指摘は、本 change が handbook に追加した観測点 1 行が Sample で観測できない Minor 1 件と、Suggestion 6 件のみである。

重要度別件数: **Critical 0 / Major 0 / Minor 1 / Suggestion 6**

## 実行結果

Simulator は `xcrun simctl list devices available` で存在を確認した機種・OS を使用した。

| 対象 | コマンド | 結果 |
|---|---|---|
| 本体 Debug | `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug` | Executed 51 tests, 0 failures |
| 本体 Release | 同上 + `-configuration Release ENABLE_TESTABILITY=YES` | Executed 53 tests, 0 failures |
| Sample UI (通常) | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` | Executed 3 tests, 0 failures |
| local-path lint | `python3 scripts/local-path-lint.py` | 違反 0 |
| identity lint | `python3 scripts/identity-lint.py` | 違反 0 |
| comment-policy lint | `python3 scripts/comment-policy-lint.py --advisory` | 検査対象 61 ファイル / 禁止 0 / 要確認 0 |
| doc-structure lint | `python3 scripts/doc-structure-lint.py` | exit 0 (警告のみ。うち 1 件は本 change が追加した箇所 — 下記 Suggestion-6) |

Debug 51 / Release 53 は前サイクル (39 / 41) から 12 件増で、増分はサイクル 7 で追加された `KsCollectionScenarioTests` 5 件・アンカー 3 件・`KsSwiftUIIntegrationTests` の親 State 反映 1 件・空データ先頭スクロール 1 件・未登録キーの準備時検知 1 件・同一配列再適用の可視セル再構成 1 件に対応する。Release が 2 件多いのは `#if !DEBUG` の 2 件によるもので、両構成を回して初めて全 Scenario が走る構成は維持されている。

Sample の通常スキームは 3 件のままで、`PerformanceDriverUITests` は 1 件も含まれない。スキームの `SkippedTests` が相互に相手のクラスを除外しており、計測ドライバの分離は引き続き効いている。

### Simulator での操作確認

`kasane/lessons/inbox/verify-interactive-collection-layout-transitions.md` の観測 (静止画と起動確認だけでは操作後の不具合を落とす) を踏まえ、Debug ビルドの Sample を iPhone 17 Pro Simulator (iOS 26.5) で操作した。デモデータと標準ステータス表示のみを観測しており、個人情報・端末固有の識別情報は扱っていない。

| 操作 | 結果 |
|---|---|
| ルートメニュー | 9 画面・順序・文言が `SampleScreen` と一致 |
| グリッド (固定列) で grid → list 切替 | 全行が全幅の一列へ切り替わり、乱れなし |
| リストでアイテムをタップ (親 `@State` 更新 → 同値配列で可視セル再構成) | 表示の乱れ・ちらつきなし |
| リストの区切り線 ON → OFF → ON | 全線が即時に消失・復帰 |
| スペーシングと余白で末尾までスクロール後、Slider を連続ドラッグ | 行間・列間・余白が追従し、表示は安定 |
| スクロール制御の「末尾」→「先頭」 | Item 100 到達後、先頭 (Item 1) へ復帰 |

## 照合した規約

`kasane/handbook/index.md` → `kasane/handbook/cross/index.md` から、`always` と担当範囲 (`ios/` 本体・`samples/ios/`・テスト実行・実行時挙動・evidence) に当たる文書を本文までロードした。ios / core / android ドメインの handbook はまだ存在しない。

| 文書 | 適用のきっかけ | 判定 |
|---|---|---|
| ソースコメント規約 | 常時 | 適用。lint 0 件に加え、本文基準でも作業文書パス・変更識別子・ローカル通番・履歴記述・公開 doc コメントへの内部用語混入がないことを確認 |
| テスト実行規約 | テストを実行するとき | 適用。件数併記・Simulator 全件・Release の `ENABLE_TESTABILITY=YES`・スキーム分離をすべて実行手順として使用 |
| 実行時挙動の検証規約 | 実行時挙動の完了判定 | 適用。サイクル 7 の修正が実行時挙動に触れるため、観測点表を事前に読んで上記の操作確認を行った |
| Sample のプラットフォーム間一致 | `samples/` を触るとき | 適用。文言の一元化・semantic color 不使用・検証画面のメニュー非掲載を確認 |
| 公開識別子と配布座標 | `ios/Package.swift`・pbxproj を触るとき | 適用。package / product / bundle ID が規約表と一致 |
| ローカル開発環境と Sample の実行 | 環境構築・Sample 実行 (guide) | 適用。本 change が追記した iOS 手順を実際に実行し、記述どおり動くことを確認 |

`kasane/lessons/` に昇格済みルールは無い (inbox 3 件のみ) ため「指摘しないこと」の制約は無い。inbox の `verify-interactive-collection-layout-transitions` (scope: code-review) は昇格前だが観点として妥当なため、上表の操作確認として取り入れた。参照した決定は core/ADR-0003・0004・0006・0007、ios/ADR-0001〜0004、cross/ADR-0002〜0004。concepts は未作成 (index のみ)。

## 前回指摘の追跡

`second-opinion-code-006.md` の「突き合わせ結果」「オーナー判断」で確定した修正リストを追跡する。

| # | 出典 | 重要度 | 状態 | 確認結果 |
|---|---|---|---|---|
| 1 | code-006 Major-1 → オーナー判断 案 B | 案 B | **解消** | `ios/Sources/KsCollectionView/KsCollectionViewController.swift:289-295` の早期脱出が `reconfigureVisibleCells()` を呼ぶ。`KsSwiftUIIntegrationTests.test配列が同値でも親のState変更を可視セルへ反映する` が `UIHostingController` 上で親 `@State` の反映を、`KsCollectionEngineTests.test同一配列の再適用ではID解決を行わず可視セルだけ再構成する` が ID 解決 0 回とセル構成 +1 回を固定。`deviation.md` に案 B として記録済み |
| 2 | code-006 Major-2 アンカー復元 | Major | **解消** | `:60-65` で切り替え直前の先頭可視 ID と旧順序を捕捉し、apply 完了後に `:445-474` で復元。`survivingAnchor` がアンカー消失時に旧順序の直後 (無ければ直前) の生存要素へ落とす。`testリストからグリッドへの切替後も先頭可視要素を表示範囲に残す` / `.testレイアウト切替と同時の先頭側への大量挿入でもアンカーを保つ` / `.testレイアウト切替と同時にアンカーが消えたら近傍要素を表示範囲に残す` が可視 ID で検証 |
| 3 | code-006 Major-3 tasks / matrix の過大計上 | Major | **解消** | `evidence/verification-matrix.md` は冒頭で「実在するテスト名と観測内容だけを書く」と宣言し、実装の説明だった欄は「自動検証なし」へ置換済み。表が引用するテスト名 45 件をソースの `func test...` 58 件と機械照合し、不一致 0 件。新設の `KsCollectionScenarioTests` 5 件 (内容変更の再構成 / キー変更でのセル置換 / `id:` キーパス / 可変行高 / state 非保持) が、これまで対応テストの無かった Scenario を実描画で埋めている |
| 4 | code-006 Minor-1 未登録キーの assertion 遅延 | Minor | **解消** | `:194-205` の `prepareRegistrations` が `registry.contains` で snapshot 準備時に検査。`test未登録テンプレートキーをsnapshot準備時に検知する` が、画面外 (60 件表示中の 61 件目) の要素でも可視化を待たずに検知されることを固定 |
| 5 | code-006 Minor-2 tasks 3.2 の翻案記述 | Minor | **解消** | `deviation.md` に「翻案元の補正は行わず `UIHostingConfiguration` と `.estimated` の自己サイズだけで成立」と記録。可変行高は `KsCollectionScenarioTests.test本文量の異なる行はそれぞれ必要な高さになる` が実レイアウト属性の高さで検証 |
| 6 | code-006 Minor-3 テンプレートキー有限性の注意書き | Minor | **解消** | `dsl-samples.md` の値キー例の直後に「テンプレートキーはセルの表示種別を表す有限集合にする」旨の注記が追加された |
| 7 | code-006 Suggestion 空データ時 `scrollToStart` | Suggestion | **解消** | `:519-525` が `.start` を対象要素の解決なしのオフセット設定へ変更。`test空の項目でも先頭へのスクロール命令でheaderの先頭へ戻す` が items 0 件 + 2,000pt header で固定。Simulator の「スクロール制御」でも末尾→先頭の復帰を確認 |
| 8 | code-006 Minor tasks 5.3「3 形」 | Minor | **解消** | 足場は書き換えず `deviation.md` に「実装は値キーと単一クロージャの 2 形」を記録 |
| 9 | review-006 Suggestion-1 世代判定のデッドコード | Suggestion | **解消** | `snapshotGeneration` は撤去され、apply 完了時の条件は `applyingSnapshotCount == 0` 単独になった |
| 10 | review-006 Suggestion-2 既定 feedback のピクセル判定 | Suggestion | **解消** | 合成後アルファの単独判定は撤去され、通常時と押下時の描画差 (`renderedImageData` / `renderedPixels`) と解決済み色のアルファ判定へ寄せられた |
| 11 | オーナー判断 accessibility 依存テスト 2 件 | 同梱修正 | **解消** | `KsCollectionEngineTests.swift:24-35` の `ControlRow` が `UIViewRepresentable` の `UIButton` になり、accessibility 設定に依存せず `UIControl` として判定される。SwiftUI `Button` の実座標経路は Sample UI テストが担う旨がコメントで自己完結している |
| 12 | オーナー判断 `Template` 推論形 / 無接頭辞 | 申し送り | **解消** | `deviation.md` に暫定である旨、phase-3 agenda に「phase-2 からの申し送り (着手前に対応する)」として API 候補付きで記録された |

`second-opinion-code-005.md` の確定リスト 11 件 (review-006 の追跡表で解消確認済み) は、いずれも今回のコードで維持されていることを再確認した。特に、案 B で追加された `reconfigureVisibleCells()` は差分適用側の `plan.reconfigure` / `plan.reload` を一切変えないため、code-005 Major-3 (位置変更時の全件 reconfigure) と Major-4 (不変更新時の O(n) 再構築) の修正は後退していない。`test挿入時に内容不変の要素のセルプロバイダを再実行しない` が引き続き green であることが、その境界を固定している。

`second-opinion-code-001.md` で降格が維持された指摘は、再判定の根拠が変わっていないため再評価対象としない。

## 指摘事項

### 🟡 Minor: handbook の観測点表に、Sample では観測できない項目がある

**該当箇所**: `kasane/handbook/cross/runtime-behavior-verification.md` (観測点表「グリッド (固定列)」行)

**問題点**: 本 change が追加した観測点表に「list / grid 切替後に**上下スクロールしても**列幅が混在せず、先頭付近のアンカーが保たれる」とあるが、対応する Sample 画面 `samples/ios/KsCollectionViewSamples/FixedGridDemoView.swift` のデータは `DemoData.fixedGridItems` の 9 件で、grid (3 列 = 3 行) でも list (9 行) でも iPhone 17 Pro の画面に収まりスクロールが発生しない。Simulator で実際に両モードを表示して確認した。

この表は長命層 (handbook) の規範であり、phase-3 の Android Sample が「両プラットフォームで同じ表現にする」(同文書) 前提で追随する対象でもある。観測できない観測点が正として残ると、目視検証が「見た感じ問題ない」に退化し、同文書が禁じている状態になる。実際、`ui/brief.md` の「固定列は grid→list 切り替え後に上下操作し、全可視セルが list 幅を維持した」という記録も、この画面では実スクロールを伴わない操作の記録にしかならない。

なお、アンカー保持そのものの検証は `KsCollectionEngineTests` の 300 件のアンカー 3 テストが成立させており、実装側の欠陥ではない。ずれているのは観測点と Sample の対応である。

**推奨修正**: 次のいずれかで整合させる。(1) 観測点からスクロールとアンカーの語を外し、切替後の列幅と表示の乱れだけを見る観測にする (アンカーの自動検証は上記 3 テストが担う旨を「大量件数」行などへ寄せる)。(2) 観測点を維持するなら、切替の土俵をスクロールが発生する件数の画面に置く。どちらも Sample のデモデータ件数はモック承認済みの見た目に関わるため、変更する場合は phase-3 の追随義務 (sample-parity) を含めて判断する。

### 🔵 Suggestion-1: 親状態の反映が「配列が完全に同値のとき」に限られる

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:289-295` / `:344-346`

**問題点**: 案 B により、`items == appliedItems` の更新では全可視セルが再構成され、テンプレートが捕捉した親の状態が反映される。一方、配列が少しでも変わった更新では、再構成対象は内容が変わった要素 (`plan.reconfigure`) だけで、内容不変の可視セルは作り直されない。つまり「選択中 ID を変えるだけ」なら色が変わり、「選択中 ID を変えると同時に 1 件追加する」と他行の色が古いまま残る。

これは spec 違反ではない — collection-core「差分更新」の Scenario が「無関係な要素は再描画されない」を要求しており、`test挿入時に内容不変の要素のセルプロバイダを再実行しない` がそれを固定している。`deviation.md` の案 B の記述も「同値配列でも」と明示的に範囲を切っている。したがって現状は合意済みの契約どおりだが、利用者から見ると条件によって反映されたりされなかったりする挙動になる。

**推奨修正**: 実装は変えず、`dsl-samples.md` の「iOS セル再利用の注意」と同じ場所に「セルの表示に影響する値は要素モデルに載せる (親の状態をテンプレートで直接読むと、配列の変化の仕方によって反映されないことがある)」旨の注記を足すことを検討する。公開ドキュメント整備は phase-7 のため本 change での対応は必須としない。phase-3 で Compose 側の再コンポーズ挙動と突き合わせる際の論点にもなる。

### 🔵 Suggestion-2: レイアウトのアンカー保持が `layout.kind` の変化に限定されている

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:60-65`

**問題点**: アンカーの捕捉条件は `previousLayout.kind != configuration.layout.kind` で、list ⇔ grid と列数の変更 (`.fixed(2)` → `.fixed(4)` は `kind` の変化) は覆う。一方、`rowSpacing` / `columnSpacing` だけの変更では捕捉されない。collection-layout「レイアウトの動的切り替え」の SHALL は「表示中に `layout` 値を差し替えたとき」と書かれており、spacing も `layout` 値の一部である。

Simulator で「スペーシングと余白」(18 件) を末尾まで送ってから Slider を連続ドラッグしたところ、先頭可視要素は保たれ実害は観測できなかった。件数が多いリストで spacing の差が大きいときにのみ、行数 × 差分の分だけ位置がずれうる。また、Slider ドラッグ中にアンカーを毎フレーム復元すると操作の追従を壊すため、単純に条件を広げる修正は適切でない。

**推奨修正**: 実装ではなく射程の確定として扱う。ksn-verify は Scenario (list → grid) を見るため VALID になるが、SHALL の文言と実装の射程がずれている点を蒸留時に整理する — spacing 変更を要求の対象外と読むのか、非ドラッグ時のみ復元する契約にするのかを決める。

### 🔵 Suggestion-3: 可視セル再構成の追加コストが性能証跡に反映されていない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:267-280` / `evidence/performance-early-measurement.md`

**問題点**: 案 B により、親の再評価が来るたびに全可視セルの `UIHostingConfiguration` が作り直される。スクロール中は `updateUIViewController` が呼ばれないため計測済みの hitch time ratio には影響しないが、連続 Slider や逐次入力のように親が高頻度で再評価される経路には毎フレームの追加コストが乗る。`evidence/performance-early-measurement.md` の計測はサイクル 7 より前の実装に対するもので、この経路の値は含まれていない。

Simulator の「スペーシングと余白」で連続ドラッグしたかぎり追従は保たれており、実害は観測できなかった。

**推奨修正**: 追加計測を必須にはしない。案 B の採用でこの経路のコストが増えたことを `evidence/performance-early-measurement.md` の状態欄に一文添えるか、蒸留時に performance-verification 規約へ昇格する際、計測対象に「親が高頻度で更新される画面」を含めるかを判断する。

### 🔵 Suggestion-4: 戻り値を捨てる `registration(for:)` 呼び出しの意図がコメントで自己完結していない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:276`

**問題点**: `_ = registration(for: configuration.templateKey(item))` は戻り値を使わず、`applyContent(to:item:)` もこの登録を参照しない。読み手には無意味な行に見えるが、実際には `deviation.md` の `[付随修正]` (セル取得の処理中にセル登録を生成すると実行時例外になる) を可視セル再構成の経路でも守るための先行登録である。その理由は `prepareRegistrations` 側 (`:192-193`) にしか書かれていない。

**推奨修正**: この行に、セル取得の処理外で登録を用意する必要があることを 1 行で添える (`prepareRegistrations` の説明と同趣旨で、この場所だけを読んでも意図が分かる形にする)。

### 🔵 Suggestion-5: テストコメントの SwiftUI 挙動の主張が確認しづらい

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsSwiftUIIntegrationTests.swift:57-58`

**問題点**: 「選択中 ID は body で読む。テンプレートのクロージャ内でしか読まない値は SwiftUI の再評価の依存にならず、親の更新自体が届かない」とあるが、`@State` の変更はそのビューの body を無条件に再評価するため、クロージャ内でしか読まない値でも親の更新自体は届くはずである。テストが `let selected = selectedID` で値を巻き上げているのは安全側の書き方として妥当だが、コメントが述べる理由は成立しない可能性が高い。誤った根拠が固定されると、後続の Android 追随や利用者向け注記が同じ前提で書かれてしまう。

**推奨修正**: 巻き上げが必要かどうかを実験で確かめ、必要ならその条件を、不要ならコメントを「値を body で確定させてクロージャの捕捉を明示する」といった書き方の説明へ改める。

### 🔵 Suggestion-6: 追記した文書に、追記前提の予告文と lint 抵触が残っている

**該当箇所**: `kasane/handbook/cross/local-development-setup.md` (定義元の表の直前・デモ画面一覧の節) / `kasane/roadmaps/v1-foundation/phases/phase-3-android-wrapper-foundation/agenda.md:31`

**問題点**: 2 点ある。

- `local-development-setup.md` には「定義元の表 (対象 / 定義元ファイル) は、各プラットフォームのビルド構成が成立した時点でこの節へ追加する」という予告文が、追加済みの表の直前に残っている。デモ画面一覧の節も「パスは Sample scaffold の成立時にここへ追記する」と「iOS の定義元は …SampleScreen.swift」が並んでおり、読み手にはどちらが現行か判別しづらい
- phase-3 agenda に追加した申し送りの 1 項目が 459 字で、`scripts/doc-structure-lint.py` の `item-chars: 200` に抵触する (本 change が新しく増やした唯一の doc-structure 警告)

いずれも hook には登録されていない助言的 lint であり、ビルド・テストには影響しない。

**推奨修正**: 予告文は iOS 分が埋まった旨と Android 分が残る旨の一文へまとめる。agenda の長い項目は、API 候補の列挙を小節または表の行へ移す。

## 確認した観点 (指摘に至らなかったもの)

- **足場の凍結**: `proposal.md` / `design.md` / `specs/*/spec.md` は HEAD から未変更。`tasks.md` の差分はチェックボックスの `[ ]` → `[x]` のみで本文の書き換えは無い。`ui/brief.md` の追記は ksn-ui の視覚照合記録に相当する節で、承認済みモックの内容には触れていない
- **deviation.md**: 記録済み 15 件はいずれも合意済み差分として扱った。`[付随修正]` は 2 件 — 「iOS 26 のセル登録準備」(`test初回表示前にセル登録を準備して再利用セルを生成する` で担保) と「項目が空のときの初回表示」(`:326-331` の 1 行。`test空の項目でも先頭へのスクロール命令でheaderの先頭へ戻す` が header 込みの初回適用を前提に成立)。どちらも本務で触るファイル内・同一能力・1 ファイルの局所修正・公開 API 非変更・ユーザー判断の分岐なしで、同梱条件に収まっている
- **案 B の副作用**: 早期脱出路は `reconfiguringAllItems`(レイアウト種別変更) を除外条件に持つため、アンカー復元を伴う経路とは競合しない。`flushPendingCommands()` の呼び出し位置も従来どおりで、`test同一配列の再適用でも保留中のスクロール命令を実行する` が命令の取りこぼしを固定している。`itemsByID` / `appliedItems` を更新しないのは配列が同値であることが前提で、再構成側は `configuration` を毎回読み直すためテンプレート差し替えにも追従する
- **アンカー復元の順序**: apply 完了後に `layoutIfNeeded()` → `restorePendingAnchor()` → `flushPendingCommands()` の順で、明示のスクロール命令がアンカー復元より後に実行される。命令とアンカーが競合したとき命令が勝つ、期待どおりの優先順位になっている
- **spec 適合の再確認**: 値キー解決 / 未登録キーの debug assertion と release フォールバック (1pt 空セル) / `id:` キーパス / adaptive の列数式と余剰幅の均等配分 / `contentPadding` と `section.contentInsets` によるインジケータ不動 / 向き別列数の `environment.container.effectiveContentSize` 参照 (物理向き非依存、core/ADR-0006 適合) / 未接続・存在しない ID・複数接続の各 no-op と警告ログ / list 以外での区切り線非表示 — いずれも実装とテストで成立
- **テストの実質**: 新設 `KsCollectionScenarioTests` は実 window に載せた実 controller と `UIHostingController` で観測しており、`cellForItem` のインスタンス同一性・`reuseIdentifier` の相違・レイアウト属性の高さ・`@State` の初期化という、計画配列の検査では取れない事実を見ている。言い訳コメントによる実質スキップや、条件を緩めた素通りアサーションは見当たらない
- **待機規約**: `waitUntil` は実時間 deadline (`ContinuousClock`)・待機対象への実行機会の譲り (`Task.sleep`)・超過時の実測値付き失敗の 3 点を満たしており、handbook の「収束を待つアサーション」に適合している。固定 `sleep` を残すのは計測ドライバのみで、通常スキームから除外されている
- **公開 API の形**: `KsCollectionLayout` は `.list` / `.list(rowSpacing:)` / `.grid(columns:rowSpacing:columnSpacing:)` の引数形で core/ADR-0006 と一致。`dsl-samples.md` の Swift / Kotlin 例と語彙表も同じ形で、値キー・`id:`・`contentPadding`・`listSeparators`・header/footer の行が追加されている。`Template` の明示形と無接頭辞は暫定として deviation と phase-3 agenda の双方に残っている
- **公開識別子**: package / product `KsCollectionView`、Sample bundle ID `jp.kamusoft.kscollectionview.samples.ios`。最低対応 OS は `ios/Package.swift` / pbxproj とも iOS 16
- **Sample パリティ**: デモ 9 画面が `SampleScreen` の `rawValue` をメニューと画面タイトルで共有 (二重管理なし)。色はすべて `SampleTheme` の固定 RGBA で semantic color 不使用。検証専用 3 画面は launch 引数でのみ到達しメニューに出ない
- **コメント規約**: 公開 doc コメントに ADR ID・change 識別子・デルタスペック構文キーワードの混入なし。内部コメントも作業文書パス・ローカル通番・履歴記述を含まず、`prepareRegistrations` や早期脱出の説明はその場だけで意味が通る
- **証跡の衛生**: `evidence/` と `ui/verification/` は静止画と Markdown のみ。identity lint と local-path lint がともに 0 件で、生 trace・端末個体名・開発者識別子・ローカル絶対パスは保存されていない
- **ビルド生成物**: `ios/.build` `DerivedData` `xcuserdata` はいずれも `.gitignore` で除外済み

## アクションプラン

1. **Minor** `handbook/cross/runtime-behavior-verification.md` の「グリッド (固定列)」観測点を、Sample で実際に観測できる内容へ合わせる (phase-3 の Android がこの表に追随する前が望ましい)
2. **Suggestion-4 / Suggestion-6** はいずれも数行の整理で閉じる。次の作業のついでで足りる
3. **Suggestion-1 / Suggestion-2 / Suggestion-3** は蒸留 (ksn-distill) の判断項目として送る — 親状態反映の射程の利用者向け注記、アンカー保持の要求射程の確定、performance-verification 規約昇格時の計測対象
4. **Suggestion-5** はテストコメントの正確性の問題で、後続フェーズでの検証時に確かめてよい
5. 本 change は L 級のため、アーカイブ前に verify (ksn-verify) が未実施である点はレビューの範囲外の残作業として引き継ぐ
