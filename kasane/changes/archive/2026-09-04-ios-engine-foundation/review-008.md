# レビュー結果: ios-engine-foundation (008 回目)

**日付**: 2026-09-02
**判定**: APPROVED

## サマリー

修正サイクル 8 の確定リスト 6 件 (Major 2 / Minor 3 / 契約注記 1) はすべて解消しており、Major 2 件にはそれぞれ新規テストが伴っている。ビルドとテストは本体 Debug 56 件 / Release 58 件 / Sample UI 3 件がすべて成功し (前サイクルの 51 / 53 / 3 から +5 / +5 / 0)、実行できた標準 lint 3 本も違反 0 件だった。Simulator での操作確認 (深い位置での連続スライダー操作・list ⇄ grid 切替・10,000 件の連続フリック・末尾/先頭スクロール) でも表示の乱れは無く、修正による後退は確認できなかった。

重点として指示された 2 点はいずれも成立している。(a) アンカー復元のオフセット保持化は、捕捉条件を `layout` 値と `contentPadding` の変化へ広げたうえで、復元値を「新レイアウトでのアンカー frame から捕捉時オフセットを引いた絶対座標」として計算するため、UIKit 側が先に補正していても二重補正にならない。差分適用を伴う経路 (挿入・削除・レイアウト切替) は従来どおり apply 完了後に復元し、同値配列の高速経路だけが `settleAnchorIfNeeded()` で自前にレイアウトを確定させてから復元する。既存の切替・挿入・削除の挙動に副作用は見つからなかった。(b) reload 優先の除外は `reconfiguringAllItems` (レイアウト種別変更) の分岐にしか効かない — 通常経路の `plan.reconfigure` と `plan.reload` は `KsSnapshotPlanner` の構築上すでに排他であり、差分更新の他経路は変わっていない。

残る指摘は Minor 3 件 (アンカー復元の射程・アンカー機構を裏付けるテストの弁別力・新規テストの固定待機) と Suggestion 4 件で、いずれも確定リストの範囲外か、蒸留・後続フェーズ送りが妥当なものである。

重要度別件数: **Critical 0 / Major 0 / Minor 3 / Suggestion 4**

## 実行結果

Simulator は `xcrun simctl list devices available` で存在を確認した機種・OS を使用した。

| 対象 | コマンド | 結果 |
|---|---|---|
| 本体 Debug | `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug` | Executed 56 tests, 0 failures |
| 本体 Release | 同上 + `-configuration Release ENABLE_TESTABILITY=YES` | Executed 58 tests, 0 failures |
| Sample UI (通常) | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` | Executed 3 tests, 0 failures |
| Sample ビルド (操作確認用) | `xcodebuild build -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -configuration Debug CODE_SIGNING_ALLOWED=NO` | BUILD SUCCEEDED |
| local-path lint | `python3 scripts/local-path-lint.py` | 違反 0 |
| identity lint | `python3 scripts/identity-lint.py` | 違反 0 |
| comment-policy lint | `python3 scripts/comment-policy-lint.py` | 検査対象 61 ファイル / 禁止 0 |
| doc-structure lint | `python3 scripts/doc-structure-lint.py` | exit 1 / 26 件 (すべて `item-chars`。本 change 由来は 1 件 — 下記 Suggestion-3) |

Debug 56 / Release 58 は前サイクル (51 / 53) から +5 で、増分はサイクル 8 で追加された 5 件 — 行間変更時のアンカー保持 2 件 (`test深い位置で行間を大きく変えても先頭可視要素を表示範囲に残す` / `test行間を連続して変えても先頭可視要素が変わらない`)、レイアウト切替と同時のキー変更 1 件 (`testレイアウト切替と同時にテンプレートキーが変わってもセルを置き換える`)、スクロール制御 2 件 (`test接続済みでも存在しないIDへのスクロール命令では表示位置が変わらない` / `test表示範囲外の要素へのcenter指定スクロールでその要素が中央に来る`) に対応する。Release が 2 件多いのは `#if !DEBUG` の 2 件によるもので、両構成を回して初めて全 Scenario が走る構成は維持されている。Sample の通常スキームは 3 件のままで `PerformanceDriverUITests` を 1 件も含まず、計測ドライバの分離は引き続き効いている。

`evidence/verification-matrix.md` が引用するテスト名 59 件を、本体テスト 58 件と Sample UI テスト 5 件のソース上の `func test...` と機械照合した。実在しない引用は 0 件で、過大計上は再発していない。

### Simulator での操作確認

`kasane/lessons/inbox/verify-interactive-collection-layout-transitions.md` の観測を踏まえ、Debug ビルドの Sample を iPhone 17 Pro Simulator (iOS 26.0) で操作した。デモデータと標準ステータス表示のみを観測しており、個人情報・端末固有の識別情報は扱っていない。

| 操作 | 結果 |
|---|---|
| ルートメニュー | 9 画面・順序・文言が `SampleScreen` と一致 |
| スペーシングと余白: 末尾までスクロール後、スペーシング Slider を連続ドラッグ | 先頭可視要素 (Item 7) が画面上の同じ位置・同じ切れ方のまま留まり、行間だけが広がった。跳ね・ちらつきなし (Major-A の修正が実挙動として効いている) |
| グリッド (固定列): grid → list 切替 | 全行が全幅の一列へ切り替わり、区切り線は先頭上端・行間・最終行下端に描画。乱れなし |
| 大量件数 (10,000 件・固定高と可変行高の混在): 連続フリック | セル内容・行高・1pt の行間/列間の見え方が安定。表示の破綻なし。grid では区切り線が出ない (見えている線は 1pt スペーシングから覗く背景) |
| スクロール制御: 「末尾」→ 「先頭」 | Item 100 到達後、先頭 (Item 1) へ復帰 |

## 照合した規約

`kasane/handbook/index.md` → `kasane/handbook/cross/index.md` から、`always` と担当範囲 (`ios/` 本体・`samples/ios/`・テスト実行・実行時挙動・evidence) に当たる文書を本文までロードした。ios / core / android ドメインの handbook はまだ存在しない。

| 文書 | 適用のきっかけ | 判定 |
|---|---|---|
| ソースコメント規約 | 常時 | 適用。lint 0 件に加え、本文基準でも作業文書パス・変更識別子・ローカル通番・履歴記述・公開 doc コメントへの内部用語混入がないことを確認 |
| テスト実行規約 | テストを実行するとき | 適用。件数併記・Simulator 全件・Release の `ENABLE_TESTABILITY=YES`・スキーム分離を実行手順として使用。「収束を待つアサーション」の節は下記 Minor-3 の根拠 |
| 実行時挙動の検証規約 | 実行時挙動の完了判定 | 適用。サイクル 8 の修正が実行時挙動に触れるため、更新された観測点表を事前に読んで上記の操作確認を行った |
| Sample のプラットフォーム間一致 | `samples/` を触るとき | 適用。Sample のデモデータ・文言に本サイクルの変更が無いこと、検証画面がメニューに出ないことを確認 |
| 公開識別子と配布座標 | `ios/Package.swift`・pbxproj を触るとき | 適用。package / product / bundle ID が規約表と一致 (本サイクルでの変更なし) |
| ローカル開発環境と Sample の実行 | 環境構築・Sample 実行 (guide) | 適用。記載の Sample ビルドコマンドを実際に実行し、記述どおり動くことを確認 |

`kasane/lessons/` に昇格済みルールは無い (inbox 3 件のみ) ため「指摘しないこと」の制約は無い。inbox の `verify-interactive-collection-layout-transitions` (scope: code-review) は昇格前だが観点として妥当なため、上表の操作確認として取り入れた。参照した決定は core/ADR-0003・0004・0006・0007、ios/ADR-0001〜0004、cross/ADR-0002〜0004。concepts は未作成 (index のみ)。

## 前回指摘の追跡

`second-opinion-code-007.md` の「突き合わせ結果」「オーナー判断」で確定した修正リストを追跡する。

| # | 出典 | 重要度 | 状態 | 確認結果 |
|---|---|---|---|---|
| 1 | 双方一致: spacing だけの差し替えでアンカーを維持しない | Major | **解消** | `ios/Sources/KsCollectionView/KsCollectionViewController.swift:64-70` で捕捉条件が `previousLayout != configuration.layout \|\| previousPadding != configuration.contentPadding` になり、`kind` 以外の layout 値と `contentPadding` も covered。復元は `:490-499` で `scrollToItem` を使わず `setContentOffset(anchor frame.minY − 捕捉時オフセット)`、`:501-510` で可動域へクランプ。同値配列の高速経路は `:294` の `settleAnchorIfNeeded()` が `layoutIfNeeded()` 後に復元する。`test深い位置で行間を大きく変えても先頭可視要素を表示範囲に残す` (行間 40 への一括変更) と `test行間を連続して変えても先頭可視要素が変わらない` (6→48 の 8 段階連続変更) が固定。Simulator の連続ドラッグでも位置が保たれることを確認 |
| 2 | code-007 Major-1: 同じ ID を reconfigure と reload の両方へ登録 | Major | **解消** | `:348-357` で `reloadIdentifiers` を先に確定し、`reconfigureIdentifiers` から `.filter { !reloadedIdentifiers.contains($0) }` で除外。`KsSnapshotPlanner` は 1 要素を reconfigure か reload の一方にしか入れないため、除外が効くのは `reconfiguringAllItems` (レイアウト種別変更) の分岐だけで、通常の差分更新経路には影響しない。`testレイアウト切替と同時にテンプレートキーが変わってもセルを置き換える` が、レイアウト切替と同一 ID のキー変更が同時に来ても例外なくセルが置き換わること (インスタンス相違・`reuseIdentifier` 相違・件数維持) を固定 |
| 3 | code-007 Minor-1: 自己サイズテストが「切れ・余分な空白なし」を観測していない | Minor | **解消** | `ios/Tests/KsCollectionViewTests/KsCollectionScenarioTests.swift:217-252` に、3 行それぞれのレイアウト属性高さと `hostedFittingHeight(of:)` (contentView の `systemLayoutSizeFitting`) の一致を `accuracy: 0.5` で照合するアサーションが追加された。ヘルパーには「一致すれば切れも余分な空白も無い」旨のコメントが自己完結して置かれている |
| 4 | code-007 Minor-2: スクロール制御の 2 Scenario に自動検証が無い | Minor | **解消** | `KsCollectionScenarioTests.swift:253-286` が接続済みコントローラでの存在しない ID の no-op (表示位置不変・`lastScrollTargetIdentifier` が nil のまま・後続の有効な命令は到達) を、`:287-318` が表示範囲外要素への `.center` 指定で frame 中心が表示範囲中心へ来ることを、いずれも実 controller で検証。ただし前者の待機は下記 Minor-3 |
| 5 | ホストのみ Minor: 観測点表「グリッド (固定列)」行が Sample で観測できない | Minor | **解消** | `kasane/handbook/cross/runtime-behavior-verification.md` の該当行が「list ⇄ grid の切替後に全可視セルの列幅が揃い、表示の乱れが無いこと (切替時のアンカー保持は本体の統合テストで担保する)」へ改められ、スクロールとアンカーの語が外れた。9 件でスクロールが起きない `FixedGridDemoView` でも観測できる内容になっている (Simulator で確認)。Sample のデモデータは変更されていない |
| 6 | 降格: 同値配列の高速経路が `id:` / `template:` / 登録集合の変更を無視 | 契約注記 | **解消** | `dsl-samples.md` の「iOS セル再利用の注意」に「`id:` / `template:` の指定と `Template` の登録集合は、表示中に差し替えない前提の宣言として扱う」旨が追記され、`deviation.md` にも同趣旨の 1 件が記録された。コード変更なしという確定内容と一致 |
| 7 | Suggestion 6 件 (蒸留 / phase-7 送り) | Suggestion | **送付済み (未着手)** | 本サイクルでの対応対象外。review-007 Suggestion-2 (アンカー保持の射程) は上記 #1 の Major 修正で結果的に解消。残りは下記 Suggestion-2 / Suggestion-3 として状態のみ記録 |

`second-opinion-code-006.md` / `code-005.md` の確定リストは、いずれも今回のコードで維持されていることを再確認した。特に、アンカー捕捉条件の拡大と復元方式の変更は `plan.reconfigure` / `plan.reload` の中身に触れないため、code-005 Major-3 (位置変更時の全件 reconfigure) と Major-4 (不変更新時の O(n) 再構築) の修正は後退していない (`test挿入時に内容不変の要素のセルプロバイダを再実行しない` が引き続き green)。案 B の可視セル再構成 (code-006 Major-1) も早期脱出路のまま維持され、そこへ `settleAnchorIfNeeded()` が追加されただけである。

## 指摘事項

### 🟡 Minor-1: オフセット保持のアンカー復元は、アンカーの高さが縮む切り替えで「表示範囲内に現れる」を保証しない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:455-468` / `:477-499`

**問題点**: `captureAnchor()` が控えるのは `attributes.frame.minY - collectionView.bounds.minY`、すなわち表示範囲上端から見たアンカーの相対位置である。先頭可視要素は上端で切れていることが多く、この値は最大で旧レイアウトでのアンカー高さぶんの負値を取りうる。復元側 (`:492-498`) はこの値をそのまま新レイアウトへ持ち込むため、**アンカーが新レイアウトで大きく低くなる場合、アンカーは表示範囲の上へ完全に外れる**。

具体的には、背の高い行 (例: 高さ 300pt のカード) をほぼ送り切った状態 (捕捉値 −290) で 3 列グリッドへ切り替え、そのセルが 120pt になると、復元後のアンカーは上端から −290〜−170 の範囲に置かれ、可視範囲に 1px も入らない。collection-layout「レイアウトの動的切り替え」の SHALL は「切り替え後もアンカー要素が表示範囲内に現れる」と明記しており、サイクル 7 までの `scrollToItem(.top)` はこれを構造的に保証していた。オフセット保持への変更 (連続変更で跳ねないための、確定リストどおりの方針) と引き換えに、この保証が条件付きになっている。

現状の Sample ではこの条件に届かない (どの画面も行高が近い) ため実害は観測できず、`testリストからグリッドへの切替後も先頭可視要素を表示範囲に残す` も 300 件の均一な行で書かれているため検知しない。

**推奨修正**: 復元時に捕捉値を新レイアウトのアンカー高さでクランプする — `offsetFromTop` を `max(offsetFromTop, -(newAttributes.frame.height - 1))` 程度に丸めてから `setContentOffset` に渡す。これなら連続変更時の滑らかさ (高さが変わらない spacing 変更ではクランプが働かない) を保ったまま、SHALL の「表示範囲内に現れる」を回復できる。行高が大きく変わるレイアウト切替のテストを 1 件追加して固定するとよい。実装ではなく要求の射程を狭める判断を採るなら、spec の書き換えではなく蒸留時の整理として扱う。

### 🟡 Minor-2: アンカー復元を裏付けるテストが、機構の有無を弁別できない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:463-559` / `kasane/changes/ios-engine-foundation/evidence/verification-matrix.md` (「動的切り替えの anchor」行)

**問題点**: アンカー系 5 件のアサーションは、いずれも「先頭可視 ID がアンカーと一致する」「可視 ID 集合にアンカーが含まれる」という観測に閉じている。この観測は、ライブラリの復元処理が働いた場合と、UIKit がレイアウト無効化に際して自前で content offset を補正した場合の**どちらでも同じ真値になる**ため、機構を外しても緑のままになりうる (本レビューのコンテキストでも、iOS 26 Simulator では機構を無効化してもテストが通ることが実装側で確認済みと伝えられている)。

つまりこの 5 件は現状「復元が壊れたら落ちる回帰ガード」としては弱く、`verification-matrix.md` が「Simulator 統合」欄でアンカー保持の検証として掲げている強さには届いていない。最低対応 OS は iOS 16 であり、OS 側の補正に依存できない環境が射程に含まれる以上、機構自体を裏付ける手当てが要る。なお本レビューでは、この主張はソースの読み取りとアサーションの意味からの分析であり、機構を外した実測は行っていない (成果物の書き換えを避けたため)。

**推奨修正**: 次のいずれかで機構を弁別できる形にする。(1) 観測を「アンカーの表示範囲上端からのオフセットが切り替え前後で一致する」という数値の等式に変える (UIKit の補正は特定要素の相対位置までは合わせないため弁別できる可能性が高い)。(2) このマシンには iOS 18.6 の Simulator ランタイムが導入済み (デバイス未作成) なので、アンカー系テストを 18.6 のデバイスでも走らせ、OS 依存でないことを 1 度確認して evidence に残す。いずれも取らない場合は、`verification-matrix.md` の当該行に「OS 側の補正と弁別していない」旨を明記して、証跡の強さを実態に合わせる。

### 🟡 Minor-3: 新規テストの「何も起きない」確認が固定待機で、空振りしても緑になる

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionScenarioTests.swift:275-280`

**問題点**: `test接続済みでも存在しないIDへのスクロール命令では表示位置が変わらない` は、存在しない ID の命令を送ったあと `try? await Task.sleep(for: .milliseconds(200))` で待ってから `contentOffset` の不変を確認する。命令の実行は `receive(_:)` → `DispatchQueue.main.async` → `flushPendingCommands()` を経るため、CPU が競合すると 200ms 以内にフラッシュが走らないことがありうる。その場合、テストは「命令がまだ処理されていない状態」で不変を確認して緑になる — 実装が壊れていても落ちない。

handbook「テスト実行規約」の「収束を待つアサーション」は、固定時間の待機で静止したことにしないことを求めている。テスト中のコメントは「何も起きないことの確認には収束を待つ対象が無い」と説明しており、意図は分かるが、後続の有効な命令 (`scrollTo(id: 120)`) は不変アサーションの**後**に置かれているため、空振りの排除には効いていない。

**推奨修正**: 命令キューが FIFO で流れることを利用して順序を組み替える — 存在しない ID の命令に続けて、現在の先頭要素を `.start` で指す「動かない有効な命令」を送り、`lastScrollTargetIdentifier` がその ID になるまで条件ベースで待ってから `contentOffset` の不変を確認する。これで「不正な命令が確かに処理された後」の観測になり、固定待機を外せる。

### 🔵 Suggestion-1: `listSeparators` の doc コメントが実際の描画範囲と食い違う

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionView.swift:148`

**問題点**: 「list の**行間**に表示する区切り線の有無を設定します」とあるが、`deviation.md` の合意済み差分により、実際には先頭行の上端・最終行の下端にも全幅で描かれる。公開 doc コメントは利用者が読む唯一の説明であり、`skills/` による本文書化は phase-7 のため、当面はこの一文が正になる。

**推奨修正**: 「list の行の境界 (先頭上端・行間・最終行下端) に表示する区切り線」といった、実際の描画に合う表現へ改める。仕様の変更ではなく記述の追随であり、数分で閉じる。

### 🔵 Suggestion-2: review-007 の Suggestion-4 / Suggestion-6 が未着手のまま残っている

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:279` / `kasane/handbook/cross/local-development-setup.md`

**問題点**: 確定リストで蒸留・phase-7 送りとされたため本サイクルの対象外だが、状態として記録しておく。(1) `_ = registration(for: configuration.templateKey(item))` には依然として意図のコメントが無く、その場だけを読むと戻り値を捨てる無意味な行に見える。(2) `local-development-setup.md` には「定義元の表は…この節へ追加する」「パスは Sample scaffold の成立時にここへ追記する」という予告文が、追加済みの表・追記済みの行の直前に残っており、どちらが現行か判別しづらい。

**推奨修正**: いずれも数行の整理。次の作業のついでで足りる。

### 🔵 Suggestion-3: doc-structure lint が exit 1 で終わり、本 change 由来の違反が 1 件残っている

**該当箇所**: `kasane/roadmaps/v1-foundation/phases/phase-3-android-wrapper-foundation/agenda.md:31`

**問題点**: `scripts/doc-structure-lint.py` は 26 件 (すべて `item-chars`) を検出して exit 1 で終わる。うち本 change が新しく増やしたのは phase-3 agenda の申し送り 1 項目 (459 字) で、残る 25 件は phase-1 / phase-2 の議論記録など既存の文書に由来する。hook に登録されていない助言的 lint であり、ビルド・テストには影響しない。なお `review-007.md` の実行結果表は同 lint を「exit 0 (警告のみ)」と記録しているが、本レビューの実行では exit 1 だった — 前回の記録が実態と食い違っている可能性がある。

**推奨修正**: 本 change 由来の 1 件は、API 候補の列挙を小節または表の行へ移して 200 字以内に収める。既存 25 件の扱い (対象範囲を狭めるか、閾値を見直すか、順次直すか) は本 change の範囲外として棚卸し (ksn-drift) へ送る。

### 🔵 Suggestion-4: 蒸留へ送る継続項目

**該当箇所**: `kasane/changes/ios-engine-foundation/review-007.md` (Suggestion-1 / Suggestion-3)

**問題点**: 前回の Suggestion のうち、(1) 親状態の反映が「配列が完全に同値のとき」に限られる射程の利用者向け注記、(2) 案 B の可視セル再構成に加えて本サイクルで `settleAnchorIfNeeded()` の強制レイアウトが乗ったため、親が高頻度で再評価される経路のコストが `evidence/performance-early-measurement.md` の計測条件に含まれていない点 — の 2 件は今も有効である。Simulator の連続ドラッグでは追従を保っており実害は観測できなかった。

**推奨修正**: 蒸留 (ksn-distill) で、利用者向け注記の追加と、performance-verification 規約へ昇格する際の計測対象 (親が高頻度で更新される画面を含めるか) を判断する。

## 確認した観点 (指摘に至らなかったもの)

- **足場の凍結**: `proposal.md` / `design.md` / `specs/*/spec.md` は HEAD から未変更。`tasks.md` の差分はチェックボックスの `[ ]` → `[x]` のみで本文の書き換えは無い。`ui/brief.md` の追記は視覚照合の記録に相当する節で、承認済みモックの内容には触れていない
- **deviation.md**: 記録済み 16 件はいずれも合意済み差分として扱った。本サイクルで増えたのは「同値配列の更新では `id:` / `template:` / `Template` の登録集合の変更を反映しない」の 1 件で、確定リストの契約注記と一致する。`[付随修正]` は前サイクルから 2 件のまま増えておらず、いずれも同梱条件に収まっている
- **アンカー捕捉条件の拡大による副作用**: `captureAnchor()` は `layoutChanged` のときだけ呼ばれるため、レイアウト変更を伴わない挿入・削除・並べ替えの経路は従来どおり (アンカー復元は走らない)。`restorePendingAnchor()` は apply 完了ハンドラ内で `layoutIfNeeded()` の後・`flushPendingCommands()` の前に置かれており、明示のスクロール命令がアンカーより優先される順序は維持されている。重ねて適用された snapshot がある間は `applyingSnapshotCount == 0` の判定で最後の完了だけが復元する
- **復元計算の冪等性**: 復元値はアンカーの新レイアウト frame からの絶対座標として求まるため、UIKit が先に content offset を補正していても二重補正にならない。`clampedVerticalOffset` は `adjustedContentInset` と `contentSize` から可動域を求めており、`contentInsetAdjustmentBehavior = .never` と整合している
- **reload / reconfigure 除外の射程**: `KsSnapshotPlanner.makePlan` は 1 要素を reconfigure か reload の一方にしか入れないため、除外フィルタが実際に効くのは `reconfiguringAllItems` の分岐のみ。`existingIdentifiers` による絞り込みも維持され、新規要素が reload/reconfigure に混ざらない
- **spec 適合の再確認**: 値キー解決 / 未登録キーの snapshot 準備時 assertion と release フォールバック / `id:` キーパス / adaptive の列数式と余剰幅の均等配分 / `contentPadding` と `section.contentInsets` によるインジケータ不動 / 向き別列数の `environment.container.effectiveContentSize` 参照 / 未接続・存在しない ID・複数接続の各 no-op と警告ログ / grid での区切り線非表示 (Simulator の「大量件数」で、見えている線が 1pt スペーシングから覗く背景であることを `LargeDataDemoView` の宣言と突き合わせて確認) — いずれも実装とテストで成立
- **テストの実質**: 新規 5 件はいずれも実 window に載せた実 controller で、レイアウト属性・可視 ID・セルインスタンス・`contentOffset` という観測可能な事実を見ている。言い訳コメントによる実質スキップや、条件を緩めた素通りアサーションは見当たらない (固定待機 1 件は Minor-3 として指摘)
- **待機規約**: `waitUntil` は実時間 deadline (`ContinuousClock`)・待機対象への実行機会の譲り (`Task.sleep`)・超過時の実測値付き失敗の 3 点を満たしている。新規 5 件のうち 4 件はこれを使っている
- **公開 API の形**: 本サイクルでの公開宣言の変更なし。`KsCollectionLayout` / `KsGridColumns` / `listSeparators` / `header` / `footer` / `KsScrollController` は core/ADR-0006・0007 と `dsl-samples.md` の語彙表に一致。`Template` の明示形と無接頭辞は暫定として `deviation.md` と phase-3 agenda の双方に残っている
- **証跡の衛生**: `evidence/` と `ui/verification/` は静止画と Markdown のみ。identity lint と local-path lint がともに 0 件で、生 trace・端末個体名・開発者識別子・ローカル絶対パスは保存されていない
- **ビルド生成物**: `ios/.build` `DerivedData` `xcuserdata` はいずれも `.gitignore` で除外済み。本レビューの Sample ビルドは作業ディレクトリ外の一時 `derivedDataPath` へ出力し、リポジトリに生成物を残していない

## アクションプラン

1. **Minor-1** アンカー復元のオフセットを新レイアウトのアンカー高さでクランプする (数行) か、要求の射程を蒸留で確定する。行高が大きく変わる切替のテストを 1 件足すと固定できる
2. **Minor-3** 存在しない ID の no-op テストから固定待機を外し、後続の「動かない有効な命令」の到達を条件ベースで待ってから不変を確認する形にする
3. **Minor-2** アンカー系テストの弁別力を上げる (オフセットの等式で観測する / iOS 18.6 デバイスでも走らせる) か、`verification-matrix.md` の当該行に弁別していない旨を明記する
4. **Suggestion-1 / Suggestion-2 / Suggestion-3 (本 change 由来の 1 件)** はいずれも数行の整理。次の作業のついででよい
5. **Suggestion-4** と Suggestion-3 の既存 25 件は蒸留 (ksn-distill) / 棚卸し (ksn-drift) へ送る
6. 本 change は L 級のため、アーカイブ前に verify (ksn-verify) が未実施である点はレビューの範囲外の残作業として引き継ぐ
