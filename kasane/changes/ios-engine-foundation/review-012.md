# レビュー結果: ios-engine-foundation (012 回目)

**日付**: 2026-09-03
**判定**: CHANGES_REQUESTED

## サマリー

中央配置はみ出し対策 (`KsRowContentPlacement`) と推定高さの実測化 (`KsEstimatedHeight`) は、いずれも翻案元の核心を正しく写しており、A/B 証跡・summary.md・deviation.md の数値も一致している。公開 API は不変で、ios パッケージ 71 件 / Sample 3 件のテストは全て通過した。

一方で、(a) 証跡に動画 2 本 (計 4.7MB) が置かれており ksn-core の媒体規約に明文で反すること、(b) `KsRowContentPlacement` が縦位置だけでなく**水平位置と「行の高さの content への提案」も変えており**、幅を明示していないテンプレートの見え方が変わる副作用が記録も検証もされていないこと、の 2 点が残る。いずれも未コミットの今なら安く是正できる。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| [ソースコメント規約](../../handbook/cross/comment-policy.md) | always |
| [Sample のプラットフォーム間一致](../../handbook/cross/sample-parity.md) | `samples/` を触るため (検証画面の追加) |
| [実行時挙動の検証規約](../../handbook/cross/runtime-behavior-verification.md) | 実行時挙動の不具合修正・完了判定 (本 change が本文を改訂) |
| [テスト実行規約](../../handbook/cross/test-execution.md) | テストの実行と件数報告 |
| [ローカル開発環境と Sample の実行](../../handbook/cross/local-development-setup.md) | 本体・Sample のビルド (iOS 16 下限の確認) |
| ksn-core `references/ui-artifacts.md` / `references/evidence.md` | `evidence/` に媒体とメモを追加したため |
| ios/ADR-0001〜0004 / lessons inbox (`verify-interactive-collection-layout-transitions`) | 翻案移植・自前 compositional セクション・レイアウト遷移の検証観点 |

ドメインスキル: `swift-ui-impl-skill` (1 ファイル 1 型・View 分割・モダン API・Concurrency の観点)。`skills.code-review` は ios ドメインに未定義。

## 検証したこと

- **ビルド / テスト**: `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.1' -configuration Debug` → `Executed 71 tests, with 0 failures`。`xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples`(同 Simulator) → `Executed 3 tests, with 0 failures` (Sample アプリのビルドを含む)。summary.md の「71 件通過 (60 + 11)」と一致
- **公開 API 不変**: `git diff` の Sources 側変更は internal 宣言のみ。新規 2 型はいずれも `internal`。`KsPublicAPITests` は無改変で通過
- **lint**: `comment-policy-lint.py --summary` → 禁止 0 件 / `identity-lint.py`・`local-path-lint.py` → 検出なし
- **証跡と文書の一致**: `evidence/height-change-after-ab-measurement.md` の `bounds.h=44.333 / natural.h=141.667 / offsetY=-48.667 → 0.0`・「負になった回数 4 → 0」、`evidence/estimated-height-ab-measurement.md` の「初回誤差 -26.9% → 0%」「再計算 27 → 3」「固定 44 = 225,244 / 中央値 = 226,906 / 平均 = 264,301 / 真値 ≈ 300,000」は、いずれも summary.md・deviation.md の記述と一致する
- **翻案の忠実性 (縦方向)**: `../KsSettingsView/ios/Sources/KsSettingsViewUI/CustomCellRowPlacement.swift` と突き合わせた。`sizeThatFits` の「提案高さをそのまま返し、提案なしのときだけ自然高を返す」は同一。`placeSubviews` の簡略化 (常に上端) は、翻案元に `effectiveCellHeight = 0` を入れた場合と数学的に等価 (`restingHeight = min(bounds.h, natural.h)` → `offsetY = max(0, (restingHeight - natural.h)/2) = 0`)。固定行高契約を持たない本ライブラリで失われる安全策は縦方向には無い
- **無限ループの不在**: `record` は `invalidateLayout()` を呼ばないため、自己サイズ → 推定更新 → 再レイアウトの閉ループは成立しない。`viewDidLayoutSubviews` の invalidate も `lastContainerSize` の guard で 1 回に収束する
- **sample-parity の例外条件**: 検証画面はルートメニュー上で「検証: …」表記により区別され (`VerificationScreen.swift:3`)、handbook の観測点表にも「デモ画面の集合に数えない」と明記された。例外枠の 2 条件は満たしている

## 指摘事項

### [🟠 Major] 証跡に動画 (.mov) を残している — 媒体規約の明文違反

**該当箇所**: `evidence/height-change-after-ab-before-centered.mov` (2.4MB) / `evidence/height-change-after-ab-after-topaligned.mov` (2.3MB)、参照元 `evidence/height-change-after-ab-measurement.md` の「録画」節、`summary.md` の「触ったファイル」

**問題点**: ksn-core `references/ui-artifacts.md` は「動画 (mov / mp4 / webm) は撮らない・残さない (容量が大きく、写り込みの確認とマスクができない)。動きの証跡が要るときは静止画の連番で代替する」と定め、`references/evidence.md` の表も `evidence/` に「置かない」側へ動画を挙げている。合計 4.7MB は `evidence/` 配下の他ファイル全体 (png 14 枚で約 2.3MB) の 2 倍にあたり、規約が挙げる容量の懸念にそのまま該当する。commit すると git 履歴から消せなくなる性質の違反であり、現在は untracked なので是正できるのは今だけ。

**推奨修正**: 2 本の .mov を `trash` で削除し、`evidence/height-change-after-ab-measurement.md` の「録画」節を削除するか、必要なら静止画の連番 (`height-change-after-<状態>-N.png`) に差し替える。数値 A/B (offsetY の表) が既に修正の効果を示しており、動画が無くても主張の裏付けは失われない。`summary.md` の「録画 2 本」の記述も併せて直す。

### [🟠 Major] `KsRowContentPlacement` が水平位置も先頭固定にしている — 縦位置対策の想定外の副作用

**該当箇所**: `ios/Sources/KsCollectionView/KsRowContentPlacement.swift:41-45`、`:59-61`

**問題点**: `placeSubviews` は `contentOrigin(in:)` (= `bounds.minX`, `bounds.minY`) に `anchor: .topLeading` で置き、幅は `bounds.width` を提案する。提案幅より自然幅が小さい content (短い `Text`、アイコンだけのグリッドセル等) は、`UIHostingConfiguration` 単体だったときはホスト View に**水平中央**へ置かれていたのに対し、本変更後は**先頭寄せ**になる。ライブラリ利用者が書いたテンプレートの既定の見え方が変わる。

この副作用は本 change のどこにも記録されていない。deviation.md と summary.md が述べるのは縦方向 (「常に上端へ揃える」) だけであり、`KsRowContentPlacement` 自身の doc コメントも「行の中で content の縦位置を決めるレイアウトです」と縦方向だけを契約として宣言している (`:3`) — 実装が自分の doc コメントより広い範囲を変えている。

証拠の性質: 本リポジトリの Sample テンプレートは `DemoListRow` / `DemoGridCell` / `TemplateSwitchDemoView` / `.header` / `.footer` の全てが `.frame(maxWidth: .infinity, ...)` を付けているため、Sample・UI テスト・既存の証跡画像のいずれにも差が現れない (= テストが通ることは非発現の根拠にならない)。逆に、全テンプレートが一律に `maxWidth: .infinity` を書いている事実自体が、素の `UIHostingConfiguration` が content を中央へ置く挙動への対処と読める。

**推奨修正**: 幅を明示しない content (例: `Text("A")` だけのテンプレート) を 1 件だけ Simulator で表示し、変更前後の水平位置を実測する。中央だったと確認できたら、次のいずれかを採る。

1. 水平方向は従来どおり中央を維持する — `placeSubviews` で自然幅を測り `x = bounds.minX + max(0, (bounds.width - natural.width) / 2)` に置く (翻案元が縦方向で行っている「余白があれば等分」と同じ形。縦方向の対策には影響しない)
2. 先頭寄せを意図的な仕様として採るなら、deviation.md に「content の水平位置は中央 → 先頭に変わる」を記録し、`KsRowContentPlacement` の doc コメントを水平位置も含む契約に直し、`contentOrigin(in:)` の x に対するテストを足す

### [🟡 Minor] content に行の高さが一切提案されなくなる — grid で背の低いセルが行高いっぱいに広がれない

**該当箇所**: `ios/Sources/KsCollectionView/KsRowContentPlacement.swift:44`

**問題点**: `placeSubviews` は常に `ProposedViewSize(width: bounds.width, height: nil)` を content へ提案する。このため、grid で「その行のうち最も高いセル」に合わせて行が高くなったとき、背の低いセルの content は自然高のままとなり、`.frame(maxHeight: .infinity)` や `Spacer()` で行高いっぱいに広げる書き方 (背景色を行全体に敷く等) が効かなくなる。変更前は行の高さが content へ提案されていたため成立していた。

高さ提案を `nil` にすること自体は自己サイズを成立させるための必然 (行高を content へ提案すると自己サイズが自己参照になる) であり、翻案元も同じ選択をしている。問題は、その帰結が記録されていないこと。

**推奨修正**: deviation.md に「content には行の高さを提案しないため、行高いっぱいに広がるテンプレートは自然高で描かれる」を既知の帰結として記録する。挙動を戻したい場合は、`bounds.height >= natural.height` の定常状態に限り `height: bounds.height` を提案する形が採れる (自己サイズの問い合わせは提案なしの経路を通るため、遷移中の上端固定は保たれる)。

### [🟡 Minor] 推定値が移動平均のため、大量件数のスクロール中に contentSize が揺れうる

**該当箇所**: `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:16`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:459`,`:464`

**問題点**: 証跡 (`evidence/estimated-height-ab-measurement.md` のスクロール制御デモ: 初回 contentSize 6433.33 = 100 件 × 実測平均) から、section provider の再実行時に**未計測の項目すべてへ最新の平均が適用される**ことが読み取れる。保持するのは直近 32 件だけなので、平均は全期間平均ではなく移動平均であり、行高が混在するコレクション (大量件数デモは 7 件に 1 件が長文) を長くスクロールすると、窓の中身が入れ替わるたびに未計測分の見積もりが動く → contentSize が変動し、スクロールインジケータの長さ・位置が揺れる可能性がある。固定 44 は偏っていたが安定していたので、これは本変更で新しく入る性質。

証跡は初回 contentSize と末尾到達までの再計算回数を測っており、**長いスクロール中のインジケータ・オフセットの安定性は測られていない**。また窓 32 件は「可視範囲と再利用プールより十分大きい」とコメントされているが (`KsEstimatedHeight.swift:15`)、iPad の多列 grid では可視セルが 32 を超えうる。

**推奨修正**: 大量件数デモ (grid 2 列 / 10,000 件) を通しでスクロールし、インジケータの跳ねと `contentOffset` の飛びが無いことを観測点として確認する (lessons inbox `verify-interactive-collection-layout-transitions` の「layout 切替後の上下スクロール」と同じ性質の確認)。揺れが出るようなら、全期間の累積平均 (件数と総和だけを持つ) にするか窓を大きくすることで、推定値の安定性を上げられる。

### [🟡 Minor] `reset()` の契機が layout kind の変更だけで、コメントの主張 (幅が変わったら捨てる) を満たしていない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:111-113`、`ios/Sources/KsCollectionView/KsEstimatedHeight.swift:35-39`

**問題点**: `reset()` の doc コメントは「行の幅が変わる list / grid の切り替えでは、別の幅で測った値が推定の役に立たないため捨てます」と幅を理由に置いているが、実際の契機は `previousLayout.kind != configuration.layout.kind` だけ。`.grid(.adaptive(minItemWidth:))` や `.grid(.orientation(portrait:landscape:))` では、**回転やウィンドウサイズ変更で列数と列幅が変わっても kind は変わらない**ため、別の幅で測った実測値がそのまま残る。list でも回転で行幅が変わるが同様に残る。`viewDidLayoutSubviews` はコンテナサイズ変化で `invalidateLayout()` を呼ぶので、古い幅で測った平均がそのまま新しい幅の見積もりに使われる。

実害は「回転直後の見積もりが一時的にずれる」程度 (数十件の実測で置き換わる) だが、コメントが宣言する契約と実装が食い違っている点は直しておきたい。

**推奨修正**: `viewDidLayoutSubviews` でコンテナ幅の変化を検出した時点でも `reset()` する (`lastContainerSize` の比較が既にある) か、`reset()` のコメントを実際の契機 (表示形態の切り替え) に合わせて直す。

### [🟡 Minor] コメントが説明対象の行とずれている

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:267-271`

**問題点**: 「中央配置だと content が上方向にもはみ出す。`KsRowContentPlacement` で上端へ固定する」というコメントが `cell.onMeasuredHeight = ...` (推定高さの記録) の直上に置かれており、説明対象の `contentConfiguration` 代入 (`:272-275`) は 3 行下にある。ソースコメント規約が求める「そのファイルだけを読んでいる人にとって意味が通る」状態から見て、読み手は最初にコメントと無関係な行を読むことになる。

**推奨修正**: コメントを `cell.contentConfiguration = ...` の直上へ移す。`onMeasuredHeight` の代入には、なぜここで毎回設定するのか (または 1 行の意図) を短く添えるか、コメント無しにする。

### [🔵 Suggestion] `KsRowContentPlacementTests` が `Layout` 本体の配線を検証していない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsRowContentPlacementTests.swift:7-42`

4 件のテストは `resolvedSize` / `contentOrigin` という static ヘルパーだけを直接叩いており、`sizeThatFits` / `placeSubviews` がそれらを実際に使っているか (特に `place` の `anchor: .topLeading` と高さ提案 `nil`) は検証されない。配線が外れてもテストは緑のままになる。`Layout` のプロトコル要件は `LayoutSubviews` を用意しづらいので、最低限 `sizeThatFits` を実 `Layout` 経由で呼ぶテスト (`ViewThatFits` 相当のホストを用意する) が難しければ、ヘルパーが唯一の入口であることをコメントで明示しておくと、後続の変更で外れにくくなる。

### [🔵 Suggestion] `sizeThatFits` が使わない計測を毎回行う

**該当箇所**: `ios/Sources/KsCollectionView/KsRowContentPlacement.swift:30-31`

幅・高さともに有限の提案が来たとき、`subview.sizeThatFits(...)` の結果 (`natural`) は `resolvedSize` で 1 度も参照されない。SwiftUI の content 計測は可視セル数 × レイアウトパス数だけ走るので、提案が両軸とも有限なときは計測を省く (遅延評価にする) と無駄が減る。翻案元も同じ形なので忠実性は損なわれない。

### [🔵 Suggestion] `prepareForReuse` で `onMeasuredHeight` を解除していない

**該当箇所**: `ios/Sources/KsCollectionView/KsHostingCell.swift:112-120`

`prepareForReuse` は `contentConfiguration = nil` にするが `onMeasuredHeight` は残す。セル登録のハンドラが `itemsByID` の引き当てに失敗して `applyContent` を通らなかった場合 (`KsCollectionViewController.swift:236-243` の guard)、内容が空のまま行われた計測が前回のハンドラ経由で推定値に混ざりうる。`record` が 0 以下を弾くので実害は小さいが、`prepareForReuse` で `onMeasuredHeight = nil` にしておくと「内容を適用したセルの計測だけを数える」ことが構造で保証される。

### [🔵 Suggestion] 追加した検証画面に UI テストが無い

**該当箇所**: `samples/ios/KsCollectionViewSamples/HeightChangeVerificationView.swift`、`samples/ios/KsCollectionViewSamples/SampleLaunchView.swift:19-21`

既存の 2 つの検証画面 (`InteractiveControlVerificationView` / `LongPressVerificationView`) は起動引数と対になる UI テストを持つのに対し、`--verify-height-change` にはテストが無い。accessibility identifier (`heightChange.expandedCount` 等) は既に揃っているので、「行をタップ → `展開中: 1 行` になる」だけのスモークを 1 件足せば、テンプレート内 state / 親 state の経路が壊れたときに気付ける (回避策を外す後続 change の再確認にもそのまま使える)。実行時挙動そのものの完了判定は目視で行う規約なので、これは回帰検知用の補助として。

### [🔵 Suggestion] ルートメニューで検証画面が区分として分かれていない

**該当箇所**: `samples/ios/KsCollectionViewSamples/RootMenuView.swift:6-16`

`VerificationScreen` はデモ画面と同じ `List` に 2 つ目の `ForEach` として並ぶだけで、視覚的な区切りが無い。sample-parity の例外枠が求める「明確に区別する」は文言 (「検証: …」) で満たしているが、`Section("検証")` に入れると、Android 側 Sample と突き合わせる人がデモ画面の集合を数え間違えにくくなる。

## アクションプラン

1. `evidence/` の .mov 2 本を削除し、参照している証跡メモと summary.md の記述を直す (commit 前でないと取り返せない)
2. 幅を明示しないテンプレートで content の水平位置を Simulator 実測し、中央維持へ直すか、deviation.md と doc コメントへ記録する
3. content へ行の高さを提案しない帰結 (grid で行高いっぱいに広がらない) を deviation.md に記録する
4. 大量件数デモの通しスクロールで、推定値の移動平均に由来するインジケータ・オフセットの揺れが無いことを観測する
5. `reset()` の契機とコメントの食い違いを、どちらかに寄せて解消する
6. `applyContent` のコメント位置を直す
7. 🔵 の 5 件は任意 (2 の対応内容によっては、テスト追加が 7 と合流する)
