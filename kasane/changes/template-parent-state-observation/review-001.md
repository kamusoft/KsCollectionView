# レビュー結果: template-parent-state-observation (001 回目)

**日付**: 2026-09-05
**判定**: CHANGES_REQUESTED

## サマリー

`observedValue(_:)` の追加と、同値配列経路でのテンプレート呼び直しの抑止は、デルタスペックの Requirement / 6 つの Scenario をいずれも満たしており、実装は素直で既存の DSL の作法にも揃っている。ビルド・テストは全件通過 (本体 89 件 / Sample 3 件、いずれも 0 failures)。指摘は Critical / Major なし、Minor 3 件・Suggestion 2 件で、いずれも実装の正しさではなく「今の正しさを将来守る仕掛け」と「記録の射程」に関するもの。最優先は deviation.md が導入した分割 (テンプレートの呼び直しと位置依存表示の分離) を守るテストが無い点。

## 照合した規約

| 文書 | 適用のきっかけ | 判定 |
|---|---|---|
| handbook/cross/comment-policy.md | 常時 (全ソースコード) | 適用。`comment-policy-lint.py` 0 件 + 規約本文からの目視照合済み (指摘 2 参照) |
| handbook/cross/test-execution.md | テストを実行するとき・テスト結果を報告するとき | 適用。実行件数まで確認済み |
| handbook/cross/sample-parity.md | `samples/` を触るとき | 適用。「検証: 行の高さ変化」は技術検証画面の例外枠 (指摘 4 参照) |
| handbook/cross/runtime-behavior-verification.md | 実行時挙動の不具合調査・完了判定 | 適用。観測点表「検証: 行の高さ変化 (iOS 固有)」が対象 |
| handbook/ios/performance-verification.md | iOS エンジンの描画・再利用・レイアウト経路に触れるとき | 適用判定に疑義あり (指摘 5 参照) |
| handbook/cross/public-identifiers.md | 公開識別子・配布座標を決めるとき | 適用外 (ビルド定義・パッケージ宣言に触れていない) |
| handbook/cross/local-development-setup.md | 環境構築の手順が要るとき (guide) | 適用外 |

参照した決定: ios/ADR-0006 (accepted)、ios/ADR-0008 (proposed — 本 change の根拠。proposed なので単独では指摘の根拠にしていない)、core/ADR-0002。
`kasane/lessons/code-review.md` は未作成のためルールの追加・抑制はなし。inbox の `reviewer-reproduces-evidence-numbers-by-probe` に従い、自前のプローブテスト 2 本で挙動を独立に確認した (実行後に削除済み)。

## 実行結果

| 対象 | コマンド | 結果 |
|---|---|---|
| 本体 | `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug` | Executed 89 tests, with 0 failures |
| Sample | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples`(同 Simulator) | Executed 3 tests, with 0 failures |
| lint | `comment-policy-lint.py --summary` / `local-path-lint.py` / `identity-lint.py` | いずれも違反 0 件 |

レビュアーのプローブ (一時ファイル、確認後に削除):

- 観測する値を宣言したまま `touchFeedbackColor` を差し替えた更新で、可視セルの色が `.systemFill` → `.systemRed` へ届くことを確認 → deviation.md「可視セル再構成の分割」の主張は現行実装で成立している
- 観測する値が同じ更新では、`registry` を作り直しても (テンプレートのクロージャが別物になっても) クロージャが 1 度も呼ばれないことを確認 → spec どおりだが、指摘 2 の根拠

## 指摘事項

### [🟡 Minor] deviation が導入した分割を守るテストが無い

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:928`、`deviation.md`「可視セル再構成の分割 (spec の解釈)」

**問題点**:
deviation.md は「後者 (位置依存の表示・タッチ時の背景色) まで止めると、観測する値を宣言している利用者に限り `touchFeedback(color:)` の色変更が表示中のセルへ届かなくなる回帰になる」ことを分割の理由に挙げている。しかしその回帰を検出するテストが無い。

- 既存の `testtouchFeedback色の変更を可視セルへ反映する` (同ファイル:1036) は `observedValue` を宣言していないため、宣言時の経路 (`rebuildingContent: false`) を一度も通らない
- 新規の `test観測する値が同じなら可視セルを再構成しない` (同ファイル:928) は `touchFeedbackColor` を差し替えているが、アサーションは `builds.counts` の不変だけで、**色が届いたこと**は見ていない

つまり、将来 `reconfigureVisibleCells(rebuildingContent:)` の分割を潰して `if rebuildingContent { ... }` の外の `configure(cell:at:)` まで囲っても、全テストが緑のまま通る。deviation が「守るために分けた」挙動が、テストで固定されていない。プローブでは現行実装で色が届くことを確認しており、実装は正しい。守りだけが欠けている。

**推奨修正**:
`test観測する値が同じなら可視セルを再構成しない` に、`touchFeedbackColor` を `.systemRed` へ変えた更新の後で可視セルの `touchFeedbackColor` が `.systemRed` になっていることのアサーションを足す (`tryUnwrapCell(controller, item: 0).touchFeedbackColor`)。「テンプレートは呼び直さない」と「位置依存の表示は追随する」を同じテストで対にして固定できる。

### [🟡 Minor] 公開 doc コメントが「渡すと、渡した値以外の変化では作り直されない」を述べていない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionView.swift:122-134`

**問題点**:
doc コメントは「渡すと値が変わったときに作り直される」「渡さないと再評価のたびに作り直される」の 2 つを述べているが、**渡した場合に排他的に狭まること**を明言していない。実際には、`observedValue(_:)` を宣言した瞬間から、配列が同値であるかぎり観測する値**以外**の変化 (body で読んでいる別の状態、テンプレートのクロージャの差し替え) は可視セルへ届かなくなる。プローブでクロージャ差し替えが無視されることを確認した。

これは spec / ios/ADR-0008 どおりの意図した挙動なので実装の誤りではない。しかし、既存の書き方 (親の状態を body でも読む) をしている利用者が「念のため」1 つの状態だけを `observedValue` に渡すと、それまで届いていた他の状態の更新が静かに止まる — この API の最も鋭い縁であり、現在の文面からは推論できない。tasks 4.3 が求める「利用者契約」の核でもある。

**推奨修正**:
doc コメントに「渡した値が変わったときだけ作り直します (それ以外の変化では作り直されません)」の趣旨を 1 文足し、「状態が複数あるときは 1 つの値にまとめて渡します」がその帰結であることが読み取れるようにする。型レベルの doc コメント (同ファイル:5-7) の「渡さないと追従しないことがあります」とも対になる。

### [🟡 Minor] spike の結論「不成立」が、構成 C については証跡の射程外

**該当箇所**: `deviation.md`「アニメーションの spike (tasks 2.1 / 2.2): 不成立につき見送り」、`evidence/transaction-spike.md`

**問題点**:
見出しと本文冒頭は「中身のアニメーションが揃う効果は観測できなかったため取り込まない」と断定的に読めるが、記録の中身は構成ごとに射程が違う。

- 構成 A / B: 届く transaction が `animation=nil` である以上、引き渡しは論理的に no-op。**確定した否定**であり、この論拠は frame ログに依存しない (妥当)
- 構成 C (タップを `withAnimation` で包む): `animation=DefaultAnimation` が実際に届いており、機構としては引き渡せている。ここで比較された presentation layer の高さは UICollectionView の自己サイズ変更由来で、記録自身が「transaction の有無に依存しない」と書いている。そして肝心の中身の描画については「この計測では判定できなかった」「オーナー目視での確認は別途必要」と明記されている

つまり spike の目的 (トランザクションを引き渡すと中身がアニメーションするか) は、構成 C については**未判定**であって不成立ではない。tasks 2.1 が判定手段として挙げた 2 つ (オーナー目視 / offset・frame ログの A/B) のうち、実施した frame ログの A/B が対象現象に届かなかったのだから、もう一方へ落とす筋になる。

このまま蒸留に渡ると、ios/ADR-0008 の Consequences「トランザクションを引き渡して改善できるかは本 change の中で確かめる」に対して「確かめて否定された」という誤った確定が入りうる。実装コードには spike の残骸が無いこと (`grep -rn "spike\|withTransaction\|CADisplayLink" ios/ samples/` で 0 件) は確認済みで、プロダクトコードのリスクは無い。

**推奨修正**:
deviation.md の当該節に「構成 C は未判定 (中身の描画は本計測の射程外)。判定にはオーナー目視が要る」を明示し、見出しまたは冒頭の断定を「A・B は不成立が確定、C は未判定のため見送り」の形に直す。deviation.md は足場凍結の対象外なので実装側で修正できる。実際にオーナー目視まで行うかは、オーナー判断 (exploration「この change のスコープ内で探る」) の解釈になるため、オーケストレーターからオーナーへ諮るのが妥当。

### [🔵 Suggestion] Android の検証画面に「展開中: N 行」が残っている

**該当箇所**: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/HeightChangeVerificationScreen.kt:87-92`

**問題点**:
iOS 側から撤去した「展開中: N 行」表示 (`heightChange.expandedCount`) が Android 側の同名検証画面には残っている。「検証: 行の高さ変化」は両プラットフォームともプラットフォーム固有の技術検証画面であり、sample-parity の例外枠 (一致の対象外) に当たるため**規約違反ではない**。tasks 3.1 の「iOS 固有画面のため sample-parity の追随対象外」という判断自体は正しい。

ただし iOS 側のこの表示は「body で state を読んで依存を張る回避策」として置かれたものであり、Compose では回避策としての役割を持たない。Android 側が iOS の回避策の写しとして入ったものなら、根拠を失った表示が残っている状態になる。

**推奨修正**:
Android 側の表示が意図して残す情報表示なのか、回避策の写しなのかを確認する。後者なら蒸留時のフォローとして記録するか、別途起票する。本 change のスコープを広げてまで直す必要はない。

### [🔵 Suggestion] ios/performance-verification の適用判定が成果物に残っていない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:342-357`、`tasks.md` 5 節

**問題点**:
`handbook/ios/index.md` の「適用のきっかけ」は「iOS エンジンの描画・再利用・レイアウト経路に触れるとき」であり、本 diff は `reconfigureVisibleCells` / `apply` という描画・再利用経路そのものに触れている。規約本文は「この経路に触れる変更は 2 系統 (hitch time ratio / メモリ) を計測し、両方を満たすまで性能面の完了と報告しない」と定める。tasks.md には性能検証の項目が無く、計測記録も無い。

一方で本変更がこの経路に加えたのは「条件が満たされたときに作業を**省く**」分岐だけで、フレームごとの新規コストは増えていない。フル計測 (基準機 + Instruments 3 試行 + メモリ往復) を掛けるのは釣り合わないと考える。

**推奨修正**:
計測の実施ではなく、**適用外と判断した根拠**を残すことを勧める (deviation.md か完了報告に「描画・再利用経路への変更は作業の省略のみで新規コストを持たないため、性能 2 系統の再計測は行わない」旨)。判定を残さないと、次の drift / 蒸留で「規約に当たる変更なのに計測が無い」として再燃する。tasks.md は凍結対象なので書き換えは求めない。

## 確認した観点 (指摘に至らなかったもの)

- **spec 充足**: collection-core の 6 Scenario すべてに対応するテストがあり、実装経路も一致する。samples の 2 Scenario は Sample の diff (表示の撤去・`observedValue` の適用) と handbook の観測点表で担保される
- **観測値の記録**: 配列が変わった更新でも `self.configuration = configuration` で観測値が記録され、次回の比較に使われる。`update(configuration:)` で `previousObservedValue` を代入前に退避している順序も正しい (`KsCollectionViewController.swift:96`)
- **未宣言 → 宣言 / 宣言 → 未宣言の遷移**: どちらも `observedValue == nil` または `!= previous` で真になり再構成される。判定漏れなし
- **`AnyHashable` の型消去**: 異種型・`Optional` を渡した場合も `AnyHashable` の非 nil 値として保持され、「宣言あり」と判定される。`nil` になって未宣言へ落ちる経路は無い
- **早期 return 以外の経路への影響**: `rebuildingVisibleCellContentOnEqualItems` は同値配列の早期 return だけに掛かる。`init` からの `apply`、`layoutKindChanged` の全件再構成、snapshot 適用後の `updateVisibleCellSeparators` / `updateVisibleSupplementaryViews` はいずれも従来どおり
- **公開 API の一貫性**: `observedValue(_:)` は既存 modifier と同じ「コピーして書き換えて返す」形・名詞句の命名で揃っている。名称確定の根拠は deviation.md に記録済み (ios/ADR-0008 は仮称と明記しているため乖離ではない)
- **comment-policy**: 公開 doc コメントに ADR ID・change 名・spec 語彙の混入なし。ADR 参照は内部コメント側 (`KsCollectionConfiguration.swift:19-20`、`KsCollectionViewController.swift:94-95`) に `ios/ADR-0006` の許容形式で置かれている
- **パス記述**: deviation.md / evidence の参照はすべて change 相対またはリポジトリ相対。ローカル絶対パスなし (lint でも 0 件)
- **tasks 4.1 / 4.2 (concepts 更新)**: 蒸留フェーズへの引き渡し運用のため未着手を指摘対象にしていない

## アクションプラン

1. (指摘 1) `test観測する値が同じなら可視セルを再構成しない` に `touchFeedbackColor` の反映アサーションを追加する — 分割を守るテストが無い状態を解消する
2. (指摘 2) `observedValue(_:)` の doc コメントに「渡した値以外の変化では作り直されない」旨を追記する
3. (指摘 3) deviation.md の spike 節で、構成 C が未判定であることを明示する。オーナー目視まで行うかはオーナーに諮る
4. (指摘 5) 性能検証規約を適用外と判断した根拠を deviation.md か完了報告に残す
5. (指摘 4) Android の「展開中: N 行」の扱いを確認し、必要なら蒸留のフォローまたは別起票へ回す
