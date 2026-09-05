# レビュー結果: template-parent-state-observation (002 回目)

**日付**: 2026-09-05
**判定**: APPROVED

## サマリー

前回サイクルの指摘 (ホスト Minor 3 件 / Suggestion 1 件、相方 Major 1 件) はすべて対処されている。今回の中心である「配列の変化と観測する値の変化が同時に届いた更新で、生き残る可視セルを再構成する」修正は、自前のプローブ 5 本で独立に検証し、意図どおり動くこと・画面外セルを巻き込まないこと・連続更新でも取り残しが出ないことを確認した。Simulator 実操作による証跡 (list / grid の 1 タップ目) もレビュアー側で再現できた。ビルド・テストは全件通過 (本体 91 件 / Sample 3 件、いずれも 0 failures)。

指摘は Critical / Major なし、Minor 1 件・Suggestion 2 件。Minor は公開 doc コメントのうち「観測する値を渡さない場合」の 1 文が実挙動より広く約束している点で、型レベルの doc コメントに逆向きの但し書き (「渡さないと追従しないことがあります」) があるため実害は限定的だが、両者が矛盾したまま公開される。

## 照合した規約

| 文書 | 適用のきっかけ | 判定 |
|---|---|---|
| handbook/cross/comment-policy.md | 常時 (全ソースコード) | 適用。`comment-policy-lint.py` 0 件 (検査対象 141 ファイル) + 規約本文からの目視照合。公開 doc コメントに内部用語なし、ADR 参照は internal 側のみ |
| handbook/cross/test-execution.md | テストを実行するとき・テスト結果を報告するとき | 適用。全件実行を件数まで確認。新規テストの待機は実時間 deadline + 実行機会の譲り + 失敗時の実測値表示を満たす既存ヘルパを使用 |
| handbook/cross/runtime-behavior-verification.md | 実行時挙動の不具合調査・完了判定 | 適用。観測点表「検証: 行の高さ変化 (iOS 固有)」の証跡が `evidence/height-change-tap-verification.md` にあり、レビュアーが独立に再現 |
| handbook/cross/sample-parity.md | `samples/` を触るとき | 適用。「検証: 行の高さ変化」は技術検証画面の例外枠 |
| handbook/ios/performance-verification.md | iOS エンジンの描画・再利用・レイアウト経路に触れるとき | 適用範囲に当たる。計測の要否はオーナー判断へ委ねることが決まっており、適用外と判断した根拠が `deviation.md` に記録済み (指摘対象外。ただし Suggestion 3 参照) |
| handbook/cross/public-identifiers.md | 公開識別子・配布座標を決めるとき | 適用外 (ビルド定義・パッケージ宣言に触れていない) |
| handbook/cross/local-development-setup.md | 環境構築の手順が要るとき (guide) | 適用外 |

参照した決定: ios/ADR-0006 (accepted)、ios/ADR-0007 (accepted。grid で背の低いセルが行高いっぱいに広がらないこと — 証跡の grid 静止画と一致)、ios/ADR-0008 (proposed — 本 change の根拠。proposed なので単独では指摘の根拠にしていない)、core/ADR-0002、core/ADR-0003。

`kasane/lessons/code-review.md` は未作成のため、ルールの追加・抑制はなし。inbox の `reviewer-reproduces-evidence-numbers-by-probe` に従い、プローブテスト 5 本と Simulator の実操作で証跡と修正の効果を独立に再現した (プローブは実行後に撤去済み、`git status` で残骸なしを確認)。

## 実行結果

| 対象 | コマンド | 結果 |
|---|---|---|
| 本体 | `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug` | Executed 91 tests, with 0 failures |
| Sample | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples` (同 Simulator) | Executed 3 tests, with 0 failures |
| lint | `comment-policy-lint.py` / `local-path-lint.py` / `identity-lint.py` | いずれも違反 0 件 |

件数は前回の 89 件から新規 2 本 (engine 1 / SwiftUI 統合 1) を加えた 91 件で、コンテキストパッケージの「新規テスト 2 本」と一致する。

### レビュアーのプローブ (一時ファイル、確認後に撤去)

いずれも `observedValue` を宣言した構成で、テンプレートのクロージャの呼び出し回数と、そのとき読まれた観測値を記録して判定した。

| プローブ | 観測結果 |
|---|---|
| 配列追加 + 観測値変更の同時更新 (30 件、可視 4 件) | 可視 4 件がすべて 1 回ずつ再構成され、新しい観測値を読む (id 1 → `true`)。画面外の id 20 は更新時に一度も構成されず、可視域へ送った時点で新しい観測値 (`true`) で構成される |
| 項目削除 + 観測値変更の同時更新 | 残った 4 件すべてが再構成され、id 4 が新しい観測値を読む。identifiers も期待どおり |
| テンプレートキー変更 (reload) + 観測値変更の同時更新 | 例外・アサーション無しで完了。同一 snapshot への reconfigure と reload の二重指示は起きていない |
| 適用中の連続 2 更新 (1 回目の配列変更の適用完了を待たずに配列 + 観測値を変更) | 生き残った可視 6 件すべてが期待どおりの観測値を読む (取り残しなし) |
| 観測値**未宣言**で配列変更 + 親状態変更が同時に届く更新 | 既存の可視セル 4 件はいずれも再構成されない (呼び出し回数が 1 のまま、古い状態を保持) → 指摘 1 / Suggestion 2 の根拠 |

Simulator (iPhone 17 Pro / iOS 26.5) 実操作による証跡の再現: `--verify-height-change` で起動し、親 state 経路の list で 1 タップ目に行 1 が展開、もう 1 タップで折りたたみ、grid へ切り替えた直後の 1 タップ目でも展開することを確認した。`evidence/height-change-tap-verification.md` の主張と一致する。

## 前回指摘の対処状況

| 前回の指摘 | 状態 | 確認内容 |
|---|---|---|
| review-001 Minor 1: deviation が導入した分割を守るテストが無い | 対処済み | `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:941` / `:950` で、観測値が同じ更新でも `touchFeedbackColor` が `.systemFill` → `.systemRed` へ届くことを、テンプレート非呼び出しのアサーションと対で固定している |
| review-001 Minor 2: doc が「渡した値以外の変化では作り直されない」を述べていない | 対処済み | `ios/Sources/KsCollectionView/KsCollectionView.swift:121-124` に排他性の段落が入り、「1 つの値にまとめて渡す」がその帰結として読める |
| review-001 Minor 3: spike の結論が構成 C については射程外 | 対処済み | `deviation.md` の見出しが「A・B は効果なし・C は未判定のため取り込まない」に直り、本文が構成ごとの射程を分けて記述している |
| review-001 Suggestion 5: 性能検証を適用外と判断した根拠が残っていない | 対処済み | `deviation.md` に「iOS 性能検証の扱い」節が追加され、適用範囲に当たることと計測を行わない理由、オーナー判断に委ねる旨が記録されている |
| review-001 Suggestion 4: Android の「展開中: N 行」が残っている | 未対処 (オーナー判断へ) | `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/HeightChangeVerificationScreen.kt:91` に `heightChange.expandedCount` が残存。指摘対象外の扱いに同意する (sample-parity の例外枠であり規約違反ではない) |
| second-opinion Major 1: 配列と観測値が同時に変わると既存の可視セルが再構成されない | 対処済み | `ios/Sources/KsCollectionView/KsCollectionViewController.swift:408-421` / `:446-454` で生き残る可視 identifier を再構成対象へ加えている。上表のプローブ 4 本で挙動を独立に確認した |
| second-opinion Major 2: list / grid の実操作確認の証跡がない | 対処済み | `evidence/height-change-tap-verification.md` + 静止画 7 点。レビュアー側でも独立に再現 |
| second-opinion Major 3: 性能検証がない | 未対処 (オーナー判断へ) | 双方一致の確定事項。指摘対象外の扱いに同意する |

## 指摘事項

### [🟡 Minor] 観測する値を渡さない場合の doc コメントが、配列が変わる更新での実挙動より広く約束している

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionView.swift:133`

**問題点**:
doc コメントは「渡さない場合は、表示するビューが再評価されるたびに表示中のセルの内容を作り直します」と無条件で述べている。しかし実際に毎回作り直すのは**配列が同値の更新**だけで、配列が変わる更新では差分計算で拾われた項目しか作り直されない。

プローブで確認した (上表の 5 本目): 観測する値を宣言せず、テンプレートが読む親の状態の変化と配列への 1 件追加が同じ更新で届いたとき、既存の可視セル 4 件はいずれもクロージャが呼び直されず、古い状態を表示したまま残った。

デルタスペックの側は「**配列が同値でも**親 View の更新が届くたびに可視セルを再構成する」と条件を明示しており、doc からその条件だけが落ちている。同じファイルの型レベル doc コメント (`ios/Sources/KsCollectionView/KsCollectionView.swift:5-7`) は「渡さないと、状態が変わっても表示が追従しないことがあります」と「ことがあります」の限定付きで正しく書けているため、2 つの記述が互いに矛盾した状態になっている。実害は型レベルの但し書きで緩和されるが、この modifier の doc だけを読んだ利用者は「渡さなくても届く」と読める。

**推奨修正**:
`:133` の 1 文に「配列が同じ更新では」相当の限定を足し、型レベル doc の但し書きと向きを揃える。合わせて、蒸留 (tasks 4.1 / 4.2) で concepts へ書く利用者契約にも同じ限定を反映する。

### [🔵 Suggestion] 観測する値を宣言しない経路の穴を、蒸留で明示的に残す

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:408-421`、`kasane/decisions/ios/0006-reconfigure-visible-cells-on-equal-array-update.md`

**問題点**:
今回の修正で、観測する値を**宣言している**利用者は「配列変更 + 状態変更の同時更新」でも取り残しが出なくなった。一方、宣言していない利用者 (ios/ADR-0006 の前提どおり body でも状態を読んでいるケース) では同じ状況で取り残しが残る (プローブで確認)。これはデルタスペックが「未指定時の挙動は変えない」と明記した範囲であり、本 change の仕様違反ではない。

ただし結果として、同じ「親の状態を捕捉するテンプレート」という目的に対して宣言の有無で追従の射程が非対称になった。ios/ADR-0006 が掲げた「親の状態を捕捉するテンプレートを成立させる」という目的は、宣言なしの経路では配列変更を伴う更新で成立しないという事実が、どの層にも書かれていない。

**推奨修正**:
蒸留で ios/ADR-0008 を accepted に昇格し ios/ADR-0006 の Consequences を改訂する際 (proposal の Non-Goals で本 change の蒸留時に行うと宣言済み)、この非対称を Consequences か concepts に 1 行残す。追加の実装は求めない。埋める判断をするなら別 change の材料になる。

### [🔵 Suggestion] deviation の性能主張に、配列変更経路で増えた全項目走査を書き添える

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:446-454`、`deviation.md`「iOS 性能検証の扱い」

**問題点**:
deviation は「加えた分岐は…テンプレートの呼び直しを省く方向のみで、フレームあたりの新規コストを足していない」と書いており、オーナーが計測の要否を判断する材料になる。この主張は概ね妥当だが、再構成対象の算出式が `plan.reconfigure` 基準 (差分件数に比例) から `identifiers` 基準 (全項目を走査し、要素ごとに最大 3 回の集合照合) へ変わっており、**配列が変わる更新に全項目 1 パスが増えている**。観測する値を宣言していない利用者にもこのパスは掛かる。

`apply` は既に全項目規模の処理を複数持つ (`Set(currentIdentifiers)`、`identifiers != currentIdentifiers`、`itemsByID` / `keysByID` の再構築、プラン生成) ためオーダーは変わらず、スクロール中のフレームで走る経路でもない。合否を左右する指摘ではないが、「新規コストを足していない」という記述のままだと、判断の前提が実際よりわずかに強い。

**推奨修正**:
deviation の当該節に「配列が変わる更新の再構成対象の算出が全項目走査 1 パス分増えている (既存の同規模パスと同オーダー、スクロール中の経路ではない)」旨を書き添える。実装で消したいなら、`survivingVisibleIdentifiers` が空のときは従来式に分岐すれば元のコストに戻せる (この場合も deviation への記録は不要になるだけで、挙動は変わらない)。

## 確認した観点 (指摘に至らなかったもの)

- **spec 充足**: collection-core の 6 Scenario すべてに engine / SwiftUI 統合テストの対応があり、実装経路も一致する。「配列の変化と観測する値の変化が同時に届く」は今回、値の記録 (`test配列と観測する値が同時に変わった更新でも観測する値を記録する`) と既存可視セルの再構成 (`test配列と観測する値が同時に変わった更新で既存の可視セルも再構成する` / `test配列の変化と同時に届いた観測する値の変化を既存の可視セルへ反映する`) の 2 面から固定されている
- **修正が回帰テストで守られているか**: 新規テストは修正前の実装 (生き残る可視セルを再構成しない) では `builds.counts` が増えず失敗する形になっており、守りとして機能する
- **再構成対象の算出の等価性**: `survivingVisibleIdentifiers` が空のとき、新しい式 `identifiers.filter { planReconfigure ∪ surviving かつ existing }` は従来の `plan.reconfigure.filter(existing)` と同じ集合を返す (`KsSnapshotPlanner` が `identifiers` を重複排除済みで返し、`reconfigure` は必ずその部分集合)。順序だけが新配列順に変わるが `reconfigureItems` の意味に影響しない
- **reload との二重指示**: `survivingVisibleIdentifiers` に入った identifier も末尾の `.filter { !reloadedIdentifiers.contains($0) }` で除かれる。テンプレートキー変更と観測値変更を同時に起こすプローブでも例外は出ていない
- **画面外セルの扱い**: 生き残る可視セルの収集は `indexPathsForVisibleItems` を経由し、画面外は対象外。プローブで、画面外セルは更新時に構成されず、可視域へ入った時点で新しい観測値で構成されることを確認した (無駄な構成も取り残しも無い)
- **`hasSnapshotChanges` の拡張**: `!survivingVisibleIdentifiers.isEmpty` を足したことで、差分が無くても観測値変更のために snapshot を適用する経路ができるが、これは配列が変わった更新に限られる (同値配列は手前の早期 return が拾う)。Scenario「観測する値の変化は差分計算を伴わない」に抵触しない
- **既存パターンとの一貫性**: `indexPathsForVisibleItems` + `dataSource.itemIdentifier(for:)` の組み合わせは既存の `reconfigureVisibleCells` と同じ形で、新しい規約を持ち込んでいない
- **Sample の変更**: 回避策の表示とそのコメントが撤去され、`heightChange.expandedCount` の参照は iOS 側に残っていない (Android 側のみ。上表参照)。spike のコード (`withTransaction` / `CADisplayLink`) も `ios/` `samples/` に残骸なし
- **証跡の妥当性**: 静止画 7 点に個体・個人を特定する情報は写っていない。`height-change-grid-1-before.png` と `height-change-grid-3-collapsed.png` はバイト同一で、撮り直しか複製かは判別できないが、レビュアーが Simulator を独立に操作して grid の 1 タップ目の展開と折りたたみを再現したため、主張自体は裏付けられている
- **足場の凍結**: `proposal.md` / `specs/` は未変更。`tasks.md` の差分はチェックマークのみ
- **パス記述**: `deviation.md` / `evidence/` の参照はすべて change 相対またはリポジトリ相対。ローカル絶対パスなし (lint でも 0 件)
- **tasks 4.1 / 4.2 (concepts 更新)**: 蒸留フェーズへの引き渡し運用のため未着手を指摘対象にしていない (指摘 1 / Suggestion 2 はその蒸留内容への申し送り)

## アクションプラン

1. (指摘 1) `KsCollectionView.swift:133` の 1 文に「配列が同じ更新では」相当の限定を足す — 公開 doc の矛盾を解消する。1 行で済み、テストへの影響はない
2. (Suggestion 3) deviation の性能節に、配列変更経路で増えた全項目走査 1 パスを書き添える — オーナーの計測要否判断の前提を正確にする
3. (Suggestion 2) 宣言なし経路の非対称を、蒸留での ios/ADR-0006 Consequences 改訂に申し送る
4. (前回 Suggestion 4 / second-opinion Major 3) Android の「展開中: N 行」と iOS 性能計測の要否は、決まりどおりオーナーへ諮る

いずれも APPROVED を覆すものではない。1 と 2 は本サイクル内で片付ければ蒸留へそのまま渡せる。
