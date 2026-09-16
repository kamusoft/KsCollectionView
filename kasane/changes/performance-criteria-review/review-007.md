# レビュー結果: performance-criteria-review (007 回目)

**日付**: 2026-09-16
**判定**: CHANGES_REQUESTED

## サマリー

tasks グループ 6 の 6.1・6.2 (内部セクション分割の試作) をレビューした。塊の件数の決め方 (`KsSectionChunking`) は design Decision 10 の規則どおりで、lcm のオーバーフロー・上限超過の縮退・空配列 1 塊・列数が基準を超える場合まで純関数の単体テストで固定されており、snapshot の塊分けも controller 側の実経路で組まれている。既存テストの `IndexPath(item:section: 0)` 直書きは全体の順番からの変換へ機械的に置き換わっており、アサーションの緩和・削除は見当たらない。Sample の通過記録も全体の順番になり、全件通過が成立しうる形になった。塊の情報は `KsSectionID` / `KsSectionChunking` とも `internal` で、公開 API・DSL には漏れていない。

ただし 1 件、**塊の件数が変わる更新経路で、同値配列の可視セル再構成 (ios/ADR-0006、accepted) が落ちる**欠陥がある。これは「7.3・7.4 が未実装であること」ではなく、**この diff で実際に足された分岐の挙動**なので指摘対象とした。6.3 の計測 fixture (「大量件数」= 固定 2 列) ではこの分岐が発火しないため、計測そのものは本指摘の影響を受けずに進められる。

テストはレビュアー側でも独立に実行した: **iPhone 17 Pro Simulator / iOS 26.0、Debug、181 tests / 0 failures** (`xcodebuild test -scheme KsCollectionView`)。ホスト報告の 2 機種 (iOS 26.1) とは別の機種・OS の組み合わせで再現している。lint は comment-policy (禁止 0 件 / 要確認 14 件はすべて本 diff 外の既存分)・local-path・identity とも違反 0。

## 照合した規約

| 文書 | 適用のきっかけ | 判定 |
|---|---|---|
| cross/comment-policy.md | **常時** (全ソースコード) | 適用。新規・改訂コメントに作業文書パス・通番・仮称・履歴記述・SHALL 等の混入なし。`KsSectionChunking` / `KsSectionID` / Sample の doc コメントはいずれも単独で意味が通る。公開メンバーの doc コメントの変更なし |
| cross/test-execution.md | テストを実行するとき・テスト結果を報告するとき | 適用。絞り込みなしの全件実行で件数 (181 tests / 0 failures) を確認。新規テストの待機は既存の `waitUntil` (deadline + 実行機会の譲り) に乗っている |
| cross/sample-parity.md | `samples/**` を触るとき | 適用。変更は通過記録の数え方 (内部ロジック) だけで、画面・文言・デモデータ・DSL 引数はいずれも不変。Android 側に追随の要る差分は生じていない |
| ios/performance-verification.md | iOS エンジンの性能・メモリの検証、大量件数を扱う変更の完了判定 | 本スライスは計測も完了判定も行わないため未発火 (6.3 / 9 系で発火する) |
| cross/scroll-performance-gate.md | 性能の完了を判定するとき・手動フリック計測・性能の証跡 | 同上、未発火 |
| cross/runtime-behavior-verification.md | 実行時挙動の不具合調査・不具合修正の完了判定 | 本スライスは不具合修正ではないため未発火。ただし「実行時にしか現れない」塊の境界の見た目は 7.1・7.2 の責務として残る (下の所見) |
| cross/public-identifiers.md / local-development-setup.md | 公開識別子・配布座標 / 環境構築 | 該当なし |

lessons は昇格済みルール (`kasane/lessons/<scope>.md`) が未生成のため、`kasane/lessons/inbox/` の scope: code-review 6 件を参照した。特に `check-tests-exercise-production-path-before-accepting-green` (テストが本番と同じ経路を通しているか) を Minor 1・Minor 2 の判定に、`report-device-and-os-with-layout-numeric-tests` をテスト結果の報告形式に適用している。

## 指摘事項

### [🟠 Major] 塊の件数が変わる更新で、同値配列の可視セル再構成 (ios/ADR-0006) が落ちる

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:440` (早期 return の条件に `!chunkSizeChanged` を足した箇所) と同 `:508-525` (塊の件数だけが変わった更新で可視セルが再構成の対象に入らない)

**問題点**:
`apply(items:...)` の早期 return は、同値配列の更新でも可視セルのテンプレートを呼び直す契約 (ios/ADR-0006 accepted、`observedValue` 未宣言時) を実現している唯一の経路である。今回 `!chunkSizeChanged` が条件に足されたため、**塊の件数が変わった更新では早期 return を抜けて後段へ落ちる**が、後段の `reconfigureIdentifiers` は `plan.reconfigure` と `survivingVisibleIdentifiers` からしか作られない。同値配列では両者とも空になるため、`reconfigureVisibleCells(rebuildingContent:)` 相当の再構成が一度も行われない。

到達する経路が実在する。`.grid(columns: .adaptive(minItemWidth:))` で解決列数が 3 (幅 390 / 最小幅 120 など、500 を割り切らない列数) になる場合:

1. `viewDidLoad` の初回 apply の時点では `resolvedColumnCount` が nil なので塊の件数は 500 (`appliedChunkSize = 500`)
2. 最初のレイアウトパスで `KsCollectionViewController.swift:586` が `resolvedColumnCount = 3` を書く
3. 次に同値配列の `update(configuration:)` が届くと `currentChunkSize()` が 501 を返し `chunkSizeChanged` が true になる → 早期 return を抜ける → テンプレートは呼び直されない

しかも項目数が塊の件数以下のときは、組み直した snapshot が現在の snapshot と完全に同一 (section も `chunkIndex: 0` の 1 つだけ) になるため、`dataSource.apply` も何も動かさない。つまりその更新は**丸ごと無効化される**。ADR-0006 が防いでいる「親の状態を捕捉したテンプレートが古い値のまま残る」症状が、adaptive の列数が変わった直後の 1 更新で再発する。回転や Split View の幅変更のたびに発火しうる。

これは「Decision 12 (組み直し・アンカー) が未実装であること」への指摘ではない。`chunkSizeChanged` による組み直しの検出自体は本 diff で実装済みであり、その分岐が既存の accepted ADR の契約を落としている点を問題としている。既存テストが検出できないのは、テストの layout が `.list` か固定列数で塊の件数が一定になり、この分岐を一度も通らないためである。

**推奨修正**:
`chunkSizeChanged` で早期 return を抜けたときも同値配列の再構成が走るようにする。たとえば (a) 後段へ落ちる前に `reconfigureVisibleCells(rebuildingContent: rebuildingVisibleCellContentOnEqualItems)` を通す、または (b) `reconfigureIdentifiers` の組み立てで `chunkSizeChanged && items == appliedItems` のときに可視セルの identifier を加える (`reconfiguringAllItems` が全件を入れているのと同じ考え方)。あわせて回帰テストを 1 本足す: adaptive (解決列数が 500 を割り切らない値になる幅) + `observedValue` 未宣言で、列数解決後の同値配列更新でテンプレートのクロージャが呼び直されることを確かめる。7.3 で組み直し経路へアンカーを足すときに同じ箇所へ触れるため、そちらに畳んでも構わないが、その場合も本件をタスクとして明示に残すこと。

### [🟡 Minor] 塊の構造を固定するテストが list の 1 通りしかなく、layout → 塊の件数の配線が検査されていない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:762-810` (新規テスト)、`ios/Tests/KsCollectionViewTests/KsSectionChunkingTests.swift`

**問題点**:
`KsSectionChunkingTests` は純関数 (`columnMultiple` / `chunkSize` / `chunkCount`) を網羅的に固定しているが、controller がその値を実際に snapshot へ渡す配線 (`currentChunkSize()` → `appendSections` / `appendItems`) を検査しているのは新規エンジンテスト 1 本だけで、その主張は `numberOfSections > 1` と通し番号の一意性に留まる。塊の件数・塊の数そのものは一度もアサートされていないため、たとえば `currentChunkSize()` が誤って 1 を返すようになっても (2,000 セクションになっても) このテストは緑のまま通る。layout 種別ごとの配線 (固定 2 列で 500、固定 3 列で 501、向き別列数で lcm 由来の値) は controller 経由では一度も通っていない。

**推奨修正**:
新規テストで `numberOfSections == 4` と各 section の件数 (先頭から末尾まで 500) を固定し、固定列数 3 のグリッドで 501 件ずつに割れることを確かめる 1 本を足す。7.3 で向き別列数・adaptive を扱うときに同じ検査軸を使い回せる。

### [🟡 Minor] Sample の通し番号変換がテスト側のヘルパと別実装で、どのテストも通らない

**該当箇所**: `samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:237` (`itemOffset(of:in:)`)、対応するテスト側の実装は `ios/Tests/KsCollectionViewTests/KsItemOffsetSupport.swift:45` (`ksItemOffset(for:in:)`)

**問題点**:
tasks 6.2 の「複数の塊をまたいで全件が一意に数えられることを単体テストで確かめる」を満たしているのは `KsCollectionEngineTests.swift:762` のテストだが、これが検査しているのはテストターゲット側のヘルパであり、Sample の `itemOffset` は同じ規則の**別の写し**で、どのテストからも実行されない (`samples/ios/` には UI テストターゲットしかない)。この通過記録は `visited.count == fixture.itemCount` という形でメモリ往復の合否条件 (`PerformanceVerificationView.swift:153`) に直結し、8.3・9.3 の証跡の成立可否を決める。片方だけが壊れても黙って「全件通過しなかった」または「通過した」に倒れる。ロジック自体は現時点では正しい (先行セクションの件数の総和 + item) ことを読んで確認している。

**推奨修正**:
8.3 でドライバへ往復ごとのログ (`visited=N/M`) を出すときに、Sample の UI テストでそのログの `N == M` を検査する経路を 1 本用意する。あるいは通し番号の算出を Sample 内の 1 箇所へ寄せ、UI テストから踏める形にする。

### [🟡 Minor] デルタスペックの Requirement に最小公倍数の縮退規則が無く、実装・ADR-0009 とずれている

**該当箇所**: `specs/collection-layout/spec.md` の Requirement「配列の内部分割 (iOS)」、`ios/Sources/KsCollectionView/KsSectionChunking.swift:30-39`

**問題点**:
spec 本文は「塊の件数は、固定列数と向き別列数では宣言された列数すべての倍数」と例外なしの SHALL で書かれている。一方 design Decision 10 と `kasane/decisions/ios/0009-internal-section-chunking.md` は、lcm がオーバーフローするか 2,000 を超える向き別列数では「現在の列数の倍数へ縮退する」と定めており、実装もそちらに従っている。縮退した塊の件数は宣言された 2 つの列数のうち一方の倍数でしかないため、spec 本文だけを読むと違反に見える。現状は実装 = design = ADR で一致しており、spec 本文だけが取り残されている。

**推奨修正**:
足場の書き換えは求めない。7.3 で向き別列数の Scenario (「向き別列数で列数が変わっても不完全な行が無い」) を実装する前に、縮退したときの期待挙動 (回転で組み直すまでの間、境界に不完全な行が出てよいのか) をどちらの文書を正とするか確定すること。蒸留時に spec / ADR のどちらへ寄せるかの判断が要る。

### [🔵 Suggestion] `maximumColumnMultiple = 2_000` の由来がコメントから読み取れない

**該当箇所**: `ios/Sources/KsCollectionView/KsSectionChunking.swift:10-12`

**問題点**:
コメントは「これを超える組み合わせでは最小公倍数を諦め、現在解決している列数の倍数へ縮退する」と動きは説明しているが、なぜ 2,000 なのか (基準 500 の 4 倍であり、1 セクション 2,000 件までは実測で体感が保てた上限) が書かれていない。値を動かしてよいかの判断がこのファイルだけでは付かない。作業文書を参照せずに現在形で書ける内容なので、コメント規約の範囲内で補える。

**推奨修正**: 「1 セクションに載せても滑らかさを保てた実測上の上限が 2,000 件であり、それを塊の件数の上限に使う」程度の一文を足す。

### [🔵 Suggestion] 解決列数の記録がレイアウト解決の副作用になっており、7.3 の検知経路と二重になりうる

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:586`

**問題点**:
`resolvedColumnCount` は compositional layout の section provider の中で書かれる。design Decision 12 は adaptive の列数変化を `viewDidLayoutSubviews` のコンテナサイズ変化で検知する設計なので、7.3 で検知経路をもう 1 本足すと「レイアウトの副作用で書かれる値」と「レイアウト後に読む値」の 2 系統が並ぶ。組み直しの発火順序 (レイアウト → 検知 → apply → レイアウト) を追いづらくなる懸念がある。

**推奨修正**: 7.3 の設計時に、解決列数の記録と組み直しの発火をどちらの経路に寄せるかを決めてから実装する。試作の段階で直す必要はない。

## 次段 (7 系) に進むうえでの所見 (指摘ではない)

- 6.3 の計測 fixture「大量件数」は `.grid(columns: .fixed(2), rowSpacing: 1, columnSpacing: 1)`・内側余白なし・ヘッダー / フッターなし・区切り線なしなので、7.1・7.2 が未実装であることによる見た目の歪み (塊ごとの余白・ヘッダーの重複・境界の上線) は発火しない。塊の件数は 500 で固定 2 列に割り切れ、10,000 件は 20 塊 250 行ずつに均等に割れる。Major 1 の分岐も固定列数では発火しないため、**段階 1 の計測は現状のビルドで成立する**と判断した。境界の行間だけは塊間に `rowSpacing` が入らず 1pt 詰まるが、体感・time profile の判定には影響しない。
- 逆に、`showsSeparators` を有効にした 500 件超のリストと、内側余白またはヘッダー / フッターを宣言した 500 件超の配列は、現時点では塊ごとに上線・余白・ヘッダーが出る。7.1・7.2 が入るまでの既知の状態であり、この試作をオーナーの手元の他の画面で触る場合の注意点として記しておく。
- `chunkSizeChanged` の判定 (Decision 12 の一部) が 6.1 に先行して入っている。7.3 で同じ箇所へ `viewDidLayoutSubviews` からの検知とアンカー捕捉を足すとき、判定が二重にならないよう既存の分岐を前提に組むこと。

## アクションプラン

1. **Major**: 塊の件数が変わる更新で同値配列の可視セル再構成が落ちる件を直し、adaptive での回帰テストを 1 本足す (7.3 に畳む場合はタスクとして明示に残す)
2. **Minor 1**: 塊の件数・塊の数を固定するアサーションを新規エンジンテストへ足し、固定列数 3 の配線を 1 本足す
3. **Minor 3**: 縮退規則について spec 本文と design / ADR-0009 のどちらを正とするかを 7.3 の着手前に確定する
4. **Minor 2**: 8.3 の実装時に、Sample の通過記録を UI テストから踏める形にする
5. **Suggestion 1・2**: 2,000 の由来の一文、解決列数の記録経路の整理 (7.3 の設計時)
6. 上記と並行して **6.3 の実機計測は現状のビルドで進めてよい** (上の所見のとおり、指摘 1 も 7.1・7.2 の不在も本 fixture では発火しない)
