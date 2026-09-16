# レビュー結果: performance-criteria-review (010 回目)

**日付**: 2026-09-16
**判定**: CHANGES_REQUESTED

## サマリー

review-009 の Major 2 件・Minor 4 件・Suggestion 3 件と、採用した相方指摘 1 件の処理を確認した。**10 件中 8 件は解消、1 件 (adaptive の 1 実行機会のずれ) は合意済み差分として deviation に落ちて 9 系へ送られ、1 件 (境界の幾何を `minX` で固定する Suggestion) は未着手**である。Major 1 の本体 (アニメーション抑止と復元の遅延を `chunkSizeChanged` 全経路へ広げる) は実装として正しく入り、Major 2 は「先に数値を動かさない」という条件どおり標本化を収束後に揃える形で直され、上限 4 倍は据え置いたまま根拠の実測値だけが塊分割後の値 (可視 39 件に対して 132 件) に採り直されている。

差し戻す理由は 1 件で、**Major 1 の修正として追加されたテストのうち `test表示形態の切り替えで塊の件数が変わっても先頭の項目を保つ` が iPhone 16e Simulator / iOS 26.0.1 で決定的に失敗する** (単独 3 走行・全件 2 走行のいずれも同じ値で失敗)。失敗しているのは差し替え後の契約ではなく**テスト自身の前提 (送った直後に項目 900 が画面の先頭に来ていること)** であり、実装側の退行を示すものではないと読むが、緑を前提にした完了報告の土台が崩れる点は review-009 Major 2 と同じである。

(d) で問われた `restoresAnchorAfterApply` の滞留は、**実害は「短い窓の中で利用者のスクロールが取り消されうる」ことに限られる Minor** と評価した (恒久的な滞留は構成できなかった)。詳細は指摘事項の 2 件目に書いた。

### テスト実行

レビュアー側で独立に実行した。ホストが使った機種 (iPhone 17 / 26.1、iPad Pro 11-inch (M5) / 26.4、iPhone 17 Pro / 26.5、iPad / 26.5) とも、review-009 が使った機種とも重ねていない。

| 実行 | 環境 | 結果 |
|---|---|---|
| ライブラリ全件 (絞り込みなし、Debug) | iPhone 16e Simulator / iOS 26.0.1 | **198 tests / 2 failures** (同一テストの 2 アサーション) |
| ライブラリ全件 (絞り込みなし、Debug) ×2 回目 | iPhone 16e Simulator / iOS 26.0.1 | 198 tests / 2 failures (同じ値) |
| ライブラリ全件 (絞り込みなし、Debug) | iPad Air 11-inch (M4) Simulator / iOS 26.4.1 | 198 tests / 0 failures |
| 該当 2 本のみ ×3 回 | iPhone 16e Simulator / iOS 26.0.1 | 2 tests / 2 failures (3 回とも同じ値) |

Sample の 2 スキームはレビュアー側では実行していない (ホスト報告の 9 / 0・5 / 0 を採る)。lint は local-path・identity・comment-policy (禁止 0 件 / 検査対象 218 ファイル) とも違反 0。doc-structure lint の指摘は本 diff の文書には無い (既存の roadmap 配下のみ)。

報告されている `KsImageTests.test失敗した表示はビューが作り直されると再び取得を試みる` の間欠失敗は、上記 4 走行 (iPad を含む) で 1 度も再現しなかった。

## 照合した規約

| 文書 | 適用のきっかけ | 判定 |
|---|---|---|
| cross/comment-policy.md | **常時** (全ソースコード) | 適用。本サイクルで増えたコメント (`viewWillTransition` の捕捉理由、`settledLiveCellCount` の収束待ち、`waitForLabel(timeout:where:)`、`PerformanceDriverUITests` の冒頭、`chunkRebuildCount` の構成理由) はいずれも作業文書パス・通番・仮称・履歴記述・デルタスペック構文キーワードを含まず、単独で読める。機械検査は禁止 0 件 |
| cross/test-execution.md | テストを実行するとき・テスト結果を報告するとき | **一部不適合**。「収束を待つアサーション」は 2 か所とも直った (`settledLiveCellCount` は実時間 deadline + 実行機会の譲り + 実測値を失敗メッセージへ、`waitForLabel(timeout:where:)` は deadline 付きの条件待ち)。計測ドライバの節に「観測のための駆動 / 判定を持つドライバ」の区別が入り、spec の Requirement とファイル冒頭とも揃った (相方 Minor の解消)。一方で**絞り込みなしの全件実行が緑にならない機種がある** (Major) |
| cross/runtime-behavior-verification.md | 実行時挙動の不具合を調査するとき・不具合修正の完了を判定するとき | 適用。`viewWillTransition` が SwiftUI の representable 経由で届くこと、アニメーション抑止と遅延復元の効き目が Simulator では弁別できないことは、どちらも deviation に「テストでは担保しない・9 系の実機で目視」と明記されている。静止したテストの緑を根拠にしていない |
| cross/scroll-performance-gate.md | 性能の完了を判定するとき・手動フリック計測を行うとき・性能の証跡を書くとき | 適用 (6.3 の範囲)。「判定の 3 状態と再試行」の非接続の対照を行っていないことと、その判断の根拠 (段階 1 の判定が食い違いに依らない)、9.1 へ送ることが証跡に明記された。ただし「9.1 の再計測で兼ねる」は文字どおり読むと接続下の走行なので、9.1 側で非接続の対照そのものを別に行う必要がある (Suggestion) |
| ios/performance-verification.md | iOS エンジンの描画・再利用・レイアウト経路に触れるとき・大量件数を扱う変更の完了を判定するとき | 適用。計測ドライバの構成の記述が「メモリの自動往復 (定常化まで反復) と画像読み込みの観測駆動」に揃い、`KS` 接頭の行から転記する旨と未判定の扱いも入った |
| cross/sample-parity.md | `samples/` を触るとき | 適用。`samples/ios` の変更は計測の帯の読み取り・判定表示・UI テストに限られ、デモ画面・文言・デモデータ・DSL 引数は不変。Android に追随の要る差分は無い |
| cross/public-identifiers.md | 公開識別子・配布座標を決めるとき | 適用。本サイクルで公開面は動いていない (`@_spi(KsMeasurement)` の表面は `KsItemOffsetLookup.itemOffset(of:in:)` 1 本のまま)。`viewWillTransition` は `UIViewController` の override で、`KsCollectionViewController` 自体が internal |
| cross/local-development-setup.md | 環境構築・Sample の起動 | 該当なし |

昇格済みルール (`kasane/lessons/<scope>.md`) は未生成のため `kasane/lessons/inbox/` を参照した。`check-tests-exercise-production-path-before-accepting-green` を新規テストと `rotate` ヘルパの評価に、`tests-created-in-change-are-in-scope-for-fixes` を失敗しているテストの扱いに、`report-device-and-os-with-layout-numeric-tests` を実行環境の併記に、`do-not-run-review-and-verify-on-same-simulator` を機種選定に、`check-sibling-contracts-when-fixing-a-review-finding` を「Major 1 の修正が他の経路に及ぼす影響」の確認に、`observe-motion-not-only-end-state-for-scroll-and-resize` と `capture-transient-layout-glitch-with-offset-logs` を deviation 36・38 の扱いに適用した。

ios/ADR-0009 は `proposed` のため、判定の根拠には使っていない (照合のみ)。accepted の ios/ADR-0003 (compositional layout で統一)・ios/ADR-0006 (同値配列でも可視セルを作り直す) との衝突は見つからなかった — `apply` の早期 return の分割 (`itemsAreEqual` で作り直しだけ先に行い、`chunkSizeChanged` なら snapshot へ進む) は ios/ADR-0006 の契約を保ったまま塊の組み直しを通している。

## review-009 の指摘 10 件の処理状況

| # | 指摘 | 状態 | 根拠 |
|---|---|---|---|
| 🟠 Major 1 | `update(configuration:)` 由来で塊の件数が変わる経路に緩和が掛からずテストも無い | **部分** | 実装は解消。`KsCollectionViewController.swift:601` が `animates = animatingDifferences && !chunkSizeChanged`、`:605-607` が `chunkSizeChanged` で `restoresAnchorAfterApply` を立て、契機は `rebuildChunksIfNeeded` から切り離された。テストは `KsCollectionEngineTests.swift:1170` (`.list` → `.grid(.fixed(3))`) と `:1188` (`.fixed(2)` → `.fixed(3)`) の 2 本が追加されたが、**前者が iPhone 16e / 26.0.1 で決定的に失敗する** (Major 1、下記) |
| 🟠 Major 2 | 同時生存セルのテストの間欠失敗と上限の根拠 | **解消** | `KsCollectionEngineTests.swift:2863-2877` に `settledLiveCellCount(in:below:)` を新設し、実時間 deadline 500 ms・1 ms の譲り・期限超過時は実測値を返して失敗メッセージへ載せる形にした。`:1452-1457` の標本化がこれを通る。上限は 4 倍のまま据え置き、`:1441-1444` のコメントの根拠値だけが塊分割後の実測 (2 機種・各複数走行で可視 39 件に対して最大 132 件 = 約 3.4 倍) に差し替わった。「先に数値を動かさない」という条件を守っている。レビュアーの 4 走行でも失敗しなかった |
| 🟡 Minor 1 | 倍率のテストが倍率の変化を 1 度も通らない | **解消** | `KsEstimatedHeightTests.swift` の空振りしていた 2 本を畳み、`test倍率が変わると前の倍率の実測値を捨てる` は倍率 2 → 3 の `record` を通して `value == 60` を確かめる形になった。`test同じ倍率で測り続ける限り実測値は捨てられない` と `test有効でない倍率どうしは同じ倍率として扱い実測値を捨てない` (正規化前で比べると毎回捨てられる並び) が足され、`KsEstimatedHeight.swift` の `sampledScale` の Optional 化と正規化後比較を弁別している |
| 🟡 Minor 2 | adaptive の組み直しが 1 実行機会遅れ、境界に不完全な行が 1 フレーム出る | **合意済み差分へ** | `deviation.md` の末尾から 3 番目の項に「詰めるには描画を 1 パス止めるか列数の確定をレイアウト完了直後に寄せる設計判断が要るため本 change では変更せず、9 系の実機で目視して見えなければ deviation に記録、見えれば起票する」と記録済み。合意済み差分なので指摘にはしない |
| 🟡 Minor 3 | 計数帯の UI テストが操作の反映を待たずに表示を読む | **解消** | `UITestSupport.swift` に `waitForLabel(timeout:where:)` を新設し、`LargeDataCountUITests.swift` の 3 か所すべてが deadline 付きの条件待ちに載った。`reset` 後は「解析値が 0」、`read` 後は「文言が変わり、かつ解析値が 0 より大きい」を待ち、期限超過時は最終 label を失敗メッセージへ入れている |
| 🟡 Minor 4 | 6.3 の証跡で体感と数値が食い違うのに非接続の対照が無い | **解消** | `evidence/manual-largeData-ios-2026-09-16-prototype.md` の「限界」に、対照を行っていないこと・段階 1 の判定がその食い違いに依らないこと・対照を 9.1 へ送ることが 1 行で入った。review-009 は「判定の節へ移す」と書いたが、相方との突き合わせで合意した形 (「証跡の限界に明記」) はこちらなので、配置は合意どおりとして解消扱いにする |
| 🔵 Suggestion 1 | 塊の所属が変わる可視セルの存在をテストが固定していない | **解消** | `assertVisibleCellsSurviveWhereChunkUnchanged` に `expectsMovedCells` (既定 true) が入り、`movedCount > 0` を既定で要求する。境界が表示範囲に入らない並べ替えのテストだけが `expectsMovedCells: false` で理由付きに外れている |
| 🔵 Suggestion 2 | 塊の境界の幾何を `frame` で 1 度固定しておく | **未解消** | `assertChunkStructure` (`KsCollectionEngineTests.swift:2416`) は依然として件数と総数だけを見ており、2 列グリッドで境界の前後の `minX` を確かめるテストは足されていない。Suggestion のため差し戻しの理由にはしない (下記に再掲) |
| 🔵 Suggestion 3 | `chunkRebuildCount` だけが Debug 構成の外にある | **解消** | `KsCollectionViewController.swift:61-64` に「計数そのものは構成を問わず持つ (`processedCommandCount` と同じく、値の更新に費用が掛からず計測対象の挙動を変えないため)」の理由コメントが入った。Suggestion が示した 2 択のうち「寄せない理由を書く」側 |
| 🟡 相方 Minor | 計測スキームの判定責務が handbook と食い違う | **解消** | `handbook/cross/test-execution.md` に「観測のための駆動 / 判定を持つドライバ / 成功件数には判定つきが含まれる」の 3 点が入り、`PerformanceDriverUITests.swift:3-10` の冒頭と `:142-149` のドライバの doc コメントも同じ区別で書き直された。`specs/samples/spec.md` の Requirement「iOS の計測ドライバの構成」とも矛盾しない |

## 付随修正 2 件の同梱条件 (レビュー観点 (b))

| 付随修正 | 局所性 | 公開 API | テストの担保 | 判定 |
|---|---|---|---|---|
| `leadingVisibleID()` のアンカー決定の幾何化 (`KsCollectionViewController.swift:747-765`) | `leadingVisibleID()` 1 関数の内側。呼び出し側 (`captureAnchor()`) は不変 | 不変 (internal) | **間接のみ**。`testadaptiveで列数が変わると塊を組み直して先頭の項目を保つ` が幾何化前は空振りしていた (deviation に記録) ため、このテストが実効を持つこと自体が担保になっている。「遠くへ送った直後に古いセルが可視一覧に残る」状況そのものを固定する単体のテストは無い | **条件内**。deviation 記録済み・組み直しの契約を成立させるために必要な最小の修正であり、スコープ外の同梱には当たらない |
| `KsEstimatedHeightTests` の幅側の空振りテストの畳み込み | テストファイル 1 本の内側 | 不変 | 畳み込み先 (`test幅が変わると前の幅の実測値を捨てる`) が遅延破棄の中間アサーションを持つ形になった | **条件内**。review-009 Minor 1 の推奨修正がそのまま「削除して 1 本に寄せる」を挙げており、その実施 |

## オーナー判断 A で追加した回転時の先頭維持 (レビュー観点 (c))

**捕捉時点**: 妥当。`KsCollectionViewController` は `UICollectionViewController` なので `view === collectionView` であり、`viewWillLayoutSubviews` まで待つと bounds だけが新しい値になって古い `contentOffset` と組になる — `viewWillTransition(to:with:)` はその手前で、`contentOffset` とレイアウト属性が変化前の値で揃っている唯一の点である。コメント (`:170-173`) がこの理由を単独で読める形で書いている。

**取り合い**: 組み直し経路とは `columnCountBeforeContainerTransition` と 2 つの guard で切り分けられている。捕捉側は `pendingAnchor == nil` のときだけ控え (他経路の控えを上書きしない)、復元側 (`:787-808`) は `!isChunkRebuildScheduled` かつ `currentChunkSize() == appliedChunkSize` のときだけ自分で戻し、塊の件数まで変わる回転は組み直し経路へ委ねる。委ねた先で `rebuildChunksIfNeeded` が `captureAnchor()` し直すため、回転前ではなく組み直し時点の位置が使われるが、これは deviation に「塊の件数まで変わる回転 (adaptive) は既存の組み直し経路 (組み直し時点の位置) に任せる」と明記されている。列数が変わらなかった変化で `pendingAnchor` を捨てる分岐には穴がある (Minor 2 として後述)。

**テスト**: `rotate(window:controller:to:)` (`KsCollectionEngineTests.swift:2655-2665`) は `controller.viewWillTransition(to:with:)` を直接呼んでから frame を差し替える。これは**本番の実装メソッドを通すが、UIKit (SwiftUI の representable 経由の階層) がそのコールバックを実際に届けることは担保しない**。この限界は deviation の末尾に「`viewWillTransition` が SwiftUI の representable 経由の階層まで届くことはテストでは担保できないため、9 系の Simulator / 実機の実回転の目視で確かめる」と明記されており、緑を届いている根拠にはしていない。`TransitionCoordinatorStub` は併走アニメーションを受け取って何もしないだけで、実装が coordinator に依存していない (使っていない) ことと整合する。評価としては **担保は部分的で、残りは 9 系で潰す形が記録されている**。

## 指摘事項

### [🟠 Major] Major 1 の修正で追加したテストが iPhone 16e / iOS 26.0.1 で決定的に失敗する

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:1204-1231` (`assertAnchorSurvivesChunkSizeChange`)、とくに `:1213-1219` の前提待ちと `:1228-1230` の判定。呼び出し元は `:1170` (`test表示形態の切り替えで塊の件数が変わっても先頭の項目を保つ`) と `:1188` (`test列数の指定の変更で塊の件数が変わっても先頭の項目を保つ`)

**問題点**:
iPhone 16e Simulator / iOS 26.0.1 で、絞り込みなしの全件実行が **198 tests / 2 failures** で終わる。2 件とも同じテストのもので、単独実行 3 回・全件実行 2 回のいずれも同じ値を出す (間欠ではなく決定的)。

```
送った後の画面上の先頭の項目 が期限内に収束しませんでした。実測値: Optional(899)
差し替え後の画面上の先頭の項目 が期限内に収束しませんでした。実測値: Optional(897)
```

同じ `assertAnchorSurvivesChunkSizeChange` を通る `:1188` は通り、iPad Air 11-inch (M4) Simulator / iOS 26.4.1 では全件 198 / 0 で通る。

内訳を読むと、**失敗しているのは差し替え後の契約ではなくテスト自身の前提**である。1 件目は `controller.update(configuration:)` を呼ぶ前、`scrollToItem(.top)` の直後に「画面と重なる項目のうち先頭が 900 であること」を待つ待機であり、実測は 899 — 送り先の 1 つ手前の項目が画面の上端に僅かに残っている。2 件目の 897 は、3 列グリッドでは 897 / 898 / 899 が同じ行の先頭・中・末なので、**「差し替え前に画面の先頭にあった項目 (899) が、差し替え後も先頭の行にいる」ことを示している**。つまり Requirement「配列の内部分割 (iOS)」の「表示範囲の先頭にあった項目を先頭に保つ」は満たされており、実装の退行ではない。

前提が崩れる理由も既知の形である。このヘルパは `scrollToItem` で深い位置 (900 件目) へ一度に飛ばしてから `onScreenItemOffsets(in:).first == 900` を厳密一致で待つ。同じファイルの `advanceToSolvedPosition` (`:2279-2301`) は「飛ばして送ると途中の行が推定のまま残り、位置の動きを行の高さと比べられない」という理由で、送り切ってから `settleContentSize` まで行う形になっている。`UniformHeightRow` の行の高さは `.font(.body)` から決まるため機種の文字設定で端数が変わり、推定のまま残った 900 行ぶんの誤差が解けていく過程で送り先が半端な位置に落ちる — 機種で結果が割れる理由がここにある。

規約上は cross/test-execution.md の「完了判定には絞り込みなしの全件実行を使う」に対して、緑にならない構成が残っている状態であり、lessons `tests-created-in-change-are-in-scope-for-fixes` のとおり本 change が作ったテストなので本 change の責務になる。

**推奨修正**:
- `assertAnchorSurvivesChunkSizeChange` のアンカーを定数 900 の厳密一致で待たず、**送り切った後に実際に画面の先頭にあった項目を読み取ってアンカーにする**。`advanceToSolvedPosition(item:in:)` が既にその形 (`advanceUntilVisible` → `scrollToItem` → `settleContentSize` → `onScreenLeadingIdentifier` を返す) で書かれているので、それを使って戻り値をアンカーにし、差し替え後は「そのアンカーが先頭の行にいる」ことを見る
- 「先頭の行にいる」の判定は、3 列では先頭の項目が 897 になりうるため、`onScreenItemOffsets(in:).first == anchor` ではなく「アンカーと画面先頭の項目が同じ行にある」(`minY` が一致する、または差が列数未満) で書く。`columnCount(in:)` と `itemFrames(in:items:)` が既にあるので道具は揃っている
- 同じ厳密一致は `testadaptiveで列数が変わると塊を組み直して先頭の項目を保つ` (`:1129-1131`・`:1139-1141`) にもあり、こちらは今回の 2 機種では通ったが同じ脆さを持つ。あわせて揃える
- 直した後は、**画面の大きさまたは倍率の異なる 2 機種以上**で絞り込みなしの全件実行を通し、機種と OS を報告に併記する (lessons `report-device-and-os-with-layout-numeric-tests`)。ホストが使った 4 機種はいずれもこの失敗を出していないため、機種を足さないと同じ見落としが残る

### [🟡 Minor] `restoresAnchorAfterApply` と `pendingAnchor` が「適用の束」の単位で持ち越され、遅延復元が古い位置へ戻しうる (レビュー観点 (d))

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:55` (`restoresAnchorAfterApply`)、`:605-607` (立てる)、`:610`・`:614` (適用が重なったときの早期 return)、`:616-625` (消費と遅延復元)

**問題点**:
報告された挙動を追った結果、**恒久的な滞留は構成できなかった**。`applyingSnapshotCount` は `apply` ごとに 1 増え、`dataSource.apply` の完了ごとに 1 減る対称な計数で、diffable の完了は必ず呼ばれるため、束の最後の完了で必ず 0 に戻り、そこで `restoresAnchorAfterApply` は落ちて `pendingAnchor` も消費される。したがって「戻らないまま残り続ける」形は無い。

一方で**実害は残る**。この 2 つの状態は「どの適用が要求した復元か」を持たない単一のフラグと単一のスロットで、`:614` の早期 return によって**束の最初の適用が控えた位置が、束の最後の適用の完了まで生き延びる**。この間に次が起こりうる。

1. 塊の件数が変わる適用 (list ⇄ grid の切り替え、列数の指定の変更、adaptive の列数確定) が走り、そのときの表示位置 P が控えられる
2. 完了の前に `update(configuration:)` 由来の別の適用が重なる。こちらは `animatingDifferences: true` で走りうるので、束の終わりはアニメーションの長さぶん (数百 ms 規模) 後ろへ伸びる
3. その間、コレクションはタッチを受け付けたままなので、利用者はスクロールできる
4. 束の最後の完了が `restoresAnchorAfterApply` を見て 1 実行機会後に `restorePendingAnchor()` を呼び、**利用者が動かした位置を P へ引き戻す**

これが報告にある「後続の適用で古い位置へ戻りうる」の実体だと読む。**重要度は Minor** とした。理由は、(a) どの Scenario も同時操作を含まないため契約違反ではない、(b) 窓は束 1 つぶんに限られ恒久的ではない、(c) 発現には「塊の件数の変化」と「重なる適用」と「その間の利用者のスクロール」の 3 つが同時に要る、から。ただし**本サイクルで露出は広がっている** — review-009 の修正前は `rebuildChunksIfNeeded` だけがこのフラグを立てていたが、いまは利用者が起こす list ⇄ grid の切り替えも通る。

副次的に、早期 return の経路ではフラグが落ちないため、束の中の**塊と無関係な適用の復元まで 1 実行機会ぶん遅れる**。表示上は無害だが、フラグが「この適用が塊の件数を変えた」ことを指さなくなっている。

**推奨修正**:
- 復元の要求を共有フラグではなく**その適用に紐づける**。`captureAnchor()` のたびに増える世代番号を持ち、`pendingAnchor` と遅延復元のクロージャの双方にその番号を載せて、番号が変わっていたら復元を捨てる。`:616-625` の分岐はそのまま使える
- あわせて `scrollViewWillBeginDragging(_:)` で `pendingAnchor` を捨てる。利用者が自分で動かし始めた後に控えた位置へ戻す理由は無く、この 1 行でこの経路だけでなく `settleAnchorIfNeeded` 側も含めた全てのアンカー経路の窓を塞げる
- 本 change のスコープ (spec の Scenario) が要求していないため、9 系へ送る判断もありうる。その場合は Minor 2 (1 実行機会のずれ) と同じく **deviation.md に「既知の窓」として記録する** こと。記録の無いまま送ると、蒸留のときに契約として読めなくなる

### [🟡 Minor] 列数が変わらなかった変化で、他の経路が控えたアンカーまで捨てられる

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:787-798` (`restoreAnchorAfterColumnCountChangeIfNeeded` の `previousColumnCount != currentColumnCount` guard)

**問題点**:
`viewWillTransition` は `pendingAnchor == nil` のときだけ控えるので、控えた直後は確かに自分のアンカーである。ところが復元は `viewDidLayoutSubviews` まで遅れ、その間に `update(configuration:)` が `layoutChanged` で `captureAnchor()` を呼べば `pendingAnchor` は**別の経路が控えた新しいアンカーに差し替わる**。その状態で列数が変わっていなければ `:796` の `pendingAnchor = nil` が走り、差し替えた側が期待していた復元が黙って落ちる (行間や内側余白の変更で位置が動いたまま戻らない)。

回転と layout 値の差し替えが同時に届く場面は多くないが、SwiftUI は回転で body を評価し直すため、`update(configuration:)` が回転の途中に届くこと自体は通常の経路である。捨てる側が「自分が控えたものかどうか」を確かめていないことが原因で、Minor 2 (レビュー観点 (d)) と同じ「アンカーに所有者が無い」問題の別の面である。

**推奨修正**:
上の世代番号を入れるなら、`viewWillTransition` で控えたときの番号を `columnCountBeforeContainerTransition` と並べて持ち、`:796` で捨てるのは番号が一致するときだけにする。世代番号を入れないなら、`columnCountBeforeContainerTransition` を `Int` ではなく「控えた列数とアンカーの識別子」の組にして、`pendingAnchor?.identifier` が一致するときだけ捨てる形でも足りる。

## 指摘ではない所見

### [🔵 Suggestion] 塊の境界の幾何を `frame` で 1 度固定する (review-009 Suggestion 2 の再掲)

未着手のまま残っている。Scenario「塊の境界に不完全な行が無い」の THEN は「境界の直前の行は 2 列とも埋まり、境界の直後の項目は行頭に置かれる」と幾何で書かれているが、`assertChunkStructure` (`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:2416`) は塊の件数が列数で割り切れることしか見ていない。割り切れることが十分条件になるのは「UIKit が各セクションの先頭項目を必ず行頭に置く」前提の下だけで、その前提こそが塊分割の成立条件である。2 列のグリッドで境界の前後 3 項目の `minX` を 1 度だけ確かめれば前提ごと守れる。Major 1 の修正で「同じ行にいるか」を `minX` / `minY` で見る道具を書くなら、その延長で足せる。

### [🔵 Suggestion] `leadingVisibleID()` の余白の扱いが、実際の構成では発火しない

`ios/Sources/KsCollectionView/KsCollectionViewController.swift:750-756` は「表示範囲は bounds をバー等の余白で狭めた矩形」と書いて `adjustedContentInset` で狭めているが、`configureCollectionView()` (`:243`) が `contentInsetAdjustmentBehavior = .never` を立てているため、**バー由来の余白はそもそも入らない**。この分岐は将来 `contentInset` を持ったときの備えとしては意味があるが、コメントは実際に効く条件を書いていない。1 行足して「`.never` を立てているのでバー由来の値は入らず、`contentInset` を持つ構成のための狭め」と書くと、読んだ人が `.never` との矛盾で止まらない。テスト側のヘルパ (`onScreenItemOffsets`) が素の `bounds` を使っていて本番と定義がずれている点も、同じ理由で今は影響しないが、`contentInset` を持つようになった時点で Major 1 と同じ形の食い違いになる。

### [🔵 Suggestion] 9.1 の「非接続の対照」は再計測とは別に必要

`evidence/manual-largeData-ios-2026-09-16-prototype.md` の「限界」は、対照を「9.1 の最終ビルドでの再計測 (同じ fixture・同じ手順) で兼ねる」と書いている。cross/scroll-performance-gate.md が求めているのは**計測器を接続せずに同じ操作列を 1 回行う**対照なので、Instruments を張った 9.1 の走行そのものは対照にならない。9.1 では「接続下の計測 1 回」と「非接続の対照 1 回 (体感と数値が食い違ったときだけ)」を別の走行として数えるか、食い違いに当たらないと判断したならその理由を証跡に書く、のどちらかにする。

### [🔵 Suggestion] `KsImageTests` の間欠失敗は本 change の外として切り出す

報告された `KsImageTests.test失敗した表示はビューが作り直されると再び取得を試みる` の間欠失敗は、レビュアーの 4 走行 (iPhone 16e / 26.0.1 ×3、iPad Air 11-inch (M4) / 26.4.1 ×1) で再現しなかった。本 diff は `KsImage` にも画像の読み込み経路にも触れておらず、本 change が作ったテストでもないため、lessons `tests-created-in-change-are-in-scope-for-fixes` の射程外である。簡易起票で別の change に積み、本 change の完了報告では「本 diff 外・レビュアー側では再現せず」と明記して、全件緑の主張の根拠から外すのがよい。

### [🔵 Suggestion] tasks 7.3 の完了印と `viewWillTransition` の未確認の関係

`tasks.md` の 7.3 は `[x]` が付いているが、そこに含まれる「表示範囲の先頭の項目を保つ」は `viewWillTransition` が SwiftUI の representable 経由で届くことに依存し、その確認は 9 系に残っている (deviation の末尾に記録済み)。deviation を読まないと「印が付いている = 実経路まで確かめた」と読めてしまうので、7.3 の行に「実経路の確認は 9 系」と 1 句添えるか、9 系のタスク側に「`viewWillTransition` の到達を目視で確かめる」を明示的な項目として足しておくと、印と実態がずれない。

### その他 (確認した観点、指摘なし)

- **足場アーティファクトの書き換え**: `specs/` と `design.md` に本サイクルの変更は無い。読み替えはすべて `deviation.md` 側に 4 項追加されている (緩和を全経路へ・1 実行機会のずれ・`leadingVisibleID` の幾何化・回転時の先頭維持)
- **アニメーション抑止の副作用**: `animates = animatingDifferences && !chunkSizeChanged` は、項目の増減と塊の件数の変化が同時に届いたときも一律でアニメーションを落とす。コメント (`:597-600`) がこれを意図として書いており、review-009 の推奨修正どおりである。増減分だけを動かして見せる手立てが差分の側に無いという説明も、`NSDiffableDataSourceSnapshot` の API に照らして正しい
- **`hasSnapshotChanges` と早期 return の分割**: `:484-495` は `itemsAreEqual` のとき可視セルの作り直しだけ先に済ませ、`chunkSizeChanged` なら snapshot 構築へ進む形になっている。ios/ADR-0006 の「同値配列でも可視セルを作り直す」と design Decision 12 の「同値配列の早期 return より前に判定する」を両立しており、コメントが理由まで書いている
- **`KsSectionChunking` の縮退**: `leastCommonMultiple` は `lhs / divisor` を先に割ってからのオーバーフロー検査で、`maximumColumnMultiple` (2,000) 超は解決済み列数へ縮退する。`KsSectionChunkingTests` が list / 固定列数 / 向き別 (割り切れる・互いに素) / 上限超えをそれぞれ固定している
- **公開 API への漏れ**: `KsSectionID` / `KsSectionChunking` / `chunkRebuildCount` / `resolvedColumnCount` / `columnCountBeforeContainerTransition` はいずれも internal。`@_spi(KsMeasurement)` の表面は `KsItemOffsetLookup.itemOffset(of:in:)` 1 本のまま
- **計測ドライバの追加テスト**: `test上限までに定常化しなければ未判定として失敗する` は `XCTExpectFailure` の `issueMatcher` を「定常化しませんでした」に絞っており、他のアサーションが落ちたときは想定外の失敗として表面化する。上限 1 往復では定常判定に要る 3 標本が揃わないので、期待した失敗が起きないまま緑になる形にもなっていない
- **Sample の Debug 構成**: `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG` はプロジェクトの Debug 構成に 1 行入っただけで、Release 側は不変。`#if DEBUG` で囲った UI テストが Debug でだけ数えられる
- **通過記録の一本化**: `PerformanceVerificationView.record(_:into:)` が `indexPath.item` から `KsItemOffsetLookup.itemOffset(of:in:)` へ移り、塊をまたいで一意に数えられる。理由コメントが「item だけで数えると別のセクションの項目と重なる」まで書いている

## アクションプラン

1. **Major**: `assertAnchorSurvivesChunkSizeChange` (と `testadaptiveで…` の同じ形) のアンカーを実測から採り、「同じ行にいる」で判定する。直した後、画面の大きさまたは倍率の異なる 2 機種以上 (ホストが使っていない機種を 1 つ以上含む) で絞り込みなしの全件実行を通し、機種と OS を併記する
2. **Minor 1 (観点 (d))**: 遅延復元をその適用に紐づける (世代番号) + `scrollViewWillBeginDragging` で控えを捨てる。本 change で直さないなら deviation に「既知の窓」として記録する
3. **Minor 2**: `viewWillTransition` が控えたアンカーかどうかを確かめてから捨てる
4. **Suggestion 4 件**: 境界の `minX` の固定 (Major の修正と同じ道具で足せる)、`leadingVisibleID` の余白のコメント、9.1 の非接続の対照の扱い、`KsImageTests` の別起票と tasks 7.3 の注記
